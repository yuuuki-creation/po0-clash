import AppKit
import Po0FFI
import QuartzCore
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

    static func date(_ unixSeconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(unixSeconds))
    }

    static func elapsed(_ since: Date, now: Date) -> String {
        let seconds = max(Int(now.timeIntervalSince(since)), 0)
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    static func delay(_ node: Node) -> String? {
        guard let delay = node.delay else { return nil }
        return delay == 0 ? String(localized: "Timeout") : "\(delay) ms"
    }

    /// A timeout is an error and anything from 600 ms up a warning, the Flutter app's thresholds.
    static func delayTint(_ delay: UInt32?) -> Color {
        switch delay {
        case 0?: return .bad
        case let delay? where delay >= 600: return .warn
        case _?: return .good
        case nil: return .ink3
        }
    }

    static func delayBackground(_ delay: UInt32?) -> Color {
        switch delay {
        case 0?: return .badMuted
        case let delay? where delay >= 600: return .warnMuted
        case _?: return .goodMuted
        case nil: return .clear
        }
    }

    static func nodeCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 node") : String(localized: "\(count) nodes")
    }

    static func usage(_ usage: Usage?) -> String? {
        guard let usage, usage.total > 0 else { return nil }
        return "\(bytes(usage.upload + usage.download)) / \(bytes(usage.total))"
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static func ago(_ unixSeconds: Int64) -> String {
        relative.localizedString(for: date(unixSeconds), relativeTo: Date())
    }
}

extension NSColor {
    static func token(
        light: UInt32,
        dark: UInt32,
        black: UInt32? = nil,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? (Theme.pureBlack ? black ?? dark : dark) : light
            return NSColor(
                srgbRed: CGFloat(hex >> 16 & 0xFF) / 255,
                green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        }
    }

    static let pageBackground = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if isDark, Theme.pureBlack { return .black }
        return .windowBackgroundColor
    }
    static let inkText = NSColor.labelColor
    static let badText = NSColor.systemRed

    convenience init(argb: UInt32) {
        self.init(
            srgbRed: CGFloat(argb >> 16 & 0xFF) / 255,
            green: CGFloat(argb >> 8 & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat(argb >> 24 & 0xFF) / 255
        )
    }
}

extension Color {
    static let page = Color(nsColor: .pageBackground)
    static let side = Color(light: 0xF5F5F7, dark: 0x1E1E1E, black: 0x000000)
    static let card = Color(light: 0xFFFFFF, dark: 0x262629, black: 0x121316)
    static let zebra = Color.clear
    static let neutral = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.14)
    static let hover = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.04, darkAlpha: 0.06)
    static let track = neutral
    static let controlSurface = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.12)
    static let segmentThumb = Color(light: 0xFFFFFF, dark: 0x3A3A3C, black: 0x1C1C1E)
    static let switchOff = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.16, darkAlpha: 0.24)
    static let dialogSurface = Color(light: 0xFFFFFF, dark: 0x2C2C2E, black: 0x1B1C20)

    static let ink = Color(nsColor: .labelColor)
    static let ink2 = Color(nsColor: .secondaryLabelColor)
    static let ink3 = Color(nsColor: .tertiaryLabelColor)
    static let good = Color(nsColor: .systemGreen)
    static let warn = Color(nsColor: .systemOrange)
    static let bad = Color(nsColor: .systemRed)
    static let goodMuted = Color(light: 0x28CD41, dark: 0x30D158, lightAlpha: 0.15, darkAlpha: 0.22)
    static let warnMuted = Color(light: 0xFF9500, dark: 0xFF9F0A, lightAlpha: 0.15, darkAlpha: 0.22)
    static let badMuted = Color(light: 0xFF3B30, dark: 0xFF453A, lightAlpha: 0.15, darkAlpha: 0.22)

    static let line = Color(nsColor: .separatorColor)
    static let stroke = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.10)
    static let press = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.14)
    static let listSelection = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.09, darkAlpha: 0.15)
    static let controlRing = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.16)
    static let segmentRing = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.12)
    static let controlShadow = Color.clear
    static let thumbShadow = Color(light: 0x000000, dark: 0x000000, lightAlpha: 0.12, darkAlpha: 0.36)
    static let scrim = Color(light: 0x000000, dark: 0x000000, lightAlpha: 0.32, darkAlpha: 0.56)

    init(light: UInt32, dark: UInt32, black: UInt32? = nil, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(nsColor: .token(light: light, dark: dark, black: black, lightAlpha: lightAlpha, darkAlpha: darkAlpha))
    }

    var argb: UInt32? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let channel = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return 0xFF00_0000 | channel(color.redComponent) << 16 | channel(color.greenComponent) << 8
            | channel(color.blueComponent)
    }
}

/// The theme settings FlClash keeps in the core, applied over the system appearance.
enum Theme {
    static var pureBlack = false
    private static var appliedColor: UInt32?

    // crates/core/src/app_settings.rs keeps the same list as THEME_COLOR_PRESETS.
    static let defaultColor: UInt32 = 0xFF00_64E0
    static let presets: [UInt32] = [
        defaultColor, 0xFF24_694C, 0xFF58_56D6, 0xFFAF_52DE, 0xFFFF_2D55, 0xFFFF_9500, 0xFF34_C759, 0xFF30_B0C7,
        0xFF8E_8E93,
    ]

    @MainActor
    static func apply(_ settings: AppSettings?) {
        guard let settings else { return }
        let target = appearance(settings.themeMode)
        let keepsAppearance = Showcase.forcesAppearance || NSApp.appearance?.name == target?.name
        if appliedColor != nil, settings.themeColor != appliedColor || settings.pureBlack != pureBlack || !keepsAppearance {
            fadeWindows()
        }
        appliedColor = settings.themeColor
        pureBlack = settings.pureBlack
        if !Showcase.forcesAppearance { NSApp.appearance = target }
    }

    private static func appearance(_ mode: ThemeMode) -> NSAppearance? {
        switch mode {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    private static func fadeWindows() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        for window in NSApp.windows where window.isVisible {
            guard let view = window.contentView else { continue }
            view.wantsLayer = true
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.2
            view.layer?.add(fade, forKey: "theme")
        }
    }

    static func accent(_ argb: UInt32) -> Color {
        Color(nsColor: nsAccent(argb))
    }

    static func onAccent(_ argb: UInt32) -> Color {
        Color(nsColor: nsOnAccent(argb))
    }

    /// The other presets are Apple's system colours, so they keep their dark-mode variants.
    static func nsAccent(_ argb: UInt32) -> NSColor {
        switch argb {
        case 0xFF00_64E0, 0xFF00_7AFF: return .token(light: 0x0064E0, dark: 0x0171E3)
        case 0xFF24_694C: return .token(light: 0x24694C, dark: 0x80CEA8)
        case 0xFF58_56D6: return .systemIndigo
        case 0xFFAF_52DE: return .systemPurple
        case 0xFFFF_2D55: return .systemPink
        case 0xFFFF_9500: return .systemOrange
        case 0xFF34_C759: return .systemGreen
        case 0xFF30_B0C7: return .systemTeal
        case 0xFF8E_8E93: return .systemGray
        default: return NSColor(argb: argb)
        }
    }

    /// White until the accent is too light to carry it, which is where 3:1 contrast runs out.
    static func nsOnAccent(_ argb: UInt32) -> NSColor {
        let accent = nsAccent(argb)
        return NSColor(name: nil) { appearance in
            var luminance: CGFloat = 0
            appearance.performAsCurrentDrawingAppearance {
                luminance = Theme.relativeLuminance(accent)
            }
            return luminance > 0.3 ? NSColor(srgbRed: 0x0A / 255, green: 0x13 / 255, blue: 0x17 / 255, alpha: 1) : .white
        }
    }

    private static func relativeLuminance(_ color: NSColor) -> CGFloat {
        guard let color = color.usingColorSpace(.sRGB) else { return 0 }
        let linear = { (value: CGFloat) -> CGFloat in
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent)
            + 0.0722 * linear(color.blueComponent)
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
        content
            .accentColor(Theme.accent(model.themeColor))
            .environment(\.onAccent, Theme.onAccent(model.themeColor))
            .font(Ui.font)
            .monospacedDigit()
            .foregroundStyle(Color.ink)
            .buttonStyle(ActionButtonStyle())
            .id(model.appSettings?.pureBlack ?? false)
    }
}

private struct OnAccentKey: EnvironmentKey {
    static let defaultValue = Color.white
}

extension EnvironmentValues {
    var onAccent: Color {
        get { self[OnAccentKey.self] }
        set { self[OnAccentKey.self] = newValue }
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

    func setting<Value>(_ key: WritableKeyPath<AppSettings, Value>, or fallback: Value) -> Binding<Value> {
        Binding(
            get: { self.appSettings?[keyPath: key] ?? fallback },
            set: { value in self.updateAppSettings { $0[keyPath: key] = value } }
        )
    }

    /// The group the core reads the current node from: GLOBAL in global mode, otherwise the profile's first group.
    var primaryGroup: ProxyGroup? { groups.first }

    var exitIpText: String {
        guard let exit = exitIp else { return "—" }
        return exit.country.map { "\(exit.ip) · \($0)" } ?? exit.ip
    }

    var whitelistSummary: String {
        let entries = whitelist?.entries ?? []
        if whitelist?.enabled != true { return String(localized: "Off") }
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

extension Usage {
    var fraction: Double {
        min(Double(upload + download) / Double(max(total, 1)), 1)
    }
}

extension WhitelistOutcome {
    var title: String {
        switch self {
        case .applied: return String(localized: "Whitelisted")
        case .notApplied: return String(localized: "Not whitelisted")
        case .disabled: return String(localized: "Disabled")
        case .rejected: return String(localized: "Rejected")
        case .error: return String(localized: "Error")
        }
    }

    var tint: Color {
        switch self {
        case .applied: return .accentColor
        case .notApplied: return .warn
        case .disabled: return .ink3
        case .rejected, .error: return .bad
        }
    }
}
