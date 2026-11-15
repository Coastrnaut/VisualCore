// WorldsMotion — feature 090 (A12-P02) T-A12-205 (FR-A12-212, FR-A12-213; clarification 3; research D3; acceptance
// scenarios US1-2 and US1-3; edge case "Reduce Motion toggled mid-ease"). Two pure helpers of the presenter, driven
// only by the frame time the host passes (never a wall clock), so both are host-testable:
//   - `ViewEasing`: the drawn view eases from the previously drawn view to the state's view over 0.35 s with
//     smoothstep (s = t²(3 − 2t), t the elapsed fraction); yaw takes the shorter way round, pitch and distance blend
//     linearly. A new target starts a new ease from the view drawn at that moment. The frame in which a target is
//     first seen already advances by its frame time, so 21 frames of 1/60 s reach the target exactly. With Reduce
//     Motion on — also when it is switched on in the middle of an ease — the target is drawn directly and the ease
//     ends. The first view after a reset is drawn directly. The easing never touches the state.
//   - `ViewAnnouncer`: the spoken view description is posted at most once per second: an offered text is spoken at
//     once when a second has passed since the last spoken one, otherwise it is held (the latest offered text wins) and
//     spoken by `tick(at:)` as soon as the second has passed.
import Foundation
import TinyWorldsCore

/// Eases the drawn view towards the state's view (see the file header).
struct ViewEasing: Sendable, Equatable {
    /// The time an ease takes, in seconds.
    static let duration = 0.35

    /// The view drawn last; nil before the first view.
    private(set) var drawn: WorldView?
    /// The view the ease started from.
    private(set) var from: WorldView?
    /// The view the ease moves to (the state's view).
    private(set) var target: WorldView?
    /// The frame time since the ease started, in seconds.
    private(set) var elapsed = 0.0

    /// Creates an easing with nothing drawn yet.
    init() {}

    /// True while the drawn view has not reached the target.
    var isEasing: Bool { drawn != nil && drawn != target }

    /// smoothstep(t) = t²(3 − 2t) for t clamped into 0…1.
    static func smoothstep(_ t: Double) -> Double {
        let x = t.isFinite ? min(max(t, 0), 1) : 1
        return x * x * (3 - 2 * x)
    }

    /// The view `s` of the way from `a` to `b` (yaw the shorter way round, pitch and distance linear).
    static func blend(_ a: WorldView, _ b: WorldView, _ s: Double) -> WorldView {
        let turn = (b.yaw - a.yaw).remainder(dividingBy: 2 * Double.pi)
        return WorldView(yaw: a.yaw + turn * s, pitch: a.pitch + (b.pitch - a.pitch) * s,
                         distance: a.distance + (b.distance - a.distance) * s)
    }

    /// Advances by `delta` seconds of frame time towards `target` and returns the view to draw; direct when
    /// `reduceMotion` is true or nothing was drawn yet.
    mutating func advance(to target: WorldView, by delta: Double, reduceMotion: Bool) -> WorldView {
        guard let current = drawn, !reduceMotion else {
            settle(on: target)
            return target
        }
        if target != self.target {
            from = current
            self.target = target
            elapsed = 0
        }
        if delta.isFinite, delta > 0 { elapsed += delta }
        if elapsed >= Self.duration - 1e-9 || from == nil {
            settle(on: target)
            return target
        }
        let view = Self.blend(from ?? current, target, Self.smoothstep(elapsed / Self.duration))
        drawn = view
        return view
    }

    /// Ends any ease with `view` drawn.
    private mutating func settle(on view: WorldView) {
        drawn = view
        from = view
        target = view
        elapsed = Self.duration
    }

    /// Forgets the drawn view; the next view is drawn directly.
    mutating func reset() { self = ViewEasing() }
}

/// Speaks the view description at most once per second (see the file header).
struct ViewAnnouncer: Sendable, Equatable {
    /// The least time between two spoken texts, in seconds.
    static let interval = 1.0

    /// The time the last text was spoken; nil before the first.
    private(set) var lastSpoken: Double?
    /// The text held back until the interval has passed (the latest offered).
    private(set) var pending: String?

    /// Creates an announcer that has spoken nothing.
    init() {}

    /// Offers `text` at `time` seconds: returns it when it may be spoken now, otherwise holds it and returns nil.
    mutating func offer(_ text: String, at time: Double) -> String? {
        pending = text
        return tick(at: time)
    }

    /// Returns the held text when the interval since the last spoken text has passed at `time`, otherwise nil.
    mutating func tick(at time: Double) -> String? {
        guard let text = pending else { return nil }
        if let last = lastSpoken, time - last < Self.interval { return nil }
        pending = nil
        lastSpoken = time
        return text
    }

    /// Forgets the held text and the last spoken time.
    mutating func reset() { self = ViewAnnouncer() }
}
