// BackwardsAuroraHintsTests — feature 395 (R02-G10-05) T-R02G1005-002 (FR-R02G1005-002, 003; SC-R02G1005-002, 003;
// clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (certified once per process
// through the adapter's cache, prewarmed concurrently): from every opening the continuation search finds a solution of
// exactly the certified smallest reversal count within the work bound, and following exact hints (re-asked after every
// reversal) wins with exactly that many reversals, in 20 groups of 5 levels; `solve(_:workBound:)` is still the
// certification; 200 seeded reachable states (seed 2_395, 20 groups of 10: certified reversals, random reversals and
// undos from certified openings, about one in four paused) get a hint that the play accepts, from every state with a
// plan following hints wins within the reversals left, and a hint never changes the play; a state with too few
// reversals left is stuck; the three hint levels read as clarification Q1 says; loading, tutorial, won and
// result-after-win plays get no hint, failed ones `stuck`; 500 seeded failures (tears and budget runs, 10 groups of 50
// on 10 levels of every band each) are explained with the true reason, reversal, section, seam and numbers tracked
// independently here (own seam scan, own reversal index, own counts). Deterministic, explicit types, plain loops.
@testable import BackwardsAuroraCore
import Foundation
import Synchronization
import Testing
import VisualCoreSimulation

/// The 100 certified levels and their solutions in manifest order, certified concurrently once per test process.
private let hintCatalogResult: Result<[BackwardsAuroraGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? BackwardsAuroraExperienceCore.generated(number: index + 1)
    }
    var catalog: [BackwardsAuroraGenerated] = []
    for number in 1...100 { catalog.append(try BackwardsAuroraExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [BackwardsAuroraGenerated] { try hintCatalogResult.get() }

/// The largest work one continuation search spent in this process (openings and samples).
private let mostWork = Mutex<Int>(0)

/// Records `work` in ``mostWork``.
private func noteWork(_ work: Int) {
    mostWork.withLock { $0 = max($0, work) }
}

/// Follows exact (level 3) hints from `start` (resumed when paused; `first`, when given, is the hint already asked for
/// `start`) until the play ends; the problems found (empty: won, every hinted reversal accepted) and the reversals
/// spent following them.
private func followHints(_ start: BackwardsAuroraPlay, label: String,
                         first: BackwardsAuroraHint? = nil) -> (problems: [String], spent: Int) {
    var play: BackwardsAuroraPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    var spent: Int = 0
    var given: BackwardsAuroraHint? = first
    for _ in 0..<48 {
        if play.stage == .won { return ([], spent) }
        if play.stage == .playing, given == nil,
           let solution = BackwardsAuroraSolver.solve(play.level, from: play.wave, reversalsLeft: play.remaining) {
            noteWork(solution.work)
        }
        let asked: BackwardsAuroraHint? = given ?? BackwardsAuroraHints.hint(level: 3, play: play)
        given = nil
        guard let hint = asked else { return (["\(label): no hint in \(play.stage)"], spent) }
        guard let action = hint.action else { return (["\(label): stuck at reversal \(play.spent)"], spent) }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], spent)
        }
        spent += 1
    }
    return (play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"], spent)
}

/// A random reversal for `play`: a length within the level's sections and a start that keeps the section inside the
/// wave; it may be a palindrome (refused) or tear.
private func randomReversal(_ play: BackwardsAuroraPlay, _ random: inout SeededRandom) -> BackwardsAuroraAction {
    let level: BackwardsAuroraLevel = play.level
    let length: Int = random.int(level.shortest...level.longest)
    let start: Int = random.int(0...(level.count - length))
    return .reverse(start, start + length - 1)
}

/// The section of `action`.
private func section(_ action: BackwardsAuroraAction) -> (start: Int, end: Int) {
    switch action {
    case let .reverse(start, end): return (start, end)
    }
}

/// The lowest seam of [start, end] in `wave` (already reversed) whose bend exceeds `limit`, computed here from the
/// samples: the interior positions among start − 1, start, end, end + 1.
private func ownTornSeam(_ wave: BackwardsAuroraWave, start: Int, end: Int, limit: Int) -> Int? {
    var seams: [Int] = []
    for k in [start - 1, start, end, end + 1] where k >= 1 && k <= wave.count - 2 && !seams.contains(k) {
        seams.append(k)
    }
    seams.sort()
    for k in seams {
        let s: [Int] = wave.samples
        if abs(s[k - 1] - 2 * s[k] + s[k + 1]) > limit { return k }
    }
    return nil
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: BackwardsAuroraPlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_395): from a certified opening, 0 … smallest − 1 certified reversals (so many
/// states stay on a winning path), then 0 … 3 random steps — a random reversal (most often) or an undo — where a
/// reversal that fails the play is undone and a won play is drawn again; about one in four samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [BackwardsAuroraGenerated] = try hintCatalog()
    var random = SeededRandom(seed: BackwardsAuroraHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        let generated: BackwardsAuroraGenerated = catalog[number - 1]
        var play: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: generated.level)
        let certified: Int = random.int(0...(generated.solution.actions.count - 1))
        for index in 0..<certified { try play.apply(generated.solution.actions[index], expecting: play.fingerprint) }
        let steps: Int = random.int(0...3)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            if random.int(0...4) == 0 {
                if play.canUndo { try play.undo() }
                continue
            }
            let action: BackwardsAuroraAction = randomReversal(play, &random)
            do {
                try play.apply(action, expecting: play.fingerprint)
            } catch {
                continue
            }
            if play.stage == .failed { try play.undo() }
        }
        guard play.stage == .playing else { continue }
        if random.int(0...3) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

@Suite struct BackwardsAuroraHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_395

    // MARK: Openings

    /// From every certified opening (20 groups of 5 levels) the continuation search finds exactly the certified
    /// solution within the work bound, and following exact hints wins with exactly the certified smallest count,
    /// within the budget.
    @Test(arguments: Array(0..<20))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let catalog: [BackwardsAuroraGenerated] = try hintCatalog()
        var most: Int = 0
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: BackwardsAuroraGenerated = catalog[number - 1]
            let level: BackwardsAuroraLevel = generated.level
            let found: BackwardsAuroraSolution? = BackwardsAuroraSolver.solve(level, from: level.opening,
                                                                             reversalsLeft: level.budget)
            let solution: BackwardsAuroraSolution = try #require(found, "level \(number): no continuation")
            #expect(solution == generated.solution, "level \(number): the opening's continuation is the certificate")
            #expect(solution.smallest == solution.actions.count && solution.work <= BackwardsAuroraSolver.workBound)
            #expect(BackwardsAuroraSolver.wins(level, actions: solution.actions), "level \(number)")
            most = max(most, solution.work)
            noteWork(solution.work)
            let opening: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: level)
            let hint: BackwardsAuroraHint? = BackwardsAuroraHints.hint(level: 3, play: opening)
            #expect(hint?.kind == .reverse && hint?.action == solution.actions.first, "level \(number)")
            #expect(BackwardsAuroraHints.plan(opening)?.actions == solution.actions, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)", first: hint)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == generated.solution.smallest && outcome.spent <= level.budget, "level \(number)")
        }
        print("BackwardsAuroraHintsTests group \(group): most opening work \(most); most so far "
              + "\(mostWork.withLock { $0 })")
    }

    /// The certification is unchanged: `solve(_:workBound:)` equals the continuation from the opening with the whole
    /// budget, also under a small work bound (both give up alike), on fixture levels.
    @Test func certificationEqualsTheOpeningContinuation() {
        for fixture in BackwardsAuroraFixtures.fixtures(30, seed: Self.seed) {
            let level: BackwardsAuroraLevel = fixture.level
            for bound in [5, 50, BackwardsAuroraSolver.workBound] {
                let certified: BackwardsAuroraSolution? = BackwardsAuroraSolver.solve(level, workBound: bound)
                let continued: BackwardsAuroraSolution? = BackwardsAuroraSolver.solve(
                    level, from: level.opening, reversalsLeft: level.budget, workBound: bound)
                #expect(certified == continued, "\(level.id) bound \(bound)")
            }
            #expect(BackwardsAuroraSolver.solve(level, from: level.opening, reversalsLeft: 0) == nil)
        }
    }

    // MARK: Reachable states

    /// 200 seeded reachable states in 20 groups of 10: the hint never changes the play; with a plan the hint is its
    /// first reversal at every level, the play accepts it and following hints wins within the reversals left; without
    /// one the hint is `stuck` with the stuck text.
    @Test(arguments: Array(0..<20))
    func reachableStatesGetLegalHintsThatWin(group: Int) throws {
        let samples: [HintSample] = try hintSamples()
        var planned: Int = 0
        for index in (10 * group)..<(10 * group + 10) {
            let sample: HintSample = samples[index]
            let play: BackwardsAuroraPlay = sample.play
            let label: String = "sample \(index) (level \(sample.number), reversal \(play.spent))"
            let before: BackwardsAuroraPlay = play
            let hint: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: 3, play: play), "\(label)")
            #expect(play == before && play.fingerprint == before.fingerprint, "\(label): the hint changed the play")
            guard let action = hint.action else {
                #expect(hint.kind == .stuck && hint.text == BackwardsAuroraHint.stuckText, "\(label)")
                #expect(BackwardsAuroraHints.plan(play) == nil, "\(label)")
                continue
            }
            planned += 1
            #expect(hint.kind == .reverse, "\(label)")
            for level in 1...2 { #expect(hint.at(level: level).action == action, "\(label)") }
            // The hinted reversal is legal: inside the wave, a length the level allows, not a palindrome.
            let (start, end): (Int, Int) = section(action)
            #expect(start >= 0 && start < end && end < play.level.count, "\(label)")
            #expect(play.level.sectionLengths.contains(end - start + 1), "\(label)")
            #expect(!play.wave.isPalindrome(start: start, end: end), "\(label)")
            var copy: BackwardsAuroraPlay = play
            if copy.stage == .paused { try copy.handle(.resume) }
            #expect(throws: Never.self, "\(label): hinted \(action) refused") {
                try copy.apply(action, expecting: copy.fingerprint)
            }
            #expect(copy.failure == nil, "\(label): the hinted reversal failed the play")
            // Following hints from there (re-asked after every reversal) wins within the reversals left.
            let outcome: (problems: [String], spent: Int) = followHints(copy, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent + 1 <= play.remaining, "\(label)")
        }
        #expect(planned >= 1, "group \(group): no sample has a plan")
        print("BackwardsAuroraHintsTests samples group \(group): \(planned) of 10 with a plan; most work so far "
              + "\(mostWork.withLock { $0 })")
    }

    /// One reversal short of the certified count is stuck: on a level whose certified solution needs two or more
    /// reversals, a play whose budget is lowered to one below it at the opening has no plan and the stuck hint.
    @Test func tooFewReversalsLeftIsStuck() throws {
        let catalog: [BackwardsAuroraGenerated] = try hintCatalog()
        var checked: Int = 0
        for generated in catalog where generated.solution.smallest >= 2 && checked < 5 {
            let level: BackwardsAuroraLevel = generated.level
            let short: Int = generated.solution.smallest - 1
            #expect(BackwardsAuroraSolver.solve(level, from: level.opening, reversalsLeft: short) == nil)
            // The same level with the budget lowered: the play itself has too few reversals left.
            let lowered: BackwardsAuroraLevel = try BackwardsAuroraLevel(
                id: level.id, seed: level.seed, difficulty: level.difficulty, opening: level.opening,
                target: level.target, checkpoints: level.checkpoints, bendLimit: level.bendLimit,
                breakingLimit: level.breakingLimit, shortest: level.shortest, longest: level.longest, budget: short)
            let play: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: lowered)
            #expect(BackwardsAuroraHints.plan(play) == nil)
            let hint: BackwardsAuroraHint? = BackwardsAuroraHints.hint(level: 2, play: play)
            #expect(hint?.kind == .stuck && hint?.action == nil && hint?.text == BackwardsAuroraHint.stuckText)
            checked += 1
        }
        #expect(checked == 5)
    }

    // MARK: Texts and stages

    /// The texts of each hint kind at each level (clarification Q1), and the level clamp.
    @Test func hintTextsAtEachLevel() {
        let reverse = BackwardsAuroraHint(level: 1, kind: .reverse, action: .reverse(3, 6))
        #expect(reverse.text == "Reverse a section of 4 samples")
        #expect(reverse.at(level: 2).text == "Reverse a section of 4 samples starting at sample 3")
        #expect(reverse.at(level: 3).text == "Reverse samples 3 to 6")
        #expect(reverse.at(level: 9).level == 3 && reverse.at(level: -1).level == 1)
        #expect(reverse.at(level: 9).text == "Reverse samples 3 to 6")
        #expect(BackwardsAuroraHint(level: 0, kind: .reverse, action: .reverse(0, 1)).text
                == "Reverse a section of 2 samples")
        for level in 1...3 {
            #expect(BackwardsAuroraHint(level: level, kind: .stuck).text
                    == "No way to fold the aurora back was found in the reversals left: undo the last reversal or "
                    + "retry the level.")
            #expect(BackwardsAuroraHint(level: level, kind: .stuck, failed: true).text
                    == "Undo the last reversal or retry the level.")
        }
        #expect(BackwardsAuroraHintKind.reverse.rawValue == "reverse")
        #expect(BackwardsAuroraHintKind.stuck.rawValue == "stuck")
    }

    /// Loading and tutorial plays get no hint; playing and paused plays the same reversal; won and result-after-win
    /// plays none; failed and result-after-failure plays the failed `stuck` hint.
    @Test func hintsFollowTheStage() throws {
        let catalog: [BackwardsAuroraGenerated] = try hintCatalog()
        let generated: BackwardsAuroraGenerated = try #require(catalog.first { $0.level.tutorial })
        let level: BackwardsAuroraLevel = generated.level
        var play = BackwardsAuroraPlay(level: level)
        #expect(BackwardsAuroraHints.hint(level: 1, play: play) == nil && BackwardsAuroraHints.plan(play) == nil)
        try play.handle(.begin)
        #expect(play.stage == .tutorial && BackwardsAuroraHints.hint(level: 1, play: play) == nil)
        try play.handle(.dismissTutorial)
        let first: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: 2, play: play))
        #expect(first.kind == .reverse && first.level == 2 && first.action == generated.solution.actions[0])
        let (start, end): (Int, Int) = section(generated.solution.actions[0])
        #expect(first.text == "Reverse a section of \(end - start + 1) samples starting at sample \(start)")
        try play.handle(.pause)
        #expect(BackwardsAuroraHints.hint(level: 2, play: play) == first)
        try play.handle(.resume)
        for action in generated.solution.actions { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won && BackwardsAuroraHints.hint(level: 3, play: play) == nil)
        #expect(BackwardsAuroraHints.plan(play) == nil)
        try play.handle(.showResult)
        #expect(BackwardsAuroraHints.hint(level: 3, play: play) == nil)
        // A failed play: a reversal that tears, or else non-tearing reversals until the budget runs out.
        var random = SeededRandom(seed: Self.seed &+ 7)
        var failing: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: level)
        var guardCount: Int = 0
        while failing.stage == .playing && guardCount < 2_000 {
            guardCount += 1
            try? failing.apply(randomReversal(failing, &random), expecting: failing.fingerprint)
            if failing.stage == .won { failing = try BackwardsAuroraExperienceCore.freshPlay(of: level) }
        }
        try #require(failing.stage == .failed)
        let stuck: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: 1, play: failing))
        #expect(stuck.kind == .stuck && stuck.action == nil)
        #expect(stuck.text == "Undo the last reversal or retry the level.")
        #expect(BackwardsAuroraHints.plan(failing) == nil)
        try failing.handle(.showResult)
        #expect(BackwardsAuroraHints.hint(level: 3, play: failing)?.text == BackwardsAuroraHint.failedText)
    }

    // MARK: Failures

    /// 500 seeded failures in 10 groups of 50, group g on levels g + 1, g + 11, … g + 91, one of every ten (the easy
    /// levels' breaking limits leave little to tear; tear runs: random reversals; budget runs: random reversals that
    /// do not tear, judged here before they are sent): each is explained with its
    /// true reason, reversal, section, seam and numbers, tracked here (own reversal index, own seam scan, own counts);
    /// about one in five is shown as a result, one in five is undone and redone first (the failure restored by redo).
    @Test(arguments: Array(0..<10))
    func failuresAreExplained(group: Int) throws {
        var random = SeededRandom(seed: Self.seed &+ 1_000 &+ UInt64(group))
        var explained: Int = 0
        var tears: Int = 0
        var budgets: Int = 0
        var attempts: Int = 0
        let advice: String = " Undo the last reversal or retry the level."
        while explained < 50 && attempts < 5_000 {
            attempts += 1
            let number: Int = 10 * random.int(0...9) + group + 1
            let level: BackwardsAuroraLevel = try BackwardsAuroraExperienceCore.generated(number: number).level
            var play: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: level)
            let tearRun: Bool = random.int(0...1) == 0
            var failingIndex: Int = -1
            var failingAction: BackwardsAuroraAction?
            var ownSeam: Int?
            for _ in 0..<400 {
                guard play.stage == .playing else { break }
                let action: BackwardsAuroraAction = randomReversal(play, &random)
                let (start, end): (Int, Int) = section(action)
                if play.wave.isPalindrome(start: start, end: end) { continue }
                let next: BackwardsAuroraWave = play.wave.reversed(start: start, end: end)
                let torn: Int? = ownTornSeam(next, start: start, end: end, limit: level.breakingLimit)
                if !tearRun && torn != nil { continue }
                let index: Int = play.spent
                try play.apply(action, expecting: play.fingerprint)
                if play.stage == .failed {
                    failingIndex = index
                    failingAction = action
                    ownSeam = torn
                }
            }
            guard play.stage == .failed, let action = failingAction else { continue }
            let mode: Int = random.int(0...4)
            if mode == 0 { try play.handle(.showResult) }
            if mode == 1 {
                try play.undo()
                try play.redo()
                try #require(play.stage == .failed)
            }
            let explanation: BackwardsAuroraFailureExplanation = try #require(
                BackwardsAuroraFailureExplanation(play: play))
            let matched: Int = level.checkpoints.filter { play.wave.samples[$0] == level.target.samples[$0] }.count
            #expect(explanation.matched == matched && explanation.checkpoints == level.checkpoints.count)
            if let seam = ownSeam {
                tears += 1
                let (start, end): (Int, Int) = section(action)
                let s: [Int] = play.wave.samples
                let bend: Int = abs(s[seam - 1] - 2 * s[seam] + s[seam + 1])
                #expect(bend > level.breakingLimit)
                #expect(explanation.failure == .tear(failingIndex, seam) && explanation.reversal == failingIndex + 1)
                #expect(explanation.start == start && explanation.end == end && explanation.seam == seam)
                #expect(explanation.bend == bend && explanation.limit == level.breakingLimit)
                #expect(explanation.text == "Reversal \(failingIndex + 1) (samples \(start) to \(end)) tore the "
                        + "aurora at seam \(seam): a bend of \(bend) against the breaking limit "
                        + "\(level.breakingLimit)." + advice, "\(explanation.text)")
            } else {
                budgets += 1
                var worst: Int = 0
                let s: [Int] = play.wave.samples
                for k in 1...(s.count - 2) { worst = max(worst, abs(s[k - 1] - 2 * s[k] + s[k + 1])) }
                #expect(play.spent == level.budget && failingIndex == level.budget - 1)
                #expect(explanation.failure == .budget && explanation.reversal == level.budget)
                #expect(explanation.start == nil && explanation.end == nil && explanation.seam == nil)
                #expect(explanation.bend == worst && explanation.limit == level.bendLimit)
                #expect(explanation.text == "The reversals ran out: \(level.budget) of \(level.budget) spent with "
                        + "\(matched) of \(level.checkpoints.count) checkpoints matched and a worst bend of \(worst) "
                        + "against the limit \(level.bendLimit)." + advice, "\(explanation.text)")
            }
            // The explanation never changes the play.
            #expect(BackwardsAuroraFailureExplanation(play: play) == explanation)
            explained += 1
        }
        print("BackwardsAuroraHintsTests failures group \(group): \(explained) explained, \(tears) tears, "
              + "\(budgets) budgets")
        #expect(explained == 50 && tears >= 5 && budgets >= 5, "group \(group): \(tears) tears, \(budgets) budgets")
        // No explanation outside a failure.
        let generated: BackwardsAuroraGenerated = try BackwardsAuroraExperienceCore.generated(number: group + 1)
        var opening: BackwardsAuroraPlay = try BackwardsAuroraExperienceCore.freshPlay(of: generated.level)
        #expect(BackwardsAuroraFailureExplanation(play: opening) == nil)
        for action in generated.solution.actions { try opening.apply(action, expecting: opening.fingerprint) }
        #expect(opening.stage == .won && BackwardsAuroraFailureExplanation(play: opening) == nil)
    }
}
