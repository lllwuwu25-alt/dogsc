import Foundation

/// The underdamped spring used by native window-height transitions on Ventura.
/// Position and velocity are sampled from the same analytic solution so a
/// changed target can start from the current motion without a visible jump.
public struct CompatibilitySpring: Sendable {
    public let response: Double
    public let dampingRatio: Double

    public init(response: Double, dampingRatio: Double) {
        self.response = max(response, 0.001)
        self.dampingRatio = min(max(dampingRatio, 0.001), 0.999)
    }

    public var settlingDuration: TimeInterval {
        // Bound residual envelope to 0.01% for the app's window-size range.
        log(10_000) / (dampingRatio * 2 * .pi / response)
    }

    public func value(target: CGFloat, initialVelocity: CGFloat, time: TimeInterval) -> CGFloat {
        let state = sample(target: Double(target), velocity: Double(initialVelocity), time: time)
        return CGFloat(Double(target) + state.position)
    }

    public func velocity(target: CGFloat, initialVelocity: CGFloat, time: TimeInterval) -> CGFloat {
        CGFloat(sample(target: Double(target), velocity: Double(initialVelocity), time: time).velocity)
    }

    private func sample(target: Double, velocity: Double, time: TimeInterval) -> (position: Double, velocity: Double) {
        let omega = 2 * Double.pi / response
        let decay = dampingRatio * omega
        let frequency = omega * sqrt(1 - dampingRatio * dampingRatio)
        let t = max(time, 0)
        let a = -target
        let b = (velocity - decay * target) / frequency
        let cosine = cos(frequency * t), sine = sin(frequency * t)
        let envelope = exp(-decay * t)
        let displacement = a * cosine + b * sine
        return (envelope * displacement,
                envelope * (-decay * displacement - a * frequency * sine + b * frequency * cosine))
    }
}
