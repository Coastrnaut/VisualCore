// NocturneGardenPlayTests — feature 381 (R02-G09-01) T-R02G0901-004 (FR-R02G0901-002, 004 … 008, 011, 013, 014;
// SC-R02G0901-001 … 004; clarifications Q3, Q4, Q5). The play of a Nocturne Garden level: the full stage table of
// `handle(_:)`; the 500 fixtures' known actions win exactly on their last action (five groups of 100), each accepted
// action spending one move, with the mask, match, leak and deviation equal to an independent computation; a win on the
// last move of the budget wins; a leak exactly at the allowance is allowed and one cell more fails on that move with the
// reason named (a plant and a sun change), and the leak is judged before the win; the budget fails on the exact move,
// with budgets one move either side; the validation order stage, stale, range, supply, no-op, with every refusal
// reachable, spending nothing and leaving the play unchanged; a removed bloom returns to the supply; undo from failed
// returns to playing and a won play is final; undo of every action restores the exact fingerprint and a new action
// clears redo; 500 seeded traces (seed 2_381, five groups of 100) replay to the same records, fingerprint and outcome,
// and a tampered trace is refused. Explicit types, plain loops; each test well under 10 s.
import Foundation
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite struct NocturneGardenPlayTests {
    typealias Play = NocturneGardenPlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(NocturneGardenAction)
        case stale(NocturneGardenAction)
        case undo
        case redo
        case event(NocturneGardenEvent)
    }

    static let events: [NocturneGardenEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(NocturneGardenError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: NocturneGardenAction) throws(NocturneGardenError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> NocturneGardenError? {
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
    static func playing(_ level: NocturneGardenLevel) throws(NocturneGardenError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// `base` with another budget.
    static func level(_ base: NocturneGardenLevel, budget: Int) throws(NocturneGardenError) -> NocturneGardenLevel {
        try NocturneGardenLevel(id: base.id, seed: base.seed, difficulty: base.difficulty, width: base.width,
                                height: base.height, target: base.target, forbidden: base.forbidden,
                                supply: base.supply, sizes: base.sizes, elevations: base.elevations, sun: base.sun,
                                budget: budget, required: base.required, leakAllowance: base.leakAllowance,
                                tutorial: base.tutorial)
    }

    /// A 16 × 12 garden with the given values.
    static func garden(target: Set<Int>, forbidden: Set<Int> = [],
                       supply: [NocturneGardenKind: Int] = [.tulip: 2, .rose: 1], sizes: Set<Int> = [1, 2],
                       elevations: Set<Int> = [1, 2, 3], sun: Int = 2, budget: Int = 6,
                       required: NocturneGardenRatio = .whole, allowance: Int = 0,
                       tutorial: Bool = false) throws(NocturneGardenError) -> NocturneGardenLevel {
        try NocturneGardenLevel(id: "garden", seed: 381, difficulty: 1, width: 16, height: 12, target: target,
                                forbidden: forbidden, supply: supply, sizes: sizes, elevations: elevations, sun: sun,
                                budget: budget, required: required, leakAllowance: allowance, tutorial: tutorial)
    }

    /// The cells of `bloom` in a 16 × 12 bed under `elevation`.
    static func cells(_ bloom: NocturneGardenBloom, _ elevation: Int = 2) -> Set<Int> {
        bloom.cells(elevation: elevation, width: 16, height: 12)
    }

    /// A tulip of size 1 at (3, 1), and a rose of size 1 at (11, 1); their shadows are disjoint.
    static let tulip = NocturneGardenBloom(kind: .tulip, column: 3, row: 1, size: 1)
    static let rose = NocturneGardenBloom(kind: .rose, column: 11, row: 1, size: 1)

    /// The cell at column 15, row 11, far from every test bloom.
    static let farCell: Int = 11 * 16 + 15

    /// Checks the play's mask, match, leak and deviation against an independent computation from its blooms.
    static func checkMeasures(_ play: Play, sourceLocation: SourceLocation = #_sourceLocation) {
        let level: NocturneGardenLevel = play.level
        var cells: Set<Int> = []
        for bloom in play.blooms {
            cells.formUnion(bloom.cells(elevation: play.elevation, width: level.width, height: level.height))
        }
        #expect(play.mask.cells == cells, sourceLocation: sourceLocation)
        let shared: Int = cells.intersection(level.target).count
        let either: Int = cells.union(level.target).count
        #expect(play.match.shared == shared, sourceLocation: sourceLocation)
        #expect(play.match.either == either, sourceLocation: sourceLocation)
        #expect(play.leak == cells.intersection(level.forbidden).count, sourceLocation: sourceLocation)
        let deviation: Int = NocturneGardenMask.boundaryDeviation(cells, level.target, width: level.width,
                                                                  height: level.height)
        #expect(play.deviation == deviation, sourceLocation: sourceLocation)
        #expect(play.blooms == play.blooms.sorted(), sourceLocation: sourceLocation)
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let target: Set<Int> = Self.cells(Self.tulip)
        let withTutorial: NocturneGardenLevel = try Self.garden(target: target, tutorial: true)
        let without: NocturneGardenLevel = try Self.garden(target: target)
        let win: NocturneGardenAction = .plant(.tulip, 3, 1, 1)

        // loading: only begin.
        var loading = Play(level: withTutorial)
        #expect(loading.stage == .loading)
        #expect(loading.moves == 0)
        #expect(loading.remaining == 6)
        #expect(loading.blooms.isEmpty)
        #expect(loading.elevation == 2)
        #expect(loading.mask.cells.isEmpty)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(win)) == .stage)
        #expect(Self.refusal(loading, .undo) == .stage)
        #expect(Self.refusal(loading, .redo) == .stage)
        try loading.handle(.begin)
        #expect(loading.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(win)) == .stage)
        #expect(Self.refusal(loading, .undo) == .stage)
        #expect(Self.refusal(loading, .redo) == .stage)
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
        #expect(Self.refusal(direct, .act(win)) == .stage)
        #expect(Self.refusal(direct, .undo) == .action("nothing-to-undo"))
        #expect(Self.refusal(direct, .redo) == .action("nothing-to-redo"))
        try direct.handle(.resume)
        #expect(direct.stage == .playing)

        // won: only showResult; then result refuses everything.
        var won: Play = direct
        try Self.act(&won, win)
        #expect(won.stage == .won)
        #expect(won.failure == nil)
        #expect(won.failureReason == nil)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(.sun(3))) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
        #expect(!won.canUndo)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        #expect(Self.refusal(won, .act(.sun(3))) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)

        // failed: only showResult; actions and redo refused, undo accepted.
        var failed: Play = try Self.playing(try Self.garden(target: target, budget: 1))
        try Self.act(&failed, .plant(.rose, 11, 1, 1))
        #expect(failed.stage == .failed)
        #expect(failed.failure == .budget)
        #expect(failed.failureReason == "the only move was spent without a match of 1/1")
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(.sun(3))) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        #expect(failed.canUndo)
        #expect(!failed.canRedo)
        try failed.handle(.showResult)
        #expect(failed.stage == .result)
        #expect(Self.refusal(failed, .undo) == .stage)
    }

    // MARK: - Known arrangements

    @Test(arguments: [0, 1, 2, 3, 4])
    func fixtureActionsWinOnTheirLastAction(group: Int) throws {
        let fixtures: [NocturneGardenFixture] = NocturneGardenFixtures.fixtures(
            100, seed: NocturneGardenFixtures.seed + UInt64(group * 100))
        for fixture in fixtures {
            var play: Play = try Self.playing(fixture.level)
            #expect(play.elevation == fixture.level.sun)
            for (step, action) in fixture.actions.enumerated() {
                #expect(play.stage == .playing, "\(fixture.level.id) ended before action \(step)")
                let before: String = play.fingerprint
                // Undo of every action but the winning one (won is final) restores the exact fingerprint and moves.
                var probe: Play = play
                try Self.act(&probe, action)
                if step < fixture.actions.count - 1 {
                    try probe.undo()
                    #expect(probe.fingerprint == before)
                    #expect(probe.moves == step)
                } else {
                    #expect(Self.refusal(probe, .undo) == .stage)
                }
                try Self.act(&play, action)
                #expect(play.moves == step + 1)
                #expect(play.remaining == fixture.level.budget - step - 1)
                #expect(play.records.count == step + 1)
                #expect(play.records[step].previous == before)
                #expect(play.records[step].next == play.fingerprint)
                #expect(play.records[step].move == step)
                #expect(play.records[step].kind == NocturneGardenRecordKind(action))
                #expect(play.records[step].action == action)
                #expect(play.records[step].seed == fixture.level.seed)
                #expect(play.records[step].schema == Play.schema)
                Self.checkMeasures(play)
                #expect(play.leak <= fixture.level.leakAllowance)
            }
            #expect(play.stage == .won, "\(fixture.level.id)")
            #expect(play.failure == nil)
            #expect(play.elevation == fixture.elevation)
            #expect(play.blooms == fixture.blooms.sorted())
            #expect(play.mask.cells == fixture.level.target)
            #expect(play.deviation == 0)
        }
    }

    /// A budget of exactly the arrangement's length wins on the last move; one more leaves a move unspent.
    @Test func aWinOnTheLastMoveOfTheBudgetWins() throws {
        for fixture in NocturneGardenFixtures.fixtures(100) {
            let n: Int = fixture.actions.count
            for budget in [n, n + 1] where budget <= NocturneGardenLevel.budgets.upperBound {
                var play: Play = try Self.playing(try Self.level(fixture.level, budget: budget))
                for action in fixture.actions { try Self.act(&play, action) }
                #expect(play.stage == .won, "\(fixture.level.id) budget \(budget)")
                #expect(play.failure == nil)
                #expect(play.remaining == budget - n)
            }
        }
    }

    // MARK: - Leak

    /// Two forbidden cells under the tulip and one under the rose: with an allowance of 2 the tulip is allowed and
    /// the rose fails on its move (index 1), naming it; with an allowance of 3 both are allowed.
    @Test func aLeakAtTheAllowanceIsAllowedAndOneMoreFails() throws {
        let first: [Int] = Self.cells(Self.tulip).sorted()
        let second: [Int] = Self.cells(Self.rose).sorted()
        try #require(first.count >= 3 && second.count >= 2)
        try #require(Set(first).isDisjoint(with: Set(second)))
        let forbidden: Set<Int> = [first[0], first[1], second[0]]
        let target: Set<Int> = Set(first).union(second).subtracting(forbidden)
        for allowance in [2, 3] {
            var play: Play = try Self.playing(try Self.garden(target: target, forbidden: forbidden,
                                                              allowance: allowance))
            try Self.act(&play, .plant(.tulip, 3, 1, 1))
            #expect(play.leak == 2)
            #expect(play.stage == .playing)
            try Self.act(&play, .plant(.rose, 11, 1, 1))
            #expect(play.leak == 3)
            Self.checkMeasures(play)
            if allowance == 2 {
                #expect(play.stage == .failed)
                #expect(play.failure == .leak(1))
                #expect(play.failure?.code == "leak")
                #expect(play.failureReason == "the shadow leaked into 3 cells of the forbidden regions at move 2 "
                    + "(planting bloom 2: rose at column 11, row 1, size 1), 2 allowed")
                #expect(play.records.last?.move == 1)
                #expect(play.records.last?.action == .plant(.rose, 11, 1, 1))
                #expect(play.records.last?.next == play.fingerprint)
            } else {
                #expect(play.stage == .playing)
                #expect(play.failure == nil)
            }
        }
    }

    /// A plant that would win (match 3/4 needed) but leaks one cell over an allowance of 0 fails as a leak; with an
    /// allowance of 1 it wins.
    @Test func theLeakIsJudgedBeforeTheWin() throws {
        let cells: [Int] = Self.cells(Self.tulip).sorted()
        try #require(cells.count >= 4)
        let forbidden: Set<Int> = [cells[0]]
        let target: Set<Int> = Set(cells).subtracting(forbidden)
        for allowance in [0, 1] {
            let level: NocturneGardenLevel = try Self.garden(target: target, forbidden: forbidden, budget: 1,
                                                             required: NocturneGardenRatio(1, 2),
                                                             allowance: allowance)
            var play: Play = try Self.playing(level)
            try Self.act(&play, .plant(.tulip, 3, 1, 1))
            #expect(play.stage == (allowance == 0 ? .failed : .won))
            #expect(play.failure == (allowance == 0 ? .leak(0) : nil))
        }
    }

    /// Raising the sun's shadow factor from 1/2 to 1 stretches the tulip's shadow into a forbidden cell: the sun move
    /// (index 1) fails, naming the sun.
    @Test func aSunChangeThatLeaksFailsNamingTheSun() throws {
        let low: Set<Int> = Self.cells(Self.tulip, 1)
        let high: Set<Int> = Self.cells(Self.tulip, 2)
        let grown: [Int] = high.subtracting(low).sorted()
        try #require(!grown.isEmpty && !grown.contains(Self.farCell))
        let level: NocturneGardenLevel = try Self.garden(target: low.union([Self.farCell]), forbidden: [grown[0]],
                                                         sun: 1)
        var play: Play = try Self.playing(level)
        try Self.act(&play, .plant(.tulip, 3, 1, 1))
        #expect(play.stage == .playing)
        #expect(play.leak == 0)
        try Self.act(&play, .sun(2))
        #expect(play.stage == .failed)
        #expect(play.failure == .leak(1))
        #expect(play.failureReason == "the shadow leaked into 1 cell of the forbidden regions at move 2 (setting "
            + "sun 2 of 4, upper middle, shadows as tall as the blooms), 0 allowed")
        Self.checkMeasures(play)
        // Undo from failed returns to playing with the move given back; redo fails again identically.
        let failed: String = play.fingerprint
        try play.undo()
        #expect(play.stage == .playing)
        #expect(play.failure == nil)
        #expect(play.failureReason == nil)
        #expect(play.moves == 1)
        #expect(play.elevation == 1)
        try play.redo()
        #expect(play.stage == .failed)
        #expect(play.fingerprint == failed)
        #expect(play.records.map(\.kind) == [.plant, .sun, .undo, .redo])
    }

    // MARK: - Budget

    /// A tulip planted and moved along the ground never reaches the target (rows 6 and up): budget b stays playing
    /// after b − 1 moves and fails on move b, for b = 1 … 6 (each one move either side of its neighbours).
    @Test func theBudgetFailsOnTheExactMove() throws {
        let target: Set<Int> = Self.cells(NocturneGardenBloom(kind: .tulip, column: 12, row: 6, size: 1))
        let actions: [NocturneGardenAction] = [.plant(.tulip, 1, 0, 1), .move(0, 2, 0), .move(0, 3, 0),
                                               .move(0, 4, 0), .move(0, 5, 0), .move(0, 6, 0)]
        for budget in 1...6 {
            var play: Play = try Self.playing(try Self.garden(target: target, budget: budget))
            for step in 0..<budget {
                #expect(play.stage == .playing, "budget \(budget) move \(step)")
                #expect(play.remaining == budget - step)
                try Self.act(&play, actions[step])
                #expect(play.match.shared == 0)
            }
            #expect(play.stage == .failed, "budget \(budget)")
            #expect(play.failure == .budget)
            #expect(play.failure?.code == "budget")
            #expect(play.moves == budget)
            #expect(play.remaining == 0)
            #expect(play.records.last?.move == budget - 1)
            if budget > 1 {
                #expect(play.failureReason == "all \(budget) moves were spent without a match of 1/1")
            }
            try play.undo()
            #expect(play.stage == .playing)
            #expect(play.failure == nil)
            #expect(play.moves == budget - 1)
            #expect(play.records.last?.kind == .undo)
        }
    }

    // MARK: - Refusals

    @Test func everyRefusalIsReachableInOrder() throws {
        let level: NocturneGardenLevel = try Self.garden(target: [Self.farCell])
        var play: Play = try Self.playing(level)
        let anchors: [NocturneGardenAction] = [.plant(.tulip, -1, 0, 1), .plant(.tulip, 16, 0, 1),
                                               .plant(.tulip, 0, -1, 1), .plant(.tulip, 0, 12, 1),
                                               .plant(.star, 0, 12, 1)]
        for action in anchors {
            #expect(Self.refusal(play, .act(action)) == .action("anchor"))
            #expect(Self.refusal(play, .stale(action)) == .stale)
        }
        for action in [NocturneGardenAction.plant(.tulip, 0, 0, 3), .plant(.tulip, 0, 0, 0)] {
            #expect(Self.refusal(play, .act(action)) == .action("size"))
        }
        for action in [NocturneGardenAction.sun(4), .sun(0)] {
            #expect(Self.refusal(play, .act(action)) == .action("elevation"))
        }
        for action in [NocturneGardenAction.move(0, 1, 1), .resize(0, 2), .remove(0), .remove(-1)] {
            #expect(Self.refusal(play, .act(action)) == .action("bloom"))
        }
        // supply: a kind the level does not supply.
        #expect(Self.refusal(play, .act(.plant(.star, 0, 0, 1))) == .supply)
        #expect(Self.refusal(play, .act(.sun(2))) == .noop)
        #expect(Self.refusal(play, .undo) == .action("nothing-to-undo"))
        #expect(Self.refusal(play, .redo) == .action("nothing-to-redo"))
        // stage comes before stale and range.
        try play.handle(.pause)
        #expect(Self.refusal(play, .stale(.plant(.star, -9, 99, 9))) == .stage)
        #expect(Self.refusal(play, .act(.sun(3))) == .stage)
        try play.handle(.resume)
        // After a plant: bloom ranges, no-ops and the rose's supply.
        try Self.act(&play, .plant(.rose, 4, 2, 1))
        #expect(play.moves == 1)
        #expect(play.records.count == 1)
        #expect(Self.refusal(play, .act(.move(1, 0, 0))) == .action("bloom"))
        #expect(Self.refusal(play, .act(.move(0, 16, 0))) == .action("anchor"))
        #expect(Self.refusal(play, .act(.resize(0, 3))) == .action("size"))
        #expect(Self.refusal(play, .act(.move(0, 4, 2))) == .noop)
        #expect(Self.refusal(play, .act(.resize(0, 1))) == .noop)
        #expect(Self.refusal(play, .act(.plant(.rose, 9, 2, 1))) == .supply)
        // range comes before supply.
        #expect(Self.refusal(play, .act(.plant(.rose, 9, 2, 3))) == .action("size"))
        #expect(NocturneGardenError.supply.reasonCode == "r02-g09.supply")
        #expect(NocturneGardenError.noop.reasonCode == "r02-g09.noop")
    }

    /// Removing a bloom returns it to the supply; moves and resizes keep the blooms in canonical order.
    @Test func aRemovedBloomReturnsToTheSupply() throws {
        let level: NocturneGardenLevel = try Self.garden(target: [Self.farCell], supply: [.tulip: 1, .rose: 1],
                                                         budget: 9)
        var play: Play = try Self.playing(level)
        try Self.act(&play, .plant(.tulip, 8, 3, 1))
        #expect(play.available(.tulip) == 0)
        #expect(Self.refusal(play, .act(.plant(.tulip, 2, 2, 1))) == .supply)
        try Self.act(&play, .plant(.rose, 1, 0, 2))
        #expect(play.blooms.map(\.kind) == [.rose, .tulip])
        try Self.act(&play, .move(0, 1, 5))
        #expect(play.blooms.map(\.kind) == [.tulip, .rose])
        try Self.act(&play, .resize(0, 2))
        #expect(play.blooms[0] == NocturneGardenBloom(kind: .tulip, column: 8, row: 3, size: 2))
        try Self.act(&play, .remove(0))
        #expect(play.blooms.map(\.kind) == [.rose])
        #expect(play.available(.tulip) == 1)
        try Self.act(&play, .plant(.tulip, 2, 2, 1))
        #expect(play.planted(.tulip) == 1)
        #expect(play.moves == 6)
        Self.checkMeasures(play)
        #expect(play.records.map(\.kind) == [.plant, .plant, .move, .resize, .remove, .plant])
    }

    // MARK: - Undo and redo

    @Test func undoAndRedoRestoreExactFingerprints() throws {
        for fixture in NocturneGardenFixtures.fixtures(100) {
            var play: Play = try Self.playing(fixture.level)
            var prints: [String] = [play.fingerprint]
            var states: [Play] = [play]
            for action in fixture.actions {
                try Self.act(&play, action)
                prints.append(play.fingerprint)
                states.append(play)
            }
            #expect(play.stage == .won)
            #expect(Self.refusal(play, .undo) == .stage)
            // Rebuild to one move before the win and walk back and forth.
            var walk: Play = try Self.playing(fixture.level)
            let n: Int = fixture.actions.count
            for action in fixture.actions.dropLast() { try Self.act(&walk, action) }
            for step in stride(from: n - 1, to: 0, by: -1) {
                let movesBefore: Int = walk.moves
                try walk.undo()
                #expect(walk.fingerprint == prints[step - 1])
                #expect(walk.blooms == states[step - 1].blooms)
                #expect(walk.elevation == states[step - 1].elevation)
                #expect(walk.mask == states[step - 1].mask)
                #expect(walk.moves == step - 1)
                #expect(walk.records.last?.kind == .undo)
                #expect(walk.records.last?.move == movesBefore)
                #expect(walk.records.last?.action == nil)
            }
            #expect(!walk.canUndo)
            for step in 1..<n {
                try walk.redo()
                #expect(walk.fingerprint == prints[step])
                #expect(walk.records.last?.kind == .redo)
            }
            #expect(!walk.canRedo)
            // Undo while paused stays paused; a new action clears redo.
            try walk.handle(.pause)
            if walk.canUndo {
                try walk.undo()
                #expect(walk.stage == .paused)
                #expect(walk.canRedo)
                try walk.handle(.resume)
                try Self.act(&walk, fixture.actions[n - 2])
                #expect(!walk.canRedo)
                #expect(Self.refusal(walk, .redo) == .action("nothing-to-redo"))
            } else {
                try walk.handle(.resume)
            }
            try Self.act(&walk, fixture.actions[n - 1])
            #expect(walk.stage == .won)
            #expect(walk.fingerprint == prints[n])
        }
    }

    // MARK: - Replay

    /// A random action for `play`: a plant, move, resize, remove or sun with operands that may be refused.
    static func randomAction(_ play: Play, _ random: inout SeededRandom) -> NocturneGardenAction {
        let level: NocturneGardenLevel = play.level
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        let count: Int = max(1, play.blooms.count)
        switch random.int(0...5) {
        case 0:
            return .move(random.int(0...(count - 1)), random.int(0...(level.width - 1)),
                         random.int(0...(level.height / 2)))
        case 1: return .resize(random.int(0...(count - 1)), random.int(1...3))
        case 2: return .remove(random.int(0...(count - 1)))
        case 3: return .sun(random.int(1...4))
        default:
            return .plant(kinds[random.int(0...5)], random.int(0...(level.width - 1)),
                          random.int(0...(level.height / 2)), random.int(1...3))
        }
    }

    @Test(arguments: [0, 1, 2, 3, 4])
    func seededTracesReplayToIdenticalFingerprints(group: Int) throws {
        var random = SeededRandom(seed: NocturneGardenFixtures.seed &+ UInt64(group))
        var outcomes: Set<NocturneGardenStage> = []
        var failures: Set<String> = []
        let fixtures: [NocturneGardenFixture] = NocturneGardenFixtures.fixtures(
            100, seed: NocturneGardenFixtures.seed + UInt64(group * 100))
        for fixture in fixtures {
            var play: Play = try Self.playing(fixture.level)
            for _ in 0..<14 {
                if play.stage == .won { break }
                if play.stage == .failed {
                    if let failure = play.failure { failures.insert(failure.code) }
                    try play.undo()
                    continue
                }
                switch random.int(0...9) {
                case 0: try? play.undo()
                case 1: try? play.redo()
                case 2:
                    try play.handle(.pause)
                    try? play.undo()
                    try play.handle(.resume)
                case 3, 4:
                    let index: Int = min(play.moves, fixture.actions.count - 1)
                    try? Self.act(&play, fixture.actions[index])
                default:
                    try? Self.act(&play, Self.randomAction(play, &random))
                }
                Self.checkMeasures(play)
            }
            if let failure = play.failure { failures.insert(failure.code) }
            outcomes.insert(play.stage)
            var replayed: Play = try Play.replay(level: fixture.level, records: play.records)
            #expect(replayed.records == play.records, "\(fixture.level.id)")
            if let last = play.records.last { #expect(replayed.fingerprint == last.next) }
            // A resume after the last (paused) undo is not a record: resume the replay to match.
            if replayed.stage == .paused && play.stage == .playing { try replayed.handle(.resume) }
            #expect(replayed.stage == play.stage)
            #expect(replayed.fingerprint == play.fingerprint)
            #expect(replayed.blooms == play.blooms)
            #expect(replayed.elevation == play.elevation)
            #expect(replayed.moves == play.moves)
            #expect(replayed.failure == play.failure)
            #expect(replayed.failureReason == play.failureReason)
            #expect(replayed.mask == play.mask)
        }
        #expect(outcomes.contains(.won))
        #expect(failures.contains("budget"))
        #expect(failures.contains("leak"))
    }

    @Test func aTamperedTraceIsRefused() throws {
        let fixture: NocturneGardenFixture = NocturneGardenFixtures.fixture(NocturneGardenFixtures.seed + 1)
        var play: Play = try Self.playing(fixture.level)
        for action in fixture.actions { try Self.act(&play, action) }
        let records: [NocturneGardenRecord] = play.records
        let first: NocturneGardenRecord = records[0]
        var changed: [NocturneGardenRecord] = records
        // A changed next fingerprint.
        changed[0] = NocturneGardenRecord(schema: first.schema, seed: first.seed, move: first.move, kind: first.kind,
                                          action: first.action, previous: first.previous, next: "0000")
        #expect(throws: NocturneGardenError.malformed("record 0")) {
            _ = try Play.replay(level: fixture.level, records: changed)
        }
        // A changed previous fingerprint.
        changed[0] = NocturneGardenRecord(schema: first.schema, seed: first.seed, move: first.move, kind: first.kind,
                                          action: first.action, previous: "0000", next: first.next)
        #expect(throws: NocturneGardenError.malformed("replay")) {
            _ = try Play.replay(level: fixture.level, records: changed)
        }
        // An action record without its action.
        changed[0] = NocturneGardenRecord(schema: first.schema, seed: first.seed, move: first.move, kind: first.kind,
                                          action: nil, previous: first.previous, next: first.next)
        #expect(throws: NocturneGardenError.malformed("record 0")) {
            _ = try Play.replay(level: fixture.level, records: changed)
        }
        // A kind that does not match its action, another schema, another seed.
        let wrongKind: NocturneGardenRecordKind = first.kind == .remove ? .move : .remove
        let damaged: [NocturneGardenRecord] = [
            NocturneGardenRecord(schema: first.schema, seed: first.seed, move: first.move, kind: wrongKind,
                                 action: first.action, previous: first.previous, next: first.next),
            NocturneGardenRecord(schema: 2, seed: first.seed, move: first.move, kind: first.kind,
                                 action: first.action, previous: first.previous, next: first.next),
            NocturneGardenRecord(schema: first.schema, seed: first.seed &+ 1, move: first.move, kind: first.kind,
                                 action: first.action, previous: first.previous, next: first.next),
        ]
        for record in damaged {
            changed[0] = record
            #expect(throws: NocturneGardenError.malformed("record 0")) {
                _ = try Play.replay(level: fixture.level, records: changed)
            }
        }
        // The records round-trip through JSON and still replay.
        let data: Data = try JSONEncoder().encode(records)
        let decoded: [NocturneGardenRecord] = try JSONDecoder().decode([NocturneGardenRecord].self, from: data)
        #expect(decoded == records)
        #expect(try Play.replay(level: fixture.level, records: decoded).fingerprint == play.fingerprint)
    }
}
