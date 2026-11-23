// EchoCartographerGestureController — feature 404 (R02-G11-04) T-R02G1104-003 (FR-R02G1104-001 … 005, 007;
// SC-R02G1104-001 … 003; clarifications Q1 … Q4). Turns pointer events into Echo Cartographer gesture actions (pulse,
// claim, mark, move the panel's cursor, reset the view) and camera orbits, host-testable without a screen. A small state
// machine in the pattern of Backwards Aurora's gesture controller (feature 394):
//
// - One finger goes down: the point is picked once with `EchoCartographerPicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the touch-down snapshot (its knowledge and markers) is kept for the whole
//   gesture.
//   - `.marker(c)` or `.cell(c)`: a press on cell c (state `cellPress`), remembering whether it started on a marker.
//   - `.empty`: a press on empty space, tracked for a double tap (state `idle`).
// - The travel is the farthest distance of the finger from its touch-down point (the release point counts as a last
//   move).
//   - A press still under 10 points of travel whose `.moved` timestamp (checked before the move is applied) or
//     ``EchoCartographerGestureController/tick(at:)`` time is at least 0.5 s after touch-down arms its claim (state
//     `held`; a press on empty space never arms). Moving to 10 points or more of travel after arming cancels it:
//     nothing is sent at release, whatever the travel.
//   - A press not armed whose travel reaches 16 points becomes a drag: `markerDrag` from a marker, `cellDrag` from a
//     cell (a press on empty space stays `idle`).
// - Release:
//   - armed and still under 10 points: `[.claim(x, y), .moveCursor(x, y)]` of the pressed cell (a marker's cell for a
//     marker) while the play is playing, nothing otherwise;
//   - a marker drag: when the release point's floor cell (`EchoCartographerPicker.floorCell`) is a chamber cell other
//     than the marker's own with no marker in the touch-down snapshot, `[.mark(old), .mark(new), .moveCursor(new)]`
//     while playing; nothing otherwise;
//   - a cell drag: when the release point's floor cell is a chamber cell with no marker in the touch-down snapshot,
//     `[.mark(x, y), .moveCursor(x, y)]` while playing; nothing otherwise;
//   - travel 10 … 16 points (not armed): nothing;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on cell c (or a
//     marker's cell): `[.pulse(x, y)]` when c is known open in the touch-down snapshot and the play is playing, else
//     `[.moveCursor(x, y)]` (in any stage: the cursor is presentation state);
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture also a tap on empty space,
//     its `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit;
//   - a drag or held press from empty space: nothing.
// - Kernel actions (pulse, claim, mark) are produced only while the play given with the releasing event is playing;
//   in every other stage (loading, tutorial, paused, won, failed, result) only `moveCursor` (taps) and `resetView`.
// - A second finger cancels any one-finger gesture (nothing sent) and the fingers orbit (state `orbiting`):
//   yaw += Δx / width × 90°, pitch −= Δy / height × 60° (positive pitch looks more from above, so moving the fingers up
//   raises the eye, as in feature 394), clamped by `EchoCartographerOrbit.clamped()`; a third finger re-bases the
//   midpoint. A finger lifting while others stay → `cancelled` until every finger has lifted. A `.cancelled` phase
//   sends nothing.
//
// Only event timestamps (and the time given to `tick`) are read, never a clock. Presentation only: the orbit and the
// cursor never enter the digest, the snapshot's state or the kernel, which still applies its own rules (stage, known
// open, walls, the marker limit) to every action sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What an Echo Cartographer gesture asks for (feature 404).
public enum EchoCartographerGestureAction: Sendable, Equatable {
    /// Emit a pulse from cell (x, y): `cell.pulse`.
    case pulse(Int, Int)
    /// Claim a beacon at cell (x, y): `cell.claim`.
    case claim(Int, Int)
    /// Toggle a marker on cell (x, y): `cell.mark`.
    case mark(Int, Int)
    /// Move the panel's cursor to cell (x, y) (presentation only, nothing sent to the kernel).
    case moveCursor(Int, Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Echo Cartographer gesture actions and camera orbits (feature 404), deterministic for the
/// same events. See the file header for the rules.
public struct EchoCartographerGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit; also a press on empty space (tracked for a double tap).
        case idle
        /// One finger went down on a cell or a marker: a tap, a drag or a held press is still possible.
        case cellPress
        /// A press on a marker moved at least 16 points: the marker moves to the release cell.
        case markerDrag
        /// A press on a cell without a marker moved at least 16 points: a marker is placed on the release cell.
        case cellDrag
        /// A press held 0.5 s without moving 10 points: lifting it claims the cell.
        case held
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap or a held press, exclusive: 10.
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a drag: 16.
    public static let dragDistance: Double = 16
    /// The time in seconds (event timestamps) from touch-down at which a lift is no longer a tap, 0.5 (a tap lifts
    /// strictly before it).
    public static let tapDuration: Double = 0.5
    /// The time in seconds a press must be held without moving 10 points to arm its claim, 0.5.
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
    /// The camera orbit (presentation only; always clamped); ``EchoCartographerOrbit/authored`` at start.
    public private(set) var orbit: EchoCartographerOrbit = .authored

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap on empty space that may start a double tap: its lift point and its `.ended` timestamp.
    private var lastEmptyTap: (location: Vec2, time: Double)?

    /// A one-finger gesture in progress.
    private struct Touch: Sendable {
        /// The finger's pointer id.
        let pointer: Int
        /// Where the finger went down, in view points.
        let start: Vec2
        /// The touch-down timestamp.
        let time: Double
        /// The pressed cell, or nil for empty space.
        let cell: EchoCartographerCell?
        /// Whether the press started on a marker (of ``cell``).
        let onMarker: Bool
        /// The snapshot drawn at touch-down (its knowledge and markers decide the gesture).
        let snapshot: EchoCartographerSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// The last finite location of the finger.
        var last: Vec2
        /// Whether the press armed its claim.
        var armed: Bool
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: EchoCartographerSceneSnapshot) -> EchoCartographerCamera? {
        guard Self.usable(viewSize) else { return nil }
        return EchoCartographerSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one of `play`). Returns
    /// the actions the event produces (see the file header): everything on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: EchoCartographerSceneSnapshot,
                                play: EchoCartographerPlay) -> [EchoCartographerGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot)
            return []
        case .moved:
            moved(event, viewSize: viewSize)
            return []
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, play: play)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, play: play)
        }
    }

    /// Advances the presentation time to `time` (seconds, on the event timestamps' clock): a press on a cell or a marker
    /// held at least ``holdDuration`` since touch-down without moving ``tapDistance`` points arms its claim (state
    /// `held`). Anything else is unchanged.
    public mutating func tick(at time: Double) {
        guard state == .cellPress, var current = touch, time.isFinite, arms(current, at: time) else { return }
        current.armed = true
        touch = current
        state = .held
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

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: EchoCartographerSceneSnapshot) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot)
            } else {
                secondFinger()
            }
        case .cellPress, .markerDrag, .cellDrag, .held:
            secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) {
        switch state {
        case .idle, .cellPress, .markerDrag, .cellDrag, .held:
            guard var current = touch, current.pointer == event.id else { return }
            if state == .cellPress, event.timestamp.isFinite, arms(current, at: event.timestamp) {
                current.armed = true
                state = .held
            }
            follow(&current, to: event.location)
            advance(current)
            touch = current
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned: EchoCartographerOrbit =
                EchoCartographerOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                      pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
        case .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                play: EchoCartographerPlay) -> [EchoCartographerGestureAction] {
        switch state {
        case .idle, .cellPress, .markerDrag, .cellDrag, .held:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastEmptyTap = nil
                return []
            }
            if !current.armed, event.timestamp.isFinite, arms(current, at: event.timestamp) { current.armed = true }
            follow(&current, to: event.location)
            return release(current, at: event, viewSize: viewSize, play: play)
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
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: EchoCartographerSceneSnapshot) {
        var pick: EchoCartographerPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = EchoCartographerPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                               snapshot: snapshot, orbit: orbit)
        }
        var cell: EchoCartographerCell?
        var onMarker: Bool = false
        switch pick {
        case .marker(let c):
            cell = c
            onMarker = true
            state = .cellPress
        case .cell(let c):
            cell = c
            state = .cellPress
        case .empty:
            state = .idle
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, cell: cell, onMarker: onMarker,
                      snapshot: snapshot, travel: 0, last: event.location, armed: false)
    }

    /// Whether press `touch` arms its claim at `time`: on a cell, not a drag, not armed, under ``tapDistance`` of
    /// travel and held at least ``holdDuration``.
    private func arms(_ touch: Touch, at time: Double) -> Bool {
        guard touch.cell != nil, !touch.armed, touch.travel < Self.tapDistance, touch.time.isFinite else {
            return false
        }
        return time - touch.time >= Self.holdDuration
    }

    /// Turns a press on a cell that is not armed into a drag once its travel reaches ``dragDistance``.
    private mutating func advance(_ touch: Touch) {
        guard state == .cellPress, !touch.armed, touch.cell != nil, touch.travel >= Self.dragDistance else { return }
        state = touch.onMarker ? .markerDrag : .cellDrag
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event`.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  play: EchoCartographerPlay) -> [EchoCartographerGestureAction] {
        let playing: Bool = play.stage == .playing
        guard let cell = touch.cell else {
            return emptyRelease(touch, at: event)
        }
        lastEmptyTap = nil
        if touch.armed {
            guard touch.travel < Self.tapDistance, playing else { return [] }
            return [.claim(cell.x, cell.y), .moveCursor(cell.x, cell.y)]
        }
        if touch.travel >= Self.dragDistance {
            guard playing, Self.usable(viewSize),
                  let target = EchoCartographerPicker.floorCell(Self.simd(touch.last), size: Self.simd(viewSize),
                                                                snapshot: touch.snapshot, orbit: orbit),
                  !touch.snapshot.markers.contains(target) else { return [] }
            if touch.onMarker {
                guard target != cell else { return [] }
                return [.mark(cell.x, cell.y), .mark(target.x, target.y), .moveCursor(target.x, target.y)]
            }
            return [.mark(target.x, target.y), .moveCursor(target.x, target.y)]
        }
        guard isTap(touch, at: event) else { return [] }
        if playing && touch.snapshot.known(cell) == .open { return [.pulse(cell.x, cell.y)] }
        return [.moveCursor(cell.x, cell.y)]
    }

    /// The release of a gesture on empty space: a double tap resets the view, anything else sends nothing.
    private mutating func emptyRelease(_ touch: Touch, at event: PointerEvent) -> [EchoCartographerGestureAction] {
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

    /// Whether `touch` lifted by `event` is a tap: under ``tapDistance`` of travel, lifted less than ``tapDuration``
    /// after touch-down (finite timestamps and location).
    private func isTap(_ touch: Touch, at event: PointerEvent) -> Bool {
        let held: Double = event.timestamp - touch.time
        return !touch.armed && touch.travel < Self.tapDistance && held.isFinite && held >= 0
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
