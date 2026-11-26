// ApsidesWorkshopGestureController — feature 474 (R02-G18-04) T-R02G1804-003 (FR-R02G1804-001 … 004, 006, 007;
// SC-R02G1804-001 … 003; clarifications Q1 … Q5). Turns pointer events into Apsides Workshop gesture actions (tune
// the periapsis knob or the size, show a tick, preview a pending orbit, explain why a gesture does nothing, reset the
// view) and camera orbits, host-testable without a screen. A small state machine ported from Celestial Eclipse Lab's
// gesture controller (feature 464), adapted to an orbit tuned by its periapsis knob and its size handle:
//
// - One finger goes down: the point is picked once with `ApsidesWorkshopPicker.pick(_:size:snapshot:orbit:)` at the
//   current view orbit and the view's size; the touch-down snapshot (its orbit, positions, shown tick and stage) is
//   kept for the whole gesture.
//   - `.knob`: a press on the periapsis knob (state `knobPress`); `.sizeHandle`: on the size handle (`handlePress`).
//   - `.orbiter`: the time crank from touch-down on (state `orbiterPress`, `crankDrag` once a tick changed), in any
//     stage: the tick t0 = `ApsidesWorkshopPicker.crankTick(_:size:snapshot:orbit:)` under the finger is read at
//     touch-down (nothing sent), and every later move (the release point counting as a last move) sends
//     `[.showTick(t)]` whenever t differs from the tick last read. Never a kernel action.
//   - `.loop`: a press on the orbit loop (state `orbiterPress`, never a crank).
//   - `.empty`: a press on empty space (state `emptyPress`), tracked for a double tap.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag). A press on a handle whose travel reaches 16 points becomes a drag
//   (state `knobDrag` or `handleDrag`); a drag from the loop or empty space does nothing.
// - Handle drag, decided when the drag starts (by the move or the release that starts it):
//   - when the touch-down snapshot is not playing: `[.explain(finishedReason)]`, nothing else for the gesture;
//   - while playing: on every move from the one that starts the drag on, the pending orbit is
//     `ApsidesWorkshopPicker.knobSteps` (the knob) or `handleSize` (the size handle) at the finger, on the touch-down
//     snapshot at the view orbit (a point casting onto no sky point changes nothing). Whenever it changes (the first
//     time always): a valid pending orbit sends `[.preview(orbit)]`; an invalid one sends `[.clearPreview]` when a
//     preview was showing and `[.explain(reason)]` when its reason (``invalidReason(_:)``) differs from the one last
//     explained since the pending orbit was last valid — so each turn to invalid explains once. A release never
//     previews or explains itself.
// - Release (`.ended`):
//   - a handle drag while playing: the pending orbit read at the release point (else the last one read); when the
//     releasing snapshot is still playing and that orbit is valid and differs from the touch-down snapshot's orbit,
//     `[.tunePeriapsis(eccentricity: k, direction: d)]` (`orbit.periapsis [k, d]`) or `[.tuneSize(a)]`
//     (`orbit.size [a]`), one undo step each (the presenter drops its preview); else `[.clearPreview]`;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on the knob or the
//     size handle: `[.explain(handleReason)]` in any stage;
//   - a tap on the orbiter or the loop: `[.showTick(t)]` with the crank tick t at the release point, in any stage —
//     unless the crank already showed a tick during this gesture (it then sent its ticks only);
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture a tap on empty space, its
//     `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit. A completed
//     double tap starts no new one;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from the loop or empty
//     space: nothing. A crank drag sends only its ticks.
// - Kernel actions (`tunePeriapsis`, `tuneSize`) are produced only while playing; `clock.show` in any stage.
// - A second finger cancels any one-finger gesture — sending `[.clearPreview]` when a preview was showing, nothing
//   else — and the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the
//   fingers up raises the eye), clamped by `ApsidesWorkshopViewOrbit.clamped()`; a third finger re-bases the midpoint.
//   A finger lifting while others stay → `cancelled` until every finger has lifted. A `.cancelled` phase sends no
//   kernel action and no tick (only the same `[.clearPreview]` when a preview was showing). `cancel()` sends nothing;
//   the presenter clears its own preview when it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the view orbit, the ticks and the preview never
// enter the digest or the kernel, which still applies its own rules (stage, validity, the budget) to every tuning sent.
// The controller calls only the picker's contract (`ApsidesWorkshopPicker.pick`, `crankTick`, `knobSteps`,
// `handleSize`) and `ApsidesWorkshopSceneGeometry.camera(aspect:orbit:)`.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What an Apsides Workshop gesture asks for (feature 474, R02-G18-04).
public enum ApsidesWorkshopGestureAction: Sendable, Equatable {
    /// Set the periapsis knob to eccentricity step `eccentricity` (0 … 15) and direction step `direction` (0 … 23):
    /// `orbit.periapsis [k, d]` (one undo step); sent only while playing, for a valid orbit differing from the current.
    case tunePeriapsis(eccentricity: Int, direction: Int)
    /// Set the size to `a` lattice units (8 … 48): `orbit.size [a]` (one undo step); sent only while playing, for a
    /// valid orbit differing from the current.
    case tuneSize(Int)
    /// Show tick `tick` (0 … period − 1) of the orbit: `clock.show [tick]` (presentation only).
    case showTick(Int)
    /// The pending orbit of a drag is `orbit` (always valid): the presenter previews it
    /// (`ApsidesWorkshopSceneSnapshot.previewing(_:)`; presentation only).
    case preview(ApsidesWorkshopOrbit)
    /// The pending orbit is gone or invalid: the presenter drops its preview.
    case clearPreview
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
    /// Why the gesture does nothing (a handle tapped, an invalid pending orbit, the play is over); shown in the
    /// description.
    case explain(String)
}

/// Turns pointer events into Apsides Workshop gesture actions and camera orbits (feature 474), deterministic for the
/// same events. See the file header for the rules.
public struct ApsidesWorkshopGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on the periapsis knob: a tap or a knob drag is still possible.
        case knobPress
        /// A press on the knob moved at least 16 points: a knob drag.
        case knobDrag
        /// One finger went down on the size handle: a tap or a size drag is still possible.
        case handlePress
        /// A press on the size handle moved at least 16 points: a size drag.
        case handleDrag
        /// One finger went down on the orbiter or the orbit loop: a tap (or, from the orbiter, the crank) is possible.
        case orbiterPress
        /// A press on the orbiter changed the tick under the finger: the time crank turns.
        case crankDrag
        /// One finger went down on empty space, tracked for a double tap.
        case emptyPress
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
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The explanation of a handle drag when the play is not playing (won or failed).
    public static let finishedReason: String = "The play is over: undo or go to the next level"
    /// The explanation of a tap on the knob or the size handle (in any stage).
    public static let handleReason: String = "Drag the knob or the size handle to tune the orbit"
    /// The explanation of a pending orbit whose periapsis distance a(20 − k) is below 60.
    public static let dipReason: String = "The periapsis would dip into the star"
    /// The explanation of a pending orbit whose apoapsis distance a(20 + k) is above 1280.
    public static let leaveReason: String = "The apoapsis would leave the sky"

    /// Why `orbit` is invalid: ``dipReason`` when a(20 − k) < 60, else ``leaveReason`` when a(20 + k) > 1280, else
    /// (a step out of range) ``dipReason`` for an eccentricity above the range and ``leaveReason`` otherwise; nil for a
    /// valid orbit.
    public static func invalidReason(_ orbit: ApsidesWorkshopOrbit) -> String? {
        guard !orbit.isValid else { return nil }
        if orbit.periapsisDistance < 60 { return dipReason }
        if orbit.apoapsisDistance > 1280 { return leaveReason }
        return orbit.eccentricity > ApsidesWorkshopOrbit.eccentricities.upperBound ? dipReason : leaveReason
    }

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``ApsidesWorkshopViewOrbit/authored`` at start.
    public private(set) var orbit: ApsidesWorkshopViewOrbit = .authored

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap on empty space that may start a double tap: its lift point and its `.ended` timestamp.
    private var lastTap: (location: Vec2, time: Double)?

    /// What a one-finger gesture went down on.
    private enum Target: Sendable, Equatable {
        /// The periapsis knob.
        case knob
        /// The size handle.
        case sizeHandle
        /// The orbiter (the time crank).
        case orbiter
        /// The orbit loop.
        case loop
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
        /// The touch-down snapshot.
        let snapshot: ApsidesWorkshopSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether a press on a handle became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The pending orbit a handle drag last read (valid or not), nil before the first.
        var pending: ApsidesWorkshopOrbit?
        /// Whether a preview is showing (the last pending orbit sent was valid).
        var previewing: Bool
        /// The reason last explained since the pending orbit was last valid.
        var explained: String?
        /// The tick the crank last read.
        var tick: Int?
        /// Whether the crank showed a tick during the gesture.
        var cranked: Bool
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points at the current orbit, or nil for a view that is not finite
    /// and positive.
    public func camera(viewSize: Vec2) -> ApsidesWorkshopCamera? {
        guard Self.usable(viewSize) else { return nil }
        return ApsidesWorkshopSceneGeometry.camera(aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one). Returns the
    /// actions the event produces (see the file header): ticks on crank moves, previews, clearing values and
    /// explanations on handle-drag moves, a clearing value on a cancel, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: ApsidesWorkshopSceneSnapshot) -> [ApsidesWorkshopGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            return began(event, viewSize: viewSize, snapshot: snapshot)
        case .moved:
            return moved(event, viewSize: viewSize)
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, snapshot: snapshot)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, snapshot: snapshot)
        }
    }

    /// Returns the camera to the authored orbit (the panel's "Reset view"); an orbit in progress continues from the
    /// fingers' current midpoint.
    public mutating func resetView() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel; the presenter clears
    /// its own preview); the orbit is kept, and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        orbitMidpoint = nil
        lastTap = nil
        state = .idle
    }

    // MARK: Phases

    /// A finger went down: a first finger starts a one-finger gesture, a second cancels it (clearing a preview) and
    /// orbits, a third re-bases the orbit's midpoint.
    private mutating func began(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: ApsidesWorkshopSceneSnapshot) -> [ApsidesWorkshopGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil { return start(event, viewSize: viewSize, snapshot: snapshot) }
            return secondFinger()
        case .knobPress, .knobDrag, .handlePress, .handleDrag, .orbiterPress, .crankDrag, .emptyPress:
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger moved: the one-finger gesture follows it, or the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [ApsidesWorkshopGestureAction] {
        switch state {
        case .idle, .knobPress, .knobDrag, .handlePress, .handleDrag, .orbiterPress, .crankDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [ApsidesWorkshopGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                                 previewing: true)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: ApsidesWorkshopViewOrbit =
                ApsidesWorkshopViewOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                         pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger lifted (or was cancelled): the one-finger gesture is released, an orbit ends or a cancelled gesture
    /// waits for the last finger.
    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                snapshot: ApsidesWorkshopSceneSnapshot) -> [ApsidesWorkshopGestureAction] {
        switch state {
        case .idle, .knobPress, .knobDrag, .handlePress, .handleDrag, .orbiterPress, .crankDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.previewing ? [.clearPreview] : []
            }
            let last: [ApsidesWorkshopGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                              previewing: false)
            return last + release(current, at: event, viewSize: viewSize, snapshot: snapshot)
        case .orbiting:
            orbitMidpoint = nil
            state = tracker.count == 0 ? .idle : .cancelled
        case .cancelled:
            if tracker.count == 0 { state = .idle }
        }
        return []
    }

    // MARK: Gestures

    /// Starts a one-finger gesture: picks the touch-down point once and decides what the gesture is on; a touch on the
    /// orbiter reads the tick under it (nothing sent).
    private mutating func start(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: ApsidesWorkshopSceneSnapshot) -> [ApsidesWorkshopGestureAction] {
        var pick: ApsidesWorkshopPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = ApsidesWorkshopPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                              snapshot: snapshot, orbit: orbit)
        }
        let target: Target
        switch pick {
        case .knob:
            target = .knob
            state = .knobPress
        case .sizeHandle:
            target = .sizeHandle
            state = .handlePress
        case .orbiter:
            target = .orbiter
            state = .orbiterPress
        case .loop:
            target = .loop
            state = .orbiterPress
        case .empty:
            target = .nothing
            state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, travel: 0, dragging: false, pending: nil, previewing: false,
                                   explained: nil, tick: nil, cranked: false)
        if target == .orbiter {
            current.tick = crankTick(event.location, viewSize: viewSize, snapshot: snapshot)
        }
        touch = current
        return []
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing) in a view of `viewSize`: the crank
    /// sends a changed tick; the travel grows to the farthest distance from the start; a press on a handle reaching
    /// ``dragDistance`` becomes a drag (explaining once outside playing); when `previewing` (a move, not the release) a
    /// handle drag while playing sends a change of its pending orbit (a preview, or a clearing value and an
    /// explanation).
    private mutating func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                                 previewing: Bool) -> [ApsidesWorkshopGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        if touch.target == .orbiter {
            let tick: Int = crankTick(location, viewSize: viewSize, snapshot: touch.snapshot)
            guard tick != touch.tick else { return [] }
            touch.tick = tick
            touch.cranked = true
            if state == .orbiterPress { state = .crankDrag }
            return [.showTick(tick)]
        }
        guard touch.target == .knob || touch.target == .sizeHandle else { return [] }
        if !touch.dragging && touch.travel >= Self.dragDistance {
            touch.dragging = true
            if state == .knobPress { state = .knobDrag }
            if state == .handlePress { state = .handleDrag }
            if touch.snapshot.stage != .playing { return [.explain(Self.finishedReason)] }
        }
        guard previewing, Self.tuningDrag(touch) else { return [] }
        guard let pending = pendingOrbit(location, touch: touch, viewSize: viewSize),
              pending != touch.pending else { return [] }
        touch.pending = pending
        if let reason = Self.invalidReason(pending) {
            var actions: [ApsidesWorkshopGestureAction] = []
            if touch.previewing { actions.append(.clearPreview) }
            touch.previewing = false
            if reason != touch.explained {
                touch.explained = reason
                actions.append(.explain(reason))
            }
            return actions
        }
        touch.previewing = true
        touch.explained = nil
        return [.preview(pending)]
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed) in a
    /// view of `viewSize`; `snapshot` is the releasing snapshot.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  snapshot: ApsidesWorkshopSceneSnapshot) -> [ApsidesWorkshopGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        switch touch.target {
        case .knob, .sizeHandle:
            lastTap = nil
            if Self.tuningDrag(touch) {
                let read: ApsidesWorkshopOrbit? = pendingOrbit(event.location, touch: touch, viewSize: viewSize)
                let current: ApsidesWorkshopOrbit = touch.snapshot.orbit
                if let pending = read ?? touch.pending, pending.isValid, pending != current,
                   snapshot.stage == .playing {
                    if touch.target == .knob {
                        return [.tunePeriapsis(eccentricity: pending.eccentricity, direction: pending.direction)]
                    }
                    return [.tuneSize(pending.size)]
                }
                return [.clearPreview]
            }
            return tap ? [.explain(Self.handleReason)] : []
        case .orbiter, .loop:
            lastTap = nil
            guard tap, !touch.cranked else { return [] }
            return [.showTick(crankTick(event.location, viewSize: viewSize, snapshot: touch.snapshot))]
        case .nothing:
            guard tap else {
                lastTap = nil
                return []
            }
            guard secondTap(at: event) else {
                lastTap = (event.location, event.timestamp)
                return []
            }
            lastTap = nil
            resetView()
            return [.resetView]
        }
    }

    /// Whether a tap on empty space lifted by `event` is the second tap of a double tap: the last tap was on empty
    /// space, its `.ended` at most ``doubleTapWindow`` earlier and its lift point at most ``doubleTapDistance`` away.
    private func secondTap(at event: PointerEvent) -> Bool {
        guard let last = lastTap else { return false }
        let gap: Double = event.timestamp - last.time
        return gap >= 0 && gap <= Self.doubleTapWindow
            && (event.location - last.location).length <= Self.doubleTapDistance
    }

    /// Whether `touch` lifted by `event` is a tap: not a drag, under ``tapDistance`` of travel, lifted less than
    /// ``tapDuration`` after touch-down (finite timestamps and location).
    private func isTap(_ touch: Touch, at event: PointerEvent) -> Bool {
        let held: Double = event.timestamp - touch.time
        return !touch.dragging && touch.travel < Self.tapDistance && held.isFinite && held >= 0
            && held < Self.tapDuration && event.location.isFinite
    }

    /// Cancels any one-finger gesture for a second finger (sending only `clearPreview` when a preview was showing)
    /// and starts an orbit from the current midpoint.
    private mutating func secondFinger() -> [ApsidesWorkshopGestureAction] {
        var actions: [ApsidesWorkshopGestureAction] = []
        if let current = touch, current.previewing { actions = [.clearPreview] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// Whether `touch` is a tuning drag that previews and may tune: a drag of the knob or the size handle begun while
    /// the touch-down snapshot was playing.
    private static func tuningDrag(_ touch: Touch) -> Bool {
        guard touch.dragging, touch.target == .knob || touch.target == .sizeHandle else { return false }
        return touch.snapshot.stage == .playing
    }

    /// The pending orbit `touch`'s handle reads under `location` in a view of `viewSize` on its touch-down snapshot at
    /// the view orbit (not checked for validity); nil when the point casts onto no sky point.
    private func pendingOrbit(_ location: Vec2, touch: Touch, viewSize: Vec2) -> ApsidesWorkshopOrbit? {
        guard location.isFinite else { return nil }
        if touch.target == .knob {
            return ApsidesWorkshopPicker.knobSteps(Self.simd(location), size: Self.simd(viewSize),
                                                   snapshot: touch.snapshot, orbit: orbit)
        }
        return ApsidesWorkshopPicker.handleSize(Self.simd(location), size: Self.simd(viewSize),
                                                snapshot: touch.snapshot, orbit: orbit)
    }

    /// The crank tick 0 … period − 1 under `location` in a view of `viewSize` showing `snapshot` at the view orbit (the
    /// picker's fallback, the shown tick, for unusable input).
    private func crankTick(_ location: Vec2, viewSize: Vec2, snapshot: ApsidesWorkshopSceneSnapshot) -> Int {
        ApsidesWorkshopPicker.crankTick(Self.simd(location), size: Self.simd(viewSize), snapshot: snapshot,
                                        orbit: orbit)
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
