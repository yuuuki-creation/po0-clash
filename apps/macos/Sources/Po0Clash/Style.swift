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

extension View {
    /// Liquid Glass only on macOS 26; earlier systems keep a plain grouped background.
    @ViewBuilder
    func card() -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(Color.primary.opacity(0.05), in: shape)
        }
        #else
        background(Color.primary.opacity(0.05), in: shape)
        #endif
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
