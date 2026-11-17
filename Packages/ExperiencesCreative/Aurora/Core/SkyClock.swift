// SkyClock — feature 152 (A21-P01) T-A21-107 (FR-A21-106; clarification Q4). The sky's animation time: a
// `SceneClock` with a 600 s period and the scene's speed (0…2), advanced only by drawn-frame deltas (each step at most
// 0.25 s × speed, so a long gap never jumps). Under Reduce Motion, or at speed 0, the clock holds its time, so
// consecutive frames are identical; `SceneClock`'s half-speed Reduce Motion factor is not used. The shader takes
// `phase = time / 600`. Pure; the clock reads no wall clock.
import VisualCoreSimulation

/// The sky's frame-driven loop clock.
public struct SkyClock: Equatable, Sendable {
    /// The loop period in seconds.
    public static let period: Double = 600
    /// The accepted speed (the scene's speed range).
    public static let speedRange: ClosedRange<Double> = 0...2

    /// The underlying scene clock (period ``period``; its own Reduce Motion flag stays off).
    public private(set) var clock: SceneClock
    /// When on, ``advance(by:)`` holds the time.
    public var reducedMotion: Bool

    /// A clock at time 0 with `speed` clamped to ``speedRange`` (a non-finite speed becomes 1).
    public init(speed: Double = 1, reducedMotion: Bool = false) {
        clock = SceneClock(duration: Self.period, speed: Self.clampSpeed(speed) ?? 1)
        self.reducedMotion = reducedMotion
    }

    /// A clock for `scene` at its speed.
    public init(scene: SkyScene, reducedMotion: Bool = false) {
        self.init(speed: scene.speed, reducedMotion: reducedMotion)
    }

    /// The current time, 0 ≤ time < ``period``.
    public var time: Double { clock.time }

    /// The playback speed (0…2); setting clamps it, and a non-finite value is ignored.
    public var speed: Double {
        get { clock.speed }
        set { if let value = Self.clampSpeed(newValue) { clock.speed = value } }
    }

    /// The loop phase `time / period`, in 0…1 (below 1).
    public var phase: Double { clock.time / Self.period }

    /// Advances by one drawn frame's `delta` (clamped to 0…0.25 s, times the speed, wrapping at the period); does
    /// nothing under Reduce Motion, at speed 0 or for a non-finite delta.
    public mutating func advance(by delta: Double) {
        guard !reducedMotion, clock.speed > 0, delta.isFinite else { return }
        clock.advance(by: delta)
    }

    /// Sets the time directly (clamped to the period; non-finite is ignored).
    public mutating func scrub(to time: Double) { clock.scrub(to: time) }

    private static func clampSpeed(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        return min(max(value, speedRange.lowerBound), speedRange.upperBound)
    }
}
