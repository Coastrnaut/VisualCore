// VoxelOrigamiPlayTests — feature 441 (R02-G15-01) T-R02G1501-004 (FR-R02G1501-004 … 008, 012; SC-R02G1501-001, 002,
// 004; clarifications Q2, Q3, Q5). The play of a Voxel Origami level: the full stage table of `handle(_:)`; the fixtures'
// known turns keep the play going (the turns after each action equal the fixtures' own `apply`, the report always the
// level's report of the turns) and win exactly on the last; each failure named on hand levels (`collision` and `sweep`
// with their hinge, moving cube, still cube and cell, on the exact turn with the turns unchanged); budget failure on the
// exact action with budgets one action either side, and a turn on the last action wins; the validation order stage,
// stale, action (hinge, step, idle) with every refusal reachable, spending nothing and leaving the play unchanged; the
// fingerprint is the SHA-256 of its canonical text; undo of every action restores the exact fingerprint, undo from failed
// returns to playing with the failing action refunded, a won play is final and a new turn clears redo; 500 seeded traces
// replay to the same records, fingerprints and outcome, and tampered traces are refused. Explicit types, plain loops,
// short traces; each test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import VoxelOrigamiCore

struct VoxelOrigamiPlayTests {
    typealias Play = VoxelOrigamiPlay
    typealias Action = VoxelOrigamiAction

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(Action)
        case stale(Action)
        case undo
        case redo
        case event(VoxelOrigamiEvent)
    }

    static let events: [VoxelOrigamiEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(VoxelOrigamiError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: Action) throws(VoxelOrigamiError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> VoxelOrigamiError? {
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
    static func playing(_ level: VoxelOrigamiLevel) throws(VoxelOrigamiError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    static func v(_ x: Int, _ y: Int, _ z: Int) -> VoxelOrigamiVector { VoxelOrigamiVector(x, y, z) }

    static func cube(_ parent: Int, _ direction: VoxelOrigamiVector) -> VoxelOrigamiCube {
        VoxelOrigamiCube(parent: parent, direction: direction, startTurn: 0)
    }

    /// An L of four cubes: 0 at the origin, 1 at +x, 2 at +x +x, 3 above 2. Cubes 0, 1 and 2 always stay in a row, so
    /// the L never becomes the square target; hinge 2 swings cube 3 clear of everything; hinge 3 is a leaf (idle).
    static func lLevel(budget: Int = 5, tutorial: Bool = false) throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        let cubes: [VoxelOrigamiCube] = [.root, cube(0, v(1, 0, 0)), cube(1, v(1, 0, 0)), cube(2, v(0, 1, 0))]
        let square: [VoxelOrigamiVector] = [v(0, 0, 0), v(0, 1, 0), v(1, 0, 0), v(1, 1, 0)]
        return try VoxelOrigamiLevel(id: "play-l", seed: 11, difficulty: 1, cubes: cubes, target: square,
                                     orientations: .any, budget: budget, tutorial: tutorial)
    }

    /// A row target of `count` cells along x (fixed orientations).
    static func row(_ count: Int) -> [VoxelOrigamiVector] {
        var cells: [VoxelOrigamiVector] = []
        for x in 0..<count { cells.append(v(x, 0, 0)) }
        return cells
    }

    /// A hook 0 (0,0,0) → 1 (1,0,0) → 2 (1,1,0) → 3 (0,1,0) with a post 0 → 4 (0,0,1) → 5 (1,0,1) → 6 (1,1,1). Hinge 2
    /// (axis +y through cube 2) turned +1 swings cube 3 onto (1,1,1), cube 6's cell: a collision.
    static func collisionLevel() throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        let cubes: [VoxelOrigamiCube] = [.root, cube(0, v(1, 0, 0)), cube(1, v(0, 1, 0)), cube(2, v(-1, 0, 0)),
                                         cube(0, v(0, 0, 1)), cube(4, v(1, 0, 0)), cube(5, v(0, 1, 0))]
        return try VoxelOrigamiLevel(id: "play-collision", seed: 12, difficulty: 1, cubes: cubes, target: row(7),
                                     orientations: .fixed, budget: 5)
    }

    /// The same hook with a post 0 → 4 (0,0,1) → 5 (0,1,1). Hinge 2 turned +1 swings cube 3 from (0,1,0) to (1,1,1)
    /// (free) through the band corner (0,1,1), cube 5's cell: a sweep. Turned −1 it lands on (1,1,−1), clear.
    static func sweepLevel() throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        let cubes: [VoxelOrigamiCube] = [.root, cube(0, v(1, 0, 0)), cube(1, v(0, 1, 0)), cube(2, v(-1, 0, 0)),
                                         cube(0, v(0, 0, 1)), cube(4, v(0, 1, 0))]
        return try VoxelOrigamiLevel(id: "play-sweep", seed: 13, difficulty: 1, cubes: cubes, target: row(6),
                                     orientations: .fixed, budget: 5)
    }

    /// `level` with another budget (and tutorial flag).
    static func rebudgeted(_ level: VoxelOrigamiLevel, budget: Int,
                           tutorial: Bool? = nil) throws(VoxelOrigamiError) -> VoxelOrigamiLevel {
        try VoxelOrigamiLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, cubes: level.cubes,
                              target: level.target, orientations: level.orientations, budget: budget,
                              tutorial: tutorial ?? level.tutorial)
    }

    // MARK: Stages

    @Test func theStageTableAcceptsOnlyItsEvents() throws {
        let level: VoxelOrigamiLevel = try Self.lLevel(budget: 1, tutorial: true)
        // Reach every stage.
        var plays: [VoxelOrigamiStage: Play] = [:]
        var play = Play(level: level)
        #expect(play.stage == .loading)
        #expect(play.turns == level.startTurns)
        #expect(play.actionsSpent == 0 && play.actionsLeft == 1 && play.failure == nil && play.records.isEmpty)
        #expect(play.pose == level.pose(turns: level.startTurns))
        #expect(play.report == level.report(turns: level.startTurns))
        plays[.loading] = play
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        plays[.tutorial] = play
        try play.handle(.dismissTutorial)
        #expect(play.stage == .playing)
        plays[.playing] = play
        var paused: Play = play
        try paused.handle(.pause)
        #expect(paused.stage == .paused)
        plays[.paused] = paused
        var failed: Play = play
        try Self.act(&failed, .turn(2, 1))
        #expect(failed.stage == .failed)
        #expect(failed.failure == .budget(0))
        plays[.failed] = failed
        var result: Play = failed
        try result.handle(.showResult)
        #expect(result.stage == .result)
        plays[.result] = result
        let fixture: VoxelOrigamiFixture = VoxelOrigamiFixture.all(count: 1)[0]
        var won: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&won, action) }
        #expect(won.stage == .won)
        plays[.won] = won
        var wonResult: Play = won
        try wonResult.handle(.showResult)
        #expect(wonResult.stage == .result)

        let accepted: [VoxelOrigamiStage: VoxelOrigamiEvent] = [.loading: .begin, .tutorial: .dismissTutorial,
                                                                 .playing: .pause, .paused: .resume,
                                                                 .won: .showResult, .failed: .showResult]
        for stage in VoxelOrigamiStage.allCases {
            guard let base = plays[stage] else {
                Issue.record("stage \(stage) not reached")
                continue
            }
            for event in Self.events where accepted[stage] != event {
                #expect(Self.refusal(base, .event(event)) == .stage, "\(stage) \(event)")
            }
        }
        // A level without a tutorial begins straight into playing.
        var plain = Play(level: try Self.lLevel())
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
    }

    @Test func turnsAreRefusedOutsidePlaying() throws {
        let level: VoxelOrigamiLevel = try Self.lLevel(budget: 1, tutorial: true)
        var play = Play(level: level)
        #expect(Self.refusal(play, .act(.turn(2, 1))) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.begin)
        #expect(Self.refusal(play, .act(.turn(2, 1))) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        try play.handle(.dismissTutorial)
        var paused: Play = play
        try paused.handle(.pause)
        #expect(Self.refusal(paused, .act(.turn(2, 1))) == .stage)
        // Stage is checked before the fingerprint and the action.
        #expect(Self.refusal(paused, .stale(.turn(99, 7))) == .stage)
        try Self.act(&play, .turn(2, 1))
        #expect(play.stage == .failed)
        #expect(Self.refusal(play, .act(.turn(2, -1))) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        try play.handle(.showResult)
        #expect(Self.refusal(play, .act(.turn(2, -1))) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        #expect(!play.canUndo && !play.canRedo)
    }

    // MARK: Validation

    @Test func everyRefusalReasonIsReachableInOrder() throws {
        let play: Play = try Self.playing(try Self.lLevel())
        #expect(Self.refusal(play, .act(.turn(0, 1))) == .action("hinge"))
        #expect(Self.refusal(play, .act(.turn(4, 1))) == .action("hinge"))
        #expect(Self.refusal(play, .act(.turn(-1, 1))) == .action("hinge"))
        #expect(Self.refusal(play, .act(.turn(2, 2))) == .action("step"))
        #expect(Self.refusal(play, .act(.turn(2, 0))) == .action("step"))
        #expect(Self.refusal(play, .act(.turn(3, 1))) == .action("idle"))
        // Hinge before step before idle.
        #expect(Self.refusal(play, .act(.turn(9, 5))) == .action("hinge"))
        #expect(Self.refusal(play, .act(.turn(3, 5))) == .action("step"))
        // Stale before the action.
        #expect(Self.refusal(play, .stale(.turn(9, 5))) == .stale)
        #expect(Self.refusal(play, .stale(.turn(2, 1))) == .stale)
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))
        #expect(VoxelOrigamiError.action("idle").reasonCode == "r02-g15.action")
        #expect(VoxelOrigamiError.stale.reasonCode == "r02-g15.stale")
        #expect(VoxelOrigamiError.stage.reasonCode == "r02-g15.stage")
    }

    @Test func aHingeWithEveryDescendantOnItsAxisIsIdle() throws {
        // A straight row 0 → 1 → 2 → 3 along +x with a branch 1 → 4 above: hinge 2 swings nothing (cube 3 on its axis).
        let cubes: [VoxelOrigamiCube] = [.root, Self.cube(0, Self.v(1, 0, 0)), Self.cube(1, Self.v(1, 0, 0)),
                                         Self.cube(2, Self.v(1, 0, 0)), Self.cube(1, Self.v(0, 1, 0))]
        let level = try VoxelOrigamiLevel(id: "play-idle", seed: 14, difficulty: 1, cubes: cubes,
                                          target: Self.row(5), orientations: .fixed, budget: 3)
        let play: Play = try Self.playing(level)
        #expect(Self.refusal(play, .act(.turn(2, 1))) == .action("idle"))
        #expect(Self.refusal(play, .act(.turn(3, -1))) == .action("idle"))
        #expect(Self.refusal(play, .act(.turn(1, 1))) == nil)
    }

    // MARK: Winning

    @Test func theFixturesKnownTurnsWinExactlyOnTheLast() throws {
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 40)
        for fixture in fixtures {
            var play: Play = try Self.playing(fixture.level)
            var turns: [Int] = fixture.level.startTurns
            for (position, action) in fixture.actions.enumerated() {
                #expect(play.stage == .playing, "\(fixture.level.id) before \(position)")
                try Self.act(&play, action)
                guard let next = VoxelOrigamiFixture.apply(action, cubes: fixture.level.cubes, turns: turns) else {
                    Issue.record("fixture turn refused")
                    break
                }
                turns = next
                #expect(play.turns == turns)
                #expect(play.pose == fixture.level.pose(turns: turns))
                #expect(play.report == fixture.level.report(turns: turns))
                #expect(play.actionsSpent == position + 1)
                let last: Bool = position == fixture.actions.count - 1
                #expect(play.report.matched == last)
                #expect(play.stage == (last ? .won : .playing), "\(fixture.level.id) at \(position)")
            }
            #expect(play.failure == nil)
            #expect(play.records.count == fixture.actions.count)
            #expect(!play.canUndo && !play.canRedo)
            #expect(Self.refusal(play, .undo) == .stage)
        }
    }

    @Test func aTurnOnTheLastActionWins() throws {
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 20)
        for fixture in fixtures {
            let level: VoxelOrigamiLevel = try Self.rebudgeted(fixture.level, budget: fixture.actions.count)
            var play: Play = try Self.playing(level)
            for action in fixture.actions { try Self.act(&play, action) }
            #expect(play.stage == .won)
            #expect(play.actionsLeft == 0)
            #expect(play.failure == nil)
        }
    }

    // MARK: Failures

    @Test func aCollisionFailsOnTheExactTurnWithTheTurnsUnchanged() throws {
        let level: VoxelOrigamiLevel = try Self.collisionLevel()
        var play: Play = try Self.playing(level)
        // A clear turn first: hinge 2 by −1 lands cube 3 on (1,1,−1).
        try Self.act(&play, .turn(2, -1))
        #expect(play.stage == .playing)
        try Self.act(&play, .turn(2, 1))
        #expect(play.stage == .playing)
        #expect(play.turns == level.startTurns)
        let before: Play = play
        try Self.act(&play, .turn(2, 1))
        #expect(play.stage == .failed)
        #expect(play.failure == .collision(hinge: 2, moving: 3, still: 6, cell: Self.v(1, 1, 1)))
        #expect(play.failure?.code == "collision")
        #expect(play.turns == before.turns)
        #expect(play.pose == before.pose)
        #expect(play.report == before.report)
        #expect(play.actionsSpent == 3)
        #expect(play.records.count == 3)
        #expect(play.records[2].kind == .turn && play.records[2].action == .turn(2, 1) && play.records[2].index == 2)
        #expect(play.records[2].previous == before.fingerprint && play.records[2].next == play.fingerprint)
        // Undo returns to playing before the failing turn, the action refunded.
        try play.undo()
        #expect(play.stage == .playing)
        #expect(play.failure == nil)
        #expect(play.fingerprint == before.fingerprint)
        #expect(play.actionsSpent == 2)
        #expect(play.records.count == 4 && play.records[3].kind == .undo && play.records[3].index == 3)
        // Redo brings the failure back exactly.
        try play.redo()
        #expect(play.stage == .failed)
        #expect(play.failure == .collision(hinge: 2, moving: 3, still: 6, cell: Self.v(1, 1, 1)))
    }

    @Test func aSweepFailsOnTheExactTurnAndTheOtherWayIsClear() throws {
        let level: VoxelOrigamiLevel = try Self.sweepLevel()
        var clear: Play = try Self.playing(level)
        try Self.act(&clear, .turn(2, -1))
        #expect(clear.stage == .playing)
        #expect(clear.pose.cells[3] == Self.v(1, 1, -1))
        var play: Play = try Self.playing(level)
        let before: Play = play
        try Self.act(&play, .turn(2, 1))
        #expect(play.stage == .failed)
        #expect(play.failure == .sweep(hinge: 2, moving: 3, still: 5, cell: Self.v(0, 1, 1)))
        #expect(play.failure?.code == "sweep")
        #expect(play.turns == before.turns)
        #expect(play.pose == before.pose)
        #expect(play.actionsSpent == 1)
        #expect(Self.refusal(play, .act(.turn(2, -1))) == .stage)
        var shown: Play = play
        try shown.handle(.showResult)
        #expect(shown.stage == .result)
        try play.undo()
        #expect(play.fingerprint == before.fingerprint)
        #expect(play.stage == .playing && play.actionsLeft == level.budget)
    }

    @Test func theBudgetFailsOnTheExactActionWithOneActionEitherSide() throws {
        for budget in [3, 4, 5] {
            let level: VoxelOrigamiLevel = try Self.lLevel(budget: budget)
            var play: Play = try Self.playing(level)
            for index in 0..<budget {
                #expect(play.stage == .playing, "budget \(budget) before \(index)")
                #expect(play.actionsLeft == budget - index)
                try Self.act(&play, .turn(2, index % 2 == 0 ? 1 : -1))
            }
            #expect(play.stage == .failed)
            #expect(play.failure == .budget(budget - 1))
            #expect(play.failure?.code == "budget")
            #expect(play.actionsLeft == 0)
            #expect(Self.refusal(play, .act(.turn(2, 1))) == .stage)
            // Undo from a budget failure refunds the last action.
            try play.undo()
            #expect(play.stage == .playing && play.actionsLeft == 1 && play.failure == nil)
        }
    }

    // MARK: Undo, redo, fingerprint

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        let level: VoxelOrigamiLevel = try Self.lLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .turn(2, 1))
        let text: String = "{\"actions\":1,\"failure\":\"none\",\"level\":\"" + level.fingerprint
            + "\",\"schema\":1,\"stage\":\"playing\",\"turns\":[0,0,1,0]}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text.utf8)))
        var failed: Play = try Self.playing(try Self.sweepLevel())
        try Self.act(&failed, .turn(2, 1))
        let failedText: String = "{\"actions\":1,\"failure\":\"sweep 2 3 5 0 1 1\",\"level\":\""
            + failed.level.fingerprint + "\",\"schema\":1,\"stage\":\"failed\",\"turns\":[0,0,0,0,0,0]}"
        #expect(failed.fingerprint == StableHash.sha256Hex(Array(failedText.utf8)))
        var paused: Play = play
        try paused.handle(.pause)
        #expect(paused.fingerprint != play.fingerprint)
    }

    @Test func undoRestoresExactFingerprintsAndANewTurnClearsRedo() throws {
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 20)
        for fixture in fixtures {
            let level: VoxelOrigamiLevel = try Self.rebudgeted(fixture.level, budget: 40)
            var play: Play = try Self.playing(level)
            var history: [String] = [play.fingerprint]
            for action in fixture.actions.dropLast() {
                try Self.act(&play, action)
                history.append(play.fingerprint)
            }
            // Undo every action, checking each fingerprint, then redo them all.
            for position in stride(from: history.count - 2, through: 0, by: -1) {
                try play.undo()
                #expect(play.fingerprint == history[position])
            }
            #expect(Self.refusal(play, .undo) == .action("undo"))
            for position in 1..<history.count {
                try play.redo()
                #expect(play.fingerprint == history[position])
            }
            #expect(Self.refusal(play, .redo) == .action("redo"))
            // Undo while paused stays paused; a new turn clears redo.
            if history.count > 1 {
                try play.handle(.pause)
                try play.undo()
                #expect(play.stage == .paused)
                #expect(play.canRedo)
                try play.handle(.resume)
                #expect(play.fingerprint == history[history.count - 2])
                // Turning the undone hinge again reaches the same moment but clears the redo stack.
                var turned: Play = play
                try Self.act(&turned, fixture.actions[history.count - 2])
                #expect(turned.stage == .playing)
                #expect(turned.fingerprint == history[history.count - 1])
                #expect(!turned.canRedo)
                #expect(Self.refusal(turned, .redo) == .action("redo"))
            }
        }
    }

    // MARK: Replay

    @Test func fiveHundredSeededTracesReplayIdentically() throws {
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 25)
        var random = SeededRandom(seed: 4_410)
        var outcomes: [VoxelOrigamiStage: Int] = [:]
        for trace in 0..<500 {
            let fixture: VoxelOrigamiFixture = fixtures[trace % fixtures.count]
            var play: Play = try Self.playing(fixture.level)
            let steps: Int = random.int(1...10)
            for _ in 0..<steps {
                let roll: Int = random.int(0...9)
                if roll < 6 {
                    let hinge: Int = random.int(1...(fixture.level.cubes.count - 1))
                    let step: Int = random.int(0...1) == 0 ? -1 : 1
                    let before: String = play.fingerprint
                    let spent: Int = play.actionsSpent
                    do {
                        try Self.act(&play, .turn(hinge, step))
                        // Undo of every accepted turn restores the exact fingerprint; redo the turn back.
                        let after: String = play.fingerprint
                        if play.stage != .won {
                            try play.undo()
                            #expect(play.fingerprint == before)
                            #expect(play.actionsSpent == spent)
                            try play.redo()
                            #expect(play.fingerprint == after)
                        }
                    } catch {
                        #expect(play.fingerprint == before)
                    }
                } else if roll < 8 {
                    try? play.undo()
                } else if roll < 9 {
                    try? play.redo()
                } else if play.stage == .playing {
                    try play.handle(.pause)
                    try? play.undo()
                    try play.handle(.resume)
                }
            }
            outcomes[play.stage, default: 0] += 1
            var replayed: Play = try Play.replay(level: fixture.level, records: play.records)
            // Pauses are not records: a trace whose last record was taken paused ends paused on replay.
            if let last = play.records.last { #expect(last.next == replayed.fingerprint) }
            if replayed.stage == .paused, play.stage == .playing { try replayed.handle(.resume) }
            #expect(replayed == play, "trace \(trace)")
            #expect(replayed.fingerprint == play.fingerprint)
            for record in play.records {
                #expect(record.schema == Play.schema && record.seed == fixture.level.seed)
            }
        }
        #expect((outcomes[.playing] ?? 0) > 0)
        #expect((outcomes[.won] ?? 0) + (outcomes[.failed] ?? 0) > 0)
    }

    @Test func recordsRoundTripAndTamperedTracesAreRefused() throws {
        let level: VoxelOrigamiLevel = try Self.collisionLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .turn(2, -1))
        try play.handle(.pause)
        try play.undo()
        try play.handle(.resume)
        try play.redo()
        try Self.act(&play, .turn(2, 1))
        try Self.act(&play, .turn(2, 1))
        #expect(play.stage == .failed)
        try play.undo()
        let records: [VoxelOrigamiRecord] = play.records
        let data: Data = try JSONEncoder().encode(records)
        let decoded: [VoxelOrigamiRecord] = try JSONDecoder().decode([VoxelOrigamiRecord].self, from: data)
        #expect(decoded == records)
        #expect(try Play.replay(level: level, records: decoded) == play)

        func refusal(_ edited: [VoxelOrigamiRecord]) -> VoxelOrigamiError? {
            do {
                _ = try Play.replay(level: level, records: edited)
                return nil
            } catch {
                return error
            }
        }
        func edit(_ index: Int, schema: Int? = nil, seed: UInt64? = nil, kind: VoxelOrigamiRecordKind? = nil,
                  action: VoxelOrigamiAction?? = nil, previous: String? = nil,
                  next: String? = nil) -> [VoxelOrigamiRecord] {
            var copy: [VoxelOrigamiRecord] = records
            let r: VoxelOrigamiRecord = copy[index]
            copy[index] = VoxelOrigamiRecord(schema: schema ?? r.schema, seed: seed ?? r.seed, index: r.index,
                                             kind: kind ?? r.kind, action: action ?? r.action,
                                             previous: previous ?? r.previous, next: next ?? r.next)
            return copy
        }
        #expect(refusal(edit(1, schema: 2)) == .malformed("schema 1"))
        #expect(refusal(edit(0, seed: 99)) == .malformed("seed 0"))
        #expect(refusal(edit(2, previous: "beef")) == .malformed("replay"))
        #expect(refusal(edit(3, next: "beef")) == .malformed("record 3"))
        #expect(refusal(edit(0, action: .some(nil))) == .malformed("record 0"))
        #expect(refusal(edit(1, action: .some(.turn(2, 1)))) == .malformed("record 1"))
        #expect(refusal(edit(0, action: .some(.turn(2, 1)))) == .malformed("record 0"))
        #expect(refusal(edit(0, action: .some(.turn(3, 1)))) == .action("idle"))
    }
}
