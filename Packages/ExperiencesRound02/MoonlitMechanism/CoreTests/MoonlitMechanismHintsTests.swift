// MoonlitMechanismHintsTests — feature 435 (R02-G14-05) T-R02G1405-002 (FR-R02G1405-002, 003, 007; SC-R02G1405-002,
// 003; clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (certified once per process
// through the experience core's cache, prewarmed concurrently): on every level `plan(_:phases:height:)` at the starting
// phases and height equals `plan(_:)` and the certified plan, the hint plan from the opening is the certified witness's
// actions (turns, re-seats in gear order, lamp steps, the run) and following exact hints (re-asked after every action)
// wins spending exactly the witness's actions, within the budget, in 10 groups of 10 levels; the new solver entry
// refuses malformed phases, heights and caps; 200 seeded reachable states (seed 2_435, 20 groups of 10: certified
// actions, then random turns, re-seats, lamp steps, runs and undos, a failing action undone, about one in five paused)
// get a hint the kernel accepts, from every state with a plan following hints wins within the actions left, and a hint
// never changes the play; a level whose budget is the certified plan size has no plan; the three hint levels read as
// clarification Q1 says; loading, tutorial, won and result-after-win plays get no hint, failed ones `stuck`; every
// failure kind reads as clarification Q5 says (singular forms included); 500 seeded failures (random actions, some
// undone and redone, 10 groups of 50) are explained with the true action and numbers tracked independently here.
// Deterministic, explicit types, plain loops.
import Foundation
@testable import MoonlitMechanismCore
import Testing
import VisualCoreSimulation

/// The 100 certified levels and plans in manifest order, certified concurrently once per test process.
private let hintCatalogResult: Result<[MoonlitMechanismGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? MoonlitMechanismExperienceCore.generated(number: index + 1)
    }
    var catalog: [MoonlitMechanismGenerated] = []
    for number in 1...100 { catalog.append(try MoonlitMechanismExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [MoonlitMechanismGenerated] { try hintCatalogResult.get() }

/// Follows exact (level 3) hints from `start` (resumed when paused) until the play ends; the problems found (empty:
/// won, every hinted action accepted, the play unchanged by every hint) and the actions spent following them.
private func followHints(_ start: MoonlitMechanismPlay, label: String) -> (problems: [String], spent: Int) {
    var play: MoonlitMechanismPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<64 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: MoonlitMechanismPlay = play
        guard let hint = MoonlitMechanismHints.hint(level: 3, play: play) else {
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

/// A random action on `play`: a turn by ±1, a re-seat of a random gear other than the driver by ±1, a lamp step by ±1
/// or (when `runs`) a run. The kernel may refuse it (a lamp step out of range).
private func randomAction(_ play: MoonlitMechanismPlay, _ random: inout SeededRandom,
                          runs: Bool = true) -> MoonlitMechanismAction {
    let n: Int = play.level.gears.count
    let roll: Int = random.int(0...(runs ? 7 : 6))
    let step: Int = random.int(0...1) == 0 ? -1 : 1
    if roll == 7 { return .run }
    if roll <= 1 { return .turn(step) }
    if roll <= 4 { return .reseat(random.int(1...(n - 1)), step) }
    return .lamp(step)
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: MoonlitMechanismPlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_435): from a certified opening, 0 … witness − 2 certified witness actions (so
/// many states stay on the certified path), then 0 … 6 random steps — a random turn, re-seat, lamp step or run (most
/// often) or an undo — where a refused action is skipped, an action that fails the play is undone and a won play is
/// drawn again; about one in five samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [MoonlitMechanismGenerated] = try hintCatalog()
    var random = SeededRandom(seed: MoonlitMechanismHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        let generated: MoonlitMechanismGenerated = catalog[number - 1]
        var play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: generated.level)
        let witness: [MoonlitMechanismAction] = generated.actions
        let certified: Int = random.int(0...(witness.count - 2))
        for index in 0..<certified { try play.apply(witness[index], expecting: play.fingerprint) }
        let steps: Int = random.int(0...6)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            if random.int(0...4) == 0 {
                if play.canUndo { try play.undo() }
                continue
            }
            let action: MoonlitMechanismAction = randomAction(play, &random)
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

/// "n <noun>s", or "1 <noun>" when n is 1 (the test's own wording of clarification Q5's counts).
private func counted(_ value: Int, _ singular: String, _ plural: String) -> String {
    value == 1 ? "1 " + singular : "\(value) " + plural
}

/// The signed step of an action as clarification Q5 writes it: "+1" or "−1" (U+2212).
private func signed(_ step: Int) -> String { step < 0 ? "\u{2212}1" : "+1" }

/// What the test expects of one failure, tracked without the play's own stacks.
private struct ExpectedFailure {
    let failure: MoonlitMechanismFailure
    let action: Int
    let text: String
}

/// The expected explanation of the failure after `applied` (the actions still applied, the failing one last) on
/// `level` with `phases` and `height` (after them): a run fails as the level's run of that set-up says, any other
/// action spends the budget.
private func expectedFailure(_ level: MoonlitMechanismLevel, applied: [MoonlitMechanismAction], phases: [Int],
                             height: Int) -> ExpectedFailure? {
    guard let failing = applied.last else { return nil }
    let index: Int = applied.count - 1
    let head: String = "Action \(index + 1)"
    let advice: String = " Undo the last action or retry the level."
    switch failing {
    case .run:
        switch level.run(phases: phases, height: height).outcome {
        case .won:
            return nil
        case .jammed(let child):
            guard let parent = level.gears[child].parent else { return nil }
            return ExpectedFailure(failure: .jammed(child), action: index,
                                   text: "\(head) (the run): gear \(child) jammed against its parent, gear "
                                       + "\(parent).\(advice)")
        case .forbidden(let frame, let cell):
            return ExpectedFailure(failure: .forbidden(frame: frame, cell: cell), action: index,
                                   text: "\(head) (the run): key frame \(frame) cast a shadow on forbidden cell "
                                       + "\(cell).\(advice)")
        case .missing(let frame, let count):
            return ExpectedFailure(failure: .missing(frame: frame, count: count), action: index,
                                   text: "\(head) (the run): key frame \(frame) missed "
                                       + counted(count, "target cell", "target cells") + ".\(advice)")
        case .stray(let frame, let count):
            return ExpectedFailure(failure: .stray(frame: frame, count: count), action: index,
                                   text: "\(head) (the run): key frame \(frame) cast "
                                       + counted(count, "stray cell", "stray cells")
                                       + ", more than the \(level.allowance) allowed.\(advice)")
        }
    case .turn(let step):
        return ExpectedFailure(failure: .budget(index), action: index,
                               text: "\(head) (a turn of the handle by \(signed(step))) spent the last action "
                                   + "without a win.\(advice)")
    case .reseat(let gear, let step):
        return ExpectedFailure(failure: .budget(index), action: index,
                               text: "\(head) (a re-seat of gear \(gear) by \(signed(step))) spent the last action "
                                   + "without a win.\(advice)")
    case .lamp(let step):
        return ExpectedFailure(failure: .budget(index), action: index,
                               text: "\(head) (a lamp step by \(signed(step))) spent the last action without a "
                                   + "win.\(advice)")
    }
}

/// `level` with its budget replaced (every other value kept).
private func withBudget(_ level: MoonlitMechanismLevel, _ budget: Int) throws -> MoonlitMechanismLevel {
    try MoonlitMechanismLevel(
        id: level.id, seed: level.seed, difficulty: level.difficulty, gears: level.gears, width: level.width,
        rows: level.rows, lampHeights: level.lampHeights, startingHeight: level.startingHeight,
        keyFrames: level.keyFrames, forbidden: level.forbidden, allowance: level.allowance, budget: budget,
        tutorial: level.tutorial)
}

/// The set-up after `action` on `phases` and `height` (a run leaves it unchanged), stepped here without the play.
private func stepped(_ level: MoonlitMechanismLevel, _ action: MoonlitMechanismAction, phases: [Int],
                     height: Int) -> (phases: [Int], height: Int) {
    switch action {
    case .turn(let step):
        return (MoonlitMechanismTrain.turned(level.gears, phases: phases, by: step), height)
    case .reseat(let gear, let step):
        var next: [Int] = phases
        next[gear] = MoonlitMechanismTrain.mod(phases[gear] + step, level.gears[gear].teeth)
        return (next, height)
    case .lamp(let step):
        return (phases, height + step)
    case .run:
        return (phases, height)
    }
}

@Suite struct MoonlitMechanismHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_435

    // MARK: Openings

    /// On every certified level (10 groups of 10): `plan(_:phases:height:)` at the starting phases and height equals
    /// `plan(_:)` and the certified plan; the hint plan from the opening is the witness's actions (turns, re-seats in
    /// gear order, lamp steps, the run); following exact hints wins spending exactly the witness's actions, within the
    /// budget.
    @Test(arguments: Array(0..<10))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let catalog: [MoonlitMechanismGenerated] = try hintCatalog()
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: MoonlitMechanismGenerated = catalog[number - 1]
            let level: MoonlitMechanismLevel = generated.level
            let atStart: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(
                level, phases: level.startingPhases, height: level.startingHeight)
            #expect(atStart == MoonlitMechanismSolver.plan(level), "level \(number)")
            #expect(atStart == generated.plan, "level \(number)")
            let opening: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: level)
            let witness: [MoonlitMechanismAction] = generated.actions
            #expect(MoonlitMechanismHints.plan(opening)?.actions == witness, "level \(number)")
            let hint: MoonlitMechanismHint? = MoonlitMechanismHints.hint(level: 3, play: opening)
            #expect(hint?.action == witness.first && hint?.kind != .stuck && hint?.kind != .run, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)")
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == witness.count && outcome.spent <= level.budget, "level \(number)")
        }
    }

    /// `plan(_:phases:height:)` refuses phases of the wrong count or out of range, a height out of range and a
    /// negative cap; after the certified set-up actions the plan from that state is empty (no smaller vector).
    @Test func planFromStateChecksItsInputs() throws {
        let generated: MoonlitMechanismGenerated = try hintCatalog()[30]
        let level: MoonlitMechanismLevel = generated.level
        let start: [Int] = level.startingPhases
        var short: [Int] = start
        short.removeLast()
        #expect(MoonlitMechanismSolver.plan(level, phases: short, height: level.startingHeight) == nil)
        var tooBig: [Int] = start
        tooBig[1] = level.gears[1].teeth
        #expect(MoonlitMechanismSolver.plan(level, phases: tooBig, height: level.startingHeight) == nil)
        var negative: [Int] = start
        negative[0] = -1
        #expect(MoonlitMechanismSolver.plan(level, phases: negative, height: level.startingHeight) == nil)
        #expect(MoonlitMechanismSolver.plan(level, phases: start, height: -1) == nil)
        #expect(MoonlitMechanismSolver.plan(level, phases: start, height: level.lampHeights) == nil)
        #expect(MoonlitMechanismSolver.plan(level, phases: start, height: level.startingHeight, maxActions: -1) == nil)
        var phases: [Int] = start
        var height: Int = level.startingHeight
        for action in generated.actions where action != .run {
            let next: (phases: [Int], height: Int) = stepped(level, action, phases: phases, height: height)
            phases = next.phases
            height = next.height
        }
        let done: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(level, phases: phases, height: height)
        #expect(done?.size == 0 && done?.smallerVectors == 0)
        // One witness action in, the rest of the plan is one action shorter.
        let first: (phases: [Int], height: Int) = stepped(level, generated.actions[0], phases: start,
                                                          height: level.startingHeight)
        let rest: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(level, phases: first.phases, height: first.height)
        #expect(rest?.size == generated.plan.size - 1)
    }

    // MARK: Seeded reachable states

    /// 200 seeded reachable states (20 groups of 10): the hint (exact level) is an action the kernel accepts whenever
    /// a plan exists, the hint plan fits the actions left, following hints wins within them, and no hint changes the
    /// play.
    @Test(arguments: Array(0..<20))
    func seededStatesGetAcceptedHints(group: Int) throws {
        let samples: [HintSample] = try hintSamples()
        var stuck: Int = 0
        for offset in 0..<10 {
            let sample: HintSample = samples[10 * group + offset]
            let label: String = "sample \(10 * group + offset) (level \(sample.number))"
            let play: MoonlitMechanismPlay = sample.play
            let plan: MoonlitMechanismHintPlan? = MoonlitMechanismHints.plan(play)
            guard let hint = MoonlitMechanismHints.hint(level: 3, play: play) else {
                Issue.record("\(label): no hint while \(play.stage)")
                continue
            }
            #expect(play == sample.play, "\(label): the hint changed the play")
            guard let plan, let action = hint.action else {
                #expect(plan == nil && hint.kind == .stuck && hint.text == MoonlitMechanismHint.stuckText, "\(label)")
                stuck += 1
                continue
            }
            #expect(plan.actions.first == action && plan.actions.count <= play.actionsLeft, "\(label)")
            #expect(plan.actions.last == .run, "\(label)")
            var copy: MoonlitMechanismPlay = play
            if copy.stage == .paused { try copy.handle(.resume) }
            do {
                try copy.apply(action, expecting: copy.fingerprint)
            } catch {
                Issue.record("\(label): hinted \(action) refused: \(error)")
            }
            let outcome: (problems: [String], spent: Int) = followHints(play, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent <= plan.actions.count && outcome.spent <= play.actionsLeft, "\(label)")
        }
        print("MoonlitMechanismHintsTests seeded group \(group): \(stuck) stuck of 10")
    }

    // MARK: Texts and stages

    /// A level whose budget is its certified plan size (no room for the run) has no plan at the opening: the hint is
    /// `stuck` with the stuck text at every level, and the play is unchanged.
    @Test func tooFewActionsLeftIsStuck() throws {
        let generated: MoonlitMechanismGenerated = try hintCatalog()[20]
        let level: MoonlitMechanismLevel = try withBudget(generated.level, generated.plan.size)
        let play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: level)
        #expect(MoonlitMechanismHints.plan(play) == nil)
        for hintLevel in 1...3 {
            let hint: MoonlitMechanismHint? = MoonlitMechanismHints.hint(level: hintLevel, play: play)
            #expect(hint?.kind == .stuck && hint?.action == nil)
            #expect(hint?.text
                    == "No way to win was found in the actions left: undo the last action or retry the level.")
        }
        #expect(play == (try MoonlitMechanismExperienceCore.freshPlay(of: level)))
    }

    /// The three hint levels read as clarification Q1 says for a turn, a re-seat, a lamp step (each way) and the run;
    /// a real hint at the opening and before the run reads the same; `at(level:)` reveals the same suggestion.
    @Test func hintLevelsReadAsClarified() throws {
        let cases: [(MoonlitMechanismHintKind, MoonlitMechanismAction, [String])] = [
            (.turn, .turn(1), ["Turn the handle", "Turn the handle forward", "Turn the handle forward one tooth"]),
            (.turn, .turn(-1), ["Turn the handle", "Turn the handle back", "Turn the handle back one tooth"]),
            (.reseat, .reseat(2, 1), ["Re-seat a gear", "Work on gear 2", "Re-seat gear 2 by +1"]),
            (.reseat, .reseat(2, -1), ["Re-seat a gear", "Work on gear 2", "Re-seat gear 2 by \u{2212}1"]),
            (.lamp, .lamp(1), ["Move the lamp", "Raise the lamp", "Raise the lamp one step"]),
            (.lamp, .lamp(-1), ["Move the lamp", "Lower the lamp", "Lower the lamp one step"]),
            (.run, .run, ["The shadows are ready: run the machine", "Run: tap the lamp", "Run: tap the lamp"]),
        ]
        for (kind, action, texts) in cases {
            for hintLevel in 1...3 {
                #expect(MoonlitMechanismHint.text(level: hintLevel, kind: kind, action: action, failed: false)
                        == texts[hintLevel - 1], "\(action) level \(hintLevel)")
            }
        }
        #expect(MoonlitMechanismHint.text(level: 2, kind: .stuck, action: nil, failed: true)
                == "Undo the last action or retry the level.")
        let catalog: [MoonlitMechanismGenerated] = try hintCatalog()
        let generated: MoonlitMechanismGenerated = catalog[0]
        var play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: generated.level)
        guard let first = MoonlitMechanismHints.plan(play)?.actions.first else {
            Issue.record("no hint plan at the opening")
            return
        }
        var expected: [String] = []
        for (_, action, texts) in cases where action == first { expected = texts }
        if case .reseat(let gear, let step) = first {
            expected = ["Re-seat a gear", "Work on gear \(gear)", "Re-seat gear \(gear) by \(signed(step))"]
        }
        #expect(expected.count == 3, "\(first)")
        for hintLevel in 1...3 where expected.count == 3 {
            let hint: MoonlitMechanismHint? = MoonlitMechanismHints.hint(level: hintLevel, play: play)
            #expect(hint?.level == hintLevel && hint?.action == first)
            #expect(hint?.text == expected[hintLevel - 1])
        }
        if expected.count == 3 {
            #expect(MoonlitMechanismHints.hint(level: 0, play: play)?.text == expected[0])
            #expect(MoonlitMechanismHints.hint(level: 9, play: play)?.text == expected[2])
            #expect(MoonlitMechanismHints.hint(level: 1, play: play)?.at(level: 3).text == expected[2])
        }
        for action in generated.actions where action != .run {
            try play.apply(action, expecting: play.fingerprint)
        }
        #expect(MoonlitMechanismHints.plan(play)?.actions == [.run])
        let run: [String] = ["The shadows are ready: run the machine", "Run: tap the lamp", "Run: tap the lamp"]
        for hintLevel in 1...3 {
            let hint: MoonlitMechanismHint? = MoonlitMechanismHints.hint(level: hintLevel, play: play)
            #expect(hint?.kind == .run && hint?.action == .run)
            #expect(hint?.text == run[hintLevel - 1])
        }
        try play.handle(.pause)
        #expect(MoonlitMechanismHints.hint(level: 2, play: play)?.text == run[1], "a paused play gets its hint")
        // Every kind but the run appears as a real first hint somewhere in the catalog.
        var kinds: Set<MoonlitMechanismHintKind> = []
        for entry in catalog {
            let opening: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: entry.level)
            if let kind = MoonlitMechanismHints.hint(level: 1, play: opening)?.kind { kinds.insert(kind) }
        }
        print("MoonlitMechanismHintsTests opening hint kinds: \(kinds.map(\.rawValue).sorted())")
        #expect(!kinds.contains(.stuck) && !kinds.contains(.run))
    }

    /// Loading and tutorial plays, won plays and results after a win get no hint; a failed play and its result get
    /// `stuck` with the failed text at every level; a playing play has no failure explanation.
    @Test func hintsByStage() throws {
        let generated: MoonlitMechanismGenerated = try hintCatalog()[0]
        var loading = MoonlitMechanismPlay(level: generated.level)
        #expect(MoonlitMechanismHints.hint(level: 1, play: loading) == nil)
        try loading.handle(.begin)
        #expect(generated.level.tutorial && loading.stage == .tutorial)
        #expect(MoonlitMechanismHints.hint(level: 1, play: loading) == nil)
        #expect(MoonlitMechanismHints.plan(loading) == nil)
        var play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: generated.level)
        #expect(MoonlitMechanismFailureExplanation(play: play) == nil)
        var failed: MoonlitMechanismPlay = play
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        for hintLevel in 1...3 {
            let hint: MoonlitMechanismHint? = MoonlitMechanismHints.hint(level: hintLevel, play: failed)
            #expect(hint?.kind == .stuck && hint?.action == nil)
            #expect(hint?.text == "Undo the last action or retry the level.")
        }
        #expect(MoonlitMechanismHints.plan(failed) == nil)
        try failed.handle(.showResult)
        #expect(MoonlitMechanismHints.hint(level: 2, play: failed)?.text == "Undo the last action or retry the level.")
        #expect(MoonlitMechanismFailureExplanation(play: failed) != nil)
        for action in generated.actions { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        #expect(MoonlitMechanismHints.hint(level: 3, play: play) == nil)
        #expect(MoonlitMechanismHints.plan(play) == nil)
        #expect(MoonlitMechanismFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(MoonlitMechanismHints.hint(level: 3, play: play) == nil)
    }

    /// Every failure kind reads as clarification Q5 says: the budget after a turn, a re-seat and a lamp step (with
    /// undo and redo of the failing action), the action words of `describe(_:)`, the singular and plural counts, and a
    /// run failure of each kind found on the catalog's openings and one-action neighbours.
    @Test func explanationTextsReadAsClarified() throws {
        let catalog: [MoonlitMechanismGenerated] = try hintCatalog()
        let generated: MoonlitMechanismGenerated = catalog[0]
        let level: MoonlitMechanismLevel = generated.level
        let advice: String = " Undo the last action or retry the level."
        let tight: MoonlitMechanismLevel = try withBudget(level, 3)
        var spent: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: tight)
        try spent.apply(.turn(1), expecting: spent.fingerprint)
        try spent.apply(.turn(-1), expecting: spent.fingerprint)
        try spent.apply(.reseat(1, -1), expecting: spent.fingerprint)
        #expect(spent.failure == .budget(2))
        let reseat: MoonlitMechanismFailureExplanation? = MoonlitMechanismFailureExplanation(play: spent)
        #expect(reseat?.action == 2 && reseat?.failure == .budget(2))
        #expect(reseat?.text == "Action 3 (a re-seat of gear 1 by \u{2212}1) spent the last action without a win."
                + advice)
        try spent.undo()
        try spent.apply(.turn(1), expecting: spent.fingerprint)
        #expect(MoonlitMechanismFailureExplanation(play: spent)?.text
                == "Action 3 (a turn of the handle by +1) spent the last action without a win." + advice)
        try spent.undo()
        let lampStep: Int = tight.startingHeight + 1 < tight.lampHeights ? 1 : -1
        try spent.apply(.lamp(lampStep), expecting: spent.fingerprint)
        let lampText: String = "Action 3 (a lamp step by \(signed(lampStep))) spent the last action without a win."
            + advice
        #expect(MoonlitMechanismFailureExplanation(play: spent)?.text == lampText)
        try spent.undo()
        try spent.redo()
        #expect(MoonlitMechanismFailureExplanation(play: spent)?.text == lampText, "after undo and redo")
        #expect(MoonlitMechanismFailureExplanation.describe(.run) == "the run")
        #expect(MoonlitMechanismFailureExplanation.describe(.turn(-1)) == "a turn of the handle by \u{2212}1")
        #expect(MoonlitMechanismFailureExplanation.describe(.reseat(3, 1)) == "a re-seat of gear 3 by +1")
        #expect(MoonlitMechanismFailureExplanation.describe(.lamp(-1)) == "a lamp step by \u{2212}1")
        #expect(MoonlitMechanismFailureExplanation.count(1, "target cell") == "1 target cell")
        #expect(MoonlitMechanismFailureExplanation.count(3, "stray cell") == "3 stray cells")
        // Run failures of every kind: a run at each opening, then after each single witness action.
        var found: [String: Int] = [:]
        for entry in catalog {
            var starts: [MoonlitMechanismPlay] = []
            let opening: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: entry.level)
            starts.append(opening)
            for action in [MoonlitMechanismAction.turn(1), .turn(-1), .reseat(1, 1), .reseat(1, -1)] {
                var moved: MoonlitMechanismPlay = opening
                try moved.apply(action, expecting: moved.fingerprint)
                if moved.stage == .playing { starts.append(moved) }
            }
            for start in starts {
                var run: MoonlitMechanismPlay = start
                try run.apply(.run, expecting: run.fingerprint)
                guard run.stage == .failed, let failure = run.failure else { continue }
                let applied: [MoonlitMechanismAction] = MoonlitMechanismHints.appliedActions(run.records)
                let expected: ExpectedFailure? = expectedFailure(entry.level, applied: applied, phases: start.phases,
                                                                 height: start.height)
                let explanation: MoonlitMechanismFailureExplanation? = MoonlitMechanismFailureExplanation(play: run)
                #expect(explanation?.failure == failure && explanation?.failure == expected?.failure,
                        "\(entry.level.id)")
                #expect(explanation?.text == expected?.text, "\(entry.level.id)")
                #expect(explanation?.action == run.actionsSpent - 1, "\(entry.level.id)")
                var key: String = failure.code
                switch failure {
                case .missing(_, let count), .stray(_, let count): if count == 1 { key += "-1" }
                default: break
                }
                found[key, default: 0] += 1
            }
        }
        // Stray: the first required key frame of a level with its first k target cells (k = 1, 2) taken out and the
        // allowance 0; the witness's set-up covered them, so its run casts exactly k stray cells there.
        for entry in catalog.prefix(20) {
            let level: MoonlitMechanismLevel = entry.level
            var phases: [Int] = level.startingPhases
            var height: Int = level.startingHeight
            for action in entry.actions {
                let next: (phases: [Int], height: Int) = stepped(level, action, phases: phases, height: height)
                phases = next.phases
                height = next.height
            }
            guard let frameIndex = level.keyFrames.firstIndex(where: { $0.required && $0.target.count >= 3 }) else {
                continue
            }
            for removed in 1...2 {
                var frames: [MoonlitMechanismKeyFrame] = level.keyFrames
                let old: MoonlitMechanismKeyFrame = frames[frameIndex]
                let kept: [Int] = Array(old.target.dropFirst(removed))
                frames[frameIndex] = MoonlitMechanismKeyFrame(turns: old.turns, target: kept, required: true)
                guard let lowered = try? MoonlitMechanismLevel(
                    id: level.id, seed: level.seed, difficulty: level.difficulty, gears: level.gears,
                    width: level.width, rows: level.rows, lampHeights: level.lampHeights,
                    startingHeight: level.startingHeight, keyFrames: frames, forbidden: level.forbidden, allowance: 0,
                    budget: level.budget, tutorial: level.tutorial) else { continue }
                var play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: lowered)
                for action in entry.actions where play.stage == .playing {
                    try play.apply(action, expecting: play.fingerprint)
                }
                guard case .stray(let frame, let count)? = play.failure else { continue }
                let expected: ExpectedFailure? = expectedFailure(lowered, applied: entry.actions, phases: phases,
                                                                 height: height)
                let explanation: MoonlitMechanismFailureExplanation? = MoonlitMechanismFailureExplanation(play: play)
                #expect(frame == frameIndex && count == removed, "\(level.id)")
                #expect(explanation?.failure == expected?.failure, "\(level.id)")
                #expect(explanation?.text == expected?.text, "\(level.id)")
                found[count == 1 ? "stray-1" : "stray", default: 0] += 1
            }
        }
        print("MoonlitMechanismHintsTests run failures found: \(found)")
        #expect(found["missing", default: 0] + found["missing-1", default: 0] > 0, "\(found)")
        #expect(found["jammed", default: 0] > 0 && found["forbidden", default: 0] > 0, "\(found)")
        #expect(found["stray-1", default: 0] > 0 && found["stray", default: 0] > 0, "\(found)")
    }

    // MARK: Seeded failures

    /// 500 seeded failures (10 groups of 50): random turns, re-seats, lamp steps and runs from certified openings (runs
    /// left out in about half the walks, so the budget runs out), with undos and redos; at each failure the explanation
    /// names the failing action and the failure's numbers, tracked here without the play's stacks; a failure is undone
    /// and redone (the same explanation) or undone and the walk continued.
    @Test(arguments: Array(0..<10))
    func seededFailuresAreExplained(group: Int) throws {
        let catalog: [MoonlitMechanismGenerated] = try hintCatalog()
        var random = SeededRandom(seed: Self.seed &+ 1_000 &+ UInt64(group))
        var explained: Int = 0
        var kinds: [String: Int] = [:]
        while explained < 50 {
            let generated: MoonlitMechanismGenerated = catalog[random.int(0...99)]
            let level: MoonlitMechanismLevel = generated.level
            var play: MoonlitMechanismPlay = try MoonlitMechanismExperienceCore.freshPlay(of: level)
            let runs: Bool = random.int(0...1) == 0
            var applied: [MoonlitMechanismAction] = []
            var states: [(phases: [Int], height: Int)] = [(level.startingPhases, level.startingHeight)]
            var undoneActions: [MoonlitMechanismAction] = []
            var undoneStates: [(phases: [Int], height: Int)] = []
            var walking: Bool = true
            var guardSteps: Int = 0
            while walking && explained < 50 && guardSteps < 400 {
                guardSteps += 1
                if play.stage == .won { break }
                let roll: Int = random.int(0...9)
                if roll == 0 && play.canUndo {
                    try play.undo()
                    undoneActions.append(applied.removeLast())
                    undoneStates.append(states.removeLast())
                    continue
                }
                if roll == 1 && play.canRedo {
                    try play.redo()
                    applied.append(undoneActions.removeLast())
                    states.append(undoneStates.removeLast())
                } else {
                    let action: MoonlitMechanismAction = randomAction(play, &random, runs: runs)
                    do {
                        try play.apply(action, expecting: play.fingerprint)
                    } catch {
                        continue
                    }
                    let last: (phases: [Int], height: Int) = states[states.count - 1]
                    states.append(stepped(level, action, phases: last.phases, height: last.height))
                    applied.append(action)
                    undoneActions.removeAll()
                    undoneStates.removeAll()
                }
                guard play.stage == .failed else { continue }
                let last: (phases: [Int], height: Int) = states[states.count - 1]
                let expected: ExpectedFailure? = expectedFailure(level, applied: applied, phases: last.phases,
                                                                 height: last.height)
                let explanation: MoonlitMechanismFailureExplanation? = MoonlitMechanismFailureExplanation(play: play)
                #expect(expected != nil && explanation?.failure == expected?.failure, "\(level.id)")
                #expect(explanation?.action == expected?.action, "\(level.id)")
                #expect(explanation?.text == expected?.text, "\(level.id)")
                #expect(play.failure == expected?.failure, "\(level.id)")
                explained += 1
                kinds[expected?.failure.code ?? "none", default: 0] += 1
                let next: Int = random.int(0...2)
                if next == 0 {
                    try play.undo()
                    try play.redo()
                    #expect(MoonlitMechanismFailureExplanation(play: play) == explanation, "\(level.id): after redo")
                    walking = false
                } else if next == 1 {
                    try play.undo()
                    undoneActions.append(applied.removeLast())
                    undoneStates.append(states.removeLast())
                } else {
                    walking = false
                }
            }
        }
        #expect(kinds["budget", default: 0] > 0 && kinds["none", default: 0] == 0, "\(kinds)")
        print("MoonlitMechanismHintsTests failures group \(group): \(kinds)")
    }
}
