// MoleculeGestures — feature 112 (A15-P03) T-A15-305 (FR-A15-301, FR-A15-302, FR-A15-310; clarification Q1; edge
// cases "A tap that hits nothing", "Very small or fast gestures", "A suspension or teardown during a gesture";
// SC-A15-302). The canvas gestures of Molecular Explorer as a pure value type over VisualCore's shared `GestureArbiter`
// (VisualCoreScenes), host-testable with synthetic pointer events and modelled on Tiny Worlds' `WorldsGestures`. Three
// declarations, by priority:
//   zoom   pinch (`PinchRecognizer`, two fingers) — 3; it takes over a drag when the second finger lands;
//   orbit  drag (`DragRecognizer`: begins after 10 points of movement, one finger) — 2;
//   pick   tap (`TapRecognizer`: lifted within 10 points and 0.3 s, one finger) — 1.
// Every gesture becomes the same stepped actions the buttons send (through the caller's `send`: the presenter's port in
// the app, a recorder in tests), so a gesture always ends in a state the buttons reach too:
//   - drag, at 0.3° per point, accumulated (the first step carries the whole movement since touch-down, so the 10-point
//     start threshold is not lost; points left over stay for the next move): every 50 points (15°) across sends one
//     `camera.orbit` and every 33⅓ points (10°) down or up one `camera.tilt`. The molecule follows the finger: the
//     orbit camera's eye sits at yaw `turn × 15°` on the +z side of the target turning toward +x as the yaw grows, so a
//     larger turn swings the eye to the right and the molecule's front appears to move LEFT; dragging right therefore
//     sends `camera.orbit [−1]` (the molecule turns right under the finger, as the Turn left button does) and dragging
//     left `camera.orbit [+1]`. A larger tilt raises the eye, so the molecule's front appears to move down: dragging
//     down (view y grows) sends `camera.tilt [+1]` and dragging up `camera.tilt [−1]`;
//   - two fingers, measured from the fingers themselves from the moment the second finger lands (the pinch
//     declaration only keeps the arbiter from reading two fingers as a drag or a tap, so a two-finger move with an
//     unchanged distance still pans): each time the fingers' distance since the last zoom step reaches 1 / 0.85 times
//     that distance, one `camera.zoom [+1]` (closer), and each time it falls to 0.85 times, one `camera.zoom [−1]`;
//     every 40 points the fingers' midpoint moves across or down/up since the last pan step, one `camera.pan` step so
//     the molecule follows the fingers: a positive pan moves the camera's target to the view's right (or up), so the
//     molecule appears to move left (or down); fingers moving right send `camera.pan [−1, 0]`, left `[+1, 0]`, down
//     (view y grows) `[0, +1]` and up `[0, −1]`;
//   - tap → the caller's `tap` with the view point (points, top-left origin): the presenter picks with the camera,
//     scene and canvas of the last drawn frame and sends `atom.select [index]`, or `atom.clear` on a miss while an atom
//     is selected. A tap during a drag or a pinch is not a tap (the arbiter owns the touch).
// A step the core refuses at a limit is dropped quietly: the result of `send` is not looked at and the accumulated
// points are used up as if it had been accepted, so nothing bursts out later (the buttons answer limits in words).
// Movements below a step send nothing; a large movement sends several steps in order (at most 64 per axis and event).
// The type never changes the state; `reset()` forgets every touch and the steps in progress (teardown) and sends
// nothing, so the next touch starts a new gesture.
import Foundation
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Molecular Explorer: drag to turn and tilt, pinch to zoom, two fingers to pan, tap to pick.
struct MoleculeGestures: Sendable {
    /// What carries out an action and answers it.
    typealias Send = (String, [Double]) -> ActionResult

    /// The actions the gestures send (each also reachable through a native control).
    static let gestureActions: Set<String> = ["camera.orbit", "camera.tilt", "camera.zoom", "camera.pan",
                                              "atom.select", "atom.clear"]
    /// Degrees of turn or tilt per point of drag.
    static let degreesPerPoint = 0.3
    /// Points of horizontal drag per `camera.orbit` step (15° at 0.3° per point: 50).
    static let orbitPoints = Double(CameraSettings.turnStepDegrees) / degreesPerPoint
    /// Points of vertical drag per `camera.tilt` step (10° at 0.3° per point: 33⅓).
    static let tiltPoints = Double(CameraSettings.tiltStepDegrees) / degreesPerPoint
    /// The finger-distance ratio of one zoom step (0.85 out, 1 / 0.85 in).
    static let zoomRatio = CameraSettings.zoomFactor
    /// Points of two-finger midpoint movement per `camera.pan` step.
    static let panPoints = 40.0
    /// The most steps one axis sends for one event.
    static let maxStepsPerEvent = 64
    /// The declarations, by priority: pinch (two fingers) > drag > tap.
    static let declarations = [
        GestureDeclaration(id: "zoom", kind: .pinch, priority: 3, pointers: 2),
        GestureDeclaration(id: "orbit", kind: .drag, priority: 2, pointers: 1),
        GestureDeclaration(id: "pick", kind: .tap, priority: 1, pointers: 1),
    ]

    /// The arbiter deciding which gesture owns the touch.
    private var arbiter = GestureArbiter(MoleculeGestures.declarations)
    /// The fingers down, in touch-down order, with their latest view points.
    private var fingers: [(id: Int, at: Vec2)] = []
    /// The finger of the active drag and its point at the last move; nil while no drag is active.
    private(set) var drag: (id: Int, at: Vec2)?
    /// The drag's points not yet turned into steps (x across, y down).
    private(set) var dragRemainder = Vec2(0, 0)
    /// The two fingers of the active two-finger gesture with the distance and the midpoint at the last zoom and pan
    /// steps; nil while fewer than two fingers are down.
    private(set) var twoFinger: (first: Int, second: Int, distance: Double, centre: Vec2)?

    /// Creates the gestures with no touch in progress.
    init() {}

    /// True while a drag turns and tilts.
    var isDragging: Bool { drag != nil }
    /// True while two fingers zoom and pan.
    var isTwoFinger: Bool { twoFinger != nil }

    /// Applies one pointer event (view points, top-left origin): the actions it causes go through `send` in order and
    /// a recognized tap goes to `tap` with its view point.
    mutating func handle(_ event: PointerEvent, send: Send, tap: (Vec2) -> Void) {
        let finite = event.location.isFinite
        if finite, event.phase == .began || event.phase == .moved {
            if let index = fingers.firstIndex(where: { $0.id == event.id }) {
                fingers[index].at = event.location
            } else if event.phase == .began {
                fingers.append((event.id, event.location))
                if fingers.count == 2, twoFinger == nil {
                    let a = fingers[0], b = fingers[1]
                    twoFinger = (a.id, b.id, a.at.distance(to: b.at), (a.at + b.at) * 0.5)
                    drag = nil
                    dragRemainder = Vec2(0, 0)
                }
            }
        }
        var started = false
        for outcome in arbiter.handle(event) {
            switch (outcome.gesture, outcome.phase) {
            case ("orbit", .began):
                started = true
                guard twoFinger == nil, outcome.values.count >= 4 else { break }
                drag = (event.id, event.location)
                dragRemainder = Vec2(outcome.values[2], outcome.values[3])
                sendDragSteps(send)
            case ("orbit", .ended), ("orbit", .cancelled):
                drag = nil
                dragRemainder = Vec2(0, 0)
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
            if drag?.id == event.id {
                drag = nil
                dragRemainder = Vec2(0, 0)
            }
            if let pair = twoFinger, pair.first == event.id || pair.second == event.id { twoFinger = nil }
        }
    }

    /// Sends the steps the move `event` makes for the owned drag or the two-finger gesture.
    private mutating func step(_ event: PointerEvent, send: Send) {
        if let current = drag, current.id == event.id {
            dragRemainder = dragRemainder + (event.location - current.at)
            drag = (current.id, event.location)
            sendDragSteps(send)
        }
        guard var pair = twoFinger, pair.first == event.id || pair.second == event.id,
              let a = fingers.first(where: { $0.id == pair.first }),
              let b = fingers.first(where: { $0.id == pair.second }) else { return }
        let distance = a.at.distance(to: b.at)
        let centre = (a.at + b.at) * 0.5
        if pair.distance > 0, distance.isFinite {
            var count = 0
            while distance * Self.zoomRatio >= pair.distance, count < Self.maxStepsPerEvent {
                _ = send("camera.zoom", [1])
                pair.distance /= Self.zoomRatio
                count += 1
            }
            count = 0
            while distance <= pair.distance * Self.zoomRatio, count < Self.maxStepsPerEvent {
                _ = send("camera.zoom", [-1])
                pair.distance *= Self.zoomRatio
                count += 1
            }
        } else if distance.isFinite, distance > 0 {
            pair.distance = distance
        }
        var count = 0
        while centre.x - pair.centre.x >= Self.panPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.pan", [-1, 0])
            pair.centre.x += Self.panPoints
            count += 1
        }
        count = 0
        while centre.x - pair.centre.x <= -Self.panPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.pan", [1, 0])
            pair.centre.x -= Self.panPoints
            count += 1
        }
        count = 0
        while centre.y - pair.centre.y >= Self.panPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.pan", [0, 1])
            pair.centre.y += Self.panPoints
            count += 1
        }
        count = 0
        while centre.y - pair.centre.y <= -Self.panPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.pan", [0, -1])
            pair.centre.y -= Self.panPoints
            count += 1
        }
        twoFinger = pair
    }

    /// Sends the orbit and tilt steps the accumulated drag holds and keeps the points left over.
    private mutating func sendDragSteps(_ send: Send) {
        guard dragRemainder.isFinite else {
            dragRemainder = Vec2(0, 0)
            return
        }
        var count = 0
        while dragRemainder.x >= Self.orbitPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.orbit", [-1])
            dragRemainder.x -= Self.orbitPoints
            count += 1
        }
        count = 0
        while dragRemainder.x <= -Self.orbitPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.orbit", [1])
            dragRemainder.x += Self.orbitPoints
            count += 1
        }
        count = 0
        while dragRemainder.y >= Self.tiltPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.tilt", [1])
            dragRemainder.y -= Self.tiltPoints
            count += 1
        }
        count = 0
        while dragRemainder.y <= -Self.tiltPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.tilt", [-1])
            dragRemainder.y += Self.tiltPoints
            count += 1
        }
    }

    /// Forgets every touch and the drag and two-finger steps in progress; sends nothing.
    mutating func reset() {
        _ = arbiter.cancelAll()
        fingers = []
        drag = nil
        dragRemainder = Vec2(0, 0)
        twoFinger = nil
    }
}
