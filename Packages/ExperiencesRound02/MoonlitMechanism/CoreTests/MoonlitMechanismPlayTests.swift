// MoonlitMechanismPlayTests — feature 431 (R02-G14-01) T-R02G1401-004 (FR-R02G1401-004 … 008, 011, 014;
// SC-R02G1401-002, 003, 004; clarifications Q2, Q4, Q5). The play of a Moonlit Mechanism level: the full stage table of
// `handle(_:)`; the fixtures' known actions keep the play going (the phases after each action equal the fixtures' own
// `apply`, the report always the level's run of the set-up) and win exactly on the closing run; each failure named on
// hand levels (`jammed` with its child, `forbidden` with its key frame and cell, `missing` and `stray` with their key
// frame and count); budget failure on the exact action with budgets one action either side, and a run on the last
// action wins; the validation order stage, stale, action (gear, driver, step, lamp) with every refusal reachable,
// spending nothing and leaving the play unchanged; the fingerprint is the SHA-256 of its canonical text; undo of every
// action restores the exact fingerprint, undo from failed returns to playing, a won play is final and a new action
// clears redo; 500 seeded traces replay to the same records, fingerprints and outcome, and tampered traces are refused.
// Explicit types, plain loops, short traces; each test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import MoonlitMechanismCore

struct MoonlitMechanismPlayTests {
    typealias Play = MoonlitMechanismPlay
    typealias Action = MoonlitMechanismAction

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(Action)
        case stale(Action)
        case undo
        case redo
        case event(MoonlitMechanismEvent)
    }

    static let events: [MoonlitMechanismEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(MoonlitMechanismError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: Action) throws(MoonlitMechanismError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> MoonlitMechanismError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused op changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.actionsSpent == play.actionsSpent, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: MoonlitMechanismLevel) throws(MoonlitMechanismError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A gear of 6 teeth with one solid blade (bit 0) whose slot k covers the single offset (k, 0); at phase q its
    /// shadow is the one cell (centre column + q, centre row + height · 1).
    static func gear(row: Int, phase: Int, parent: Int?, alignment: Int) -> MoonlitMechanismGear {
        var slots: [[MoonlitMechanismCell]] = []
        for k in 0..<6 { slots.append([MoonlitMechanismCell(column: k, row: 0)]) }
        var blades: [Bool] = Array(repeating: false, count: 6)
        blades[0] = true
        return MoonlitMechanismGear(teeth: 6, phase: phase, blades: blades, depth: 1,
                                    centre: MoonlitMechanismCell(column: 2, row: row), parent: parent,
                                    alignment: alignment, slots: slots)
    }

    /// The hand level: a 10 × 8 wall, the driver on row 2 and one child on row 5 (meshing divisor 6, alignment 0), both
    /// at phase 0, two lamp heights starting at 0. Key frame 0 (turns 0) casts cells 22 and 52; key frame 1 (turns 1:
    /// phases 1 and 5) casts cells 23 and 57. By default both are required with exactly those targets, so a run of the
    /// start wins.
    static func hand(frames: [MoonlitMechanismKeyFrame]? = nil, forbidden: [Int] = [], allowance: Int = 0,
                     budget: Int = 5, tutorial: Bool = false, gears: Int = 2) throws(MoonlitMechanismError)
        -> MoonlitMechanismLevel {
        let keyFrames: [MoonlitMechanismKeyFrame] = frames ?? [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [23, 57], required: true),
        ]
        var train: [MoonlitMechanismGear] = [gear(row: 2, phase: 0, parent: nil, alignment: 0),
                                             gear(row: 5, phase: 0, parent: 0, alignment: 0)]
        if gears == 3 { train.append(gear(row: 6, phase: 0, parent: 0, alignment: 0)) }
        return try MoonlitMechanismLevel(id: "play-case", seed: 88, difficulty: 1, gears: train, width: 10, rows: 8,
                                         lampHeights: 2, startingHeight: 0, keyFrames: keyFrames,
                                         forbidden: forbidden, allowance: allowance, budget: budget,
                                         tutorial: tutorial)
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: MoonlitMechanismLevel = try Self.hand(tutorial: true)
        let without: MoonlitMechanismLevel = try Self.hand()
        let turn: Action = .turn(1)

        // loading: only begin.
        var play = Play(level: withTutorial)
        #expect(play.stage == .loading)
        #expect(play.phases == [0, 0])
        #expect(play.height == 0)
        #expect(play.actionsSpent == 0)
        #expect(play.actionsLeft == 5)
        #expect(play.failure == nil)
        #expect(play.records.isEmpty)
        #expect(play.report == withTutorial.run(phases: [0, 0], height: 0))
        #expect(!play.canUndo && !play.canRedo)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(turn)) == .stage)
        #expect(Self.refusal(play, .act(.run)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(play, .event(event)) == .stage)
        }
        #expect(Self.refusal(play, .act(turn)) == .stage)
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
        #expect(Self.refusal(play, .act(turn)) == .stage)
        #expect(Self.refusal(play, .act(.run)) == .stage)
        #expect(Self.refusal(play, .stale(.reseat(99, 99))) == .stage)
        try play.handle(.resume)
        #expect(play.stage == .playing)

        // won: showResult only; undo refused (final).
        var won: Play = try Self.playing(without)
        try Self.act(&won, .run)
        #expect(won.stage == .won)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(turn)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
        #expect(!won.canUndo && !won.canRedo)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(.run)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)

        // failed: showResult, undo; actions and redo refused.
        var failed: Play = try Self.playing(without)
        try Self.act(&failed, .reseat(1, 1))
        try Self.act(&failed, .run)
        #expect(failed.stage == .failed)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(turn)) == .stage)
        #expect(Self.refusal(failed, .act(.run)) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        #expect(failed.canUndo)
        var shown: Play = failed
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        #expect(Self.refusal(shown, .undo) == .stage)
        #expect(!shown.canUndo)
        #expect(MoonlitMechanismStage.allCases.count == 7)
    }

    // MARK: - Known actions

    /// 200 fixtures: the known turns, re-seats and lamp steps keep the play going (the phases and height after each
    /// equal the fixtures' own `apply`, the report the level's run of the set-up), and the closing run wins with the
    /// report of the solution.
    @Test func fixturesWinOnTheExactRun() throws {
        let fixtures: [MoonlitMechanismFixture] = MoonlitMechanismFixture.all(count: 200)
        #expect(fixtures.count == 200)
        for fixture in fixtures {
            let level: MoonlitMechanismLevel = fixture.level
            var play: Play = try Self.playing(level)
            var phases: [Int] = level.startingPhases
            var height: Int = level.startingHeight
            let count: Int = fixture.actions.count
            for number in 0..<(count - 1) {
                let action: Action = fixture.actions[number]
                #expect(action != .run)
                guard let next = MoonlitMechanismFixture.apply(action, gears: level.gears, phases: phases,
                                                               height: height, lampHeights: level.lampHeights) else {
                    Issue.record("fixture action refused by the fixtures' apply")
                    return
                }
                (phases, height) = next
                try Self.act(&play, action)
                #expect(play.stage == .playing)
                #expect(play.failure == nil)
                #expect(play.actionsSpent == number + 1)
                #expect(play.phases == phases)
                #expect(play.height == height)
                #expect(play.report == level.run(phases: phases, height: height))
                #expect(play.records.last?.kind == Play.kind(of: action))
            }
            #expect(play.phases == fixture.solution)
            #expect(play.height == fixture.solutionHeight)
            #expect(fixture.actions[count - 1] == .run)
            try Self.act(&play, .run)
            #expect(play.stage == .won, "fixture did not win")
            #expect(play.failure == nil)
            #expect(play.actionsSpent == count)
            #expect(play.report == level.run(phases: fixture.solution, height: fixture.solutionHeight))
            #expect(play.report.outcome == .won)
            #expect(play.records.count == count)
            #expect(play.records.last?.kind == .run)
        }
    }

    // MARK: - Failures

    /// Each run failure is named: `jammed` with its child, `forbidden` with its key frame and lowest cell, `missing`
    /// and `stray` with their key frame and count; the report names the same and lists every pair and key frame.
    @Test func runFailuresAreNamed() throws {
        // jammed: re-seating the child breaks its mesh by one tooth.
        var jam: Play = try Self.playing(try Self.hand())
        try Self.act(&jam, .reseat(1, 1))
        #expect(jam.report.errors == [0, 1])
        #expect(jam.report.frames.count == 2)
        try Self.act(&jam, .run)
        #expect(jam.stage == .failed)
        #expect(jam.failure == .jammed(1))
        #expect(jam.failure?.code == "jammed")

        // jammed names the first misaligned child of three.
        var jam3: Play = try Self.playing(try Self.hand(gears: 3))
        try Self.act(&jam3, .reseat(2, -1))
        try Self.act(&jam3, .reseat(1, 1))
        try Self.act(&jam3, .run)
        #expect(jam3.report.errors == [0, 1, 1])
        #expect(jam3.failure == .jammed(1))

        // forbidden: key frame 1 (not required) casts 23 and 57, both forbidden; the lowest is named.
        let frames1: [MoonlitMechanismKeyFrame] = [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [79], required: false),
        ]
        var forbid: Play = try Self.playing(try Self.hand(frames: frames1, forbidden: [23, 57]))
        try Self.act(&forbid, .run)
        #expect(forbid.failure == .forbidden(frame: 1, cell: 23))
        #expect(forbid.failure?.code == "forbidden")
        #expect(forbid.report.frames[1].forbidden == [23, 57])

        // missing: key frame 0 wants one more cell.
        let frames2: [MoonlitMechanismKeyFrame] = [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52, 53], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [23, 57], required: true),
        ]
        var miss: Play = try Self.playing(try Self.hand(frames: frames2))
        try Self.act(&miss, .run)
        #expect(miss.failure == .missing(frame: 0, count: 1))
        #expect(miss.failure?.code == "missing")

        // missing after a lamp step: both cells drop a row, so key frame 0 misses 2.
        var lamp: Play = try Self.playing(try Self.hand())
        try Self.act(&lamp, .lamp(1))
        #expect(lamp.height == 1)
        #expect(lamp.report.frames[0].cast == [32, 62])
        try Self.act(&lamp, .run)
        #expect(lamp.failure == .missing(frame: 0, count: 2))

        // stray: key frame 1 targets only 23, so 57 is one stray cell above the allowance 0.
        let frames3: [MoonlitMechanismKeyFrame] = [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [23], required: true),
        ]
        var stray: Play = try Self.playing(try Self.hand(frames: frames3))
        try Self.act(&stray, .run)
        #expect(stray.failure == .stray(frame: 1, count: 1))
        #expect(stray.failure?.code == "stray")
        // With an allowance of 1 the same run wins.
        var allowed: Play = try Self.playing(try Self.hand(frames: frames3, allowance: 1))
        try Self.act(&allowed, .run)
        #expect(allowed.stage == .won)

        // budget code.
        #expect(MoonlitMechanismFailure.budget(0).code == "budget")
    }

    /// For budgets 1 … 6, non-run actions fail `budget(index)` on exactly the action that spends the budget: the action
    /// before still plays, and the same action with one more budget still plays. A run on the last action wins.
    @Test func budgetFailsOnTheExactAction() throws {
        for budget in 1...6 {
            var play: Play = try Self.playing(try Self.hand(budget: budget))
            var roomy: Play = try Self.playing(try Self.hand(budget: budget + 1))
            for number in 0..<budget {
                let action: Action = number % 2 == 0 ? .turn(1) : .turn(-1)
                try Self.act(&play, action)
                try Self.act(&roomy, action)
                #expect(roomy.stage == .playing)
                #expect(roomy.failure == nil)
                if number < budget - 1 {
                    #expect(play.stage == .playing)
                    #expect(play.failure == nil)
                    #expect(play.actionsLeft == budget - number - 1)
                }
            }
            #expect(play.stage == .failed)
            #expect(play.failure == .budget(budget - 1))
            #expect(play.actionsLeft == 0)
            #expect(play.actionsSpent == budget)
            #expect(roomy.actionsLeft == 1)
        }

        // A run on the last action wins: two turns that cancel, then the run.
        var last: Play = try Self.playing(try Self.hand(budget: 3))
        try Self.act(&last, .turn(1))
        try Self.act(&last, .turn(-1))
        try Self.act(&last, .run)
        #expect(last.stage == .won)
        #expect(last.failure == nil)
        #expect(last.actionsLeft == 0)

        // A failing run on the last action fails with the run's reason, not budget.
        var lastFail: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&lastFail, .reseat(1, 1))
        try Self.act(&lastFail, .run)
        #expect(lastFail.failure == .jammed(1))

        // A run with budget 1 wins on the only action.
        var only: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&only, .run)
        #expect(only.stage == .won)
    }

    // MARK: - Refusals

    /// The validation order stage, stale, action; every action refusal (gear, driver, step, lamp, undo, redo) is
    /// reachable, spends nothing and leaves the play unchanged.
    @Test func everyRefusalIsReachable() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 20))
        // Stale before action.
        #expect(Self.refusal(play, .stale(.reseat(9, 9))) == .stale)
        #expect(Self.refusal(play, .stale(.run)) == .stale)
        // Nothing to undo or redo.
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))
        // Unknown gear first, then the driver, then the step.
        #expect(Self.refusal(play, .act(.reseat(2, 1))) == .action("gear"))
        #expect(Self.refusal(play, .act(.reseat(-1, 1))) == .action("gear"))
        #expect(Self.refusal(play, .act(.reseat(9, 7))) == .action("gear"))
        #expect(Self.refusal(play, .act(.reseat(0, 1))) == .action("driver"))
        #expect(Self.refusal(play, .act(.reseat(0, 3))) == .action("driver"))
        #expect(Self.refusal(play, .act(.reseat(1, 0))) == .action("step"))
        #expect(Self.refusal(play, .act(.reseat(1, 2))) == .action("step"))
        #expect(Self.refusal(play, .act(.turn(0))) == .action("step"))
        #expect(Self.refusal(play, .act(.turn(2))) == .action("step"))
        #expect(Self.refusal(play, .act(.turn(-6))) == .action("step"))
        #expect(Self.refusal(play, .act(.lamp(0))) == .action("step"))
        #expect(Self.refusal(play, .act(.lamp(2))) == .action("step"))
        // A lamp step out of range.
        #expect(Self.refusal(play, .act(.lamp(-1))) == .action("lamp"))
        #expect(Self.refusal(play, .act(.lamp(1))) == nil)
        try Self.act(&play, .lamp(1))
        #expect(Self.refusal(play, .act(.lamp(1))) == .action("lamp"))
        #expect(Self.refusal(play, .act(.lamp(-1))) == nil)
        // Valid moves are accepted.
        #expect(Self.refusal(play, .act(.reseat(1, -1))) == nil)
        #expect(Self.refusal(play, .act(.turn(-1))) == nil)

        // Stage first: paused refuses even a stale invalid action by stage.
        try play.handle(.pause)
        #expect(Self.refusal(play, .stale(.reseat(99, 99))) == .stage)
        try play.handle(.resume)

        // Reason codes.
        let codes: [String] = [MoonlitMechanismError.stage.reasonCode, MoonlitMechanismError.stale.reasonCode,
                               MoonlitMechanismError.action("gear").reasonCode]
        #expect(codes == ["r02-g14.stage", "r02-g14.stale", "r02-g14.action"])

        // Only the one accepted lamp step was spent and recorded.
        #expect(play.actionsSpent == 1)
        #expect(play.records.count == 1)

        // A redo after a new action is refused.
        try play.undo()
        #expect(play.canRedo)
        try Self.act(&play, .turn(1))
        #expect(!play.canRedo)
        #expect(Self.refusal(play, .redo) == .action("redo"))
    }

    // MARK: - Fingerprint

    /// The fingerprint is the SHA-256 of its canonical text and covers phases, height, actions, stage and failure.
    @Test func fingerprintIsCanonical() throws {
        let level: MoonlitMechanismLevel = try Self.hand()
        var play: Play = try Self.playing(level)
        let text0: String = "{\"actions\":0,\"failure\":\"none\",\"height\":0,\"level\":\"" + level.fingerprint
            + "\",\"phases\":[0,0],\"schema\":1,\"stage\":\"playing\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text0.utf8)))
        #expect(play.fingerprint.count == 64)
        try Self.act(&play, .reseat(1, 1))
        try Self.act(&play, .run)
        let text1: String = "{\"actions\":2,\"failure\":\"jammed 1\",\"height\":0,\"level\":\"" + level.fingerprint
            + "\",\"phases\":[0,1],\"schema\":1,\"stage\":\"failed\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text1.utf8)))

        var lamp: Play = try Self.playing(level)
        try Self.act(&lamp, .lamp(1))
        try Self.act(&lamp, .run)
        let text2: String = "{\"actions\":2,\"failure\":\"missing 0 2\",\"height\":1,\"level\":\"" + level.fingerprint
            + "\",\"phases\":[0,0],\"schema\":1,\"stage\":\"failed\"}"
        #expect(lamp.fingerprint == StableHash.sha256Hex(Array(text2.utf8)))

        var budget: Play = try Self.playing(try Self.hand(budget: 1))
        try Self.act(&budget, .turn(1))
        let text3: String = "{\"actions\":1,\"failure\":\"budget 0\",\"height\":0,\"level\":\""
            + budget.level.fingerprint + "\",\"phases\":[1,5],\"schema\":1,\"stage\":\"failed\"}"
        #expect(budget.fingerprint == StableHash.sha256Hex(Array(text3.utf8)))

        let frames1: [MoonlitMechanismKeyFrame] = [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [79], required: false),
        ]
        var forbid: Play = try Self.playing(try Self.hand(frames: frames1, forbidden: [23, 57]))
        try Self.act(&forbid, .run)
        let text4: String = "{\"actions\":1,\"failure\":\"forbidden 1 23\",\"height\":0,\"level\":\""
            + forbid.level.fingerprint + "\",\"phases\":[0,0],\"schema\":1,\"stage\":\"failed\"}"
        #expect(forbid.fingerprint == StableHash.sha256Hex(Array(text4.utf8)))

        let frames3: [MoonlitMechanismKeyFrame] = [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [23], required: true),
        ]
        var stray: Play = try Self.playing(try Self.hand(frames: frames3))
        try Self.act(&stray, .run)
        let text5: String = "{\"actions\":1,\"failure\":\"stray 1 1\",\"height\":0,\"level\":\""
            + stray.level.fingerprint + "\",\"phases\":[0,0],\"schema\":1,\"stage\":\"failed\"}"
        #expect(stray.fingerprint == StableHash.sha256Hex(Array(text5.utf8)))

        // Stage is covered.
        var paused: Play = try Self.playing(level)
        let playingPrint: String = paused.fingerprint
        try paused.handle(.pause)
        #expect(paused.fingerprint != playingPrint)
    }

    // MARK: - Undo and redo

    /// Undo of every action restores the exact earlier fingerprint, phases, height and report; redo restores the later
    /// ones; undo while paused stays paused; undo from failed returns to playing (recorded) and redo restores the
    /// failure.
    @Test func undoRestoresExactStates() throws {
        let level: MoonlitMechanismLevel = try Self.hand(budget: 20, gears: 3)
        var play: Play = try Self.playing(level)
        let actions: [Action] = [.turn(1), .reseat(1, 1), .lamp(1), .reseat(2, -1), .turn(-1), .lamp(-1)]
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
            #expect(play.phases == states[earlier].phases)
            #expect(play.height == states[earlier].height)
            #expect(play.actionsSpent == states[earlier].actionsSpent)
            #expect(play.report == states[earlier].report)
            #expect(play.records.last?.kind == .undo)
            #expect(play.records.last?.action == nil)
            #expect(play.records.last?.previous == previous)
            #expect(play.records.last?.next == play.fingerprint)
        }
        #expect(!play.canUndo)
        #expect(play.canRedo)
        for later in 1..<states.count {
            try play.redo()
            #expect(play.fingerprint == states[later].fingerprint)
            #expect(play.phases == states[later].phases)
            #expect(play.height == states[later].height)
            #expect(play.report == states[later].report)
            #expect(play.records.last?.kind == .redo)
        }
        #expect(play.records.count == actions.count + 2 * undone)

        // Undo while paused stays paused; redo too.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused)
        #expect(play.phases == states[states.count - 2].phases)
        #expect(play.height == states[states.count - 2].height)
        try play.redo()
        #expect(play.stage == .paused)
        try play.handle(.resume)
        #expect(play.fingerprint == states[states.count - 1].fingerprint)

        // Undo from a budget failure returns to playing and is recorded; redo restores the failure.
        var failed: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&failed, .turn(1))
        let beforeFail: Play = failed
        try Self.act(&failed, .turn(1))
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

        // Undo from a failed run returns to playing at the earlier state; then the play can still win.
        var retry: Play = try Self.playing(try Self.hand())
        try Self.act(&retry, .reseat(1, 1))
        let beforeRun: String = retry.fingerprint
        try Self.act(&retry, .run)
        #expect(retry.failure == .jammed(1))
        try retry.undo()
        #expect(retry.stage == .playing)
        #expect(retry.failure == nil)
        #expect(retry.fingerprint == beforeRun)
        #expect(retry.actionsSpent == 1)
        try Self.act(&retry, .reseat(1, -1))
        try Self.act(&retry, .run)
        #expect(retry.stage == .won)
    }

    // MARK: - Replay

    /// 500 seeded traces (seed 2_431 onwards) of random valid and invalid turns, re-seats, lamp steps, runs, undo,
    /// redo, pause and resume on fixture levels (plus 20 hand levels with forbidden and stray key frames) replay to the
    /// same records, fingerprints and outcome; tampered traces are refused.
    @Test func seededTracesReplayExactly() throws {
        var random = SeededRandom(seed: 2_431)
        var cases: [(level: MoonlitMechanismLevel, actions: [Action])] = []
        for fixture in MoonlitMechanismFixture.all(count: 480, seed: 2_432) {
            cases.append((fixture.level, fixture.actions))
        }
        let forbidFrames: [MoonlitMechanismKeyFrame] = [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [79], required: false),
        ]
        let strayFrames: [MoonlitMechanismKeyFrame] = [
            MoonlitMechanismKeyFrame(turns: 0, target: [22, 52], required: true),
            MoonlitMechanismKeyFrame(turns: 1, target: [23], required: true),
        ]
        for number in 0..<20 {
            let level: MoonlitMechanismLevel = number % 2 == 0
                ? try Self.hand(frames: forbidFrames, forbidden: [23, 57], budget: 12)
                : try Self.hand(frames: strayFrames, budget: 12, gears: 3)
            cases.append((level, [.turn(1), .run]))
        }
        #expect(cases.count == 500)
        var reached: Set<String> = []
        for fixture in cases {
            let level: MoonlitMechanismLevel = fixture.level
            var play: Play = try Self.playing(level)
            let n: Int = level.gears.count
            let steps: Int = random.int(6...40)
            for _ in 0..<steps {
                let choice: Int = random.int(0...17)
                let op: Op
                switch choice {
                case 0: op = .act(.turn(random.int(-2...2)))
                case 1: op = .act(.turn(random.int(0...1) == 0 ? -1 : 1))
                case 2: op = .act(.reseat(random.int(-1...n), random.int(-2...2)))
                case 3...4: op = .act(.reseat(random.int(1...(n - 1)), random.int(0...1) == 0 ? -1 : 1))
                case 5: op = .act(.lamp(random.int(-2...2)))
                case 6: op = .act(.lamp(random.int(0...1) == 0 ? -1 : 1))
                case 7...8: op = .act(fixture.actions[random.int(0...(fixture.actions.count - 1))])
                case 9: op = .act(.run)
                case 10...11: op = .undo
                case 12: op = .redo
                case 13: op = .event(.pause)
                case 14: op = .event(.resume)
                default: op = .stale(.run)
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
                #expect(play.report == level.run(phases: play.phases, height: play.height))
                if play.stage == .won { reached.insert("won") }
                if let failure = play.failure { reached.insert("failed-" + failure.code) }
            }
            let replayed: Play = try Play.replay(level: level, records: play.records)
            #expect(replayed.records == play.records)
            #expect(replayed.phases == play.phases)
            #expect(replayed.height == play.height)
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
                var tampered: [MoonlitMechanismRecord] = play.records
                let r: MoonlitMechanismRecord = tampered[0]
                tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                     action: r.action, previous: r.previous, next: "0000")
                #expect(throws: MoonlitMechanismError.malformed("record 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed &+ 1, index: r.index,
                                                     kind: r.kind, action: r.action, previous: r.previous,
                                                     next: r.next)
                #expect(throws: MoonlitMechanismError.malformed("seed 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = MoonlitMechanismRecord(schema: 2, seed: r.seed, index: r.index, kind: r.kind,
                                                     action: r.action, previous: r.previous, next: r.next)
                #expect(throws: MoonlitMechanismError.malformed("schema 0")) {
                    try Play.replay(level: level, records: tampered)
                }
                tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                                     action: r.action, previous: "0000", next: r.next)
                #expect(throws: MoonlitMechanismError.malformed("replay")) {
                    try Play.replay(level: level, records: tampered)
                }
            }
        }
        let expected: [String] = ["accepted", "action-gear", "action-driver", "action-step", "action-lamp",
                                  "action-undo", "action-redo", "r02-g14.stage", "r02-g14.stale", "won",
                                  "failed-jammed", "failed-forbidden", "failed-missing", "failed-stray",
                                  "failed-budget"]
        for name in expected {
            #expect(reached.contains(name), "trace never reached \(name)")
        }
    }

    /// A record whose kind and action disagree, or whose index is changed, is refused; records round-trip through
    /// JSON.
    @Test func replayRefusesMismatchedRecords() throws {
        let level: MoonlitMechanismLevel = try Self.hand()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .turn(1))
        try Self.act(&play, .turn(-1))
        try Self.act(&play, .run)
        let replayed: Play = try Play.replay(level: level, records: play.records)
        #expect(replayed == play)
        let r: MoonlitMechanismRecord = play.records[0]
        var tampered: [MoonlitMechanismRecord] = play.records
        tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .lamp,
                                             action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MoonlitMechanismError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .turn,
                                             action: nil, previous: r.previous, next: r.next)
        #expect(throws: MoonlitMechanismError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed, index: r.index + 1, kind: r.kind,
                                             action: r.action, previous: r.previous, next: r.next)
        #expect(throws: MoonlitMechanismError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .turn,
                                             action: .turn(-1), previous: r.previous, next: r.next)
        #expect(throws: MoonlitMechanismError.malformed("record 0")) {
            try Play.replay(level: level, records: tampered)
        }
        // A replayed action that is refused surfaces its refusal.
        tampered[0] = MoonlitMechanismRecord(schema: r.schema, seed: r.seed, index: r.index, kind: .reseat,
                                             action: .reseat(0, 1), previous: r.previous, next: r.next)
        #expect(throws: MoonlitMechanismError.action("driver")) {
            try Play.replay(level: level, records: tampered)
        }
        // Records round-trip through JSON.
        let data: Data = try JSONEncoder().encode(play.records)
        let decoded: [MoonlitMechanismRecord] = try JSONDecoder().decode([MoonlitMechanismRecord].self, from: data)
        #expect(decoded == play.records)
    }
}
