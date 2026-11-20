// Heightfield+Coding — feature 217 (R02-F17) T-R02F17-006 (FR-R02F17-007; clarification Q5). The stored form: JSON
// schema 1 with sorted keys holding the size, edges, parameters, ledger, every quantity in quanta and every flux, so a
// reopened state continues bit-identically. Schema 1 is the first stored form (a later one adds a `MigrationChain`
// step in the consuming experience); a newer schema is refused, and so is any state whose arrays have the wrong size,
// whose amounts leave 0 … 2⁴⁰, whose fluxes leave 0 … maxFlux or whose totals do not match its ledger.
import Foundation

extension Heightfield: Codable {
    private enum Key: String, CodingKey {
        case schema, width, height, dyeChannels, edges, parameters, ledger, terrain, water, sediment, dye, fluxes
    }

    /// Reads the stored form; throws ``HeightfieldError/newerSchema(_:)`` for a schema above ``schema`` and
    /// ``HeightfieldError/malformed(_:)`` (or the size, channel and parameter refusals of the initialiser) otherwise.
    public init(from decoder: any Decoder) throws {
        let c: KeyedDecodingContainer<Key>
        let schemaValue: Int
        do {
            c = try decoder.container(keyedBy: Key.self)
            schemaValue = try c.decode(Int.self, forKey: .schema)
        } catch {
            throw HeightfieldError.malformed(String(describing: error))
        }
        guard schemaValue <= Self.schema else { throw HeightfieldError.newerSchema(schemaValue) }
        guard schemaValue == Self.schema else { throw HeightfieldError.malformed("schema \(schemaValue)") }
        do {
            try self.init(width: try c.decode(Int.self, forKey: .width), height: try c.decode(Int.self, forKey: .height),
                          dyeChannels: try c.decode(Int.self, forKey: .dyeChannels),
                          edges: try c.decode(HeightfieldEdges.self, forKey: .edges),
                          parameters: try c.decode(HeightfieldParameters.self, forKey: .parameters))
            ledger = try c.decode(HeightfieldLedger.self, forKey: .ledger)
            terrainQ = try c.decode([Int64].self, forKey: .terrain)
            waterQ = try c.decode([Int64].self, forKey: .water)
            sedimentQ = try c.decode([Int64].self, forKey: .sediment)
            dyeQ = try c.decode([Int64].self, forKey: .dye)
            fluxes = try c.decode([Double].self, forKey: .fluxes)
        } catch let error as HeightfieldError {
            throw error
        } catch {
            throw HeightfieldError.malformed(String(describing: error))
        }
        let cells = cellCount
        guard terrainQ.count == cells, waterQ.count == cells, sedimentQ.count == cells,
              dyeQ.count == cells * dyeChannels, fluxes.count == cells * 4, ledger.dye.count == dyeChannels else {
            throw HeightfieldError.malformed("array sizes")
        }
        for array in [terrainQ, waterQ, sedimentQ, dyeQ] where !array.allSatisfy({ $0 >= 0 && $0 <= Self.maxAmount }) {
            throw HeightfieldError.malformed("amount out of range")
        }
        guard fluxes.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= Self.maxFlux }) else {
            throw HeightfieldError.malformed("flux out of range")
        }
        guard isBalanced else { throw HeightfieldError.malformed("ledger") }
    }

    /// Writes the stored form.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(dyeChannels, forKey: .dyeChannels)
        try c.encode(edges, forKey: .edges)
        try c.encode(parameters, forKey: .parameters)
        try c.encode(ledger, forKey: .ledger)
        try c.encode(terrainQ, forKey: .terrain)
        try c.encode(waterQ, forKey: .water)
        try c.encode(sedimentQ, forKey: .sediment)
        try c.encode(dyeQ, forKey: .dye)
        try c.encode(fluxes, forKey: .fluxes)
    }

    /// The stored form: JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Integers, finite doubles and strings only, so encoding cannot fail.
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Reads a stored state (see ``init(from:)``).
    public static func decode(_ data: Data) throws(HeightfieldError) -> Heightfield {
        do {
            return try JSONDecoder().decode(Heightfield.self, from: data)
        } catch let error as HeightfieldError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }
}
