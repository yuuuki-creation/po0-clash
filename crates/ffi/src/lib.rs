//! UniFFI surface of `po0-core` for the Swift and Kotlin apps. Only conversions live here.

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
    Links
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
pub struct Traffic {
    pub up: u64,
    pub down: u64,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct ExitIp {
    pub ip: String,
    pub country: Option<String>,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct Usage {
    pub upload: u64,
    pub download: u64,
    pub total: u64,
    pub expire: Option<i64>,
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
}

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
            usage: value.usage.map(|usage| Usage {
                upload: usage.upload,
                download: usage.download,
                total: usage.total,
                expire: usage.expire,
            }),
            selected: value.selected,
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

    pub fn stop(&self) {
        self.inner.stop();
    }

    pub fn traffic(&self) -> Traffic {
        let traffic = self.inner.traffic();
        Traffic {
            up: traffic.up,
            down: traffic.down,
        }
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
