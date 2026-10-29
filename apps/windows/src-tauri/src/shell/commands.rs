use std::sync::Arc;

use serde::Serialize;
use tauri::{AppHandle, Manager, State};
use tauri_plugin_dialog::DialogExt;

use super::po0::{
    Core, CoreError, ExitIp, ImportResult, Mode, Profile, ProxyGroup, RouteMode, Status, Traffic, WhitelistState,
};
use super::{Backdrop, autostart, locale_is_zh};

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
    zh: bool,
    backdrop: bool,
}

#[tauri::command]
pub fn app_info(app: AppHandle, backdrop: State<'_, Backdrop>) -> AppInfo {
    AppInfo { version: app.package_info().version.to_string(), zh: locale_is_zh(), backdrop: backdrop.0 }
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
pub async fn whitelist(core: CoreState<'_>) -> Reply<WhitelistState> {
    blocking(&core, |c| Ok(c.whitelist())).await
}

#[tauri::command]
pub async fn set_whitelist_enabled(core: CoreState<'_>, enabled: bool) -> Reply<()> {
    blocking(&core, move |c| c.set_whitelist_enabled(enabled)).await
}

#[tauri::command]
pub async fn add_whitelist_entries(core: CoreState<'_>, text: String, name: String) -> Reply<usize> {
    blocking(&core, move |c| c.add_whitelist_entries(text, name.trim().to_string()).map(|added| added.len())).await
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
pub async fn autostart_enabled() -> Reply<bool> {
    tauri::async_runtime::spawn_blocking(autostart::enabled).await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn set_autostart(enabled: bool) -> Reply<()> {
    tauri::async_runtime::spawn_blocking(move || autostart::set(enabled)).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn export_diagnostics(app: AppHandle, core: CoreState<'_>) -> Reply<Option<String>> {
    let core = Arc::clone(&core);
    tauri::async_runtime::spawn_blocking(move || {
        let mut dialog = app
            .dialog()
            .file()
            .set_file_name("po0-clash-diagnostics.txt")
            .add_filter("Text", &["txt"]);
        if let Some(window) = app.get_webview_window("main") {
            dialog = dialog.set_parent(&window);
        }
        let Some(picked) = dialog.blocking_save_file() else {
            return Ok(None);
        };
        let path = picked.into_path().map_err(|e| e.to_string())?;
        core.export_diagnostics(path.clone()).map_err(|e| e.to_string())?;
        Ok(Some(path.display().to_string()))
    })
    .await
    .map_err(|e| e.to_string())?
}
