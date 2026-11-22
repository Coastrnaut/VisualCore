// NocturneGardenSolverTests — feature 382 (R02-G09-02) T-R02G0902-003 (FR-R02G0902-002; clarification Q2). The exact
// solver: `needed` is ⌈p·|T| / q⌉; the stamp shifted by an anchor and clipped to the bed is the bloom's own cell set
// for every kind, size, elevation and anchor (bed edges included); a one-bloom target solves in one plant; a target
// cast under another sun solves with that sun move first in exactly the bound's move count; a target no plant reaches
// within the leak allowance has no bound and no solution; generator candidates of bands 1 … 3 solve in exactly the
// lower bound, win on the last action and not one action earlier; the single-plant cover agrees with a brute force
// through the rules kernel; solving is deterministic; and the work bound is honoured. Fixture seed 2_382.
// Deterministic, explicit types, plain loops; each test well under 2 s on a debug build.
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite struct NocturneGardenSolverTests {
    /// The fixture seed of this feature.
    static let seed: UInt64 = 2_382

    /// A hand-built level on a bed of `width` × `height`; fails the test on an invalid level.
    static func level(width: Int = 16, height: Int = 12, target: Set<Int>, forbidden: Set<Int> = [],
                      supply: [NocturneGardenKind: Int], sizes: Set<Int> = [1], elevations: Set<Int> = [2],
                      sun: Int = 2, budget: Int = 10, required: NocturneGardenRatio = .whole,
                      allowance: Int = 0) throws -> NocturneGardenLevel {
        try NocturneGardenLevel(id: "solver-test", seed: seed, difficulty: 1, width: width, height: height,
                                target: target, forbidden: forbidden, supply: supply, sizes: sizes,
                                elevations: elevations, sun: sun, budget: budget, required: required,
                                leakAllowance: allowance)
    }

    /// The most target cells one plant darkens at `elevation` within the leak allowance, found by planting every
    /// candidate through the rules kernel (after a sun move when `elevation` is not the opening sun) and reading the
    /// mask with `NocturneGardenMask`.
    static func bruteCover(_ level: NocturneGardenLevel, elevation: Int) -> Int {
        let rules = NocturneGardenRules(level: level)
        var start: NocturneGardenRules.Position = rules.initialState
        if elevation != level.sun {
            guard let moved = rules.apply(.sun(elevation), to: start) else { return -1 }
            start = moved
        }
        var best: Int = 0
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 {
            for row in 0..<level.height {
                for column in 0..<level.width {
                    for size in level.sizes.sorted() {
                        guard let next = rules.apply(.plant(kind, column, row, size), to: start) else { return -1 }
                        let mask: NocturneGardenMask = NocturneGardenMask.union(next.blooms, elevation: next.sun,
                                                                                width: level.width,
                                                                                height: level.height)
                        guard mask.leak(forbidden: level.forbidden) <= level.leakAllowance else { continue }
                        best = max(best, mask.intersection(level.target))
                    }
                }
            }
        }
        return best
    }

    /// `needed` is the least shared count s with s·q ≥ p·|T|: 4/5 of 10 is 8, 2/3 of 10 is 7, 1/1 of 10 is 10.
    @Test func neededIsCeiling() throws {
        let target: Set<Int> = Set(0..<10)
        let cases: [(p: Int, q: Int, needed: Int)] = [(4, 5, 8), (2, 3, 7), (1, 1, 10), (17, 20, 9), (1, 10, 1)]
        for entry in cases {
            let level: NocturneGardenLevel = try Self.level(target: target, supply: [.tulip: 1],
                                                            required: try NocturneGardenRatio(entry.p, entry.q))
            #expect(NocturneGardenSolver.needed(level) == entry.needed, "\(entry.p)/\(entry.q)")
        }
        let single: NocturneGardenLevel = try Self.level(target: [5], supply: [.rose: 1])
        #expect(NocturneGardenSolver.needed(single) == 1)
    }

    /// The stamp of every kind, size 1 … 3 and elevation 1 … 4, shifted by an anchor and clipped to the bed, equals
    /// the bloom's own cells, at inner anchors and at anchors on every bed edge and corner.
    @Test func stampMatchesBloomCells() {
        let width: Int = 16
        let height: Int = 12
        let anchors: [(column: Int, row: Int)] = [(0, 0), (5, 3), (7, 0), (0, 6), (15, 0), (15, 11), (0, 11),
                                                  (8, 11), (15, 5), (1, 9)]
        for kind in NocturneGardenKind.allCases {
            for size in 1...3 {
                for elevation in 1...4 {
                    let offsets: [(dx: Int, dy: Int)] = NocturneGardenSolver.stamp(kind, size: size,
                                                                                    elevation: elevation)
                    #expect(!offsets.isEmpty, "\(kind) \(size) \(elevation)")
                    for anchor in anchors {
                        var shifted: Set<Int> = []
                        for offset in offsets {
                            let c: Int = anchor.column + offset.dx
                            let r: Int = anchor.row + offset.dy
                            if c >= 0, c < width, r >= 0, r < height { shifted.insert(r * width + c) }
                        }
                        let bloom = NocturneGardenBloom(kind: kind, column: anchor.column, row: anchor.row,
                                                        size: size)
                        let cells: Set<Int> = bloom.cells(elevation: elevation, width: width, height: height)
                        #expect(shifted == cells, "\(kind) size \(size) sun \(elevation) at \(anchor)")
                    }
                }
            }
        }
    }

    /// A target that is exactly one tulip's mask under the opening sun: the bound is one plant and the solution is a
    /// single plant that wins.
    @Test func singleBloomTarget() throws {
        let bloom = NocturneGardenBloom(kind: .tulip, column: 5, row: 2, size: 1)
        let target: Set<Int> = bloom.cells(elevation: 2, width: 16, height: 12)
        let level: NocturneGardenLevel = try Self.level(target: target, supply: [.tulip: 1])
        let bound: NocturneGardenBound = try #require(NocturneGardenSolver.lowerBound(level))
        #expect(bound.smallest == 1)
        #expect(bound.cover == target.count)
        #expect(!bound.sunMove)
        let solution: NocturneGardenSolution = try #require(NocturneGardenSolver.solve(level))
        #expect(solution.smallest == 1)
        #expect(solution.actions.count == 1)
        if case .plant = solution.actions[0] {} else { Issue.record("not a plant: \(solution.actions)") }
        #expect(NocturneGardenSolver.wins(level, actions: solution.actions))
    }

    /// A target cast under sun 3 while the level opens at sun 2 with one tulip of size 1: no single plant under sun 2
    /// covers it and the supply holds one bloom, so the solution is the sun move then one plant, in exactly the
    /// bound's move count.
    @Test func sunMoveFirst() throws {
        let bloom = NocturneGardenBloom(kind: .tulip, column: 6, row: 1, size: 1)
        let target: Set<Int> = bloom.cells(elevation: 3, width: 16, height: 12)
        let level: NocturneGardenLevel = try Self.level(target: target, supply: [.tulip: 1], elevations: [2, 3],
                                                        sun: 2)
        #expect(NocturneGardenSolver.cover(level, elevation: 2) < target.count)
        #expect(NocturneGardenSolver.cover(level, elevation: 3) == target.count)
        let bound: NocturneGardenBound = try #require(NocturneGardenSolver.lowerBound(level))
        let solution: NocturneGardenSolution = try #require(NocturneGardenSolver.solve(level))
        #expect(solution.actions.first == .sun(3))
        #expect(solution.actions.count == bound.smallest)
        #expect(solution.actions.count == 2)
        #expect(solution.smallest == bound.smallest)
        #expect(NocturneGardenSolver.wins(level, actions: solution.actions))
    }

    /// An unreachable target: one cell in the ground-row corner, every other cell of the bed forbidden, no leak
    /// allowed. Every bloom's outline rises six units above its foot, so any plant whose cast darkens the corner cell
    /// also darkens the cell above it, which is forbidden: every plant touching the target leaks beyond the allowance
    /// at every size and elevation. The brute force through the kernel confirms it; the solver gives no cover, no
    /// bound and no solution.
    @Test func unreachableTarget() throws {
        let width: Int = 16
        let height: Int = 12
        let target: Set<Int> = [0]
        var forbidden: Set<Int> = Set(0..<(width * height))
        forbidden.remove(0)
        let level: NocturneGardenLevel = try Self.level(target: target, forbidden: forbidden,
                                                        supply: [.tulip: 1, .bell: 1, .star: 1, .fern: 1, .rose: 1,
                                                                 .lily: 1],
                                                        sizes: [1, 2, 3], elevations: [1, 2, 3, 4], sun: 1)
        for elevation in 1...4 {
            #expect(Self.bruteCover(level, elevation: elevation) == 0, "brute \(elevation)")
            #expect(NocturneGardenSolver.cover(level, elevation: elevation) == 0, "cover \(elevation)")
        }
        #expect(NocturneGardenSolver.lowerBound(level) == nil)
        #expect(NocturneGardenSolver.solve(level) == nil)
    }

    /// The first 20 candidates of the first entry of bands 1, 2 and 3: every solved candidate's solution has exactly
    /// the lower bound's length, wins, and does not win one action earlier.
    @Test func candidatesSolveAtTheBound() throws {
        var solved: Int = 0
        for entryIndex in [0, 20, 40] {
            let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[entryIndex]
            for k in 0..<20 {
                guard let level = NocturneGardenGenerator.candidate(entry, index: k),
                      let solution = NocturneGardenSolver.solve(level) else { continue }
                solved += 1
                let bound: NocturneGardenBound = try #require(NocturneGardenSolver.lowerBound(level))
                #expect(solution.actions.count == bound.smallest, "entry \(entry.number) candidate \(k)")
                #expect(solution.smallest == bound.smallest, "entry \(entry.number) candidate \(k)")
                #expect(solution.work <= NocturneGardenSolver.workBound)
                #expect(NocturneGardenSolver.wins(level, actions: solution.actions), "entry \(entry.number) \(k)")
                var play = NocturneGardenPlay(level: level)
                try play.handle(.begin)
                if level.tutorial { try play.handle(.dismissTutorial) }
                for action in solution.actions.dropLast() {
                    try play.apply(action, expecting: play.fingerprint)
                }
                #expect(play.stage == .playing, "entry \(entry.number) candidate \(k) won early")
            }
        }
        #expect(solved > 0)
    }

    /// The single-plant cover the solver reports equals a brute force through the rules kernel, at every allowed
    /// elevation of a few hand-built levels and fixture levels (seed 2_382).
    @Test func coverMatchesBruteForce() throws {
        var levels: [NocturneGardenLevel] = []
        let tulip = NocturneGardenBloom(kind: .tulip, column: 4, row: 1, size: 2)
        let star = NocturneGardenBloom(kind: .star, column: 10, row: 0, size: 1)
        var target: Set<Int> = tulip.cells(elevation: 2, width: 16, height: 12)
        target.formUnion(star.cells(elevation: 2, width: 16, height: 12))
        var forbidden: Set<Int> = []
        for cell in NocturneGardenGenerator.ring(target, distance: 1, width: 16, height: 12) where cell % 3 == 0 {
            forbidden.insert(cell)
        }
        levels.append(try Self.level(target: target, forbidden: forbidden, supply: [.tulip: 1, .star: 1, .lily: 1],
                                     sizes: [1, 2], elevations: [1, 2, 3], sun: 1,
                                     required: try NocturneGardenRatio(4, 5), allowance: 1))
        levels.append(try Self.level(target: target, forbidden: forbidden, supply: [.fern: 2],
                                     sizes: [1, 3], elevations: [2, 4], sun: 4, allowance: 0))
        for fixture in NocturneGardenFixtures.fixtures(1, seed: Self.seed) where fixture.level.budget >= 2 {
            levels.append(fixture.level)
        }
        #expect(levels.count >= 3)
        for level in levels {
            for elevation in level.elevations.sorted() {
                #expect(NocturneGardenSolver.cover(level, elevation: elevation)
                            == Self.bruteCover(level, elevation: elevation), "\(level.fingerprint) sun \(elevation)")
            }
        }
    }

    /// Solving the same level twice gives equal solutions: the same actions and the same work.
    @Test func deterministic() throws {
        let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[20]
        var compared: Int = 0
        for k in 0..<8 {
            guard let level = NocturneGardenGenerator.candidate(entry, index: k) else { continue }
            let first: NocturneGardenSolution? = NocturneGardenSolver.solve(level)
            let second: NocturneGardenSolution? = NocturneGardenSolver.solve(level)
            #expect(first == second, "candidate \(k)")
            #expect(NocturneGardenSolver.lowerBound(level) == NocturneGardenSolver.lowerBound(level))
            if first != nil { compared += 1 }
        }
        #expect(compared > 0)
    }

    /// The work bound is honoured: with no plant evaluation allowed a level that needs one gives nil; with the default
    /// bound it solves within the bound.
    @Test func workBoundHonoured() throws {
        let bloom = NocturneGardenBloom(kind: .rose, column: 3, row: 2, size: 2)
        let target: Set<Int> = bloom.cells(elevation: 2, width: 16, height: 12)
        let level: NocturneGardenLevel = try Self.level(target: target, supply: [.rose: 1], sizes: [2])
        #expect(NocturneGardenSolver.solve(level, workBound: 0) == nil)
        let solution: NocturneGardenSolution = try #require(NocturneGardenSolver.solve(level))
        #expect(solution.work >= 1)
        #expect(solution.work <= NocturneGardenSolver.workBound)
        #expect(NocturneGardenSolver.wins(level, actions: solution.actions))
    }
}
