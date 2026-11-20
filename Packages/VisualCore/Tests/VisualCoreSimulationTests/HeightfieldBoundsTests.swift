// HeightfieldBoundsTests — feature 217 (R02-F17) T-R02F17-003 (FR-R02F17-003, FR-R02F17-009; SC-R02F17-003).
// Extreme columns, cliffs and frame times up to 10 s keep every amount within 0 … 2⁴⁰ and every flux finite within
// 0 … 1,000,000 with the ledger balanced; a frame longer than 64 stable sub-steps reports its dropped time; a zero time
// does nothing and a negative or non-finite time is refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct HeightfieldBoundsTests {
    /// The number of cells that break a bound (amount outside 0 … 2⁴⁰, flux not finite or outside 0 … maxFlux).
    static func boundViolations(_ field: Heightfield) -> Int {
        var violations = 0
        let range: ClosedRange<Int64> = 0...Heightfield.maxAmount
        for c in 0..<field.cellCount {
            if !range.contains(field.water(at: c)) { violations += 1 }
            if !range.contains(field.terrain(at: c)) { violations += 1 }
            if !range.contains(field.sediment(at: c)) { violations += 1 }
            let fluxes: [Double] = field.flux(at: c)
            for f in fluxes where !f.isFinite || f < 0 || f > Heightfield.maxFlux { violations += 1 }
        }
        if !range.contains(field.totalWater) || !range.contains(field.totalRock) { violations += 1 }
        return violations
    }

    @Test func extremeCasesStayWithinBounds() throws {
        var random = SeededRandom(seed: 2_017)
        let limit: Int64 = Heightfield.maxAmount
        var violations = 0
        var unbalanced = 0
        var droppedFrames = 0
        let start = Date()
        for run in 0..<100 {
            let edges: HeightfieldEdges = run % 2 == 0 ? .walled : .open
            let side: Int = random.int(4...8)
            var field = try Heightfield(width: side, height: side, edges: edges)
            let cells = field.cellCount
            // Water columns: 1 … 3 cells share up to the whole grid limit.
            let columns: Int = random.int(1...3)
            var waterLeft: Int64 = limit - Int64(random.int(0...1_000_000))
            for _ in 0..<columns {
                let c: Int = random.int(0...(cells - 1))
                let room: Int64 = min(waterLeft, limit - field.water(at: c))
                let amount = Int64(Double(room) * random.range(0.3...1.0))
                try field.add(water: amount, at: c)
                waterLeft -= amount
            }
            // Cliffs: terrain 0 beside cells of huge terrain, the rock total at most 2⁴⁰.
            if run % 3 != 2 {
                let cliffs: Int = random.int(1...3)
                var rockLeft: Int64 = limit
                for _ in 0..<cliffs {
                    let c: Int = random.int(0...(cells - 1))
                    let room: Int64 = min(rockLeft, limit - field.terrain(at: c))
                    let amount = Int64(Double(room) * random.range(0.3...1.0))
                    try field.add(terrain: amount, at: c)
                    rockLeft -= amount
                }
            }
            for _ in 0..<4 {
                let time: Double = random.range(0...10)
                let report = try field.step(by: time)
                if report.droppedTime > 0 { droppedFrames += 1 }
                violations += Self.boundViolations(field)
                if !field.isBalanced { unbalanced += 1 }
            }
        }
        let elapsed = Date().timeIntervalSince(start)
        print("SC-R02F17-003: 100 extreme cases in \(elapsed) s, frames with dropped time \(droppedFrames)")
        #expect(violations == 0)
        #expect(unbalanced == 0)
        #expect(droppedFrames > 0)
        // An add past the per-cell or grid-total limit is refused.
        var full = try Heightfield(width: 4, height: 4)
        try full.add(water: limit, at: 0)
        #expect(throws: HeightfieldError.amountLimit) { try full.add(water: 1, at: 1) }
        #expect(throws: HeightfieldError.amountLimit) { try full.add(terrain: limit + 1, at: 2) }
    }

    @Test func longFrameReportsDroppedTime() throws {
        var field = try Heightfield(width: 8, height: 8, edges: .walled)
        let deep: Int64 = 1 << 30 // 16,384 units: stability limit 0.25 / √(9.81 · 16,384) ≈ 6.2e-4 s.
        try field.add(water: deep, at: field.cell(x: 3, y: 3))
        let stable = 0.25 / (field.parameters.gravity * Double(deep) / Double(Heightfield.quantaPerUnit)).squareRoot()
        let report = try field.step(by: 1.0)
        #expect(report.substeps == 64)
        #expect(abs(report.substepDuration - stable) < 1e-12)
        #expect(report.droppedTime > 0)
        #expect(abs(report.droppedTime - (1.0 - 64 * stable)) < 1e-9)
        #expect(field.isBalanced)
        #expect(Self.boundViolations(field) == 0)
    }

    @Test func zeroTimeDoesNothingAndInvalidTimesAreRefused() throws {
        var field = try Heightfield(width: 6, height: 5, edges: .open)
        try field.add(terrain: 3 * Heightfield.quantaPerUnit, at: 4)
        try field.add(water: Heightfield.quantaPerUnit, at: 7)
        _ = try field.step(by: 1.0 / 60)
        let before = field
        let report = try field.step(by: 0)
        #expect(report.substeps == 0)
        #expect(report.droppedTime == 0)
        #expect(field == before)
        #expect(throws: HeightfieldError.invalidTime) { _ = try field.step(by: -1.0 / 60) }
        #expect(throws: HeightfieldError.invalidTime) { _ = try field.step(by: Double.nan) }
        #expect(throws: HeightfieldError.invalidTime) { _ = try field.step(by: Double.infinity) }
        #expect(throws: HeightfieldError.invalidTime) { _ = try field.step(by: -Double.infinity) }
        #expect(field == before)
        #expect(HeightfieldError.invalidTime.reasonCode == "r2-f17.invalid-time")
    }

    @Test func moderateFrameUsesTwoSubsteps() throws {
        var field = try Heightfield(width: 8, height: 8, edges: .walled)
        for c in 0..<field.cellCount { try field.add(water: Heightfield.quantaPerUnit / 10, at: c) }
        let report = try field.step(by: 1.0 / 60)
        #expect(report.substeps == 2)
        #expect(report.substepDuration == 1.0 / 120)
        #expect(report.droppedTime == 0)
        #expect(!report.fluxClamped)
    }
}
