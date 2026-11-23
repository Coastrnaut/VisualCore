// HarmonicBridgesPlayTests — feature 411 (R02-G12-01) T-R02G1201-004 (FR-R02G1201-004 … 008, 013, 014;
// SC-R02G1201-001, 002, 004; clarifications Q3, Q4, Q5). The play of a Harmonic Bridges level: the full stage table of
// `handle(_:)`; the 500 fixtures' known tunings then a test win exactly on the test and never before, with the report
// after every action equal to the level's report at the play's pegs; a failing test names its step and string (checked
// against an independent cut search on the 500 fixtures, on the hand level and on a level with no string across the
// cut); budget failure on the exact action with budgets one action either side, and a test on the last action wins; the
// validation order stage, stale, action (string, peg, locked), no-op, with every refusal reachable, spending nothing and
// leaving the play unchanged; a pluck names the string and its resonance and changes nothing; the fingerprint is the
// SHA-256 of its canonical text; undo of every action restores the exact fingerprint, undo from failed returns to
// playing, a won play is final and a new action clears redo; 500 seeded traces (seed 2_411 onwards) replay to the same
// records, fingerprints and outcome, and tampered traces are refused. Explicit types, plain loops; each test well under
// 10 s.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import HarmonicBridgesCore

struct HarmonicBridgesPlayTests {
    typealias Play = HarmonicBridgesPlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(HarmonicBridgesAction)
        case stale(HarmonicBridgesAction)
        case undo
        case redo
        case event(HarmonicBridgesEvent)
    }

    static let events: [HarmonicBridgesEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(HarmonicBridgesError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: HarmonicBridgesAction) throws(HarmonicBridgesError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> HarmonicBridgesError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused \(op) changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.actionsSpent == play.actionsSpent, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: HarmonicBridgesLevel) throws(HarmonicBridgesError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A level whose goal no string reaches: islands 0, 1, 2; one string 0–1 (a bridge in step 0); start 0, goal 2.
    static func cutLevel() throws -> HarmonicBridgesLevel {
        try HarmonicBridgesLevel(
            id: "cut", seed: 3, difficulty: 1,
            islands: [HarmonicBridgesIsland(x: 0, y: 0), HarmonicBridgesIsland(x: 4, y: 0),
                      HarmonicBridgesIsland(x: 8, y: 0)],
            strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 2)],
            start: 0, goal: 2, steps: [[HarmonicBridgesTone(frequency: 2, strength: 2)]],
            threshold: 2, budget: 3)
    }

    /// The expected break, found independently of the kernel's own rule: the first step whose goal is not reached
    /// (breadth-first from the start over the report's bridges), then the lowest-index string with exactly one end
    /// reached that is not a bridge then.
    static func expectedBreak(_ level: HarmonicBridgesLevel, _ report: HarmonicBridgesReport) -> (Int, Int?)? {
        for step in 0..<level.steps.count {
            var seen: [Bool] = Array(repeating: false, count: level.islands.count)
            seen[level.start] = true
            var changed: Bool = true
            while changed {
                changed = false
                for (index, string) in level.strings.enumerated() where report.bridges[step][index] {
                    if seen[string.a] != seen[string.b] {
                        seen[string.a] = true
                        seen[string.b] = true
                        changed = true
                    }
                }
            }
            if seen[level.goal] { continue }
            for (index, string) in level.strings.enumerated() {
                if seen[string.a] != seen[string.b] && !report.bridges[step][index] { return (step, index) }
            }
            return (step, nil)
        }
        return nil
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(tutorial: true)
        let without: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let tune: HarmonicBridgesAction = .tune(0, 3)

        // loading: only begin.
        var play = Play(level: withTutorial)
        #expect(play.stage == .loading)
        #expect(play.pegs == withTutorial.startingPegs)
        #expect(play.actionsSpent == 0)
        #expect(play.actionsLeft == 6)
        #expect(play.failure == nil)
        #expect(play.report == withTutorial.report(pegs: withTutorial.startingPegs))
        #expect(!play.canUndo && !play.canRedo)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(tune)) == .stage)
        #expect(Self.refusal(play, .act(.test)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(tune)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        try play.handle(.dismissTutorial)
        #expect(play.stage == .playing)

        // Without a tutorial, begin goes straight to playing.
        var direct = Play(level: without)
        try direct.handle(.begin)
        #expect(direct.stage == .playing)

        // playing: pause only.
        for event in Self.events where event != .pause {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        try play.handle(.pause)
        #expect(play.stage == .paused)

        // paused: resume only; actions refused by stage, even stale or invalid ones.
        for event in Self.events where event != .resume {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(tune)) == .stage)
        #expect(Self.refusal(play, .act(.test)) == .stage)
        #expect(Self.refusal(play, .stale(.tune(99, 0))) == .stage)
        try play.handle(.resume)
        #expect(play.stage == .playing)

        // won: showResult only; undo refused (final).
        var won: Play = try Self.playing(without)
        try Self.act(&won, .tune(3, 1))
        try Self.act(&won, .test)
        #expect(won.stage == .won)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(tune)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
        #expect(!won.canUndo && !won.canRedo)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(.test)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)

        // failed: showResult, undo; actions and redo refused.
        var failed: Play = try Self.playing(without)
        try Self.act(&failed, .test)
        #expect(failed.stage == .failed)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(tune)) == .stage)
        #expect(Self.refusal(failed, .act(.test)) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        #expect(failed.canUndo)
        var shown: Play = failed
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        #expect(Self.refusal(shown, .undo) == .stage)
        #expect(!shown.canUndo)
    }

    // MARK: - Known actions

    /// The 500 fixtures: the known tunings keep the play going (the report always the level's at the play's pegs),
    /// and the test after them wins; a test at the starting pegs fails with the independently found break.
    @Test func fixturesWinOnTheTestAfterTheirTunings() throws {
        let fixtures: [HarmonicBridgesFixture] = HarmonicBridgesFixtures.fixtures(500)
        for fixture in fixtures {
            let level: HarmonicBridgesLevel = fixture.level
            var play: Play = try Self.playing(level)
            for (number, tuning) in fixture.winningActions.enumerated() {
                try Self.act(&play, .tune(tuning.string, tuning.peg))
                #expect(play.stage == .playing)
                #expect(play.failure == nil)
                #expect(play.actionsSpent == number + 1)
                #expect(play.pegs[tuning.string] == tuning.peg)
                #expect(play.report == level.report(pegs: play.pegs))
                #expect(play.records.last?.kind == .tune)
            }
            #expect(play.pegs == fixture.winningPegs)
            try Self.act(&play, .test)
            #expect(play.stage == .won, "fixture \(level.seed) did not win")
            #expect(play.failure == nil)
            #expect(play.actionsSpent == fixture.winningActions.count + 1)
            #expect(play.report.goalReachedInEveryStep)
            #expect(play.records.last?.kind == .test)
            #expect(play.records.count == fixture.winningActions.count + 1)

            // A test at the starting pegs fails with the break found independently.
            var early: Play = try Self.playing(level)
            try Self.act(&early, .test)
            #expect(early.stage == .failed)
            #expect(early.actionsSpent == 1)
            if let expected = Self.expectedBreak(level, early.report) {
                #expect(early.failure == .broken(step: expected.0, string: expected.1))
            } else {
                Issue.record("fixture \(level.seed): the starting pegs reach the goal")
            }
        }
    }

    /// The hand level: a test at the start fails in step 1 naming string 0; the winning tuning then wins; a level with no
    /// string across the cut fails naming no string.
    @Test func failingTestNamesStepAndString() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .test)
        #expect(play.stage == .failed)
        #expect(play.failure == .broken(step: 1, string: 0))
        #expect(play.failure?.code == "broken")
        #expect(play.report.reached[0] == [true, true, false, true])
        #expect(play.report.reached[1] == [true, false, true, false])

        try play.undo()
        #expect(play.stage == .playing)
        #expect(play.failure == nil)
        #expect(play.actionsSpent == 0)
        try Self.act(&play, .tune(3, 1))
        #expect(play.report.bridges[1] == [false, false, true, true])
        try Self.act(&play, .test)
        #expect(play.stage == .won)

        // One quarter below the threshold at a sample is not a bridge: threshold 3 breaks string 0 in step 0 (swing
        // 2 6 8 6 2), so step 0 now breaks first, naming string 0.
        var strict: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(threshold: 3))
        try Self.act(&strict, .tune(3, 1))
        try Self.act(&strict, .test)
        #expect(strict.failure == .broken(step: 0, string: 0))

        var cut: Play = try Self.playing(Self.cutLevel())
        try Self.act(&cut, .test)
        #expect(cut.stage == .failed)
        #expect(cut.failure == .broken(step: 0, string: nil))
    }

    // MARK: - Budget

    /// Budget failure on the exact action, with budgets one action either side; a test on the last action decides by
    /// itself (wins or breaks), never `budget`.
    @Test func budgetFailsOnTheExactAction() throws {
        // Budget 2: the second tuning spends the last action and fails budget(1).
        var two: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(budget: 2))
        try Self.act(&two, .tune(0, 3))
        #expect(two.stage == .playing)
        #expect(two.actionsLeft == 1)
        try Self.act(&two, .tune(0, 4))
        #expect(two.stage == .failed)
        #expect(two.failure == .budget(1))
        #expect(two.failure?.code == "budget")
        #expect(two.actionsLeft == 0)
        #expect(two.report == two.level.report(pegs: [4, 4, 3, 5]))

        // Budget 3 (one more): the same two tunings leave play going.
        var three: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(budget: 3))
        try Self.act(&three, .tune(0, 3))
        try Self.act(&three, .tune(0, 4))
        #expect(three.stage == .playing)
        #expect(three.failure == nil)
        #expect(three.actionsLeft == 1)

        // Budget 1 (one fewer): the first tuning fails budget(0).
        var one: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(budget: 1))
        try Self.act(&one, .tune(0, 3))
        #expect(one.stage == .failed)
        #expect(one.failure == .budget(0))

        // A test on the last action wins.
        var last: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(budget: 2))
        try Self.act(&last, .tune(3, 1))
        try Self.act(&last, .test)
        #expect(last.stage == .won)
        #expect(last.failure == nil)
        #expect(last.actionsLeft == 0)

        // A failing test on the last action names the break, not the budget.
        var lastBreak: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(budget: 1))
        try Self.act(&lastBreak, .test)
        #expect(lastBreak.failure == .broken(step: 1, string: 0))
    }

    // MARK: - Refusals

    /// The validation order stage, stale, action (string, peg, locked), no-op, with every refusal reachable; a refused
    /// action spends nothing and leaves the play unchanged.
    @Test func everyRefusalIsReachableInOrder() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(lockedLast: true)
        var play: Play = try Self.playing(level)

        // Nothing to undo or redo.
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))

        // Stale before action: an invalid action with a stale fingerprint is stale.
        #expect(Self.refusal(play, .stale(.tune(99, 13))) == .stale)
        #expect(Self.refusal(play, .stale(.test)) == .stale)
        // Action: unknown string first, then peg, then locked.
        #expect(Self.refusal(play, .act(.tune(4, 1))) == .action("string"))
        #expect(Self.refusal(play, .act(.tune(-1, 1))) == .action("string"))
        #expect(Self.refusal(play, .act(.tune(99, 13))) == .action("string"))
        #expect(Self.refusal(play, .act(.tune(0, 0))) == .action("peg"))
        #expect(Self.refusal(play, .act(.tune(0, 13))) == .action("peg"))
        #expect(Self.refusal(play, .act(.tune(3, 13))) == .action("peg"))
        #expect(Self.refusal(play, .act(.tune(3, 1))) == .action("locked"))
        // Locked before no-op: a locked string's current peg is locked.
        #expect(Self.refusal(play, .act(.tune(3, 5))) == .action("locked"))
        // No-op last.
        #expect(Self.refusal(play, .act(.tune(0, 2))) == .noop)
        #expect(Self.refusal(play, .act(.tune(2, 3))) == .noop)
        // The boundaries of the peg range are accepted.
        #expect(Self.refusal(play, .act(.tune(0, 1))) == nil)
        #expect(Self.refusal(play, .act(.tune(0, 12))) == nil)

        // Stage first: paused refuses even a stale invalid action by stage.
        try play.handle(.pause)
        #expect(Self.refusal(play, .stale(.tune(99, 13))) == .stage)
        try play.handle(.resume)

        // Reason codes.
        let codes: [String] = [HarmonicBridgesError.stage.reasonCode, HarmonicBridgesError.stale.reasonCode,
                               HarmonicBridgesError.action("string").reasonCode, HarmonicBridgesError.noop.reasonCode]
        #expect(codes == ["r02-g12.stage", "r02-g12.stale", "r02-g12.action", "r02-g12.noop"])

        // Nothing was spent or recorded by any refusal.
        #expect(play.actionsSpent == 0)
        #expect(play.records.isEmpty)

        // A redo after a new action is refused.
        try Self.act(&play, .tune(0, 3))
        try play.undo()
        #expect(play.canRedo)
        try Self.act(&play, .tune(1, 5))
        #expect(!play.canRedo)
        #expect(Self.refusal(play, .redo) == .action("redo"))
    }

    // MARK: - Pluck

    /// A pluck names the string and its resonance per step at the current pegs and changes nothing; an unknown string is
    /// refused.
    @Test func pluckIsAQueryInWords() throws {
        var play: Play = try Self.playing(HarmonicBridgesFixtures.handLevel())
        let before: Play = play
        let text: String = try play.pluck(0)
        let expectedText: String = "string 0, island 0 to island 1, peg 2: step 0: mode 1, swing 2 6 8 6 2, a bridge; "
            + "step 1: no modes, swing 0 0 0 0 0, not a bridge"
        #expect(text == expectedText)
        #expect(play == before)
        #expect(throws: HarmonicBridgesError.action("string")) {
            try play.pluck(4)
        }
        #expect(throws: HarmonicBridgesError.action("string")) {
            try play.pluck(-1)
        }
        // After tuning string 3 to peg 1 the pluck follows the new peg.
        try Self.act(&play, .tune(3, 1))
        let tuned: String = try play.pluck(3)
        let expectedTuned: String = "string 3, island 2 to island 3, peg 1: step 0: mode 2, swing 6 6 0 6 6, "
            + "not a bridge; step 1: modes 1 and 3, swing 5 3 8 3 5, a bridge"
        #expect(tuned == expectedTuned)
        // A pluck works in every stage, also loading.
        let loading = Play(level: HarmonicBridgesFixtures.handLevel())
        let early: String = try loading.pluck(2)
        #expect(early.hasPrefix("string 2, island 0 to island 2, peg 3: "))
        #expect(play.progressDescription == play.level.progressDescription(report: play.report, actionsLeft: 5))
    }

    // MARK: - Undo and redo

    /// Undo of every action restores the exact earlier fingerprint, pegs and report; redo restores the later ones; undo
    /// while paused stays paused; undo from failed returns to playing (recorded) and redo restores the failure.
    @Test func undoRestoresExactStates() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        var play: Play = try Self.playing(level)
        let actions: [HarmonicBridgesAction] = [.tune(0, 3), .tune(1, 5), .tune(2, 4), .tune(0, 7)]
        var states: [Play] = [play]
        for action in actions {
            try Self.act(&play, action)
            states.append(play)
        }
        var undone: Int = 0
        for earlier in stride(from: states.count - 2, through: 0, by: -1) {
            let previous: String = play.fingerprint
            try play.undo()
            undone += 1
            #expect(play.fingerprint == states[earlier].fingerprint)
            #expect(play.pegs == states[earlier].pegs)
            #expect(play.actionsSpent == states[earlier].actionsSpent)
            #expect(play.report == states[earlier].report)
            #expect(play.records.last?.kind == .undo)
            #expect(play.records.last?.previous == previous)
            #expect(play.records.last?.next == play.fingerprint)
        }
        #expect(!play.canUndo)
        #expect(play.canRedo)
        for later in 1..<states.count {
            try play.redo()
            #expect(play.fingerprint == states[later].fingerprint)
            #expect(play.pegs == states[later].pegs)
            #expect(play.report == states[later].report)
            #expect(play.records.last?.kind == .redo)
        }
        #expect(play.records.count == actions.count + 2 * undone)

        // Undo while paused stays paused; redo too.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        #expect(play.pegs == states[states.count - 2].pegs)
        try play.redo()
        #expect(play.stage == .paused)
        try play.handle(.resume)
        #expect(play.fingerprint == states[states.count - 1].fingerprint)

        // Undo from a budget failure returns to playing and is recorded; redo restores the failure.
        var failed: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(budget: 2))
        try Self.act(&failed, .tune(0, 3))
        let beforeFail: Play = failed
        try Self.act(&failed, .tune(0, 4))
        #expect(failed.failure == .budget(1))
        let failedPrint: String = failed.fingerprint
        try failed.undo()
        #expect(failed.stage == .playing)
        #expect(failed.failure == nil)
        #expect(failed.actionsSpent == 1)
        #expect(failed.fingerprint == beforeFail.fingerprint)
        #expect(failed.records.last?.kind == .undo)
        #expect(failed.records.last?.previous == failedPrint)
        try failed.redo()
        #expect(failed.stage == .failed)
        #expect(failed.failure == .budget(1))
        #expect(failed.fingerprint == failedPrint)

        // Undo from a broken test returns to playing at the earlier pegs.
        var broken: Play = try Self.playing(level)
        let start: String = broken.fingerprint
        try Self.act(&broken, .test)
        try broken.undo()
        #expect(broken.stage == .playing)
        #expect(broken.fingerprint == start)
        #expect(broken.actionsSpent == 0)
    }

    /// The fingerprint is the SHA-256 of its canonical text and covers pegs, actions, stage and failure.
    @Test func fingerprintIsCanonical() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        var play: Play = try Self.playing(level)
        let text0: String = "{\"actions\":0,\"failure\":\"none\",\"level\":\"" + level.fingerprint
            + "\",\"pegs\":[2,4,3,5],\"schema\":1,\"stage\":\"playing\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text0.utf8)))
        #expect(play.fingerprint.count == 64)
        try Self.act(&play, .test)
        let text1: String = "{\"actions\":1,\"failure\":\"broken 1 0\",\"level\":\"" + level.fingerprint
            + "\",\"pegs\":[2,4,3,5],\"schema\":1,\"stage\":\"failed\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text1.utf8)))

        var cut: Play = try Self.playing(Self.cutLevel())
        try Self.act(&cut, .test)
        let text2: String = "{\"actions\":1,\"failure\":\"broken 0 none\",\"level\":\"" + cut.level.fingerprint
            + "\",\"pegs\":[2],\"schema\":1,\"stage\":\"failed\"}"
        #expect(cut.fingerprint == StableHash.sha256Hex(Array(text2.utf8)))

        var budget: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(budget: 1))
        try Self.act(&budget, .tune(1, 10))
        let text3: String = "{\"actions\":1,\"failure\":\"budget 0\",\"level\":\"" + budget.level.fingerprint
            + "\",\"pegs\":[2,10,3,5],\"schema\":1,\"stage\":\"failed\"}"
        #expect(budget.fingerprint == StableHash.sha256Hex(Array(text3.utf8)))

        // Stage is covered.
        var paused: Play = try Self.playing(level)
        let playingPrint: String = paused.fingerprint
        try paused.handle(.pause)
        #expect(paused.fingerprint != playingPrint)
    }

    // MARK: - Replay

    /// 500 seeded traces (seed 2_411 onwards) of random valid and invalid tunings, tests, undo, redo, pause and resume
    /// replay to the same records, fingerprints and outcome; tampered traces are refused.
    @Test func seededTracesReplayExactly() throws {
        var random = SeededRandom(seed: 2_411)
        let fixtures: [HarmonicBridgesFixture] = HarmonicBridgesFixtures.fixtures(500, from: 2_411)
        var reached: Set<String> = []
        for fixture in fixtures {
            let level: HarmonicBridgesLevel = fixture.level
            var play: Play = try Self.playing(level)
            let count: Int = level.strings.count
            let steps: Int = random.int(4...24)
            for _ in 0..<steps {
                let choice: Int = random.int(0...13)
                let op: Op
                switch choice {
                case 0...2: op = .act(.tune(random.int(-1...count), random.int(0...13)))
                case 3...4: op = .act(.tune(random.int(0...(count - 1)), random.int(1...12)))
                case 5:
                    if fixture.winningActions.isEmpty {
                        op = .act(.test)
                    } else {
                        let tuning: (string: Int, peg: Int) =
                            fixture.winningActions[random.int(0...(fixture.winningActions.count - 1))]
                        op = .act(.tune(tuning.string, tuning.peg))
                    }
                case 6: op = .act(.test)
                case 7...8: op = .undo
                case 9: op = .redo
                case 10: op = .event(.pause)
                case 11: op = .event(.resume)
                case 12:
                    let string: Int = random.int(0...(count - 1))
                    op = .act(.tune(string, play.pegs[string]))
                default: op = .stale(.test)
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
                #expect(play.report == level.report(pegs: play.pegs))
            }
            if play.stage == .won { reached.insert("won") }
            if play.failure != nil { reached.insert("failed-" + (play.failure?.code ?? "")) }
            let replayed: Play = try Play.replay(level: level, records: play.records)
            #expect(replayed.records == play.records)
            #expect(replayed.pegs == play.pegs)
            #expect(replayed.actionsSpent == play.actionsSpent)
            #expect(replayed.report == play.report)
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
                var tampered: [HarmonicBridgesRecord] = play.records
                let r: HarmonicBridgesRecord = tampered[0]
                tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                    action: r.action, previous: r.previous, next: "0000")
                #expect(throws: HarmonicBridgesError.malformed("record 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed &+ 1, index: r.index,
                                                    kind: r.kind, action: r.action, previous: r.previous,
                                                    next: r.next)
                #expect(throws: HarmonicBridgesError.malformed("seed 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = HarmonicBridgesRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                                    action: r.action, previous: r.previous, next: r.next)
                #expect(throws: HarmonicBridgesError.malformed("schema 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                    action: r.action, previous: "0000", next: r.next)
                #expect(throws: HarmonicBridgesError.malformed("replay")) {
                    try Play.replay(level: level, records: tampered)
                }
            }
        }
        let expected: [String] = ["accepted", "action-string", "action-peg", "action-locked", "action-undo",
                                  "action-redo", "r02-g12.noop", "r02-g12.stage", "r02-g12.stale", "won",
                                  "failed-broken", "failed-budget"]
        for name in expected {
            #expect(reached.contains(name), "trace never reached \(name)")
        }
    }

    /// A record whose kind and action disagree, or whose index is changed, is refused.
    @Test func replayRefusesMismatchedRecords() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .tune(3, 1))
        try Self.act(&play, .test)
        let replayed: Play = try Play.replay(level: level, records: play.records)
        #expect(replayed == play)
        let r: HarmonicBridgesRecord = play.records[0]
        var tampered: [HarmonicBridgesRecord] = play.records
        tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .test,
                                            action: r.action, previous: r.previous, next: r.next)
        #expect(throws: HarmonicBridgesError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .tune,
                                            action: nil, previous: r.previous, next: r.next)
        #expect(throws: HarmonicBridgesError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                            action: r.action, previous: r.previous, next: r.next)
        #expect(throws: HarmonicBridgesError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .tune,
                                            action: .tune(3, 2), previous: r.previous, next: r.next)
        #expect(throws: HarmonicBridgesError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        // A replayed action that is refused surfaces its refusal.
        tampered[0] = HarmonicBridgesRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .tune,
                                            action: .tune(9, 1), previous: r.previous, next: r.next)
        #expect(throws: HarmonicBridgesError.action("string")) {
            try Play.replay(level: level, records: tampered)
        }
        // Records round-trip through JSON.
        let data: Data = try JSONEncoder().encode(play.records)
        let decoded: [HarmonicBridgesRecord] = try JSONDecoder().decode([HarmonicBridgesRecord].self, from: data)
        #expect(decoded == play.records)
    }
}
