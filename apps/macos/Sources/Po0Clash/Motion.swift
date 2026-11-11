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
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}
