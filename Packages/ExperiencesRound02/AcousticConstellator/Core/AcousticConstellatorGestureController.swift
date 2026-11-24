// AcousticConstellatorGestureController — feature 424 (R02-G13-04) T-R02G1304-003 (FR-R02G1304-001 … 004, 006;
// SC-R02G1304-001 … 003; clarifications Q1 … Q5). Turns pointer events into Acoustic Constellator gesture actions
// (choose a star or a pair, preview a link drag, link, unlink, nudge, listen, reset the view) and camera orbits,
// host-testable without a screen. A small state machine in the pattern of Harmonic Bridges' gesture controller
// (feature 414):
//
// - One finger goes down: the point is picked once with `AcousticConstellatorPicker.pick(_:size:snapshot:orbit:)` at
//   the current orbit and the view's size; the touch-down snapshot (its links, fixed links and stage) is kept for the
//   whole gesture.
//   - `.star(s)`: a press on star s (state `starPress`).
//   - `.coherence(_)` or `.hold(_)`: a press on a gauge target (state `targetPress`).
//   - `.link(i)`: a press on link i of the snapshot's links (state `linkPress`).
//   - `.empty`: a press on empty space, tracked for a double tap (state `idle`).
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag or move the preview).
// - A press on a star whose travel reaches 16 points becomes a link drag (state `linkDrag`). When the touch-down
//   snapshot is playing, every move from the one that starts the drag on (the release included) whose point differs
//   from the last previewed one sends `[.preview(from: s, target: t, point: p)]`: p the finger in view points, t the
//   other star whose projected centre is nearest the finger within 22 points
//   (`AcousticConstellatorPicker.starAt(_:size:snapshot:orbit:excluding:)`, ties to the lower index) or nil. On any
//   other stage a link drag previews and sends nothing.
// - Release (`.ended`):
//   - a link drag with a target t, the touch-down and the releasing snapshots both playing: for the pair (a, b) =
//     (min(s, t), max(s, t)) `[.link(a, b), .choosePair(s, t)]` when the touch-down snapshot does not link it,
//     `[.unlink(a, b), .choosePair(s, t)]` when the player linked it, `[.choosePair(s, t)]` when a fixed link joins it;
//     without a target, or off playing: nothing;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on star s:
//     `[.nudge(star: s), .choose(star: s)]` while the releasing snapshot is playing, `[.choose(star: s)]` otherwise;
//   - a tap on link i: `[.choosePair(a, b)]` with its stars, in any stage (presentation state);
//   - a tap on a gauge target: `[.listen]` while the releasing snapshot is playing, nothing otherwise;
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture also a tap on empty space,
//     its `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from a link, a gauge target
//     or empty space: nothing.
// - Kernel actions (link, unlink, nudge, listen) are produced only while playing; on every other stage (loading,
//   tutorial, paused, won, failed, result) only `choose`, `choosePair` (a link tap) and `resetView`.
// - A second finger cancels any one-finger gesture (nothing more sent) and the fingers orbit (state `orbiting`):
//   yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the fingers up raises the eye), clamped by
//   `AcousticConstellatorOrbit.clamped()`; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends nothing.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit, the chosen star and partner and the
// preview never enter the digest, the snapshot's state or the kernel, which still applies its own rules (stage, the
// degree and link limits, fixed links, the budget) to every action sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What an Acoustic Constellator gesture asks for (feature 424).
public enum AcousticConstellatorGestureAction: Sendable, Equatable {
    /// Choose star `star` in the panel (presentation only, nothing sent to the kernel).
    case choose(star: Int)
    /// Choose the first star as the panel's star and the second as its partner (presentation only).
    case choosePair(Int, Int)
    /// Preview a link drag from star `from` to the finger at view point `point` (origin top left), aiming at star
    /// `target` or at none (presentation only).
    case preview(from: Int, target: Int?, point: SIMD2<Double>)
    /// Link the two stars (lower index first): `link.add [a, b]`.
    case link(Int, Int)
    /// Remove the player's link between the two stars (lower index first): `link.remove [a, b]`.
    case unlink(Int, Int)
    /// Nudge star `star` one step forward: `star.nudge [star, 1]`.
    case nudge(star: Int)
    /// Listen to the constellation: `constellation.listen`.
    case listen
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Acoustic Constellator gesture actions and camera orbits (feature 424), deterministic for
/// the same events. See the file header for the rules.
public struct AcousticConstellatorGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit; also a press on empty space (tracked for a double tap).
        case idle
        /// One finger went down on a star: a tap or a link drag is still possible.
        case starPress
        /// A press on a star moved at least 16 points: a link drag.
        case linkDrag
        /// One finger went down on a coherence bar or a hold pip: a tap listens.
        case targetPress
        /// One finger went down on a link: a tap chooses its stars.
        case linkPress
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

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``AcousticConstellatorOrbit/authored`` at start.
    public private(set) var orbit: AcousticConstellatorOrbit = .authored

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
        /// Star `index`.
        case star(Int)
        /// A coherence bar or a hold pip.
        case gauge
        /// A link between stars `a` and `b`.
        case link(a: Int, b: Int)
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
        /// The touch-down snapshot (links, fixed links, stars, stage).
        let snapshot: AcousticConstellatorSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether the press became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The point of the last preview, nil before the first.
        var previewed: Vec2?
        /// The star the last preview aimed at, nil for none.
        var aim: Int?
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: AcousticConstellatorSceneSnapshot) -> AcousticConstellatorCamera? {
        guard Self.usable(viewSize) else { return nil }
        return AcousticConstellatorSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one: links, fixed links
    /// and stage). Returns the actions the event produces (see the file header): previews on moves, everything else
    /// on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: AcousticConstellatorSceneSnapshot) -> [AcousticConstellatorGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot)
            return []
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
    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: AcousticConstellatorSceneSnapshot) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot)
            } else {
                secondFinger()
            }
        case .starPress, .linkDrag, .targetPress, .linkPress:
            secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    /// A finger moved: the one-finger gesture follows it (perhaps becoming a drag or moving the preview), or the orbit
    /// follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [AcousticConstellatorGestureAction] {
        switch state {
        case .idle, .starPress, .linkDrag, .targetPress, .linkPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [AcousticConstellatorGestureAction] = follow(&current, to: event.location, viewSize: viewSize)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: AcousticConstellatorOrbit =
                AcousticConstellatorOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
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
                                snapshot: AcousticConstellatorSceneSnapshot) -> [AcousticConstellatorGestureAction] {
        switch state {
        case .idle, .starPress, .linkDrag, .targetPress, .linkPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastEmptyTap = nil
                return []
            }
            var actions: [AcousticConstellatorGestureAction] = follow(&current, to: event.location, viewSize: viewSize)
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
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: AcousticConstellatorSceneSnapshot) {
        var pick: AcousticConstellatorPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = AcousticConstellatorPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                                   snapshot: snapshot, orbit: orbit)
        }
        var target: Target = .nothing
        switch pick {
        case .star(let index):
            if index >= 0, index < snapshot.stars.count { target = .star(index) }
        case .coherence, .hold:
            target = .gauge
        case .link(let index):
            if index >= 0, index < snapshot.links.count {
                target = .link(a: snapshot.links[index].a, b: snapshot.links[index].b)
            }
        case .empty:
            target = .nothing
        }
        switch target {
        case .star: state = .starPress
        case .gauge: state = .targetPress
        case .link: state = .linkPress
        case .nothing: state = .idle
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                      snapshot: snapshot, travel: 0, dragging: false, previewed: nil, aim: nil)
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing): its travel grows to the farthest
    /// distance from the start; a press on a star reaching ``dragDistance`` becomes a link drag; returns the preview
    /// this move produces (a playing link drag whose point moved).
    private mutating func follow(_ touch: inout Touch, to location: Vec2,
                                 viewSize: Vec2) -> [AcousticConstellatorGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        guard case .star(let star) = touch.target else { return [] }
        if !touch.dragging {
            guard touch.travel >= Self.dragDistance else { return [] }
            touch.dragging = true
            if state == .starPress { state = .linkDrag }
        }
        guard touch.snapshot.stage == .playing, location != touch.previewed else { return [] }
        var aim: Int? = nil
        if Self.usable(viewSize) {
            aim = AcousticConstellatorPicker.starAt(Self.simd(location), size: Self.simd(viewSize),
                                                    snapshot: touch.snapshot, orbit: orbit, excluding: star)
        }
        touch.previewed = location
        touch.aim = aim
        return [.preview(from: star, target: aim, point: Self.simd(location))]
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed);
    /// `playing` tells whether the releasing snapshot is playing.
    private mutating func release(_ touch: Touch, at event: PointerEvent,
                                  playing: Bool) -> [AcousticConstellatorGestureAction] {
        switch touch.target {
        case .nothing:
            return emptyRelease(touch, at: event)
        case .gauge:
            lastEmptyTap = nil
            guard isTap(touch, at: event), playing else { return [] }
            return [.listen]
        case .link(let a, let b):
            lastEmptyTap = nil
            guard isTap(touch, at: event) else { return [] }
            return [.choosePair(a, b)]
        case .star(let star):
            lastEmptyTap = nil
            if touch.dragging {
                guard touch.snapshot.stage == .playing, playing, let aim = touch.aim else { return [] }
                return Self.linkRelease(from: star, to: aim, snapshot: touch.snapshot)
            }
            guard isTap(touch, at: event) else { return [] }
            return playing ? [.nudge(star: star), .choose(star: star)] : [.choose(star: star)]
        }
    }

    /// The release of a playing link drag from star `star` to star `aim` on `snapshot`: link, unlink or (a fixed pair)
    /// nothing, then the pair chosen.
    private static func linkRelease(from star: Int, to aim: Int,
                                    snapshot: AcousticConstellatorSceneSnapshot) -> [AcousticConstellatorGestureAction] {
        let pair: AcousticConstellatorLink = AcousticConstellatorLink.between(star, aim)
        let choice: AcousticConstellatorGestureAction = .choosePair(star, aim)
        if snapshot.fixedLinks.contains(pair) { return [choice] }
        if snapshot.links.contains(pair) { return [.unlink(pair.a, pair.b), choice] }
        return [.link(pair.a, pair.b), choice]
    }

    /// The release of a gesture on empty space: a double tap resets the view, anything else sends nothing.
    private mutating func emptyRelease(_ touch: Touch, at event: PointerEvent) -> [AcousticConstellatorGestureAction] {
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
