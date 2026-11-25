// CelestialEclipseLabGestureController — feature 464 (R02-G17-04) T-R02G1704-003 (FR-R02G1704-001 … 004, 006, 007;
// SC-R02G1704-001 … 003; clarifications Q1 … Q5). Turns pointer events into Celestial Eclipse Lab gesture actions
// (choose a planet, show a tick, preview and set a phase, explain why a gesture does nothing, reset the view) and
// camera orbits, host-testable without a screen. A small state machine ported from Starlit Cartouche's gesture
// controller (feature 454), adapted to planets on their orbits with a time dial:
//
// - One finger goes down: the point is picked once with `CelestialEclipseLabPicker.pick(_:size:snapshot:orbit:)` at
//   the current orbit and the view's size; the touch-down snapshot (its bodies, phases, shown tick and stage) is kept
//   for the whole gesture.
//   - `.body(b)`: a press on planet b, movable or fixed (state `planetPress`).
//   - `.dial`: a dial drag from touch-down on (state `dialDrag`), in any stage: the touch-down sends `[.showTick(t)]`
//     for the tick t = `CelestialEclipseLabPicker.dialTick(_:size:snapshot:orbit:)` under the finger, and every later
//     move (the release point counting as a last move) sends `[.showTick(t)]` whenever t differs from the tick last
//     sent. Never a kernel action.
//   - `.empty`: a press on empty space (state `emptyPress`), tracked for a double tap.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag). A press on a planet whose travel reaches 16 points becomes a phase drag
//   (state `planetDrag`); a drag from empty space does nothing.
// - Phase drag, decided when the drag starts (by the move or the release that starts it):
//   - from a fixed planet: `[.explain(fixedReason)]` (in any stage), nothing else for the gesture;
//   - from a movable planet when the touch-down snapshot is not playing: `[.explain(finishedReason)]`, nothing else;
//   - from a movable planet while playing: on every move from the one that starts the drag on, the pending offset is
//     `CelestialEclipseLabPicker.ringOffset(_:body:size:snapshot:orbit:)` at the finger (on the touch-down snapshot
//     at the orbit); whenever it changes (the first time always), `[.preview(body: b, offset: p)]` is sent. A release
//     never sends a preview itself.
// - Release (`.ended`):
//   - a phase drag of a movable planet while playing: the offset p is the ring offset at the release point; when the
//     releasing snapshot is still playing and p differs from the touch-down snapshot's current phase of b,
//     `[.setPhase(body: b, offset: p)]` (`orbit.phase [b, p]`, one undo step; the presenter drops its preview), else
//     `[.clearPreview]`;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on planet b:
//     `[.choosePlanet(b)]` in any stage (`orbit.choose [b]`);
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture a tap on empty space, its
//     `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit. A completed
//     double tap starts no new one;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from empty space: nothing.
//     A dial drag sends only its ticks.
// - Kernel actions (`setPhase`) are produced only while playing; the presentation choices (`orbit.choose`,
//   `clock.show`) in any stage.
// - A second finger cancels any one-finger gesture — sending `[.clearPreview]` when a preview was pending, nothing
//   else — and the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the
//   fingers up raises the eye), clamped by `CelestialEclipseLabOrbit.clamped()`; a third finger re-bases the midpoint.
//   A finger lifting while others stay → `cancelled` until every finger has lifted. A `.cancelled` phase sends no
//   kernel action and no choice (only the same `[.clearPreview]` when a preview was pending). `cancel()` sends
//   nothing; the presenter clears its own preview when it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit, the choices and the preview never enter
// the digest or the kernel, which still applies its own rules (stage, a fixed body, the budget) to every phase sent.
// The controller calls only the picker's contract (`CelestialEclipseLabPicker.pick`, `dialTick`, `ringOffset`) and
// `CelestialEclipseLabSceneGeometry.camera(_:aspect:orbit:)`.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Celestial Eclipse Lab gesture asks for (feature 464, R02-G17-04).
public enum CelestialEclipseLabGestureAction: Sendable, Equatable {
    /// Choose planet `index` (movable or fixed): `orbit.choose [index]` (presentation only, never an undo step).
    case choosePlanet(Int)
    /// Show tick `tick` (0 … horizon − 1) on the time dial: `clock.show [tick]` (presentation only).
    case showTick(Int)
    /// Set planet `body`'s phase to `offset`: `orbit.phase [body, offset]` (one undo step); sent only while playing
    /// and only when `offset` differs from the body's current phase.
    case setPhase(body: Int, offset: Int)
    /// The pending offset of a phase drag is `offset` for planet `body`: the presenter previews it
    /// (`CelestialEclipseLabSceneSnapshot.previewing(body:offset:)`; presentation only).
    case preview(body: Int, offset: Int)
    /// The pending offset is gone: the presenter drops its preview.
    case clearPreview
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
    /// Why the gesture does nothing (a fixed planet, the play is over); shown in the description.
    case explain(String)
}

/// Turns pointer events into Celestial Eclipse Lab gesture actions and camera orbits (feature 464), deterministic for
/// the same events. See the file header for the rules.
public struct CelestialEclipseLabGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on a planet: a tap or a phase drag is still possible.
        case planetPress
        /// A press on a planet moved at least 16 points: a phase drag.
        case planetDrag
        /// One finger went down on the time dial: every change of the tick under it is shown.
        case dialDrag
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

    /// The explanation of a phase drag from a fixed planet (in any stage).
    public static let fixedReason: String = "This planet is fixed: its phase cannot change"
    /// The explanation of a phase drag from a movable planet when the play is not playing (won or failed).
    public static let finishedReason: String = "The play is over: undo or go to the next level"

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``CelestialEclipseLabOrbit/authored`` at start.
    public private(set) var orbit: CelestialEclipseLabOrbit = .authored

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
        /// Planet `index` (movable or fixed).
        case planet(Int)
        /// The time dial.
        case dial
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
        let snapshot: CelestialEclipseLabSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether a press on a planet became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The pending offset a phase drag last previewed, nil when none is.
        var pending: Int?
        /// The tick a dial drag last sent.
        var tick: Int?
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: CelestialEclipseLabSceneSnapshot) -> CelestialEclipseLabCamera? {
        guard Self.usable(viewSize) else { return nil }
        return CelestialEclipseLabSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one). Returns the
    /// actions the event produces (see the file header): ticks on dial touches and moves, previews and explanations on
    /// phase-drag moves, a clearing value on a cancel, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: CelestialEclipseLabSceneSnapshot) -> [CelestialEclipseLabGestureAction] {
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
                                snapshot: CelestialEclipseLabSceneSnapshot) -> [CelestialEclipseLabGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil { return start(event, viewSize: viewSize, snapshot: snapshot) }
            return secondFinger()
        case .planetPress, .planetDrag, .dialDrag, .emptyPress:
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger moved: the one-finger gesture follows it, or the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [CelestialEclipseLabGestureAction] {
        switch state {
        case .idle, .planetPress, .planetDrag, .dialDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [CelestialEclipseLabGestureAction] = follow(&current, to: event.location,
                                                                     viewSize: viewSize, previewing: true)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: CelestialEclipseLabOrbit =
                CelestialEclipseLabOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
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
                                snapshot: CelestialEclipseLabSceneSnapshot) -> [CelestialEclipseLabGestureAction] {
        switch state {
        case .idle, .planetPress, .planetDrag, .dialDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.pending == nil ? [] : [.clearPreview]
            }
            let last: [CelestialEclipseLabGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
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
    /// dial shows the tick under it at once.
    private mutating func start(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: CelestialEclipseLabSceneSnapshot) -> [CelestialEclipseLabGestureAction] {
        var pick: CelestialEclipseLabPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = CelestialEclipseLabPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                                  snapshot: snapshot, orbit: orbit)
        }
        var target: Target = .nothing
        switch pick {
        case .body(let index):
            if snapshot.bodies.indices.contains(index) { target = .planet(index) }
        case .dial:
            target = .dial
        case .empty:
            target = .nothing
        }
        switch target {
        case .planet: state = .planetPress
        case .dial: state = .dialDrag
        case .nothing: state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, travel: 0, dragging: false, pending: nil, tick: nil)
        var actions: [CelestialEclipseLabGestureAction] = []
        if target == .dial {
            let tick: Int = dialTick(event.location, viewSize: viewSize, snapshot: snapshot)
            current.tick = tick
            actions = [.showTick(tick)]
        }
        touch = current
        return actions
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing) in a view of `viewSize`: a dial
    /// drag sends a changed tick; the travel grows to the farthest distance from the start; a press on a planet
    /// reaching ``dragDistance`` becomes a phase drag (explaining once for a fixed planet or outside playing); when
    /// `previewing` (a move, not the release) a phase drag of a movable planet while playing sends a change of its
    /// pending offset.
    private mutating func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                                 previewing: Bool) -> [CelestialEclipseLabGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        if touch.target == .dial {
            let tick: Int = dialTick(location, viewSize: viewSize, snapshot: touch.snapshot)
            guard tick != touch.tick else { return [] }
            touch.tick = tick
            return [.showTick(tick)]
        }
        guard case .planet(let body) = touch.target else { return [] }
        if !touch.dragging && touch.travel >= Self.dragDistance {
            touch.dragging = true
            if state == .planetPress { state = .planetDrag }
            if touch.snapshot.bodies[body].fixed { return [.explain(Self.fixedReason)] }
            if touch.snapshot.stage != .playing { return [.explain(Self.finishedReason)] }
        }
        guard previewing, Self.phaseDrag(touch) else { return [] }
        let offset: Int = ringOffset(location, body: body, viewSize: viewSize, snapshot: touch.snapshot)
        guard offset != touch.pending else { return [] }
        touch.pending = offset
        return [.preview(body: body, offset: offset)]
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed) in a
    /// view of `viewSize`; `snapshot` is the releasing snapshot.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  snapshot: CelestialEclipseLabSceneSnapshot) -> [CelestialEclipseLabGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        switch touch.target {
        case .planet(let body):
            lastTap = nil
            if Self.phaseDrag(touch) {
                let offset: Int = ringOffset(event.location, body: body, viewSize: viewSize,
                                             snapshot: touch.snapshot)
                let current: Int = touch.snapshot.phases.indices.contains(body) ? touch.snapshot.phases[body] : offset
                if snapshot.stage == .playing && offset != current { return [.setPhase(body: body, offset: offset)] }
                return [.clearPreview]
            }
            return tap ? [.choosePlanet(body)] : []
        case .dial:
            lastTap = nil
            return []
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

    /// Cancels any one-finger gesture for a second finger (sending only `clearPreview` when a preview was pending)
    /// and starts an orbit from the current midpoint.
    private mutating func secondFinger() -> [CelestialEclipseLabGestureAction] {
        var actions: [CelestialEclipseLabGestureAction] = []
        if let current = touch, current.pending != nil { actions = [.clearPreview] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// Whether `touch` is a phase drag that previews and may set a phase: a drag of a movable planet begun while the
    /// touch-down snapshot was playing.
    private static func phaseDrag(_ touch: Touch) -> Bool {
        guard touch.dragging, case .planet(let body) = touch.target else { return false }
        return !touch.snapshot.bodies[body].fixed && touch.snapshot.stage == .playing
    }

    /// The tick 0 … horizon − 1 under `location` on the dial of a view of `viewSize` showing `snapshot` at the orbit
    /// (the picker's fallback, the shown tick, for unusable input).
    private func dialTick(_ location: Vec2, viewSize: Vec2, snapshot: CelestialEclipseLabSceneSnapshot) -> Int {
        CelestialEclipseLabPicker.dialTick(Self.simd(location), size: Self.simd(viewSize), snapshot: snapshot,
                                           orbit: orbit)
    }

    /// The ring offset of planet `body` under `location` in a view of `viewSize` showing `snapshot` at the orbit (the
    /// picker's fallback, the current phase, for unusable input).
    private func ringOffset(_ location: Vec2, body: Int, viewSize: Vec2,
                            snapshot: CelestialEclipseLabSceneSnapshot) -> Int {
        CelestialEclipseLabPicker.ringOffset(Self.simd(location), body: body, size: Self.simd(viewSize),
                                             snapshot: snapshot, orbit: orbit)
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
