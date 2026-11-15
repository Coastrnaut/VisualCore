// AquariumGestures — feature 070 (A09-P03) T-A09-305 (FR-A09-311; clarifications 1 and 2; research D1). The canvas
// gestures of Digital Aquarium as a pure value type over the shared `GestureArbiter` (VisualCoreScenes), so they are
// host-testable with synthetic pointer events. Three one-finger declarations: `feed` (tap, priority 1) → `food.drop`
// at the lift point; `place` (long press, priority 2: held 0.5 s within 10 points) → `decor.place` at the press point;
// `move` (drag, priority 3: begins after 10 points of movement) → when the drag's touch-down point lies on a decor piece
// (the topmost piece whose centre is within half its drawn width plus a touch margin), `decor.move` of that piece at
// the current point on `began` and every `changed`; a drag that starts on water sends nothing. The arbiter gives each
// touch to one gesture. Because every declaration uses one pointer the arbiter ignores a second finger, so this type
// counts the fingers itself: a second finger cancels everything (a pending tap or long press fails, a drag stops) and
// nothing more is sent until every finger has lifted.
// View points (top-left origin, y down) map onto the 16 × 9 tank the way the presenter draws it: centred, scale
// s = min(width / 16, height / 9) points per unit, y up; positions are sent as fractions of the tank (x left→right,
// y bottom→top) clamped to 0…1, so a touch in the letterbox outside the tank lands on its nearest edge.
import Foundation
import DigitalAquariumCore
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Digital Aquarium: turns pointer events into `food.drop`, `decor.place` and `decor.move`
/// actions through the shared gesture arbitration.
struct AquariumGestures: Sendable {
    /// The actions the gestures send (each also reachable through a native control).
    static let gestureActions: Set<String> = ["food.drop", "decor.place", "decor.move"]
    /// Extra reach around a decor piece's drawn half width for a touch, in tank units.
    static let touchMargin = 0.3
    /// The gesture declarations: tap → feed (1), long press → place (2), drag → move (3), one finger each.
    static let declarations = [
        GestureDeclaration(id: "feed", kind: .tap, priority: 1, pointers: 1),
        GestureDeclaration(id: "place", kind: .longPress, priority: 2, pointers: 1),
        GestureDeclaration(id: "move", kind: .drag, priority: 3, pointers: 1),
    ]

    private var arbiter = GestureArbiter(AquariumGestures.declarations)
    /// The pointers currently down (every finger, also the ones the arbiter ignores).
    private var down: Set<Int> = []
    /// A second finger landed: nothing is sent until every finger lifts.
    private var suppressed = false
    /// The decor index being dragged, if the drag began on a piece.
    private(set) var dragging: Int?

    /// Creates the gestures with no touch in progress.
    init() {}

    /// Applies one pointer event (view points, top-left origin) and returns the actions it causes, in order, each as a
    /// control id with its values: `food.drop [x, y]`, `decor.place [x, y]`, `decor.move [index, x, y]` (x and y tank
    /// fractions 0…1). `document` and `catalog` give the decor pieces and their sizes for the drag hit test;
    /// `viewSize` is the canvas size in points.
    mutating func handle(_ event: PointerEvent, document: HabitatDocument, catalog: SpeciesCatalog,
                         viewSize: Vec2) -> [(control: String, values: [Double])] {
        switch event.phase {
        case .began:
            down.insert(event.id)
            if down.count > 1 {
                if !suppressed { _ = arbiter.cancelAll(); dragging = nil; suppressed = true }
                return []
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

        var actions: [(control: String, values: [Double])] = []
        // The piece held before this event: the arbiter reports `changed` only when the drag recognizer's state
        // changes (once), so every later move of the held finger is turned into `decor.move` here (research D1).
        let held = dragging
        for outcome in arbiter.handle(event) {
            switch (outcome.gesture, outcome.phase) {
            case ("feed", .recognized):
                if let f = Self.fractions(of: outcome.values, viewSize: viewSize) { actions.append(("food.drop", f)) }
            case ("place", .recognized):
                if let f = Self.fractions(of: outcome.values, viewSize: viewSize) { actions.append(("decor.place", f)) }
            case ("move", .began):
                dragging = nil
                guard outcome.values.count >= 4 else { break }
                let start = Vec2(outcome.values[0] - outcome.values[2], outcome.values[1] - outcome.values[3])
                guard let tank = Self.tankPoint(view: start, viewSize: viewSize) else { break }
                dragging = Self.hitDecor(at: tank, document: document, catalog: catalog)
                if let index = dragging, let f = Self.fractions(of: outcome.values, viewSize: viewSize) {
                    actions.append(("decor.move", [Double(index)] + f))
                }
            case ("move", .changed):
                break                                  // handled below for every move of the held finger
            case ("move", .ended), ("move", .cancelled):
                dragging = nil
            default:
                break
            }
        }
        if event.phase == .moved, let index = held, dragging == index,
           let f = Self.fractions(view: event.location, viewSize: viewSize) {
            actions.append(("decor.move", [Double(index)] + f))
        }
        if event.phase == .cancelled || down.isEmpty { dragging = nil }
        return actions
    }

    /// Cancels every gesture in progress and forgets the dragged piece and the fingers down.
    mutating func reset() {
        _ = arbiter.cancelAll()
        down = []
        suppressed = false
        dragging = nil
    }

    // MARK: Mapping

    /// The tank point (units, y up) of a view point, through the presenter's centred scale; nil for an empty or
    /// non-finite view size or point.
    static func tankPoint(view p: Vec2, viewSize: Vec2) -> Vec2? {
        let s = AquariumPresenter.scale(width: viewSize.x, height: viewSize.y)
        guard s.isFinite, s > 0, p.isFinite else { return nil }
        let w = AquariumPresenter.tankWidth, h = AquariumPresenter.tankHeight
        return Vec2((p.x - viewSize.x / 2) / s + w / 2, (viewSize.y / 2 - p.y) / s + h / 2)
    }

    /// The tank fractions [x, y] (each clamped to 0…1) of a view point; nil when it cannot be mapped.
    static func fractions(view p: Vec2, viewSize: Vec2) -> [Double]? {
        guard let t = tankPoint(view: p, viewSize: viewSize) else { return nil }
        let w = AquariumPresenter.tankWidth, h = AquariumPresenter.tankHeight
        return [min(max(t.x / w, 0), 1), min(max(t.y / h, 0), 1)]
    }

    /// The fractions of the view point held in the first two outcome values.
    private static func fractions(of values: [Double], viewSize: Vec2) -> [Double]? {
        guard values.count >= 2 else { return nil }
        return fractions(view: Vec2(values[0], values[1]), viewSize: viewSize)
    }

    /// The topmost (last drawn) decor piece whose centre is within half its drawn width (kind size × scale) plus
    /// ``touchMargin`` of `point` (tank units); nil when the point is on water or the piece's kind is not in `catalog`.
    static func hitDecor(at point: Vec2, document: HabitatDocument, catalog: SpeciesCatalog) -> Int? {
        for index in document.decor.indices.reversed() {
            let piece = document.decor[index]
            guard let kind = catalog.decor(id: piece.kindId) else { continue }
            if point.distance(to: piece.position) <= 0.5 * kind.size * piece.scale + touchMargin { return index }
        }
        return nil
    }
}
