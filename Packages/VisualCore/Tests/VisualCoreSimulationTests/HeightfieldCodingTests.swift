// HeightfieldCodingTests — feature 217 (R02-F17) T-R02F17-006 (FR-R02F17-007, FR-R02F17-009; SC-R02F17-005). The
// stored form round-trips byte for byte, a reopened state continues bit-identically, and newer or damaged forms are
// refused with stable reason codes.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct HeightfieldCodingTests {
    /// A seeded 16 × 12 open-edged grid with terrain, water, two dyes and erosion, stepped a few frames.
    static func fixture() throws -> Heightfield {
        var random = SeededRandom(seed: 2_017)
        var parameters = HeightfieldParameters()
        parameters.erosion = true
        var field = try Heightfield(width: 16, height: 12, dyeChannels: 2, edges: .open, parameters: parameters)
        for y in 0..<field.height {
            for x in 0..<field.width {
                let c: Int = field.cell(x: x, y: y)
                let slope: Int64 = Int64(field.width - x) * 20_000
                try field.add(terrain: slope + Int64(random.int(0...40_000)), at: c)
                try field.add(water: Int64(random.int(0...90_000)), at: c)
                if random.int(0...3) == 0 { try field.add(dye: Int64(random.int(0...50_000)), channel: 0, at: c) }
                if random.int(0...3) == 0 { try field.add(dye: Int64(random.int(0...50_000)), channel: 1, at: c) }
            }
        }
        for _ in 0..<20 { _ = try field.step(by: 1.0 / 60) }
        return field
    }

    /// The stored form as a mutable JSON object.
    static func object(_ field: Heightfield) throws -> [String: Any] {
        let parsed: Any = try JSONSerialization.jsonObject(with: field.encoded())
        return try #require(parsed as? [String: Any])
    }

    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func expectMalformed(_ data: Data) {
        do {
            _ = try Heightfield.decode(data)
            Issue.record("damaged state was accepted")
        } catch {
            #expect(error.reasonCode == "r2-f17.malformed")
            if case .malformed = error {} else { Issue.record("expected malformed, got \(error)") }
        }
    }

    @Test func roundTripIsByteIdentical() throws {
        let original: Heightfield = try Self.fixture()
        #expect(original.isBalanced)
        #expect(original.totalRock > 0 && original.totalWater > 0)
        let bytes: Data = original.encoded()
        #expect(!bytes.isEmpty)
        let decoded: Heightfield = try Heightfield.decode(bytes)
        #expect(decoded == original)
        #expect(decoded.encoded() == bytes)
        let text: String = try #require(String(data: bytes, encoding: .utf8))
        #expect(text.contains("\"schema\":1"))
        // Sorted keys: the top-level keys appear in alphabetical order.
        let keys: [String] = ["dye", "dyeChannels", "edges", "fluxes", "height", "ledger", "parameters", "schema",
                              "sediment", "terrain", "water", "width"]
        var last: String.Index = text.startIndex
        for key in keys {
            let range: Range<String.Index>? = text.range(of: "\"\(key)\":", range: last..<text.endIndex)
            #expect(range != nil, "key \(key) out of order")
            if let range { last = range.upperBound }
        }
        let json: [String: Any] = try Self.object(original)
        #expect(json["schema"] as? Int == Heightfield.schema)
    }

    @Test func reopenedStateContinuesBitIdentically() throws {
        var original: Heightfield = try Self.fixture()
        var reopened: Heightfield = try Heightfield.decode(original.encoded())
        for _ in 0..<200 {
            let a: HeightfieldStepReport = try original.step(by: 1.0 / 60)
            let b: HeightfieldStepReport = try reopened.step(by: 1.0 / 60)
            #expect(a == b)
        }
        #expect(original == reopened)
        #expect(original.encoded() == reopened.encoded())
        #expect(original.isBalanced && reopened.isBalanced)
    }

    @Test func newerSchemaIsRefused() throws {
        var json: [String: Any] = try Self.object(try Self.fixture())
        json["schema"] = 2
        let data: Data = try Self.data(json)
        #expect(throws: HeightfieldError.newerSchema(2)) { try Heightfield.decode(data) }
        #expect(HeightfieldError.newerSchema(2).reasonCode == "r2-f17.newer-schema")
    }

    @Test func damagedFormsAreMalformed() throws {
        let field: Heightfield = try Self.fixture()
        let bytes: Data = field.encoded()
        let base: [String: Any] = try Self.object(field)

        // Empty data, truncated JSON, not an object.
        Self.expectMalformed(Data())
        Self.expectMalformed(bytes.prefix(bytes.count / 2))
        Self.expectMalformed(Data("[1, 2, 3]".utf8))

        // Missing schema.
        var noSchema: [String: Any] = base
        noSchema.removeValue(forKey: "schema")
        Self.expectMalformed(try Self.data(noSchema))

        // Missing array.
        var noFluxes: [String: Any] = base
        noFluxes.removeValue(forKey: "fluxes")
        Self.expectMalformed(try Self.data(noFluxes))

        // Wrong array size: one water value dropped.
        var short: [String: Any] = base
        var water: [Int64] = try #require(base["water"] as? [Int64])
        water.removeLast()
        short["water"] = water
        Self.expectMalformed(try Self.data(short))

        // Negative amount.
        var negative: [String: Any] = base
        var terrain: [Int64] = try #require(base["terrain"] as? [Int64])
        terrain[0] = -1
        negative["terrain"] = terrain
        Self.expectMalformed(try Self.data(negative))

        // Amount above 2⁴⁰.
        var huge: [String: Any] = base
        var sediment: [Int64] = try #require(base["sediment"] as? [Int64])
        sediment[0] = Heightfield.maxAmount + 1
        huge["sediment"] = sediment
        Self.expectMalformed(try Self.data(huge))

        // Flux out of range, negative and above the limit.
        var fluxHigh: [String: Any] = base
        var fluxes: [Double] = try #require(base["fluxes"] as? [Double])
        fluxes[0] = Heightfield.maxFlux * 2
        fluxHigh["fluxes"] = fluxes
        Self.expectMalformed(try Self.data(fluxHigh))
        var fluxLow: [String: Any] = base
        fluxes[0] = -1
        fluxLow["fluxes"] = fluxes
        Self.expectMalformed(try Self.data(fluxLow))

        // Unbalanced ledger: one water value changed.
        var unbalanced: [String: Any] = base
        var changed: [Int64] = try #require(base["water"] as? [Int64])
        changed[3] += 1
        unbalanced["water"] = changed
        Self.expectMalformed(try Self.data(unbalanced))

        // An unmodified re-serialisation is still accepted.
        let same: Heightfield = try Heightfield.decode(try Self.data(base))
        #expect(same.isBalanced)
    }

    @Test func storedFormKeepsTheInitialiserRefusals() throws {
        var json: [String: Any] = try Self.object(try Self.fixture())
        json["width"] = 3
        let small: Data = try Self.data(json)
        #expect(throws: HeightfieldError.gridSize) { try Heightfield.decode(small) }
    }
}
