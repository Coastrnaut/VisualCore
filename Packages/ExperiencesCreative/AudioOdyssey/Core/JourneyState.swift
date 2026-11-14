// JourneyState — feature 054 (A07-P01) T-A07-103 (FR-A07-111, FR-A07-121; data-model "JourneyState", schema 1). The
// domain state of Audio Odyssey: the world, the unwrapped travelled distance, the speed choice, the current speed, the
// seed of the rail and the worlds, and whether the flight is paused. All fields are persisted and part of the digest.
// Feature 055 (A07-P02) T-A07-204 (FR-A07-220; data-model "JourneyState" schema 2): adds the audio `source`; a schema-1
// payload without it decodes as the demo signal, and the digest text ends with `|source=<raw value>`.
// Feature 056 (A07-P03) T-A07-302 (FR-A07-301–303, FR-A07-312, FR-A07-330; clarifications 2, 3 and 5; data-model
// "JourneyState" schema 3): the stored speed choice becomes the continuous `speedTarget` (0.5…7 units/s in 0.5 steps;
// `speedChoice` is now the nearest preset, `select(_: SpeedChoice)` presets the target to 2/4/7), and the state gains
// `easing`, `calmMotion` and the per-world `mappings`. A schema-1/2 payload (with `speedChoice`, without the new keys)
// maps slow/medium/fast to 2/4/7 and takes the defaults; a schema-3 payload must carry `speedTarget`, `easing`,
// `calmMotion` and three `mappings`. The digest text is `v3`, drops `speedChoice` and ends with
// `|speedTarget=<Double>|easing=<raw>|calm=<0|1>|map=<tunnel>-<landscape>-<star corridor>` (`WorldMapping.digestText`).
//
// Rules: `distance` and `speed` are finite and ≥ 0; `speedTarget` is in 0.5…7 on the 0.5 grid. A decoded payload that
// breaks a rule (NaN, infinity, a negative value, a speed target outside 0.5…7, an unknown world, speed choice, source,
// easing, channel or sensitivity, a mapping count other than 3) is refused with `DecodingError.dataCorrupted` (a
// schema-3 speed target inside the range but off the grid is snapped); the mutating methods ignore or clamp such values
// and report it.
import Foundation

/// The speed presets of the flight (clarification 2 of feature 054): slow 2, medium 4, fast 7 units per second. Since
/// schema 3 they preset the continuous speed target; the raw values appear only in schema-1/2 payloads.
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

    /// The preset nearest to `speed` (a tie goes to the slower preset).
    public static func nearest(to speed: Double) -> SpeedChoice {
        allCases.min { abs($0.unitsPerSecond - speed) < abs($1.unitsPerSecond - speed) } ?? .medium
    }
}

/// The state of Audio Odyssey. Schema version 3 (schema 2 with the continuous speed target, easing, calm motion and
/// the per-world mappings).
public struct JourneyState: Sendable, Equatable, Codable {
    /// The schema version of the persisted fields.
    public static let schemaVersion = 3
    /// The step `reseed()` adds to the seed (the golden-ratio increment).
    public static let seedStep: UInt64 = 0x9E37_79B9_7F4A_7C15
    /// The range of the speed target in units per second.
    public static let speedTargetRange: ClosedRange<Double> = 0.5...7
    /// The grid of the speed target (the slider step) in units per second.
    public static let speedTargetStep = 0.5
    /// The speed target of a new state (the medium preset).
    public static let defaultSpeedTarget = SpeedChoice.medium.unitsPerSecond

    /// The world drawn around the rail.
    public private(set) var world: JourneyWorld
    /// The travelled distance along the rail in units, unwrapped (it keeps growing past the rail's length); finite, ≥ 0.
    public private(set) var distance: Double
    /// The chosen speed in units per second, in 0.5…7 on the 0.5 grid, before the active comfort limits clamp it.
    public private(set) var speedTarget: Double
    /// The current speed in units per second (eased toward the target); finite, ≥ 0.
    public private(set) var speed: Double
    /// The seed of the rail and of every world piece.
    public private(set) var seed: UInt64
    /// Whether the flight is paused.
    public private(set) var paused: Bool
    /// The chosen audio source (feature 055); the demo signal by default.
    public private(set) var source: SourceKind
    /// The camera easing (feature 056); standard by default.
    public private(set) var easing: Easing
    /// The in-app calm-motion setting (feature 056); off by default. The effective calm motion is this or the system
    /// Reduce Motion.
    public private(set) var calmMotion: Bool
    /// The mapping of every world, in world order (always three).
    public private(set) var mappings: [WorldMapping]

    /// A state; a distance or speed that is not finite and ≥ 0 becomes 0, the speed target is clamped and snapped (NaN
    /// becomes 4), and mappings whose count is not 3 become the defaults.
    public init(seed: UInt64, world: JourneyWorld = .tunnel, distance: Double = 0,
                speedTarget: Double = JourneyState.defaultSpeedTarget, speed: Double = 0, paused: Bool = false,
                source: SourceKind = .demo, easing: Easing = .standard, calmMotion: Bool = false,
                mappings: [WorldMapping] = WorldMapping.allDefaults) {
        self.seed = seed
        self.world = world
        self.distance = Self.isUsable(distance) ? distance : 0
        self.speedTarget = Self.snappedSpeedTarget(speedTarget) ?? Self.defaultSpeedTarget
        self.speed = Self.isUsable(speed) ? speed : 0
        self.paused = paused
        self.source = source
        self.easing = easing
        self.calmMotion = calmMotion
        self.mappings = mappings.count == JourneyWorld.allCases.count ? mappings : WorldMapping.allDefaults
    }

    /// A state whose speed target is the preset `speedChoice` (source compatibility with schema 1/2 callers).
    public init(seed: UInt64, world: JourneyWorld = .tunnel, distance: Double = 0, speedChoice: SpeedChoice,
                speed: Double = 0, paused: Bool = false, source: SourceKind = .demo) {
        self.init(seed: seed, world: world, distance: distance, speedTarget: speedChoice.unitsPerSecond, speed: speed,
                  paused: paused, source: source)
    }

    /// Whether `value` is allowed as a distance or speed: finite and ≥ 0.
    public static func isUsable(_ value: Double) -> Bool { value.isFinite && value >= 0 }

    /// `value` clamped to 0.5…7 and snapped to the 0.5 grid; `nil` when it is not finite.
    public static func snappedSpeedTarget(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        let clamped = min(max(value, speedTargetRange.lowerBound), speedTargetRange.upperBound)
        return (clamped / speedTargetStep).rounded() * speedTargetStep
    }

    /// The speed preset nearest to the speed target (a tie goes to the slower preset).
    public var speedChoice: SpeedChoice { SpeedChoice.nearest(to: speedTarget) }

    /// The mapping of `world`.
    public func mapping(for world: JourneyWorld) -> WorldMapping { mappings[world.rawValue] }

    /// Selects `world`; distance, speed and every mapping are kept.
    public mutating func select(_ world: JourneyWorld) { self.world = world }

    /// Presets the speed target to `speedChoice` (2, 4 or 7); the current speed eases toward it in the flight.
    public mutating func select(_ speedChoice: SpeedChoice) { speedTarget = speedChoice.unitsPerSecond }

    /// Selects the audio source; distance, speed and world are kept.
    public mutating func select(_ source: SourceKind) { self.source = source }

    /// Sets the speed target, clamped to 0.5…7 and snapped to the 0.5 grid; returns `false` and changes nothing when
    /// `value` is not finite.
    @discardableResult
    public mutating func setSpeedTarget(_ value: Double) -> Bool {
        guard let snapped = Self.snappedSpeedTarget(value) else { return false }
        speedTarget = snapped
        return true
    }

    /// Selects the camera easing.
    public mutating func setEasing(_ easing: Easing) { self.easing = easing }

    /// Turns the in-app calm motion on or off.
    public mutating func setCalmMotion(_ calmMotion: Bool) { self.calmMotion = calmMotion }

    /// Replaces the mapping of `world`; the other worlds keep theirs.
    public mutating func setMapping(_ mapping: WorldMapping, for world: JourneyWorld) { mappings[world.rawValue] = mapping }

    /// Returns every world to its default mapping.
    public mutating func resetMappings() { mappings = WorldMapping.allDefaults }

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

    /// The canonical text of every field for the experience digest: the distance and the speed target in Swift's
    /// shortest round-trip form, the speed rounded to 1e-6 (as an integer count of micro-units) and the mappings in
    /// world order (`WorldMapping.digestText` joined by `-`).
    public var digestText: String {
        let micro = Int64((speed * 1e6).rounded())
        return "a07.journey.v\(Self.schemaVersion)|world=\(world.rawValue)|distance=\(distance)"
            + "|speedMicro=\(micro)|seed=\(seed)|paused=\(paused ? 1 : 0)|source=\(source.rawValue)"
            + "|speedTarget=\(speedTarget)|easing=\(easing.rawValue)|calm=\(calmMotion ? 1 : 0)"
            + "|map=\(mappings.map(\.digestText).joined(separator: "-"))"
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case world, distance, speedChoice, speedTarget, speed, seed, paused, source, easing, calmMotion, mappings
    }

    /// Decodes and validates a state; refuses non-finite or negative distance and speed, unknown enum values, a speed
    /// target outside 0.5…7 and a mapping count other than 3. A payload with `speedTarget` is schema 3 and must carry
    /// `easing`, `calmMotion` and `mappings`; otherwise it is schema 1/2: `speedChoice` sets the target (2/4/7), a
    /// missing `source` is the demo signal and the new fields take their defaults.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let world = try c.decode(JourneyWorld.self, forKey: .world)
        let distance = try c.decode(Double.self, forKey: .distance)
        let speed = try c.decode(Double.self, forKey: .speed)
        let seed = try c.decode(UInt64.self, forKey: .seed)
        let paused = try c.decode(Bool.self, forKey: .paused)
        let source = try c.decodeIfPresent(SourceKind.self, forKey: .source) ?? .demo
        guard Self.isUsable(distance) else {
            throw DecodingError.dataCorruptedError(forKey: .distance, in: c,
                                                   debugDescription: "distance \(distance) is not finite and ≥ 0")
        }
        guard Self.isUsable(speed) else {
            throw DecodingError.dataCorruptedError(forKey: .speed, in: c,
                                                   debugDescription: "speed \(speed) is not finite and ≥ 0")
        }
        let speedTarget: Double
        let easing: Easing
        let calmMotion: Bool
        let mappings: [WorldMapping]
        if c.contains(.speedTarget) {
            let target = try c.decode(Double.self, forKey: .speedTarget)
            guard target.isFinite, Self.speedTargetRange.contains(target), let snapped = Self.snappedSpeedTarget(target)
            else {
                throw DecodingError.dataCorruptedError(forKey: .speedTarget, in: c,
                                                       debugDescription: "speed target \(target) is not in 0.5…7")
            }
            speedTarget = snapped
            easing = try c.decode(Easing.self, forKey: .easing)
            calmMotion = try c.decode(Bool.self, forKey: .calmMotion)
            mappings = try c.decode([WorldMapping].self, forKey: .mappings)
            guard mappings.count == JourneyWorld.allCases.count else {
                throw DecodingError.dataCorruptedError(forKey: .mappings, in: c,
                                                       debugDescription: "\(mappings.count) mappings, expected 3")
            }
        } else {
            speedTarget = try c.decode(SpeedChoice.self, forKey: .speedChoice).unitsPerSecond
            easing = .standard
            calmMotion = false
            mappings = WorldMapping.allDefaults
        }
        self.init(seed: seed, world: world, distance: distance, speedTarget: speedTarget, speed: speed, paused: paused,
                  source: source, easing: easing, calmMotion: calmMotion, mappings: mappings)
    }

    /// Encodes every schema-3 field under its own name (no `speedChoice`).
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(world, forKey: .world)
        try c.encode(distance, forKey: .distance)
        try c.encode(speedTarget, forKey: .speedTarget)
        try c.encode(speed, forKey: .speed)
        try c.encode(seed, forKey: .seed)
        try c.encode(paused, forKey: .paused)
        try c.encode(source, forKey: .source)
        try c.encode(easing, forKey: .easing)
        try c.encode(calmMotion, forKey: .calmMotion)
        try c.encode(mappings, forKey: .mappings)
    }
}
