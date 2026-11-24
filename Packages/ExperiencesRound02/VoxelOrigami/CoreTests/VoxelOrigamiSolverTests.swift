// VoxelOrigamiSolverTests — feature 442 (R02-G15-02) T-R02G1502-003 (FR-R02G1502-002; SC-R02G1502-001, 002, 005;
// clarifications Q2, Q5). The breadth-first solver of Voxel Origami. Hand levels (orientations `fixed`, so a match is
// the target up to a translation) with minima worked out by hand:
// - one turn: a chain 0 —+x— 1 —+x— 2 —+y— 3 with hinge 2 started one quarter turn on (cube 3 at (2, 0, 1)); hinge 1
//   and hinge 2 share the x axis, so hinge 1 turned −1 already brings cube 3 back to (2, 1, 0) and, as the lower hinge
//   with −1 tried first, it is the plan: [turn(1, −1)], one state (the start) at depth 0;
// - two turns: two independent arms 0 —+x— 1 —+y— 2 and 0 —−x— 3 —+y— 4, hinges 1 and 3 each started one quarter
//   turn on; the root row of three is the only row of three, so the match is the rest pose itself; one turn fixes at
//   most one arm, so the minimum is 2: [turn(1, −1), turn(3, −1)], the start and its four neighbours counted;
// - a swept turn: 0 —+x— 1 —+z— 2 and 0 —+y— 3 —+z— 4 —+x— 5 (cube 5 at (1, 1, 1)), target cube 2 at (1, 1, 0) instead
//   of (1, 0, 1). The obvious turn(1, −1) would swing cube 2 through the arc that passes within one cell of cube 5 in
//   its layer, so the kernel refuses it (`sweep`) and the play fails; the long way round (+1 three times) is clear, and
//   moving cube 5 out of the way and back also costs three turns, so the minimum is 3.
// Then: the plan matches (VoxelOrigamiSolver.matches) and is minimal; the plan and the states counted at each smaller
// depth equal an independent breadth-first search written here (moves hinges ascending, −1 then +1, frontier order,
// states merged by quarter turns, its own match test); a work bound one short of the plan's work and a turn bound one
// short of its size give no plan, the exact bounds give the same plan; and an independent depth-first enumeration (no
// state merging) of every turn sequence the play accepts shorter than the plan finds no match (and, one turn longer,
// does find a match of the plan's size that plays), on the hand levels, on 24 seeded fixtures (seed 2,442) and on the
// two levels with the fewest cubes of each band of the generated catalog (a band's levels are generated in manifest
// order until two have the band's least cube count). A start that already matches is refused by the level (`solved`),
// so the solver never sees one. Explicit types, plain loops; each test runs in under 4 s on a debug host build.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiSolverTests {
    /// The fixture seed of this feature.
    static let seed: UInt64 = 2_442
    /// The fixtures searched.
    static let fixtureCount: Int = 24

    // MARK: - Hand levels

    /// A cube attached to `parent` along `direction` with `turn` as its starting quarter turn.
    static func cube(_ parent: Int, _ x: Int, _ y: Int, _ z: Int, turn: Int = 0) -> VoxelOrigamiCube {
        VoxelOrigamiCube(parent: parent, direction: VoxelOrigamiVector(x, y, z), startTurn: turn)
    }

    /// A `fixed` hand level of `cubes` and `target` (sorted here), budget 10.
    static func handLevel(_ id: String, cubes: [VoxelOrigamiCube],
                          target: [VoxelOrigamiVector]) throws -> VoxelOrigamiLevel {
        try VoxelOrigamiLevel(id: id, seed: seed, difficulty: 1, cubes: cubes, target: target.sorted(),
                              orientations: .fixed, budget: 10)
    }

    /// The one-turn hand level (see the file header).
    static func oneTurn() throws -> VoxelOrigamiLevel {
        let cubes: [VoxelOrigamiCube] = [.root, cube(0, 1, 0, 0), cube(1, 1, 0, 0, turn: 1), cube(2, 0, 1, 0)]
        let target: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0),
                                            VoxelOrigamiVector(2, 0, 0), VoxelOrigamiVector(2, 1, 0)]
        return try handLevel("one-turn", cubes: cubes, target: target)
    }

    /// The two-turn hand level (see the file header).
    static func twoTurns() throws -> VoxelOrigamiLevel {
        let cubes: [VoxelOrigamiCube] = [.root, cube(0, 1, 0, 0, turn: 1), cube(1, 0, 1, 0),
                                         cube(0, -1, 0, 0, turn: 1), cube(3, 0, 1, 0)]
        let target: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0),
                                            VoxelOrigamiVector(1, 1, 0), VoxelOrigamiVector(-1, 0, 0),
                                            VoxelOrigamiVector(-1, 1, 0)]
        return try handLevel("two-turns", cubes: cubes, target: target)
    }

    /// The swept hand level (see the file header).
    static func swept() throws -> VoxelOrigamiLevel {
        let cubes: [VoxelOrigamiCube] = [.root, cube(0, 1, 0, 0), cube(1, 0, 0, 1), cube(0, 0, 1, 0),
                                         cube(3, 0, 0, 1), cube(4, 1, 0, 0)]
        let target: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0),
                                            VoxelOrigamiVector(1, 1, 0), VoxelOrigamiVector(0, 1, 0),
                                            VoxelOrigamiVector(0, 1, 1), VoxelOrigamiVector(1, 1, 1)]
        return try handLevel("swept", cubes: cubes, target: target)
    }

    @Test func oneTurnHandLevelHasItsHandPlan() throws {
        let level: VoxelOrigamiLevel = try Self.oneTurn()
        let plan: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(level)
        #expect(plan?.turns == [.turn(1, -1)], "hinge 1 turned back is the first one-turn fix")
        #expect(plan?.statesByDepth == [1], "only the start lies below depth 1")
        #expect(VoxelOrigamiSolver.matches(level, actions: [.turn(1, -1)]), "the hand plan matches")
        #expect(VoxelOrigamiSolver.matches(level, actions: [.turn(2, -1)]), "hinge 2 turned back matches too")
        #expect(!VoxelOrigamiSolver.matches(level, actions: [.turn(1, 1)]), "the other way does not")
    }

    @Test func twoTurnHandLevelHasItsHandPlan() throws {
        let level: VoxelOrigamiLevel = try Self.twoTurns()
        let plan: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(level)
        #expect(plan?.turns == [.turn(1, -1), .turn(3, -1)], "each arm turned back, lower hinge first")
        #expect(plan?.statesByDepth == [1, 4], "the start and its four neighbours were searched")
        let singles: [VoxelOrigamiAction] = [.turn(1, -1), .turn(1, 1), .turn(3, -1), .turn(3, 1)]
        for single in singles {
            #expect(!VoxelOrigamiSolver.matches(level, actions: [single]), "no single turn fixes both arms")
        }
        #expect(VoxelOrigamiSolver.matches(level, actions: [.turn(1, -1), .turn(3, -1)]), "the hand plan matches")
    }

    @Test func sweptHandLevelGoesTheLongWay() throws {
        let level: VoxelOrigamiLevel = try Self.swept()
        let start: [Int] = level.startTurns
        let blocked: VoxelOrigamiFailure? = VoxelOrigamiLattice.check(level.cubes, turns: start, hinge: 1, step: -1)
        #expect(blocked?.code == "sweep", "the obvious turn is swept by cube 5")
        let backTurns: [Int] = VoxelOrigamiLattice.turned(start, hinge: 1, step: -1)
        #expect(level.report(turns: backTurns).matched, "its end pose alone would match")
        #expect(!VoxelOrigamiSolver.matches(level, actions: [.turn(1, -1)]), "the play fails the swept turn")
        let longWay: [VoxelOrigamiAction] = [.turn(1, 1), .turn(1, 1), .turn(1, 1)]
        #expect(VoxelOrigamiSolver.matches(level, actions: longWay), "the long way round matches")
        let plan: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(level)
        #expect(plan?.size == 3, "the minimum is three turns")
        if let plan {
            #expect(VoxelOrigamiSolver.matches(level, actions: plan.turns), "the plan matches")
            #expect(plan.statesByDepth.count == 3, "depths 0, 1 and 2 were searched")
            #expect(plan.statesByDepth.first == 1, "depth 0 is the start alone")
        }
    }

    @Test func handPlansEqualTheIndependentSearchAndNothingShorterMatches() throws {
        let levels: [VoxelOrigamiLevel] = [try Self.oneTurn(), try Self.twoTurns(), try Self.swept()]
        for level in levels {
            try Self.checkAgainstIndependentSearch(level)
        }
    }

    @Test func aStartThatAlreadyMatchesIsRefusedByTheLevel() {
        let cubes: [VoxelOrigamiCube] = [.root, Self.cube(0, 1, 0, 0), Self.cube(1, 1, 0, 0), Self.cube(2, 0, 1, 0)]
        let target: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(1, 0, 0),
                                            VoxelOrigamiVector(2, 0, 0), VoxelOrigamiVector(2, 1, 0)]
        #expect(throws: VoxelOrigamiError.level("solved")) {
            try Self.handLevel("solved", cubes: cubes, target: target)
        }
    }

    // MARK: - Bounds

    @Test func workBoundAndTurnBoundAreRespected() throws {
        let levels: [VoxelOrigamiLevel] = [try Self.oneTurn(), try Self.twoTurns(), try Self.swept()]
        for level in levels {
            guard let plan = VoxelOrigamiSolver.plan(level) else {
                Issue.record("a hand level has a plan")
                continue
            }
            #expect(plan.work >= plan.size, "at least one turn was tried per turn of the plan")
            #expect(VoxelOrigamiSolver.plan(level, workBound: plan.work - 1) == nil,
                    "one turn short of the plan's work gives no plan")
            #expect(VoxelOrigamiSolver.plan(level, workBound: plan.work) == plan, "the exact work gives the plan")
            #expect(VoxelOrigamiSolver.plan(level, workBound: 0) == nil, "no work gives no plan")
            #expect(VoxelOrigamiSolver.plan(level, maxTurns: plan.size - 1) == nil,
                    "one turn short of the plan's size gives no plan")
            #expect(VoxelOrigamiSolver.plan(level, maxTurns: plan.size) == plan, "the exact turn bound gives the plan")
        }
        #expect(VoxelOrigamiSolver.workBound == 300_000, "the work bound of clarification Q2")
        #expect(VoxelOrigamiSolver.maxTurns == 6, "at most six turns")
    }

    @Test func boundsAreRespectedOnSeededFixtures() {
        for fixture in VoxelOrigamiFixture.all(count: 8, seed: Self.seed) {
            guard let plan = VoxelOrigamiSolver.plan(fixture.level) else {
                Issue.record("fixture \(fixture.level.id) has a plan")
                continue
            }
            #expect(VoxelOrigamiSolver.plan(fixture.level, workBound: plan.work - 1) == nil, "work bound respected")
            #expect(VoxelOrigamiSolver.plan(fixture.level, maxTurns: plan.size - 1) == nil, "turn bound respected")
        }
    }

    // MARK: - Seeded levels

    @Test func seededFixturePlansAreMinimalAndFirstInOrder() throws {
        for fixture in VoxelOrigamiFixture.all(count: Self.fixtureCount, seed: Self.seed) {
            let level: VoxelOrigamiLevel = fixture.level
            guard let plan = VoxelOrigamiSolver.plan(level) else {
                Issue.record("fixture \(level.id) has a plan")
                continue
            }
            #expect(plan.size <= fixture.actions.count, "the plan is no longer than the fixture's known turns")
            try Self.checkAgainstIndependentSearch(level)
        }
    }

    @Test func fewestCubeLevelsOfBand1HaveNoShorterSequence() throws { try Self.checkFewestCubes(band: 1) }
    @Test func fewestCubeLevelsOfBand2HaveNoShorterSequence() throws { try Self.checkFewestCubes(band: 2) }
    @Test func fewestCubeLevelsOfBand3HaveNoShorterSequence() throws { try Self.checkFewestCubes(band: 3) }
    @Test func fewestCubeLevelsOfBand4HaveNoShorterSequence() throws { try Self.checkFewestCubes(band: 4) }
    @Test func fewestCubeLevelsOfBand5HaveNoShorterSequence() throws { try Self.checkFewestCubes(band: 5) }

    /// Generates `band`'s levels in manifest order until two have the fewest cubes a band allows (or all twenty are
    /// generated) and checks the two with the fewest cubes, ties broken by manifest order.
    static func checkFewestCubes(band: Int) throws {
        let profile: VoxelOrigamiBandProfile = .of(band: band)
        var generated: [VoxelOrigamiGenerated] = []
        var atLeast: Int = 0
        for entry in VoxelOrigamiManifest.entries where entry.band == band {
            let item: VoxelOrigamiGenerated = try VoxelOrigamiGenerator.generate(entry)
            #expect(profile.cubes.contains(item.level.cubes.count), "the cube count lies in the band's range")
            generated.append(item)
            if item.level.cubes.count == profile.cubes.lowerBound { atLeast += 1 }
            if atLeast == 2 { break }
        }
        var chosen: [VoxelOrigamiGenerated] = []
        for _ in 0..<2 {
            var best: VoxelOrigamiGenerated? = nil
            for item in generated where !chosen.contains(where: { $0.entry.number == item.entry.number }) {
                if let current = best, current.level.cubes.count <= item.level.cubes.count { continue }
                best = item
            }
            if let best { chosen.append(best) }
        }
        #expect(chosen.count == 2, "two levels checked per band")
        for item in chosen {
            let level: VoxelOrigamiLevel = item.level
            #expect(profile.planRange.contains(item.plan.size), "the plan lies in the band's range")
            #expect(VoxelOrigamiSolver.matches(level, actions: item.plan.turns), "the plan matches")
            let found: [VoxelOrigamiAction]? = shorterSequenceMatches(level, below: item.plan.size)
            #expect(found == nil, "no turn sequence shorter than the plan matches (level \(item.entry.number))")
            let independent: (turns: [VoxelOrigamiAction], frontiers: [Int])? =
                independentSearch(level, maxTurns: profile.planRange.upperBound)
            #expect(independent?.turns == item.plan.turns, "the plan equals the independent search's first plan")
            #expect(independent?.frontiers == item.plan.statesByDepth, "the counts equal the independent frontiers")
        }
    }

    // MARK: - Independent checks

    /// Checks `level`'s plan against the independent breadth-first search and depth-first enumeration.
    static func checkAgainstIndependentSearch(_ level: VoxelOrigamiLevel) throws {
        let plan: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(level)
        let independent: (turns: [VoxelOrigamiAction], frontiers: [Int])? =
            independentSearch(level, maxTurns: VoxelOrigamiSolver.maxTurns)
        #expect(plan?.turns == independent?.turns, "\(level.id): the plan is the first in the fixed order")
        #expect(plan?.statesByDepth == independent?.frontiers, "\(level.id): the counts equal the frontier sizes")
        guard let plan else { return }
        #expect(plan.statesByDepth.first == 1, "\(level.id): depth 0 is the start alone")
        #expect(plan.statesByDepth.count == plan.size, "\(level.id): one count per smaller depth")
        #expect(VoxelOrigamiSolver.matches(level, actions: plan.turns), "\(level.id): the plan matches")
        if plan.size > 0 {
            let shorter: [VoxelOrigamiAction] = Array(plan.turns.dropLast())
            #expect(!VoxelOrigamiSolver.matches(level, actions: shorter), "\(level.id): the plan without its last turn")
        }
        let found: [VoxelOrigamiAction]? = shorterSequenceMatches(level, below: plan.size)
        #expect(found == nil, "\(level.id): no accepted sequence shorter than the plan matches")
        let atSize: [VoxelOrigamiAction]? = shorterSequenceMatches(level, below: plan.size + 1)
        #expect(atSize?.count == plan.size, "\(level.id): the enumeration finds a match of the plan's size")
        if let atSize {
            #expect(VoxelOrigamiSolver.matches(level, actions: atSize), "\(level.id): the enumerated match plays")
        }
    }

    /// The test's own match: the occupied cells of `turns` equal the target under a rotation of the allowed group and a
    /// translation (each rotated cell set and the target are both shifted to their least corner and compared sorted).
    static func independentMatch(_ level: VoxelOrigamiLevel, turns: [Int],
                                 normalisedTarget: [VoxelOrigamiVector]) -> Bool {
        let cells: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(level.cubes, turns: turns).cells
        for rotation in level.orientations.group {
            var rotated: [VoxelOrigamiVector] = []
            for cell in cells { rotated.append(rotation.applied(to: cell)) }
            if normalise(rotated) == normalisedTarget { return true }
        }
        return false
    }

    /// `cells` shifted so that their least x, y and z are 0, sorted.
    static func normalise(_ cells: [VoxelOrigamiVector]) -> [VoxelOrigamiVector] {
        var minX: Int = Int.max
        var minY: Int = Int.max
        var minZ: Int = Int.max
        for cell in cells {
            minX = min(minX, cell.x)
            minY = min(minY, cell.y)
            minZ = min(minZ, cell.z)
        }
        var shifted: [VoxelOrigamiVector] = []
        for cell in cells { shifted.append(VoxelOrigamiVector(cell.x - minX, cell.y - minY, cell.z - minZ)) }
        return shifted.sorted()
    }

    /// The moves the play accepts and clears from `turns`, in the fixed order (hinges ascending, −1 then +1), with
    /// their resulting turns.
    static func clearMoves(_ level: VoxelOrigamiLevel, turns: [Int]) -> [(VoxelOrigamiAction, [Int])] {
        var moves: [(VoxelOrigamiAction, [Int])] = []
        for hinge in 1..<level.cubes.count {
            for step in [-1, 1] {
                let action: VoxelOrigamiAction = .turn(hinge, step)
                if let next = VoxelOrigamiFixture.apply(action, cubes: level.cubes, turns: turns) {
                    moves.append((action, next))
                }
            }
        }
        return moves
    }

    /// The test's own breadth-first search: the first matching path in frontier order and the frontier sizes below it.
    static func independentSearch(_ level: VoxelOrigamiLevel,
                                  maxTurns: Int) -> (turns: [VoxelOrigamiAction], frontiers: [Int])? {
        let target: [VoxelOrigamiVector] = normalise(level.target)
        let start: [Int] = level.startTurns
        var frontier: [([Int], [VoxelOrigamiAction])] = [(start, [])]
        var seen: Set<[Int]> = [start]
        var frontiers: [Int] = []
        var depth: Int = 0
        while !frontier.isEmpty, depth < maxTurns {
            frontiers.append(frontier.count)
            depth += 1
            var next: [([Int], [VoxelOrigamiAction])] = []
            for (turns, path) in frontier {
                for (action, reached) in clearMoves(level, turns: turns) {
                    if seen.contains(reached) { continue }
                    seen.insert(reached)
                    let reachedPath: [VoxelOrigamiAction] = path + [action]
                    if independentMatch(level, turns: reached, normalisedTarget: target) {
                        return (reachedPath, frontiers)
                    }
                    next.append((reached, reachedPath))
                }
            }
            frontier = next
        }
        return nil
    }

    /// The rotation- and translation-invariant spread of `cells`: the sum over pairs of their squared distance,
    /// n · Σ|c|² − |Σc|².
    static func spread(_ cells: [VoxelOrigamiVector]) -> Int {
        var sx: Int = 0
        var sy: Int = 0
        var sz: Int = 0
        var squares: Int = 0
        for c in cells {
            sx += c.x
            sy += c.y
            sz += c.z
            squares += c.x * c.x + c.y * c.y + c.z * c.z
        }
        return cells.count * squares - (sx * sx + sy * sy + sz * sz)
    }

    /// The test's own depth-first enumeration, without state merging, of every sequence of fewer than `below` turns
    /// the play accepts and clears from the start: the first that matches, or nil. A turn is modelled as the rigid
    /// quarter turn of the hinge cube's subtree about the hinge's axis (checked against the kernel's pose wherever the
    /// enumeration continues); a reached pose whose spread differs from the target's cannot match, and a pose that
    /// might is confirmed through the kernel's lattice check and the test's own match.
    static func shorterSequenceMatches(_ level: VoxelOrigamiLevel, below: Int) -> [VoxelOrigamiAction]? {
        guard below > 1 else { return nil }
        let cubes: [VoxelOrigamiCube] = level.cubes
        let target: [VoxelOrigamiVector] = normalise(level.target)
        let targetSpread: Int = spread(level.target)
        var subtrees: [[Int]] = [[]]
        for hinge in 1..<cubes.count { subtrees.append(VoxelOrigamiLattice.descendants(cubes, of: hinge)) }
        let start: [Int] = level.startTurns
        var stack: [([Int], [VoxelOrigamiVector], [VoxelOrigamiAction])] =
            [(start, VoxelOrigamiLattice.pose(cubes, turns: start).cells, [])]
        while let (turns, cells, path) = stack.popLast() {
            let continues: Bool = path.count + 1 < below - 1
            for hinge in 1..<cubes.count {
                guard let parent = cubes[hinge].parent else { continue }
                let centre: VoxelOrigamiVector = cells[hinge]
                let axis: VoxelOrigamiVector = centre - cells[parent]
                var swings: Bool = false
                for index in subtrees[hinge] where !VoxelOrigamiLattice.isParallel(cells[index] - centre, axis) {
                    swings = true
                    break
                }
                if !swings { continue }
                for step in [-1, 1] {
                    let rotation: VoxelOrigamiRotation = .quarter(about: axis, turns: step)
                    var reachedCells: [VoxelOrigamiVector] = cells
                    for index in subtrees[hinge] {
                        reachedCells[index] = centre + rotation.applied(to: cells[index] - centre)
                    }
                    let action: VoxelOrigamiAction = .turn(hinge, step)
                    let mightMatch: Bool = spread(reachedCells) == targetSpread
                    if !mightMatch && !continues { continue }
                    guard let reached = VoxelOrigamiFixture.apply(action, cubes: cubes, turns: turns) else { continue }
                    let reachedPath: [VoxelOrigamiAction] = path + [action]
                    if mightMatch, independentMatch(level, turns: reached, normalisedTarget: target) {
                        return reachedPath
                    }
                    if continues {
                        let kernelCells: [VoxelOrigamiVector] = VoxelOrigamiLattice.pose(cubes, turns: reached).cells
                        if kernelCells != reachedCells {
                            Issue.record("\(level.id): the rigid turn model disagrees with the kernel's pose")
                            return reachedPath
                        }
                        stack.append((reached, reachedCells, reachedPath))
                    }
                }
            }
        }
        return nil
    }
}
