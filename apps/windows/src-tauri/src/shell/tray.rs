use std::sync::{Arc, Mutex};

use tauri::image::Image;
use tauri::menu::{CheckMenuItem, Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Emitter, Manager, Wry};

use super::po0::{Core, EngineState, RouteMode};
use super::{language, show_window};

const TRAY_ID: &str = "main";

struct Labels {
    connect: &'static str,
    open: &'static str,
    quit: &'static str,
    stopped: &'static str,
    starting: &'static str,
    running: &'static str,
    failed: &'static str,
}

fn labels(app: &AppHandle) -> Labels {
    match language(&app.state::<Arc<Core>>()) {
        "zh" => Labels {
            connect: "连接",
            open: "打开 po0-clash",
            quit: "退出",
            stopped: "未连接",
            starting: "正在连接",
            running: "已连接",
            failed: "连接失败",
        },
        "ja" => Labels {
            connect: "接続",
            open: "po0-clashを開く",
            quit: "終了",
            stopped: "未接続",
            starting: "接続中",
            running: "接続済み",
            failed: "接続に失敗しました",
        },
        "ru" => Labels {
            connect: "Подключить",
            open: "Открыть po0-clash",
            quit: "Выйти",
            stopped: "Не подключено",
            starting: "Подключение",
            running: "Подключено",
            failed: "Не удалось подключиться",
        },
        _ => Labels {
            connect: "Connect",
            open: "Open po0-clash",
            quit: "Quit",
            stopped: "Disconnected",
            starting: "Connecting",
            running: "Connected",
            failed: "Connection failed",
        },
    }
}

fn icon(engine: &EngineState, route_mode: RouteMode) -> Image<'static> {
    let bytes: &'static [u8] = match (engine, route_mode) {
        (EngineState::Running, RouteMode::Tun) => include_bytes!("../../icons/tray/tun.ico"),
        (EngineState::Running, RouteMode::SystemProxy) => {
            include_bytes!("../../icons/tray/proxy.ico")
        }
        _ => include_bytes!("../../icons/tray/stopped.ico"),
    };
    Image::from_bytes(bytes).expect("bundled tray icon")
}

struct Tray {
    connect: CheckMenuItem<Wry>,
    refreshing: Mutex<()>,
}

pub fn create(app: &AppHandle) -> tauri::Result<()> {
    let labels = labels(app);
    let connect =
        CheckMenuItem::with_id(app, "connect", labels.connect, true, false, None::<&str>)?;
    let open = MenuItem::with_id(app, "open", labels.open, true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", labels.quit, true, None::<&str>)?;
    let separator = PredefinedMenuItem::separator(app)?;
    let menu = Menu::with_items(app, &[&connect, &separator, &open, &quit])?;
    TrayIconBuilder::with_id(TRAY_ID)
        .icon(icon(&EngineState::Stopped, RouteMode::Tun))
        .tooltip("po0-clash")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "connect" => toggle(app),
            "open" => show_window(app),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                show_window(tray.app_handle());
            }
        })
        .build(app)?;
    app.manage(Tray {
        connect,
        refreshing: Mutex::new(()),
    });
    refresh(app);
    Ok(())
}

pub fn refresh(app: &AppHandle) {
    let app = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let tray = app.state::<Tray>();
        let _serial = tray.refreshing.lock().unwrap_or_else(|e| e.into_inner());
        let status = app.state::<Arc<Core>>().status();
        let labels = labels(&app);
        let state = match &status.engine {
            EngineState::Stopped => labels.stopped,
            EngineState::Starting => labels.starting,
            EngineState::Running => labels.running,
            EngineState::Failed(_) => labels.failed,
        };
        let active = matches!(status.engine, EngineState::Running | EngineState::Starting);
        let _ = tray.connect.set_checked(active);
        if let Some(icon_handle) = app.tray_by_id(TRAY_ID) {
            let _ = icon_handle.set_icon(Some(icon(&status.engine, status.route_mode)));
            let _ = icon_handle.set_tooltip(Some(format!("po0-clash · {state}")));
        }
    });
}

pub fn toggle(app: &AppHandle) {
    let app = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let core = Arc::clone(&app.state::<Arc<Core>>());
        match core.status().engine {
            EngineState::Running | EngineState::Starting => core.stop(),
            _ => {
                if let Err(e) = core.start(None) {
                    let _ = app.emit("shell-error", e.to_string());
                    show_window(&app);
                }
            }
        }
        refresh(&app);
    });
}
