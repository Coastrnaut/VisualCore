// MyceliumArchitectGrowthTests — feature 511 (R02-G22-01) T-R02G2201-003 (FR-R02G2201-003 … 006, 015; SC-R02G2201-003,
// 004). An independent reimplementation of the growth, written from the specification's clarifications only (the field
// Σ s · max(0, R − Chebyshev distance) over unconsumed nutrients; admissibility: on the board, not a rock or blocker, not
// grown, no corner cut between two orthogonal obstacles, toxins admissible; the score (f(t) − f(c)) − κ·turn − ο·obs(t)
// with obs counting rocks, blockers and off-board cells among t's eight neighbours; ties to the smaller turn, then the
// lower direction number; dormant when nothing is admissible or the best score is below 0; tips in ascending number,
// tips born in a pulse first moving in the next; seeds start tips at the root in ascending direction; a consumed
// nutrient spawns a tip heading (k + 2) mod 8; weights 2 and 3; starved before a step, toxic after, then unreached
// (the lowest terminal) and overweight), compared with the kernel on 500 seeded runs (fixtures of seed 2,511 with their
// winning arrangements, random arrangements on them and random variations of their numbers): every field value, step,
// grown cell, pulse, parent, weight, terminal pulse and path weight, failure and the win equal, and no network exceeds
// 2048 nodes. Hand cases: a branch weight one unit either side of the budget and of the limit, a toxin one cell either
// side of a tip's path, a terminal one cell beyond the network, a starved step onto a toxin, ties by turn then direction,
// a refused corner cut, a negative best score, a consumed nutrient that no longer pulls, two tips competing for one cell
// and growth ending early. Explicit types, plain loops; each test well under 10 s.
import Foundation
import XCTest
import VisualCoreSimulation
@testable import MyceliumArchitectCore

/// One step of the independent reference.
struct MyceliumArchitectReferenceStep: Equatable {
    /// The pulse.
    let pulse: Int
    /// The tip, 0-based.
    let tip: Int
    /// The cell left.
    let from: MyceliumArchitectCell
    /// The direction number, 0 … 7.
    let direction: Int
    /// The cell grown.
    let to: MyceliumArchitectCell
    /// The winning score.
    let score: Int
    /// The segment weight.
    let weight: Int
    /// Whether a nutrient was consumed.
    let consumed: Bool
    /// The tip born, or nil.
    let newTip: Int?
}

/// The result of the independent reference.
struct MyceliumArchitectReferenceRun {
    /// The field before growth, [row][column].
    var field: [[Int]] = []
    /// Every step.
    var steps: [MyceliumArchitectReferenceStep] = []
    /// The grown cells, the root first.
    var grown: [MyceliumArchitectCell] = []
    /// The pulse of each grown cell (root 0).
    var grownPulses: [Int] = []
    /// The parent index of each grown cell (root nil).
    var parents: [Int?] = []
    /// The total branch weight.
    var totalWeight: Int = 0
    /// The pulses started with a growing tip.
    var pulsesRun: Int = 0
    /// Each terminal's reach pulse.
    var terminalPulses: [Int?] = []
    /// Each terminal's path weight.
    var terminalPathWeights: [Int?] = []
    /// The failure, or nil when won.
    var failure: MyceliumArchitectFailure?
}

/// The independent reference of the growth, written from the clarifications only.
enum MyceliumArchitectReference {
    /// Column change per direction, clockwise from north.
    static let dc: [Int] = [0, 1, 1, 1, 0, -1, -1, -1]
    /// Row change per direction, clockwise from north.
    static let dr: [Int] = [-1, -1, 0, 1, 1, 1, 0, -1]

    /// A tip of the reference.
    struct Tip {
        /// The column.
        var column: Int
        /// The row.
        var row: Int
        /// The heading, 0 … 7.
        var heading: Int
        /// Whether it is still growing.
        var growing: Bool
    }

    /// The nutrient value at (column, row).
    static func value(_ column: Int, _ row: Int, nutrients: [MyceliumArchitectCell], strength: Int, reach: Int) -> Int {
        var sum: Int = 0
        for n in nutrients {
            let a: Int = abs(column - n.column)
            let b: Int = abs(row - n.row)
            let d: Int = a > b ? a : b
            let r: Int = reach - d
            if r > 0 { sum += strength * r }
        }
        return sum
    }

    /// The reference run of `arrangement` on `level`.
    static func run(_ level: MyceliumArchitectLevel, _ arrangement: MyceliumArchitectArrangement)
        -> MyceliumArchitectReferenceRun {
        let width: Int = level.width
        let height: Int = level.height
        var walls: Set<MyceliumArchitectCell> = Set(level.rocks)
        for b in arrangement.blockers { walls.insert(b) }
        let poison: Set<MyceliumArchitectCell> = Set(level.toxins)
        var food: [MyceliumArchitectCell] = level.fixedNutrients
        for n in arrangement.nutrients { food.append(n) }

        func isObstacle(_ column: Int, _ row: Int) -> Bool {
            if column < 0 || row < 0 || column >= width || row >= height { return true }
            return walls.contains(MyceliumArchitectCell(column: column, row: row))
        }

        var out = MyceliumArchitectReferenceRun()
        for row in 0..<height {
            var line: [Int] = []
            for column in 0..<width {
                line.append(value(column, row, nutrients: food, strength: level.strength, reach: level.reach))
            }
            out.field.append(line)
        }
        var where_: [MyceliumArchitectCell: Int] = [level.root: 0]
        var pathWeight: [Int] = [0]
        out.grown = [level.root]
        out.grownPulses = [0]
        out.parents = [nil]
        out.terminalPulses = [Int?](repeating: nil, count: level.terminals.count)
        out.terminalPathWeights = [Int?](repeating: nil, count: level.terminals.count)
        var tips: [Tip] = []
        var seeds: [Int] = []
        for s in arrangement.seeds { seeds.append(s.rawValue) }
        seeds.sort()
        for s in seeds { tips.append(Tip(column: level.root.column, row: level.root.row, heading: s, growing: true)) }

        var pulse: Int = 1
        var stopped: Bool = false
        while pulse <= level.pulses && !stopped {
            var anyGrowing: Bool = false
            for tip in tips where tip.growing { anyGrowing = true }
            if !anyGrowing { break }
            out.pulsesRun = pulse
            let count: Int = tips.count
            var t: Int = 0
            while t < count && !stopped {
                if !tips[t].growing {
                    t += 1
                    continue
                }
                let c0: Int = tips[t].column
                let r0: Int = tips[t].row
                let h: Int = tips[t].heading
                let here: Int = value(c0, r0, nutrients: food, strength: level.strength, reach: level.reach)
                var bestK: Int = -1
                var bestScore: Int = 0
                var bestTurn: Int = 0
                for k in 0..<8 {
                    let c1: Int = c0 + dc[k]
                    let r1: Int = r0 + dr[k]
                    if isObstacle(c1, r1) { continue }
                    if where_[MyceliumArchitectCell(column: c1, row: r1)] != nil { continue }
                    if dc[k] != 0 && dr[k] != 0 && isObstacle(c1, r0) && isObstacle(c0, r1) { continue }
                    let diff: Int = abs(k - h)
                    let turn: Int = diff < 8 - diff ? diff : 8 - diff
                    var obs: Int = 0
                    for j in 0..<8 where isObstacle(c1 + dc[j], r1 + dr[j]) { obs += 1 }
                    let gain: Int = value(c1, r1, nutrients: food, strength: level.strength, reach: level.reach) - here
                    let score: Int = gain - level.curvature * turn - level.obstacle * obs
                    var better: Bool = false
                    if bestK < 0 {
                        better = true
                    } else if score > bestScore {
                        better = true
                    } else if score == bestScore && turn < bestTurn {
                        better = true
                    } else if score == bestScore && turn == bestTurn && k < bestK {
                        better = true
                    }
                    if better {
                        bestK = k
                        bestScore = score
                        bestTurn = turn
                    }
                }
                if bestK < 0 || bestScore < 0 {
                    tips[t].growing = false
                    t += 1
                    continue
                }
                let c1: Int = c0 + dc[bestK]
                let r1: Int = r0 + dr[bestK]
                let target = MyceliumArchitectCell(column: c1, row: r1)
                let w: Int = bestK % 2 == 0 ? 2 : 3
                if out.totalWeight + w > level.nutrientBudget {
                    out.failure = .starved(pulse: pulse, tip: t, cell: target, weight: out.totalWeight + w,
                                           budget: level.nutrientBudget)
                    stopped = true
                    break
                }
                out.totalWeight += w
                let parent: Int = where_[MyceliumArchitectCell(column: c0, row: r0)]!
                where_[target] = out.grown.count
                out.grown.append(target)
                out.grownPulses.append(pulse)
                out.parents.append(parent)
                pathWeight.append(pathWeight[parent] + w)
                tips[t].column = c1
                tips[t].row = r1
                tips[t].heading = bestK
                var consumed: Bool = false
                var born: Int?
                var i: Int = 0
                while i < food.count {
                    if food[i] == target {
                        food.remove(at: i)
                        consumed = true
                        break
                    }
                    i += 1
                }
                if consumed {
                    born = tips.count
                    tips.append(Tip(column: c1, row: r1, heading: (bestK + 2) % 8, growing: true))
                }
                out.steps.append(MyceliumArchitectReferenceStep(
                    pulse: pulse, tip: t, from: MyceliumArchitectCell(column: c0, row: r0), direction: bestK,
                    to: target, score: bestScore, weight: w, consumed: consumed, newTip: born))
                for (m, terminal) in level.terminals.enumerated() where terminal == target {
                    out.terminalPulses[m] = pulse
                    out.terminalPathWeights[m] = pathWeight[pathWeight.count - 1]
                }
                if poison.contains(target) {
                    out.failure = .toxic(pulse: pulse, tip: t, cell: target)
                    stopped = true
                    break
                }
                t += 1
            }
            pulse += 1
        }
        if out.failure == nil {
            for m in 0..<out.terminalPulses.count where out.terminalPulses[m] == nil {
                out.failure = .unreached(terminal: m)
                break
            }
        }
        if out.failure == nil && out.totalWeight > level.weightLimit {
            out.failure = .overweight(weight: out.totalWeight, limit: level.weightLimit)
        }
        return out
    }
}

/// Growth tests of Mycelium Architect: the 500-run reference comparison and the hand cases.
final class MyceliumArchitectGrowthTests: XCTestCase {
    /// Shorthand for a cell.
    typealias Cell = MyceliumArchitectCell
    /// Shorthand for a direction.
    typealias Direction = MyceliumArchitectDirection

    /// A hand level (probe: it may already win): `width` × `height`, the root and the rest as given.
    static func hand(root: Cell = Cell(column: 1, row: 2), terminals: [Cell] = [Cell(column: 7, row: 2)],
                     rocks: [Cell] = [], toxins: [Cell] = [], fixed: [Cell] = [], strength: Int = 1, reach: Int = 4,
                     curvature: Int = 1, obstacle: Int = 0, pulses: Int = 16, nutrientBudget: Int = 4094,
                     weightLimit: Int = 4094, width: Int = 9, height: Int = 5) throws -> MyceliumArchitectLevel {
        try MyceliumArchitectLevel(id: "hand", seed: 1, difficulty: 1, width: width, height: height, root: root,
                                   terminals: terminals, rocks: rocks, toxins: toxins, fixedNutrients: fixed,
                                   strength: strength, reach: reach, curvature: curvature, obstacle: obstacle,
                                   maxNutrients: 3, maxBlockers: 3, maxSeeds: 4, startSeeds: [], pulses: pulses,
                                   nutrientBudget: nutrientBudget, weightLimit: weightLimit, budget: 8,
                                   tutorial: false, refusingAWin: false)
    }

    /// An arrangement of these items.
    static func arrangement(nutrients: [Cell] = [], blockers: [Cell] = [],
                            seeds: [Direction]) -> MyceliumArchitectArrangement {
        MyceliumArchitectArrangement(nutrients: nutrients, blockers: blockers, seeds: seeds)
    }

    /// The differences between the kernel's report and the reference run, in words (empty when equal).
    static func differences(_ report: MyceliumArchitectReport, _ ref: MyceliumArchitectReferenceRun) -> [String] {
        var out: [String] = []
        if report.field != ref.field { out.append("field") }
        if report.steps.count != ref.steps.count {
            out.append("step count \(report.steps.count) vs \(ref.steps.count)")
        } else {
            for i in 0..<report.steps.count {
                let a: MyceliumArchitectStep = report.steps[i]
                let b: MyceliumArchitectReferenceStep = ref.steps[i]
                let same: Bool = a.pulse == b.pulse && a.tip == b.tip && a.from == b.from
                    && a.direction.rawValue == b.direction && a.to == b.to && a.score == b.score
                    && a.weight == b.weight && a.consumed == b.consumed && a.newTip == b.newTip
                if !same {
                    out.append("step \(i): \(a) vs \(b)")
                    break
                }
            }
        }
        if report.grown != ref.grown { out.append("grown") }
        if report.grownPulses != ref.grownPulses { out.append("grown pulses") }
        if report.parents != ref.parents { out.append("parents") }
        if report.totalWeight != ref.totalWeight { out.append("total \(report.totalWeight) vs \(ref.totalWeight)") }
        if report.pulsesRun != ref.pulsesRun { out.append("pulses run \(report.pulsesRun) vs \(ref.pulsesRun)") }
        if report.terminalPulses != ref.terminalPulses { out.append("terminal pulses") }
        if report.terminalPathWeights != ref.terminalPathWeights { out.append("terminal path weights") }
        if report.failure != ref.failure { out.append("failure \(String(describing: report.failure)) vs "
                                                      + "\(String(describing: ref.failure))") }
        if report.wins != (ref.failure == nil) { out.append("wins") }
        if report.nodeCount > MyceliumArchitectGrowth.nodeCap { out.append("node count \(report.nodeCount)") }
        return out
    }

    /// A random arrangement on `level`: 0 … 4 distinct seeds and 0 … 6 nutrients and blockers on empty cells.
    static func randomArrangement(_ level: MyceliumArchitectLevel,
                                  _ random: inout SeededRandom) -> MyceliumArchitectArrangement {
        var seeds: [Direction] = []
        let seedCount: Int = random.int(0...4)
        while seeds.count < seedCount {
            let d: Direction = Direction(rawValue: random.int(0...7))!
            if !seeds.contains(d) { seeds.append(d) }
        }
        var nutrients: [Cell] = []
        var blockers: [Cell] = []
        let nutrientCount: Int = random.int(0...6)
        let blockerCount: Int = random.int(0...6)
        for kind in 0..<2 {
            let wanted: Int = kind == 0 ? nutrientCount : blockerCount
            var tries: Int = 0
            var placed: Int = 0
            while placed < wanted && tries < 64 {
                tries += 1
                let cell = Cell(column: random.int(0...(level.width - 1)), row: random.int(0...(level.height - 1)))
                let sofar = MyceliumArchitectArrangement(nutrients: nutrients, blockers: blockers, seeds: seeds)
                if !level.isEmpty(cell, in: sofar) { continue }
                if kind == 0 { nutrients.append(cell) } else { blockers.append(cell) }
                placed += 1
            }
        }
        return MyceliumArchitectArrangement(nutrients: nutrients, blockers: blockers, seeds: seeds)
    }

    /// `level` with randomly varied numbers: strength, reach, penalties, pulses, budget and limit.
    static func varied(_ level: MyceliumArchitectLevel, _ random: inout SeededRandom) -> MyceliumArchitectLevel? {
        let budget: Int = random.int(0...3) == 0 ? 4094 : random.int(2...60)
        let limit: Int = random.int(2...budget)
        return try? MyceliumArchitectLevel(
            id: "varied", seed: level.seed, difficulty: level.difficulty, width: level.width, height: level.height,
            root: level.root, terminals: level.terminals, rocks: level.rocks, toxins: level.toxins,
            fixedNutrients: level.fixedNutrients, strength: random.int(1...8), reach: random.int(1...16),
            curvature: random.int(0...8), obstacle: random.int(0...8), maxNutrients: level.maxNutrients,
            maxBlockers: level.maxBlockers, maxSeeds: level.maxSeeds, startSeeds: level.startSeeds,
            pulses: random.int(1...128), nutrientBudget: budget, weightLimit: limit, budget: level.budget,
            tutorial: level.tutorial, refusingAWin: false)
    }

    // MARK: SC-R02G2201-003 — 500 seeded runs against the reference

    /// Over 500 seeded runs every field value, step, grown cell, pulse, parent, weight, terminal, failure and the win
    /// equal the independent reference, and no network exceeds 2048 nodes.
    func testFiveHundredSeededRunsEqualTheIndependentReference() {
        let fixtures: [MyceliumArchitectFixture] = MyceliumArchitectFixture.all(count: 100)
        var random = SeededRandom(seed: 2_511 &* 7 &+ 3)
        var runs: Int = 0
        var mismatches: [String] = []
        var codes: [String: Int] = [:]
        var index: Int = 0
        while runs < 500 {
            let fixture: MyceliumArchitectFixture = fixtures[index % fixtures.count]
            let mode: Int = index % 5
            index += 1
            var level: MyceliumArchitectLevel = fixture.level
            var arrangement: MyceliumArchitectArrangement = fixture.winning
            if mode == 1 || mode == 2 {
                arrangement = Self.randomArrangement(level, &random)
            } else if mode >= 3 {
                guard let v = Self.varied(level, &random) else { continue }
                level = v
                arrangement = mode == 3 ? fixture.winning : Self.randomArrangement(level, &random)
            }
            let report: MyceliumArchitectReport = MyceliumArchitectGrowth.report(level, arrangement: arrangement)
            let ref: MyceliumArchitectReferenceRun = MyceliumArchitectReference.run(level, arrangement)
            let diffs: [String] = Self.differences(report, ref)
            if !diffs.isEmpty && mismatches.count < 5 {
                mismatches.append("run \(runs) (\(level.id), mode \(mode)): " + diffs.joined(separator: "; "))
            }
            if mode == 0 { XCTAssertTrue(report.wins, "fixture \(fixture.level.id) wins with its arrangement") }
            let code: String = report.failure?.code ?? "won"
            codes[code, default: 0] += 1
            runs += 1
        }
        XCTAssertEqual(mismatches, [], "kernel and reference disagree")
        for code in ["won", "toxic", "starved", "unreached", "overweight"] {
            XCTAssertGreaterThan(codes[code, default: 0], 0, "the 500 runs include \(code)")
        }
    }

    // MARK: SC-R02G2201-004 — hand cases

    /// A flat field, one tip east from (1, 2): seven steps of weight 2 to (8, 2), 14 in all; a budget of 13 starves the
    /// last step, 14 and 15 grow it; a limit of 13 is overweight, 14 and 15 win.
    func testBranchWeightOneUnitEitherSideOfTheBudgetAndTheLimit() throws {
        let east = Self.arrangement(seeds: [.east])
        let below = MyceliumArchitectGrowth.report(try Self.hand(nutrientBudget: 13, weightLimit: 13), arrangement: east)
        XCTAssertEqual(below.failure, .starved(pulse: 7, tip: 0, cell: Cell(column: 8, row: 2), weight: 14, budget: 13))
        XCTAssertEqual(below.grown.count, 7, "nothing is grown on the starved step")
        XCTAssertEqual(below.totalWeight, 12)
        let at = MyceliumArchitectGrowth.report(try Self.hand(nutrientBudget: 14, weightLimit: 14), arrangement: east)
        XCTAssertNil(at.failure)
        XCTAssertEqual(at.totalWeight, 14)
        let above = MyceliumArchitectGrowth.report(try Self.hand(nutrientBudget: 15, weightLimit: 15), arrangement: east)
        XCTAssertNil(above.failure)
        let over = MyceliumArchitectGrowth.report(try Self.hand(nutrientBudget: 15, weightLimit: 13), arrangement: east)
        XCTAssertEqual(over.failure, .overweight(weight: 14, limit: 13))
        let limitAt = MyceliumArchitectGrowth.report(try Self.hand(nutrientBudget: 15, weightLimit: 14),
                                                     arrangement: east)
        XCTAssertNil(limitAt.failure)
    }

    /// A toxin on the path at (5, 2) fails `toxic` at pulse 4; a toxin one cell beside the path, or one cell beyond its
    /// end, is never entered.
    func testAToxinOneCellEitherSideOfATipsPath() throws {
        let east = Self.arrangement(seeds: [.east])
        let on = MyceliumArchitectGrowth.report(try Self.hand(toxins: [Cell(column: 5, row: 2)]), arrangement: east)
        XCTAssertEqual(on.failure, .toxic(pulse: 4, tip: 0, cell: Cell(column: 5, row: 2)))
        XCTAssertEqual(on.grown.last, Cell(column: 5, row: 2), "the toxic step is grown")
        let north = MyceliumArchitectGrowth.report(try Self.hand(toxins: [Cell(column: 5, row: 1)]), arrangement: east)
        XCTAssertNil(north.failure)
        let south = MyceliumArchitectGrowth.report(try Self.hand(toxins: [Cell(column: 5, row: 3)]), arrangement: east)
        XCTAssertNil(south.failure)
        let beyond = MyceliumArchitectGrowth.report(try Self.hand(toxins: [Cell(column: 8, row: 2)], pulses: 6),
                                                    arrangement: east)
        XCTAssertNil(beyond.failure, "six pulses grow to (7, 2); the toxin at (8, 2) is one cell beyond")
        let reached = MyceliumArchitectGrowth.report(try Self.hand(toxins: [Cell(column: 8, row: 2)], pulses: 7),
                                                     arrangement: east)
        XCTAssertEqual(reached.failure, .toxic(pulse: 7, tip: 0, cell: Cell(column: 8, row: 2)))
    }

    /// Five pulses grow to (6, 2): a terminal at (7, 2) is one cell beyond and fails `unreached`; at (6, 2) it is
    /// reached at pulse 5 with path weight 10.
    func testATerminalOneCellBeyondTheNetwork() throws {
        let east = Self.arrangement(seeds: [.east])
        let beyond = MyceliumArchitectGrowth.report(try Self.hand(pulses: 5), arrangement: east)
        XCTAssertEqual(beyond.failure, .unreached(terminal: 0))
        XCTAssertEqual(beyond.grown.last, Cell(column: 6, row: 2))
        XCTAssertEqual(beyond.terminalPulses, [nil])
        let at = MyceliumArchitectGrowth.report(try Self.hand(terminals: [Cell(column: 6, row: 2)], pulses: 5),
                                                arrangement: east)
        XCTAssertNil(at.failure)
        XCTAssertEqual(at.terminalPulses, [5])
        XCTAssertEqual(at.terminalPathWeights, [10])
        let two = MyceliumArchitectGrowth.report(
            try Self.hand(terminals: [Cell(column: 4, row: 2), Cell(column: 7, row: 2), Cell(column: 8, row: 2)],
                          pulses: 5), arrangement: east)
        XCTAssertEqual(two.failure, .unreached(terminal: 1), "the lowest-numbered unreached terminal")
    }

    /// A step onto a toxin that would exceed the budget fails `starved` (checked first), not `toxic`.
    func testAStarvedStepOntoAToxinIsStarved() throws {
        let east = Self.arrangement(seeds: [.east])
        let starved = MyceliumArchitectGrowth.report(try Self.hand(toxins: [Cell(column: 5, row: 2)], nutrientBudget: 7,
                                                                   weightLimit: 7), arrangement: east)
        XCTAssertEqual(starved.failure, .starved(pulse: 4, tip: 0, cell: Cell(column: 5, row: 2), weight: 8, budget: 7))
        XCTAssertEqual(starved.grown.count, 4)
        XCTAssertEqual(starved.totalWeight, 6)
        let toxic = MyceliumArchitectGrowth.report(try Self.hand(toxins: [Cell(column: 5, row: 2)], nutrientBudget: 8,
                                                                 weightLimit: 8), arrangement: east)
        XCTAssertEqual(toxic.failure, .toxic(pulse: 4, tip: 0, cell: Cell(column: 5, row: 2)))
    }

    /// Equal scores go to the smaller turn (south wins although its number is higher), then the lower number
    /// (north-east before south-east around a rock).
    func testEqualScoresBrokenByTurnThenDirection() throws {
        let flat = try Self.hand(curvature: 0, pulses: 1)
        let south = MyceliumArchitectGrowth.report(flat, arrangement: Self.arrangement(seeds: [.south]))
        XCTAssertEqual(south.steps.first?.direction, .south)
        XCTAssertEqual(south.steps.first?.score, 0)
        let rock = try Self.hand(rocks: [Cell(column: 2, row: 2)], curvature: 0, pulses: 1)
        let around = MyceliumArchitectGrowth.report(rock, arrangement: Self.arrangement(seeds: [.east]))
        XCTAssertEqual(around.steps.first?.direction, .northEast)
        XCTAssertEqual(around.steps.first?.to, Cell(column: 2, row: 1))
    }

    /// A diagonal step between two obstacles is refused, so the tip goes dormant; with one side open it is taken.
    func testACornerCutIsRefused() throws {
        let food = [Cell(column: 2, row: 1)]
        let cut = try Self.hand(rocks: [Cell(column: 1, row: 1), Cell(column: 2, row: 2)])
        let refused = MyceliumArchitectGrowth.report(cut, arrangement: Self.arrangement(nutrients: food,
                                                                                        seeds: [.northEast]))
        XCTAssertEqual(refused.steps.count, 0)
        XCTAssertEqual(refused.grown, [Cell(column: 1, row: 2)])
        XCTAssertEqual(refused.pulsesRun, 1)
        let open = try Self.hand(rocks: [Cell(column: 1, row: 1)])
        let taken = MyceliumArchitectGrowth.report(open, arrangement: Self.arrangement(nutrients: food,
                                                                                       seeds: [.northEast]))
        XCTAssertEqual(taken.steps.first?.direction, .northEast)
        XCTAssertEqual(taken.steps.first?.score, 1)
        XCTAssertEqual(taken.steps.first?.consumed, true)
    }

    /// A tip whose best score is below 0 goes dormant (a nutrient behind it, curvature 8); with curvature 0 it turns.
    func testANegativeBestScoreMakesTheTipDormant() throws {
        let behind = Self.arrangement(nutrients: [Cell(column: 0, row: 2)], seeds: [.east])
        let stiff = MyceliumArchitectGrowth.report(try Self.hand(curvature: 8), arrangement: behind)
        XCTAssertEqual(stiff.steps.count, 0)
        XCTAssertEqual(stiff.pulsesRun, 1)
        XCTAssertEqual(stiff.failure, .unreached(terminal: 0))
        let loose = MyceliumArchitectGrowth.report(try Self.hand(curvature: 0), arrangement: behind)
        XCTAssertEqual(loose.steps.first?.direction, .west)
        XCTAssertEqual(loose.steps.first?.score, 1)
    }

    /// Tip 0 consumes the nutrient at (4, 4) in pulse 2; tip 1 then ignores it (south-east, score 0, instead of east,
    /// score −1); the born tip 2 heads south and first moves in pulse 3.
    func testAConsumedNutrientNoLongerPulls() throws {
        let level = try Self.hand(root: Cell(column: 2, row: 4), terminals: [Cell(column: 11, row: 0)], strength: 2,
                                  reach: 4, curvature: 1, width: 12, height: 9)
        let report = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(
            nutrients: [Cell(column: 4, row: 4)], seeds: [.east, .south]))
        XCTAssertGreaterThanOrEqual(report.steps.count, 5)
        guard report.steps.count >= 5 else { return }
        XCTAssertEqual(report.steps[0].to, Cell(column: 3, row: 4))
        XCTAssertEqual(report.steps[1].to, Cell(column: 3, row: 5))
        XCTAssertEqual(report.steps[1].score, 1)
        let eat: MyceliumArchitectStep = report.steps[2]
        XCTAssertEqual(eat.pulse, 2)
        XCTAssertEqual(eat.tip, 0)
        XCTAssertEqual(eat.to, Cell(column: 4, row: 4))
        XCTAssertTrue(eat.consumed)
        XCTAssertEqual(eat.newTip, 2)
        let after: MyceliumArchitectStep = report.steps[3]
        XCTAssertEqual(after.pulse, 2)
        XCTAssertEqual(after.tip, 1)
        XCTAssertEqual(after.direction, .southEast)
        XCTAssertEqual(after.score, 0)
        var pulseTwoTips: [Int] = []
        var bornStep: MyceliumArchitectStep?
        for s in report.steps {
            if s.pulse == 2 { pulseTwoTips.append(s.tip) }
            if s.tip == 2 && bornStep == nil { bornStep = s }
        }
        XCTAssertEqual(pulseTwoTips, [0, 1], "the born tip does not move in its own pulse")
        XCTAssertEqual(bornStep?.pulse, 3)
        XCTAssertEqual(bornStep?.from, Cell(column: 4, row: 4))
        XCTAssertEqual(bornStep?.direction, .south)
    }

    /// Two tips choose (3, 3) in pulse 1: tip 0 takes it, tip 1 chooses among the rest (east, score 0); alone, tip 1
    /// would have taken (3, 3).
    func testTwoTipsCompetingForOneCellInOnePulse() throws {
        let level = try Self.hand(root: Cell(column: 2, row: 4), terminals: [Cell(column: 11, row: 0)], reach: 6,
                                  curvature: 0, pulses: 1, width: 12, height: 9)
        let food = [Cell(column: 4, row: 2)]
        let both = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(nutrients: food,
                                                                                       seeds: [.north, .east]))
        XCTAssertEqual(both.steps.count, 2)
        guard both.steps.count == 2 else { return }
        XCTAssertEqual(both.steps[0].tip, 0)
        XCTAssertEqual(both.steps[0].to, Cell(column: 3, row: 3))
        XCTAssertEqual(both.steps[0].score, 1)
        XCTAssertEqual(both.steps[1].tip, 1)
        XCTAssertEqual(both.steps[1].direction, .east)
        XCTAssertEqual(both.steps[1].score, 0)
        let alone = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(nutrients: food,
                                                                                        seeds: [.east]))
        XCTAssertEqual(alone.steps.first?.to, Cell(column: 3, row: 3))
    }

    /// With every tip dormant growth ends early: one tip east on a flat field stops at the edge in pulse 8 of 50, and
    /// with no seed no pulse runs.
    func testGrowthEndsEarlyWhenEveryTipIsDormant() throws {
        let level = try Self.hand(pulses: 50)
        let report = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(seeds: [.east]))
        XCTAssertEqual(report.steps.count, 7)
        XCTAssertEqual(report.pulsesRun, 8)
        XCTAssertLessThan(report.pulsesRun, level.pulses)
        XCTAssertNil(report.failure)
        let none = MyceliumArchitectGrowth.report(level, arrangement: Self.arrangement(seeds: []))
        XCTAssertEqual(none.pulsesRun, 0)
        XCTAssertEqual(none.grown, [Cell(column: 1, row: 2)])
        XCTAssertEqual(none.failure, .unreached(terminal: 0))
    }

    /// Every hand case also equals the independent reference.
    func testHandCasesEqualTheReference() throws {
        var cases: [(MyceliumArchitectLevel, MyceliumArchitectArrangement)] = []
        let east = Self.arrangement(seeds: [.east])
        cases.append((try Self.hand(nutrientBudget: 13, weightLimit: 13), east))
        cases.append((try Self.hand(toxins: [Cell(column: 5, row: 2)], nutrientBudget: 7, weightLimit: 7), east))
        cases.append((try Self.hand(rocks: [Cell(column: 1, row: 1), Cell(column: 2, row: 2)]),
                      Self.arrangement(nutrients: [Cell(column: 2, row: 1)], seeds: [.northEast])))
        cases.append((try Self.hand(root: Cell(column: 2, row: 4), terminals: [Cell(column: 11, row: 0)], strength: 2,
                                    width: 12, height: 9),
                      Self.arrangement(nutrients: [Cell(column: 4, row: 4)], seeds: [.east, .south])))
        cases.append((try Self.hand(root: Cell(column: 2, row: 4), terminals: [Cell(column: 11, row: 0)], reach: 6,
                                    curvature: 0, pulses: 1, width: 12, height: 9),
                      Self.arrangement(nutrients: [Cell(column: 4, row: 2)], seeds: [.north, .east])))
        for (i, c) in cases.enumerated() {
            let diffs: [String] = Self.differences(MyceliumArchitectGrowth.report(c.0, arrangement: c.1),
                                                   MyceliumArchitectReference.run(c.0, c.1))
            XCTAssertEqual(diffs, [], "hand case \(i)")
        }
    }
}
