// TerrainSettings — feature 218 (R02-F18) T-R02F18-002 (FR-R02F18-001, FR-R02F18-007; clarifications Q1, Q2, Q5;
// data-model.md). The size and detail rules of a square terrain: P × P pieces of C × C base cells of size s, L levels
// (level ℓ samples every 2^ℓ base cells), one level per distance D, and a vertex budget. Stored as JSON schema 1 with
// sorted keys; a newer schema is refused, damaged or out-of-range data is refused as malformed or by the matching code.
import Foundation

/// The size and detail rules of a square, piecewise terrain.
public struct TerrainSettings: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema = 1
    /// The default vertex budget, ``MeshBudget/default``'s vertex limit.
    public static let defaultVertexBudget = 262_144

    /// Pieces per side P, 1 … 64.
    public let pieces: Int
    /// Base cells per piece side C, a power of two in 4 … 128.
    public let pieceCells: Int
    /// The base cell size s, finite and positive.
    public let cellSize: Double
    /// The number of levels L, 1 … log₂ C; level ℓ samples every 2^ℓ base cells.
    public let levels: Int
    /// The distance per level D, finite and positive.
    public let levelDistance: Double
    /// The most vertices all pieces together may have, 1 … 4,194,304.
    public let vertexBudget: Int

    /// Creates the settings or refuses a value outside its range with the matching ``TerrainError``.
    public init(pieces: Int, pieceCells: Int, cellSize: Double, levels: Int, levelDistance: Double,
                vertexBudget: Int = TerrainSettings.defaultVertexBudget) throws(TerrainError) {
        guard (1...64).contains(pieces) else { throw .terrainSize(pieces) }
        guard (4...128).contains(pieceCells), pieceCells & (pieceCells - 1) == 0 else { throw .pieceSize(pieceCells) }
        let maxLevels = pieceCells.trailingZeroBitCount
        guard (1...maxLevels).contains(levels) else { throw .levelCount(levels) }
        guard cellSize.isFinite, cellSize > 0, levelDistance.isFinite, levelDistance > 0 else { throw .levelDistance }
        guard (1...4_194_304).contains(vertexBudget) else { throw .budget(vertexBudget) }
        self.pieces = pieces
        self.pieceCells = pieceCells
        self.cellSize = cellSize
        self.levels = levels
        self.levelDistance = levelDistance
        self.vertexBudget = vertexBudget
    }

    /// The side of the whole terrain, pieces · pieceCells · cellSize.
    public var size: Double { Double(pieces * pieceCells) * cellSize }

    /// The stored form: JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Integers and finite doubles only, so encoding cannot fail.
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Reads stored settings; refuses a newer schema, damaged data and values outside their ranges.
    public static func decode(_ data: Data) throws(TerrainError) -> TerrainSettings {
        do {
            return try JSONDecoder().decode(TerrainSettings.self, from: data)
        } catch let error as TerrainError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }
}

extension TerrainSettings: Codable {
    private enum Key: String, CodingKey { case schema, pieces, pieceCells, cellSize, levels, levelDistance, vertexBudget }

    /// Reads the stored form (see ``decode(_:)``).
    public init(from decoder: any Decoder) throws {
        let c: KeyedDecodingContainer<Key>
        let schemaValue: Int
        do {
            c = try decoder.container(keyedBy: Key.self)
            schemaValue = try c.decode(Int.self, forKey: .schema)
        } catch {
            throw TerrainError.malformed(String(describing: error))
        }
        guard schemaValue <= Self.schema else { throw TerrainError.newerSchema(schemaValue) }
        guard schemaValue == Self.schema else { throw TerrainError.malformed("schema \(schemaValue)") }
        do {
            try self.init(pieces: try c.decode(Int.self, forKey: .pieces),
                          pieceCells: try c.decode(Int.self, forKey: .pieceCells),
                          cellSize: try c.decode(Double.self, forKey: .cellSize),
                          levels: try c.decode(Int.self, forKey: .levels),
                          levelDistance: try c.decode(Double.self, forKey: .levelDistance),
                          vertexBudget: try c.decode(Int.self, forKey: .vertexBudget))
        } catch let error as TerrainError {
            throw error
        } catch {
            throw TerrainError.malformed(String(describing: error))
        }
    }

    /// Writes the stored form with the schema.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(pieces, forKey: .pieces)
        try c.encode(pieceCells, forKey: .pieceCells)
        try c.encode(cellSize, forKey: .cellSize)
        try c.encode(levels, forKey: .levels)
        try c.encode(levelDistance, forKey: .levelDistance)
        try c.encode(vertexBudget, forKey: .vertexBudget)
    }
}
