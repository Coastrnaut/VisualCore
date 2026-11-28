// MyceliumArchitectGestureController — feature 514 (R02-G22-04) T-R02G2204-004 (FR-R02G2204-001 … 006, 008, 009, 010,
// 012; SC-R02G2204-001, 002, 003, 006; clarifications Q2–Q5; research R4 … R7; data-model.md; contracts/api.md). Turns
// pointer events into Mycelium Architect gesture actions (place a nutrient or a blocker, clear a placed item, seed or
// unseed a direction, show a pulse, inspect a cell, preview a change, orbit, reset the view, explain why a gesture does
// nothing), host-testable without a screen. A small state machine on the pattern of Binary Gardens' gesture controller
// (feature 504), with feature 504's constants, adapted to sites, seeds dragged from the root, sprouts dragged back onto
// it, the weight gauge scrubbed and cells inspected:
//
// - One finger goes down: the point is picked once with `MyceliumArchitectPicker.pick(_:viewSize:snapshot:orbit:)` at
//   the given view orbit and view size; the touch-down snapshot (the drawn one) and orbit are kept for the whole gesture.
//   - `.cell(c)` while the touch-down snapshot is playing, on an empty site (`level.isSite(c)` and
//     `level.isEmpty(c, in:)`) or on a placed nutrient or blocker: a site press (state `sitePress`); the change is the
//     tool's placement (`.nutrient(c)` or `.blocker(c)`) on an empty site and `.clear(c)` on a placed item, and
//     touch-down sends `[.preview(change)]` (the presenter asks the adapter's `previewReport(_:)` for the kernel's
//     report of the changed arrangement, or its refusal). Any other cell, and every cell outside playing: a cell press
//     (`cellPress`).
//   - `.root`: a root press (`rootPress`); `.sprout(d)`: a sprout press (`sproutPress`); `.gauge`: a gauge press
//     (`gaugePress`); `.empty`: an empty press (`emptyPress`), tracked for a double tap.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move. A press reaching ``dragDistance`` (16 points) is decided once, at the move (or release) that reaches it:
//   - a site press: the preview is cancelled (`[.clearPreview]`) and the release sends nothing;
//   - a root press: outside playing `[.explain(stageReason)]` and nothing else; otherwise a seed drag (`seedDrag`):
//     start and finger are cast onto z = 0 (`MyceliumArchitectPicker.cast`) and the direction is
//     `MyceliumArchitectPicker.direction(from:to:)`; every move whose direction differs from the one previewed sends
//     `[.preview(.seed(direction))]`;
//   - a sprout press of direction d: outside playing `[.explain(stageReason)]`; otherwise an unseed drag (`unseedDrag`)
//     previewing `[.preview(.unseed(d))]` once;
//   - a gauge press: a scrub (`scrub`), in any stage: every move (the release point included) whose pulse
//     `MyceliumArchitectPicker.pulse(atPlaneX:pulsesRun:)` of the cast x differs from the last one sent sends
//     `[.showPulse(pulse)]`;
//   - a cell or empty press: nothing (a release does nothing).
//   A release never previews itself (a drag begun by the release point commits without a preview).
// - Release (`.ended`):
//   - a site press not dragged (any duration; a tap or a longer press under 16 points) released over the same cell
//     (picked with the touch-down snapshot and orbit; otherwise only `.clearPreview`): while the releasing snapshot is
//     playing, exactly one `.send(control, values)` of the change (`cell.nutrient`, `cell.blocker` or `cell.clear`
//     with [column, row]) and `.clearPreview`; a change the kernel refuses (a count at its limit) is still sent once,
//     so its refusal is shown and logged; when the play stopped meanwhile, `[.clearPreview, .explain(stageReason)]`;
//   - a seed drag: with the release point cast and the cast travel at least ``seedTravel`` · s (s the touch-down
//     snapshot's fit scale) while the releasing snapshot is playing, exactly one `.send("root.seed", [d])` for the
//     direction d at the release point, then `.clearPreview`; otherwise `.clearPreview` only (and the stage reason when
//     the play stopped);
//   - an unseed drag: released inside the root's pick disc (`MyceliumArchitectPicker.hitsRoot(_:viewSize:snapshot:
//     orbit:)` on the touch-down snapshot and orbit) while the releasing snapshot is playing, exactly one
//     `.send("root.unseed", [d])` and `.clearPreview`; otherwise `.clearPreview` only;
//   - a gauge press not dragged (any duration): `[.showPulse(p)]` for the pulse under the release point, in any stage;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on the root:
//     `[.explain(rootReason)]`; on a sprout: `[.explain(sproutReason)]`; in any stage;
//   - a tap on a cell (a cell press): `[.inspect(c)]`, or `[.inspect(nil)]` when c is the touch-down snapshot's
//     inspected cell, in any stage; when the cell would be a site press while playing (an empty site or a placed item)
//     but the play is not running, also `.explain(stageReason)`;
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture a tap on empty space, its
//     `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]`. A completed double tap starts no
//     new one;
//   - anything else: nothing.
// - Kernel actions (`.send`) are produced only while playing; pulses and inspection in any stage. The kernel still
//   applies its own rules (stage, change rule, budget) to every action sent.
// - A second finger cancels any one-finger gesture — sending `[.clearPreview]` when a preview was showing, nothing
//   else — and the fingers orbit (state `orbiting`): from the orbit passed with each move, yaw += Δx / width × 90° and
//   pitch −= Δy / height × 60°, clamped by `MyceliumArchitectViewOrbit.clamped()`, sent as `[.orbit(o)]` when it
//   differs from the orbit passed; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends no kernel action (only the same
//   `[.clearPreview]` when a preview was showing). ``cancel()`` sends nothing.
//
// Only event timestamps are read, never a clock. Presentation only: the controller never holds the kernel; the orbit,
// the preview, the shown pulse and the inspection are the presenter's. The controller calls only the picker's contract
// (`pick`, `cast`, `direction`, `pulse`, `hitsRoot`) and the snapshot (level, arrangement, stage, fit scale, pulses
// run, inspected cell).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Mycelium Architect gesture asks for (feature 514, R02-G22-04).
public enum MyceliumArchitectGestureAction: Sendable, Equatable {
    /// Send the adapter control `control` with `values`: `cell.nutrient`, `cell.blocker` or `cell.clear` with
    /// [column, row], `root.seed` or `root.unseed` with [direction]. Produced only while playing.
    case send(String, [Double])
    /// Show pulse `pulse` (`growth.show [pulse]`; presentation only; any stage).
    case showPulse(Int)
    /// Inspect a cell, or clear the inspection with nil (presentation only; any stage).
    case inspect(MyceliumArchitectCell?)
    /// The press or drag would make the kernel action `change`: the presenter previews it through the adapter's
    /// `previewReport(_:)` (presentation only).
    case preview(MyceliumArchitectAction)
    /// The presenter drops its preview.
    case clearPreview
    /// The camera turned to the orbit `orbit` (two fingers; clamped); the presenter stores and redraws it.
    case orbit(MyceliumArchitectViewOrbit)
    /// The camera returns to the authored view (a double tap on empty space).
    case resetView
    /// Why the gesture does nothing (the root or a sprout tapped, the play not running); shown in the description.
    case explain(String)
}

/// Turns pointer events into Mycelium Architect gesture actions (feature 514), deterministic for the same events. See
/// the file header for the rules.
public struct MyceliumArchitectGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on an empty site or a placed item while playing: its change is previewed.
        case sitePress
        /// One finger went down on the root: a tap or a seed drag is still possible.
        case rootPress
        /// A drag from the root choosing the direction to seed.
        case seedDrag
        /// One finger went down on a sprout: a tap or an unseed drag is still possible.
        case sproutPress
        /// A drag of a sprout towards the root.
        case unseedDrag
        /// One finger went down on the weight gauge: a press or a scrub is possible.
        case gaugePress
        /// A drag along the weight gauge showing the pulse under the finger.
        case scrub
        /// One finger went down on a cell that a tap inspects.
        case cellPress
        /// One finger went down on empty space, tracked for a double tap.
        case emptyPress
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap, exclusive: 10 (feature 504).
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a drag: 16 (feature 504).
    public static let dragDistance: Double = 16
    /// The time in seconds (event timestamps) from touch-down at which a lift is no longer a tap, 0.5 (a tap lifts
    /// strictly before it; feature 504).
    public static let tapDuration: Double = 0.5
    /// The longest time in seconds between the two `.ended` events of a double tap, 0.35 (feature 504).
    public static let doubleTapWindow: Double = 0.35
    /// The largest distance in view points between the two lift points of a double tap, 22 (feature 504).
    public static let doubleTapDistance: Double = 22
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90° (feature 504).
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60° (feature 504).
    public static let pitchPerViewHeight: Double = Double.pi / 3
    /// The smallest cast travel of a seed drag that seeds, in cells (times the fit scale s): 0.5 (clarification Q4).
    public static let seedTravel: Double = 0.5

    /// The explanation of a kernel gesture when the play is over (won, failed, result shown).
    public static let finishedReason: String = "The play is over: undo or go to the next level"
    /// The explanation of a kernel gesture while the level is not played (loading, tutorial, paused).
    public static let notRunningReason: String = "The level is not being played"
    /// The explanation of a tap on the root (in any stage).
    public static let rootReason: String = "Drag from the root towards a direction to seed a filament"
    /// The explanation of a tap on a sprout (in any stage).
    public static let sproutReason: String = "Drag a sprout back onto the root to remove it"

    /// The current gesture state (for the presenter's diagnostics).
    public private(set) var state: State = .idle

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
        /// The weight gauge.
        case gauge
        /// The sprout of a seeded direction.
        case sprout(MyceliumArchitectDirection)
        /// The root.
        case root
        /// An empty site or a placed item while playing, with the change a release sends.
        case site(MyceliumArchitectAction)
        /// A cell a tap inspects; `blocked` when it would be a site press but the play is not running.
        case cell(MyceliumArchitectCell, blocked: Bool)
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
        let snapshot: MyceliumArchitectSceneSnapshot
        /// The touch-down view orbit.
        let orbit: MyceliumArchitectViewOrbit
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double = 0
        /// Whether the press became a drag (travel reached ``dragDistance``).
        var dragging: Bool = false
        /// Whether the drag can change nothing (the play not running, an unusable cast).
        var blocked: Bool = false
        /// Whether a preview is showing.
        var previewing: Bool = false
        /// The change last previewed by a drag.
        var previewed: MyceliumArchitectAction?
        /// The pulse a scrub last sent.
        var pulse: Int?
        /// A seed drag's touch-down point cast onto z = 0.
        var startPlane: Vec2?
    }

    /// Creates an idle controller.
    public init() {}

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one) with `tool` chosen
    /// and the camera at `orbit`. Returns the actions the event produces (see the file header); `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: MyceliumArchitectSceneSnapshot,
                                tool: MyceliumArchitectTool,
                                orbit: MyceliumArchitectViewOrbit) -> [MyceliumArchitectGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            return began(event, viewSize: viewSize, snapshot: snapshot, tool: tool, orbit: orbit)
        case .moved:
            return moved(event, viewSize: viewSize, orbit: orbit)
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, snapshot: snapshot)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, snapshot: snapshot)
        }
    }

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel; the presenter clears
    /// its own preview); the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        orbitMidpoint = nil
        lastTap = nil
        state = .idle
    }

    /// The explanation of a kernel gesture in `stage` (not playing): ``finishedReason`` for a won or failed play or a
    /// shown result, ``notRunningReason`` otherwise (loading, tutorial, paused).
    public static func stageReason(_ stage: MyceliumArchitectStage) -> String {
        switch stage {
        case .won, .failed, .result: return finishedReason
        default: return notRunningReason
        }
    }

    /// The `.send` of kernel action `action`: `cell.nutrient`, `cell.blocker` or `cell.clear` with [column, row],
    /// `root.seed` or `root.unseed` with [direction]; nil for the run (never a gesture).
    public static func send(_ action: MyceliumArchitectAction) -> MyceliumArchitectGestureAction? {
        switch action {
        case .nutrient(let cell): return .send("cell.nutrient", [Double(cell.column), Double(cell.row)])
        case .blocker(let cell): return .send("cell.blocker", [Double(cell.column), Double(cell.row)])
        case .clear(let cell): return .send("cell.clear", [Double(cell.column), Double(cell.row)])
        case .seed(let direction): return .send("root.seed", [Double(direction.rawValue)])
        case .unseed(let direction): return .send("root.unseed", [Double(direction.rawValue)])
        case .run: return nil
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
    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: MyceliumArchitectSceneSnapshot,
                                tool: MyceliumArchitectTool,
                                orbit: MyceliumArchitectViewOrbit) -> [MyceliumArchitectGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                return start(event, viewSize: viewSize, snapshot: snapshot, tool: tool, orbit: orbit)
            }
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
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2,
                                orbit: MyceliumArchitectViewOrbit) -> [MyceliumArchitectGestureAction] {
        if Self.oneFinger(state) {
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [MyceliumArchitectGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                                   previewing: true)
            touch = current
            return actions
        }
        guard state == .orbiting, let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
        orbitMidpoint = midpoint
        guard Self.usable(viewSize), midpoint.isFinite, last.isFinite else { return [] }
        let delta: Vec2 = midpoint - last
        let turned: MyceliumArchitectViewOrbit =
            MyceliumArchitectViewOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                       pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight).clamped()
        return turned == orbit ? [] : [.orbit(turned)]
    }

    /// A finger lifted (or was cancelled): the one-finger gesture is released, an orbit ends or a cancelled gesture
    /// waits for the last finger.
    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                snapshot: MyceliumArchitectSceneSnapshot) -> [MyceliumArchitectGestureAction] {
        if Self.oneFinger(state) {
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.previewing ? [.clearPreview] : []
            }
            let last: [MyceliumArchitectGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
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

    /// Starts a one-finger gesture: picks the touch-down point once and decides what the gesture is on; a site press
    /// previews its change.
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: MyceliumArchitectSceneSnapshot,
                                tool: MyceliumArchitectTool,
                                orbit: MyceliumArchitectViewOrbit) -> [MyceliumArchitectGestureAction] {
        var pick: MyceliumArchitectPickTarget = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = MyceliumArchitectPicker.pick(event.location, viewSize: viewSize, snapshot: snapshot, orbit: orbit)
        }
        let target: Target
        switch pick {
        case .gauge:
            target = .gauge
            state = .gaugePress
        case .sprout(let direction):
            target = .sprout(direction)
            state = .sproutPress
        case .root:
            target = .root
            state = .rootPress
        case .cell(let cell):
            let change: MyceliumArchitectAction? = Self.siteChange(cell, snapshot: snapshot, tool: tool)
            if let action = change, snapshot.stage == .playing {
                target = .site(action)
                state = .sitePress
            } else {
                target = .cell(cell, blocked: change != nil)
                state = .cellPress
            }
        case .empty:
            target = .nothing
            state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, orbit: orbit)
        var actions: [MyceliumArchitectGestureAction] = []
        if case .site(let action) = target {
            current.previewing = true
            current.previewed = action
            actions = [.preview(action)]
        }
        touch = current
        return actions
    }

    /// The change a press on `cell` makes with `tool` in `snapshot` (ignoring the stage): the tool's placement on an
    /// empty site, `.clear(cell)` on a placed nutrient or blocker; nil for any other cell.
    private static func siteChange(_ cell: MyceliumArchitectCell, snapshot: MyceliumArchitectSceneSnapshot,
                                   tool: MyceliumArchitectTool) -> MyceliumArchitectAction? {
        let level: MyceliumArchitectLevel = snapshot.level
        let arrangement: MyceliumArchitectArrangement = snapshot.arrangement
        if arrangement.nutrients.contains(cell) || arrangement.blockers.contains(cell) { return .clear(cell) }
        guard level.isSite(cell), level.isEmpty(cell, in: arrangement) else { return nil }
        switch tool {
        case .nutrient: return .nutrient(cell)
        case .blocker: return .blocker(cell)
        }
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing) in a view of `viewSize`: the travel
    /// grows to the farthest distance from the start; a press reaching ``dragDistance`` is decided once (see the file
    /// header); a scrub sends a changed pulse; when `previewing` (a move, not the release) a seed or unseed drag sends
    /// its preview.
    private mutating func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                                 previewing: Bool) -> [MyceliumArchitectGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        var actions: [MyceliumArchitectGestureAction] = []
        let starting: Bool = !touch.dragging && touch.travel >= Self.dragDistance
        if starting { touch.dragging = true }
        let s: MyceliumArchitectSceneSnapshot = touch.snapshot
        switch touch.target {
        case .gauge:
            guard touch.dragging else { return [] }
            if starting { state = .scrub }
            guard let pulse = pulse(location, touch: touch, viewSize: viewSize), pulse != touch.pulse else {
                return []
            }
            touch.pulse = pulse
            return [.showPulse(pulse)]
        case .site:
            guard starting, touch.previewing else { return [] }
            touch.previewing = false
            return [.clearPreview]
        case .root:
            if starting {
                guard s.stage == .playing else {
                    touch.blocked = true
                    return [.explain(Self.stageReason(s.stage))]
                }
                touch.startPlane = MyceliumArchitectPicker.cast(touch.start, viewSize: viewSize, orbit: touch.orbit)
                if touch.startPlane == nil { touch.blocked = true }
                if !touch.blocked { state = .seedDrag }
            }
            guard touch.dragging, !touch.blocked, previewing,
                  let direction = seedDirection(location, touch: touch, viewSize: viewSize) else { return actions }
            let change: MyceliumArchitectAction = .seed(direction)
            guard change != touch.previewed else { return actions }
            touch.previewed = change
            touch.previewing = true
            actions.append(.preview(change))
            return actions
        case .sprout(let direction):
            guard starting else { return [] }
            guard s.stage == .playing else {
                touch.blocked = true
                return [.explain(Self.stageReason(s.stage))]
            }
            state = .unseedDrag
            let change: MyceliumArchitectAction = .unseed(direction)
            touch.previewed = change
            guard previewing else { return [] }
            touch.previewing = true
            return [.preview(change)]
        case .cell, .nothing:
            return []
        }
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed) in a
    /// view of `viewSize`; `snapshot` is the releasing snapshot.
    /// Whether `point` picks the cell `change` acts on, with the touch-down snapshot and orbit (feature 514,
    /// FR-R02G2204-002, T-R02G2204-014): a site press lifted over a neighbouring cell sends nothing.
    private static func releasesOverSameCell(_ change: MyceliumArchitectAction, at point: Vec2, viewSize: Vec2,
                                             touch: Touch) -> Bool {
        let cell: MyceliumArchitectCell
        switch change {
        case .nutrient(let c), .blocker(let c), .clear(let c): cell = c
        default: return false
        }
        guard usable(viewSize), point.isFinite else { return false }
        let picked: MyceliumArchitectPickTarget = MyceliumArchitectPicker.pick(point, viewSize: viewSize,
                                                                               snapshot: touch.snapshot,
                                                                               orbit: touch.orbit)
        return picked == .cell(cell)
    }

    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  snapshot: MyceliumArchitectSceneSnapshot) -> [MyceliumArchitectGestureAction] {
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
            return [.resetView]
        }
        lastTap = nil
        let playing: Bool = snapshot.stage == .playing
        switch touch.target {
        case .gauge:
            guard !touch.dragging, let pulse = pulse(event.location, touch: touch, viewSize: viewSize) else {
                return []
            }
            return [.showPulse(pulse)]
        case .site(let change):
            guard !touch.dragging else { return [] }
            // FR-R02G2204-002 (T-R02G2204-014): sent only on release over the same cell, picked as at touch-down.
            guard Self.releasesOverSameCell(change, at: event.location, viewSize: viewSize, touch: touch) else {
                return [.clearPreview]
            }
            guard playing else { return [.clearPreview, .explain(Self.stageReason(snapshot.stage))] }
            guard let send = Self.send(change) else { return [.clearPreview] }
            return [send, .clearPreview]
        case .root:
            guard touch.dragging else { return tap ? [.explain(Self.rootReason)] : [] }
            guard !touch.blocked else { return [] }
            guard playing else { return [.clearPreview, .explain(Self.stageReason(snapshot.stage))] }
            guard let start = touch.startPlane,
                  let end = MyceliumArchitectPicker.cast(event.location, viewSize: viewSize, orbit: touch.orbit),
                  (end - start).length >= Self.seedTravel * touch.snapshot.fitScale,
                  let send = Self.send(.seed(MyceliumArchitectPicker.direction(from: start, to: end))) else {
                return [.clearPreview]
            }
            return [send, .clearPreview]
        case .sprout(let direction):
            guard touch.dragging else { return tap ? [.explain(Self.sproutReason)] : [] }
            guard !touch.blocked else { return [] }
            guard playing else { return [.clearPreview, .explain(Self.stageReason(snapshot.stage))] }
            guard Self.usable(viewSize), event.location.isFinite,
                  MyceliumArchitectPicker.hitsRoot(event.location, viewSize: viewSize, snapshot: touch.snapshot,
                                                   orbit: touch.orbit),
                  let send = Self.send(.unseed(direction)) else {
                return [.clearPreview]
            }
            return [send, .clearPreview]
        case .cell(let cell, let blocked):
            guard tap else { return [] }
            var actions: [MyceliumArchitectGestureAction] = [.inspect(touch.snapshot.inspectedCell == cell ? nil : cell)]
            if blocked { actions.append(.explain(Self.stageReason(touch.snapshot.stage))) }
            return actions
        case .nothing:
            return []
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

    /// Cancels any one-finger gesture for a second finger (sending only `clearPreview` when a preview was showing)
    /// and starts an orbit from the current midpoint.
    private mutating func secondFinger() -> [MyceliumArchitectGestureAction] {
        var actions: [MyceliumArchitectGestureAction] = []
        if let current = touch, current.previewing { actions = [.clearPreview] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// The pulse under `location` on the gauge (the cast x by the gauge formula of the touch-down snapshot's pulses
    /// run); nil for unusable input.
    private func pulse(_ location: Vec2, touch: Touch, viewSize: Vec2) -> Int? {
        guard Self.usable(viewSize), location.isFinite,
              let plane = MyceliumArchitectPicker.cast(location, viewSize: viewSize, orbit: touch.orbit) else {
            return nil
        }
        return MyceliumArchitectPicker.pulse(atPlaneX: plane.x, pulsesRun: touch.snapshot.pulsesRun)
    }

    /// The direction a seed drag of `touch` reads at `location`: the board-plane direction from the cast touch-down
    /// point to the cast finger; nil for unusable input.
    private func seedDirection(_ location: Vec2, touch: Touch, viewSize: Vec2) -> MyceliumArchitectDirection? {
        guard let start = touch.startPlane, Self.usable(viewSize), location.isFinite,
              let end = MyceliumArchitectPicker.cast(location, viewSize: viewSize, orbit: touch.orbit) else {
            return nil
        }
        return MyceliumArchitectPicker.direction(from: start, to: end)
    }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
