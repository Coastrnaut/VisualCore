// QualityGovernor — feature 192 T-U06-006 (UA-F06; FR-U06-010 to FR-U06-012, FR-U06-014). Decides which quality
// level of an experience is in force: the pinned level, or the tier of the existing `QualityPolicy` (thermal state
// and Low Power Mode with hysteresis). Decisions are deterministic: time is passed in, so behavior can be tested
// exactly on the host.

/// Chooses the quality level in force (0 = best) for an experience with `levelCount` levels.
///
/// - In automatic mode (no pin) the level is the tier of a `QualityPolicy` with the Low Power ceiling
///   `min(1, levelCount − 1)`, a decision interval of 2 s and a calm period of 10 s.
/// - With a pin the level is the pin, clamped to the level range, and no policy decision is taken.
/// - Decisions are taken at most once per `minimumInterval` seconds.
public struct QualityGovernor: Sendable, Equatable {
    /// Minimum seconds between two policy decisions (1).
    public static let minimumInterval: Double = 1

    /// Number of levels (1…8); level 0 is the best.
    public let levelCount: Int
    /// The pinned level, or nil in automatic mode. Stored as given; `levelInForce` clamps it to the level range.
    public private(set) var pin: Int?

    private var policy: QualityPolicy
    private var lastDecision: Double?

    /// Creates a governor. `levelCount` is clamped to 1…8; a negative pin is treated as level 0 and a pin beyond
    /// the last level as the last level.
    public init(levelCount: Int, pin: Int? = nil) {
        let count = min(max(levelCount, 1), 8)
        self.levelCount = count
        self.pin = pin
        self.policy = QualityPolicy(tierCount: count, lowPowerCeiling: min(1, count - 1))
    }

    /// The level in force: the pin clamped to 0…`levelCount` − 1, or the policy's tier in automatic mode.
    public var levelInForce: Int {
        if let pin {
            return min(max(pin, 0), levelCount - 1)
        }
        return policy.tier
    }

    /// Level changes toward lower quality taken by the policy.
    public var stepsDown: Int { policy.stepsDown }

    /// Level changes toward higher quality taken by the policy.
    public var stepsUp: Int { policy.stepsUp }

    /// Takes a decision for the conditions observed at `now` (seconds, monotonic) and returns the level in force.
    ///
    /// A non-finite `now` changes nothing. With a pin no policy decision is taken. In automatic mode the policy is
    /// asked only when no decision was taken yet or at least `minimumInterval` seconds passed since the last one
    /// (a `now` before the last decision changes nothing).
    @discardableResult
    public mutating func decide(conditions: DeviceConditions, now: Double) -> Int {
        guard now.isFinite else { return levelInForce }
        guard pin == nil else { return levelInForce }
        if let last = lastDecision, now - last < Self.minimumInterval {
            return levelInForce
        }
        _ = policy.decide(thermal: conditions.thermal, lowPower: conditions.lowPower, now: now)
        lastDecision = now
        return levelInForce
    }

    /// Pins a level, or returns to automatic mode with nil. Changing from a pin to automatic starts the policy
    /// again from level 0 with its timing forgotten. Setting the same value changes nothing.
    public mutating func setPin(_ pin: Int?) {
        guard pin != self.pin else { return }
        let wasPinned = self.pin != nil
        self.pin = pin
        if pin == nil, wasPinned {
            policy.reset()
            lastDecision = nil
        }
    }

    /// Forgets the timing after a suspension, so that the calm period starts again; the level does not change.
    public mutating func resume() {
        policy.forgetTiming()
        lastDecision = nil
    }
}
