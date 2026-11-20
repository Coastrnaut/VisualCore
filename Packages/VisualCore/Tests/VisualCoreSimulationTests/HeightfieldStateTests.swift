// HeightfieldStateTests — feature 217 (R02-F17) T-R02F17-002 (FR-R02F17-001, FR-R02F17-006, FR-R02F17-008,
// FR-R02F17-009; SC-R02F17-001, SC-R02F17-003). Limits and refusals of the heightfield state, the ledger after seeded
// edits, the surface and the field handoff values, and the reason codes.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct HeightfieldStateTests {
    @Test func gridSizeAndChannelCountRefusals() throws {
        #expect(throws: HeightfieldError.gridSize) { try Heightfield(width: 3, height: 8) }
        #expect(throws: HeightfieldError.gridSize) { try Heightfield(width: 8, height: 3) }
        #expect(throws: HeightfieldError.gridSize) { try Heightfield(width: 1_025, height: 8) }
        #expect(throws: HeightfieldError.gridSize) { try Heightfield(width: 8, height: 1_025) }
        #expect(throws: HeightfieldError.gridSize) { try Heightfield(width: 600, height: 600) }
        #expect(throws: HeightfieldError.dyeChannel(5)) { try Heightfield(width: 8, height: 8, dyeChannels: 5) }
        #expect(throws: HeightfieldError.dyeChannel(-1)) { try Heightfield(width: 8, height: 8, dyeChannels: -1) }
        let smallest = try Heightfield(width: 4, height: 4, dyeChannels: 4)
        #expect(smallest.cellCount == 16 && smallest.dyeChannels == 4)
        #expect(smallest.edges == .walled && smallest.parameters == HeightfieldParameters())
        #expect(smallest.isBalanced && smallest.totalWater == 0 && smallest.totalRock == 0)
        let widest = try Heightfield(width: 1_024, height: 256)
        #expect(widest.cellCount == Heightfield.maxCells)
    }

    @Test func invalidParametersAreNamed() throws {
        var cases: [(HeightfieldParameters, String)] = []
        var p = HeightfieldParameters()
        p.gravity = 0; cases.append((p, "gravity"))
        p = HeightfieldParameters(); p.gravity = .nan; cases.append((p, "gravity"))
        p = HeightfieldParameters(); p.gravity = 101; cases.append((p, "gravity"))
        p = HeightfieldParameters(); p.pipeArea = 0; cases.append((p, "pipeArea"))
        p = HeightfieldParameters(); p.pipeArea = 11; cases.append((p, "pipeArea"))
        p = HeightfieldParameters(); p.pipeArea = .infinity; cases.append((p, "pipeArea"))
        p = HeightfieldParameters(); p.damping = 1.1; cases.append((p, "damping"))
        p = HeightfieldParameters(); p.damping = -0.1; cases.append((p, "damping"))
        p = HeightfieldParameters(); p.maxSubstep = 0; cases.append((p, "maxSubstep"))
        p = HeightfieldParameters(); p.maxSubstep = 0.2; cases.append((p, "maxSubstep"))
        p = HeightfieldParameters(); p.maxSubsteps = 0; cases.append((p, "maxSubsteps"))
        p = HeightfieldParameters(); p.maxSubsteps = 65; cases.append((p, "maxSubsteps"))
        p = HeightfieldParameters(); p.capacity = 11; cases.append((p, "capacity"))
        p = HeightfieldParameters(); p.dissolving = 11; cases.append((p, "dissolving"))
        p = HeightfieldParameters(); p.depositing = 11; cases.append((p, "depositing"))
        p = HeightfieldParameters(); p.depositing = -1; cases.append((p, "depositing"))
        for (parameters, name) in cases {
            #expect(throws: HeightfieldError.invalidParameter(name)) {
                try Heightfield(width: 8, height: 8, parameters: parameters)
            }
            #expect(throws: HeightfieldError.invalidParameter(name)) { try parameters.validated() }
        }
        var edge = HeightfieldParameters()
        edge.gravity = 100; edge.pipeArea = 10; edge.damping = 1; edge.maxSubstep = 0.1; edge.maxSubsteps = 64
        edge.capacity = 10; edge.dissolving = 0; edge.depositing = 10; edge.erosion = true
        let accepted = try Heightfield(width: 8, height: 8, parameters: edge)
        #expect(accepted.parameters == edge)
        var low = HeightfieldParameters()
        low.damping = 0; low.maxSubsteps = 1; low.capacity = 0
        #expect(try low.validated() == low)
    }

    @Test func cellChannelAndAmountRefusals() throws {
        var field = try Heightfield(width: 8, height: 8, dyeChannels: 2)
        let cells: Int = field.cellCount
        #expect(throws: HeightfieldError.cellRange(-1)) { try field.add(water: 1, at: -1) }
        #expect(throws: HeightfieldError.cellRange(cells)) { try field.add(water: 1, at: cells) }
        #expect(throws: HeightfieldError.cellRange(cells)) { try field.add(terrain: 1, at: cells) }
        #expect(throws: HeightfieldError.cellRange(-1)) { try field.add(dye: 1, channel: 0, at: -1) }
        #expect(throws: HeightfieldError.cellRange(cells)) { try field.remove(water: 1, at: cells) }
        #expect(throws: HeightfieldError.cellRange(-1)) { try field.remove(terrain: 1, at: -1) }
        #expect(throws: HeightfieldError.cellRange(cells)) { try field.remove(dye: 1, channel: 0, at: cells) }
        #expect(throws: HeightfieldError.dyeChannel(2)) { try field.add(dye: 1, channel: 2, at: 0) }
        #expect(throws: HeightfieldError.dyeChannel(-1)) { try field.add(dye: 1, channel: -1, at: 0) }
        #expect(throws: HeightfieldError.dyeChannel(2)) { try field.remove(dye: 1, channel: 2, at: 0) }
        #expect(throws: HeightfieldError.amountLimit) { try field.add(water: -1, at: 0) }
        #expect(throws: HeightfieldError.amountLimit) { try field.add(terrain: -1, at: 0) }
        #expect(throws: HeightfieldError.amountLimit) { try field.add(dye: -1, channel: 0, at: 0) }
        #expect(throws: HeightfieldError.amountLimit) { try field.remove(water: -1, at: 0) }
        #expect(throws: HeightfieldError.amountLimit) { try field.remove(terrain: -1, at: 0) }
        #expect(throws: HeightfieldError.amountLimit) { try field.remove(dye: -1, channel: 0, at: 0) }
        let limit: Int64 = Heightfield.maxAmount
        #expect(throws: HeightfieldError.amountLimit) { try field.add(water: limit + 1, at: 0) }
        // A cell may hold exactly 2⁴⁰; one quantum more is refused.
        try field.add(water: limit, at: 0)
        #expect(throws: HeightfieldError.amountLimit) { try field.add(water: 1, at: 0) }
        try field.add(terrain: limit, at: 1)
        #expect(throws: HeightfieldError.amountLimit) { try field.add(terrain: 1, at: 1) }
        // The grid total across two cells is bounded too.
        let half: Int64 = limit / 2
        try field.add(dye: half + 1, channel: 1, at: 2)
        #expect(throws: HeightfieldError.amountLimit) { try field.add(dye: half, channel: 1, at: 3) }
        #expect(throws: HeightfieldError.amountLimit) { try field.add(water: 1, at: 5) }
        try field.add(dye: half - 1, channel: 1, at: 3)
        #expect(field.totalDye(1) == limit)
        // Refused edits change nothing.
        #expect(field.water(at: 0) == limit && field.totalWater == limit && field.water(at: 5) == 0)
        #expect(field.terrain(at: 1) == limit && field.totalRock == limit)
        #expect(field.dye(1, at: 3) == half - 1 && field.ledger.dye[1].added == limit)
        #expect(field.ledger.water.added == limit && field.ledger.rock.added == limit)
        #expect(field.isBalanced)
    }

    @Test func seededEditsKeepTheLedgerBalanced() throws {
        var random = SeededRandom(seed: 2_017)
        var field = try Heightfield(width: 16, height: 12, dyeChannels: 3)
        var addedWater: Int64 = 0, removedWater: Int64 = 0
        var addedRock: Int64 = 0, removedRock: Int64 = 0
        var addedDye: [Int64] = [0, 0, 0], removedDye: [Int64] = [0, 0, 0]
        var expectedWater: [Int64] = Array(repeating: 0, count: field.cellCount)
        var expectedTerrain: [Int64] = Array(repeating: 0, count: field.cellCount)
        for _ in 0..<600 {
            let cell: Int = random.int(0...(field.cellCount - 1))
            let amount: Int64 = Int64(random.int(0...200_000))
            let op: Int = random.int(0...5)
            switch op {
            case 0:
                try field.add(water: amount, at: cell)
                addedWater += amount; expectedWater[cell] += amount
            case 1:
                let before: Int64 = field.water(at: cell)
                let taken: Int64 = try field.remove(water: amount, at: cell)
                #expect(taken == min(amount, before))
                removedWater += taken; expectedWater[cell] -= taken
            case 2:
                try field.add(terrain: amount, at: cell)
                addedRock += amount; expectedTerrain[cell] += amount
            case 3:
                let before: Int64 = field.terrain(at: cell)
                let taken: Int64 = try field.remove(terrain: amount, at: cell)
                #expect(taken == min(amount, before))
                removedRock += taken; expectedTerrain[cell] -= taken
            case 4:
                let channel: Int = random.int(0...2)
                try field.add(dye: amount, channel: channel, at: cell)
                addedDye[channel] += amount
            default:
                let channel: Int = random.int(0...2)
                let before: Int64 = field.dye(channel, at: cell)
                let taken: Int64 = try field.remove(dye: amount, channel: channel, at: cell)
                #expect(taken == min(amount, before))
                removedDye[channel] += taken
            }
            #expect(field.isBalanced)
        }
        #expect(field.ledger.water.added == addedWater && field.ledger.water.removed == removedWater)
        #expect(field.ledger.rock.added == addedRock && field.ledger.rock.removed == removedRock)
        #expect(field.ledger.water.drained == 0 && field.ledger.rock.drained == 0)
        #expect(field.ledger.water.net == field.totalWater && field.totalWater == addedWater - removedWater)
        #expect(field.ledger.rock.net == field.totalRock && field.totalRock == addedRock - removedRock)
        for k in 0..<3 {
            #expect(field.ledger.dye[k].added == addedDye[k] && field.ledger.dye[k].removed == removedDye[k])
            #expect(field.ledger.dye[k].net == field.totalDye(k))
        }
        for c in 0..<field.cellCount {
            #expect(field.water(at: c) == expectedWater[c] && field.terrain(at: c) == expectedTerrain[c])
            #expect(field.water(at: c) >= 0 && field.terrain(at: c) >= 0 && field.sediment(at: c) == 0)
        }
        #expect(field.totalDye(3) == 0 && field.totalDye(-1) == 0)
    }

    @Test func removeTakesOnlyWhatIsPresent() throws {
        var field = try Heightfield(width: 4, height: 4, dyeChannels: 1)
        try field.add(water: 100, at: 5)
        try field.add(terrain: 70, at: 5)
        try field.add(dye: 30, channel: 0, at: 5)
        #expect(try field.remove(water: 250, at: 5) == 100)
        #expect(try field.remove(terrain: 1_000, at: 5) == 70)
        #expect(try field.remove(dye: 31, channel: 0, at: 5) == 30)
        #expect(try field.remove(water: 1, at: 5) == 0)
        #expect(try field.remove(terrain: 1, at: 6) == 0)
        #expect(field.water(at: 5) == 0 && field.terrain(at: 5) == 0 && field.dye(0, at: 5) == 0)
        #expect(field.ledger.water.removed == 100 && field.ledger.rock.removed == 70 && field.ledger.dye[0].removed == 30)
        #expect(field.ledger.water.net == 0 && field.ledger.rock.net == 0 && field.ledger.dye[0].net == 0)
        #expect(field.isBalanced)
    }

    @Test func accessorsAndSurface() throws {
        var field = try Heightfield(width: 6, height: 5, dyeChannels: 1)
        #expect(field.cell(x: 2, y: 3) == 3 * 6 + 2)
        let cell: Int = field.cell(x: 2, y: 3)
        try field.add(terrain: 3 * 65_536, at: cell)
        try field.add(water: 32_768, at: cell)
        #expect(field.surface(at: cell) == 3.5)
        #expect(field.surface(at: 0) == 0)
        #expect(field.surface(at: -1) == 0 && field.surface(at: field.cellCount) == 0)
        #expect(field.terrain(at: -1) == 0 && field.water(at: 99) == 0 && field.sediment(at: 30) == 0)
        #expect(field.dye(0, at: -1) == 0 && field.dye(1, at: cell) == 0 && field.dye(-1, at: cell) == 0)
        #expect(field.flux(at: cell) == [0, 0, 0, 0] && field.flux(at: -1) == [0, 0, 0, 0])
        #expect(Heightfield.quantaPerUnit == 65_536 && Heightfield.maxAmount == 1_099_511_627_776)
    }

    @Test func fieldGridHandoff() throws {
        var random = SeededRandom(seed: 2_017)
        var field = try Heightfield(width: 7, height: 5, dyeChannels: 3)
        for c in 0..<field.cellCount {
            try field.add(terrain: Int64(random.int(0...500_000)), at: c)
            try field.add(water: Int64(random.int(0...300_000)), at: c)
            for k in 0..<3 { try field.add(dye: Int64(random.int(0...90_000)), channel: k, at: c) }
        }
        // Sediment only arises from erosion; set some directly to check the third channel.
        field.sedimentQ[field.cell(x: 3, y: 2)] = 131_072
        let grid: FieldGrid = field.fieldGrid()
        #expect(grid.width == 7 && grid.height == 5 && grid.channels == 4 && grid.values.count == 7 * 5 * 4)
        let unit: Double = 65_536
        for y in 0..<5 {
            for x in 0..<7 {
                let c: Int = y * 7 + x
                let base: Int = (y * 7 + x) * 4
                var dyeSum: Int64 = 0
                for k in 0..<3 { dyeSum += field.dye(k, at: c) }
                #expect(grid.values[base] == Float(Double(field.terrain(at: c)) / unit))
                #expect(grid.values[base + 1] == Float(Double(field.water(at: c)) / unit))
                #expect(grid.values[base + 2] == Float(Double(field.sediment(at: c)) / unit))
                #expect(grid.values[base + 3] == Float(Double(dyeSum) / unit))
                #expect(grid[x, y, 0] == grid.values[base])
            }
        }
        #expect(grid[3, 2, 2] == 2)
        let dyes: FieldGrid? = field.dyeField()
        #expect(dyes != nil)
        if let dyes {
            #expect(dyes.width == 7 && dyes.height == 5 && dyes.channels == 3)
            for c in 0..<field.cellCount {
                for k in 0..<3 {
                    #expect(dyes.values[c * 3 + k] == Float(Double(field.dye(k, at: c)) / unit))
                }
            }
        }
        let plain = try Heightfield(width: 4, height: 4)
        #expect(plain.dyeField() == nil)
        let empty: FieldGrid = plain.fieldGrid()
        #expect(empty.channels == 4 && empty.values.allSatisfy { $0 == 0 })
    }

    @Test func reasonCodes() {
        let cases: [(HeightfieldError, String)] = [
            (.gridSize, "r2-f17.grid-size"),
            (.cellRange(3), "r2-f17.cell-range"),
            (.amountLimit, "r2-f17.amount-limit"),
            (.invalidTime, "r2-f17.invalid-time"),
            (.invalidParameter("gravity"), "r2-f17.invalid-parameter"),
            (.dyeChannel(5), "r2-f17.dye-channel"),
            (.newerSchema(2), "r2-f17.newer-schema"),
            (.malformed("x"), "r2-f17.malformed"),
        ]
        for (error, code) in cases { #expect(error.reasonCode == code) }
    }
}
