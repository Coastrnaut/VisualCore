// JourneyState — feature 054 (A07-P01) T-A07-103 (FR-A07-111, FR-A07-121; data-model "JourneyState", schema 1). The
// domain state of Audio Odyssey: the world, the unwrapped travelled distance, the speed choice, the current speed, the
// seed of the rail and the worlds, and whether the flight is paused. All fields are persisted and part of the digest.
//
// Rules: `distance` and `speed` are finite and ≥ 0. A decoded payload that breaks a rule (NaN, infinity, a negative
// value, an unknown world or speed choice) is refused with `DecodingError.dataCorrupted`; the mutating methods ignore
// such values and report it.
import Foundation

/// The speed choices of the flight (clarification 2): slow 2, medium 4, fast 7 units per second. The raw values are
/// persisted.
public enum SpeedChoice: Int, CaseIterable, Codable, Sendable {
    /// 2 units per second.
    case slow = 0
    /// 4 units per second (the first choice).
    case medium = 1
    /// 7 units per second.
    case fast = 2

    /// The target speed in units per second, before the active comfort limits clamp it.
    public var unitsPerSecond: Double {
        switch self {
        case .slow: 2
        case .medium: 4
        case .fast: 7
        }
    }

    /// The name shown in the speed picker and spoken in the canvas description.
    public var displayName: String {
        switch self {
        case .slow: "Slow"
        case .medium: "Medium"
        case .fast: "Fast"
        }
    }
}

/// The state of Audio Odyssey. Schema version 1.
public struct JourneyState: Sendable, Equatable, Codable {
    /// The schema version of the persisted fields.
    public static let schemaVersion = 1
    /// The step `reseed()` adds to the seed (the golden-ratio increment).
    public static let seedStep: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// The world drawn around the rail.
    public private(set) var world: JourneyWorld
    /// The travelled distance along the rail in units, unwrapped (it keeps growing past the rail's length); finite, ≥ 0.
    public private(set) var distance: Double
    /// The chosen speed.
    public private(set) var speedChoice: SpeedChoice
    /// The current speed in units per second (eased toward the choice); finite, ≥ 0.
    public private(set) var speed: Double
    /// The seed of the rail and of every world piece.
    public private(set) var seed: UInt64
    /// Whether the flight is paused.
    public private(set) var paused: Bool

    /// A state; a distance or speed that is not finite and ≥ 0 becomes 0.
    public init(seed: UInt64, world: JourneyWorld = .tunnel, distance: Double = 0, speedChoice: SpeedChoice = .medium,
                speed: Double = 0, paused: Bool = false) {
        self.seed = seed
        self.world = world
        self.distance = Self.isUsable(distance) ? distance : 0
        self.speedChoice = speedChoice
        self.speed = Self.isUsable(speed) ? speed : 0
        self.paused = paused
    }

    /// Whether `value` is allowed as a distance or speed: finite and ≥ 0.
    public static func isUsable(_ value: Double) -> Bool { value.isFinite && value >= 0 }

    /// Selects `world`; distance and speed are kept.
    public mutating func select(_ world: JourneyWorld) { self.world = world }

    /// Selects the speed choice; the current speed eases toward it in the flight.
    public mutating func select(_ speedChoice: SpeedChoice) { self.speedChoice = speedChoice }

    /// Pauses (`true`) or resumes (`false`) the flight; distance and speed are kept.
    public mutating func setPaused(_ paused: Bool) { self.paused = paused }

    /// Moves to the next seed (adds `seedStep`, wrapping); distance, world and speed are kept.
    public mutating func reseed() { seed &+= Self.seedStep }

    /// Records the flight's distance and speed; returns `false` and changes nothing when either is not finite and ≥ 0.
    @discardableResult
    public mutating func update(distance: Double, speed: Double) -> Bool {
        guard Self.isUsable(distance), Self.isUsable(speed) else { return false }
        self.distance = distance
        self.speed = speed
        return true
    }

    /// The canonical text of every field for the experience digest: the distance in Swift's shortest round-trip form
    /// and the speed rounded to 1e-6 (as an integer count of micro-units).
    public var digestText: String {
        let micro = Int64((speed * 1e6).rounded())
        return "a07.journey.v\(Self.schemaVersion)|world=\(world.rawValue)|distance=\(distance)"
            + "|speedChoice=\(speedChoice.rawValue)|speedMicro=\(micro)|seed=\(seed)|paused=\(paused ? 1 : 0)"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case world, distance, speedChoice, speed, seed, paused }

    /// Decodes and validates a state; refuses non-finite or negative distance and speed and unknown enum values.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let world = try c.decode(JourneyWorld.self, forKey: .world)
        let distance = try c.decode(Double.self, forKey: .distance)
        let speedChoice = try c.decode(SpeedChoice.self, forKey: .speedChoice)
        let speed = try c.decode(Double.self, forKey: .speed)
        let seed = try c.decode(UInt64.self, forKey: .seed)
        let paused = try c.decode(Bool.self, forKey: .paused)
        guard Self.isUsable(distance) else {
            throw DecodingError.dataCorruptedError(forKey: .distance, in: c,
                                                   debugDescription: "distance \(distance) is not finite and ≥ 0")
        }
        guard Self.isUsable(speed) else {
            throw DecodingError.dataCorruptedError(forKey: .speed, in: c,
                                                   debugDescription: "speed \(speed) is not finite and ≥ 0")
        }
        self.init(seed: seed, world: world, distance: distance, speedChoice: speedChoice, speed: speed, paused: paused)
    }

    /// Encodes every field under its own name.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(world, forKey: .world)
        try c.encode(distance, forKey: .distance)
        try c.encode(speedChoice, forKey: .speedChoice)
        try c.encode(speed, forKey: .speed)
        try c.encode(seed, forKey: .seed)
        try c.encode(paused, forKey: .paused)
    }
}
