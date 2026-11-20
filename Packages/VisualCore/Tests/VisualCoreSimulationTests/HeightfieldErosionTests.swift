// HeightfieldErosionTests — feature 217 (R02-F17) T-R02F17-005 (FR-R02F17-005; SC-R02F17-004; clarification Q4;
// research R6). Water poured at the top of a 16 × 8 slope wears the upper third down and builds the lower third up
// while terrain plus sediment balances exactly; erosion off leaves terrain untouched; rock never goes below the floor;
// rock balances with open edges where sediment drains.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct HeightfieldErosionTests {
    static let unit: Int64 = Heightfield.quantaPerUnit

    /// A 16 × 8 grid whose terrain falls along x from 4 + 4 units at x = 0 to 4 units at x = 15.
    static func slope(erosion: Bool, edges: HeightfieldEdges = .walled) throws -> Heightfield {
        var p = HeightfieldParameters()
        p.erosion = erosion
        var field = try Heightfield(width: 16, height: 8, edges: edges, parameters: p)
        for y in 0..<8 {
            for x in 0..<16 {
                let drop: Int64 = 4 * unit * Int64(15 - x) / 15
                try field.add(terrain: 4 * unit + drop, at: field.cell(x: x, y: y))
            }
        }
        return field
    }

    /// Pours `amount` quanta on every cell with x ≤ 1, then runs one sub-step of 1/120 s.
    static func pourAndStep(_ field: inout Heightfield, amount: Int64) throws {
        for y in 0..<field.height {
            for x in 0...1 { try field.add(water: amount, at: field.cell(x: x, y: y)) }
        }
        let report = try field.step(by: 1.0 / 120)
        #expect(report.substeps == 1)
    }

    /// The terrain (not sediment) of the columns in `columns`.
    static func terrain(_ field: Heightfield, columns: Range<Int>) -> Int64 {
        var total: Int64 = 0
        for y in 0..<field.height {
            for x in columns { total += field.terrain(at: field.cell(x: x, y: y)) }
        }
        return total
    }

    @Test func slopeWearsDownAtTheTopAndBuildsUpAtTheBottom() throws {
        var field = try Self.slope(erosion: true)
        let upperBefore: Int64 = Self.terrain(field, columns: 0..<5)
        let lowerBefore: Int64 = Self.terrain(field, columns: 11..<16)
        for _ in 0..<1_000 {
            try Self.pourAndStep(&field, amount: 655)
            #expect(field.isBalanced)
            #expect(field.totalRock == field.ledger.rock.net)
        }
        let upperAfter: Int64 = Self.terrain(field, columns: 0..<5)
        let lowerAfter: Int64 = Self.terrain(field, columns: 11..<16)
        var sediment: Int64 = 0
        for c in 0..<field.cellCount { sediment += field.sediment(at: c) }
        print("HeightfieldErosionTests SC-R02F17-004: upper third \(upperBefore) -> \(upperAfter) "
              + "(\(upperAfter - upperBefore)), lower third \(lowerBefore) -> \(lowerAfter) (\(lowerAfter - lowerBefore)), "
              + "suspended \(sediment), water \(field.totalWater) quanta")
        #expect(upperAfter < upperBefore)
        #expect(lowerAfter > lowerBefore)
        #expect(field.ledger.rock.added == field.totalRock)
        #expect(field.ledger.rock.drained == 0 && field.ledger.rock.removed == 0)
    }

    @Test func disabledErosionLeavesTerrainUnchanged() throws {
        var field = try Self.slope(erosion: false)
        let before: [Int64] = field.terrainQ
        for _ in 0..<300 {
            try Self.pourAndStep(&field, amount: 655)
            #expect(field.isBalanced)
        }
        #expect(field.terrainQ == before)
        for c in 0..<field.cellCount { #expect(field.sediment(at: c) == 0) }
        #expect(field.totalWater > 0)
    }

    @Test func rockNeverGoesBelowTheFloor() throws {
        // 16 × 8, walled: an 8-unit wall at x = 0, then a layer of 1 quantum; strong erosion constants. Water poured
        // on the wall rushes down over the thin layer.
        var p = HeightfieldParameters()
        p.erosion = true
        p.capacity = 10
        p.dissolving = 10
        p.depositing = 0
        var field = try Heightfield(width: 16, height: 8, parameters: p)
        for y in 0..<8 {
            for x in 0..<16 { try field.add(terrain: x == 0 ? 8 * Self.unit : 1, at: field.cell(x: x, y: y)) }
        }
        var floorHits: Int = 0
        for _ in 0..<300 {
            for y in 0..<8 { try field.add(water: 2_000, at: field.cell(x: 0, y: y)) }
            _ = try field.step(by: 1.0 / 120)
            #expect(field.isBalanced)
            for c in 0..<field.cellCount {
                #expect(field.terrain(at: c) >= 0)
                #expect(field.sediment(at: c) >= 0)
                #expect(field.water(at: c) >= 0)
                if field.terrain(at: c) == 0 { floorHits += 1 }
            }
        }
        print("HeightfieldErosionTests floor: cell-steps at terrain 0: \(floorHits)")
        #expect(floorHits > 0)
    }

    @Test func rockBalancesWithOpenEdges() throws {
        var field = try Self.slope(erosion: true, edges: .open)
        let added: Int64 = field.ledger.rock.added
        for _ in 0..<400 {
            try Self.pourAndStep(&field, amount: 655)
            #expect(field.isBalanced)
            #expect(field.totalRock == field.ledger.rock.added - field.ledger.rock.drained)
        }
        print("HeightfieldErosionTests open: rock drained \(field.ledger.rock.drained) of \(added), "
              + "water drained \(field.ledger.water.drained) quanta")
        #expect(field.ledger.water.drained > 0)
        #expect(field.ledger.rock.drained >= 0)
    }
}
