// Easing.swift — standard easing curves (feature 006 T-F509; FR-F505; research R5, after Robert Penner's
// easing equations, re-implemented). Every curve satisfies f(0) = 0 and f(1) = 1 exactly; back and
// elastic overshoot in between by design.
import Foundation

public enum EasingCurve: String, CaseIterable, Sendable, Codable {
    case linear, quad, cubic, sine, expo, back, elastic, bounce
}

public enum EasingMode: String, CaseIterable, Sendable, Codable {
    case `in`, out, inOut
}

/// Eases `t` (clamped to [0, 1]) with `curve` in `mode`.
public func ease(_ t: Double, _ curve: EasingCurve, _ mode: EasingMode = .inOut) -> Double {
    guard t.isFinite else { return 0 }
    if t <= 0 { return 0 }
    if t >= 1 { return 1 }
    switch mode {
    case .in: return easeIn(t, curve)
    case .out: return 1 - easeIn(1 - t, curve)
    case .inOut: return t < 0.5 ? easeIn(2 * t, curve) / 2 : 1 - easeIn(2 - 2 * t, curve) / 2
    }
}

/// The "in" form of each curve on (0, 1); the other modes are derived from it.
private func easeIn(_ t: Double, _ curve: EasingCurve) -> Double {
    switch curve {
    case .linear: return t
    case .quad: return t * t
    case .cubic: return t * t * t
    case .sine: return 1 - cos(t * .pi / 2)
    case .expo: return t == 0 ? 0 : pow(2, 10 * t - 10)
    case .back:
        let c1 = 1.70158, c3 = c1 + 1
        return c3 * t * t * t - c1 * t * t
    case .elastic:
        let c4 = 2 * Double.pi / 3
        return -pow(2, 10 * t - 10) * sin((10 * t - 10.75) * c4)
    case .bounce:
        return 1 - bounceOut(1 - t)
    }
}

private func bounceOut(_ t: Double) -> Double {
    let n1 = 7.5625, d1 = 2.75
    if t < 1 / d1 { return n1 * t * t }
    if t < 2 / d1 { let u = t - 1.5 / d1; return n1 * u * u + 0.75 }
    if t < 2.5 / d1 { let u = t - 2.25 / d1; return n1 * u * u + 0.9375 }
    let u = t - 2.625 / d1
    return n1 * u * u + 0.984375
}
