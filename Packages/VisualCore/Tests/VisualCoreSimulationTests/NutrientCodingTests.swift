// NutrientCodingTests — feature 221 (R02-F21) T-R02F21-005 (FR-R02F21-007, 008; clarification Q5; SC-R02F21-006). The
// stored form round-trips byte for byte, a reopened field continues bit-identically for 200 frames with sources, sinks,
// decay and growth, and newer, damaged, rule-breaking and unbalanced forms are refused with stable reason codes.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct NutrientCodingTests {
    /// A seeded 24 × 16 field with three channels, amounts, sources and sinks with nonzero carries, bands, decay, and a
    /// network of two seeds and grown cells, with eaten and faded quanta in the ledger.
    static func fixture() throws -> NutrientField {
        var random = SeededRandom(seed: 2_021)
        let diffusion: [Double] = [0.8, 2.5, 0.3]
        let decay: [Double] = [0, 0.05, 0.2]
        var field = try NutrientField(width: 24, height: 16, channels: 3, diffusion: diffusion, decay: decay)
        let unit: Int64 = NutrientField.quantaPerUnit
        for c in 0..<field.cellCount {
            try field.add(Int64(random.int(0...196_608)), channel: 0, at: c)
            if random.int(0...2) == 0 { try field.add(Int64(random.int(0...500_000)), channel: 1, at: c) }
            if random.int(0...3) == 0 { try field.add(Int64(random.int(0...90_000)), channel: 2, at: c) }
        }
        try field.addSource(try NutrientSource(cell: field.cell(x: 3, y: 4), channel: 0, kind: .source, rate: 2.5,
                                               carry: 0.25))
        try field.addSource(try NutrientSource(cell: field.cell(x: 20, y: 11), channel: 1, kind: .sink, rate: 1.75,
                                               carry: 0.625))
        try field.addSource(try NutrientSource(cell: field.cell(x: 12, y: 8), channel: 2, kind: .source, rate: 0.5,
                                               carry: 0.125))
        try field.addSource(try NutrientSource(cell: field.cell(x: 7, y: 13), channel: 0, kind: .sink, rate: 0.3,
                                               carry: 0.875))
        try field.setBand(try ViabilityBand(low: 0.5, high: 3, ramp: 0.5), channel: 0)
        try field.setBand(try ViabilityBand(low: 0, high: 12, ramp: 1), channel: 2)

        var network = try GrowthNetwork(limit: 300, perFrame: 3, threshold: 0.25, foodChannel: 0, cost: unit / 8)
        let seedA: Int = field.cell(x: 5, y: 5)
        let seedB: Int = field.cell(x: 17, y: 10)
        network.append(seedA, parent: -1)
        network.append(seedA + 1, parent: seedA)
        network.append(seedA + 1 + field.width, parent: seedA + 1)
        network.append(seedB, parent: -1)
        network.append(seedB - field.width, parent: seedB)
        try field.setNetwork(network)

        // Move some removed quanta to eaten and faded so every account counter is nonzero.
        let eaten: Int64 = try field.remove(unit / 8, channel: 0, at: seedA + 1)
        field.ledger.accounts[0].removed -= eaten
        field.ledger.accounts[0].eaten += eaten
        var faded: Int64 = 0
        for c in 0..<field.cellCount where field.amount(2, at: c) > 0 {
            faded += try field.remove(1_000, channel: 2, at: c)
        }
        field.ledger.accounts[2].removed -= faded
        field.ledger.accounts[2].faded += faded
        return field
    }

    /// The stored form as a mutable JSON object.
    static func object(_ field: NutrientField) throws -> [String: Any] {
        let parsed: Any = try JSONSerialization.jsonObject(with: field.encoded())
        return try #require(parsed as? [String: Any])
    }

    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func expectMalformed(_ data: Data, _ label: String) {
        do {
            _ = try NutrientField.decode(data)
            Issue.record("damaged form accepted: \(label)")
        } catch {
            #expect(error.reasonCode == "r2-f21.malformed", "\(label)")
            if case .malformed = error {} else { Issue.record("expected malformed for \(label), got \(error)") }
        }
    }

    /// The JSON object with `key` replaced.
    static func with(_ base: [String: Any], _ key: String, _ value: Any) -> [String: Any] {
        var copy: [String: Any] = base
        copy[key] = value
        return copy
    }

    @Test func roundTripIsByteIdentical() throws {
        let original: NutrientField = try Self.fixture()
        #expect(original.isBalanced)
        #expect(original.sources.count == 4)
        #expect(original.network?.count == 5)
        #expect(original.ledger.accounts[0].eaten > 0 && original.ledger.accounts[2].faded > 0)
        let bytes: Data = original.encoded()
        let decoded: NutrientField = try NutrientField.decode(bytes)
        #expect(decoded == original)
        #expect(decoded.encoded() == bytes)
        #expect(decoded.sources[1].carry == 0.625)
        #expect(decoded.network?.contains(original.cell(x: 5, y: 5)) == true)
        let text: String = try #require(String(data: bytes, encoding: .utf8))
        #expect(text.contains("\"schema\":1"))
        let keys: [String] = ["amounts", "bands", "channels", "decay", "diffusion", "height", "ledger", "network",
                              "schema", "sources", "width"]
        let json: [String: Any] = try Self.object(original)
        #expect(Set(json.keys) == Set(keys))
        // JSONDecoder on the type gives the same field.
        let viaDecoder: NutrientField = try JSONDecoder().decode(NutrientField.self, from: bytes)
        #expect(viaDecoder == original)
    }

    @Test func reopenedFieldContinuesBitIdentically() throws {
        var original: NutrientField = try Self.fixture()
        var reopened: NutrientField = try NutrientField.decode(original.encoded())
        var grown: Int = 0
        for _ in 0..<200 {
            let a: NutrientStepReport = try original.step(by: 1.0 / 60)
            let b: NutrientStepReport = try reopened.step(by: 1.0 / 60)
            #expect(a == b)
            grown += a.grown
        }
        #expect(grown > 0)
        #expect(original == reopened)
        #expect(original.encoded() == reopened.encoded())
        #expect(original.isBalanced && reopened.isBalanced)
        // And a field reopened after the run still round-trips.
        let again: NutrientField = try NutrientField.decode(original.encoded())
        #expect(again == original)
    }

    @Test func emptyFieldRoundTrips() throws {
        let empty = try NutrientField(width: 2, height: 2, diffusion: [0])
        let bytes: Data = empty.encoded()
        let decoded: NutrientField = try NutrientField.decode(bytes)
        #expect(decoded == empty)
        #expect(decoded.encoded() == bytes)
        let text: String = try #require(String(data: bytes, encoding: .utf8))
        #expect(text.contains("\"network\":null"))
        #expect(text.contains("\"bands\":[null]"))
    }

    @Test func newerSchemaIsRefused() throws {
        let json: [String: Any] = Self.with(try Self.object(try Self.fixture()), "schema", 2)
        let data: Data = try Self.data(json)
        #expect(throws: NutrientError.newerSchema(2)) { try NutrientField.decode(data) }
        #expect(NutrientError.newerSchema(2).reasonCode == "r2-f21.newer-schema")
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(NutrientField.self, from: data) }
    }

    @Test func damagedFormsAreMalformed() throws {
        let field: NutrientField = try Self.fixture()
        let bytes: Data = field.encoded()
        let base: [String: Any] = try Self.object(field)

        Self.expectMalformed(Data("not json".utf8), "not JSON")
        Self.expectMalformed(Data(), "empty")
        Self.expectMalformed(bytes.prefix(bytes.count / 2), "truncated")
        Self.expectMalformed(Data("[1, 2, 3]".utf8), "array")
        let keys: [String] = ["amounts", "bands", "channels", "decay", "diffusion", "height", "ledger", "network",
                              "schema", "sources", "width"]
        for key in keys {
            var missing: [String: Any] = base
            missing.removeValue(forKey: key)
            Self.expectMalformed(try Self.data(missing), "missing \(key)")
        }
        Self.expectMalformed(try Self.data(Self.with(base, "schema", 0)), "schema 0")
        Self.expectMalformed(try Self.data(Self.with(base, "width", 1)), "width 1")
        Self.expectMalformed(try Self.data(Self.with(base, "channels", 5)), "channels 5")
        Self.expectMalformed(try Self.data(Self.with(base, "diffusion", [0.8, -1, 0.3])), "negative diffusion")

        // An unmodified re-serialisation is still accepted.
        let same: NutrientField = try NutrientField.decode(try Self.data(base))
        #expect(same == field)
    }

    @Test func ruleBreakingAmountsAndLedgerAreMalformed() throws {
        let base: [String: Any] = try Self.object(try Self.fixture())
        let amounts: [[Int64]] = try #require(base["amounts"] as? [[Int64]])

        var negative: [[Int64]] = amounts
        negative[0][0] = -1
        Self.expectMalformed(try Self.data(Self.with(base, "amounts", negative)), "negative amount")

        var huge: [[Int64]] = amounts
        huge[1][2] = NutrientField.maxAmount + 1
        Self.expectMalformed(try Self.data(Self.with(base, "amounts", huge)), "amount over 2^40")

        var overTotal: [[Int64]] = amounts
        overTotal[2][0] = NutrientField.maxAmount
        overTotal[2][1] = 1
        Self.expectMalformed(try Self.data(Self.with(base, "amounts", overTotal)), "channel total over 2^40")

        var short: [[Int64]] = amounts
        short[0].removeLast()
        Self.expectMalformed(try Self.data(Self.with(base, "amounts", short)), "short channel")

        var unbalanced: [[Int64]] = amounts
        unbalanced[0][3] += 1
        Self.expectMalformed(try Self.data(Self.with(base, "amounts", unbalanced)), "unbalanced ledger")

        var ledger: [String: Any] = try #require(base["ledger"] as? [String: Any])
        var accounts: [[String: Any]] = try #require(ledger["accounts"] as? [[String: Any]])
        accounts[1]["added"] = (accounts[1]["added"] as? Int64 ?? 0) + 7
        ledger["accounts"] = accounts
        Self.expectMalformed(try Self.data(Self.with(base, "ledger", ledger)), "account changed")

        var negativeAccounts: [[String: Any]] = try #require((base["ledger"] as? [String: Any])?["accounts"]
            as? [[String: Any]])
        negativeAccounts[0]["faded"] = -5
        negativeAccounts[0]["added"] = (negativeAccounts[0]["added"] as? Int64 ?? 0) + 5
        let negativeLedger: [String: Any] = ["accounts": negativeAccounts]
        Self.expectMalformed(try Self.data(Self.with(base, "ledger", negativeLedger)), "negative counter")
    }

    @Test func ruleBreakingSourcesAndBandsAreMalformed() throws {
        let base: [String: Any] = try Self.object(try Self.fixture())
        let sources: [[String: Any]] = try #require(base["sources"] as? [[String: Any]])

        var carry: [[String: Any]] = sources
        carry[0]["carry"] = 1.5
        Self.expectMalformed(try Self.data(Self.with(base, "sources", carry)), "carry 1.5")

        var cell: [[String: Any]] = sources
        cell[1]["cell"] = 24 * 16
        Self.expectMalformed(try Self.data(Self.with(base, "sources", cell)), "source cell out of range")

        var channel: [[String: Any]] = sources
        channel[2]["channel"] = 3
        Self.expectMalformed(try Self.data(Self.with(base, "sources", channel)), "source channel out of range")

        var rate: [[String: Any]] = sources
        rate[0]["rate"] = 0
        Self.expectMalformed(try Self.data(Self.with(base, "sources", rate)), "source rate 0")

        var kind: [[String: Any]] = sources
        kind[0]["kind"] = "drain"
        Self.expectMalformed(try Self.data(Self.with(base, "sources", kind)), "unknown kind")

        let bands: [Any] = try #require(base["bands"] as? [Any])
        var inverted: [Any] = bands
        inverted[0] = ["low": 3.0, "high": 0.5, "ramp": 0.5]
        Self.expectMalformed(try Self.data(Self.with(base, "bands", inverted)), "band low > high")

        var ramp: [Any] = bands
        ramp[1] = ["low": 0.0, "high": 1.0, "ramp": -1.0]
        Self.expectMalformed(try Self.data(Self.with(base, "bands", ramp)), "negative ramp")

        var fewer: [Any] = bands
        fewer.removeLast()
        Self.expectMalformed(try Self.data(Self.with(base, "bands", fewer)), "band count")
    }

    @Test func ruleBreakingNetworksAreMalformed() throws {
        let field: NutrientField = try Self.fixture()
        let base: [String: Any] = try Self.object(field)
        let network: [String: Any] = try #require(base["network"] as? [String: Any])
        let cells: [Int] = try #require(network["cells"] as? [Int])
        let parents: [Int] = try #require(network["parents"] as? [Int])

        var outOfRange: [Int] = cells
        outOfRange[1] = field.cellCount
        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "cells", outOfRange))),
                             "network cell out of range")

        var repeated: [Int] = cells
        repeated[4] = cells[3]
        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "cells", repeated))),
                             "network cell repeated")

        var farParent: [Int] = parents
        farParent[2] = cells[0]  // cells[2] is a diagonal of cells[0], not a 4-neighbour.
        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "parents", farParent))),
                             "parent not a neighbour")

        var laterParent: [Int] = parents
        laterParent[1] = cells[2]  // A neighbour, but not an earlier network cell.
        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "parents", laterParent))),
                             "parent not earlier")

        // A wrap from the end of one row to the start of the next is not a neighbour.
        var wrapCells: [Int] = cells
        var wrapParents: [Int] = parents
        wrapCells.append(field.width - 1)
        wrapParents.append(-1)
        wrapCells.append(field.width)
        wrapParents.append(field.width - 1)
        let wrapped: [String: Any] = Self.with(Self.with(network, "cells", wrapCells), "parents", wrapParents)
        Self.expectMalformed(try Self.data(Self.with(base, "network", wrapped)), "row wrap parent")

        var shortParents: [Int] = parents
        shortParents.removeLast()
        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "parents", shortParents))),
                             "parents count")

        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "limit", 2))),
                             "over the limit")
        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "foodChannel", 3))),
                             "food channel")
        Self.expectMalformed(try Self.data(Self.with(base, "network", Self.with(network, "threshold", 0))),
                             "threshold 0")

        // No network at all is fine.
        let none: NutrientField = try NutrientField.decode(try Self.data(Self.with(base, "network", NSNull())))
        #expect(none.network == nil)
    }

    @Test func jsonDecoderRefusesBrokenRules() throws {
        let base: [String: Any] = try Self.object(try Self.fixture())
        var sources: [[String: Any]] = try #require(base["sources"] as? [[String: Any]])
        sources[0]["carry"] = 1.5
        let data: Data = try Self.data(Self.with(base, "sources", sources))
        do {
            _ = try JSONDecoder().decode(NutrientField.self, from: data)
            Issue.record("broken rule accepted by JSONDecoder")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(context.debugDescription == "r2-f21.malformed")
        }
        let width: Data = try Self.data(Self.with(base, "width", 1))
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(NutrientField.self, from: width) }
    }
}
