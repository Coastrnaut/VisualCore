// AmethystEscapeHintsTests — feature 365 (R02-G07-05) T-R02G0705-002 (FR-R02G0705-002, 003; SC-R02G0705-002, 003;
// clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (generated once per process through
// the adapter's cache, prewarmed concurrently): the search from the opening crystal equals the certified solve on every
// level, and following exact hints from every level's opening wins in the certified smallest move count; 200 seeded
// reachable states (seed 2_365: random legal moves, undos, redos and pauses from certified openings, a failing move undone)
// get a legal exact hint, from every state with a plan following hints wins, and an independent breadth-first search
// written here (crystals in a set, `rotating` and `transition`, no packed states) agrees on the shortest escape within the
// moves left, so a state without a plan has none; the three hint levels agree on the action and read as clarification Q1
// says; loading, tutorial, won and result-after-win plays get no hint, failed ones `stuck`; a hint never changes the play;
// 500 seeded failures (seed 3_365) are explained with the reason, shell, sector and move tracked independently here by an
// own crystal replay. Every group measures and prints its slowest hint (no wall-clock assertion). Explicit types, plain
// loops.
@testable import AmethystEscapeCore
import Foundation
import Testing

/// The 100 certified levels and their solutions in manifest order, generated concurrently once per test process.
private let hintCatalogResult: Result<[AmethystEscapeGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? AmethystEscapeExperienceCore.generated(number: index + 1)
    }
    var catalog: [AmethystEscapeGenerated] = []
    for number in 1...100 { catalog.append(try AmethystEscapeExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [AmethystEscapeGenerated] { try hintCatalogResult.get() }

/// Seconds of a duration.
private func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) * 1e-18
}

/// Timing of hint calls: the slowest, the total and the count.
private struct HintClock {
    var slowest: Double = 0
    var total: Double = 0
    var count: Int = 0

    /// The hint of `level` for `play`, timed.
    mutating func hint(_ level: Int, _ play: AmethystEscapePlay) -> AmethystEscapeHint? {
        let start: ContinuousClock.Instant = ContinuousClock.now
        let hint: AmethystEscapeHint? = AmethystEscapeHints.hint(level: level, play: play)
        let elapsed: Double = seconds(ContinuousClock.now - start)
        if elapsed > slowest { slowest = elapsed }
        total += elapsed
        count += 1
        return hint
    }

    /// A one-line summary in milliseconds.
    var summary: String {
        let mean: Double = count == 0 ? 0 : total / Double(count)
        return String(format: "%d hints, mean %.3f ms, slowest %.3f ms", count, mean * 1_000, slowest * 1_000)
    }
}

/// The legal actions of `play` by the rules (none unless playing).
private func legalActions(_ play: AmethystEscapePlay) -> [AmethystEscapeAction] {
    let rules = AmethystEscapeRules(level: play.level)
    let position = AmethystEscapeRules.Position(crystal: play.crystal, moves: play.moves, outcome: .playing)
    return rules.moves(in: position)
}

/// Follows exact hints from `start` (resumed when paused) until the play ends; the problems found (empty: won, every
/// hinted action legal and accepted) and the moves spent following them.
private func followHints(_ start: AmethystEscapePlay, label: String,
                         clock: inout HintClock) -> (problems: [String], spent: Int) {
    var play: AmethystEscapePlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    var spent: Int = 0
    for _ in 0..<64 {
        if play.stage == .won { return ([], spent) }
        guard let hint = clock.hint(3, play) else { return (["\(label): no hint in \(play.stage)"], spent) }
        guard let action = hint.action else { return (["\(label): stuck at move \(play.moves)"], spent) }
        if !legalActions(play).contains(action) { return (["\(label): hinted \(action) is not legal"], spent) }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], spent)
        }
        spent += 1
    }
    return (play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"], spent)
}

/// An independent breadth-first search on `AmethystEscapeCrystal` itself (crystals in a set, no packed states): the
/// smallest number of moves, at most `limit`, after which the pearl leaves through the exit gap from `crystal`, or nil.
private func independentShortest(_ level: AmethystEscapeLevel, from crystal: AmethystEscapeCrystal,
                                 limit: Int) -> Int? {
    if crystal.isBlocked(crystal.pearl, level: level) { return nil }
    var seen: Set<AmethystEscapeCrystal> = [crystal]
    var frontier: [AmethystEscapeCrystal] = [crystal]
    var depth: Int = 0
    while !frontier.isEmpty && depth < limit {
        var next: [AmethystEscapeCrystal] = []
        for state in frontier {
            var successors: [AmethystEscapeCrystal] = []
            switch state.transition(level: level) {
            case .exited: return depth + 1
            case .moved(let pocket): successors.append(state.placing(pearl: pocket))
            case .wedge, .stuck: break
            }
            for shell in level.shells.indices {
                successors.append(state.rotating(shell: shell, step: 1, level: level))
                successors.append(state.rotating(shell: shell, step: -1, level: level))
            }
            for successor in successors where !seen.contains(successor) {
                seen.insert(successor)
                next.append(successor)
            }
        }
        frontier = next
        depth += 1
    }
    return nil
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: AmethystEscapePlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_365): from a certified opening, 0 … budget − 1 random steps — a legal action
/// (most often), an undo or a redo — where a move that fails the play is undone; about one in four samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [AmethystEscapeGenerated] = try hintCatalog()
    var random = AmethystEscapeRandom(seed: 2_365)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        var play: AmethystEscapePlay = try AmethystEscapeExperienceCore.freshPlay(of: catalog[number - 1].level)
        let steps: Int = random.int(0..<play.level.budget)
        for _ in 0..<steps {
            let roll: Int = random.int(0..<10)
            if roll == 0, play.canUndo {
                try play.undo()
            } else if roll == 1, play.canRedo {
                try play.redo()
            } else {
                let actions: [AmethystEscapeAction] = legalActions(play)
                let action: AmethystEscapeAction = actions[random.int(0..<actions.count)]
                try play.apply(action, expecting: play.fingerprint)
                if play.stage == .failed { try play.undo() }
            }
            if play.stage == .won { break }
        }
        guard play.stage == .playing else { continue }
        if random.int(0..<4) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// The expected text of a hint of `level` for `action` on `lvl` (clarification Q1), written out here.
private func expectedText(_ level: Int, _ action: AmethystEscapeAction, _ lvl: AmethystEscapeLevel) -> String {
    switch action {
    case .advance:
        return level == 3 ? "Roll the pearl one pocket" : "Roll the pearl"
    case .rotate(let shell, let step):
        let name: String
        if shell == 0 {
            name = "shell 1 (inner)"
        } else if shell == lvl.shells.count - 1 {
            name = "shell \(shell + 1) (outer)"
        } else {
            name = "shell \(shell + 1)"
        }
        switch level {
        case 1: return "Turn a shell"
        case 2: return "Turn \(name)"
        default: return "Turn \(name) one sector \(step == 1 ? "clockwise" : "anticlockwise")"
        }
    }
}

@Suite struct AmethystEscapeHintsTests {
    /// The search from the opening crystal equals the certified solve on all 100 levels (one band of 20 per argument),
    /// and its actions are the certified solution's.
    @Test(arguments: [1, 2, 3, 4, 5])
    func searchFromTheOpeningEqualsTheCertifiedSolve(band: Int) throws {
        for generated in try hintCatalog()[(band - 1) * 20..<band * 20] {
            let level: AmethystEscapeLevel = generated.level
            let fromOpening: AmethystEscapeSolution? =
                AmethystEscapeSolver.solve(level, from: AmethystEscapeCrystal(level: level), maxDepth: Int.max)
            #expect(fromOpening == AmethystEscapeSolver.solve(level), "\(level.id)")
            #expect(fromOpening?.actions == generated.solution.actions, "\(level.id)")
            #expect(AmethystEscapeSolver.solve(level, from: AmethystEscapeCrystal(level: level), maxDepth: 0) == nil)
        }
    }

    /// Following exact hints from every certified opening wins in exactly the certified smallest move count, and the
    /// opening's plan is the certified solution (one band of 20 per argument).
    @Test(arguments: [1, 2, 3, 4, 5])
    func exactHintsFromTheOpeningWinAllOneHundredLevels(band: Int) throws {
        var clock = HintClock()
        var problems: [String] = []
        for generated in try hintCatalog()[(band - 1) * 20..<band * 20] {
            let play: AmethystEscapePlay = try AmethystEscapeExperienceCore.freshPlay(of: generated.level)
            #expect(AmethystEscapeHints.plan(play)?.actions == generated.solution.actions, "\(generated.level.id)")
            let result: (problems: [String], spent: Int) = followHints(play, label: generated.level.id, clock: &clock)
            problems.append(contentsOf: result.problems)
            if result.problems.isEmpty {
                #expect(result.spent == generated.solution.smallest, "\(generated.level.id) took \(result.spent)")
            }
        }
        #expect(problems.isEmpty, "\(problems.prefix(5))")
        print("AmethystEscapeHints openings band \(band): \(clock.summary)")
    }

    /// 200 seeded reachable states: every exact hint is a legal action; the three levels agree on it and read as
    /// clarification Q1 says; the plan's length is the independent search's shortest escape within the moves left (so a
    /// state without a plan has no escape there, and its hint is `stuck`); following hints from every state with a plan
    /// wins; a hint never changes the play. Five chunks of 40 samples, one per argument.
    @Test(arguments: [0, 1, 2, 3, 4])
    func seededReachableStatesGetLegalHintsThatWin(chunk: Int) throws {
        let samples: [HintSample] = try hintSamples()
        var clock = HintClock()
        var problems: [String] = []
        var withPlan: Int = 0
        var paused: Int = 0
        var searchSeconds: Double = 0
        for index in chunk * 40..<(chunk + 1) * 40 {
            let sample: HintSample = samples[index]
            let play: AmethystEscapePlay = sample.play
            let before: AmethystEscapePlay = play
            let fingerprint: String = play.fingerprint
            if play.stage == .paused { paused += 1 }
            let label: String = "sample \(index) (level \(sample.number), move \(play.moves))"
            let plan: AmethystEscapePlan? = AmethystEscapeHints.plan(play)
            let searchStart: ContinuousClock.Instant = ContinuousClock.now
            let shortest: Int? = independentShortest(play.level, from: play.crystal, limit: play.remaining)
            searchSeconds += seconds(ContinuousClock.now - searchStart)
            #expect(plan?.actions.count == shortest, "\(label): plan \(String(describing: plan)) vs \(String(describing: shortest))")
            guard let exact = clock.hint(3, play) else {
                problems.append("\(label): no hint")
                continue
            }
            let one: AmethystEscapeHint? = AmethystEscapeHints.hint(level: 1, play: play)
            let two: AmethystEscapeHint? = AmethystEscapeHints.hint(level: 2, play: play)
            #expect(one?.kind == exact.kind && two?.kind == exact.kind, "\(label)")
            #expect(one?.shell == exact.shell && two?.shell == exact.shell, "\(label)")
            #expect(one?.step == exact.step && two?.step == exact.step, "\(label)")
            #expect(play == before && play.fingerprint == fingerprint, "\(label): the hint changed the play")
            guard let plan else {
                #expect(exact.kind == .stuck, "\(label)")
                #expect(exact.text == "No escape is reachable in the moves left: undo the last move or retry the level.")
                #expect(one?.text == exact.text && two?.text == exact.text)
                continue
            }
            withPlan += 1
            guard let action = exact.action else {
                problems.append("\(label): stuck with a plan")
                continue
            }
            #expect(action == plan.actions[0], "\(label)")
            #expect(legalActions(play).contains(action), "\(label): \(action) is not legal")
            #expect(one?.text == expectedText(1, action, play.level), "\(label)")
            #expect(two?.text == expectedText(2, action, play.level), "\(label)")
            #expect(exact.text == expectedText(3, action, play.level), "\(label)")
            let result: (problems: [String], spent: Int) = followHints(play, label: label, clock: &clock)
            problems.append(contentsOf: result.problems)
            if result.problems.isEmpty { #expect(result.spent == plan.actions.count, "\(label)") }
        }
        #expect(problems.isEmpty, "\(problems.prefix(5))")
        print("AmethystEscapeHints samples chunk \(chunk): \(withPlan) of 40 with a plan, \(paused) paused; "
            + "\(clock.summary); independent search \(String(format: "%.2f", searchSeconds)) s")
    }

    /// The 200 samples are reachable and varied: all playing or paused, some paused, some with a plan and some without.
    @Test func theSampleIsVaried() throws {
        let samples: [HintSample] = try hintSamples()
        #expect(samples.count == 200)
        var withPlan: Int = 0
        var paused: Int = 0
        for sample in samples {
            #expect(sample.play.stage == .playing || sample.play.stage == .paused)
            if sample.play.stage == .paused { paused += 1 }
            if AmethystEscapeHints.plan(sample.play) != nil { withPlan += 1 }
        }
        #expect(withPlan > 0 && withPlan < samples.count, "with a plan: \(withPlan) of \(samples.count)")
        #expect(paused > 0)
    }

    /// Loading, tutorial, won and result-after-win plays get no hint and no plan; a failed play (and its result) gets
    /// `stuck` with the failed text at every level and no plan; levels outside 1 … 3 are clamped.
    @Test func stagesWithoutAPlanGetTheRightHint() throws {
        let catalog: [AmethystEscapeGenerated] = try hintCatalog()
        let level: AmethystEscapeLevel = catalog[0].level
        #expect(level.tutorial)
        var loading = AmethystEscapePlay(level: level)
        #expect(AmethystEscapeHints.hint(level: 1, play: loading) == nil)
        try loading.handle(.begin)
        #expect(loading.stage == .tutorial)
        #expect(AmethystEscapeHints.hint(level: 3, play: loading) == nil)
        #expect(AmethystEscapeHints.plan(loading) == nil)
        var won: AmethystEscapePlay = try AmethystEscapeExperienceCore.freshPlay(of: level)
        for action in catalog[0].solution.actions { try won.apply(action, expecting: won.fingerprint) }
        #expect(won.stage == .won)
        #expect(AmethystEscapeHints.hint(level: 2, play: won) == nil)
        #expect(AmethystEscapeHints.plan(won) == nil)
        try won.handle(.showResult)
        #expect(AmethystEscapeHints.hint(level: 2, play: won) == nil)
        var failed: AmethystEscapePlay = try AmethystEscapeExperienceCore.freshPlay(of: level)
        while failed.stage == .playing { try failed.apply(.rotate(0, 1), expecting: failed.fingerprint) }
        #expect(failed.failure == .budget)
        #expect(AmethystEscapeHints.plan(failed) == nil)
        for hintLevel in [0, 1, 2, 3, 4] {
            let hint: AmethystEscapeHint? = AmethystEscapeHints.hint(level: hintLevel, play: failed)
            #expect(hint?.kind == .stuck && hint?.level == min(3, max(1, hintLevel)))
            #expect(hint?.text == "Undo the last move or retry the level.")
            #expect(hint?.action == nil)
        }
        try failed.handle(.showResult)
        #expect(AmethystEscapeHints.hint(level: 1, play: failed)?.text == "Undo the last move or retry the level.")
        let fresh: AmethystEscapePlay = try AmethystEscapeExperienceCore.freshPlay(of: level)
        #expect(AmethystEscapeHints.hint(level: 9, play: fresh)?.level == 3)
        #expect(AmethystEscapeHints.hint(level: -2, play: fresh)?.level == 1)
    }

    /// 500 seeded failures (seed 3_365): random legal actions from certified openings until the play fails (a won play is
    /// discarded). The reason, shell, sector, move and text equal those tracked independently here — the crystal is
    /// replayed with `rotating` and `transition`, a wedge is the advance into a blocked pocket, else the budget — and the
    /// failed play's hint is `stuck`. A play that has not failed has no explanation.
    @Test func seededFailuresAreExplainedWithTheirTrueReason() throws {
        let catalog: [AmethystEscapeGenerated] = try hintCatalog()
        var random = AmethystEscapeRandom(seed: 3_365)
        var explained: Int = 0
        var wedges: Int = 0
        while explained < 500 {
            let number: Int = random.int(1...100)
            let level: AmethystEscapeLevel = catalog[number - 1].level
            var play: AmethystEscapePlay = try AmethystEscapeExperienceCore.freshPlay(of: level)
            #expect(AmethystEscapeFailureExplanation(play: play) == nil)
            var crystal = AmethystEscapeCrystal(level: level)
            var moves: Int = 0
            var wedge: AmethystEscapePocket? = nil
            while play.stage == .playing {
                let actions: [AmethystEscapeAction] = legalActions(play)
                let action: AmethystEscapeAction = actions[random.int(0..<actions.count)]
                try play.apply(action, expecting: play.fingerprint)
                moves += 1
                switch action {
                case .rotate(let shell, let step):
                    crystal = crystal.rotating(shell: shell, step: step, level: level)
                case .advance:
                    switch crystal.transition(level: level) {
                    case .moved(let pocket): crystal = crystal.placing(pearl: pocket)
                    case .wedge(let pocket):
                        crystal = crystal.placing(pearl: pocket)
                        wedge = pocket
                    case .exited, .stuck: break
                    }
                }
            }
            guard play.stage == .failed else { continue }
            let failedPlay: AmethystEscapePlay = play
            guard let explanation = AmethystEscapeFailureExplanation(play: play) else {
                Issue.record("level \(number): failed play without an explanation")
                continue
            }
            #expect(play == failedPlay, "the explanation changed the play")
            #expect(explanation.move == moves)
            #expect(explanation.pearl == crystal.pearl)
            let s: Int = crystal.pearl.sector + 1
            let n: Int = level.sectors
            let shellWords: String = crystal.pearl.shell == 0 ? "shell 1 (inner)"
                : crystal.pearl.shell == level.shells.count - 1 ? "shell \(crystal.pearl.shell + 1) (outer)"
                : "shell \(crystal.pearl.shell + 1)"
            if let wedge {
                wedges += 1
                #expect(explanation.failure == .wedge(wedge.shell, wedge.sector))
                #expect(explanation.shell == wedge.shell && explanation.sector == wedge.sector)
                #expect(explanation.text == "The pearl fell into the blocked wedge of \(shellWords), sector \(s) of \(n), "
                    + "on move \(moves). Undo the last move or retry the level.")
            } else {
                #expect(moves == level.budget)
                #expect(explanation.failure == .budget)
                #expect(explanation.shell == crystal.pearl.shell && explanation.sector == crystal.pearl.sector)
                #expect(explanation.text == "The moves ran out: \(moves) of \(level.budget) spent and the pearl is in "
                    + "\(shellWords), sector \(s) of \(n). Undo the last move or retry the level.")
            }
            #expect(AmethystEscapeHints.hint(level: 3, play: play)?.kind == .stuck)
            try play.handle(.showResult)
            #expect(AmethystEscapeFailureExplanation(play: play) == explanation)
            explained += 1
        }
        #expect(wedges > 0 && wedges < 500, "wedges \(wedges) of 500")
        print("AmethystEscapeHints failures: 500 explained, \(wedges) wedges")
    }

    /// A crystal whose pearl lies in a blocked wedge (a failed state) is not searched.
    @Test func aWedgedCrystalHasNoEscape() throws {
        for generated in try hintCatalog() {
            let level: AmethystEscapeLevel = generated.level
            for shell in level.shells.indices {
                guard let own = level.shells[shell].blocked.first else { continue }
                let crystal = AmethystEscapeCrystal(offsets: Array(repeating: 0, count: level.shells.count),
                                                    pearl: AmethystEscapePocket(shell: shell, sector: own))
                #expect(AmethystEscapeSolver.solve(level, from: crystal, maxDepth: Int.max) == nil, "\(level.id)")
            }
        }
    }
}
