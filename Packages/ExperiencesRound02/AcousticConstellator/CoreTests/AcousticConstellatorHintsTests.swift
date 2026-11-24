// AcousticConstellatorHintsTests — feature 425 (R02-G13-05) T-R02G1305-002 (FR-R02G1305-002, 003, 007; SC-R02G1305-002,
// 003; clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (certified once per process
// through the experience core's cache, prewarmed concurrently): on every level `plan(_:links:phases:)` at the fixed
// links and starting phases equals `plan(_:)` and the certified plan, the hint plan from the opening holds the
// certified witness's actions (missing symbol pairs first) and following exact hints (re-asked after every action) wins
// spending exactly the witness's actions, within the budget, in 10 groups of 10 levels; 200 seeded reachable states
// (seed 2_425, 20 groups of 10: certified actions, then random links, unlinks, nudges, listens and undos, a failing
// action undone, about one in five paused) get a hint the kernel accepts, from every state with a plan following hints
// wins within the actions left, and a hint never changes the play; a play holding more than six links still gets a
// plan; a level whose budget is the certified plan size has no plan; the three hint levels read as clarification Q1
// says; loading, tutorial, won and result-after-win plays get no hint, failed ones `stuck`; 500 seeded failures (random
// actions, some undone and redone, 10 groups of 50) are explained with the true action and numbers tracked
// independently here. Deterministic, explicit types, plain loops.
@testable import AcousticConstellatorCore
import Foundation
import Testing
import VisualCoreSimulation

/// The 100 certified levels and plans in manifest order, certified concurrently once per test process.
private let hintCatalogResult: Result<[AcousticConstellatorGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? AcousticConstellatorExperienceCore.generated(number: index + 1)
    }
    var catalog: [AcousticConstellatorGenerated] = []
    for number in 1...100 { catalog.append(try AcousticConstellatorExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [AcousticConstellatorGenerated] { try hintCatalogResult.get() }

/// Follows exact (level 3) hints from `start` (resumed when paused) until the play ends; the problems found (empty:
/// won, every hinted action accepted, the play unchanged by every hint) and the actions spent following them.
private func followHints(_ start: AcousticConstellatorPlay, label: String) -> (problems: [String], spent: Int) {
    var play: AcousticConstellatorPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<64 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: AcousticConstellatorPlay = play
        guard let hint = AcousticConstellatorHints.hint(level: 3, play: play) else {
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

/// A random action on `play`: a link of a random pair, an unlink of a random link, a nudge of a random star by ±1, or
/// (when `listens`) a listen. The kernel may refuse it.
private func randomAction(_ play: AcousticConstellatorPlay, _ random: inout SeededRandom,
                          listens: Bool = true) -> AcousticConstellatorAction {
    let n: Int = play.level.stars.count
    let roll: Int = random.int(0...(listens ? 7 : 6))
    if roll == 7 { return .listen }
    if roll <= 2 {
        let u: Int = random.int(0...(n - 1))
        var v: Int = random.int(0...(n - 2))
        if v >= u { v += 1 }
        return .link(u, v)
    }
    if roll == 3 && !play.links.isEmpty {
        let link: AcousticConstellatorLink = play.links[random.int(0...(play.links.count - 1))]
        return .unlink(link.a, link.b)
    }
    return .nudge(random.int(0...(n - 1)), random.int(0...1) == 0 ? -1 : 1)
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: AcousticConstellatorPlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_425): from a certified opening, 0 … plan − 1 certified witness actions (so many
/// states stay on the certified path), then 0 … 6 random steps — a random link, unlink, nudge or listen (most often) or
/// an undo — where a refused action is skipped, an action that fails the play is undone and a won play is drawn again;
/// about one in five samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [AcousticConstellatorGenerated] = try hintCatalog()
    var random = SeededRandom(seed: AcousticConstellatorHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        let generated: AcousticConstellatorGenerated = catalog[number - 1]
        var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: generated.level)
        let witness: [AcousticConstellatorAction] = generated.actions
        let certified: Int = random.int(0...(witness.count - 2))
        for index in 0..<certified { try play.apply(witness[index], expecting: play.fingerprint) }
        let steps: Int = random.int(0...6)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            if random.int(0...4) == 0 {
                if play.canUndo { try play.undo() }
                continue
            }
            let action: AcousticConstellatorAction = randomAction(play, &random)
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
    let failure: AcousticConstellatorFailure
    let action: Int
    let text: String
}

/// The expected explanation of the failure after `applied` (the actions still applied, the failing one last) on
/// `level` with `links` and `phases` (after them): a listen fails as the level's listen of those links and phases says,
/// any other action spends the budget.
private func expectedFailure(_ level: AcousticConstellatorLevel, applied: [AcousticConstellatorAction],
                             links: [AcousticConstellatorLink], phases: [Int]) -> ExpectedFailure? {
    guard let failing = applied.last else { return nil }
    let index: Int = applied.count - 1
    let advice: String = " Undo the last action or retry the level."
    switch failing {
    case .listen:
        switch level.listen(links: links.sorted(), phases: phases).outcome {
        case .won: return nil
        case .missing(let pair):
            return ExpectedFailure(failure: .missing(pair), action: index,
                                   text: "Action \(index + 1) (the listen) found the symbol's pair star \(pair.a) – "
                                       + "star \(pair.b) unlinked.\(advice)")
        case .disconnected(let tick, let link):
            return ExpectedFailure(failure: .disconnected(tick: tick, link: link), action: index,
                                   text: "Action \(index + 1) (the listen): on tick \(tick) the link from star "
                                       + "\(link.a) to star \(link.b) snapped and the symbol came apart.\(advice)")
        case .incoherent(let run):
            return ExpectedFailure(failure: .incoherent(run), action: index,
                                   text: "Action \(index + 1) (the listen): the stars held together for at most \(run) "
                                       + "of the \(level.hold) ticks needed within \(level.window).\(advice)")
        }
    case .link(let u, let v):
        return ExpectedFailure(failure: .budget(index), action: index,
                               text: "Action \(index + 1) (a link of star \(min(u, v)) and star \(max(u, v))) spent "
                                   + "the last move without a win.\(advice)")
    case .unlink(let u, let v):
        return ExpectedFailure(failure: .budget(index), action: index,
                               text: "Action \(index + 1) (an unlink of star \(min(u, v)) and star \(max(u, v))) "
                                   + "spent the last move without a win.\(advice)")
    case .nudge(let star, let step):
        let sign: String = step < 0 ? "−1" : "+1"
        return ExpectedFailure(failure: .budget(index), action: index,
                               text: "Action \(index + 1) (a nudge of star \(star) by \(sign)) spent the last move "
                                   + "without a win.\(advice)")
    }
}

/// `level` with its budget replaced (every other value kept).
private func withBudget(_ level: AcousticConstellatorLevel, _ budget: Int) throws -> AcousticConstellatorLevel {
    try AcousticConstellatorLevel(
        id: level.id, seed: level.seed, difficulty: level.difficulty, stars: level.stars, fixedLinks: level.fixedLinks,
        symbol: level.symbol, coupling: level.coupling, degreeLimit: level.degreeLimit, linkLimit: level.linkLimit,
        snapLimit: level.snapLimit, threshold: level.threshold, hold: level.hold, window: level.window, budget: budget,
        tutorial: level.tutorial)
}

@Suite struct AcousticConstellatorHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_425

    // MARK: Openings

    /// On every certified level (10 groups of 10): `plan(_:links:phases:)` at the fixed links and starting phases
    /// equals `plan(_:)` and the certified plan; the hint plan from the opening holds the witness's actions, missing
    /// symbol pairs first, then helper links, nudges and the listen; following exact hints wins spending exactly the
    /// witness's actions, within the budget.
    @Test(arguments: Array(0..<10))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let catalog: [AcousticConstellatorGenerated] = try hintCatalog()
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: AcousticConstellatorGenerated = catalog[number - 1]
            let level: AcousticConstellatorLevel = generated.level
            let atStart: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(
                level, links: level.fixedLinks, phases: level.startingPhases)
            #expect(atStart == AcousticConstellatorSolver.plan(level), "level \(number)")
            #expect(atStart == generated.plan, "level \(number)")
            let opening: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: level)
            let witness: [AcousticConstellatorAction] = generated.actions
            let symbol: Set<AcousticConstellatorLink> = Set(level.symbol)
            var expected: [AcousticConstellatorAction] = []
            for link in generated.plan.links.sorted() where symbol.contains(link) {
                expected.append(.link(link.a, link.b))
            }
            for link in generated.plan.links.sorted() where !symbol.contains(link) {
                expected.append(.link(link.a, link.b))
            }
            for action in witness {
                if case .nudge = action { expected.append(action) }
            }
            expected.append(.listen)
            #expect(AcousticConstellatorHints.plan(opening)?.actions == expected, "level \(number)")
            let hint: AcousticConstellatorHint? = AcousticConstellatorHints.hint(level: 3, play: opening)
            #expect(hint?.kind == .linkSymbol && hint?.action == expected.first, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)")
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == witness.count && outcome.spent <= level.budget, "level \(number)")
        }
    }

    /// `plan(_:links:phases:)` refuses phases of the wrong count or outside 0 … 11 and malformed links; from the
    /// certified links it excludes them and keeps only the nudges; at the certified links and phases it is empty.
    @Test func planFromStateChecksItsInputs() throws {
        let generated: AcousticConstellatorGenerated = try hintCatalog()[30]
        let level: AcousticConstellatorLevel = generated.level
        var short: [Int] = level.startingPhases
        short.removeLast()
        #expect(AcousticConstellatorSolver.plan(level, links: level.fixedLinks, phases: short) == nil)
        var twelve: [Int] = level.startingPhases
        twelve[0] = 12
        #expect(AcousticConstellatorSolver.plan(level, links: level.fixedLinks, phases: twelve) == nil)
        let bad: [AcousticConstellatorLink] = [AcousticConstellatorLink(a: 0, b: level.stars.count)]
        #expect(AcousticConstellatorSolver.plan(level, links: bad, phases: level.startingPhases) == nil)
        let linked: [AcousticConstellatorLink] = (level.fixedLinks + generated.plan.links).sorted()
        let rest: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level, links: linked,
                                                                              phases: level.startingPhases)
        #expect(rest?.links.isEmpty == true && rest?.nudges == generated.plan.nudges)
        var nudged: [Int] = level.startingPhases
        for nudge in generated.plan.nudges {
            nudged[nudge.star] = AcousticConstellatorClock.reduce(nudged[nudge.star] + nudge.step)
        }
        let done: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level, links: linked, phases: nudged)
        #expect(done?.size == 0 && done?.smallerSets == 0)
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
            let play: AcousticConstellatorPlay = sample.play
            let plan: AcousticConstellatorHintPlan? = AcousticConstellatorHints.plan(play)
            guard let hint = AcousticConstellatorHints.hint(level: 3, play: play) else {
                Issue.record("\(label): no hint while \(play.stage)")
                continue
            }
            #expect(play == sample.play, "\(label): the hint changed the play")
            guard let plan, let action = hint.action else {
                #expect(plan == nil && hint.kind == .stuck && hint.text == AcousticConstellatorHint.stuckText,
                        "\(label)")
                stuck += 1
                continue
            }
            #expect(plan.actions.first == action && plan.actions.count <= play.actionsLeft, "\(label)")
            #expect(plan.actions.last == .listen, "\(label)")
            var copy: AcousticConstellatorPlay = play
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
        print("AcousticConstellatorHintsTests seeded group \(group): \(stuck) stuck of 10")
    }

    /// A play holding more than six links (the fixed links, every certified link and, where the limits allow, a further
    /// helper pair that keeps a plan) still gets a plan from the solver entry, and following its hints wins.
    @Test func moreThanSixLinksStillGetAPlan() throws {
        let catalog: [AcousticConstellatorGenerated] = try hintCatalog()
        var checked: Int = 0
        var withHelper: Int = 0
        for generated in catalog {
            let level: AcousticConstellatorLevel = generated.level
            guard level.linkLimit > 6 else { continue }
            var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: level)
            for action in generated.actions where action != .listen {
                if case .link = action { try play.apply(action, expecting: play.fingerprint) }
            }
            // Link helper pairs one at a time while a plan remains, until the play holds more than six links.
            var a: Int = 0
            while play.links.count <= 6 && a < level.stars.count {
                for b in (a + 1)..<max(a + 1, level.stars.count) where play.links.count <= 6 {
                    var trial: AcousticConstellatorPlay = play
                    do { try trial.apply(.link(a, b), expecting: trial.fingerprint) } catch { continue }
                    if trial.stage == .playing && AcousticConstellatorHints.plan(trial) != nil {
                        play = trial
                        withHelper += 1
                    }
                }
                a += 1
            }
            guard play.links.count > 6 else { continue }
            let label: String = "\(level.id) with \(play.links.count) links"
            let minimal: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level, links: play.links,
                                                                                     phases: play.phases)
            #expect(minimal != nil, "\(label)")
            if let minimal {
                for link in minimal.links { #expect(!play.links.contains(link), "\(label): a given link planned") }
            }
            #expect(AcousticConstellatorHints.plan(play) != nil, "\(label)")
            let outcome: (problems: [String], spent: Int) = followHints(play, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            checked += 1
        }
        #expect(checked > 0)
        print("AcousticConstellatorHintsTests more than six links: \(checked) plays, \(withHelper) helper links added")
    }

    // MARK: Texts and stages

    /// A level whose budget is its certified plan size (no room for the listen) has no plan at the opening: the hint is
    /// `stuck` with the stuck text at every level, and the play is unchanged.
    @Test func tooFewActionsLeftIsStuck() throws {
        let generated: AcousticConstellatorGenerated = try hintCatalog()[20]
        let level: AcousticConstellatorLevel = try withBudget(generated.level, generated.plan.size)
        let play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: level)
        #expect(AcousticConstellatorHints.plan(play) == nil)
        for hintLevel in 1...3 {
            let hint: AcousticConstellatorHint? = AcousticConstellatorHints.hint(level: hintLevel, play: play)
            #expect(hint?.kind == .stuck && hint?.action == nil)
            #expect(hint?.text
                    == "No way to win was found in the moves left: undo the last action or retry the level.")
        }
        #expect(play == (try AcousticConstellatorExperienceCore.freshPlay(of: level)))
    }

    /// The three hint levels read as clarification Q1 says, for a symbol link, a helper link, a nudge and the listen,
    /// and `at(level:)` reveals the same suggestion at another level.
    @Test func hintLevelsReadAsClarified() throws {
        let catalog: [AcousticConstellatorGenerated] = try hintCatalog()
        let generated: AcousticConstellatorGenerated = catalog[0]
        var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: generated.level)
        guard case .link(let a, let b)? = AcousticConstellatorHints.plan(play)?.actions.first else {
            Issue.record("no link hint at the opening")
            return
        }
        let link: [String] = ["Link two stars of the symbol", "Work on star \(a) and star \(b)",
                              "Link star \(a) to star \(b)"]
        for hintLevel in 1...3 {
            let hint: AcousticConstellatorHint? = AcousticConstellatorHints.hint(level: hintLevel, play: play)
            #expect(hint?.level == hintLevel && hint?.kind == .linkSymbol && hint?.action == .link(a, b))
            #expect(hint?.text == link[hintLevel - 1])
        }
        #expect(AcousticConstellatorHints.hint(level: 0, play: play)?.text == link[0])
        #expect(AcousticConstellatorHints.hint(level: 9, play: play)?.text == link[2])
        #expect(AcousticConstellatorHints.hint(level: 1, play: play)?.at(level: 3).text == link[2])
        let helper: AcousticConstellatorAction = .link(4, 1)
        #expect(AcousticConstellatorHint.text(level: 1, kind: .linkHelper, action: helper, failed: false)
                == "Link a helper pair so the phases pull together")
        #expect(AcousticConstellatorHint.text(level: 2, kind: .linkHelper, action: helper, failed: false)
                == "Work on star 1 and star 4")
        #expect(AcousticConstellatorHint.text(level: 3, kind: .linkHelper, action: helper, failed: false)
                == "Link star 1 to star 4")
        let nudges: [(AcousticConstellatorAction, String)] = [(.nudge(3, 1), "Nudge star 3 by +1"),
                                                              (.nudge(3, -1), "Nudge star 3 by −1")]
        for (action, exact) in nudges {
            #expect(AcousticConstellatorHint.text(level: 1, kind: .nudge, action: action, failed: false)
                    == "Nudge a star's phase")
            #expect(AcousticConstellatorHint.text(level: 2, kind: .nudge, action: action, failed: false)
                    == "Work on star 3")
            #expect(AcousticConstellatorHint.text(level: 3, kind: .nudge, action: action, failed: false) == exact)
        }
        // A level whose plan holds a nudge: after its links the hint is that nudge.
        if let nudging = catalog.first(where: { !$0.plan.nudges.isEmpty }) {
            var nudgePlay: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(
                of: nudging.level)
            for action in nudging.actions {
                if case .link = action { try nudgePlay.apply(action, expecting: nudgePlay.fingerprint) }
            }
            let hint: AcousticConstellatorHint? = AcousticConstellatorHints.hint(level: 3, play: nudgePlay)
            #expect(hint?.kind == .nudge)
            if case .nudge(let star, let step)? = hint?.action {
                #expect(hint?.text == "Nudge star \(star) by " + (step < 0 ? "−1" : "+1"))
            }
        }
        for action in generated.actions where action != .listen {
            try play.apply(action, expecting: play.fingerprint)
        }
        let listen: [String] = ["The symbol is ready: listen", "Listen: tap the coherence gauge",
                                "Listen: tap the coherence gauge"]
        #expect(AcousticConstellatorHints.plan(play)?.actions == [.listen])
        for hintLevel in 1...3 {
            let hint: AcousticConstellatorHint? = AcousticConstellatorHints.hint(level: hintLevel, play: play)
            #expect(hint?.kind == .listen && hint?.action == .listen)
            #expect(hint?.text == listen[hintLevel - 1])
        }
        try play.handle(.pause)
        #expect(AcousticConstellatorHints.hint(level: 2, play: play)?.text == listen[1], "a paused play gets its hint")
    }

    /// Loading and tutorial plays, won plays and results after a win get no hint; a failed play and its result get
    /// `stuck` with the failed text at every level; a playing play has no failure explanation.
    @Test func hintsByStage() throws {
        let generated: AcousticConstellatorGenerated = try hintCatalog()[0]
        var loading = AcousticConstellatorPlay(level: generated.level)
        #expect(AcousticConstellatorHints.hint(level: 1, play: loading) == nil)
        try loading.handle(.begin)
        #expect(generated.level.tutorial && loading.stage == .tutorial)
        #expect(AcousticConstellatorHints.hint(level: 1, play: loading) == nil)
        var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: generated.level)
        #expect(AcousticConstellatorFailureExplanation(play: play) == nil)
        var failed: AcousticConstellatorPlay = play
        try failed.apply(.listen, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        for hintLevel in 1...3 {
            let hint: AcousticConstellatorHint? = AcousticConstellatorHints.hint(level: hintLevel, play: failed)
            #expect(hint?.kind == .stuck && hint?.action == nil)
            #expect(hint?.text == "Undo the last action or retry the level.")
        }
        try failed.handle(.showResult)
        #expect(AcousticConstellatorHints.hint(level: 2, play: failed)?.text
                == "Undo the last action or retry the level.")
        #expect(AcousticConstellatorFailureExplanation(play: failed) != nil)
        for action in generated.actions { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        #expect(AcousticConstellatorHints.hint(level: 3, play: play) == nil)
        #expect(AcousticConstellatorHints.plan(play) == nil)
        #expect(AcousticConstellatorFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(AcousticConstellatorHints.hint(level: 3, play: play) == nil)
    }

    /// A missing pair and an exhausted budget (after a link, an unlink and a nudge) read as clarification Q5 says.
    @Test func explanationTextsReadAsClarified() throws {
        let generated: AcousticConstellatorGenerated = try hintCatalog()[0]
        let level: AcousticConstellatorLevel = generated.level
        var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: level)
        try play.apply(.listen, expecting: play.fingerprint)
        guard case .missing(let pair)? = play.failure else {
            Issue.record("a bare listen did not fail missing")
            return
        }
        let explanation: AcousticConstellatorFailureExplanation? = AcousticConstellatorFailureExplanation(play: play)
        #expect(explanation?.action == 0 && explanation?.failure == play.failure)
        #expect(explanation?.text == "Action 1 (the listen) found the symbol's pair star \(pair.a) – star \(pair.b) "
                + "unlinked. Undo the last action or retry the level.")
        let tight: AcousticConstellatorLevel = try withBudget(level, 3)
        guard let first = AcousticConstellatorSolver.missing(level).first else { return }
        var spent: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: tight)
        try spent.apply(.nudge(0, -1), expecting: spent.fingerprint)
        try spent.apply(.link(first.b, first.a), expecting: spent.fingerprint)
        try spent.apply(.unlink(first.a, first.b), expecting: spent.fingerprint)
        #expect(spent.failure == .budget(2))
        #expect(AcousticConstellatorFailureExplanation(play: spent)?.text
                == "Action 3 (an unlink of star \(first.a) and star \(first.b)) spent the last move without a win. "
                + "Undo the last action or retry the level.")
        try spent.undo()
        try spent.apply(.nudge(1, 1), expecting: spent.fingerprint)
        #expect(AcousticConstellatorFailureExplanation(play: spent)?.text
                == "Action 3 (a nudge of star 1 by +1) spent the last move without a win. Undo the last action or "
                + "retry the level.")
        var linked: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(
            of: try withBudget(level, 1))
        try linked.apply(.link(first.b, first.a), expecting: linked.fingerprint)
        #expect(AcousticConstellatorFailureExplanation(play: linked)?.text
                == "Action 1 (a link of star \(first.a) and star \(first.b)) spent the last move without a win. "
                + "Undo the last action or retry the level.")
        #expect(AcousticConstellatorFailureExplanation.describe(.listen) == "the listen")
        #expect(AcousticConstellatorFailureExplanation.describe(.nudge(2, -1)) == "a nudge of star 2 by −1")
    }

    // MARK: Seeded failures

    /// 500 seeded failures (10 groups of 50): random links, unlinks, nudges and listens from certified openings
    /// (listens left out in about half the walks, so the budget runs out), with undos and redos; at each failure the
    /// explanation names the failing action and the failure's numbers, tracked here without the play's stacks; a
    /// failure is undone and redone (the same explanation) or undone and the walk continued.
    @Test(arguments: Array(0..<10))
    func seededFailuresAreExplained(group: Int) throws {
        let catalog: [AcousticConstellatorGenerated] = try hintCatalog()
        var random = SeededRandom(seed: Self.seed &+ 1_000 &+ UInt64(group))
        var explained: Int = 0
        var kinds: [String: Int] = [:]
        while explained < 50 {
            let generated: AcousticConstellatorGenerated = catalog[random.int(0...99)]
            let level: AcousticConstellatorLevel = generated.level
            var play: AcousticConstellatorPlay = try AcousticConstellatorExperienceCore.freshPlay(of: level)
            let listens: Bool = random.int(0...1) == 0
            var applied: [AcousticConstellatorAction] = []
            var states: [(links: [AcousticConstellatorLink], phases: [Int])] = [(level.fixedLinks, level.startingPhases)]
            var undoneActions: [AcousticConstellatorAction] = []
            var undoneStates: [(links: [AcousticConstellatorLink], phases: [Int])] = []
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
                    let action: AcousticConstellatorAction = randomAction(play, &random, listens: listens)
                    do {
                        try play.apply(action, expecting: play.fingerprint)
                    } catch {
                        continue
                    }
                    var state: (links: [AcousticConstellatorLink], phases: [Int]) = states[states.count - 1]
                    switch action {
                    case .link(let u, let v): state.links.append(AcousticConstellatorLink.between(u, v))
                    case .unlink(let u, let v): state.links.removeAll { $0 == AcousticConstellatorLink.between(u, v) }
                    case .nudge(let star, let step):
                        state.phases[star] = AcousticConstellatorClock.reduce(state.phases[star] + step)
                    case .listen: break
                    }
                    applied.append(action)
                    states.append(state)
                    undoneActions.removeAll()
                    undoneStates.removeAll()
                }
                guard play.stage == .failed else { continue }
                let last: (links: [AcousticConstellatorLink], phases: [Int]) = states[states.count - 1]
                let expected: ExpectedFailure? = expectedFailure(level, applied: applied, links: last.links,
                                                                 phases: last.phases)
                let explanation: AcousticConstellatorFailureExplanation? =
                    AcousticConstellatorFailureExplanation(play: play)
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
                    #expect(AcousticConstellatorFailureExplanation(play: play) == explanation, "\(level.id): after redo")
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
        print("AcousticConstellatorHintsTests failures group \(group): \(kinds)")
    }
}
