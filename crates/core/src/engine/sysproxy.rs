#[cfg(any(target_os = "macos", windows))]
mod imp {
    use sysproxy::Sysproxy;

    #[cfg(target_os = "macos")]
    const BYPASS: &str =
        "127.0.0.1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,localhost,*.local,timestamp.apple.com";
    #[cfg(windows)]
    const BYPASS: &str = "localhost;127.*;192.168.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.2*;172.30.*;172.31.*;<local>";

    fn proxy(enable: bool, port: u16) -> Sysproxy {
        Sysproxy {
            enable,
            host: "127.0.0.1".into(),
            port,
            bypass: BYPASS.into(),
        }
    }

    pub fn set(port: u16) -> Result<(), String> {
        proxy(true, port)
            .set_system_proxy()
            .map_err(|error| error.to_string())
    }

    pub fn clear(port: u16) {
        let _ = proxy(false, port).set_system_proxy();
    }

    pub fn points_at(port: u16) -> bool {
        Sysproxy::get_system_proxy().is_ok_and(|current| {
            current.enable && current.host == "127.0.0.1" && current.port == port
        })
    }
}

#[cfg(not(any(target_os = "macos", windows)))]
mod imp {
    pub fn set(_port: u16) -> Result<(), String> {
        Ok(())
    }

    pub fn clear(_port: u16) {}

    pub fn points_at(_port: u16) -> bool {
        false
    }
}

pub use imp::*;
