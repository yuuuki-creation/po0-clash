use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Platform {
    MacOs,
    Windows,
    Android,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Mode {
    #[default]
    Rule,
    Global,
    Direct,
}

impl Mode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Rule => "rule",
            Self::Global => "global",
            Self::Direct => "direct",
        }
    }
}

/// Desktop only: exactly one of the two carries traffic (ADR 0011). Android always uses its VPN.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RouteMode {
    #[default]
    SystemProxy,
    Tun,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "state", content = "message")]
pub enum EngineState {
    #[default]
    Stopped,
    Starting,
    Running,
    /// The engine stopped on its own or never came up; it is not restarted automatically.
    Failed(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    pub engine: EngineState,
    pub mode: Mode,
    pub route_mode: RouteMode,
    pub profile_id: Option<String>,
    pub current_node: Option<String>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Traffic {
    pub up: u64,
    pub down: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ExitIp {
    pub ip: String,
    pub country: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProfileKind {
    Subscription,
    /// Share links pasted by the user, handed to mihomo as a file proxy-provider.
    Links,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Usage {
    pub upload: u64,
    pub download: u64,
    pub total: u64,
    /// Unix seconds; `None` when the subscription never expires.
    pub expire: Option<i64>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Profile {
    pub id: String,
    pub name: String,
    pub kind: ProfileKind,
    pub url: Option<String>,
    pub updated_at: Option<i64>,
    pub usage: Option<Usage>,
    pub selected: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ImportResult {
    pub profile: Profile,
    pub added: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProxyGroup {
    pub name: String,
    pub kind: String,
    pub selectable: bool,
    pub now: Option<String>,
    pub nodes: Vec<Node>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Node {
    pub name: String,
    pub kind: String,
    /// Milliseconds of the last test; `None` when untested, 0 when it timed out.
    pub delay: Option<u32>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum WhitelistKind {
    Po0,
    Ggy,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum WhitelistOutcome {
    Applied,
    NotApplied,
    Disabled,
    Rejected,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WhitelistResult {
    pub outcome: WhitelistOutcome,
    pub ip: Option<String>,
    pub message: Option<String>,
    pub at: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WhitelistEntry {
    pub id: String,
    pub kind: WhitelistKind,
    pub name: String,
    /// The first characters of the secret; the only part of it ever shown or logged.
    pub label: String,
    pub result: Option<WhitelistResult>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WhitelistState {
    pub enabled: bool,
    pub entries: Vec<WhitelistEntry>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Change {
    Status,
    Profiles,
    Groups,
    Whitelist,
}
