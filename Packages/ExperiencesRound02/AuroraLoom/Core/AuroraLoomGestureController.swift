// AuroraLoomGestureController — feature 304 (R02-G01-04) T-R02G0104-003 (FR-R02G0104-002, 003, 006; SC-R02G0104-001,
// 002; clarifications Q1–Q3, Q5; research R2, R3). Turns pointer events into at most one `AuroraLoomMove` per gesture,
// host-testable without a screen. A small state machine (research R3):
//
// - idle → dragging: one finger goes down on a handle (R02-F22's `HandlePicker` against the handles of the current
//   steps, through the drawn camera `AuroraLoomSceneGeometry.camera(aspect:orbit:)` and the view as viewport) while the
//   level is playing; the handle's ribbon becomes the selection. An anchor follows its rail (`HandleDrag`, axis +y,
//   clamped to the rail) and the candidate is `AuroraLoomHandles.waveStep(atHeight:)` of the drag height; a dial
//   follows its ring plane (`HandleDrag`, plane normal +x through the knob) and the candidate is
//   `AuroraLoomHandles.phaseStep(start:turnedAngle:)` of the accumulated (unwrapped) turn about the dial centre, so
//   turns past a full revolution wrap modulo 16.
// - dragging → idle: the dragging finger ends; one move is returned iff the candidate differs from the start step and
//   the level is still playing.
// - any → orbiting: a second finger goes down (a drag in progress is dropped without a move). The midpoint of the
//   fingers turns the camera: Δx / view width × 90° onto the azimuth offset (dragging right adds) and Δy / view height ×
//   60° onto the elevation (dragging down adds, raising the eye so the loom tilts towards the viewer), each clamped
//   to `AuroraLoomOrbit`'s ranges. A third finger re-bases the midpoint so the camera does not jump.
// - orbiting → cancelled when a finger lifts while others stay down; cancelled → idle when every finger has lifted.
// - a `.cancelled` pointer phase ends any drag or orbit without a move.
//
// A finger on empty space does nothing, but a short tap there (lifted within 20 pt of where it went down, with no other
// finger) counts towards a double tap: two such taps whose `.ended` timestamps are at most 0.3 s apart and whose end
// points are at most 20 pt apart reset the orbit to the authored pose. Unknown pointer ids, repeated `.began` ids,
// non-finite locations and a view size that is not finite and positive are ignored (no move, no crash): the
// bookkeeping is R02-F22's `PointerTracker`, which rejects them.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The state of the Aurora Loom gesture controller (feature 304, research R3).
public enum AuroraLoomGesturePhase: Sendable, Equatable {
    /// No gesture: the next finger may pick a handle.
    case idle
    /// One finger drags `handle`; `start` is the step when the drag began and `candidate` the step under the finger.
    case dragging(AuroraLoomHandleID, start: Int, candidate: Int)
    /// Two or more fingers turn the camera.
    case orbiting
    /// A gesture was cancelled; nothing responds until every finger has lifted.
    case cancelled
}

/// Turns pointer events into Aurora Loom moves, camera orbits and the ribbon selection (feature 304, FR-R02G0104-002,
/// 003, 006): at most one ``AuroraLoomMove`` per gesture, deterministic for the same events. See the file header for
/// the rules.
public struct AuroraLoomGestureController: Sendable {
    /// The longest time in seconds between the two `.ended` events of a double tap.
    public static let doubleTapInterval = 0.3
    /// The largest distance in points a tap may travel, and between the two taps of a double tap.
    public static let doubleTapDistance = 20.0
    /// The azimuth turn in radians for a two-finger movement across the whole view width (90°).
    public static let azimuthPerViewWidth = 90.0 * Double.pi / 180
    /// The elevation turn in radians for a two-finger movement across the whole view height (60°).
    public static let elevationPerViewHeight = 60.0 * Double.pi / 180

    /// The current gesture state.
    public private(set) var phase: AuroraLoomGesturePhase = .idle
    /// The selected ribbon (0 … 2): the ribbon of the last picked handle or the last ``select(ribbon:)``; 0 at start.
    public private(set) var selectedRibbon: Int = 0
    /// The camera orbit (presentation only; always clamped); ``AuroraLoomOrbit/authored`` at start.
    public private(set) var orbit: AuroraLoomOrbit = .authored

    /// The active pointers.
    private var tracker = PointerTracker()
    /// The drag in progress, with its pointer id and the accumulated dial turn.
    private var drag: Drag?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// A finger on empty space that may become a tap: its id and where it went down.
    private var tapCandidate: (id: Int, location: Vec2)?
    /// The last tap on empty space: where and when it ended.
    private var lastTap: (location: Vec2, timestamp: Double)?
    /// The drawn camera's view-projection and its inverse for the last view size and orbit (the camera fit is a
    /// bisection, so it is computed once per view size and orbit, not per event).
    private var cachedCamera: (viewSize: Vec2, orbit: AuroraLoomOrbit, viewProjection: Mat4, inverse: Mat4?)?

    /// A drag in progress.
    private struct Drag: Sendable {
        let pointer: Int
        let handle: AuroraLoomHandleID
        let start: Int
        var candidate: Int
        var constraint: HandleDrag
        /// The dial turn in radians, unwrapped across updates (0 for anchors).
        var turned: Double = 0
        /// The last wrapped angle reported by `HandleDrag.angle(around:)`.
        var lastAngle: Double = 0
    }

    /// Creates an idle controller: ribbon 0 selected, the authored orbit.
    public init() {}

    /// The move the drag would make if released now, while dragging; nil otherwise.
    public var preview: AuroraLoomMove? {
        guard let drag else { return nil }
        return AuroraLoomMove(ribbon: drag.handle.ribbon, control: drag.handle.control, step: drag.candidate)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `steps`; returns the move a released drag
    /// makes, or nil. Handles respond only while `playing`; orbiting and the double tap work regardless.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, steps: AuroraLoomSteps,
                                playing: Bool) -> AuroraLoomMove? {
        guard tracker.handle(event) else { return nil }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, steps: steps, playing: playing)
            return nil
        case .moved:
            moved(event, viewSize: viewSize)
            return nil
        case .ended:
            return ended(event, cancelled: false, playing: playing)
        case .cancelled:
            return ended(event, cancelled: true, playing: playing)
        }
    }

    /// Selects `ribbon` (0 … 2; other values are ignored), as a stepper does.
    public mutating func select(ribbon: Int) {
        guard (0..<AuroraLoomSceneGeometry.ribbonCount).contains(ribbon) else { return }
        selectedRibbon = ribbon
    }

    /// Returns the camera to the authored pose.
    public mutating func resetOrbit() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Cancels the gesture in progress without a move: idle when no finger is down, else cancelled until every finger
    /// has lifted.
    public mutating func cancel() {
        drag = nil
        orbitMidpoint = nil
        tapCandidate = nil
        phase = tracker.count == 0 ? .idle : .cancelled
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, steps: AuroraLoomSteps, playing: Bool) {
        switch phase {
        case .idle:
            if tracker.count == 1 {
                pickOrTap(event, viewSize: viewSize, steps: steps, playing: playing)
            } else {
                startOrbit()
            }
        case .dragging:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) {
        switch phase {
        case .dragging:
            guard var current = drag, current.pointer == event.id,
                  let ray = ray(at: event.location, viewSize: viewSize) else { return }
            current.constraint.update(ray: ray)
            switch current.handle.control {
            case .wave:
                current.candidate = AuroraLoomHandles.waveStep(atHeight: current.constraint.position.y)
            case .phase:
                let angle = current.constraint.angle(around: AuroraLoomHandles.dialCentre(ribbon: current.handle.ribbon))
                current.turned += Self.wrapped(angle - current.lastAngle)
                current.lastAngle = angle
                current.candidate = AuroraLoomHandles.phaseStep(start: current.start, turnedAngle: current.turned)
            }
            drag = current
            phase = .dragging(current.handle, start: current.start, candidate: current.candidate)
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard viewSize.isFinite, viewSize.x > 0, viewSize.y > 0 else { return }
            let delta = midpoint - last
            let turned = AuroraLoomOrbit(
                azimuthOffset: orbit.azimuthOffset + delta.x / viewSize.x * Self.azimuthPerViewWidth,
                elevation: orbit.elevation + delta.y / viewSize.y * Self.elevationPerViewHeight)
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

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, playing: Bool) -> AuroraLoomMove? {
        switch phase {
        case .dragging:
            guard let current = drag, current.pointer == event.id else { return nil }
            drag = nil
            phase = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled, playing, current.candidate != current.start else { return nil }
            return AuroraLoomMove(ribbon: current.handle.ribbon, control: current.handle.control,
                                  step: current.candidate)
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

    /// Picks a handle under a first finger and starts its drag, or remembers a possible tap on empty space.
    private mutating func pickOrTap(_ event: PointerEvent, viewSize: Vec2, steps: AuroraLoomSteps, playing: Bool) {
        guard let picked = pick(at: event.location, viewSize: viewSize, steps: steps) else {
            tapCandidate = (event.id, event.location)
            return
        }
        guard playing, let start = step(of: picked, in: steps),
              let ray = ray(at: event.location, viewSize: viewSize) else { return }
        let constraint: HandleDrag?
        switch picked.control {
        case .wave:
            let bounds = AuroraLoomHandles.railBounds(ribbon: picked.ribbon)
            constraint = HandleDrag(start: AuroraLoomHandles.anchorPosition(ribbon: picked.ribbon, wave: start),
                                    ray: ray, constraint: .axis(AuroraLoomHandles.railAxis), bounds: bounds)
        case .phase:
            constraint = HandleDrag(start: AuroraLoomHandles.dialKnob(ribbon: picked.ribbon, phase: start),
                                    ray: ray, constraint: .plane(AuroraLoomHandles.dialNormal))
        }
        guard let constraint else { return }
        selectedRibbon = picked.ribbon
        drag = Drag(pointer: event.id, handle: picked, start: start, candidate: start, constraint: constraint)
        phase = .dragging(picked, start: start, candidate: start)
    }

    /// Drops any drag and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        drag = nil
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

    /// The handle under `location`, by R02-F22's picking rule through the drawn camera; nil for none or an unusable
    /// view.
    private mutating func pick(at location: Vec2, viewSize: Vec2, steps: AuroraLoomSteps) -> AuroraLoomHandleID? {
        guard let camera = camera(viewSize: viewSize),
              let handles = try? AuroraLoomHandles.spatialHandles(steps: steps),
              let picked = try? HandlePicker.pick(handles, at: location, viewProjection: camera.viewProjection,
                                                  viewport: viewSize) else { return nil }
        return AuroraLoomHandleID(raw: handles[picked].id)
    }

    /// The current step of `handle`'s control in `steps`, or nil when `steps` has no such ribbon.
    private func step(of handle: AuroraLoomHandleID, in steps: AuroraLoomSteps) -> Int? {
        let values = handle.control == .wave ? steps.wave : steps.phase
        guard values.indices.contains(handle.ribbon) else { return nil }
        return values[handle.ribbon]
    }

    /// The drawn camera's view-projection and inverse for `viewSize` at the current orbit, or nil for a view that is
    /// not finite and positive.
    private mutating func camera(viewSize: Vec2) -> (viewProjection: Mat4, inverse: Mat4?)? {
        guard viewSize.isFinite, viewSize.x > 0, viewSize.y > 0 else { return nil }
        if let cached = cachedCamera, cached.viewSize == viewSize, cached.orbit == orbit {
            return (cached.viewProjection, cached.inverse)
        }
        let camera = AuroraLoomSceneGeometry.camera(aspect: viewSize.x / viewSize.y, orbit: orbit)
        let viewProjection = camera.projection * camera.view
        let inverse = viewProjection.inverse
        cachedCamera = (viewSize, orbit, viewProjection, inverse)
        return (viewProjection, inverse)
    }

    /// The world ray through `location`, or nil outside the view or for an unusable view.
    private mutating func ray(at location: Vec2, viewSize: Vec2) -> Ray3? {
        guard let camera = camera(viewSize: viewSize), let inverse = camera.inverse else { return nil }
        return ScreenProjection.ray(through: location, viewport: viewSize, inverseViewProjection: inverse)
    }

    /// `angle` wrapped into −π … π.
    private static func wrapped(_ angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        var a = angle.truncatingRemainder(dividingBy: 2 * Double.pi)
        if a > Double.pi { a -= 2 * Double.pi }
        if a < -Double.pi { a += 2 * Double.pi }
        return a
    }
}
