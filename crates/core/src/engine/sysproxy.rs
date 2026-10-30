#[cfg(any(target_os = "macos", windows))]
mod imp {
    use sysproxy::Sysproxy;

    use crate::options;

    #[cfg(target_os = "macos")]
    const SEPARATOR: &str = ",";
    #[cfg(windows)]
    const SEPARATOR: &str = ";";

    fn proxy(enable: bool, port: u16, bypass: &[String]) -> Sysproxy {
        let bypass: Vec<&str> = bypass
            .iter()
            .map(|host| host.trim())
            .filter(|host| !host.is_empty())
            .collect();
        Sysproxy {
            enable,
            host: "127.0.0.1".into(),
            port,
            bypass: bypass.join(SEPARATOR),
        }
    }

    pub fn set(port: u16, bypass: &[String]) -> Result<(), String> {
        proxy(true, port, bypass)
            .set_system_proxy()
            .map_err(|error| error.to_string())
    }

    pub fn clear(port: u16) {
        let _ = proxy(false, port, &options::default_bypass()).set_system_proxy();
    }

    pub fn points_at(port: u16) -> bool {
        Sysproxy::get_system_proxy().is_ok_and(|current| {
            current.enable && current.host == "127.0.0.1" && current.port == port
        })
    }
}

#[cfg(not(any(target_os = "macos", windows)))]
mod imp {
    pub fn set(_port: u16, _bypass: &[String]) -> Result<(), String> {
        Ok(())
    }

    pub fn clear(_port: u16) {}

    pub fn points_at(_port: u16) -> bool {
        false
    }
}

pub use imp::*;
