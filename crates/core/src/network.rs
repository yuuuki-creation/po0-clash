use std::net::IpAddr;

use crate::model::IntranetIp;

/// Tunnels, VPNs (mihomo's own TUN included), bridges and Apple's peer-to-peer links never carry the address other
/// devices on the LAN reach.
const VIRTUAL: &[&str] = &[
    "utun", "tun", "tap", "wg", "ipsec", "ppp", "llw", "awdl", "anpi", "gif", "stf", "bridge",
    "docker", "veth", "vmnet", "Meta",
];

const PHYSICAL: &[&str] = &["en", "eth", "wlan", "wl"];

pub fn intranet_ip() -> Option<IntranetIp> {
    pick(interfaces())
}

fn pick(mut candidates: Vec<(String, IpAddr)>) -> Option<IntranetIp> {
    candidates
        .retain(|(name, ip)| usable(ip) && !VIRTUAL.iter().any(|prefix| name.starts_with(prefix)));
    candidates.sort_by_key(|(name, ip)| {
        (
            !PHYSICAL.iter().any(|prefix| name.starts_with(prefix)),
            !ip.is_ipv4(),
        )
    });
    candidates.into_iter().next().map(|(name, ip)| IntranetIp {
        ip: ip.to_string(),
        interface: Some(name).filter(|name| !name.is_empty()),
    })
}

/// 198.18.0.0/15 is where mihomo puts its TUN and fake-ip addresses.
fn usable(ip: &IpAddr) -> bool {
    match ip {
        IpAddr::V4(v4) => {
            let [a, b, ..] = v4.octets();
            !v4.is_loopback()
                && !v4.is_unspecified()
                && !v4.is_link_local()
                && !(a == 198 && (b & 0xfe) == 18)
        }
        IpAddr::V6(v6) => !v6.is_loopback() && !v6.is_unspecified() && !v6.is_unicast_link_local(),
    }
}

#[cfg(unix)]
fn interfaces() -> Vec<(String, IpAddr)> {
    use std::ffi::CStr;
    use std::net::{Ipv4Addr, Ipv6Addr};

    let mut found = Vec::new();
    let mut head: *mut libc::ifaddrs = std::ptr::null_mut();
    // SAFETY: the list is only read before freeifaddrs, and each address as the structure its family names.
    unsafe {
        if libc::getifaddrs(&mut head) != 0 {
            return found;
        }
        let mut cursor = head;
        while let Some(entry) = cursor.as_ref() {
            cursor = entry.ifa_next;
            if entry.ifa_flags & libc::IFF_UP as libc::c_uint == 0 || entry.ifa_addr.is_null() {
                continue;
            }
            let ip = match i32::from((*entry.ifa_addr).sa_family) {
                libc::AF_INET => {
                    let addr = &*entry.ifa_addr.cast::<libc::sockaddr_in>();
                    IpAddr::V4(Ipv4Addr::from(u32::from_be(addr.sin_addr.s_addr)))
                }
                libc::AF_INET6 => {
                    let addr = &*entry.ifa_addr.cast::<libc::sockaddr_in6>();
                    IpAddr::V6(Ipv6Addr::from(addr.sin6_addr.s6_addr))
                }
                _ => continue,
            };
            let name = CStr::from_ptr(entry.ifa_name)
                .to_string_lossy()
                .into_owned();
            found.push((name, ip));
        }
        libc::freeifaddrs(head);
    }
    found
}

/// Connecting a UDP socket sends nothing; it only makes the OS choose the address its default route leaves from.
#[cfg(not(unix))]
fn interfaces() -> Vec<(String, IpAddr)> {
    std::net::UdpSocket::bind("0.0.0.0:0")
        .and_then(|socket| {
            socket.connect("192.0.2.1:9")?;
            socket.local_addr()
        })
        .map(|addr| vec![(String::new(), addr.ip())])
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn candidate(name: &str, ip: &str) -> (String, IpAddr) {
        (name.to_owned(), ip.parse().unwrap())
    }

    #[test]
    fn prefers_the_lan_address_over_tunnels_and_bridges() {
        let picked = pick(vec![
            candidate("lo0", "127.0.0.1"),
            candidate("utun4", "198.18.0.1"),
            candidate("bridge100", "192.168.64.1"),
            candidate("en0", "fe80::1"),
            candidate("en0", "2001:db8::5"),
            candidate("en0", "192.168.1.23"),
            candidate("en7", "10.0.0.2"),
        ]);
        assert_eq!(
            picked,
            Some(IntranetIp {
                ip: "192.168.1.23".to_owned(),
                interface: Some("en0".to_owned()),
            })
        );
    }

    #[test]
    fn falls_back_to_ipv6_and_unnamed_addresses() {
        let picked = pick(vec![candidate("en0", "2001:db8::5")]).unwrap();
        assert_eq!(picked.ip, "2001:db8::5");
        let unnamed = pick(vec![candidate("", "192.168.1.9")]).unwrap();
        assert_eq!(unnamed.interface, None);
        assert_eq!(pick(vec![candidate("", "198.19.0.1")]), None);
        assert!(intranet_ip().is_none_or(|found| !found.ip.is_empty()));
    }
}
