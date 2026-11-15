// WorldsGestures — feature 090 (A12-P02) T-A12-205 (FR-A12-211, FR-A12-221; SC-A12-205; clarification 3; research D3;
// edge case "Very fast or tiny gestures"). The canvas gestures of Tiny Worlds as a pure value type over VisualCore's
// shared `GestureArbiter` (VisualCoreScenes), host-testable with synthetic pointer events. Three declarations, by
// priority:
//   zoom   pinch (`PinchRecognizer`, two fingers) — 3; it takes over a drag when the second finger lands;
//   orbit  drag (`DragRecognizer`: begins after 10 points of movement, one finger) — 2;
//   pick   tap (`TapRecognizer`: lifted within 10 points and 0.3 s, one finger) — 1.
// The actions, sent through the caller's `send` (the presenter's port in the app, a recorder in tests):
//   - drag → `view.orbit [Δyaw°, Δpitch°]` for the movement since the previous move of the drag's finger (the first
//     one carries the whole movement since touch-down, so the 10-point start threshold is not lost), at 0.3° per point:
//     Δyaw = −0.3 · Δx and Δpitch = +0.3 · Δy (view points, y down). The world follows the finger: dragging right
//     turns the eye to the west of the old view (the world appears to turn right under the finger) and dragging down
//     raises the eye (the world tilts towards the viewer). Each value is clamped into −180…180, the action's range;
//     a step with no movement sends nothing;
//   - pinch → `view.zoom [factor]` with factor = the change of the two fingers' distance since the previous move (the
//     first one: the gesture's scale since touch-down; spreading the fingers gives a factor above 1, which divides the
//     distance and so moves in), clamped into 0.5…2, the action's
//     range, so a pinch to (almost) zero or to infinity saturates step by step at the camera's distance limits; a
//     factor of exactly 1 or a non-finite or non-positive scale sends nothing;
//   - tap → the caller's `tap` with the view point (points, top-left origin): the presenter resolves it to a ground
//     point and speaks it (no action, so the world never changes).
// Both actions are also sent by the native controls (turn, tilt and zoom buttons), so `GestureAlternatives.missing`
// is empty. The type never changes the world; `reset()` forgets every touch (suspension and teardown).
import Foundation
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Tiny Worlds: drag to orbit, pinch to zoom and tap to point at the ground.
struct WorldsGestures: Sendable {
    /// What carries out an action and answers it.
    typealias Send = (String, [Double]) -> ActionResult

    /// The actions the gestures send (each also reachable through a native control).
    static let gestureActions: Set<String> = ["view.orbit", "view.zoom"]
    /// Degrees of yaw and of pitch per point of drag.
    static let degreesPerPoint = 0.3
    /// The declarations, by priority: pinch (two fingers) > drag > tap.
    static let declarations = [
        GestureDeclaration(id: "zoom", kind: .pinch, priority: 3, pointers: 2),
        GestureDeclaration(id: "orbit", kind: .drag, priority: 2, pointers: 1),
        GestureDeclaration(id: "pick", kind: .tap, priority: 1, pointers: 1),
    ]

    private var arbiter = GestureArbiter(WorldsGestures.declarations)
    /// The fingers down, in touch-down order, with their latest view points.
    private var fingers: [(id: Int, at: Vec2)] = []
    /// The finger of the active drag and its point at the last step sent; nil while no drag is active.
    private(set) var drag: (id: Int, at: Vec2)?
    /// The two fingers of the active pinch and their distance at the last step sent; nil while no pinch is active.
    private(set) var pinch: (first: Int, second: Int, distance: Double)?

    /// Creates the gestures with no touch in progress.
    init() {}

    /// True while a drag orbits.
    var isDragging: Bool { drag != nil }
    /// True while a pinch zooms.
    var isPinching: Bool { pinch != nil }

    /// The `view.orbit` values of a drag movement of (`dx`, `dy`) view points: [−0.3 · dx, 0.3 · dy], each clamped
    /// into −180…180; nil when the movement is zero or not finite.
    static func orbitStep(dx: Double, dy: Double) -> [Double]? {
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return nil }
        let range = WorldView.orbitStepRange
        func clamp(_ value: Double) -> Double { min(max(value, range.lowerBound), range.upperBound) }
        return [clamp(-degreesPerPoint * dx), clamp(degreesPerPoint * dy)]
    }

    /// The `view.zoom` factor of a pinch whose scale (or finger distance) went from `previous` to `scale`:
    /// scale ÷ previous clamped into 0.5…2; nil when either is not finite and positive or the factor is exactly 1.
    static func zoomFactor(from previous: Double, to scale: Double) -> Double? {
        guard previous.isFinite, scale.isFinite, previous > 0, scale > 0 else { return nil }
        let ratio = scale / previous
        let range = WorldView.zoomRange
        let factor = ratio.isFinite ? min(max(ratio, range.lowerBound), range.upperBound) : range.upperBound
        return factor == 1 ? nil : factor
    }

    /// Applies one pointer event (view points, top-left origin): the actions it causes go through `send` in order and
    /// a recognized tap goes to `tap` with its view point. The arbiter decides which gesture owns the touch and
    /// reports its start; the steps of an owned drag or pinch are measured here on every move of its fingers (the
    /// arbiter reports a continuous gesture's state changes, not every move).
    mutating func handle(_ event: PointerEvent, send: Send, tap: (Vec2) -> Void) {
        let finite = event.location.isFinite
        if finite, event.phase == .began || event.phase == .moved {
            if let index = fingers.firstIndex(where: { $0.id == event.id }) {
                fingers[index].at = event.location
            } else if event.phase == .began {
                fingers.append((event.id, event.location))
            }
        }
        var started = false
        for outcome in arbiter.handle(event) {
            switch (outcome.gesture, outcome.phase) {
            case ("orbit", .began):
                started = true
                guard outcome.values.count >= 4 else { break }
                drag = (event.id, event.location)
                if let step = Self.orbitStep(dx: outcome.values[2], dy: outcome.values[3]) {
                    _ = send("view.orbit", step)
                }
            case ("orbit", .ended), ("orbit", .cancelled):
                drag = nil
            case ("zoom", .began):
                started = true
                guard fingers.count >= 2, let scale = outcome.values.first else { break }
                let first = fingers[0], second = fingers[1]
                pinch = (first.id, second.id, first.at.distance(to: second.at))
                if let factor = Self.zoomFactor(from: 1, to: scale) { _ = send("view.zoom", [factor]) }
            case ("zoom", .ended), ("zoom", .cancelled):
                pinch = nil
            case ("pick", .recognized):
                guard outcome.values.count >= 2 else { break }
                tap(Vec2(outcome.values[0], outcome.values[1]))
            default:
                break
            }
        }
        if !started, finite, event.phase == .moved { step(event, send: send) }
        if event.phase == .ended || event.phase == .cancelled {
            fingers.removeAll { $0.id == event.id }
            if drag?.id == event.id { drag = nil }
            if let p = pinch, p.first == event.id || p.second == event.id { pinch = nil }
        }
    }

    /// Sends the step of the owned drag or pinch that the move `event` makes.
    private mutating func step(_ event: PointerEvent, send: Send) {
        if let current = drag, current.id == event.id {
            drag = (current.id, event.location)
            if let step = Self.orbitStep(dx: event.location.x - current.at.x, dy: event.location.y - current.at.y) {
                _ = send("view.orbit", step)
            }
        }
        if let current = pinch, current.first == event.id || current.second == event.id,
           let a = fingers.first(where: { $0.id == current.first }),
           let b = fingers.first(where: { $0.id == current.second }) {
            let distance = a.at.distance(to: b.at)
            if let factor = Self.zoomFactor(from: current.distance, to: distance) {
                _ = send("view.zoom", [factor])
            }
            if distance.isFinite, distance > 0 { pinch = (current.first, current.second, distance) }
        }
    }

    /// Forgets every touch and the drag and pinch in progress; sends nothing.
    mutating func reset() {
        _ = arbiter.cancelAll()
        fingers = []
        drag = nil
        pinch = nil
    }
}
