// SceneClock.swift — a deterministic play/pause/scrub clock for animated scenes (feature 013 T-A01-201; gap G-CLOCK;
// contract specs/013-gas-p02-scene-controls/contracts/api.md). Time comes only from frame deltas, never the wall clock.

/// Scene time driven by frame deltas: play, pause, scrub, speed (0…4×) and a Reduce Motion rate (0.5×). A single delta
/// is capped at `maxDelta` so returning from the background never jumps; time wraps at `duration`.
public struct SceneClock: Sendable, Equatable {
    /// Largest delta applied by one `advance(by:)` (seconds).
    public static let maxDelta = 0.25
    /// Playback-rate multiplier while `reducedMotion` is on.
    public static let reducedMotionFactor = 0.5
    /// Allowed speed range.
    public static let speedRange = 0.0...4.0

    /// Length of the timeline in seconds; time wraps to 0 when it reaches this.
    public let duration: Double
    /// Current time, 0 ≤ time < duration.
    public private(set) var time: Double = 0
    /// Whether `advance(by:)` moves time.
    public private(set) var isPlaying: Bool
    /// Playback speed, clamped to 0…4.
    public var speed: Double { didSet { speed = speed.isFinite ? min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound) : oldValue } }
    /// Halves the playback rate (scrubbing and paused time are unaffected).
    public var reducedMotion = false

    /// A clock at time 0; a non-finite or non-positive duration becomes 120 s.
    public init(duration: Double = 120, speed: Double = 1, isPlaying: Bool = true) {
        self.duration = duration.isFinite && duration > 0 ? duration : 120
        self.speed = speed.isFinite ? min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound) : 1
        self.isPlaying = isPlaying
    }

    /// Advances by a frame delta while playing: `min(max(delta, 0), maxDelta) × speed × (reducedMotion ? 0.5 : 1)`,
    /// wrapping at `duration`. Non-finite deltas are ignored.
    public mutating func advance(by delta: Double) {
        guard isPlaying, delta.isFinite else { return }
        let step = min(max(delta, 0), Self.maxDelta) * speed * (reducedMotion ? Self.reducedMotionFactor : 1)
        time = (time + step).truncatingRemainder(dividingBy: duration)
    }

    /// Sets the time directly, clamped to 0…duration (the end maps to just before `duration`). Non-finite is ignored.
    public mutating func scrub(to newTime: Double) {
        guard newTime.isFinite else { return }
        time = min(max(newTime, 0), duration.nextDown)
    }

    /// Starts advancing.
    public mutating func play() { isPlaying = true }
    /// Stops advancing; time is kept.
    public mutating func pause() { isPlaying = false }
    /// Switches between playing and paused.
    public mutating func toggle() { isPlaying.toggle() }
}
