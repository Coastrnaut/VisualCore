// ArcadeGestures — feature 075 (A10-P01) T-A10-104 (FR-A10-121; clarification 4). The canvas gesture of Neon Arcade
// as a pure value type over the shared `GestureArbiter` (VisualCoreScenes), so it is host-testable with synthetic
// pointer events. One one-finger declaration, `steer` (drag; it begins after the arbiter's 10 points of movement):
// on `began` and on every later move of the held finger it sends `run.steer` with the finger's horizontal offset from
// the player in game units ÷ 1.5, clamped to −1…1; when the finger lifts or the drag is cancelled it sends
// `run.steer [0]`. Because the declaration uses one pointer the arbiter ignores a second finger, so this type counts
// the fingers itself: a second finger stops the steering (`run.steer [0]` once) and nothing more is sent until every
// finger has lifted.
// View points (top-left origin, y down) map onto the 9 × 16 field the way the presenter draws it: centred, scale
// s = min(width / 9, height / 16) points per unit.
import Foundation
import NeonArcadeCore
import VisualCoreMath
import VisualCoreScenes

/// The canvas gesture of Neon Arcade: turns a one-finger drag into `run.steer` actions through the shared gesture
/// arbitration.
struct ArcadeGestures: Sendable {
    /// The actions the gesture sends (each also reachable through a native control).
    static let gestureActions: Set<String> = ["run.steer"]
    /// The finger offset from the player, in game units, that gives full steering.
    static let steerReach = 1.5
    /// The gesture declaration: drag → steer, one finger.
    static let declarations = [GestureDeclaration(id: "steer", kind: .drag, priority: 1, pointers: 1)]

    private var arbiter = GestureArbiter(ArcadeGestures.declarations)
    /// The pointers currently down (every finger, also the ones the arbiter ignores).
    private var down: Set<Int> = []
    /// A second finger landed: nothing is sent until every finger lifts.
    private var suppressed = false
    /// Whether a drag is steering (its release sends `run.steer [0]`).
    private(set) var steering = false

    /// Creates the gesture with no touch in progress.
    init() {}

    /// Applies one pointer event (view points, top-left origin) and returns the actions it causes, in order, each as a
    /// control id with its values (`run.steer [value]`). `playerX` is the player's x in game units in the last drawn
    /// run; `viewSize` is the canvas size in points.
    mutating func handle(_ event: PointerEvent, playerX: Double,
                         viewSize: Vec2) -> [(control: String, values: [Double])] {
        var actions: [(control: String, values: [Double])] = []
        switch event.phase {
        case .began:
            down.insert(event.id)
            if down.count > 1 {
                if !suppressed {
                    _ = arbiter.cancelAll()
                    suppressed = true
                    if steering { steering = false; actions.append(("run.steer", [0])) }
                }
                return actions
            }
        case .moved:
            break
        case .ended, .cancelled:
            down.remove(event.id)
            if suppressed {
                if down.isEmpty { suppressed = false; _ = arbiter.cancelAll() }
                return []
            }
        }
        if suppressed { return [] }

        // The arbiter reports `changed` only when the drag recognizer's state changes, so every later move of the
        // held finger is turned into `run.steer` here.
        let held = steering
        for outcome in arbiter.handle(event) where outcome.gesture == "steer" {
            switch outcome.phase {
            case .began:
                steering = true
                if let value = Self.steeringValue(view: event.location, playerX: playerX, viewSize: viewSize) {
                    actions.append(("run.steer", [value]))
                }
            case .ended, .cancelled:
                if steering { steering = false; actions.append(("run.steer", [0])) }
            default:
                break
            }
        }
        if event.phase == .moved, held, steering,
           let value = Self.steeringValue(view: event.location, playerX: playerX, viewSize: viewSize) {
            actions.append(("run.steer", [value]))
        }
        if (event.phase == .ended || event.phase == .cancelled), down.isEmpty, steering {
            steering = false
            actions.append(("run.steer", [0]))
        }
        return actions
    }

    /// Cancels the drag in progress and forgets the fingers down (no action is sent).
    mutating func reset() {
        _ = arbiter.cancelAll()
        down = []
        suppressed = false
        steering = false
    }

    // MARK: Mapping

    /// The field x (game units) of a view x, through the presenter's centred scale; nil for an empty or non-finite
    /// view size or point.
    static func fieldX(view x: Double, viewSize: Vec2) -> Double? {
        let s = ArcadePresenter.scale(width: viewSize.x, height: viewSize.y)
        guard s.isFinite, s > 0, x.isFinite else { return nil }
        return (x - viewSize.x / 2) / s + GameRun.fieldWidth / 2
    }

    /// The steering value of a finger at view point `p`: (field x − `playerX`) ÷ ``steerReach``, clamped to −1…1; nil
    /// when the point cannot be mapped or `playerX` is not finite.
    static func steeringValue(view p: Vec2, playerX: Double, viewSize: Vec2) -> Double? {
        guard playerX.isFinite, let x = fieldX(view: p.x, viewSize: viewSize) else { return nil }
        return min(max((x - playerX) / steerReach, -1), 1)
    }
}
