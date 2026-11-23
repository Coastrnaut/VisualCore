// BackwardsAuroraPlayTests — feature 391 (R02-G10-01) T-R02G1001-004 (FR-R02G1001-004 … 008, 013, 014;
// SC-R02G1001-002, 004; clarifications Q3, Q4, Q5). The play of a Backwards Aurora level: the full stage table of
// `handle(_:)`; the 500 fixtures' known reversals win exactly on their last reversal, each spending one, with the truth
// metric equal to an independent computation; a seam bend equal to the breaking limit B survives and one of B + 1
// tears at the lowest breaking seam, naming the reversal; tear is judged before win and budget; the budget fails on the
// exact reversal with budgets one reversal either side; a win on the last reversal of the budget wins; the validation
// order stage, stale, range and length, no-op, with every refusal reachable, spending nothing and leaving the play
// unchanged; undo from failed returns to playing, a won play is final; undo of every reversal restores the exact
// fingerprint and a new reversal clears redo; 500 seeded traces (seed 2_391) replay to the same records, fingerprints
// and outcome, and a tampered trace is refused. Explicit types, plain loops; each test well under 10 s.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

struct BackwardsAuroraPlayTests {
    typealias Play = BackwardsAuroraPlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(Int, Int)
        case stale(Int, Int)
        case undo
        case redo
        case event(BackwardsAuroraEvent)
    }

    static let events: [BackwardsAuroraEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    /// The straight wave 0, 2, 4, … 22 (every bend 0).
    static let straight: [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]

    static func perform(_ op: Op, _ play: inout Play) throws(BackwardsAuroraError) {
        switch op {
        case let .act(start, end): try play.apply(.reverse(start, end), expecting: play.fingerprint)
        case let .stale(start, end): try play.apply(.reverse(start, end), expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ start: Int, _ end: Int) throws(BackwardsAuroraError) {
        try play.apply(.reverse(start, end), expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> BackwardsAuroraError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused \(op) changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.spent == play.spent, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: BackwardsAuroraLevel) throws(BackwardsAuroraError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// `samples` with the section [start, end] reversed.
    static func reversed(_ samples: [Int], _ start: Int, _ end: Int) -> [Int] {
        var result: [Int] = samples
        result.replaceSubrange(start...end, with: samples[start...end].reversed())
        return result
    }

    /// A hand level of the given values.
    static func level(opening: [Int], target: [Int], checkpoints: [Int], bendLimit: Int, breakingLimit: Int,
                      shortest: Int = 2, longest: Int = 12, budget: Int = 5,
                      tutorial: Bool = false) throws -> BackwardsAuroraLevel {
        try BackwardsAuroraLevel(id: "hand", seed: 391, difficulty: 1, opening: BackwardsAuroraWave(opening),
                                 target: BackwardsAuroraWave(target), checkpoints: checkpoints, bendLimit: bendLimit,
                                 breakingLimit: breakingLimit, shortest: shortest, longest: longest, budget: budget,
                                 tutorial: tutorial)
    }

    /// The tear level: the straight opening, the target with [4, 7] reversed, checkpoints 4 and 7. Reversing [4, 7]
    /// matches every checkpoint and leaves the seam bends 6, −10, 10, −6 at positions 3, 4, 7, 8.
    static func tearLevel(bendLimit: Int, breakingLimit: Int, budget: Int = 5) throws -> BackwardsAuroraLevel {
        try level(opening: straight, target: reversed(straight, 4, 7), checkpoints: [4, 7], bendLimit: bendLimit,
                  breakingLimit: breakingLimit, budget: budget)
    }

    /// The budget level: the straight opening, the target with [2, 5] reversed, checkpoints 2 and 9; reversing [0, 1]
    /// never changes checkpoint 2, so it never wins and (B = 128) never tears.
    static func budgetLevel(budget: Int) throws -> BackwardsAuroraLevel {
        try level(opening: straight, target: reversed(straight, 2, 5), checkpoints: [2, 9], bendLimit: 1,
                  breakingLimit: 128, budget: budget)
    }

    /// The win level: the opening with [2, 5] reversed, the straight target, checkpoints 2 and 9, L = 4; reversing
    /// [2, 5] wins, reversing [0, 1] twice changes nothing in the end.
    static func winLevel(budget: Int, tutorial: Bool = false) throws -> BackwardsAuroraLevel {
        try level(opening: reversed(straight, 2, 5), target: straight, checkpoints: [2, 9], bendLimit: 4,
                  breakingLimit: 128, budget: budget, tutorial: tutorial)
    }

    /// The level with palindromes: 0, 3, 6, 9, 12, 9, 6, 3, 0, 3, 6, 9 (sections [2, 6], [1, 7] and [7, 9] read
    /// the same both ways), the target with the first two samples swapped, sections of 3 … 6.
    static func palindromeLevel() throws -> BackwardsAuroraLevel {
        let opening: [Int] = [0, 3, 6, 9, 12, 9, 6, 3, 0, 3, 6, 9]
        return try level(opening: opening, target: reversed(opening, 0, 1), checkpoints: [0, 1], bendLimit: 64,
                         breakingLimit: 128, shortest: 3, longest: 6)
    }

    /// `base` with another budget.
    static func level(_ base: BackwardsAuroraLevel, budget: Int) throws -> BackwardsAuroraLevel {
        try BackwardsAuroraLevel(id: base.id, seed: base.seed, difficulty: base.difficulty, opening: base.opening,
                                 target: base.target, checkpoints: base.checkpoints, bendLimit: base.bendLimit,
                                 breakingLimit: base.breakingLimit, shortest: base.shortest, longest: base.longest,
                                 budget: budget, tutorial: base.tutorial)
    }

    /// Checks the play's truth metric and checkpoints against an independent computation from its wave.
    static func checkMeasures(_ play: Play, sourceLocation: SourceLocation = #_sourceLocation) {
        let samples: [Int] = play.wave.samples
        let target: [Int] = play.level.target.samples
        var numerator: Int = 0
        var denominator: Int = 0
        for k in 0..<samples.count {
            numerator += abs(samples[k] - target[k])
            denominator += abs(target[k])
        }
        if denominator == 0 { denominator = 1 }
        #expect(play.distance.numerator == numerator, sourceLocation: sourceLocation)
        #expect(play.distance.denominator == denominator, sourceLocation: sourceLocation)
        var worst: Int = 0
        for k in 1..<(samples.count - 1) {
            worst = max(worst, abs(samples[k - 1] - 2 * samples[k] + samples[k + 1]))
        }
        #expect(play.worstBend == worst, sourceLocation: sourceLocation)
        var matched: [Bool] = []
        for position in play.level.checkpoints { matched.append(samples[position] == target[position]) }
        #expect(play.matched == matched, sourceLocation: sourceLocation)
        #expect(play.remaining == play.level.budget - play.spent, sourceLocation: sourceLocation)
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: BackwardsAuroraLevel = try Self.winLevel(budget: 3, tutorial: true)
        let without: BackwardsAuroraLevel = try Self.winLevel(budget: 3)

        // loading: only begin.
        var play = Play(level: withTutorial)
        #expect(play.stage == .loading)
        #expect(play.spent == 0)
        #expect(play.remaining == 3)
        #expect(play.wave == withTutorial.opening)
        #expect(play.failure == nil)
        #expect(!play.canUndo && !play.canRedo)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(2, 5)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(2, 5)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        try play.handle(.dismissTutorial)
        #expect(play.stage == .playing)

        // Without a tutorial, begin goes straight to playing.
        var direct = Play(level: without)
        try direct.handle(.begin)
        #expect(direct.stage == .playing)

        // playing: pause only (resume, begin, dismissTutorial, showResult refused).
        for event in Self.events where event != .pause {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        try play.handle(.pause)
        #expect(play.stage == .paused)

        // paused: resume only; reversals refused by stage, even stale ones.
        for event in Self.events where event != .resume {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(2, 5)) == .stage)
        #expect(Self.refusal(play, .stale(2, 5)) == .stage)
        try play.handle(.resume)
        #expect(play.stage == .playing)

        // won: showResult only; undo and redo refused (won is final).
        try Self.act(&play, 2, 5)
        #expect(play.stage == .won)
        #expect(play.spent == 1)
        #expect(!play.canUndo)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(0, 1)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.showResult)
        #expect(play.stage == .result)

        // result: everything refused.
        for event in Self.events {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(0, 1)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)

        // failed: showResult and undo; reversals, redo and other events refused.
        var failed: Play = try Self.playing(Self.budgetLevel(budget: 1))
        try Self.act(&failed, 0, 1)
        #expect(failed.stage == .failed)
        #expect(failed.failure == .budget)
        #expect(failed.canUndo && !failed.canRedo)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(0, 1)) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        var shown: Play = failed
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        #expect(Self.refusal(shown, .undo) == .stage)
    }

    // MARK: - Fixtures

    /// The 500 fixtures' known reversals win exactly on their last reversal, each spending one, never tearing.
    @Test func fixturesWinOnTheExactLastKnownReversal() throws {
        let fixtures: [BackwardsAuroraFixture] = BackwardsAuroraFixtures.fixtures(500)
        #expect(fixtures.count == 500)
        for fixture in fixtures {
            var play: Play = try Self.playing(fixture.level)
            Self.checkMeasures(play)
            let last: Int = fixture.sections.count - 1
            for index in 0...last {
                let section: (start: Int, end: Int) = fixture.sections[index]
                let before: String = play.fingerprint
                try Self.act(&play, section.start, section.end)
                #expect(play.spent == index + 1)
                #expect(play.wave == fixture.waves[index])
                #expect(play.records.count == index + 1)
                #expect(play.records[index].previous == before)
                #expect(play.records[index].next == play.fingerprint)
                #expect(play.records[index].move == index)
                #expect(play.records[index].kind == .reverse)
                #expect(play.records[index].action == .reverse(section.start, section.end))
                #expect(play.records[index].seed == fixture.level.seed)
                #expect(play.records[index].schema == Play.schema)
                Self.checkMeasures(play)
                if index < last {
                    #expect(play.stage == .playing)
                    #expect(play.failure == nil)
                }
            }
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.distance.numerator == 0)
            #expect(play.matched.allSatisfy { $0 })
        }
    }

    /// A win on the last reversal of the budget wins (fixtures with the budget cut to their known reversals and a
    /// hand level of budgets 1 and 3).
    @Test func aWinOnTheLastReversalOfTheBudgetWins() throws {
        let fixtures: [BackwardsAuroraFixture] = BackwardsAuroraFixtures.fixtures(100)
        for fixture in fixtures {
            let exact: BackwardsAuroraLevel = try Self.level(fixture.level, budget: fixture.sections.count)
            var play: Play = try Self.playing(exact)
            for section in fixture.sections { try Self.act(&play, section.start, section.end) }
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.remaining == 0)
        }
        var one: Play = try Self.playing(Self.winLevel(budget: 1))
        try Self.act(&one, 2, 5)
        #expect(one.stage == .won)
        #expect(one.wave.samples == Self.straight)
        var three: Play = try Self.playing(Self.winLevel(budget: 3))
        try Self.act(&three, 0, 1)
        try Self.act(&three, 0, 1)
        #expect(three.stage == .playing)
        try Self.act(&three, 2, 5)
        #expect(three.stage == .won)
        #expect(three.spent == 3)
        #expect(three.remaining == 0)
    }

    // MARK: - Tear

    /// A seam bend equal to B survives; one of B + 1 tears at the lowest breaking seam, naming the reversal.
    @Test func aSeamBendEqualToTheBreakingLimitSurvivesAndOneMoreTears() throws {
        // The hand-computed seam bends after reversing [4, 7] of the straight wave.
        let after: BackwardsAuroraWave = try BackwardsAuroraWave(Self.straight).reversed(start: 4, end: 7)
        #expect(BackwardsAuroraWave.seams(start: 4, end: 7, count: 12) == [3, 4, 7, 8])
        #expect(after.bend(at: 3) == 6)
        #expect(after.bend(at: 4) == -10)
        #expect(after.bend(at: 7) == 10)
        #expect(after.bend(at: 8) == -6)

        // B = 10 (the worst seam bend exactly): survives, and with L = 10 the reversal wins.
        var survives: Play = try Self.playing(Self.tearLevel(bendLimit: 10, breakingLimit: 10))
        try Self.act(&survives, 4, 7)
        #expect(survives.stage == .won)
        #expect(survives.failure == nil)
        #expect(survives.worstBend == 10)

        // B = 10 with L = 9: survives, not smooth, still playing.
        var rough: Play = try Self.playing(Self.tearLevel(bendLimit: 9, breakingLimit: 10))
        try Self.act(&rough, 4, 7)
        #expect(rough.stage == .playing)
        #expect(rough.failure == nil)

        // B = 9: bends 10 at positions 4 and 7 are B + 1; the lowest, 4, tears on reversal 0.
        var tears: Play = try Self.playing(Self.tearLevel(bendLimit: 9, breakingLimit: 9))
        try Self.act(&tears, 4, 7)
        #expect(tears.stage == .failed)
        #expect(tears.failure == .tear(0, 4))
        #expect(tears.failure?.code == "tear")
        #expect(tears.spent == 1)
        #expect(tears.records.count == 1)
        #expect(tears.records[0].next == tears.fingerprint)

        // B = 5: every seam is beyond; the lowest, 3, is named.
        var lowest: Play = try Self.playing(Self.tearLevel(bendLimit: 5, breakingLimit: 5))
        try Self.act(&lowest, 4, 7)
        #expect(lowest.failure == .tear(0, 3))

        // A tear on the second reversal names reversal 1 (the first, [0, 1], leaves seam bends 6 and −2).
        var later: Play = try Self.playing(Self.tearLevel(bendLimit: 9, breakingLimit: 9))
        try Self.act(&later, 0, 1)
        #expect(later.stage == .playing)
        try Self.act(&later, 4, 7)
        #expect(later.failure == .tear(1, 4))
    }

    /// Tear is judged first: a tearing reversal that matches every checkpoint fails (since B ≥ L, a tear also means
    /// the wave is not smooth, so it can never win), and a tearing reversal on the last of the budget is a tear, not a
    /// budget failure.
    @Test func tearIsJudgedBeforeWinAndBudget() throws {
        var matching: Play = try Self.playing(Self.tearLevel(bendLimit: 9, breakingLimit: 9))
        try Self.act(&matching, 4, 7)
        #expect(matching.matched == [true, true])
        #expect(matching.stage == .failed)
        #expect(matching.failure == .tear(0, 4))

        var last: Play = try Self.playing(Self.tearLevel(bendLimit: 9, breakingLimit: 9, budget: 1))
        try Self.act(&last, 4, 7)
        #expect(last.stage == .failed)
        #expect(last.failure == .tear(0, 4))
        #expect(last.remaining == 0)
    }

    // MARK: - Budget

    /// The budget fails on the exact reversal, with budgets one reversal either side; further reversals are refused by
    /// stage and undo returns to playing.
    @Test func theBudgetFailsOnTheExactReversal() throws {
        for budget in 1...5 {
            var play: Play = try Self.playing(Self.budgetLevel(budget: budget))
            for index in 0..<budget {
                #expect(play.stage == .playing)
                try Self.act(&play, 0, 1)
                #expect(play.spent == index + 1)
                if index < budget - 1 {
                    #expect(play.stage == .playing, "budget \(budget) failed early at \(index + 1)")
                    #expect(play.failure == nil)
                }
            }
            #expect(play.stage == .failed)
            #expect(play.failure == .budget)
            #expect(play.failure?.code == "budget")
            #expect(play.remaining == 0)
            #expect(Self.refusal(play, .act(0, 1)) == .stage)
            // Undo from failed: an honest retry back to playing, recorded, spending nothing.
            let failedPrint: String = play.fingerprint
            try play.undo()
            #expect(play.stage == .playing)
            #expect(play.failure == nil)
            #expect(play.spent == budget - 1)
            #expect(play.records.last?.kind == .undo)
            #expect(play.records.last?.previous == failedPrint)
            // Redo brings the failure back exactly.
            try play.redo()
            #expect(play.stage == .failed)
            #expect(play.fingerprint == failedPrint)
        }
    }

    // MARK: - Validation

    /// Every refusal reason is reachable, in the order stage, stale, range and length, no-op; refusals change nothing.
    @Test func everyRefusalIsReachableInOrder() throws {
        let level: BackwardsAuroraLevel = try Self.palindromeLevel()
        var play: Play = try Self.playing(level)
        // .action, by name.
        #expect(Self.refusal(play, .act(0, 12)) == .action("end"))
        #expect(Self.refusal(play, .act(0, -1)) == .action("end"))
        #expect(Self.refusal(play, .act(-1, 3)) == .action("start"))
        #expect(Self.refusal(play, .act(5, 5)) == .action("start"))
        #expect(Self.refusal(play, .act(6, 4)) == .action("start"))
        #expect(Self.refusal(play, .act(0, 1)) == .action("length"))
        #expect(Self.refusal(play, .act(0, 6)) == .action("length"))
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))
        // .noop for palindromes; the length check comes first ([1, 7] is a palindrome of length 7).
        #expect(Self.refusal(play, .act(2, 6)) == .noop)
        #expect(Self.refusal(play, .act(7, 9)) == .noop)
        #expect(Self.refusal(play, .act(1, 7)) == .action("length"))
        // .stale before the range.
        #expect(Self.refusal(play, .stale(0, 12)) == .stale)
        #expect(Self.refusal(play, .stale(0, 2)) == .stale)
        // .stage before stale.
        try play.handle(.pause)
        #expect(Self.refusal(play, .stale(0, 12)) == .stage)
        try play.handle(.resume)
        // A valid reversal is accepted.
        try Self.act(&play, 0, 2)
        #expect(play.spent == 1)
        #expect(play.wave.samples[0] == 6)
        #expect(BackwardsAuroraError.noop.reasonCode == "r02-g10.noop")
    }

    // MARK: - Undo and redo

    /// Undo of every reversal restores the exact fingerprints (spending nothing); redo replays them; a new reversal
    /// clears redo; undo and redo work while paused and keep the pause.
    @Test func undoAndRedoRestoreExactFingerprints() throws {
        let fixtures: [BackwardsAuroraFixture] = BackwardsAuroraFixtures.fixtures(100)
        for fixture in fixtures {
            var play: Play = try Self.playing(fixture.level)
            var prints: [String] = [play.fingerprint]
            var waves: [BackwardsAuroraWave] = [play.wave]
            for section in fixture.sections.dropLast() {
                try Self.act(&play, section.start, section.end)
                prints.append(play.fingerprint)
                waves.append(play.wave)
            }
            let steps: Int = prints.count - 1
            for back in 0..<steps {
                try play.undo()
                let index: Int = steps - 1 - back
                #expect(play.fingerprint == prints[index])
                #expect(play.wave == waves[index])
                #expect(play.spent == index)
                #expect(play.records.last?.kind == .undo)
                #expect(play.records.last?.action == nil)
            }
            #expect(!play.canUndo)
            for forward in 0..<steps {
                try play.redo()
                #expect(play.fingerprint == prints[forward + 1])
                #expect(play.spent == forward + 1)
            }
            #expect(!play.canRedo)
        }

        // While paused: undo and redo keep the pause; a new reversal clears redo.
        var play: Play = try Self.playing(Self.budgetLevel(budget: 5))
        try Self.act(&play, 0, 1)
        let afterOne: String = play.fingerprint
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        #expect(play.spent == 0)
        #expect(play.wave.samples == Self.straight)
        #expect(play.canRedo)
        try play.redo()
        #expect(play.stage == .paused)
        try play.handle(.resume)
        #expect(play.fingerprint == afterOne)
        try play.undo()
        #expect(play.canRedo)
        try Self.act(&play, 10, 11)
        #expect(!play.canRedo)
        #expect(Self.refusal(play, .redo) == .action("redo"))
    }

    // MARK: - Replay

    /// 500 seeded traces (seed 2_391) of random valid and invalid reversals, undo, redo, pause and resume replay to the
    /// same records, fingerprints and outcome; a tampered trace is refused.
    @Test func seededTracesReplayExactly() throws {
        var random = SeededRandom(seed: 2_391)
        let fixtures: [BackwardsAuroraFixture] = BackwardsAuroraFixtures.fixtures(500)
        var reached: Set<String> = []
        for fixture in fixtures {
            let level: BackwardsAuroraLevel = fixture.level
            var play: Play = try Self.playing(level)
            let count: Int = level.count
            let steps: Int = random.int(4...30)
            for _ in 0..<steps {
                let choice: Int = random.int(0...11)
                let op: Op
                switch choice {
                case 0...5: op = .act(random.int(-1...count), random.int(-1...count))
                case 6:
                    let next: Int = min(play.spent, fixture.sections.count - 1)
                    op = .act(fixture.sections[next].start, fixture.sections[next].end)
                case 7: op = .undo
                case 8: op = .redo
                case 9: op = .event(.pause)
                case 10: op = .event(.resume)
                default: op = .stale(random.int(0...(count - 1)), random.int(0...(count - 1)))
                }
                let before: Play = play
                do {
                    try Self.perform(op, &play)
                    if case .act = op { reached.insert("accepted") }
                } catch {
                    #expect(play == before)
                    switch error {
                    case .action(let name): reached.insert("action-" + name)
                    default: reached.insert(error.reasonCode)
                    }
                }
            }
            let replayed: Play = try Play.replay(level: level, records: play.records)
            #expect(replayed.records == play.records)
            #expect(replayed.wave == play.wave)
            #expect(replayed.spent == play.spent)
            #expect(replayed.failure == play.failure)
            if let last = play.records.last {
                #expect(replayed.fingerprint == last.next)
            }
            // Pauses are not records: align a trailing pause or resume, then the plays agree exactly.
            var aligned: Play = replayed
            if aligned.stage == .playing && play.stage == .paused {
                try aligned.handle(.pause)
            } else if aligned.stage == .paused && play.stage == .playing {
                try aligned.handle(.resume)
            }
            #expect(aligned == play)
            #expect(aligned.fingerprint == play.fingerprint)
            if play.records.count > 0 {
                var tampered: [BackwardsAuroraRecord] = play.records
                let r: BackwardsAuroraRecord = tampered[0]
                tampered[0] = BackwardsAuroraRecord(schema: r.schema, seed: r.seed, move: r.move, kind: r.kind,
                                                    action: r.action, previous: r.previous, next: "0000")
                #expect(throws: BackwardsAuroraError.malformed("record 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = BackwardsAuroraRecord(schema: r.schema, seed: r.seed &+ 1, move: r.move, kind: r.kind,
                                                    action: r.action, previous: r.previous, next: r.next)
                #expect(throws: BackwardsAuroraError.malformed("seed 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = BackwardsAuroraRecord(schema: 2, seed: r.seed, move: r.move, kind: r.kind,
                                                    action: r.action, previous: r.previous, next: r.next)
                #expect(throws: BackwardsAuroraError.malformed("schema 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = BackwardsAuroraRecord(schema: r.schema, seed: r.seed, move: r.move, kind: r.kind,
                                                    action: r.action, previous: "0000", next: r.next)
                #expect(throws: BackwardsAuroraError.malformed("replay")) {
                    try Play.replay(level: level, records: tampered)
                }
            }
        }
        let expected: [String] = ["accepted", "action-end", "action-start", "action-undo", "action-redo",
                                  "r02-g10.stage", "r02-g10.stale"]
        for reason in expected {
            #expect(reached.contains(reason), "trace never reached \(reason)")
        }
    }

    /// The record trace is Codable and round-trips through JSON.
    @Test func recordsRoundTripThroughJSON() throws {
        var play: Play = try Self.playing(Self.winLevel(budget: 4))
        try Self.act(&play, 0, 1)
        try play.undo()
        try play.redo()
        try Self.act(&play, 0, 1)
        try Self.act(&play, 2, 5)
        let data: Data = try JSONEncoder().encode(play.records)
        let decoded: [BackwardsAuroraRecord] = try JSONDecoder().decode([BackwardsAuroraRecord].self, from: data)
        #expect(decoded == play.records)
        let replayed: Play = try Play.replay(level: play.level, records: decoded)
        #expect(replayed.fingerprint == play.fingerprint)
        #expect(replayed.stage == .won)
    }

    // MARK: - Words

    /// The level's names in words read the play's wave; the play leaves them unaffected.
    @Test func wordsReadThePlaysWave() throws {
        var play: Play = try Self.playing(Self.winLevel(budget: 2))
        let level: BackwardsAuroraLevel = play.level
        #expect(level.checkpointName(0, wave: play.wave) == "checkpoint 1 at position 2: height 10, target 4, not matched")
        #expect(level.bendDescription(play.wave).hasSuffix("too sharp"))
        #expect(BackwardsAuroraLevel.reversalsText(play.remaining) == "2 reversals left")
        try Self.act(&play, 2, 5)
        #expect(level.checkpointName(0, wave: play.wave) == "checkpoint 1 at position 2: height 4, target 4, matched")
        #expect(level.checkpointName(1, wave: play.wave) == "checkpoint 2 at position 9: height 18, target 18, matched")
        #expect(level.bendDescription(play.wave) == "worst bend 0 of limit 4, smooth")
        #expect(level.sampleName(3, wave: play.wave) == "sample at position 3: height 6")
        #expect(BackwardsAuroraLevel.reversalsText(play.remaining) == "1 reversal left")
        #expect(level == play.level)
    }
}
