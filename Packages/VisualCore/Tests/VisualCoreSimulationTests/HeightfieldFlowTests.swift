// HeightfieldFlowTests — feature 217 (R02-F17) T-R02F17-003 (FR-R02F17-002, FR-R02F17-006; SC-R02F17-001,
// SC-R02F17-002). Seeded terrains keep their ledgers balanced and every amount non-negative after every step; a closed
// bowl filled in one quarter levels out within 2,000 sub-steps; water runs downhill; open edges drain into the ledger;
// two identical runs give identical states.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct HeightfieldFlowTests {
    static let unit: Int64 = Heightfield.quantaPerUnit

    /// A seeded terrain: random terrain 0 … 4 units and water 0 … 2 units per cell, in whole quanta.
    static func seededField(_ random: inout SeededRandom, side: ClosedRange<Int>,
                            edges: HeightfieldEdges) throws -> Heightfield {
        let width: Int = random.int(side)
        let height: Int = random.int(side)
        var field = try Heightfield(width: width, height: height, edges: edges)
        for c in 0..<field.cellCount {
            let terrain = Int64(random.int(0...Int(4 * unit)))
            let water = Int64(random.int(0...Int(2 * unit)))
            try field.add(terrain: terrain, at: c)
            try field.add(water: water, at: c)
        }
        return field
    }

    /// Whether no cell holds a negative amount of water, terrain or sediment.
    static func noNegativeAmount(_ field: Heightfield) -> Bool {
        for c in 0..<field.cellCount {
            if field.water(at: c) < 0 || field.terrain(at: c) < 0 || field.sediment(at: c) < 0 { return false }
        }
        return true
    }

    @Test func seededTerrainsBalanceAfterEveryStep() throws {
        var random = SeededRandom(seed: 2_017)
        let start = Date()
        var failures = 0
        for run in 0..<50 {
            let edges: HeightfieldEdges = run % 2 == 0 ? .walled : .open
            var field = try Self.seededField(&random, side: 4...6, edges: edges)
            for _ in 0..<500 {
                _ = try field.step(by: 1.0 / 60)
                let balanced: Bool = field.isBalanced
                let nonNegative: Bool = Self.noNegativeAmount(field)
                if !balanced || !nonNegative { failures += 1 }
            }
        }
        let elapsed = Date().timeIntervalSince(start)
        print("SC-R02F17-001 flow: 50 terrains × 500 steps in \(elapsed) s, failures \(failures)")
        #expect(failures == 0)
    }

    @Test func closedBowlSettlesWithin2000Substeps() throws {
        var field = try Heightfield(width: 16, height: 16, edges: .walled)
        for y in 0..<16 {
            for x in 0..<16 {
                let dx = Double(x) - 7.5
                let dy = Double(y) - 7.5
                let units: Double = 0.008 * (dx * dx + dy * dy)
                try field.add(terrain: Int64((units * Double(Self.unit)).rounded(.down)), at: field.cell(x: x, y: y))
            }
        }
        // Water poured in the top-left quarter only: 1 unit per cell.
        for y in 0..<8 {
            for x in 0..<8 { try field.add(water: Self.unit, at: field.cell(x: x, y: y)) }
        }
        let waterBefore = field.totalWater
        var substeps = 0
        var oneSubstepEach = true
        for _ in 0..<2_000 {
            let report = try field.step(by: field.parameters.maxSubstep)
            if report.substeps != 1 { oneSubstepEach = false }
            substeps += report.substeps
        }
        #expect(oneSubstepEach)
        #expect(substeps == 2_000)
        #expect(field.isBalanced)
        #expect(field.totalWater == waterBefore)
        let wet: Int64 = Self.unit / 64
        var highest = -Double.infinity
        var lowest = Double.infinity
        var wetCells = 0
        for c in 0..<field.cellCount where field.water(at: c) > wet {
            let s = field.surface(at: c)
            highest = max(highest, s)
            lowest = min(lowest, s)
            wetCells += 1
        }
        let spread = highest - lowest
        print("SC-R02F17-002: wet cells \(wetCells), surface \(lowest) … \(highest), spread \(spread)")
        #expect(wetCells > 0)
        #expect(spread <= 0.05)
    }

    @Test func waterRunsDownhill() throws {
        var field = try Heightfield(width: 16, height: 8, edges: .walled)
        for y in 0..<8 {
            for x in 0..<16 {
                try field.add(terrain: Int64(15 - x) * Self.unit / 4, at: field.cell(x: x, y: y))
            }
        }
        for y in 0..<8 {
            for x in 0..<2 { try field.add(water: Self.unit / 2, at: field.cell(x: x, y: y)) }
        }
        func bottomWater(_ f: Heightfield) -> Int64 {
            var sum: Int64 = 0
            for y in 0..<8 {
                for x in 12..<16 { sum += f.water(at: f.cell(x: x, y: y)) }
            }
            return sum
        }
        let before = bottomWater(field)
        for _ in 0..<240 { _ = try field.step(by: 1.0 / 60) }
        let after = bottomWater(field)
        print("downhill: bottom water \(before) → \(after) quanta of \(field.totalWater)")
        #expect(before == 0)
        #expect(after > before)
        #expect(field.isBalanced)
    }

    @Test func openEdgesDrain() throws {
        var field = try Heightfield(width: 8, height: 8, edges: .open)
        let edgeCell = field.cell(x: 0, y: 3)
        try field.add(water: Self.unit, at: edgeCell)
        let before = field.water(at: edgeCell)
        for _ in 0..<60 { _ = try field.step(by: 1.0 / 60) }
        #expect(field.water(at: edgeCell) < before)
        #expect(field.ledger.water.drained > 0)
        #expect(field.totalWater < Self.unit)
        #expect(field.isBalanced)

        // Walled: nothing leaves.
        var walled = try Heightfield(width: 8, height: 8, edges: .walled)
        try walled.add(water: Self.unit, at: edgeCell)
        for _ in 0..<60 { _ = try walled.step(by: 1.0 / 60) }
        #expect(walled.ledger.water.drained == 0)
        #expect(walled.totalWater == Self.unit)
    }

    @Test func identicalRunsGiveIdenticalStates() throws {
        var randomA = SeededRandom(seed: 2_017)
        var randomB = SeededRandom(seed: 2_017)
        var a = try Self.seededField(&randomA, side: 10...10, edges: .open)
        var b = try Self.seededField(&randomB, side: 10...10, edges: .open)
        #expect(a == b)
        for _ in 0..<200 {
            let ra = try a.step(by: 1.0 / 60)
            let rb = try b.step(by: 1.0 / 60)
            #expect(ra == rb)
        }
        #expect(a == b)
        #expect(a.ledger == b.ledger)
    }
}
