// GardenHistory — feature 145 (A20-P01) T-A20-108 (FR-A20-105, FR-A20-106; clarification Q4). Every edit of the
// garden is a command that records what its undo needs: `rake`, `place`, `move`, `rotate`, `remove` (the removed stone
// with its depth) and `tone`. A command is validated against the current document and refused without a change;
// undo and redo apply exact inverses and move commands between the two lists, and a new command clears redo. At most
// 100 commands stay undoable: the oldest folds into the checkpoint (a document and its reference sand field), and the
// field is rebuilt from the checkpoint by replaying the rake strokes. No texture snapshot, GPU, network or clock.
import Foundation
import VisualCoreMath

/// One undoable edit of the garden, carrying everything its exact inverse needs.
public enum GardenCommand: Codable, Equatable, Sendable {
    /// Rakes a stroke into the sand (appended to the document's strokes).
    case rake(RakeStroke)
    /// Places a stone; its id is the document's `nextStoneID` and its depth is unique.
    case place(Stone)
    /// Moves the stone `id` from its current position `from` to `to`.
    case move(id: UInt32, from: Vec2, to: Vec2)
    /// Rotates the stone `id` from its current rotation `from` to `to` (radians, normalized into −π…π).
    case rotate(id: UInt32, from: Double, to: Double)
    /// Removes a stone; the value is the removed stone with its depth, so the undo re-inserts it exactly.
    case remove(Stone)
    /// Changes the sand tone from `from` (the current tone) to `to`.
    case tone(from: String, to: String)
}

/// The command history of a garden: the current document, a checkpoint, the undoable commands (at most
/// ``maxUndo``) and the undone commands that redo can re-apply.
///
/// The stones of ``document`` are kept in depth order (ascending), so removing a stone and undoing the removal gives
/// an equal document.
public struct GardenHistory: Equatable, Sendable {
    /// The most commands that stay undoable; older commands fold into the ``checkpoint``.
    public static let maxUndo = 100

    /// The state before the first command of ``done``: a document and its reference sand field.
    public struct Checkpoint: Equatable, Sendable {
        /// The document before the first undoable command.
        public var document: GardenDocument
        /// The reference sand field of ``document`` (its strokes replayed in order).
        public var field: SandField

        /// Creates a checkpoint.
        public init(document: GardenDocument, field: SandField) {
            self.document = document
            self.field = field
        }
    }

    /// The current garden: the checkpoint document with every command of ``done`` applied in order.
    public private(set) var document: GardenDocument
    /// The state before the first command of ``done``.
    public private(set) var checkpoint: Checkpoint
    /// The undoable commands, oldest first (at most ``maxUndo``).
    public private(set) var done: [GardenCommand]
    /// The undone commands, the next one to redo last.
    public private(set) var undone: [GardenCommand]

    /// Starts a history at `document` (its stones put in depth order); the checkpoint is that document and its
    /// replayed field, and both lists are empty.
    public init(document: GardenDocument = .empty) {
        var start = document
        start.stones.sort { $0.depth < $1.depth }
        self.document = start
        checkpoint = Checkpoint(document: start, field: SandField.replay(start.strokes))
        done = []
        undone = []
    }

    /// Whether there is a command to undo.
    public var canUndo: Bool { !done.isEmpty }
    /// Whether there is a command to redo.
    public var canRedo: Bool { !undone.isEmpty }

    /// The reference sand field of ``document``: the checkpoint field with every rake stroke of ``done`` applied in
    /// order. Stones do not change the sand in this phase.
    public func field() -> SandField {
        var field = checkpoint.field
        for command in done {
            if case let .rake(stroke) = command { field.apply(stroke) }
        }
        return field
    }

    // MARK: - Applying

    /// Validates `command` against the current document and applies it. On success the command is appended to
    /// ``done``, ``undone`` is cleared and, beyond ``maxUndo`` commands, the oldest folds into the checkpoint. A
    /// refused command changes nothing.
    ///
    /// Refusals: a rake with an unknown style (``DocumentRefusal/unknownRake(_:)``), no or more than 512 points or
    /// ``GardenDocument/maxStrokes`` strokes already (``DocumentRefusal/overCap(_:)``) or a point outside 0…1; a
    /// place of an unknown kind, a value out of range, ``GardenDocument/maxStones`` stones already, an id other than
    /// `nextStoneID` or a repeated depth; a move, rotate or remove of a missing id, a `from` (or removed stone) that
    /// is not the current value or a `to` out of range (a rotation is normalized into −π…π first); a tone change to
    /// an unknown tone or from a tone that is not the current one.
    @discardableResult
    public mutating func apply(_ command: GardenCommand) -> Result<Void, DocumentRefusal> {
        switch validated(command) {
        case let .failure(refusal):
            return .failure(refusal)
        case let .success(accepted):
            Self.forward(accepted, on: &document)
            done.append(accepted)
            undone.removeAll()
            fold()
            return .success(())
        }
    }

    /// Rakes the resampled stroke of a raw drag `points` with the rake style `rake`.
    @discardableResult
    public mutating func rake(_ points: [Vec2], rake: String = GardenPalette.defaultRakeID)
        -> Result<RakeStroke, DocumentRefusal> {
        switch StrokeResampler.resample(points) {
        case let .failure(refusal):
            return .failure(refusal)
        case let .success(out):
            let stroke = RakeStroke(rake: rake, points: out.points, capped: out.capped)
            return apply(.rake(stroke)).map { stroke }
        }
    }

    /// Places a stone of `kind` with the id `nextStoneID` and a depth above every stone (0 for the first).
    @discardableResult
    public mutating func placeStone(kind: String, position: Vec2, rotation: Double = 0, scale: Double = 1)
        -> Result<Stone, DocumentRefusal> {
        let depth = (document.stones.map(\.depth).max() ?? -1) + 1
        let stone = Stone(id: document.nextStoneID, kind: kind, position: position,
                          rotation: Self.normalized(rotation), scale: scale, depth: depth)
        return apply(.place(stone)).map { stone }
    }

    /// Moves the stone `id` to `position`.
    @discardableResult
    public mutating func moveStone(id: UInt32, to position: Vec2) -> Result<Void, DocumentRefusal> {
        guard let stone = document.stones.first(where: { $0.id == id }) else { return .failure(.outOfRange("id")) }
        return apply(.move(id: id, from: stone.position, to: position))
    }

    /// Rotates the stone `id` to `rotation` (radians, normalized into −π…π).
    @discardableResult
    public mutating func rotateStone(id: UInt32, to rotation: Double) -> Result<Void, DocumentRefusal> {
        guard let stone = document.stones.first(where: { $0.id == id }) else { return .failure(.outOfRange("id")) }
        return apply(.rotate(id: id, from: stone.rotation, to: rotation))
    }

    /// Removes the stone `id`.
    @discardableResult
    public mutating func removeStone(id: UInt32) -> Result<Void, DocumentRefusal> {
        guard let stone = document.stones.first(where: { $0.id == id }) else { return .failure(.outOfRange("id")) }
        return apply(.remove(stone))
    }

    /// Changes the sand tone to `tone`.
    @discardableResult
    public mutating func setTone(_ tone: String) -> Result<Void, DocumentRefusal> {
        apply(.tone(from: document.tone, to: tone))
    }

    // MARK: - Undo and redo

    /// Undoes the newest command exactly and moves it to ``undone``. Returns false and changes nothing when there is
    /// nothing to undo.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let command = done.popLast() else { return false }
        Self.backward(command, on: &document)
        undone.append(command)
        return true
    }

    /// Re-applies the newest undone command and moves it back to ``done``. Returns false and changes nothing when
    /// there is nothing to redo.
    @discardableResult
    public mutating func redo() -> Bool {
        guard let command = undone.popLast() else { return false }
        Self.forward(command, on: &document)
        done.append(command)
        fold()
        return true
    }

    // MARK: - Internals

    /// Folds the oldest commands into the checkpoint while ``done`` holds more than ``maxUndo``.
    private mutating func fold() {
        while done.count > Self.maxUndo {
            let oldest = done.removeFirst()
            Self.forward(oldest, on: &checkpoint.document)
            if case let .rake(stroke) = oldest { checkpoint.field.apply(stroke) }
        }
    }

    /// `angle` normalized into −π…π (a non-finite angle is returned unchanged and refused by the check).
    static func normalized(_ angle: Double) -> Double {
        guard angle.isFinite else { return angle }
        if Stone.rotationRange.contains(angle) { return angle }
        let wrapped = remainder(angle, 2 * Double.pi)
        return min(max(wrapped, -Double.pi), Double.pi)
    }

    private static func inUnit(_ point: Vec2) -> Bool {
        point.x.isFinite && point.y.isFinite && Stone.positionRange.contains(point.x)
            && Stone.positionRange.contains(point.y)
    }

    /// The command as it will be stored (rotations normalized), or the refusal.
    private func validated(_ command: GardenCommand) -> Result<GardenCommand, DocumentRefusal> {
        switch command {
        case let .rake(stroke):
            guard GardenPalette.rake(id: stroke.rake) != nil else { return .failure(.unknownRake(stroke.rake)) }
            guard !stroke.points.isEmpty, stroke.points.count <= RakeStroke.maxPoints else {
                return .failure(.overCap("points"))
            }
            for point in stroke.points where !Self.inUnit(point) { return .failure(.outOfRange("points")) }
            guard document.strokes.count < GardenDocument.maxStrokes else { return .failure(.overCap("strokes")) }
            return .success(command)
        case let .place(stone):
            guard GardenPalette.stone(id: stone.kind) != nil else { return .failure(.unknownStone(stone.kind)) }
            guard Self.inUnit(stone.position) else { return .failure(.outOfRange("position")) }
            var placed = stone
            placed.rotation = Self.normalized(stone.rotation)
            guard placed.rotation.isFinite, Stone.rotationRange.contains(placed.rotation) else {
                return .failure(.outOfRange("rotation"))
            }
            guard stone.scale.isFinite, Stone.scaleRange.contains(stone.scale) else {
                return .failure(.outOfRange("scale"))
            }
            guard document.stones.count < GardenDocument.maxStones else { return .failure(.overCap("stones")) }
            guard stone.id == document.nextStoneID, stone.id < UInt32.max else { return .failure(.outOfRange("id")) }
            guard !document.stones.contains(where: { $0.depth == stone.depth }) else {
                return .failure(.outOfRange("depth"))
            }
            return .success(.place(placed))
        case let .move(id, from, to):
            guard let stone = document.stones.first(where: { $0.id == id }) else { return .failure(.outOfRange("id")) }
            guard stone.position == from, Self.inUnit(to) else { return .failure(.outOfRange("position")) }
            return .success(command)
        case let .rotate(id, from, to):
            guard let stone = document.stones.first(where: { $0.id == id }) else { return .failure(.outOfRange("id")) }
            let angle = Self.normalized(to)
            guard stone.rotation == from, angle.isFinite, Stone.rotationRange.contains(angle) else {
                return .failure(.outOfRange("rotation"))
            }
            return .success(.rotate(id: id, from: from, to: angle))
        case let .remove(stone):
            guard let stored = document.stones.first(where: { $0.id == stone.id }), stored == stone else {
                return .failure(.outOfRange("id"))
            }
            return .success(command)
        case let .tone(from, to):
            guard GardenPalette.tone(id: to) != nil else { return .failure(.unknownTone(to)) }
            guard from == document.tone else { return .failure(.outOfRange("tone")) }
            return .success(command)
        }
    }

    /// Inserts `stone` into `stones` keeping the depth order.
    private static func insert(_ stone: Stone, into stones: inout [Stone]) {
        let index = stones.firstIndex { $0.depth > stone.depth } ?? stones.endIndex
        stones.insert(stone, at: index)
    }

    /// Applies a validated command to `document`.
    private static func forward(_ command: GardenCommand, on document: inout GardenDocument) {
        switch command {
        case let .rake(stroke):
            document.strokes.append(stroke)
        case let .place(stone):
            insert(stone, into: &document.stones)
            document.nextStoneID = stone.id + 1
        case let .move(id, _, to):
            if let index = document.stones.firstIndex(where: { $0.id == id }) { document.stones[index].position = to }
        case let .rotate(id, _, to):
            if let index = document.stones.firstIndex(where: { $0.id == id }) { document.stones[index].rotation = to }
        case let .remove(stone):
            document.stones.removeAll { $0.id == stone.id }
        case let .tone(_, to):
            document.tone = to
        }
    }

    /// Applies the exact inverse of a command that was the last one applied to `document`.
    private static func backward(_ command: GardenCommand, on document: inout GardenDocument) {
        switch command {
        case .rake:
            document.strokes.removeLast()
        case let .place(stone):
            document.stones.removeAll { $0.id == stone.id }
            document.nextStoneID = stone.id
        case let .move(id, from, _):
            if let index = document.stones.firstIndex(where: { $0.id == id }) {
                document.stones[index].position = from
            }
        case let .rotate(id, from, _):
            if let index = document.stones.firstIndex(where: { $0.id == id }) {
                document.stones[index].rotation = from
            }
        case let .remove(stone):
            insert(stone, into: &document.stones)
        case let .tone(from, _):
            document.tone = from
        }
    }
}
