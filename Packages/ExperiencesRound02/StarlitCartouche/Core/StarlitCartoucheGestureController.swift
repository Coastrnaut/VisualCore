// StarlitCartoucheGestureController — feature 454 (R02-G16-04) T-R02G1604-003 (FR-R02G1604-001, 002, 004, 006, 007;
// SC-R02G1604-001 … 003; clarifications Q1 … Q5). Turns pointer events into Starlit Cartouche gesture actions (choose
// a destination or a wait, preview and fly a leg, explain why a gesture does nothing, reset the view) and camera
// orbits, host-testable without a screen. A small state machine in the pattern of Voxel Origami's gesture controller
// (feature 444), adapted to a ship among orbiting stars with a time slider:
//
// - One finger goes down: the point is picked once with `StarlitCartouchePicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the touch-down snapshot (its stars, ship's star, beat, choice and stage) is kept
//   for the whole gesture.
//   - `.star(s)`: a press on a star other than the ship's (state `starPress`).
//   - `.ship`: a press on the ship's star (state `shipPress`).
//   - `.slider`: a slider drag from touch-down on (state `sliderDrag`), in any stage: the touch-down sends
//     `[.chooseWait(w)]` for the wait w = `StarlitCartouchePicker.sliderWait(_:size:snapshot:orbit:)` under the finger,
//     and every later move (the release point counting as a last move) sends `[.chooseWait(w)]` whenever w differs
//     from the wait last sent. Never a kernel action.
//   - `.empty`: a press on empty space (state `emptyPress`), tracked for a double tap.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag). A press on the ship whose travel reaches 16 points becomes a ship drag
//   (state `shipDrag`); a drag from a star or from empty space does nothing.
// - Ship drag, decided when the drag starts (by the move or the release that starts it):
//   - when the touch-down snapshot is not playing: `[.explain(finishedReason)]` on won, failed or result,
//     `[.explain(waitingReason)]` on loading, tutorial or paused; nothing else for the gesture;
//   - while playing: on every move from the one that starts the drag on, the star under the finger (picked on the
//     touch-down snapshot at the orbit; a star other than the ship's) is the pending destination; whenever it changes,
//     `[.preview(s)]` is sent for a star s, or `[.clearPreview]` when the finger leaves every such star. A release
//     never sends a preview itself.
// - Release (`.ended`):
//   - a ship drag while playing: `[.clearPreview]` when a destination was pending, followed — when the releasing
//     snapshot is still playing at the touch-down's star and beat and the release point picks a star s other than the
//     ship's — by `.fly(star: s, wait: w)` (w the releasing snapshot's chosen wait; `route.fly [s, w]`) when a corridor
//     of the releasing snapshot joins the ship's star and s, else by `.explain(noCorridorReason(s))`;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on a star s:
//     `[.chooseDestination(s)]` in any stage; as the second tap of a double tap (the previous gesture a tap on the
//     same star, its `.ended` at most 0.35 s earlier and at most 22 points away): while the releasing snapshot is
//     playing `[.fly(star: s, wait: w)]` (the kernel decides; the first tap already chose s), on won, failed or result
//     `[.chooseDestination(s), .explain(finishedReason)]`, on loading, tutorial or paused `[.chooseDestination(s)]`.
//     A completed double tap starts no new one;
//   - a tap on the ship: nothing;
//   - a tap on empty space: nothing; as the second tap of a double tap on empty space (same window and distance),
//     `[.resetView]` and the authored orbit;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from a star or from empty
//     space: nothing. A slider drag sends only its waits.
// - Kernel actions (`fly`) are produced only while playing; the choices (`route.choose`) in any stage.
// - A second finger cancels any one-finger gesture — sending `[.clearPreview]` when a destination was pending, nothing
//   else — and the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the
//   fingers up raises the eye), clamped by `StarlitCartoucheOrbit.clamped()`; a third finger re-bases the midpoint. A
//   finger lifting while others stay → `cancelled` until every finger has lifted. A `.cancelled` phase sends no kernel
//   action and no choice (only the same `[.clearPreview]` when a destination was pending). `cancel()` sends nothing;
//   the presenter clears its own preview when it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit, the choice and the preview never enter
// the digest or the kernel, which still applies its own rules (stage, windows, hazards, the deadline, strokes, the
// budget, a star without a corridor) to every leg sent. The controller calls only the picker's contract
// (`StarlitCartouchePicker.pick`, `sliderWait`, `StarlitCartoucheSceneGeometry.camera(_:aspect:orbit:)`).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Starlit Cartouche gesture asks for (feature 454).
public enum StarlitCartoucheGestureAction: Sendable, Equatable {
    /// Choose star `index` as the destination, the chosen wait kept: `route.choose [index, wait]` (presentation only,
    /// never an undo step).
    case chooseDestination(Int)
    /// Choose wait `wait` (0 … 8), the chosen destination kept: `route.choose [destination, wait]` (presentation only).
    case chooseWait(Int)
    /// Fly one leg to star `star` after waiting `wait` beats: `route.fly [star, wait]` (one undo step).
    case fly(star: Int, wait: Int)
    /// The pending destination of a ship drag is star `index`: the presenter previews that leg (presentation only).
    case preview(Int)
    /// The pending destination is gone: the presenter restores the destination chosen before the drag.
    case clearPreview
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
    /// Why the gesture does nothing (the play is over or not under way, no corridor); shown in the description.
    case explain(String)
}

/// Turns pointer events into Starlit Cartouche gesture actions and camera orbits (feature 454), deterministic for the
/// same events. See the file header for the rules.
public struct StarlitCartoucheGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on a star other than the ship's: a tap or a double tap is still possible.
        case starPress
        /// One finger went down on the ship's star: a ship drag is still possible.
        case shipPress
        /// A press on the ship moved at least 16 points: a ship drag.
        case shipDrag
        /// One finger went down on the time slider: every change of the wait under it is chosen.
        case sliderDrag
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

    /// The explanation of a ship drag, or a double tap on a star, on a won, failed or shown-result play.
    public static let finishedReason: String = "The play is over: undo or go to the next level"
    /// The explanation of a ship drag while the play is loading, in its tutorial or paused.
    public static let waitingReason: String = "The play is not under way"

    /// The explanation of a ship drag released over star `star` when no corridor joins it to the ship's star.
    public static func noCorridorReason(_ star: Int) -> String {
        "No corridor joins the ship's star to star \(star)"
    }

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``StarlitCartoucheOrbit/authored`` at start.
    public private(set) var orbit: StarlitCartoucheOrbit = .authored

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
        /// Star `index`, not the ship's.
        case star(Int)
        /// The ship's star.
        case ship
        /// The time slider.
        case slider
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
        let snapshot: StarlitCartoucheSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether a press on the ship became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The pending destination shown by a ship drag, nil when none is.
        var pending: Int?
        /// The wait a slider drag last sent.
        var wait: Int?
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: StarlitCartoucheSceneSnapshot) -> StarlitCartoucheCamera? {
        guard Self.usable(viewSize) else { return nil }
        return StarlitCartoucheSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one). Returns the
    /// actions the event produces (see the file header): waits on slider touches and moves, previews and explanations
    /// on ship-drag moves, a clearing value on a cancel, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: StarlitCartoucheSceneSnapshot) -> [StarlitCartoucheGestureAction] {
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
                                snapshot: StarlitCartoucheSceneSnapshot) -> [StarlitCartoucheGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil { return start(event, viewSize: viewSize, snapshot: snapshot) }
            return secondFinger()
        case .starPress, .shipPress, .shipDrag, .sliderDrag, .emptyPress:
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger moved: the one-finger gesture follows it, or the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [StarlitCartoucheGestureAction] {
        switch state {
        case .idle, .starPress, .shipPress, .shipDrag, .sliderDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [StarlitCartoucheGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                                  previewing: true)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: StarlitCartoucheOrbit =
                StarlitCartoucheOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
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
                                snapshot: StarlitCartoucheSceneSnapshot) -> [StarlitCartoucheGestureAction] {
        switch state {
        case .idle, .starPress, .shipPress, .shipDrag, .sliderDrag, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.pending == nil ? [] : [.clearPreview]
            }
            let last: [StarlitCartoucheGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
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
    /// slider chooses the wait under it at once.
    private mutating func start(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: StarlitCartoucheSceneSnapshot) -> [StarlitCartoucheGestureAction] {
        var pick: StarlitCartouchePick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = StarlitCartouchePicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                               snapshot: snapshot, orbit: orbit)
        }
        var target: Target = .nothing
        switch pick {
        case .star(let index):
            if index >= 0, index < snapshot.stars.count, index != snapshot.star { target = .star(index) }
        case .ship:
            target = .ship
        case .slider:
            target = .slider
        case .empty:
            target = .nothing
        }
        switch target {
        case .star: state = .starPress
        case .ship: state = .shipPress
        case .slider: state = .sliderDrag
        case .nothing: state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, travel: 0, dragging: false, pending: nil, wait: nil)
        var actions: [StarlitCartoucheGestureAction] = []
        if target == .slider {
            let wait: Int = sliderWait(event.location, viewSize: viewSize, snapshot: snapshot)
            current.wait = wait
            actions = [.chooseWait(wait)]
        }
        touch = current
        return actions
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing) in a view of `viewSize`: a slider
    /// drag sends a changed wait; the travel grows to the farthest distance from the start; a press on the ship
    /// reaching ``dragDistance`` becomes a ship drag (explaining once outside playing); when `previewing` (a move, not
    /// the release) a ship drag while playing sends a change of its pending destination.
    private mutating func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                                 previewing: Bool) -> [StarlitCartoucheGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        if touch.target == .slider {
            let wait: Int = sliderWait(location, viewSize: viewSize, snapshot: touch.snapshot)
            guard wait != touch.wait else { return [] }
            touch.wait = wait
            return [.chooseWait(wait)]
        }
        guard touch.target == .ship else { return [] }
        if !touch.dragging && touch.travel >= Self.dragDistance {
            touch.dragging = true
            if state == .shipPress { state = .shipDrag }
            if touch.snapshot.stage != .playing {
                return [.explain(Self.finished(touch.snapshot.stage) ? Self.finishedReason : Self.waitingReason)]
            }
        }
        guard previewing, touch.dragging, touch.snapshot.stage == .playing else { return [] }
        let under: Int? = destination(at: location, viewSize: viewSize, snapshot: touch.snapshot)
        guard under != touch.pending else { return [] }
        touch.pending = under
        if let star = under { return [.preview(star)] }
        return [.clearPreview]
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed) in a
    /// view of `viewSize`; `snapshot` is the releasing snapshot.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  snapshot: StarlitCartoucheSceneSnapshot) -> [StarlitCartoucheGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        switch touch.target {
        case .ship:
            lastTap = nil
            guard touch.dragging, touch.snapshot.stage == .playing else { return [] }
            var actions: [StarlitCartoucheGestureAction] = touch.pending == nil ? [] : [.clearPreview]
            guard snapshot.stage == .playing, snapshot.star == touch.snapshot.star,
                  snapshot.beat == touch.snapshot.beat,
                  let star = destination(at: event.location, viewSize: viewSize, snapshot: touch.snapshot) else {
                return actions
            }
            if Self.joined(snapshot.star, star, snapshot) {
                actions.append(.fly(star: star, wait: snapshot.chosenWait))
            } else {
                actions.append(.explain(Self.noCorridorReason(star)))
            }
            return actions
        case .slider:
            lastTap = nil
            return []
        case .star(let star):
            guard tap else {
                lastTap = nil
                return []
            }
            guard secondTap(of: .star(star), at: event) else {
                lastTap = (.star(star), event.location, event.timestamp)
                return [.chooseDestination(star)]
            }
            lastTap = nil
            if snapshot.stage == .playing { return [.fly(star: star, wait: snapshot.chosenWait)] }
            if Self.finished(snapshot.stage) { return [.chooseDestination(star), .explain(Self.finishedReason)] }
            return [.chooseDestination(star)]
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

    /// Cancels any one-finger gesture for a second finger (sending only `clearPreview` when a destination was pending)
    /// and starts an orbit from the current midpoint.
    private mutating func secondFinger() -> [StarlitCartoucheGestureAction] {
        var actions: [StarlitCartoucheGestureAction] = []
        if let current = touch, current.pending != nil { actions = [.clearPreview] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// The star other than the ship's under `location` in a view of `viewSize` showing `snapshot` at the orbit, or nil.
    private func destination(at location: Vec2, viewSize: Vec2, snapshot: StarlitCartoucheSceneSnapshot) -> Int? {
        guard Self.usable(viewSize), location.isFinite else { return nil }
        let pick: StarlitCartouchePick = StarlitCartouchePicker.pick(Self.simd(location), size: Self.simd(viewSize),
                                                                     snapshot: snapshot, orbit: orbit)
        guard case .star(let index) = pick, index >= 0, index < snapshot.stars.count, index != snapshot.star else {
            return nil
        }
        return index
    }

    /// The wait 0 … 8 under `location` on the slider of a view of `viewSize` showing `snapshot` at the orbit (0 for a
    /// view that is not usable).
    private func sliderWait(_ location: Vec2, viewSize: Vec2, snapshot: StarlitCartoucheSceneSnapshot) -> Int {
        guard Self.usable(viewSize), location.isFinite else { return 0 }
        let wait: Int = StarlitCartouchePicker.sliderWait(Self.simd(location), size: Self.simd(viewSize),
                                                          snapshot: snapshot, orbit: orbit)
        return min(max(wait, 0), 8)
    }

    /// Whether a corridor of `snapshot` joins stars `a` and `b`.
    private static func joined(_ a: Int, _ b: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> Bool {
        for corridor in snapshot.corridors where (corridor.a == a && corridor.b == b)
            || (corridor.a == b && corridor.b == a) {
            return true
        }
        return false
    }

    /// Whether `stage` ends the play for gestures: won, failed or result.
    private static func finished(_ stage: StarlitCartoucheStage) -> Bool {
        stage == .won || stage == .failed || stage == .result
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
