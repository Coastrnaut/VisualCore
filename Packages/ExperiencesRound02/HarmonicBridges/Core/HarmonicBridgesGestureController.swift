// HarmonicBridgesGestureController — feature 414 (R02-G12-04) T-R02G1204-003 (FR-R02G1204-001 … 003, 005;
// SC-R02G1204-001 … 003; clarifications Q1 … Q4). Turns pointer events into Harmonic Bridges gesture actions (choose a
// string, preview a peg, tune, test, reset the view) and camera orbits, host-testable without a screen. A small state
// machine in the pattern of Echo Cartographer's gesture controller (feature 404):
//
// - One finger goes down: the point is picked once with `HarmonicBridgesPicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the touch-down snapshot (its pegs, locks and stage) is kept for the whole
//   gesture.
//   - `.string(s)`: a press on string s (state `stringPress`); its current peg is the touch-down snapshot's.
//   - `.pip(_)` or `.goal`: a press on a test target (state `targetPress`).
//   - `.empty`: a press on empty space, tracked for a double tap (state `idle`).
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag or change the preview).
// - A press on a string whose travel reaches 16 points becomes a peg drag (state `pegDrag`):
//   - a tuning drag when the string is unlocked and the touch-down snapshot is playing: at the move that starts the
//     drag `[.preview(s, p)]` with the previewed peg
//     p = ``HarmonicBridgesGestureController/previewedPeg(current:upward:)`` of the current peg and the upward
//     movement (touch-down y − current y, view points, origin top left), and after
//     that `[.preview(s, p)]` at every move that changes p;
//   - otherwise (a locked string, or a stage other than playing) a choosing drag: `[.choose(s, current)]` once at the
//     move that starts the drag, no preview.
// - Release (`.ended`):
//   - a tuning drag: any last preview as above, then `[.tune(s, p)]` when p differs from the current peg and the
//     snapshot given with the releasing event is playing; nothing else;
//   - a choosing drag: nothing more;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on string s:
//     `[.choose(s, current)]` in any stage (the chosen string is presentation state);
//   - a tap on a pip or the goal: `[.test]` while the releasing snapshot is playing, nothing otherwise;
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture also a tap on empty space,
//     its `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from a pip, the goal or
//     empty space: nothing.
// - Kernel actions (tune, test) are produced only while playing; on every other stage (loading, tutorial, paused, won,
//   failed, result) only `choose`, and `resetView`.
// - A second finger cancels any one-finger gesture (nothing more sent) and the fingers orbit (state `orbiting`):
//   yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the fingers up raises the eye), clamped by
//   `HarmonicBridgesOrbit.clamped()`; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends nothing.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit, the chosen string and the preview never
// enter the digest, the snapshot's state or the kernel, which still applies its own rules (stage, locks, the no-op and
// peg rules, the budget) to every action sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Harmonic Bridges gesture asks for (feature 414).
public enum HarmonicBridgesGestureAction: Sendable, Equatable {
    /// Choose string `string` at peg `peg` in the panel (presentation only, nothing sent to the kernel).
    case choose(string: Int, peg: Int)
    /// Preview peg `peg` of string `string` during a peg drag; the panel's chosen string and peg follow (presentation
    /// only).
    case preview(string: Int, peg: Int)
    /// Tune string `string` to peg `peg`: `string.tune [string, peg]`.
    case tune(string: Int, peg: Int)
    /// Test the crossing: `crossing.test`.
    case test
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Harmonic Bridges gesture actions and camera orbits (feature 414), deterministic for the
/// same events. See the file header for the rules.
public struct HarmonicBridgesGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit; also a press on empty space (tracked for a double tap).
        case idle
        /// One finger went down on a string: a tap or a peg drag is still possible.
        case stringPress
        /// A press on a string moved at least 16 points: a tuning or choosing drag.
        case pegDrag
        /// One finger went down on a step pip or the goal island: a tap tests the crossing.
        case targetPress
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap, exclusive: 10.
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a drag: 16.
    public static let dragDistance: Double = 16
    /// The time in seconds (event timestamps) from touch-down at which a lift is no longer a tap, 0.5 (a tap lifts
    /// strictly before it).
    public static let tapDuration: Double = 0.5
    /// The longest time in seconds between the two `.ended` events of a double tap, 0.35.
    public static let doubleTapWindow: Double = 0.35
    /// The largest distance in view points between the two lift points of a double tap, 22.
    public static let doubleTapDistance: Double = 22
    /// The upward movement in view points that turns the previewed peg by one, 24.
    public static let pointsPerPeg: Double = 24
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``HarmonicBridgesOrbit/authored`` at start.
    public private(set) var orbit: HarmonicBridgesOrbit = .authored

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap on empty space that may start a double tap: its lift point and its `.ended` timestamp.
    private var lastEmptyTap: (location: Vec2, time: Double)?

    /// What a one-finger gesture went down on.
    private enum Target: Sendable, Equatable {
        /// String `index` with its current peg and lock at touch-down.
        case string(index: Int, peg: Int, locked: Bool)
        /// A step pip or the goal island.
        case testTarget
        /// Empty space.
        case nothing
    }

    /// A one-finger gesture in progress.
    private struct Touch: Sendable {
        /// The finger's pointer id.
        let pointer: Int
        /// Where the finger went down, in view points.
        let start: Vec2
        /// The touch-down timestamp.
        let time: Double
        /// What the finger went down on.
        let target: Target
        /// Whether the touch-down snapshot was playing.
        let playing: Bool
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// The last finite location of the finger.
        var last: Vec2
        /// Whether the press became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The last previewed peg of a tuning drag, nil before its first preview.
        var preview: Int?
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: HarmonicBridgesSceneSnapshot) -> HarmonicBridgesCamera? {
        guard Self.usable(viewSize) else { return nil }
        return HarmonicBridgesSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// The previewed peg of a string at peg `current` after an upward movement of `upward` view points: `current` +
    /// round(`upward` / ``pointsPerPeg``) with halves away from zero, clamped to 1 … 12 (a non-finite movement counts
    /// as none).
    public static func previewedPeg(current: Int, upward: Double) -> Int {
        let low: Int = HarmonicBridgesLevel.pegs.lowerBound
        let high: Int = HarmonicBridgesLevel.pegs.upperBound
        let span: Double = Double(high - low + 1)
        var steps: Double = 0
        if upward.isFinite {
            steps = (upward / pointsPerPeg).rounded(.toNearestOrAwayFromZero)
            steps = min(max(steps, -span), span)
        }
        let base: Int = min(max(current, low - Int(span)), high + Int(span))
        return min(max(base + Int(steps), low), high)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one: pegs, locks and
    /// stage). Returns the actions the event produces (see the file header): previews and a choosing drag's choice on
    /// moves, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: HarmonicBridgesSceneSnapshot) -> [HarmonicBridgesGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot)
            return []
        case .moved:
            return moved(event, viewSize: viewSize)
        case .ended:
            return ended(event, cancelled: false, snapshot: snapshot)
        case .cancelled:
            return ended(event, cancelled: true, snapshot: snapshot)
        }
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
        state = .idle
    }

    // MARK: Phases

    /// A finger went down: a first finger starts a one-finger gesture, a second cancels it and orbits, a third
    /// re-bases the orbit's midpoint.
    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: HarmonicBridgesSceneSnapshot) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot)
            } else {
                secondFinger()
            }
        case .stringPress, .pegDrag, .targetPress:
            secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    /// A finger moved: the one-finger gesture follows it (perhaps becoming a drag or changing the preview), or the
    /// orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [HarmonicBridgesGestureAction] {
        switch state {
        case .idle, .stringPress, .pegDrag, .targetPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [HarmonicBridgesGestureAction] = follow(&current, to: event.location)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: HarmonicBridgesOrbit =
                HarmonicBridgesOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                     pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger lifted (or was cancelled): the one-finger gesture is released, an orbit ends or a cancelled gesture
    /// waits for the last finger.
    private mutating func ended(_ event: PointerEvent, cancelled: Bool,
                                snapshot: HarmonicBridgesSceneSnapshot) -> [HarmonicBridgesGestureAction] {
        switch state {
        case .idle, .stringPress, .pegDrag, .targetPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastEmptyTap = nil
                return []
            }
            var actions: [HarmonicBridgesGestureAction] = follow(&current, to: event.location)
            actions += release(current, at: event, playing: snapshot.stage == .playing)
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

    /// Starts a one-finger gesture: picks the touch-down point once and decides what the gesture is on.
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: HarmonicBridgesSceneSnapshot) {
        var pick: HarmonicBridgesPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = HarmonicBridgesPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                              snapshot: snapshot, orbit: orbit)
        }
        var target: Target = .nothing
        switch pick {
        case .string(let index):
            if index >= 0, index < snapshot.strings.count, index < snapshot.pegs.count {
                target = .string(index: index, peg: snapshot.pegs[index], locked: snapshot.strings[index].locked)
            }
        case .pip, .goal:
            target = .testTarget
        case .empty:
            target = .nothing
        }
        switch target {
        case .string: state = .stringPress
        case .testTarget: state = .targetPress
        case .nothing: state = .idle
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                      playing: snapshot.stage == .playing, travel: 0, last: event.location, dragging: false,
                      preview: nil)
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing): its travel grows to the farthest
    /// distance from the start; a press on a string reaching ``dragDistance`` becomes a peg drag; returns the drag's
    /// choice or preview this move produces.
    private mutating func follow(_ touch: inout Touch, to location: Vec2) -> [HarmonicBridgesGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        touch.last = location
        guard case .string(let index, let peg, let locked) = touch.target else { return [] }
        let tuning: Bool = touch.playing && !locked
        if !touch.dragging {
            guard touch.travel >= Self.dragDistance else { return [] }
            touch.dragging = true
            if state == .stringPress { state = .pegDrag }
            guard tuning else { return [.choose(string: index, peg: peg)] }
        }
        guard tuning else { return [] }
        let previewed: Int = Self.previewedPeg(current: peg, upward: touch.start.y - location.y)
        guard previewed != touch.preview else { return [] }
        touch.preview = previewed
        return [.preview(string: index, peg: previewed)]
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed);
    /// `playing` tells whether the releasing snapshot is playing.
    private mutating func release(_ touch: Touch, at event: PointerEvent,
                                  playing: Bool) -> [HarmonicBridgesGestureAction] {
        switch touch.target {
        case .nothing:
            return emptyRelease(touch, at: event)
        case .testTarget:
            lastEmptyTap = nil
            guard isTap(touch, at: event), playing else { return [] }
            return [.test]
        case .string(let index, let peg, let locked):
            lastEmptyTap = nil
            if touch.dragging {
                guard touch.playing, playing, !locked, let previewed = touch.preview, previewed != peg else {
                    return []
                }
                return [.tune(string: index, peg: previewed)]
            }
            guard isTap(touch, at: event) else { return [] }
            return [.choose(string: index, peg: peg)]
        }
    }

    /// The release of a gesture on empty space: a double tap resets the view, anything else sends nothing.
    private mutating func emptyRelease(_ touch: Touch, at event: PointerEvent) -> [HarmonicBridgesGestureAction] {
        guard isTap(touch, at: event) else {
            lastEmptyTap = nil
            return []
        }
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

    /// Whether `touch` lifted by `event` is a tap: not a drag, under ``tapDistance`` of travel, lifted less than
    /// ``tapDuration`` after touch-down (finite timestamps and location).
    private func isTap(_ touch: Touch, at event: PointerEvent) -> Bool {
        let held: Double = event.timestamp - touch.time
        return !touch.dragging && touch.travel < Self.tapDistance && held.isFinite && held >= 0
            && held < Self.tapDuration && event.location.isFinite
    }

    /// Cancels any one-finger gesture for a second finger (nothing sent) and starts an orbit from the current
    /// midpoint.
    private mutating func secondFinger() {
        touch = nil
        lastEmptyTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
    }

    // MARK: Helpers

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
