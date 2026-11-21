// LissajousLabyrinthGestureController — feature 314 (R02-G02-04) T-R02G0204-004 (FR-R02G0204-002, 003, 004, 007;
// clarifications Q2, Q3, Q5; research R3–R6, R8). Turns pointer events into at most one `LissajousLabyrinthAction` per
// gesture, host-testable without a screen. A small state machine (research R5, as feature 304's R3):
//
// - idle → turning: one finger goes down on a dial ring's knob (R02-F22's `HandlePicker` against the four
//   `LissajousLabyrinthHandles.spatialHandles(level:dials:)`, projected through the drawn camera
//   `LissajousLabyrinthSceneGeometry.viewProjection(aspect:snapshot:orbit:)` for the view's aspect and the current
//   orbit) or, when no knob is in reach, on a ring itself (the touch ray meets the ring's plane within 0.7 … 1.3 ring
//   radii of its centre; the hit nearest the exact radius wins, ties to the lower id; knobs keep priority) while the
//   level is playing; that dial becomes the selection (clarification Q2). The contact point (the knob, or the ring
//   hit) follows the ring's plane (`HandleDrag(.plane(ringNormal))`); every move reads the ring angle of the dragged
//   point (`LissajousLabyrinthHandles.angle(of:dial:level:)`), starting from the contact point's own angle (so a ring
//   touched anywhere and released unmoved sends nothing), and adds the shortest change from the previous reading
//   (`angleDelta(from:to:)`), so the turned angle is unwrapped and a turn past 180° or a full turn counts
//   (research R3). The candidate is `LissajousLabyrinthHandles.value(_:start:turnedAngle:)`: start +
//   round(turn / step), clamped 1 … 9 for the frequencies and modulo 16 for the phases.
// - turning → idle: the turning finger ends; one action (dial, candidate) is returned iff the candidate differs from
//   the start and the level is still playing (research R4).
// - any → orbiting: a second finger goes down (a turn in progress is dropped without an action). The midpoint of the
//   fingers turns the camera: Δx / view width × 90° onto the azimuth offset (dragging right adds) and Δy / view
//   height × 60° onto the elevation (dragging down adds), clamped by `LissajousLabyrinthOrbit.clamped()`
//   (research R6). A third finger re-bases the midpoint so the camera does not jump.
// - orbiting → cancelled when a finger lifts while others stay down; cancelled → idle when every finger has lifted.
// - a `.cancelled` pointer phase ends any turn or orbit without an action.
//
// A finger on empty space (no knob in reach, no ring band under it) does nothing, but a short tap there (lifted within
// 20 pt of where it went down, with no other finger) counts towards a double tap: two such taps whose `.ended`
// timestamps are at most 0.3 s apart and whose end points are at most 20 pt apart reset the orbit to the authored pose.
// Only event timestamps are read, never a clock.
// Unknown pointer ids, repeated `.began` ids, non-finite locations and a view size that is not finite and positive are
// ignored (no action, no crash): the bookkeeping is R02-F22's `PointerTracker`, which rejects them.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The state of the Lissajous Labyrinth gesture controller (feature 314, research R5).
public enum LissajousLabyrinthGesturePhase: Sendable, Equatable {
    /// No gesture: the next finger may pick a dial ring.
    case idle
    /// One finger turns the ring of a dial; `start` is the dial's value when the turn began and `candidate` the value
    /// the turn names now.
    case turning(LissajousLabyrinthDial, start: Int, candidate: Int)
    /// Two or more fingers turn the camera.
    case orbiting
    /// A gesture was cancelled; nothing responds until every finger has lifted.
    case cancelled
}

/// Turns pointer events into Lissajous Labyrinth actions, camera orbits and the dial selection (feature 314,
/// FR-R02G0204-002, 003, 004, 007): at most one ``LissajousLabyrinthAction`` per gesture, deterministic for the same
/// events. See the file header for the rules.
public struct LissajousLabyrinthGestureController: Sendable {
    /// The longest time in seconds between the two `.ended` events of a double tap.
    public static let doubleTapInterval = 0.3
    /// The largest distance in points a tap may travel, and between the two taps of a double tap.
    public static let doubleTapDistance = 20.0
    /// The azimuth turn in radians for a two-finger movement across the whole view width (90°).
    public static let azimuthPerViewWidth = 90.0 * Double.pi / 180
    /// The elevation turn in radians for a two-finger movement across the whole view height (60°).
    public static let elevationPerViewHeight = 60.0 * Double.pi / 180
    /// The band around each ring, as fractions of the ring radius from its centre, where a touch with no knob in reach
    /// grabs the ring (0.7 … 1.3; clarification Q2).
    public static let ringBand: ClosedRange<Double> = 0.7...1.3

    /// The current gesture state.
    public private(set) var phase: LissajousLabyrinthGesturePhase = .idle
    /// The selected dial: the dial of the last picked ring or the last ``select(_:)``; frequencyA at start
    /// (research R8).
    public private(set) var selectedDial: LissajousLabyrinthDial = .frequencyA
    /// The camera orbit (presentation only; always clamped); ``LissajousLabyrinthOrbit/authored`` at start.
    public private(set) var orbit: LissajousLabyrinthOrbit = .authored

    /// The active pointers.
    private var tracker = PointerTracker()
    /// The turn in progress.
    private var turn: Turn?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// A finger on empty space that may become a tap: its id and where it went down.
    private var tapCandidate: (id: Int, location: Vec2)?
    /// The last tap on empty space: where and when it ended.
    private var lastTap: (location: Vec2, timestamp: Double)?
    /// The drawn camera's view-projection and its inverse for the last view size, level and orbit.
    private var cachedCamera: (viewSize: Vec2, level: LissajousLabyrinthLevel, orbit: LissajousLabyrinthOrbit,
                               viewProjection: Mat4, inverse: Mat4?)?

    /// A turn in progress.
    private struct Turn: Sendable {
        let pointer: Int
        let dial: LissajousLabyrinthDial
        /// The snapshot the turn began on: its level's rings are turned (they do not move while the turn lasts).
        let snapshot: LissajousLabyrinthSceneSnapshot
        let start: Int
        var candidate: Int
        var constraint: HandleDrag
        /// The turned angle in radians (clockwise as seen from the eye), unwrapped across updates.
        var turned: Double = 0
        /// The ring angle of the last dragged point.
        var lastAngle: Double
    }

    /// Creates an idle controller: frequencyA selected, the authored orbit.
    public init() {}

    /// The action the turn would send if released now: the candidate while turning and different from the start; nil
    /// otherwise.
    public var preview: LissajousLabyrinthAction? {
        guard let turn, turn.candidate != turn.start else { return nil }
        return LissajousLabyrinthAction(dial: turn.dial, value: turn.candidate)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot`; returns the action a released
    /// turn sends, or nil. Rings respond only while `playing`; orbiting and the double tap work regardless.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: LissajousLabyrinthSceneSnapshot,
                                playing: Bool) -> LissajousLabyrinthAction? {
        guard tracker.handle(event) else { return nil }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot, playing: playing)
            return nil
        case .moved:
            moved(event, viewSize: viewSize, snapshot: snapshot)
            return nil
        case .ended:
            return ended(event, cancelled: false, playing: playing)
        case .cancelled:
            return ended(event, cancelled: true, playing: playing)
        }
    }

    /// Selects `dial`, as a panel stepper does.
    public mutating func select(_ dial: LissajousLabyrinthDial) {
        selectedDial = dial
    }

    /// Returns the camera to the authored pose.
    public mutating func resetOrbit() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Cancels the gesture in progress without an action: idle when no finger is down, else cancelled until every
    /// finger has lifted.
    public mutating func cancel() {
        turn = nil
        orbitMidpoint = nil
        tapCandidate = nil
        phase = tracker.count == 0 ? .idle : .cancelled
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: LissajousLabyrinthSceneSnapshot,
                                playing: Bool) {
        switch phase {
        case .idle:
            if tracker.count == 1 {
                pickOrTap(event, viewSize: viewSize, snapshot: snapshot, playing: playing)
            } else {
                startOrbit()
            }
        case .turning:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2, snapshot: LissajousLabyrinthSceneSnapshot) {
        switch phase {
        case .turning:
            guard var current = turn, current.pointer == event.id,
                  let ray = ray(at: event.location, viewSize: viewSize, snapshot: current.snapshot) else { return }
            let point = current.constraint.update(ray: ray)
            guard !current.constraint.isHeld,
                  let angle = LissajousLabyrinthHandles.angle(of: point, dial: current.dial,
                                                              level: current.snapshot.level)
            else { return }
            current.turned += LissajousLabyrinthHandles.angleDelta(from: current.lastAngle, to: angle)
            current.lastAngle = angle
            current.candidate = LissajousLabyrinthHandles.value(current.dial, start: current.start,
                                                                turnedAngle: current.turned)
            turn = current
            phase = .turning(current.dial, start: current.start, candidate: current.candidate)
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard viewSize.isFinite, viewSize.x > 0, viewSize.y > 0 else { return }
            let delta = midpoint - last
            let turned = LissajousLabyrinthOrbit(
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

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, playing: Bool) -> LissajousLabyrinthAction? {
        switch phase {
        case .turning:
            guard let current = turn, current.pointer == event.id else { return nil }
            turn = nil
            phase = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled, playing, current.candidate != current.start else { return nil }
            return LissajousLabyrinthAction(dial: current.dial, value: current.candidate)
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

    /// Picks a knob (first) or a ring band under a first finger and starts that dial's turn from the contact point,
    /// or remembers a possible tap on empty space.
    private mutating func pickOrTap(_ event: PointerEvent, viewSize: Vec2, snapshot: LissajousLabyrinthSceneSnapshot,
                                    playing: Bool) {
        let level = snapshot.level
        let contact: (dial: LissajousLabyrinthDial, point: Vec3)
        if let dial = pick(at: event.location, viewSize: viewSize, snapshot: snapshot) {
            contact = (dial, LissajousLabyrinthHandles.knob(dial, value: snapshot.dials[dial], level: level))
        } else if let ray = ray(at: event.location, viewSize: viewSize, snapshot: snapshot),
                  let ring = Self.ringHit(ray, level: level) {
            contact = ring
        } else {
            tapCandidate = (event.id, event.location)
            return
        }
        let dial = contact.dial
        guard playing, let ray = ray(at: event.location, viewSize: viewSize, snapshot: snapshot) else { return }
        let start = snapshot.dials[dial]
        guard let constraint = HandleDrag(start: contact.point, ray: ray,
                                          constraint: .plane(LissajousLabyrinthHandles.ringNormal)),
              let angle = LissajousLabyrinthHandles.angle(of: constraint.position, dial: dial, level: level)
        else { return }
        selectedDial = dial
        turn = Turn(pointer: event.id, dial: dial, snapshot: snapshot, start: start, candidate: start,
                    constraint: constraint, lastAngle: angle)
        phase = .turning(dial, start: start, candidate: start)
    }

    /// The ring band `ray` touches when no knob is in reach (clarification Q2): the ray meets each ring's plane (centre
    /// ``LissajousLabyrinthHandles/ringPlane(_:level:)``, normal ``LissajousLabyrinthHandles/ringNormal``) in front of
    /// its origin, and a ring counts when the hit lies within ``ringBand`` × the ring radius of its centre; the hit
    /// nearest to the exact ring radius wins, ties to the lower id. Returns the dial and the hit point; nil for none or
    /// a ray grazing the planes (|cos| below `HandleDrag.planeGrazing`).
    static func ringHit(_ ray: Ray3, level: LissajousLabyrinthLevel) -> (dial: LissajousLabyrinthDial, point: Vec3)? {
        let normal = LissajousLabyrinthHandles.ringNormal
        let facing = normal.dot(ray.direction)
        guard abs(facing) >= HandleDrag.planeGrazing else { return nil }
        let radius = LissajousLabyrinthHandles.ringRadius(level: level)
        guard radius > 0, radius.isFinite else { return nil }
        var best: (dial: LissajousLabyrinthDial, point: Vec3, error: Double)?
        for dial in LissajousLabyrinthDial.allCases {
            let plane = LissajousLabyrinthHandles.ringPlane(dial, level: level)
            let t = normal.dot(plane.centre - ray.origin) / facing
            guard t.isFinite, t > 0 else { continue }
            let hit = ray.origin + ray.direction * t
            let distance = (hit - plane.centre).length
            guard distance >= ringBand.lowerBound * radius, distance <= ringBand.upperBound * radius else { continue }
            let error = abs(distance - radius)
            if let current = best, error >= current.error { continue }
            best = (dial, hit, error)
        }
        guard let best else { return nil }
        return (best.dial, best.point)
    }

    /// Drops any turn and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        turn = nil
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

    /// The dial whose ring knob is under `location`, by R02-F22's picking rule (nearest on screen, then nearest in
    /// depth, then the lower id) through the drawn camera; nil for none or an unusable view.
    private mutating func pick(at location: Vec2, viewSize: Vec2,
                               snapshot: LissajousLabyrinthSceneSnapshot) -> LissajousLabyrinthDial? {
        guard let camera = camera(viewSize: viewSize, snapshot: snapshot),
              let handles = try? LissajousLabyrinthHandles.spatialHandles(level: snapshot.level,
                                                                          dials: snapshot.dials),
              let picked = try? HandlePicker.pick(handles, at: location, viewProjection: camera.viewProjection,
                                                  viewport: viewSize) else { return nil }
        return LissajousLabyrinthHandles.dial(id: handles[picked].id)
    }

    /// The drawn camera's view-projection and inverse for `viewSize`, `snapshot` and the current orbit, or nil for a
    /// view that is not finite and positive. The framing depends on the snapshot's level only (never on the dials or
    /// the time), so it is cached per view size, level and orbit.
    private mutating func camera(viewSize: Vec2, snapshot: LissajousLabyrinthSceneSnapshot)
        -> (viewProjection: Mat4, inverse: Mat4?)? {
        guard viewSize.isFinite, viewSize.x > 0, viewSize.y > 0 else { return nil }
        let level = snapshot.level
        if let cached = cachedCamera, cached.viewSize == viewSize, cached.orbit == orbit, cached.level == level {
            return (cached.viewProjection, cached.inverse)
        }
        let viewProjection = LissajousLabyrinthSceneGeometry.viewProjection(
            aspect: viewSize.x / viewSize.y, snapshot: snapshot, orbit: orbit)
        let inverse = viewProjection.inverse
        cachedCamera = (viewSize, level, orbit, viewProjection, inverse)
        return (viewProjection, inverse)
    }

    /// The world ray through `location`, or nil for an unusable view.
    private mutating func ray(at location: Vec2, viewSize: Vec2, snapshot: LissajousLabyrinthSceneSnapshot) -> Ray3? {
        guard let camera = camera(viewSize: viewSize, snapshot: snapshot),
              let inverse = camera.inverse else { return nil }
        return ScreenProjection.ray(through: location, viewport: viewSize, inverseViewProjection: inverse)
    }
}
