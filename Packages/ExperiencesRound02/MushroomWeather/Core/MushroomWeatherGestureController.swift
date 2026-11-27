// MushroomWeatherGestureController — feature 494 (R02-G20-04) T-R02G2004-003 (FR-R02G2004-001 … 006, 008, 009;
// SC-R02G2004-001 … 003; clarifications Q1–Q5). Turns pointer events into Mushroom Weather gesture actions (place a pod
// on a site, move a pod to another site, remove it off the floor, open or shut a vent, set the moonlight, show a cycle,
// preview a drag, select a slot, reset the view, explain why a gesture does nothing) and camera orbits, host-testable
// without a screen. A small state machine ported from Microscopic Aurora's gesture controller (feature 484), adapted to
// pods dragged between sites, vents tapped and the moon dragged up or down:
//
// - One finger goes down: the point is picked once with `MushroomWeatherPicker.pick(_:size:snapshot:orbit:)` at the
//   current view orbit and the view's size; the touch-down snapshot (its pods, sites, vents, moonlight, cycles and
//   stage) is kept for the whole gesture.
//   - `.site(i)`: a press on a site (state `sitePress`); `.pod(slot)`: on a pod (`podPress`); `.vent(i)`: on a vent
//     (`ventPress`); `.moon`: on the moon (`moonPress`); `.floor`: on the floor (`floorPress`); `.empty`: on empty
//     space (`emptyPress`), tracked for a double tap.
//   - `.scrubber`: the scrubber from touch-down on (state `scrubberPress`, `scrubDrag` once a cycle changed), in any
//     stage: the cycle c0 = `MushroomWeatherPicker.scrubCycle(_:size:snapshot:orbit:)` under the finger is read at
//     touch-down (nothing sent), and every later move (the release point counting as a last move) sends
//     `[.showCycle(c)]` whenever c differs from the cycle last read. Never a kernel action.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag). A press on a pod or on the moon whose travel reaches 16 points becomes a
//   drag (state `podDrag` or `moonDrag`); a drag from a site, a vent, the floor or empty space does nothing.
// - Pod and moon drags, decided when the drag starts (by the move or the release that starts it):
//   - when the touch-down snapshot is not playing: `[.explain(finishedReason)]`, nothing else for the gesture;
//   - while playing, on every move from the one that starts the drag on, the drag's target is read: for a pod drag
//     `MushroomWeatherPicker.dropTarget(_:slot:size:snapshot:orbit:)` at the finger on the touch-down snapshot at the
//     view orbit (nil: no change); for a moon drag the level ℓ = `MushroomWeatherPicker.moonLevel(start:travel:)` of
//     the touch-down moonlight and the vertical travel (finger y − touch-down y; up raises), `.moonlight(level: ℓ)`
//     when ℓ differs from the touch-down moonlight, else nil. Whenever it changes: a change sends `[.preview(kind)]`;
//     no change sends `[.clearPreview]` (only when a preview was showing). A release never previews itself.
// - Release (`.ended`):
//   - a pod drag while playing: the drop target read at the release point (the last one read for a non-finite point);
//     when the releasing snapshot is still playing and the target is a change, `[.move(slot:cell:)]` (`pod.place
//     [slot, row, column]`) or `[.remove(slot:)]` (`pod.remove [slot]`), one undo step each (the presenter drops its
//     preview); else `[.clearPreview]`;
//   - a moon drag while playing: the level read at the release point (the last one read for a non-finite point); when
//     the releasing snapshot is still playing and it differs from the touch-down moonlight, `[.setMoonlight(ℓ)]`
//     (`moon.set [level]`, one undo step); else `[.clearPreview]`;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on an empty site:
//     while playing (touch-down and releasing snapshots), `[.place(slot:cell:)]` in the first free slot
//     (`pod.place [slot, row, column]`), or `[.explain(fullReason)]` with every slot used; outside playing
//     `[.explain(finishedReason)]`. A site another pod holds is answered as a tap on that pod;
//   - a tap on a pod: `[.selectSlot(slot), .explain(podReason)]` in any stage;
//   - a tap on a vent: while playing (touch-down and releasing snapshots), `[.setVent(index:open:)]` with the other
//     state (`vent.set [index, open]`); outside playing `[.explain(finishedReason)]`;
//   - a tap on the moon: `[.explain(moonReason)]` in any stage;
//   - a tap on the scrubber: `[.showCycle(c)]` with the scrub cycle c at the release point, in any stage — unless the
//     scrubber already showed a cycle during this gesture (it then sent its cycles only);
//   - a tap on the floor: nothing (it breaks a double tap);
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture a tap on empty space, its
//     `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit. A completed
//     double tap starts no new one;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from a site, a vent, the
//     floor or empty space: nothing. A scrub drag sends only its cycles.
// - Kernel actions (`place`, `move`, `remove`, `setVent`, `setMoonlight`) are produced only while playing;
//   `clock.show` in any stage. The kernel still applies its own rules (the stage, the budget) to every action sent.
// - A second finger cancels any one-finger gesture — sending `[.clearPreview]` when a preview was showing, nothing
//   else — and the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the
//   fingers right carries the eye towards +x, moving them up raises the eye), clamped by
//   `MushroomWeatherViewOrbit.clamped()`; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends no kernel action and no cycle (only the same
//   `[.clearPreview]` when a preview was showing). `cancel()` sends nothing; the presenter clears its own preview when
//   it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the view orbit, the shown cycle and the preview
// never enter the digest or the kernel. The controller calls only the picker's contract (`MushroomWeatherPicker.pick`,
// `dropTarget`, `moonLevel`, `scrubCycle`) and `MushroomWeatherSceneGeometry.camera(aspect:orbit:)`.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Mushroom Weather gesture asks for (feature 494, R02-G20-04).
public enum MushroomWeatherGestureAction: Sendable, Equatable {
    /// Put slot `slot`'s pod (an empty slot) on site `cell`: `pod.place [slot, row, column]` (one undo step); sent only
    /// while playing, for a tap on an empty site.
    case place(slot: Int, cell: MushroomWeatherCell)
    /// Move slot `slot`'s pod to site `cell` (another free site): `pod.place [slot, row, column]` (one undo step); sent
    /// only while playing, on a drop.
    case move(slot: Int, cell: MushroomWeatherCell)
    /// Empty slot `slot`: `pod.remove [slot]` (one undo step); sent only while playing, for a drop off the floor.
    case remove(slot: Int)
    /// Set vent `index` open or shut: `vent.set [index, open ? 1 : 0]` (one undo step); sent only while playing, for a
    /// tap on the vent (always the other state).
    case setVent(index: Int, open: Bool)
    /// Set the moonlight to `level` (0 … 3, never the current one): `moon.set [level]` (one undo step); sent only while
    /// playing, on the release of a moon drag.
    case setMoonlight(Int)
    /// Show cycle `cycle` (0 … cycles run) of the predicted run: `clock.show [cycle]` (presentation only).
    case showCycle(Int)
    /// The drag would change `kind` (always a change): the presenter previews it (presentation only).
    case preview(MushroomWeatherPreviewKind)
    /// The drag would change nothing (or ended): the presenter drops its preview.
    case clearPreview
    /// Select slot `slot` in the panel (a tap on its pod; presentation only).
    case selectSlot(Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
    /// Why the gesture does nothing (a pod or the moon tapped, every slot used, the play is over); shown in the
    /// description.
    case explain(String)
}

/// Turns pointer events into Mushroom Weather gesture actions and camera orbits (feature 494), deterministic for the
/// same events. See the file header for the rules.
public struct MushroomWeatherGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on a site: a tap is still possible.
        case sitePress
        /// One finger went down on a pod: a tap or a pod drag is still possible.
        case podPress
        /// A press on a pod moved at least 16 points: a pod drag.
        case podDrag
        /// One finger went down on a vent: a tap toggles it.
        case ventPress
        /// One finger went down on the moon: a tap explains, a drag changes the moonlight.
        case moonPress
        /// A press on the moon moved at least 16 points: a moon drag.
        case moonDrag
        /// One finger went down on the scrubber: a tap or a scrub is possible.
        case scrubberPress
        /// A press on the scrubber changed the cycle under the finger: the scrub.
        case scrubDrag
        /// One finger went down on the floor: nothing responds.
        case floorPress
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

    /// The explanation of a gesture that would change the forest when the play is not playing (won or failed).
    public static let finishedReason: String = "The play is over: undo or go to the next level"
    /// The explanation of a tap on a pod (in any stage).
    public static let podReason: String = "Drag a pod to another site, or off the floor to remove it"
    /// The explanation of a tap on an empty site while every slot holds a pod.
    public static let fullReason: String = "Every pod slot is used: drag a pod off the floor to free one"
    /// The explanation of a tap on the moon (in any stage).
    public static let moonReason: String = "Drag the moon up or down to change the moonlight"

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``MushroomWeatherViewOrbit/authored`` at start.
    public private(set) var orbit: MushroomWeatherViewOrbit = .authored

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
        /// Site `index` of the touch-down snapshot.
        case site(Int)
        /// The pod of slot `slot`.
        case pod(Int)
        /// Vent `index`.
        case vent(Int)
        /// The moon.
        case moon
        /// The scrubber.
        case scrubber
        /// The floor.
        case floor
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
        let snapshot: MushroomWeatherSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether a press on a pod or the moon became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The change a pod or moon drag last read (nil: no change).
        var change: MushroomWeatherPreviewKind?
        /// Whether a preview is showing (the last change sent was a change).
        var previewing: Bool
        /// The cycle the scrubber last read.
        var cycle: Int?
        /// Whether the scrubber showed a cycle during the gesture.
        var scrubbed: Bool
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points at the current orbit, or nil for a view that is not finite
    /// and positive.
    public func camera(viewSize: Vec2) -> MushroomWeatherCamera? {
        guard Self.usable(viewSize) else { return nil }
        return MushroomWeatherSceneGeometry.camera(aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one). Returns the
    /// actions the event produces (see the file header): cycles on scrub moves, previews and clearing values on pod
    /// and moon drag moves, a clearing value on a cancel, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
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
                                snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil { return start(event, viewSize: viewSize, snapshot: snapshot) }
            return secondFinger()
        case .sitePress, .podPress, .podDrag, .ventPress, .moonPress, .moonDrag, .scrubberPress, .scrubDrag,
             .floorPress, .emptyPress:
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger moved: the one-finger gesture follows it, or the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [MushroomWeatherGestureAction] {
        switch state {
        case .idle, .sitePress, .podPress, .podDrag, .ventPress, .moonPress, .moonDrag, .scrubberPress, .scrubDrag,
             .floorPress, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [MushroomWeatherGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                                 previewing: true)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: MushroomWeatherViewOrbit =
                MushroomWeatherViewOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
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
                                snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
        switch state {
        case .idle, .sitePress, .podPress, .podDrag, .ventPress, .moonPress, .moonDrag, .scrubberPress, .scrubDrag,
             .floorPress, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.previewing ? [.clearPreview] : []
            }
            let last: [MushroomWeatherGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
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
    /// scrubber reads the cycle under it (nothing sent).
    private mutating func start(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
        var pick: MushroomWeatherPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = MushroomWeatherPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                              snapshot: snapshot, orbit: orbit)
        }
        let target: Target
        switch pick {
        case .site(let index):
            target = .site(index)
            state = .sitePress
        case .pod(let slot):
            target = .pod(slot)
            state = .podPress
        case .vent(let index):
            target = .vent(index)
            state = .ventPress
        case .moon:
            target = .moon
            state = .moonPress
        case .scrubber:
            target = .scrubber
            state = .scrubberPress
        case .floor:
            target = .floor
            state = .floorPress
        case .empty:
            target = .nothing
            state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, travel: 0, dragging: false, change: nil, previewing: false,
                                   cycle: nil, scrubbed: false)
        if target == .scrubber {
            current.cycle = scrubCycle(event.location, viewSize: viewSize, snapshot: snapshot)
        }
        touch = current
        return []
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing) in a view of `viewSize`: the
    /// scrubber sends a changed cycle; the travel grows to the farthest distance from the start; a press on a pod or
    /// the moon reaching ``dragDistance`` becomes a drag (explaining once outside playing); when `previewing` (a move,
    /// not the release) a pod or moon drag while playing sends a change of its target (a preview or a clearing value).
    private mutating func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                                 previewing: Bool) -> [MushroomWeatherGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        if touch.target == .scrubber {
            let cycle: Int = scrubCycle(location, viewSize: viewSize, snapshot: touch.snapshot)
            guard cycle != touch.cycle else { return [] }
            touch.cycle = cycle
            touch.scrubbed = true
            if state == .scrubberPress { state = .scrubDrag }
            return [.showCycle(cycle)]
        }
        guard Self.draggable(touch.target) else { return [] }
        if !touch.dragging && touch.travel >= Self.dragDistance {
            touch.dragging = true
            if state == .podPress { state = .podDrag }
            if state == .moonPress { state = .moonDrag }
            if touch.snapshot.stage != .playing { return [.explain(Self.finishedReason)] }
        }
        guard previewing, Self.movingDrag(touch) else { return [] }
        let change: MushroomWeatherPreviewKind? = self.change(location, touch: touch, viewSize: viewSize)
        guard change != touch.change else { return [] }
        touch.change = change
        if let kind = change {
            touch.previewing = true
            return [.preview(kind)]
        }
        guard touch.previewing else { return [] }
        touch.previewing = false
        return [.clearPreview]
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed) in a
    /// view of `viewSize`; `snapshot` is the releasing snapshot.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        switch touch.target {
        case .pod(let slot):
            lastTap = nil
            if Self.movingDrag(touch) {
                return commit(touch, at: event, viewSize: viewSize, snapshot: snapshot)
            }
            return tap ? [.selectSlot(slot), .explain(Self.podReason)] : []
        case .moon:
            lastTap = nil
            if Self.movingDrag(touch) {
                return commit(touch, at: event, viewSize: viewSize, snapshot: snapshot)
            }
            return tap ? [.explain(Self.moonReason)] : []
        case .site(let index):
            lastTap = nil
            guard tap else { return [] }
            return siteTap(index, touch: touch, snapshot: snapshot)
        case .vent(let index):
            lastTap = nil
            guard tap else { return [] }
            return ventTap(index, touch: touch, snapshot: snapshot)
        case .scrubber:
            lastTap = nil
            guard tap, !touch.scrubbed else { return [] }
            return [.showCycle(scrubCycle(event.location, viewSize: viewSize, snapshot: touch.snapshot))]
        case .floor:
            lastTap = nil
            return []
        case .nothing:
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
    }

    /// The release of a pod or moon drag begun while playing: the change read at the release point (the last one read
    /// for a non-finite point); when the releasing `snapshot` is still playing and it is a change, one move, removal or
    /// moonlight change; else a clearing value.
    private func commit(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                        snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
        var change: MushroomWeatherPreviewKind? = touch.change
        if event.location.isFinite { change = self.change(event.location, touch: touch, viewSize: viewSize) }
        guard snapshot.stage == .playing, let kind = change else { return [.clearPreview] }
        switch kind {
        case let .pod(slot, target):
            guard touch.snapshot.pods.indices.contains(slot), touch.snapshot.pods[slot] != nil else {
                return [.clearPreview]
            }
            if let cell = target { return [.move(slot: slot, cell: cell)] }
            return [.remove(slot: slot)]
        case .moonlight(let level):
            return [.setMoonlight(level)]
        }
    }

    /// The actions of a tap on site `index` of `touch`'s touch-down snapshot, released on `snapshot`: outside playing
    /// an explanation that the play is over; a site another pod holds answers as a tap on that pod; else a placement
    /// in the first free slot, or an explanation that every slot is used.
    private func siteTap(_ index: Int, touch: Touch,
                         snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
        let s: MushroomWeatherSceneSnapshot = touch.snapshot
        guard s.sites.indices.contains(index) else { return [] }
        guard s.stage == .playing, snapshot.stage == .playing else { return [.explain(Self.finishedReason)] }
        let cell: MushroomWeatherCell = s.sites[index]
        var free: Int? = nil
        for slot in s.pods.indices {
            if let pod = s.pods[slot] {
                if pod == cell { return [.selectSlot(slot), .explain(Self.podReason)] }
            } else if free == nil {
                free = slot
            }
        }
        guard let slot = free else { return [.explain(Self.fullReason)] }
        return [.place(slot: slot, cell: cell)]
    }

    /// The actions of a tap on vent `index` of `touch`'s touch-down snapshot, released on `snapshot`: outside playing
    /// an explanation that the play is over; else the vent set to its other state.
    private func ventTap(_ index: Int, touch: Touch,
                         snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherGestureAction] {
        let s: MushroomWeatherSceneSnapshot = touch.snapshot
        guard s.ventsOpen.indices.contains(index) else { return [] }
        guard s.stage == .playing, snapshot.stage == .playing else { return [.explain(Self.finishedReason)] }
        return [.setVent(index: index, open: !s.ventsOpen[index])]
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
    private mutating func secondFinger() -> [MushroomWeatherGestureAction] {
        var actions: [MushroomWeatherGestureAction] = []
        if let current = touch, current.previewing { actions = [.clearPreview] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// Whether a press on `target` can become a drag that previews: a pod or the moon.
    private static func draggable(_ target: Target) -> Bool {
        switch target {
        case .pod, .moon: return true
        default: return false
        }
    }

    /// Whether `touch` is a moving drag that previews and may commit: a drag of a pod or the moon begun while the
    /// touch-down snapshot was playing.
    private static func movingDrag(_ touch: Touch) -> Bool {
        guard touch.dragging, draggable(touch.target) else { return false }
        return touch.snapshot.stage == .playing
    }

    /// The change a pod or moon drag of `touch` reads at `location` in a view of `viewSize` (nil: no change): a pod's
    /// drop target on the touch-down snapshot at the view orbit; the moon's level of the vertical travel when it
    /// differs from the touch-down moonlight.
    private func change(_ location: Vec2, touch: Touch, viewSize: Vec2) -> MushroomWeatherPreviewKind? {
        guard location.isFinite else { return nil }
        switch touch.target {
        case .pod(let slot):
            guard Self.usable(viewSize) else { return nil }
            return MushroomWeatherPicker.dropTarget(Self.simd(location), slot: slot, size: Self.simd(viewSize),
                                                    snapshot: touch.snapshot, orbit: orbit)
        case .moon:
            let current: Int = touch.snapshot.moonlight
            let level: Int = MushroomWeatherPicker.moonLevel(start: current, travel: location.y - touch.start.y)
            return level == current ? nil : .moonlight(level: level)
        default:
            return nil
        }
    }

    /// The scrub cycle 0 … cycles run under `location` in a view of `viewSize` showing `snapshot` at the view orbit
    /// (the picker's fallback, the shown cycle, for unusable input).
    private func scrubCycle(_ location: Vec2, viewSize: Vec2, snapshot: MushroomWeatherSceneSnapshot) -> Int {
        MushroomWeatherPicker.scrubCycle(Self.simd(location), size: Self.simd(viewSize), snapshot: snapshot,
                                         orbit: orbit)
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
