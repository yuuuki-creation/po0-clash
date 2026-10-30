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

    /// The Flutter app's thresholds: a timeout is red, under 600 ms green, anything slower orange.
    static func delayTint(_ delay: UInt32?) -> Color {
        switch delay {
        case 0?: return .badText
        case let delay? where delay < 600: return .goodText
        case .some: return .warnText
        case nil: return .secondary
        }
    }

    static func nodeCount(_ count: Int) -> String {
        count == 1 ? String(localized: "1 node") : String(localized: "\(count) nodes")
    }

    /// "2.59 GB" as its number and unit, so the unit can be set smaller and grey.
    static func parts(_ text: String) -> (value: String, unit: String) {
        guard let space = text.lastIndex(where: \.isWhitespace) else { return (text, "") }
        return (String(text[..<space]), String(text[text.index(after: space)...]))
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

/// docs/development/native-design.md in macOS 26's grouped-form colours, so cards match the settings pages: a white
/// page, faint grey cards on it, white tiles inside the cards.
extension Color {
    static let pageBackground = Color(light: 0xFFFFFF, dark: 0x1E1E1E, black: 0x000000)
    static let cardBackground = Color(light: 0xF7F7F7, dark: 0x252525, black: 0x161616)
    static let tileBackground = Color(light: 0xFFFFFF, dark: 0x303030, black: 0x262626)
    static let controlFill = Color(light: 0x767680, dark: 0x767680, lightAlpha: 0.12, darkAlpha: 0.24)
    static let cardEdge = Color(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.05, darkAlpha: 0.06)
    static let goodText = Color(light: 0x1E7F35, dark: 0x30D158)
    static let warnText = Color(light: 0xB25000, dark: 0xFF9F0A)
    static let badText = Color(light: 0xD70015, dark: 0xFF6961)

    init(light: UInt32, dark: UInt32, black: UInt32? = nil, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? (Theme.pureBlack ? black ?? dark : dark) : light
            return NSColor(
                srgbRed: CGFloat(hex >> 16 & 0xFF) / 255,
                green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }
}

/// The theme settings FlClash keeps in the core, applied over the system appearance.
enum Theme {
    static var pureBlack = false
    static let defaultColor: UInt32 = 0xFF00_7AFF
    static let presets: [UInt32] = [
        defaultColor, 0xFF58_56D6, 0xFFAF_52DE, 0xFFFF_2D55, 0xFFFF_9500, 0xFF34_C759, 0xFF30_B0C7, 0xFF8E_8E93,
    ]

    @MainActor
    static func apply(_ settings: AppSettings?) {
        guard let settings else { return }
        pureBlack = settings.pureBlack
        guard !Showcase.forcesAppearance else { return }
        switch settings.themeMode {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// The presets are Apple's system colours, so they keep their dark-mode variants.
    static func accent(_ argb: UInt32) -> Color {
        switch argb {
        case 0xFF00_7AFF: return Color(nsColor: .systemBlue)
        case 0xFF58_56D6: return Color(nsColor: .systemIndigo)
        case 0xFFAF_52DE: return Color(nsColor: .systemPurple)
        case 0xFFFF_2D55: return Color(nsColor: .systemPink)
        case 0xFFFF_9500: return Color(nsColor: .systemOrange)
        case 0xFF34_C759: return Color(nsColor: .systemGreen)
        case 0xFF30_B0C7: return Color(nsColor: .systemTeal)
        case 0xFF8E_8E93: return Color(nsColor: .systemGray)
        default: return Color(argb: argb)
        }
    }
}

struct AppTheme: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        let accent = Theme.accent(model.appSettings?.themeColor ?? Theme.defaultColor)
        content
            .tint(accent)
            .accentColor(accent)
            .id(model.appSettings?.pureBlack ?? false)
    }
}

extension Color {
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double(argb >> 16 & 0xFF) / 255,
            green: Double(argb >> 8 & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double(argb >> 24 & 0xFF) / 255
        )
    }

    var argb: UInt32? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let channel = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return 0xFF00_0000 | channel(color.redComponent) << 16 | channel(color.greenComponent) << 8
            | channel(color.blueComponent)
    }
}

struct Metric: View {
    private let value: String
    private let unit: String
    private let size: CGFloat

    init(_ text: String, size: CGFloat = 26) {
        (value, unit) = Format.parts(text)
        self.size = size
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if !unit.isEmpty {
                Text(unit).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}

struct CircleButton: View {
    let symbol: String
    let help: LocalizedStringKey
    var size: CGFloat = 24
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if busy {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: symbol).font(.system(size: size * 0.46, weight: .semibold))
                }
            }
            .frame(width: size, height: size)
            .background(Color.controlFill, in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

struct SearchField: View {
    @Binding var text: String
    let prompt: LocalizedStringKey
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(prompt, text: $text).textFieldStyle(.plain).focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.controlFill, in: Capsule())
        .onAppear { focused = true }
        .onExitCommand { text = "" }
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
    }
}

/// Liquid Glass belongs to the floating control layer only (HIG, macOS 26); content sits on opaque grouped
/// surfaces like a grouped `Form`.
extension View {
    func cardSurface(radius: CGFloat = 14) -> some View {
        background(Color.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

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
                buttonStyle(.glassProminent)
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
    func buttonBorderShapeCapsule() -> some View {
        if #available(macOS 14, *) {
            buttonBorderShape(.capsule)
        } else {
            self
        }
    }

    @ViewBuilder
    private func plainButton(prominent: Bool) -> some View {
        if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}

/// A row of floating controls; on macOS 26 its glass buttons share one container so they render as one layer.
struct ControlBar<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            GlassEffectContainer {
                HStack(spacing: 8) { content }.glassButton()
            }
        } else {
            HStack(spacing: 8) { content }.glassButton()
        }
        #else
        HStack(spacing: 8) { content }.glassButton()
        #endif
    }
}

struct EmptyRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

    var symbol: String {
        switch self {
        case .applied: return "checkmark.circle.fill"
        case .notApplied: return "minus.circle"
        case .disabled: return "pause.circle"
        case .rejected, .error: return "xmark.octagon"
        }
    }

    var tint: Color {
        switch self {
        case .applied: return .green
        case .notApplied: return .orange
        case .disabled: return .secondary
        case .rejected, .error: return .red
        }
    }
}
