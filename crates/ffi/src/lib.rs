//! UniFFI surface of `po0-core` for the Swift and Kotlin apps. Only conversions live here.

use std::collections::HashMap;
use std::fmt;
use std::path::PathBuf;
use std::sync::Arc;

use po0_core as core;

uniffi::setup_scaffolding!();

/// Flat, so Kotlin's `CoreException.Invalid(message)` carries the Display text as
/// `Throwable.message` instead of a clashing field.
#[derive(Debug, uniffi::Error)]
#[uniffi(flat_error)]
pub enum CoreError {
    Invalid(String),
    Network(String),
    Engine(String),
    Io(String),
}

impl fmt::Display for CoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let (Self::Invalid(message)
        | Self::Network(message)
        | Self::Engine(message)
        | Self::Io(message)) = self;
        f.write_str(message)
    }
}

impl std::error::Error for CoreError {}

impl From<core::CoreError> for CoreError {
    fn from(error: core::CoreError) -> Self {
        match error {
            core::CoreError::Invalid(message) => Self::Invalid(message),
            core::CoreError::Network(message) => Self::Network(message),
            core::CoreError::Engine(message) => Self::Engine(message),
            core::CoreError::Io(message) => Self::Io(message),
        }
    }
}

type Result<T> = std::result::Result<T, CoreError>;

macro_rules! mirror_enum {
    ($name:ident { $($variant:ident),* $(,)? }) => {
        #[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
        pub enum $name { $($variant),* }

        impl From<core::$name> for $name {
            fn from(value: core::$name) -> Self {
                match value { $(core::$name::$variant => Self::$variant),* }
            }
        }

        impl From<$name> for core::$name {
            fn from(value: $name) -> Self {
                match value { $($name::$variant => Self::$variant),* }
            }
        }
    };
}

mirror_enum!(Platform {
    MacOs,
    Windows,
    Android
});
mirror_enum!(Mode {
    Rule,
    Global,
    Direct
});
mirror_enum!(RouteMode { SystemProxy, Tun });
mirror_enum!(ProfileKind {
    Subscription,
    Links,
    File
});
mirror_enum!(WhitelistKind { Po0, Ggy });
mirror_enum!(WhitelistOutcome {
    Applied,
    NotApplied,
    Disabled,
    Rejected,
    Error
});
mirror_enum!(Change {
    Status,
    Profiles,
    Groups,
    Whitelist
});

mirror_enum!(LogLevel {
    Debug,
    Info,
    Warning,
    Error,
    Silent
});
mirror_enum!(FindProcessMode {
    Off,
    Strict,
    Always
});
mirror_enum!(TunStack {
    System,
    Gvisor,
    Mixed
});
mirror_enum!(GeodataLoader {
    Standard,
    Memconservative
});
mirror_enum!(ProviderKind { Proxy, Rule });
mirror_enum!(DnsMode {
    Normal,
    FakeIp,
    RedirHost
});

macro_rules! mirror_record {
    ($name:ident { $($field:ident: $ty:ty),* $(,)? }) => {
        #[derive(Debug, Clone, uniffi::Record)]
        pub struct $name { $(pub $field: $ty),* }

        impl From<core::$name> for $name {
            fn from(value: core::$name) -> Self {
                Self { $($field: value.$field),* }
            }
        }

        impl From<$name> for core::$name {
            fn from(value: $name) -> Self {
                Self { $($field: value.$field),* }
            }
        }
    };
}

mirror_record!(Connection {
    id: String,
    network: String,
    inbound: String,
    host: String,
    destination: String,
    source: String,
    process: Option<String>,
    process_path: Option<String>,
    rule: String,
    rule_payload: String,
    chains: Vec<String>,
    upload: u64,
    download: u64,
    start: i64,
});

mirror_record!(Rule {
    kind: String,
    payload: String,
    proxy: String,
});

mirror_record!(GeoFile {
    name: String,
    size: Option<u64>,
    modified: Option<i64>,
});

mirror_record!(Traffic { up: u64, down: u64 });

mirror_record!(Usage {
    upload: u64,
    download: u64,
    total: u64,
    expire: Option<i64>,
});

fn convert<T: Into<U>, U>(items: Vec<T>) -> Vec<U> {
    items.into_iter().map(Into::into).collect()
}

mirror_record!(GeoxUrl {
    geoip: String,
    geosite: String,
    mmdb: String,
    asn: String,
});

mirror_record!(FallbackFilter {
    geoip: bool,
    geoip_code: String,
    geosite: Vec<String>,
    ipcidr: Vec<String>,
    domain: Vec<String>,
});

#[derive(Debug, Clone, uniffi::Record)]
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
    pub nameserver_policy: HashMap<String, String>,
    pub fallback_filter: FallbackFilter,
}

#[derive(Debug, Clone, uniffi::Record)]
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
    pub hosts: HashMap<String, String>,
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

impl From<core::DnsOptions> for DnsOptions {
    fn from(v: core::DnsOptions) -> Self {
        Self {
            enable: v.enable,
            listen: v.listen,
            prefer_h3: v.prefer_h3,
            use_hosts: v.use_hosts,
            use_system_hosts: v.use_system_hosts,
            respect_rules: v.respect_rules,
            ipv6: v.ipv6,
            enhanced_mode: v.enhanced_mode.into(),
            fake_ip_range: v.fake_ip_range,
            fake_ip_filter: v.fake_ip_filter,
            default_nameserver: v.default_nameserver,
            nameserver: v.nameserver,
            fallback: v.fallback,
            proxy_server_nameserver: v.proxy_server_nameserver,
            nameserver_policy: v.nameserver_policy.into_iter().collect(),
            fallback_filter: v.fallback_filter.into(),
        }
    }
}

impl From<DnsOptions> for core::DnsOptions {
    fn from(v: DnsOptions) -> Self {
        Self {
            enable: v.enable,
            listen: v.listen,
            prefer_h3: v.prefer_h3,
            use_hosts: v.use_hosts,
            use_system_hosts: v.use_system_hosts,
            respect_rules: v.respect_rules,
            ipv6: v.ipv6,
            enhanced_mode: v.enhanced_mode.into(),
            fake_ip_range: v.fake_ip_range,
            fake_ip_filter: v.fake_ip_filter,
            default_nameserver: v.default_nameserver,
            nameserver: v.nameserver,
            fallback: v.fallback,
            proxy_server_nameserver: v.proxy_server_nameserver,
            nameserver_policy: v.nameserver_policy.into_iter().collect(),
            fallback_filter: v.fallback_filter.into(),
        }
    }
}

impl From<core::EngineOptions> for EngineOptions {
    fn from(v: core::EngineOptions) -> Self {
        Self {
            mixed_port: v.mixed_port,
            socks_port: v.socks_port,
            http_port: v.http_port,
            allow_lan: v.allow_lan,
            authentication: v.authentication,
            log_level: v.log_level.into(),
            ipv6: v.ipv6,
            unified_delay: v.unified_delay,
            tcp_concurrent: v.tcp_concurrent,
            find_process_mode: v.find_process_mode.into(),
            keep_alive_interval: v.keep_alive_interval,
            interface_name: v.interface_name,
            test_url: v.test_url,
            user_agent: v.user_agent,
            hosts: v.hosts.into_iter().collect(),
            external_controller: v.external_controller,
            tun_stack: v.tun_stack.map(Into::into),
            tun_route_address: v.tun_route_address,
            tun_dns_hijack: v.tun_dns_hijack,
            geodata_loader: v.geodata_loader.into(),
            geo_auto_update: v.geo_auto_update,
            geo_update_interval: v.geo_update_interval,
            geox_url: v.geox_url.into(),
            override_dns: v.override_dns,
            dns: v.dns.into(),
            added_rules: v.added_rules,
        }
    }
}

impl From<EngineOptions> for core::EngineOptions {
    fn from(v: EngineOptions) -> Self {
        Self {
            mixed_port: v.mixed_port,
            socks_port: v.socks_port,
            http_port: v.http_port,
            allow_lan: v.allow_lan,
            authentication: v.authentication,
            log_level: v.log_level.into(),
            ipv6: v.ipv6,
            unified_delay: v.unified_delay,
            tcp_concurrent: v.tcp_concurrent,
            find_process_mode: v.find_process_mode.into(),
            keep_alive_interval: v.keep_alive_interval,
            interface_name: v.interface_name,
            test_url: v.test_url,
            user_agent: v.user_agent,
            hosts: v.hosts.into_iter().collect(),
            external_controller: v.external_controller,
            tun_stack: v.tun_stack.map(Into::into),
            tun_route_address: v.tun_route_address,
            tun_dns_hijack: v.tun_dns_hijack,
            geodata_loader: v.geodata_loader.into(),
            geo_auto_update: v.geo_auto_update,
            geo_update_interval: v.geo_update_interval,
            geox_url: v.geox_url.into(),
            override_dns: v.override_dns,
            dns: v.dns.into(),
            added_rules: v.added_rules,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Enum)]
pub enum EngineState {
    Stopped,
    Starting,
    Running,
    Failed { message: String },
}

impl From<core::EngineState> for EngineState {
    fn from(value: core::EngineState) -> Self {
        match value {
            core::EngineState::Stopped => Self::Stopped,
            core::EngineState::Starting => Self::Starting,
            core::EngineState::Running => Self::Running,
            core::EngineState::Failed(message) => Self::Failed { message },
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct CoreOptions {
    pub data_dir: String,
    pub platform: Platform,
    pub mihomo_path: Option<String>,
    pub legacy_prefs: Option<String>,
    pub legacy_database: Option<String>,
    pub app_version: String,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct Status {
    pub engine: EngineState,
    pub mode: Mode,
    pub route_mode: RouteMode,
    pub profile_id: Option<String>,
    pub current_node: Option<String>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct Connections {
    pub upload_total: u64,
    pub download_total: u64,
    pub items: Vec<Connection>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct LogEntry {
    pub level: LogLevel,
    pub message: String,
    pub at: i64,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct Provider {
    pub name: String,
    pub kind: ProviderKind,
    pub vehicle: String,
    pub behavior: Option<String>,
    pub count: u32,
    pub updated_at: Option<i64>,
    pub usage: Option<Usage>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct ExitIp {
    pub ip: String,
    pub country: Option<String>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct Profile {
    pub id: String,
    pub name: String,
    pub kind: ProfileKind,
    pub url: Option<String>,
    pub updated_at: Option<i64>,
    pub usage: Option<Usage>,
    pub selected: bool,
    pub auto_update: bool,
    pub update_hours: u32,
}

mirror_record!(ProfileEdit {
    name: String,
    url: Option<String>,
    auto_update: bool,
    update_hours: u32,
});

#[derive(Debug, Clone, uniffi::Record)]
pub struct ImportResult {
    pub profile: Profile,
    pub added: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct Node {
    pub name: String,
    pub kind: String,
    pub delay: Option<u32>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct ProxyGroup {
    pub name: String,
    pub kind: String,
    pub selectable: bool,
    pub now: Option<String>,
    pub nodes: Vec<Node>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct WhitelistResult {
    pub outcome: WhitelistOutcome,
    pub ip: Option<String>,
    pub message: Option<String>,
    pub at: i64,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct WhitelistEntry {
    pub id: String,
    pub kind: WhitelistKind,
    pub name: String,
    pub label: String,
    pub result: Option<WhitelistResult>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct WhitelistState {
    pub enabled: bool,
    pub entries: Vec<WhitelistEntry>,
}

impl From<core::Status> for Status {
    fn from(value: core::Status) -> Self {
        Self {
            engine: value.engine.into(),
            mode: value.mode.into(),
            route_mode: value.route_mode.into(),
            profile_id: value.profile_id,
            current_node: value.current_node,
        }
    }
}

impl From<core::Profile> for Profile {
    fn from(value: core::Profile) -> Self {
        Self {
            id: value.id,
            name: value.name,
            kind: value.kind.into(),
            url: value.url,
            updated_at: value.updated_at,
            usage: value.usage.map(Into::into),
            selected: value.selected,
            auto_update: value.auto_update,
            update_hours: value.update_hours,
        }
    }
}

impl From<core::ProxyGroup> for ProxyGroup {
    fn from(value: core::ProxyGroup) -> Self {
        Self {
            name: value.name,
            kind: value.kind,
            selectable: value.selectable,
            now: value.now,
            nodes: value
                .nodes
                .into_iter()
                .map(|node| Node {
                    name: node.name,
                    kind: node.kind,
                    delay: node.delay,
                })
                .collect(),
        }
    }
}

impl From<core::WhitelistEntry> for WhitelistEntry {
    fn from(value: core::WhitelistEntry) -> Self {
        Self {
            id: value.id,
            kind: value.kind.into(),
            name: value.name,
            label: value.label,
            result: value.result.map(|result| WhitelistResult {
                outcome: result.outcome.into(),
                ip: result.ip,
                message: result.message,
                at: result.at,
            }),
        }
    }
}

#[uniffi::export(callback_interface)]
pub trait CoreListener: Send + Sync {
    fn on_change(&self, change: Change);
}

struct ListenerAdapter(Box<dyn CoreListener>);

impl core::Listener for ListenerAdapter {
    fn on_change(&self, change: core::Change) {
        self.0.on_change(change.into());
    }
}

#[derive(uniffi::Object)]
pub struct Po0Core {
    inner: Arc<core::Core>,
}

#[uniffi::export]
impl Po0Core {
    #[uniffi::constructor]
    pub fn new(options: CoreOptions) -> Result<Arc<Self>> {
        let inner = core::Core::new(core::CoreOptions {
            data_dir: PathBuf::from(options.data_dir),
            platform: options.platform.into(),
            mihomo_path: options.mihomo_path.map(PathBuf::from),
            legacy_prefs: options.legacy_prefs.map(PathBuf::from),
            legacy_database: options.legacy_database.map(PathBuf::from),
            app_version: options.app_version,
        })?;
        Ok(Arc::new(Self { inner }))
    }

    pub fn set_listener(&self, listener: Box<dyn CoreListener>) {
        self.inner.set_listener(Arc::new(ListenerAdapter(listener)));
    }

    pub fn set_mihomo_path(&self, path: String) {
        self.inner.set_mihomo_path(PathBuf::from(path));
    }

    pub fn status(&self) -> Status {
        self.inner.status().into()
    }

    pub fn start(&self, tun_fd: Option<i32>) -> Result<()> {
        Ok(self.inner.start(tun_fd)?)
    }

    pub fn engine_options(&self) -> EngineOptions {
        self.inner.engine_options().into()
    }

    pub fn set_engine_options(&self, options: EngineOptions) -> Result<()> {
        Ok(self.inner.set_engine_options(options.into())?)
    }

    pub fn stop(&self) {
        self.inner.stop();
    }

    pub fn was_connected(&self) -> bool {
        self.inner.was_connected()
    }

    pub fn traffic(&self) -> Traffic {
        self.inner.traffic().into()
    }

    pub fn traffic_history(&self) -> Vec<Traffic> {
        convert(self.inner.traffic_history())
    }

    pub fn memory(&self) -> u64 {
        self.inner.memory()
    }

    pub fn connections(&self) -> Connections {
        let connections = self.inner.connections();
        Connections {
            upload_total: connections.upload_total,
            download_total: connections.download_total,
            items: convert(connections.items),
        }
    }

    pub fn close_connection(&self, id: String) -> Result<()> {
        Ok(self.inner.close_connection(id)?)
    }

    pub fn close_all_connections(&self) -> Result<()> {
        Ok(self.inner.close_all_connections()?)
    }

    pub fn requests(&self) -> Vec<Connection> {
        convert(self.inner.requests())
    }

    pub fn clear_requests(&self) {
        self.inner.clear_requests();
    }

    pub fn logs(&self) -> Vec<LogEntry> {
        self.inner
            .logs()
            .into_iter()
            .map(|entry| LogEntry {
                level: entry.level.into(),
                message: entry.message,
                at: entry.at,
            })
            .collect()
    }

    pub fn clear_logs(&self) {
        self.inner.clear_logs();
    }

    pub fn flush_dns_cache(&self) -> Result<()> {
        Ok(self.inner.flush_dns_cache()?)
    }

    pub fn providers(&self) -> Result<Vec<Provider>> {
        Ok(self
            .inner
            .providers()?
            .into_iter()
            .map(|provider| Provider {
                name: provider.name,
                kind: provider.kind.into(),
                vehicle: provider.vehicle,
                behavior: provider.behavior,
                count: provider.count,
                updated_at: provider.updated_at,
                usage: provider.usage.map(Into::into),
            })
            .collect())
    }

    pub fn update_provider(&self, kind: ProviderKind, name: String) -> Result<()> {
        Ok(self.inner.update_provider(kind.into(), name)?)
    }

    pub fn rules(&self) -> Result<Vec<Rule>> {
        Ok(convert(self.inner.rules()?))
    }

    pub fn geo_files(&self) -> Vec<GeoFile> {
        convert(self.inner.geo_files())
    }

    pub fn update_geo(&self) -> Result<()> {
        Ok(self.inner.update_geo()?)
    }

    pub fn exit_ip(&self) -> Result<ExitIp> {
        let exit = self.inner.exit_ip()?;
        Ok(ExitIp {
            ip: exit.ip,
            country: exit.country,
        })
    }

    pub fn set_mode(&self, mode: Mode) -> Result<()> {
        Ok(self.inner.set_mode(mode.into())?)
    }

    pub fn set_route_mode(&self, route_mode: RouteMode) -> Result<()> {
        Ok(self.inner.set_route_mode(route_mode.into())?)
    }

    pub fn profiles(&self) -> Vec<Profile> {
        self.inner.profiles().into_iter().map(Into::into).collect()
    }

    pub fn add_subscription(&self, url: String) -> Result<Profile> {
        Ok(self.inner.add_subscription(url)?.into())
    }

    pub fn update_profile(&self, id: String) -> Result<Profile> {
        Ok(self.inner.update_profile(id)?.into())
    }

    pub fn remove_profile(&self, id: String) -> Result<()> {
        Ok(self.inner.remove_profile(id)?)
    }

    pub fn select_profile(&self, id: String) -> Result<()> {
        Ok(self.inner.select_profile(id)?)
    }

    pub fn import_file(&self, name: String, content: String) -> Result<Profile> {
        Ok(self.inner.import_file(name, content)?.into())
    }

    pub fn edit_profile(&self, id: String, edit: ProfileEdit) -> Result<Profile> {
        Ok(self.inner.edit_profile(id, edit.into())?.into())
    }

    pub fn profile_content(&self, id: String) -> Result<String> {
        Ok(self.inner.profile_content(id)?)
    }

    pub fn preview_config(&self, id: String) -> Result<String> {
        Ok(self.inner.preview_config(id)?)
    }

    pub fn reorder_profiles(&self, ids: Vec<String>) -> Result<()> {
        Ok(self.inner.reorder_profiles(ids)?)
    }

    pub fn import_links(&self, text: String) -> Result<ImportResult> {
        let result = self.inner.import_links(text)?;
        Ok(ImportResult {
            profile: result.profile.into(),
            added: result.added,
        })
    }

    pub fn groups(&self) -> Result<Vec<ProxyGroup>> {
        Ok(self.inner.groups()?.into_iter().map(Into::into).collect())
    }

    pub fn select_node(&self, group: String, node: String) -> Result<()> {
        Ok(self.inner.select_node(group, node)?)
    }

    pub fn test_delay(&self, group: String) -> Result<ProxyGroup> {
        Ok(self.inner.test_delay(group)?.into())
    }

    pub fn test_node_delay(&self, node: String) -> Result<u32> {
        Ok(self.inner.test_node_delay(node)?)
    }

    pub fn whitelist(&self) -> WhitelistState {
        let state = self.inner.whitelist();
        WhitelistState {
            enabled: state.enabled,
            entries: state.entries.into_iter().map(Into::into).collect(),
        }
    }

    pub fn set_whitelist_enabled(&self, enabled: bool) -> Result<()> {
        Ok(self.inner.set_whitelist_enabled(enabled)?)
    }

    pub fn add_whitelist_entries(&self, text: String, name: String) -> Result<Vec<WhitelistEntry>> {
        Ok(self
            .inner
            .add_whitelist_entries(text, name)?
            .into_iter()
            .map(Into::into)
            .collect())
    }

    pub fn remove_whitelist_entry(&self, id: String) -> Result<()> {
        Ok(self.inner.remove_whitelist_entry(id)?)
    }

    pub fn whitelist_now(&self) {
        self.inner.whitelist_now();
    }

    pub fn network_changed(&self) {
        self.inner.network_changed();
    }

    pub fn set_active(&self, active: bool) {
        self.inner.set_active(active);
    }

    pub fn export_diagnostics(&self, path: String) -> Result<()> {
        Ok(self.inner.export_diagnostics(PathBuf::from(path))?)
    }

    pub fn shutdown(&self) {
        self.inner.shutdown();
    }
}
