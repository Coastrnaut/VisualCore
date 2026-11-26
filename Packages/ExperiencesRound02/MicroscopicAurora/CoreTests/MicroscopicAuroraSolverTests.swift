// MicroscopicAuroraSolverTests — feature 482 (R02-G19-02) T-R02G1902-003 (FR-R02G1902-002; SC-R02G1902-001, 002, 005;
// clarifications Q2, Q5). The certifying solver of Microscopic Aurora, on generated levels of every band (manifest
// entries 1, 2, 21, 41, 42, 61 and 81, each generated with no previous level and cached per process):
// - known minima: the generator's own winning wells (one in band 1, two in band 3) win through the kernel's play,
//   the plan wins, and every set with fewer wells, placed through the kernel's play, loses;
// - an independent enumeration (site subsets by bit mask, then 8^d options by a base-8 counter, judged by the kernel's
//   swim with no loss order) gives the plan's size as the first depth with a win, the plan's counts per smaller depth
//   (1 + 8k for a two-well plan) and the plan's nearest miss; no smaller set wins;
// - `sets(sites:size:)` lists C(k, d)·8^d sets in strictly increasing (site, strength, sense) order, clockwise first;
// - the loss order changes the work only: a plain fixed-order search wins first at the plan's depth;
// - the work bound: nil one set short of the plan's work, the same plan at it, every plan within 1,200;
// - no plan for a level without sites or with a starting well;
// - the loss of a hand report and of real reports equals unlit stencil cells plus lit cells outside the stencil;
// - the difficulty record's fields.
// Plain loops, explicit types, no clock.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraSolverTests {
    typealias Level = MicroscopicAuroraLevel
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell
    typealias Solver = MicroscopicAuroraSolver
    typealias Generated = MicroscopicAuroraGenerated

    /// The manifest numbers of the levels under test: two of band 1, one of band 2, two of band 3, one of 4 and 5.
    static let numbers: [Int] = [1, 2, 21, 41, 42, 61, 81]

    /// The generated levels of ``numbers``, in that order.
    static let generated: [Generated] = {
        var result: [Generated] = []
        for number in numbers {
            let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[number - 1]
            if let level = try? MicroscopicAuroraGenerator.generate(entry, previous: nil) { result.append(level) }
        }
        return result
    }()

    // MARK: - Independent helpers

    /// The result of the independent search of one level.
    struct Search: Sendable {
        /// The sets judged at each depth below the first depth with a win.
        let countsByDepth: [Int]
        /// The first depth with a win, or nil.
        let winDepth: Int?
        /// The first winning set found at that depth.
        let winner: [Well]?
        /// The smallest loss over the sets of the depths below the first win (independent loss), as clarification Q3
        /// defines the nearest miss; the sets judged at the winning depth do not count.
        let nearestMiss: Int
    }

    /// The well of option 0 … 7 on `cell`: strength option / 2 + 1, clockwise for even options.
    static func well(_ cell: Cell, option: Int) -> Well {
        Well(cell: cell, strength: option / 2 + 1, sense: option % 2 == 0 ? .clockwise : .counterclockwise)
    }

    /// Every set of `size` wells on distinct `sites`: site subsets by bit mask, then a base-8 counter of options.
    static func enumerate(_ sites: [Cell], size: Int) -> [[Well]] {
        var result: [[Well]] = []
        let limit: Int = 1 << sites.count
        for mask in 0..<limit where mask.nonzeroBitCount == size {
            var chosen: [Cell] = []
            for bit in 0..<sites.count where mask & (1 << bit) != 0 { chosen.append(sites[bit]) }
            var total: Int = 1
            for _ in 0..<size { total *= 8 }
            for code in 0..<total {
                var set: [Well] = []
                var rest: Int = code
                for cell in chosen {
                    set.append(well(cell, option: rest % 8))
                    rest /= 8
                }
                result.append(set)
            }
        }
        return result
    }

    /// The loss written out from the density: stencil cells below the threshold plus other cells at or above it.
    static func independentLoss(_ level: Level, _ report: MicroscopicAuroraReport) -> Int {
        var inside: [Bool] = Array(repeating: false, count: report.density.count)
        for cell in level.stencil { inside[cell.index] = true }
        var value: Int = 0
        for index in 0..<report.density.count {
            let lit: Bool = report.density[index] >= level.threshold
            if inside[index] && !lit { value += 1 }
            if !inside[index] && lit { value += 1 }
        }
        return value
    }

    /// The independent search of `level`: depth 0, 1, … in the enumeration's own order, the first win ending it.
    static func search(_ level: Level) -> Search {
        let sites: [Cell] = level.sites ?? []
        var counts: [Int] = []
        var nearest: Int = Int.max
        for depth in 0...min(Level.slots, sites.count) {
            var judged: Int = 0
            var depthNearest: Int = Int.max
            for set in enumerate(sites, size: depth) {
                judged += 1
                let report: MicroscopicAuroraReport = MicroscopicAuroraDish.report(level, wells: set)
                if report.wins {
                    return Search(countsByDepth: counts, winDepth: depth, winner: set,
                                  nearestMiss: nearest == Int.max ? 0 : nearest)
                }
                depthNearest = min(depthNearest, independentLoss(level, report))
            }
            counts.append(judged)
            nearest = min(nearest, depthNearest)
        }
        return Search(countsByDepth: counts, winDepth: nil, winner: nil, nearestMiss: nearest)
    }

    /// The independent searches of ``generated``, in order.
    static let searches: [Search] = {
        var result: [Search] = []
        for item in generated { result.append(search(item.level)) }
        return result
    }()

    /// The binomial coefficient C(n, k).
    static func choose(_ n: Int, _ k: Int) -> Int {
        if k < 0 || k > n { return 0 }
        var value: Int = 1
        for i in 0..<k { value = value * (n - i) / (i + 1) }
        return value
    }

    /// `level` rebuilt with `sites` and `wells`, through the public initializer.
    static func rebuilt(_ level: Level, sites: [Cell]?, wells: [Well?]) throws -> Level {
        try Level(id: level.id, seed: level.seed, difficulty: level.difficulty, radius: level.radius,
                  length: level.length, rules: level.rules, swimmers: level.swimmers, stencil: level.stencil,
                  threshold: level.threshold, coverage: level.coverage, coherence: level.coherence, wells: wells,
                  budget: level.budget, tutorial: level.tutorial, sites: sites)
    }

    /// The generated level of manifest `number`.
    static func level(_ number: Int) -> Generated? {
        generated.first { $0.entry.number == number }
    }

    // MARK: - Tests

    @Test func everyLevelUnderTestIsGenerated() {
        #expect(Self.generated.count == Self.numbers.count)
        for item in Self.generated {
            #expect(item.level.sites != nil)
            #expect(item.level.placedWells.isEmpty)
            #expect(item.plan.size == MicroscopicAuroraBandProfile.of(band: item.entry.band).plan)
        }
    }

    @Test func knownMinimaOfBandsOneAndThree() throws {
        for number in [1, 41] {
            let item: Generated = try #require(Self.level(number))
            let known = try #require(MicroscopicAuroraGenerator.candidateWithSites(item.entry, index: item.skipped))
            #expect(known.level == item.level)
            let expected: Int = number == 1 ? 1 : 2
            #expect(known.winning.count == expected)
            #expect(item.plan.size == expected)
            #expect(Solver.replayWins(item.level, actions: Solver.placements(known.winning)))
            #expect(Solver.replayWins(item.level, actions: item.plan.actions))
            #expect(!Solver.replayWins(item.level, actions: []))
            if expected == 2 {
                let sites: [Cell] = try #require(item.level.sites)
                var losing: Int = 0
                for cell in sites {
                    for option in 0..<8 {
                        let well: Well = Self.well(cell, option: option)
                        let actions: [MicroscopicAuroraAction] = [.place(slot: 0, well: well)]
                        if !Solver.replayWins(item.level, actions: actions) { losing += 1 }
                    }
                }
                #expect(losing == 8 * sites.count)
            }
        }
    }

    @Test func independentEnumerationAgreesWithThePlan() throws {
        #expect(Self.searches.count == Self.generated.count)
        for (offset, item) in Self.generated.enumerated() {
            let found: Search = Self.searches[offset]
            let sites: Int = try #require(item.level.sites).count
            #expect(found.winDepth == item.plan.size, "level \(item.entry.number)")
            #expect(found.countsByDepth == item.plan.setsByDepth, "level \(item.entry.number)")
            var expected: [Int] = []
            for depth in 0..<item.plan.size { expected.append(Self.choose(sites, depth) * Self.power8(depth)) }
            #expect(item.plan.setsByDepth == expected)
            #expect(found.nearestMiss == item.plan.nearestMiss, "level \(item.entry.number)")
            #expect(MicroscopicAuroraDish.report(item.level, wells: item.plan.wells).wins)
            #expect(item.plan.actions == Solver.placements(item.plan.wells))
        }
    }

    /// 8^n.
    static func power8(_ n: Int) -> Int {
        var value: Int = 1
        for _ in 0..<n { value *= 8 }
        return value
    }

    @Test func setsOrderAndCount() {
        var sites: [Cell] = []
        for column in 0..<8 { sites.append(Cell(row: 12, column: 4 + 2 * column)) }
        for k in 2...8 {
            let prefix: [Cell] = Array(sites.prefix(k))
            for size in 0...3 {
                let sets: [[Well]] = Solver.sets(sites: prefix, size: size)
                #expect(sets.count == Self.choose(k, size) * Self.power8(size), "k \(k) size \(size)")
                var previous: [Int]?
                for set in sets {
                    #expect(set.count == size)
                    var key: [Int] = []
                    var lastSite: Int = -1
                    for well in set {
                        let site: Int = prefix.firstIndex(of: well.cell) ?? -1
                        #expect(site > lastSite)
                        lastSite = site
                        key.append(site)
                        key.append(well.strength)
                        key.append(well.sense == .clockwise ? 0 : 1)
                    }
                    if let previous { #expect(Self.lexicallyBefore(previous, key)) }
                    previous = key
                }
            }
        }
        let two: [Cell] = Array(sites.prefix(2))
        let ones: [[Well]] = Solver.sets(sites: two, size: 1)
        #expect(ones.first == [Self.well(two[0], option: 0)])
        #expect(ones[1] == [Self.well(two[0], option: 1)])
        #expect(ones[2] == [Self.well(two[0], option: 2)])
        #expect(ones.last == [Self.well(two[1], option: 7)])
        let pairs: [[Well]] = Solver.sets(sites: two, size: 2)
        #expect(pairs.first == [Self.well(two[0], option: 0), Self.well(two[1], option: 0)])
        #expect(pairs[1] == [Self.well(two[0], option: 0), Self.well(two[1], option: 1)])
        #expect(Solver.sets(sites: two, size: 0) == [[]])
        #expect(Solver.sets(sites: two, size: 3).isEmpty)
    }

    /// Whether `a` comes strictly before `b` in lexicographic order (equal lengths).
    static func lexicallyBefore(_ a: [Int], _ b: [Int]) -> Bool {
        for index in 0..<min(a.count, b.count) where a[index] != b[index] { return a[index] < b[index] }
        return false
    }

    @Test func lossOrderChangesOnlyTheWork() {
        for (offset, item) in Self.generated.enumerated() {
            let found: Search = Self.searches[offset]
            #expect(found.winDepth == item.plan.size)
            if let winner = found.winner { #expect(MicroscopicAuroraDish.report(item.level, wells: winner).wins) }
            let smaller: Int = item.plan.setsByDepth.reduce(0, +)
            #expect(item.plan.work > smaller)
            let lastDepth: Int = Self.choose(item.level.sites?.count ?? 0, item.plan.size) * Self.power8(item.plan.size)
            #expect(item.plan.work <= smaller + lastDepth)
        }
    }

    @Test func workBound() throws {
        #expect(Solver.workBound == 1_200)
        for item in Self.generated {
            #expect(item.plan.work <= 1_200)
            #expect(Solver.plan(item.level, workBound: item.plan.work - 1) == nil, "level \(item.entry.number)")
            #expect(Solver.plan(item.level, workBound: item.plan.work) == item.plan)
            #expect(Solver.plan(item.level, workBound: 0) == nil)
        }
    }

    @Test func noPlanWithoutSitesOrWithAStartingWell() throws {
        let item: Generated = try #require(Self.level(41))
        let bare: Level = try Self.rebuilt(item.level, sites: nil, wells: [nil, nil, nil])
        #expect(bare.sites == nil)
        #expect(Solver.plan(bare) == nil)
        let sites: [Cell] = try #require(item.level.sites)
        let start: Well = Self.well(sites[0], option: 0)
        let started: Level = try Self.rebuilt(item.level, sites: sites, wells: [start, nil, nil])
        #expect(!started.placedWells.isEmpty)
        #expect(Solver.plan(started) == nil)
        #expect(Solver.plan(try Self.rebuilt(item.level, sites: sites, wells: [nil, nil, nil])) == item.plan)
    }

    @Test func lossOfHandAndRealReports() throws {
        let item: Generated = try #require(Self.level(1))
        let level: Level = item.level
        let t: Int = level.threshold
        var inside: Set<Int> = []
        for cell in level.stencil { inside.insert(cell.index) }
        var density: [Int] = Array(repeating: 0, count: MicroscopicAuroraDish.cells * MicroscopicAuroraDish.cells)
        var lit: [Cell] = []
        var unlit: Int = 0
        for (position, cell) in level.stencil.sorted().enumerated() {
            if position % 3 == 0 {
                density[cell.index] = t - 1
                unlit += 1
            } else {
                density[cell.index] = t + position
                lit.append(cell)
            }
        }
        var outside: Int = 0
        var placedOutside: Int = 0
        for index in 0..<density.count where !inside.contains(index) && placedOutside < 7 {
            density[index] = placedOutside % 2 == 0 ? t + 2 : t - 1
            if placedOutside % 2 == 0 { outside += 1 }
            placedOutside += 1
        }
        let report = MicroscopicAuroraReport(ticks: level.length, finalSwimmers: level.swimmers, density: density,
                                             litStencil: lit, coverage: 0, groups: 1, smallestCoherence: 0,
                                             smallestCoherenceTick: 0, failure: nil)
        #expect(outside == 4)
        #expect(Solver.loss(level, report: report) == unlit + outside)
        #expect(Solver.loss(level, report: report) == Self.independentLoss(level, report))
        let sites: [Cell] = try #require(level.sites)
        var checked: Int = 0
        for cell in sites {
            for option in [0, 3, 6] {
                let wells: [Well] = [Self.well(cell, option: option)]
                let real: MicroscopicAuroraReport = MicroscopicAuroraDish.report(level, wells: wells)
                #expect(Solver.loss(level, report: real) == Self.independentLoss(level, real))
                checked += 1
            }
        }
        let empty: MicroscopicAuroraReport = MicroscopicAuroraDish.report(level, wells: [])
        #expect(Solver.loss(level, report: empty) == Self.independentLoss(level, empty))
        #expect(checked == 3 * sites.count)
    }

    @Test func difficultyFields() throws {
        for item in Self.generated {
            let level: Level = item.level
            let difficulty = MicroscopicAuroraDifficulty(level: level, plan: item.plan)
            #expect(difficulty == item.difficulty)
            #expect(difficulty.placements == item.plan.size)
            #expect(difficulty.stencil == level.stencil.count)
            #expect(difficulty.coverage == level.coverage)
            #expect(difficulty.swarm == level.swimmers.count)
            let sites: Int = try #require(level.sites).count
            #expect(difficulty.sites == sites)
            #expect(sites == MicroscopicAuroraBandProfile.of(band: item.entry.band).sites)
            var searched: Int = 0
            for count in item.plan.setsByDepth { searched += count }
            #expect(difficulty.setsSearched == searched)
            #expect(difficulty.setsSearched == (item.plan.size == 1 ? 1 : 1 + 8 * sites))
            #expect(difficulty.work == item.plan.work)
            #expect(difficulty.nearestMiss == item.plan.nearestMiss)
            #expect(difficulty.puzzleDifficulty == PuzzleDifficulty(shortest: item.plan.size, explored: item.plan.work))
        }
    }
}
