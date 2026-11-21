// HueCompassGestureController — feature 334 (R02-G04-04) T-R02G0404-003 (FR-R02G0404-001 … 004; SC-R02G0404-001,
// 002; clarifications Q1–Q3, Q5). Turns pointer events into Hue Compass actions (turn, probe, reset view), the swipe
// preview and camera orbits, host-testable without a screen. A small state machine in the pattern of Wave Knot Keeper's
// gesture controller (feature 324):
//
// - idle → swiping: one finger goes down. The drawn camera is `HueCompassSceneGeometry.camera(aspect:orbit:)` for the
//   view's aspect (width / height) and the current orbit; the compass centre is projected through it
//   (`HueCompassDial.centre`). The start bearing is the snapshot's bearing.
// - swiping: every move (and the release point) adds `HueCompassDial.accumulate(previous:current:)` between the last
//   valid angle and the new one (`HueCompassDial.angle(of:centre:)`). A point inside the 20-point dead zone has no angle
//   and adds nothing; the last valid angle is kept, so the angle gathered before stands. While the snapshot's stage is
//   `playing`, ``HueCompassGestureController/previewBearing`` is the start bearing plus
//   `HueCompassDial.steps(forAngle:)` of the accumulated angle, modulo 96; otherwise it is nil.
// - swiping → idle on release. A touch that never went 10 points (`HueCompassDial.tapDistance`) or farther from where
//   it began is a tap: within the hub (`HueCompassDial.hubRadius`, distance ≤ radius) it returns `[.probe]` while
//   playing; outside the projected wheel (the world point under the finger on the compass plane lies farther than 1.0
//   from the centre, or the finger is not over the plane at all) it counts towards a double tap: two such taps whose
//   `.ended` timestamps are at most 0.35 s apart return `[.resetView]` and reset the orbit, in every stage; any other
//   tap returns `[]`. Otherwise the swipe returns `[.turn(steps)]` with steps =
//   `HueCompassDial.wrapped(HueCompassDial.steps(forAngle: accumulated))`, only while playing and only when steps ≠ 0.
// - any → orbiting: a second finger goes down (a swipe in progress is dropped: nothing is sent). The midpoint of the
//   fingers turns the camera: yaw += Δx / view width × 90° (dragging right turns the eye counter-clockwise about +z,
//   seen from above) and tilt += Δy / view height × 60° (screen y grows downwards, so dragging up lowers the tilt and
//   the view looks more from above, towards a top view), clamped after every step by `HueCompassOrbit.clamped()`
//   (yaw ±40°, tilt 15° … 60°). A third finger re-bases the midpoint so the camera does not jump.
// - orbiting → cancelled when a finger lifts while others stay down; cancelled → idle when every finger has lifted.
// - a `.cancelled` pointer phase ends any swipe or orbit and sends nothing.
//
// Only event timestamps are read, never a clock, so the same events give the same results. Unknown pointer ids,
// repeated `.began` ids and non-finite locations (rejected by `PointerTracker`) send nothing; a view size that is not
// finite and positive has no camera, so a swipe on it sends nothing and has no preview. Presentation only: the orbit is
// never in the digest, the snapshot or the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Hue Compass gesture asks for (feature 334): at most one per gesture.
public enum HueCompassGestureAction: Sendable, Equatable {
    /// Turn the compass by this many bearings, −47 … 48 and never 0: `compass.turn [steps]`.
    case turn(Int)
    /// Probe at the current bearing: `compass.probe`.
    case probe
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Hue Compass gesture actions, the swipe preview and camera orbits (feature 334,
/// FR-R02G0404-001 … 004): at most one action per gesture, deterministic for the same events. See the file header for
/// the rules.
public struct HueCompassGestureController: Sendable {
    /// The state of the gesture controller (clarification Q2).
    public enum State: Sendable, Equatable {
        /// No gesture: the next finger starts a swipe (or a tap).
        case idle
        /// One finger swipes about the compass centre, or presses for a tap.
        case swiping
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The longest time in seconds between the two `.ended` events of a double tap, 0.35.
    public static let doubleTapInterval: Double = 0.35
    /// The radius of the projected wheel in world units, 1.0: a tap farther out is on empty space.
    public static let wheelRadius: Double = 1.0
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The tilt change in radians for a two-finger movement across the whole view height, 60° (upwards lowers it).
    public static let tiltPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``HueCompassOrbit/authored`` at start.
    public private(set) var orbit: HueCompassOrbit = .authored
    /// The bearing the swipe in progress would turn the compass to, 0 … 95: the start bearing plus the whole bearings of
    /// the accumulated angle, modulo 96. Nil when no swipe is in progress or the latest snapshot is not playing.
    public private(set) var previewBearing: Int?

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The swipe in progress.
    private var swipe: Swipe?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The `.ended` timestamp of the last tap on empty space, if it may start a double tap.
    private var lastTapTime: Double?

    /// A swipe (or press) in progress.
    private struct Swipe: Sendable {
        /// The finger's pointer id.
        let pointer: Int
        /// Where the finger went down, in view points.
        let start: Vec2
        /// The snapshot's bearing when the finger went down.
        let startBearing: Int
        /// The drawn camera when the finger went down; nil for an unusable view.
        let camera: HueCompassCamera?
        /// The projected compass centre in view points; nil for an unusable view.
        let centre: SIMD2<Double>?
        /// The view size the swipe began in.
        let size: SIMD2<Double>
        /// The last angle outside the dead zone, radians; nil while none has been seen.
        var lastAngle: Double?
        /// The angle gathered so far, radians.
        var accumulated: Double
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The angle the swipe in progress has gathered so far, in radians (counter-clockwise positive); nil when no swipe
    /// is in progress.
    public var accumulatedAngle: Double? { swipe?.accumulated }

    /// The drawn camera for a view of `viewSize` points at the current orbit, or nil for a view that is not finite and
    /// positive.
    public func camera(viewSize: Vec2) -> HueCompassCamera? {
        guard Self.usable(viewSize) else { return nil }
        return HueCompassSceneGeometry.camera(aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot`. Returns `[.turn(steps)]` when a
    /// swipe with a non-zero wrapped turn is released while `snapshot.stage` is `playing`, `[.probe]` for a tap within
    /// the hub while playing, `[.resetView]` for a double tap on empty space (any stage), and `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: HueCompassSceneSnapshot) -> [HueCompassGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot)
            return []
        case .moved:
            moved(event, viewSize: viewSize, snapshot: snapshot)
            return []
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

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: HueCompassSceneSnapshot) {
        switch state {
        case .idle:
            if tracker.count == 1 {
                startSwipe(event, viewSize: viewSize, snapshot: snapshot)
            } else {
                startOrbit()
            }
        case .swiping:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2, snapshot: HueCompassSceneSnapshot) {
        switch state {
        case .swiping:
            guard var current = swipe, current.pointer == event.id else { return }
            Self.follow(&current, to: event.location)
            swipe = current
            previewBearing = Self.preview(current, snapshot: snapshot)
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned: HueCompassOrbit = HueCompassOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                                          tilt: orbit.tilt + delta.y / viewSize.y * Self.tiltPerViewHeight)
            orbit = turned.clamped()
        case .idle, .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool,
                                snapshot: HueCompassSceneSnapshot) -> [HueCompassGestureAction] {
        switch state {
        case .swiping:
            guard var current = swipe, current.pointer == event.id else { return [] }
            swipe = nil
            previewBearing = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else { return [] }
            Self.follow(&current, to: event.location)
            if current.travel < HueCompassDial.tapDistance {
                return tap(current, at: event.location, timestamp: event.timestamp, snapshot: snapshot)
            }
            lastTapTime = nil
            guard snapshot.stage == .playing, current.centre != nil else { return [] }
            let steps: Int = HueCompassDial.wrapped(HueCompassDial.steps(forAngle: current.accumulated))
            return steps == 0 ? [] : [.turn(steps)]
        case .orbiting:
            orbitMidpoint = nil
            state = tracker.count == 0 ? .idle : .cancelled
        case .cancelled:
            if tracker.count == 0 { state = .idle }
        case .idle:
            break
        }
        return []
    }

    // MARK: Helpers

    /// Starts a swipe for the first finger.
    private mutating func startSwipe(_ event: PointerEvent, viewSize: Vec2, snapshot: HueCompassSceneSnapshot) {
        let camera: HueCompassCamera? = camera(viewSize: viewSize)
        let size: SIMD2<Double> = SIMD2(viewSize.x, viewSize.y)
        var centre: SIMD2<Double>?
        if let camera { centre = HueCompassDial.centre(camera: camera, size: size) }
        var lastAngle: Double?
        if let centre {
            lastAngle = HueCompassDial.angle(of: SIMD2(event.location.x, event.location.y), centre: centre)
        }
        let started: Swipe = Swipe(pointer: event.id, start: event.location, startBearing: snapshot.bearing,
                                   camera: camera, centre: centre, size: size, lastAngle: lastAngle, accumulated: 0,
                                   travel: 0)
        swipe = started
        state = .swiping
        previewBearing = Self.preview(started, snapshot: snapshot)
    }

    /// Drops any swipe and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        swipe = nil
        previewBearing = nil
        lastTapTime = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
    }

    /// The action of a tap that ended at `location` at `timestamp`.
    private mutating func tap(_ swipe: Swipe, at location: Vec2, timestamp: Double,
                              snapshot: HueCompassSceneSnapshot) -> [HueCompassGestureAction] {
        guard let camera = swipe.camera, let centre = swipe.centre else {
            lastTapTime = nil
            return []
        }
        let point: SIMD2<Double> = SIMD2(location.x, location.y)
        let offset: SIMD2<Double> = point - centre
        let distance: Double = (offset.x * offset.x + offset.y * offset.y).squareRoot()
        if distance <= HueCompassDial.hubRadius(camera: camera, size: swipe.size) {
            lastTapTime = nil
            return snapshot.stage == .playing ? [.probe] : []
        }
        guard Self.outsideWheel(location, camera: camera, size: swipe.size) else {
            lastTapTime = nil
            return []
        }
        if let last = lastTapTime, timestamp.isFinite, timestamp - last >= 0,
           timestamp - last <= Self.doubleTapInterval {
            lastTapTime = nil
            resetView()
            return [.resetView]
        }
        lastTapTime = timestamp.isFinite ? timestamp : nil
        return []
    }

    /// Moves `swipe`'s finger to `location`: its travel grows and the angle change since the last valid angle is added
    /// (a point inside the dead zone adds nothing and keeps the last valid angle).
    private static func follow(_ swipe: inout Swipe, to location: Vec2) {
        swipe.travel = max(swipe.travel, (location - swipe.start).length)
        guard let centre = swipe.centre,
              let angle = HueCompassDial.angle(of: SIMD2(location.x, location.y), centre: centre) else { return }
        if let last = swipe.lastAngle {
            swipe.accumulated += HueCompassDial.accumulate(previous: last, current: angle)
        }
        swipe.lastAngle = angle
    }

    /// The preview bearing of `swipe` for `snapshot`: nil unless playing and the view is usable.
    private static func preview(_ swipe: Swipe, snapshot: HueCompassSceneSnapshot) -> Int? {
        guard snapshot.stage == .playing, swipe.centre != nil else { return nil }
        let bearings: Int = HueCompassWheel.bearings
        let raw: Int = (swipe.startBearing + HueCompassDial.steps(forAngle: swipe.accumulated)) % bearings
        return raw < 0 ? raw + bearings : raw
    }

    /// Whether the view point `location` lies outside the projected wheel: the ray through it meets the compass plane
    /// (z = 0) farther than ``wheelRadius`` from the centre, or does not meet it in front of the camera.
    static func outsideWheel(_ location: Vec2, camera: HueCompassCamera, size: SIMD2<Double>) -> Bool {
        guard let inverse = camera.viewProjection.inverse,
              let ray = ScreenProjection.ray(through: location, viewport: Vec2(size.x, size.y),
                                             inverseViewProjection: inverse),
              ray.direction.z != 0 else { return true }
        let t: Double = (0 - ray.origin.z) / ray.direction.z
        guard t.isFinite, t >= 0 else { return true }
        let x: Double = ray.origin.x + ray.direction.x * t
        let y: Double = ray.origin.y + ray.direction.y * t
        return (x * x + y * y).squareRoot() > wheelRadius
    }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
