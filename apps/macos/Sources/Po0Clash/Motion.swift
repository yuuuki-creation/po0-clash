import SwiftUI

enum Motion {
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let quick = Animation.spring(response: 0.22, dampingFraction: 0.9)
}

extension View {
    func motion<Value: Equatable>(_ animation: Animation = Motion.spring, value: Value) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    func rollingDigits() -> some View {
        contentTransition(.numericText())
    }

    @ViewBuilder
    func replacingSymbol() -> some View {
        if #available(macOS 14, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    @ViewBuilder
    func pulsing(_ active: Bool) -> some View {
        if #available(macOS 14, *) {
            symbolEffect(.pulse, isActive: active)
        } else {
            self
        }
    }

    func hoverHighlight<S: InsettableShape>(_ shape: S) -> some View {
        modifier(HoverHighlight(shape: shape))
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

private struct HoverHighlight<S: InsettableShape>: ViewModifier {
    let shape: S
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .overlay(shape.fill(Color.primary.opacity(hovering ? 0.05 : 0)).allowsHitTesting(false))
            .onHover { hovering = $0 }
            .motion(Motion.quick, value: hovering)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .motion(Motion.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

struct PageEntrance: ViewModifier {
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !enabled ? 1 : 0)
            .offset(y: shown || !enabled || reduceMotion ? 0 : 10)
            .onAppear { withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) { shown = true } }
    }
}

extension View {
    /// On macOS 26 a pinned header lets the content scroll under its glass, as the toolbar does; before, it stays opaque.
    @ViewBuilder
    func pinnedHeaderBackground() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            self
        } else {
            background(Color.pageBackground)
        }
        #else
        background(Color.pageBackground)
        #endif
    }
}
