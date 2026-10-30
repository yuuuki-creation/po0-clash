use std::sync::Arc;

use serde::Serialize;
use tauri::{AppHandle, Manager, State};
use tauri_plugin_dialog::DialogExt;

use super::po0::{
    AppSettings, Connection, Connections, Core, CoreError, EngineOptions, ExitIp, GeoFile,
    ImportResult, IntranetIp, LogEntry, Mode, Profile, ProfileEdit, ProfileOverride, Provider,
    ProviderKind, ProxyGroup, RestoreScope, RouteMode, Rule, Script, Status, Traffic, WebDav,
    WhitelistState,
};
use super::{Backdrop, Launch, LaunchNotice, autostart, language, loopback};

type CoreState<'a> = State<'a, Arc<Core>>;
type Reply<T> = Result<T, String>;

async fn blocking<T, F>(core: &Arc<Core>, f: F) -> Reply<T>
where
    T: Send + 'static,
    F: FnOnce(&Core) -> Result<T, CoreError> + Send + 'static,
{
    let core = Arc::clone(core);
    tauri::async_runtime::spawn_blocking(move || f(&core))
        .await
        .map_err(|e| e.to_string())?
        .map_err(|e| e.to_string())
}

#[derive(Serialize)]
pub struct AppInfo {
    version: String,
    language: &'static str,
    backdrop: bool,
}

#[tauri::command]
pub fn app_info(app: AppHandle, core: CoreState<'_>, backdrop: State<'_, Backdrop>) -> AppInfo {
    AppInfo {
        version: app.package_info().version.to_string(),
        language: language(&core),
        backdrop: backdrop.0,
    }
}

#[tauri::command]
pub async fn status(core: CoreState<'_>) -> Reply<Status> {
    blocking(&core, |c| Ok(c.status())).await
}

#[tauri::command]
pub async fn start(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| c.start(None)).await
}

#[tauri::command]
pub async fn stop(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| {
        c.stop();
        Ok(())
    })
    .await
}

#[tauri::command]
pub async fn traffic(core: CoreState<'_>) -> Reply<Traffic> {
    blocking(&core, |c| Ok(c.traffic())).await
}

#[tauri::command]
pub async fn traffic_history(core: CoreState<'_>) -> Reply<Vec<Traffic>> {
    blocking(&core, |c| Ok(c.traffic_history())).await
}

#[tauri::command]
pub async fn memory(core: CoreState<'_>) -> Reply<u64> {
    blocking(&core, |c| Ok(c.memory())).await
}

#[tauri::command]
pub async fn connections(core: CoreState<'_>) -> Reply<Connections> {
    blocking(&core, |c| Ok(c.connections())).await
}

#[tauri::command]
pub async fn close_connection(core: CoreState<'_>, id: String) -> Reply<()> {
    blocking(&core, move |c| c.close_connection(id)).await
}

#[tauri::command]
pub async fn close_all_connections(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| c.close_all_connections()).await
}

#[tauri::command]
pub async fn requests(core: CoreState<'_>) -> Reply<Vec<Connection>> {
    blocking(&core, |c| Ok(c.requests())).await
}

#[tauri::command]
pub async fn clear_requests(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| {
        c.clear_requests();
        Ok(())
    })
    .await
}

#[tauri::command]
pub async fn logs(core: CoreState<'_>) -> Reply<Vec<LogEntry>> {
    blocking(&core, |c| Ok(c.logs())).await
}

#[tauri::command]
pub async fn clear_logs(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| {
        c.clear_logs();
        Ok(())
    })
    .await
}

#[tauri::command]
pub async fn exit_ip(core: CoreState<'_>) -> Reply<ExitIp> {
    blocking(&core, |c| c.exit_ip()).await
}

#[tauri::command]
pub async fn set_mode(core: CoreState<'_>, mode: Mode) -> Reply<()> {
    blocking(&core, move |c| c.set_mode(mode)).await
}

#[tauri::command]
pub async fn set_route_mode(core: CoreState<'_>, route_mode: RouteMode) -> Reply<()> {
    blocking(&core, move |c| c.set_route_mode(route_mode)).await
}

#[tauri::command]
pub async fn profiles(core: CoreState<'_>) -> Reply<Vec<Profile>> {
    blocking(&core, |c| Ok(c.profiles())).await
}

#[tauri::command]
pub async fn add_subscription(core: CoreState<'_>, url: String) -> Reply<Profile> {
    blocking(&core, move |c| c.add_subscription(url.trim().to_string())).await
}

#[tauri::command]
pub async fn update_profile(core: CoreState<'_>, id: String) -> Reply<Profile> {
    blocking(&core, move |c| c.update_profile(id)).await
}

#[tauri::command]
pub async fn remove_profile(core: CoreState<'_>, id: String) -> Reply<()> {
    blocking(&core, move |c| c.remove_profile(id)).await
}

#[tauri::command]
pub async fn select_profile(core: CoreState<'_>, id: String) -> Reply<()> {
    blocking(&core, move |c| c.select_profile(id)).await
}

#[tauri::command]
pub async fn import_file(core: CoreState<'_>, name: String, content: String) -> Reply<Profile> {
    blocking(&core, move |c| c.import_file(name, content)).await
}

#[tauri::command]
pub async fn edit_profile(core: CoreState<'_>, id: String, edit: ProfileEdit) -> Reply<Profile> {
    blocking(&core, move |c| c.edit_profile(id, edit)).await
}

#[tauri::command]
pub async fn preview_config(core: CoreState<'_>, id: String) -> Reply<String> {
    blocking(&core, move |c| c.preview_config(id)).await
}

#[tauri::command]
pub async fn reorder_profiles(core: CoreState<'_>, ids: Vec<String>) -> Reply<()> {
    blocking(&core, move |c| c.reorder_profiles(ids)).await
}

#[tauri::command]
pub async fn export_profile(
    app: AppHandle,
    core: CoreState<'_>,
    id: String,
    name: String,
) -> Reply<Option<String>> {
    let core = Arc::clone(&core);
    tauri::async_runtime::spawn_blocking(move || {
        let content = core.profile_content(id).map_err(|e| e.to_string())?;
        let Some(path) = save_dialog(
            &app,
            &format!("{name}.yaml"),
            "YAML",
            &["yaml", "yml", "txt"],
        ) else {
            return Ok(None);
        };
        std::fs::write(&path, content).map_err(|e| e.to_string())?;
        Ok(Some(path.display().to_string()))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn import_links(core: CoreState<'_>, text: String) -> Reply<ImportResult> {
    blocking(&core, move |c| c.import_links(text)).await
}

#[tauri::command]
pub async fn groups(core: CoreState<'_>) -> Reply<Vec<ProxyGroup>> {
    blocking(&core, |c| c.groups()).await
}

#[tauri::command]
pub async fn select_node(core: CoreState<'_>, group: String, node: String) -> Reply<()> {
    blocking(&core, move |c| c.select_node(group, node)).await
}

#[tauri::command]
pub async fn test_delay(core: CoreState<'_>, group: String) -> Reply<ProxyGroup> {
    blocking(&core, move |c| c.test_delay(group)).await
}

#[tauri::command]
pub async fn test_node_delay(core: CoreState<'_>, node: String) -> Reply<u32> {
    blocking(&core, move |c| c.test_node_delay(node)).await
}

#[tauri::command]
pub async fn whitelist(core: CoreState<'_>) -> Reply<WhitelistState> {
    blocking(&core, |c| Ok(c.whitelist())).await
}

#[tauri::command]
pub async fn set_whitelist_enabled(core: CoreState<'_>, enabled: bool) -> Reply<()> {
    blocking(&core, move |c| c.set_whitelist_enabled(enabled)).await
}

#[tauri::command]
pub async fn add_whitelist_entries(
    core: CoreState<'_>,
    text: String,
    name: String,
) -> Reply<usize> {
    blocking(&core, move |c| {
        c.add_whitelist_entries(text, name.trim().to_string())
            .map(|added| added.len())
    })
    .await
}

#[tauri::command]
pub async fn remove_whitelist_entry(core: CoreState<'_>, id: String) -> Reply<()> {
    blocking(&core, move |c| c.remove_whitelist_entry(id)).await
}

#[tauri::command]
pub async fn whitelist_now(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| {
        c.whitelist_now();
        Ok(())
    })
    .await
}

#[tauri::command]
pub async fn app_settings(core: CoreState<'_>) -> Reply<AppSettings> {
    blocking(&core, |c| Ok(c.app_settings())).await
}

#[tauri::command]
pub async fn set_app_settings(core: CoreState<'_>, settings: AppSettings) -> Reply<()> {
    blocking(&core, move |c| c.set_app_settings(settings)).await
}

#[tauri::command]
pub async fn engine_options(core: CoreState<'_>) -> Reply<EngineOptions> {
    blocking(&core, |c| Ok(c.engine_options())).await
}

#[tauri::command]
pub async fn set_engine_options(core: CoreState<'_>, options: EngineOptions) -> Reply<()> {
    blocking(&core, move |c| c.set_engine_options(options)).await
}

#[tauri::command]
pub async fn providers(core: CoreState<'_>) -> Reply<Vec<Provider>> {
    blocking(&core, |c| c.providers()).await
}

#[tauri::command]
pub async fn update_provider(core: CoreState<'_>, kind: String, name: String) -> Reply<()> {
    let kind = if kind == "rule" {
        ProviderKind::Rule
    } else {
        ProviderKind::Proxy
    };
    blocking(&core, move |c| c.update_provider(kind, name)).await
}

#[tauri::command]
pub async fn rules(core: CoreState<'_>) -> Reply<Vec<Rule>> {
    blocking(&core, |c| c.rules()).await
}

#[tauri::command]
pub async fn geo_files(core: CoreState<'_>) -> Reply<Vec<GeoFile>> {
    blocking(&core, |c| Ok(c.geo_files())).await
}

#[tauri::command]
pub async fn update_geo(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| c.update_geo()).await
}

#[tauri::command]
pub async fn flush_dns_cache(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| c.flush_dns_cache()).await
}

#[tauri::command]
pub async fn intranet_ip(core: CoreState<'_>) -> Reply<Option<IntranetIp>> {
    blocking(&core, |c| Ok(c.intranet_ip())).await
}

#[tauri::command]
pub async fn autostart_enabled() -> Reply<bool> {
    tauri::async_runtime::spawn_blocking(autostart::enabled)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn set_autostart(enabled: bool) -> Reply<()> {
    tauri::async_runtime::spawn_blocking(move || autostart::set(enabled))
        .await
        .map_err(|e| e.to_string())?
}

fn save_dialog(
    app: &AppHandle,
    file_name: &str,
    filter: &str,
    extensions: &[&str],
) -> Option<std::path::PathBuf> {
    let mut dialog = app
        .dialog()
        .file()
        .set_file_name(file_name)
        .add_filter(filter, extensions);
    if let Some(window) = app.get_webview_window("main") {
        dialog = dialog.set_parent(&window);
    }
    // An elevated process starts in System32, which is where the dialog would open otherwise.
    if let Ok(desktop) = app.path().desktop_dir() {
        dialog = dialog.set_directory(desktop);
    }
    dialog.blocking_save_file()?.into_path().ok()
}

fn scope(name: &str) -> RestoreScope {
    if name == "profiles" {
        RestoreScope::Profiles
    } else {
        RestoreScope::All
    }
}

#[tauri::command]
pub async fn backup_to_file(app: AppHandle, core: CoreState<'_>) -> Reply<Option<String>> {
    let core = Arc::clone(&core);
    tauri::async_runtime::spawn_blocking(move || {
        let data = core.backup().map_err(|e| e.to_string())?;
        let Some(path) = save_dialog(&app, "po0-clash-backup.zip", "Zip", &["zip"]) else {
            return Ok(None);
        };
        std::fs::write(&path, data).map_err(|e| e.to_string())?;
        Ok(Some(path.display().to_string()))
    })
    .await
    .map_err(|e| e.to_string())?
}

/// Returns false when the person cancels the file picker.
#[tauri::command]
pub async fn restore_from_file(
    app: AppHandle,
    core: CoreState<'_>,
    scope_name: String,
) -> Reply<bool> {
    let core = Arc::clone(&core);
    tauri::async_runtime::spawn_blocking(move || {
        let mut dialog = app.dialog().file().add_filter("Zip", &["zip"]);
        if let Some(window) = app.get_webview_window("main") {
            dialog = dialog.set_parent(&window);
        }
        if let Ok(desktop) = app.path().desktop_dir() {
            dialog = dialog.set_directory(desktop);
        }
        let Some(path) = dialog
            .blocking_pick_file()
            .and_then(|picked| picked.into_path().ok())
        else {
            return Ok(false);
        };
        let data = std::fs::read(&path).map_err(|e| e.to_string())?;
        core.restore(data, scope(&scope_name))
            .map_err(|e| e.to_string())?;
        Ok(true)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn check_webdav(core: CoreState<'_>, dav: WebDav) -> Reply<()> {
    blocking(&core, move |c| c.check_webdav(dav)).await
}

#[tauri::command]
pub async fn backup_to_webdav(core: CoreState<'_>) -> Reply<()> {
    blocking(&core, |c| c.backup_to_webdav()).await
}

#[tauri::command]
pub async fn restore_from_webdav(core: CoreState<'_>, scope_name: String) -> Reply<()> {
    blocking(&core, move |c| c.restore_from_webdav(scope(&scope_name))).await
}

#[tauri::command]
pub async fn export_diagnostics(app: AppHandle, core: CoreState<'_>) -> Reply<Option<String>> {
    let core = Arc::clone(&core);
    tauri::async_runtime::spawn_blocking(move || {
        let Some(path) = save_dialog(&app, "po0-clash-diagnostics.txt", "Text", &["txt"]) else {
            return Ok(None);
        };
        core.export_diagnostics(path.clone())
            .map_err(|e| e.to_string())?;
        Ok(Some(path.display().to_string()))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn profile_override(core: CoreState<'_>, id: String) -> Reply<ProfileOverride> {
    blocking(&core, move |c| c.profile_override(id)).await
}

#[tauri::command]
pub async fn set_profile_override(
    core: CoreState<'_>,
    id: String,
    overrides: ProfileOverride,
) -> Reply<()> {
    blocking(&core, move |c| c.set_profile_override(id, overrides)).await
}

#[derive(Serialize)]
pub struct GroupsAndRules {
    groups: String,
    rules: Vec<String>,
}

#[tauri::command]
pub async fn profile_groups_and_rules(core: CoreState<'_>, id: String) -> Reply<GroupsAndRules> {
    blocking(&core, move |c| {
        c.profile_groups_and_rules(id)
            .map(|(groups, rules)| GroupsAndRules { groups, rules })
    })
    .await
}

#[tauri::command]
pub async fn scripts(core: CoreState<'_>) -> Reply<Vec<Script>> {
    blocking(&core, |c| Ok(c.scripts())).await
}

#[tauri::command]
pub async fn save_script(core: CoreState<'_>, script: Script) -> Reply<Script> {
    blocking(&core, move |c| c.save_script(script)).await
}

#[tauri::command]
pub async fn remove_script(core: CoreState<'_>, id: String) -> Reply<()> {
    blocking(&core, move |c| c.remove_script(id)).await
}

#[derive(Serialize)]
pub struct ShareNode {
    name: String,
    kind: String,
}

#[tauri::command]
pub async fn share_nodes(core: CoreState<'_>, id: String) -> Reply<Vec<ShareNode>> {
    blocking(&core, move |c| {
        Ok(c.share_nodes(id)?
            .into_iter()
            .map(|n| ShareNode {
                name: n.name,
                kind: n.kind,
            })
            .collect())
    })
    .await
}

#[tauri::command]
pub async fn rename_share_node(
    core: CoreState<'_>,
    id: String,
    name: String,
    new_name: String,
) -> Reply<()> {
    blocking(&core, move |c| c.rename_share_node(id, name, new_name)).await
}

#[tauri::command]
pub async fn remove_share_node(core: CoreState<'_>, id: String, name: String) -> Reply<()> {
    blocking(&core, move |c| c.remove_share_node(id, name)).await
}

#[derive(Serialize)]
pub struct License {
    name: String,
    version: String,
    license: String,
    url: String,
}

#[tauri::command]
pub async fn licenses(core: CoreState<'_>) -> Reply<Vec<License>> {
    blocking(&core, |c| {
        Ok(c.licenses()
            .into_iter()
            .map(|l| License {
                name: l.name,
                version: l.version,
                license: l.license,
                url: l.url,
            })
            .collect())
    })
    .await
}

#[tauri::command]
pub async fn loopback_apps() -> Reply<Vec<loopback::AppContainer>> {
    tauri::async_runtime::spawn_blocking(loopback::apps)
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn set_loopback(sids: Vec<String>) -> Reply<()> {
    tauri::async_runtime::spawn_blocking(move || loopback::set(&sids))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub fn launch_notice(launch: State<'_, Launch>) -> Option<LaunchNotice> {
    launch
        .0
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
        .take()
}

#[tauri::command]
pub fn open_url(url: String) -> Reply<()> {
    use windows_sys::Win32::UI::Shell::ShellExecuteW;
    use windows_sys::Win32::UI::WindowsAndMessaging::SW_SHOWNORMAL;
    if !(url.starts_with("https://") || url.starts_with("http://")) {
        return Err(format!("not a web link: {url}"));
    }
    let wide = |s: &str| s.encode_utf16().chain(Some(0)).collect::<Vec<u16>>();
    let (verb, target) = (wide("open"), wide(&url));
    // SAFETY: both strings are NUL-terminated and outlive the call.
    let result = unsafe {
        ShellExecuteW(
            std::ptr::null_mut(),
            verb.as_ptr(),
            target.as_ptr(),
            std::ptr::null(),
            std::ptr::null(),
            SW_SHOWNORMAL,
        )
    };
    // ShellExecuteW reports success as a value above 32.
    if result as usize > 32 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error().to_string())
    }
}
