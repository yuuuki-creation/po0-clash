//! FlClash's global hotkeys through RegisterHotKey, owned by one thread that also receives WM_HOTKEY.

use std::sync::{Arc, Condvar, Mutex, PoisonError};
use std::time::Duration;

use tauri::{AppHandle, Emitter, Manager};
use windows_sys::Win32::System::Threading::GetCurrentThreadId;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    MOD_ALT, MOD_CONTROL, MOD_NOREPEAT, MOD_SHIFT, MOD_WIN, RegisterHotKey, UnregisterHotKey,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    GetMessageW, MSG, PM_NOREMOVE, PeekMessageW, PostThreadMessageW, WM_APP, WM_HOTKEY,
};

use super::po0::{Core, Hotkey, HotkeyAction, HotkeyModifier, Mode, RouteMode};
use super::{show_window, tray};

const RELOAD: u32 = WM_APP + 1;

#[derive(Default)]
struct State {
    wanted: Vec<Hotkey>,
    paused: bool,
    failed: Vec<HotkeyAction>,
    requested: u64,
    applied: u64,
}

pub struct Hotkeys {
    thread: u32,
    state: Arc<(Mutex<State>, Condvar)>,
}

/// Maps a W3C `KeyboardEvent.code`, the form the core stores, to a Windows virtual-key code.
fn virtual_key(code: &str) -> Option<u32> {
    let single = |rest: &str| {
        let mut chars = rest.chars();
        chars.next().filter(|_| chars.next().is_none())
    };
    if let Some(c) = code
        .strip_prefix("Key")
        .and_then(single)
        .filter(char::is_ascii_uppercase)
    {
        return Some(c as u32);
    }
    if let Some(c) = code
        .strip_prefix("Digit")
        .and_then(single)
        .filter(char::is_ascii_digit)
    {
        return Some(c as u32);
    }
    if let Some(rest) = code
        .strip_prefix("Numpad")
        .and_then(|n| n.parse::<u32>().ok())
    {
        return (rest <= 9).then_some(0x60 + rest);
    }
    if let Some(n) = code.strip_prefix('F').and_then(|n| n.parse::<u32>().ok()) {
        return (1..=24).contains(&n).then_some(0x6F + n);
    }
    Some(match code {
        "Space" => 0x20,
        "Enter" => 0x0D,
        "Tab" => 0x09,
        "Backspace" => 0x08,
        "Delete" => 0x2E,
        "Insert" => 0x2D,
        "Escape" => 0x1B,
        "Home" => 0x24,
        "End" => 0x23,
        "PageUp" => 0x21,
        "PageDown" => 0x22,
        "ArrowLeft" => 0x25,
        "ArrowUp" => 0x26,
        "ArrowRight" => 0x27,
        "ArrowDown" => 0x28,
        "Minus" => 0xBD,
        "Equal" => 0xBB,
        "BracketLeft" => 0xDB,
        "BracketRight" => 0xDD,
        "Backslash" => 0xDC,
        "Semicolon" => 0xBA,
        "Quote" => 0xDE,
        "Comma" => 0xBC,
        "Period" => 0xBE,
        "Slash" => 0xBF,
        "Backquote" => 0xC0,
        _ => return None,
    })
}

fn modifiers(list: &[HotkeyModifier]) -> u32 {
    list.iter().fold(MOD_NOREPEAT, |flags, modifier| {
        flags
            | match modifier {
                HotkeyModifier::Control => MOD_CONTROL,
                HotkeyModifier::Alt => MOD_ALT,
                HotkeyModifier::Shift => MOD_SHIFT,
                HotkeyModifier::Meta => MOD_WIN,
            }
    })
}

/// Registers what is wanted on the calling thread, the one whose queue then gets WM_HOTKEY.
fn apply(state: &(Mutex<State>, Condvar), registered: &mut Vec<HotkeyAction>) {
    let (lock, done) = state;
    let mut state = lock.lock().unwrap_or_else(PoisonError::into_inner);
    for id in 0..registered.len() {
        // SAFETY: unregistering an id this thread registered, or never did, has no other effect.
        unsafe { UnregisterHotKey(std::ptr::null_mut(), id as i32) };
    }
    registered.clear();
    state.failed.clear();
    if !state.paused {
        for hotkey in state.wanted.clone() {
            let id = registered.len() as i32;
            let ok = virtual_key(&hotkey.key).is_some_and(|vk| {
                // SAFETY: a null window binds the hotkey to this thread's message queue.
                unsafe {
                    RegisterHotKey(std::ptr::null_mut(), id, modifiers(&hotkey.modifiers), vk) != 0
                }
            });
            registered.push(hotkey.action);
            if !ok {
                state.failed.push(hotkey.action);
            }
        }
    }
    state.applied = state.requested;
    done.notify_all();
}

fn fire(app: &AppHandle, action: HotkeyAction) {
    let core = Arc::clone(&app.state::<Arc<Core>>());
    if action == HotkeyAction::Connect {
        return tray::toggle(app);
    }
    if action == HotkeyAction::ShowWindow {
        let window = app.get_webview_window("main");
        let shown = window
            .as_ref()
            .is_some_and(|w| w.is_visible().unwrap_or(false) && !w.is_minimized().unwrap_or(false));
        match window {
            Some(window) if shown => {
                let _ = window.hide();
            }
            _ => show_window(app),
        }
        return;
    }
    let app = app.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let status = core.status();
        let result = match action {
            HotkeyAction::Mode => core.set_mode(match status.mode {
                Mode::Rule => Mode::Global,
                Mode::Global => Mode::Direct,
                Mode::Direct => Mode::Rule,
            }),
            HotkeyAction::SystemProxy => core.set_route_mode(RouteMode::SystemProxy),
            _ => core.set_route_mode(match status.route_mode {
                RouteMode::Tun => RouteMode::SystemProxy,
                RouteMode::SystemProxy => RouteMode::Tun,
            }),
        };
        if let Err(e) = result {
            let _ = app.emit("shell-error", e.to_string());
        }
        tray::refresh(&app);
    });
}

impl Hotkeys {
    pub fn spawn(app: AppHandle) -> Self {
        let state = Arc::new((Mutex::new(State::default()), Condvar::new()));
        let (sender, receiver) = std::sync::mpsc::channel();
        let shared = Arc::clone(&state);
        std::thread::spawn(move || {
            let mut msg = MSG::default();
            // SAFETY: peeking creates this thread's message queue before anyone posts to it.
            unsafe { PeekMessageW(&mut msg, std::ptr::null_mut(), 0, 0, PM_NOREMOVE) };
            let _ = sender.send(unsafe { GetCurrentThreadId() });
            let mut registered = Vec::new();
            // SAFETY: `msg` is a valid MSG for the whole loop.
            while unsafe { GetMessageW(&mut msg, std::ptr::null_mut(), 0, 0) } > 0 {
                match msg.message {
                    RELOAD => apply(&shared, &mut registered),
                    WM_HOTKEY => {
                        if let Some(&action) = registered.get(msg.wParam) {
                            fire(&app, action);
                        }
                    }
                    _ => {}
                }
            }
        });
        Self {
            thread: receiver.recv().unwrap_or_default(),
            state,
        }
    }

    /// Waits briefly for the hotkey thread, so `failed` describes this change when it returns.
    fn request(&self, change: impl FnOnce(&mut State) -> bool) {
        let (lock, done) = &*self.state;
        let mut state = lock.lock().unwrap_or_else(PoisonError::into_inner);
        if !change(&mut state) {
            return;
        }
        state.requested += 1;
        let target = state.requested;
        unsafe { PostThreadMessageW(self.thread, RELOAD, 0, 0) };
        let _ = done.wait_timeout_while(state, Duration::from_secs(2), |s| s.applied < target);
    }

    pub fn sync(&self, hotkeys: Vec<Hotkey>) {
        self.request(|state| {
            let changed = state.wanted != hotkeys;
            state.wanted = hotkeys;
            changed
        });
    }

    pub fn pause(&self, paused: bool) {
        self.request(|state| std::mem::replace(&mut state.paused, paused) != paused);
    }

    pub fn failed(&self) -> Vec<HotkeyAction> {
        self.state
            .0
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .failed
            .clone()
    }
}

pub fn refresh(app: &AppHandle) {
    if let (Some(hotkeys), Some(core)) = (app.try_state::<Hotkeys>(), app.try_state::<Arc<Core>>())
    {
        hotkeys.sync(core.app_settings().hotkeys);
    }
}
