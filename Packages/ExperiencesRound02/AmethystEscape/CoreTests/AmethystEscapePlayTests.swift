// AmethystEscapePlayTests — feature 361 (R02-G07-01) T-R02G0701-004 (FR-R02G0701-004 … 008; SC-R02G0701-001 … 004;
// clarifications Q3 … Q5). The play of an Amethyst Escape level: the full stage table of `handle(_:)`; the 500 fixtures'
// known solutions win exactly on their last action, each accepted action spending one move; a wedge and the budget fail
// on the exact move with the reason named, the budget one move either side of each fixture's solution length; an exit on
// the last move of the budget wins and a wedge on it is named a wedge; the validation order stage, stale, range, stuck,
// with every refusal reachable, spending nothing and leaving the play unchanged; undo from failed returns to playing and
// a won play is final; undo and redo restore exact fingerprints for every action and a new action clears redo; a full
// turn restores the crystal; 500 seeded traces (seed 2_361) replay to the same records, fingerprint and outcome, and a
// tampered record is refused. Explicit types, plain loops; each test well under 3 s.
import Foundation
import Testing
@testable import AmethystEscapeCore

@Suite struct AmethystEscapePlayTests {
    typealias Play = AmethystEscapePlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(AmethystEscapeAction)
        case stale(AmethystEscapeAction)
        case undo
        case redo
        case event(AmethystEscapeEvent)
    }

    static let events: [AmethystEscapeEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(AmethystEscapeError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: AmethystEscapeAction) throws(AmethystEscapeError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> AmethystEscapeError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused \(op) changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.moves == play.moves, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: AmethystEscapeLevel) throws(AmethystEscapeError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// `base` with another budget and no tutorial.
    static func level(_ base: AmethystEscapeLevel, budget: Int) throws(AmethystEscapeError) -> AmethystEscapeLevel {
        try AmethystEscapeLevel(id: base.id, seed: base.seed, difficulty: base.difficulty, sectors: base.sectors,
                                shells: base.shells, start: base.start, budget: budget)
    }

    /// Six sectors, two shells. Shell 0 has an aperture at own sector 0 and no walls; shell 1 has the exit gap at own
    /// sector 3 and a blocked wedge at own sector 5. The pearl starts at sector 5 of shell 0: an advance rolls it to
    /// sector 0, the next one lifts it into shell 1 at sector 0. With shell 1 turned +1 that pocket is its own sector 5,
    /// the wedge, so rotate(1, +1), advance, advance fails on move 3 with wedge(1, 0).
    static func wedgeLevel(budget: Int = 10) throws(AmethystEscapeError) -> AmethystEscapeLevel {
        let shells: [AmethystEscapeShell] = [AmethystEscapeShell(apertures: [0]),
                                             AmethystEscapeShell(apertures: [3], blocked: [5])]
        return try AmethystEscapeLevel(id: "wedge", seed: 11, difficulty: 1, sectors: 6, shells: shells, start: 5,
                                       budget: budget)
    }

    /// Six sectors, two shells, both open at own sector 0 and without walls; the pearl starts at sector 0, so
    /// advance, advance leaves through the exit gap on move 2.
    static func straightLevel(budget: Int) throws(AmethystEscapeError) -> AmethystEscapeLevel {
        let shells: [AmethystEscapeShell] = [AmethystEscapeShell(apertures: [0]), AmethystEscapeShell(apertures: [0])]
        return try AmethystEscapeLevel(id: "straight", seed: 12, difficulty: 1, sectors: 6, shells: shells, start: 0,
                                       budget: budget)
    }

    /// Six sectors, two shells; shell 0 is open only at own sector 0 and has wall 5, and the pearl starts at sector 5:
    /// the first advance is stuck, and turning shell 0 carries the pearl with it, so it stays stuck.
    static func stuckLevel() throws(AmethystEscapeError) -> AmethystEscapeLevel {
        let shells: [AmethystEscapeShell] = [AmethystEscapeShell(apertures: [0], walls: [5]),
                                             AmethystEscapeShell(apertures: [0])]
        return try AmethystEscapeLevel(id: "stuck", seed: 13, difficulty: 1, sectors: 6, shells: shells, start: 5,
                                       budget: 20, tutorial: true)
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: AmethystEscapeLevel = AmethystEscapeFixtures.fixture(0).level
        let without: AmethystEscapeLevel = AmethystEscapeFixtures.fixture(1).level
        #expect(withTutorial.tutorial)
        #expect(!without.tutorial)

        // loading: only begin.
        var loading = Play(level: withTutorial)
        #expect(loading.stage == .loading)
        #expect(loading.moves == 0)
        #expect(loading.remaining == withTutorial.budget)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(.advance)) == .stage)
        #expect(Self.refusal(loading, .undo) == .stage)
        #expect(Self.refusal(loading, .redo) == .stage)
        try loading.handle(.begin)
        #expect(loading.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(.rotate(0, 1))) == .stage)
        #expect(Self.refusal(loading, .undo) == .stage)
        try loading.handle(.dismissTutorial)
        #expect(loading.stage == .playing)

        // No tutorial: begin goes straight to playing.
        var direct = Play(level: without)
        try direct.handle(.begin)
        #expect(direct.stage == .playing)

        // playing: only pause.
        for event in Self.events where event != .pause {
            #expect(Self.refusal(direct, .event(event)) == .stage)
        }
        try direct.handle(.pause)
        #expect(direct.stage == .paused)

        // paused: only resume; actions refused; undo and redo judged (nothing to undo here).
        for event in Self.events where event != .resume {
            #expect(Self.refusal(direct, .event(event)) == .stage)
        }
        #expect(Self.refusal(direct, .act(.advance)) == .stage)
        #expect(Self.refusal(direct, .undo) == .action("nothing-to-undo"))
        #expect(Self.refusal(direct, .redo) == .action("nothing-to-redo"))
        try direct.handle(.resume)
        #expect(direct.stage == .playing)

        // won: only showResult; then result refuses everything.
        let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(1)
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(.advance)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)

        // failed: only showResult.
        var failed: Play = try Self.playing(try Self.straightLevel(budget: 1))
        try Self.act(&failed, .advance)
        #expect(failed.stage == .failed)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        try failed.handle(.showResult)
        #expect(failed.stage == .result)
    }

    // MARK: - Known solutions

    @Test func fixtureSolutionsWinOnTheirLastAction() throws {
        for index in 0..<500 {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(index)
            var play: Play = try Self.playing(fixture.level)
            for (step, action) in fixture.actions.enumerated() {
                #expect(play.stage == .playing, "fixture \(index) ended before action \(step)")
                let before: String = play.fingerprint
                try Self.act(&play, action)
                #expect(play.moves == step + 1)
                #expect(play.remaining == fixture.level.budget - step - 1)
                #expect(play.records.count == step + 1)
                #expect(play.records[step].previous == before)
                #expect(play.records[step].next == play.fingerprint)
                #expect(play.records[step].move == step)
                #expect(play.records[step].action == action)
            }
            #expect(play.stage == .won, "fixture \(index)")
            #expect(play.failure == nil)
            #expect(play.moves == fixture.actions.count)
        }
    }

    @Test func budgetFailsOnTheExactMoveOneEitherSide() throws {
        for index in 0..<100 {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(index)
            let length: Int = fixture.actions.count
            for budget in [length - 1, length, length + 1] where AmethystEscapeLevel.budgets.contains(budget) {
                let level: AmethystEscapeLevel = try Self.level(fixture.level, budget: budget)
                var play: Play = try Self.playing(level)
                for action in fixture.actions where play.stage == .playing { try Self.act(&play, action) }
                if budget < length {
                    #expect(play.stage == .failed, "fixture \(index) budget \(budget)")
                    #expect(play.failure == .budget)
                    #expect(play.failure?.code == "budget")
                    #expect(play.moves == budget)
                    #expect(play.remaining == 0)
                    #expect(Self.refusal(play, .act(fixture.actions[budget])) == .stage)
                } else {
                    // An exit on the last move of the budget wins.
                    #expect(play.stage == .won, "fixture \(index) budget \(budget)")
                    #expect(play.failure == nil)
                    #expect(play.moves == length)
                    #expect(play.remaining == budget - length)
                }
            }
        }
    }

    @Test func exitOnTheLastMoveWinsAndBudgetFailsTheMoveBefore() throws {
        var exact: Play = try Self.playing(try Self.straightLevel(budget: 2))
        try Self.act(&exact, .advance)
        #expect(exact.stage == .playing)
        #expect(exact.remaining == 1)
        try Self.act(&exact, .advance)
        #expect(exact.stage == .won)
        #expect(exact.remaining == 0)
        #expect(exact.failure == nil)

        var short: Play = try Self.playing(try Self.straightLevel(budget: 1))
        try Self.act(&short, .advance)
        #expect(short.stage == .failed)
        #expect(short.failure == .budget)
        #expect(short.crystal.pearl == AmethystEscapePocket(shell: 1, sector: 0))
        #expect(short.moves == 1)

        // Rotations spend moves too.
        var turning: Play = try Self.playing(try Self.straightLevel(budget: 2))
        try Self.act(&turning, .rotate(1, 1))
        try Self.act(&turning, .rotate(1, -1))
        #expect(turning.stage == .failed)
        #expect(turning.failure == .budget)
    }

    @Test func wedgeFailsOnTheExactMoveWithThePocketNamed() throws {
        var play: Play = try Self.playing(try Self.wedgeLevel())
        try Self.act(&play, .rotate(1, 1))
        try Self.act(&play, .advance)
        #expect(play.stage == .playing)
        #expect(play.crystal.pearl == AmethystEscapePocket(shell: 0, sector: 0))
        try Self.act(&play, .advance)
        #expect(play.stage == .failed)
        #expect(play.moves == 3)
        #expect(play.failure == .wedge(1, 0))
        #expect(play.failure?.code == "wedge")
        #expect(play.crystal.pearl == AmethystEscapePocket(shell: 1, sector: 0))
        #expect(play.records.last?.kind == .advance)

        // Without the turn the same pocket is shell 1's own sector 0, which is open: no wedge.
        var safe: Play = try Self.playing(try Self.wedgeLevel())
        try Self.act(&safe, .advance)
        try Self.act(&safe, .advance)
        #expect(safe.stage == .playing)
        #expect(safe.failure == nil)

        // A wedge on the last move of the budget is named a wedge, not the budget.
        var last: Play = try Self.playing(try Self.wedgeLevel(budget: 3))
        try Self.act(&last, .rotate(1, 1))
        try Self.act(&last, .advance)
        try Self.act(&last, .advance)
        #expect(last.failure == .wedge(1, 0))

        // One move short of the budget for the wedge: the budget fails first, on move 2.
        var early: Play = try Self.playing(try Self.wedgeLevel(budget: 2))
        try Self.act(&early, .rotate(1, 1))
        try Self.act(&early, .advance)
        #expect(early.failure == .budget)
        #expect(early.moves == 2)
    }

    @Test func fullTurnRestoresTheCrystal() throws {
        let level: AmethystEscapeLevel = try Self.wedgeLevel(budget: 30)
        for shell in 0..<level.shells.count {
            var play: Play = try Self.playing(level)
            let opening: AmethystEscapeCrystal = play.crystal
            for step in 0..<level.sectors {
                try Self.act(&play, .rotate(shell, 1))
                #expect((play.crystal == opening) == (step == level.sectors - 1))
            }
            #expect(play.moves == level.sectors)
        }
    }

    // MARK: - Refusals

    @Test func validationOrderAndEveryRefusal() throws {
        let level: AmethystEscapeLevel = try Self.stuckLevel()
        var play = Play(level: level)
        // stage, before stale and range.
        #expect(Self.refusal(play, .stale(.rotate(9, 5))) == .stage)
        try play.handle(.begin)
        #expect(Self.refusal(play, .stale(.advance)) == .stage)
        try play.handle(.dismissTutorial)
        // stale, before range and stuck.
        #expect(Self.refusal(play, .stale(.rotate(9, 5))) == .stale)
        #expect(Self.refusal(play, .stale(.advance)) == .stale)
        // range: a shell out of range or a step other than ±1.
        let outOfRange: [AmethystEscapeAction] = [.rotate(-1, 1), .rotate(2, 1), .rotate(0, 0), .rotate(0, 2),
                                                  .rotate(1, -2)]
        for action in outOfRange {
            #expect(Self.refusal(play, .act(action)) == .action("range"))
        }
        // stuck: spends nothing, records nothing.
        #expect(Self.refusal(play, .act(.advance)) == .stuck)
        #expect(play.moves == 0)
        #expect(play.records.isEmpty)
        // Turning the pearl's shell carries the pearl: still stuck.
        try Self.act(&play, .rotate(0, 1))
        #expect(play.crystal.pearl == AmethystEscapePocket(shell: 0, sector: 0))
        #expect(play.crystal.ownSector(play.crystal.pearl, level: level) == 5)
        #expect(Self.refusal(play, .act(.advance)) == .stuck)
        #expect(play.moves == 1)
        // Turning another shell never moves the pearl.
        try Self.act(&play, .rotate(1, -1))
        #expect(play.crystal.pearl == AmethystEscapePocket(shell: 0, sector: 0))
        // nothing-to-redo, then nothing-to-undo after undoing everything.
        #expect(Self.refusal(play, .redo) == .action("nothing-to-redo"))
        try play.undo()
        try play.undo()
        #expect(Self.refusal(play, .undo) == .action("nothing-to-undo"))
        #expect(play.moves == 0)
        // A stale fingerprint from an earlier moment.
        let earlier: String = play.fingerprint
        try Self.act(&play, .rotate(1, 1))
        var copy: Play = play
        do {
            try copy.apply(.rotate(1, 1), expecting: earlier)
            Issue.record("an action expecting an earlier fingerprint was accepted")
        } catch {
            #expect(error == .stale)
        }
        #expect(copy == play)
        #expect(AmethystEscapeError.stuck.reasonCode == "r02-g07.stuck")
        #expect(AmethystEscapeError.stale.reasonCode == "r02-g07.stale")
    }

    // MARK: - Undo and redo

    @Test func undoFromFailedAndWonIsFinal() throws {
        var failed: Play = try Self.playing(try Self.wedgeLevel())
        try Self.act(&failed, .rotate(1, 1))
        try Self.act(&failed, .advance)
        let beforeFail: String = failed.fingerprint
        try Self.act(&failed, .advance)
        let failedPrint: String = failed.fingerprint
        #expect(failed.canUndo)
        #expect(!failed.canRedo)
        #expect(Self.refusal(failed, .redo) == .stage)
        try failed.undo()
        #expect(failed.stage == .playing)
        #expect(failed.failure == nil)
        #expect(failed.moves == 2)
        #expect(failed.fingerprint == beforeFail)
        #expect(failed.records.last?.kind == .undo)
        #expect(failed.records.last?.action == nil)
        #expect(failed.records.last?.move == 3)
        try failed.redo()
        #expect(failed.stage == .failed)
        #expect(failed.moves == 3)
        #expect(failed.fingerprint == failedPrint)
        #expect(failed.records.last?.kind == .redo)

        let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(2)
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        #expect(!won.canUndo)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
    }

    @Test func undoAndRedoRestoreExactFingerprints() throws {
        for index in 0..<200 {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(index)
            var play: Play = try Self.playing(fixture.level)
            for action in fixture.actions {
                let before: String = play.fingerprint
                let crystalBefore: AmethystEscapeCrystal = play.crystal
                let movesBefore: Int = play.moves
                try Self.act(&play, action)
                if play.stage == .won {
                    #expect(Self.refusal(play, .undo) == .stage)
                    break
                }
                let after: String = play.fingerprint
                let count: Int = play.records.count
                // Undo while paused too, on odd fixtures.
                if index % 2 == 1 { try play.handle(.pause) }
                try play.undo()
                if index % 2 == 1 {
                    #expect(play.stage == .paused)
                    try play.handle(.resume)
                }
                #expect(play.fingerprint == before, "fixture \(index)")
                #expect(play.crystal == crystalBefore)
                #expect(play.moves == movesBefore)
                #expect(play.canRedo)
                try play.redo()
                #expect(play.fingerprint == after, "fixture \(index)")
                #expect(play.records.count == count + 2)
                #expect(!play.canRedo)
            }
            #expect(play.stage == .won, "fixture \(index)")
        }

        // A new action clears the redo stack.
        var play: Play = try Self.playing(try Self.wedgeLevel())
        try Self.act(&play, .rotate(0, 1))
        try play.undo()
        #expect(play.canRedo)
        try Self.act(&play, .rotate(1, -1))
        #expect(!play.canRedo)
        #expect(Self.refusal(play, .redo) == .action("nothing-to-redo"))
    }

    // MARK: - Seeded traces and replay

    /// A seeded random action for `play` (sometimes out of range, so refusals occur too).
    static func randomAction(_ play: Play, random: inout AmethystEscapeRandom) -> AmethystEscapeAction {
        switch random.int(0...9) {
        case 0...4:
            return .advance
        case 5...8:
            return .rotate(random.int(0..<play.level.shells.count), random.bool() ? 1 : -1)
        default:
            return .rotate(random.int(-1...play.level.shells.count), random.int(-2...2))
        }
    }

    @Test func seededTracesReplayIdentically() throws {
        var random = AmethystEscapeRandom(seed: AmethystEscapeFixtures.seed)
        var tampered: Int = 0
        var pausedEdits: Int = 0
        var wins: Int = 0
        var failures: Int = 0
        for trace in 0..<500 {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(trace / 2)
            let level: AmethystEscapeLevel = trace % 2 == 0 ? fixture.level : AmethystEscapeFixtures.randomLevel(trace / 2)
            var play: Play = try Self.playing(level)
            // Every fourth trace starts with the known solution but its last action, so wins occur too.
            if trace % 4 == 0 {
                for action in fixture.actions.dropLast() { try Self.act(&play, action) }
            }
            let length: Int = random.int(5...30)
            for _ in 0..<length {
                let op: Op
                switch random.int(0...11) {
                case 0, 1: op = .undo
                case 2: op = .redo
                case 3: op = .event(.pause)
                case 4: op = .event(.resume)
                default: op = .act(Self.randomAction(play, random: &random))
                }
                if Self.refusal(play, op) == nil {
                    if play.stage == .paused, case .undo = op { pausedEdits += 1 }
                    if play.stage == .paused, case .redo = op { pausedEdits += 1 }
                    try Self.perform(op, &play)
                }
            }
            if play.stage == .won { wins += 1 }
            if play.stage == .failed { failures += 1 }

            var replayed: Play = try Play.replay(level: level, records: play.records)
            // Pauses and resumes are not recorded: a pause or resume after the last record is not reproduced.
            if play.stage == .paused && replayed.stage == .playing { try play.handle(.resume) }
            if replayed.stage == .paused && play.stage == .playing { try replayed.handle(.resume) }
            #expect(replayed.records == play.records, "trace \(trace)")
            #expect(replayed.fingerprint == play.fingerprint, "trace \(trace)")
            #expect(replayed.stage == play.stage)
            #expect(replayed.crystal == play.crystal)
            #expect(replayed.moves == play.moves)
            #expect(replayed.failure == play.failure)
            #expect(replayed == play, "trace \(trace)")

            // A tampered record is refused.
            if !play.records.isEmpty {
                let index: Int = random.int(0..<play.records.count)
                let record: AmethystEscapeRecord = play.records[index]
                var records: [AmethystEscapeRecord] = play.records
                let expected: AmethystEscapeError
                switch trace % 3 {
                case 0:
                    records[index] = AmethystEscapeRecord(schema: record.schema, seed: record.seed, move: record.move,
                                                          kind: record.kind, action: record.action,
                                                          previous: record.previous, next: "0000")
                    expected = .malformed("record \(index)")
                case 1:
                    records[index] = AmethystEscapeRecord(schema: record.schema, seed: record.seed &+ 1,
                                                          move: record.move, kind: record.kind, action: record.action,
                                                          previous: record.previous, next: record.next)
                    expected = .malformed("record \(index)")
                default:
                    records[index] = AmethystEscapeRecord(schema: record.schema, seed: record.seed, move: record.move,
                                                          kind: record.kind, action: record.action, previous: "0000",
                                                          next: record.next)
                    expected = .malformed("replay")
                }
                do {
                    _ = try Play.replay(level: level, records: records)
                    Issue.record("trace \(trace): tampered record \(index) replayed")
                } catch {
                    #expect(error == expected, "trace \(trace)")
                }
                tampered += 1
            }
        }
        #expect(tampered >= 450)
        #expect(pausedEdits >= 20, "undo and redo while paused: \(pausedEdits)")
        #expect(wins >= 20, "wins: \(wins)")
        #expect(failures >= 20, "failures: \(failures)")

        // An action record without its action is malformed.
        let level: AmethystEscapeLevel = try Self.wedgeLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .advance)
        let record: AmethystEscapeRecord = play.records[0]
        let broken = AmethystEscapeRecord(schema: record.schema, seed: record.seed, move: record.move, kind: .advance,
                                          action: nil, previous: record.previous, next: record.next)
        do {
            _ = try Play.replay(level: level, records: [broken])
            Issue.record("an advance record without its action replayed")
        } catch {
            #expect(error == .malformed("record 0"))
        }
    }
}
