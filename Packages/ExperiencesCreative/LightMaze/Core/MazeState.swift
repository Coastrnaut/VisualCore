// MazeState — feature 096 (A13-P01) T-A13-103 (FR-A13-122; clarification Q5; data-model "MazeState"). The saved state
// of Light Maze at snapshot schema 1: the level index (0…19, an index into `LevelCatalog.bundled`), the orientations of
// the level's turnable tiles in tile order and the selection (−1 for none, else an index into those turnable tiles).
//
// Written as JSON with sorted keys: `{"levelIndex", "orientations": ["slash" | "backslash", …], "schema": 1,
// "selection"}`. `decode(_:)` reads the schema first and refuses, in this order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, a missing or malformed key, a level index
//   outside the catalog, an orientation count other than the level's number of turnable tiles, or a selection outside
//   −1…count − 1;
// - `newer-version`: a schema above 1 (whatever else the payload holds).
// A refusal changes nothing; the caller opens the first level (`MazeState.initial`).
//
// Choosing a level sets its starting orientations and clears the selection; turning toggles the selected tile;
// resetting restores the level's starting orientations and clears the selection. The beam is computed by the tracer
// from the level's board with the state's orientations; it is never stored.
import Foundation

/// Why a saved maze state was refused.
public enum MazeStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing, malformed or out-of-range key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``MazeState/schemaVersion``).
    case newerVersion = "newer-version"
}

/// The state of a Light Maze session: level, orientations of its turnable tiles and selection.
public struct MazeState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes and reads.
    public static let schemaVersion = 1
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

    /// The level `levelIndex` (clamped into the catalog) in its starting orientations with nothing selected.
    public init(levelIndex: Int) {
        let index = min(max(levelIndex, 0), Self.catalog.levels.count - 1)
        self.levelIndex = index
        self.orientations = Self.catalog.levels[index].startOrientations
        self.selection = Self.noSelection
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

    /// Chooses level `index` in its starting orientations with nothing selected; false, with nothing changed, for an
    /// index outside the catalog.
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

    /// Toggles the selected tile's orientation; false, with nothing changed, when nothing is selected.
    @discardableResult
    public mutating func turnSelected() -> Bool {
        guard orientations.indices.contains(selection) else { return false }
        orientations[selection] = orientations[selection].toggled
        return true
    }

    /// Restores the level's starting orientations and clears the selection.
    public mutating func reset() {
        self = MazeState(levelIndex: levelIndex)
    }

    private enum CodingKeys: String, CodingKey { case levelIndex, orientations, schema, selection }

    /// Decodes a schema-1 state, throwing for another schema or any value ``decode(_:)`` refuses as damaged.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        levelIndex = try c.decode(Int.self, forKey: .levelIndex)
        orientations = try c.decode([Orientation].self, forKey: .orientations)
        selection = try c.decode(Int.self, forKey: .selection)
        guard schema == Self.schemaVersion, Self.catalog.levels.indices.contains(levelIndex),
              orientations.count == Self.catalog.levels[levelIndex].turnableCount,
              selection == Self.noSelection || orientations.indices.contains(selection) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "not a valid maze state"))
        }
    }

    /// Encodes the state at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(levelIndex, forKey: .levelIndex)
        try c.encode(orientations, forKey: .orientations)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(selection, forKey: .selection)
    }

    /// The state as JSON with sorted keys (deterministic bytes for equal states).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The state in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<MazeState, MazeStateRefusal> {
        struct Header: Decodable { var schema: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= schemaVersion else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let state = try? decoder.decode(MazeState.self, from: data) else { return .failure(.damaged) }
        return .success(state)
    }
}
