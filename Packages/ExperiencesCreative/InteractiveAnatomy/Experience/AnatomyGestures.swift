// AnatomyGestures — feature 127 (A17-P04) T-A17-405 (FR-A17-401; clarification Q1; edge cases "A drag that starts as a
// tap", "Pinch and drag at once"; SC-A17-401; contracts/accessibility-pack.md). The canvas gestures of Interactive
// Anatomy as a pure value type over VisualCore's shared `GestureArbiter` (VisualCoreScenes), host-testable with
// synthetic pointer events and modelled on Molecular Explorer's `MoleculeGestures`. Three declarations, by priority:
//   zoom   pinch (`PinchRecognizer`, two fingers) — 3; it takes over a drag when the second finger lands;
//   orbit  drag (`DragRecognizer`: begins after 10 points of movement, one finger) — 2;
//   pick   tap (`TapRecognizer`: lifted within 10 points and 0.3 s, one finger) — 1.
// Every gesture becomes the same stepped actions the buttons send (through the caller's `send`: the presenter, which
// shows the answer, in the app; a recorder in tests), so a gesture always ends in a state the buttons reach too:
//   - drag, at 0.3° per point, accumulated (the first step carries the whole movement since touch-down, so the 10-point
//     start threshold is not lost; points left over stay for the next move): every 50 points (15°) across sends one
//     `camera.turn` (+1 to the right, −1 to the left) and every 33⅓ points (10°) up or down one `camera.tilt` (+1 up,
//     that is the view y falling; −1 down);
//   - two fingers, measured from the fingers themselves from the moment the second finger lands: each time the
//     fingers' distance since the last zoom step reaches 1 / 0.85 times that distance, one `camera.zoom [+1]`, and each
//     time it falls to 0.85 times, one `camera.zoom [−1]`. A drag in progress ends when the second finger lands, so a
//     pinch never also turns or tilts; two fingers held at a near-constant distance send nothing;
//   - tap → the caller's `tap` with the view point (points, top-left origin), only for a touch that never had a second
//     finger. A drag is not a tap (the arbiter owns the touch).
// A refused step (`a17.camera-limit` at a tilt or zoom limit) is answered by the caller ("The camera is at its
// limit."); the accumulated points are used up as if it had been accepted, so nothing bursts out later. Movements below
// a step send nothing; a large movement sends several steps in order (at most 64 per axis and event). The type never
// changes the state; `reset()` forgets every touch and the steps in progress (teardown, suspension) and sends nothing.
import Foundation
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Interactive Anatomy: drag to turn and tilt, pinch to zoom, tap to pick.
struct AnatomyGestures: Sendable {
    /// What carries out an action and answers it.
    typealias Send = (String, [Double]) -> ActionResult

    /// The actions the gestures send (each also reachable through a native control).
    static let gestureActions: Set<String> = ["camera.turn", "camera.tilt", "camera.zoom", "structure.select",
                                              "structure.clear"]
    /// Degrees of turn or tilt per point of drag.
    static let degreesPerPoint = 0.3
    /// Points of horizontal drag per `camera.turn` step (15° at 0.3° per point: 50).
    static let turnPoints = AnatomyCameraState.turnStepDegrees / degreesPerPoint
    /// Points of vertical drag per `camera.tilt` step (10° at 0.3° per point: 33⅓).
    static let tiltPoints = AnatomyCameraState.tiltStepDegrees / degreesPerPoint
    /// The finger-distance ratio of one zoom step (0.85 out, 1 / 0.85 in).
    static let zoomRatio = AnatomyCameraState.zoomFactor
    /// The most steps one axis sends for one event.
    static let maxStepsPerEvent = 64
    /// The declarations, by priority: pinch (two fingers) > drag > tap.
    static let declarations = [
        GestureDeclaration(id: "zoom", kind: .pinch, priority: 3, pointers: 2),
        GestureDeclaration(id: "orbit", kind: .drag, priority: 2, pointers: 1),
        GestureDeclaration(id: "pick", kind: .tap, priority: 1, pointers: 1),
    ]

    /// The arbiter deciding which gesture owns the touch.
    private var arbiter = GestureArbiter(AnatomyGestures.declarations)
    /// The fingers down, in touch-down order, with their latest view points.
    private var fingers: [(id: Int, at: Vec2)] = []
    /// Whether a second finger landed since the first went down (the touch then never taps).
    private(set) var multiTouch = false
    /// The finger of the active drag and its point at the last move; nil while no drag is active.
    private(set) var drag: (id: Int, at: Vec2)?
    /// The drag's points not yet turned into steps (x across, y down).
    private(set) var dragRemainder = Vec2(0, 0)
    /// The two fingers of the pinch with their distance at the last zoom step; nil while fewer than two are down.
    private(set) var pinch: (first: Int, second: Int, distance: Double)?

    /// Creates the gestures with no touch in progress.
    init() {}

    /// True while a drag turns and tilts.
    var isDragging: Bool { drag != nil }
    /// True while two fingers zoom.
    var isPinching: Bool { pinch != nil }

    /// Applies one pointer event (view points, top-left origin): the actions it causes go through `send` in order and
    /// a recognized tap of a single-finger touch goes to `tap` with its view point.
    mutating func handle(_ event: PointerEvent, send: Send, tap: (Vec2) -> Void) {
        let finite = event.location.isFinite
        if finite, event.phase == .began || event.phase == .moved {
            if let index = fingers.firstIndex(where: { $0.id == event.id }) {
                fingers[index].at = event.location
            } else if event.phase == .began {
                fingers.append((event.id, event.location))
                if fingers.count >= 2 { multiTouch = true }
                if fingers.count == 2, pinch == nil {
                    let a = fingers[0], b = fingers[1]
                    pinch = (a.id, b.id, a.at.distance(to: b.at))
                    drag = nil
                    dragRemainder = Vec2(0, 0)
                }
            }
        }
        var started = false
        for outcome in arbiter.handle(event) {
            switch (outcome.gesture, outcome.phase) {
            case ("orbit", .began):
                guard pinch == nil, !multiTouch, outcome.values.count >= 4 else { break }
                started = true
                drag = (event.id, event.location)
                dragRemainder = Vec2(outcome.values[2], outcome.values[3])
                sendDragSteps(send)
            case ("orbit", .ended), ("orbit", .cancelled):
                drag = nil
                dragRemainder = Vec2(0, 0)
            case ("pick", .recognized):
                guard !multiTouch, outcome.values.count >= 2 else { break }
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
            if let pair = pinch, pair.first == event.id || pair.second == event.id { pinch = nil }
            if fingers.isEmpty { multiTouch = false }
        }
    }

    /// Sends the steps the move `event` makes for the owned drag or the pinch.
    private mutating func step(_ event: PointerEvent, send: Send) {
        if let current = drag, current.id == event.id {
            dragRemainder = dragRemainder + (event.location - current.at)
            drag = (current.id, event.location)
            sendDragSteps(send)
        }
        guard var pair = pinch, pair.first == event.id || pair.second == event.id,
              let a = fingers.first(where: { $0.id == pair.first }),
              let b = fingers.first(where: { $0.id == pair.second }) else { return }
        let distance = a.at.distance(to: b.at)
        guard distance.isFinite else { return }
        if pair.distance > 0 {
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
        } else if distance > 0 {
            pair.distance = distance
        }
        pinch = pair
    }

    /// Sends the turn and tilt steps the accumulated drag holds and keeps the points left over.
    private mutating func sendDragSteps(_ send: Send) {
        guard dragRemainder.isFinite else {
            dragRemainder = Vec2(0, 0)
            return
        }
        var count = 0
        while dragRemainder.x >= Self.turnPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.turn", [1])
            dragRemainder.x -= Self.turnPoints
            count += 1
        }
        count = 0
        while dragRemainder.x <= -Self.turnPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.turn", [-1])
            dragRemainder.x += Self.turnPoints
            count += 1
        }
        count = 0
        while dragRemainder.y <= -Self.tiltPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.tilt", [1])
            dragRemainder.y += Self.tiltPoints
            count += 1
        }
        count = 0
        while dragRemainder.y >= Self.tiltPoints, count < Self.maxStepsPerEvent {
            _ = send("camera.tilt", [-1])
            dragRemainder.y -= Self.tiltPoints
            count += 1
        }
    }

    /// Forgets every touch and the drag and pinch steps in progress; sends nothing.
    mutating func reset() {
        _ = arbiter.cancelAll()
        fingers = []
        multiTouch = false
        drag = nil
        dragRemainder = Vec2(0, 0)
        pinch = nil
    }
}
