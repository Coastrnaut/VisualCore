// EchoCartographerSolverTests — feature 402 (R02-G11-02) T-R02G1102-003 (FR-R02G1102-002; SC-R02G1102-001, 002, 005;
// clarifications Q2, Q5). The inference solver of Echo Cartographer: the region of the hand level; the fitting
// placements of the hand level counted by hand (no pulse: C(24, 2) = 276; after the entry pulse, echoes [4, 10]: the
// cells at 4 are (2, 2) and (0, 4), at 10 (6, 0) and (6, 4), so 2 × 2 = 4 placements, collected in enumeration order);
// the cap and the work count; an independent brute force (path lengths by fixed-point relaxation, no queue; every
// beacon-count subset of an independently computed region) equal to the solver's count on 200 seeded small chambers
// with 0 … 3 random observations; the greedy plan's pulses each from a cell known open at its turn, exactly one
// placement after the plan (the true beacons, by brute force), at least two before its last pulse, the counterexample
// equal to the brute force's first two fits, the witness winning through the kernel, the work bound and the pulse limit
// honoured; and `wins(_:actions:)` refusing a truncated or missing claim. Fixture seed 2_402. Deterministic, explicit
// types, plain loops.
import Testing
import VisualCoreSimulation
@testable import EchoCartographerCore

@Suite struct EchoCartographerSolverTests {
    /// The fixture seed of this feature.
    static let seed: UInt64 = 2_402

    // MARK: - Independent reference

    /// Path lengths from `from` by fixed-point relaxation (no queue): every open cell repeatedly takes one more than
    /// its smallest open neighbour until nothing changes; nil for walls and unreachable cells.
    static func relaxedLengths(_ chamber: EchoCartographerChamber, from: EchoCartographerCell) -> [Int?] {
        var lengths: [Int?] = Array(repeating: nil, count: chamber.cellCount)
        guard chamber.isOpen(from) else { return lengths }
        lengths[chamber.index(from)] = 0
        let steps: [(Int, Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        var changed: Bool = true
        while changed {
            changed = false
            for index in 0..<chamber.cellCount {
                let cell: EchoCartographerCell = chamber.cell(index)
                if !chamber.isOpen(cell) { continue }
                for step in steps {
                    let neighbour = EchoCartographerCell(x: cell.x + step.0, y: cell.y + step.1)
                    if !chamber.isOpen(neighbour) { continue }
                    guard let d = lengths[chamber.index(neighbour)] else { continue }
                    let candidate: Int = d + 1
                    if lengths[index] == nil || candidate < lengths[index]! {
                        lengths[index] = candidate
                        changed = true
                    }
                }
            }
        }
        return lengths
    }

    /// The region by relaxation: open cells reachable from the entry, the entry excluded, in index order.
    static func bruteRegion(_ level: EchoCartographerLevel) -> [Int] {
        let lengths: [Int?] = relaxedLengths(level.chamber, from: level.entry)
        let entry: Int = level.chamber.index(level.entry)
        var cells: [Int] = []
        for index in 0..<level.chamber.cellCount where lengths[index] != nil && index != entry {
            cells.append(index)
        }
        return cells
    }

    /// Every beacon-count subset of the region that fits every observation (its sorted relaxed distances equal the
    /// echoes): the number of fits and the first `collect` fits in lexicographic index order.
    static func bruteFits(_ level: EchoCartographerLevel, observations: [EchoCartographerObservation],
                          collect: Int = 0) -> (count: Int, first: [[EchoCartographerCell]]) {
        let chamber: EchoCartographerChamber = level.chamber
        let region: [Int] = bruteRegion(level)
        let k: Int = level.beacons.count
        var tables: [[Int?]] = []
        for observation in observations { tables.append(relaxedLengths(chamber, from: observation.emitter)) }
        var count: Int = 0
        var first: [[EchoCartographerCell]] = []
        if region.count < k { return (0, first) }
        var picks: [Int] = []
        for i in 0..<k { picks.append(i) }
        while true {
            var fits: Bool = true
            for j in 0..<observations.count {
                var distances: [Int] = []
                for p in picks {
                    if let d = tables[j][region[p]] { distances.append(d) } else { distances.append(-1) }
                }
                distances.sort()
                if distances != observations[j].echoes {
                    fits = false
                    break
                }
            }
            if fits {
                count += 1
                if first.count < collect {
                    var cells: [EchoCartographerCell] = []
                    for p in picks { cells.append(chamber.cell(region[p])) }
                    first.append(cells)
                }
            }
            // Next k-subset in lexicographic order.
            var i: Int = k - 1
            while i >= 0 && picks[i] == region.count - k + i { i -= 1 }
            if i < 0 { break }
            picks[i] += 1
            var m: Int = i + 1
            while m < k {
                picks[m] = picks[m - 1] + 1
                m += 1
            }
        }
        return (count, first)
    }

    /// Whether `placement` fits every observation, by relaxed distances.
    static func fitsAll(_ level: EchoCartographerLevel, _ placement: [EchoCartographerCell],
                        _ observations: [EchoCartographerObservation]) -> Bool {
        for observation in observations {
            let table: [Int?] = relaxedLengths(level.chamber, from: observation.emitter)
            var distances: [Int] = []
            for cell in placement { distances.append(table[level.chamber.index(cell)] ?? -1) }
            distances.sort()
            if distances != observation.echoes { return false }
        }
        return true
    }

    /// A seeded small level: W, H 5 … 8, one wall in four, 1 … 3 beacons in the entry's region, energy 60; nil when
    /// the draw makes no valid level.
    static func smallLevel(_ random: inout SeededRandom, number: Int) -> EchoCartographerLevel? {
        let width: Int = random.int(5...8)
        let height: Int = random.int(5...8)
        var walls: Set<Int> = []
        for index in 0..<(width * height) where random.int(0...3) == 0 { walls.insert(index) }
        guard let chamber = try? EchoCartographerChamber(width: width, height: height, walls: walls) else {
            return nil
        }
        var open: [Int] = []
        for index in 0..<chamber.cellCount where !walls.contains(index) { open.append(index) }
        guard open.count >= 2 else { return nil }
        let entry: EchoCartographerCell = chamber.cell(open[random.int(0...(open.count - 1))])
        let reach: [Int?] = chamber.pathLengths(from: entry)
        var pool: [Int] = []
        for index in open where reach[index] != nil && index != chamber.index(entry) { pool.append(index) }
        guard !pool.isEmpty else { return nil }
        let wanted: Int = min(random.int(1...3), pool.count)
        var beacons: [EchoCartographerCell] = []
        for _ in 0..<wanted { beacons.append(chamber.cell(pool.remove(at: random.int(0...(pool.count - 1))))) }
        return try? EchoCartographerLevel(id: "solver-\(number)", seed: seed, difficulty: 1, chamber: chamber,
                                          entry: entry, beacons: beacons, tolerance: random.int(0...2), energy: 60,
                                          missCost: 1, tutorial: random.int(0...3) == 0)
    }

    /// `count` seeded small levels from seed 2_402.
    static func smallLevels(_ count: Int) -> [EchoCartographerLevel] {
        var random = SeededRandom(seed: seed)
        var levels: [EchoCartographerLevel] = []
        var number: Int = 0
        while levels.count < count {
            number += 1
            if let level = smallLevel(&random, number: number) { levels.append(level) }
        }
        return levels
    }

    /// The observation a pulse from `cell` gives on `level`.
    static func observe(_ level: EchoCartographerLevel, _ cell: EchoCartographerCell) -> EchoCartographerObservation {
        EchoCartographerObservation(emitter: cell, echoes: level.echo(from: cell).beaconDistances)
    }

    /// Shorthand for a cell.
    static func c(_ x: Int, _ y: Int) -> EchoCartographerCell { EchoCartographerCell(x: x, y: y) }

    // MARK: - Region

    /// The hand level's region is its 24 open cells other than the entry, in cell-index order, and agrees with the
    /// relaxation reference.
    @Test func regionOfHandLevel() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let region: [EchoCartographerCell] = EchoCartographerSolver.region(level)
        let expected: [EchoCartographerCell] = [
            Self.c(1, 0), Self.c(2, 0), Self.c(4, 0), Self.c(5, 0), Self.c(6, 0),
            Self.c(0, 1), Self.c(2, 1), Self.c(4, 1), Self.c(6, 1),
            Self.c(0, 2), Self.c(2, 2), Self.c(3, 2), Self.c(4, 2), Self.c(6, 2),
            Self.c(0, 3), Self.c(4, 3), Self.c(6, 3),
            Self.c(0, 4), Self.c(1, 4), Self.c(2, 4), Self.c(3, 4), Self.c(4, 4), Self.c(5, 4), Self.c(6, 4),
        ]
        #expect(region == expected)
        #expect(!region.contains(level.entry))
        var indices: [Int] = []
        for cell in region { indices.append(level.chamber.index(cell)) }
        #expect(indices == Self.bruteRegion(level))
    }

    // MARK: - Fitting placements, hand-worked

    /// With no observation every pair of the 24 region cells fits: C(24, 2) = 276; a cap below stops the count.
    @Test func fittingWithoutObservations() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var work: Int = 0
        let all = EchoCartographerSolver.fitting(level, observations: [], cap: 1_000, work: &work)
        #expect(all.count == 276)
        #expect(all.first.isEmpty)
        #expect(work > 276)
        var cappedWork: Int = 0
        let capped = EchoCartographerSolver.fitting(level, observations: [], cap: 10, work: &cappedWork)
        #expect(capped.count == 10)
        #expect(cappedWork < work)
        var tinyWork: Int = 0
        let tiny = EchoCartographerSolver.fitting(level, observations: [], cap: 1, work: &tinyWork)
        #expect(tiny.count == 1)
    }

    /// After the entry pulse (echoes [4, 10]) exactly 4 placements fit, collected in enumeration order:
    /// {(6,0),(2,2)}, {(6,0),(0,4)}, {(2,2),(6,4)}, {(0,4),(6,4)}; a cap of 3 stops at 3; work only grows.
    @Test func fittingAfterEntryPulse() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let heard: EchoCartographerObservation = Self.observe(level, level.entry)
        #expect(heard.echoes == [4, 10])
        var work: Int = 5
        let result = EchoCartographerSolver.fitting(level, observations: [heard], cap: 1_000, work: &work, collect: 10)
        #expect(result.count == 4)
        let expected: [[EchoCartographerCell]] = [
            [Self.c(6, 0), Self.c(2, 2)], [Self.c(6, 0), Self.c(0, 4)], [Self.c(2, 2), Self.c(6, 4)], [Self.c(0, 4), Self.c(6, 4)],
        ]
        #expect(result.first == expected)
        #expect(work > 5 + 4)
        var limitedWork: Int = 0
        let two = EchoCartographerSolver.fitting(level, observations: [heard], cap: 1_000, work: &limitedWork,
                                                 collect: 2)
        #expect(two.first == [expected[0], expected[1]])
        var cappedWork: Int = 0
        let capped = EchoCartographerSolver.fitting(level, observations: [heard], cap: 3, work: &cappedWork)
        #expect(capped.count == 3)
        // A second pulse from (6, 0) (echoes [0, 6]) leaves only the true beacons.
        let second: EchoCartographerObservation = Self.observe(level, Self.c(6, 0))
        #expect(second.echoes == [0, 6])
        var secondWork: Int = 0
        let unique = EchoCartographerSolver.fitting(level, observations: [heard, second], cap: 1_000,
                                                    work: &secondWork, collect: 2)
        #expect(unique.count == 1)
        #expect(unique.first == [[Self.c(6, 0), Self.c(2, 2)]])
    }

    /// The enumeration stops once the work passes its limit.
    @Test func fittingHonoursWorkLimit() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        var work: Int = 0
        let result = EchoCartographerSolver.fitting(level, observations: [], cap: 1_000, work: &work, limit: 50)
        #expect(work <= 52)
        #expect(result.count < 276)
    }

    // MARK: - Independent brute force

    /// On 200 seeded small chambers with 0 … 3 random observations from region cells, the solver's uncapped count
    /// and its first two fits equal the brute force over every beacon-count subset with relaxed path lengths.
    @Test func fittingEqualsBruteForce() {
        let levels: [EchoCartographerLevel] = Self.smallLevels(200)
        var random = SeededRandom(seed: Self.seed &+ 1)
        var observed: [Int] = [0, 0, 0, 0]
        for level in levels {
            let region: [EchoCartographerCell] = EchoCartographerSolver.region(level)
            let n: Int = random.int(0...3)
            var observations: [EchoCartographerObservation] = []
            for _ in 0..<n {
                let cell: EchoCartographerCell = region[random.int(0...(region.count - 1))]
                observations.append(Self.observe(level, cell))
            }
            observed[n] += 1
            let brute = Self.bruteFits(level, observations: observations, collect: 2)
            var work: Int = 0
            let solved = EchoCartographerSolver.fitting(level, observations: observations, cap: Int.max, work: &work,
                                                        collect: 2)
            #expect(solved.count == brute.count, "level \(level.id): \(solved.count) vs \(brute.count)")
            #expect(solved.first == brute.first, "level \(level.id) first fits")
            #expect(solved.count >= 1, "level \(level.id): the beacons always fit")
        }
        for n in 0...3 { #expect(observed[n] > 0, "observation count \(n) sampled") }
    }

    // MARK: - Plan

    /// On seeded small levels with a plan: every pulse is from a cell known open at its turn (knowledge replayed),
    /// the counts match the brute force, the last count is 1 and the beacons are the brute force's unique fit, at least
    /// two fit before the last pulse, the counterexample is the brute force's first two fits (distinct, one not the
    /// beacons, which fails the last pulse), the witness wins, the work stays in bound and the pulses within 6.
    @Test func planCertifiesSeededLevels() {
        let levels: [EchoCartographerLevel] = Self.smallLevels(60)
        var planned: Int = 0
        for level in levels {
            guard let plan = EchoCartographerSolver.plan(level) else { continue }
            planned += 1
            #expect(!plan.pulses.isEmpty)
            #expect(plan.pulses.count <= EchoCartographerSolver.maxPulses)
            #expect(plan.placements.count == plan.pulses.count)
            #expect(plan.work <= EchoCartographerSolver.workBound)
            #expect(plan.work > 0)
            var knowledge: EchoCartographerKnowledge = level.openingKnowledge
            var observations: [EchoCartographerObservation] = []
            for (turn, pulse) in plan.pulses.enumerated() {
                #expect(knowledge[pulse] == .open, "level \(level.id) pulse \(turn) from an unknown cell")
                let echo: EchoCartographerEcho = level.echo(from: pulse)
                knowledge.reveal(echo)
                observations.append(EchoCartographerObservation(emitter: pulse, echoes: echo.beaconDistances))
                let brute = Self.bruteFits(level, observations: observations)
                let expected: Int = min(brute.count, EchoCartographerSolver.placementCap)
                #expect(plan.placements[turn] == expected, "level \(level.id) turn \(turn)")
            }
            #expect(plan.placements.last == 1)
            let after = Self.bruteFits(level, observations: observations, collect: 2)
            #expect(after.count == 1)
            #expect(after.first == [level.beacons], "level \(level.id): the unique fit is the beacons")
            let before: [EchoCartographerObservation] = Array(observations.dropLast())
            let short = Self.bruteFits(level, observations: before, collect: 2)
            #expect(plan.placementsBeforeLast >= 2)
            #expect(plan.placementsBeforeLast == min(short.count, EchoCartographerSolver.placementCap))
            #expect(plan.counterexample == short.first, "level \(level.id) counterexample")
            #expect(plan.counterexample.count == 2)
            if plan.counterexample.count == 2 {
                #expect(plan.counterexample[0] != plan.counterexample[1])
                var differing: Int = 0
                for placement in plan.counterexample {
                    #expect(Self.fitsAll(level, placement, before))
                    if placement != level.beacons {
                        differing += 1
                        #expect(!Self.fitsAll(level, placement, observations))
                    }
                }
                #expect(differing >= 1)
            }
            let actions: [EchoCartographerAction] = EchoCartographerSolver.actions(level, plan: plan)
            #expect(actions.count == plan.pulses.count + level.beacons.count)
            #expect(EchoCartographerSolver.wins(level, actions: actions), "level \(level.id) witness wins")
        }
        #expect(planned >= 30, "planned \(planned) of 60")
    }

    /// The plan is deterministic and, on the hand level, two pulses: the entry ((0, 0), 4 placements) then a cell
    /// that leaves the beacons alone.
    @Test func planOfHandLevel() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        guard let plan = EchoCartographerSolver.plan(level) else {
            Issue.record("the hand level has a plan")
            return
        }
        #expect(plan == EchoCartographerSolver.plan(level))
        #expect(plan.pulses.first == level.entry)
        #expect(plan.placements.first == 4)
        #expect(plan.pulses.count == 2)
        #expect(plan.placements.last == 1)
        #expect(plan.placementsBeforeLast == 4)
        #expect(plan.counterexample == [[Self.c(6, 0), Self.c(2, 2)], [Self.c(6, 0), Self.c(0, 4)]])
        #expect(EchoCartographerSolver.wins(level, actions: EchoCartographerSolver.actions(level, plan: plan)))
    }

    /// A tiny work bound gives no plan.
    @Test func planHonoursWorkBound() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        #expect(EchoCartographerSolver.plan(level, workBound: 1) == nil)
        #expect(EchoCartographerSolver.plan(level, workBound: 0) == nil)
        let levels: [EchoCartographerLevel] = Self.smallLevels(20)
        for level in levels {
            if let plan = EchoCartographerSolver.plan(level, workBound: 2_000) {
                #expect(plan.work <= 2_000, "level \(level.id)")
            }
        }
    }

    /// Over the first 40 shared fixtures every plan found uses 1 … 6 distinct pulses, ends at 1 placement after at
    /// least 2, and stays within the work bound.
    @Test func planHonoursPulseLimit() {
        let fixtures: [EchoCartographerFixture] = EchoCartographerFixtures.fixtures(40)
        var planned: Int = 0
        for fixture in fixtures {
            guard let plan = EchoCartographerSolver.plan(fixture.level) else { continue }
            planned += 1
            #expect(plan.pulses.count <= EchoCartographerSolver.maxPulses)
            #expect(plan.pulses.count >= 1)
            #expect(plan.placements.last == 1)
            #expect(plan.placementsBeforeLast >= 2)
            #expect(plan.work <= EchoCartographerSolver.workBound)
            var pulsed: Set<EchoCartographerCell> = []
            for pulse in plan.pulses { pulsed.insert(pulse) }
            #expect(pulsed.count == plan.pulses.count, "fixture \(fixture.level.id): no cell pulsed twice")
        }
        #expect(planned > 0)
    }

    // MARK: - Wins

    /// The full witness wins; the witness without its last claim does not; a last claim off the last beacon (a miss
    /// at tolerance 0) does not; an action refused by the play (a pulse from an unknown cell) does not.
    @Test func winsRequiresTheFullWitness() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel(tolerance: 0)
        let full: [EchoCartographerAction] = [.pulse(0, 0), .claim(6, 0), .claim(2, 2)]
        #expect(EchoCartographerSolver.wins(level, actions: full))
        let truncated: [EchoCartographerAction] = [.pulse(0, 0), .claim(6, 0)]
        #expect(!EchoCartographerSolver.wins(level, actions: truncated))
        let missed: [EchoCartographerAction] = [.pulse(0, 0), .claim(6, 0), .claim(0, 4)]
        #expect(!EchoCartographerSolver.wins(level, actions: missed))
        let refused: [EchoCartographerAction] = [.pulse(4, 4), .claim(6, 0), .claim(2, 2)]
        #expect(!EchoCartographerSolver.wins(level, actions: refused))
        let trailing: [EchoCartographerAction] = full + [.claim(0, 4)]
        #expect(!EchoCartographerSolver.wins(level, actions: trailing))
        #expect(!EchoCartographerSolver.wins(level, actions: []))
    }
}
