// WorldResponse — feature 056 (A07-P03) T-A07-302 (FR-A07-311; SC-A07-304; clarification 4; research D4; data-model
// "WorldResponse"). The bounded, step-limited audio response of every world, generalising `TunnelResponse` (which stays
// as it is and equals the tunnel's case): the primary response (tunnel breathing amount, landscape height swell,
// star-corridor sparkle) and the light (ambient brightness). Pure numbers; the experience maps the envelope to targets
// in 0…1 through the world's `WorldMapping` and calls `update` once per frame.
//
// Rules: primary ∈ [0, max] with max tunnel 0.35, landscape 0.6, star corridor 1.0 (Reduce Motion halves the max); rest
// tunnel 0.08, landscape 0.1, star corridor 0.1 (clamped into the range); a single update moves primary by at most
// 0.02 × max / 0.35 (the full max). Light exactly as `TunnelResponse`'s ambient: [0.30, 0.70], rest 0.35, step 0.03;
// Reduce Flashing → [0.30, 0.50], step 0.015. A target t ∈ 0…1 (clamped, NaN → 0) maps to `rest + t × (upper − rest)`.
import Foundation

/// The audio response of one world: primary amount and light, bounded and step-limited per update.
public struct WorldResponse: Sendable, Equatable {
    /// The primary step of the tunnel; other worlds scale it by their max ÷ the tunnel's max.
    public static let basePrimaryStep = 0.02

    /// The largest primary amount of `world` without Reduce Motion: tunnel 0.35, landscape 0.6, star corridor 1.0.
    public static func maxPrimary(for world: JourneyWorld) -> Double {
        switch world {
        case .tunnel: TunnelResponse.rippleBounds.upperBound
        case .landscape: 0.6
        case .starCorridor: 1.0
        }
    }

    /// The primary amount of `world` at rest (silence): tunnel 0.08, landscape 0.1, star corridor 0.1.
    public static func restPrimary(for world: JourneyWorld) -> Double {
        switch world {
        case .tunnel: TunnelResponse.restRipple
        case .landscape, .starCorridor: 0.1
        }
    }

    /// The primary step limit of `world`: `0.02 × max / 0.35` (tunnel 0.02).
    public static func primaryStep(for world: JourneyWorld) -> Double {
        basePrimaryStep * (maxPrimary(for: world) / maxPrimary(for: .tunnel))
    }

    /// The world this response belongs to.
    public let world: JourneyWorld
    /// Whether Reduce Motion was active when this response was made.
    public let reduceMotion: Bool
    /// Whether Reduce Flashing was active when this response was made.
    public let reduceFlashing: Bool
    /// The active primary range.
    public let primaryRange: ClosedRange<Double>
    /// The active light range.
    public let lightRange: ClosedRange<Double>
    /// The active primary step limit per update.
    public let primaryStepLimit: Double
    /// The active light step limit per update.
    public let lightStepLimit: Double
    /// The current primary amount, always inside `primaryRange`.
    public private(set) var primary: Double
    /// The current light, always inside `lightRange`.
    public private(set) var light: Double

    /// A response of `world` at rest with the ranges and steps of the given comfort settings.
    public init(world: JourneyWorld, reduceMotion: Bool, reduceFlashing: Bool) {
        self.world = world
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        let maxPrimary = Self.maxPrimary(for: world)
        primaryRange = 0...(reduceMotion ? maxPrimary / 2 : maxPrimary)
        lightRange = reduceFlashing ? TunnelResponse.reducedAmbientBounds : TunnelResponse.ambientBounds
        primaryStepLimit = Self.primaryStep(for: world)
        lightStepLimit = reduceFlashing ? TunnelResponse.reducedAmbientStep : TunnelResponse.ambientStep
        primary = Self.clamp(Self.restPrimary(for: world), to: primaryRange)
        light = Self.clamp(TunnelResponse.restAmbient, to: lightRange)
    }

    /// The primary amount at rest inside the active range.
    public var primaryRest: Double { Self.clamp(Self.restPrimary(for: world), to: primaryRange) }
    /// The light at rest inside the active range.
    public var lightRest: Double { Self.clamp(TunnelResponse.restAmbient, to: lightRange) }

    /// The scale the presenter applies for the primary amount: tunnel radial breathing `1 + primary × 0.5`, landscape
    /// vertical scale of the strip `1 + primary`, star-corridor star scale `1 + primary × 0.6` (1…1.6).
    public var primaryScale: Double {
        switch world {
        case .tunnel: 1 + primary * TunnelResponse.breathingGain
        case .landscape: 1 + primary
        case .starCorridor: 1 + primary * 0.6
        }
    }

    /// Moves toward the targets: each target in 0…1 (clamped; NaN counts as 0) maps to `rest + t × (upper − rest)`,
    /// and each value moves toward its mapped target by at most its step limit.
    public mutating func update(primaryTarget: Double, lightTarget: Double) {
        primary = Self.approach(primary, TunnelResponse.map(primaryTarget, rest: primaryRest, range: primaryRange),
                                step: primaryStepLimit, range: primaryRange)
        light = Self.approach(light, TunnelResponse.map(lightTarget, rest: lightRest, range: lightRange),
                              step: lightStepLimit, range: lightRange)
    }

    private static func approach(_ value: Double, _ goal: Double, step: Double, range: ClosedRange<Double>) -> Double {
        let delta = min(max(goal - value, -step), step)
        return clamp(value + delta, to: range)
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
