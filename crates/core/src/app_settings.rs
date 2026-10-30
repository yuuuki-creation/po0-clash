use serde::{Deserialize, Deserializer, Serialize};

use crate::error::{CoreError, Result};

pub const DEFAULT_THEME_COLOR: u32 = 0xFF00_7AFF;

/// The Flutter app's presets, system blue first.
pub const THEME_COLOR_PRESETS: [u32; 8] = [
    DEFAULT_THEME_COLOR,
    0xFF58_56D6,
    0xFFAF_52DE,
    0xFFFF_2D55,
    0xFFFF_9500,
    0xFF34_C759,
    0xFF30_B0C7,
    0xFF8E_8E93,
];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ThemeMode {
    #[default]
    System,
    Light,
    Dark,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SchemeVariant {
    TonalSpot,
    #[default]
    Fidelity,
    Monochrome,
    Neutral,
    Vibrant,
    Expressive,
    Content,
    Rainbow,
    FruitSalad,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProxiesLayout {
    #[default]
    Tabs,
    List,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProxiesSort {
    #[default]
    Profile,
    Delay,
    Name,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProxiesDensity {
    Loose,
    #[default]
    Standard,
    Tight,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProxyTileStyle {
    #[default]
    Detailed,
    Compact,
    Minimal,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum GroupIconStyle {
    #[default]
    Standard,
    IconOnly,
    Hidden,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DashboardCard {
    CurrentNode,
    Speed,
    Mode,
    Takeover,
    Whitelist,
    Traffic,
    Connections,
    Memory,
    IntranetIp,
    Subscription,
    ExitIp,
}

impl DashboardCard {
    pub const ALL: [Self; 11] = [
        Self::CurrentNode,
        Self::Speed,
        Self::Mode,
        Self::Takeover,
        Self::Whitelist,
        Self::Traffic,
        Self::Connections,
        Self::Memory,
        Self::IntranetIp,
        Self::Subscription,
        Self::ExitIp,
    ];
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum HotkeyAction {
    Connect,
    ShowWindow,
    Mode,
    SystemProxy,
    Tun,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum HotkeyModifier {
    Control,
    Alt,
    Shift,
    Meta,
}

/// `key` is a W3C `KeyboardEvent.code` such as `KeyP` or `F5`, so every platform names keys the same way.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Hotkey {
    pub action: HotkeyAction,
    pub key: String,
    #[serde(default)]
    pub modifiers: Vec<HotkeyModifier>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WebDav {
    pub url: String,
    pub user: String,
    pub password: String,
    pub file_name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RestoreStrategy {
    #[default]
    Compatible,
    Override,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AccessControlMode {
    #[default]
    RejectSelected,
    AcceptSelected,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum AppSort {
    #[default]
    Unsorted,
    Name,
    InstallTime,
}

/// Android's per-app proxy; each mode keeps its own list, as in the Flutter app.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct AccessControl {
    pub enabled: bool,
    pub mode: AccessControlMode,
    pub accepted: Vec<String>,
    pub rejected: Vec<String>,
    pub sort: AppSort,
    pub hide_system_apps: bool,
    pub hide_offline_apps: bool,
}

impl Default for AccessControl {
    fn default() -> Self {
        Self {
            enabled: false,
            mode: AccessControlMode::RejectSelected,
            accepted: Vec::new(),
            rejected: Vec::new(),
            sort: AppSort::Unsorted,
            hide_system_apps: true,
            hide_offline_apps: true,
        }
    }
}

/// Everything else FlClash keeps about the app rather than the engine, so a backup carries it and every platform
/// starts from the same defaults.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct AppSettings {
    pub language: Option<String>,
    pub theme_mode: ThemeMode,
    pub theme_color: u32,
    pub theme_colors: Vec<u32>,
    pub scheme_variant: SchemeVariant,
    pub pure_black: bool,
    pub text_scale: Option<u16>,
    pub launch_at_login: bool,
    pub silent_launch: bool,
    pub auto_connect: bool,
    pub minimize_on_close: bool,
    pub hide_from_recents: bool,
    pub page_animation: bool,
    pub show_nav_labels: bool,
    pub capture_logs: bool,
    pub close_connections_on_switch: bool,
    pub only_proxy_traffic: bool,
    pub notification_stop_button: bool,
    pub auto_check_update: bool,
    pub check_certificate: bool,
    pub tray_speed: bool,
    pub crash_reports: bool,
    pub crash_reports_asked: bool,
    pub disclaimer_accepted: bool,
    pub developer_mode: bool,
    pub proxies_layout: ProxiesLayout,
    pub proxies_sort: ProxiesSort,
    pub proxies_density: ProxiesDensity,
    pub proxy_tile_style: ProxyTileStyle,
    pub group_icon_style: GroupIconStyle,
    pub dashboard_cards: Vec<DashboardCard>,
    pub hotkeys: Vec<Hotkey>,
    pub webdav: Option<WebDav>,
    pub restore_strategy: RestoreStrategy,
    pub access_control: AccessControl,
    pub excluded_ssids: Vec<String>,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            language: None,
            theme_mode: ThemeMode::System,
            theme_color: DEFAULT_THEME_COLOR,
            theme_colors: THEME_COLOR_PRESETS.to_vec(),
            scheme_variant: SchemeVariant::Fidelity,
            pure_black: false,
            text_scale: None,
            launch_at_login: false,
            silent_launch: false,
            auto_connect: false,
            minimize_on_close: true,
            hide_from_recents: false,
            page_animation: true,
            show_nav_labels: true,
            capture_logs: false,
            close_connections_on_switch: true,
            only_proxy_traffic: false,
            notification_stop_button: true,
            auto_check_update: true,
            check_certificate: true,
            tray_speed: true,
            crash_reports: false,
            crash_reports_asked: false,
            disclaimer_accepted: false,
            developer_mode: false,
            proxies_layout: ProxiesLayout::Tabs,
            proxies_sort: ProxiesSort::Profile,
            proxies_density: ProxiesDensity::Standard,
            proxy_tile_style: ProxyTileStyle::Detailed,
            group_icon_style: GroupIconStyle::Standard,
            dashboard_cards: DashboardCard::ALL.to_vec(),
            hotkeys: Vec::new(),
            webdav: None,
            restore_strategy: RestoreStrategy::Compatible,
            access_control: AccessControl::default(),
            excluded_ssids: Vec::new(),
        }
    }
}

impl AppSettings {
    /// Duplicates collapse, the chosen colour stays in the list, and two actions may not share a shortcut.
    pub fn validated(mut self) -> Result<Self> {
        dedup(&mut self.theme_colors);
        if !self.theme_colors.contains(&self.theme_color) {
            self.theme_colors.push(self.theme_color);
        }
        self.text_scale = self.text_scale.map(|percent| percent.clamp(50, 200));
        dedup(&mut self.dashboard_cards);
        dedup(&mut self.access_control.accepted);
        dedup(&mut self.access_control.rejected);
        self.excluded_ssids.retain(|ssid| !ssid.trim().is_empty());
        dedup(&mut self.excluded_ssids);
        for hotkey in &mut self.hotkeys {
            hotkey.modifiers.sort();
            hotkey.modifiers.dedup();
        }
        for (index, hotkey) in self.hotkeys.iter().enumerate() {
            if hotkey.key.trim().is_empty() {
                return Err(CoreError::Invalid("a shortcut needs a key".into()));
            }
            let clash = self.hotkeys[..index]
                .iter()
                .any(|other| other.key == hotkey.key && other.modifiers == hotkey.modifiers);
            if clash {
                return Err(CoreError::Invalid(format!(
                    "the shortcut for {:?} is already in use",
                    hotkey.action
                )));
            }
        }
        if let Some(dav) = &self.webdav {
            let url = dav.url.trim();
            if !(url.starts_with("https://") || url.starts_with("http://")) {
                return Err(CoreError::Invalid("WebDAV needs an http(s) address".into()));
            }
        }
        Ok(self)
    }
}

fn dedup<T: PartialEq>(items: &mut Vec<T>) {
    let mut seen: Vec<T> = Vec::with_capacity(items.len());
    for item in items.drain(..) {
        if !seen.contains(&item) {
            seen.push(item);
        }
    }
    *items = seen;
}

/// A settings file written by a newer version may hold values this one does not know; they fall back to the
/// defaults instead of failing the whole file and losing the profiles with it.
pub(crate) fn lenient<'de, D: Deserializer<'de>>(
    deserializer: D,
) -> std::result::Result<AppSettings, D::Error> {
    let value = serde_json::Value::deserialize(deserializer)?;
    Ok(AppSettings::deserialize(value).unwrap_or_default())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_fields_take_the_flutter_defaults() {
        let settings: AppSettings = serde_json::from_str(r#"{"pureBlack":true}"#).unwrap();
        assert!(settings.pure_black);
        assert_eq!(settings.theme_color, DEFAULT_THEME_COLOR);
        assert_eq!(settings.proxies_layout, ProxiesLayout::Tabs);
        assert!(settings.close_connections_on_switch && settings.check_certificate);
        assert_eq!(settings.dashboard_cards.len(), DashboardCard::ALL.len());
    }

    #[test]
    fn unknown_values_do_not_lose_the_rest_of_the_file() {
        #[derive(Deserialize)]
        struct File {
            #[serde(deserialize_with = "lenient")]
            app: AppSettings,
            kept: u32,
        }
        let file: File = serde_json::from_str(r#"{"app":{"themeMode":"sepia"},"kept":7}"#).unwrap();
        assert_eq!(file.app, AppSettings::default());
        assert_eq!(file.kept, 7);
    }

    #[test]
    fn validation_tidies_lists_and_refuses_clashing_shortcuts() {
        let shortcut = |action, modifiers: Vec<HotkeyModifier>| Hotkey {
            action,
            key: "KeyP".into(),
            modifiers,
        };
        let settings = AppSettings {
            theme_color: 0xFF12_3456,
            text_scale: Some(400),
            dashboard_cards: vec![DashboardCard::Speed, DashboardCard::Speed],
            excluded_ssids: vec!["home".into(), " ".into(), "home".into()],
            hotkeys: vec![
                shortcut(
                    HotkeyAction::Connect,
                    vec![HotkeyModifier::Shift, HotkeyModifier::Meta],
                ),
                shortcut(HotkeyAction::Tun, vec![HotkeyModifier::Meta]),
            ],
            ..AppSettings::default()
        }
        .validated()
        .unwrap();
        assert_eq!(settings.theme_colors.last(), Some(&0xFF12_3456));
        assert_eq!(settings.text_scale, Some(200));
        assert_eq!(settings.dashboard_cards, [DashboardCard::Speed]);
        assert_eq!(settings.excluded_ssids, ["home"]);
        assert_eq!(
            settings.hotkeys[0].modifiers,
            [HotkeyModifier::Shift, HotkeyModifier::Meta]
        );

        let clashing = AppSettings {
            hotkeys: vec![
                shortcut(
                    HotkeyAction::Connect,
                    vec![HotkeyModifier::Meta, HotkeyModifier::Shift],
                ),
                shortcut(
                    HotkeyAction::Tun,
                    vec![HotkeyModifier::Shift, HotkeyModifier::Meta],
                ),
            ],
            ..AppSettings::default()
        };
        assert!(clashing.validated().is_err());
    }
}
