// AmbientCore — feature 132 T-A18-203 (FR-A18-2xx; G-OVERLAY/G-BUDGETS). The state of Ambient Clock as an
// experience (clarification Q1): numbers only, so replays and digests stay deterministic. The core never reads a
// clock, a locale or a time zone; the presenter (`AmbientPresenter`) reads the injected clock source and environment
// and formats the text with the A18-P01 model (`AmbientClockState`).
//
// Fields: the instant (seconds since 1970, 0 until the first `time.set`), the hour cycle (0 system, 1 h12, 2 h24),
// seconds shown (default off), the date line shown (default on), motion (default on), the speed (0.25–2, default 1)
// and the time-change revision (+1 per accepted `time.changed`). The quality tier is presentation only: it is not in
// `==`, the digest or the snapshot, and it is kept across `reset()` (as Infinite Geometry's `GeometryCore`).
//
// Actions (numbers; the engine refuses a value outside the declared range, a non-finite value and a wrong value count
// before the core sees it; called directly, the core refuses an unknown control and a wrong count itself):
//   time.set [0…4.1e9]           the instant from the presenter's clock source.
//   time.changed [0…4]           a time-change event, the index of its kind in `TimeChangeKind.allCases` (foreground,
//                                significantTime, timeZone, locale, calendarDay); a value that is not a whole index is
//                                refused with `a18.invalid-choice`. The revision grows by one.
//   clock.format [0…2, 0…1, 0…1] hour cycle, seconds, date; the cycle must be a whole index, seconds and date
//                                exactly 0 or 1 (`a18.invalid-choice` otherwise).
//   theme.motion [0…1]           exactly 0 (still) or 1 (moving); `a18.invalid-choice` otherwise.
//   theme.speed [0.25…2]         the background's speed.
// A refusal changes nothing.
//
// Digest: the format and theme fields (hour cycle, seconds, date, motion, speed). The instant and the revision are
// derived from the wall clock and its notifications, so — as `ExperienceCore.writeDigest` requires of anything
// derived from a clock — they stay out of the digest; they are not stored either (FR-A18-209), so a snapshot round
// trip keeps the digest. Snapshot schema 1: `{"hourCycle", "showDate", "showSeconds", "motion", "speed"}` as JSON
// with sorted keys; decoding refuses a value outside its range.
//
// Quality (G-BUDGETS, FR-A18-208): `level-0` (5 noise octaves at the full resolution) and `level-1` (3 octaves at
// half resolution: resolutionShare 0.5, iterationShare 0.6); each level makes exactly one full-screen draw. The
// octaves are the level's iteration share of 5, rounded.
//
// Outcome: `motion-off` while motion is off, else `showing-time`.
import AmbientClockCore
import Foundation
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// The rule codes of Ambient Clock's refusals.
public enum AmbientRule {
    /// A value that is not a whole index, or a switch other than exactly 0 or 1.
    public static let invalidChoice = "a18.invalid-choice"
}

/// Why a stored Ambient Clock state is refused.
public enum AmbientRestoreError: Error, Equatable {
    /// A field of the payload lies outside its range (its key is named).
    case outOfRange(String)
}

/// The state of Ambient Clock (see the file header). Snapshot schema 1.
public struct AmbientCore: ExperienceCore, Equatable, Codable {
    /// The experience's id in the catalog.
    public static let experienceID = "a18.ambient-clock"
    /// The action ids in declaration order.
    public static let actionIDs = ["time.set", "time.changed", "clock.format", "theme.motion", "theme.speed"]
    /// The number of values each action carries, by action id.
    static let valueCounts: [String: Int] = ["time.set": 1, "time.changed": 1, "clock.format": 3,
                                             "theme.motion": 1, "theme.speed": 1]
    /// The largest instant `time.set` accepts, seconds since 1970 (about the year 2099).
    public static let maxInstant = 4.1e9
    /// The range of the background's speed.
    public static let speedRange: ClosedRange<Double> = 0.25...2
    /// The default speed.
    public static let defaultSpeed = 1.0
    /// The octaves of the noise at the best quality level.
    public static let fullOctaves = 5
    /// The outcome code while motion is on.
    public static let showingTimeCode = "showing-time"
    /// The outcome code while motion is off.
    public static let motionOffCode = "motion-off"

    /// The last instant set, seconds since 1970; 0 until the first `time.set` (not stored, not in the digest).
    public private(set) var instant: Double = 0
    /// The hour cycle: 0 system, 1 h12, 2 h24 (the order of `HourCycle.allCases`).
    public private(set) var hourCycle: Int = 0
    /// Whether the seconds are shown (default false).
    public private(set) var showSeconds = false
    /// Whether the date line is shown (default true).
    public private(set) var showDate = true
    /// Whether the background moves (default true).
    public private(set) var motion = true
    /// The background's speed, 0.25–2 (default 1).
    public private(set) var speed: Double = AmbientCore.defaultSpeed
    /// The number of accepted `time.changed` actions (not stored, not in the digest).
    public private(set) var revision: Int = 0
    /// The quality tier the host set (0 = level-0, 1 = level-1, clamped); presentation only — not in the digest,
    /// the snapshot or `==`.
    public private(set) var qualityTier = 0

    /// The opening state: no instant yet, the system hour cycle, no seconds, the date line, motion on at speed 1.
    public init() {}

    /// A state with the given format and theme fields (every value is clamped into its range; the hour cycle is
    /// rounded).
    public init(hourCycle: Int, showSeconds: Bool, showDate: Bool, motion: Bool, speed: Double) {
        self.hourCycle = min(max(hourCycle, 0), HourCycle.allCases.count - 1)
        self.showSeconds = showSeconds
        self.showDate = showDate
        self.motion = motion
        self.speed = speed.isFinite ? min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound)
            : Self.defaultSpeed
    }

    // MARK: Derived

    /// The hour cycle as the A18-P01 model names it.
    public var hourCycleValue: HourCycle { Self.hourCycle(index: hourCycle) }

    /// The A18-P01 preferences of the format fields (the zone and locale policies are the system's; their editor is
    /// A18-P03).
    public var preferences: ClockPreferences {
        Self.preferences(hourCycle: hourCycle, showSeconds: showSeconds, showDate: showDate)
    }

    /// The instant as a date; nil until the first `time.set`.
    public var date: Date? { instant > 0 ? Date(timeIntervalSince1970: instant) : nil }

    /// The hour cycle with index `index` (clamped to 0…2): system, h12, h24.
    public static func hourCycle(index: Int) -> HourCycle {
        HourCycle.allCases[min(max(index, 0), HourCycle.allCases.count - 1)]
    }

    /// The index of `cycle` in `HourCycle.allCases` (0 system, 1 h12, 2 h24).
    public static func index(of cycle: HourCycle) -> Int {
        HourCycle.allCases.firstIndex(of: cycle) ?? 0
    }

    /// The A18-P01 preferences of the format fields `hourCycle` (index, clamped), `showSeconds` and `showDate`, with
    /// the system zone and locale policies.
    public static func preferences(hourCycle: Int, showSeconds: Bool, showDate: Bool) -> ClockPreferences {
        ClockPreferences(hourCycle: Self.hourCycle(index: hourCycle), showSeconds: showSeconds, showDate: showDate)
    }

    /// The three `clock.format` values of `preferences`: the hour cycle's index, seconds and date as 0 or 1.
    public static func formatValues(_ preferences: ClockPreferences) -> [Double] {
        [Double(index(of: preferences.hourCycle)), preferences.showSeconds ? 1 : 0, preferences.showDate ? 1 : 0]
    }

    /// The `time.changed` value of `kind`: its index in `TimeChangeKind.allCases`.
    public static func value(of kind: TimeChangeKind) -> Double {
        Double(TimeChangeKind.allCases.firstIndex(of: kind) ?? 0)
    }

    // MARK: Quality (G-BUDGETS)

    /// Two quality tiers: level-0 and level-1.
    public static var qualityTiers: Int { 2 }

    /// `level-0`: the full resolution and iteration shares; `level-1`: resolution share 0.5 and iteration share 0.6.
    /// Element shares are 1 and no level has an effect pass (one full-screen draw each).
    public static var qualityProfile: QualityProfile {
        let levels = [QualityLevel(name: "level-0", resolutionShare: 1, iterationShare: 1),
                      QualityLevel(name: "level-1", resolutionShare: 0.5, iterationShare: 0.6)]
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: levels.count)
    }

    /// The noise octaves drawn at `tier` (clamped to the profile): 5 × the level's iteration share, rounded, at
    /// least 1 — 5 at level-0 and 3 at level-1.
    public static func octaves(forTier tier: Int) -> Int {
        let share = qualityProfile.level(min(max(tier, 0), qualityTiers - 1)).iterationShare
        return max(1, Int((Double(fullOctaves) * share).rounded()))
    }

    /// The pixel block edge drawn at `tier` (clamped): 1 ÷ the level's resolution share, rounded, at least 1 — 1 at
    /// level-0 and 2 at level-1 (one noise sample per 2 × 2 pixels).
    public static func pixelBlock(forTier tier: Int) -> Int {
        let share = qualityProfile.level(min(max(tier, 0), qualityTiers - 1)).resolutionShare
        return max(1, Int((1 / share).rounded()))
    }

    /// Stores `tier` clamped to 0 ..< `qualityTiers`; the state and its digest do not change.
    public mutating func setQualityTier(_ tier: Int) {
        qualityTier = min(max(tier, 0), Self.qualityTiers - 1)
    }

    /// Equal states: every stored value except the presentation-only `qualityTier`.
    public static func == (lhs: AmbientCore, rhs: AmbientCore) -> Bool {
        lhs.instant == rhs.instant && lhs.hourCycle == rhs.hourCycle && lhs.showSeconds == rhs.showSeconds
            && lhs.showDate == rhs.showDate && lhs.motion == rhs.motion && lhs.speed == rhs.speed
            && lhs.revision == rhs.revision
    }

    // MARK: Contract

    /// Schema 1, the first; no migration.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 1)
    }

    /// The five controls with their declared ranges (see the file header).
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "time.set", ranges: [0...maxInstant]),
         ExperienceControl(id: "time.changed", ranges: [0...Double(TimeChangeKind.allCases.count - 1)]),
         ExperienceControl(id: "clock.format", ranges: [0...Double(HourCycle.allCases.count - 1), 0...1, 0...1]),
         ExperienceControl(id: "theme.motion", ranges: [0...1]),
         ExperienceControl(id: "theme.speed", ranges: [speedRange])]
    }

    /// The opening state; the seed changes nothing (nothing is random) and no clock is read.
    public static func prepare(seed: UInt64) async throws -> AmbientCore {
        try Task.checkCancellation()
        return AmbientCore()
    }

    /// A host step changes nothing: the time enters only as `time.set`, and the motion is drawn from the frame time.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        if let index = v.firstIndex(where: { !$0.isFinite }) { return .rejected(.nonFinite(index: index)) }
        let invalid = ActionResult.rejected(.rule(code: AmbientRule.invalidChoice))
        switch action.control {
        case "time.set":
            guard (0...Self.maxInstant).contains(v[0]) else { return .rejected(.outOfRange(index: 0)) }
            instant = v[0]
        case "time.changed":
            guard Self.choice(v[0], count: TimeChangeKind.allCases.count) != nil else { return invalid }
            revision += 1
        case "clock.format":
            guard let cycle = Self.choice(v[0], count: HourCycle.allCases.count),
                  let seconds = Self.flag(v[1]), let date = Self.flag(v[2]) else { return invalid }
            hourCycle = cycle
            showSeconds = seconds
            showDate = date
        case "theme.motion":
            guard let on = Self.flag(v[0]) else { return invalid }
            motion = on
        default:   // theme.speed
            guard Self.speedRange.contains(v[0]) else { return .rejected(.outOfRange(index: 0)) }
            speed = v[0]
        }
        return .accepted
    }

    /// The index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// The switch named by `value`: exactly 0 (false) or 1 (true); nil otherwise.
    static func flag(_ value: Double) -> Bool? {
        value == 0 ? false : value == 1 ? true : nil
    }

    /// Back to the opening state; the quality tier, which is not state, is kept.
    public mutating func reset() {
        let tier = qualityTier
        self = AmbientCore()
        qualityTier = tier
    }

    /// `motion-off` while motion is off, else `showing-time`.
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: motion ? Self.showingTimeCode : Self.motionOffCode)
    }

    /// "a18.ambient.v1", then the hour cycle, seconds, date, motion and speed (the instant and the revision come from
    /// the clock and stay out; see the file header).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add("a18.ambient.v1")
        builder.add(hourCycle)
        builder.add(showSeconds)
        builder.add(showDate)
        builder.add(motion)
        try builder.add(speed)
    }

    // MARK: Snapshot

    private enum CodingKeys: String, CodingKey {
        case hourCycle, showSeconds, showDate, motion, speed
    }

    /// Decodes the schema-1 fields; a value outside its range throws ``AmbientRestoreError/outOfRange(_:)``. The
    /// instant and the revision start at 0 (the presenter sends the time again).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let cycle = try c.decode(Int.self, forKey: .hourCycle)
        guard (0..<HourCycle.allCases.count).contains(cycle) else {
            throw AmbientRestoreError.outOfRange(CodingKeys.hourCycle.rawValue)
        }
        let speed = try c.decode(Double.self, forKey: .speed)
        guard speed.isFinite, Self.speedRange.contains(speed) else {
            throw AmbientRestoreError.outOfRange(CodingKeys.speed.rawValue)
        }
        hourCycle = cycle
        showSeconds = try c.decode(Bool.self, forKey: .showSeconds)
        showDate = try c.decode(Bool.self, forKey: .showDate)
        motion = try c.decode(Bool.self, forKey: .motion)
        self.speed = speed
    }

    /// Encodes the schema-1 fields: hour cycle, seconds, date, motion and speed (not the instant, the revision or the
    /// quality tier).
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(hourCycle, forKey: .hourCycle)
        try c.encode(showSeconds, forKey: .showSeconds)
        try c.encode(showDate, forKey: .showDate)
        try c.encode(motion, forKey: .motion)
        try c.encode(speed, forKey: .speed)
    }
}
