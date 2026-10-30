use serde_yaml::{Mapping, Value};

use crate::error::{CoreError, Result};
use crate::model::{Mode, Platform, RouteMode};
use crate::options::{
    DnsMode, DnsOptions, EngineOptions, FindProcessMode, GeodataLoader, TunStack,
};

pub const PO0_HOST: &str = "124.221.69.228";
pub const PO0_CIDR: &str = "124.221.69.228/32";
pub const DELAY_URL: &str = "https://www.gstatic.com/generate_204";
const DIRECT_LISTENER: &str = "po0-direct";
const LOOPBACK: &str = "127.0.0.1";
const EXTERNAL_CONTROLLER: &str = "127.0.0.1:9090";
const SYSTEM_DNS: &str = "system://";

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
    pub options: &'a EngineOptions,
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

pub fn links_base(provider_path: &str, delay_url: &str) -> String {
    format!(
        "proxy-providers:
  links:
    type: file
    path: '{provider_path}'
    health-check: {{enable: true, url: '{delay_url}', interval: 600}}
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
    let options = params.options;
    set(&mut root, "mixed-port", Value::from(params.mixed_port));
    if options.socks_port != 0 {
        set(&mut root, "socks-port", Value::from(options.socks_port));
    }
    if options.http_port != 0 {
        set(&mut root, "port", Value::from(options.http_port));
    }
    set(&mut root, "allow-lan", Value::Bool(options.allow_lan));
    set(
        &mut root,
        "bind-address",
        key(if options.allow_lan { "*" } else { LOOPBACK }),
    );
    if !options.authentication.is_empty() {
        set(
            &mut root,
            "authentication",
            strings(options.authentication.iter().map(String::as_str)),
        );
        // The system proxy cannot carry credentials, so local clients stay exempt.
        set(
            &mut root,
            "skip-auth-prefixes",
            strings(["127.0.0.1/8", "::1/128"]),
        );
    }
    set(&mut root, "mode", key(params.mode.as_str()));
    set(&mut root, "log-level", key(options.log_level.as_str()));
    set(&mut root, "ipv6", Value::Bool(options.ipv6));
    set(
        &mut root,
        "unified-delay",
        Value::Bool(options.unified_delay),
    );
    set(
        &mut root,
        "tcp-concurrent",
        Value::Bool(options.tcp_concurrent),
    );
    if options.keep_alive_interval != 0 {
        set(
            &mut root,
            "keep-alive-interval",
            Value::from(options.keep_alive_interval),
        );
    }
    if !options.interface_name.trim().is_empty() {
        set(
            &mut root,
            "interface-name",
            key(options.interface_name.trim()),
        );
    }
    if !options.hosts.is_empty() {
        let mut hosts = match root.remove("hosts") {
            Some(Value::Mapping(hosts)) => hosts,
            _ => Mapping::new(),
        };
        for (host, address) in &options.hosts {
            hosts.insert(key(host), key(address));
        }
        set(&mut root, "hosts", Value::Mapping(hosts));
    }
    let external = if options.external_controller {
        EXTERNAL_CONTROLLER
    } else {
        ""
    };
    set(&mut root, "external-controller", key(external));
    set(&mut root, params.controller.0, key(&params.controller.1));
    set(&mut root, "secret", key(params.secret));
    set(
        &mut root,
        "profile",
        yaml("{store-selected: false, store-fake-ip: true}"),
    );
    let mut geox = Mapping::new();
    geox.insert(key("geoip"), key(&options.geox_url.geoip));
    geox.insert(key("geosite"), key(&options.geox_url.geosite));
    geox.insert(key("mmdb"), key(&options.geox_url.mmdb));
    geox.insert(key("asn"), key(&options.geox_url.asn));
    set(&mut root, "geox-url", Value::Mapping(geox));
    set(
        &mut root,
        "geodata-loader",
        key(match options.geodata_loader {
            GeodataLoader::Standard => "standard",
            GeodataLoader::Memconservative => "memconservative",
        }),
    );
    set(
        &mut root,
        "geo-auto-update",
        Value::Bool(options.geo_auto_update),
    );
    set(
        &mut root,
        "geo-update-interval",
        Value::from(options.geo_update_interval.max(1)),
    );
    let find_process = match (params.platform, options.find_process_mode) {
        (Platform::Android, _) | (_, FindProcessMode::Off) => "off",
        (_, FindProcessMode::Strict) => "strict",
        (_, FindProcessMode::Always) => "always",
    };
    set(&mut root, "find-process-mode", key(find_process));

    let tun = tun(params);
    let tun_on = tun.get("enable") == Some(&Value::Bool(true));
    set(&mut root, "tun", Value::Mapping(tun));
    if options.override_dns {
        set(&mut root, "dns", dns(&options.dns));
    }
    match root.get_mut("dns") {
        Some(Value::Mapping(dns)) if tun_on => {
            dns.insert(key("enable"), Value::Bool(true));
        }
        Some(Value::Mapping(_)) => {}
        _ => set(&mut root, "dns", yaml(DEFAULT_DNS)),
    }
    if options.append_system_dns
        && let Some(Value::Mapping(dns)) = root.get_mut("dns")
    {
        let nameserver = dns
            .entry(key("nameserver"))
            .or_insert_with(|| Value::Sequence(Vec::new()));
        if let Value::Sequence(servers) = nameserver
            && !servers.contains(&key(SYSTEM_DNS))
        {
            servers.push(key(SYSTEM_DNS));
        }
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

    let mut rules = vec![key(&format!("IP-CIDR,{PO0_CIDR},DIRECT,no-resolve"))];
    rules.extend(
        options
            .added_rules
            .iter()
            .map(|rule| rule.trim())
            .filter(|rule| !rule.is_empty())
            .map(key),
    );
    if let Some(Value::Sequence(theirs)) = root.remove("rules") {
        rules.extend(theirs);
    }
    set(&mut root, "rules", Value::Sequence(rules));

    serde_yaml::to_string(&Value::Mapping(root)).map_err(invalid)
}

fn dns(options: &DnsOptions) -> Value {
    let mut dns = Mapping::new();
    let mut set = |name: &str, value: Value| {
        dns.insert(key(name), value);
    };
    let list = |items: &[String]| strings(items.iter().map(String::as_str));
    set("enable", Value::Bool(options.enable));
    if !options.listen.trim().is_empty() {
        set("listen", key(options.listen.trim()));
    }
    set("prefer-h3", Value::Bool(options.prefer_h3));
    set("use-hosts", Value::Bool(options.use_hosts));
    set("use-system-hosts", Value::Bool(options.use_system_hosts));
    set("respect-rules", Value::Bool(options.respect_rules));
    set("ipv6", Value::Bool(options.ipv6));
    set(
        "enhanced-mode",
        key(match options.enhanced_mode {
            DnsMode::Normal => "normal",
            DnsMode::FakeIp => "fake-ip",
            DnsMode::RedirHost => "redir-host",
        }),
    );
    set("fake-ip-range", key(&options.fake_ip_range));
    set("fake-ip-filter", list(&options.fake_ip_filter));
    set("default-nameserver", list(&options.default_nameserver));
    set("nameserver", list(&options.nameserver));
    if !options.fallback.is_empty() {
        set("fallback", list(&options.fallback));
        let filter = &options.fallback_filter;
        let mut fallback_filter = Mapping::new();
        fallback_filter.insert(key("geoip"), Value::Bool(filter.geoip));
        fallback_filter.insert(key("geoip-code"), key(&filter.geoip_code));
        fallback_filter.insert(key("geosite"), list(&filter.geosite));
        fallback_filter.insert(key("ipcidr"), list(&filter.ipcidr));
        fallback_filter.insert(key("domain"), list(&filter.domain));
        set("fallback-filter", Value::Mapping(fallback_filter));
    }
    if !options.proxy_server_nameserver.is_empty() {
        set(
            "proxy-server-nameserver",
            list(&options.proxy_server_nameserver),
        );
    }
    if !options.nameserver_policy.is_empty() {
        let policy = options
            .nameserver_policy
            .iter()
            .map(|(domain, server)| (key(domain), key(server)))
            .collect();
        set("nameserver-policy", Value::Mapping(policy));
    }
    Value::Mapping(dns)
}

fn tun(params: &Params) -> Mapping {
    let options = params.options;
    let stack = |default: TunStack| {
        key(match options.tun_stack.unwrap_or(default) {
            TunStack::System => "system",
            TunStack::Gvisor => "gvisor",
            TunStack::Mixed => "mixed",
        })
    };
    let hijack = if options.tun_dns_hijack.is_empty() {
        strings(["any:53"])
    } else {
        strings(options.tun_dns_hijack.iter().map(String::as_str))
    };
    let mut tun = Mapping::new();
    let mut set = |name: &str, value: Value| {
        tun.insert(key(name), value);
    };
    match (params.platform, params.tun_fd, params.route_mode) {
        (Platform::Android, fd, _) => {
            set("enable", Value::Bool(fd.is_some()));
            set("stack", stack(TunStack::Gvisor));
            set("file-descriptor", Value::from(fd.unwrap_or(0)));
            set("auto-route", Value::Bool(false));
            set("auto-detect-interface", Value::Bool(false));
            set("inet4-address", strings([ANDROID_TUN_V4]));
            set("inet6-address", strings([ANDROID_TUN_V6]));
            set("mtu", Value::from(ANDROID_TUN_MTU));
            set("dns-hijack", hijack);
        }
        (platform, _, RouteMode::Tun) => {
            set("enable", Value::Bool(true));
            if platform == Platform::Windows {
                set("device", key("po0-clash"));
            }
            // TCP over the mixed stack times out on Windows, so it defaults to gVisor there.
            let default = if platform == Platform::Windows {
                TunStack::Gvisor
            } else {
                TunStack::Mixed
            };
            set("stack", stack(default));
            set("auto-route", Value::Bool(true));
            set("auto-detect-interface", Value::Bool(true));
            set("strict-route", Value::Bool(false));
            set("dns-hijack", hijack);
            if !options.tun_route_address.is_empty() {
                set(
                    "route-address",
                    strings(options.tun_route_address.iter().map(String::as_str)),
                );
            }
            set("route-exclude-address", strings([PO0_CIDR]));
        }
        (_, _, RouteMode::SystemProxy) => set("enable", Value::Bool(false)),
    }
    tun
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::options::{GeoxUrl, LogLevel};

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

    fn render_with(base: &str, target: (Platform, RouteMode, Option<i32>)) -> Value {
        render_options(base, target, &EngineOptions::default())
    }

    fn render_options(
        base: &str,
        (platform, route_mode, tun_fd): (Platform, RouteMode, Option<i32>),
        options: &EngineOptions,
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
                options,
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
            &links_base("./providers/x.txt", DELAY_URL),
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
                options: &EngineOptions::default(),
            },
        );
        assert!(result.is_err());
    }

    #[test]
    fn defaults_keep_the_engine_private() {
        let config = render_with(SUBSCRIPTION, params(Platform::MacOs, RouteMode::Tun, None));
        assert_eq!(config["bind-address"], key(LOOPBACK));
        assert_eq!(config["log-level"], key("warning"));
        assert_eq!(config["find-process-mode"], key("strict"));
        assert_eq!(config["tun"]["stack"], key("mixed"));
        assert!(config.get("authentication").is_none());
        assert_eq!(config["geox-url"]["mmdb"], key(&GeoxUrl::default().mmdb));
    }

    #[test]
    fn options_reach_the_config() {
        let mut options = EngineOptions {
            socks_port: 7891,
            http_port: 7892,
            allow_lan: true,
            authentication: vec!["me:pw".into()],
            log_level: LogLevel::Debug,
            ipv6: true,
            find_process_mode: FindProcessMode::Always,
            keep_alive_interval: 30,
            interface_name: "en0".into(),
            external_controller: true,
            tun_stack: Some(TunStack::System),
            tun_route_address: vec!["0.0.0.0/1".into()],
            added_rules: vec!["DOMAIN,example.com,DIRECT".into(), " ".into()],
            override_dns: true,
            append_system_dns: true,
            ..EngineOptions::default()
        };
        options
            .hosts
            .insert("router.lan".into(), "192.168.1.1".into());
        options
            .dns
            .nameserver_policy
            .insert("+.cn".into(), "223.5.5.5".into());
        let config = render_options(
            SUBSCRIPTION,
            params(Platform::MacOs, RouteMode::Tun, None),
            &options,
        );
        assert_eq!(config["socks-port"], Value::from(7891));
        assert_eq!(config["port"], Value::from(7892));
        assert_eq!(config["allow-lan"], Value::Bool(true));
        assert_eq!(config["bind-address"], key("*"));
        assert_eq!(config["authentication"][0], key("me:pw"));
        assert_eq!(config["skip-auth-prefixes"][0], key("127.0.0.1/8"));
        assert_eq!(config["log-level"], key("debug"));
        assert_eq!(config["ipv6"], Value::Bool(true));
        assert_eq!(config["find-process-mode"], key("always"));
        assert_eq!(config["keep-alive-interval"], Value::from(30));
        assert_eq!(config["interface-name"], key("en0"));
        assert_eq!(config["hosts"]["router.lan"], key("192.168.1.1"));
        assert_eq!(config["external-controller"], key("127.0.0.1:9090"));
        assert_eq!(config["tun"]["stack"], key("system"));
        assert_eq!(config["tun"]["route-address"][0], key("0.0.0.0/1"));
        assert_eq!(config["tun"]["route-exclude-address"][0], key(PO0_CIDR));
        assert_eq!(config["dns"]["enable"], Value::Bool(true));
        assert_eq!(config["dns"]["nameserver-policy"]["+.cn"], key("223.5.5.5"));
        let nameservers = config["dns"]["nameserver"].as_sequence().unwrap();
        assert_eq!(nameservers.last(), Some(&key(SYSTEM_DNS)));
        let rules = config["rules"].as_sequence().unwrap();
        assert_eq!(rules[0], key("IP-CIDR,124.221.69.228/32,DIRECT,no-resolve"));
        assert_eq!(rules[1], key("DOMAIN,example.com,DIRECT"));
        assert_eq!(rules[2], key("MATCH,DIRECT"));
    }

    #[test]
    fn android_never_looks_up_processes_and_windows_tun_uses_gvisor() {
        let options = EngineOptions {
            find_process_mode: FindProcessMode::Always,
            ..EngineOptions::default()
        };
        let android = render_options(
            "proxies: []\n",
            params(Platform::Android, RouteMode::SystemProxy, Some(3)),
            &options,
        );
        assert_eq!(android["find-process-mode"], key("off"));
        let windows = render_with(
            SUBSCRIPTION,
            params(Platform::Windows, RouteMode::Tun, None),
        );
        assert_eq!(windows["tun"]["stack"], key("gvisor"));
    }

    #[test]
    fn the_direct_route_names_the_listener() {
        assert_eq!(direct().route(), "PROXY u:p@127.0.0.1:4000");
    }
}
