// MyceliumArchitectPlayTests — feature 511 (R02-G22-01) T-R02G2201-004 (FR-R02G2201-006 … 009, 012, 013, 015;
// SC-R02G2201-001, 002, 004; clarifications Q4, Q5). The play of a Mycelium Architect level: the full stage table of
// `handle(_:)` with the recorded event kinds and the tutorial flag; the 500 fixtures' known actions keep the report
// equal to the growth report after every arrangement action and win on the run (SC-R02G2201-001); each failure named
// on the run (`toxic`, `starved`, `unreached`, `overweight`) with its words; the budget refusal on the exact action with
// the run still allowed; the validation order stage, stale, action, budget, with every refusal reachable (each action
// reason, the budget, the stage in every stage, a stale fingerprint), spending nothing and leaving the play unchanged;
// the fingerprint is the SHA-256 of its canonical text; undo restores exact fingerprints, undo from failed returns to
// playing with the arrangement before the run (recorded) and a redo re-runs it to the same failure, a won run is final,
// nothing but resume is accepted while paused, a new action clears redo; 500 seeded random traces replay to the same
// records, fingerprints and outcome, and tampered traces are refused. Explicit types, plain loops, short traces; each
// test well under 10 s; no clock.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import MyceliumArchitectCore

@Suite struct MyceliumArchitectPlayTests {
    typealias Play = MyceliumArchitectPlay
    typealias Action = MyceliumArchitectAction
    typealias Level = MyceliumArchitectLevel
    typealias Cell = MyceliumArchitectCell
    typealias Direction = MyceliumArchitectDirection
    typealias Record = MyceliumArchitectRecord
    typealias Growth = MyceliumArchitectGrowth
    typealias Failure = MyceliumArchitectFailure
    typealias Stage = MyceliumArchitectStage
    typealias Event = MyceliumArchitectEvent

    /// The test seed of the feature.
    static let seed: UInt64 = 2_511

    /// The 500 fixtures of the feature seed, built once.
    static let fixtures: [MyceliumArchitectFixture] = MyceliumArchitectFixture.all(count: 500)

    /// The first 25 fixtures, built on their own so the shorter tests need not wait for all 500.
    static let few: [MyceliumArchitectFixture] = MyceliumArchitectFixture.all(count: 25)

    /// An operation on a play, for refusal checks.
    enum Operation {
        /// Apply an action, naming the given previous fingerprint (nil: the current one).
        case act(Action, String?)
        /// Undo.
        case undo
        /// Redo.
        case redo
        /// Handle an event.
        case event(Event)
    }

    /// Applies `action` with the current fingerprint.
    static func act(_ play: inout Play, _ action: Action) throws(MyceliumArchitectError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// Runs `operation` on a copy of `play`; returns the refusal (nil when accepted) and expects a refused copy to be
    /// unchanged.
    static func refusal(_ play: Play, _ operation: Operation) -> MyceliumArchitectError? {
        var copy: Play = play
        do {
            switch operation {
            case .act(let action, let previous): try copy.apply(action, expecting: previous ?? copy.fingerprint)
            case .undo: try copy.undo()
            case .redo: try copy.redo()
            case .event(let event): try copy.handle(event)
            }
        } catch {
            #expect(copy == play)
            return error
        }
        return nil
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    static func playing(_ level: Level) throws(MyceliumArchitectError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The hand level: a 9 × 5 board, root (1, 2), terminal (7, 2), strength 1, reach 4, curvature 1, obstacle 0,
    /// 16 pulses. With no field a seeded tip grows straight on until the board ends: seeded east it grows (2, 2) …
    /// (8, 2), seven segments of weight 2 (total 14), reaching the terminal on pulse 6 at path weight 12; seeded west
    /// it grows (0, 2) only. The start (no seed) never wins.
    static func hand(rocks: [Cell] = [], toxins: [Cell] = [], fixed: [Cell] = [], startSeeds: [Direction] = [],
                     nutrientBudget: Int = 4094, weightLimit: Int = 4094, budget: Int = 8, maxNutrients: Int = 1,
                     maxBlockers: Int = 1, maxSeeds: Int = 2, tutorial: Bool = false, id: String = "hand",
                     seed: UInt64 = 7) throws(MyceliumArchitectError) -> Level {
        try Level(id: id, seed: seed, difficulty: 1, width: 9, height: 5, root: Cell(column: 1, row: 2),
                  terminals: [Cell(column: 7, row: 2)], rocks: rocks, toxins: toxins, fixedNutrients: fixed,
                  strength: 1, reach: 4, curvature: 1, obstacle: 0, maxNutrients: maxNutrients,
                  maxBlockers: maxBlockers, maxSeeds: maxSeeds, startSeeds: startSeeds, pulses: 16,
                  nutrientBudget: nutrientBudget, weightLimit: weightLimit, budget: budget, tutorial: tutorial)
    }

    /// The refusal level: the hand level with a rock at (4, 0), a toxin at (4, 4), a fixed nutrient at (6, 4), the
    /// starting seed north, one nutrient, one blocker and two seeds allowed.
    static func refusalLevel(budget: Int = 8) throws(MyceliumArchitectError) -> Level {
        try hand(rocks: [Cell(column: 4, row: 0)], toxins: [Cell(column: 4, row: 4)], fixed: [Cell(column: 6, row: 4)],
                 startSeeds: [.north], budget: budget)
    }

    /// A play of `level` in each stage: loading, tutorial (when the level has one), playing, paused, won, failed and
    /// result (won from seeding east, failed from seeding west).
    static func plays(_ level: Level) throws(MyceliumArchitectError) -> [Stage: Play] {
        var plays: [Stage: Play] = [:]
        var play = Play(level: level)
        plays[.loading] = play
        try play.handle(.begin)
        if level.tutorial {
            plays[.tutorial] = play
            try play.handle(.dismissTutorial)
        }
        plays[.playing] = play
        var paused: Play = play
        try paused.handle(.pause)
        plays[.paused] = paused
        var won: Play = play
        try act(&won, .seed(.east))
        try act(&won, .run)
        plays[.won] = won
        var failed: Play = play
        try act(&failed, .seed(.west))
        try act(&failed, .run)
        plays[.failed] = failed
        var result: Play = failed
        try result.handle(.showResult)
        plays[.result] = result
        return plays
    }

    // MARK: Stages and events

    @Test func theStageTableAcceptsOnlyItsEventsAndRecordsTheirKinds() throws {
        let events: [Event] = [.begin, .dismissTutorial, .pause, .resume, .showResult]
        let kinds: [Record.Kind] = [.begin, .dismissTutorial, .pause, .resume, .showResult]
        let tutorialPlays: [Stage: Play] = try Self.plays(try Self.hand(tutorial: true))
        #expect(tutorialPlays.count == Stage.allCases.count)
        for stage in Stage.allCases {
            let play: Play = tutorialPlays[stage]!
            #expect(play.stage == stage)
            for e in 0..<events.count {
                let event: Event = events[e]
                let accepted: Bool = (stage == .loading && event == .begin)
                    || (stage == .tutorial && event == .dismissTutorial)
                    || (stage == .playing && event == .pause) || (stage == .paused && event == .resume)
                    || ((stage == .won || stage == .failed) && event == .showResult)
                if accepted {
                    var copy: Play = play
                    try copy.handle(event)
                    #expect(copy.records.count == play.records.count + 1)
                    #expect(copy.records.last!.kind == kinds[e])
                    #expect(copy.records.last!.action == nil)
                    #expect(copy.records.last!.previous == play.fingerprint)
                    #expect(copy.records.last!.next == copy.fingerprint)
                } else {
                    #expect(Self.refusal(play, .event(event)) == .stage)
                }
            }
        }
    }

    @Test func theTutorialFlagDecidesWhereBeginLeads() throws {
        var tutorial = Play(level: try Self.hand(tutorial: true))
        try tutorial.handle(.begin)
        #expect(tutorial.stage == .tutorial)
        #expect(Self.refusal(tutorial, .act(.seed(.east), nil)) == .stage)
        #expect(Self.refusal(tutorial, .act(.run, nil)) == .stage)
        try tutorial.handle(.dismissTutorial)
        #expect(tutorial.stage == .playing)
        #expect(tutorial.records.map { $0.kind } == [.begin, .dismissTutorial])

        var plain = Play(level: try Self.hand())
        try plain.handle(.begin)
        #expect(plain.stage == .playing)
        #expect(Self.refusal(plain, .event(.dismissTutorial)) == .stage)
        #expect(plain.records.map { $0.kind } == [.begin])
    }

    @Test func pauseRefusesEverythingButResume() throws {
        var play: Play = try Self.playing(try Self.hand())
        try Self.act(&play, .seed(.east))
        try play.undo()
        try play.handle(.pause)
        #expect(play.stage == .paused)
        #expect(Self.refusal(play, .act(.seed(.west), nil)) == .stage)
        #expect(Self.refusal(play, .act(.nutrient(Cell(column: 3, row: 3)), nil)) == .stage)
        #expect(Self.refusal(play, .act(.run, nil)) == .stage)
        #expect(Self.refusal(play, .undo) == .stage)
        #expect(Self.refusal(play, .redo) == .stage)
        #expect(Self.refusal(play, .event(.pause)) == .stage)
        #expect(Self.refusal(play, .event(.showResult)) == .stage)
        #expect(!play.canUndo)
        #expect(!play.canRedo)
        try play.handle(.resume)
        #expect(play.stage == .playing)
        #expect(play.canRedo)
        try play.redo()
        #expect(play.arrangement.seeds == [.east])
    }

    // MARK: Known arrangements (SC-R02G2201-001)

    @Test func theKnownActionsOfFiveHundredFixturesWinOnTheRun() throws {
        #expect(Self.fixtures.count == 500)
        for fixture in Self.fixtures {
            var play = Play(level: fixture.level)
            try play.handle(.begin)
            #expect(play.stage == (fixture.level.tutorial ? Stage.tutorial : Stage.playing))
            if fixture.level.tutorial { try play.handle(.dismissTutorial) }
            for action in fixture.actions {
                try Self.act(&play, action)
                if action != .run {
                    #expect(play.report == Growth.report(fixture.level, arrangement: play.arrangement))
                }
            }
            #expect(play.stage == .won)
            #expect(play.failure == nil)
            #expect(play.arrangement == fixture.winning)
            #expect(play.actionsSpent == fixture.actions.count - 1)
            #expect(play.records.last!.kind == .run)
            #expect(Self.refusal(play, .undo) == .stage)
        }
    }

    // MARK: Failures (FR-R02G2201-006)

    @Test func eachFailureIsNamedOnTheRun() throws {
        let toxicLevel: Level = try Self.hand(toxins: [Cell(column: 4, row: 2)])
        let starvedLevel: Level = try Self.hand(nutrientBudget: 6, weightLimit: 6)
        let overweightLevel: Level = try Self.hand(weightLimit: 13)
        let unreachedLevel: Level = try Self.hand()
        let levels: [Level] = [toxicLevel, starvedLevel, overweightLevel, unreachedLevel]
        let seeds: [Direction] = [.east, .east, .east, .west]
        let failures: [Failure] = [
            .toxic(pulse: 3, tip: 0, cell: Cell(column: 4, row: 2)),
            .starved(pulse: 4, tip: 0, cell: Cell(column: 5, row: 2), weight: 8, budget: 6),
            .overweight(weight: 14, limit: 13),
            .unreached(terminal: 0),
        ]
        let codes: [String] = ["toxic", "starved", "overweight", "unreached"]
        let words: [String] = [
            "tip 1 grew into toxin at (4, 2) on pulse 3",
            "tip 1 ran out of nutrient on pulse 4: growing to (5, 2) would make the branch weight 8, above the "
                + "budget of 6",
            "the network's branch weight 14 is above the limit of 13",
            "terminal 1 at (7, 2) was not reached",
        ]
        for index in 0..<levels.count {
            var play: Play = try Self.playing(levels[index])
            try Self.act(&play, .seed(seeds[index]))
            #expect(play.report.failure == failures[index])
            try Self.act(&play, .run)
            #expect(play.stage == .failed)
            #expect(play.failure == failures[index])
            #expect(play.failure?.code == codes[index])
            #expect(levels[index].failureDescription(play.failure!) == words[index])
            #expect(play.actionsSpent == 1)
            #expect(play.records.last!.kind == .run)
            #expect(play.records.last!.action == .run)
        }
        var empty: Play = try Self.playing(unreachedLevel)
        try Self.act(&empty, .run)
        #expect(empty.failure == .unreached(terminal: 0))
        #expect(empty.actionsSpent == 0)
        var winner: Play = try Self.playing(unreachedLevel)
        try Self.act(&winner, .seed(.east))
        try Self.act(&winner, .run)
        #expect(winner.stage == .won)
        #expect(winner.report.totalWeight == 14)
        #expect(winner.report.terminalPathWeights == [12])
    }

    // MARK: Validation order and refusals (FR-R02G2201-007, 012)

    @Test func theBudgetRefusesTheExactActionAndStillAllowsTheRun() throws {
        var play: Play = try Self.playing(try Self.hand(budget: 2))
        try Self.act(&play, .seed(.east))
        #expect(play.actionsLeft == 1)
        try Self.act(&play, .seed(.west))
        #expect(play.actionsLeft == 0)
        #expect(Self.refusal(play, .act(.nutrient(Cell(column: 3, row: 3)), nil)) == .budget)
        #expect(Self.refusal(play, .act(.blocker(Cell(column: 3, row: 3)), nil)) == .budget)
        #expect(Self.refusal(play, .act(.unseed(.west), nil)) == .budget)
        #expect(Self.refusal(play, .act(.nutrient(Cell(column: -1, row: 0)), nil)) == .action("cell"))
        #expect(Self.refusal(play, .act(.nutrient(Cell(column: 3, row: 3)), "stale")) == .stale)
        try Self.act(&play, .run)
        #expect(play.stage == .won)
        #expect(play.actionsSpent == 2)
    }

    @Test func everyActionReasonIsReachableAndChangesNothing() throws {
        var play: Play = try Self.playing(try Self.refusalLevel())
        let blockedCells: [Cell] = [
            Cell(column: -1, row: 0), Cell(column: 9, row: 2), Cell(column: 2, row: 5), Cell(column: 1, row: 2),
            Cell(column: 7, row: 2), Cell(column: 4, row: 0), Cell(column: 4, row: 4), Cell(column: 6, row: 4),
        ]
        for cell in blockedCells {
            #expect(Self.refusal(play, .act(.nutrient(cell), nil)) == .action("cell"))
            #expect(Self.refusal(play, .act(.blocker(cell), nil)) == .action("cell"))
        }
        #expect(Self.refusal(play, .act(.clear(Cell(column: 3, row: 3)), nil)) == .action("clear"))
        #expect(Self.refusal(play, .act(.clear(Cell(column: 6, row: 4)), nil)) == .action("clear"))
        #expect(Self.refusal(play, .act(.clear(Cell(column: 4, row: 0)), nil)) == .action("clear"))
        #expect(Self.refusal(play, .act(.seed(.north), nil)) == .action("seeded"))
        #expect(Self.refusal(play, .act(.unseed(.east), nil)) == .action("not seeded"))
        #expect(Self.refusal(play, .act(.unseed(.north), nil)) == .action("starting seed"))
        #expect(Self.refusal(play, .undo) == .action("undo"))
        #expect(Self.refusal(play, .redo) == .action("redo"))

        try Self.act(&play, .nutrient(Cell(column: 3, row: 3)))
        #expect(Self.refusal(play, .act(.nutrient(Cell(column: 3, row: 3)), nil)) == .action("cell"))
        #expect(Self.refusal(play, .act(.blocker(Cell(column: 3, row: 3)), nil)) == .action("cell"))
        #expect(Self.refusal(play, .act(.nutrient(Cell(column: 5, row: 1)), nil)) == .action("nutrient limit"))
        try Self.act(&play, .blocker(Cell(column: 5, row: 1)))
        #expect(Self.refusal(play, .act(.nutrient(Cell(column: 5, row: 1)), nil)) == .action("cell"))
        #expect(Self.refusal(play, .act(.blocker(Cell(column: 2, row: 4)), nil)) == .action("blocker limit"))
        try Self.act(&play, .seed(.east))
        #expect(Self.refusal(play, .act(.seed(.east), nil)) == .action("seeded"))
        #expect(Self.refusal(play, .act(.seed(.south), nil)) == .action("seed limit"))
        #expect(play.arrangement == MyceliumArchitectArrangement(nutrients: [Cell(column: 3, row: 3)],
                                                                 blockers: [Cell(column: 5, row: 1)],
                                                                 seeds: [.north, .east]))
        try Self.act(&play, .unseed(.east))
        try Self.act(&play, .clear(Cell(column: 3, row: 3)))
        try Self.act(&play, .clear(Cell(column: 5, row: 1)))
        #expect(play.arrangement == play.level.start)
        #expect(play.actionsSpent == 6)
        #expect(play.records.map { $0.kind } == [.begin, .nutrient, .blocker, .seed, .unseed, .clear, .clear])

        let limited: Play = try Self.playing(try Self.hand(maxNutrients: 0, maxBlockers: 0))
        #expect(Self.refusal(limited, .act(.nutrient(Cell(column: 3, row: 3)), nil)) == .action("nutrient limit"))
        #expect(Self.refusal(limited, .act(.blocker(Cell(column: 3, row: 3)), nil)) == .action("blocker limit"))
    }

    @Test func theStageIsRefusedInEveryStageButPlaying() throws {
        let plays: [Stage: Play] = try Self.plays(try Self.hand(tutorial: true))
        let actions: [Action] = [.nutrient(Cell(column: 3, row: 3)), .blocker(Cell(column: 3, row: 3)),
                                 .clear(Cell(column: 3, row: 3)), .seed(.south), .unseed(.east), .run]
        for stage in Stage.allCases where stage != .playing {
            let play: Play = plays[stage]!
            for action in actions {
                #expect(Self.refusal(play, .act(action, nil)) == .stage)
                #expect(Self.refusal(play, .act(action, "stale")) == .stage)
            }
            #expect(Self.refusal(play, .redo) == .stage)
            if stage != .failed {
                #expect(Self.refusal(play, .undo) == .stage)
            }
        }
        let playing: Play = plays[.playing]!
        #expect(Self.refusal(playing, .act(.nutrient(Cell(column: -1, row: 0)), "stale")) == .stale)
        #expect(Self.refusal(playing, .act(.run, "stale")) == .stale)
        #expect(Self.refusal(playing, .act(.seed(.east), nil)) == nil)
    }

    // MARK: Fingerprint

    @Test func theFingerprintIsTheHashOfItsCanonicalText() throws {
        var play: Play = try Self.playing(try Self.refusalLevel())
        try Self.act(&play, .nutrient(Cell(column: 3, row: 3)))
        try Self.act(&play, .blocker(Cell(column: 5, row: 1)))
        try Self.act(&play, .seed(.east))
        try Self.act(&play, .run)
        let failure: String = Play.text(play.failure)
        let text: String = "{\"actions\":3,\"blockers\":[[5,1]],\"failure\":\"" + failure + "\",\"level\":\""
            + play.level.fingerprint + "\",\"nutrients\":[[3,3]],\"schema\":1,\"seeds\":[0,2],\"stage\":\""
            + play.stage.rawValue + "\"}"
        #expect(play.fingerprint == StableHash.sha256Hex(Array(text.utf8)))
        #expect(Play.text(nil) == "none")
        #expect(Play.text(.toxic(pulse: 3, tip: 1, cell: Cell(column: 4, row: 2))) == "toxic 3 1 4 2")
        #expect(Play.text(.starved(pulse: 4, tip: 0, cell: Cell(column: 5, row: 2), weight: 8, budget: 6))
                == "starved 4 0 5 2 8 6")
        #expect(Play.text(.unreached(terminal: 2)) == "unreached 2")
        #expect(Play.text(.overweight(weight: 14, limit: 13)) == "overweight 14 13")
        let other: Play = try Self.playing(try Self.refusalLevel(budget: 9))
        #expect(other.fingerprint != (try Self.playing(try Self.refusalLevel())).fingerprint)
    }

    // MARK: Undo and redo (FR-R02G2201-008)

    @Test func undoAndRedoRestoreExactFingerprints() throws {
        for fixture in Self.few {
            var play: Play = try Self.playing(fixture.level)
            var prints: [String] = [play.fingerprint]
            for action in fixture.actions where action != .run {
                try Self.act(&play, action)
                prints.append(play.fingerprint)
            }
            var index: Int = prints.count - 1
            while index > 0 {
                try play.undo()
                index -= 1
                #expect(play.fingerprint == prints[index])
                #expect(play.actionsSpent == index)
                #expect(play.report == Growth.report(fixture.level, arrangement: play.arrangement))
            }
            #expect(play.arrangement == fixture.level.start)
            #expect(Self.refusal(play, .undo) == .action("undo"))
            for next in 1..<prints.count {
                try play.redo()
                #expect(play.fingerprint == prints[next])
            }
            #expect(Self.refusal(play, .redo) == .action("redo"))
            try Self.act(&play, .run)
            #expect(play.stage == .won)
        }
    }

    @Test func undoFromFailedReturnsToPlayingAndRedoFailsAgain() throws {
        var play: Play = try Self.playing(try Self.hand())
        try Self.act(&play, .seed(.west))
        let beforeRun: String = play.fingerprint
        try Self.act(&play, .run)
        let afterRun: String = play.fingerprint
        #expect(play.stage == .failed)
        #expect(play.canUndo)
        #expect(!play.canRedo)
        try play.undo()
        #expect(play.stage == .playing)
        #expect(play.failure == nil)
        #expect(play.arrangement.seeds == [.west])
        #expect(play.actionsSpent == 1)
        #expect(play.fingerprint == beforeRun)
        #expect(play.records.last!.kind == .undo)
        try play.redo()
        #expect(play.stage == .failed)
        #expect(play.failure == .unreached(terminal: 0))
        #expect(play.fingerprint == afterRun)
        #expect(play.records.last!.kind == .redo)
        try play.undo()
        try Self.act(&play, .seed(.east))
        #expect(!play.canRedo)
        #expect(Self.refusal(play, .redo) == .action("redo"))
        try Self.act(&play, .run)
        #expect(play.stage == .won)
        #expect(!play.canUndo)
        #expect(Self.refusal(play, .undo) == .stage)
        try play.handle(.showResult)
        #expect(play.stage == .result)
        #expect(play.records.map { $0.kind } == [.begin, .seed, .run, .undo, .redo, .undo, .seed, .run, .showResult])
    }

    // MARK: Replay (FR-R02G2201-008; SC-R02G2201-002)

    /// A seeded random trace of up to 16 operations on `level`, refusals ignored.
    static func randomTrace(_ level: Level, _ random: inout SeededRandom) -> Play {
        var play = Play(level: level)
        try? play.handle(.begin)
        try? play.handle(.dismissTutorial)
        for _ in 0..<16 {
            let roll: Int = random.int(0...13)
            let cell = Cell(column: random.int(-1...level.width), row: random.int(-1...level.height))
            let direction: Direction = Direction(rawValue: random.int(0...7))!
            switch roll {
            case 0, 1, 2: try? act(&play, .nutrient(cell))
            case 3, 4: try? act(&play, .blocker(cell))
            case 5:
                let placed: [Cell] = play.arrangement.nutrients + play.arrangement.blockers
                let target: Cell = placed.isEmpty ? cell : placed[random.int(0...(placed.count - 1))]
                try? act(&play, .clear(target))
            case 6, 7: try? act(&play, .seed(direction))
            case 8: try? act(&play, .unseed(direction))
            case 9: try? act(&play, .run)
            case 10: try? play.undo()
            case 11: try? play.redo()
            case 12:
                try? play.handle(.pause)
                try? play.handle(.resume)
            default: try? play.handle(.showResult)
            }
        }
        return play
    }

    @Test func fiveHundredSeededTracesReplayToTheSameFingerprints() throws {
        var random = SeededRandom(seed: Self.seed)
        for index in 0..<500 {
            let level: Level = Self.fixtures[index].level
            let play: Play = Self.randomTrace(level, &random)
            #expect(play.records.first!.previous == Play(level: level).fingerprint)
            for r in 1..<play.records.count {
                #expect(play.records[r].previous == play.records[r - 1].next)
            }
            #expect(play.records.last!.next == play.fingerprint)
            let replayed: Play = try Play.replay(level: level, records: play.records)
            #expect(replayed.records == play.records)
            #expect(replayed.fingerprint == play.fingerprint)
            #expect(replayed.stage == play.stage)
            #expect(replayed.failure == play.failure)
            #expect(replayed.arrangement == play.arrangement)
            #expect(replayed.actionsSpent == play.actionsSpent)
        }
    }

    @Test func tamperedTracesAreRefused() throws {
        let level: Level = try Self.hand()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .seed(.west))
        try Self.act(&play, .run)
        try play.undo()
        let records: [Record] = play.records
        #expect(try Play.replay(level: level, records: records) == play)

        func refusal(_ level: Level, _ records: [Record]) -> MyceliumArchitectError? {
            do {
                _ = try Play.replay(level: level, records: records)
            } catch {
                return error
            }
            return nil
        }
        let otherSeed: Level = try Self.hand(maxSeeds: 3, seed: 7)
        #expect(refusal(otherSeed, records) == .malformed("chain 0"))
        let otherLevel: Level = try Self.hand(id: "other", seed: 8)
        #expect(refusal(otherLevel, records) == .malformed("seed 0"))

        var broken: [Record] = records
        let second: Record = broken[1]
        broken[1] = Record(schema: second.schema, levelSeed: second.levelSeed, index: second.index, kind: second.kind,
                           action: second.action, previous: "broken", next: second.next)
        #expect(refusal(level, broken) == .malformed("chain 1"))

        var reindexed: [Record] = records
        reindexed[1] = Record(schema: second.schema, levelSeed: second.levelSeed, index: 5, kind: second.kind,
                              action: second.action, previous: second.previous, next: second.next)
        #expect(refusal(level, reindexed) == .malformed("index 1"))

        var schemaChanged: [Record] = records
        schemaChanged[1] = Record(schema: 2, levelSeed: second.levelSeed, index: second.index, kind: second.kind,
                                  action: second.action, previous: second.previous, next: second.next)
        #expect(refusal(level, schemaChanged) == .malformed("schema 1"))

        var noAction: [Record] = records
        noAction[1] = Record(schema: second.schema, levelSeed: second.levelSeed, index: second.index,
                             kind: second.kind, action: nil, previous: second.previous, next: second.next)
        #expect(refusal(level, noAction) == .malformed("record 1"))

        var wrongKind: [Record] = records
        wrongKind[1] = Record(schema: second.schema, levelSeed: second.levelSeed, index: second.index,
                              kind: .nutrient, action: second.action, previous: second.previous, next: second.next)
        #expect(refusal(level, wrongKind) == .malformed("record 1"))

        var eventWithAction: [Record] = records
        let first: Record = records[0]
        eventWithAction[0] = Record(schema: first.schema, levelSeed: first.levelSeed, index: first.index,
                                    kind: first.kind, action: .run, previous: first.previous, next: first.next)
        #expect(refusal(level, eventWithAction) == .malformed("record 0"))

        var wrongNext: [Record] = records
        let last: Record = records[records.count - 1]
        wrongNext[records.count - 1] = Record(schema: last.schema, levelSeed: last.levelSeed, index: last.index,
                                              kind: last.kind, action: nil, previous: last.previous, next: "wrong")
        #expect(refusal(level, wrongNext) == .malformed("record \(records.count - 1)"))

        var otherAction: [Record] = records
        otherAction[1] = Record(schema: second.schema, levelSeed: second.levelSeed, index: second.index,
                                kind: second.kind, action: .seed(.east), previous: second.previous, next: second.next)
        #expect(refusal(level, otherAction) == .malformed("record 1"))
    }
}
