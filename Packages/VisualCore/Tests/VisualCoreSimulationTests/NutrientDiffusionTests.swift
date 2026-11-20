// NutrientDiffusionTests — feature 221 (R02-F21) T-R02F21-003 (FR-R02F21-001…003, 006; SC-R02F21-001…003). Seeded
// fields with sources, sinks and decay stay balanced to the quantum and never negative after every frame, and every
// report equals its ledger deltas; a concentrated spot only flattens and spreads at 4 · D per second; long frames are
// cut and reported; sources cap at the limit and sinks report their shortfall; a field with sources, a sink and decay
// settles; an all-zero field stays zero; bad times are refused and a time of 0 does nothing.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreSimulation

@Suite struct NutrientDiffusionTests {
    static let unit: Int64 = NutrientField.quantaPerUnit

    /// Whether no cell of any channel holds a negative amount.
    static func noNegativeAmount(_ field: NutrientField) -> Bool {
        for k in 0..<field.channels {
            for c in 0..<field.cellCount where field.amount(k, at: c) < 0 { return false }
        }
        return true
    }

    /// Whether the report's per-channel numbers equal the ledger's change from `before` to `after`.
    static func reportMatchesLedger(_ report: NutrientStepReport, before: NutrientLedger,
                                    after: NutrientLedger) -> Bool {
        for k in 0..<before.accounts.count {
            let old: NutrientAccount = before.accounts[k]
            let new: NutrientAccount = after.accounts[k]
            if report.added[k] != new.added - old.added { return false }
            if report.removed[k] != new.removed - old.removed { return false }
            if report.faded[k] != new.faded - old.faded { return false }
            if report.eaten[k] != new.eaten - old.eaten { return false }
        }
        return true
    }

    /// A seeded field: sides 2 … 24, 1 … 4 channels, D in 0 … 50, λ in 0 … 2, 0 … 4 units per cell and 0 … 4 sources
    /// and sinks.
    static func seededField(_ random: inout SeededRandom) throws -> NutrientField {
        let width: Int = random.int(2...24)
        let height: Int = random.int(2...24)
        let channels: Int = random.int(1...4)
        var rates: [Double] = []
        var fades: [Double] = []
        for _ in 0..<channels {
            rates.append(random.double() * 50)
            fades.append(random.double() * 2)
        }
        var field = try NutrientField(width: width, height: height, channels: channels, diffusion: rates,
                                      decay: fades)
        for k in 0..<channels {
            for c in 0..<field.cellCount {
                let quanta = Int64(random.int(0...Int(4 * unit)))
                try field.add(quanta, channel: k, at: c)
            }
        }
        let springs: Int = random.int(0...4)
        for _ in 0..<springs {
            let kind: NutrientSourceKind = random.int(0...1) == 0 ? .source : .sink
            let rate: Double = 0.1 + random.double() * 20
            let source = try NutrientSource(cell: random.int(0...(field.cellCount - 1)),
                                            channel: random.int(0...(channels - 1)), kind: kind, rate: rate)
            try field.addSource(source)
        }
        return field
    }

    @Test func seededFieldsBalanceAfterEveryFrame() throws {
        var random = SeededRandom(seed: 2_021)
        let start = Date()
        var failures = 0
        var substeps = 0
        for _ in 0..<20 {
            var field = try Self.seededField(&random)
            for _ in 0..<300 {
                let time: Double = random.double() * 0.4
                let before: NutrientLedger = field.ledger
                let report: NutrientStepReport = try field.step(by: time)
                substeps += report.substeps
                let balanced: Bool = field.isBalanced
                let nonNegative: Bool = Self.noNegativeAmount(field)
                let matches: Bool = Self.reportMatchesLedger(report, before: before, after: field.ledger)
                if !balanced || !nonNegative || !matches { failures += 1 }
            }
        }
        let elapsed = Date().timeIntervalSince(start)
        print("SC-R02F21-001 balance: 20 fields × 300 frames (\(substeps) sub-steps) in \(elapsed) s, failures \(failures)")
        #expect(failures == 0)
    }

    /// The amount-weighted mean squared distance of channel 0 from cell (x0, y0).
    static func spread(_ field: NutrientField, x0: Int, y0: Int) -> Double {
        var weighted = 0.0
        var sum = 0.0
        for y in 0..<field.height {
            for x in 0..<field.width {
                let a = Double(field.amount(0, at: field.cell(x: x, y: y)))
                let dx = Double(x - x0)
                let dy = Double(y - y0)
                weighted += a * (dx * dx + dy * dy)
                sum += a
            }
        }
        return sum > 0 ? weighted / sum : 0
    }

    /// The largest and smallest amount of channel 0.
    static func extremes(_ field: NutrientField) -> (high: Int64, low: Int64) {
        var high: Int64 = Int64.min
        var low: Int64 = Int64.max
        for c in 0..<field.cellCount {
            let a = field.amount(0, at: c)
            high = max(high, a)
            low = min(low, a)
        }
        return (high, low)
    }

    @Test func spotFlattensAndSpreadsAtFourD() throws {
        let rate = 2.0
        var field = try NutrientField(width: 64, height: 64, diffusion: [rate])
        let centre = field.cell(x: 32, y: 32)
        try field.add(1 << 30, channel: 0, at: centre)
        var spread0 = Self.spread(field, x0: 32, y0: 32)
        let first = spread0
        var bounds = Self.extremes(field)
        var elapsed = 0.0
        var peakRose = 0
        var lowFell = 0
        var spreadStalled = 0
        for _ in 0..<60 {
            let report: NutrientStepReport = try field.step(by: 1.0 / 60)
            elapsed += report.simulated
            let now = Self.extremes(field)
            if now.high > bounds.high { peakRose += 1 }
            if now.low < bounds.low { lowFell += 1 }
            bounds = now
            let spread = Self.spread(field, x0: 32, y0: 32)
            if spread <= spread0 { spreadStalled += 1 }
            spread0 = spread
        }
        let expected = 4 * rate * elapsed
        let measured = spread0 - first
        let error = abs(measured - expected) / expected
        print("SC-R02F21-002 spread: ΔS \(measured) over \(elapsed) s, expected 4·D·t \(expected), error \(error * 100) %")
        #expect(field.isBalanced)
        #expect(field.total(0) == 1 << 30)
        #expect(peakRose == 0)
        #expect(lowFell == 0)
        #expect(spreadStalled == 0)
        #expect(error < 0.01)
    }

    @Test func longFrameIsCutAndReported() throws {
        var field = try NutrientField(width: 64, height: 64, channels: 4, diffusion: [1_000, 10, 0, 500],
                                      decay: [0.5, 0, 1, 0])
        var random = SeededRandom(seed: 2_021)
        for k in 0..<4 {
            for c in 0..<field.cellCount { try field.add(Int64(random.int(0...Int(8 * Self.unit))), channel: k, at: c) }
        }
        let start = Date()
        let report: NutrientStepReport = try field.step(by: 3)
        let elapsed = Date().timeIntervalSince(start)
        print("long frame: 64 × 64 × 4 channels, \(report.substeps) sub-steps in \(elapsed * 1_000) ms, simulated \(report.simulated) s, dropped \(report.dropped) s")
        #expect(report.substeps == 256)
        #expect(abs(report.simulated - 256.0 / 8_000) < 1e-12)
        #expect(abs(report.dropped - (3 - 256.0 / 8_000)) < 1e-12)
        #expect(field.isBalanced)
        #expect(Self.noNegativeAmount(field))

        var slow = try NutrientField(width: 4, height: 4, diffusion: [1])
        let cut: NutrientStepReport = try slow.step(by: 3)
        #expect(cut.substeps == 2)
        #expect(cut.simulated == 0.25)
        #expect(cut.dropped == 2.75)
    }

    @Test func sourcesCapAndSinksReportShort() throws {
        var field = try NutrientField(width: 2, height: 2, diffusion: [0])
        try field.add(NutrientField.maxAmount, channel: 0, at: 0)
        try field.addSource(NutrientSource(cell: 0, channel: 0, kind: .source, rate: 1))
        try field.addSource(NutrientSource(cell: 1, channel: 0, kind: .sink, rate: 1))
        let before: NutrientLedger = field.ledger
        let report: NutrientStepReport = try field.step(by: 0.1)
        let moved = Int64((0.1 * Double(Self.unit)).rounded(.down))
        #expect(report.substeps == 1)
        #expect(report.capped == moved)
        #expect(report.short == moved)
        #expect(report.added[0] == 0)
        #expect(report.removed[0] == 0)
        #expect(field.isBalanced)
        #expect(Self.reportMatchesLedger(report, before: before, after: field.ledger))
        #expect(field.amount(0, at: 0) == NutrientField.maxAmount)
        #expect(field.amount(0, at: 1) == 0)
    }

    @Test func sourcesSinksAndDecaySettle() throws {
        var field = try NutrientField(width: 16, height: 16, diffusion: [5], decay: [1])
        try field.addSource(NutrientSource(cell: field.cell(x: 2, y: 3), channel: 0, kind: .source, rate: 4))
        try field.addSource(NutrientSource(cell: field.cell(x: 13, y: 12), channel: 0, kind: .source, rate: 2))
        try field.addSource(NutrientSource(cell: field.cell(x: 8, y: 8), channel: 0, kind: .sink, rate: 1))
        var high: Int64 = 0
        var low: Int64 = Int64.max
        var unbalanced = 0
        for frame in 0..<600 {
            _ = try field.step(by: 1.0 / 60)
            if !field.isBalanced { unbalanced += 1 }
            if frame >= 540 {
                high = max(high, field.total(0))
                low = min(low, field.total(0))
            }
        }
        let change = Double(high - low) / Double(high)
        print("SC-R02F21-003 settle: total \(low) … \(high) quanta over the last 60 frames, change \(change * 100) %")
        #expect(unbalanced == 0)
        #expect(high > 0)
        #expect(change < 0.001)
    }

    @Test func allZeroFieldStaysZero() throws {
        var field = try NutrientField(width: 8, height: 8, channels: 2, diffusion: [3, 40], decay: [1, 0])
        for _ in 0..<50 {
            let report: NutrientStepReport = try field.step(by: 1.0 / 30)
            #expect(report.added == [0, 0])
            #expect(report.faded == [0, 0])
        }
        for k in 0..<2 {
            #expect(field.total(k) == 0)
            for c in 0..<field.cellCount { #expect(field.amount(k, at: c) == 0) }
        }
        #expect(field.isBalanced)
    }

    @Test func badTimesAreRefused() throws {
        let field = try NutrientField(width: 4, height: 4, diffusion: [1])
        var copy = field
        #expect(throws: NutrientError.time) { try copy.step(by: -1) }
        #expect(throws: NutrientError.time) { try copy.step(by: Double.nan) }
        #expect(throws: NutrientError.time) { try copy.step(by: Double.infinity) }
        #expect(copy == field)
        #expect(NutrientError.time.reasonCode == "r2-f21.time")
    }

    @Test func zeroTimeDoesNothing() throws {
        var field = try NutrientField(width: 4, height: 4, diffusion: [1], decay: [1])
        try field.add(5 * Self.unit, channel: 0, at: 5)
        try field.addSource(NutrientSource(cell: 0, channel: 0, kind: .source, rate: 3))
        let before = field
        let report: NutrientStepReport = try field.step(by: 0)
        #expect(report.substeps == 0)
        #expect(report.simulated == 0)
        #expect(report.dropped == 0)
        #expect(report.grown == 0)
        #expect(field == before)
    }
}
