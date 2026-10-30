use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use crate::config::DELAY_URL;

pub const DEFAULT_MIXED_PORT: u16 = 7894;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LogLevel {
    Debug,
    Info,
    #[default]
    Warning,
    Error,
    Silent,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FindProcessMode {
    Off,
    #[default]
    Strict,
    Always,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TunStack {
    System,
    Gvisor,
    Mixed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum GeodataLoader {
    Standard,
    #[default]
    Memconservative,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DnsMode {
    Normal,
    #[default]
    FakeIp,
    RedirHost,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct GeoxUrl {
    pub geoip: String,
    pub geosite: String,
    pub mmdb: String,
    pub asn: String,
}

impl Default for GeoxUrl {
    fn default() -> Self {
        let base = "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release";
        Self {
            geoip: format!("{base}/geoip.dat"),
            geosite: format!("{base}/geosite.dat"),
            mmdb: format!("{base}/country.mmdb"),
            asn: format!("{base}/GeoLite2-ASN.mmdb"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct FallbackFilter {
    pub geoip: bool,
    pub geoip_code: String,
    pub geosite: Vec<String>,
    pub ipcidr: Vec<String>,
    pub domain: Vec<String>,
}

impl Default for FallbackFilter {
    fn default() -> Self {
        Self {
            geoip: true,
            geoip_code: "CN".into(),
            geosite: Vec::new(),
            ipcidr: vec!["240.0.0.0/4".into()],
            domain: strings(&["+.google.com", "+.facebook.com", "+.youtube.com"]),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct DnsOptions {
    pub enable: bool,
    pub listen: String,
    pub prefer_h3: bool,
    pub use_hosts: bool,
    pub use_system_hosts: bool,
    pub respect_rules: bool,
    pub ipv6: bool,
    pub enhanced_mode: DnsMode,
    pub fake_ip_range: String,
    pub fake_ip_filter: Vec<String>,
    pub default_nameserver: Vec<String>,
    pub nameserver: Vec<String>,
    pub fallback: Vec<String>,
    pub proxy_server_nameserver: Vec<String>,
    pub nameserver_policy: BTreeMap<String, String>,
    pub fallback_filter: FallbackFilter,
}

impl Default for DnsOptions {
    fn default() -> Self {
        Self {
            enable: true,
            listen: String::new(),
            prefer_h3: false,
            use_hosts: true,
            use_system_hosts: true,
            respect_rules: false,
            ipv6: false,
            enhanced_mode: DnsMode::FakeIp,
            fake_ip_range: "198.18.0.1/16".into(),
            fake_ip_filter: strings(&[
                "*.lan",
                "*.local",
                "localhost",
                "+.msftconnecttest.com",
                "+.msftncsi.com",
                "time.*.com",
                "ntp.*.com",
            ]),
            default_nameserver: strings(&["223.5.5.5", "119.29.29.29"]),
            nameserver: strings(&[
                "https://dns.alidns.com/dns-query",
                "https://doh.pub/dns-query",
            ]),
            fallback: Vec::new(),
            proxy_server_nameserver: strings(&["https://doh.pub/dns-query"]),
            nameserver_policy: BTreeMap::new(),
            fallback_filter: FallbackFilter::default(),
        }
    }
}

/// Everything FlClash lets people change about the engine. Defaults keep the behaviour the native apps had before
/// these options existed.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct EngineOptions {
    pub mixed_port: u16,
    pub socks_port: u16,
    pub http_port: u16,
    pub allow_lan: bool,
    pub authentication: Vec<String>,
    pub log_level: LogLevel,
    pub ipv6: bool,
    pub unified_delay: bool,
    pub tcp_concurrent: bool,
    pub find_process_mode: FindProcessMode,
    pub keep_alive_interval: u32,
    pub interface_name: String,
    pub test_url: String,
    pub user_agent: String,
    pub hosts: BTreeMap<String, String>,
    pub external_controller: bool,
    pub tun_stack: Option<TunStack>,
    pub tun_route_address: Vec<String>,
    pub tun_dns_hijack: Vec<String>,
    pub geodata_loader: GeodataLoader,
    pub geo_auto_update: bool,
    pub geo_update_interval: u32,
    pub geox_url: GeoxUrl,
    pub override_dns: bool,
    pub dns: DnsOptions,
    pub added_rules: Vec<String>,
}

impl Default for EngineOptions {
    fn default() -> Self {
        Self {
            mixed_port: DEFAULT_MIXED_PORT,
            socks_port: 0,
            http_port: 0,
            allow_lan: false,
            authentication: Vec::new(),
            log_level: LogLevel::Warning,
            ipv6: false,
            unified_delay: true,
            tcp_concurrent: true,
            find_process_mode: FindProcessMode::Strict,
            keep_alive_interval: 0,
            interface_name: String::new(),
            test_url: DELAY_URL.into(),
            user_agent: String::new(),
            hosts: BTreeMap::new(),
            external_controller: false,
            tun_stack: None,
            tun_route_address: Vec::new(),
            tun_dns_hijack: strings(&["any:53"]),
            geodata_loader: GeodataLoader::Memconservative,
            geo_auto_update: false,
            geo_update_interval: 24,
            geox_url: GeoxUrl::default(),
            override_dns: false,
            dns: DnsOptions::default(),
            added_rules: Vec::new(),
        }
    }
}

impl EngineOptions {
    pub fn delay_url(&self) -> &str {
        if self.test_url.trim().is_empty() {
            DELAY_URL
        } else {
            self.test_url.trim()
        }
    }
}

fn strings(items: &[&str]) -> Vec<String> {
    items.iter().map(|item| (*item).to_owned()).collect()
}
