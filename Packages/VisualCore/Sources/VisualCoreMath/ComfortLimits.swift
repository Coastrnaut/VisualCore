// ComfortLimits — feature 054 (A07-P01) T-A07-102 (FR-A07-102; gap G-CAMERARAIL; research D3).
// Motion-comfort limits for rail flights; the reduced-motion form honours the system Reduce Motion setting.

/// Limits that keep camera motion comfortable: speed, acceleration, turn rate, lateral sway and roll.
public struct ComfortLimits: Sendable, Equatable, Codable {
    /// Highest travel speed, world units per second.
    public var maxSpeed: Double
    /// Highest change of speed, world units per second squared.
    public var maxAcceleration: Double
    /// Highest turn rate of the look direction, radians per second (rails are built so that at `maxSpeed` the
    /// minimum turn radius is at least `maxSpeed ÷ maxTurnRate`).
    public var maxTurnRate: Double
    /// Amplitude of the lateral sway, world units (0 disables sway).
    public var swayAmplitude: Double
    /// Highest camera roll, radians (0: the horizon stays level).
    public var maxRoll: Double

    /// Creates limits from their five values.
    public init(maxSpeed: Double, maxAcceleration: Double, maxTurnRate: Double, swayAmplitude: Double,
                maxRoll: Double) {
        self.maxSpeed = maxSpeed
        self.maxAcceleration = maxAcceleration
        self.maxTurnRate = maxTurnRate
        self.swayAmplitude = swayAmplitude
        self.maxRoll = maxRoll
    }

    /// Standard comfort: 8 units/s, 1.5 units/s², 45°/s, sway 0.25 units, no roll.
    public static let standard = ComfortLimits(maxSpeed: 8, maxAcceleration: 1.5, maxTurnRate: .pi / 4,
                                               swayAmplitude: 0.25, maxRoll: 0)
    /// Reduced motion: 2.5 units/s, 0.75 units/s², 45°/s, no sway, no roll.
    public static let reducedMotion = ComfortLimits(maxSpeed: 2.5, maxAcceleration: 0.75, maxTurnRate: .pi / 4,
                                                    swayAmplitude: 0, maxRoll: 0)
}
