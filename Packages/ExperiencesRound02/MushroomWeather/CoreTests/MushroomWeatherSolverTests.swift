// MushroomWeatherSolverTests — feature 492 (R02-G20-02) T-R02G2002-003 (FR-R02G2002-002; SC-R02G2002-002, 005;
// clarifications Q2, Q5). The certifying solver of Mushroom Weather, on hand levels with known minima (a one-pod plan,
// a vent-toggle plan, a moonlight plan and a two-action plan, each built so that only its target arrangement lands
// every colony in a zero-margin band) and on generated catalog levels of bands 1 … 3 (manifest entries 1, 2, 21 and 41,
// each generated with no previous level and cached per process):
// - known minima: the plan has the expected size, wins through the kernel's play, and no arrangement at a smaller
//   distance wins;
// - an independent breadth-first search over `MushroomWeatherPuzzle` moves (place, move, remove, vent, moonlight via
//   the puzzle's `moves(in:)` and `apply(_:to:)`, never the solver's enumeration), keyed by the set of pod cells, the
//   vent states and the moonlight, reproduces the plan's size as the first depth with a win, `arrangementsByDepth` per
//   depth and the same arrangement sets as `arrangements(_:depth:)`; `distance` agrees with the BFS depth;
// - the loss order changes only the work: a plain fixed-order search over `arrangements(_:depth:)` wins first at the
//   plan's depth with the same per-depth counts and nearest miss;
// - the plan is the first winning arrangement at its depth when that depth is ordered by the parent's band loss
//   (ties in fixed order), and its work is the arrangements below plus its position there;
// - the work bound: nil one arrangement short of the plan's work (and at a bound of 1), the same plan at it;
// - no plan for a level without sites or with a starting pod.
// Plain loops, explicit types, no clock.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherSolverTests {
    typealias Level = MushroomWeatherLevel
    typealias Cell = MushroomWeatherCell
    typealias Arrangement = MushroomWeatherArrangement
    typealias Solver = MushroomWeatherSolver
    typealias Generated = MushroomWeatherGenerated

    // MARK: - Generated levels

    /// The manifest numbers of the generated levels under test: two of band 1, one of band 2, one of band 3.
    static let numbers: [Int] = [1, 2, 21, 41]

    /// The generated levels of ``numbers``, in that order (generated once per process).
    static let generated: [Generated] = {
        var result: [Generated] = []
        for number in numbers {
            let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[number - 1]
            if let level = try? MushroomWeatherGenerator.generate(entry, previous: nil) { result.append(level) }
        }
        return result
    }()

    // MARK: - Hand levels

    /// The cell at `row`, `column`.
    static func cell(_ row: Int, _ column: Int) -> Cell { Cell(row: row, column: column) }

    /// The pod sites of every hand level (none is a colony or blocked).
    static let handSites: [Cell] = [cell(1, 1), cell(1, 3), cell(3, 2), cell(4, 4), cell(5, 0)]

    /// A hand-made 6 × 6 level (cell (0, 5) blocked, humidity 300 and rate 30 on every floor cell, diffusion 6; vents
    /// at (2, 3) and (3, 1), open 180, closed 5; two pod slots; colonies at (2, 2) and (4, 3); 24 cycles, 6 required)
    /// whose colony bands are the exact minimum … maximum of each colony over the last 6 cycles of `target`'s run
    /// (margin 0), so `target` wins and nearly every other arrangement misses. Starts at `start`.
    static func hand(target: Arrangement, start: Arrangement, budget: Int = 6,
                     sites: [Cell]? = handSites) throws(MushroomWeatherError) -> Level {
        let rows: Int = 6, columns: Int = 6, length: Int = 24, required: Int = 6
        let blocked: [Cell] = [cell(0, 5)]
        var humidity: [Int] = Array(repeating: 300, count: rows * columns)
        var rates: [Int] = Array(repeating: 30, count: rows * columns)
        humidity[5] = 0
        rates[5] = 0
        let vents: [MushroomWeatherVent] = [MushroomWeatherVent(cell: cell(2, 3), openRate: 180, closedRate: 5),
                                            MushroomWeatherVent(cell: cell(3, 1), openRate: 180, closedRate: 5)]
        let podRules: MushroomWeatherPodRules = MushroomWeatherPodRules(slots: 2, release: 25, grownRelease: 40,
                                                                        growthThreshold: 800)
        let colonyCells: [Cell] = [cell(2, 2), cell(4, 3)]
        let wide: [MushroomWeatherColony] = colonyCells.map {
            MushroomWeatherColony(cell: $0, low: 0, high: MushroomWeatherForest.maximumMoldBound)
        }
        let probe: Level = try Level.probe(rows: rows, columns: columns, blocked: blocked, humidity: humidity,
                                           diffusion: 6, rates: rates, vents: vents, podRules: podRules,
                                           colonies: wide, moldBound: MushroomWeatherForest.maximumMoldBound,
                                           length: length, required: required, start: target)
        let fields: [[Int]] = MushroomWeatherForest.run(probe, arrangement: target, keepFields: true).fields
        var highest: Int = 0
        for field in fields {
            for value in field { highest = max(highest, value) }
        }
        var colonies: [MushroomWeatherColony] = []
        for colonyCell in colonyCells {
            let i: Int = probe.index(of: colonyCell)
            var low: Int = Int.max, high: Int = 0
            for (cycle, field) in fields.enumerated() where cycle > length - required {
                low = min(low, field[i])
                high = max(high, field[i])
            }
            colonies.append(MushroomWeatherColony(cell: colonyCell, low: low, high: high))
        }
        return try Level(id: "solver-hand", seed: 0, difficulty: 1, rows: rows, columns: columns, blocked: blocked,
                         humidity: humidity, diffusion: 6, rates: rates, vents: vents, podRules: podRules,
                         colonies: colonies, moldBound: max(1000, highest + 50), length: length, required: required,
                         start: start, budget: budget, sites: sites)
    }

    /// The common start of the hand levels: no pod, both vents closed, moonlight 0.
    static let handStart: Arrangement = Arrangement(pods: [nil, nil], ventsOpen: [false, false], moonlight: 0)

    /// A hand case: a name, its level and the size of its minimal plan.
    struct HandCase: Sendable {
        /// The case's name.
        let name: String
        /// The level.
        let level: Level
        /// The size of the level's minimal plan.
        let size: Int
    }

    /// The hand cases: one pod, one vent toggle, one moonlight change, and a pod plus a vent toggle.
    static let handCases: [HandCase] = {
        let targets: [(String, Arrangement, Int)] = [
            ("one pod", Arrangement(pods: [cell(1, 3), nil], ventsOpen: [false, false], moonlight: 0), 1),
            ("vent", Arrangement(pods: [nil, nil], ventsOpen: [true, false], moonlight: 0), 1),
            ("moonlight", Arrangement(pods: [nil, nil], ventsOpen: [false, false], moonlight: 3), 1),
            ("two actions", Arrangement(pods: [cell(3, 2), nil], ventsOpen: [false, true], moonlight: 0), 2),
        ]
        var result: [HandCase] = []
        for (name, target, size) in targets {
            if let level = try? hand(target: target, start: handStart) {
                result.append(HandCase(name: name, level: level, size: size))
            }
        }
        return result
    }()

    // MARK: - Independent search

    /// An arrangement up to slot order: the pod cells (ascending), the vent states and the moonlight.
    struct Key: Hashable, Sendable {
        /// The pod cells, ascending.
        let pods: [Cell]
        /// The vent states.
        let vents: [Bool]
        /// The moonlight.
        let moonlight: Int

        /// The key of `arrangement`.
        init(_ arrangement: Arrangement) {
            pods = arrangement.placedPods.sorted()
            vents = arrangement.ventsOpen
            moonlight = arrangement.moonlight
        }
    }

    /// The result of the independent breadth-first search.
    struct Search: Sendable {
        /// The keys first reached at each depth 0 … the deepest searched, with a representative arrangement.
        let layers: [[Key: Arrangement]]
        /// The first depth whose layer holds a winning arrangement, or nil.
        let winDepth: Int?
    }

    /// A breadth-first search over the puzzle's moves from the start, up to `maxDepth` actions, keyed by ``Key``: a
    /// layer holds the keys not reached at a smaller depth; the frontier is every position of a new key.
    static func search(_ level: Level, maxDepth: Int) -> Search {
        let rules: MushroomWeatherPuzzle = MushroomWeatherPuzzle(level: level)
        let start: MushroomWeatherPuzzle.Position = rules.initialState
        var seen: Set<Key> = [Key(start.arrangement)]
        var layers: [[Key: Arrangement]] = [[Key(start.arrangement): start.arrangement]]
        var winDepth: Int? = rules.isSolved(start) ? 0 : nil
        var frontier: [MushroomWeatherPuzzle.Position] = [start]
        var depth: Int = 0
        while depth < maxDepth && !frontier.isEmpty {
            depth += 1
            var layer: [Key: Arrangement] = [:]
            var next: [MushroomWeatherPuzzle.Position] = []
            var expanded: Set<Arrangement> = []
            for position in frontier {
                for move in rules.moves(in: position) {
                    guard let child = rules.apply(move, to: position) else { continue }
                    let key: Key = Key(child.arrangement)
                    if seen.contains(key) { continue }
                    if layer[key] == nil { layer[key] = child.arrangement }
                    if expanded.insert(child.arrangement).inserted { next.append(child) }
                }
            }
            for (key, arrangement) in layer {
                seen.insert(key)
                if winDepth == nil, rules.isSolved(MushroomWeatherPuzzle.Position(arrangement: arrangement,
                                                                                   actionsSpent: depth)) {
                    winDepth = depth
                }
            }
            layers.append(layer)
            frontier = next
        }
        return Search(layers: layers, winDepth: winDepth)
    }

    /// Whether `arrangement` wins `level` (the kernel's predicted report).
    static func wins(_ level: Level, _ arrangement: Arrangement) -> Bool {
        MushroomWeatherForest.report(level, arrangement: arrangement).wins
    }

    /// Every level under test with its plan: the hand cases and the generated levels.
    static func levelsUnderTest() -> [(String, Level)] {
        var result: [(String, Level)] = []
        for handCase in handCases { result.append(("hand " + handCase.name, handCase.level)) }
        for item in generated { result.append(("level \(item.entry.number)", item.level)) }
        return result
    }

    // MARK: - Tests

    @Test func fixturesExist() {
        #expect(Self.handCases.count == 4)
        #expect(Self.generated.count == Self.numbers.count)
    }

    @Test func handLevelsHaveKnownMinima() throws {
        for handCase in Self.handCases {
            let level: Level = handCase.level
            let plan: MushroomWeatherPlan = try #require(Solver.plan(level), "\(handCase.name)")
            #expect(plan.size == handCase.size, "\(handCase.name)")
            #expect(Solver.replayWins(level, actions: plan.actions), "\(handCase.name)")
            #expect(Self.wins(level, plan.arrangement), "\(handCase.name)")
            #expect(Solver.distance(plan.arrangement, from: level.start) == plan.size, "\(handCase.name)")
            for depth in 0..<plan.size {
                for arrangement in Solver.arrangements(level, depth: depth) {
                    #expect(!Self.wins(level, arrangement), "\(handCase.name) depth \(depth)")
                }
            }
            #expect(plan.arrangementsByDepth.count == plan.size, "\(handCase.name)")
            #expect(plan.arrangementsByDepth.first == 1, "\(handCase.name)")
        }
    }

    @Test func handPlansTakeTheExpectedActions() throws {
        var plans: [String: MushroomWeatherPlan] = [:]
        for handCase in Self.handCases { plans[handCase.name] = Solver.plan(handCase.level) }
        #expect(plans["one pod"]?.actions == [.place(slot: 0, cell: Self.cell(1, 3))])
        #expect(plans["vent"]?.actions == [.vent(index: 0, open: true)])
        #expect(plans["moonlight"]?.actions == [.moonlight(level: 3)])
        #expect(plans["two actions"]?.actions == [.place(slot: 0, cell: Self.cell(3, 2)), .vent(index: 1, open: true)])
        // A depth-1 hand level judges 1 arrangement at depth 0; the depth-1 count is sites + vents + 3 moonlights.
        #expect(plans["two actions"]?.arrangementsByDepth == [1, 5 + 2 + 3])
    }

    @Test func independentSearchReproducesTheCounts() throws {
        for (name, level) in Self.levelsUnderTest() {
            let plan: MushroomWeatherPlan = try #require(Solver.plan(level), "\(name)")
            let search: Search = Self.search(level, maxDepth: plan.size)
            #expect(search.winDepth == plan.size, "\(name)")
            #expect(search.layers.count == plan.size + 1, "\(name)")
            var counts: [Int] = []
            for depth in 0..<plan.size { counts.append(search.layers[depth].count) }
            #expect(counts == plan.arrangementsByDepth, "\(name)")
            for depth in 0...plan.size {
                let listed: [Arrangement] = Solver.arrangements(level, depth: depth)
                let keys: Set<Key> = Set(listed.map { Key($0) })
                #expect(keys.count == listed.count, "\(name) depth \(depth) duplicates")
                #expect(keys == Set(search.layers[depth].keys), "\(name) depth \(depth)")
            }
        }
    }

    @Test func distanceAgreesWithSearchDepth() throws {
        for (name, level) in Self.levelsUnderTest() {
            let plan: MushroomWeatherPlan = try #require(Solver.plan(level), "\(name)")
            let search: Search = Self.search(level, maxDepth: plan.size)
            for (depth, layer) in search.layers.enumerated() {
                for arrangement in layer.values {
                    #expect(Solver.distance(arrangement, from: level.start) == depth, "\(name) depth \(depth)")
                }
            }
        }
    }

    @Test func lossOrderChangesOnlyTheWork() throws {
        for (name, level) in Self.levelsUnderTest() {
            let plan: MushroomWeatherPlan = try #require(Solver.plan(level), "\(name)")
            var counts: [Int] = []
            var nearest: Int = Int.max
            var winDepth: Int?
            var depth: Int = 0
            while winDepth == nil && depth <= level.budget {
                let listed: [Arrangement] = Solver.arrangements(level, depth: depth)
                var won: Bool = false
                var depthNearest: Int = Int.max
                for arrangement in listed {
                    let report: MushroomWeatherReport = MushroomWeatherForest.report(level, arrangement: arrangement)
                    if report.wins {
                        won = true
                    } else {
                        depthNearest = min(depthNearest, Solver.loss(level, report: report))
                    }
                }
                // The nearest miss counts only the depths below the first win (clarification Q2).
                if won {
                    winDepth = depth
                } else {
                    counts.append(listed.count)
                    nearest = min(nearest, depthNearest)
                }
                depth += 1
            }
            #expect(winDepth == plan.size, "\(name)")
            #expect(counts == plan.arrangementsByDepth, "\(name)")
            #expect(nearest == plan.nearestMiss, "\(name)")
            let below: Int = counts.reduce(0, +)
            #expect(plan.work > below, "\(name)")
            #expect(plan.work <= below + Solver.arrangements(level, depth: plan.size).count, "\(name)")
        }
    }

    @Test func planIsTheFirstWinnerInSearchOrder() throws {
        for (name, level) in Self.levelsUnderTest() {
            let plan: MushroomWeatherPlan = try #require(Solver.plan(level), "\(name)")
            let choices: [Solver.Choice] = Solver.choices(level, depth: plan.size)
            var keys: [Int] = []
            for choice in choices {
                let parent: Arrangement = Solver.arrangement(level, choice.parent)
                let report: MushroomWeatherReport = MushroomWeatherForest.report(level, arrangement: parent)
                keys.append(report.wins ? Int.max : Solver.loss(level, report: report))
            }
            let order: [Int] = choices.indices.sorted { (keys[$0], $0) < (keys[$1], $1) }
            var first: Int?
            for (position, index) in order.enumerated()
                where Self.wins(level, Solver.arrangement(level, choices[index])) {
                first = position
                #expect(Solver.arrangement(level, choices[index]) == plan.arrangement, "\(name)")
                break
            }
            let position: Int = try #require(first, "\(name)")
            #expect(plan.work == plan.arrangementsByDepth.reduce(0, +) + position + 1, "\(name)")
        }
    }

    @Test func workBoundIsRespected() throws {
        for (name, level) in Self.levelsUnderTest() {
            let plan: MushroomWeatherPlan = try #require(Solver.plan(level), "\(name)")
            #expect(plan.work <= Solver.workBound, "\(name)")
            #expect(Solver.plan(level, workBound: plan.work - 1) == nil, "\(name)")
            #expect(Solver.plan(level, workBound: plan.work) == plan, "\(name)")
            #expect(Solver.plan(level, workBound: 1) == nil, "\(name)")
        }
        #expect(Solver.workBound == 1_500)
    }

    @Test func generatedPlansMatchTheirBand() {
        for item in Self.generated {
            let profile: MushroomWeatherBandProfile = .of(band: item.entry.band)
            #expect(item.plan.size == profile.plan, "level \(item.entry.number)")
            #expect(item.plan == Solver.plan(item.level), "level \(item.entry.number)")
            #expect(Solver.replayWins(item.level, actions: item.plan.actions), "level \(item.entry.number)")
        }
    }

    @Test func levelsWithoutSitesOrWithAStartingPodHaveNoPlan() throws {
        let target: Arrangement = Arrangement(pods: [Self.cell(1, 3), nil], ventsOpen: [false, false], moonlight: 0)
        let unsited: Level = try Self.hand(target: target, start: Self.handStart, sites: nil)
        #expect(unsited.sites == nil)
        #expect(Solver.plan(unsited) == nil)
        #expect(Solver.arrangements(unsited, depth: 1).isEmpty)
        let podded: Arrangement = Arrangement(pods: [nil, Self.cell(5, 0)], ventsOpen: [false, false], moonlight: 0)
        let started: Level = try Self.hand(target: target, start: podded)
        #expect(Solver.plan(started) == nil)
        for item in Self.generated where !item.level.start.placedPods.isEmpty {
            Issue.record("level \(item.entry.number) starts with a pod")
        }
    }
}
