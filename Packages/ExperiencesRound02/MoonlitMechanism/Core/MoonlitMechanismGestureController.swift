// MoonlitMechanismGestureController — feature 434 (R02-G14-04) T-R02G1404-003 (FR-R02G1404-001 … 004, 006;
// SC-R02G1404-001 … 003; clarifications Q1 … Q5). Turns pointer events into Moonlit Mechanism gesture actions (choose
// a gear, preview and send handle turns, preview and send lamp steps, re-seat a gear, show a key frame, run the
// machine, reset the view) and camera orbits, host-testable without a screen. A small state machine in the pattern of
// Acoustic Constellator's gesture controller (feature 424):
//
// - One finger goes down: the point is picked once with `MoonlitMechanismPicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the touch-down snapshot (its gears, stage and actions left) is kept for the
//   whole gesture.
//   - `.gear(g)`: a press on gear g (state `gearPress`); the gear's projected centre
//     (`MoonlitMechanismPicker.gearCentre(_:size:snapshot:orbit:)`) is kept as the pivot of a gear drag.
//   - `.lamp` or `.ladder`: a press on the lamp or its ladder (state `lampPress`).
//   - `.card(k)`: a press on key-frame card k (state `cardPress`).
//   - `.empty`: a press on empty space (state `emptyPress`), tracked for a double tap.
// - The travel is the farthest distance of the finger from its touch-down point; the release point counts as a last
//   move (so a release can also start a drag), but a release never sends a pending preview itself.
// - Gear drag: from touch-down on, every finger point (the touch-down point, each move, the release) farther than
//   12 points (`centreDeadZone`) from the pivot updates the finger's angle about it
//   (`MoonlitMechanismPicker.angle(of:about:)`, clockwise on screen); each change of angle is unwrapped into −π … π and
//   added to the swept angle; points within 12 points are skipped, so the sweep never jumps through the centre. A
//   press on a gear whose travel reaches 16 points becomes a gear drag (state `gearDrag`). The pending turn in whole
//   teeth is n = round(swept ÷ (2π ÷ T)) (T the gear's teeth in the touch-down snapshot; rounded half away from zero),
//   its magnitude capped at the touch-down snapshot's actions left. When the touch-down snapshot is playing, every
//   move from the one that starts the drag on sends `[.pendingTurn(gear: g, teeth: n)]` (n signed: positive turns the
//   dragged gear clockwise on screen).
// - Lamp drag: a press on the lamp or the ladder whose travel reaches 16 points becomes a lamp drag (state
//   `lampDrag`); its rungs are round(−Δy ÷ 24) for the finger's vertical travel Δy from touch-down (view y grows
//   downward, so a finger moving up gives positive rungs; rounded half away from zero; `lampRungDistance`). When the
//   touch-down snapshot is playing, every move from the one that starts the drag on sends `[.pendingLamp(steps: r)]`.
// - Release (`.ended`):
//   - a gear drag whose touch-down snapshot is playing: `[.pendingTurn(gear: g, teeth: 0)]` (clears the pending
//     text), followed, when the releasing snapshot is playing and n ≠ 0, by `.turn(step: d × sign(n), count: |n|)`
//     with d = `MoonlitMechanismSceneGeometry.turnSense(g, snapshot)` (= `MoonlitMechanismTrain.direction`), so the
//     dragged gear turns the way the finger went; off playing at touch-down: nothing;
//   - a lamp drag whose touch-down snapshot is playing: `[.pendingLamp(steps: 0)]`, followed, when the releasing
//     snapshot is playing and r ≠ 0, by `.lampStep(step: sign(r), count: |r|)`; off playing at touch-down: nothing;
//   - a tap (travel under 10 points, lifted less than 0.5 s after touch-down by event timestamps) on gear g:
//     `[.chooseGear(g)]` in any stage; as the second tap of a double tap (the previous gesture a tap on the same gear,
//     its `.ended` at most 0.35 s earlier and at most 22 points away) while the releasing snapshot is playing:
//     `[.reseat(gear: g), .chooseGear(g)]`, except on the driver (gear 0), where only `[.chooseGear(0)]` is sent and
//     ``MoonlitMechanismGestureController/refusedDriverReseat`` turns true for that event (the presenter says the
//     driver cannot be re-seated); a completed double tap (in any stage) starts no new one;
//   - a tap on the lamp: `[.run]` while the releasing snapshot is playing, nothing otherwise; a tap on the ladder:
//     nothing;
//   - a tap on card k: `[.showFrame(k)]` in any stage (presentation: the adapter's `frame.show` never changes the
//     play);
//   - a tap on empty space: nothing; as the second tap of a double tap on empty space (same window and distance),
//     `[.resetView]` and the authored orbit;
//   - travel 10 … 16 points, a press lifted 0.5 s or later without moving 10 points, a drag from a card or empty
//     space: nothing.
// - Kernel actions (turn, lampStep, reseat, run) are produced only while playing; on every other stage (loading,
//   tutorial, paused, won, failed, result) only `chooseGear`, `showFrame` and `resetView` (and the clearing pending
//   values of a drag that began while playing).
// - A second finger cancels any one-finger gesture — a gear or lamp drag that began while playing sends its clearing
//   `pendingTurn(gear: g, teeth: 0)` or `pendingLamp(steps: 0)`, nothing else — and the fingers orbit (state
//   `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (moving the fingers up raises the eye), clamped
//   by `MoonlitMechanismOrbit.clamped()`; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends no kernel action (only the same clearing
//   pending value of a drag that began while playing). `cancel()` sends nothing; the presenter clears its own pending
//   text when it calls it.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit, the chosen gear and the pending turn and
// lamp steps never enter the digest, the snapshot's state or the kernel, which still applies its own rules (stage,
// the budget, the lamp range, the driver) to every action sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Moonlit Mechanism gesture asks for (feature 434).
public enum MoonlitMechanismGestureAction: Sendable, Equatable {
    /// Choose gear `index` as the panel's gear (presentation only, nothing sent to the kernel).
    case chooseGear(Int)
    /// The pending turn of a gear drag on gear `gear`: `teeth` whole teeth (positive turns the dragged gear clockwise
    /// on screen), |teeth| actions; 0 clears the pending text (presentation only).
    case pendingTurn(gear: Int, teeth: Int)
    /// Turn the handle `count` times by `step` (±1): `handle.turn [step]`, sent `count` times (each its own undo step).
    case turn(step: Int, count: Int)
    /// The pending lamp steps of a lamp drag (positive raises the lamp); 0 clears the pending text (presentation
    /// only).
    case pendingLamp(steps: Int)
    /// Step the lamp `count` times by `step` (±1): `lamp.step [step]`, sent `count` times.
    case lampStep(step: Int, count: Int)
    /// Re-seat gear `gear` one blade slot forward: `gear.reseat [gear, 1]`.
    case reseat(gear: Int)
    /// Show key frame `index`: `frame.show [index]` (presentation, never changes the play).
    case showFrame(Int)
    /// Run the machine through every key frame: `machine.run`.
    case run
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Moonlit Mechanism gesture actions and camera orbits (feature 434), deterministic for the
/// same events. See the file header for the rules.
public struct MoonlitMechanismGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No press, drag or orbit.
        case idle
        /// One finger went down on a gear: a tap, a double tap or a gear drag is still possible.
        case gearPress
        /// A press on a gear moved at least 16 points: a gear drag (rotary).
        case gearDrag
        /// One finger went down on the lamp or its ladder: a tap or a lamp drag is still possible.
        case lampPress
        /// A press on the lamp or its ladder moved at least 16 points: a lamp drag (vertical).
        case lampDrag
        /// One finger went down on a key-frame card: a tap shows its key frame.
        case cardPress
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
    /// Finger points at most this many view points from a dragged gear's projected centre do not update its angle, 12.
    public static let centreDeadZone: Double = 12
    /// The vertical finger travel in view points of one lamp rung, 24.
    public static let lampRungDistance: Double = 24
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``MoonlitMechanismOrbit/authored`` at start.
    public private(set) var orbit: MoonlitMechanismOrbit = .authored
    /// True right after the event that completed a double tap on the driver (gear 0) while playing, which re-seats
    /// nothing (the presenter says the driver cannot be re-seated); false after every other event.
    public private(set) var refusedDriverReseat: Bool = false

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
        /// Gear `index`.
        case gear(Int)
        /// The lamp.
        case lamp
        /// The lamp's ladder.
        case ladder
        /// Key-frame card `index`.
        case card(Int)
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
        /// The touch-down snapshot (gears, stage, actions left).
        let snapshot: MoonlitMechanismSceneSnapshot
        /// The projected centre of the touched gear (the drag's pivot), nil for other targets or a centre that does
        /// not project.
        let pivot: Vec2?
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// Whether the press became a drag (travel reached ``dragDistance``).
        var dragging: Bool
        /// The finger's last angle about the pivot outside the dead zone, nil before the first.
        var angle: Double?
        /// The clockwise angle swept about the pivot so far, radians.
        var swept: Double
        /// The finger's last location (for the lamp's vertical travel).
        var last: Vec2
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: MoonlitMechanismSceneSnapshot) -> MoonlitMechanismCamera? {
        guard Self.usable(viewSize) else { return nil }
        return MoonlitMechanismSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one: the gears, the
    /// stage and the actions left). Returns the actions the event produces (see the file header): pending previews on
    /// moves, clearing pending values on a cancel, everything else on release; `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: MoonlitMechanismSceneSnapshot) -> [MoonlitMechanismGestureAction] {
        refusedDriverReseat = false
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            return began(event, viewSize: viewSize, snapshot: snapshot)
        case .moved:
            return moved(event, viewSize: viewSize)
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

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel; the presenter clears
    /// its own pending text); the orbit is kept, and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        orbitMidpoint = nil
        lastTap = nil
        refusedDriverReseat = false
        state = .idle
    }

    // MARK: Phases

    /// A finger went down: a first finger starts a one-finger gesture, a second cancels it (clearing a pending
    /// preview) and orbits, a third re-bases the orbit's midpoint.
    private mutating func began(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: MoonlitMechanismSceneSnapshot) -> [MoonlitMechanismGestureAction] {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot)
                return []
            }
            return secondFinger()
        case .gearPress, .gearDrag, .lampPress, .lampDrag, .cardPress, .emptyPress:
            return secondFinger()
        case .orbiting:
            orbitMidpoint = tracker.centroid
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger moved: the one-finger gesture follows it (perhaps becoming a drag and sending its pending preview), or
    /// the orbit follows the fingers' midpoint.
    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) -> [MoonlitMechanismGestureAction] {
        switch state {
        case .idle, .gearPress, .gearDrag, .lampPress, .lampDrag, .cardPress, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            follow(&current, to: event.location)
            touch = current
            guard current.dragging, current.snapshot.stage == .playing else { return [] }
            switch current.target {
            case .gear(let gear):
                return [.pendingTurn(gear: gear, teeth: Self.teeth(current))]
            case .lamp, .ladder:
                return [.pendingLamp(steps: Self.rungs(current))]
            case .card, .nothing:
                return []
            }
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return [] }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return [] }
            let delta: Vec2 = midpoint - last
            let turned: MoonlitMechanismOrbit =
                MoonlitMechanismOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                      pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
            return []
        case .cancelled:
            return []
        }
    }

    /// A finger lifted (or was cancelled): the one-finger gesture is released, an orbit ends or a cancelled gesture
    /// waits for the last finger.
    private mutating func ended(_ event: PointerEvent, cancelled: Bool,
                                snapshot: MoonlitMechanismSceneSnapshot) -> [MoonlitMechanismGestureAction] {
        switch state {
        case .idle, .gearPress, .gearDrag, .lampPress, .lampDrag, .cardPress, .emptyPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return Self.clearing(current)
            }
            follow(&current, to: event.location)
            return release(current, at: event, playing: snapshot.stage == .playing)
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
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: MoonlitMechanismSceneSnapshot) {
        var pick: MoonlitMechanismPick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = MoonlitMechanismPicker.pick(Self.simd(event.location), size: Self.simd(viewSize),
                                               snapshot: snapshot, orbit: orbit)
        }
        var target: Target = .nothing
        var pivot: Vec2? = nil
        switch pick {
        case .gear(let index):
            if index >= 0, index < snapshot.gears.count {
                target = .gear(index)
                if let c = MoonlitMechanismPicker.gearCentre(index, size: Self.simd(viewSize), snapshot: snapshot,
                                                             orbit: orbit) {
                    pivot = Vec2(c.x, c.y)
                }
            }
        case .lamp:
            target = .lamp
        case .ladder:
            target = .ladder
        case .card(let index):
            if index >= 0, index < snapshot.keyFrames.count { target = .card(index) }
        case .empty:
            target = .nothing
        }
        switch target {
        case .gear: state = .gearPress
        case .lamp, .ladder: state = .lampPress
        case .card: state = .cardPress
        case .nothing: state = .emptyPress
        }
        var current: Touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, target: target,
                                   snapshot: snapshot, pivot: pivot, travel: 0, dragging: false, angle: nil,
                                   swept: 0, last: event.location)
        Self.sweep(&current, to: event.location)
        touch = current
    }

    /// Moves `touch`'s finger to `location` (a non-finite location changes nothing): its travel grows to the farthest
    /// distance from the start, a gear press sweeps its angle, and a press on a gear, the lamp or the ladder reaching
    /// ``dragDistance`` becomes a drag.
    private mutating func follow(_ touch: inout Touch, to location: Vec2) {
        guard location.isFinite, touch.start.isFinite else { return }
        touch.travel = max(touch.travel, (location - touch.start).length)
        touch.last = location
        Self.sweep(&touch, to: location)
        guard !touch.dragging, touch.travel >= Self.dragDistance else { return }
        switch touch.target {
        case .gear:
            touch.dragging = true
            if state == .gearPress { state = .gearDrag }
        case .lamp, .ladder:
            touch.dragging = true
            if state == .lampPress { state = .lampDrag }
        case .card, .nothing:
            break
        }
    }

    /// The release actions of the one-finger gesture `touch` lifted by `event` (its last move already followed);
    /// `playing` tells whether the releasing snapshot is playing.
    private mutating func release(_ touch: Touch, at event: PointerEvent,
                                  playing: Bool) -> [MoonlitMechanismGestureAction] {
        let tap: Bool = isTap(touch, at: event)
        switch touch.target {
        case .gear(let gear):
            if touch.dragging {
                lastTap = nil
                guard touch.snapshot.stage == .playing else { return [] }
                var actions: [MoonlitMechanismGestureAction] = [.pendingTurn(gear: gear, teeth: 0)]
                let n: Int = Self.teeth(touch)
                if playing && n != 0 {
                    let sense: Int = MoonlitMechanismSceneGeometry.turnSense(gear, touch.snapshot)
                    actions.append(.turn(step: sense * (n > 0 ? 1 : -1), count: abs(n)))
                }
                return actions
            }
            guard tap else {
                lastTap = nil
                return []
            }
            guard secondTap(of: .gear(gear), at: event) else {
                lastTap = (.gear(gear), event.location, event.timestamp)
                return [.chooseGear(gear)]
            }
            lastTap = nil
            guard playing else { return [.chooseGear(gear)] }
            guard gear != 0 else {
                refusedDriverReseat = true
                return [.chooseGear(gear)]
            }
            return [.reseat(gear: gear), .chooseGear(gear)]
        case .lamp, .ladder:
            lastTap = nil
            if touch.dragging {
                guard touch.snapshot.stage == .playing else { return [] }
                var actions: [MoonlitMechanismGestureAction] = [.pendingLamp(steps: 0)]
                let r: Int = Self.rungs(touch)
                if playing && r != 0 { actions.append(.lampStep(step: r > 0 ? 1 : -1, count: abs(r))) }
                return actions
            }
            guard tap, touch.target == .lamp, playing else { return [] }
            return [.run]
        case .card(let index):
            lastTap = nil
            guard tap else { return [] }
            return [.showFrame(index)]
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

    /// Cancels any one-finger gesture for a second finger (sending only the clearing pending value of a drag that
    /// began while playing) and starts an orbit from the current midpoint.
    private mutating func secondFinger() -> [MoonlitMechanismGestureAction] {
        var actions: [MoonlitMechanismGestureAction] = []
        if let current = touch { actions = Self.clearing(current) }
        touch = nil
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
        return actions
    }

    // MARK: Helpers

    /// The clearing pending value of a cancelled `touch`: `pendingTurn(gear: g, teeth: 0)` or `pendingLamp(steps: 0)`
    /// for a gear or lamp drag that began while playing (its pending preview was shown); nothing otherwise.
    private static func clearing(_ touch: Touch) -> [MoonlitMechanismGestureAction] {
        guard touch.dragging, touch.snapshot.stage == .playing else { return [] }
        switch touch.target {
        case .gear(let gear): return [.pendingTurn(gear: gear, teeth: 0)]
        case .lamp, .ladder: return [.pendingLamp(steps: 0)]
        case .card, .nothing: return []
        }
    }

    /// Adds the finger at `location` to a gear touch's swept angle: skipped within ``centreDeadZone`` of the pivot (or
    /// without a pivot); otherwise the change of angle since the last counted point, unwrapped into −π … π.
    private static func sweep(_ touch: inout Touch, to location: Vec2) {
        guard case .gear = touch.target, let pivot = touch.pivot, location.isFinite,
              (location - pivot).length > centreDeadZone else { return }
        let a: Double = MoonlitMechanismPicker.angle(of: simd(location), about: simd(pivot))
        if let previous = touch.angle { touch.swept += unwrapped(a - previous) }
        touch.angle = a
    }

    /// `delta` brought into −π … π by whole turns.
    static func unwrapped(_ delta: Double) -> Double {
        var d: Double = delta.remainder(dividingBy: 2 * Double.pi)
        if d < -Double.pi { d += 2 * Double.pi }
        if d > Double.pi { d -= 2 * Double.pi }
        return d
    }

    /// The pending teeth of a gear touch: round(swept ÷ (2π ÷ T)), its magnitude capped at the touch-down snapshot's
    /// actions left (0 for a gear outside the snapshot).
    private static func teeth(_ touch: Touch) -> Int {
        guard case .gear(let gear) = touch.target, gear < touch.snapshot.gears.count else { return 0 }
        let count: Int = max(touch.snapshot.gears[gear].teeth, 1)
        let raw: Double = (touch.swept / (2 * Double.pi / Double(count))).rounded()
        guard raw.isFinite else { return 0 }
        let cap: Int = max(touch.snapshot.actionsLeft, 0)
        return Int(min(max(raw, -Double(cap)), Double(cap)))
    }

    /// The pending rungs of a lamp touch: round(−Δy ÷ ``lampRungDistance``) for the finger's vertical travel Δy
    /// (bounded by ±1 000 000 so a far-off point cannot overflow).
    private static func rungs(_ touch: Touch) -> Int {
        let raw: Double = (-(touch.last.y - touch.start.y) / lampRungDistance).rounded()
        guard raw.isFinite else { return 0 }
        return Int(min(max(raw, -1_000_000), 1_000_000))
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
