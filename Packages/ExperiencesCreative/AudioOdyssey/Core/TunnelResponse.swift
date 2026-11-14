// TunnelResponse — feature 055 (A07-P02) T-A07-204 (FR-A07-210, FR-A07-211; SC-A07-203; clarifications 3 and 5;
// data-model "TunnelResponse"). The bounded, step-limited audio response of the tunnel: the ripple amount (a radial
// breathing applied per piece at draw time) and the ambient light (brightness). Pure numbers; the experience maps the
// smoothed audio features to targets in 0…1 and calls `update` once per frame.
//
// Rules: ripple ∈ [0, 0.35] (rest 0.08), ambient ∈ [0.30, 0.70] (rest 0.35); a single update moves ripple by at most
// 0.02 and ambient by at most 0.03. Reduce Motion halves the ripple range ([0, 0.175]); Reduce Flashing halves the
// ambient range ([0.30, 0.50], the lower bound kept) and the ambient step (0.015). A target of 0 (silence) leads back
// to rest; a target of 1 leads to the upper bound.
import Foundation

/// The audio response of the tunnel: ripple amount and ambient light, bounded and step-limited per update.
public struct TunnelResponse: Sendable, Equatable {
    /// The ripple amount at rest (silence).
    public static let restRipple = 0.08
    /// The ambient light at rest (silence).
    public static let restAmbient = 0.35
    /// The full ripple range.
    public static let rippleBounds: ClosedRange<Double> = 0...0.35
    /// The ripple range under Reduce Motion (half the width of `rippleBounds`, same lower bound).
    public static let reducedRippleBounds: ClosedRange<Double> = 0...0.175
    /// The full ambient range.
    public static let ambientBounds: ClosedRange<Double> = 0.30...0.70
    /// The ambient range under Reduce Flashing (half the width of `ambientBounds`, same lower bound).
    public static let reducedAmbientBounds: ClosedRange<Double> = 0.30...0.50
    /// The largest change of the ripple amount in one update.
    public static let rippleStep = 0.02
    /// The largest change of the ambient light in one update.
    public static let ambientStep = 0.03
    /// The largest change of the ambient light in one update under Reduce Flashing.
    public static let reducedAmbientStep = 0.015
    /// The radial scale gained per unit of ripple: `breathingScale = 1 + ripple × breathingGain`.
    public static let breathingGain = 0.5

    /// Whether Reduce Motion was active when this response was made.
    public let reduceMotion: Bool
    /// Whether Reduce Flashing was active when this response was made.
    public let reduceFlashing: Bool
    /// The active ripple range.
    public let rippleRange: ClosedRange<Double>
    /// The active ambient range.
    public let ambientRange: ClosedRange<Double>
    /// The active ripple step limit per update.
    public let rippleStepLimit: Double
    /// The active ambient step limit per update.
    public let ambientStepLimit: Double
    /// The current ripple amount, always inside `rippleRange`.
    public private(set) var ripple: Double
    /// The current ambient light, always inside `ambientRange`.
    public private(set) var ambient: Double

    /// A response at rest with the ranges and steps of the given comfort settings.
    public init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        rippleRange = reduceMotion ? Self.reducedRippleBounds : Self.rippleBounds
        ambientRange = reduceFlashing ? Self.reducedAmbientBounds : Self.ambientBounds
        rippleStepLimit = Self.rippleStep
        ambientStepLimit = reduceFlashing ? Self.reducedAmbientStep : Self.ambientStep
        ripple = Self.clamp(Self.restRipple, to: rippleRange)
        ambient = Self.clamp(Self.restAmbient, to: ambientRange)
    }

    /// The ripple amount at rest inside the active range.
    public var rippleRest: Double { Self.clamp(Self.restRipple, to: rippleRange) }
    /// The ambient light at rest inside the active range.
    public var ambientRest: Double { Self.clamp(Self.restAmbient, to: ambientRange) }

    /// The uniform radial scale applied to every tunnel piece around the rail at draw time: `1 + ripple × 0.5`.
    public var breathingScale: Double { 1 + ripple * Self.breathingGain }

    /// Moves toward the targets: each target in 0…1 (clamped; NaN counts as 0) maps to `rest + t × (upper − rest)`,
    /// and each value moves toward its mapped target by at most its step limit.
    public mutating func update(rippleTarget: Double, ambientTarget: Double) {
        ripple = Self.approach(ripple, Self.map(rippleTarget, rest: rippleRest, range: rippleRange),
                               step: rippleStepLimit, range: rippleRange)
        ambient = Self.approach(ambient, Self.map(ambientTarget, rest: ambientRest, range: ambientRange),
                                step: ambientStepLimit, range: ambientRange)
    }

    /// The value a target in 0…1 maps to (NaN and values outside 0…1 are clamped first, NaN to 0).
    public static func map(_ target: Double, rest: Double, range: ClosedRange<Double>) -> Double {
        let t = target.isNaN ? 0 : min(max(target, 0), 1)
        return clamp(rest + t * (range.upperBound - rest), to: range)
    }

    private static func approach(_ value: Double, _ goal: Double, step: Double, range: ClosedRange<Double>) -> Double {
        let delta = min(max(goal - value, -step), step)
        return clamp(value + delta, to: range)
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
