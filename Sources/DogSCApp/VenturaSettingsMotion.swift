import SwiftUI

extension View {
    @ViewBuilder
    func dogscPulse<Trigger: Equatable>(trigger: Trigger, depth: CGFloat = 0.90,
                                      duration: Double = 0.32) -> some View {
        if #available(macOS 14.0, *) {
            keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, scale in
                view.scaleEffect(RecorderMotion.reduces ? 1 : scale)
            } keyframes: { _ in
                CubicKeyframe(depth, duration: 0.08)
                SpringKeyframe(1, duration: duration, spring: Spring(duration: duration, bounce: 0.18))
            }
        } else {
            modifier(VenturaPulse(trigger: trigger, depth: depth, duration: duration))
        }
    }

    @ViewBuilder
    func dogscBellMotion(ringing: Bool) -> some View {
        if #available(macOS 14.0, *) {
            keyframeAnimator(initialValue: 0.0, trigger: ringing) { view, angle in
                view.rotationEffect(.degrees(RecorderMotion.reduces ? 0 : angle), anchor: .top)
            } keyframes: { _ in
                if ringing {
                    CubicKeyframe(16, duration: 0.08)
                    CubicKeyframe(-13, duration: 0.12)
                    CubicKeyframe(9, duration: 0.12)
                    CubicKeyframe(-5, duration: 0.12)
                    SpringKeyframe(0, duration: 0.3, spring: Spring(duration: 0.3, bounce: 0.2))
                } else {
                    CubicKeyframe(0, duration: 0.01)
                }
            }
        } else {
            modifier(VenturaBell(ringing: ringing))
        }
    }

    func dogscRipple(active: Bool) -> some View {
        modifier(VenturaRipple(active: active))
    }
}

private struct VenturaPulse<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let depth: CGFloat
    let duration: Double
    @State private var hasAppeared = false
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.scaleEffect(scale).task(id: trigger) {
            guard hasAppeared else { hasAppeared = true; return }
            guard !RecorderMotion.reduces else { scale = 1; return }
            withAnimation(.easeOut(duration: 0.08)) { scale = depth }
            do { try await Task.sleep(for: .seconds(0.08)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: duration, dampingFraction: 0.82)) { scale = 1 }
        }
    }
}

private struct VenturaBell: ViewModifier {
    let ringing: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(angle), anchor: .top).task(id: ringing) {
            guard ringing, !RecorderMotion.reduces else { angle = 0; return }
            for next in [16.0, -13, 9, -5, 0] {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.12)) { angle = next }
                do { try await Task.sleep(for: .seconds(0.12)) } catch { return }
            }
        }
    }
}

private struct VenturaRipple: ViewModifier {
    let active: Bool
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content.scaleEffect(scale).opacity(opacity).task(id: active) {
            guard active, !RecorderMotion.reduces else { opacity = 0; return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { scale = 1; opacity = 0.8 }
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.7)) { scale = 1.6; opacity = 0 }
        }
    }
}
