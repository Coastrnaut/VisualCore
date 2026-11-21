// ColorfallCanyonsSolverTests — feature 342 (R02-G05-02) T-R02G0502-003 (FR-R02G0502-002; SC-R02G0502-002). The
// edit-set solver of clarification Q2 against an independent brute force written here: every edit set of at most 3
// edits over `ColorfallCanyonsSolver.moves(_:)` (no relevance pruning, no routing cache), each run on R02-G05-01's
// kernel tick, on hand-built channel levels needing exactly 0, 1, 2 and 3 edits (and more), on generated candidates of
// every band and on the kernel fixtures. Also: the flat-array `FastFlow` agrees with the kernel verdict and tick, the
// router agrees with `ColorfallCanyonsFluid.downhill(of:level:)`, every smaller edit set loses, the work counters are
// consistent, fluid never leaves the reachable cells, and the solver is deterministic. Seed 2_342; no clock.
import Foundation
import XCTest
@testable import ColorfallCanyonsCore

/// An independent brute force of clarification Q2: every non-decreasing move list, evaluated on the kernel tick.
private enum BruteForce {
    /// The outcome of one edit set on the kernel: nil when the set is not allowed (a carve below 0 or a valve twice).
    static func evaluate(_ level: ColorfallCanyonsLevel,
                         _ edits: [ColorfallCanyonsEdit]) -> (won: Bool, tick: Int)? {
        var fluid = ColorfallCanyonsFluid(level: level)
        var toggled: Set<Int> = []
        for edit in edits {
            switch edit {
            case .carve(let cell):
                guard level.isCarvable(cell, heights: fluid.heights) else { return nil }
                fluid.carve(cell)
            case .valve(let spring):
                guard toggled.insert(spring).inserted else { return nil }
                fluid.toggle(spring)
            }
        }
        while true {
            let masses: [[Int]] = fluid.masses
            let supplies: [Int] = fluid.supplies
            fluid.tick(level: level)
            switch fluid.verdict(level: level) {
            case .won: return (true, fluid.tick)
            case .failed: return (false, fluid.tick)
            case .running:
                // The tick is a function of masses and supplies (heights and valves are fixed after the edits): a state
                // the tick leaves unchanged stays forever, so only the time failure at the tick limit remains.
                if fluid.masses == masses && fluid.supplies == supplies { return (false, level.tickLimit) }
            }
        }
    }

    /// Calls `body` with every non-decreasing index list of `size` over `count` moves until it returns false.
    static func forEachSet(count: Int, size: Int, _ body: ([Int]) -> Bool) {
        var indices: [Int] = []
        var stopped: Bool = false
        func visit(_ start: Int) {
            if stopped { return }
            if indices.count == size {
                if !body(indices) { stopped = true }
                return
            }
            guard start < count else { return }
            for index in start..<count {
                indices.append(index)
                visit(index)
                indices.removeLast()
                if stopped { return }
            }
        }
        visit(0)
    }

    /// The smallest winning edit-set size of at most `depth` over every move, nil when none wins; also the sets run.
    static func smallest(_ level: ColorfallCanyonsLevel, depth: Int = 3) -> (size: Int?, runs: Int) {
        let moves: [ColorfallCanyonsEdit] = ColorfallCanyonsSolver.moves(level)
        var runs: Int = 0
        for size in 0...depth {
            var won: Bool = false
            forEachSet(count: moves.count, size: size) { indices in
                guard let outcome = evaluate(level, indices.map { moves[$0] }) else { return true }
                runs += 1
                if outcome.won { won = true }
                return !won
            }
            if won { return (size, runs) }
        }
        return (nil, runs)
    }
}

/// Seeded sampling shared by the tests.
private enum Sample {
    /// The test seed.
    static let seed: UInt64 = 2_342

    /// The first `perEntry` non-nil candidates (k < 64) of the first `entries` manifest entries of `band`.
    static func candidates(band: Int, entries: Int, perEntry: Int) -> [ColorfallCanyonsLevel] {
        var levels: [ColorfallCanyonsLevel] = []
        for entry in ColorfallCanyonsManifest.entries.filter({ $0.band == band }).prefix(entries) {
            var taken: Int = 0
            for k in 0..<64 where taken < perEntry {
                guard let candidate = ColorfallCanyonsGenerator.candidate(entry, index: k) else { continue }
                levels.append(candidate.level)
                taken += 1
            }
        }
        return levels
    }

    /// A seeded edit set of 0 … 3 moves of `level` (possibly not allowed).
    static func edits(_ level: ColorfallCanyonsLevel, _ random: inout ColorfallCanyonsRandom) -> [ColorfallCanyonsEdit] {
        let moves: [ColorfallCanyonsEdit] = ColorfallCanyonsSolver.moves(level)
        var picked: [ColorfallCanyonsEdit] = []
        for _ in 0..<random.int(0...3) { picked.append(moves[random.int(0...(moves.count - 1))]) }
        return picked.sorted()
    }
}

final class ColorfallCanyonsSolverTests: XCTestCase {
    // MARK: Hand-built channel levels

    /// A 8 × 4 channel: row 1 falls by one per column from the spring at column 0 to the basin at column 7 (height 0);
    /// a dam at column 3 stands `rise` above its upstream neighbour (nil: no dam). The basin wants `want` only.
    private func channel(rise: Int?, open: Bool, color: ColorfallCanyonsColor = .cyan,
                         want: ColorfallCanyonsColor = .cyan) throws -> (level: ColorfallCanyonsLevel, dam: Int) {
        let columns: Int = 8
        let rows: Int = 4
        var grounds = [ColorfallCanyonsGround](repeating: .rock, count: columns * rows)
        var heights = [Int](repeating: 15, count: columns * rows)
        for column in 0..<columns {
            grounds[columns + column] = .open
            heights[columns + column] = 13 - column
        }
        let dam: Int = columns + 3
        if let rise { heights[dam] = heights[dam - 1] + rise }
        heights[2 * columns - 1] = 0
        grounds[columns * rows - 1] = .drain
        heights[columns * rows - 1] = 0
        var shares = [0, 0, 0]
        shares[want.rawValue] = 1_000
        let spring = ColorfallCanyonsSpring(cell: columns, color: color, release: 2, supply: 30, open: open)
        let basin = ColorfallCanyonsBasin(cell: 2 * columns - 1, capacity: 40, fill: 20, shares: shares, tolerance: 0,
                                          isProtected: false, toleratedWrong: 0)
        let level = try ColorfallCanyonsLevel(id: "solver-channel", seed: Sample.seed, difficulty: 1, columns: columns,
                                              rows: rows, heights: heights, grounds: grounds, springs: [spring],
                                              basins: [basin], flowRate: 4, budget: 10, tickLimit: 60)
        return (level, dam)
    }

    /// Asserts that `level` needs exactly `expected` edits: the solver's smallest set, its win and the brute force.
    private func assertSmallest(_ level: ColorfallCanyonsLevel, _ expected: [ColorfallCanyonsEdit],
                                line: UInt = #line) throws {
        let solution = try XCTUnwrap(ColorfallCanyonsSolver.solve(level), line: line)
        XCTAssertEqual(solution.smallest, expected.count, line: line)
        XCTAssertEqual(solution.edits, expected, line: line)
        let run = try XCTUnwrap(ColorfallCanyonsSolver.run(level, edits: solution.edits), line: line)
        XCTAssertEqual(run.verdict, .won, line: line)
        XCTAssertEqual(run.tick, solution.winTick, line: line)
        XCTAssertEqual(BruteForce.smallest(level).size, expected.count, line: line)
    }

    func testHandBuiltLevelsNeedExactlyZeroOneTwoAndThreeEdits() throws {
        let plain = try channel(rise: nil, open: true)
        try assertSmallest(plain.level, [])
        let closed = try channel(rise: nil, open: false)
        try assertSmallest(closed.level, [.valve(0)])
        let low = try channel(rise: 1, open: true)
        try assertSmallest(low.level, [.carve(low.dam), .carve(low.dam)])
        let level = try channel(rise: 0, open: false)
        try assertSmallest(level.level, [.carve(level.dam), .valve(0)])
        let high = try channel(rise: 2, open: true)
        try assertSmallest(high.level, [.carve(high.dam), .carve(high.dam), .carve(high.dam)])
        let both = try channel(rise: 1, open: false)
        try assertSmallest(both.level, [.carve(both.dam), .carve(both.dam), .valve(0)])
        // A depth below the smallest count finds nothing.
        XCTAssertNil(ColorfallCanyonsSolver.solve(high.level, depth: 2))
        XCTAssertEqual(ColorfallCanyonsSolver.solve(high.level, depth: 3)?.smallest, 3)
    }

    func testLevelsNeedingMoreThanThreeEditsOrUnsolvableReturnNil() throws {
        let tall = try channel(rise: 3, open: true)
        XCTAssertNil(ColorfallCanyonsSolver.solve(tall.level))
        XCTAssertNil(BruteForce.smallest(tall.level).size)
        XCTAssertEqual(BruteForce.smallest(tall.level, depth: 4).size, 4)
        let closedTall = try channel(rise: 2, open: false)
        XCTAssertNil(ColorfallCanyonsSolver.solve(closedTall.level))
        XCTAssertNil(BruteForce.smallest(closedTall.level).size)
        let wrong = try channel(rise: nil, open: true, color: .cyan, want: .coral)
        XCTAssertNil(ColorfallCanyonsSolver.solve(wrong.level))
        XCTAssertNil(BruteForce.smallest(wrong.level).size)
        // Depths outside 0 … 3 clamp.
        let plain = try channel(rise: nil, open: true)
        XCTAssertEqual(ColorfallCanyonsSolver.solve(plain.level, depth: -1)?.smallest, 0)
        XCTAssertNil(ColorfallCanyonsSolver.solve(tall.level, depth: 9))
    }

    // MARK: Brute force agreement (SC-R02G0502-002)

    private func assertBruteForceAgrees(_ levels: [ColorfallCanyonsLevel], minimum: Int,
                                        line: UInt = #line) -> [Int?] {
        XCTAssertGreaterThanOrEqual(levels.count, minimum, line: line)
        var sizes: [Int?] = []
        for level in levels {
            let solved: Int? = ColorfallCanyonsSolver.solve(level)?.smallest
            let brute: Int? = BruteForce.smallest(level).size
            XCTAssertEqual(solved, brute, "\(level.id) seed \(level.seed)", line: line)
            sizes.append(brute)
        }
        return sizes
    }

    /// The catalog levels of the first two manifest entries of `band`, checked against the generator's own solution.
    private func catalog(band: Int, line: UInt = #line) throws -> [ColorfallCanyonsLevel] {
        var levels: [ColorfallCanyonsLevel] = []
        for entry in ColorfallCanyonsManifest.entries.filter({ $0.band == band }).prefix(2) {
            let generated = try ColorfallCanyonsGenerator.generate(entry)
            let profile = ColorfallCanyonsBandProfile.of(band: band)
            XCTAssertTrue(profile.smallest.contains(generated.solution.smallest), line: line)
            // The generator searches to the band's largest count; the pruning (hence the work) depends on the depth,
            // the smallest set does not.
            XCTAssertEqual(ColorfallCanyonsSolver.solve(generated.level, depth: profile.smallest.upperBound),
                           generated.solution, line: line)
            let full = try XCTUnwrap(ColorfallCanyonsSolver.solve(generated.level), line: line)
            XCTAssertEqual(full.edits, generated.solution.edits, line: line)
            XCTAssertEqual(full.winTick, generated.solution.winTick, line: line)
            levels.append(generated.level)
        }
        return levels
    }

    func testBruteForceAgreesOnBandOneCatalogLevelsAndCandidates() throws {
        let levels: [ColorfallCanyonsLevel] = try catalog(band: 1) + Sample.candidates(band: 1, entries: 2, perEntry: 2)
        _ = assertBruteForceAgrees(levels, minimum: 6)
    }

    func testBruteForceAgreesOnBandTwoCatalogLevelsAndCandidates() throws {
        let levels: [ColorfallCanyonsLevel] = try catalog(band: 2) + Sample.candidates(band: 2, entries: 2, perEntry: 1)
        let sizes: [Int?] = assertBruteForceAgrees(levels, minimum: 4)
        XCTAssertTrue(sizes.contains(where: { $0 == nil }), "an unsolved candidate is sampled")
    }

    func testBruteForceAgreesOnBandThreeCatalogLevelsAndCandidates() throws {
        let levels: [ColorfallCanyonsLevel] = try catalog(band: 3) + Sample.candidates(band: 3, entries: 2, perEntry: 1)
        _ = assertBruteForceAgrees(levels, minimum: 4)
    }

    func testBruteForceAgreesOnBandFourCatalogLevels() throws {
        _ = assertBruteForceAgrees(try catalog(band: 4), minimum: 2)
    }

    func testBruteForceAgreesOnBandFiveCatalogLevels() throws {
        _ = assertBruteForceAgrees(try catalog(band: 5), minimum: 2)
    }

    func testBruteForceAgreesOnUnsolvedBandFourAndFiveCandidates() {
        let levels: [ColorfallCanyonsLevel] = Sample.candidates(band: 4, entries: 1, perEntry: 1)
            + Sample.candidates(band: 5, entries: 1, perEntry: 1)
        let sizes: [Int?] = assertBruteForceAgrees(levels, minimum: 2)
        XCTAssertTrue(sizes.contains(where: { $0 == nil }), "an unsolved candidate is sampled")
    }

    func testBruteForceAgreesOnKernelFixtures() {
        var random = ColorfallCanyonsRandom(seed: Sample.seed)
        var levels: [ColorfallCanyonsLevel] = []
        for _ in 0..<24 { levels.append(ColorfallCanyonsFixtures.fixture(random.int(0...499)).level) }
        let sizes: [Int?] = assertBruteForceAgrees(levels, minimum: 24)
        // The fixtures need 1 … 4 edits: the sample covers solvable and unsolvable ones.
        XCTAssertTrue(sizes.contains(where: { $0 != nil }))
        XCTAssertTrue(sizes.contains(where: { $0 == nil }))
    }

    // MARK: FastFlow and router agreement

    func testFastFlowAndRouterAgreeWithKernel() throws {
        var random = ColorfallCanyonsRandom(seed: Sample.seed)
        var levels: [ColorfallCanyonsLevel] = []
        for band in 1...5 { levels += Sample.candidates(band: band, entries: 2, perEntry: 2) }
        for i in 0..<20 { levels.append(ColorfallCanyonsFixtures.fixture(i * 25).level) }
        for i in 0..<20 { levels.append(ColorfallCanyonsFixtures.randomLevel(i)) }
        var compared: Int = 0
        var wins: Int = 0
        for level in levels {
            let router = ColorfallCanyonsSolver.Router(level: level)
            let flow = ColorfallCanyonsSolver.FastFlow(level: level, router: router)
            for _ in 0..<25 {
                let edits: [ColorfallCanyonsEdit] = Sample.edits(level, &random)
                guard let fluid = ColorfallCanyonsSolver.edited(level, edits: edits) else { continue }
                let routing: [Int?] = ColorfallCanyonsSolver.routing(level, heights: fluid.heights)
                for cell in 0..<level.cellCount {
                    XCTAssertEqual(routing[cell], fluid.downhill(of: cell, level: level), "\(level.id) cell \(cell)")
                }
                let kernel = try XCTUnwrap(ColorfallCanyonsSolver.run(level, edits: edits))
                let fast = flow.run(routing: routing.map { $0 ?? -1 }, valves: fluid.valves)
                XCTAssertEqual(fast.won, kernel.verdict == .won, "\(level.id) \(edits)")
                XCTAssertEqual(fast.tick, kernel.tick, "\(level.id) \(edits)")
                compared += 1
                if fast.won { wins += 1 }
            }
        }
        XCTAssertGreaterThan(compared, 1_000)
        XCTAssertGreaterThan(wins, 0)
    }

    // MARK: Smaller sets lose; work counters

    func testEverySmallerEditSetLosesAndCountersAreConsistent() throws {
        var levels: [ColorfallCanyonsLevel] = []
        for i in 0..<12 { levels.append(ColorfallCanyonsFixtures.fixture(i * 41).level) }
        levels += Sample.candidates(band: 1, entries: 2, perEntry: 2)
        levels += Sample.candidates(band: 2, entries: 1, perEntry: 2)
        var solved: Int = 0
        for level in levels {
            guard let solution = ColorfallCanyonsSolver.solve(level) else { continue }
            solved += 1
            XCTAssertGreaterThanOrEqual(solution.work, 1)
            XCTAssertLessThanOrEqual(solution.smaller, solution.work)
            XCTAssertLessThan(solution.smaller, solution.work, "the winning routing is simulated")
            let kernel = try XCTUnwrap(ColorfallCanyonsSolver.run(level, edits: solution.edits))
            XCTAssertEqual(kernel.verdict, .won)
            XCTAssertEqual(kernel.tick, solution.winTick)
            XCTAssertEqual(BruteForce.evaluate(level, solution.edits)?.tick, solution.winTick)
            XCTAssertEqual(solution.edits, solution.edits.sorted(), "solver order")
            let moves: [ColorfallCanyonsEdit] = ColorfallCanyonsSolver.moves(level)
            var sets: Int = 0
            for size in 0..<solution.smallest {
                BruteForce.forEachSet(count: moves.count, size: size) { indices in
                    let edits: [ColorfallCanyonsEdit] = indices.map { moves[$0] }
                    guard let outcome = BruteForce.evaluate(level, edits) else { return true }
                    XCTAssertFalse(outcome.won, "\(level.id) \(edits) wins with fewer edits")
                    sets += 1
                    return true
                }
            }
            // Each distinct routing of fewer edits comes from at least one allowed smaller set.
            XCTAssertLessThanOrEqual(solution.smaller, sets)
        }
        XCTAssertGreaterThanOrEqual(solved, 8)
    }

    // MARK: reachable / relevantMoves soundness

    func testLeftOutCarvesChangeNoReachableRoutingAndFluidStaysReachable() {
        var random = ColorfallCanyonsRandom(seed: Sample.seed)
        var levels: [ColorfallCanyonsLevel] = []
        for band in 1...5 { levels += Sample.candidates(band: band, entries: 2, perEntry: 1) }
        for i in 0..<10 { levels.append(ColorfallCanyonsFixtures.randomLevel(i)) }
        var leftOut: Int = 0
        var checkedRuns: Int = 0
        for level in levels {
            let router = ColorfallCanyonsSolver.Router(level: level)
            let reach: Set<Int> = ColorfallCanyonsSolver.reachable(level, router: router, depth: 3)
            let relevant: [ColorfallCanyonsEdit] = ColorfallCanyonsSolver.relevantMoves(level, router: router, depth: 3)
            let excluded: [ColorfallCanyonsEdit] = ColorfallCanyonsSolver.moves(level).filter { !relevant.contains($0) }
            // Every valve stays; relevant moves keep the order of `moves(_:)`.
            XCTAssertEqual(relevant.filter { if case .valve = $0 { true } else { false } }.count, level.springs.count)
            XCTAssertEqual(relevant, ColorfallCanyonsSolver.moves(level).filter(relevant.contains))
            for move in excluded {
                guard case .carve(let cell) = move else { continue }
                leftOut += 1
                XCTAssertFalse(reach.contains(cell))
                for _ in 0..<4 {
                    let base: [ColorfallCanyonsEdit] = Sample.edits(level, &random)
                    var heights: [Int] = level.heights
                    for case .carve(let c) in base { heights[c] -= 1 }
                    guard heights.allSatisfy({ $0 >= 0 }) else { continue }
                    let before: [Int?] = router.routing(heights)
                    for depth in 1...3 where heights[cell] - depth >= 0 {
                        var carved: [Int] = heights
                        carved[cell] -= depth
                        let after: [Int?] = router.routing(carved)
                        for c in reach { XCTAssertEqual(before[c], after[c], "\(level.id) carve \(cell) cell \(c)") }
                    }
                }
            }
            // Under any allowed set of at most 3 edits, fluid only ever sits on reachable cells.
            for _ in 0..<12 {
                let edits: [ColorfallCanyonsEdit] = Sample.edits(level, &random)
                guard var fluid = ColorfallCanyonsSolver.edited(level, edits: edits) else { continue }
                checkedRuns += 1
                while fluid.verdict(level: level) == .running || fluid.tick == 0 {
                    fluid.tick(level: level)
                    for cell in 0..<level.cellCount where fluid.volume(cell) > 0 && level.grounds[cell] != .drain {
                        XCTAssertTrue(reach.contains(cell), "\(level.id) \(edits) fluid on \(cell)")
                    }
                }
            }
        }
        XCTAssertGreaterThan(leftOut, 0, "the sample exercises the pruning")
        XCTAssertGreaterThan(checkedRuns, 50)
    }

    // MARK: Determinism

    func testSolveIsDeterministic() throws {
        var levels: [ColorfallCanyonsLevel] = [try channel(rise: 1, open: false).level]
        for band in 1...5 { levels += Sample.candidates(band: band, entries: 1, perEntry: 1) }
        for i in 0..<5 { levels.append(ColorfallCanyonsFixtures.fixture(i * 97).level) }
        for level in levels {
            XCTAssertEqual(ColorfallCanyonsSolver.solve(level), ColorfallCanyonsSolver.solve(level), level.id)
        }
    }
}
