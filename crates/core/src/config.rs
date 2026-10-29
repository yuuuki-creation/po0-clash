use serde_yaml::{Mapping, Value};

use crate::error::{CoreError, Result};
use crate::model::{Mode, Platform, RouteMode};

pub const PO0_HOST: &str = "124.221.69.228";
pub const PO0_CIDR: &str = "124.221.69.228/32";
pub const DELAY_URL: &str = "https://www.gstatic.com/generate_204";
const DIRECT_LISTENER: &str = "po0-direct";
const LOOPBACK: &str = "127.0.0.1";

/// Android VpnService addresses; the Builder in the app must use the same ones and MTU.
pub const ANDROID_TUN_V4: &str = "172.19.0.1/30";
pub const ANDROID_TUN_V6: &str = "fdfe:dcba:9876::1/126";
pub const ANDROID_TUN_MTU: u32 = 9000;

const OVERRIDDEN: &[&str] = &[
    "port",
    "socks-port",
    "redir-port",
    "tproxy-port",
    "mixed-port",
    "allow-lan",
    "bind-address",
    "authentication",
    "skip-auth-prefixes",
    "external-controller",
    "external-controller-tls",
    "external-controller-unix",
    "external-controller-pipe",
    "external-controller-cors",
    "external-ui",
    "external-ui-url",
    "external-ui-name",
    "external-doh-server",
    "secret",
    "tun",
    "profile",
];

const DEFAULT_DNS: &str = "
enable: true
ipv6: false
enhanced-mode: fake-ip
fake-ip-range: 198.18.0.1/16
fake-ip-filter: ['*.lan', '*.local', 'localhost', '+.msftconnecttest.com', '+.msftncsi.com', 'time.*.com', 'ntp.*.com']
default-nameserver: [223.5.5.5, 119.29.29.29]
nameserver: ['https://dns.alidns.com/dns-query', 'https://doh.pub/dns-query']
";

const GEOX_URL: &str = "
geoip: https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat
geosite: https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat
mmdb: https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/country.mmdb
asn: https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/GeoLite2-ASN.mmdb
";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DirectListener {
    pub port: u16,
    pub username: String,
    pub password: String,
}

impl DirectListener {
    /// mihomo resolves a listener's `proxy` before the mode, so neither global mode nor TUN
    /// can send these connections through a node (ADR 0012).
    pub fn route(&self) -> String {
        format!(
            "PROXY {}:{}@{LOOPBACK}:{}",
            self.username, self.password, self.port
        )
    }
}

pub struct Params<'a> {
    pub platform: Platform,
    pub mode: Mode,
    pub route_mode: RouteMode,
    pub tun_fd: Option<i32>,
    pub mixed_port: u16,
    pub controller: (&'static str, String),
    pub secret: &'a str,
    pub direct: &'a DirectListener,
}

fn key(name: &str) -> Value {
    Value::String(name.to_owned())
}

fn yaml(text: &str) -> Value {
    serde_yaml::from_str(text).expect("built-in YAML parses")
}

fn strings<'a>(items: impl IntoIterator<Item = &'a str>) -> Value {
    Value::Sequence(items.into_iter().map(key).collect())
}

pub fn links_base(provider_path: &str) -> String {
    format!(
        "proxy-providers:
  links:
    type: file
    path: '{provider_path}'
    health-check: {{enable: true, url: '{DELAY_URL}', interval: 600}}
proxy-groups:
  - {{name: PROXY, type: select, use: [links]}}
rules:
  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - MATCH,PROXY
"
    )
}

pub fn render(base: &str, params: &Params) -> Result<String> {
    let invalid = |error: serde_yaml::Error| CoreError::Invalid(format!("config: {error}"));
    let mut value: Value = serde_yaml::from_str(base).map_err(invalid)?;
    value.apply_merge().map_err(invalid)?;
    let Value::Mapping(mut root) = value else {
        return Err(CoreError::Invalid("config: not a mapping".into()));
    };
    for name in OVERRIDDEN {
        root.remove(*name);
    }
    let set = |root: &mut Mapping, name: &str, value: Value| {
        root.insert(key(name), value);
    };
    set(&mut root, "mixed-port", Value::from(params.mixed_port));
    set(&mut root, "allow-lan", Value::Bool(false));
    set(&mut root, "bind-address", key(LOOPBACK));
    set(&mut root, "mode", key(params.mode.as_str()));
    set(&mut root, "log-level", key("warning"));
    set(&mut root, "external-controller", key(""));
    set(&mut root, params.controller.0, key(&params.controller.1));
    set(&mut root, "secret", key(params.secret));
    set(
        &mut root,
        "profile",
        yaml("{store-selected: false, store-fake-ip: true}"),
    );
    if !root.contains_key("geox-url") {
        set(&mut root, "geox-url", yaml(GEOX_URL));
    }
    if params.platform == Platform::Android {
        set(&mut root, "find-process-mode", key("off"));
    }

    let tun = tun(params);
    let tun_on = tun.get("enable") == Some(&Value::Bool(true));
    set(&mut root, "tun", Value::Mapping(tun));
    match root.get_mut("dns") {
        Some(Value::Mapping(dns)) if tun_on => {
            dns.insert(key("enable"), Value::Bool(true));
        }
        Some(Value::Mapping(_)) => {}
        _ => set(&mut root, "dns", yaml(DEFAULT_DNS)),
    }

    let mut listeners: Vec<Value> = match root.remove("listeners") {
        Some(Value::Sequence(items)) => items
            .into_iter()
            .filter(|item| item.get("name").and_then(Value::as_str) != Some(DIRECT_LISTENER))
            .collect(),
        _ => Vec::new(),
    };
    let mut user = Mapping::new();
    user.insert(key("username"), key(&params.direct.username));
    user.insert(key("password"), key(&params.direct.password));
    let mut direct = Mapping::new();
    direct.insert(key("name"), key(DIRECT_LISTENER));
    direct.insert(key("type"), key("http"));
    direct.insert(key("listen"), key(LOOPBACK));
    direct.insert(key("port"), Value::from(params.direct.port));
    direct.insert(key("users"), Value::Sequence(vec![Value::Mapping(user)]));
    direct.insert(key("proxy"), key("DIRECT"));
    listeners.push(Value::Mapping(direct));
    set(&mut root, "listeners", Value::Sequence(listeners));

    let po0_rule = key(&format!("IP-CIDR,{PO0_CIDR},DIRECT,no-resolve"));
    match root.get_mut("rules") {
        Some(Value::Sequence(rules)) => rules.insert(0, po0_rule),
        _ => set(&mut root, "rules", Value::Sequence(vec![po0_rule])),
    }

    serde_yaml::to_string(&Value::Mapping(root)).map_err(invalid)
}

fn tun(params: &Params) -> Mapping {
    let mut tun = Mapping::new();
    let mut set = |name: &str, value: Value| {
        tun.insert(key(name), value);
    };
    match (params.platform, params.tun_fd, params.route_mode) {
        (Platform::Android, fd, _) => {
            set("enable", Value::Bool(fd.is_some()));
            set("stack", key("gvisor"));
            set("file-descriptor", Value::from(fd.unwrap_or(0)));
            set("auto-route", Value::Bool(false));
            set("auto-detect-interface", Value::Bool(false));
            set("inet4-address", strings([ANDROID_TUN_V4]));
            set("inet6-address", strings([ANDROID_TUN_V6]));
            set("mtu", Value::from(ANDROID_TUN_MTU));
            set("dns-hijack", strings(["any:53"]));
        }
        (platform, _, RouteMode::Tun) => {
            set("enable", Value::Bool(true));
            if platform == Platform::Windows {
                set("device", key("po0-clash"));
            }
            set("stack", key("mixed"));
            set("auto-route", Value::Bool(true));
            set("auto-detect-interface", Value::Bool(true));
            set("strict-route", Value::Bool(false));
            set("dns-hijack", strings(["any:53"]));
            set("route-exclude-address", strings([PO0_CIDR]));
        }
        (_, _, RouteMode::SystemProxy) => set("enable", Value::Bool(false)),
    }
    tun
}

#[cfg(test)]
mod tests {
    use super::*;

    fn direct() -> DirectListener {
        DirectListener {
            port: 4000,
            username: "u".into(),
            password: "p".into(),
        }
    }

    fn params(
        platform: Platform,
        route_mode: RouteMode,
        tun_fd: Option<i32>,
    ) -> (Platform, RouteMode, Option<i32>) {
        (platform, route_mode, tun_fd)
    }

    fn render_with(
        base: &str,
        (platform, route_mode, tun_fd): (Platform, RouteMode, Option<i32>),
    ) -> Value {
        let direct = direct();
        let text = render(
            base,
            &Params {
                platform,
                mode: Mode::Global,
                route_mode,
                tun_fd,
                mixed_port: 7894,
                controller: ("external-controller-unix", "/run/ctl.sock".into()),
                secret: "s",
                direct: &direct,
            },
        )
        .unwrap();
        serde_yaml::from_str(&text).unwrap()
    }

    const SUBSCRIPTION: &str = "
port: 7890
socks-port: 7891
allow-lan: true
external-controller: 0.0.0.0:9090
secret: theirs
mode: rule
base: &base {type: ss, cipher: aes-128-gcm, password: p, port: 1}
proxies:
  - {<<: *base, name: a, server: 1.1.1.1}
listeners:
  - {name: po0-direct, type: socks, port: 1}
  - {name: keep, type: socks, port: 2}
dns: {enable: false, nameserver: [1.1.1.1]}
rules:
  - MATCH,DIRECT
";

    #[test]
    fn overrides_ports_controller_and_mode() {
        let config = render_with(
            SUBSCRIPTION,
            params(Platform::MacOs, RouteMode::SystemProxy, None),
        );
        assert_eq!(config["mixed-port"], Value::from(7894));
        assert!(config.get("port").is_none() && config.get("socks-port").is_none());
        assert_eq!(config["allow-lan"], Value::Bool(false));
        assert_eq!(config["external-controller"], key(""));
        assert_eq!(config["external-controller-unix"], key("/run/ctl.sock"));
        assert_eq!(config["secret"], key("s"));
        assert_eq!(config["mode"], key("global"));
        assert_eq!(config["tun"]["enable"], Value::Bool(false));
        assert_eq!(config["dns"]["enable"], Value::Bool(false));
        assert_eq!(config["proxies"][0]["cipher"], key("aes-128-gcm"));
        assert!(config["proxies"][0].get("<<").is_none());
    }

    #[test]
    fn adds_the_po0_direct_route() {
        let config = render_with(
            SUBSCRIPTION,
            params(Platform::Windows, RouteMode::Tun, None),
        );
        assert_eq!(
            config["rules"][0],
            key("IP-CIDR,124.221.69.228/32,DIRECT,no-resolve")
        );
        assert_eq!(config["rules"][1], key("MATCH,DIRECT"));
        let listeners = config["listeners"].as_sequence().unwrap();
        assert_eq!(listeners.len(), 2);
        assert_eq!(listeners[0]["name"], key("keep"));
        assert_eq!(listeners[1]["name"], key("po0-direct"));
        assert_eq!(listeners[1]["proxy"], key("DIRECT"));
        assert_eq!(listeners[1]["users"][0]["password"], key("p"));
        assert_eq!(config["tun"]["route-exclude-address"][0], key(PO0_CIDR));
        assert_eq!(config["tun"]["device"], key("po0-clash"));
        assert_eq!(config["dns"]["enable"], Value::Bool(true));
    }

    #[test]
    fn android_runs_tun_on_the_vpn_descriptor() {
        let config = render_with(
            "proxies: []\n",
            params(Platform::Android, RouteMode::SystemProxy, Some(42)),
        );
        assert_eq!(config["tun"]["enable"], Value::Bool(true));
        assert_eq!(config["tun"]["file-descriptor"], Value::from(42));
        assert_eq!(config["tun"]["auto-route"], Value::Bool(false));
        assert_eq!(config["find-process-mode"], key("off"));
        assert_eq!(config["dns"]["enhanced-mode"], key("fake-ip"));
        assert_eq!(
            config["rules"][0],
            key("IP-CIDR,124.221.69.228/32,DIRECT,no-resolve")
        );
    }

    #[test]
    fn links_profiles_render() {
        let config = render_with(
            &links_base("./providers/x.txt"),
            params(Platform::MacOs, RouteMode::Tun, None),
        );
        assert_eq!(
            config["proxy-providers"]["links"]["path"],
            key("./providers/x.txt")
        );
        assert_eq!(config["proxy-groups"][0]["name"], key("PROXY"));
        assert_eq!(
            config["rules"].as_sequence().unwrap().last().unwrap(),
            &key("MATCH,PROXY")
        );
    }

    #[test]
    fn rejects_non_mappings() {
        let direct = direct();
        let result = render(
            "- a\n",
            &Params {
                platform: Platform::MacOs,
                mode: Mode::Rule,
                route_mode: RouteMode::SystemProxy,
                tun_fd: None,
                mixed_port: 1,
                controller: ("external-controller-unix", String::new()),
                secret: "",
                direct: &direct,
            },
        );
        assert!(result.is_err());
    }

    #[test]
    fn the_direct_route_names_the_listener() {
        assert_eq!(direct().route(), "PROXY u:p@127.0.0.1:4000");
    }
}
