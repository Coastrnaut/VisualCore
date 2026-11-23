// BackwardsAuroraGestureController — feature 394 (R02-G10-04) T-R02G1004-004 (FR-R02G1004-001 … 005, 007;
// SC-R02G1004-001 … 003; clarifications Q1 … Q4). Turns pointer events into Backwards Aurora gesture actions (set the
// chosen section's start or end, reverse the section, reset the view), the timeline freeze preview and camera orbits,
// host-testable without a screen. A small state machine in the pattern of Nocturne Garden's gesture controller (feature
// 384):
//
// - One finger goes down: the point is picked once with `BackwardsAuroraPicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the touch-down snapshot (with its chosen section [start, end]) and play are kept
//   for the whole gesture.
//   - `.start`, `.end`: an end drag (state `endDrag`).
//   - `.band(k)`: a band press (state `bandPress`).
//   - `.sample(k)`: a sample press (state `samplePress`).
//   - `.empty`: a press on empty space tracked for a double tap (state `idle`).
// - Moves grow the travel (the farthest distance from the touch-down point).
//   - End drag, once the travel reaches 16 points: the dragged end follows `BackwardsAuroraPicker.column` under the
//     finger, clamped to 0 … end − 1 for the start and start + 1 … N − 1 for the end (the other end as at touch-down),
//     and `.setStart(k)` / `.setEnd(k)` is returned by the event at which the clamped column changes.
//   - Band press: a press still under 10 points of travel whose event timestamp (or a ``tick(at:snapshot:play:)``
//     time) is at least 0.5 s after touch-down freezes (state `freeze`): the preview
//     (``BackwardsAuroraGestureController/preview``) is `BackwardsAuroraFreezePreview.make` of the section; a frozen
//     press never becomes a swipe. Otherwise the event at which the travel first reaches 16 points decides: when the
//     finger's displacement from touch-down there has |dx| ≥ 2·|dy| the press is a swipe (state `swipe`, the preview
//     of the section while it lasts); any other band drag sends nothing.
// - Release (the release point counts as a last move, without the hold check):
//   - a swipe sends `.reverse(start, end)` of the touch-down section when the play is playing, nothing on a finished
//     play (any other stage); a freeze or another band drag sends nothing;
//   - an end drag sends the last column change, if the release point brings one;
//   - travel 10 … 16 points: nothing;
//   - a tap (travel < 10 points, at most 0.5 s from touch-down to lift by event timestamps) on a sample or the band
//     takes the column k: k < start → `.setStart(k)`; k > end → `.setEnd(k)`; start < k < end → the nearer end moves
//     to k (ties to the start); k on an end → nothing. Taps work on a finished play too (presentation state);
//   - a tap on an end: nothing;
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous tap also on empty space, its
//     `.ended` at most 0.35 s earlier and at most 22 points away), `.resetView` and the authored orbit;
//   - a longer press: nothing.
// - A second finger cancels any one-finger gesture (preview dropped, nothing sent) and the fingers orbit (state
//   `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60°, clamped by `BackwardsAuroraOrbit.clamped()`; a
//   third finger re-bases the midpoint. A finger lifting while others stay → `cancelled` until every finger has lifted.
//   A `.cancelled` phase sends nothing.
//
// Only event timestamps (and the time given to `tick`) are read, never a clock. Presentation only: the orbit, the section
// and the preview never enter the digest, the snapshot's state or the kernel, which still applies its own rules (stage,
// range, section lengths, palindromes) to the one reversal sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Backwards Aurora gesture asks for (feature 394).
public enum BackwardsAuroraGestureAction: Sendable, Equatable {
    /// Move the chosen section's start to position k (presentation only, nothing sent to the kernel).
    case setStart(Int)
    /// Move the chosen section's end to position k (presentation only, nothing sent to the kernel).
    case setEnd(Int)
    /// Reverse the section [start, end]: `wave.reverse`.
    case reverse(Int, Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Backwards Aurora gesture actions, the freeze preview and camera orbits (feature 394),
/// deterministic for the same events. See the file header for the rules.
public struct BackwardsAuroraGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit: the next finger starts one, or a press on empty space tracked for a tap.
        case idle
        /// One finger went down on a sample column outside the band: a tap moves an end there.
        case samplePress
        /// One finger went down on an end of the chosen section: a drag moves that end.
        case endDrag
        /// One finger went down on the band: a tap moves an end, a sideways drag swipes, a hold freezes.
        case bandPress
        /// A band press moved sideways at least 16 points: a reversal on release, the preview meanwhile.
        case swipe
        /// A band press held 0.5 s without moving 10 points: the preview until the finger lifts.
        case freeze
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap, exclusive: 10 (also the most a held press may move to freeze).
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of an end drag or a swipe, 16.
    public static let dragDistance: Double = 16
    /// The longest time in seconds (event timestamps) from touch-down to lift of a tap, 0.5.
    public static let tapDuration: Double = 0.5
    /// The time in seconds a band press must be held without moving 10 points to freeze, 0.5.
    public static let holdDuration: Double = 0.5
    /// The longest time in seconds between the two `.ended` events of a double tap, 0.35.
    public static let doubleTapWindow: Double = 0.35
    /// The largest distance in view points between the two lift points of a double tap, 22.
    public static let doubleTapDistance: Double = 22
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``BackwardsAuroraOrbit/authored`` at start.
    public private(set) var orbit: BackwardsAuroraOrbit = .authored
    /// The freeze preview of the chosen section while a press is frozen or a swipe lasts (the scene draws its
    /// samples as a pale dashed ribbon), or nil.
    public private(set) var preview: BackwardsAuroraFreezePreview?

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap on empty space that may start a double tap: its lift point and its `.ended` timestamp.
    private var lastEmptyTap: (location: Vec2, time: Double)?

    /// What a one-finger gesture is on.
    private enum Kind: Sendable, Equatable {
        /// The section's start.
        case start
        /// The section's end.
        case end
        /// The band at column k.
        case band(Int)
        /// Sample column k.
        case sample(Int)
        /// Empty space.
        case empty
    }

    /// A one-finger gesture in progress.
    private struct Touch: Sendable {
        /// The finger's pointer id.
        let pointer: Int
        /// Where the finger went down, in view points.
        let start: Vec2
        /// The touch-down timestamp.
        let time: Double
        /// What the gesture is on.
        let kind: Kind
        /// The snapshot drawn at touch-down (its chosen section is the gesture's section).
        let snapshot: BackwardsAuroraSceneSnapshot
        /// The play at touch-down.
        let play: BackwardsAuroraPlay
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// The last finite location of the finger.
        var last: Vec2
        /// For an end drag: the dragged end's current position.
        var position: Int
        /// For a band press: nil while undecided, true once a swipe, false once another drag.
        var swiping: Bool?
        /// For a band press: whether it froze.
        var frozen: Bool
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: BackwardsAuroraSceneSnapshot) -> BackwardsAuroraCamera? {
        guard Self.usable(viewSize) else { return nil }
        return BackwardsAuroraSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one of the committed
    /// play with the panel's chosen section, without the preview) of `play`. Returns the actions the event produces
    /// (see the file header): end-drag column changes as they happen, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: BackwardsAuroraSceneSnapshot,
                                play: BackwardsAuroraPlay) -> [BackwardsAuroraGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot, play: play)
            return []
        case .moved:
            return moved(event, viewSize: viewSize)
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, play: play)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, play: play)
        }
    }

    /// Advances the presentation time to `time` (seconds, on the event timestamps' clock): a band press held at least
    /// ``holdDuration`` since touch-down without moving ``tapDistance`` points freezes, showing the preview of the
    /// chosen section of `snapshot` on `play`. Anything else is unchanged.
    public mutating func tick(at time: Double, snapshot: BackwardsAuroraSceneSnapshot, play: BackwardsAuroraPlay) {
        guard state == .bandPress, var current = touch, time.isFinite else { return }
        guard freezes(current, at: time) else { return }
        current.frozen = true
        touch = current
        state = .freeze
        preview = BackwardsAuroraFreezePreview.make(play: play, start: snapshot.sectionStart, end: snapshot.sectionEnd)
    }

    /// Returns the camera to the authored orbit (the panel's "Reset view"); an orbit in progress continues from the
    /// fingers' current midpoint.
    public mutating func resetView() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel); the orbit is kept,
    /// and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        orbitMidpoint = nil
        lastEmptyTap = nil
        preview = nil
        state = .idle
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: BackwardsAuroraSceneSnapshot,
                                play: BackwardsAuroraPlay) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot, play: play)
            } else {
                secondFinger()
            }
        case .samplePress, .endDrag, .bandPress, .swipe, .freeze:
            secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [BackwardsAuroraGestureAction] {
        switch state {
        case .idle, .samplePress, .endDrag, .bandPress, .swipe, .freeze:
            guard var current = touch, current.pointer == event.id else { return [] }
            if state == .bandPress, event.timestamp.isFinite, freezes(current, at: event.timestamp) {
                current.frozen = true
                state = .freeze
                preview = BackwardsAuroraFreezePreview.make(play: current.play, start: current.snapshot.sectionStart,
                                                            end: current.snapshot.sectionEnd)
            }
            follow(&current, to: event.location)
            let actions: [BackwardsAuroraGestureAction] = advance(&current, viewSize: viewSize)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: BackwardsAuroraOrbit =
                BackwardsAuroraOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                     pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
            return []
        case .cancelled:
            return []
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                play: BackwardsAuroraPlay) -> [BackwardsAuroraGestureAction] {
        switch state {
        case .idle, .samplePress, .endDrag, .bandPress, .swipe, .freeze:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                preview = nil
                lastEmptyTap = nil
                return []
            }
            follow(&current, to: event.location)
            var actions: [BackwardsAuroraGestureAction] = advance(&current, viewSize: viewSize)
            actions += release(current, at: event, play: play)
            preview = nil
            return actions
        case .orbiting:
            orbitMidpoint = nil
            state = tracker.count == 0 ? .idle : .cancelled
        case .cancelled:
            if tracker.count == 0 { state = .idle }
        }
        return []
    }

    // MARK: Gestures

    /// Starts a one-finger gesture: picks the touch-down point once and decides what the gesture is.
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: BackwardsAuroraSceneSnapshot,
                                play: BackwardsAuroraPlay) {
        var pick: BackwardsAuroraPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = BackwardsAuroraPicker.pick(Self.simd(event.location), size: Self.simd(viewSize), snapshot: snapshot,
                                              orbit: orbit)
        }
        let kind: Kind
        var position: Int = 0
        switch pick {
        case .start:
            kind = .start
            position = snapshot.sectionStart
            state = .endDrag
        case .end:
            kind = .end
            position = snapshot.sectionEnd
            state = .endDrag
        case .band(let k):
            kind = .band(k)
            state = .bandPress
        case .sample(let k):
            kind = .sample(k)
            state = .samplePress
        case .empty:
            kind = .empty
            state = .idle
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, kind: kind, snapshot: snapshot,
                      play: play, travel: 0, last: event.location, position: position, swiping: nil, frozen: false)
        preview = nil
    }

    /// Whether band press `touch` freezes at `time`: undecided, not frozen, under ``tapDistance`` of travel and held
    /// at least ``holdDuration``.
    private func freezes(_ touch: Touch, at time: Double) -> Bool {
        guard case .band = touch.kind, !touch.frozen, touch.swiping == nil, touch.travel < Self.tapDistance,
              touch.time.isFinite else { return false }
        return time - touch.time >= Self.holdDuration
    }

    /// Applies the finger's latest location to `touch`: an end drag's column change (returned), or a band press's
    /// swipe decision at the event where the travel first reaches ``dragDistance``.
    private mutating func advance(_ touch: inout Touch, viewSize: Vec2) -> [BackwardsAuroraGestureAction] {
        guard touch.travel >= Self.dragDistance else { return [] }
        switch touch.kind {
        case .start, .end:
            guard Self.usable(viewSize),
                  let column = BackwardsAuroraPicker.column(Self.simd(touch.last), size: Self.simd(viewSize),
                                                            snapshot: touch.snapshot, orbit: orbit) else { return [] }
            let section: (start: Int, end: Int) = (touch.snapshot.sectionStart, touch.snapshot.sectionEnd)
            let clamped: Int
            if touch.kind == .start {
                clamped = min(max(column, 0), section.end - 1)
            } else {
                clamped = min(max(column, section.start + 1), touch.snapshot.count - 1)
            }
            guard clamped != touch.position else { return [] }
            touch.position = clamped
            return touch.kind == .start ? [.setStart(clamped)] : [.setEnd(clamped)]
        case .band:
            guard !touch.frozen, touch.swiping == nil else { return [] }
            let d: Vec2 = touch.last - touch.start
            let sideways: Bool = abs(d.x) >= 2 * abs(d.y)
            touch.swiping = sideways
            if sideways {
                state = .swipe
                preview = BackwardsAuroraFreezePreview.make(play: touch.play, start: touch.snapshot.sectionStart,
                                                            end: touch.snapshot.sectionEnd)
            }
            return []
        case .sample, .empty:
            return []
        }
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (end-drag changes come from
    /// ``advance(_:viewSize:)``).
    private mutating func release(_ touch: Touch, at event: PointerEvent,
                                  play: BackwardsAuroraPlay) -> [BackwardsAuroraGestureAction] {
        let start: Int = touch.snapshot.sectionStart
        let end: Int = touch.snapshot.sectionEnd
        if touch.frozen {
            lastEmptyTap = nil
            return []
        }
        if touch.travel >= Self.dragDistance {
            lastEmptyTap = nil
            if case .band = touch.kind, touch.swiping == true, play.stage == .playing {
                return [.reverse(start, end)]
            }
            return []
        }
        let held: Double = event.timestamp - touch.time
        guard touch.travel < Self.tapDistance, held.isFinite, held >= 0, held <= Self.tapDuration,
              event.timestamp.isFinite, event.location.isFinite else {
            lastEmptyTap = nil
            return []
        }
        switch touch.kind {
        case .band(let k), .sample(let k):
            lastEmptyTap = nil
            return Self.tap(k, start: start, end: end)
        case .start, .end:
            lastEmptyTap = nil
            return []
        case .empty:
            if let last = lastEmptyTap, event.timestamp - last.time >= 0,
               event.timestamp - last.time <= Self.doubleTapWindow,
               (event.location - last.location).length <= Self.doubleTapDistance {
                lastEmptyTap = nil
                resetView()
                return [.resetView]
            }
            lastEmptyTap = (event.location, event.timestamp)
            return []
        }
    }

    /// The section change of a tap on column `k` with the section [`start`, `end`]: left of the start moves it, right
    /// of the end moves it, strictly inside moves the nearer end (ties to the start), on an end nothing.
    static func tap(_ k: Int, start: Int, end: Int) -> [BackwardsAuroraGestureAction] {
        if k < start { return [.setStart(k)] }
        if k > end { return [.setEnd(k)] }
        if k == start || k == end { return [] }
        return k - start <= end - k ? [.setStart(k)] : [.setEnd(k)]
    }

    /// Cancels any one-finger gesture for a second finger (nothing sent, preview dropped) and starts an orbit from the
    /// current midpoint.
    private mutating func secondFinger() {
        touch = nil
        preview = nil
        lastEmptyTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
    }

    // MARK: Helpers

    /// Moves `touch`'s finger to `location`: its travel grows to the farthest distance from the start and its last
    /// location follows (a non-finite location changes nothing).
    private func follow(_ touch: inout Touch, to location: Vec2) {
        guard location.isFinite, touch.start.isFinite else { return }
        touch.travel = max(touch.travel, (location - touch.start).length)
        touch.last = location
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
