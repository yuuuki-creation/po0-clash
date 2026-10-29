import Po0FFI
import SwiftUI

enum Format {
    static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .file)
    }

    static func rate(_ value: UInt64) -> String {
        bytes(value) + "/s"
    }

    static func date(_ unixSeconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(unixSeconds))
    }

    static func delay(_ node: Node) -> String? {
        guard let delay = node.delay else { return nil }
        return delay == 0 ? String(localized: "Timeout") : "\(delay) ms"
    }
}

/// Liquid Glass belongs to the floating control layer only (HIG, macOS 26); content sits on opaque grouped
/// surfaces like a grouped `Form`.
extension View {
    func groupedSection() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
