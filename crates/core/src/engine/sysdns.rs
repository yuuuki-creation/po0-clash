//! FlClash's "auto set system DNS" on macOS: while TUN runs, the default network service also lists a public
//! resolver, so lookups that would go straight to a LAN resolver leave through TUN, where mihomo answers them.

use std::net::IpAddr;

use serde::{Deserialize, Serialize};

#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
pub const FALLBACK: &str = "223.5.5.5";

/// The servers a network service had before the fallback was added.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Saved {
    pub service: String,
    pub servers: Vec<String>,
}

#[cfg(target_os = "macos")]
mod imp {
    use std::process::Command;

    use super::{FALLBACK, Saved, default_interface, dns_servers, service_for};

    const NETWORKSETUP: &str = "/usr/sbin/networksetup";

    fn run(program: &str, args: &[&str]) -> Option<String> {
        let output = Command::new(program).args(args).output().ok()?;
        output
            .status
            .success()
            .then(|| String::from_utf8_lossy(&output.stdout).into_owned())
    }

    fn default_service() -> Option<String> {
        let device = default_interface(&run("/sbin/route", &["-n", "get", "default"])?)?;
        service_for(&run(NETWORKSETUP, &["-listnetworkserviceorder"])?, &device)
    }

    fn read(service: &str) -> Option<Vec<String>> {
        run(NETWORKSETUP, &["-getdnsservers", service]).map(|output| dns_servers(&output))
    }

    fn write(service: &str, servers: &[String]) -> bool {
        let mut args = vec!["-setdnsservers", service];
        if servers.is_empty() {
            args.push("Empty");
        } else {
            args.extend(servers.iter().map(String::as_str));
        }
        run(NETWORKSETUP, &args).is_some()
    }

    /// Nothing is saved when the service already lists the fallback, since then there is nothing to undo.
    pub fn apply() -> Option<Saved> {
        let service = default_service()?;
        let servers = read(&service)?;
        if servers.iter().any(|server| server == FALLBACK) {
            return None;
        }
        let mut patched = servers.clone();
        patched.push(FALLBACK.into());
        write(&service, &patched).then_some(Saved { service, servers })
    }

    pub fn restore(saved: &Saved) {
        write(&saved.service, &saved.servers);
    }

    /// After a network change the default service may differ, or its servers may have been reset.
    pub fn refresh(saved: Option<Saved>) -> Option<Saved> {
        if let Some(saved) = saved {
            let intact = default_service().as_deref() == Some(saved.service.as_str())
                && read(&saved.service)
                    .is_some_and(|servers| servers.iter().any(|server| server == FALLBACK));
            if intact {
                return Some(saved);
            }
            restore(&saved);
        }
        apply()
    }
}

#[cfg(not(target_os = "macos"))]
mod imp {
    use super::Saved;

    pub fn apply() -> Option<Saved> {
        None
    }

    pub fn restore(_saved: &Saved) {}

    pub fn refresh(_saved: Option<Saved>) -> Option<Saved> {
        None
    }
}

pub use imp::*;

#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
fn default_interface(route: &str) -> Option<String> {
    route.lines().find_map(|line| {
        let device = line.trim().strip_prefix("interface:")?.trim();
        (!device.is_empty()).then(|| device.to_owned())
    })
}

/// Each `(1) Wi-Fi` line is followed by `(Hardware Port: Wi-Fi, Device: en0)`; disabled services show `(*)`.
#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
fn service_for(order: &str, device: &str) -> Option<String> {
    let mut service = None;
    for line in order.lines().map(str::trim) {
        if let Some(port) = line.strip_prefix("(Hardware Port:") {
            let named = port
                .rsplit_once("Device:")
                .map(|(_, rest)| rest.trim_end_matches(')').trim());
            if named == Some(device) {
                return service;
            }
        } else if let Some((_, name)) = line
            .strip_prefix('(')
            .and_then(|rest| rest.split_once(") "))
        {
            service = Some(name.trim().to_owned());
        }
    }
    None
}

#[cfg_attr(not(target_os = "macos"), allow(dead_code))]
fn dns_servers(output: &str) -> Vec<String> {
    output
        .lines()
        .map(str::trim)
        .filter(|line| line.parse::<IpAddr>().is_ok())
        .map(str::to_owned)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn networksetup_output_is_read() {
        let route = "   route to: default\ndestination: default\n    gateway: 192.168.1.1\n  interface: en0\n";
        assert_eq!(default_interface(route).as_deref(), Some("en0"));
        let order = "An asterisk (*) denotes that a network service is disabled.\n(1) USB 10/100 LAN\n\
                     (Hardware Port: USB 10/100 LAN, Device: en7)\n\n(*) Wi-Fi Backup\n\
                     (Hardware Port: Wi-Fi, Device: en1)\n\n(2) Wi-Fi\n(Hardware Port: Wi-Fi, Device: en0)\n";
        assert_eq!(service_for(order, "en0").as_deref(), Some("Wi-Fi"));
        assert_eq!(service_for(order, "en7").as_deref(), Some("USB 10/100 LAN"));
        assert_eq!(service_for(order, "utun3"), None);
        assert!(dns_servers("There aren't any DNS Servers set on Wi-Fi.\n").is_empty());
        assert_eq!(
            dns_servers("192.168.1.1\nfe80::1\n"),
            ["192.168.1.1", "fe80::1"]
        );
    }
}
