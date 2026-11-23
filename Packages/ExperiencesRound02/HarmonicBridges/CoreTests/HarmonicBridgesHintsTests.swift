// HarmonicBridgesHintsTests — feature 415 (R02-G12-05) T-R02G1205-002 (FR-R02G1205-002, 003, 007; SC-R02G1205-002,
// 003; clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (certified once per process
// through the adapter's cache, prewarmed concurrently): on every level `plan(_:pegs:)` at the starting pegs equals
// `plan(_:)`, the hint plan from the opening is the certified witness and following exact hints (re-asked after every
// action) wins spending exactly the witness's actions, within the budget, in 10 groups of 10 levels; 200 seeded reachable
// states (seed 2_415, 20 groups of 10: certified tunings, then random tunings, tests and undos, a failing action undone,
// about one in five paused) get a hint the kernel accepts, from every state with a plan following hints wins within the
// actions left, and a hint never changes the play; a level whose budget is the certified tuning count is stuck; the
// three hint levels read as clarification Q1 says; loading, tutorial, won and result-after-win plays get no hint,
// failed ones `stuck`; 500 seeded failures (random tunings and tests, some undone and redone, 10 groups of 50) are
// explained with the true action, step, string and counts tracked independently here. Deterministic, explicit types,
// plain loops.
@testable import HarmonicBridgesCore
import Foundation
import Testing
import VisualCoreSimulation

/// The 100 certified levels and plans in manifest order, certified concurrently once per test process.
private let hintCatalogResult: Result<[HarmonicBridgesGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? HarmonicBridgesExperienceCore.generated(number: index + 1)
    }
    var catalog: [HarmonicBridgesGenerated] = []
    for number in 1...100 { catalog.append(try HarmonicBridgesExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [HarmonicBridgesGenerated] { try hintCatalogResult.get() }

/// Follows exact (level 3) hints from `start` (resumed when paused) until the play ends; the problems found (empty:
/// won, every hinted action accepted, the play unchanged by every hint) and the actions spent following them.
private func followHints(_ start: HarmonicBridgesPlay, label: String) -> (problems: [String], spent: Int) {
    var play: HarmonicBridgesPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<64 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: HarmonicBridgesPlay = play
        guard let hint = HarmonicBridgesHints.hint(level: 3, play: play) else {
            return (["\(label): no hint in \(play.stage)"], play.actionsSpent - spentBefore)
        }
        guard play == before else { return (["\(label): the hint changed the play"], play.actionsSpent - spentBefore) }
        guard let action = hint.action else {
            return (["\(label): stuck with \(play.actionsLeft) actions left"], play.actionsSpent - spentBefore)
        }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], play.actionsSpent - spentBefore)
        }
    }
    return (play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"], play.actionsSpent - spentBefore)
}

/// A random action on `play`: a tuning of a random string to a random other peg (three in four), else the test.
private func randomAction(_ play: HarmonicBridgesPlay, _ random: inout SeededRandom,
                          tests: Bool = true) -> HarmonicBridgesAction {
    if tests && random.int(0...3) == 0 { return .test }
    let string: Int = random.int(0...(play.level.strings.count - 1))
    var peg: Int = random.int(1...11)
    if peg >= play.pegs[string] { peg += 1 }
    return .tune(string, peg)
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: HarmonicBridgesPlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_415): from a certified opening, 0 … plan − 1 certified tunings (so many states
/// stay on the certified path), then 0 … 6 random steps — a random tuning or a test (most often) or an undo — where a
/// refused action is skipped, an action that fails the play is undone and a won play is drawn again; about one in five
/// samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [HarmonicBridgesGenerated] = try hintCatalog()
    var random = SeededRandom(seed: HarmonicBridgesHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        let generated: HarmonicBridgesGenerated = catalog[number - 1]
        var play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: generated.level)
        let certified: Int = random.int(0...(generated.plan.tunings.count - 1))
        for index in 0..<certified {
            let tuning: HarmonicBridgesTuning = generated.plan.tunings[index]
            try play.apply(.tune(tuning.string, tuning.peg), expecting: play.fingerprint)
        }
        let steps: Int = random.int(0...6)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            if random.int(0...4) == 0 {
                if play.canUndo { try play.undo() }
                continue
            }
            let action: HarmonicBridgesAction = randomAction(play, &random)
            do {
                try play.apply(action, expecting: play.fingerprint)
            } catch {
                continue
            }
            if play.stage == .failed { try play.undo() }
        }
        guard play.stage == .playing else { continue }
        if random.int(0...4) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// What the test expects of one failure, tracked without the play's own stacks.
private struct ExpectedFailure {
    let failure: HarmonicBridgesFailure
    let action: Int
    let text: String
}

/// The expected explanation of the failure after `applied` (the actions still applied, the failing one last) on
/// `level` at `pegs` (the pegs after them): the failing index is the last applied one, the failure a broken test (the
/// level's break at those pegs) or the budget, the steps reached counted from the level's report at those pegs.
private func expectedFailure(_ level: HarmonicBridgesLevel, applied: [HarmonicBridgesAction],
                             pegs: [Int]) -> ExpectedFailure? {
    guard let failing = applied.last else { return nil }
    let index: Int = applied.count - 1
    let report: HarmonicBridgesReport = level.report(pegs: pegs)
    var reached: Int = 0
    for step in 0..<level.steps.count where report.reached[step][level.goal] { reached += 1 }
    let tail: String = ": the start reached the goal in \(reached) of \(level.steps.count) steps. "
        + "Undo the last action or retry the level."
    switch failing {
    case .test:
        guard let broken = level.firstBreak(report) else { return nil }
        let failure: HarmonicBridgesFailure = .broken(step: broken.step, string: broken.string)
        let place: String
        if let string = broken.string {
            place = "in step \(broken.step) at string \(string)"
        } else {
            place = "in step \(broken.step): no string reaches across"
        }
        return ExpectedFailure(failure: failure, action: index,
                               text: "Action \(index + 1) (the test) broke the crossing \(place)\(tail)")
    case .tune(let string, let peg):
        return ExpectedFailure(failure: .budget(index), action: index,
                               text: "Action \(index + 1) (a tuning of string \(string) to peg \(peg)) spent the last "
                                   + "move without a win\(tail)")
    }
}

@Suite struct HarmonicBridgesHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_415

    // MARK: Openings

    /// On every certified level (10 groups of 10): `plan(_:pegs:)` at the starting pegs equals `plan(_:)` and the
    /// certified plan; the hint plan from the opening is the certified witness; following exact hints wins spending
    /// exactly the witness's actions, within the budget.
    @Test(arguments: Array(0..<10))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let catalog: [HarmonicBridgesGenerated] = try hintCatalog()
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: HarmonicBridgesGenerated = catalog[number - 1]
            let level: HarmonicBridgesLevel = generated.level
            let atStart: HarmonicBridgesPlan? = HarmonicBridgesSolver.plan(level, pegs: level.startingPegs)
            #expect(atStart == HarmonicBridgesSolver.plan(level), "level \(number)")
            #expect(atStart == generated.plan, "level \(number)")
            let opening: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: level)
            let witness: [HarmonicBridgesAction] = HarmonicBridgesSolver.actions(generated.plan)
            #expect(HarmonicBridgesHints.plan(opening)?.actions == witness, "level \(number)")
            let hint: HarmonicBridgesHint? = HarmonicBridgesHints.hint(level: 3, play: opening)
            #expect(hint?.kind == .tune && hint?.action == witness.first, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)")
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == witness.count && outcome.spent <= level.budget, "level \(number)")
        }
    }

    /// `plan(_:pegs:)` refuses pegs of the wrong count or outside 1 … 12, and on a level copy at other pegs it is the
    /// plan of that copy (locks kept).
    @Test func planAtPegsChecksThePegs() throws {
        let generated: HarmonicBridgesGenerated = try hintCatalog()[10]
        let level: HarmonicBridgesLevel = generated.level
        var short: [Int] = level.startingPegs
        short.removeLast()
        #expect(HarmonicBridgesSolver.plan(level, pegs: short) == nil)
        var zero: [Int] = level.startingPegs
        zero[0] = 0
        #expect(HarmonicBridgesSolver.plan(level, pegs: zero) == nil)
        var thirteen: [Int] = level.startingPegs
        thirteen[0] = 13
        #expect(HarmonicBridgesSolver.plan(level, pegs: thirteen) == nil)
        var tuned: [Int] = level.startingPegs
        for tuning in generated.plan.tunings { tuned[tuning.string] = tuning.peg }
        let won: HarmonicBridgesPlan? = HarmonicBridgesSolver.plan(level, pegs: tuned)
        #expect(won?.tunings.isEmpty == true, "the certified pegs already win")
        let copy: HarmonicBridgesLevel? = HarmonicBridgesSolver.level(level, pegs: tuned)
        #expect(copy?.startingPegs == tuned)
        if let copy {
            for index in copy.strings.indices { #expect(copy.strings[index].locked == level.strings[index].locked) }
        }
    }

    // MARK: Seeded reachable states

    /// 200 seeded reachable states (20 groups of 10): the hint (exact level) is an action the kernel accepts whenever a
    /// plan exists, the hint plan fits the actions left, following hints wins within them, and no hint changes the play.
    @Test(arguments: Array(0..<20))
    func seededStatesGetAcceptedHints(group: Int) throws {
        let samples: [HintSample] = try hintSamples()
        var stuck: Int = 0
        for offset in 0..<10 {
            let sample: HintSample = samples[10 * group + offset]
            let label: String = "sample \(10 * group + offset) (level \(sample.number))"
            let play: HarmonicBridgesPlay = sample.play
            let plan: HarmonicBridgesHintPlan? = HarmonicBridgesHints.plan(play)
            guard let hint = HarmonicBridgesHints.hint(level: 3, play: play) else {
                Issue.record("\(label): no hint while \(play.stage)")
                continue
            }
            #expect(play == sample.play, "\(label): the hint changed the play")
            guard let plan, let action = hint.action else {
                #expect(plan == nil && hint.kind == .stuck && hint.text == HarmonicBridgesHint.stuckText, "\(label)")
                stuck += 1
                continue
            }
            #expect(plan.actions.first == action && plan.actions.count <= play.actionsLeft, "\(label)")
            #expect(plan.actions.last == .test, "\(label)")
            var copy: HarmonicBridgesPlay = play
            if copy.stage == .paused { try copy.handle(.resume) }
            do {
                try copy.apply(action, expecting: copy.fingerprint)
            } catch {
                Issue.record("\(label): hinted \(action) refused: \(error)")
            }
            let outcome: (problems: [String], spent: Int) = followHints(play, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == plan.actions.count && outcome.spent <= play.actionsLeft, "\(label)")
        }
        print("HarmonicBridgesHintsTests seeded group \(group): \(stuck) stuck of 10")
    }

    // MARK: Texts and stages

    /// A level whose budget is its certified tuning count has no plan at the opening: the hint is `stuck` with the
    /// stuck text at every level, and the play is unchanged.
    @Test func tooFewActionsLeftIsStuck() throws {
        let generated: HarmonicBridgesGenerated = try hintCatalog()[20]
        let source: HarmonicBridgesLevel = generated.level
        let level: HarmonicBridgesLevel = try HarmonicBridgesLevel(
            id: source.id, seed: source.seed, difficulty: source.difficulty, islands: source.islands,
            strings: source.strings, start: source.start, goal: source.goal, steps: source.steps,
            threshold: source.threshold, budget: generated.plan.tunings.count, tutorial: source.tutorial)
        let play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: level)
        #expect(HarmonicBridgesHints.plan(play) == nil)
        for hintLevel in 1...3 {
            let hint: HarmonicBridgesHint? = HarmonicBridgesHints.hint(level: hintLevel, play: play)
            #expect(hint?.kind == .stuck && hint?.action == nil)
            #expect(hint?.text
                    == "No way to win was found in the moves left: undo the last action or retry the level.")
        }
        #expect(play == (try HarmonicBridgesExperienceCore.freshPlay(of: level)))
    }

    /// The three hint levels read as clarification Q1 says, for a tuning and for the test, and `at(level:)` reveals the
    /// same suggestion at another level.
    @Test func hintLevelsReadAsClarified() throws {
        let generated: HarmonicBridgesGenerated = try hintCatalog()[0]
        var play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: generated.level)
        let first: HarmonicBridgesTuning = generated.plan.tunings[0]
        let tune: [String] = ["Tune a string so that more steps are bridged", "Tune string \(first.string)",
                              "Tune string \(first.string) to peg \(first.peg)"]
        for hintLevel in 1...3 {
            let hint: HarmonicBridgesHint? = HarmonicBridgesHints.hint(level: hintLevel, play: play)
            #expect(hint?.level == hintLevel && hint?.kind == .tune)
            #expect(hint?.action == .tune(first.string, first.peg))
            #expect(hint?.text == tune[hintLevel - 1])
        }
        #expect(HarmonicBridgesHints.hint(level: 0, play: play)?.text == tune[0])
        #expect(HarmonicBridgesHints.hint(level: 9, play: play)?.text == tune[2])
        #expect(HarmonicBridgesHints.hint(level: 1, play: play)?.at(level: 3).text == tune[2])
        for tuning in generated.plan.tunings {
            try play.apply(.tune(tuning.string, tuning.peg), expecting: play.fingerprint)
        }
        let test: [String] = ["Every step is bridged: test the crossing",
                              "Test the crossing: tap the goal or a step pip",
                              "Test the crossing: tap the goal or a step pip"]
        #expect(HarmonicBridgesHints.plan(play)?.actions == [.test])
        for hintLevel in 1...3 {
            let hint: HarmonicBridgesHint? = HarmonicBridgesHints.hint(level: hintLevel, play: play)
            #expect(hint?.kind == .test && hint?.action == .test)
            #expect(hint?.text == test[hintLevel - 1])
        }
        try play.handle(.pause)
        #expect(HarmonicBridgesHints.hint(level: 2, play: play)?.text == test[1], "a paused play gets its hint")
    }

    /// Loading and tutorial plays, won plays and results after a win get no hint; a failed play and its result get
    /// `stuck` with the failed text at every level; a playing play has no failure explanation.
    @Test func hintsByStage() throws {
        let catalog: [HarmonicBridgesGenerated] = try hintCatalog()
        let generated: HarmonicBridgesGenerated = catalog[0]
        var loading = HarmonicBridgesPlay(level: generated.level)
        #expect(HarmonicBridgesHints.hint(level: 1, play: loading) == nil)
        try loading.handle(.begin)
        #expect(generated.level.tutorial && loading.stage == .tutorial)
        #expect(HarmonicBridgesHints.hint(level: 1, play: loading) == nil)
        var play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: generated.level)
        #expect(HarmonicBridgesFailureExplanation(play: play) == nil)
        var failed: HarmonicBridgesPlay = play
        try failed.apply(.test, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        for hintLevel in 1...3 {
            let hint: HarmonicBridgesHint? = HarmonicBridgesHints.hint(level: hintLevel, play: failed)
            #expect(hint?.kind == .stuck && hint?.action == nil)
            #expect(hint?.text == "Undo the last action or retry the level.")
        }
        try failed.handle(.showResult)
        #expect(HarmonicBridgesHints.hint(level: 2, play: failed)?.text == "Undo the last action or retry the level.")
        #expect(HarmonicBridgesFailureExplanation(play: failed) != nil)
        for action in HarmonicBridgesSolver.actions(generated.plan) {
            try play.apply(action, expecting: play.fingerprint)
        }
        #expect(play.stage == .won)
        #expect(HarmonicBridgesHints.hint(level: 3, play: play) == nil)
        #expect(HarmonicBridgesHints.plan(play) == nil)
        #expect(HarmonicBridgesFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(HarmonicBridgesHints.hint(level: 3, play: play) == nil)
    }

    /// A broken test with and without a string and an exhausted budget read as clarification Q5 says.
    @Test func explanationTextsReadAsClarified() throws {
        let generated: HarmonicBridgesGenerated = try hintCatalog()[0]
        let level: HarmonicBridgesLevel = generated.level
        var play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: level)
        try play.apply(.test, expecting: play.fingerprint)
        let explanation: HarmonicBridgesFailureExplanation? = HarmonicBridgesFailureExplanation(play: play)
        #expect(explanation?.action == 0 && explanation?.failure == play.failure)
        let text: String = explanation?.text ?? ""
        #expect(text.hasPrefix("Action 1 (the test) broke the crossing in step "))
        #expect(text.hasSuffix(" steps. Undo the last action or retry the level."))
        #expect(text.contains(": the start reached the goal in "))
        // A broken test with no string across the cut: one string from the start to the goal that never bridges.
        let lone: HarmonicBridgesLevel = try HarmonicBridgesLevel(
            id: "lone", seed: 1, difficulty: 1,
            islands: [HarmonicBridgesIsland(x: 0, y: 0), HarmonicBridgesIsland(x: 3, y: 0),
                      HarmonicBridgesIsland(x: 6, y: 0)],
            strings: [HarmonicBridgesString(a: 1, b: 2, length: 1, peg: 1)], start: 0, goal: 2,
            steps: [[HarmonicBridgesTone(frequency: 1, strength: 1)]], threshold: 12, budget: 3)
        var stranded: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: lone)
        try stranded.apply(.test, expecting: stranded.fingerprint)
        #expect(stranded.failure == .broken(step: 0, string: nil))
        #expect(HarmonicBridgesFailureExplanation(play: stranded)?.text
                == "Action 1 (the test) broke the crossing in step 0: no string reaches across: the start reached the "
                + "goal in 0 of 1 steps. Undo the last action or retry the level.")
        var spent: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: lone)
        try spent.apply(.tune(0, 2), expecting: spent.fingerprint)
        try spent.apply(.tune(0, 3), expecting: spent.fingerprint)
        try spent.apply(.tune(0, 4), expecting: spent.fingerprint)
        #expect(spent.failure == .budget(2))
        #expect(HarmonicBridgesFailureExplanation(play: spent)?.text
                == "Action 3 (a tuning of string 0 to peg 4) spent the last move without a win: the start reached the "
                + "goal in 0 of 1 steps. Undo the last action or retry the level.")
    }

    // MARK: Seeded failures

    /// 500 seeded failures (10 groups of 50): random tunings and tests from certified openings (tests left out in
    /// about half the walks, so the budget runs out), with undos and redos; at each failure the explanation names the
    /// failing action, the failure (step and string or the budget) and the steps reached, tracked here without the
    /// play's stacks; a failure is undone and redone (the same explanation) or undone and the walk continued.
    @Test(arguments: Array(0..<10))
    func seededFailuresAreExplained(group: Int) throws {
        let catalog: [HarmonicBridgesGenerated] = try hintCatalog()
        var random = SeededRandom(seed: Self.seed &+ 1_000 &+ UInt64(group))
        var explained: Int = 0
        var kinds: [String: Int] = [:]
        while explained < 50 {
            let generated: HarmonicBridgesGenerated = catalog[random.int(0...99)]
            let level: HarmonicBridgesLevel = generated.level
            var play: HarmonicBridgesPlay = try HarmonicBridgesExperienceCore.freshPlay(of: level)
            let tests: Bool = random.int(0...1) == 0
            var applied: [HarmonicBridgesAction] = []
            var pegsStack: [[Int]] = [level.startingPegs]
            var undoneActions: [HarmonicBridgesAction] = []
            var undonePegs: [[Int]] = []
            var walking: Bool = true
            var guardSteps: Int = 0
            while walking && explained < 50 && guardSteps < 400 {
                guardSteps += 1
                if play.stage == .won { break }
                let roll: Int = random.int(0...9)
                if roll == 0 && play.canUndo {
                    try play.undo()
                    undoneActions.append(applied.removeLast())
                    undonePegs.append(pegsStack.removeLast())
                    continue
                }
                if roll == 1 && play.canRedo {
                    try play.redo()
                    applied.append(undoneActions.removeLast())
                    pegsStack.append(undonePegs.removeLast())
                } else {
                    let action: HarmonicBridgesAction = randomAction(play, &random, tests: tests)
                    do {
                        try play.apply(action, expecting: play.fingerprint)
                    } catch {
                        continue
                    }
                    var pegs: [Int] = pegsStack[pegsStack.count - 1]
                    if case .tune(let string, let peg) = action { pegs[string] = peg }
                    applied.append(action)
                    pegsStack.append(pegs)
                    undoneActions.removeAll()
                    undonePegs.removeAll()
                }
                guard play.stage == .failed else { continue }
                let expected: ExpectedFailure? = expectedFailure(level, applied: applied,
                                                                 pegs: pegsStack[pegsStack.count - 1])
                let explanation: HarmonicBridgesFailureExplanation? = HarmonicBridgesFailureExplanation(play: play)
                #expect(expected != nil && explanation?.failure == expected?.failure, "\(level.id)")
                #expect(explanation?.action == expected?.action, "\(level.id)")
                #expect(explanation?.text == expected?.text, "\(level.id)")
                #expect(play.failure == expected?.failure, "\(level.id)")
                explained += 1
                switch expected?.failure {
                case .broken(_, let string)?: kinds[string == nil ? "broken-none" : "broken", default: 0] += 1
                case .budget?: kinds["budget", default: 0] += 1
                case nil: kinds["none", default: 0] += 1
                }
                let next: Int = random.int(0...2)
                if next == 0 {
                    try play.undo()
                    try play.redo()
                    #expect(HarmonicBridgesFailureExplanation(play: play) == explanation, "\(level.id): after redo")
                    walking = false
                } else if next == 1 {
                    try play.undo()
                    undoneActions.append(applied.removeLast())
                    undonePegs.append(pegsStack.removeLast())
                } else {
                    walking = false
                }
            }
        }
        #expect(kinds["budget", default: 0] > 0 && kinds["broken", default: 0] > 0, "\(kinds)")
        print("HarmonicBridgesHintsTests failures group \(group): \(kinds)")
    }
}
