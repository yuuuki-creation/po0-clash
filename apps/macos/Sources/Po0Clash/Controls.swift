import AppKit
import SwiftUI

/// The macOS sizes of docs/design/native-ui.
enum Ui {
    static let font = Font.system(size: 13)
    static let boldFont = Font.system(size: 13, weight: .semibold)
    static let codeFont = Font.system(size: 12, design: .monospaced)
    static let control: CGFloat = 28
    static let row: CGFloat = 42
    static let tableRow: CGFloat = 34
    static let padding: CGFloat = 14
    static let block: CGFloat = 14
    static let pageInset: CGFloat = 20
    static let maxWidth: CGFloat = 1100
    static let sidebarWidth: CGFloat = 212
    static let columnWidth: CGFloat = 340
    static let groupRadius: CGFloat = 10
    static let controlRadius: CGFloat = 6
}

// MARK: Buttons

struct ActionButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(configuration: configuration, primary: primary)
    }
}

private struct ActionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let primary: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.onAccent) private var onAccent

    private let shape = RoundedRectangle(cornerRadius: Ui.controlRadius, style: .continuous)

    var body: some View {
        configuration.label
            .font(Ui.font)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: Ui.control)
            .foregroundStyle(primary ? onAccent : Color.ink)
            .background(primary ? Color.accentColor : Color.controlSurface, in: shape)
            .overlay(shape.stroke(primary ? Color.clear : Color.controlRing, lineWidth: 0.5))
            .brightness(configuration.isPressed ? -0.08 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(shape)
    }
}

struct IconButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, tint: tint)
    }
}

private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color?
    @Environment(\.isEnabled) private var isEnabled

    private let shape = RoundedRectangle(cornerRadius: Ui.controlRadius, style: .continuous)

    var body: some View {
        configuration.label
            .frame(width: Ui.control, height: Ui.control)
            .foregroundStyle(tint ?? (configuration.isPressed ? Color.ink : Color.ink2))
            .background(configuration.isPressed ? Color.press : Color.clear, in: shape)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(shape)
    }
}

/// A full-width row: the fill darkens while held and there is no other chrome.
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowPressBody(configuration: configuration)
    }
}

private struct RowPressBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .foregroundStyle(Color.ink)
            .background(configuration.isPressed ? Color.press : Color.clear)
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Rectangle())
    }
}

struct IconButton: View {
    let symbol: String
    let help: LocalizedStringKey
    var busy = false
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if busy {
                Ring()
            } else {
                Image(systemName: symbol).font(.system(size: 15))
            }
        }
        .buttonStyle(IconButtonStyle(tint: tint))
        .disabled(busy)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

struct Ring: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turned = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(turned ? 360 : 0))
            .animation(reduceMotion ? nil : Animation.linear(duration: 0.8).repeatForever(autoreverses: false), value: turned)
            .onAppear {
                DispatchQueue.main.async { turned = true }
            }
    }
}

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 10
    var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(dimmed ? 0.3 : 1)
            .animation(pulsing && !reduceMotion ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: dimmed)
            .motion(Motion.dot, value: color)
            .onAppear { dimmed = pulsing && !reduceMotion }
            .onChange(of: pulsing) { pulsing in dimmed = pulsing && !reduceMotion }
    }
}

// MARK: Groups and rows

extension View {
    func cardSurface() -> some View {
        let shape = RoundedRectangle(cornerRadius: Ui.groupRadius, style: .continuous)
        return background(Color.card)
            .clipShape(shape)
            .overlay(shape.stroke(Color.stroke, lineWidth: 1))
    }

    /// Drawn one point up, so the group's clip removes it from the first row.
    func hairlineAbove() -> some View {
        overlay(alignment: .top) {
            Rectangle()
                .fill(Color.line)
                .frame(height: 1)
                .padding(.leading, Ui.padding)
                .offset(y: -1)
                .allowsHitTesting(false)
        }
    }
}

struct RowGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
    }
}

struct Row<Content: View>: View {
    private let height: CGFloat
    private let content: Content

    init(height: CGFloat = Ui.row, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, Ui.padding)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .hairlineAbove()
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.ink2)
    }
}

struct LinkRow<Value: View>: View {
    private let title: Text
    private let action: () -> Void
    private let value: Value

    init(_ title: Text, action: @escaping () -> Void, @ViewBuilder value: () -> Value) {
        self.title = title
        self.action = action
        self.value = value()
    }

    var body: some View {
        Button(action: action) {
            Row {
                title.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                value.foregroundStyle(Color.ink2).lineLimit(1)
                Chevron()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
    }
}

extension LinkRow where Value == EmptyView {
    init(_ title: Text, action: @escaping () -> Void) {
        self.init(title, action: action) { EmptyView() }
    }
}

struct ValueRow<Value: View>: View {
    private let title: Text
    private let value: Value

    init(_ title: Text, @ViewBuilder value: () -> Value) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        Row {
            title.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            value.foregroundStyle(Color.ink2).lineLimit(1).truncationMode(.middle)
        }
    }
}

/// A title beside a wide control, or above it when the two cannot share the row.
struct ControlRow<Control: View>: View {
    private let title: Text
    private let control: Control

    init(_ title: Text, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        Row {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    title.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    control
                }
                VStack(alignment: .leading, spacing: 6) {
                    title.lineLimit(1)
                    control
                }
                .padding(.vertical, 6)
            }
        }
    }
}

struct CheckRow: View {
    private let title: Text
    private let checked: Bool
    private let action: () -> Void

    init(_ title: Text, checked: Bool, action: @escaping () -> Void) {
        self.title = title
        self.checked = checked
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Row {
                CheckMark(visible: checked)
                title.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

struct CheckMark: View {
    let visible: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 14, height: 14)
            .opacity(visible ? 1 : 0)
    }
}

struct SettingsSection<Content: View>: View {
    private let title: LocalizedStringKey?
    private let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(Ui.boldFont) }
            RowGroup { content }
        }
    }
}

/// Text that reports a failure, selectable so it can be copied into a bug report.
struct ErrorText: View {
    let message: String

    var body: some View {
        Text(verbatim: message)
            .foregroundStyle(Color.bad)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyState: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 28)).foregroundStyle(Color.ink3)
            Text(title).foregroundStyle(Color.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.track)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: fraction > 0 ? max(proxy.size.width * fraction, 6) : 0)
            }
        }
        .frame(height: 6)
        .motion(Motion.bar, value: fraction)
    }
}

// MARK: Switch

struct SwitchControl: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Color.accentColor)
            .accessibilityValue(isOn ? Text("On") : Text("Off"))
    }
}

struct ToggleRow: View {
    private let title: Text
    @Binding private var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = Text(title)
        _isOn = isOn
    }

    init(verbatim title: String, isOn: Binding<Bool>) {
        self.title = Text(verbatim: title)
        _isOn = isOn
    }

    var body: some View {
        Row {
            title.frame(maxWidth: .infinity, alignment: .leading)
            SwitchControl(isOn: $isOn).accessibilityLabel(title)
        }
    }
}

// MARK: Segmented control

struct Segment<Value> {
    let value: Value
    let title: LocalizedStringKey

    init(_ value: Value, _ title: LocalizedStringKey) {
        self.value = value
        self.title = title
    }
}

struct SegmentedControl<Value: Equatable>: View {
    @Binding var selection: Value
    let segments: [Segment<Value>]

    private var selectedIndex: Binding<Int> {
        Binding(
            get: { segments.firstIndex { $0.value == selection } ?? 0 },
            set: { index in
                guard segments.indices.contains(index) else { return }
                selection = segments[index].value
            }
        )
    }

    var body: some View {
        Picker("", selection: selectedIndex) {
            ForEach(segments.indices, id: \.self) { index in
                Text(segments[index].title).tag(index)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize()
    }
}

// MARK: Fields

private struct FieldSurface: ViewModifier {
    let focused: Bool

    private let shape = RoundedRectangle(cornerRadius: Ui.controlRadius, style: .continuous)

    func body(content: Content) -> some View {
        content
            .background(Color.card, in: shape)
            .overlay(shape.stroke(Color.controlRing, lineWidth: 0.5))
            .overlay(
                shape.stroke(Color.accentColor.opacity(0.38), lineWidth: 3)
                    .padding(-1.5)
                    .opacity(focused ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .motion(Motion.focus, value: focused)
    }
}

private struct FieldChrome: ViewModifier {
    let autofocus: Bool
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focused($focused)
            .padding(.horizontal, 8)
            .frame(minHeight: Ui.control)
            .modifier(FieldSurface(focused: focused))
            .onAppear {
                guard autofocus else { return }
                DispatchQueue.main.async { focused = true }
            }
    }
}

extension View {
    /// For a `TextField` or `SecureField`.
    func fieldChrome(autofocus: Bool = false) -> some View {
        modifier(FieldChrome(autofocus: autofocus))
    }

    /// For a multi-line editor, which brings its own focus handling.
    func editorChrome() -> some View {
        modifier(FieldSurface(focused: false))
    }
}

struct FieldRow<Field: View>: View {
    private let title: Text
    private let field: Field

    init(_ title: LocalizedStringKey, @ViewBuilder field: () -> Field) {
        self.title = Text(title)
        self.field = field()
    }

    init(verbatim title: String, @ViewBuilder field: () -> Field) {
        self.title = Text(verbatim: title)
        self.field = field()
    }

    var body: some View {
        Row {
            title.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            field.fieldChrome().frame(maxWidth: 280)
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.ink2)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ink2)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Ui.control)
        .modifier(FieldSurface(focused: focused))
        .frame(minWidth: 110, idealWidth: 220, maxWidth: 220)
        .background(
            Button {
                focused = true
            } label: {
                EmptyView()
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f")
            .opacity(0)
            .accessibilityHidden(true)
        )
        .onExitCommand { text = "" }
    }
}

