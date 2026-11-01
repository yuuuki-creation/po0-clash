import SwiftUI

/// The macOS column of docs/design/native-ui: durations in seconds, with Reduce Motion everything lands at once.
enum Motion {
    static let control = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.2)
    static let sidebar = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.25)
    static let press = Animation.easeOut(duration: 0.12)
    static let fill = Animation.linear(duration: 0.2)
    static let dot = Animation.easeInOut(duration: 0.2)
    static let bar = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3)
    static let hairline = Animation.linear(duration: 0.15)
    static let focus = Animation.linear(duration: 0.12)
    static let subpage = Animation.linear(duration: 0.12)
    static let dialogIn = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.2)
    static let dialogOut = Animation.timingCurve(0.4, 0, 1, 1, duration: 0.15)
    static let rowIn = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.25)
    static let rowOut = Animation.timingCurve(0.4, 0, 1, 1, duration: 0.2)
}

extension View {
    func motion<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    func rowListMotion<ID: Equatable>(ids: [ID]) -> some View {
        modifier(RowListMotion(ids: ids))
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

private struct RowListMotion<ID: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ids: [ID]
    @State private var shownCount: Int?

    func body(content: Content) -> some View {
        let grew = ids.count >= (shownCount ?? ids.count)
        content
            .animation(reduceMotion ? nil : grew ? Motion.rowIn : Motion.rowOut, value: ids)
            .onAppear { shownCount = ids.count }
            .onChange(of: ids.count) { count in shownCount = count }
    }
}

private struct RowFold: ViewModifier {
    let folded: Bool

    func body(content: Content) -> some View {
        content
            .frame(height: folded ? 0 : nil, alignment: .top)
            .clipped()
            .opacity(folded ? 0 : 1)
    }
}

extension AnyTransition {
    static var rowFold: AnyTransition {
        .modifier(active: RowFold(folded: true), identity: RowFold(folded: false))
    }
}
