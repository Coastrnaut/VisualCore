// BinaryGardensSolverTests — feature 502 (R02-G21-02) T-R02G2102-003 (FR-R02G2102-002, 003; SC-R02G2102-001, 002, 005;
// clarifications Q2, Q3, Q5; research R3, R6, R9, R10, R14). The certifying solver of Binary Gardens, on hand levels
// with known minima (one ring, one phase, a luminosity and a tilt, and a swap of two rings that the minimum separation
// σ forces into a three-action detour), each with one world whose bands are its target's run with zero margin
// (comfortable band = the target's lowest … highest flux, window 48, bloom band = the target's integral; the judge is
// invariant under a cyclic shift of time, so phases come in winning families, while the detour's target is its only
// winner), and on generated catalog levels of bands 1 … 4 (manifest entries 1, 21, 41 and 61, each generated with no
// previous level and cached per process):
// - known minima: the plan has the expected size and actions, wins through the kernel's play, and no arrangement
//   reachable with fewer actions wins; the detour plan's every prefix keeps σ (refused moves are never followed);
// - an independent enumeration of every action sequence shorter than the plan through `BinaryGardensPuzzle` moves (no
//   visited set, no loss order) judges every arrangement reached: none wins, the number first reached at each length
//   equals `arrangementsByDepth`, and the plan's own sequence goes through the puzzle's moves to a win;
// - the loss order changes only the work: a plain breadth-first sweep in discovery order wins first at the plan's depth
//   with the same per-depth counts and the same nearest miss;
// - the plan is its parent chain: replaying its actions from the start reaches its arrangement;
// - the work bound: nil one arrangement short of the plan's work (and at a bound of 1), the same plan at it; nil when
//   the depth limit is below the plan;
// - `BinaryGardensControl` values, actions, settings and adjustability in the fixed order;
// - `BinaryGardensDifficulty(level:plan:)` on a hand level and `puzzleDifficulty`;
// - the loss: 0 for the target's report, the sum of its three parts otherwise.
// Plain loops, explicit types, no clock.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensSolverTests {
    typealias Level = BinaryGardensLevel
    typealias Arrangement = BinaryGardensArrangement
    typealias Solver = BinaryGardensSolver

    // MARK: - Generated levels

    /// The manifest numbers of the generated levels under test: the first of bands 1 … 4.
    static let numbers: [Int] = [1, 21, 41, 61]

    /// The generated levels of ``numbers``, in that order (generated once per process, no previous level).
    static let generated: [BinaryGardensGenerated] = {
        var result: [BinaryGardensGenerated] = []
        for number in numbers {
            let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[number - 1]
            if let level = try? BinaryGardensGenerator.generate(entry, previous: nil) { result.append(level) }
        }
        return result
    }()

    // MARK: - Hand levels

    /// A hand level whose one world's bands are exactly the target's run (zero margin): rings `rings`, ω 1,
    /// luminosities 8 and 24, T_max `maxTilt`, σ `separation`, phase step `phaseStep`, clamp 2, one world at radius 20,
    /// phase 5, speed −1; comfortable band = the target's lowest … highest flux, window 48, lethal bounds 0 and 200 000,
    /// bloom band = the target's integral, tolerance 0. Starts at `start` with the given adjustable flags.
    static func hand(target: Arrangement, start: Arrangement, rings: [Int] = [3, 6, 9], maxTilt: Int = 2,
                     separation: Int = 0, phaseStep: Int = 8, flags: [[Bool]],
                     budget: Int = 10) throws(BinaryGardensError) -> Level {
        let wide = BinaryGardensWorld(radius: 20, phase: 5, speed: -1, lethalLow: 0, comfortLow: 1,
                                      comfortHigh: 199_999, lethalHigh: 200_000, window: 1, bloomLow: 0,
                                      bloomHigh: BinaryGardensLevel.maximumBloom)
        var targetStars: [BinaryGardensStar] = []
        for star in 0..<2 {
            targetStars.append(BinaryGardensStar(ring: target.rings[star], phase: target.phases[star],
                                                 luminosity: target.luminosities[star], ringAdjustable: true,
                                                 phaseAdjustable: false, luminosityAdjustable: false))
        }
        let probe: Level = try Level.probe(ringRadii: rings, starSpeed: 1, luminosityLevels: [8, 24],
                                           stars: targetStars, maxTilt: maxTilt, startTilt: target.tilt,
                                           minimumSeparation: separation, clampRadius: 2, worlds: [wide],
                                           lethalTolerance: 0, phaseStep: phaseStep)
        let light: BinaryGardensWorldLight = probe.startReport.worlds[0]
        let low: Int = light.flux.min() ?? 1
        let high: Int = light.flux.max() ?? 1
        let world = BinaryGardensWorld(radius: 20, phase: 5, speed: -1, lethalLow: 0, comfortLow: low,
                                       comfortHigh: high, lethalHigh: 200_000, window: 48, bloomLow: light.integral,
                                       bloomHigh: light.integral)
        var stars: [BinaryGardensStar] = []
        for star in 0..<2 {
            stars.append(BinaryGardensStar(ring: start.rings[star], phase: start.phases[star],
                                           luminosity: start.luminosities[star], ringAdjustable: flags[star][0],
                                           phaseAdjustable: flags[star][1], luminosityAdjustable: flags[star][2]))
        }
        return try Level(id: "solver-hand", seed: 0, difficulty: 1, ringRadii: rings, starSpeed: 1,
                         luminosityLevels: [8, 24], stars: stars, maxTilt: maxTilt, startTilt: start.tilt,
                         minimumSeparation: separation, clampRadius: 2, worlds: [world], lethalTolerance: 0,
                         budget: budget, tutorial: false, phaseStep: phaseStep)
    }

    /// An arrangement of the given values.
    static func arrangement(_ rings: [Int], _ phases: [Int], _ luminosities: [Int], _ tilt: Int) -> Arrangement {
        Arrangement(rings: rings, phases: phases, luminosities: luminosities, tilt: tilt)
    }

    /// A hand case: a name, its level, its target, the size of its minimal plan and the plan the solver finds.
    struct HandCase: Sendable {
        /// The case's name.
        let name: String
        /// The level.
        let level: Level
        /// The target arrangement whose run set the bands.
        let target: Arrangement
        /// The size of the level's minimal plan.
        let size: Int
        /// The solver's plan: the first winner of its sweep.
        let actions: [BinaryGardensAction]
    }

    /// Every control adjustable on both stars.
    static let allFlags: [[Bool]] = [[true, true, true], [true, true, true]]

    /// The hand cases: one ring, one phase, a luminosity and a tilt, and the σ detour.
    static let handCases: [HandCase] = {
        let start: Arrangement = arrangement([0, 2], [0, 24], [0, 1], 0)
        var result: [HandCase] = []
        let simple: [(String, Arrangement, Int, [BinaryGardensAction])] = [
            ("one ring", arrangement([1, 2], [0, 24], [0, 1], 0), 1, [.ring(star: 0, index: 1)]),
            // Star 2's phases 8, 16, 32 and 40 all win (the cyclic family); 8 comes first in the move order.
            ("one phase", arrangement([0, 2], [0, 40], [0, 1], 0), 1, [.phase(star: 1, step: 8)]),
            ("luminosity and tilt", arrangement([0, 2], [0, 24], [1, 1], 2), 2,
             [.luminosity(star: 0, index: 1), .tilt(step: 2)]),
        ]
        for (name, target, size, actions) in simple {
            if let level = try? hand(target: target, start: start, flags: allFlags) {
                result.append(HandCase(name: name, level: level, target: target, size: size, actions: actions))
            }
        }
        // The σ detour: rings 2, 5, 8 and σ 2; star 1 on ring 1 and star 2 on ring 2, both locked at phase 0, swap to
        // rings 2 and 1. Both direct moves put the stars 0 units apart, so the swap goes through ring 3: three actions
        // for two changed controls.
        let detourStart: Arrangement = arrangement([0, 1], [0, 0], [0, 1], 0)
        let detourTarget: Arrangement = arrangement([1, 0], [0, 0], [0, 1], 0)
        if let level = try? hand(target: detourTarget, start: detourStart, rings: [2, 5, 8], maxTilt: 0,
                                 separation: 2, flags: [[true, false, false], [true, false, false]]) {
            result.append(HandCase(name: "detour", level: level, target: detourTarget, size: 3,
                                   actions: [.ring(star: 0, index: 2), .ring(star: 1, index: 0),
                                             .ring(star: 0, index: 1)]))
        }
        return result
    }()

    // MARK: - Independent checks

    /// The result of the independent enumeration.
    struct Enumeration: Sendable {
        /// The arrangements first reached at each length 0 … the deepest enumerated.
        let firstReached: [Set<Arrangement>]
        /// Whether any reached arrangement wins.
        let anyWin: Bool
    }

    /// Every action sequence of length 0 … `maxLength` through the puzzle's moves (no visited set, no loss order); the
    /// arrangements reached at each length, minus those reached at a smaller length, each judged once by the kernel.
    static func enumerate(_ level: Level, maxLength: Int) -> Enumeration {
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        var reached: Set<Arrangement> = []
        var firstReached: [Set<Arrangement>] = []
        var frontier: [BinaryGardensPuzzle.Position] = [rules.initialState]
        var anyWin: Bool = false
        var length: Int = 0
        while length <= maxLength {
            var layer: Set<Arrangement> = []
            for position in frontier where !reached.contains(position.arrangement) {
                layer.insert(position.arrangement)
            }
            for arrangement in layer where BinaryGardensSky.report(level, arrangement: arrangement).wins {
                anyWin = true
            }
            reached.formUnion(layer)
            firstReached.append(layer)
            if length == maxLength { break }
            var next: [BinaryGardensPuzzle.Position] = []
            for position in frontier {
                for move in rules.moves(in: position) {
                    if let child = rules.apply(move, to: position) { next.append(child) }
                }
            }
            frontier = next
            length += 1
        }
        return Enumeration(firstReached: firstReached, anyWin: anyWin)
    }

    /// The plain breadth-first sweep in discovery order (no loss order): the first depth with a win, the arrangements
    /// judged at each smaller depth and the smallest loss among them.
    static func plainSweep(_ level: Level, maxDepth: Int) -> (depth: Int?, counts: [Int], nearest: Int) {
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        var seen: Set<Arrangement> = [level.start]
        var layer: [Arrangement] = [level.start]
        var counts: [Int] = []
        var nearest: Int = Int.max
        var depth: Int = 0
        while depth <= maxDepth {
            var won: Bool = false
            var layerNearest: Int = Int.max
            for arrangement in layer {
                let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: arrangement)
                if report.wins {
                    won = true
                } else {
                    layerNearest = min(layerNearest, Solver.loss(level, report: report))
                }
            }
            if won { return (depth, counts, nearest) }
            counts.append(layer.count)
            nearest = min(nearest, layerNearest)
            var next: [Arrangement] = []
            for arrangement in layer {
                let position = BinaryGardensPuzzle.Position(arrangement: arrangement, actionsSpent: depth)
                for move in rules.moves(in: position) {
                    guard let child = rules.apply(move, to: position) else { continue }
                    if seen.insert(child.arrangement).inserted { next.append(child.arrangement) }
                }
            }
            layer = next
            depth += 1
        }
        return (nil, counts, nearest)
    }

    /// Every level under test with its plan depth: the hand cases and the generated levels.
    static func levelsUnderTest() -> [(name: String, level: Level, depth: Int)] {
        var result: [(name: String, level: Level, depth: Int)] = []
        for handCase in handCases { result.append(("hand " + handCase.name, handCase.level, handCase.size)) }
        for item in generated {
            result.append(("level \(item.entry.number)", item.level,
                           BinaryGardensBandProfile.of(band: item.entry.band).plan))
        }
        return result
    }

    // MARK: - Tests

    @Test func fixturesExist() {
        #expect(Self.handCases.count == 4)
        #expect(Self.generated.count == Self.numbers.count)
        #expect(Solver.workBound == 5_000)
    }

    @Test func handLevelsHaveKnownMinima() throws {
        for handCase in Self.handCases {
            let level: Level = handCase.level
            let plan: BinaryGardensPlan = try #require(Solver.plan(level, maxDepth: handCase.size), "\(handCase.name)")
            #expect(plan.size == handCase.size, "\(handCase.name)")
            #expect(plan.actions == handCase.actions, "\(handCase.name)")
            #expect(BinaryGardensSky.report(level, arrangement: plan.arrangement).wins, "\(handCase.name)")
            #expect(Solver.replayWins(level, actions: plan.actions), "\(handCase.name)")
            #expect(plan.arrangementsByDepth.count == plan.size, "\(handCase.name)")
            #expect(plan.arrangementsByDepth.first == 1, "\(handCase.name)")
            let enumeration: Enumeration = Self.enumerate(level, maxLength: plan.size - 1)
            #expect(!enumeration.anyWin, "\(handCase.name) wins with fewer actions")
            // Too shallow a search finds nothing.
            #expect(Solver.plan(level, maxDepth: plan.size - 1) == nil, "\(handCase.name)")
        }
    }

    @Test func theDetourKeepsTheSeparationAtEveryStep() throws {
        let detour: HandCase = try #require(Self.handCases.first { $0.name == "detour" })
        let level: Level = detour.level
        let plan: BinaryGardensPlan = try #require(Solver.plan(level, maxDepth: 3))
        #expect(plan.actions == detour.actions)
        #expect(plan.arrangement == detour.target)
        var arrangement: Arrangement = level.start
        for action in plan.actions {
            arrangement = try BinaryGardensSky.changed(level, arrangement, by: action)
            #expect(BinaryGardensSky.keepsSeparation(level, arrangement: arrangement))
        }
        #expect(arrangement == detour.target)
        // Both direct moves are refused for the separation.
        #expect(throws: BinaryGardensError.action("separation")) {
            try BinaryGardensSky.changed(level, level.start, by: .ring(star: 0, index: 1))
        }
        #expect(throws: BinaryGardensError.action("separation")) {
            try BinaryGardensSky.changed(level, level.start, by: .ring(star: 1, index: 0))
        }
        // The target differs from the start in two controls, yet lies at depth 3; it is the only winner of the nine
        // ring pairs.
        var differing: Int = 0
        for control in BinaryGardensControl.allCases
            where control.value(of: detour.target) != control.value(of: level.start) { differing += 1 }
        #expect(differing == 2)
        var winners: [Arrangement] = []
        for ring1 in 0..<3 {
            for ring2 in 0..<3 {
                let candidate: Arrangement = Self.arrangement([ring1, ring2], [0, 0], [0, 1], 0)
                if BinaryGardensSky.report(level, arrangement: candidate).wins { winners.append(candidate) }
            }
        }
        #expect(winners == [detour.target])
        #expect(plan.arrangementsByDepth == [1, 2, 2])
    }

    @Test func handPlansTakeTheExpectedActions() throws {
        for handCase in Self.handCases {
            #expect(Solver.plan(handCase.level, maxDepth: handCase.size)?.actions == handCase.actions,
                    "\(handCase.name)")
        }
        // Depth 1 of a hand level with every control adjustable: 2 + 5 + 1 per star and 2 tilts.
        let two: BinaryGardensPlan? = Solver.plan(Self.handCases[2].level, maxDepth: 2)
        #expect(two?.arrangementsByDepth == [1, 2 * (2 + 5 + 1) + 2])
    }

    @Test func independentEnumerationReproducesTheCounts() throws {
        for (name, level, depth) in Self.levelsUnderTest() {
            let plan: BinaryGardensPlan = try #require(Solver.plan(level, maxDepth: depth), "\(name)")
            #expect(plan.size == depth, "\(name)")
            let enumeration: Enumeration = Self.enumerate(level, maxLength: plan.size - 1)
            #expect(!enumeration.anyWin, "\(name) is won with fewer actions")
            var counts: [Int] = []
            for layer in enumeration.firstReached { counts.append(layer.count) }
            #expect(counts == plan.arrangementsByDepth, "\(name)")
            // The plan's own sequence goes through the puzzle's moves to a win.
            let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
            var position: BinaryGardensPuzzle.Position = rules.initialState
            for action in plan.actions {
                #expect(rules.moves(in: position).contains(action), "\(name) \(action)")
                position = try #require(rules.apply(action, to: position), "\(name)")
            }
            #expect(position.arrangement == plan.arrangement, "\(name)")
            #expect(rules.isSolved(position), "\(name)")
        }
    }

    @Test func lossOrderChangesOnlyTheWork() throws {
        for (name, level, depth) in Self.levelsUnderTest() {
            let plan: BinaryGardensPlan = try #require(Solver.plan(level, maxDepth: depth), "\(name)")
            let plain: (depth: Int?, counts: [Int], nearest: Int) = Self.plainSweep(level, maxDepth: depth)
            #expect(plain.depth == plan.size, "\(name)")
            #expect(plain.counts == plan.arrangementsByDepth, "\(name)")
            #expect(plain.nearest == plan.nearestMiss, "\(name)")
            let below: Int = plan.arrangementsByDepth.reduce(0, +)
            #expect(plan.work > below, "\(name)")
            let next: Enumeration = Self.enumerate(level, maxLength: plan.size)
            #expect(plan.work <= below + next.firstReached[plan.size].count, "\(name)")
            // The nearest miss is the loss of its arrangement, which lies at a smaller depth.
            let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: plan.nearestMissArrangement)
            #expect(!report.wins, "\(name)")
            #expect(Solver.loss(level, report: report) == plan.nearestMiss, "\(name)")
            var smaller: Bool = false
            for layer in next.firstReached.prefix(plan.size) where layer.contains(plan.nearestMissArrangement) {
                smaller = true
            }
            #expect(smaller, "\(name)")
        }
    }

    @Test func planIsItsParentChainAndReplays() throws {
        for (name, level, depth) in Self.levelsUnderTest() {
            let plan: BinaryGardensPlan = try #require(Solver.plan(level, maxDepth: depth), "\(name)")
            var arrangement: Arrangement = level.start
            for action in plan.actions {
                arrangement = try BinaryGardensSky.changed(level, arrangement, by: action)
            }
            #expect(arrangement == plan.arrangement, "\(name)")
            #expect(BinaryGardensSky.report(level, arrangement: arrangement).wins, "\(name)")
            #expect(Solver.replayWins(level, actions: plan.actions), "\(name)")
            #expect(!Solver.replayWins(level, actions: Array(plan.actions.dropLast())), "\(name)")
            // The solver is deterministic.
            #expect(Solver.plan(level, maxDepth: depth) == plan, "\(name)")
        }
    }

    @Test func workBoundIsRespected() throws {
        for (name, level, depth) in Self.levelsUnderTest() {
            let plan: BinaryGardensPlan = try #require(Solver.plan(level, maxDepth: depth), "\(name)")
            #expect(plan.work <= Solver.workBound, "\(name)")
            #expect(Solver.plan(level, maxDepth: depth, workBound: plan.work - 1) == nil, "\(name)")
            #expect(Solver.plan(level, maxDepth: depth, workBound: plan.work) == plan, "\(name)")
            #expect(Solver.plan(level, maxDepth: depth, workBound: 1) == nil, "\(name)")
            #expect(Solver.plan(level, maxDepth: depth, workBound: 0) == nil, "\(name)")
        }
    }

    @Test func generatedPlansMatchTheirBand() {
        for item in Self.generated {
            let profile: BinaryGardensBandProfile = .of(band: item.entry.band)
            #expect(item.plan.size == profile.plan, "level \(item.entry.number)")
            #expect(item.plan == Solver.plan(item.level, maxDepth: profile.plan), "level \(item.entry.number)")
            #expect(Solver.replayWins(item.level, actions: item.plan.actions), "level \(item.entry.number)")
        }
    }

    @Test func controlsFollowTheFixedOrder() throws {
        let level: Level = Self.handCases[0].level
        #expect(BinaryGardensControl.allCases == [.star1Ring, .star1Phase, .star1Luminosity, .star2Ring, .star2Phase,
                                                  .star2Luminosity, .tilt])
        var raw: [Int] = []
        for control in BinaryGardensControl.allCases { raw.append(control.rawValue) }
        #expect(raw == [0, 1, 2, 3, 4, 5, 6])
        #expect(BinaryGardensControl.star1Ring.values(in: level) == [0, 1, 2])
        #expect(BinaryGardensControl.star2Phase.values(in: level) == [0, 8, 16, 24, 32, 40])
        #expect(BinaryGardensControl.star1Luminosity.values(in: level) == [0, 1])
        #expect(BinaryGardensControl.tilt.values(in: level) == [0, 1, 2])
        let a: Arrangement = Self.arrangement([0, 2], [8, 24], [1, 0], 1)
        var values: [Int] = []
        for control in BinaryGardensControl.allCases { values.append(control.value(of: a)) }
        #expect(values == [0, 8, 1, 2, 24, 0, 1])
        #expect(BinaryGardensControl.star1Ring.action(2) == .ring(star: 0, index: 2))
        #expect(BinaryGardensControl.star1Phase.action(16) == .phase(star: 0, step: 16))
        #expect(BinaryGardensControl.star1Luminosity.action(1) == .luminosity(star: 0, index: 1))
        #expect(BinaryGardensControl.star2Ring.action(0) == .ring(star: 1, index: 0))
        #expect(BinaryGardensControl.star2Phase.action(40) == .phase(star: 1, step: 40))
        #expect(BinaryGardensControl.star2Luminosity.action(1) == .luminosity(star: 1, index: 1))
        #expect(BinaryGardensControl.tilt.action(2) == .tilt(step: 2))
        #expect(BinaryGardensControl.star2Phase.setting(40, in: a) == Self.arrangement([0, 2], [8, 40], [1, 0], 1))
        #expect(BinaryGardensControl.tilt.setting(0, in: a) == Self.arrangement([0, 2], [8, 24], [1, 0], 0))
        // Setting any other legal value is what the kernel's check of the control's action gives.
        for control in BinaryGardensControl.allCases {
            for value in control.values(in: level) where value != control.value(of: a) {
                let set: Arrangement = control.setting(value, in: a)
                #expect(control.value(of: set) == value, "\(control)")
                #expect(try BinaryGardensSky.changed(level, a, by: control.action(value)) == set, "\(control)")
                #expect(BinaryGardensControl.of(control.action(value))?.control == control, "\(control)")
            }
        }
        #expect(BinaryGardensControl.of(.run) == nil)
        let detour: Level = Self.handCases[3].level
        var adjustable: [BinaryGardensControl] = []
        for control in BinaryGardensControl.allCases where control.isAdjustable(in: detour) { adjustable.append(control) }
        #expect(adjustable == [.star1Ring, .star2Ring])
        #expect(BinaryGardensControl.star1Phase.values(in: detour) == [0, 8, 16, 24, 32, 40])
        #expect(BinaryGardensControl.tilt.values(in: detour) == [0])
    }

    @Test func difficultyOfAHandLevel() throws {
        let handCase: HandCase = Self.handCases[2]
        let level: Level = handCase.level
        let plan: BinaryGardensPlan = try #require(Solver.plan(level, maxDepth: 2))
        let difficulty = BinaryGardensDifficulty(level: level, plan: plan)
        #expect(difficulty.actions == 2)
        #expect(difficulty.worlds == 1)
        #expect(difficulty.narrowestBand == level.worlds[0].comfortHigh - level.worlds[0].comfortLow)
        #expect(difficulty.tightestWindow == 48)
        #expect(difficulty.adjustable == 7)
        // Rings 2, phases 5, luminosity 1 per star, tilts 2.
        #expect(difficulty.moveSpace == 2 * (2 + 5 + 1) + 2)
        #expect(difficulty.arrangementsSearched == plan.arrangementsByDepth.reduce(0, +))
        #expect(difficulty.arrangementsSearched == 1 + 18)
        #expect(difficulty.work == plan.work)
        #expect(difficulty.nearestMiss == plan.nearestMiss)
        #expect(difficulty.puzzleDifficulty == PuzzleDifficulty(shortest: 2, explored: plan.work))
        let detour: Level = Self.handCases[3].level
        let detourPlan: BinaryGardensPlan = try #require(Solver.plan(detour, maxDepth: 3))
        let detourDifficulty = BinaryGardensDifficulty(level: detour, plan: detourPlan)
        #expect(detourDifficulty.adjustable == 2)
        #expect(detourDifficulty.moveSpace == 2 + 2)
        #expect(detourDifficulty.actions == 3)
        #expect(detourDifficulty.arrangementsSearched == 5)
    }

    @Test func lossSumsTheThreeParts() throws {
        let handCase: HandCase = Self.handCases[0]
        let level: Level = handCase.level
        let world: BinaryGardensWorld = level.worlds[0]
        #expect(Solver.loss(level, report: BinaryGardensSky.report(level, arrangement: handCase.target)) == 0)
        let report: BinaryGardensReport = level.startReport
        let light: BinaryGardensWorldLight = report.worlds[0]
        var expected: Int = 0
        for flux in light.flux { expected += max(0, world.comfortLow - flux, flux - world.comfortHigh) }
        expected += max(0, world.bloomLow - light.integral, light.integral - world.bloomHigh)
        expected += 1000 * max(0, world.window - light.window)
        #expect(Solver.loss(level, report: report) == expected)
        #expect(expected > 0)
    }
}
