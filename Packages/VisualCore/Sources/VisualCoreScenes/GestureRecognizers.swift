// GestureRecognizers.swift — pure, event-driven gesture state machines (feature 006 T-F506; FR-F502,
// SC-F503; research R2; clarifications 2026-11-10 for thresholds and one/two-finger interaction).
//
// Feed each PointerEvent to a PointerTracker first, then to the recognizers with the updated tracker.
// Time-based transitions (tap timeout, long-press) are evaluated on events and on `tick(now:)`; there
// are no timers, so every recognizer is deterministic and host-testable.
// Continuous gestures (drag, pinch, rotate): possible → began → changed* → ended | cancelled, or failed.
// Discrete gestures (tap, double-tap, long-press): possible → recognized | failed | cancelled.
// A recognizer in a terminal state resets to `possible` when the next first finger lands.
import Foundation
import VisualCoreMath

/// Lifecycle state of a gesture recognizer (continuous: possible → began → changed → ended/cancelled/failed; discrete: possible → recognized/failed/cancelled).
public enum GestureState: String, Sendable, Equatable {
    case possible, began, changed, ended, cancelled, failed, recognized
    /// True for ended, cancelled, failed and recognized; the recognizer ignores events until the next first finger lands.
    public var isTerminal: Bool { [.ended, .cancelled, .failed, .recognized].contains(self) }
    /// True while a continuous gesture is in progress (began or changed).
    public var isActive: Bool { self == .began || self == .changed }
}

/// A deterministic, timer-free gesture state machine fed with pointer events and `tick(now:)`.
public protocol GestureRecognizer: Sendable {
    /// Current recognition state.
    var state: GestureState { get }
    /// `tracker` must already include `event`.
    mutating func handle(_ event: PointerEvent, tracker: PointerTracker)
    /// Advances time-based transitions without an event.
    mutating func tick(now: Double)
    /// Returns to `possible` and clears all tracked touches and results.
    mutating func reset()
}

extension GestureRecognizer {
    /// True when a terminal recognizer should start over for this event (first finger down).
    func startsOver(_ e: PointerEvent, _ tracker: PointerTracker) -> Bool {
        e.phase == .began && tracker.count == 1
    }
}

// MARK: Tap

/// Recognizes a single-finger tap that lifts within `maxDistance` points and `maxDuration` seconds; a second finger fails it.
public struct TapRecognizer: GestureRecognizer {
    /// Maximum movement from the touch-down point, in points (default 10).
    public var maxDistance = 10.0
    /// Maximum touch-down-to-lift time, in seconds (default 0.3).
    public var maxDuration = 0.3
    /// `recognized` on a valid tap; `failed` on too much movement, too long a hold or a second finger.
    public private(set) var state: GestureState = .possible
    /// Lift location of the recognized tap, in view points; nil until recognized.
    public private(set) var location: Vec2?
    private var start: (id: Int, at: Vec2, time: Double)?
    /// Time the recognized tap ended (used by DoubleTapRecognizer).
    public private(set) var endTime: Double?

    /// Creates a tap recognizer with the given movement (points) and duration (seconds) limits.
    public init(maxDistance: Double = 10, maxDuration: Double = 0.3) {
        self.maxDistance = maxDistance; self.maxDuration = maxDuration
    }

    /// Returns to `possible` and clears the pending touch, location and end time.
    public mutating func reset() { state = .possible; start = nil; location = nil; endTime = nil }

    /// A finger is down and the tap is still undecided.
    var isTracking: Bool { state == .possible && start != nil }

    /// Tracks the first finger; recognizes on lift within the limits, otherwise fails (or cancels on a cancelled touch).
    public mutating func handle(_ e: PointerEvent, tracker: PointerTracker) {
        if state.isTerminal { guard startsOver(e, tracker) else { return }; reset() }
        switch e.phase {
        case .began:
            if start == nil, tracker.count == 1 { start = (e.id, e.location, e.timestamp) }
            else { state = .failed }   // a second finger fails a pending tap
        case .moved:
            guard let s = start, s.id == e.id else { return }
            if e.location.distance(to: s.at) > maxDistance || e.timestamp - s.time > maxDuration { state = .failed }
        case .ended:
            guard let s = start, s.id == e.id else { return }
            if e.location.distance(to: s.at) <= maxDistance && e.timestamp - s.time <= maxDuration {
                state = .recognized; location = e.location; endTime = e.timestamp
            } else { state = .failed }
        case .cancelled:
            if start?.id == e.id { state = .cancelled }
        }
    }

    /// Fails a pending tap once more than `maxDuration` seconds have passed since touch-down.
    public mutating func tick(now: Double) {
        if state == .possible, let s = start, now - s.time > maxDuration { state = .failed }
    }
}

// MARK: Double tap

/// Recognizes two taps whose second touch-down is within `maxInterval` seconds of the first tap's lift and within `maxSeparation` points of it.
public struct DoubleTapRecognizer: GestureRecognizer {
    /// Maximum time from the first tap's lift to the second touch-down, in seconds (default 0.3).
    public var maxInterval = 0.3
    /// Maximum distance between the two tap locations, in points (default 30).
    public var maxSeparation = 30.0
    /// `recognized` after a valid second tap; `failed` when either tap fails or the interval or separation is exceeded.
    public private(set) var state: GestureState = .possible
    /// Location of the second tap, in view points; nil until recognized.
    public private(set) var location: Vec2?
    private var tap = TapRecognizer()
    private var first: (at: Vec2, time: Double)?

    /// Creates a double-tap recognizer with the given interval (seconds) and separation (points) limits.
    public init(maxInterval: Double = 0.3, maxSeparation: Double = 30) {
        self.maxInterval = maxInterval; self.maxSeparation = maxSeparation
    }

    /// Returns to `possible` and forgets the first tap.
    public mutating func reset() { state = .possible; tap.reset(); first = nil; location = nil }

    /// Feeds the event to the inner tap recognizer and combines its result with the first tap's time and location.
    public mutating func handle(_ e: PointerEvent, tracker: PointerTracker) {
        if state.isTerminal { guard startsOver(e, tracker) else { return }; reset() }
        if e.phase == .began, let f = first, e.timestamp - f.time > maxInterval { state = .failed; return }
        tap.handle(e, tracker: tracker)
        switch tap.state {
        case .failed: state = .failed
        case .cancelled: state = .cancelled
        case .recognized:
            let at = tap.location!, time = tap.endTime!
            if let f = first {
                // The interval was checked when the second finger landed (≤ maxInterval after the first tap ended).
                if at.distance(to: f.at) <= maxSeparation { state = .recognized; location = at } else { state = .failed }
            } else {
                first = (at, time)
                tap.reset()
            }
        default: break
        }
    }

    /// Fails when the current tap times out or no second tap lands within `maxInterval` seconds of the first.
    public mutating func tick(now: Double) {
        guard state == .possible else { return }
        if tap.isTracking {
            tap.tick(now: now)
            if tap.state == .failed { state = .failed }
        } else if let f = first, now - f.time > maxInterval {
            state = .failed
        }
    }
}

// MARK: Long press

/// Recognizes a single finger held for at least `minDuration` seconds without moving more than `maxDistance` points.
public struct LongPressRecognizer: GestureRecognizer {
    /// Minimum hold time, in seconds (default 0.5).
    public var minDuration = 0.5
    /// Maximum movement during the hold, in points (default 10).
    public var maxDistance = 10.0
    /// `recognized` once the hold completes; `failed` on movement, an early lift or a second finger.
    public private(set) var state: GestureState = .possible
    /// Touch-down location of the recognized press, in view points; nil until recognized.
    public private(set) var location: Vec2?
    private var start: (id: Int, at: Vec2, time: Double)?

    /// Creates a long-press recognizer with the given hold time (seconds) and movement limit (points).
    public init(minDuration: Double = 0.5, maxDistance: Double = 10) {
        self.minDuration = minDuration; self.maxDistance = maxDistance
    }

    /// Returns to `possible` and clears the pending touch and location.
    public mutating func reset() { state = .possible; start = nil; location = nil }

    /// Tracks the first finger, first evaluating whether the hold already completed by the event's timestamp.
    public mutating func handle(_ e: PointerEvent, tracker: PointerTracker) {
        if state.isTerminal { guard startsOver(e, tracker) else { return }; reset() }
        if state == .possible { tick(now: e.timestamp) }   // the hold may have completed before this event
        guard state == .possible else { return }
        switch e.phase {
        case .began:
            if start == nil, tracker.count == 1 { start = (e.id, e.location, e.timestamp) } else { state = .failed }
        case .moved:
            guard let s = start, s.id == e.id else { return }
            if e.location.distance(to: s.at) > maxDistance { state = .failed }
        case .ended:
            if start?.id == e.id { state = .failed }   // lifted before minDuration
        case .cancelled:
            if start?.id == e.id { state = .cancelled }
        }
    }

    /// Recognizes the press once `minDuration` seconds have elapsed since touch-down.
    public mutating func tick(now: Double) {
        if state == .possible, let s = start, now - s.time >= minDuration { state = .recognized; location = s.at }
    }
}

// MARK: Drag

/// Continuous single-finger drag that begins after moving more than `minDistance` points; a second finger cancels it.
public struct DragRecognizer: GestureRecognizer {
    /// Movement from the touch-down point required to begin, in points (default 10).
    public var minDistance = 10.0
    /// Continuous state: began after `minDistance`, changed on later moves, ended on lift; failed if lifted before beginning.
    public private(set) var state: GestureState = .possible
    /// Current finger location, in view points; nil before touch-down.
    public private(set) var location: Vec2?
    /// Finger offset from where it landed.
    public private(set) var translation: Vec2 = .zero
    /// Points per second over the last move.
    public private(set) var velocity: Vec2 = .zero
    private var start: (id: Int, at: Vec2)?
    private var last: (at: Vec2, time: Double)?

    /// Creates a drag recognizer that begins after `minDistance` points of movement.
    public init(minDistance: Double = 10) { self.minDistance = minDistance }

    /// Returns to `possible` and zeroes location, translation and velocity.
    public mutating func reset() {
        state = .possible; start = nil; last = nil; location = nil; translation = .zero; velocity = .zero
    }

    /// Updates location, translation and velocity from the tracked finger and advances the drag state.
    public mutating func handle(_ e: PointerEvent, tracker: PointerTracker) {
        if state.isTerminal { guard startsOver(e, tracker) else { return }; reset() }
        switch e.phase {
        case .began:
            if start == nil, tracker.count == 1 {
                start = (e.id, e.location); last = (e.location, e.timestamp); location = e.location
            } else {
                state = state.isActive ? .cancelled : .failed   // a second finger cancels the drag
            }
        case .moved:
            guard let s = start, s.id == e.id else { return }
            if let l = last, e.timestamp > l.time { velocity = (e.location - l.at) / (e.timestamp - l.time) }
            last = (e.location, e.timestamp)
            location = e.location
            translation = e.location - s.at
            if state == .possible { if translation.length > minDistance { state = .began } }
            else if state.isActive { state = .changed }
        case .ended:
            guard start?.id == e.id else { return }
            state = state.isActive ? .ended : .failed
        case .cancelled:
            guard start?.id == e.id else { return }
            state = state.isActive ? .cancelled : .failed
        }
    }

    /// No-op: dragging has no time-based transitions.
    public mutating func tick(now: Double) {}
}

// MARK: Two-finger gestures

/// Shared tracking of the first two pointers for pinch and rotate.
struct TwoFinger: Sendable {
    var ids: (Int, Int)?
    var initial: Vec2 = .zero   // vector from finger 0 to finger 1 at the start

    mutating func vector(_ tracker: PointerTracker) -> Vec2? {
        if ids == nil, tracker.order.count >= 2 {
            ids = (tracker.order[0], tracker.order[1])
            initial = tracker.active[tracker.order[1]]! - tracker.active[tracker.order[0]]!
        }
        guard let (a, b) = ids, let pa = tracker.active[a], let pb = tracker.active[b] else { return nil }
        return pb - pa
    }
    func involves(_ id: Int) -> Bool { ids.map { $0.0 == id || $0.1 == id } ?? false }
    func center(_ tracker: PointerTracker) -> Vec2? {
        guard let (a, b) = ids, let pa = tracker.active[a], let pb = tracker.active[b] else { return nil }
        return (pa + pb) / 2
    }
}

/// Continuous two-finger pinch reporting `scale` relative to the initial finger distance.
public struct PinchRecognizer: GestureRecognizer {
    /// Change in finger distance (points) before the pinch begins.
    public var minChange = 0.0
    /// Continuous state: began once the distance changes by more than `minChange`; failed if only one finger came and went.
    public private(set) var state: GestureState = .possible
    /// Current distance / initial distance.
    public private(set) var scale = 1.0
    /// Midpoint between the two tracked fingers, in view points; nil before the first move.
    public private(set) var center: Vec2?
    private var fingers = TwoFinger()

    /// Creates a pinch recognizer that begins after the finger distance changes by `minChange` points.
    public init(minChange: Double = 0) { self.minChange = minChange }

    /// Returns to `possible`, resets `scale` to 1 and forgets the tracked fingers.
    public mutating func reset() { state = .possible; scale = 1; center = nil; fingers = TwoFinger() }

    /// Tracks the first two fingers and updates scale and center when either moves; lifting one ends the pinch.
    public mutating func handle(_ e: PointerEvent, tracker: PointerTracker) {
        if state.isTerminal { guard startsOver(e, tracker) else { return }; reset() }
        switch e.phase {
        case .began:
            _ = fingers.vector(tracker)
        case .moved:
            guard fingers.involves(e.id), let v = fingers.vector(tracker), fingers.initial.length > 0 else { return }
            scale = v.length / fingers.initial.length
            center = fingers.center(tracker)
            if state == .possible { if abs(v.length - fingers.initial.length) > minChange { state = .began } }
            else if state.isActive { state = .changed }
        case .ended, .cancelled:
            guard fingers.involves(e.id) else {
                if tracker.count == 0, fingers.ids == nil { state = .failed }   // one finger came and went
                return
            }
            state = state.isActive ? (e.phase == .ended ? .ended : .cancelled) : .failed
        }
    }

    /// No-op: pinching has no time-based transitions.
    public mutating func tick(now: Double) {}
}

/// Continuous two-finger rotation reporting `angle` relative to the initial finger vector.
public struct RotateRecognizer: GestureRecognizer {
    /// Rotation (radians) before the gesture begins.
    public var minAngle = 0.0
    /// Continuous state: began once |angle| exceeds `minAngle`; failed if only one finger came and went.
    public private(set) var state: GestureState = .possible
    /// Counter-clockwise on screen, radians in (-π, π] relative to the start.
    public private(set) var angle = 0.0
    /// Midpoint between the two tracked fingers, in view points; nil before the first move.
    public private(set) var center: Vec2?
    private var fingers = TwoFinger()

    /// Creates a rotate recognizer that begins after `minAngle` radians of rotation.
    public init(minAngle: Double = 0) { self.minAngle = minAngle }

    /// Returns to `possible`, resets `angle` to 0 and forgets the tracked fingers.
    public mutating func reset() { state = .possible; angle = 0; center = nil; fingers = TwoFinger() }

    /// Tracks the first two fingers and updates angle and center when either moves; lifting one ends the rotation.
    public mutating func handle(_ e: PointerEvent, tracker: PointerTracker) {
        if state.isTerminal { guard startsOver(e, tracker) else { return }; reset() }
        switch e.phase {
        case .began:
            _ = fingers.vector(tracker)
        case .moved:
            guard fingers.involves(e.id), let v = fingers.vector(tracker), fingers.initial.length > 0, v.length > 0 else { return }
            // View points are y-down, so negate to report counter-clockwise on screen as positive.
            angle = -atan2(fingers.initial.cross(v), fingers.initial.dot(v))
            center = fingers.center(tracker)
            if state == .possible { if abs(angle) > minAngle { state = .began } }
            else if state.isActive { state = .changed }
        case .ended, .cancelled:
            guard fingers.involves(e.id) else {
                if tracker.count == 0, fingers.ids == nil { state = .failed }
                return
            }
            state = state.isActive ? (e.phase == .ended ? .ended : .cancelled) : .failed
        }
    }

    /// No-op: rotation has no time-based transitions.
    public mutating func tick(now: Double) {}
}
