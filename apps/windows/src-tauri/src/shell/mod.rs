mod autostart;
mod commands;
mod netwatch;
mod tray;

use std::sync::Arc;

use po0_core as po0;
use po0::{Change, Core, CoreOptions, Listener, Platform};
use tauri::{AppHandle, Emitter, Manager, RunEvent, WindowEvent};

/// The language chosen in the app settings, or the system's when none is.
pub fn is_zh(core: &Core) -> bool {
    core.app_settings()
        .language
        .or_else(sys_locale::get_locale)
        .is_some_and(|l| l.to_ascii_lowercase().starts_with("zh"))
}

pub struct Backdrop(pub bool);

pub fn show_window(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
    }
}

/// Windows 10 draws Acrylic untinted, which leaves the page titles on a raw blur of the desktop.
fn acrylic_tint(window: &tauri::WebviewWindow) -> (u8, u8, u8, u8) {
    match window.theme() {
        Ok(tauri::Theme::Dark) => (32, 32, 32, 200),
        _ => (243, 243, 243, 200),
    }
}

struct Bridge(AppHandle);

impl Listener for Bridge {
    fn on_change(&self, change: Change) {
        let _ = self.0.emit("core-change", change);
        if matches!(change, Change::Status) {
            tray::refresh(&self.0);
        }
    }
}

fn open_core(app: &AppHandle) -> Result<Arc<Core>, String> {
    let paths = app.path();
    let data_dir = paths.app_data_dir().map_err(|e| e.to_string())?.join("core");
    // path_provider puts the Flutter app's support dir at %APPDATA%\<CompanyName>\<ProductName> from Runner.rc.
    let legacy = paths.data_dir().map_err(|e| e.to_string())?.join("io.github.yuuukicreation").join("po0-clash");
    let existing = |name: &str| Some(legacy.join(name)).filter(|p| p.is_file());
    Core::new(CoreOptions {
        data_dir,
        platform: Platform::Windows,
        mihomo_path: paths.resource_dir().ok().map(|dir| dir.join("mihomo.exe")),
        legacy_prefs: existing("shared_preferences.json"),
        legacy_database: existing("database.sqlite"),
        app_version: app.package_info().version.to_string(),
    })
    .map_err(|e| e.to_string())
}

fn fatal(message: &str) -> ! {
    use windows_sys::Win32::UI::WindowsAndMessaging::{MB_ICONERROR, MB_OK, MessageBoxW};
    let wide = |s: &str| s.encode_utf16().chain(Some(0)).collect::<Vec<u16>>();
    let (text, caption) = (wide(message), wide("po0-clash"));
    // SAFETY: both strings are NUL-terminated and outlive the call.
    unsafe { MessageBoxW(std::ptr::null_mut(), text.as_ptr(), caption.as_ptr(), MB_OK | MB_ICONERROR) };
    std::process::exit(1)
}

pub fn run() {
    let autostarted = std::env::args().any(|a| a == autostart::ARG);
    let app = tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| show_window(app)))
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            commands::app_info,
            commands::status,
            commands::start,
            commands::stop,
            commands::traffic,
            commands::traffic_history,
            commands::memory,
            commands::connections,
            commands::close_connection,
            commands::close_all_connections,
            commands::requests,
            commands::clear_requests,
            commands::logs,
            commands::clear_logs,
            commands::exit_ip,
            commands::set_mode,
            commands::set_route_mode,
            commands::profiles,
            commands::add_subscription,
            commands::update_profile,
            commands::remove_profile,
            commands::select_profile,
            commands::import_links,
            commands::import_file,
            commands::edit_profile,
            commands::preview_config,
            commands::reorder_profiles,
            commands::export_profile,
            commands::groups,
            commands::select_node,
            commands::test_delay,
            commands::test_node_delay,
            commands::whitelist,
            commands::set_whitelist_enabled,
            commands::add_whitelist_entries,
            commands::remove_whitelist_entry,
            commands::whitelist_now,
            commands::app_settings,
            commands::set_app_settings,
            commands::engine_options,
            commands::set_engine_options,
            commands::providers,
            commands::update_provider,
            commands::rules,
            commands::geo_files,
            commands::update_geo,
            commands::flush_dns_cache,
            commands::intranet_ip,
            commands::autostart_enabled,
            commands::set_autostart,
            commands::export_diagnostics,
            commands::backup_to_file,
            commands::restore_from_file,
            commands::check_webdav,
            commands::backup_to_webdav,
            commands::restore_from_webdav,
        ])
        .setup(move |app| {
            let handle = app.handle();
            let core = open_core(handle).unwrap_or_else(|e| fatal(&e));
            app.manage(Arc::clone(&core));
            let window = app.get_webview_window("main").expect("main window");
            let backdrop = window_vibrancy::apply_mica(&window, None)
                .or_else(|_| window_vibrancy::apply_acrylic(&window, Some(acrylic_tint(&window))))
                .is_ok();
            app.manage(Backdrop(backdrop));
            tray::create(handle)?;
            core.set_listener(Arc::new(Bridge(handle.clone())));
            netwatch::spawn(Arc::clone(&core));
            let settings = core.app_settings();
            if !autostarted && !settings.silent_launch {
                show_window(handle);
            }
            let connect = if autostarted { core.was_connected() } else { settings.auto_connect };
            if connect {
                let handle = handle.clone();
                tauri::async_runtime::spawn_blocking(move || {
                    if let Err(e) = core.start(None) {
                        let _ = handle.emit("shell-error", e.to_string());
                    }
                });
            }
            Ok(())
        })
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                let minimize = window
                    .try_state::<Arc<Core>>()
                    .is_none_or(|core| core.app_settings().minimize_on_close);
                if minimize {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .build(tauri::generate_context!())
        .unwrap_or_else(|e| fatal(&e.to_string()));
    app.run(|app, event| {
        if let RunEvent::Exit = event
            && let Some(core) = app.try_state::<Arc<Core>>()
        {
            core.shutdown();
        }
    });
}
