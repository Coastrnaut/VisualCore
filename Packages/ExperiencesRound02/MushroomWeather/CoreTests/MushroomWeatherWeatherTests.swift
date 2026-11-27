// MushroomWeatherWeatherTests — feature 491 (R02-G20-01) T-R02G2001-003 (FR-R02G2001-003, 004, 005, 014;
// SC-R02G2001-003, 004; clarifications Q1 … Q4). The exact weather against an independent reference written from the
// spec's clarifications alone: the synchronous cycle (diffusion over every orthogonal floor pair, flow (hₐ − h_b)·D/64
// truncated toward zero; evaporation ⌊h·rate·(4 + L)/4096⌋ never more than the cell holds, a vent cell at its open or
// closed rate; release r, or g once grown), the ledger (before, released, evaporated, after), the pods' integrals (the
// cell's humidity after each cycle, grown at the cycle the integral reaches G and releasing g from the next cycle), the
// colony runs (final, longest, first cycle out of band) and the judge (per cycle `dried` by lowest colony, then `mold`
// by first row-major cell; after T cycles `unstable` naming the shortest final run, lowest colony on a tie). 500 seeded
// fixtures, each run with its winning, its starting and a random arrangement, agree on every humidity value at every
// cycle and on every report value, and the ledger balances and chains every cycle; hand cases pin a band edge, the mold
// bound, a survival floor and a growth threshold one unit either side, a final run one cycle short of K, equal
// neighbours, the evaporation never exceeding the cell, and a vent and the moonlight each changing an outcome.
// Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MushroomWeatherCore

/// An independent reference of the weather, written from clarifications Q1 … Q4 only (integers, no kernel logic).
private enum ReferenceWeather {
    /// The result of one reference run.
    struct Result {
        /// The humidity of every cell (row-major) of every cycle run, cycle 0 (the start) first.
        var fields: [[Int]] = []
        /// The ledger of every cycle run, cycle 1 first.
        var ledger: [MushroomWeatherLedger] = []
        /// The cycle each slot's pod grew, nil when it did not or the slot is empty.
        var grownAt: [Int?] = []
        /// Each colony's runs.
        var colonies: [MushroomWeatherColonyRuns] = []
        /// The cycles run.
        var cycles: Int = 0
        /// The judge's failure, or nil for a win.
        var failure: MushroomWeatherFailure?
    }

    /// The evaporation rate of every cell for the arrangement's vent states.
    static func cellRates(_ level: MushroomWeatherLevel, _ arrangement: MushroomWeatherArrangement) -> [Int] {
        var rates: [Int] = level.rates
        for (i, vent) in level.vents.enumerated() {
            let index: Int = vent.cell.row * level.columns + vent.cell.column
            rates[index] = arrangement.ventsOpen[i] ? vent.openRate : vent.closedRate
        }
        return rates
    }

    /// One synchronous cycle of clarification Q2: (field, released, evaporated).
    static func cycle(_ h: [Int], level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement,
                      grown: [Bool], rates: [Int]) -> (field: [Int], released: Int, evaporated: Int) {
        let rows: Int = level.rows
        let columns: Int = level.columns
        var floor: [Bool] = Array(repeating: true, count: rows * columns)
        for cell in level.blocked { floor[cell.row * columns + cell.column] = false }
        // (1) Diffusion over every orthogonal pair of floor cells, each flow from the start of the step.
        var delta: [Int] = Array(repeating: 0, count: rows * columns)
        for row in 0..<rows {
            for column in 0..<columns {
                let a: Int = row * columns + column
                if !floor[a] { continue }
                var partners: [Int] = []
                if column + 1 < columns { partners.append(a + 1) }
                if row + 1 < rows { partners.append(a + columns) }
                for b in partners where floor[b] {
                    // Swift's `/` truncates toward zero, as the clarification requires.
                    let flow: Int = ((h[a] - h[b]) * level.diffusion) / 64
                    delta[a] -= flow
                    delta[b] += flow
                }
            }
        }
        var field: [Int] = h
        for i in 0..<field.count { field[i] += delta[i] }
        // (2) Evaporation from the diffused field.
        var evaporated: Int = 0
        for i in 0..<field.count where floor[i] {
            var loss: Int = (field[i] * rates[i] * (4 + arrangement.moonlight)) / 4096
            if loss > field[i] { loss = field[i] }
            field[i] -= loss
            evaporated += loss
        }
        // (3) Release by every placed pod.
        var released: Int = 0
        for (slot, pod) in arrangement.pods.enumerated() {
            guard let pod else { continue }
            let amount: Int = grown[slot] ? level.podRules.grownRelease : level.podRules.release
            field[pod.row * columns + pod.column] += amount
            released += amount
        }
        return (field, released, evaporated)
    }

    /// The run of clarifications Q3 and Q4, judged.
    static func run(_ level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement) -> Result {
        var result = Result()
        let columns: Int = level.columns
        let rates: [Int] = cellRates(level, arrangement)
        let slots: Int = arrangement.pods.count
        var grown: [Bool] = Array(repeating: false, count: slots)
        var integral: [Int] = Array(repeating: 0, count: slots)
        result.grownAt = Array(repeating: nil, count: slots)
        let n: Int = level.colonies.count
        var current: [Int] = Array(repeating: 0, count: n)
        var longest: [Int] = Array(repeating: 0, count: n)
        var firstOut: [Int?] = Array(repeating: nil, count: n)
        var floor: [Bool] = Array(repeating: true, count: level.rows * columns)
        for cell in level.blocked { floor[cell.row * columns + cell.column] = false }
        var h: [Int] = level.humidity
        result.fields.append(h)
        var c: Int = 1
        while c <= level.length {
            var before: Int = 0
            for v in h { before += v }
            let step = cycle(h, level: level, arrangement: arrangement, grown: grown, rates: rates)
            h = step.field
            var after: Int = 0
            for v in h { after += v }
            result.fields.append(h)
            result.ledger.append(MushroomWeatherLedger(cycle: c, before: before, released: step.released,
                                                       evaporated: step.evaporated, after: after))
            // Integrals after the three steps; grown from the next cycle on.
            for slot in 0..<slots {
                guard let pod = arrangement.pods[slot] else { continue }
                integral[slot] += h[pod.row * columns + pod.column]
                if result.grownAt[slot] == nil && integral[slot] >= level.podRules.growthThreshold {
                    result.grownAt[slot] = c
                    grown[slot] = true
                }
            }
            // Colony runs.
            for (k, colony) in level.colonies.enumerated() {
                let value: Int = h[colony.cell.row * columns + colony.cell.column]
                if colony.low <= value && value <= colony.high {
                    current[k] += 1
                    if current[k] > longest[k] { longest[k] = current[k] }
                } else {
                    current[k] = 0
                    if firstOut[k] == nil { firstOut[k] = c }
                }
            }
            result.cycles = c
            // The judge: dried by lowest colony, then mold by first row-major floor cell.
            for (k, colony) in level.colonies.enumerated() where result.failure == nil {
                if let f = colony.survivalFloor, h[colony.cell.row * columns + colony.cell.column] < f {
                    result.failure = .dried(colony: k, cycle: c)
                }
            }
            if result.failure == nil {
                for i in 0..<h.count where result.failure == nil && floor[i] && h[i] > level.moldBound {
                    result.failure = .mold(cell: MushroomWeatherCell(row: i / columns, column: i % columns), cycle: c)
                }
            }
            if result.failure != nil { break }
            c += 1
        }
        for k in 0..<n {
            result.colonies.append(MushroomWeatherColonyRuns(finalRun: current[k], longestRun: longest[k],
                                                             firstOutOfBand: firstOut[k]))
        }
        if result.failure == nil {
            var shortest: Int = -1
            for k in 0..<n where current[k] < level.required {
                if shortest < 0 || current[k] < current[shortest] { shortest = k }
            }
            if shortest >= 0 { result.failure = .unstable(colony: shortest, run: current[shortest]) }
        }
        return result
    }
}

@Suite struct MushroomWeatherWeatherTests {
    /// The 500 seeded fixtures, built once (about 5 s in debug).
    static let fixtures: [MushroomWeatherFixture] = MushroomWeatherFixture.all(count: 500)

    /// Compares the kernel's run of `level` with `arrangement` to the reference; returns the kernel's failure code.
    @discardableResult
    static func compare(_ level: MushroomWeatherLevel, _ arrangement: MushroomWeatherArrangement,
                        label: String) -> String {
        let kernel: (report: MushroomWeatherReport, fields: [[Int]]) =
            MushroomWeatherForest.run(level, arrangement: arrangement, keepFields: true)
        let reference: ReferenceWeather.Result = ReferenceWeather.run(level, arrangement: arrangement)
        let report: MushroomWeatherReport = kernel.report
        #expect(kernel.fields.count == reference.fields.count, "\(label) cycles of fields")
        var firstMismatch: Int = -1
        for c in 0..<min(kernel.fields.count, reference.fields.count) where firstMismatch < 0 {
            if kernel.fields[c] != reference.fields[c] { firstMismatch = c }
        }
        #expect(firstMismatch < 0, "\(label) humidity differs first at cycle \(firstMismatch)")
        #expect(report.cycles == reference.cycles, "\(label) cycles")
        #expect(report.humidity == reference.fields[reference.fields.count - 1], "\(label) final humidity")
        #expect(report.ledger == reference.ledger, "\(label) ledger")
        #expect(report.grownAt == reference.grownAt, "\(label) growth cycles")
        #expect(report.colonies == reference.colonies, "\(label) colony runs")
        #expect(report.failure == reference.failure, "\(label) failure")
        #expect(report.wins == (reference.failure == nil), "\(label) outcome")
        // The ledger balances every cycle, chains from the start and matches the field totals.
        var total: Int = 0
        for v in level.humidity { total += v }
        for (i, entry) in report.ledger.enumerated() {
            #expect(entry.cycle == i + 1, "\(label) ledger numbering")
            #expect(entry.balances, "\(label) ledger balances at cycle \(entry.cycle)")
            #expect(entry.before == total, "\(label) ledger chains at cycle \(entry.cycle)")
            total = entry.after
            if i + 1 < kernel.fields.count {
                var sum: Int = 0
                for v in kernel.fields[i + 1] { sum += v }
                #expect(sum == entry.after, "\(label) ledger total at cycle \(entry.cycle)")
            }
        }
        return report.failure?.code ?? "won"
    }

    /// A random arrangement of `level`: 0 … P pods on distinct free floor cells in random slots, random vents and
    /// moonlight.
    static func randomArrangement(_ level: MushroomWeatherLevel,
                                  _ random: inout SeededRandom) -> MushroomWeatherArrangement {
        let colonies: Set<MushroomWeatherCell> = level.colonyCells
        var free: [MushroomWeatherCell] = []
        for i in 0..<(level.rows * level.columns) where level.floorMask[i] {
            let cell: MushroomWeatherCell = level.cell(at: i)
            if !colonies.contains(cell) { free.append(cell) }
        }
        var pods: [MushroomWeatherCell?] = Array(repeating: nil, count: level.podRules.slots)
        for slot in 0..<level.podRules.slots where random.int(0...2) > 0 && !free.isEmpty {
            let k: Int = random.int(0...(free.count - 1))
            pods[slot] = free[k]
            free.remove(at: k)
        }
        var vents: [Bool] = []
        for _ in level.vents { vents.append(random.int(0...1) == 1) }
        return MushroomWeatherArrangement(pods: pods, ventsOpen: vents, moonlight: random.int(0...3))
    }

    @Test func kernelMatchesTheReferenceOn500SeededRuns() {
        let fixtures: [MushroomWeatherFixture] = Self.fixtures
        #expect(fixtures.count == 500)
        var random = SeededRandom(seed: 4_910_003)
        var codes: [String: Int] = [:]
        for (k, fixture) in fixtures.enumerated() {
            let won: String = Self.compare(fixture.level, fixture.winning, label: "fixture \(k) winning")
            #expect(won == "won", "fixture \(k) winning arrangement wins")
            let start: String = Self.compare(fixture.level, fixture.level.start, label: "fixture \(k) start")
            #expect(start != "won", "fixture \(k) start does not win")
            codes[start, default: 0] += 1
            let arrangement: MushroomWeatherArrangement = Self.randomArrangement(fixture.level, &random)
            let other: String = Self.compare(fixture.level, arrangement, label: "fixture \(k) random")
            codes[other, default: 0] += 1
        }
        // Every judge rule and the win are exercised by the starting and random arrangements.
        for code in ["won", "dried", "mold", "unstable"] {
            #expect((codes[code] ?? 0) > 0, "failure codes \(codes)")
        }
    }

    @Test func aLoneCycleMatchesTheReferenceWithAnyGrowth() {
        let fixtures: [MushroomWeatherFixture] = Self.fixtures
        var random = SeededRandom(seed: 4_910_031)
        for (k, fixture) in fixtures.enumerated() {
            let level: MushroomWeatherLevel = fixture.level
            let arrangement: MushroomWeatherArrangement = Self.randomArrangement(level, &random)
            var grown: [Bool] = []
            for _ in arrangement.pods { grown.append(random.int(0...1) == 1) }
            let kernel: (humidity: [Int], ledger: MushroomWeatherLedger) =
                MushroomWeatherForest.cycle(level.humidity, level: level, arrangement: arrangement, grown: grown)
            let reference = ReferenceWeather.cycle(level.humidity, level: level, arrangement: arrangement,
                                                   grown: grown,
                                                   rates: ReferenceWeather.cellRates(level, arrangement))
            #expect(kernel.humidity == reference.field, "fixture \(k) lone cycle field")
            #expect(MushroomWeatherForest.rates(level, arrangement: arrangement)
                    == ReferenceWeather.cellRates(level, arrangement), "fixture \(k) rates")
            var before: Int = 0
            for v in level.humidity { before += v }
            var after: Int = 0
            for v in reference.field { after += v }
            #expect(kernel.ledger == MushroomWeatherLedger(cycle: 0, before: before, released: reference.released,
                                                           evaporated: reference.evaporated, after: after),
                    "fixture \(k) lone cycle ledger")
            #expect(kernel.ledger.balances, "fixture \(k) lone cycle balances")
        }
    }

    // MARK: Hand cases on a 6 × 6 floor

    /// The cell at `row`, `column`.
    static func cell(_ row: Int, _ column: Int) -> MushroomWeatherCell { MushroomWeatherCell(row: row, column: column) }

    /// Corner (0, 0) cut off by blocking (0, 1) and (1, 0).
    static let isolateTopLeft: [MushroomWeatherCell] = [cell(0, 1), cell(1, 0)]
    /// Corner (0, 5) cut off by blocking (0, 4) and (1, 5).
    static let isolateTopRight: [MushroomWeatherCell] = [cell(0, 4), cell(1, 5)]

    /// A 6 × 6 field of `value` with `blocked` cells 0 and `overrides` (row-major index → value).
    static func field(_ value: Int, blocked: [MushroomWeatherCell] = [], overrides: [Int: Int] = [:]) -> [Int] {
        var h: [Int] = Array(repeating: value, count: 36)
        for (i, v) in overrides { h[i] = v }
        for c in blocked { h[c.row * 6 + c.column] = 0 }
        return h
    }

    /// A 6 × 6 probe level (the "already won" rule skipped).
    static func hand(humidity: [Int], blocked: [MushroomWeatherCell] = [], diffusion: Int = 12,
                     rates: [Int] = Array(repeating: 0, count: 36), vents: [MushroomWeatherVent] = [],
                     podRules: MushroomWeatherPodRules = MushroomWeatherPodRules(slots: 1, release: 10,
                                                                                 grownRelease: 30,
                                                                                 growthThreshold: 200_000),
                     colonies: [MushroomWeatherColony], moldBound: Int = 2000, length: Int = 20, required: Int = 5,
                     pods: [MushroomWeatherCell?]? = nil, ventsOpen: [Bool]? = nil,
                     moonlight: Int = 0) throws -> MushroomWeatherLevel {
        let start = MushroomWeatherArrangement(
            pods: pods ?? Array(repeating: nil, count: podRules.slots),
            ventsOpen: ventsOpen ?? Array(repeating: false, count: vents.count), moonlight: moonlight)
        return try MushroomWeatherLevel.probe(rows: 6, columns: 6, blocked: blocked, humidity: humidity,
                                              diffusion: diffusion, rates: rates, vents: vents, podRules: podRules,
                                              colonies: colonies, moldBound: moldBound, length: length,
                                              required: required, start: start)
    }

    /// The run of `level`'s start, also compared with the reference.
    static func runStart(_ level: MushroomWeatherLevel,
                         label: String) -> (report: MushroomWeatherReport, fields: [[Int]]) {
        Self.compare(level, level.start, label: label)
        return MushroomWeatherForest.run(level, arrangement: level.start, keepFields: true)
    }

    @Test func equalNeighboursExchangeNothingAndFlowsAreAntisymmetric() throws {
        // A uniform floor with no evaporation and no pod: every cycle's field is the start.
        let level: MushroomWeatherLevel = try Self.hand(humidity: Self.field(500),
                                                        colonies: [MushroomWeatherColony(cell: Self.cell(2, 2),
                                                                                         low: 500, high: 500)])
        let run = Self.runStart(level, label: "uniform")
        #expect(run.fields.count == 21)
        for field in run.fields { #expect(field == level.humidity) }
        for entry in run.report.ledger {
            #expect(entry.before == 18_000 && entry.released == 0 && entry.evaporated == 0 && entry.after == 18_000)
        }
        for d in MushroomWeatherLevel.diffusions {
            #expect(MushroomWeatherForest.flow(700, 700, diffusion: d) == 0)
            for (a, b) in [(0, 5), (0, 6), (13, 2), (10_000, 0), (1, 9_999)] {
                #expect(MushroomWeatherForest.flow(a, b, diffusion: d) == ((a - b) * d) / 64)
                #expect(MushroomWeatherForest.flow(a, b, diffusion: d) == -MushroomWeatherForest.flow(b, a, diffusion: d))
            }
        }
        // Truncation toward zero both ways: 5·12/64 = 0.94 → 0 and −0.94 → 0; 6·12/64 = 1.125 → ±1.
        #expect(MushroomWeatherForest.flow(5, 0, diffusion: 12) == 0)
        #expect(MushroomWeatherForest.flow(0, 5, diffusion: 12) == 0)
        #expect(MushroomWeatherForest.flow(6, 0, diffusion: 12) == 1)
        #expect(MushroomWeatherForest.flow(0, 6, diffusion: 12) == -1)
    }

    @Test func evaporationNeverExceedsTheCell() {
        // rate·(4 + L) ≤ 200·7 = 1400 < 4096, so the cap cannot bind: the loss is ⌊h·rate·(4 + L)/4096⌋ ≤ h.
        for h in [0, 1, 2, 3, 7, 100, 999, 1000, 4095, 4096, 9_999, 10_000, 10_080] {
            for rate in [0, 1, 50, 199, 200] {
                for light in MushroomWeatherLevel.moonlightLevels {
                    let loss: Int = MushroomWeatherForest.evaporation(h, rate: rate, moonlight: light)
                    #expect(loss == (h * rate * (4 + light)) / 4096, "h \(h) rate \(rate) L \(light)")
                    #expect(loss >= 0 && loss <= h, "h \(h) rate \(rate) L \(light)")
                }
            }
        }
        // 1024·100·4/4096 = 100; at L = 3, 1024·100·7/4096 = 175.
        #expect(MushroomWeatherForest.evaporation(1024, rate: 100, moonlight: 0) == 100)
        #expect(MushroomWeatherForest.evaporation(1024, rate: 100, moonlight: 3) == 175)
    }

    @Test func aColonyExactlyOnABandEdgeIsInsideAndOneUnitBeyondIsNot() throws {
        // The uniform floor of 500 never changes; the colony at (2, 2) holds 500 every cycle.
        func outcome(low: Int, high: Int) throws -> MushroomWeatherReport {
            let level: MushroomWeatherLevel = try Self.hand(
                humidity: Self.field(500), colonies: [MushroomWeatherColony(cell: Self.cell(2, 2), low: low,
                                                                            high: high)])
            return Self.runStart(level, label: "band \(low) … \(high)").report
        }
        let onLow: MushroomWeatherReport = try outcome(low: 500, high: 600)
        #expect(onLow.wins)
        #expect(onLow.colonies[0] == MushroomWeatherColonyRuns(finalRun: 20, longestRun: 20, firstOutOfBand: nil))
        #expect(try outcome(low: 501, high: 600).failure == .unstable(colony: 0, run: 0))
        #expect(try outcome(low: 400, high: 500).wins)
        let above: MushroomWeatherReport = try outcome(low: 400, high: 499)
        #expect(above.failure == .unstable(colony: 0, run: 0))
        #expect(above.colonies[0] == MushroomWeatherColonyRuns(finalRun: 0, longestRun: 0, firstOutOfBand: 1))
    }

    @Test func aCellExactlyAtTheMoldBoundIsNotMoldAndOneUnitAboveIs() throws {
        // A uniform floor with no evaporation, two pods releasing 1 per cycle at (2, 3) and (1, 4). A one-unit
        // difference never flows (1·12/64 = 0), so each pod cell gains exactly 1 per cycle.
        let rules = MushroomWeatherPodRules(slots: 2, release: 1, grownRelease: 1, growthThreshold: 200_000)
        let colony = MushroomWeatherColony(cell: Self.cell(5, 0), low: 0, high: 1000)
        let atBound: MushroomWeatherLevel = try Self.hand(humidity: Self.field(999), podRules: rules,
                                                          colonies: [colony], moldBound: 1000,
                                                          pods: [Self.cell(2, 3), Self.cell(1, 4)])
        let run = Self.runStart(atBound, label: "mold 999")
        #expect(run.fields[1][2 * 6 + 3] == 1000 && run.fields[1][1 * 6 + 4] == 1000)
        // Cycle 1 ends at exactly M: not mold; cycle 2 ends at M + 1: mold, first row-major cell named.
        #expect(run.report.failure == .mold(cell: Self.cell(1, 4), cycle: 2))
        #expect(run.report.cycles == 2)
        let fromBound: MushroomWeatherLevel = try Self.hand(humidity: Self.field(1000), podRules: rules,
                                                            colonies: [colony], moldBound: 1000,
                                                            pods: [Self.cell(2, 3), Self.cell(1, 4)])
        #expect(Self.runStart(fromBound, label: "mold 1000").report.failure == .mold(cell: Self.cell(1, 4), cycle: 1))
        let noPods: MushroomWeatherLevel = try Self.hand(humidity: Self.field(1000), podRules: rules,
                                                         colonies: [colony], moldBound: 1000)
        #expect(Self.runStart(noPods, label: "at bound, no pods").report.wins)
    }

    @Test func aSensitiveColonyExactlyAtItsFloorLivesAndOneUnitBelowDries() throws {
        // Colony 1 at the cut-off corner (0, 0), 1024 units at rate 100: cycle 1 loses 100 → 924, cycle 2 loses
        // ⌊924·400/4096⌋ = 90 → 834. Colony 0 sits on the still floor and is never dried.
        var rates: [Int] = Array(repeating: 0, count: 36)
        rates[0] = 100
        func run(floor: Int) throws -> MushroomWeatherReport {
            let level: MushroomWeatherLevel = try Self.hand(
                humidity: Self.field(1024, blocked: Self.isolateTopLeft), blocked: Self.isolateTopLeft,
                rates: rates,
                colonies: [MushroomWeatherColony(cell: Self.cell(4, 4), low: 1024, high: 1024, survivalFloor: 0),
                           MushroomWeatherColony(cell: Self.cell(0, 0), low: 925, high: 1024,
                                                 survivalFloor: floor)])
            return Self.runStart(level, label: "floor \(floor)").report
        }
        let atFloor: MushroomWeatherReport = try run(floor: 924)
        #expect(atFloor.failure == .dried(colony: 1, cycle: 2))
        #expect(atFloor.humidity[0] == 834)
        let aboveFloor: MushroomWeatherReport = try run(floor: 925)
        #expect(aboveFloor.failure == .dried(colony: 1, cycle: 1))
        #expect(aboveFloor.cycles == 1)
        #expect(aboveFloor.humidity[0] == 924)
    }

    @Test func aGrowthIntegralExactlyAtItsThresholdGrowsAndOneUnitShortWaits() throws {
        // A pod at the cut-off corner (0, 5), 480 units, no evaporation, release 10, grown 30: the cell holds 490,
        // 500, 510 after cycles 1 … 3, so the integral is 490, 990, 1500. G = 1500 grows at cycle 3 (then 510 +
        // 30 per cycle, 1020 > 1000 at cycle 20: mold); G = 1501 grows at cycle 4 (520 + 30 per cycle, exactly 1000
        // at cycle 20: won).
        let colony = MushroomWeatherColony(cell: Self.cell(5, 0), low: 480, high: 480)
        func run(threshold: Int) throws -> (report: MushroomWeatherReport, fields: [[Int]]) {
            let rules = MushroomWeatherPodRules(slots: 1, release: 10, grownRelease: 30, growthThreshold: threshold)
            let level: MushroomWeatherLevel = try Self.hand(
                humidity: Self.field(480, blocked: Self.isolateTopRight), blocked: Self.isolateTopRight,
                podRules: rules, colonies: [colony], moldBound: 1000, pods: [Self.cell(0, 5)])
            return Self.runStart(level, label: "threshold \(threshold)")
        }
        let at = try run(threshold: 1500)
        #expect(at.report.grownAt == [3])
        #expect(at.fields[3][5] == 510 && at.fields[4][5] == 540)
        #expect(at.report.failure == .mold(cell: Self.cell(0, 5), cycle: 20))
        let short = try run(threshold: 1501)
        #expect(short.report.grownAt == [4])
        #expect(short.fields[4][5] == 520 && short.fields[5][5] == 550)
        #expect(short.report.humidity[5] == 1000)
        #expect(short.report.wins)
    }

    @Test func aFinalRunOneCycleShortOfTheRequirementIsUnstable() throws {
        // The cut-off corner (0, 0) dries from 1024 at rate 100, strictly falling every cycle; a band whose top is
        // the value at cycle T − K + 1 holds for the last K cycles, one unit lower only for the last K − 1.
        var rates: [Int] = Array(repeating: 0, count: 36)
        rates[0] = 100
        let still = MushroomWeatherColony(cell: Self.cell(4, 4), low: 1024, high: 1024)
        let probe: MushroomWeatherLevel = try Self.hand(
            humidity: Self.field(1024, blocked: Self.isolateTopLeft), blocked: Self.isolateTopLeft, rates: rates,
            colonies: [still], required: 12)
        let fields: [[Int]] = Self.runStart(probe, label: "drying probe").fields
        for c in 1..<fields.count { #expect(fields[c][0] < fields[c - 1][0], "falls at cycle \(c)") }
        let edge: Int = fields[20 - 12 + 1][0]
        func run(high: Int) throws -> MushroomWeatherReport {
            let level: MushroomWeatherLevel = try Self.hand(
                humidity: Self.field(1024, blocked: Self.isolateTopLeft), blocked: Self.isolateTopLeft,
                rates: rates, colonies: [still, MushroomWeatherColony(cell: Self.cell(0, 0), low: 0, high: high)],
                required: 12)
            return Self.runStart(level, label: "final run high \(high)").report
        }
        let enough: MushroomWeatherReport = try run(high: edge)
        #expect(enough.wins)
        #expect(enough.colonies[1] == MushroomWeatherColonyRuns(finalRun: 12, longestRun: 12, firstOutOfBand: 1))
        let short: MushroomWeatherReport = try run(high: edge - 1)
        #expect(short.failure == .unstable(colony: 1, run: 11))
        #expect(short.colonies[1] == MushroomWeatherColonyRuns(finalRun: 11, longestRun: 11, firstOutOfBand: 1))
    }

    @Test func aVentChangesTheOutcome() throws {
        // A vent over the cut-off colony cell (0, 0): closed (rate 0) it holds 1024 for ever; open (rate 100) it dries.
        let vent = MushroomWeatherVent(cell: Self.cell(0, 0), openRate: 100, closedRate: 0)
        var rates: [Int] = Array(repeating: 0, count: 36)
        rates[0] = 50  // the cell's own rate is replaced by the vent's
        func run(open: Bool) throws -> MushroomWeatherReport {
            let level: MushroomWeatherLevel = try Self.hand(
                humidity: Self.field(1024, blocked: Self.isolateTopLeft), blocked: Self.isolateTopLeft, rates: rates,
                vents: [vent], colonies: [MushroomWeatherColony(cell: Self.cell(0, 0), low: 1024, high: 1024)],
                ventsOpen: [open])
            return Self.runStart(level, label: "vent open \(open)").report
        }
        #expect(try run(open: false).wins)
        let open: MushroomWeatherReport = try run(open: true)
        #expect(open.failure == .unstable(colony: 0, run: 0))
        #expect(open.ledger[0].evaporated == 100)
    }

    @Test func theMoonlightChangesTheOutcome() throws {
        // The cut-off colony cell (0, 0) at rate 100: a band fitted to its last 5 cycles under L = 0 wins there and
        // fails under L = 3, which evaporates 7/4 as fast.
        var rates: [Int] = Array(repeating: 0, count: 36)
        rates[0] = 100
        let still = MushroomWeatherColony(cell: Self.cell(4, 4), low: 1024, high: 1024)
        let dark: MushroomWeatherLevel = try Self.hand(
            humidity: Self.field(1024, blocked: Self.isolateTopLeft), blocked: Self.isolateTopLeft, rates: rates,
            colonies: [still])
        let fields: [[Int]] = Self.runStart(dark, label: "moonlight probe").fields
        var low: Int = Int.max
        var high: Int = 0
        for c in 16...20 {
            low = min(low, fields[c][0])
            high = max(high, fields[c][0])
        }
        func run(moonlight: Int) throws -> MushroomWeatherReport {
            let level: MushroomWeatherLevel = try Self.hand(
                humidity: Self.field(1024, blocked: Self.isolateTopLeft), blocked: Self.isolateTopLeft, rates: rates,
                colonies: [still, MushroomWeatherColony(cell: Self.cell(0, 0), low: low, high: high)],
                moonlight: moonlight)
            return Self.runStart(level, label: "moonlight \(moonlight)").report
        }
        #expect(try run(moonlight: 0).wins)
        let bright: MushroomWeatherReport = try run(moonlight: 3)
        #expect(bright.failure == .unstable(colony: 1, run: 0))
        #expect(bright.ledger[0].evaporated == 175)
    }
}
