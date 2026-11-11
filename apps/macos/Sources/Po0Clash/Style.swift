import AppKit
import Po0FFI
import SwiftUI

enum Format {
    /// FlClash's 1024 steps and short units, so a few hundred bytes read "441 B" rather than "441 bytes".
    static func bytes(_ value: UInt64) -> String {
        let (size, unit) = scaled(value)
        return String(format: unit == "B" || size >= 100 ? "%.0f %@" : "%.1f %@", size, unit)
    }

    static func rate(_ value: UInt64) -> String {
        bytes(value) + "/s"
    }

    /// Whole numbers, as the Flutter app's menu bar showed them.
    static func shortRate(_ value: UInt64) -> String {
        let (size, unit) = scaled(value)
        return String(format: "%.0f %@/s", size, unit)
    }

    private static func scaled(_ value: UInt64) -> (size: Double, unit: String) {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(value)
        var unit = 0
        while size >= 1024, unit < units.count - 1 {
            size /= 1024
            unit += 1
        }
        return (size, units[unit])
    }

    static func delay(_ node: Node) -> String? {
        guard let delay = node.delay else { return nil }
        return delay == 0 ? String(localized: "Timeout") : "\(delay) ms"
    }
}

/// The theme settings FlClash keeps in the core, applied over the system appearance.
enum Theme {
    static let defaultColor: UInt32 = 0xFF00_7AFF

    @MainActor
    static func apply(_ settings: AppSettings?) {
        guard let settings else { return }
        guard !Showcase.forcesAppearance else { return }
        switch settings.themeMode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    static func accent(_ argb: UInt32) -> Color {
        Color(nsColor: nsAccent(argb))
    }

    /// The presets are Apple's system colours, so they keep their dark-mode variants.
    static func nsAccent(_ argb: UInt32) -> NSColor {
        switch argb {
        case 0xFF00_64E0, 0xFF00_7AFF: return .systemBlue
        case 0xFF58_56D6: return .systemIndigo
        case 0xFFAF_52DE: return .systemPurple
        case 0xFFFF_2D55: return .systemPink
        case 0xFFFF_9500: return .systemOrange
        case 0xFF24_694C, 0xFF34_C759: return .systemGreen
        case 0xFF30_B0C7: return .systemTeal
        case 0xFF8E_8E93: return .systemGray
        default: return NSColor(argb: argb)
        }
    }
}

extension AppModel {
    var themeColor: UInt32 {
        Showcase.themeColor ?? appSettings?.themeColor ?? Theme.defaultColor
    }
}

struct AppTheme: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        let accent = Theme.accent(model.themeColor)
        content
            .accentColor(accent)
            .environment(\.themeAccent, accent)
            .toggleStyle(.themedSwitch)
    }
}

private struct ThemeAccentKey: EnvironmentKey {
    static let defaultValue = Color.accentColor
}

extension EnvironmentValues {
    /// The theme colour itself: `Color.accentColor` reaches switches and segmented pickers as the system accent.
    var themeAccent: Color {
        get { self[ThemeAccentKey.self] }
        set { self[ThemeAccentKey.self] = newValue }
    }
}

/// A window-wide tint would colour push buttons too, so the theme reaches switches through their style.
struct ThemedSwitch: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ThemedSwitchBody(configuration: configuration)
    }
}

private struct ThemedSwitchBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.themeAccent) private var accent

    var body: some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(accent)
    }
}

extension ToggleStyle where Self == ThemedSwitch {
    static var themedSwitch: ThemedSwitch { ThemedSwitch() }
}

extension View {
    func themedSegments() -> some View {
        modifier(ThemedSegments())
    }
}

private struct ThemedSegments: ViewModifier {
    @Environment(\.themeAccent) private var accent

    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .tint(accent)
    }
}

extension NSColor {
    convenience init(argb: UInt32) {
        self.init(
            srgbRed: CGFloat(argb >> 16 & 0xFF) / 255,
            green: CGFloat(argb >> 8 & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat(argb >> 24 & 0xFF) / 255
        )
    }
}

extension View {
    func groupedSection() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent).tint(Color.accentColor)
            } else {
                buttonStyle(.glass)
            }
        } else {
            plainButton(prominent: prominent)
        }
        #else
        plainButton(prominent: prominent)
        #endif
    }

    @ViewBuilder
    private func plainButton(prominent: Bool) -> some View {
        if prominent {
            buttonStyle(.borderedProminent).tint(Color.accentColor)
        } else {
            buttonStyle(.bordered)
        }
    }
}

extension AppModel {
    var stateTitle: String {
        switch status?.engine {
        case .running?:
            return status?.routeMode == .tun
                ? String(localized: "Connected · TUN") : String(localized: "Connected · System proxy")
        case .starting?: return String(localized: "Connecting…")
        case .failed?: return String(localized: "Connection failed")
        default: return String(localized: "Not connected")
        }
    }

    var exitIpText: String {
        guard let exit = exitIp else { return "—" }
        return exit.country.map { "\(exit.ip) · \($0)" } ?? exit.ip
    }

    var whitelistSummary: String {
        let entries = whitelist?.entries ?? []
        if entries.isEmpty { return String(localized: "No tokens or links yet") }
        let applied = entries.filter { $0.result?.outcome == .applied }.count
        return String(localized: "\(applied) of \(entries.count) whitelisted")
    }
}

extension Profile {
    /// The core names the share-link profile in English; show it in the user's language instead.
    var title: String {
        kind == .links ? String(localized: "Share links") : name
    }
}
