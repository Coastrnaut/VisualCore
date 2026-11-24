// MoonlitMechanismSolverTests — feature 432 (R02-G14-02) T-R02G1402-003 (FR-R02G1402-002; SC-R02G1402-001, 002,
// 005; clarifications Q2, Q5). The minimal-plan solver of Moonlit Mechanism. Hand levels with minima worked out by
// hand: two 6-tooth gears (the child meshing with the driver), each with one solid blade whose slot k casts the single
// cell (column 1 + k) on its own row (driver row 1, child row 3, both depth 1, so lamp height h moves both down h rows),
// two required key frames (turns 0 and 1) whose targets are the solution's casts, allowance 0. The cast fixes both
// phases and the lamp height, so exactly one set-up wins (solution phases 2 and 3, height 0); a turn t moves the driver
// by +t and the child by −t, a re-seat r moves the child by r. From that the minima: a start turned one tooth back (plan
// +1 turn) or forward (−1 turn); the child re-seated one tooth off (a turn cannot help: it would move the driver; plan
// one re-seat); the lamp one height up (plan −1 lamp); turned back and re-seated back (no single action fixes both
// gears; plan +1 turn and +1 re-seat); turned back with the lamp up (plan +1 turn, −1 lamp); the solution itself (plan
// 0, only the run). Then the witness order (turns, re-seats in gear order, lamp steps, run), `wins` for the witness and
// not for the witness without its last set-up action; an independent breadth-first search (the test's own step on
// phases and lamp height, every action the play accepts, states merged by phases and height) on the 40 feature
// fixtures and on the two catalog levels of each band 1 … 5 with the fewest gears: nothing reached within plan − 1
// actions wins and something at plan actions does; `smallerVectors` recounted by the test's own enumeration of the
// integer vectors of dimension gears + 1 and L1 norm below the plan size; the work bound (0 runs, one run short of the
// plan's work, exactly the plan's work) and the action bound (plan − 1). Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MoonlitMechanismCore

@Suite struct MoonlitMechanismSolverTests {
    /// The fixture seed of this feature.
    static let seed: UInt64 = 2_432
    /// The fixtures searched.
    static let fixtureCount: Int = 40

    // MARK: - Hand levels

    /// The solution phases of the hand levels (driver, child).
    static let solution: [Int] = [2, 3]
    /// The solution lamp height of the hand levels.
    static let solutionHeight: Int = 0

    /// A 6-tooth gear with one solid blade (bit 0) whose slot k casts (column k, row 0) from `centre`.
    static func gear(phase: Int, centre: MoonlitMechanismCell, parent: Int?, alignment: Int) -> MoonlitMechanismGear {
        var blades: [Bool] = Array(repeating: false, count: 6)
        blades[0] = true
        var slots: [[MoonlitMechanismCell]] = []
        for slot in 0..<6 { slots.append([MoonlitMechanismCell(column: slot, row: 0)]) }
        return MoonlitMechanismGear(teeth: 6, phase: phase, blades: blades, depth: 1, centre: centre, parent: parent,
                                    alignment: alignment, slots: slots)
    }

    /// The hand level whose start is `phases` at lamp height `height` (the solution fixed as above), budget 9.
    static func handLevel(_ id: String, phases: [Int], height: Int) throws -> MoonlitMechanismLevel {
        let alignment: Int = MoonlitMechanismTrain.mod(solution[0] + solution[1], 6)
        let centres: [MoonlitMechanismCell] = [MoonlitMechanismCell(column: 1, row: 1),
                                                MoonlitMechanismCell(column: 1, row: 3)]
        var solved: [MoonlitMechanismGear] = []
        var start: [MoonlitMechanismGear] = []
        for index in 0..<2 {
            let parent: Int? = index == 0 ? nil : 0
            let align: Int = index == 0 ? 0 : alignment
            solved.append(gear(phase: solution[index], centre: centres[index], parent: parent, alignment: align))
            start.append(gear(phase: phases[index], centre: centres[index], parent: parent, alignment: align))
        }
        var frames: [MoonlitMechanismKeyFrame] = []
        for turns in 0..<2 {
            let at: [Int] = MoonlitMechanismTrain.turned(solved, phases: solution, by: turns)
            let cells: [Int] = MoonlitMechanismTrain.cast(solved, phases: at, height: solutionHeight, width: 8,
                                                          rows: 6)
            frames.append(MoonlitMechanismKeyFrame(turns: turns, target: cells, required: true))
        }
        return try MoonlitMechanismLevel(id: id, seed: seed, difficulty: 1, gears: start, width: 8, rows: 6,
                                         lampHeights: 2, startingHeight: height, keyFrames: frames, forbidden: [],
                                         allowance: 0, budget: 9)
    }

    /// One hand case: a start and its plan worked out by hand.
    struct HandCase {
        /// The level id.
        let id: String
        /// The starting phases.
        let phases: [Int]
        /// The starting lamp height.
        let height: Int
        /// The expected net turns.
        let turns: Int
        /// The expected net lamp steps.
        let lamp: Int
        /// The expected re-seats (driver first, always 0).
        let reseats: [Int]
    }

    /// The hand cases (see the file header).
    static let handCases: [HandCase] = [
        HandCase(id: "turn-forward", phases: [1, 4], height: 0, turns: 1, lamp: 0, reseats: [0, 0]),
        HandCase(id: "turn-back", phases: [3, 2], height: 0, turns: -1, lamp: 0, reseats: [0, 0]),
        HandCase(id: "reseat-up", phases: [2, 2], height: 0, turns: 0, lamp: 0, reseats: [0, 1]),
        HandCase(id: "reseat-down", phases: [2, 4], height: 0, turns: 0, lamp: 0, reseats: [0, -1]),
        HandCase(id: "lamp-down", phases: [2, 3], height: 1, turns: 0, lamp: -1, reseats: [0, 0]),
        HandCase(id: "turn-and-reseat", phases: [1, 3], height: 0, turns: 1, lamp: 0, reseats: [0, 1]),
        HandCase(id: "turn-and-lamp", phases: [1, 4], height: 1, turns: 1, lamp: -1, reseats: [0, 0]),
        HandCase(id: "already-won", phases: [2, 3], height: 0, turns: 0, lamp: 0, reseats: [0, 0]),
    ]

    @Test func handLevelsHaveTheirMinimaWorkedOutByHand() throws {
        for hand in Self.handCases {
            let level: MoonlitMechanismLevel = try Self.handLevel(hand.id, phases: hand.phases, height: hand.height)
            let plan: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(level)
            #expect(plan != nil, "a hand level has a plan")
            guard let plan else { continue }
            #expect(plan.turns == hand.turns, "the plan's net turns are the hand minimum")
            #expect(plan.lamp == hand.lamp, "the plan's net lamp steps are the hand minimum")
            #expect(plan.reseats == hand.reseats, "the plan's re-seats are the hand minimum")
            let size: Int = abs(hand.turns) + abs(hand.lamp) + hand.reseats.reduce(0) { $0 + abs($1) }
            #expect(plan.size == size, "the plan's size is the hand minimum")
            #expect(plan.smallerVectors == Self.vectorsBelow(dimensions: 3, norm: size),
                    "every vector of a smaller norm was tried")
            #expect(MoonlitMechanismSolver.wins(level, actions: MoonlitMechanismSolver.actions(plan)),
                    "the hand plan's witness wins")
        }
    }

    @Test func aStartThatAlreadyWinsHasAnEmptyPlan() throws {
        let level: MoonlitMechanismLevel = try Self.handLevel("already-won", phases: Self.solution,
                                                              height: Self.solutionHeight)
        #expect(level.run(phases: level.startingPhases, height: level.startingHeight).outcome == .won,
                "the solution start wins as it stands")
        let plan: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(level)
        #expect(plan?.size == 0, "a winning start needs no action")
        #expect(plan?.smallerVectors == 0, "no vector is smaller than the zero vector")
        #expect(plan?.work == 1, "the zero vector is judged by one run")
        if let plan {
            #expect(MoonlitMechanismSolver.actions(plan) == [.run], "the empty plan's witness is the run alone")
            #expect(MoonlitMechanismSolver.wins(level, actions: [.run]), "the run alone wins")
        }
    }

    @Test func noSingleActionFixesTheTwoActionHandLevel() throws {
        let level: MoonlitMechanismLevel = try Self.handLevel("turn-and-reseat", phases: [1, 3], height: 0)
        let singles: [MoonlitMechanismAction] = [.turn(1), .turn(-1), .reseat(1, 1), .reseat(1, -1), .lamp(1)]
        for action in singles {
            #expect(!MoonlitMechanismSolver.wins(level, actions: [action, .run]), "no single action wins")
        }
        #expect(MoonlitMechanismSolver.wins(level, actions: [.turn(1), .reseat(1, 1), .run]),
                "the hand pair of actions wins")
    }

    // MARK: - Witness order and replay

    @Test func witnessListsTurnsThenReseatsInGearOrderThenLampThenRun() {
        let plan = MoonlitMechanismPlan(turns: -2, lamp: 1, reseats: [0, 1, 0, -2], smallerVectors: 0, work: 0)
        let expected: [MoonlitMechanismAction] = [.turn(-1), .turn(-1), .reseat(1, 1), .reseat(3, -1),
                                                  .reseat(3, -1), .lamp(1), .run]
        #expect(MoonlitMechanismSolver.actions(plan) == expected, "turns, re-seats in gear order, lamp steps, run")
        #expect(plan.size == 6, "the size is the vector's L1 norm")
        let back = MoonlitMechanismPlan(turns: 1, lamp: -2, reseats: [0, -1, 2], smallerVectors: 0, work: 0)
        let expectedBack: [MoonlitMechanismAction] = [.turn(1), .reseat(1, -1), .reseat(2, 1), .reseat(2, 1),
                                                      .lamp(-1), .lamp(-1), .run]
        #expect(MoonlitMechanismSolver.actions(back) == expectedBack, "each coordinate's sign gives its steps")
    }

    @Test func witnessWinsAndLosesWithoutItsLastSetUpAction() throws {
        var levels: [MoonlitMechanismLevel] = []
        for hand in Self.handCases {
            levels.append(try Self.handLevel(hand.id, phases: hand.phases, height: hand.height))
        }
        for fixture in MoonlitMechanismFixture.all(count: Self.fixtureCount, seed: Self.seed) {
            levels.append(fixture.level)
        }
        for level in levels {
            guard let plan = MoonlitMechanismSolver.plan(level) else {
                Issue.record("a fixture or hand level has a plan")
                continue
            }
            let actions: [MoonlitMechanismAction] = MoonlitMechanismSolver.actions(plan)
            #expect(actions.count == plan.size + 1, "the witness is the plan's actions and the run")
            #expect(actions.last == .run, "the witness ends with the run")
            #expect(MoonlitMechanismSolver.wins(level, actions: actions), "the witness wins")
            guard plan.size > 0 else { continue }
            var shorter: [MoonlitMechanismAction] = actions
            shorter.remove(at: actions.count - 2)
            #expect(!MoonlitMechanismSolver.wins(level, actions: shorter),
                    "the witness without its last set-up action loses")
        }
    }

    // MARK: - Independent breadth-first search

    /// A set-up: the phases and the lamp height.
    struct SetUp: Hashable {
        /// The phases.
        let phases: [Int]
        /// The lamp height.
        let height: Int
    }

    /// The set-ups one accepted action from `state` (the test's own step: a turn ±1 moves every gear by its train
    /// direction, a re-seat ±1 of each non-driver gear, a lamp step ±1 within range).
    static func successors(_ state: SetUp, level: MoonlitMechanismLevel) -> [SetUp] {
        let gears: [MoonlitMechanismGear] = level.gears
        var signs: [Int] = []
        for index in gears.indices {
            var depth: Int = 0
            var current: Int = index
            while let parent = gears[current].parent {
                depth += 1
                current = parent
            }
            signs.append(depth % 2 == 0 ? 1 : -1)
        }
        var next: [SetUp] = []
        for step in [1, -1] {
            var turned: [Int] = state.phases
            for index in gears.indices {
                turned[index] = ((turned[index] + signs[index] * step) % gears[index].teeth + gears[index].teeth)
                    % gears[index].teeth
            }
            next.append(SetUp(phases: turned, height: state.height))
            for gear in 1..<gears.count {
                var reseated: [Int] = state.phases
                reseated[gear] = ((reseated[gear] + step) % gears[gear].teeth + gears[gear].teeth) % gears[gear].teeth
                next.append(SetUp(phases: reseated, height: state.height))
            }
            let height: Int = state.height + step
            if height >= 0, height < level.lampHeights {
                next.append(SetUp(phases: state.phases, height: height))
            }
        }
        return next
    }

    /// Breadth-first search to depth `size`: true when no set-up within `size − 1` actions wins and some set-up at
    /// exactly `size` actions does.
    static func searchConfirms(_ level: MoonlitMechanismLevel, size: Int) -> Bool {
        let start = SetUp(phases: level.startingPhases, height: level.startingHeight)
        var seen: Set<SetUp> = [start]
        var layer: [SetUp] = [start]
        for depth in 0...size {
            var wins: Bool = false
            for state in layer where level.run(phases: state.phases, height: state.height).outcome == .won {
                wins = true
                break
            }
            if depth < size, wins { return false }
            if depth == size { return wins }
            var next: [SetUp] = []
            for state in layer {
                for successor in successors(state, level: level) where !seen.contains(successor) {
                    seen.insert(successor)
                    next.append(successor)
                }
            }
            layer = next
        }
        return false
    }

    @Test func independentSearchConfirmsFixturePlans() {
        let fixtures: [MoonlitMechanismFixture] = MoonlitMechanismFixture.all(count: Self.fixtureCount,
                                                                              seed: Self.seed)
        #expect(fixtures.count == Self.fixtureCount, "every fixture is drawn")
        for fixture in fixtures {
            guard let plan = MoonlitMechanismSolver.plan(fixture.level) else {
                Issue.record("the solver finds every fixture's plan")
                continue
            }
            #expect(plan.size <= fixture.actions.count - 1, "the plan is no longer than the known actions")
            #expect(Self.searchConfirms(fixture.level, size: plan.size),
                    "the breadth-first search finds no shorter win and a win at the plan's size")
        }
    }

    /// The generated catalog levels searched: for each band 1 … 5 the two entries with the fewest gears (ties in
    /// manifest order).
    static func catalogSample() throws -> [MoonlitMechanismGenerated] {
        var sample: [MoonlitMechanismGenerated] = []
        for band in 1...5 {
            var generated: [MoonlitMechanismGenerated] = []
            for entry in MoonlitMechanismManifest.entries where entry.band == band {
                generated.append(try MoonlitMechanismGenerator.generate(entry))
            }
            let sorted: [MoonlitMechanismGenerated] = generated.enumerated().sorted { left, right in
                if left.element.level.gears.count != right.element.level.gears.count {
                    return left.element.level.gears.count < right.element.level.gears.count
                }
                return left.offset < right.offset
            }.map(\.element)
            sample.append(contentsOf: sorted.prefix(2))
        }
        return sample
    }

    @Test func independentSearchConfirmsCatalogPlans() throws {
        let sample: [MoonlitMechanismGenerated] = try Self.catalogSample()
        #expect(sample.count == 10, "two catalog levels per band")
        for generated in sample {
            let range: ClosedRange<Int> = MoonlitMechanismBandProfile.of(band: generated.entry.band).planRange
            #expect(range.contains(generated.plan.size), "the catalog plan lies in its band's range")
            #expect(MoonlitMechanismSolver.plan(generated.level, maxActions: range.upperBound) == generated.plan,
                    "the solver repeats the catalog plan")
            #expect(Self.searchConfirms(generated.level, size: generated.plan.size),
                    "the breadth-first search finds no shorter win and a win at the plan's size")
            #expect(MoonlitMechanismSolver.wins(generated.level, actions: generated.actions),
                    "the catalog witness wins")
        }
    }

    // MARK: - Smaller vectors

    /// The integer vectors of `dimensions` coordinates with L1 norm exactly `norm` (the test's own recursion).
    static func vectors(dimensions: Int, norm: Int) -> Int {
        if dimensions == 1 { return norm == 0 ? 1 : 2 }
        var count: Int = 0
        for value in -norm...norm { count += vectors(dimensions: dimensions - 1, norm: norm - abs(value)) }
        return count
    }

    /// The integer vectors of `dimensions` coordinates with L1 norm below `norm`.
    static func vectorsBelow(dimensions: Int, norm: Int) -> Int {
        var count: Int = 0
        for value in 0..<max(norm, 0) { count += vectors(dimensions: dimensions, norm: value) }
        return count
    }

    @Test func vectorCountMatchesKnownValues() {
        #expect(Self.vectors(dimensions: 3, norm: 0) == 1, "one vector of norm 0")
        #expect(Self.vectors(dimensions: 3, norm: 1) == 6, "six unit vectors in three dimensions")
        #expect(Self.vectors(dimensions: 3, norm: 2) == 18, "eighteen vectors of norm 2 in three dimensions")
        #expect(Self.vectors(dimensions: 2, norm: 3) == 12, "twelve vectors of norm 3 in the plane")
    }

    @Test func smallerVectorsCountsEveryVectorOfASmallerNorm() throws {
        var levels: [MoonlitMechanismLevel] = []
        for fixture in MoonlitMechanismFixture.all(count: 12, seed: Self.seed) { levels.append(fixture.level) }
        for generated in try Self.catalogSample() { levels.append(generated.level) }
        for level in levels {
            guard let plan = MoonlitMechanismSolver.plan(level) else {
                Issue.record("the level has a plan")
                continue
            }
            #expect(plan.smallerVectors == Self.vectorsBelow(dimensions: level.gears.count + 1, norm: plan.size),
                    "smallerVectors is every vector of norm below the plan's size")
            #expect(plan.work >= 1, "the winning vector was judged by a run")
            #expect(plan.work <= plan.smallerVectors + Self.vectors(dimensions: level.gears.count + 1,
                                                                     norm: plan.size),
                    "runs never exceed the vectors tried")
        }
    }

    // MARK: - Work and action bounds

    @Test func workAndActionBoundsAreRespected() throws {
        var levels: [MoonlitMechanismLevel] = []
        for hand in Self.handCases {
            levels.append(try Self.handLevel(hand.id, phases: hand.phases, height: hand.height))
        }
        for fixture in MoonlitMechanismFixture.all(count: 12, seed: Self.seed) { levels.append(fixture.level) }
        for level in levels {
            guard let plan = MoonlitMechanismSolver.plan(level) else {
                Issue.record("the level has a plan")
                continue
            }
            #expect(plan.work <= MoonlitMechanismSolver.workBound, "the work stays within the bound")
            #expect(MoonlitMechanismSolver.plan(level, workBound: 0) == nil, "no run allowed gives no plan")
            #expect(MoonlitMechanismSolver.plan(level, workBound: plan.work) == plan,
                    "a bound of exactly the plan's work finds the same plan")
            #expect(MoonlitMechanismSolver.plan(level, workBound: plan.work - 1) == nil,
                    "a bound one run short of the plan's work gives no plan")
            if plan.size > 0 {
                #expect(MoonlitMechanismSolver.plan(level, maxActions: plan.size - 1) == nil,
                        "an action bound below the plan's size gives no plan")
            }
            #expect(MoonlitMechanismSolver.plan(level, maxActions: plan.size) == plan,
                    "an action bound of exactly the plan's size finds the same plan")
        }
    }

    @Test func planIsDeterministic() {
        for fixture in MoonlitMechanismFixture.all(count: 8, seed: Self.seed) {
            #expect(MoonlitMechanismSolver.plan(fixture.level) == MoonlitMechanismSolver.plan(fixture.level),
                    "the same level gives the same plan")
        }
    }
}
