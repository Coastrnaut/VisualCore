// MazeState — feature 096 (A13-P01) T-A13-103 (FR-A13-122; clarification Q5; data-model "MazeState"); schema 2 with
// moves and undo: feature 098 (A13-P03) T-A13-302 (FR-A13-310, FR-A13-330; clarification Q3; data-model "Move",
// "MazeState"; contracts/progress.md). The saved state of Light Maze at snapshot schema 2: the level index (0…19, an
// index into `LevelCatalog.bundled`), the orientations of the level's turnable tiles in tile order, the selection (−1
// for none, else an index into those turnable tiles) and the moves made on the level (at most 64, oldest first).
//
// Written as JSON with sorted keys: `{"levelIndex", "moves": [{"after", "before", "tile"}, …], "orientations":
// ["slash" | "backslash", …], "schema": 2, "selection"}`. `decode(_:)` reads the schema first and refuses, in this
// order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, a missing or malformed key, a level index
//   outside the catalog, an orientation count other than the level's number of turnable tiles, a selection outside
//   −1…count − 1, or (schema 2) more than 64 moves, a move whose tile is outside the turnable tiles, whose `after` is
//   not the toggle of its `before`, or a tile whose last move's `after` differs from its orientation;
// - `newer-version`: a schema above 2 (whatever else the payload holds).
// A schema-1 payload (no `moves` key) migrates to schema 2 with no moves. A refusal changes nothing; the caller opens
// the first level (`MazeState.initial`).
//
// Choosing a level sets its starting orientations, clears the selection and empties the moves; turning toggles the
// selected tile and appends the move (the oldest dropped beyond 64); undoing restores the last move's `before`
// orientation exactly and removes that move; resetting restores the level's starting orientations, clears the
// selection and empties the moves. The beam is computed by the tracer from the level's board with the state's
// orientations; it is never stored.
import Foundation

/// Why a saved maze state was refused.
public enum MazeStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing, malformed or out-of-range key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``MazeState/schemaVersion``).
    case newerVersion = "newer-version"
}

/// One turn of a turnable tile: which tile, and its orientation before and after (after is the toggle of before).
public struct Move: Codable, Equatable, Sendable {
    /// The turnable tile's index (into ``MazeState/orientations``, like ``MazeState/selection``).
    public var tile: Int
    /// The tile's orientation before the turn.
    public var before: Orientation
    /// The tile's orientation after the turn.
    public var after: Orientation

    /// A move of turnable tile `tile` from `before` to `after`.
    public init(tile: Int, before: Orientation, after: Orientation) {
        self.tile = tile
        self.before = before
        self.after = after
    }
}

/// The state of a Light Maze session: level, orientations of its turnable tiles and selection.
public struct MazeState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes and reads.
    public static let schemaVersion = 2
    /// The most moves kept; turning beyond this drops the oldest.
    public static let maxMoves = 64
    /// The selection value for "no tile selected".
    public static let noSelection = -1
    /// The catalog the level index refers to.
    public static let catalog = LevelCatalog.bundled
    /// The first level in its starting orientations with nothing selected.
    public static let initial = MazeState(levelIndex: 0)

    /// The level index, 0…19.
    public private(set) var levelIndex: Int
    /// The orientations of the level's turnable tiles in tile order.
    public private(set) var orientations: [Orientation]
    /// The selected turnable tile's index (into ``orientations``), or ``noSelection``.
    public private(set) var selection: Int
    /// The moves made on the current level, oldest first (at most ``maxMoves``).
    public private(set) var moves: [Move]

    /// The level `levelIndex` (clamped into the catalog) in its starting orientations with nothing selected.
    public init(levelIndex: Int) {
        let index = min(max(levelIndex, 0), Self.catalog.levels.count - 1)
        self.levelIndex = index
        self.orientations = Self.catalog.levels[index].startOrientations
        self.selection = Self.noSelection
        self.moves = []
    }

    /// The current level.
    public var level: Level { Self.catalog.levels[levelIndex] }

    /// The current level's board with the state's orientations.
    public var board: Board { level.board.applying(orientations) ?? level.board }

    /// The beam of the current board.
    public var beam: Beam { BeamTracer.trace(board) }

    /// True when every target of the current board is lit.
    public var isSolved: Bool { beam.isSolved }

    /// The selected turnable tile's index in `board.tiles`, if any.
    public var selectedTileIndex: Int? {
        let indices = level.board.turnableIndices
        return indices.indices.contains(selection) ? indices[selection] : nil
    }

    /// Chooses level `index` in its starting orientations with nothing selected and no moves; false, with nothing
    /// changed, for an index outside the catalog.
    @discardableResult
    public mutating func selectLevel(_ index: Int) -> Bool {
        guard Self.catalog.levels.indices.contains(index) else { return false }
        self = MazeState(levelIndex: index)
        return true
    }

    /// Selects turnable tile `index` (an index into ``orientations``); false, with nothing changed, for any other index.
    @discardableResult
    public mutating func selectTile(_ index: Int) -> Bool {
        guard orientations.indices.contains(index) else { return false }
        selection = index
        return true
    }

    /// Toggles the selected tile's orientation and appends the move (dropping the oldest beyond ``maxMoves``); false,
    /// with nothing changed, when nothing is selected.
    @discardableResult
    public mutating func turnSelected() -> Bool {
        guard orientations.indices.contains(selection) else { return false }
        let before = orientations[selection]
        let after = before.toggled
        orientations[selection] = after
        moves.append(Move(tile: selection, before: before, after: after))
        if moves.count > Self.maxMoves {
            moves.removeFirst(moves.count - Self.maxMoves)
        }
        return true
    }

    /// Restores the last move's `before` orientation on its tile and removes that move; the selection is unchanged.
    /// False, with nothing changed, when there are no moves.
    @discardableResult
    public mutating func undo() -> Bool {
        guard let last = moves.last, orientations.indices.contains(last.tile) else { return false }
        orientations[last.tile] = last.before
        moves.removeLast()
        return true
    }

    /// Restores the level's starting orientations, clears the selection and empties the moves.
    public mutating func reset() {
        self = MazeState(levelIndex: levelIndex)
    }

    private enum CodingKeys: String, CodingKey { case levelIndex, moves, orientations, schema, selection }

    /// Decodes a schema-2 state, or a schema-1 state migrated with no moves; throws for another schema or any value
    /// ``decode(_:)`` refuses as damaged.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        levelIndex = try c.decode(Int.self, forKey: .levelIndex)
        orientations = try c.decode([Orientation].self, forKey: .orientations)
        selection = try c.decode(Int.self, forKey: .selection)
        moves = schema == 1 ? [] : try c.decode([Move].self, forKey: .moves)
        guard schema >= Self.oldestReadableSchema, schema <= Self.schemaVersion,
              Self.catalog.levels.indices.contains(levelIndex),
              orientations.count == Self.catalog.levels[levelIndex].turnableCount,
              selection == Self.noSelection || orientations.indices.contains(selection),
              Self.movesAreConsistent(moves, orientations) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "not a valid maze state"))
        }
    }

    /// Encodes the state at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(levelIndex, forKey: .levelIndex)
        try c.encode(moves, forKey: .moves)
        try c.encode(orientations, forKey: .orientations)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(selection, forKey: .selection)
    }

    /// True when `moves` fit `orientations`: at most ``maxMoves``, each on a turnable tile with `after` the toggle of
    /// `before`, and each tile's last move ending in its current orientation.
    static func movesAreConsistent(_ moves: [Move], _ orientations: [Orientation]) -> Bool {
        guard moves.count <= maxMoves else { return false }
        var lastAfter: [Int: Orientation] = [:]
        for move in moves {
            guard orientations.indices.contains(move.tile), move.after == move.before.toggled else { return false }
            lastAfter[move.tile] = move.after
        }
        for (tile, after) in lastAfter where orientations[tile] != after {
            return false
        }
        return true
    }

    /// The state as JSON with sorted keys (deterministic bytes for equal states).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The oldest schema ``decode(_:)`` still reads (migrated to ``schemaVersion`` with no moves).
    public static let oldestReadableSchema = 1

    /// The state in `data`, or the reason it is refused (see the file header for the order of the checks); a schema-1
    /// payload is migrated to schema 2 with no moves.
    public static func decode(_ data: Data) -> Result<MazeState, MazeStateRefusal> {
        struct Header: Decodable { var schema: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= oldestReadableSchema else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let state = try? decoder.decode(MazeState.self, from: data) else { return .failure(.damaged) }
        return .success(state)
    }
}
