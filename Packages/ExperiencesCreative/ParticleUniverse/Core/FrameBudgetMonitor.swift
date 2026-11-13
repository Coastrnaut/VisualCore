// FrameBudgetMonitor.swift — feature 037 A04-P05 T-A04-505 (US2; FR-A04-510 to FR-A04-514; research D1; clarification 1;
// contracts/monitor.md). Turns the times of drawn frames into a requested detail tier: more than 25% of the last 120
// recorded frames over 1.2× the budget steps down one tier, at least 95% of the last 600 recorded frames under 0.8× the
// budget steps up one tier, and both windows restart after a change, so detail moves at most one tier per window.
// Pure and deterministic; the presenter draws at the coarser of this tier and the host's (heat and Low Power Mode win).

/// Requests a drawn detail tier (0 = full detail … `maxTier`) from the times of the frames drawn.
///
/// A window is decided only once it holds its full number of recorded frames (120 for stepping down, 600 for stepping
/// up); after a change, or after `restart()`, both windows start empty again. Times that are not finite or not
/// positive are ignored, as if the frame had not been drawn.
public struct FrameBudgetMonitor: Equatable, Sendable {
    /// Frames in the step-down window.
    public static let slowWindow = 120
    /// Frames in the step-up window.
    public static let fastWindow = 600
    /// A frame is slow above this multiple of the budget.
    public static let slowFactor = 1.2
    /// A frame is fast below this multiple of the budget.
    public static let fastFactor = 0.8
    /// More than this many slow frames in a full step-down window step down (25% of 120).
    public static let slowLimit = slowWindow / 4
    /// At least this many fast frames in a full step-up window step up (95% of 600).
    public static let fastQuota = fastWindow * 95 / 100

    /// The frame budget in seconds (the display's frame interval).
    public let budget: Double
    /// The coarsest tier this monitor requests.
    public let maxTier: Int
    /// The requested tier, within `0...maxTier`.
    public private(set) var tier = 0

    private var slowFlags: Ring
    private var fastFlags: Ring

    /// Creates a monitor at `tier` (default 0, clamped to `0...maxTier`) for frames of `budget` seconds (default
    /// 1/60 s) and tiers `0...maxTier` (default 3); a non-positive or non-finite budget falls back to 1/60 s and a
    /// negative `maxTier` to 0. A monitor rebuilt for a new budget passes the old tier (T-A04-516).
    public init(budget: Double = 1.0 / 60, maxTier: Int = 3, tier: Int = 0) {
        self.budget = budget.isFinite && budget > 0 ? budget : 1.0 / 60
        self.maxTier = max(maxTier, 0)
        self.tier = min(max(tier, 0), self.maxTier)
        slowFlags = Ring(capacity: Self.slowWindow)
        fastFlags = Ring(capacity: Self.fastWindow)
    }

    /// Records the time of one drawn frame in seconds and returns the requested tier. A step down wins over a step
    /// up (the two cannot hold together: 31 slow frames leave at most 569 fast ones in the 600). A change restarts
    /// both windows; a tier already at its bound does not change and the windows keep sliding.
    @discardableResult
    public mutating func record(frameTime: Double) -> Int {
        guard frameTime.isFinite, frameTime > 0 else { return tier }
        slowFlags.push(frameTime > budget * Self.slowFactor)
        fastFlags.push(frameTime < budget * Self.fastFactor)
        if slowFlags.isFull, slowFlags.trueCount > Self.slowLimit, tier < maxTier {
            tier += 1
            restart()
        } else if fastFlags.isFull, fastFlags.trueCount >= Self.fastQuota, tier > 0 {
            tier -= 1
            restart()
        }
        return tier
    }

    /// Clears both windows and keeps the tier (pause, background, resume, a new graphics context).
    public mutating func restart() {
        slowFlags.clear()
        fastFlags.clear()
    }
}

/// The display's frame interval, estimated from the target presentation times the host reports (T-A04-516,
/// FR-A04-510).
///
/// The host's frame time is counted from its start while the target timestamp is a media-clock reading, so their
/// difference is not an interval; the steps between the targets of consecutive frames are. A late frame skips whole
/// display intervals, so its step is a multiple of the interval: the estimate is the smallest step seen since the
/// last `reset()`. Steps outside 1/240 s … 1/10 s, steps across a gap in the frame index and non-finite targets are
/// ignored; until a step is accepted the estimate is nil.
public struct FrameIntervalEstimate: Equatable, Sendable {
    /// The shortest accepted step in seconds (240 Hz).
    public static let shortest = 1.0 / 240
    /// The longest accepted step in seconds (10 Hz).
    public static let longest = 0.1

    /// The estimated interval in seconds, or nil before the first accepted step.
    public private(set) var interval: Double?
    private var last: (index: Int, target: Double)?

    /// An estimate with no steps seen.
    public init() {}

    /// Notes the frame `index` with target presentation time `target` and returns the current estimate.
    @discardableResult
    public mutating func observe(index: Int, target: Double) -> Double? {
        guard target.isFinite else { return interval }
        defer { last = (index, target) }
        guard let last, index == last.index + 1 else { return interval }
        let step = target - last.target
        guard step >= Self.shortest, step <= Self.longest else { return interval }
        interval = min(interval ?? step, step)
        return interval
    }

    /// Forgets every step (a new graphics context or session).
    public mutating func reset() {
        interval = nil
        last = nil
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.interval == b.interval && a.last?.index == b.last?.index && a.last?.target == b.last?.target
    }
}

/// A fixed-capacity ring of flags that counts its true entries.
private struct Ring: Equatable, Sendable {
    private var flags: [Bool] = []
    private var next = 0
    private let capacity: Int
    /// The number of true flags held.
    private(set) var trueCount = 0

    init(capacity: Int) { self.capacity = capacity }

    /// Whether the ring holds `capacity` flags.
    var isFull: Bool { flags.count == capacity }

    /// Appends `flag`, dropping the oldest when full.
    mutating func push(_ flag: Bool) {
        if flags.count < capacity {
            flags.append(flag)
        } else {
            if flags[next] { trueCount -= 1 }
            flags[next] = flag
            next = (next + 1) % capacity
        }
        if flag { trueCount += 1 }
    }

    /// Empties the ring.
    mutating func clear() {
        flags.removeAll(keepingCapacity: true)
        next = 0
        trueCount = 0
    }
}
