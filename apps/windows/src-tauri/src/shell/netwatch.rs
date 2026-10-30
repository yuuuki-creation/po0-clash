use std::net::Ipv4Addr;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use windows_sys::Win32::NetworkManagement::IpHelper::{GetBestRoute2, MIB_IPFORWARD_ROW2};
use windows_sys::Win32::Networking::WinSock::{AF_INET, SOCKADDR_INET};

use super::po0::Core;

const INTERVAL: Duration = Duration::from_secs(5);

// po0's API address is excluded from the TUN routes, so its route always describes the physical uplink.
const PROBE: Ipv4Addr = Ipv4Addr::new(124, 221, 69, 228);

#[derive(PartialEq, Eq)]
struct Uplink {
    interface: u32,
    next_hop: u32,
    source: u32,
}

fn uplink() -> Option<Uplink> {
    // SAFETY: plain-old-data out parameters, zero-initialised, so reading them is defined even when the call fails.
    unsafe {
        let mut destination: SOCKADDR_INET = std::mem::zeroed();
        destination.Ipv4.sin_family = AF_INET;
        destination.Ipv4.sin_addr.S_un.S_addr = u32::from_ne_bytes(PROBE.octets());
        let mut route: MIB_IPFORWARD_ROW2 = std::mem::zeroed();
        let mut source: SOCKADDR_INET = std::mem::zeroed();
        let status = GetBestRoute2(
            std::ptr::null(),
            0,
            std::ptr::null(),
            &destination,
            0,
            &mut route,
            &mut source,
        );
        (status == 0).then_some(Uplink {
            interface: route.InterfaceIndex,
            next_hop: route.NextHop.Ipv4.sin_addr.S_un.S_addr,
            source: source.Ipv4.sin_addr.S_un.S_addr,
        })
    }
}

pub fn spawn(core: Arc<Core>) {
    thread::Builder::new()
        .name("netwatch".into())
        .spawn(move || {
            let mut last = uplink();
            loop {
                thread::sleep(INTERVAL);
                let now = uplink();
                if now != last {
                    last = now;
                    core.network_changed();
                }
            }
        })
        .expect("spawn network watcher");
}
