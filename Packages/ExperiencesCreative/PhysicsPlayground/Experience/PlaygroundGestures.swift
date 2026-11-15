// PlaygroundGestures — feature 084 (A11-P03) T-A11-303 (FR-A11-303; SC-A11-301; clarification 2; research D4; edge
// cases "Tap where a body already is", "Two fingers or a cancelled gesture", "A drag outside the stage"). The canvas
// gestures of Physics Playground as a pure value type over VisualCore's shared `GestureArbiter` (VisualCoreScenes), so
// they are host-testable with synthetic pointer events. Four one-finger declarations, by priority:
//   delete   double tap (`DoubleTapRecognizer`: second touch-down within 0.3 s and 30 points of the first tap) — 4;
//   pin      long press (`LongPressRecognizer`: held ≥ 0.5 s within 10 points) — 3;
//   grab     drag (`DragRecognizer`: begins after 10 points of movement) — 2;
//   tap      tap (`TapRecognizer`: lifted within 10 points and 0.3 s) — 1.
// View points (top-left origin, y down) map to stage metres (y up) through the presenter's letterbox mapping: the
// 12 × 10 m view (the 10 × 8 m stage and a 1 m wall on each side) centred in the canvas at s = min(width / 12,
// height / 10) points per metre. A body is hit when the point lies inside its shape at its pose (inside the circle, or
// inside the rotated box); the topmost (last drawn) body wins. The actions, sent through the caller's `send`:
//   - double tap on a body → `edit.delete [id]` (on the empty stage, nothing);
//   - long press on a body → `edit.pin [id]` (a toggle; on the empty stage, nothing);
//   - drag that starts on a dynamic, unpinned body → `edit.grab [id, x, y]` at the touch-down point (clamped into the
//     stage), then `edit.move [x, y]` to the finger (clamped into the stage) right away and on every later move of
//     the held finger, then `edit.release` when the finger lifts, the touch is cancelled or a second finger lands; a
//     drag that starts elsewhere, or whose grab is refused, sends nothing more;
//   - tap on a body → `edit.select [id]`; tap on the empty stage → `edit.add [x, y, kind]` with the shape picker's
//     kind; a tap outside the stage → nothing. A tap is held back until the double-tap window (0.3 s after its lift)
//     has closed — checked on later events and on `advance(by:world:send:)`, which the presenter calls every frame —
//     so a double tap deletes without first selecting; any other gesture that starts sends a held tap first.
// The declarations use one pointer, so the arbiter ignores a second finger; this type counts fingers itself: a second
// finger ends a grab (`edit.release` once) and nothing more is sent until every finger has lifted. A first finger that
// lands while the world holds a grab no finger owns (a restored world) releases it first. `reset()` forgets every
// touch (suspension and teardown). The type never changes the world; it only sends actions.
import Foundation
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Physics Playground: tap, double tap, long press and drag turned into edit actions through
/// the shared gesture arbitration.
struct PlaygroundGestures: Sendable {
    /// What carries out an action and answers it (the presenter's port in the app, a recorder in tests).
    typealias Send = (String, [Double]) -> ActionResult

    /// The actions the gestures send (each also reachable through a native control).
    static let gestureActions = PlaygroundCore.gestureActionIDs
    /// The double-tap window in seconds: a tap is sent only once this long has passed after its lift without a second
    /// touch (the `DoubleTapRecognizer`'s interval).
    static let doubleTapWindow = DoubleTapRecognizer().maxInterval
    /// The declarations, by priority: double tap > long press > drag > tap, one finger each.
    static let declarations = [
        GestureDeclaration(id: "delete", kind: .doubleTap, priority: 4, pointers: 1),
        GestureDeclaration(id: "pin", kind: .longPress, priority: 3, pointers: 1),
        GestureDeclaration(id: "grab", kind: .drag, priority: 2, pointers: 1),
        GestureDeclaration(id: "tap", kind: .tap, priority: 1, pointers: 1),
    ]
    /// The stage size in metres.
    static let stageSize = WorldSettings.defaultStage
    /// The view's width and height in metres: the stage and a wall on each side.
    static let viewWidth = stageSize.x + 2 * WorldSimulation.wallThickness,
               viewHeight = stageSize.y + 2 * WorldSimulation.wallThickness

    private var arbiter = GestureArbiter(PlaygroundGestures.declarations)
    /// The pointers currently down (every finger, also the ones the arbiter ignores).
    private var down: Set<Int> = []
    /// A second finger landed: nothing is sent until every finger lifts.
    private var suppressed = false
    /// The first finger's id, its touch-down point in stage metres and its touch-down time.
    private var touch: (id: Int, stage: Vec2?, time: Double)?
    /// The finger whose drag holds an accepted grab.
    private(set) var grabFinger: Int?
    /// A recognized tap held back until the double-tap window closes: its action and the time it becomes due.
    private(set) var pending: (control: String, values: [Double], due: Double)?
    /// The latest time seen: the last event's timestamp plus the frame time advanced since.
    private(set) var clock = 0.0
    /// The canvas size in points of the last event (the long press is mapped with it on a frame tick).
    private var viewSize: Vec2?

    /// Creates the gestures with no touch in progress.
    init() {}

    /// True while a drag holds a grab.
    var isGrabbing: Bool { grabFinger != nil }

    // MARK: Events

    /// Applies one pointer event (view points, top-left origin) against `world` (the last drawn world) on a canvas of
    /// `viewSize` points; `kind` is the shape picker's kind for an add. Every action it causes goes through `send`, in
    /// order.
    mutating func handle(_ event: PointerEvent, viewSize: Vec2, world: PhysicsWorld, kind: BodyKind,
                         send: Send) {
        clock = max(clock, event.timestamp)
        self.viewSize = viewSize
        switch event.phase {
        case .began:
            down.insert(event.id)
            if down.count > 1 {
                if !suppressed {
                    suppressed = true
                    _ = arbiter.cancelAll()
                    endGrab(send)
                }
                return
            }
            flushIfDue(send, touchBegan: event.timestamp)
            touch = (event.id, Self.stagePoint(view: event.location, viewSize: viewSize), event.timestamp)
            if grabFinger == nil, world.grab != nil { _ = send("edit.release", []) }
        case .moved:
            break
        case .ended, .cancelled:
            down.remove(event.id)
            if suppressed {
                if down.isEmpty { suppressed = false; _ = arbiter.cancelAll() }
                return
            }
        }
        if suppressed { return }

        let held = grabFinger == event.id
        for outcome in arbiter.handle(event) {
            apply(outcome, location: event.location, world: world, kind: kind, send: send)
        }
        if event.phase == .moved, held, grabFinger == event.id { move(to: event.location, send) }
        if event.phase == .ended || event.phase == .cancelled, down.isEmpty {
            if grabFinger != nil { endGrab(send) }
            touch = nil
            flushIfDue(send, touchBegan: nil)
        }
    }

    /// Advances the gestures' clock by `seconds` (the frame time; the presenter calls this every frame): a long press
    /// held still is recognized and a held tap whose double-tap window has closed is sent.
    mutating func advance(by seconds: Double, world: PhysicsWorld, send: Send) {
        guard seconds.isFinite, seconds > 0 else { return }
        clock += seconds
        guard !suppressed else { return }
        for outcome in arbiter.tick(now: clock) {
            let location = outcome.values.count >= 2 ? Vec2(outcome.values[0], outcome.values[1]) : .zero
            apply(outcome, location: location, world: world, kind: .circle, send: send)
        }
        flushIfDue(send, touchBegan: nil)
    }

    /// Forgets every touch, the held tap and the grab finger (suspension, teardown); sends nothing.
    mutating func reset() {
        _ = arbiter.cancelAll()
        down = []
        suppressed = false
        touch = nil
        grabFinger = nil
        pending = nil
        viewSize = nil
    }

    /// Turns one arbiter outcome into actions.
    private mutating func apply(_ outcome: GestureOutcome, location: Vec2, world: PhysicsWorld, kind: BodyKind,
                                send: Send) {
        let view = outcome.values.count >= 2 ? Vec2(outcome.values[0], outcome.values[1]) : location
        switch (outcome.gesture, outcome.phase) {
        case ("delete", .recognized):
            pending = nil   // the first tap of the double tap is never sent
            if let body = body(atView: view, in: world) { _ = send("edit.delete", [Double(body.id)]) }
        case ("pin", .recognized):
            flush(send)
            if let body = body(atView: view, in: world) { _ = send("edit.pin", [Double(body.id)]) }
        case ("grab", .began):
            flush(send)
            beginGrab(at: view, world: world, send: send)
        case ("grab", .ended), ("grab", .cancelled):
            endGrab(send)
        case ("tap", .recognized):
            flush(send)
            guard let size = viewSize, let point = Self.stagePoint(view: view, viewSize: size),
                  Self.isInsideStage(point) else { return }
            let due = clock + Self.doubleTapWindow
            if let body = Self.body(at: point, in: world) {
                pending = ("edit.select", [Double(body.id)], due)
            } else {
                pending = ("edit.add", [point.x, point.y, Double(kind.rawValue)], due)
            }
        default:
            break
        }
    }

    /// Sends `edit.grab` for the dynamic, unpinned body under the touch-down point and, when it is accepted,
    /// `edit.move` to the finger's current view point `view`.
    private mutating func beginGrab(at view: Vec2, world: PhysicsWorld, send: Send) {
        guard let touch, let start = touch.stage, let body = Self.body(at: start, in: world), !body.isFixed else {
            return
        }
        let anchor = Self.clampedIntoStage(start)
        guard send("edit.grab", [Double(body.id), anchor.x, anchor.y]).isAccepted else { return }
        grabFinger = touch.id
        move(to: view, send)
    }

    /// Sends `edit.move` to the view point `view` (clamped into the stage).
    private func move(to view: Vec2, _ send: Send) {
        guard let size = viewSize, let point = Self.stagePoint(view: view, viewSize: size) else { return }
        let target = Self.clampedIntoStage(point)
        _ = send("edit.move", [target.x, target.y])
    }

    /// Ends the grab with `edit.release` when one is held.
    private mutating func endGrab(_ send: Send) {
        guard grabFinger != nil else { return }
        grabFinger = nil
        _ = send("edit.release", [])
    }

    /// Sends the held tap now.
    private mutating func flush(_ send: Send) {
        guard let held = pending else { return }
        pending = nil
        _ = send(held.control, held.values)
    }

    /// Sends the held tap when its window has closed: the clock is past its due time and no finger is down, or the
    /// finger down landed after the window closed (`touchBegan`, or the first finger's touch-down time).
    private mutating func flushIfDue(_ send: Send, touchBegan: Double?) {
        guard let held = pending, clock > held.due else { return }
        let landed = touchBegan ?? (down.isEmpty ? nil : touch?.time)
        if let landed, landed <= held.due { return }   // a second touch inside the window: the double tap decides
        flush(send)
    }

    /// The body under the view point `view` on the last event's canvas.
    private func body(atView view: Vec2, in world: PhysicsWorld) -> PhysicsBody? {
        guard let size = viewSize, let point = Self.stagePoint(view: view, viewSize: size) else { return nil }
        return Self.body(at: point, in: world)
    }

    // MARK: Mapping and hit test

    /// The view's scale in points per metre for a canvas of `viewSize` points: min(width / 12, height / 10).
    static func scale(viewSize: Vec2) -> Double {
        min(viewSize.x / viewWidth, viewSize.y / viewHeight)
    }

    /// The stage point (metres, y up) of the view point `p` (points, top-left origin, y down) on a canvas of
    /// `viewSize` points; nil for an empty or non-finite size or point.
    static func stagePoint(view p: Vec2, viewSize: Vec2) -> Vec2? {
        let s = scale(viewSize: viewSize)
        guard s.isFinite, s > 0, p.isFinite else { return nil }
        return Vec2((p.x - viewSize.x / 2) / s + stageSize.x / 2, (viewSize.y / 2 - p.y) / s + stageSize.y / 2)
    }

    /// The view point (points, top-left origin) of the stage point `p` on a canvas of `viewSize` points (the inverse
    /// of ``stagePoint(view:viewSize:)``).
    static func viewPoint(stage p: Vec2, viewSize: Vec2) -> Vec2 {
        let s = scale(viewSize: viewSize)
        return Vec2(viewSize.x / 2 + (p.x - stageSize.x / 2) * s, viewSize.y / 2 - (p.y - stageSize.y / 2) * s)
    }

    /// True when `p` lies on the stage (0…10 × 0…8 m).
    static func isInsideStage(_ p: Vec2) -> Bool {
        p.x >= 0 && p.y >= 0 && p.x <= stageSize.x && p.y <= stageSize.y
    }

    /// `p` clamped into the stage.
    static func clampedIntoStage(_ p: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 0), stageSize.x), min(max(p.y, 0), stageSize.y))
    }

    /// True when the stage point `p` lies inside `body`'s shape at its pose (inside the circle, or inside the rotated
    /// box, edges included).
    static func contains(_ body: PhysicsBody, _ p: Vec2) -> Bool {
        guard body.isFinite, p.isFinite else { return false }
        let local = body.pose.toLocal(p)
        switch body.shape {
        case .circle(let radius): return local.length <= radius
        case .box(let half): return abs(local.x) <= half.x && abs(local.y) <= half.y
        }
    }

    /// The topmost body (the last drawn, so the last in the world's order) whose shape contains the stage point `p`.
    static func body(at p: Vec2, in world: PhysicsWorld) -> PhysicsBody? {
        world.bodies.last { contains($0, p) }
    }
}
