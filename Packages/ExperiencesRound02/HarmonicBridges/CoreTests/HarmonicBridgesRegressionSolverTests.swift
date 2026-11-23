// HarmonicBridgesRegressionSolverTests — feature 418 (R02-G12-08) T-R02G1208-002 (FR-R02G1208-001, 002;
// SC-R02G1208-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/harmonic-bridges/levels (part by part and by fingerprint); the witness's actions replay on a fresh play
// (begun, the tutorial dismissed) to a win on the last action and not before, in exactly its action count (the plan's
// tunings then one test), within the budget, with exactly its per-step bridge digests (`HarmonicBridgesWitness.digest`
// of the report after each tuning) and per-action fingerprints (after `begin`, after `dismissTutorial` when the level
// has a tutorial, and after each action); the smaller choices recounted over the solver's options equal the witness's
// counterexample (its `choices` and `size`, and for a one-tuning plan the starting pegs' break);
// `HarmonicBridgesSolver.plan` returns exactly the witness's tunings with exactly its `smallerChoices` (the
// counterexample's `choices`) and size, and its work is at most `HarmonicBridgesSolver.workBound` (counted, never
// timed).
// The 100 levels are generated concurrently once per process (through the experience core's cache) so each test stays
// short.
//
// The alterations (clarification Q2): eleven kinds, each applied to a copy of level 1, 41 or 81 and each detected by
// the checker `firstFailure`, which returns the first differing part with a message naming the level and the part
// ("level 41: budget differs …"): an island's position, a string's length, a string's starting peg, a string's
// lock, a step's tone, the threshold, the budget (each rebuilt through the level initialiser; a refused construction
// is itself named as the part); a plan tuning; a witness action, a per-action fingerprint; the smaller-choices count.
// The unaltered input gives nil. Every alteration is fixed (no random source). Explicit types, plain loops, short runs.
@testable import HarmonicBridgesCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionSolverWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/harmonic-bridges/levels", isDirectory: true)

/// The 100 certified levels in manifest order, generated concurrently once per test process (through the experience
/// core's cache).
private let regressionSolverCatalogResult: Result<[HarmonicBridgesGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? HarmonicBridgesExperienceCore.generated(number: index + 1)
    }
    var catalog: [HarmonicBridgesGenerated] = []
    for number in 1...100 { catalog.append(try HarmonicBridgesExperienceCore.generated(number: number)) }
    return catalog
}

/// A failure of the regression: the part that differs first and the message naming the level and that part.
struct HarmonicBridgesRegressionFailure: Equatable, CustomStringConvertible {
    /// The part's name, one of the names of clarification Q2 or another part of the level, witness or plan.
    let part: String
    /// The message: "level N: <part> differs (…)".
    let message: String

    /// The message.
    var description: String { message }
}

/// The independent replay of a witness's actions: the play at the end, the fingerprints, the per-step bridge digests
/// after each tuning, the tunings applied, and whether any action but the first found the play no longer playing.
struct HarmonicBridgesRegressionReplay {
    /// The play after the last action.
    let play: HarmonicBridgesPlay
    /// The fingerprints after `begin`, after `dismissTutorial` (with a tutorial) and after each action.
    let fingerprints: [String]
    /// The bridge digest of the report after every tuning, in order.
    let digests: [String]
    /// The tunings applied, in order.
    let tunings: [HarmonicBridgesTuning]
    /// Whether an action was applied to a play no longer playing.
    let endedEarly: Bool
}

@Suite struct HarmonicBridgesRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    // MARK: Helpers

    /// The stored witness of manifest number `number`, read with the plain decoder (the level re-checked; the proof is
    /// not re-run, which the regression below does itself).
    static func witness(_ number: Int) throws -> HarmonicBridgesWitness {
        let name: String = String(HarmonicBridgesGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: regressionSolverWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(HarmonicBridgesWitness.self, from: data)
    }

    /// The generated level of manifest number `number` (1 … 100) from the prewarmed catalog.
    static func generated(_ number: Int) throws -> HarmonicBridgesGenerated {
        let catalog: [HarmonicBridgesGenerated] = try regressionSolverCatalogResult.get()
        return catalog[number - 1]
    }

    /// A failure of `part` for `name` with the detail `detail`.
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> HarmonicBridgesRegressionFailure {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return HarmonicBridgesRegressionFailure(part: part, message: "\(name): \(part) differs\(suffix)")
    }

    /// The tunings of `actions`: every `.tune` in order (the witness's plan part).
    static func tunings(_ actions: [HarmonicBridgesAction]) -> [HarmonicBridgesTuning] {
        var result: [HarmonicBridgesTuning] = []
        for action in actions {
            if case .tune(let string, let peg) = action {
                result.append(HarmonicBridgesTuning(string: string, peg: peg))
            }
        }
        return result
    }

    /// The independent replay of `actions` on a fresh play of `level`, as the witness computes it: the fingerprint
    /// after `begin`, after `dismissTutorial` when the play shows a tutorial, and after each action (each applied with
    /// the current fingerprint), the `HarmonicBridgesWitness.digest` of the report after each tuning; nil when a stage
    /// event or an action is refused.
    static func replayed(_ level: HarmonicBridgesLevel,
                         _ actions: [HarmonicBridgesAction]) -> HarmonicBridgesRegressionReplay? {
        var play: HarmonicBridgesPlay = HarmonicBridgesPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var tunings: [HarmonicBridgesTuning] = []
        var endedEarly: Bool = false
        do {
            try play.handle(.begin)
            fingerprints.append(play.fingerprint)
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                if case .tune(let string, let peg) = action {
                    digests.append(HarmonicBridgesWitness.digest(play.report))
                    tunings.append(HarmonicBridgesTuning(string: string, peg: peg))
                }
            }
        } catch {
            return nil
        }
        return HarmonicBridgesRegressionReplay(play: play, fingerprints: fingerprints, digests: digests,
                                               tunings: tunings, endedEarly: endedEarly)
    }

    /// The first disagreement of `level` with its stored witness level, naming the level and the part, or nil.
    static func levelFailure(_ level: HarmonicBridgesLevel, stored: HarmonicBridgesLevel,
                             name: String) -> HarmonicBridgesRegressionFailure? {
        if level.id != stored.id { return failure(name, "id") }
        if level.seed != stored.seed { return failure(name, "seed") }
        if level.difficulty != stored.difficulty { return failure(name, "difficulty") }
        if level.islands.count != stored.islands.count {
            return failure(name, "island position", "count \(level.islands.count), witness \(stored.islands.count)")
        }
        for index in 0..<level.islands.count where level.islands[index] != stored.islands[index] {
            return failure(name, "island position", "island \(index)")
        }
        if level.strings.count != stored.strings.count {
            return failure(name, "string", "count \(level.strings.count), witness \(stored.strings.count)")
        }
        for index in 0..<level.strings.count {
            let lhs: HarmonicBridgesString = level.strings[index]
            let rhs: HarmonicBridgesString = stored.strings[index]
            if lhs.a != rhs.a || lhs.b != rhs.b { return failure(name, "string ends", "string \(index)") }
            if lhs.length != rhs.length {
                return failure(name, "string length", "string \(index): \(lhs.length), witness \(rhs.length)")
            }
            if lhs.peg != rhs.peg {
                return failure(name, "string starting peg", "string \(index): \(lhs.peg), witness \(rhs.peg)")
            }
            if lhs.locked != rhs.locked {
                return failure(name, "string lock", "string \(index): \(lhs.locked), witness \(rhs.locked)")
            }
        }
        if level.start != stored.start { return failure(name, "start") }
        if level.goal != stored.goal { return failure(name, "goal") }
        if level.steps.count != stored.steps.count {
            return failure(name, "step tone", "step count \(level.steps.count), witness \(stored.steps.count)")
        }
        for step in 0..<level.steps.count where level.steps[step] != stored.steps[step] {
            return failure(name, "step tone", "step \(step)")
        }
        if level.threshold != stored.threshold {
            return failure(name, "threshold", "\(level.threshold), witness \(stored.threshold)")
        }
        if level.budget != stored.budget {
            return failure(name, "budget", "\(level.budget), witness \(stored.budget)")
        }
        if level.tutorial != stored.tutorial { return failure(name, "tutorial") }
        if level.fingerprint != stored.fingerprint { return failure(name, "level fingerprint") }
        return nil
    }

    /// The first disagreement between `level`, its stored `witness` and the solver's `plan` for `level`, naming the
    /// level and the part; nil when the level equals the witness's level, the witness's actions replay on a fresh play
    /// to a win on the last action in exactly its action count within the budget with exactly its per-step bridge
    /// digests and per-action fingerprints, the recounted smaller choices equal the witness's counterexample, and the
    /// plan's tunings, smaller choices and size equal the witness's with work at most
    /// `HarmonicBridgesSolver.workBound`.
    /// A replay the play refuses is a named failure, never a crash. Pure.
    static func firstFailure(level: HarmonicBridgesLevel, witness: HarmonicBridgesWitness,
                             plan: HarmonicBridgesPlan?) -> HarmonicBridgesRegressionFailure? {
        let name: String = "level \(witness.number)"

        // The level against the witness's level, part by part, then by fingerprint.
        if let found: HarmonicBridgesRegressionFailure = levelFailure(level, stored: witness.level, name: name) {
            return found
        }

        // The witness's actions replayed on a fresh play: a win on the last action and not before.
        guard let run: HarmonicBridgesRegressionReplay = replayed(level, witness.actions) else {
            return failure(name, "witness action", "replay refused")
        }
        if run.endedEarly { return failure(name, "witness action", "the play ends before the last action") }
        if run.play.stage != .won {
            return failure(name, "witness action", "replay does not win (stage \(run.play.stage))")
        }
        if run.tunings.isEmpty { return failure(name, "witness action", "no tuning") }
        if witness.actions.count != run.tunings.count + 1 || witness.actions.last != .test {
            return failure(name, "witness action",
                           "count \(witness.actions.count), \(run.tunings.count) tunings + 1 test")
        }
        if run.play.actionsSpent != witness.actions.count || run.play.actionsSpent > level.budget {
            return failure(name, "budget", "spent \(run.play.actionsSpent) of \(level.budget)")
        }

        // The per-step bridge digests and per-action fingerprints.
        if run.digests.count != witness.bridgeDigests.count {
            return failure(name, "per-step bridge digest",
                           "count \(witness.bridgeDigests.count), replay \(run.digests.count)")
        }
        for index in 0..<run.digests.count where run.digests[index] != witness.bridgeDigests[index] {
            return failure(name, "per-step bridge digest", "tuning \(index + 1)")
        }
        if run.fingerprints.count != witness.fingerprints.count {
            return failure(name, "per-action fingerprint",
                           "count \(witness.fingerprints.count), replay \(run.fingerprints.count)")
        }
        for index in 0..<run.fingerprints.count where run.fingerprints[index] != witness.fingerprints[index] {
            return failure(name, "per-action fingerprint", "fingerprint \(index + 1)")
        }

        // The counterexample: its size one below the plan, every smaller choice recounted (none winning) and, for a
        // one-tuning plan, the starting pegs' break.
        let size: Int = run.tunings.count - 1
        if witness.counterexample.size != size {
            return failure(name, "smaller-choices size", "\(witness.counterexample.size), replay \(size)")
        }
        guard let recount: Int = HarmonicBridgesWitness.smallerChoices(level, size: size) else {
            return failure(name, "smaller-choices count", "a smaller choice wins or the recount exceeds the bound")
        }
        if recount != witness.counterexample.choices {
            return failure(name, "smaller-choices count", "\(witness.counterexample.choices), recount \(recount)")
        }
        let start: HarmonicBridgesBreak? = size == 0 ? level.firstBreak(level.report(pegs: level.startingPegs)) : nil
        if witness.counterexample.start != start { return failure(name, "counterexample start") }

        // The solver: exactly the witness's tunings, smaller choices and size; work within the bound.
        guard let plan: HarmonicBridgesPlan = plan else {
            return failure(name, "plan tuning", "the solver finds no plan")
        }
        if plan.tunings.count != run.tunings.count {
            return failure(name, "plan tuning", "count \(plan.tunings.count), witness \(run.tunings.count)")
        }
        for index in 0..<plan.tunings.count where plan.tunings[index] != run.tunings[index] {
            return failure(name, "plan tuning", "tuning \(index + 1)")
        }
        if HarmonicBridgesSolver.actions(plan) != witness.actions {
            return failure(name, "witness action", "not the plan's actions")
        }
        if plan.smallerChoices != witness.counterexample.choices {
            return failure(name, "smaller-choices count",
                           "plan \(plan.smallerChoices), witness \(witness.counterexample.choices)")
        }
        if plan.tunings.count - 1 != witness.counterexample.size {
            return failure(name, "smaller-choices size", "plan \(plan.tunings.count - 1)")
        }
        if plan.work > HarmonicBridgesSolver.workBound {
            return failure(name, "solver work", "\(plan.work) exceeds \(HarmonicBridgesSolver.workBound)")
        }
        if plan.work != witness.difficulty.work {
            return failure(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)")
        }
        return nil
    }

    /// Checks level `number` of group `group` (levels 10·(group − 1) + 1 … 10·group): one level per argument.
    static func check(group: Int, index: Int) throws {
        let number: Int = (group - 1) * 10 + index + 1
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        let generated: HarmonicBridgesGenerated = try generated(number)
        let witness: HarmonicBridgesWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: HarmonicBridgesPlan? = HarmonicBridgesSolver.plan(generated.level)
        let found: HarmonicBridgesRegressionFailure? = firstFailure(level: generated.level, witness: witness,
                                                                    plan: plan)
        #expect(found == nil, Comment(rawValue: found?.message ?? ""))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= HarmonicBridgesSolver.workBound,
                "level \(number): solver work above the bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1208-001; SC-R02G1208-001; Q1)

    @Test(arguments: Array(0..<10)) func group01(index: Int) throws { try Self.check(group: 1, index: index) }
    @Test(arguments: Array(0..<10)) func group02(index: Int) throws { try Self.check(group: 2, index: index) }
    @Test(arguments: Array(0..<10)) func group03(index: Int) throws { try Self.check(group: 3, index: index) }
    @Test(arguments: Array(0..<10)) func group04(index: Int) throws { try Self.check(group: 4, index: index) }
    @Test(arguments: Array(0..<10)) func group05(index: Int) throws { try Self.check(group: 5, index: index) }
    @Test(arguments: Array(0..<10)) func group06(index: Int) throws { try Self.check(group: 6, index: index) }
    @Test(arguments: Array(0..<10)) func group07(index: Int) throws { try Self.check(group: 7, index: index) }
    @Test(arguments: Array(0..<10)) func group08(index: Int) throws { try Self.check(group: 8, index: index) }
    @Test(arguments: Array(0..<10)) func group09(index: Int) throws { try Self.check(group: 9, index: index) }
    @Test(arguments: Array(0..<10)) func group10(index: Int) throws { try Self.check(group: 10, index: index) }

    // MARK: Alterations (FR-R02G1208-002; SC-R02G1208-002; clarification Q2)

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: HarmonicBridgesLevel, islands: [HarmonicBridgesIsland]? = nil,
                        strings: [HarmonicBridgesString]? = nil, steps: [[HarmonicBridgesTone]]? = nil,
                        threshold: Int? = nil, budget: Int? = nil) throws -> HarmonicBridgesLevel {
        try HarmonicBridgesLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                                 islands: islands ?? level.islands, strings: strings ?? level.strings,
                                 start: level.start, goal: level.goal, steps: steps ?? level.steps,
                                 threshold: threshold ?? level.threshold, budget: budget ?? level.budget,
                                 tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: HarmonicBridgesWitness, actions: [HarmonicBridgesAction]? = nil,
                        fingerprints: [String]? = nil,
                        counterexample: HarmonicBridgesCounterexample? = nil) -> HarmonicBridgesWitness {
        HarmonicBridgesWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                               bridgeDigests: witness.bridgeDigests,
                               fingerprints: fingerprints ?? witness.fingerprints,
                               counterexample: counterexample ?? witness.counterexample,
                               difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// One more within `range`, or one less at its upper end.
    static func nudged(_ value: Int, within range: ClosedRange<Int>) -> Int {
        value < range.upperBound ? value + 1 : value - 1
    }

    /// String `index` of `level` with the given parts replaced.
    static func string(_ level: HarmonicBridgesLevel, _ index: Int, length: Int? = nil, peg: Int? = nil,
                       locked: Bool? = nil) -> HarmonicBridgesString {
        let entry: HarmonicBridgesString = level.strings[index]
        return HarmonicBridgesString(a: entry.a, b: entry.b, length: length ?? entry.length, peg: peg ?? entry.peg,
                                     locked: locked ?? entry.locked)
    }

    /// The strings with string 0 replaced by `replacement`.
    static func strings(_ level: HarmonicBridgesLevel,
                        first replacement: HarmonicBridgesString) -> [HarmonicBridgesString] {
        var strings: [HarmonicBridgesString] = level.strings
        strings[0] = replacement
        return strings
    }

    /// The islands with island 0 moved to the first grid cell (row by row) that no island occupies.
    static func islandsAltered(_ level: HarmonicBridgesLevel) -> [HarmonicBridgesIsland] {
        var islands: [HarmonicBridgesIsland] = level.islands
        for y in HarmonicBridgesLevel.rows {
            for x in HarmonicBridgesLevel.columns {
                let cell: HarmonicBridgesIsland = HarmonicBridgesIsland(x: x, y: y)
                if !islands.contains(cell) {
                    islands[0] = cell
                    return islands
                }
            }
        }
        return islands
    }

    /// The steps with step 0's first tone moved to the lowest frequency that step does not sound (strength kept).
    static func stepsAltered(_ level: HarmonicBridgesLevel) -> [[HarmonicBridgesTone]] {
        var steps: [[HarmonicBridgesTone]] = level.steps
        let heard: [Int] = steps[0].map(\.frequency)
        for frequency in HarmonicBridgesLevel.frequencies where !heard.contains(frequency) {
            steps[0][0] = HarmonicBridgesTone(frequency: frequency, strength: steps[0][0].strength)
            return steps
        }
        return steps
    }

    /// The level alteration of `part` checked against `witness`: the copy built by `build`, or a construction the level
    /// rules refuse, which is itself a failure naming `part`.
    static func levelAlterationFailure(part: String, number: Int, witness: HarmonicBridgesWitness,
                                       plan: HarmonicBridgesPlan?,
                                       build: () throws -> HarmonicBridgesLevel) -> HarmonicBridgesRegressionFailure? {
        let copy: HarmonicBridgesLevel
        do {
            copy = try build()
        } catch {
            return failure("level \(number)", part, "the level rules refuse the copy: \(error)")
        }
        if copy.fingerprint == witness.level.fingerprint {
            return HarmonicBridgesRegressionFailure(part: "unchanged", message: "level \(number): \(part) unchanged")
        }
        return firstFailure(level: copy, witness: witness, plan: plan)
    }

    /// Records an issue unless `found` names exactly `part` in a message naming level `number` and the part.
    static func expectNamed(_ found: HarmonicBridgesRegressionFailure?, number: Int, part: String) {
        let message: String = found?.message ?? "(none)"
        #expect(found?.part == part, "level \(number) alteration \(part): found \"\(message)\"")
        #expect(message.hasPrefix("level \(number): \(part) differs"),
                "level \(number) alteration \(part): \"\(message)\" does not name the level and the part")
    }

    /// The unaltered level, witness and plan are clean, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: HarmonicBridgesLevel = try Self.generated(number).level
        let witness: HarmonicBridgesWitness = try Self.witness(number)
        let found: HarmonicBridgesRegressionFailure? = Self.firstFailure(level: level, witness: witness,
                                                                         plan: HarmonicBridgesSolver.plan(level))
        #expect(found == nil, "level \(number): \(found?.message ?? "")")
    }

    /// Level alterations: an island's position, a string's length, a string's starting peg, a string's lock, a step's
    /// tone, the threshold and the budget, each rebuilt through the level initialiser and named exactly. The level is
    /// compared first, so the unaltered plan is passed and no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: HarmonicBridgesGenerated = try Self.generated(number)
        let level: HarmonicBridgesLevel = generated.level
        let witness: HarmonicBridgesWitness = try Self.witness(number)
        let plan: HarmonicBridgesPlan = generated.plan
        let first: HarmonicBridgesString = level.strings[0]

        let island: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "island position", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, islands: Self.islandsAltered(level))
            }
        Self.expectNamed(island, number: number, part: "island position")

        let length: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "string length", number: number, witness: witness, plan: plan) {
                let altered: Int = Self.nudged(first.length, within: HarmonicBridgesLevel.lengths)
                return try Self.rebuilt(level, strings: Self.strings(level, first: Self.string(level, 0,
                                                                                               length: altered)))
            }
        Self.expectNamed(length, number: number, part: "string length")

        let peg: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "string starting peg", number: number, witness: witness, plan: plan) {
                let altered: Int = Self.nudged(first.peg, within: HarmonicBridgesLevel.pegs)
                return try Self.rebuilt(level, strings: Self.strings(level, first: Self.string(level, 0, peg: altered)))
            }
        Self.expectNamed(peg, number: number, part: "string starting peg")

        let lock: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "string lock", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, strings: Self.strings(level, first: Self.string(level, 0,
                                                                                        locked: !first.locked)))
            }
        Self.expectNamed(lock, number: number, part: "string lock")

        let tone: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "step tone", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, steps: Self.stepsAltered(level))
            }
        Self.expectNamed(tone, number: number, part: "step tone")

        let threshold: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "threshold", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level,
                                 threshold: Self.nudged(level.threshold, within: HarmonicBridgesLevel.thresholds))
            }
        Self.expectNamed(threshold, number: number, part: "threshold")

        let budget: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "budget", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, budget: Self.nudged(level.budget, within: HarmonicBridgesLevel.budgets))
            }
        Self.expectNamed(budget, number: number, part: "budget")
    }

    /// A refused level construction is named too: a string length one above the longest allowed is refused by the
    /// level rules and reported as the string length.
    @Test func aRefusedLevelConstructionIsNamed() throws {
        let number: Int = 41
        let generated: HarmonicBridgesGenerated = try Self.generated(number)
        let level: HarmonicBridgesLevel = generated.level
        let witness: HarmonicBridgesWitness = try Self.witness(number)
        let tooLong: Int = HarmonicBridgesLevel.lengths.upperBound + 1
        let found: HarmonicBridgesRegressionFailure? =
            Self.levelAlterationFailure(part: "string length", number: number, witness: witness, plan: generated.plan) {
                try Self.rebuilt(level, strings: Self.strings(level, first: Self.string(level, 0, length: tooLong)))
            }
        Self.expectNamed(found, number: number, part: "string length")
        #expect(found?.message.contains("refuse") == true, "level \(number): \(found?.message ?? "(none)")")
    }

    /// The plan alteration: the solver's first tuning set to another peg (one more, or one less at peg 12).
    @Test(arguments: alteredNumbers) func planTuningAlterationIsNamed(number: Int) throws {
        let level: HarmonicBridgesLevel = try Self.generated(number).level
        let witness: HarmonicBridgesWitness = try Self.witness(number)
        let plan: HarmonicBridgesPlan? = HarmonicBridgesSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: HarmonicBridgesPlan = plan else { return }
        var tunings: [HarmonicBridgesTuning] = plan.tunings
        let other: Int = Self.nudged(tunings[0].peg, within: HarmonicBridgesLevel.pegs)
        tunings[0] = HarmonicBridgesTuning(string: tunings[0].string, peg: other)
        let copy: HarmonicBridgesPlan = HarmonicBridgesPlan(tunings: tunings, smallerChoices: plan.smallerChoices,
                                                            work: plan.work)
        #expect(copy != plan, "level \(number): plan unchanged")
        Self.expectNamed(Self.firstFailure(level: level, witness: witness, plan: copy), number: number,
                         part: "plan tuning")
    }

    /// Witness alterations: an action, a per-action fingerprint and the smaller-choices count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: HarmonicBridgesLevel = try Self.generated(number).level
        let witness: HarmonicBridgesWitness = try Self.witness(number)
        let plan: HarmonicBridgesPlan? = HarmonicBridgesSolver.plan(level)
        var parts: [String] = []
        var copies: [HarmonicBridgesWitness] = []

        // A witness action: the final test replaced by the first tuning again, a no-op the play refuses, so the
        // altered actions never win.
        var actions: [HarmonicBridgesAction] = witness.actions
        actions[actions.count - 1] = actions[0]
        #expect(!HarmonicBridgesSolver.wins(level, actions: actions), "level \(number): the altered actions win")
        parts.append("witness action")
        copies.append(Self.rebuilt(witness, actions: actions))

        // A per-action fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        parts.append("per-action fingerprint")
        copies.append(Self.rebuilt(witness, fingerprints: fingerprints))

        // The smaller-choices count: the counterexample's choices one more.
        let counterexample: HarmonicBridgesCounterexample =
            HarmonicBridgesCounterexample(size: witness.counterexample.size,
                                          choices: witness.counterexample.choices + 1,
                                          start: witness.counterexample.start)
        parts.append("smaller-choices count")
        copies.append(Self.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 3)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: HarmonicBridgesWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: level, witness: copy, plan: plan), number: number, part: part)
        }
    }
}
