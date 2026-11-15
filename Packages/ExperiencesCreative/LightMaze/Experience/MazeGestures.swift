// MazeGestures — feature 097 (A13-P02) T-A13-203 (FR-A13-201–204; SC-A13-201–203; clarifications Q1–Q3, Q2 as
// amended; research D1; contract `specs/097-lm-p02-interaction/contracts/interaction.md`). The canvas gestures of
// Light Maze as a pure value type over VisualCore's shared `GestureArbiter` (VisualCoreScenes), host-testable with
// synthetic pointer events, after Tiny Worlds' `WorldsGestures`. Three declarations, by priority:
//   twist  rotation (`RotateRecognizer`, two fingers) — 3; it takes over a drag when the second finger lands;
//   snap   drag (`DragRecognizer`: begins after 10 points of movement, one finger) — 2;
//   pick   tap (`TapRecognizer`: lifted within 10 points and 0.3 s, one finger) — 1.
// The caller passes, with every event, the current maze state (read again after every action sent, so a drag that
// turns a tile sees the turned tile), a mapping from view points (top-left origin) to board units (one unit per cell,
// x east, y north; the presenter inverts its board camera of the last frame) and `send`, which carries out an action
// and answers it (the presenter's port in the app, a recorder in tests). The rules:
//   - tap → the cell under the point (the floor of x and y): a turnable tile (mirror or prism) that is not selected
//     sends `tile.select [i]` (i: its index among the level's turnable tiles in tile order), the selected one sends
//     `tile.turn`; anything else on the board sends nothing and answers "Nothing to turn there.", a point off the
//     board "Outside the board.";
//   - drag → only when it began (10 points) on a turnable tile; on its start and on every later move of its finger the
//     vector from touch-down to the latest point is measured in board units; once it is at least ``snapDistance``
//     (0.35 cell) long the target is `/` when the direction lies strictly within 45° of north-east or south-west (x and
//     y of the same sign), else `\` (an axis-aligned drag lies exactly 45° from both diagonals and snaps to `\`); when
//     the tile's orientation differs the gesture sends `tile.select [i]` then `tile.turn` (the same actions as the
//     Select and Turn controls), when it matches it sends nothing. At most one turn per event; a later move may turn
//     it back when the direction crosses over. Only the tile where the drag started is affected, wherever the finger
//     goes. A drag that begins elsewhere sends nothing and answers like a tap there;
//   - rotation → only over the selected tile (the midpoint of the two fingers when the rotation starts); the angle is
//     accumulated from the recognizer's start angle and then from every move of either finger (counter-clockwise on
//     screen positive), and each time it passes ±``snapAngle`` (45°) from the last snap the gesture sends one
//     `tile.turn` and the reference moves by that 45°; less sends nothing. Over another cell it sends nothing and
//     answers "Select a mirror or prism first." with nothing selected, else "Twist over the selected tile.".
// The gesture actions are `tile.select` and `tile.turn`, both sent by the native controls, so
// `GestureAlternatives.missing` is empty. The type never changes the maze itself; `reset()` forgets every touch
// (suspension and teardown).
import Foundation
import LightMazeCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Light Maze: tap to select or turn, drag or twist to snap a mirror or prism.
struct MazeGestures: Sendable {
    /// What carries out an action and answers it.
    typealias Send = (String, [Double]) -> ActionResult

    /// The actions the gestures send (both also sent by the native controls).
    static let gestureActions: Set<String> = ["tile.select", "tile.turn"]
    /// The drag length, in cells, from which a drag snaps its tile.
    static let snapDistance = 0.35
    /// The rotation, in radians, that turns the selected tile once (45°).
    static let snapAngle = Double.pi / 4
    /// The answer to a gesture on a cell of the board without a turnable tile.
    static let nothingWords = "Nothing to turn there."
    /// The answer to a gesture off the board.
    static let outsideWords = "Outside the board."
    /// The answer to a rotation with nothing selected.
    static let selectFirstWords = "Select a mirror or prism first."
    /// The answer to a rotation over a cell other than the selected tile's.
    static let twistWords = "Twist over the selected tile."
    /// The declarations, by priority: rotation (two fingers) > drag > tap.
    static let declarations = [
        GestureDeclaration(id: "twist", kind: .rotate, priority: 3, pointers: 2),
        GestureDeclaration(id: "snap", kind: .drag, priority: 2, pointers: 1),
        GestureDeclaration(id: "pick", kind: .tap, priority: 1, pointers: 1),
    ]

    private var arbiter = GestureArbiter(MazeGestures.declarations)
    /// The fingers down, in touch-down order, with their latest view points.
    private var fingers: [(id: Int, at: Vec2)] = []
    /// The active drag: its finger, the index in `board.tiles` of the tile it started on and the touch-down point in
    /// board units; nil while no drag snaps a tile.
    private(set) var drag: (id: Int, tile: Int, origin: Vec2)?
    /// The active rotation: its two fingers, their vector (view points) at the last step and the angle accumulated
    /// since the last snap; nil while no rotation turns a tile.
    private(set) var twist: (first: Int, second: Int, vector: Vec2, angle: Double)?

    /// Creates the gestures with no touch in progress.
    init() {}

    /// True while a drag snaps a tile.
    var isDragging: Bool { drag != nil }
    /// True while a rotation turns the selected tile.
    var isTwisting: Bool { twist != nil }

    /// The orientation a drag along `vector` (board units, y north) snaps to: `/` when x and y have the same sign
    /// (strictly within 45° of north-east or south-west), else `\`; nil when the vector is shorter than
    /// ``snapDistance`` or not finite.
    static func target(of vector: Vec2) -> Orientation? {
        guard vector.isFinite, vector.length >= snapDistance else { return nil }
        return vector.x * vector.y > 0 ? .slash : .backslash
    }

    /// What lies at the board point `point` of `state`: the turnable tile's index in `board.tiles` and among the
    /// turnable tiles, or the words of a refusal ("Outside the board." / "Nothing to turn there.").
    static func turnable(at point: Vec2?, in state: MazeState) -> Result<(tile: Int, position: Int), Refusal> {
        let board = state.board
        guard let point, let cell = Cell(containing: point), board.contains(cell) else {
            return .failure(Refusal(words: outsideWords))
        }
        guard let tile = board.tileIndex(at: cell), board.tiles[tile].kind.isTurnable,
              let position = board.turnableIndices.firstIndex(of: tile) else {
            return .failure(Refusal(words: nothingWords))
        }
        return .success((tile, position))
    }

    /// The words of a gesture that changed nothing.
    struct Refusal: Error, Equatable {
        /// The answer in words.
        let words: String
    }

    /// Applies one pointer event (view points, top-left origin). `state` reads the current maze state (nil before
    /// the first state: then nothing is sent), `toBoard` maps a view point to board units (nil off a usable canvas)
    /// and `send` carries out each action. Returns the words of the last refusal the event caused (a gesture that
    /// changed nothing, or an action `send` refused), or nil.
    @discardableResult
    mutating func handle(_ event: PointerEvent, state: () -> MazeState?, toBoard: (Vec2) -> Vec2?,
                         send: Send) -> String? {
        let finite = event.location.isFinite
        if finite, event.phase == .began || event.phase == .moved {
            if let index = fingers.firstIndex(where: { $0.id == event.id }) {
                fingers[index].at = event.location
            } else if event.phase == .began {
                fingers.append((event.id, event.location))
            }
        }
        var words: String?
        var started = false
        for outcome in arbiter.handle(event) {
            switch (outcome.gesture, outcome.phase) {
            case ("snap", .began):
                started = true
                guard outcome.values.count >= 4, let current = state() else { break }
                let latest = Vec2(outcome.values[0], outcome.values[1])
                let down = latest - Vec2(outcome.values[2], outcome.values[3])
                switch Self.turnable(at: toBoard(down), in: current) {
                case .success(let found):
                    guard let origin = toBoard(down) else { break }
                    drag = (event.id, found.tile, origin)
                    words = snap(to: toBoard(latest), state: state, send: send) ?? words
                case .failure(let refusal):
                    words = refusal.words
                }
            case ("snap", .ended), ("snap", .cancelled):
                drag = nil
            case ("twist", .began):
                started = true
                drag = nil
                guard fingers.count >= 2, let angle = outcome.values.first, let current = state() else { break }
                let first = fingers[0], second = fingers[1]
                let middle = (first.at + second.at) / 2
                guard let selected = current.selectedTileIndex else {
                    words = Self.selectFirstWords
                    break
                }
                guard case .success(let found) = Self.turnable(at: toBoard(middle), in: current),
                      found.tile == selected else {
                    words = Self.twistWords
                    break
                }
                twist = (first.id, second.id, second.at - first.at, angle)
                words = turnByTwist(send: send) ?? words
            case ("twist", .ended), ("twist", .cancelled):
                twist = nil
            case ("pick", .recognized):
                guard outcome.values.count >= 2, let current = state() else { break }
                let point = Vec2(outcome.values[0], outcome.values[1])
                words = pick(at: toBoard(point), state: current, send: send) ?? words
            default:
                break
            }
        }
        if !started, finite, event.phase == .moved {
            words = step(event, state: state, toBoard: toBoard, send: send) ?? words
        }
        if event.phase == .ended || event.phase == .cancelled {
            fingers.removeAll { $0.id == event.id }
            if drag?.id == event.id { drag = nil }
            if let t = twist, t.first == event.id || t.second == event.id { twist = nil }
        }
        return words
    }

    /// The tap at the board point `point`: selects or turns a turnable tile, else answers in words.
    private func pick(at point: Vec2?, state: MazeState, send: Send) -> String? {
        switch Self.turnable(at: point, in: state) {
        case .success(let found):
            if state.selection == found.position {
                return Self.answer("tile.turn", send("tile.turn", []))
            }
            return Self.answer("tile.select", send("tile.select", [Double(found.position)]))
        case .failure(let refusal):
            return refusal.words
        }
    }

    /// Snaps the dragged tile towards the latest point `latest` (board units): `tile.select` and `tile.turn` when the
    /// drag is long enough and the tile's orientation differs from the target; nothing otherwise.
    private func snap(to latest: Vec2?, state: () -> MazeState?, send: Send) -> String? {
        guard let current = drag, let latest, let target = Self.target(of: latest - current.origin),
              let now = state() else { return nil }
        let board = now.board
        guard board.tiles.indices.contains(current.tile), board.tiles[current.tile].kind.isTurnable,
              let position = board.turnableIndices.firstIndex(of: current.tile),
              board.tiles[current.tile].orientation != target else { return nil }
        let selected = send("tile.select", [Double(position)])
        guard selected.isAccepted else { return Self.answer("tile.select", selected) }
        return Self.answer("tile.turn", send("tile.turn", []))
    }

    /// Sends one `tile.turn` for every ±45° the twist accumulated since its last snap, moving the reference by 45°
    /// each time.
    private mutating func turnByTwist(send: Send) -> String? {
        guard var current = twist, current.angle.isFinite else { return nil }
        var words: String?
        while abs(current.angle) >= Self.snapAngle - 1e-12 {
            current.angle -= current.angle > 0 ? Self.snapAngle : -Self.snapAngle
            words = Self.answer("tile.turn", send("tile.turn", [])) ?? words
        }
        twist = current
        return words
    }

    /// The step of the owned drag or rotation that the move `event` makes.
    private mutating func step(_ event: PointerEvent, state: () -> MazeState?, toBoard: (Vec2) -> Vec2?,
                               send: Send) -> String? {
        var words: String?
        if let current = drag, current.id == event.id {
            words = snap(to: toBoard(event.location), state: state, send: send) ?? words
        }
        if let current = twist, current.first == event.id || current.second == event.id,
           let a = fingers.first(where: { $0.id == current.first }),
           let b = fingers.first(where: { $0.id == current.second }) {
            let vector = b.at - a.at
            if vector.length > 0, current.vector.length > 0 {
                // View points are y-down: negate so that counter-clockwise on screen is positive.
                let delta = -atan2(current.vector.cross(vector), current.vector.dot(vector))
                twist = (current.first, current.second, vector, current.angle + delta)
                words = turnByTwist(send: send) ?? words
            }
        }
        return words
    }

    /// The words of a refused action, or nil when it was accepted.
    private static func answer(_ control: String, _ result: ActionResult) -> String? {
        result.isAccepted ? nil : MazePresenter.answerWords(control: control, result: result)
    }

    /// Forgets every touch and the drag and rotation in progress; sends nothing.
    mutating func reset() {
        _ = arbiter.cancelAll()
        fingers = []
        drag = nil
        twist = nil
    }
}
