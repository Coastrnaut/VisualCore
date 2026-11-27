// MyceliumArchitectSolverTests — feature 512 (R02-G22-02) T-R02G2202-004 (FR-R02G2202-002; SC-R02G2202-002;
// clarification Q3; research R3, R5). The breadth-first solver of Mycelium Architect, on generated catalog levels (the
// first four manifest entries of each band, generated in manifest order within the band — the first of a band with no
// previous level — and cached per process) and on a hand level with sites:
// - minimal plans: the solver's length equals the band's plan length p on every sampled level, and `solve` with a depth
//   limit below the length returns nil;
// - an independent enumeration of every action sequence shorter than the plan through `MyceliumArchitectPuzzle` moves
//   (no visited set, no loss order) on the two sampled levels with the smallest move space in each band judges every
//   arrangement reached: none wins, the number first reached at each length equals `countsByDepth`, and the plan's own
//   sequence goes through the puzzle's moves to a win;
// - the work: the arrangements judged, the start included — every arrangement first reached below the plan plus the
//   ones of the plan's depth judged before the first winner in the loss order;
// - the loss is 0 exactly for winning reports and positive otherwise;
// - the plan replays through `MyceliumArchitectPlay` to `won`;
// - on a level with sites the move list holds placements only on sites.
// Plain loops, explicit types, no clock.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MyceliumArchitectCore

@Suite struct MyceliumArchitectSolverTests {
    typealias Level = MyceliumArchitectLevel
    typealias Arrangement = MyceliumArchitectArrangement
    typealias Action = MyceliumArchitectAction
    typealias Cell = MyceliumArchitectCell
    typealias Puzzle = MyceliumArchitectPuzzle
    typealias Solver = MyceliumArchitectSolver
    typealias Generated = MyceliumArchitectGeneratedLevel

    // MARK: - Generated levels

    /// The sampled levels per band: the first `perBand` manifest entries of each band.
    static let perBand: Int = 4

    /// The sampled generated levels, band by band in manifest order (generated once per process; within a band each
    /// entry gets the previous sampled level, the first of a band none).
    static let sample: [Generated] = {
        var result: [Generated] = []
        for band in 1...5 {
            var previous: Level? = nil
            var taken: Int = 0
            for entry in MyceliumArchitectManifest.entries where entry.band == band && taken < perBand {
                if let generated = try? MyceliumArchitectGenerator.generate(entry, previous: previous) {
                    result.append(generated)
                    previous = generated.level
                }
                taken += 1
            }
        }
        return result
    }()

    /// The two sampled levels with the smallest move space at the start in each band (ties keep manifest order).
    static let smallest: [Generated] = {
        var result: [Generated] = []
        for band in 1...5 {
            var inBand: [Generated] = []
            for generated in sample where generated.entry.band == band { inBand.append(generated) }
            let ordered: [Generated] = inBand.enumerated().sorted { a, b in
                a.element.difficulty.moveSpace != b.element.difficulty.moveSpace
                    ? a.element.difficulty.moveSpace < b.element.difficulty.moveSpace : a.offset < b.offset
            }.map(\.element)
            for generated in ordered.prefix(2) { result.append(generated) }
        }
        return result
    }()

    // MARK: - Independent enumeration

    /// What an enumeration of every action sequence shorter than `length` found.
    struct Enumeration {
        /// The distinct arrangements first reached at each length 0 … length − 1.
        var firstReached: [Int]
        /// The action sequences judged (every sequence, repeats included).
        var sequences: Int
        /// The judged sequences whose arrangement wins.
        var wins: Int
    }

    /// Enumerates every action sequence of fewer than `length` actions through the puzzle's moves and applies, with no
    /// visited set and no loss order, judging the arrangement of every sequence by the growth.
    static func enumerate(_ level: Level, below length: Int) -> Enumeration {
        let puzzle = Puzzle(level: level)
        var reached: [Set<Arrangement>] = Array(repeating: [], count: length)
        var sequences: Int = 0
        var wins: Int = 0
        var stack: [(state: Puzzle.Position, depth: Int)] = [(puzzle.initialState, 0)]
        while let (state, depth) = stack.popLast() {
            sequences += 1
            if MyceliumArchitectGrowth.report(level, arrangement: state.arrangement).wins { wins += 1 }
            reached[depth].insert(state.arrangement)
            if depth + 1 >= length { continue }
            for move in puzzle.moves(in: state) {
                if let next = puzzle.apply(move, to: state) { stack.append((next, depth + 1)) }
            }
        }
        var seen: Set<Arrangement> = []
        var firstReached: [Int] = []
        for depth in 0..<length {
            var fresh: Int = 0
            for arrangement in reached[depth] where !seen.contains(arrangement) { fresh += 1 }
            seen.formUnion(reached[depth])
            firstReached.append(fresh)
        }
        return Enumeration(firstReached: firstReached, sequences: sequences, wins: wins)
    }

    /// What a counting sweep in the solver's order found.
    struct Sweep {
        /// The arrangements judged until the first winner, the start included.
        var judged: Int
        /// The distinct arrangements first reached at the depth of the first winner.
        var lastLayer: Int
        /// Whether every judged report had loss 0 exactly when it won.
        var lossAgrees: Bool
        /// The arrangements judged in all (to the end of the winner's depth).
        var total: Int
    }

    /// A breadth-first sweep to `depth` that expands each layer in ascending loss (stable) and the puzzle's move
    /// order, counting the arrangements judged until the first winner and checking the loss against every report.
    static func sweep(_ level: Level, depth limit: Int) -> Sweep {
        let puzzle = Puzzle(level: level)
        var seen: Set<Arrangement> = [level.start]
        let startReport: MyceliumArchitectReport = MyceliumArchitectGrowth.report(level, arrangement: level.start)
        var lossAgrees: Bool = (Solver.loss(level, startReport) == 0) == startReport.wins
        var judged: Int = 1
        var winnerAt: Int? = nil
        var total: Int = 1
        var lastLayer: Int = 0
        var layer: [(arrangement: Arrangement, loss: Int)] = [(level.start, Solver.loss(level, startReport))]
        for depth in 0..<limit {
            var ordered: [(offset: Int, arrangement: Arrangement, loss: Int)] = []
            for (offset, item) in layer.enumerated() { ordered.append((offset, item.arrangement, item.loss)) }
            ordered.sort { a, b in a.loss != b.loss ? a.loss < b.loss : a.offset < b.offset }
            var next: [(arrangement: Arrangement, loss: Int)] = []
            for item in ordered {
                let state = Puzzle.Position(arrangement: item.arrangement, actionsSpent: depth)
                for move in puzzle.moves(in: state) {
                    guard let after = puzzle.apply(move, to: state) else { continue }
                    if seen.contains(after.arrangement) { continue }
                    seen.insert(after.arrangement)
                    total += 1
                    let report: MyceliumArchitectReport = MyceliumArchitectGrowth.report(level,
                                                                                        arrangement: after.arrangement)
                    let loss: Int = Solver.loss(level, report)
                    if (loss == 0) != report.wins { lossAgrees = false }
                    if winnerAt == nil {
                        judged += 1
                        if report.wins { winnerAt = depth + 1 }
                    }
                    next.append((after.arrangement, loss))
                }
            }
            lastLayer = next.count
            if winnerAt != nil { break }
            layer = next
        }
        return Sweep(judged: judged, lastLayer: lastLayer, lossAgrees: lossAgrees, total: total)
    }

    // MARK: - Tests

    /// Every sampled entry generates, and its solver plan has the band's length p; re-solving gives the same solution.
    @Test func testMyceliumArchitectPlansAreMinimal() {
        #expect(Self.sample.count == 5 * Self.perBand)
        for generated in Self.sample {
            let p: Int = MyceliumArchitectBandProfile.band(generated.entry.band).plan
            #expect(generated.solution.length == p, "entry \(generated.entry.number)")
            #expect(generated.solution.countsByDepth.count == p, "entry \(generated.entry.number)")
            #expect(generated.solution.actions.last == .run, "entry \(generated.entry.number)")
            let again: MyceliumArchitectSolution? = Solver.solve(generated.level, maxDepth: p)
            #expect(again == generated.solution, "entry \(generated.entry.number)")
            #expect(generated.difficulty.witnessLength == p, "entry \(generated.entry.number)")
        }
    }

    /// The independent enumeration: no sequence shorter than the plan wins, the arrangements first reached at each
    /// length equal the solver's per-depth counts, and the plan goes through the puzzle's moves to a win.
    @Test func testMyceliumArchitectIndependentEnumeration() {
        #expect(Self.smallest.count == 10)
        for generated in Self.smallest {
            let level: Level = generated.level
            let solution: MyceliumArchitectSolution = generated.solution
            let found: Enumeration = Self.enumerate(level, below: solution.length)
            #expect(found.wins == 0, "entry \(generated.entry.number)")
            #expect(found.firstReached == solution.countsByDepth, "entry \(generated.entry.number)")
            #expect(found.sequences >= solution.countsByDepth.reduce(0, +), "entry \(generated.entry.number)")
            let puzzle = Puzzle(level: level)
            var state: Puzzle.Position = puzzle.initialState
            var followed: Bool = true
            for action in solution.actions.dropLast() {
                if !puzzle.moves(in: state).contains(action) { followed = false; break }
                guard let next = puzzle.apply(action, to: state) else { followed = false; break }
                state = next
            }
            #expect(followed, "entry \(generated.entry.number)")
            #expect(puzzle.isSolved(state), "entry \(generated.entry.number)")
        }
    }

    /// The work is the arrangements judged: the start, every arrangement first reached below the plan, and the
    /// arrangements of the plan's depth judged in the loss order up to the first winner.
    @Test func testMyceliumArchitectWorkCountsJudgedArrangements() {
        for generated in Self.smallest {
            let solution: MyceliumArchitectSolution = generated.solution
            let swept: Sweep = Self.sweep(generated.level, depth: solution.length)
            let below: Int = solution.countsByDepth.reduce(0, +)
            #expect(solution.work == swept.judged, "entry \(generated.entry.number)")
            #expect(solution.work > below, "entry \(generated.entry.number)")
            #expect(solution.work <= below + swept.lastLayer, "entry \(generated.entry.number)")
            #expect(generated.difficulty.work == solution.work, "entry \(generated.entry.number)")
            #expect(generated.difficulty.searchedBelow == below, "entry \(generated.entry.number)")
        }
    }

    /// The loss is 0 exactly for winning reports: every arrangement reached to the plan's depth, the start and the
    /// plan's arrangement; the nearest miss's loss is positive.
    @Test func testMyceliumArchitectLossZeroExactlyForWins() {
        for generated in Self.smallest {
            let level: Level = generated.level
            let swept: Sweep = Self.sweep(level, depth: generated.solution.length)
            #expect(swept.lossAgrees, "entry \(generated.entry.number)")
            #expect(swept.total >= generated.solution.work, "entry \(generated.entry.number)")
        }
        for generated in Self.sample {
            let level: Level = generated.level
            #expect(Solver.loss(level, level.startReport) > 0, "entry \(generated.entry.number)")
            #expect(generated.solution.nearestMissLoss > 0, "entry \(generated.entry.number)")
            var play = MyceliumArchitectPlay(level: level)
            let report: MyceliumArchitectReport
            do {
                try play.handle(.begin)
                if play.stage == .tutorial { try play.handle(.dismissTutorial) }
                for action in generated.solution.actions.dropLast() { try play.apply(action, expecting: play.fingerprint) }
                report = play.report
            } catch {
                Issue.record("entry \(generated.entry.number): \(error)")
                continue
            }
            #expect(report.wins, "entry \(generated.entry.number)")
            #expect(Solver.loss(level, report) == 0, "entry \(generated.entry.number)")
        }
    }

    /// Every sampled plan replays through the play to `won`, its run last.
    @Test func testMyceliumArchitectPlansReplayThroughPlay() throws {
        for generated in Self.sample {
            var play = MyceliumArchitectPlay(level: generated.level)
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in generated.solution.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .won, "entry \(generated.entry.number)")
            #expect(play.actionsSpent == generated.solution.length, "entry \(generated.entry.number)")
        }
    }

    /// `solve` returns nil when the depth limit is below the minimal length, and the same plan at the length.
    @Test func testMyceliumArchitectSolveNilBelowMinimalLength() {
        for generated in Self.sample {
            let length: Int = generated.solution.length
            for depth in 0..<length {
                #expect(Solver.solve(generated.level, maxDepth: depth) == nil,
                        "entry \(generated.entry.number) depth \(depth)")
            }
            #expect(Solver.solve(generated.level, maxDepth: length + 1)?.actions == generated.solution.actions,
                    "entry \(generated.entry.number)")
        }
    }

    // MARK: - Sites

    /// A 6 × 6 hand level with three sites, root (1, 1), one terminal (4, 4), no starting seed, two nutrients, two
    /// blockers and two seeds allowed, a budget of 4 (built without the "already won" rule).
    static func sitesLevel() throws(MyceliumArchitectError) -> Level {
        try Level(id: "sites-hand", seed: 512, difficulty: 1, width: 6, height: 6, root: Cell(column: 1, row: 1),
                  terminals: [Cell(column: 4, row: 4)], rocks: [Cell(column: 3, row: 3)], toxins: [],
                  fixedNutrients: [], strength: 4, reach: 6, curvature: 1, obstacle: 1, maxNutrients: 2,
                  maxBlockers: 2, maxSeeds: 2, startSeeds: [], pulses: 16, nutrientBudget: 100, weightLimit: 100,
                  budget: 4, tutorial: false, refusingAWin: false,
                  sites: [Cell(column: 5, row: 5), Cell(column: 3, row: 0), Cell(column: 0, row: 4)])
    }

    /// On a level with sites the move list holds placements only on sites, in ascending order, then the seeds; a
    /// placement off a site is refused; after a placement its clear joins the list.
    @Test func testMyceliumArchitectSitesLimitPlacements() throws {
        let level: Level = try Self.sitesLevel()
        let sites: [Cell] = try #require(level.sites)
        #expect(sites == [Cell(column: 3, row: 0), Cell(column: 0, row: 4), Cell(column: 5, row: 5)])
        let puzzle = Puzzle(level: level)
        let moves: [Action] = puzzle.moves(in: puzzle.initialState)
        var expected: [Action] = []
        for cell in sites { expected.append(.nutrient(cell)) }
        for cell in sites { expected.append(.blocker(cell)) }
        for direction in MyceliumArchitectDirection.allCases.sorted() { expected.append(.seed(direction)) }
        #expect(moves == expected)
        for move in moves {
            switch move {
            case .nutrient(let cell), .blocker(let cell):
                #expect(sites.contains(cell))
            case .seed:
                break
            case .clear, .unseed, .run:
                Issue.record("unexpected move \(move)")
            }
        }
        #expect(puzzle.apply(.nutrient(Cell(column: 2, row: 2)), to: puzzle.initialState) == nil)
        #expect(puzzle.apply(.blocker(Cell(column: 0, row: 0)), to: puzzle.initialState) == nil)
        let placed: Puzzle.Position = try #require(puzzle.apply(.nutrient(sites[1]), to: puzzle.initialState))
        let after: [Action] = puzzle.moves(in: placed)
        #expect(after.contains(.clear(sites[1])))
        #expect(!after.contains(.nutrient(sites[1])))
        for move in after {
            switch move {
            case .nutrient(let cell), .blocker(let cell), .clear(let cell):
                #expect(sites.contains(cell))
            case .seed, .unseed:
                break
            case .run:
                Issue.record("unexpected run")
            }
        }
    }
}
