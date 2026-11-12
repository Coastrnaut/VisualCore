// QualityPolicy.swift — quality tiers stepped by thermal state and Low Power Mode, with hysteresis (feature 021
// T-A02-301; gap G-QUALITY; spec 021 clarification 4; research R1–R2). Apps define what each tier means (solver
// iterations, particle counts, effect passes). The policy only decides which tier to use. Decisions are deterministic:
// time is passed in, so behavior can be tested exactly on the host.

/// Chooses a quality tier (0 = best) from the device's thermal state and Low Power Mode.
///
/// - Steps one tier down when the thermal state is serious or critical, or when Low Power Mode is on and the tier is
///   better than `lowPowerCeiling`.
/// - Steps one tier up after `calmPeriod` seconds of calm: a nominal or fair thermal state without Low Power Mode.
/// - Changes at most once per `decisionInterval` seconds, never below the last tier.
public struct QualityPolicy: Sendable, Equatable {
    /// Number of tiers (≥ 1); tier 0 is the best.
    public let tierCount: Int
    /// The best tier allowed while Low Power Mode is on (0…tierCount − 1).
    public let lowPowerCeiling: Int
    /// Minimum seconds between two tier changes (default 2).
    public let decisionInterval: Double
    /// Seconds of calm needed before stepping up one tier (default 10).
    public let calmPeriod: Double
    /// The current tier.
    public private(set) var tier = 0
    /// Tier changes toward lower quality.
    public private(set) var stepsDown = 0
    /// Tier changes toward higher quality.
    public private(set) var stepsUp = 0
    private var lastChange: Double?
    private var calmSince: Double?

    /// Invalid values fall back: `tierCount` < 1 becomes 1, the ceiling is clamped to the tier range, and
    /// non-positive or non-finite intervals become 2 s and 10 s.
    public init(tierCount: Int, lowPowerCeiling: Int = 1, decisionInterval: Double = 2, calmPeriod: Double = 10) {
        self.tierCount = max(1, tierCount)
        self.lowPowerCeiling = min(max(lowPowerCeiling, 0), self.tierCount - 1)
        self.decisionInterval = decisionInterval.isFinite && decisionInterval > 0 ? decisionInterval : 2
        self.calmPeriod = calmPeriod.isFinite && calmPeriod > 0 ? calmPeriod : 10
    }

    /// Updates and returns the tier for the state observed at `now` (seconds, monotonic). A non-finite `now` keeps
    /// the current tier.
    public mutating func decide(thermal: FramePacing.Thermal, lowPower: Bool, now: Double) -> Int {
        guard now.isFinite else { return tier }
        let canChange = lastChange.map { now - $0 >= decisionInterval } ?? true
        let hot = thermal == .serious || thermal == .critical
        if hot || (lowPower && tier < lowPowerCeiling) {
            calmSince = nil
            if canChange, tier < tierCount - 1 {
                tier += 1
                stepsDown += 1
                lastChange = now
            }
            return tier
        }
        guard !lowPower else {
            calmSince = nil
            return tier
        }
        let since = calmSince ?? now
        calmSince = since
        if tier > 0, now - since >= calmPeriod, canChange {
            tier -= 1
            stepsUp += 1
            lastChange = now
            calmSince = now
        }
        return tier
    }

    /// Forgets timing and keeps the tier: the calm period and the decision interval start again at the next
    /// decision (feature 192: an experience that resumes after a suspension must not count the time it was away
    /// as calm).
    public mutating func forgetTiming() {
        lastChange = nil
        calmSince = nil
    }

    /// Returns to the best tier and forgets timing (for example when a screen opens again).
    public mutating func reset() {
        tier = 0
        lastChange = nil
        calmSince = nil
    }
}
