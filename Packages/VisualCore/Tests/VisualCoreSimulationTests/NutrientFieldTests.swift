// NutrientFieldTests — feature 221 (R02-F21) T-R02F21-002 (FR-R02F21-002, 003, 004, 008; SC-R02F21-004; clarifications
// Q1, Q3, Q4, Q5). Refusals and reason codes; add and remove limits with the ledger; sources, bands and seeds; viability
// 1 inside every band, 0 outside any band and strictly between in a ramp for 1,000 seeded cells; FieldGrid hand-offs.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct NutrientFieldTests {
    static let unit: Int64 = NutrientField.quantaPerUnit

    @Test func refusalsAndCodes() throws {
        #expect(throws: NutrientError.gridSize) { try NutrientField(width: 1, height: 4, diffusion: [1]) }
        #expect(throws: NutrientError.gridSize) { try NutrientField(width: 513, height: 4, diffusion: [1]) }
        _ = try NutrientField(width: 512, height: 512, diffusion: [1])
        #expect(throws: NutrientError.channel(0)) { try NutrientField(width: 4, height: 4, channels: 0, diffusion: []) }
        #expect(throws: NutrientError.channel(5)) {
            try NutrientField(width: 4, height: 4, channels: 5, diffusion: [1, 1, 1, 1, 1])
        }
        #expect(throws: NutrientError.parameter("diffusion")) { try NutrientField(width: 4, height: 4, diffusion: [1_001]) }
        #expect(throws: NutrientError.parameter("diffusion")) { try NutrientField(width: 4, height: 4, diffusion: [.nan]) }
        #expect(throws: NutrientError.parameter("diffusion")) {
            try NutrientField(width: 4, height: 4, channels: 2, diffusion: [1])
        }
        #expect(throws: NutrientError.parameter("decay")) {
            try NutrientField(width: 4, height: 4, diffusion: [1], decay: [100.5])
        }
        #expect(throws: NutrientError.parameter("decay")) { try NutrientField(width: 4, height: 4, diffusion: [1], decay: [-1]) }
        #expect(throws: NutrientError.parameter("rate")) { try NutrientSource(cell: 0, channel: 0, kind: .source, rate: 0) }
        #expect(throws: NutrientError.parameter("rate")) {
            try NutrientSource(cell: 0, channel: 0, kind: .sink, rate: 1_000.5)
        }
        #expect(throws: NutrientError.parameter("band")) { try ViabilityBand(low: 2, high: 1) }
        #expect(throws: NutrientError.parameter("band")) { try ViabilityBand(low: 0, high: 1, ramp: -1) }
        #expect(throws: NutrientError.parameter("band")) { try ViabilityBand(low: .nan, high: 1) }
        let codes: [(NutrientError, String)] = [
            (.gridSize, "r2-f21.grid-size"), (.channel(1), "r2-f21.channel"), (.cellRange(1), "r2-f21.cell-range"),
            (.amountLimit, "r2-f21.amount-limit"), (.parameter("x"), "r2-f21.parameter"), (.time, "r2-f21.time"),
            (.sourceLimit, "r2-f21.source-limit"), (.growth("x"), "r2-f21.growth"),
            (.newerSchema(2), "r2-f21.newer-schema"), (.malformed("x"), "r2-f21.malformed"),
        ]
        for (error, code) in codes { #expect(error.reasonCode == code) }
    }

    @Test func addRemoveAndTheLedger() throws {
        var field = try NutrientField(width: 4, height: 3, channels: 2, diffusion: [1, 2])
        #expect(field.cellCount == 12 && field.cell(x: 3, y: 2) == 11)
        try field.add(5 * Self.unit, channel: 1, at: 7)
        #expect(field.amount(1, at: 7) == 5 * Self.unit && field.total(1) == 5 * Self.unit)
        let taken: Int64 = try field.remove(7 * Self.unit, channel: 1, at: 7)
        #expect(taken == 5 * Self.unit)
        #expect(field.ledger.accounts[1].added == 5 * Self.unit && field.ledger.accounts[1].removed == 5 * Self.unit)
        #expect(field.isBalanced)
        #expect(throws: NutrientError.channel(2)) { try field.add(1, channel: 2, at: 0) }
        #expect(throws: NutrientError.cellRange(12)) { try field.add(1, channel: 0, at: 12) }
        #expect(throws: NutrientError.amountLimit) { try field.add(-1, channel: 0, at: 0) }
        #expect(throws: NutrientError.amountLimit) { try field.remove(-1, channel: 0, at: 0) }
        try field.add(NutrientField.maxAmount, channel: 0, at: 0)
        #expect(throws: NutrientError.amountLimit) { try field.add(1, channel: 0, at: 0) }
        #expect(throws: NutrientError.amountLimit) { try field.add(1, channel: 0, at: 1) }   // the grid total is full
        #expect(field.isBalanced)
        #expect(field.amount(9, at: 0) == 0 && field.amount(0, at: -1) == 0 && field.total(-1) == 0)
    }

    @Test func sourcesBandsAndSeeds() throws {
        var field = try NutrientField(width: 4, height: 4, channels: 2, diffusion: [1, 1])
        for i in 0..<NutrientField.maxSources {
            try field.addSource(NutrientSource(cell: i % 16, channel: i % 2, kind: i % 3 == 0 ? .sink : .source, rate: 1))
        }
        #expect(throws: NutrientError.sourceLimit) {
            try field.addSource(NutrientSource(cell: 0, channel: 0, kind: .source, rate: 1))
        }
        var other = try NutrientField(width: 4, height: 4, diffusion: [1])
        #expect(throws: NutrientError.cellRange(16)) {
            try other.addSource(NutrientSource(cell: 16, channel: 0, kind: .source, rate: 1))
        }
        #expect(throws: NutrientError.channel(1)) {
            try other.addSource(NutrientSource(cell: 0, channel: 1, kind: .source, rate: 1))
        }
        #expect(throws: NutrientError.channel(1)) { try other.setBand(ViabilityBand(low: 0, high: 1), channel: 1) }
        #expect(throws: NutrientError.growth("network")) { try other.seed(at: 0) }
        #expect(throws: NutrientError.growth("foodChannel")) {
            try other.setNetwork(GrowthNetwork(limit: 4, perFrame: 1, threshold: 1, foodChannel: 1, cost: 0))
        }
        try other.setNetwork(GrowthNetwork(limit: 2, perFrame: 1, threshold: 1, foodChannel: 0, cost: 0))
        try other.seed(at: 5)
        #expect(throws: NutrientError.growth("seed")) { try other.seed(at: 5) }
        #expect(throws: NutrientError.cellRange(-1)) { try other.seed(at: -1) }
        try other.seed(at: 6)
        #expect(throws: NutrientError.growth("limit")) { try other.seed(at: 7) }
        #expect(other.network?.cells == [5, 6] && other.network?.parents == [-1, -1])
        try other.setNetwork(nil)
        #expect(other.network == nil)
    }

    @Test func viabilityBandsOverSeededCells() throws {
        var random = SeededRandom(seed: 2_021)
        var field = try NutrientField(width: 40, height: 25, channels: 3, diffusion: [0, 0, 0])
        let bands: [ViabilityBand] = [
            try ViabilityBand(low: 1, high: 3, ramp: 1), try ViabilityBand(low: 0.5, high: 2, ramp: 0.5),
            try ViabilityBand(low: 2, high: 2, ramp: 0),
        ]
        for k in 0..<3 { try field.setBand(bands[k], channel: k) }
        var inside = 0, outside = 0, ramped = 0
        for c in 0..<field.cellCount {
            for k in 0..<3 {
                // Channel 2 sits exactly on its hard band half of the time.
                let q: Int64 = k == 2 ? (random.int(0...1) == 0 ? 2 * Self.unit : Int64(random.int(0...Int(4 * Self.unit))))
                                      : Int64(random.int(0...Int(5 * Self.unit)))
                try field.add(q, channel: k, at: c)
            }
            var expected = 1.0
            for k in 0..<3 {
                let units = Double(field.amount(k, at: c)) / Double(Self.unit)
                let b = bands[k]
                var m: Double
                if units >= b.low && units <= b.high { m = 1 } else if b.ramp == 0 { m = 0 } else {
                    let d = units < b.low ? b.low - units : units - b.high
                    m = d >= b.ramp ? 0 : 1 - d / b.ramp
                }
                expected = min(expected, m)
            }
            let v = field.viability(at: c)
            #expect(v == expected)
            #expect(v >= 0 && v <= 1)
            if v == 1 { inside += 1 } else if v == 0 { outside += 1 } else { ramped += 1 }
        }
        print("NutrientFieldTests SC-R02F21-004: \(field.cellCount) cells, inside \(inside), outside \(outside), ramp \(ramped)")
        #expect(field.cellCount == 1_000 && inside > 0 && outside > 0 && ramped > 0)
        let band = try ViabilityBand(low: 1, high: 2, ramp: 0.5)
        #expect(band.membership(1.5) == 1 && band.membership(0.75) == 0.5 && band.membership(2.25) == 0.5)
        #expect(band.membership(0.4) == 0 && band.membership(.nan) == 0)
        #expect(field.viability(at: -1) == 0)
        let open = try NutrientField(width: 2, height: 2, diffusion: [1])
        #expect(open.viability(at: 0) == 1)
    }

    @Test func fieldGridHandOffs() throws {
        var field = try NutrientField(width: 3, height: 2, channels: 2, diffusion: [1, 1])
        try field.add(Self.unit / 2, channel: 1, at: field.cell(x: 2, y: 1))
        try field.setBand(ViabilityBand(low: 0.25, high: 1), channel: 1)
        let grid = try #require(field.fieldGrid(channel: 1))
        #expect(grid.width == 3 && grid.height == 2 && grid.channels == 1)
        #expect(grid[2, 1, 0] == 0.5 && grid[0, 0, 0] == 0)
        #expect(field.fieldGrid(channel: 2) == nil)
        let viable = field.viabilityGrid()
        #expect(viable[2, 1, 0] == 1 && viable[0, 0, 0] == 0)
    }
}
