// BinaryGardensGestureController — feature 504 (R02-G21-04) T-R02G2104-003 (FR-R02G2104-001 … 008, 010, 011, 012;
// SC-R02G2104-001 … 003; clarifications Q1–Q5; research R1–R3, R6–R8). Turns pointer events into Binary Gardens gesture
// actions (move a star to a ring, shift its phase, set its luminosity, tilt the orbit plane, show a tick, inspect a
// world, select a star, preview a drag, reset the view, explain why a gesture does nothing) and camera orbits,
// host-testable without a screen. A small state machine ported from Mushroom Weather's gesture controller (feature
// 494, itself from feature 484), adapted to stars dragged across their rings or along their orbit, luminosity pips,
// the tilt dial, worlds inspected and gauge rows scrubbed:
//
// - One finger goes down: the point is picked once with `BinaryGardensPicker.pick(_:size:snapshot:orbit:)` at the
//   current view orbit and the view's size; the touch-down snapshot (the drawn one: its arrangement, freedoms, star
//   speed, shown tick, inspected world and stage) is kept for the whole gesture.
//   - `.star(i)`: a press on a star (state `starPress`); `.pips(i)`: on its luminosity pips (`pipsPress`); `.dial`: on
//     the tilt dial (`dialPress`); `.world(j)`: on a world (`worldPress`); `.ring(i)`: on a ring (`ringPress`);
//     `.disc`: on the system disc (`discPress`); `.empty`: on empty space (`emptyPress`), tracked for a double tap.
//   - `.gauge(j)`: a gauge row from touch-down on (state `gaugePress`, `scrubDrag` once a tick changed), in any
//     stage: the tick t0 = `BinaryGardensPicker.gaugeTick(_:size:orbit:)` under the finger is read at touch-down
//     (nothing sent), and every later move (the release point counting as a last move) sends `[.showTick(t)]`
//     whenever t differs from the tick last read. Never a kernel action and never an undo step.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag). A press on a star, its pips or the dial whose travel reaches 16 points
//   becomes a drag, decided once, at the move (or release) that starts it:
//   - when the touch-down snapshot is not playing: `[.explain(finishedReason)]` on a won, failed or shown result,
//     `[.explain(notRunningReason)]` in loading, tutorial or paused; nothing else for the gesture;
//   - a star drag: its mode by `BinaryGardensPicker.dragMode(travel:star:size:snapshot:orbit:)` for the travel
//     (finger − touch-down point) — state `ringDrag` or `phaseDrag`; both locked: `[.explain(fixedReason)]` and
//     nothing else;
//   - a pip drag: a locked luminosity gives `[.explain(luminosityLockedReason)]`, a level with a single luminosity
//     level `[.explain(singleLevelReason)]`, nothing else; otherwise state `luminosityDrag`;
//   - a dial drag: state `tiltDrag`;
//   - while playing, on every move from the one that starts the drag on, the drag's target is read on the touch-down
//     snapshot at the view orbit: a ring drag `BinaryGardensPicker.ringTarget`, a phase drag `phaseTarget`, a pip drag
//     `stepValue(start:travel:upper:)` of the star's luminosity with the horizontal travel and upper levels − 1, a dial
//     drag the same of the tilt with upper T_max; the change is `.ring`, `.phase`, `.luminosity` or `.tilt` when the
//     target differs from the committed value, else none. Whenever it changes: a change sends `[.preview(change)]`;
//     no change sends `[.clearPreview]` (only when a preview was showing). A release never previews itself.
// - Release (`.ended`):
//   - a star, pip or dial drag while playing: the target read at the release point (the last one read for a
//     non-finite point); when the releasing snapshot is still playing and it is a change, exactly one `[.setRing]`,
//     `[.setPhase]`, `[.setLuminosity]` or `[.setTilt]` (`star.ring`, `star.phase`, `star.luminosity`, `orbit.tilt`;
//     the presenter drops its preview; a change the kernel refuses is still sent once, so its refusal is shown and
//     logged); else `[.clearPreview]`;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on a star:
//     `[.selectStar(i), .explain(starReason)]` in any stage;
//   - a tap on the luminosity pips: while playing (touch-down and releasing snapshots), `[.setLuminosity(i, k)]` for
//     the pip k nearest the finger (`BinaryGardensPicker.nearestPip`) when it differs from the current level, else
//     nothing; a locked luminosity or a single level is explained; outside playing the stage is explained;
//   - a tap on the dial: while playing, `[.setTilt(s)]` for the nearest pip when it differs, else nothing; outside
//     playing the stage is explained;
//   - a tap on a world: `[.inspectWorld(j)]`, or `[.inspectWorld(nil)]` when j is already inspected, in any stage;
//   - a tap on a gauge row: `[.inspectWorld(j)]` (no toggle) and, when the cast x is at most 0.95 (not on the bloom
//     meter) and the press did not scrub, `.showTick(t)` for the tick under the finger; in any stage;
//   - a tap on a ring: `[.explain(ringReason)]`; on the system disc: nothing (it breaks a double tap);
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture a tap on empty space, its
//     `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit. A completed
//     double tap starts no new one;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from a world, a ring, the
//     disc or empty space: nothing. A scrub sends only its ticks.
// - Kernel actions are produced only while playing; `clock.show` and inspection in any stage. The kernel still applies
//   its own rules (stage, budget, separation) to every action sent.
// - A second finger cancels any one-finger gesture — sending `[.clearPreview]` when a preview was showing, nothing
//   else — and the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the
//   fingers right carries the eye towards +x, moving them up raises the eye), clamped by
//   `BinaryGardensViewOrbit.clamped()`; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends no kernel action and no tick (only the same
//   `[.clearPreview]` when a preview was showing). `cancel()` sends nothing; the presenter clears its own preview when
//   it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the view orbit, the shown tick, the preview and the
// inspection never enter the digest or the kernel. The controller calls only the picker's contract and
// `BinaryGardensSceneGeometry.camera(aspect:orbit:)`.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Binary Gardens gesture asks for (feature 504, R02-G21-04).
public enum BinaryGardensGestureAction: Sendable, Equatable {
    /// Move star `star` to ring `index`: `star.ring [star, index]` (one action); sent only while playing, on the
    /// release of a ring drag on another ring.
    case setRing(star: Int, index: Int)
    /// Shift star `star` to grid phase `step`: `star.phase [star, step]` (one action); sent only while playing, on the
    /// release of a phase drag at another grid phase.
    case setPhase(star: Int, step: Int)
    /// Set star `star`'s luminosity to level `index`: `star.luminosity [star, index]` (one action); sent only while
    /// playing, for a pip tap or the release of a pip drag at another level.
    case setLuminosity(star: Int, index: Int)
    /// Tilt the orbit plane to `step`: `orbit.tilt [step]` (one action); sent only while playing, for a dial tap or the
    /// release of a dial drag at another step.
    case setTilt(Int)
    /// Show tick `tick` (1 … 48): `clock.show [tick]` (presentation only; any stage).
    case showTick(Int)
    /// Inspect world `world`, or clear the inspection with nil (presentation only; any stage).
    case inspectWorld(Int?)
    /// Select star `star` in the panel (a tap on it; presentation only).
    case selectStar(Int)
    /// The drag would make `change` (a `.ring`, `.phase`, `.luminosity` or `.tilt` action, always a change): the
    /// presenter previews it (presentation only).
    case preview(BinaryGardensAction)
    /// The drag would change nothing (or ended): the presenter drops its preview.
    case clearPreview
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
    /// Why the gesture does nothing (a star or a ring tapped, a locked control, a single level, the play not running);
    /// shown in the description.
    case explain(String)
}

/// Turns pointer events into Binary Gardens gesture actions and camera orbits (feature 504), deterministic for the
/// same events. See the file header for the rules.
public struct BinaryGardensGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on a star: a tap or a star drag is still possible.
        case starPress
        /// A star drag across the rings.
        case ringDrag
        /// A star drag along its orbit.
        case phaseDrag
        /// One finger went down on a star's luminosity pips: a tap or a luminosity drag is still possible.
        case pipsPress
        /// A sideways drag along the luminosity pips.
        case luminosityDrag
        /// One finger went down on the tilt dial: a tap or a tilt drag is still possible.
        case dialPress
        /// A sideways drag along the tilt dial.
        case tiltDrag
        /// One finger went down on a gauge row: a tap or a scrub is possible.
        case gaugePress
        /// A press on a gauge row changed the tick under the finger: the scrub.
        case scrubDrag
        /// One finger went down on a world: a tap inspects it.
        case worldPress
        /// One finger went down on a ring: a tap explains.
        case ringPress
        /// One finger went down on the system disc: nothing responds.
        case discPress
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
    /// The largest cast x of a gauge-row tap that shows its tick (the bloom meter starts at 0.97).
    public static let tickTapLimit: Double = 0.95

    /// The explanation of a gesture that would change the system when the play is over (won, failed, result shown).
    public static let finishedReason: String = "The play is over: undo or go to the next level"
    /// The explanation of a gesture that would change the system while the level is not played (loading, tutorial,
    /// paused).
    public static let notRunningReason: String = "The level is not being played"
    /// The explanation of a tap on a star (in any stage).
    public static let starReason: String =
        "Drag a star along its orbit to shift its phase, or across the rings to move it"
    /// The explanation of a tap on a ring (in any stage).
    public static let ringReason: String = "Drag a star across the rings to move it to another ring"
    /// The explanation of a star drag whose star has neither its ring nor its phase adjustable.
    public static let fixedReason: String = "This star's ring and phase are fixed"
    /// The explanation of a pip tap or drag on a star whose luminosity is not adjustable.
    public static let luminosityLockedReason: String = "This star's brightness is fixed"
    /// The explanation of a pip tap or drag on a level with a single luminosity level.
    public static let singleLevelReason: String = "This level has a single brightness"

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``BinaryGardensViewOrbit/authored`` at start.
    public private(set) var orbit: BinaryGardensViewOrbit = .authored

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
        /// World `j`'s gauge row.
        case gauge(Int)
        /// Star `i`'s luminosity pips.
        case pips(Int)
        /// Star `i`.
        case star(Int)
        /// World `j`.
        case world(Int)
        /// Ring `i`.
        case ring(Int)
        /// The tilt dial.
        case dial
        /// The system disc.
        case disc
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
        let snapshot: BinaryGardensSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether a press on a star, its pips or the dial became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// Whether the drag explained why it does nothing (not playing, locked, a single level).
        var blocked: Bool
        /// A star drag's mode, decided once.
        var mode: BinaryGardensStarDragMode?
        /// The change the drag last read (nil: no change).
        var change: BinaryGardensAction?
        /// Whether a preview is showing (the last change sent was a change).
        var previewing: Bool
        /// The tick a gauge press last read.
        var tick: Int?
        /// Whether the gauge press showed a tick during the gesture.
        var scrubbed: Bool
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points at the current orbit, or nil for a view that is not finite
    /// and positive.
    public func camera(viewSize: Vec2) -> BinaryGardensCamera? {
        guard Self.usable(viewSize) else { return nil }
        return BinaryGardensSceneGeometry.camera(aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one: the core's snapshot
    /// with the presenter's preview and inspection). Returns the actions the event produces (see the file header):
    /// ticks on scrub moves, previews and clearing values on drag moves, a clearing value on a cancel, everything else
    /// on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
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

    /// The explanation of a kernel gesture in `stage` (not playing): ``finishedReason`` for a won or failed play or a
    /// shown result, ``notRunningReason`` otherwise.
    public static func stageReason(_ stage: BinaryGardensStage) -> String {
        switch stage {
        case .won, .failed, .result: return finishedReason
        default: return notRunningReason
        }
    }

    // MARK: Phases

    /// Whether `state` is a one-finger state.
    private static func oneFinger(_ state: State) -> Bool {
        switch state {
        case .orbiting, .cancelled: return false
        default: return true
        }
    }

    /// A finger went down: a first finger starts a one-finger gesture, a second cancels it (clearing a preview) and
    /// orbits, a third re-bases the orbit's midpoint.
    private mutating func began(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil { return start(event, viewSize: viewSize, snapshot: snapshot) }
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        default:
            return secondFinger()
        }
    }

    /// A finger moved: the one-finger gesture follows it, or the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [BinaryGardensGestureAction] {
        if Self.oneFinger(state) {
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [BinaryGardensGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                               previewing: true)
            touch = current
            return actions
        }
        guard state == .orbiting, let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
        orbitMidpoint = midpoint
        guard Self.usable(viewSize) else { return [] }
        let delta: Vec2 = midpoint - last
        let turned: BinaryGardensViewOrbit =
            BinaryGardensViewOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                   pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
        orbit = turned.clamped()
        return []
    }

    /// A finger lifted (or was cancelled): the one-finger gesture is released, an orbit ends or a cancelled gesture
    /// waits for the last finger.
    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
        if Self.oneFinger(state) {
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.previewing ? [.clearPreview] : []
            }
            let last: [BinaryGardensGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                            previewing: false)
            return last + release(current, at: event, viewSize: viewSize, snapshot: snapshot)
        }
        if state == .orbiting {
            orbitMidpoint = nil
            state = tracker.count == 0 ? .idle : .cancelled
        } else if tracker.count == 0 {
            state = .idle
        }
        return []
    }

    // MARK: Gestures

    /// Starts a one-finger gesture: picks the touch-down point once and decides what the gesture is on; a touch on a
    /// gauge row reads the tick under it (nothing sent).
    private mutating func start(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
        var pick: BinaryGardensPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = BinaryGardensPicker.pick(Self.simd(event.location), size: Self.simd(viewSize), snapshot: snapshot,
                                            orbit: orbit)
        }
        let target: Target
        switch pick {
        case .gauge(let world):
            target = .gauge(world)
            state = .gaugePress
        case .pips(let star):
            target = .pips(star)
            state = .pipsPress
        case .star(let star):
            target = .star(star)
            state = .starPress
        case .world(let world):
            target = .world(world)
            state = .worldPress
        case .ring(let ring):
            target = .ring(ring)
            state = .ringPress
        case .dial:
            target = .dial
            state = .dialPress
        case .disc:
            target = .disc
            state = .discPress
        case .empty:
            target = .nothing
            state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, travel: 0, dragging: false, blocked: false, mode: nil,
                                   change: nil, previewing: false, tick: nil, scrubbed: false)
        if case .gauge = target { current.tick = gaugeTick(event.location, viewSize: viewSize) }
        touch = current
        return []
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing) in a view of `viewSize`: a gauge
    /// press sends a changed tick; the travel grows to the farthest distance from the start; a press on a star, its pips
    /// or the dial reaching ``dragDistance`` becomes a drag (explaining once when it cannot change anything); when
    /// `previewing` (a move, not the release) a drag while playing sends a change of its target (a preview or a clearing
    /// value).
    private mutating func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                                 previewing: Bool) -> [BinaryGardensGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        if case .gauge = touch.target {
            guard let tick = gaugeTick(location, viewSize: viewSize), tick != touch.tick else { return [] }
            touch.tick = tick
            touch.scrubbed = true
            state = .scrubDrag
            return [.showTick(tick)]
        }
        guard Self.draggable(touch.target) else { return [] }
        if !touch.dragging && touch.travel >= Self.dragDistance {
            touch.dragging = true
            if let reason = startDrag(&touch, at: location, viewSize: viewSize) {
                touch.blocked = true
                return [.explain(reason)]
            }
            if touch.blocked { return [] }
        }
        guard previewing, Self.movingDrag(touch) else { return [] }
        let change: BinaryGardensAction? = self.change(location, touch: touch, viewSize: viewSize)
        guard change != touch.change else { return [] }
        touch.change = change
        if let action = change {
            touch.previewing = true
            return [.preview(action)]
        }
        guard touch.previewing else { return [] }
        touch.previewing = false
        return [.clearPreview]
    }

    /// Decides the drag `touch` starts at `location` (once): the explanation when it cannot change anything (the
    /// stage, both of a star's ring and phase fixed, a locked luminosity, a single level), else nil with the state and a
    /// star drag's mode set. A dial without steps blocks silently.
    private mutating func startDrag(_ touch: inout Touch, at location: Vec2, viewSize: Vec2) -> String? {
        let s: BinaryGardensSceneSnapshot = touch.snapshot
        guard s.stage == .playing else { return Self.stageReason(s.stage) }
        switch touch.target {
        case .star(let star):
            let travel: SIMD2<Double> = Self.simd(location - touch.start)
            guard Self.usable(viewSize),
                  let mode = BinaryGardensPicker.dragMode(travel: travel, star: star, size: Self.simd(viewSize),
                                                          snapshot: s, orbit: orbit) else {
                return Self.usable(viewSize) ? Self.fixedReason : nil
            }
            touch.mode = mode
            state = mode == .ring ? .ringDrag : .phaseDrag
        case .pips(let star):
            if !s.freedom(star).luminosity { return Self.luminosityLockedReason }
            if s.luminosityLevels.count <= 1 { return Self.singleLevelReason }
            state = .luminosityDrag
        case .dial:
            guard s.maxTilt > 0 else {
                touch.blocked = true
                return nil
            }
            state = .tiltDrag
        default:
            touch.blocked = true
        }
        return nil
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed) in a
    /// view of `viewSize`; `snapshot` is the releasing snapshot.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        if case .nothing = touch.target {
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
        lastTap = nil
        if Self.movingDrag(touch) { return commit(touch, at: event, viewSize: viewSize, snapshot: snapshot) }
        guard tap else { return [] }
        switch touch.target {
        case .star(let star):
            return [.selectStar(star), .explain(Self.starReason)]
        case .pips(let star):
            return pipTap(star, touch: touch, at: event, viewSize: viewSize, snapshot: snapshot)
        case .dial:
            return dialTap(touch, at: event, viewSize: viewSize, snapshot: snapshot)
        case .world(let world):
            return [.inspectWorld(touch.snapshot.inspectedWorld == world ? nil : world)]
        case .gauge(let world):
            var actions: [BinaryGardensGestureAction] = [.inspectWorld(world)]
            if !touch.scrubbed, Self.usable(viewSize),
               let x = BinaryGardensPicker.gaugeX(Self.simd(event.location), size: Self.simd(viewSize), orbit: orbit),
               x <= Self.tickTapLimit, let tick = gaugeTick(event.location, viewSize: viewSize) {
                actions.append(.showTick(tick))
            }
            return actions
        case .ring:
            return [.explain(Self.ringReason)]
        case .disc, .nothing:
            return []
        }
    }

    /// The release of a drag begun while playing: the change read at the release point (the last one read for a
    /// non-finite point); when the releasing `snapshot` is still playing and it is a change, exactly one kernel action;
    /// else a clearing value.
    private func commit(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                        snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
        var change: BinaryGardensAction? = touch.change
        if event.location.isFinite { change = self.change(event.location, touch: touch, viewSize: viewSize) }
        guard snapshot.stage == .playing, let action = change else { return [.clearPreview] }
        switch action {
        case .ring(let star, let index): return [.setRing(star: star, index: index)]
        case .phase(let star, let step): return [.setPhase(star: star, step: step)]
        case .luminosity(let star, let index): return [.setLuminosity(star: star, index: index)]
        case .tilt(let step): return [.setTilt(step)]
        case .run: return [.clearPreview]
        }
    }

    /// The actions of a tap on star `star`'s luminosity pips lifted by `event`, released on `snapshot`: the stage, a
    /// locked luminosity or a single level explained; else the nearest pip's level when it differs from the current one.
    private func pipTap(_ star: Int, touch: Touch, at event: PointerEvent, viewSize: Vec2,
                        snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
        let s: BinaryGardensSceneSnapshot = touch.snapshot
        guard s.stage == .playing else { return [.explain(Self.stageReason(s.stage))] }
        guard snapshot.stage == .playing else { return [.explain(Self.stageReason(snapshot.stage))] }
        guard s.freedom(star).luminosity else { return [.explain(Self.luminosityLockedReason)] }
        guard s.luminosityLevels.count > 1 else { return [.explain(Self.singleLevelReason)] }
        guard Self.usable(viewSize), s.arrangement.luminosities.indices.contains(star) else { return [] }
        let level: Int = BinaryGardensPicker.nearestPip(Self.simd(event.location), star: star,
                                                        size: Self.simd(viewSize), snapshot: s, orbit: orbit)
        return level == s.arrangement.luminosities[star] ? [] : [.setLuminosity(star: star, index: level)]
    }

    /// The actions of a tap on the tilt dial lifted by `event`, released on `snapshot`: the stage explained; else the
    /// nearest pip's step when it differs from the current tilt.
    private func dialTap(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                         snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensGestureAction] {
        let s: BinaryGardensSceneSnapshot = touch.snapshot
        guard s.stage == .playing else { return [.explain(Self.stageReason(s.stage))] }
        guard snapshot.stage == .playing else { return [.explain(Self.stageReason(snapshot.stage))] }
        guard Self.usable(viewSize), s.maxTilt > 0 else { return [] }
        let step: Int = BinaryGardensPicker.nearestTiltPip(Self.simd(event.location), size: Self.simd(viewSize),
                                                           snapshot: s, orbit: orbit)
        return step == s.arrangement.tilt ? [] : [.setTilt(step)]
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
    private mutating func secondFinger() -> [BinaryGardensGestureAction] {
        var actions: [BinaryGardensGestureAction] = []
        if let current = touch, current.previewing { actions = [.clearPreview] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// Whether a press on `target` can become a drag that previews: a star, its pips or the dial.
    private static func draggable(_ target: Target) -> Bool {
        switch target {
        case .star, .pips, .dial: return true
        default: return false
        }
    }

    /// Whether `touch` is a moving drag that previews and may commit: a drag of a star, its pips or the dial begun while
    /// the touch-down snapshot was playing, not blocked by a lock or a single level.
    private static func movingDrag(_ touch: Touch) -> Bool {
        guard touch.dragging, !touch.blocked, draggable(touch.target) else { return false }
        return touch.snapshot.stage == .playing
    }

    /// The change a drag of `touch` reads at `location` in a view of `viewSize` (nil: no change): a star drag's ring or
    /// grid phase target, a pip drag's luminosity or a dial drag's tilt by horizontal travel, each on the touch-down
    /// snapshot at the view orbit, when it differs from the committed value.
    private func change(_ location: Vec2, touch: Touch, viewSize: Vec2) -> BinaryGardensAction? {
        guard location.isFinite else { return nil }
        let s: BinaryGardensSceneSnapshot = touch.snapshot
        let travel: Double = location.x - touch.start.x
        switch touch.target {
        case .star(let star):
            guard Self.usable(viewSize), let mode = touch.mode, (0..<2).contains(star),
                  s.arrangement.rings.count == 2, s.arrangement.phases.count == 2 else { return nil }
            let point: SIMD2<Double> = Self.simd(location)
            let size: SIMD2<Double> = Self.simd(viewSize)
            switch mode {
            case .ring:
                let index: Int = BinaryGardensPicker.ringTarget(point, star: star, size: size, snapshot: s, orbit: orbit)
                return index == s.arrangement.rings[star] ? nil : .ring(star: star, index: index)
            case .phase:
                let step: Int = BinaryGardensPicker.phaseTarget(point, star: star, size: size, snapshot: s,
                                                                orbit: orbit)
                return step == s.arrangement.phases[star] ? nil : .phase(star: star, step: step)
            }
        case .pips(let star):
            guard s.arrangement.luminosities.indices.contains(star) else { return nil }
            let current: Int = s.arrangement.luminosities[star]
            let level: Int = BinaryGardensPicker.stepValue(start: current, travel: travel,
                                                           upper: s.luminosityLevels.count - 1)
            return level == current ? nil : .luminosity(star: star, index: level)
        case .dial:
            let current: Int = s.arrangement.tilt
            let step: Int = BinaryGardensPicker.stepValue(start: current, travel: travel, upper: s.maxTilt)
            return step == current ? nil : .tilt(step: step)
        default:
            return nil
        }
    }

    /// The tick 1 … 48 under `location` on a gauge row in a view of `viewSize` at the view orbit; nil for unusable
    /// input.
    private func gaugeTick(_ location: Vec2, viewSize: Vec2) -> Int? {
        guard Self.usable(viewSize), location.isFinite else { return nil }
        return BinaryGardensPicker.gaugeTick(Self.simd(location), size: Self.simd(viewSize), orbit: orbit)
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
