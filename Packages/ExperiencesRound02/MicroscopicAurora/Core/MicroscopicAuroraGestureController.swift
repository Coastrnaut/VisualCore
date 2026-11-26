// MicroscopicAuroraGestureController — feature 484 (R02-G19-04) T-R02G1904-003 (FR-R02G1904-001 … 005, 007, 008;
// SC-R02G1904-001 … 003). Turns pointer events into Microscopic Aurora gesture actions (place a well on a site, move a
// well to another site, remove it off the dish, show a tick, preview a drop, toggle the freeze, select a slot, reset the
// view, explain why a gesture does nothing) and camera orbits, host-testable without a screen. A small state machine
// ported from Apsides Workshop's gesture controller (feature 474), adapted to wells dragged between sites:
//
// - One finger goes down: the point is picked once with `MicroscopicAuroraPicker.pick(_:size:snapshot:orbit:)` at the
//   current view orbit and the view's size; the touch-down snapshot (its wells, sites, ticks and stage) is kept for the
//   whole gesture.
//   - `.site(i)`: a press on a site (state `sitePress`); `.well(slot)`: on a well (`wellPress`); `.field`: on the dish
//     field (`fieldPress`); `.empty`: on empty space (`emptyPress`), tracked for a double tap.
//   - `.scrubber`: the scrubber from touch-down on (state `scrubberPress`, `scrubDrag` once a tick changed), in any
//     stage: the tick t0 = `MicroscopicAuroraPicker.scrubTick(_:size:snapshot:orbit:)` under the finger is read at
//     touch-down (nothing sent), and every later move (the release point counting as a last move) sends
//     `[.showTick(t)]` whenever t differs from the tick last read. Never a kernel action.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag). A press on a well whose travel reaches 16 points becomes a drag (state
//   `wellDrag`); a drag from a site, the field or empty space does nothing.
// - Well drag, decided when the drag starts (by the move or the release that starts it):
//   - when the touch-down snapshot is not playing: `[.explain(finishedReason)]`, nothing else for the gesture;
//   - while playing: on every move from the one that starts the drag on, the drop target is
//     `MicroscopicAuroraPicker.dropTarget(_:slot:size:snapshot:orbit:)` at the finger on the touch-down snapshot at
//     the view orbit (nil: no change). Whenever it changes: a change sends `[.preview(slot:target:)]`; no change sends
//     `[.clearPreview]` (only when a preview was showing). A release never previews itself.
// - Release (`.ended`):
//   - a well drag while playing: the drop target read at the release point (the last one read for a non-finite
//     point); when the releasing snapshot is still playing and the target is a change, `[.move(slot:well:)]` (the
//     slot's well on the target site with the same strength and sense; `well.place`) or `[.remove(slot:)]`
//     (`well.remove`), one undo step each (the presenter drops its preview); else `[.clearPreview]`;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on an empty site:
//     while playing (touch-down and releasing snapshots), `[.place(slot:well:)]` in the first free slot with the
//     controller's ``strength`` and ``sense`` (`well.place`), or `[.explain(fullReason)]` with every slot used; outside
//     playing `[.explain(finishedReason)]`. A site another well holds is answered as a tap on that well;
//   - a tap on a well: `[.selectSlot(slot), .explain(wellReason)]` in any stage;
//   - a tap on the scrubber: `[.showTick(t)]` with the scrub tick t at the release point, in any stage — unless the
//     scrubber already showed a tick during this gesture (it then sent its ticks only);
//   - a tap on the field: `[.toggleFreeze]` in any stage;
//   - a tap on empty space: nothing; as the second tap of a double tap (the previous gesture a tap on empty space, its
//     `.ended` at most 0.35 s earlier and at most 22 points away), `[.resetView]` and the authored orbit. A completed
//     double tap starts no new one;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from a site, the field or
//     empty space: nothing. A scrub drag sends only its ticks.
// - Kernel actions (`place`, `move`, `remove`) are produced only while playing; `clock.show` in any stage. The kernel
//   still applies its own rules (the stage, the budget) to every action sent.
// - A second finger cancels any one-finger gesture — sending `[.clearPreview]` when a preview was showing, nothing
//   else — and the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the
//   fingers up raises the eye), clamped by `MicroscopicAuroraViewOrbit.clamped()`; a third finger re-bases the
//   midpoint. A finger lifting while others stay → `cancelled` until every finger has lifted. A `.cancelled` phase
//   sends no kernel action and no tick (only the same `[.clearPreview]` when a preview was showing). `cancel()` sends
//   nothing; the presenter clears its own preview when it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the view orbit, the ticks, the freeze and the
// preview never enter the digest or the kernel. The controller calls only the picker's contract
// (`MicroscopicAuroraPicker.pick`, `dropTarget`, `scrubTick`) and `MicroscopicAuroraSceneGeometry.camera(aspect:orbit:)`.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Microscopic Aurora gesture asks for (feature 484, R02-G19-04).
public enum MicroscopicAuroraGestureAction: Sendable, Equatable {
    /// Put `well` into the empty slot `slot`: `well.place [slot, row, column, strength, sense]` (one undo step); sent
    /// only while playing, for a tap on an empty site.
    case place(slot: Int, well: MicroscopicAuroraWell)
    /// Move slot `slot`'s well to `well` (another free site, the same strength and sense):
    /// `well.place [slot, row, column, strength, sense]` (one undo step); sent only while playing, on a drop.
    case move(slot: Int, well: MicroscopicAuroraWell)
    /// Empty slot `slot`: `well.remove [slot]` (one undo step); sent only while playing, for a drop off the dish.
    case remove(slot: Int)
    /// Show tick `tick` (0 … ticks swum) of the swim: `clock.show [tick]` (presentation only).
    case showTick(Int)
    /// The drop of slot `slot`'s well would be `target` (always a change): the presenter previews it
    /// (presentation only).
    case preview(slot: Int, target: MicroscopicAuroraPreviewTarget)
    /// The drop would change nothing (or the drag ended): the presenter drops its preview.
    case clearPreview
    /// Freeze or unfreeze the drawn swim (a tap on the dish field; presentation only).
    case toggleFreeze
    /// Select slot `slot` in the panel (a tap on its well; presentation only).
    case selectSlot(Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
    /// Why the gesture does nothing (a well tapped, every slot used, the play is over); shown in the description.
    case explain(String)
}

/// Turns pointer events into Microscopic Aurora gesture actions and camera orbits (feature 484), deterministic for the
/// same events. See the file header for the rules.
public struct MicroscopicAuroraGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on a site: a tap is still possible.
        case sitePress
        /// One finger went down on a well: a tap or a well drag is still possible.
        case wellPress
        /// A press on a well moved at least 16 points: a well drag.
        case wellDrag
        /// One finger went down on the scrubber: a tap or a scrub is possible.
        case scrubberPress
        /// A press on the scrubber changed the tick under the finger: the scrub.
        case scrubDrag
        /// One finger went down on the dish field: a tap toggles the freeze.
        case fieldPress
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

    /// The explanation of a gesture that would change the wells when the play is not playing (won or failed).
    public static let finishedReason: String = "The play is over: undo or go to the next level"
    /// The explanation of a tap on a well (in any stage).
    public static let wellReason: String = "Drag a well to another site, or off the dish to remove it"
    /// The explanation of a tap on an empty site while every slot holds a well.
    public static let fullReason: String = "Every well slot is used: drag a well off the dish to free one"

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``MicroscopicAuroraViewOrbit/authored`` at start.
    public private(set) var orbit: MicroscopicAuroraViewOrbit = .authored
    /// The strength of a well a tap places (the panel's, 1 … 4).
    public var strength: Int
    /// The turning sense of a well a tap places (the panel's).
    public var sense: MicroscopicAuroraSense

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
        /// The well of slot `slot`.
        case well(Int)
        /// The scrubber.
        case scrubber
        /// The dish field.
        case field
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
        let snapshot: MicroscopicAuroraSceneSnapshot
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether a press on a well became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The drop target a well drag last read (nil: no change).
        var drop: MicroscopicAuroraPreviewTarget?
        /// Whether a preview is showing (the last drop target sent was a change).
        var previewing: Bool
        /// The tick the scrubber last read.
        var tick: Int?
        /// Whether the scrubber showed a tick during the gesture.
        var scrubbed: Bool
    }

    /// Creates an idle controller at the authored orbit placing wells of `strength` (default 2, the panel's) turning by
    /// `sense` (default clockwise).
    public init(strength: Int = 2, sense: MicroscopicAuroraSense = .clockwise) {
        self.strength = strength
        self.sense = sense
    }

    /// The drawn camera for a view of `viewSize` points at the current orbit, or nil for a view that is not finite
    /// and positive.
    public func camera(viewSize: Vec2) -> MicroscopicAuroraCamera? {
        guard Self.usable(viewSize) else { return nil }
        return MicroscopicAuroraSceneGeometry.camera(aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one). Returns the
    /// actions the event produces (see the file header): ticks on scrub moves, previews and clearing values on
    /// well-drag moves, a clearing value on a cancel, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraGestureAction] {
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
                                snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil { return start(event, viewSize: viewSize, snapshot: snapshot) }
            return secondFinger()
        case .sitePress, .wellPress, .wellDrag, .scrubberPress, .scrubDrag, .fieldPress, .emptyPress:
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger moved: the one-finger gesture follows it, or the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [MicroscopicAuroraGestureAction] {
        switch state {
        case .idle, .sitePress, .wellPress, .wellDrag, .scrubberPress, .scrubDrag, .fieldPress, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            let actions: [MicroscopicAuroraGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
                                                                   previewing: true)
            touch = current
            return actions
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: MicroscopicAuroraViewOrbit =
                MicroscopicAuroraViewOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
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
                                snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraGestureAction] {
        switch state {
        case .idle, .sitePress, .wellPress, .wellDrag, .scrubberPress, .scrubDrag, .fieldPress, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return current.previewing ? [.clearPreview] : []
            }
            let last: [MicroscopicAuroraGestureAction] = follow(&current, to: event.location, viewSize: viewSize,
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
    /// scrubber reads the tick under it (nothing sent).
    private mutating func start(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraGestureAction] {
        var pick: MicroscopicAuroraPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = MicroscopicAuroraPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                                snapshot: snapshot, orbit: orbit)
        }
        let target: Target
        switch pick {
        case .site(let index):
            target = .site(index)
            state = .sitePress
        case .well(let slot):
            target = .well(slot)
            state = .wellPress
        case .scrubber:
            target = .scrubber
            state = .scrubberPress
        case .field:
            target = .field
            state = .fieldPress
        case .empty:
            target = .nothing
            state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, travel: 0, dragging: false, drop: nil, previewing: false,
                                   tick: nil, scrubbed: false)
        if target == .scrubber {
            current.tick = scrubTick(event.location, viewSize: viewSize, snapshot: snapshot)
        }
        touch = current
        return []
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing) in a view of `viewSize`: the
    /// scrubber sends a changed tick; the travel grows to the farthest distance from the start; a press on a well
    /// reaching ``dragDistance`` becomes a drag (explaining once outside playing); when `previewing` (a move, not the
    /// release) a well drag while playing sends a change of its drop target (a preview or a clearing value).
    private mutating func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                                 previewing: Bool) -> [MicroscopicAuroraGestureAction] {
        guard location.isFinite, touch.start.isFinite else { return [] }
        touch.travel = max(touch.travel, (location - touch.start).length)
        if touch.target == .scrubber {
            let tick: Int = scrubTick(location, viewSize: viewSize, snapshot: touch.snapshot)
            guard tick != touch.tick else { return [] }
            touch.tick = tick
            touch.scrubbed = true
            if state == .scrubberPress { state = .scrubDrag }
            return [.showTick(tick)]
        }
        guard case .well(let slot) = touch.target else { return [] }
        if !touch.dragging && touch.travel >= Self.dragDistance {
            touch.dragging = true
            if state == .wellPress { state = .wellDrag }
            if touch.snapshot.stage != .playing { return [.explain(Self.finishedReason)] }
        }
        guard previewing, Self.movingDrag(touch) else { return [] }
        let drop: MicroscopicAuroraPreviewTarget? = dropTarget(location, slot: slot, touch: touch, viewSize: viewSize)
        guard drop != touch.drop else { return [] }
        touch.drop = drop
        if let target = drop {
            touch.previewing = true
            return [.preview(slot: slot, target: target)]
        }
        guard touch.previewing else { return [] }
        touch.previewing = false
        return [.clearPreview]
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed) in a
    /// view of `viewSize`; `snapshot` is the releasing snapshot.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        switch touch.target {
        case .well(let slot):
            lastTap = nil
            if Self.movingDrag(touch) {
                var drop: MicroscopicAuroraPreviewTarget? = touch.drop
                if event.location.isFinite {
                    drop = dropTarget(event.location, slot: slot, touch: touch, viewSize: viewSize)
                }
                if let target = drop, snapshot.stage == .playing, touch.snapshot.wells.indices.contains(slot),
                   let well = touch.snapshot.wells[slot] {
                    switch target {
                    case .site(let cell):
                        return [.move(slot: slot, well: MicroscopicAuroraWell(cell: cell, strength: well.strength,
                                                                               sense: well.sense))]
                    case .removal:
                        return [.remove(slot: slot)]
                    }
                }
                return [.clearPreview]
            }
            return tap ? [.selectSlot(slot), .explain(Self.wellReason)] : []
        case .site(let index):
            lastTap = nil
            guard tap else { return [] }
            return siteTap(index, touch: touch, snapshot: snapshot)
        case .scrubber:
            lastTap = nil
            guard tap, !touch.scrubbed else { return [] }
            return [.showTick(scrubTick(event.location, viewSize: viewSize, snapshot: touch.snapshot))]
        case .field:
            lastTap = nil
            return tap ? [.toggleFreeze] : []
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

    /// The actions of a tap on site `index` of `touch`'s touch-down snapshot, released on `snapshot`: outside playing
    /// an explanation that the play is over; a site another well holds answers as a tap on that well; else a placement
    /// in the first free slot with ``strength`` and ``sense``, or an explanation that every slot is used.
    private func siteTap(_ index: Int, touch: Touch,
                         snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraGestureAction] {
        let s: MicroscopicAuroraSceneSnapshot = touch.snapshot
        guard s.sites.indices.contains(index) else { return [] }
        guard s.stage == .playing, snapshot.stage == .playing else { return [.explain(Self.finishedReason)] }
        let cell: MicroscopicAuroraCell = s.sites[index]
        var free: Int? = nil
        for slot in s.wells.indices {
            if let well = s.wells[slot] {
                if well.cell == cell { return [.selectSlot(slot), .explain(Self.wellReason)] }
            } else if free == nil {
                free = slot
            }
        }
        guard let slot = free else { return [.explain(Self.fullReason)] }
        return [.place(slot: slot, well: MicroscopicAuroraWell(cell: cell, strength: strength, sense: sense))]
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
    private mutating func secondFinger() -> [MicroscopicAuroraGestureAction] {
        var actions: [MicroscopicAuroraGestureAction] = []
        if let current = touch, current.previewing { actions = [.clearPreview] }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// Whether `touch` is a moving drag that previews and may move or remove: a drag of a well begun while the
    /// touch-down snapshot was playing.
    private static func movingDrag(_ touch: Touch) -> Bool {
        guard touch.dragging, case .well = touch.target else { return false }
        return touch.snapshot.stage == .playing
    }

    /// The drop target of slot `slot`'s well at `location` in a view of `viewSize` on `touch`'s touch-down snapshot at
    /// the view orbit (nil: no change).
    private func dropTarget(_ location: Vec2, slot: Int, touch: Touch,
                            viewSize: Vec2) -> MicroscopicAuroraPreviewTarget? {
        guard location.isFinite, Self.usable(viewSize) else { return nil }
        return MicroscopicAuroraPicker.dropTarget(Self.simd(location), slot: slot, size: Self.simd(viewSize),
                                                  snapshot: touch.snapshot, orbit: orbit)
    }

    /// The scrub tick 0 … ticks swum under `location` in a view of `viewSize` showing `snapshot` at the view orbit
    /// (the picker's fallback, the shown tick, for unusable input).
    private func scrubTick(_ location: Vec2, viewSize: Vec2, snapshot: MicroscopicAuroraSceneSnapshot) -> Int {
        MicroscopicAuroraPicker.scrubTick(Self.simd(location), size: Self.simd(viewSize), snapshot: snapshot,
                                          orbit: orbit)
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
