// ChronoConstellatorGestureController — feature 354 (R02-G06-04) T-R02G0604-003 (FR-R02G0604-001, 002, 003, 005, 006;
// SC-R02G0604-001, 003, 004; clarifications Q1 … Q5). Turns pointer events into Chrono Constellator actions (start
// phase, scrub steps and rewind, hold and release, star selection, reset view), the drag preview (candidate cell, scrub
// tick, dragged star) and camera orbits, host-testable without a screen. A small state machine in the pattern of
// Colorfall Canyons's gesture controller (feature 344):
//
// - One finger goes down: the point is picked once with `ChronoConstellatorPicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size.
//   - `.star(s)`: a star gesture (state `starDrag`, in every stage); s is ``ChronoConstellatorGestureController/
//     draggedStar`` until the gesture ends.
//   - `.timeline`, or a point within 22 points of the projected current-tick bar line (the line across the grid's
//     width at z = halfDepth − tickBarInset·u, y = trackLift·u), while the stage is `playing` or `failed`: a scrub
//     (state `scrub`), ``ChronoConstellatorGestureController/scrubTick`` = `ChronoConstellatorPicker.tick(at:…)`.
//   - Anything else: a press tracked for a tap (state stays `idle`).
// - Moves grow the travel (the farthest distance from the touch-down point). A star drag's candidate is the star's loop
//   cell at `ChronoConstellatorPicker.loopIndex(star:at:…)`, only while the stage is `playing`, the tick is 0 and the
//   travel is at least 10 points; a scrub's tick follows the finger.
// - Release of a star gesture: travel ≥ 16 points, playing at tick 0 and a loop index that differs from the star's
//   phase → `[.phase(s, index)]`; travel < 10 points held ≥ 0.5 s (event timestamps) while playing at tick 0 →
//   `[.hold(s, 1, 10)]` when the star has no hold starting at tick 1, else `[.release(s, 1)]`; any other travel
//   < 10 points → `[.select(s)]` (every stage); 10 … 16 points → `[]`.
// - Release of a scrub at t′ (the release point's tick, else the last scrub tick) from tick t: won → `[]`; t′ > t →
//   `[.step(t′ − t)]`; t′ < t → `[.rewind]` then `[.step(t′)]` when t′ > 0; t′ = t → `[]`.
// - Release of a press under 10 points: two such taps on empty space or a cell (not a star, not the timeline) whose
//   `.ended` timestamps are at most 0.35 s apart → `[.resetView]` and the authored orbit, in every stage.
// - A second finger cancels any star gesture, scrub or press (nothing sent, preview cleared) and orbits: yaw += Δx /
//   width × 90°, pitch −= Δy / height × 60°, clamped; a third finger re-bases the midpoint. A finger lifting while
//   others stay → `cancelled` until every finger has lifted. A `.cancelled` phase sends nothing.
//
// At most two actions per gesture. Only event timestamps are read, never a clock. Presentation only: the orbit never
// enters the digest, the snapshot or the kernel, which still applies its own rules (edits at tick 0, budget, a won play
// is final) to whatever is sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Chrono Constellator gesture asks for (feature 354): at most two per gesture.
public enum ChronoConstellatorGestureAction: Sendable, Equatable {
    /// Set star (first) to start at loop index (second): `star.phase [star, index]`.
    case phase(Int, Int)
    /// Replay this many ticks: `time.step [ticks]`.
    case step(Int)
    /// Return to tick 0 keeping the timeline: `time.rewind`.
    case rewind
    /// Hold star (first) from tick (second) for (third) ticks: `star.hold [star, start, length]`.
    case hold(Int, Int, Int)
    /// Remove the hold of star (first) starting at tick (second): `star.release [star, start]`.
    case release(Int, Int)
    /// Select this star in the panel's star picker (presentation only, nothing sent to the kernel).
    case select(Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Chrono Constellator gesture actions, the drag preview and camera orbits (feature 354):
/// at most two actions per gesture, deterministic for the same events. See the file header for the rules.
public struct ChronoConstellatorGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No star gesture, scrub or orbit: the next finger starts one, or a press tracked for a tap.
        case idle
        /// One finger went down on a star: a phase drag, a long press or a tap.
        case starDrag
        /// One finger scrubs the timeline.
        case scrub
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap or press, exclusive: 10.
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a phase drag, 16.
    public static let dragDistance: Double = 16
    /// The shortest press in seconds (event timestamps) that toggles a hold, 0.5.
    public static let pressDuration: Double = 0.5
    /// The longest time in seconds between the two `.ended` events of a double tap, 0.35.
    public static let doubleTapWindow: Double = 0.35
    /// The first held tick of the gesture's standard hold, 1.
    public static let holdStart: Int = 1
    /// The length in ticks of the gesture's standard hold, 10.
    public static let holdLength: Int = 10
    /// The distance in view points within which a touch near the projected current-tick bar line starts a scrub, 22.
    public static let barReach: Double = 22
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``ChronoConstellatorOrbit/authored`` at start.
    public private(set) var orbit: ChronoConstellatorOrbit = .authored
    /// The loop cell a star drag in progress would start its star on (outlined by the scene), or nil.
    public private(set) var candidateCell: Int?
    /// The tick a scrub in progress points at, or nil when no scrub is in progress.
    public private(set) var scrubTick: Int?
    /// The star of a star gesture in progress (set at touch-down on a star, cleared when the gesture ends or is
    /// cancelled), for the presenter's description; nil otherwise.
    public private(set) var draggedStar: Int?

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The `.ended` timestamp of the last tap on empty space, if it may start a double tap.
    private var lastTapTime: Double?

    /// What a one-finger gesture is.
    private enum Kind: Sendable, Equatable {
        /// A gesture on this star.
        case star(Int)
        /// A timeline scrub.
        case scrub
        /// A press on empty space or a cell (a possible double tap).
        case space
        /// A press on anything else (no tap action).
        case other
    }

    /// A one-finger gesture in progress.
    private struct Touch: Sendable {
        /// The finger's pointer id.
        let pointer: Int
        /// Where the finger went down, in view points.
        let start: Vec2
        /// The touch-down timestamp.
        let time: Double
        /// What the gesture is.
        let kind: Kind
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot) -> ChronoConstellatorCamera? {
        guard Self.usable(viewSize) else { return nil }
        return ChronoConstellatorSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one). Returns the
    /// actions of a gesture that ended with this event (at most two, see the file header), and `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: ChronoConstellatorSceneSnapshot) -> [ChronoConstellatorGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot)
            return []
        case .moved:
            moved(event, viewSize: viewSize, snapshot: snapshot)
            return []
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

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel); the orbit is kept,
    /// and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        orbitMidpoint = nil
        lastTapTime = nil
        clearPreview()
        state = .idle
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot)
            } else {
                startOrbit()
            }
        case .starDrag, .scrub:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot) {
        switch state {
        case .idle, .starDrag, .scrub:
            guard var current = touch, current.pointer == event.id else { return }
            Self.follow(&current, to: event.location)
            touch = current
            preview(current, at: event.location, viewSize: viewSize, snapshot: snapshot)
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned: ChronoConstellatorOrbit =
                ChronoConstellatorOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                        pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
        case .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                snapshot: ChronoConstellatorSceneSnapshot) -> [ChronoConstellatorGestureAction] {
        switch state {
        case .idle, .starDrag, .scrub:
            guard var current = touch, current.pointer == event.id else { return [] }
            let lastScrub: Int? = scrubTick
            touch = nil
            clearPreview()
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTapTime = nil
                return []
            }
            Self.follow(&current, to: event.location)
            switch current.kind {
            case .star(let star):
                lastTapTime = nil
                return starRelease(current, star: star, at: event, viewSize: viewSize, snapshot: snapshot)
            case .scrub:
                lastTapTime = nil
                var target: Int? = lastScrub
                if let tick = tick(at: event.location, viewSize: viewSize, snapshot: snapshot) { target = tick }
                return Self.scrubActions(to: target, snapshot: snapshot)
            case .space:
                return spaceTap(current, timestamp: event.timestamp)
            case .other:
                lastTapTime = nil
                return []
            }
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
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot) {
        var pick: ChronoConstellatorPick = .empty
        if Self.usable(viewSize) {
            pick = ChronoConstellatorPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                                 snapshot: snapshot, orbit: orbit)
        }
        let scrubbable: Bool = snapshot.stage == .playing || snapshot.stage == .failed
        var kind: Kind = .other
        if case .star(let star) = pick {
            kind = .star(star)
        } else if scrubbable, Self.isTimeline(pick) || nearBar(event.location, viewSize: viewSize,
                                                                snapshot: snapshot) {
            kind = .scrub
        } else if pick == .empty || Self.isCell(pick) {
            kind = .space
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, kind: kind, travel: 0)
        clearPreview()
        switch kind {
        case .star(let star):
            draggedStar = star
            state = .starDrag
        case .scrub:
            scrubTick = tick(at: event.location, viewSize: viewSize, snapshot: snapshot)
            state = .scrub
        case .space, .other:
            state = .idle
        }
    }

    /// Updates the candidate cell or scrub tick for `touch` with its finger at `location`.
    private mutating func preview(_ touch: Touch, at location: Vec2, viewSize: Vec2,
                                  snapshot: ChronoConstellatorSceneSnapshot) {
        switch touch.kind {
        case .star(let star):
            candidateCell = nil
            guard touch.travel >= Self.tapDistance, Self.editable(snapshot),
                  let index = loopIndex(star, at: location, viewSize: viewSize, snapshot: snapshot) else { return }
            candidateCell = snapshot.stars[star].loop[index]
        case .scrub:
            if let tick = tick(at: location, viewSize: viewSize, snapshot: snapshot) { scrubTick = tick }
        case .space, .other:
            break
        }
    }

    /// The actions of a star gesture released by `event`.
    private func starRelease(_ touch: Touch, star: Int, at event: PointerEvent, viewSize: Vec2,
                             snapshot: ChronoConstellatorSceneSnapshot) -> [ChronoConstellatorGestureAction] {
        if touch.travel >= Self.dragDistance {
            guard Self.editable(snapshot), snapshot.phases.indices.contains(star),
                  let index = loopIndex(star, at: event.location, viewSize: viewSize, snapshot: snapshot),
                  index != snapshot.phases[star] else { return [] }
            return [.phase(star, index)]
        }
        guard touch.travel < Self.tapDistance else { return [] }
        let held: Double = event.timestamp - touch.time
        if held.isFinite, held >= Self.pressDuration, Self.editable(snapshot) {
            var holds: Bool = false
            for hold in snapshot.holds where hold.star == star && hold.start == Self.holdStart { holds = true }
            return holds ? [.release(star, Self.holdStart)] : [.hold(star, Self.holdStart, Self.holdLength)]
        }
        return [.select(star)]
    }

    /// The actions of a scrub released at `target` (nil: no tick) from the snapshot's tick.
    private static func scrubActions(to target: Int?,
                                     snapshot: ChronoConstellatorSceneSnapshot) -> [ChronoConstellatorGestureAction] {
        guard let target, snapshot.stage != .won else { return [] }
        if target > snapshot.tick { return [.step(target - snapshot.tick)] }
        if target < snapshot.tick { return target > 0 ? [.rewind, .step(target)] : [.rewind] }
        return []
    }

    /// The action of a press on empty space or a cell that ended at `timestamp`.
    private mutating func spaceTap(_ touch: Touch, timestamp: Double) -> [ChronoConstellatorGestureAction] {
        guard touch.travel < Self.tapDistance else {
            lastTapTime = nil
            return []
        }
        if let last = lastTapTime, timestamp.isFinite, timestamp - last >= 0,
           timestamp - last <= Self.doubleTapWindow {
            lastTapTime = nil
            resetView()
            return [.resetView]
        }
        lastTapTime = timestamp.isFinite ? timestamp : nil
        return []
    }

    /// Cancels any one-finger gesture (nothing sent) and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        touch = nil
        clearPreview()
        lastTapTime = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
    }

    /// Clears the candidate cell, the scrub tick and the dragged star.
    private mutating func clearPreview() {
        candidateCell = nil
        scrubTick = nil
        draggedStar = nil
    }

    // MARK: Helpers

    /// The picker's loop index of `star` at `location`, or nil (unusable view included).
    private func loopIndex(_ star: Int, at location: Vec2, viewSize: Vec2,
                           snapshot: ChronoConstellatorSceneSnapshot) -> Int? {
        guard Self.usable(viewSize), location.isFinite,
              let index = ChronoConstellatorPicker.loopIndex(star: star, at: Self.simd(location),
                                                            size: Self.simd(viewSize), snapshot: snapshot,
                                                            orbit: orbit),
              snapshot.stars.indices.contains(star), snapshot.stars[star].loop.indices.contains(index) else {
            return nil
        }
        return index
    }

    /// The picker's scrub tick at `location`, or nil (unusable view included).
    private func tick(at location: Vec2, viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot) -> Int? {
        guard Self.usable(viewSize), location.isFinite else { return nil }
        return ChronoConstellatorPicker.tick(at: Self.simd(location), size: Self.simd(viewSize), snapshot: snapshot,
                                             orbit: orbit)
    }

    /// Whether `location` lies within ``barReach`` points of the projected current-tick bar line: the segment from the
    /// grid's left to its right edge at z = halfDepth − tickBarInset·u and y = trackLift·u.
    private func nearBar(_ location: Vec2, viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot) -> Bool {
        guard location.isFinite, snapshot.columns > 0, snapshot.rows > 0,
              let camera = camera(viewSize: viewSize, snapshot: snapshot) else { return false }
        let u: Double = ChronoConstellatorSceneGeometry.cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let z: Double = Double(snapshot.rows) * u / 2 - ChronoConstellatorSceneGeometry.tickBarInset * u
        let y: Double = ChronoConstellatorSceneGeometry.trackLift * u
        guard let a = ChronoConstellatorSceneGeometry.project(SIMD3(-halfWidth, y, z), camera: camera),
              let b = ChronoConstellatorSceneGeometry.project(SIMD3(halfWidth, y, z), camera: camera) else {
            return false
        }
        let p: SIMD2<Double> = Self.simd(location)
        let pa: SIMD2<Double> = SIMD2(a.x * viewSize.x, a.y * viewSize.y)
        let pb: SIMD2<Double> = SIMD2(b.x * viewSize.x, b.y * viewSize.y)
        return Self.segmentDistance(p, pa, pb) <= Self.barReach
    }

    /// The distance from `p` to the segment `a` … `b` (to `a` for a degenerate segment).
    static func segmentDistance(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let ab: SIMD2<Double> = b - a
        let lengthSquared: Double = (ab * ab).sum()
        var t: Double = 0
        if lengthSquared > 0 { t = min(max(((p - a) * ab).sum() / lengthSquared, 0), 1) }
        let d: SIMD2<Double> = p - (a + ab * t)
        return (d * d).sum().squareRoot()
    }

    /// Whether `snapshot` accepts edits: playing at tick 0.
    private static func editable(_ snapshot: ChronoConstellatorSceneSnapshot) -> Bool {
        snapshot.stage == .playing && snapshot.tick == 0
    }

    /// Whether `pick` is the timeline band.
    private static func isTimeline(_ pick: ChronoConstellatorPick) -> Bool {
        if case .timeline = pick { return true }
        return false
    }

    /// Whether `pick` is a field cell.
    private static func isCell(_ pick: ChronoConstellatorPick) -> Bool {
        if case .cell = pick { return true }
        return false
    }

    /// Moves `touch`'s finger to `location`: its travel grows to the farthest distance from the start (a non-finite
    /// location adds nothing).
    private static func follow(_ touch: inout Touch, to location: Vec2) {
        guard location.isFinite else { return }
        touch.travel = max(touch.travel, (location - touch.start).length)
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
