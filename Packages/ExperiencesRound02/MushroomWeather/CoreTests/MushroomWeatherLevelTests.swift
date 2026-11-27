// MushroomWeatherLevelTests — feature 491 (R02-G20-01) T-R02G2001-002 (FR-R02G2001-001, 002, 003, 004, 005, 009, 013,
// 014; SC-R02G2001-001, 003, 004, 005). The level's rules (every range and rule refused by name: id, difficulty, rows,
// columns, blocked cells, humidity, a cell above the mold bound, diffusion, rates, vents, pod rules, colonies, bands,
// survival floors, mold bound, length, required cycles, the starting pods, vent states and moonlight, the budget, a
// sensitive colony starting below its floor, a starting arrangement that already wins), the fixtures' known
// arrangements, the ledger, hand-computed cycles (two-cell diffusion both ways, evaporation and its cap, growth exactly
// at and one unit short of the threshold, the three failures), its words, and the stored form (round trip, damaged,
// edited, newer and older forms refused). Explicit types, plain loops.
import Foundation
import Testing
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherLevelTests {
    /// The first fixture, the base of every refusal case.
    static let base: MushroomWeatherFixture = MushroomWeatherFixture.all(count: 1)[0]

    /// A copy of the base level with some values changed.
    static func variant(id: String? = nil, difficulty: Int? = nil, rows: Int? = nil, columns: Int? = nil,
                        blocked: [MushroomWeatherCell]? = nil, humidity: [Int]? = nil, diffusion: Int? = nil,
                        rates: [Int]? = nil, vents: [MushroomWeatherVent]? = nil,
                        podRules: MushroomWeatherPodRules? = nil, colonies: [MushroomWeatherColony]? = nil,
                        moldBound: Int? = nil, length: Int? = nil, required: Int? = nil,
                        start: MushroomWeatherArrangement? = nil, budget: Int? = nil) throws -> MushroomWeatherLevel {
        let l: MushroomWeatherLevel = base.level
        return try MushroomWeatherLevel(id: id ?? l.id, seed: l.seed, difficulty: difficulty ?? l.difficulty,
                                        rows: rows ?? l.rows, columns: columns ?? l.columns,
                                        blocked: blocked ?? l.blocked, humidity: humidity ?? l.humidity,
                                        diffusion: diffusion ?? l.diffusion, rates: rates ?? l.rates,
                                        vents: vents ?? l.vents, podRules: podRules ?? l.podRules,
                                        colonies: colonies ?? l.colonies, moldBound: moldBound ?? l.moldBound,
                                        length: length ?? l.length, required: required ?? l.required,
                                        start: start ?? l.start, budget: budget ?? l.budget)
    }

    /// Pod rules equal to the base's except the named values.
    static func podRules(slots: Int? = nil, release: Int? = nil, grown: Int? = nil,
                         threshold: Int? = nil) -> MushroomWeatherPodRules {
        let r: MushroomWeatherPodRules = base.level.podRules
        return MushroomWeatherPodRules(slots: slots ?? r.slots, release: release ?? r.release,
                                       grownRelease: grown ?? r.grownRelease,
                                       growthThreshold: threshold ?? r.growthThreshold)
    }

    /// The base's starting arrangement with some values changed.
    static func start(pods: [MushroomWeatherCell?]? = nil, ventsOpen: [Bool]? = nil,
                      moonlight: Int? = nil) -> MushroomWeatherArrangement {
        let s: MushroomWeatherArrangement = base.level.start
        return MushroomWeatherArrangement(pods: pods ?? s.pods, ventsOpen: ventsOpen ?? s.ventsOpen,
                                          moonlight: moonlight ?? s.moonlight)
    }

    /// The reason payload of a level refusal, or "none".
    static func refusal(_ build: () throws -> MushroomWeatherLevel) -> String {
        do {
            _ = try build()
            return "none"
        } catch let error as MushroomWeatherError {
            if case .level(let name) = error { return name }
            return error.reasonCode
        } catch {
            return "other"
        }
    }

    /// A hand-made 6 × 6 probe level whose floor is `floor` (every other cell blocked), with the given humidity and
    /// rates by cell (0 elsewhere), no vents, one colony (wide band unless given), and pods per `pods`.
    static func hand(floor: [MushroomWeatherCell], humidity: [MushroomWeatherCell: Int],
                     rates: [MushroomWeatherCell: Int] = [:], diffusion: Int = 8,
                     colony: MushroomWeatherColony, podRules: MushroomWeatherPodRules? = nil,
                     pods: [MushroomWeatherCell?] = [nil], moonlight: Int = 0, moldBound: Int = 10_000,
                     length: Int = 20, required: Int = 5) throws -> MushroomWeatherLevel {
        let floorSet: Set<MushroomWeatherCell> = Set(floor)
        var blocked: [MushroomWeatherCell] = []
        var h: [Int] = []
        var r: [Int] = []
        for row in 0..<6 {
            for column in 0..<6 {
                let cell = MushroomWeatherCell(row: row, column: column)
                if !floorSet.contains(cell) { blocked.append(cell) }
                h.append(humidity[cell] ?? 0)
                r.append(rates[cell] ?? 0)
            }
        }
        let rules: MushroomWeatherPodRules = podRules
            ?? MushroomWeatherPodRules(slots: pods.count, release: 10, grownRelease: 80, growthThreshold: 100)
        return try MushroomWeatherLevel.probe(rows: 6, columns: 6, blocked: blocked, humidity: h,
                                              diffusion: diffusion, rates: r, vents: [], podRules: rules,
                                              colonies: [colony], moldBound: moldBound, length: length,
                                              required: required,
                                              start: MushroomWeatherArrangement(pods: pods, ventsOpen: [],
                                                                                moonlight: moonlight))
    }

    static let a = MushroomWeatherCell(row: 0, column: 0)
    static let b = MushroomWeatherCell(row: 0, column: 1)
    static let far = MushroomWeatherCell(row: 5, column: 5)

    @Test func aValidLevelBuildsAndRoundTrips() throws {
        let level: MushroomWeatherLevel = Self.base.level
        let data: Data = level.encoded()
        let decoded: MushroomWeatherLevel = try MushroomWeatherLevel.decode(data)
        #expect(decoded == level && decoded.fingerprint == level.fingerprint)
        let json: MushroomWeatherLevel = try JSONDecoder().decode(MushroomWeatherLevel.self, from: data)
        #expect(json == level)
        #expect(level.encoded() == data)
        #expect(level.fingerprint.count == 64)
        #expect(level.blocked == level.blocked.sorted())
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix("{\"blocked\":") && text.contains("\"fingerprint\":\"\(level.fingerprint)\""))
    }

    @Test func theKnownArrangementsWinAndTheStartsDoNot() {
        for fixture in MushroomWeatherFixture.all(count: 30) {
            #expect(!fixture.level.startReport.wins)
            let report: MushroomWeatherReport = MushroomWeatherForest.report(fixture.level, arrangement: fixture.winning)
            #expect(report.wins && report.cycles == fixture.level.length)
            for runs in report.colonies { #expect(runs.finalRun >= fixture.level.required) }
            #expect(fixture.actions.last == .run && fixture.actions.count - 1 <= fixture.level.budget)
        }
    }

    @Test func theFixturesAreDeterministic() {
        let first: [MushroomWeatherFixture] = MushroomWeatherFixture.all(count: 5)
        let second: [MushroomWeatherFixture] = MushroomWeatherFixture.all(count: 5)
        for i in 0..<5 {
            #expect(first[i].level == second[i].level && first[i].actions == second[i].actions)
        }
    }

    @Test func theLedgerBalancesEveryCycle() {
        for fixture in MushroomWeatherFixture.all(count: 30) {
            let level: MushroomWeatherLevel = fixture.level
            for arrangement in [level.start, fixture.winning] {
                let run = MushroomWeatherForest.run(level, arrangement: arrangement, keepFields: true)
                #expect(run.fields.count == run.report.cycles + 1)
                #expect(run.report.ledger.count == run.report.cycles)
                var total: Int = 0
                for value in level.humidity { total += value }
                for (i, entry) in run.report.ledger.enumerated() {
                    #expect(entry.cycle == i + 1 && entry.balances && entry.before == total)
                    var sum: Int = 0
                    for value in run.fields[i + 1] {
                        #expect(value >= 0)
                        sum += value
                    }
                    #expect(entry.after == sum)
                    total = entry.after
                }
                #expect(run.fields.last == run.report.humidity)
                for (i, value) in run.report.humidity.enumerated() where !level.floorMask[i] { #expect(value == 0) }
            }
        }
    }

    @Test func diffusionBetweenTwoCellsIsExactAndTruncatesTowardZero() throws {
        let colony = MushroomWeatherColony(cell: Self.b, low: 0, high: 10_000)
        let level: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.b], humidity: [Self.a: 640],
                                                        colony: colony)
        let step = MushroomWeatherForest.cycle(level.humidity, level: level, arrangement: level.start, grown: [false])
        #expect(step.humidity[level.index(of: Self.a)] == 560 && step.humidity[level.index(of: Self.b)] == 80)
        #expect(step.ledger == MushroomWeatherLedger(cycle: 0, before: 640, released: 0, evaporated: 0, after: 640))
        // (0 − 100)·1/64 = −1.5625 → −1 (toward zero): one unit flows from b to a.
        let slow: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.b], humidity: [Self.b: 100], diffusion: 1,
                                                       colony: colony)
        let back = MushroomWeatherForest.cycle(slow.humidity, level: slow, arrangement: slow.start, grown: [false])
        #expect(back.humidity[slow.index(of: Self.a)] == 1 && back.humidity[slow.index(of: Self.b)] == 99)
        #expect(MushroomWeatherForest.flow(100, 0, diffusion: 1) == 1 && MushroomWeatherForest.flow(0, 100, diffusion: 1) == -1)
        #expect(MushroomWeatherForest.flow(37, 37, diffusion: 12) == 0)
        // Two cells not adjacent exchange nothing.
        let apart: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 640],
                                                        colony: MushroomWeatherColony(cell: Self.far, low: 0, high: 10_000))
        let none = MushroomWeatherForest.cycle(apart.humidity, level: apart, arrangement: apart.start, grown: [false])
        #expect(none.humidity == apart.humidity)
    }

    @Test func evaporationIsExactAndNeverExceedsTheCell() throws {
        #expect(MushroomWeatherForest.evaporation(4096, rate: 200, moonlight: 3) == 1400)
        #expect(MushroomWeatherForest.evaporation(1000, rate: 200, moonlight: 3) == 341)
        #expect(MushroomWeatherForest.evaporation(1000, rate: 50, moonlight: 0) == 48)
        #expect(MushroomWeatherForest.evaporation(1, rate: 200, moonlight: 3) == 0)
        #expect(MushroomWeatherForest.evaporation(0, rate: 200, moonlight: 3) == 0)
        for h in [0, 1, 2, 3, 100, 10_080] {
            for rate in [0, 1, 99, 200] {
                for moon in 0...3 {
                    let e: Int = MushroomWeatherForest.evaporation(h, rate: rate, moonlight: moon)
                    #expect(e >= 0 && e <= h)
                }
            }
        }
        let colony = MushroomWeatherColony(cell: Self.far, low: 0, high: 10_000)
        let level: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 1000],
                                                        rates: [Self.a: 200], colony: colony, moonlight: 3)
        let step = MushroomWeatherForest.cycle(level.humidity, level: level, arrangement: level.start, grown: [false])
        #expect(step.humidity[0] == 659 && step.ledger.evaporated == 341 && step.ledger.balances)
    }

    @Test func aPodGrowsExactlyAtItsThreshold() throws {
        let colony = MushroomWeatherColony(cell: Self.far, low: 0, high: 10_000)
        // Isolated pod cell from 0, release 10: humidity 10·n, integral 10·n(n+1)/2 = 100 at cycle 4.
        let rules = MushroomWeatherPodRules(slots: 1, release: 10, grownRelease: 80, growthThreshold: 100)
        let level: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.far: 500],
                                                        colony: colony, podRules: rules, pods: [Self.a])
        let run = MushroomWeatherForest.run(level, arrangement: level.start, keepFields: true)
        #expect(run.report.grownAt == [4])
        #expect(run.fields[4][0] == 40 && run.fields[5][0] == 120 && run.fields[6][0] == 200)
        #expect(run.report.ledger[3].released == 10 && run.report.ledger[4].released == 80)
        #expect(run.report.wins)
        // One unit more: growth at cycle 5 (integral 150), grown release from cycle 6.
        let later = MushroomWeatherPodRules(slots: 1, release: 10, grownRelease: 80, growthThreshold: 101)
        let short: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.far: 500],
                                                        colony: colony, podRules: later, pods: [Self.a])
        let run2 = MushroomWeatherForest.run(short, arrangement: short.start, keepFields: true)
        #expect(run2.report.grownAt == [5] && run2.fields[5][0] == 50 && run2.fields[6][0] == 130)
    }

    @Test func theJudgeNamesEachFailure() throws {
        // Dried: a sensitive colony at 1000 with floor 900 loses 341 in the first cycle.
        let sensitive = MushroomWeatherColony(cell: Self.a, low: 900, high: 1000, survivalFloor: 900)
        let dry: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 1000],
                                                      rates: [Self.a: 200], colony: sensitive, moonlight: 3)
        #expect(dry.startReport.failure == .dried(colony: 0, cycle: 1))
        #expect(dry.startReport.colonies[0].firstOutOfBand == 1)
        // Exactly at the floor is alive (rate 0, the colony holds 900).
        let alive = MushroomWeatherColony(cell: Self.a, low: 900, high: 1000, survivalFloor: 900)
        let still: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 900],
                                                        colony: alive)
        #expect(still.startReport.wins)
        // Mold: a pod cell at M − 5 releasing 10 exceeds M at cycle 1; at M − 10 it sits exactly at M (not mold).
        let colony = MushroomWeatherColony(cell: Self.far, low: 0, high: 1000)
        let moldy: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 995],
                                                        colony: colony, pods: [Self.a], moldBound: 1000)
        #expect(moldy.startReport.failure == .mold(cell: Self.a, cycle: 1))
        let edge: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 990],
                                                       colony: colony, pods: [Self.a], moldBound: 1000, length: 20)
        #expect(edge.startReport.failure == .mold(cell: Self.a, cycle: 2))
        // Unstable: an isolated colony drying from 5000 at rate 200 (moonlight 0) enters a band 0 … h₁₆ at cycle 16,
        // so its final run is 5 (wins with K 5); with the band 0 … h₁₇ the final run is 4 (unstable).
        var h: [Int] = [5000]
        for _ in 1...20 { h.append(h[h.count - 1] - h[h.count - 1] * 200 * 4 / 4096) }
        #expect(h[16] > h[17] && h[15] > h[16])
        let late: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 5000],
                                                       rates: [Self.a: 200],
                                                       colony: MushroomWeatherColony(cell: Self.a, low: 0, high: h[16]),
                                                       length: 20, required: 5)
        #expect(late.startReport.wins && late.startReport.colonies[0].finalRun == 5)
        #expect(late.startReport.humidity[0] == h[20])
        let short: MushroomWeatherLevel = try Self.hand(floor: [Self.a, Self.far], humidity: [Self.a: 5000],
                                                        rates: [Self.a: 200],
                                                        colony: MushroomWeatherColony(cell: Self.a, low: 0, high: h[17]),
                                                        length: 20, required: 5)
        #expect(short.startReport.failure == .unstable(colony: 0, run: 4))
        #expect(short.startReport.colonies[0] == MushroomWeatherColonyRuns(finalRun: 4, longestRun: 4,
                                                                           firstOutOfBand: 1))
    }

    @Test func startingArrangementsThatWinAreRefused() {
        let l: MushroomWeatherLevel = Self.base.level
        #expect(Self.refusal { try Self.variant(start: Self.base.winning, budget: l.budget) } == "already won")
    }

    @Test func everyRangeIsRefusedByName() {
        let l: MushroomWeatherLevel = Self.base.level
        let cells: Int = l.rows * l.columns
        let floorCells: [MushroomWeatherCell] = (0..<cells).map { l.cell(at: $0) }.filter { l.isFloor($0) }
        let colonyCells: Set<MushroomWeatherCell> = l.colonyCells
        let free: [MushroomWeatherCell] = floorCells.filter { !colonyCells.contains($0) }
        let colony0: MushroomWeatherColony = l.colonies[0]
        let blockedCell: MushroomWeatherCell? = l.blocked.first
        let outside = MushroomWeatherCell(row: l.rows, column: 0)
        var tooWet: [Int] = l.humidity
        tooWet[l.index(of: free[0])] = l.moldBound + 1
        var negative: [Int] = l.humidity
        negative[l.index(of: free[0])] = -1
        var badRates: [Int] = l.rates
        badRates[0] = 201
        var podsOnColony: [MushroomWeatherCell?] = l.start.pods
        podsOnColony[0] = colony0.cell
        var podsShared: [MushroomWeatherCell?] = Array(repeating: nil, count: l.podRules.slots)
        podsShared[0] = free[0]
        podsShared[1] = free[0]
        var podsOff: [MushroomWeatherCell?] = Array(repeating: nil, count: l.podRules.slots)
        podsOff[0] = outside
        var cases: [(String, () throws -> MushroomWeatherLevel)] = [
            ("id", { try Self.variant(id: "Bad Id") }),
            ("difficulty", { try Self.variant(difficulty: 0) }),
            ("difficulty", { try Self.variant(difficulty: 6) }),
            ("rows", { try Self.variant(rows: 5) }),
            ("rows", { try Self.variant(rows: 13) }),
            ("columns", { try Self.variant(columns: 5) }),
            ("columns", { try Self.variant(columns: 15) }),
            ("blocked outside", { try Self.variant(blocked: l.blocked + [outside]) }),
            ("mold bound", { try Self.variant(moldBound: 999) }),
            ("mold bound", { try Self.variant(moldBound: 10_001) }),
            ("humidity", { try Self.variant(humidity: Array(l.humidity.dropLast())) }),
            ("humidity", { try Self.variant(humidity: negative) }),
            ("cell above mold bound", { try Self.variant(humidity: tooWet) }),
            ("diffusion", { try Self.variant(diffusion: 0) }),
            ("diffusion", { try Self.variant(diffusion: 13) }),
            ("rates", { try Self.variant(rates: badRates) }),
            ("rates", { try Self.variant(rates: Array(l.rates.dropLast())) }),
            ("vents", { try Self.variant(vents: Array(repeating: l.vents[0], count: 7),
                                         start: Self.start(ventsOpen: Array(repeating: false, count: 7))) }),
            ("vent off floor", { try Self.variant(vents: [MushroomWeatherVent(cell: outside, openRate: 1, closedRate: 0)]
                                                     + l.vents.dropFirst()) }),
            ("vent rate", { try Self.variant(vents: [MushroomWeatherVent(cell: l.vents[0].cell, openRate: 201,
                                                                         closedRate: 0)] + l.vents.dropFirst()) }),
            ("vents share a cell", { try Self.variant(vents: l.vents + [l.vents[0]],
                                                      start: Self.start(ventsOpen: l.start.ventsOpen + [false])) }),
            ("slots", { try Self.variant(podRules: Self.podRules(slots: 7)) }),
            ("release", { try Self.variant(podRules: Self.podRules(release: 0)) }),
            ("release", { try Self.variant(podRules: Self.podRules(release: 41, grown: 80)) }),
            ("grown release", { try Self.variant(podRules: Self.podRules(release: 20, grown: 19)) }),
            ("grown release", { try Self.variant(podRules: Self.podRules(grown: 81)) }),
            ("growth threshold", { try Self.variant(podRules: Self.podRules(threshold: 99)) }),
            ("growth threshold", { try Self.variant(podRules: Self.podRules(threshold: 200_001)) }),
            ("colonies", { try Self.variant(colonies: []) }),
            ("colonies", { try Self.variant(colonies: Array(repeating: colony0, count: 7)) }),
            ("colony off floor", { try Self.variant(colonies: [MushroomWeatherColony(cell: outside, low: 0, high: 1)]) }),
            ("band", { try Self.variant(colonies: [MushroomWeatherColony(cell: colony0.cell, low: 5, high: 4)]) }),
            ("band", { try Self.variant(colonies: [MushroomWeatherColony(cell: colony0.cell, low: 0,
                                                                         high: l.moldBound + 1)]) }),
            ("survival floor", { try Self.variant(colonies: [MushroomWeatherColony(cell: colony0.cell, low: 5, high: 9,
                                                                                   survivalFloor: 6)]) }),
            ("survival floor", { try Self.variant(colonies: [MushroomWeatherColony(cell: colony0.cell, low: 5, high: 9,
                                                                                   survivalFloor: -1)]) }),
            ("colonies share a cell", { try Self.variant(colonies: [colony0, colony0]) }),
            ("length", { try Self.variant(length: 19) }),
            ("length", { try Self.variant(length: 201) }),
            ("required cycles", { try Self.variant(required: 4) }),
            ("required cycles", { try Self.variant(required: l.length + 1) }),
            ("pods", { try Self.variant(start: Self.start(pods: l.start.pods + [nil])) }),
            ("pod off floor", { try Self.variant(start: Self.start(pods: podsOff)) }),
            ("pod on colony", { try Self.variant(start: Self.start(pods: podsOnColony)) }),
            ("pods share a cell", { try Self.variant(start: Self.start(pods: podsShared)) }),
            ("vent states", { try Self.variant(start: Self.start(ventsOpen: l.start.ventsOpen + [true])) }),
            ("moonlight", { try Self.variant(start: Self.start(moonlight: 4)) }),
            ("moonlight", { try Self.variant(start: Self.start(moonlight: -1)) }),
            ("budget", { try Self.variant(budget: 0) }),
            ("budget", { try Self.variant(budget: 13) }),
        ]
        if let blockedCell {
            cases.append(("blocked duplicate", { try Self.variant(blocked: l.blocked + [blockedCell]) }))
            var wetBlock: [Int] = l.humidity
            wetBlock[l.index(of: blockedCell)] = 1
            cases.append(("humidity", { try Self.variant(humidity: wetBlock) }))
            cases.append(("vent off floor", {
                try Self.variant(vents: [MushroomWeatherVent(cell: blockedCell, openRate: 1, closedRate: 0)]
                                 + l.vents.dropFirst())
            }))
            cases.append(("colony off floor", {
                try Self.variant(colonies: [MushroomWeatherColony(cell: blockedCell, low: 0, high: 1)])
            }))
            var podsBlocked: [MushroomWeatherCell?] = Array(repeating: nil, count: l.podRules.slots)
            podsBlocked[0] = blockedCell
            cases.append(("pod off floor", { try Self.variant(start: Self.start(pods: podsBlocked)) }))
        }
        for (name, build) in cases {
            #expect(Self.refusal(build) == name, "expected \(name)")
        }
        #expect(!l.isFloor(outside) && !l.isFloor(MushroomWeatherCell(row: 0, column: -1)))
    }

    @Test func aSensitiveColonyStartingBelowItsFloorIsRefused() {
        let l: MushroomWeatherLevel = Self.base.level
        let cell: MushroomWeatherCell = l.colonies[0].cell
        let units: Int = l.humidity[l.index(of: cell)]
        var colonies: [MushroomWeatherColony] = l.colonies
        colonies[0] = MushroomWeatherColony(cell: cell, low: units + 1, high: l.moldBound, survivalFloor: units + 1)
        #expect(Self.refusal { try Self.variant(colonies: colonies) } == "colony below floor")
        colonies[0] = MushroomWeatherColony(cell: cell, low: units, high: l.moldBound, survivalFloor: units)
        #expect(Self.refusal { try Self.variant(colonies: colonies) } != "colony below floor")
    }

    @Test func theStoredFormRefusesDamage() throws {
        let level: MushroomWeatherLevel = Self.base.level
        let data: Data = level.encoded()
        let text: String = String(decoding: data, as: UTF8.self)
        func code(_ text: String) -> String {
            do {
                _ = try MushroomWeatherLevel.decode(Data(text.utf8))
                return "none"
            } catch {
                return error.reasonCode
            }
        }
        #expect(code(text) == "none")
        #expect(code("{") == "r02-g20.malformed")
        #expect(code(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")) == "r02-g20.newer-schema")
        #expect(code(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")) == "r02-g20.malformed")
        let budget: Int = level.budget
        let edited: String = text.replacingOccurrences(of: "\"budget\":\(budget)",
                                                       with: "\"budget\":\(budget == 12 ? 11 : budget + 1)")
        #expect(edited != text)
        #expect(code(edited) == "r02-g20.malformed")
        #expect(code(text.replacingOccurrences(of: "\"diffusion\":\(level.diffusion)",
                                               with: "\"diffusion\":0")) == "r02-g20.malformed")
        #expect(code(text.replacingOccurrences(of: "\"fingerprint\":\"\(level.fingerprint)\"",
                                               with: "\"fingerprint\":\"\(String(repeating: "0", count: 64))\""))
            == "r02-g20.malformed")
        #expect(code(text.replacingOccurrences(of: "\"rows\":", with: "\"rowz\":")) == "r02-g20.malformed")
        do {
            _ = try MushroomWeatherLevel.decode(Data(text.replacingOccurrences(of: "\"schema\":1",
                                                                              with: "\"schema\":7").utf8))
            Issue.record("a newer schema decoded")
        } catch {
            #expect(error == .newerSchema(7))
        }
    }

    @Test func everythingIsNamedInWords() throws {
        let l: MushroomWeatherLevel = Self.base.level
        #expect(l.podDescription(1, cell: MushroomWeatherCell(row: 3, column: 7), grownAt: 18)
            == "pod 2 at row 3, column 7, grown at cycle 18")
        #expect(l.podDescription(0, cell: MushroomWeatherCell(row: 3, column: 7), grownAt: nil)
            == "pod 1 at row 3, column 7, not grown")
        #expect(l.podDescription(2, cell: nil, grownAt: nil) == "pod 3 empty")
        #expect(l.failureDescription(.dried(colony: 1, cycle: 14)) == "colony 2 dries out at cycle 14")
        #expect(l.failureDescription(.mold(cell: MushroomWeatherCell(row: 3, column: 4), cycle: 9))
            == "row 3, column 4 turns to mold at cycle 9")
        #expect(l.failureDescription(.unstable(colony: 0, run: 3))
            == "colony 1 is in band for only the last 3 cycles, needs \(l.required)")
        #expect(MushroomWeatherLevel.ledgerDescription(MushroomWeatherLedger(cycle: 5, before: 4120, released: 12,
                                                                             evaporated: 40, after: 4092))
            == "cycle 5: 4120 units, 12 released, 40 evaporated, 4092 units")
        let colony = MushroomWeatherColony(cell: MushroomWeatherCell(row: 5, column: 2), low: 380, high: 520)
        let level: MushroomWeatherLevel = try Self.hand(floor: [colony.cell, Self.a], humidity: [colony.cell: 412],
                                                        colony: colony, length: 20, required: 12)
        let report = MushroomWeatherReport(cycles: 12, humidity: level.humidity, ledger: [], grownAt: [nil],
                                           colonies: [MushroomWeatherColonyRuns(finalRun: 12, longestRun: 12,
                                                                                firstOutOfBand: nil)],
                                           failure: nil)
        #expect(level.colonyDescription(0, report: report)
            == "colony 1 at row 5, column 2: 412 units, band 380 … 520, in band for the last 12 of 12 cycles")
        let words: String = l.progressDescription(report: l.startReport, arrangement: l.start, actionsLeft: 1)
        #expect(words.contains("pod 1 ") && words.contains("colony 1 at ") && words.contains("moonlight ")
            && words.contains("running now would fail: ") && words.hasSuffix("1 action left"))
        if !l.vents.isEmpty { #expect(words.contains("vent 1 at ")) }
        let win: String = l.progressDescription(report: MushroomWeatherForest.report(l, arrangement: Self.base.winning),
                                                arrangement: Self.base.winning, actionsLeft: 3)
        #expect(win.contains("running now would win") && win.hasSuffix("3 actions left"))
    }
}
