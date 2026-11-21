// WaveKnotKeeperGestureController — feature 324 (R02-G03-04) T-R02G0304-003 (FR-R02G0304-003, 005, 007;
// SC-R02G0304-002; clarifications Q2, Q3, Q5). Turns pointer events into Wave Knot Keeper actions, camera orbits and
// the drag preview, host-testable without a screen. A small state machine in the pattern of Lissajous Labyrinth's
// gesture controller (feature 314):
//
// - idle → dragging: one finger goes down on a control handle (`WaveKnotKeeperHandles.pick` through the drawn camera
//   `WaveKnotKeeperSceneGeometry.camera(for:aspect:orbit:)` for the view's aspect and the current orbit). The touch
//   returns `point.select [point]` at once (presentation only; clarification Q2), whatever the stage.
// - dragging: every move recomputes the candidate direction (`WaveKnotKeeperHandles.candidate`) from the drag vector
//   (current location − start location) on the snapshot and camera the drag began with, but only while the current
//   snapshot's stage is `playing`; otherwise there is no candidate.
// - dragging → idle: the finger ends; exactly one `point.move [point, direction index]` (an index into
//   `WaveKnotKeeperDirection.allCases`) is returned iff the candidate at the release location exists and the stage is
//   `playing`; otherwise nothing (a tap selects only).
// - any → orbiting: a second finger goes down (a drag in progress is dropped without a move). The midpoint of the
//   fingers turns the camera: yaw += Δx / view width × 90° (dragging right adds) and pitch −= Δy / view height × 60°
//   (screen y grows downwards, so dragging up raises the pitch and the view looks more from above), clamped by
//   `WaveKnotKeeperOrbit.clamped()` (clarification Q3). A third finger re-bases the midpoint so the camera does not
//   jump.
// - orbiting → cancelled when a finger lifts while others stay down; cancelled → idle when every finger has lifted.
// - a `.cancelled` pointer phase ends any drag or orbit without an action.
//
// One finger on empty space does nothing (it never orbits), but a short tap there (lifted within 22 pt of where it went
// down, with no other finger) counts towards a double tap: two such taps whose `.ended` timestamps are at most 0.3 s
// apart and whose end points are at most 22 pt apart reset the orbit to the authored one. Only event timestamps are
// read, never a clock, so the same events give the same results. Unknown pointer ids, repeated `.began` ids, non-finite
// locations (rejected by R02-F22's `PointerTracker`) and a view size that is not finite and positive send nothing.
import Foundation
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// The state of the Wave Knot Keeper gesture controller (feature 324, clarification Q2).
public enum WaveKnotKeeperGesturePhase: Sendable, Equatable {
    /// No gesture: the next finger may pick a handle.
    case idle
    /// One finger drags control point `point`; `start` is where the finger went down (view points).
    case dragging(point: Int, start: Vec2)
    /// Two or more fingers turn the camera.
    case orbiting
    /// A gesture was cancelled; nothing responds until every finger has lifted.
    case cancelled
}

/// Turns pointer events into Wave Knot Keeper actions (`point.select`, `point.move`), the drag preview and camera
/// orbits (feature 324, FR-R02G0304-003, 005, 007): at most one action per event and at most one `point.move` per
/// gesture, deterministic for the same events. See the file header for the rules.
public struct WaveKnotKeeperGestureController: Sendable {
    /// The control that selects a point: `point.select [point]`.
    public static let selectControl = "point.select"
    /// The control that moves a point: `point.move [point, direction index]`.
    public static let moveControl = "point.move"
    /// The longest time in seconds between the two `.ended` events of a double tap, 0.3.
    public static let doubleTapInterval = 0.3
    /// The largest distance in points a tap may travel, and between the two taps of a double tap, 22.
    public static let doubleTapDistance = 22.0
    /// The yaw turn in degrees for a two-finger movement across the whole view width, 90.
    public static let yawPerViewWidth = 90.0
    /// The pitch turn in degrees for a two-finger movement across the whole view height, 60 (upwards raises it).
    public static let pitchPerViewHeight = 60.0

    /// The current gesture state.
    public private(set) var phase: WaveKnotKeeperGesturePhase = .idle
    /// The camera orbit (presentation only; always clamped); ``WaveKnotKeeperOrbit/authored`` at start.
    public private(set) var orbit: WaveKnotKeeperOrbit = .authored
    /// The direction the drag in progress names now, or nil (no drag, too short, or not playing).
    public private(set) var candidate: WaveKnotKeeperDirection?

    /// The active pointers.
    private var tracker = PointerTracker()
    /// The drag in progress.
    private var drag: Drag?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// A finger on empty space that may become a tap: its id and where it went down.
    private var tapCandidate: (id: Int, location: Vec2)?
    /// The last tap on empty space: where and when it ended.
    private var lastTap: (location: Vec2, timestamp: Double)?

    /// A drag in progress.
    private struct Drag: Sendable {
        let pointer: Int
        let point: Int
        let start: Vec2
        /// The snapshot the drag began on: its rope and camera frame the drag (the rope does not move during it).
        let snapshot: WaveKnotKeeperSceneSnapshot
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The dragged control point, or nil when no drag is in progress.
    public var draggedPoint: Int? { drag?.point }

    /// The move the drag would send if released now: `point.move [point, direction index]` for the current
    /// ``candidate``; nil otherwise.
    public var preview: ScriptedAction? {
        guard let drag, let candidate else { return nil }
        return Self.move(point: drag.point, direction: candidate)
    }

    /// The drawn camera for `snapshot` in a view of `viewSize` points at the current orbit, or nil for a view that is
    /// not finite and positive.
    public func camera(for snapshot: WaveKnotKeeperSceneSnapshot, viewSize: Vec2) -> WaveKnotKeeperCamera? {
        guard Self.usable(viewSize) else { return nil }
        return WaveKnotKeeperSceneGeometry.camera(for: snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot`; returns `point.select [point]`
    /// when a finger goes down on a handle, `point.move [point, direction index]` when a drag with a candidate is
    /// released while `snapshot.stage` is `playing`, or nil. Orbiting and the double tap work in every stage.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: WaveKnotKeeperSceneSnapshot) -> ScriptedAction? {
        guard tracker.handle(event) else { return nil }
        switch event.phase {
        case .began:
            return began(event, viewSize: viewSize, snapshot: snapshot)
        case .moved:
            moved(event, viewSize: viewSize, snapshot: snapshot)
            return nil
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, snapshot: snapshot)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, snapshot: snapshot)
        }
    }

    /// Returns the camera to the authored orbit (the panel's "Reset view").
    public mutating func resetOrbit() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Cancels the gesture in progress without an action: idle when no finger is down, else cancelled until every
    /// finger has lifted.
    public mutating func cancel() {
        drag = nil
        candidate = nil
        orbitMidpoint = nil
        tapCandidate = nil
        phase = tracker.count == 0 ? .idle : .cancelled
    }

    /// The action `point.move [point, direction index]`.
    public static func move(point: Int, direction: WaveKnotKeeperDirection) -> ScriptedAction {
        let index: Int = WaveKnotKeeperDirection.allCases.firstIndex(of: direction) ?? 0
        return ScriptedAction(moveControl, [Double(point), Double(index)])
    }

    /// The action `point.select [point]`.
    public static func select(point: Int) -> ScriptedAction {
        ScriptedAction(selectControl, [Double(point)])
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: WaveKnotKeeperSceneSnapshot) -> ScriptedAction? {
        switch phase {
        case .idle:
            if tracker.count == 1 {
                return pickOrTap(event, viewSize: viewSize, snapshot: snapshot)
            }
            startOrbit()
        case .dragging:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
        return nil
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2, snapshot: WaveKnotKeeperSceneSnapshot) {
        switch phase {
        case .dragging:
            guard let current = drag, current.pointer == event.id else { return }
            candidate = snapshot.stage == .playing
                ? candidate(for: current, at: event.location, viewSize: viewSize) : nil
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned = WaveKnotKeeperOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                             pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
        case .idle:
            if let tap = tapCandidate, tap.id == event.id,
               (event.location - tap.location).length > Self.doubleTapDistance {
                tapCandidate = nil
            }
        case .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                snapshot: WaveKnotKeeperSceneSnapshot) -> ScriptedAction? {
        switch phase {
        case .dragging:
            guard let current = drag, current.pointer == event.id else { return nil }
            drag = nil
            candidate = nil
            phase = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled, snapshot.stage == .playing,
                  let direction = candidate(for: current, at: event.location, viewSize: viewSize) else { return nil }
            return Self.move(point: current.point, direction: direction)
        case .orbiting:
            orbitMidpoint = nil
            phase = tracker.count == 0 ? .idle : .cancelled
        case .cancelled:
            if tracker.count == 0 { phase = .idle }
        case .idle:
            if let tap = tapCandidate, tap.id == event.id {
                tapCandidate = nil
                if !cancelled, (event.location - tap.location).length <= Self.doubleTapDistance {
                    registerTap(at: event.location, timestamp: event.timestamp)
                }
            }
        }
        return nil
    }

    // MARK: Helpers

    /// Picks a handle under a first finger and starts its drag (returning `point.select`), or remembers a possible tap
    /// on empty space.
    private mutating func pickOrTap(_ event: PointerEvent, viewSize: Vec2,
                                    snapshot: WaveKnotKeeperSceneSnapshot) -> ScriptedAction? {
        guard let camera = camera(for: snapshot, viewSize: viewSize),
              let point = WaveKnotKeeperHandles.pick(SIMD2(event.location.x, event.location.y), snapshot: snapshot,
                                                     camera: camera, size: SIMD2(viewSize.x, viewSize.y)) else {
            tapCandidate = (event.id, event.location)
            return nil
        }
        drag = Drag(pointer: event.id, point: point, start: event.location, snapshot: snapshot)
        candidate = nil
        phase = .dragging(point: point, start: event.location)
        return Self.select(point: point)
    }

    /// The candidate direction of `drag` with the finger at `location`, on the drag's own snapshot and the current
    /// camera; nil for none or an unusable view.
    private func candidate(for drag: Drag, at location: Vec2, viewSize: Vec2) -> WaveKnotKeeperDirection? {
        guard let camera = camera(for: drag.snapshot, viewSize: viewSize) else { return nil }
        let delta: Vec2 = location - drag.start
        return WaveKnotKeeperHandles.candidate(point: drag.point, drag: SIMD2(delta.x, delta.y),
                                               snapshot: drag.snapshot, camera: camera,
                                               size: SIMD2(viewSize.x, viewSize.y))
    }

    /// Drops any drag and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        drag = nil
        candidate = nil
        tapCandidate = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        phase = .orbiting
    }

    /// Records a tap on empty space; a second one close in time and place resets the orbit.
    private mutating func registerTap(at location: Vec2, timestamp: Double) {
        if let last = lastTap, timestamp.isFinite, timestamp - last.timestamp >= 0,
           timestamp - last.timestamp <= Self.doubleTapInterval,
           (location - last.location).length <= Self.doubleTapDistance {
            lastTap = nil
            resetOrbit()
        } else {
            lastTap = timestamp.isFinite ? (location, timestamp) : nil
        }
    }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
