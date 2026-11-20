// HeightfieldDyeTests — feature 217 (R02-F17) T-R02F17-004 (FR-R02F17-004; SC-R02F17-001; clarification Q4; research
// R4). Every dye channel's grid total equals its ledger account exactly after every step of seeded runs, walled and
// open; dye goes only where water went; a cell that sends all its water in one direction sends all its dye; drained dye
// is counted; channel refusals.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct HeightfieldDyeTests {
    static let unit: Int64 = Heightfield.quantaPerUnit

    /// A seeded grid of 4 … 8 cells per side, 1 … 4 dye channels, random terrain, water and dye (dye only in wet cells).
    static func seededGrid(_ random: inout SeededRandom) throws -> Heightfield {
        let width: Int = random.int(4...8)
        let height: Int = random.int(4...8)
        let channels: Int = random.int(1...4)
        let edges: HeightfieldEdges = random.int(0...1) == 0 ? .walled : .open
        var field = try Heightfield(width: width, height: height, dyeChannels: channels, edges: edges)
        for c in 0..<field.cellCount {
            try field.add(terrain: Int64(random.int(0...Int(2 * unit))), at: c)
            let water: Int64 = Int64(random.int(0...Int(unit / 2)))
            if water > 0 { try field.add(water: water, at: c) }
            for k in 0..<channels where random.int(0...2) == 0 && water > 0 {
                try field.add(dye: Int64(random.int(0...Int(unit))), channel: k, at: c)
            }
        }
        return field
    }

    @Test func seededRunsConserveEveryChannelExactly() throws {
        var random = SeededRandom(seed: 2_017)
        var openRuns: Int = 0
        var drainedDye: Int64 = 0
        var remainderCells: Int = 0
        for _ in 0..<20 {
            var field = try Self.seededGrid(&random)
            if field.edges == .open { openRuns += 1 }
            #expect(field.isBalanced)
            var unbalanced: Int = 0
            var mismatches: Int = 0
            var negatives: Int = 0
            for _ in 0..<300 {
                _ = try field.step(by: 1.0 / 60)
                if !field.isBalanced { unbalanced += 1 }
                for k in 0..<field.dyeChannels {
                    let account = field.ledger.dye[k]
                    if field.totalDye(k) != account.net || account.added - account.drained != field.totalDye(k) {
                        mismatches += 1
                    }
                }
                for c in 0..<field.cellCount {
                    for k in 0..<field.dyeChannels {
                        if field.dye(k, at: c) < 0 { negatives += 1 }
                        // Q4: a cell that sends all its water sends its remainder too, so a dry cell keeps no dye.
                        if field.water(at: c) == 0 && field.dye(k, at: c) > 0 { remainderCells += 1 }
                    }
                }
            }
            #expect(unbalanced == 0)
            #expect(mismatches == 0)
            #expect(negatives == 0)
            for k in 0..<field.dyeChannels { drainedDye += field.ledger.dye[k].drained }
            if field.edges == .walled {
                for k in 0..<field.dyeChannels { #expect(field.ledger.dye[k].drained == 0) }
            }
        }
        print("HeightfieldDyeTests seeded: open runs \(openRuns)/20, dye drained \(drainedDye) quanta, "
              + "dry cell-channel samples holding dye \(remainderCells)")
        #expect(remainderCells == 0)
        #expect(openRuns > 0 && openRuns < 20)
        #expect(drainedDye > 0)
    }

    @Test func dyeNeverReachesADryPlateau() throws {
        // 16 × 8, walled: the left half at height 0 holds water up to 1 unit and dye; the right half is a plateau at
        // 10 units, plus a pocket at (3, 3) ringed by 12-unit walls in the left half. No water can climb in.
        var random = SeededRandom(seed: 2_017)
        var field = try Heightfield(width: 16, height: 8, dyeChannels: 3)
        var dry: [Int] = []
        for y in 0..<8 {
            for x in 0..<16 {
                let c: Int = field.cell(x: x, y: y)
                let ring: Bool = abs(x - 3) <= 1 && abs(y - 3) <= 1 && !(x == 3 && y == 3)
                if x >= 8 {
                    try field.add(terrain: 10 * Self.unit, at: c)
                    dry.append(c)
                } else if ring {
                    try field.add(terrain: 12 * Self.unit, at: c)
                    dry.append(c)
                } else if x == 3 && y == 3 {
                    dry.append(c)
                } else {
                    try field.add(water: Int64(random.int(0...Int(Self.unit))), at: c)
                    for k in 0..<3 { try field.add(dye: Int64(random.int(1...Int(Self.unit))), channel: k, at: c) }
                }
            }
        }
        for _ in 0..<300 {
            _ = try field.step(by: 1.0 / 60)
            #expect(field.isBalanced)
            for c in dry {
                #expect(field.water(at: c) == 0)
                for k in 0..<3 { #expect(field.dye(k, at: c) == 0) }
            }
        }
        var moved: Bool = false
        for c in 0..<field.cellCount where field.flux(at: c) != [0, 0, 0, 0] { moved = true }
        #expect(moved)
    }

    @Test func aCellSendingAllItsWaterSendsAllItsDye() throws {
        // 4 × 4, walled: (0, 0) is a 5-unit peak with 100 quanta of water and dye; its right neighbour (1, 0) is at 0;
        // every other cell is a 20-unit wall. One sub-step of 1/120 s wants ≈ 220 quanta to the right, more than the
        // cell holds, so all its water — and therefore all its dye — goes right.
        var field = try Heightfield(width: 4, height: 4, dyeChannels: 4)
        for c in 0..<field.cellCount where c != 1 {
            try field.add(terrain: (c == 0 ? 5 : 20) * Self.unit, at: c)
        }
        try field.add(water: 100, at: 0)
        let dyes: [Int64] = [7, 1, 99, 100]
        for k in 0..<4 { try field.add(dye: dyes[k], channel: k, at: 0) }
        let report = try field.step(by: 1.0 / 120)
        #expect(report.substeps == 1)
        #expect(field.water(at: 0) == 0)
        #expect(field.water(at: 1) == 100)
        for k in 0..<4 {
            #expect(field.dye(k, at: 0) == 0)
            #expect(field.dye(k, at: 1) == dyes[k])
        }
        for _ in 0..<60 {
            _ = try field.step(by: 1.0 / 60)
            #expect(field.isBalanced)
            #expect(field.water(at: 0) == 0)
            for k in 0..<4 { #expect(field.dye(k, at: 0) == 0 && field.dye(k, at: 1) == dyes[k]) }
        }
    }

    @Test func drainedDyeIsCounted() throws {
        // 8 × 8, open, flat: a dyed water column in the middle spreads and leaves across the border.
        var field = try Heightfield(width: 8, height: 8, dyeChannels: 2, edges: .open)
        for y in 3...4 {
            for x in 3...4 {
                let c: Int = field.cell(x: x, y: y)
                try field.add(water: Self.unit, at: c)
                try field.add(dye: Self.unit / 2, channel: 0, at: c)
                try field.add(dye: 3, channel: 1, at: c)
            }
        }
        for _ in 0..<300 {
            _ = try field.step(by: 1.0 / 60)
            #expect(field.isBalanced)
        }
        let added0: Int64 = field.ledger.dye[0].added
        print("HeightfieldDyeTests drain: water drained \(field.ledger.water.drained)/\(field.ledger.water.added), "
              + "dye0 drained \(field.ledger.dye[0].drained)/\(added0), dye1 drained \(field.ledger.dye[1].drained)/12")
        #expect(field.ledger.water.drained > 0)
        #expect(field.ledger.dye[0].drained > 0)
        #expect(field.ledger.dye[0].drained <= added0)
        for k in 0..<2 {
            #expect(field.ledger.dye[k].removed == 0)
            #expect(field.totalDye(k) == field.ledger.dye[k].added - field.ledger.dye[k].drained)
        }
        // A remove is counted apart from the drain.
        let cell: Int = field.cell(x: 4, y: 4)
        let held: Int64 = field.dye(0, at: cell)
        let taken: Int64 = try field.remove(dye: held + 1_000, channel: 0, at: cell)
        #expect(taken == held)
        #expect(field.ledger.dye[0].removed == held)
        #expect(field.isBalanced)
    }

    @Test func channelRefusals() throws {
        #expect(throws: HeightfieldError.dyeChannel(5)) { try Heightfield(width: 4, height: 4, dyeChannels: 5) }
        #expect(throws: HeightfieldError.dyeChannel(-1)) { try Heightfield(width: 4, height: 4, dyeChannels: -1) }
        var field = try Heightfield(width: 4, height: 4, dyeChannels: 2)
        #expect(throws: HeightfieldError.dyeChannel(2)) { try field.add(dye: 1, channel: 2, at: 0) }
        #expect(throws: HeightfieldError.dyeChannel(-1)) { try field.add(dye: 1, channel: -1, at: 0) }
        #expect(throws: HeightfieldError.dyeChannel(2)) { try field.remove(dye: 1, channel: 2, at: 0) }
        #expect(throws: HeightfieldError.cellRange(16)) { try field.add(dye: 1, channel: 0, at: 16) }
        #expect(throws: HeightfieldError.amountLimit) { try field.add(dye: -1, channel: 0, at: 0) }
        #expect(field.ledger.dye[0].added == 0 && field.ledger.dye[1].added == 0)
        #expect(field.dye(2, at: 0) == 0 && field.dye(-1, at: 0) == 0 && field.totalDye(9) == 0)
        #expect(HeightfieldError.dyeChannel(7).reasonCode == "r2-f17.dye-channel")
        let none = try Heightfield(width: 4, height: 4)
        #expect(none.dyeField() == nil)
        #expect(none.ledger.dye.isEmpty)
        let four = try Heightfield(width: 4, height: 4, dyeChannels: Heightfield.maxDyeChannels)
        #expect(four.dyeField()?.channels == 4)
    }
}
