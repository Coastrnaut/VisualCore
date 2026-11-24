// VoxelOrigamiGestureController — feature 444 (R02-G15-04) T-R02G1504-003 (FR-R02G1504-001, 002, 004, 005;
// SC-R02G1504-001 … 003; clarifications Q1 … Q5). Turns pointer events into Voxel Origami gesture actions (choose a
// hinge, preview and send a quarter turn of a hinge, explain why a gesture does nothing, reset the view) and camera
// orbits, host-testable without a screen. A small state machine in the pattern of Moonlit Mechanism's gesture
// controller (feature 434), adapted to a chain of hinged cubes seen in three dimensions:
//
// - One finger goes down: the point is picked once with `VoxelOrigamiPicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the touch-down snapshot (its cubes, turns, turnable hinges, stage and actions
//   left) is kept for the whole gesture.
//   - `.cube(h)`: a press on cube h (state `cubePress`; h = 0 is the root, which has no hinge). When h ≥ 1, the
//     touch-down snapshot is playing and h is one of its turnable hinges, the turn prediction
//     `VoxelOrigamiPicker.prediction(_:size:snapshot:orbit:)` is computed once here.
//   - `.empty`: a press on empty space (state `emptyPress`), tracked for a double tap.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag). A press on a cube whose travel reaches 16 points becomes a cube drag
//   (state `cubeDrag`); a drag from empty space does nothing.
// - Cube drag, decided once when the drag starts (by the move or the release that starts it):
//   - from the root (any stage): `[.explain(rootReason)]`, nothing else for the gesture;
//   - otherwise, when the touch-down snapshot is not playing: on won, failed or result
//     `[.explain(finishedReason)]`, on loading, tutorial or paused nothing; nothing else for the gesture;
//   - otherwise, from a hinge that is not turnable in the touch-down snapshot (it swings nothing):
//     `[.explain(idleReason(h))]`, nothing else for the gesture;
//   - otherwise (a turnable hinge while playing, with a prediction): on every move from the one that starts the drag
//     on, the step `prediction.step(for: d, threshold: 24)` for the finger's travel d (the vector from the touch-down
//     point to the finger) is the pending step; whenever it changes, `[.pendingTurn(hinge: h, step: s)]` is sent for
//     a step s, or `[.clearPending]` when it falls back to none. A release never sends a pending preview itself.
// - Release (`.ended`):
//   - a cube drag of a turnable hinge: `[.clearPending]` when a step was pending, followed, when the releasing
//     snapshot is playing and the step for the release point is ±1, by `.turn(hinge: h, step: s)` (one quarter turn,
//     `hinge.turn [h, s]`); other cube drags: nothing more;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on a non-root cube
//     h: `[.chooseHinge(h)]` in any stage; as the second tap of a double tap (the previous gesture a tap on the same
//     cube, its `.ended` at most 0.35 s earlier and at most 22 points away): while the releasing snapshot is playing,
//     `[.turn(hinge: h, step: 1)]` when h is one of its turnable hinges, else `[.explain(idleReason(h))]` (the first
//     tap already chose it); on won, failed or result `[.chooseHinge(h), .explain(finishedReason)]`; on loading,
//     tutorial or paused `[.chooseHinge(h)]`. A completed double tap starts no new one;
//   - a tap on the root: nothing;
//   - a tap on empty space: nothing; as the second tap of a double tap on empty space (same window and distance),
//     `[.resetView]` and the authored orbit;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from empty space: nothing.
// - Kernel actions (`turn`) are produced only while playing; `chooseHinge` (the adapter's presentation-only
//   `hinge.choose`) in any stage.
// - A second finger cancels any one-finger gesture — sending `[.clearPending]` when a step was pending, nothing else —
//   and the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the fingers
//   up raises the eye), clamped by `VoxelOrigamiOrbit.clamped()`; a third finger re-bases the midpoint. A finger
//   lifting while others stay → `cancelled` until every finger has lifted. A `.cancelled` phase sends no kernel action
//   (only the same `[.clearPending]` when a step was pending). `cancel()` sends nothing; the presenter clears its own
//   pending text when it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit, the chosen hinge and the pending turn
// never enter the digest, the snapshot's state or the kernel, which still applies its own rules (stage, the budget,
// collisions and sweeps, a hinge that swings nothing) to every action sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Voxel Origami gesture asks for (feature 444).
public enum VoxelOrigamiGestureAction: Sendable, Equatable {
    /// Choose hinge `index` (1 … cubes − 1) as the panel's hinge: `hinge.choose [index]` (presentation only, never an
    /// undo step).
    case chooseHinge(Int)
    /// The pending quarter turn of a cube drag: hinge `hinge` by `step` (±1) (presentation only).
    case pendingTurn(hinge: Int, step: Int)
    /// The pending quarter turn is gone (the drag fell back below the threshold, ended or was cancelled; presentation
    /// only).
    case clearPending
    /// Turn hinge `hinge` one quarter turn by `step` (±1): `hinge.turn [hinge, step]` (one undo step).
    case turn(hinge: Int, step: Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
    /// Why the gesture does nothing (the root has no hinge, the hinge swings nothing, the play is over); the presenter
    /// shows it in the description.
    case explain(String)
}

/// Turns pointer events into Voxel Origami gesture actions and camera orbits (feature 444), deterministic for the same
/// events. See the file header for the rules.
public struct VoxelOrigamiGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on a cube: a tap, a double tap or a cube drag is still possible.
        case cubePress
        /// A press on a cube moved at least 16 points: a cube drag.
        case cubeDrag
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
    /// The projection in view points of the finger's travel onto a predicted motion at which a quarter turn becomes
    /// pending, 24.
    public static let turnDistance: Double = 24
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The explanation of a drag from the root cube (cube 0), which has no hinge.
    public static let rootReason: String = "The root cube has no hinge"
    /// The explanation of a drag, or a double tap, on a won, failed or shown-result play.
    public static let finishedReason: String = "The play is over: undo or go to the next level"

    /// The explanation of a drag, or a double tap, on hinge `hinge` while it swings no cube.
    public static func idleReason(_ hinge: Int) -> String {
        "Nothing would move: hinge \(hinge) swings no cube"
    }

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``VoxelOrigamiOrbit/authored`` at start.
    public private(set) var orbit: VoxelOrigamiOrbit = .authored

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap that may start a double tap: what it was on, its lift point and its `.ended` timestamp.
    private var lastTap: (target: Target, location: Vec2, time: Double)?

    /// What a one-finger gesture went down on.
    private enum Target: Sendable, Equatable {
        /// Cube `index` (0 is the root).
        case cube(Int)
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
        /// The touch-down snapshot (cubes, turns, turnable hinges, stage, actions left).
        let snapshot: VoxelOrigamiSceneSnapshot
        /// The turn prediction of the touched hinge: only for a turnable hinge (≥ 1) of a playing touch-down snapshot
        /// whose prediction exists.
        let prediction: VoxelOrigamiTurnPrediction?
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether the press became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The pending step shown (±1), nil when none is.
        var pending: Int?
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: VoxelOrigamiSceneSnapshot) -> VoxelOrigamiCamera? {
        guard Self.usable(viewSize) else { return nil }
        return VoxelOrigamiSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one: the cubes, the
    /// turns, the turnable hinges, the stage and the actions left). Returns the actions the event produces (see the
    /// file header): pending previews and explanations on moves, a clearing value on a cancel, everything else on
    /// release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: VoxelOrigamiSceneSnapshot) -> [VoxelOrigamiGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            return began(event, viewSize: viewSize, snapshot: snapshot)
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

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel; the presenter clears
    /// its own pending text); the orbit is kept, and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        orbitMidpoint = nil
        lastTap = nil
        state = .idle
    }

    // MARK: Phases

    /// A finger went down: a first finger starts a one-finger gesture, a second cancels it (clearing a pending step)
    /// and orbits, a third re-bases the orbit's midpoint.
    private mutating func began(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: VoxelOrigamiSceneSnapshot) -> [VoxelOrigamiGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot)
                return []
            }
            return secondFinger()
        case .cubePress, .cubeDrag, .emptyPress:
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger moved: the one-finger gesture follows it (perhaps becoming a drag, sending its explanation or a change
    /// of its pending step), or the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [VoxelOrigamiGestureAction] {
        switch state {
        case .idle, .cubePress, .cubeDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            var actions: [VoxelOrigamiGestureAction] = follow(&current, to: event.location)
            if current.dragging, let prediction = current.prediction, case .cube(let hinge) = current.target {
                let step: Int? = Self.step(prediction, from: current.start, to: event.location)
                if step != current.pending {
                    if let s = step {
                        actions.append(.pendingTurn(hinge: hinge, step: s))
                    } else {
                        actions.append(.clearPending)
                    }
                    current.pending = step
                }
            }
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: VoxelOrigamiOrbit =
                VoxelOrigamiOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
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
                                snapshot: VoxelOrigamiSceneSnapshot) -> [VoxelOrigamiGestureAction] {
        switch state {
        case .idle, .cubePress, .cubeDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.pending == nil ? [] : [.clearPending]
            }
            let started: [VoxelOrigamiGestureAction] = follow(&current, to: event.location)
            return started + release(current, at: event, snapshot: snapshot)
        case .orbiting:
            orbitMidpoint = nil
            state = tracker.count == 0 ? .idle : .cancelled
        case .cancelled:
            if tracker.count == 0 { state = .idle }
        }
        return []
    }

    // MARK: Gestures

    /// Starts a one-finger gesture: picks the touch-down point once, decides what the gesture is on and, for a
    /// turnable hinge while playing, computes its turn prediction.
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: VoxelOrigamiSceneSnapshot) {
        var pick: VoxelOrigamiPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = VoxelOrigamiPicker.pick(Self.simd(event.location), size: Self.simd(viewSize), snapshot: snapshot,
                                           orbit: orbit)
        }
        var target: Target = .nothing
        var prediction: VoxelOrigamiTurnPrediction? = nil
        if case .cube(let index) = pick, index >= 0, index < snapshot.cubes.count {
            target = .cube(index)
            if index >= 1, snapshot.stage == .playing, snapshot.turnable.contains(index) {
                prediction = VoxelOrigamiPicker.prediction(index, size: Self.simd(viewSize), snapshot: snapshot,
                                                           orbit: orbit)
            }
        }
        state = target == .nothing ? .emptyPress : .cubePress
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                      snapshot: snapshot, prediction: prediction, travel: 0, dragging: false, pending: nil)
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing): its travel grows to the farthest
    /// distance from the start, and a press on a cube reaching ``dragDistance`` becomes a drag. Returns the drag's
    /// explanation when this move started a drag that cannot turn (see the file header), `[]` otherwise.
    private mutating func follow(_ touch: inout Touch, to location: Vec2) -> [VoxelOrigamiGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        guard !touch.dragging, touch.travel >= Self.dragDistance, case .cube(let cube) = touch.target else {
            return []
        }
        touch.dragging = true
        if state == .cubePress { state = .cubeDrag }
        if let reason = Self.dragReason(cube, touch.snapshot) { return [.explain(reason)] }
        return []
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed);
    /// `snapshot` is the releasing snapshot.
    private mutating func release(_ touch: Touch, at event: PointerEvent,
                                  snapshot: VoxelOrigamiSceneSnapshot) -> [VoxelOrigamiGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        switch touch.target {
        case .cube(let cube):
            if touch.dragging {
                lastTap = nil
                var actions: [VoxelOrigamiGestureAction] = touch.pending == nil ? [] : [.clearPending]
                if let prediction = touch.prediction, snapshot.stage == .playing,
                   let step = Self.step(prediction, from: touch.start, to: event.location) {
                    actions.append(.turn(hinge: cube, step: step))
                }
                return actions
            }
            guard tap, cube >= 1 else {
                lastTap = nil
                return []
            }
            guard secondTap(of: .cube(cube), at: event) else {
                lastTap = (.cube(cube), event.location, event.timestamp)
                return [.chooseHinge(cube)]
            }
            lastTap = nil
            if snapshot.stage == .playing {
                guard snapshot.turnable.contains(cube) else { return [.explain(Self.idleReason(cube))] }
                return [.turn(hinge: cube, step: 1)]
            }
            if Self.finished(snapshot.stage) { return [.chooseHinge(cube), .explain(Self.finishedReason)] }
            return [.chooseHinge(cube)]
        case .nothing:
            guard tap else {
                lastTap = nil
                return []
            }
            guard secondTap(of: .nothing, at: event) else {
                lastTap = (.nothing, event.location, event.timestamp)
                return []
            }
            lastTap = nil
            resetView()
            return [.resetView]
        }
    }

    /// Whether a tap on `target` lifted by `event` is the second tap of a double tap: the last tap was on the same
    /// target, its `.ended` at most ``doubleTapWindow`` earlier and its lift point at most ``doubleTapDistance`` away.
    private func secondTap(of target: Target, at event: PointerEvent) -> Bool {
        guard let last = lastTap, last.target == target else { return false }
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

    /// Cancels any one-finger gesture for a second finger (sending only `clearPending` when a step was pending) and
    /// starts an orbit from the current midpoint.
    private mutating func secondFinger() -> [VoxelOrigamiGestureAction] {
        var actions: [VoxelOrigamiGestureAction] = []
        if let current = touch, current.pending != nil { actions = [.clearPending] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// Why a drag from cube `cube` on the touch-down snapshot `snapshot` turns nothing, or nil when it may turn (or
    /// says nothing): the root has no hinge (any stage); a won, failed or shown-result play is over; on loading,
    /// tutorial or paused nil (nothing at all is sent); a hinge that is not turnable swings no cube.
    private static func dragReason(_ cube: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> String? {
        if cube == 0 { return rootReason }
        if snapshot.stage != .playing { return finished(snapshot.stage) ? finishedReason : nil }
        if !snapshot.turnable.contains(cube) { return idleReason(cube) }
        return nil
    }

    /// Whether `stage` ends the play for gestures: won, failed or result.
    private static func finished(_ stage: VoxelOrigamiStage) -> Bool {
        stage == .won || stage == .failed || stage == .result
    }

    /// The step `prediction` gives the finger's travel from `start` to `location` at ``turnDistance``, nil for none
    /// (or a location that is not finite).
    private static func step(_ prediction: VoxelOrigamiTurnPrediction, from start: Vec2, to location: Vec2) -> Int? {
        guard location.isFinite, start.isFinite else { return nil }
        let d: Vec2 = location - start
        return prediction.step(for: SIMD2(d.x, d.y), threshold: turnDistance)
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
