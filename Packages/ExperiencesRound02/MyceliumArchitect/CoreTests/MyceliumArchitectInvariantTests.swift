// MyceliumArchitectInvariantTests — feature 511 (R02-G22-01) T-R02G2201-006 (FR-R02G2201-013; the source's invariants
// R2-G22-INV-01 … 05 and INV-07 … 10 on Mycelium Architect), modelled on BinaryGardensInvariantTests (feature 501).
// Each named test gives a direct boundary example and a seeded check of neighbouring inputs (seed 2,516: fixtures drawn
// from it, random arrangements and traces, a pulse count one either side, an action budget one either side, a weight
// limit and a nutrient budget one unit below the grown weight, a nutrient moved one cell, a toxin on one grown cell, a
// level seed one step on, a byte of a stored level changed or the form truncated).
// How each invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G22-02; INV-11 is
// superseded by the free tier):
// - INV-01 Time: growth counts whole pulses, never a clock; the same arrangement gives the same report however often or
//   late it is computed; a terminal two steps away is unreached with 1 pulse and reached with 2; a run of p pulses is
//   the first p pulses of a run of p + 1; the kernel sources hold no clock or random source.
// - INV-02 Input budget: the action that spends the last one is accepted, the next refused `budget`, the run still
//   accepted; stale before action before budget; refusals change nothing.
// - INV-03 Goal: a run wins exactly when every terminal is reached and the weight is at most the limit (and nothing was
//   toxic or starved); a limit equal to the weight wins, one below fails `overweight`; an extra unreached terminal fails
//   `unreached`.
// - INV-04 Repeatability: replaying the records reproduces every fingerprint and the outcome; a trace with a record
//   removed, or replayed on a level with another seed, is refused `malformed`.
// - INV-05 Undo: undo restores the exact previous fingerprint, from failed too; redo the later one; a won run is final;
//   nothing is undone while paused.
// - INV-07 Failure honesty: every failure has a code, names its pulse, tip, cell or terminal and has words; a toxin on a
//   grown cell fails `toxic` at exactly that cell's pulse and tip; a nutrient budget one below the weight fails
//   `starved` on the last step; the play never changes the arrangement on its own.
// - INV-08 Stability: every report value is bounded (field ≤ 14 · 8 · 16, weight ≤ budget, node count ≤ 2048, cells
//   on the board, scores within bounds); moving a nutrient one cell changes no field value by more than the strength.
// - INV-09 Save: stored levels round-trip byte for byte; every truncation and every sampled one-byte edit is refused;
//   a stored record trace replays to the same play.
// - INV-10 Renderer purity: the report depends only on the level's rules and the arrangement; reading words or
//   descriptions changes nothing; the id, seed, difficulty, action budget and tutorial never change it.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import XCTest
import VisualCoreSimulation
@testable import MyceliumArchitectCore

/// The invariant tests of Mycelium Architect's rule kernel (FR-R02G2201-013).
final class MyceliumArchitectInvariantTests: XCTestCase {
    /// A cell.
    typealias Cell = MyceliumArchitectCell
    /// A direction.
    typealias Direction = MyceliumArchitectDirection
    /// A level.
    typealias Level = MyceliumArchitectLevel
    /// A play.
    typealias Play = MyceliumArchitectPlay
    /// An arrangement.
    typealias Arrangement = MyceliumArchitectArrangement
    /// A report.
    typealias Report = MyceliumArchitectReport
    /// A failure.
    typealias Failure = MyceliumArchitectFailure
    /// A refusal.
    typealias Refusal = MyceliumArchitectError
    /// A fixture.
    typealias Fixture = MyceliumArchitectFixture

    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_516

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The fixtures of the invariant seed (computed once).
    static let fixtures: [Fixture] = Fixture.all(count: 12, seed: seed)

    // MARK: Helpers

    /// A hand level: a 9 × 5 board, root (1, 2), strength 1, reach 4, curvature 1, no obstacle penalty, no start seed
    /// (a probe: it may already win). With `seed(.east)` and nothing placed, the tip grows straight east one cell per
    /// pulse, (2, 2) at pulse 1 … (8, 2) at pulse 7, weight 2 per step.
    static func hand(terminals: [Cell] = [Cell(column: 3, row: 2)], toxins: [Cell] = [], pulses: Int = 16,
                     nutrientBudget: Int = 4094, weightLimit: Int = 4094, budget: Int = 8) throws -> Level {
        try Level(id: "hand", seed: 1, difficulty: 1, width: 9, height: 5, root: Cell(column: 1, row: 2),
                  terminals: terminals, rocks: [], toxins: toxins, fixedNutrients: [], strength: 1, reach: 4,
                  curvature: 1, obstacle: 0, maxNutrients: 3, maxBlockers: 3, maxSeeds: 4, startSeeds: [],
                  pulses: pulses, nutrientBudget: nutrientBudget, weightLimit: weightLimit, budget: budget,
                  tutorial: false, refusingAWin: false)
    }

    /// `level` with the given values replaced (a probe: it may already win).
    static func rebuilt(_ level: Level, id: String? = nil, seed: UInt64? = nil, difficulty: Int? = nil,
                        terminals: [Cell]? = nil, toxins: [Cell]? = nil, pulses: Int? = nil,
                        nutrientBudget: Int? = nil, weightLimit: Int? = nil, budget: Int? = nil,
                        tutorial: Bool? = nil) throws -> Level {
        try Level(id: id ?? level.id, seed: seed ?? level.seed, difficulty: difficulty ?? level.difficulty,
                  width: level.width, height: level.height, root: level.root,
                  terminals: terminals ?? level.terminals, rocks: level.rocks, toxins: toxins ?? level.toxins,
                  fixedNutrients: level.fixedNutrients, strength: level.strength, reach: level.reach,
                  curvature: level.curvature, obstacle: level.obstacle, maxNutrients: level.maxNutrients,
                  maxBlockers: level.maxBlockers, maxSeeds: level.maxSeeds, startSeeds: level.startSeeds,
                  pulses: pulses ?? level.pulses, nutrientBudget: nutrientBudget ?? level.nutrientBudget,
                  weightLimit: weightLimit ?? level.weightLimit, budget: budget ?? level.budget,
                  tutorial: tutorial ?? level.tutorial, refusingAWin: false)
    }

    /// A play of `level` moved to `playing` (begin, and dismissTutorial when the level has one).
    static func playing(_ level: Level) throws -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The refusal `body` throws, or nil when it is accepted (an error of another type is reported as malformed).
    static func refusal(_ body: () throws -> Void) -> Refusal? {
        do {
            try body()
            return nil
        } catch let refused as Refusal {
            return refused
        } catch {
            return .malformed("not a refusal: \(error)")
        }
    }

    /// A random arrangement action on `level` (it may be refused).
    static func randomAction(_ level: Level, _ play: Play, _ random: inout SeededRandom) -> MyceliumArchitectAction {
        let direction: Direction = Direction(rawValue: random.int(0...7))!
        let cell = Cell(column: random.int(0...(level.width - 1)), row: random.int(0...(level.height - 1)))
        let roll: Int = random.int(0...4)
        if roll == 0 { return .seed(direction) }
        if roll == 1 { return .unseed(direction) }
        if roll == 2 { return .nutrient(cell) }
        if roll == 3 { return .blocker(cell) }
        let placed: [Cell] = play.arrangement.nutrients + play.arrangement.blockers
        if placed.isEmpty { return .clear(cell) }
        return .clear(placed[random.int(0...(placed.count - 1))])
    }

    /// A seeded trace on `level`: `count` random arrangement actions, undos and redos (refusals ignored), then the run
    /// when `run`.
    static func randomTrace(_ level: Level, _ random: inout SeededRandom, count: Int, run: Bool) throws -> Play {
        var play: Play = try playing(level)
        for _ in 0..<count {
            let roll: Int = random.int(0...9)
            if roll == 8 {
                try? play.undo()
            } else if roll == 9 {
                try? play.redo()
            } else {
                let action: MyceliumArchitectAction = randomAction(level, play, &random)
                try? play.apply(action, expecting: play.fingerprint)
            }
        }
        if run { try play.apply(.run, expecting: play.fingerprint) }
        return play
    }

    /// The fixture plays driven by the known winning actions.
    static func winningPlay(_ fixture: Fixture) throws -> Play {
        var play: Play = try playing(fixture.level)
        for action in fixture.actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// Checks that `failure` names honest values for `level` and has words that say them.
    static func checkHonest(_ failure: Failure, _ level: Level, _ report: Report, file: StaticString = #filePath,
                            line: UInt = #line) {
        XCTAssertFalse(failure.code.isEmpty, file: file, line: line)
        let words: String = level.failureDescription(failure)
        XCTAssertFalse(words.isEmpty, file: file, line: line)
        switch failure {
        case let .toxic(pulse, tip, cell):
            XCTAssertEqual(failure.code, "toxic", file: file, line: line)
            XCTAssertTrue((1...level.pulses).contains(pulse), file: file, line: line)
            XCTAssertTrue(level.toxins.contains(cell), file: file, line: line)
            XCTAssertEqual(report.steps.last?.to, cell, file: file, line: line)
            XCTAssertEqual(report.steps.last?.tip, tip, file: file, line: line)
            XCTAssertTrue(words.contains("pulse \(pulse)"), file: file, line: line)
            XCTAssertTrue(words.contains("tip \(tip + 1)"), file: file, line: line)
            XCTAssertTrue(words.contains(cell.words), file: file, line: line)
        case let .starved(pulse, tip, cell, weight, budget):
            XCTAssertEqual(failure.code, "starved", file: file, line: line)
            XCTAssertTrue((1...level.pulses).contains(pulse), file: file, line: line)
            XCTAssertEqual(budget, level.nutrientBudget, file: file, line: line)
            XCTAssertGreaterThan(weight, budget, file: file, line: line)
            XCTAssertLessThanOrEqual(weight - report.totalWeight, 3, file: file, line: line)
            XCTAssertTrue(words.contains("pulse \(pulse)"), file: file, line: line)
            XCTAssertTrue(words.contains("tip \(tip + 1)"), file: file, line: line)
            XCTAssertTrue(words.contains(cell.words), file: file, line: line)
        case let .unreached(terminal):
            XCTAssertEqual(failure.code, "unreached", file: file, line: line)
            XCTAssertTrue(terminal >= 0 && terminal < level.terminals.count, file: file, line: line)
            XCTAssertNil(report.terminalPulses[terminal], file: file, line: line)
            XCTAssertTrue(words.contains("terminal \(terminal + 1)"), file: file, line: line)
            XCTAssertTrue(words.contains(level.terminals[terminal].words), file: file, line: line)
        case let .overweight(weight, limit):
            XCTAssertEqual(failure.code, "overweight", file: file, line: line)
            XCTAssertEqual(weight, report.totalWeight, file: file, line: line)
            XCTAssertEqual(limit, level.weightLimit, file: file, line: line)
            XCTAssertGreaterThan(weight, limit, file: file, line: line)
            XCTAssertEqual(report.terminalsReached, level.terminals.count, file: file, line: line)
            XCTAssertTrue(words.contains(Level.grouped(weight)), file: file, line: line)
            XCTAssertTrue(words.contains(Level.grouped(limit)), file: file, line: line)
        }
    }

    /// Checks every bound of `report` on `level` with `arrangement`.
    static func checkBounded(_ report: Report, _ level: Level, _ arrangement: Arrangement,
                             file: StaticString = #filePath, line: UInt = #line) {
        let fieldBound: Int = 14 * 8 * 16
        XCTAssertEqual(report.field.count, level.height, file: file, line: line)
        for row in report.field {
            XCTAssertEqual(row.count, level.width, file: file, line: line)
            for value in row {
                XCTAssertTrue(value >= 0 && value <= fieldBound, file: file, line: line)
            }
        }
        XCTAssertTrue(report.totalWeight >= 0 && report.totalWeight <= level.nutrientBudget, file: file, line: line)
        XCTAssertTrue(report.nodeCount >= 1 && report.nodeCount <= MyceliumArchitectGrowth.nodeCap,
                      file: file, line: line)
        XCTAssertEqual(report.grown.count, report.grownPulses.count, file: file, line: line)
        XCTAssertEqual(report.grown.count, report.parents.count, file: file, line: line)
        XCTAssertEqual(report.steps.count, report.grown.count - 1, file: file, line: line)
        XCTAssertEqual(Set(report.grown).count, report.grown.count, file: file, line: line)
        XCTAssertEqual(report.grown.first, level.root, file: file, line: line)
        XCTAssertTrue(report.pulsesRun >= 0 && report.pulsesRun <= level.pulses, file: file, line: line)
        var previousPulse: Int = 0
        for i in 0..<report.grown.count {
            XCTAssertTrue(level.contains(report.grown[i]), file: file, line: line)
            XCTAssertFalse(level.rocks.contains(report.grown[i]), file: file, line: line)
            XCTAssertFalse(arrangement.blockers.contains(report.grown[i]), file: file, line: line)
            let pulse: Int = report.grownPulses[i]
            XCTAssertTrue(pulse >= previousPulse && pulse <= report.pulsesRun, file: file, line: line)
            previousPulse = pulse
            if i == 0 {
                XCTAssertNil(report.parents[i], file: file, line: line)
            } else if let parent = report.parents[i] {
                XCTAssertTrue(parent >= 0 && parent < i, file: file, line: line)
            } else {
                XCTFail("grown cell \(i) has no parent", file: file, line: line)
            }
        }
        var sum: Int = 0
        for step in report.steps {
            XCTAssertTrue(step.weight == 2 || step.weight == 3, file: file, line: line)
            XCTAssertEqual(step.weight, MyceliumArchitectGrowth.weight(step.direction), file: file, line: line)
            XCTAssertTrue(step.score >= 0 && step.score <= fieldBound, file: file, line: line)
            XCTAssertEqual(step.from.distance(to: step.to), 1, file: file, line: line)
            sum += step.weight
        }
        XCTAssertEqual(sum, report.totalWeight, file: file, line: line)
        XCTAssertEqual(report.terminalPulses.count, level.terminals.count, file: file, line: line)
        for t in 0..<level.terminals.count {
            if let pulse = report.terminalPulses[t] {
                XCTAssertTrue(pulse >= 1 && pulse <= report.pulsesRun, file: file, line: line)
                let weight: Int = report.terminalPathWeights[t] ?? -1
                XCTAssertTrue(weight >= 2 && weight <= report.totalWeight, file: file, line: line)
            } else {
                XCTAssertNil(report.terminalPathWeights[t], file: file, line: line)
            }
        }
    }

    // MARK: INV-01 Time

    /// Growth counts pulses, never a clock: the same arrangement gives the same report however often or late it is
    /// computed; a terminal two cells away is unreached with 1 pulse and reached with 2; p pulses are a prefix of p + 1.
    func testMyceliumArchitectTimeBoundary() throws {
        let east = Arrangement(nutrients: [], blockers: [], seeds: [.east])
        let one: Level = try Self.hand(pulses: 1)
        let two: Level = try Self.hand(pulses: 2)
        let short: Report = MyceliumArchitectGrowth.report(one, arrangement: east)
        let enough: Report = MyceliumArchitectGrowth.report(two, arrangement: east)
        XCTAssertEqual(short.failure, .unreached(terminal: 0))
        XCTAssertEqual(short.pulsesRun, 1)
        XCTAssertEqual(short.grownPulses, [0, 1])
        XCTAssertTrue(enough.wins)
        XCTAssertEqual(enough.pulsesRun, 2)
        XCTAssertEqual(enough.terminalPulses, [2])
        XCTAssertEqual(enough.grownPulses, [0, 1, 2])
        // However often or late: a hundred recomputations, pauses and reads in between change nothing.
        var play: Play = try Self.playing(two)
        try play.apply(.seed(.east), expecting: play.fingerprint)
        let fingerprint: String = play.fingerprint
        for _ in 0..<100 {
            XCTAssertEqual(MyceliumArchitectGrowth.report(two, arrangement: east), enough)
            try play.handle(.pause)
            try play.handle(.resume)
            XCTAssertEqual(play.fingerprint, fingerprint)
            XCTAssertEqual(play.report, enough)
        }
        // The kernel sources read no clock and no random source.
        let core: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Core")
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: core.path).sorted()
        let forbidden: [String] = ["Da" + "te()", "Da" + "te.now", "CFAbsolute" + "Time", "Dispatch" + "Time",
                                   "Continuous" + "Clock", "Suspending" + "Clock", "CACurrent" + "MediaTime",
                                   "system" + "Uptime", "Time" + "Interval", "CADisplay" + "Link",
                                   "SystemRandom" + "NumberGenerator", ".rand" + "om("]
        var scanned: Int = 0
        for name in names where name.hasSuffix(".swift") {
            let text: String = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            scanned += 1
            for token in forbidden {
                XCTAssertFalse(text.contains(token), "\(name) holds \(token)")
            }
        }
        XCTAssertGreaterThanOrEqual(scanned, 4)
        // Neighbouring inputs: a pulse count p and p + 1; p's run is the first p pulses of p + 1's.
        var random = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let p: Int = random.int(1...fixture.level.pulses)
            let lower: Level = try Self.rebuilt(fixture.level, pulses: p)
            let upper: Level = try Self.rebuilt(fixture.level, pulses: p + 1)
            let a: Report = MyceliumArchitectGrowth.report(lower, arrangement: fixture.winning)
            let b: Report = MyceliumArchitectGrowth.report(upper, arrangement: fixture.winning)
            XCTAssertEqual(a.field, b.field)
            var prefix: [MyceliumArchitectStep] = []
            for step in b.steps where step.pulse <= p { prefix.append(step) }
            XCTAssertEqual(a.steps, prefix)
            if case .unreached = a.failure {} else if case .overweight = a.failure {} else if a.failure != nil {
                XCTAssertEqual(a.failure, b.failure)
            }
            for pulse in a.grownPulses { XCTAssertLessThanOrEqual(pulse, p) }
            XCTAssertEqual(MyceliumArchitectGrowth.report(lower, arrangement: fixture.winning), a)
        }
    }

    // MARK: INV-02 Input budget

    /// The action that spends the last one is accepted, the next refused `budget`; the run is still accepted; stale and
    /// action refusals come first; a refusal changes nothing.
    func testMyceliumArchitectInputbudgetBoundary() throws {
        let level: Level = try Self.hand(terminals: [Cell(column: 7, row: 2)], budget: 3)
        var play: Play = try Self.playing(level)
        let toggles: [MyceliumArchitectAction] = [.seed(.north), .unseed(.north), .seed(.north)]
        for (i, action) in toggles.enumerated() {
            try play.apply(action, expecting: play.fingerprint)
            XCTAssertEqual(play.actionsSpent, i + 1)
        }
        XCTAssertEqual(play.actionsLeft, 0)
        let before: Play = play
        XCTAssertEqual(Self.refusal { try play.apply(.unseed(.north), expecting: play.fingerprint) }, .budget)
        XCTAssertEqual(Self.refusal { try play.apply(.nutrient(level.root), expecting: play.fingerprint) },
                       .action("cell"))
        XCTAssertEqual(Self.refusal { try play.apply(.nutrient(Cell(column: 9, row: 0)), expecting: play.fingerprint) },
                       .action("cell"))
        XCTAssertEqual(Self.refusal { try play.apply(.unseed(.north), expecting: Self.staleFingerprint) }, .stale)
        XCTAssertEqual(play, before)
        try play.apply(.run, expecting: play.fingerprint)
        XCTAssertEqual(play.actionsSpent, 3)
        XCTAssertEqual(play.stage, .failed)
        // Neighbouring inputs: budgets b − 1, b and b + 1; the k-th action is accepted exactly when k ≤ budget.
        var random = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let b: Int = random.int(2...23)
            let direction: Direction = Direction(rawValue: random.int(0...7))!
            for budget in [b - 1, b, b + 1] {
                let probe: Level = try Self.rebuilt(fixture.level, budget: budget)
                var toggle: Play = try Self.playing(probe)
                for k in 1...(b + 1) {
                    let seeded: Bool = toggle.arrangement.seeds.contains(direction)
                    let action: MyceliumArchitectAction = seeded ? .unseed(direction) : .seed(direction)
                    let spent: Int = toggle.actionsSpent
                    let refused: Refusal? = Self.refusal { try toggle.apply(action, expecting: toggle.fingerprint) }
                    if k <= budget {
                        XCTAssertNil(refused)
                        XCTAssertEqual(toggle.actionsSpent, spent + 1)
                    } else {
                        XCTAssertEqual(refused, .budget)
                        XCTAssertEqual(toggle.actionsSpent, spent)
                    }
                }
                XCTAssertNil(Self.refusal { try toggle.apply(.run, expecting: toggle.fingerprint) })
            }
        }
    }

    // MARK: INV-03 Goal

    /// Won only when every terminal is reached and the weight is at most the limit: limit = weight wins, weight − 1
    /// fails `overweight`; an extra unreached terminal fails `unreached`.
    func testMyceliumArchitectGoalBoundary() throws {
        let east = Arrangement(nutrients: [], blockers: [], seeds: [.east])
        let far: [Cell] = [Cell(column: 7, row: 2)]
        let exact: Report = MyceliumArchitectGrowth.report(try Self.hand(terminals: far, weightLimit: 14),
                                                           arrangement: east)
        XCTAssertEqual(exact.totalWeight, 14)
        XCTAssertTrue(exact.wins)
        let tight: Report = MyceliumArchitectGrowth.report(try Self.hand(terminals: far, weightLimit: 13),
                                                           arrangement: east)
        XCTAssertEqual(tight.failure, .overweight(weight: 14, limit: 13))
        let missing: Report = MyceliumArchitectGrowth.report(
            try Self.hand(terminals: far + [Cell(column: 4, row: 0)]), arrangement: east)
        XCTAssertEqual(missing.failure, .unreached(terminal: 1))
        // Neighbouring inputs: the limit at the weight and one unit below; one extra terminal off the network.
        var random = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let won: Play = try Self.winningPlay(fixture)
            XCTAssertEqual(won.stage, .won)
            let report: Report = MyceliumArchitectGrowth.report(fixture.level, arrangement: fixture.winning)
            let weight: Int = report.totalWeight
            let atLimit: Level = try Self.rebuilt(fixture.level, weightLimit: weight)
            XCTAssertTrue(MyceliumArchitectGrowth.report(atLimit, arrangement: fixture.winning).wins)
            let below: Level = try Self.rebuilt(fixture.level, weightLimit: weight - 1)
            XCTAssertEqual(MyceliumArchitectGrowth.report(below, arrangement: fixture.winning).failure,
                           .overweight(weight: weight, limit: weight - 1))
            var spare: [Cell] = []
            for row in 0..<fixture.level.height {
                for column in 0..<fixture.level.width {
                    let cell = Cell(column: column, row: row)
                    if fixture.level.isEmpty(cell, in: fixture.winning) && !report.grown.contains(cell) {
                        spare.append(cell)
                    }
                }
            }
            if !spare.isEmpty {
                let extra: Cell = spare[random.int(0...(spare.count - 1))]
                let more: Level = try Self.rebuilt(fixture.level, terminals: fixture.level.terminals + [extra])
                XCTAssertEqual(MyceliumArchitectGrowth.report(more, arrangement: fixture.winning).failure,
                               .unreached(terminal: fixture.level.terminals.count))
            }
            // Random arrangements: the verdict is exactly the rule.
            for _ in 0..<6 {
                let play: Play = try Self.randomTrace(fixture.level, &random, count: 12, run: false)
                let r: Report = play.report
                var hazard: Bool = false
                for step in r.steps where fixture.level.toxins.contains(step.to) { hazard = true }
                if case .starved = r.failure { hazard = true }
                let rule: Bool = !hazard && r.terminalsReached == fixture.level.terminals.count
                    && r.totalWeight <= fixture.level.weightLimit
                XCTAssertEqual(r.wins, rule)
                var ran: Play = play
                try ran.apply(.run, expecting: ran.fingerprint)
                XCTAssertEqual(ran.stage, rule ? .won : .failed)
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// Replaying the records reproduces every fingerprint and the outcome; a trace with a record removed or replayed on
    /// a level with another seed is refused.
    func testMyceliumArchitectRepeatabilityBoundary() throws {
        var random = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let first: Play = try Self.winningPlay(fixture)
            let second: Play = try Self.winningPlay(fixture)
            XCTAssertEqual(first.records, second.records)
            XCTAssertEqual(first.fingerprint, second.fingerprint)
            let replayed: Play = try Play.replay(level: fixture.level, records: first.records)
            XCTAssertEqual(replayed, first)
            XCTAssertEqual(replayed.stage, .won)
            // Neighbouring inputs: a seeded trace, the same trace less one record, the same trace on seed + 1.
            let runs: Bool = random.int(0...1) == 1
            let traced: Play = try Self.randomTrace(fixture.level, &random, count: 20, run: runs)
            let again: Play = try Play.replay(level: fixture.level, records: traced.records)
            XCTAssertEqual(again, traced)
            for i in 0..<traced.records.count {
                XCTAssertEqual(again.records[i].next, traced.records[i].next)
            }
            if traced.records.count >= 2 {
                var shorter: [MyceliumArchitectRecord] = traced.records
                shorter.remove(at: random.int(0...(traced.records.count - 2)))
                let refused: Refusal? = Self.refusal { _ = try Play.replay(level: fixture.level, records: shorter) }
                if case .malformed = refused {} else { XCTFail("a trace less one record was not refused: \(String(describing: refused))") }
            }
            let other: Level = try Self.rebuilt(fixture.level, seed: fixture.level.seed + 1)
            XCTAssertEqual(Self.refusal { _ = try Play.replay(level: other, records: traced.records) },
                           .malformed("seed 0"))
        }
    }

    // MARK: INV-05 Undo

    /// Undo restores the exact previous fingerprint (from failed too); redo the later one; a won run is final; nothing
    /// is undone while paused.
    func testMyceliumArchitectUndoBoundary() throws {
        var random = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            var play: Play = try Self.playing(fixture.level)
            let start: String = play.fingerprint
            try play.apply(.run, expecting: start)
            XCTAssertEqual(play.stage, .failed)
            let failed: String = play.fingerprint
            try play.undo()
            XCTAssertEqual(play.fingerprint, start)
            XCTAssertEqual(play.stage, .playing)
            XCTAssertEqual(play.arrangement, fixture.level.start)
            try play.redo()
            XCTAssertEqual(play.fingerprint, failed)
            var won: Play = try Self.winningPlay(fixture)
            XCTAssertEqual(Self.refusal { try won.undo() }, .stage)
            var paused: Play = try Self.playing(fixture.level)
            try paused.apply(fixture.actions[0], expecting: paused.fingerprint)
            try paused.handle(.pause)
            XCTAssertEqual(Self.refusal { try paused.undo() }, .stage)
            // Neighbouring inputs: after every accepted random action (one step from the previous state), undo
            // restores the previous fingerprint and redo the later one.
            var walk: Play = try Self.playing(fixture.level)
            for _ in 0..<16 {
                let before: String = walk.fingerprint
                let arrangement: Arrangement = walk.arrangement
                let action: MyceliumArchitectAction = Self.randomAction(fixture.level, walk, &random)
                if Self.refusal({ try walk.apply(action, expecting: before) }) != nil {
                    XCTAssertEqual(walk.fingerprint, before)
                    continue
                }
                let after: String = walk.fingerprint
                XCTAssertNotEqual(after, before)
                var back: Play = walk
                try back.undo()
                XCTAssertEqual(back.fingerprint, before)
                XCTAssertEqual(back.arrangement, arrangement)
                try back.redo()
                XCTAssertEqual(back.fingerprint, after)
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// Every failure has a code, names its pulse, tip, cell or terminal and has words; no automatic solution: the play
    /// never changes the arrangement on its own.
    func testMyceliumArchitectFailurehonestyBoundary() throws {
        let east = Arrangement(nutrients: [], blockers: [], seeds: [.east])
        let far: [Cell] = [Cell(column: 7, row: 2)]
        let toxicLevel: Level = try Self.hand(terminals: far, toxins: [Cell(column: 3, row: 2)])
        let toxic: Report = MyceliumArchitectGrowth.report(toxicLevel, arrangement: east)
        XCTAssertEqual(toxic.failure, .toxic(pulse: 2, tip: 0, cell: Cell(column: 3, row: 2)))
        Self.checkHonest(toxic.failure!, toxicLevel, toxic)
        let starvedLevel: Level = try Self.hand(terminals: far, nutrientBudget: 2, weightLimit: 2)
        let starved: Report = MyceliumArchitectGrowth.report(starvedLevel, arrangement: east)
        XCTAssertEqual(starved.failure,
                       .starved(pulse: 2, tip: 0, cell: Cell(column: 3, row: 2), weight: 4, budget: 2))
        XCTAssertEqual(starved.totalWeight, 2)
        Self.checkHonest(starved.failure!, starvedLevel, starved)
        let shortLevel: Level = try Self.hand(terminals: far, pulses: 3)
        let short: Report = MyceliumArchitectGrowth.report(shortLevel, arrangement: east)
        XCTAssertEqual(short.failure, .unreached(terminal: 0))
        Self.checkHonest(short.failure!, shortLevel, short)
        let heavyLevel: Level = try Self.hand(terminals: far, weightLimit: 4)
        let heavy: Report = MyceliumArchitectGrowth.report(heavyLevel, arrangement: east)
        XCTAssertEqual(heavy.failure, .overweight(weight: 14, limit: 4))
        Self.checkHonest(heavy.failure!, heavyLevel, heavy)
        // The play reports the judge's failure and changes nothing on its own.
        var play: Play = try Self.playing(toxicLevel)
        try play.apply(.seed(.east), expecting: play.fingerprint)
        let arrangement: Arrangement = play.arrangement
        try play.apply(.run, expecting: play.fingerprint)
        XCTAssertEqual(play.failure, toxic.failure)
        XCTAssertEqual(play.arrangement, arrangement)
        XCTAssertEqual(play.actionsSpent, 1)
        try play.handle(.showResult)
        XCTAssertEqual(play.arrangement, arrangement)
        // Neighbouring inputs: a toxin on one grown cell, a nutrient budget one unit below the weight, random traces.
        var random = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let level: Level = fixture.level
            let report: Report = MyceliumArchitectGrowth.report(level, arrangement: fixture.winning)
            var candidates: [Int] = []
            for i in 1..<report.grown.count {
                let cell: Cell = report.grown[i]
                if level.isEmpty(cell, in: fixture.winning) { candidates.append(i) }
            }
            if !candidates.isEmpty {
                let i: Int = candidates[random.int(0...(candidates.count - 1))]
                let cell: Cell = report.grown[i]
                let step: MyceliumArchitectStep = report.steps[i - 1]
                let poisoned: Level = try Self.rebuilt(level, toxins: level.toxins + [cell])
                let r: Report = MyceliumArchitectGrowth.report(poisoned, arrangement: fixture.winning)
                XCTAssertEqual(r.failure, .toxic(pulse: step.pulse, tip: step.tip, cell: cell))
                Self.checkHonest(r.failure!, poisoned, r)
            }
            let weight: Int = report.totalWeight
            let last: MyceliumArchitectStep = report.steps[report.steps.count - 1]
            let lean: Level = try Self.rebuilt(level, nutrientBudget: weight - 1,
                                               weightLimit: min(level.weightLimit, weight - 1))
            let s: Report = MyceliumArchitectGrowth.report(lean, arrangement: fixture.winning)
            XCTAssertEqual(s.failure, .starved(pulse: last.pulse, tip: last.tip, cell: last.to, weight: weight,
                                               budget: weight - 1))
            Self.checkHonest(s.failure!, lean, s)
            for _ in 0..<4 {
                let traced: Play = try Self.randomTrace(level, &random, count: 10, run: true)
                if let failure = traced.failure {
                    XCTAssertEqual(traced.stage, .failed)
                    XCTAssertEqual(failure, traced.report.failure)
                    Self.checkHonest(failure, level, traced.report)
                } else {
                    XCTAssertEqual(traced.stage, .won)
                }
                XCTAssertEqual(MyceliumArchitectGrowth.report(level, arrangement: traced.arrangement), traced.report)
            }
        }
    }

    // MARK: INV-08 Stability

    /// Every report value is bounded: field ≤ 14 · 8 · 16, weight ≤ budget, node count ≤ 2048, cells on the board,
    /// scores within bounds; moving one nutrient one cell changes no field value by more than the strength.
    func testMyceliumArchitectStabilityBoundary() throws {
        var fixed: [Cell] = []
        for column in 12..<20 { fixed.append(Cell(column: column, row: 10)) }
        let extreme = try Level(id: "extreme", seed: 9, difficulty: 5, width: 32, height: 32,
                                root: Cell(column: 16, row: 16), terminals: [Cell(column: 0, row: 0)], rocks: [],
                                toxins: [], fixedNutrients: fixed, strength: 8, reach: 16, curvature: 0, obstacle: 0,
                                maxNutrients: 6, maxBlockers: 6, maxSeeds: 4, startSeeds: [], pulses: 128,
                                nutrientBudget: 4094, weightLimit: 4094, budget: 24, tutorial: false,
                                refusingAWin: false)
        var placed: [Cell] = []
        for column in 13..<19 { placed.append(Cell(column: column, row: 11)) }
        let crowded = Arrangement(nutrients: placed, blockers: [], seeds: [.north, .east, .south, .west])
        let crowdedReport: Report = MyceliumArchitectGrowth.report(extreme, arrangement: crowded)
        Self.checkBounded(crowdedReport, extreme, crowded)
        let open = Arrangement(nutrients: [], blockers: [], seeds: [.northEast, .southEast, .southWest, .northWest])
        Self.checkBounded(MyceliumArchitectGrowth.report(extreme, arrangement: open), extreme, open)
        let empty = try Level(id: "empty", seed: 9, difficulty: 5, width: 32, height: 32,
                              root: Cell(column: 0, row: 0), terminals: [Cell(column: 31, row: 31)], rocks: [],
                              toxins: [], fixedNutrients: [], strength: 8, reach: 16, curvature: 0, obstacle: 0,
                              maxNutrients: 6, maxBlockers: 6, maxSeeds: 4, startSeeds: [], pulses: 128,
                              nutrientBudget: 2, weightLimit: 2, budget: 24, tutorial: false, refusingAWin: false)
        let corner = Arrangement(nutrients: [], blockers: [], seeds: [.east, .south])
        let cornerReport: Report = MyceliumArchitectGrowth.report(empty, arrangement: corner)
        Self.checkBounded(cornerReport, empty, corner)
        XCTAssertLessThanOrEqual(cornerReport.totalWeight, 2)
        // Neighbouring inputs: seeded arrangements, and one nutrient moved one cell.
        var random = SeededRandom(seed: Self.seed)
        var moves: Int = 0
        for fixture in Self.fixtures {
            let level: Level = fixture.level
            Self.checkBounded(MyceliumArchitectGrowth.report(level, arrangement: fixture.winning), level,
                              fixture.winning)
            for _ in 0..<4 {
                let play: Play = try Self.randomTrace(level, &random, count: 14, run: false)
                Self.checkBounded(play.report, level, play.arrangement)
            }
            let nutrients: [Cell] = level.fixedNutrients + fixture.winning.nutrients
            if nutrients.isEmpty { continue }
            let n: Int = random.int(0...(nutrients.count - 1))
            let moved: Cell = nutrients[n].moved(Direction(rawValue: random.int(0...7))!)
            if !level.contains(moved) { continue }
            var shifted: [Cell] = nutrients
            shifted[n] = moved
            let a: [[Int]] = MyceliumArchitectGrowth.field(level, nutrients: nutrients)
            let b: [[Int]] = MyceliumArchitectGrowth.field(level, nutrients: shifted)
            for row in 0..<level.height {
                for column in 0..<level.width {
                    XCTAssertLessThanOrEqual(abs(a[row][column] - b[row][column]), level.strength)
                }
            }
            moves += 1
        }
        XCTAssertGreaterThan(moves, 0)
    }

    // MARK: INV-09 Save

    /// A stored level round-trips byte for byte; a truncated or edited form is refused, never partly accepted; a
    /// stored record trace replays to the same play.
    func testMyceliumArchitectSaveBoundary() throws {
        var random = SeededRandom(seed: Self.seed)
        for (f, fixture) in Self.fixtures.enumerated() {
            let level: Level = fixture.level
            let data: Data = level.encoded()
            let decoded: Level = try Level.decode(data)
            XCTAssertEqual(decoded, level)
            XCTAssertEqual(decoded.encoded(), data)
            let viaCodable: Level = try JSONDecoder().decode(Level.self, from: try JSONEncoder().encode(level))
            XCTAssertEqual(viaCodable, level)
            let text: String = String(decoding: data, as: UTF8.self)
            let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
            XCTAssertEqual(Self.refusal { _ = try Level.decode(Data(newer.utf8)) }, .newerSchema(2))
            let budgetKey: String = "\"budget\":\(level.budget)"
            let edited: String = text.replacingOccurrences(of: budgetKey, with: "\"budget\":\(level.budget % 24 + 1)")
            XCTAssertEqual(Self.refusal { _ = try Level.decode(Data(edited.utf8)) }, .malformed("fingerprint"))
            // Neighbouring inputs: every truncation; a sample of one-byte edits (one bit flipped).
            let bytes: [UInt8] = Array(data)
            for length in 0..<bytes.count {
                XCTAssertNotNil(Self.refusal { _ = try Level.decode(Data(bytes[0..<length])) }, "length \(length)")
            }
            if f < 6 {
                for _ in 0..<80 {
                    var flipped: [UInt8] = bytes
                    let position: Int = random.int(0...(bytes.count - 1))
                    flipped[position] ^= 0x01
                    XCTAssertNotNil(Self.refusal { _ = try Level.decode(Data(flipped)) }, "byte \(position)")
                }
            }
            // A stored record trace replays to the same play; a truncated stored trace is unreadable.
            let play: Play = try Self.winningPlay(fixture)
            let stored: Data = try JSONEncoder().encode(play.records)
            let records: [MyceliumArchitectRecord] = try JSONDecoder().decode([MyceliumArchitectRecord].self,
                                                                              from: stored)
            XCTAssertEqual(try Play.replay(level: decoded, records: records), play)
            let cut: Data = stored.prefix(stored.count / 2)
            XCTAssertThrowsError(try JSONDecoder().decode([MyceliumArchitectRecord].self, from: cut))
        }
    }

    // MARK: INV-10 Renderer purity

    /// The report depends only on the level's rules and the arrangement: reading words or descriptions changes
    /// nothing; two reports of the same input are equal; id, seed, difficulty, budget and tutorial never change it.
    func testMyceliumArchitectRendererpurityBoundary() throws {
        var random = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let level: Level = fixture.level
            var play: Play = try Self.playing(level)
            for action in fixture.actions.dropLast() { try play.apply(action, expecting: play.fingerprint) }
            let fingerprint: String = play.fingerprint
            let report: Report = play.report
            var spoken: Int = 0
            for row in 0..<level.height {
                for column in 0..<level.width {
                    spoken += level.cellDescription(Cell(column: column, row: row), arrangement: play.arrangement,
                                                    report: report).count
                }
            }
            for step in report.steps { spoken += level.stepDescription(step).count }
            for t in 0..<level.terminals.count { spoken += level.terminalDescription(t, report: report).count }
            if let failure = report.failure { spoken += level.failureDescription(failure).count }
            spoken += level.progressDescription(report: report, actionsLeft: play.actionsLeft).count
            XCTAssertGreaterThan(spoken, 0)
            XCTAssertEqual(play.fingerprint, fingerprint)
            XCTAssertEqual(play.report, report)
            XCTAssertEqual(MyceliumArchitectGrowth.report(level, arrangement: play.arrangement), report)
            XCTAssertEqual(MyceliumArchitectGrowth.report(level, arrangement: play.arrangement),
                           MyceliumArchitectGrowth.report(level, arrangement: play.arrangement))
            // A play is a value: changing a copy leaves the original as it was.
            var copy: Play = play
            try copy.apply(.run, expecting: copy.fingerprint)
            XCTAssertEqual(play.fingerprint, fingerprint)
            XCTAssertEqual(play.stage, .playing)
            // Neighbouring inputs: the seed one step on, another id, difficulty, action budget and tutorial.
            let step: UInt64 = UInt64(random.int(1...1_000))
            let relabelled: Level = try Self.rebuilt(level, id: "renamed-\(step)", seed: level.seed &+ step,
                                                     difficulty: level.difficulty % 5 + 1,
                                                     budget: level.budget % 24 + 1, tutorial: !level.tutorial)
            XCTAssertNotEqual(relabelled.fingerprint, level.fingerprint)
            XCTAssertEqual(MyceliumArchitectGrowth.report(relabelled, arrangement: fixture.winning),
                           MyceliumArchitectGrowth.report(level, arrangement: fixture.winning))
            let neighbour: Level = try Self.rebuilt(level, seed: level.seed + 1)
            XCTAssertEqual(MyceliumArchitectGrowth.report(neighbour, arrangement: play.arrangement), report)
        }
    }
}
