// FacetedForgeSolverTests — feature 372 (R02-G08-02) T-R02G0802-003 (FR-R02G0802-002; SC-R02G0802-001, 002, 005;
// clarifications Q2, Q5). The certifying solver, seed 2_372: hand-built cube levels with known solutions (halves by an
// axis plane, halves by a body diagonal that only the face-count rule tells apart, quarters) are solved with
// smallest = lowerBound and the solution replays to a win; unreachable targets (shares no integer plane makes, a face
// count no half of a cube has) give nil, confirmed by an exhaustive enumeration of every single cut; canPartition on
// fitting, misfitting, one-entry face-count and symmetric pieces; lowerBound; determinism; the work bound (a tiny bound
// gives nil, the exact work of a solution suffices and one less does not). On the R02-G08-01 fixtures (seed 2_371,
// their sliver limit half the smallest share made) the solver finds exactly target.count − 1 winning cuts, within its
// default bound except fixture-2401 (a 1/1056 piece; 39,454 evaluations), which is solved with a bound of 60,000.
// The independent check: for levels of 2 … 3 target pieces a breadth-first search written here over every cut
// sequence of length lowerBound − 1 (every piece, directions 0 … 12, every crossing depth) counts lowerBound pieces
// after each sequence and finds no win, and the solver's solution replayed on a fresh play has target.count pieces
// whose recomputed (share, faces) multiset equals the target. Explicit types, plain loops; each test under 10 s on a
// debug host build (slowest about 5 s).
import Foundation
import Testing
@testable import FacetedForgeCore

@Suite struct FacetedForgeSolverTests {
    typealias Level = FacetedForgeLevel
    typealias Piece = FacetedForgePiece
    typealias Solver = FacetedForgeSolver
    typealias Entry = FacetedForgeTargetPiece
    typealias Fraction = FacetedForgeFraction

    /// The solver test seed.
    static let seed: UInt64 = 2_372

    /// The sliver limit of the hand-built levels.
    static let sliver: Fraction = Fraction(unchecked: 1, 64)

    // MARK: - Hand-built levels

    /// The half-spaces lo ≤ n·p ≤ hi of direction `direction`.
    static func slab(_ direction: Int, _ lo: Int, _ hi: Int) -> [FacetedForgeHalfSpace] {
        [FacetedForgeHalfSpace(direction: direction, sign: 1, depth: hi),
         FacetedForgeHalfSpace(direction: direction, sign: -1, depth: lo)]
    }

    /// The cube −2 … 2 (volume 64).
    static let cubePlanes: [FacetedForgeHalfSpace] = (slab(0, -2, 2) + slab(1, -2, 2) + slab(2, -2, 2)).sorted()

    /// A level on the cube −2 … 2 with `target` (sorted here).
    static func cube(_ id: String, _ target: [Entry], budget: Int) throws -> Level {
        try Level(id: id, seed: seed, difficulty: 1, planes: cubePlanes, budget: budget, sliver: sliver,
                  target: target.sorted())
    }

    /// An entry of share n / d and `faces` faces.
    static func entry(_ n: Int64, _ d: Int64, _ faces: Int) -> Entry {
        Entry(share: Fraction(unchecked: n, d), faces: faces)
    }

    /// Two 1/2 boxes: x = 0 halves the cube; x = −1 (tried first) gives 1/4 and 3/4 and is pruned, so the solver
    /// answers [cut(0, 0, 0)] after exactly two evaluations.
    static func halves() throws -> Level { try cube("halves", [entry(1, 2, 6), entry(1, 2, 6)], budget: 1) }

    /// Two 1/2 pieces of 7 faces: x + y + z = 0 crosses all six faces of the cube (a hexagon), so each half keeps six
    /// cube faces and gains the cut. Every axis and face-diagonal cut through the centre makes 1/2 halves of 6 or 5
    /// faces, which the one-entry face-count rule refuses, so the first cut kept is direction 9 at depth 0.
    static func diagonal() throws -> Level { try cube("diagonal", [entry(1, 2, 7), entry(1, 2, 7)], budget: 1) }

    /// Four 1/4 boxes in three cuts (slabs or a 2 × 2 grid).
    static func quarters() throws -> Level {
        try cube("quarters", [entry(1, 4, 6), entry(1, 4, 6), entry(1, 4, 6), entry(1, 4, 6)], budget: 3)
    }

    /// 1/2, 1/4, 1/4 boxes in two cuts.
    static func mixed() throws -> Level {
        try cube("mixed", [entry(1, 2, 6), entry(1, 4, 6), entry(1, 4, 6)], budget: 4)
    }

    /// 1/3 and 2/3 boxes: every integer plane cuts the cube −2 … 2 into 6-faced boxes only along an axis, at shares
    /// k/4. Unreachable.
    static func thirds() throws -> Level { try cube("thirds", [entry(1, 3, 6), entry(2, 3, 6)], budget: 2) }

    /// Two 1/2 pieces of 9 faces: one plane crosses at most six faces of a cube, so a half has at most 7. Unreachable.
    static func nineFaces() throws -> Level { try cube("nine-faces", [entry(1, 2, 9), entry(1, 2, 9)], budget: 1) }

    /// The levels with a known solution.
    static func solvable() throws -> [Level] { [try halves(), try diagonal(), try quarters(), try mixed()] }

    /// The cube and its halves by `direction` at depth 0.
    static func split(_ direction: Int, _ depth: Int = 0) throws -> (cube: Piece, below: Piece, above: Piece) {
        let cube: Piece = try Piece(halfSpaces: cubePlanes)
        let halves: (below: Piece, above: Piece) = try cube.cut(direction: direction, depth: depth)
        return (cube, halves.below, halves.above)
    }

    // MARK: - Independent check (its own enumeration and matching)

    /// The (share, faces) multiset of `pieces`, sorted, computed here from volumes.
    static func multiset(_ pieces: [Piece], crystal: Piece) throws -> [Entry] {
        var result: [Entry] = []
        for piece in pieces {
            let share: Fraction = try piece.volume.dividing(by: crystal.volume)
            result.append(Entry(share: share, faces: piece.faceCount))
        }
        return result.sorted()
    }

    /// Every piece list reachable by exactly `length` cuts from the crystal (every piece, directions 0 … 12, every
    /// depth −24 … 24 that crosses it; no pruning), breadth-first, deduplicated by the piece set.
    static func reachable(_ level: Level, length: Int) -> [[Piece]] {
        var layer: [[Piece]] = [[level.crystal]]
        for _ in 0..<length {
            var next: [[Piece]] = []
            var seen: Set<[Piece]> = []
            for pieces in layer {
                for index in pieces.indices {
                    for direction in 0...12 {
                        for depth in FacetedForgeHalfSpace.depths
                        where pieces[index].isCrossed(direction: direction, depth: depth) {
                            guard let halves = try? pieces[index].cut(direction: direction, depth: depth) else {
                                continue
                            }
                            var rest: [Piece] = pieces
                            rest.remove(at: index)
                            let after: [Piece] = Piece.canonical(rest + [halves.below, halves.above])
                            if seen.insert(after).inserted { next.append(after) }
                        }
                    }
                }
            }
            layer = next
        }
        return layer
    }

    /// Whether some list reachable by `length` cuts matches the level's target, checking the piece count of every list.
    static func anyWins(_ level: Level, length: Int) throws -> Bool {
        let target: [Entry] = level.target.sorted()
        for pieces in reachable(level, length: length) {
            #expect(pieces.count == length + 1)
            if try multiset(pieces, crystal: level.crystal) == target { return true }
        }
        return false
    }

    /// The pieces after replaying `actions` on a fresh play (begun, tutorial dismissed), and its stage.
    static func replay(_ level: Level, _ actions: [FacetedForgeAction]) throws -> FacetedForgePlay {
        var play = FacetedForgePlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The fixtures, built once.
    static let fixtures: [FacetedForgeFixture] = FacetedForgeFixtures.fixtures(40)

    // MARK: - Tests

    /// lowerBound is the target's piece count minus one.
    @Test func lowerBoundIsPiecesMinusOne() throws {
        #expect(Solver.lowerBound(try Self.halves()) == 1)
        #expect(Solver.lowerBound(try Self.mixed()) == 2)
        #expect(Solver.lowerBound(try Self.quarters()) == 3)
        for fixture in Self.fixtures {
            #expect(Solver.lowerBound(fixture.level) == fixture.level.target.count - 1)
            #expect(Solver.lowerBound(fixture.level) == fixture.actions.count)
        }
    }

    /// The hand-built levels are solved with smallest = lowerBound, actions of that length, and win on replay.
    @Test func handBuiltLevelsSolve() throws {
        for level in try Self.solvable() {
            let solution: FacetedForgeSolution? = Solver.solve(level)
            #expect(solution != nil, "\(level.id)")
            guard let solution else { continue }
            #expect(solution.smallest == Solver.lowerBound(level))
            #expect(solution.actions.count == solution.smallest)
            #expect(solution.work >= solution.smallest)
            #expect(solution.work <= Solver.workBound)
            #expect(FacetedForgeGenerator.wins(level, actions: solution.actions), "\(level.id)")
        }
    }

    /// The exact answers worked out by hand: halves after two evaluations, the diagonal by direction 9 at depth 0.
    @Test func handBuiltAnswers() throws {
        let halves: FacetedForgeSolution? = Solver.solve(try Self.halves())
        #expect(halves == FacetedForgeSolution(smallest: 1, actions: [.cut(0, 0, 0)], work: 2))
        let diagonal: FacetedForgeSolution? = Solver.solve(try Self.diagonal())
        #expect(diagonal?.actions == [.cut(0, 9, 0)])
        let (_, below, above) = try Self.split(9)
        #expect(below.faceCount == 7)
        #expect(above.faceCount == 7)
    }

    /// Unreachable targets give nil, and an exhaustive enumeration of every cut sequence of length lowerBound agrees.
    @Test func unreachableTargetsGiveNil() throws {
        for level in [try Self.thirds(), try Self.nineFaces()] {
            #expect(Solver.solve(level) == nil, "\(level.id)")
            #expect(try !Self.anyWins(level, length: Solver.lowerBound(level)), "\(level.id)")
        }
    }

    /// canPartition: fitting and misfitting shares, more pieces than entries, the one-entry face-count rule and
    /// symmetric (interchangeable) pieces.
    @Test func canPartitionCases() throws {
        let (cube, left, right) = try Self.split(0)
        let (_, low, high) = try Self.split(9)
        let (_, quarter, threeQuarters) = try Self.split(0, -1)
        let crystal: Fraction = cube.volume
        let halvesTarget: [Entry] = [Self.entry(1, 2, 6), Self.entry(1, 2, 6)]
        #expect(Solver.canPartition([cube], into: halvesTarget, crystal: crystal))
        #expect(Solver.canPartition([left, right], into: halvesTarget, crystal: crystal))
        #expect(!Solver.canPartition([quarter, threeQuarters], into: halvesTarget, crystal: crystal))
        let quarterEntry: Entry = Self.entry(1, 4, 6)
        let quartersTarget: [Entry] = [quarterEntry, quarterEntry, quarterEntry, quarterEntry]
        #expect(Solver.canPartition([threeQuarters, quarter], into: quartersTarget, crystal: crystal))
        #expect(Solver.canPartition([left, right], into: quartersTarget, crystal: crystal))
        // More pieces than entries.
        #expect(!Solver.canPartition([left, right], into: [Self.entry(1, 1, 6)], crystal: crystal))
        // One entry per piece: the face count must match.
        #expect(!Solver.canPartition([low, high], into: halvesTarget, crystal: crystal))
        let sevens: [Entry] = [Self.entry(1, 2, 7), Self.entry(1, 2, 7)]
        #expect(Solver.canPartition([low, high], into: sevens, crystal: crystal))
        #expect(!Solver.canPartition([left, right], into: sevens, crystal: crystal))
        // Two entries on a piece lift the face-count rule (the cube is 6-faced, the entries are not).
        #expect(Solver.canPartition([cube], into: sevens, crystal: crystal))
        // Mixed faces: each piece must take the entry of its own face count.
        let mixedFaces: [Entry] = [Self.entry(1, 2, 6), Self.entry(1, 2, 7)].sorted()
        let (_, half6, _) = try Self.split(0)
        #expect(Solver.canPartition([low, half6], into: mixedFaces, crystal: crystal))
        #expect(Solver.canPartition([half6, low], into: mixedFaces, crystal: crystal))
        // Symmetric pieces: two equal halves, one takes 1/2, the other 1/4 + 1/4.
        let uneven: [Entry] = [Self.entry(1, 2, 6), Self.entry(1, 4, 6), Self.entry(1, 4, 6)]
        #expect(Solver.canPartition([left, right], into: uneven, crystal: crystal))
        #expect(Solver.canPartition([low, high], into: uneven, crystal: crystal) == false)
        // A piece left without an entry fails.
        #expect(!Solver.canPartition([left, right], into: [Self.entry(1, 2, 6)], crystal: crystal))
    }

    /// Two solves of the same level are equal.
    @Test func solveIsDeterministic() throws {
        var levels: [Level] = try Self.solvable()
        for fixture in Self.fixtures.prefix(10) { levels.append(fixture.level) }
        for level in levels {
            #expect(Solver.solve(level) == Solver.solve(level), "\(level.id)")
        }
    }

    /// The work bound: a bound of 1 gives nil on multi-evaluation levels; a solution's own work suffices and one less
    /// does not.
    @Test func workBoundIsHonoured() throws {
        for level in try Self.solvable() {
            guard let solution = Solver.solve(level) else {
                Issue.record("\(level.id) unsolved")
                continue
            }
            #expect(solution.work <= Solver.workBound)
            #expect(Solver.solve(level, workBound: solution.work) == solution, "\(level.id)")
            #expect(Solver.solve(level, workBound: solution.work - 1) == nil, "\(level.id)")
            #expect(Solver.solve(level, workBound: 0) == nil)
            if solution.work > 1 {
                #expect(Solver.solve(level, workBound: 1) == nil, "\(level.id)")
            }
        }
    }

    /// The fixtures whose search needs more than the default bound (their slivers are far below the catalog's 1/64;
    /// fixture-2401's 4 cuts leave a 1/1056 piece and the search needs 39,454 evaluations).
    static let overBound: Set<String> = ["fixture-2401"]

    /// A bound large enough for every fixture.
    static let fixtureBound: Int = 60_000

    /// On the R02-G08-01 fixtures (chunk `chunk` of four, ten each; ``overBound`` left to its own test) the solver
    /// finds exactly target.count − 1 cuts that win, within the default bound.
    @Test(arguments: [0, 1, 2, 3]) func fixturesSolve(chunk: Int) throws {
        let slice: ArraySlice<FacetedForgeFixture> = Self.fixtures[(chunk * 10)..<(chunk * 10 + 10)]
        for fixture in slice where !Self.overBound.contains(fixture.level.id) {
            let level: Level = fixture.level
            let solution: FacetedForgeSolution? = Solver.solve(level)
            #expect(solution != nil, "\(level.id)")
            guard let solution else { continue }
            #expect(solution.work <= Solver.workBound)
            #expect(solution.smallest == level.target.count - 1)
            #expect(solution.actions.count == level.target.count - 1)
            #expect(FacetedForgeGenerator.wins(level, actions: solution.actions), "\(level.id)")
        }
    }

    /// A fixture in ``overBound`` is solved within ``fixtureBound`` with more work than the default bound (so the
    /// default bound gives nil: the bounded search is a prefix of the same depth-first order, see
    /// ``workBoundIsHonoured()``): exactly target.count − 1 cuts that win.
    @Test func overBoundFixtureSolvesWithLargerBound() throws {
        var seen: Int = 0
        for fixture in Self.fixtures where Self.overBound.contains(fixture.level.id) {
            seen += 1
            let level: Level = fixture.level
            let solution: FacetedForgeSolution? = Solver.solve(level, workBound: Self.fixtureBound)
            #expect(solution != nil, "\(level.id)")
            guard let solution else { continue }
            #expect(solution.work > Solver.workBound)
            #expect(solution.actions.count == level.target.count - 1)
            #expect(FacetedForgeGenerator.wins(level, actions: solution.actions), "\(level.id)")
        }
        #expect(seen == Self.overBound.count)
    }

    /// The independent check on levels of 2 … 3 target pieces: no sequence of lowerBound − 1 cuts wins (each leaves
    /// lowerBound pieces), and the solution replayed on a fresh play has target.count pieces matching the target.
    @Test func independentCheckOnSmallLevels() throws {
        var levels: [Level] = [try Self.halves(), try Self.diagonal(), try Self.mixed()]
        for fixture in Self.fixtures where fixture.level.target.count <= 3 { levels.append(fixture.level) }
        #expect(levels.count >= 6)
        for level in levels {
            let bound: Int = Solver.lowerBound(level)
            #expect(try !Self.anyWins(level, length: bound - 1), "\(level.id)")
            guard let solution = Solver.solve(level) else {
                Issue.record("\(level.id) unsolved")
                continue
            }
            let play: FacetedForgePlay = try Self.replay(level, solution.actions)
            #expect(play.stage == .won, "\(level.id)")
            #expect(play.pieces.count == level.target.count)
            #expect(play.pieces.count == solution.actions.count + 1)
            #expect(try Self.multiset(play.pieces, crystal: level.crystal) == level.target.sorted(), "\(level.id)")
        }
        // On two-piece levels the one-cut enumeration also finds the win the solver found.
        for level in [try Self.halves(), try Self.diagonal()] {
            #expect(try Self.anyWins(level, length: 1), "\(level.id)")
        }
    }
}
