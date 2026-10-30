import AppKit
import Carbon.HIToolbox
import Po0FFI
import SwiftUI

/// FlClash's global hotkeys, registered with Carbon's hot key API because it needs no accessibility permission.
@MainActor
final class Hotkeys: ObservableObject {
    static let shared = Hotkeys()

    @Published private(set) var failed: Set<HotkeyAction> = []
    /// Recording a shortcut has to receive keys that are already registered.
    var paused = false {
        didSet { apply(registered) }
    }

    private var registered: [Hotkey] = []
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: HotkeyAction] = [:]
    private var handler: EventHandlerRef?

    func register(_ hotkeys: [Hotkey]) {
        if hotkeys != registered { apply(hotkeys) }
    }

    private func apply(_ hotkeys: [Hotkey]) {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs = []
        actions = [:]
        registered = hotkeys
        var failed = Set<HotkeyAction>()
        if !paused {
            installHandler()
            for (index, hotkey) in hotkeys.enumerated() {
                var ref: EventHotKeyRef?
                let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
                let status = Shortcut.keyCode(hotkey.key).map { code in
                    RegisterEventHotKey(
                        UInt32(code), Shortcut.carbonModifiers(hotkey.modifiers), id, GetEventDispatcherTarget(), 0, &ref
                    )
                }
                if status == OSStatus(noErr), let ref {
                    refs.append(ref)
                    actions[UInt32(index)] = hotkey.action
                } else {
                    failed.insert(hotkey.action)
                }
            }
        }
        self.failed = failed
    }

    private static let signature = "po0c".utf8.reduce(OSType(0)) { $0 << 8 | OSType($1) }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), hotkeyPressed, 1, &spec, nil, &handler)
    }

    fileprivate func fire(_ index: UInt32) {
        guard let action = actions[index] else { return }
        let model = AppModel.shared
        switch action {
        case .connect:
            model.setConnected(!model.isRunning)
        case .showWindow:
            MainWindow.shared.toggle()
        case .mode:
            switch model.status?.mode {
            case .rule: model.setMode(.global)
            case .global: model.setMode(.direct)
            default: model.setMode(.rule)
            }
        case .systemProxy:
            model.setRouteMode(.systemProxy)
        case .tun:
            model.setRouteMode(model.status?.routeMode == .tun ? .systemProxy : .tun)
        }
    }
}

private func hotkeyPressed(_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    var id = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &id
    )
    if status == OSStatus(noErr) {
        let index = id.id
        Task { @MainActor in Hotkeys.shared.fire(index) }
    }
    return status
}

/// Keys are stored as W3C `KeyboardEvent.code` names so every platform reads the same settings.
enum Shortcut {
    private static let codes: [String: Int] = {
        var codes = [
            "KeyA": kVK_ANSI_A, "KeyB": kVK_ANSI_B, "KeyC": kVK_ANSI_C, "KeyD": kVK_ANSI_D, "KeyE": kVK_ANSI_E,
            "KeyF": kVK_ANSI_F, "KeyG": kVK_ANSI_G, "KeyH": kVK_ANSI_H, "KeyI": kVK_ANSI_I, "KeyJ": kVK_ANSI_J,
            "KeyK": kVK_ANSI_K, "KeyL": kVK_ANSI_L, "KeyM": kVK_ANSI_M, "KeyN": kVK_ANSI_N, "KeyO": kVK_ANSI_O,
            "KeyP": kVK_ANSI_P, "KeyQ": kVK_ANSI_Q, "KeyR": kVK_ANSI_R, "KeyS": kVK_ANSI_S, "KeyT": kVK_ANSI_T,
            "KeyU": kVK_ANSI_U, "KeyV": kVK_ANSI_V, "KeyW": kVK_ANSI_W, "KeyX": kVK_ANSI_X, "KeyY": kVK_ANSI_Y,
            "KeyZ": kVK_ANSI_Z,
            "Digit0": kVK_ANSI_0, "Digit1": kVK_ANSI_1, "Digit2": kVK_ANSI_2, "Digit3": kVK_ANSI_3,
            "Digit4": kVK_ANSI_4, "Digit5": kVK_ANSI_5, "Digit6": kVK_ANSI_6, "Digit7": kVK_ANSI_7,
            "Digit8": kVK_ANSI_8, "Digit9": kVK_ANSI_9,
            "Minus": kVK_ANSI_Minus, "Equal": kVK_ANSI_Equal, "BracketLeft": kVK_ANSI_LeftBracket,
            "BracketRight": kVK_ANSI_RightBracket, "Backslash": kVK_ANSI_Backslash, "Semicolon": kVK_ANSI_Semicolon,
            "Quote": kVK_ANSI_Quote, "Comma": kVK_ANSI_Comma, "Period": kVK_ANSI_Period, "Slash": kVK_ANSI_Slash,
            "Backquote": kVK_ANSI_Grave,
            "Space": kVK_Space, "Enter": kVK_Return, "Tab": kVK_Tab, "Backspace": kVK_Delete,
            "Delete": kVK_ForwardDelete, "Escape": kVK_Escape, "Home": kVK_Home, "End": kVK_End,
            "PageUp": kVK_PageUp, "PageDown": kVK_PageDown, "ArrowLeft": kVK_LeftArrow,
            "ArrowRight": kVK_RightArrow, "ArrowUp": kVK_UpArrow, "ArrowDown": kVK_DownArrow,
        ]
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        ]
        for (index, code) in functionKeys.enumerated() { codes["F\(index + 1)"] = code }
        return codes
    }()

    private static let labels = [
        "Space": "Space", "Enter": "↩", "Tab": "⇥", "Backspace": "⌫", "Delete": "⌦", "Escape": "⎋",
        "Home": "↖", "End": "↘", "PageUp": "⇞", "PageDown": "⇟", "ArrowLeft": "←", "ArrowRight": "→",
        "ArrowUp": "↑", "ArrowDown": "↓", "Minus": "-", "Equal": "=", "BracketLeft": "[", "BracketRight": "]",
        "Backslash": "\\", "Semicolon": ";", "Quote": "'", "Comma": ",", "Period": ".", "Slash": "/",
        "Backquote": "`",
    ]

    static func keyCode(_ key: String) -> Int? { codes[key] }

    static func key(forCode code: Int) -> String? { codes.first { $0.value == code }?.key }

    static func isFunctionKey(_ key: String) -> Bool { key.hasPrefix("F") && Int(key.dropFirst()) != nil }

    static func modifiers(_ flags: NSEvent.ModifierFlags) -> [HotkeyModifier] {
        [(NSEvent.ModifierFlags.control, HotkeyModifier.control), (.option, .alt), (.shift, .shift), (.command, .meta)]
            .filter { flags.contains($0.0) }
            .map { $0.1 }
    }

    static func carbonModifiers(_ modifiers: [HotkeyModifier]) -> UInt32 {
        var flags = 0
        for modifier in modifiers {
            switch modifier {
            case .control: flags |= controlKey
            case .alt: flags |= optionKey
            case .shift: flags |= shiftKey
            case .meta: flags |= cmdKey
            }
        }
        return UInt32(flags)
    }

    static func display(_ hotkey: Hotkey) -> String {
        let symbols: [(HotkeyModifier, String)] = [(.control, "⌃"), (.alt, "⌥"), (.shift, "⇧"), (.meta, "⌘")]
        let key = labels[hotkey.key]
            ?? (hotkey.key.hasPrefix("Key") || hotkey.key.hasPrefix("Digit") ? String(hotkey.key.suffix(1)) : hotkey.key)
        return symbols.filter { hotkey.modifiers.contains($0.0) }.map { $0.1 }.joined() + key
    }
}

extension HotkeyAction {
    static let all: [HotkeyAction] = [.connect, .showWindow, .mode, .systemProxy, .tun]

    var title: LocalizedStringKey {
        switch self {
        case .connect: return "Connect/Disconnect"
        case .showWindow: return "Show/Hide window"
        case .mode: return "Switch mode"
        case .systemProxy: return "Use the system proxy"
        case .tun: return "Turn TUN on or off"
        }
    }
}

struct HotkeysView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var hotkeys = Hotkeys.shared

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.all, id: \.self) { action in
                    LabeledContent {
                        ShortcutRecorder(action: action)
                    } label: {
                        Text(action.title)
                        if hotkeys.failed.contains(action) {
                            Text("Not registered; another app may be using it.").foregroundStyle(.red)
                        }
                    }
                }
            } footer: {
                Text("Global hotkeys work even while the window is hidden. Click a shortcut to record a new one; while recording, Delete clears it and Esc cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.appSettings == nil)
    }
}

private struct ShortcutRecorder: View {
    @EnvironmentObject private var model: AppModel
    let action: HotkeyAction
    @State private var monitor: Any?
    @State private var needsModifier = false

    private var current: Hotkey? { model.appSettings?.hotkeys.first { $0.action == action } }

    var body: some View {
        HStack(spacing: 8) {
            if needsModifier, monitor != nil {
                Text("Include ⌃, ⌥ or ⌘").font(.caption).foregroundStyle(.secondary)
            }
            Button(action: monitor == nil ? start : stop) {
                Group {
                    if monitor != nil {
                        Text("Press a shortcut…")
                    } else if let current {
                        Text(verbatim: Shortcut.display(current))
                    } else {
                        Text("Not set").foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 120)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        Hotkeys.shared.paused = true
        needsModifier = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            record(event)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        Hotkeys.shared.paused = false
    }

    private func record(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        let code = Int(event.keyCode)
        if flags.isEmpty, code == kVK_Escape { return stop() }
        if flags.isEmpty, code == kVK_Delete || code == kVK_ForwardDelete {
            save(nil)
            return stop()
        }
        guard let key = Shortcut.key(forCode: code) else { return }
        guard Shortcut.isFunctionKey(key) || !flags.isDisjoint(with: [.control, .option, .command]) else {
            needsModifier = true
            return
        }
        save(Hotkey(action: action, key: key, modifiers: Shortcut.modifiers(flags)))
        stop()
    }

    /// A combination already used by another action moves here, as FlClash does.
    private func save(_ hotkey: Hotkey?) {
        model.updateAppSettings { settings in
            settings.hotkeys.removeAll { other in
                other.action == action || (other.key == hotkey?.key && other.modifiers == hotkey?.modifiers)
            }
            if let hotkey { settings.hotkeys.append(hotkey) }
        }
    }
}
