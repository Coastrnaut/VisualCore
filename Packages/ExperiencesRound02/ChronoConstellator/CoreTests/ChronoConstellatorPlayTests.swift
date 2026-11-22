// ChronoConstellatorPlayTests — feature 351 (R02-G06-01) T-R02G0601-004 (FR-R02G0601-004 … 008; SC-R02G0601-001 … 004;
// clarifications Q3, Q4, Q5). The play of a Chrono Constellator level: the full stage table of `handle(_:)`; the 200
// fixtures' known solutions, applied as actions, win at exactly their win tick and the step stops there; collision and
// time fail at the exact tick, one tick either side of each limit; the validation order stage, stale, range,
// not-at-start, same-phase, overlap, no-hold, budget, with every refusal reachable and leaving the play unchanged; rewind
// keeps the timeline (also from failed); a won play is final; undo and redo restore exact fingerprints for every action
// kind and a new action clears redo; 500 seeded traces (seeds 2_351 and 2_356) replay to the same records, fingerprint
// and outcome (undo and redo made while paused included) and a tampered record is refused. Explicit types, plain loops; each test well under 10 s.
import Foundation
import Testing
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorPlayTests {
    typealias Play = ChronoConstellatorPlay

    /// One operation on a play, so that refusals can be listed and checked in loops.
    enum Op {
        case act(ChronoConstellatorAction)
        case stale(ChronoConstellatorAction)
        case undo
        case redo
        case event(ChronoConstellatorEvent)
    }

    static let events: [ChronoConstellatorEvent] = [.begin, .dismissTutorial, .pause, .resume, .showResult]

    static func perform(_ op: Op, _ play: inout Play) throws(ChronoConstellatorError) {
        switch op {
        case .act(let action): try play.apply(action, expecting: play.fingerprint)
        case .stale(let action): try play.apply(action, expecting: "0000")
        case .undo: try play.undo()
        case .redo: try play.redo()
        case .event(let event): try play.handle(event)
        }
    }

    static func act(_ play: inout Play, _ action: ChronoConstellatorAction) throws(ChronoConstellatorError) {
        try play.apply(action, expecting: play.fingerprint)
    }

    /// The refusal of `op` on a copy of `play` (nil when accepted); a refused op must leave the copy unchanged.
    static func refusal(_ play: Play, _ op: Op,
                        sourceLocation: SourceLocation = #_sourceLocation) -> ChronoConstellatorError? {
        var copy: Play = play
        do {
            try perform(op, &copy)
            return nil
        } catch {
            #expect(copy == play, "refused \(op) changed the play", sourceLocation: sourceLocation)
            #expect(copy.fingerprint == play.fingerprint, sourceLocation: sourceLocation)
            #expect(copy.records == play.records, sourceLocation: sourceLocation)
            return error
        }
    }

    /// A play of `level` that has begun (and dismissed its tutorial).
    static func playing(_ level: ChronoConstellatorLevel) throws(ChronoConstellatorError) -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// Two stars on a 6 × 5 grid whose loops share cells 1 and 7. Star 0 circles [0, 1, 7, 6] from phase 0; star 1
    /// circles [1, 2, 3, 4, 10, 16, 15, 14, 13, 7] from phase 1. Star 0 is on cell 1 when t ≡ 1 (mod 4), star 1 when
    /// t ≡ 9 (mod 10), so they first meet at tick 9 on cell 1 (cell 7 first at tick 18). Targets 6 and 16 need t odd
    /// and t even at once, so the default timeline never wins.
    static func collisionLevel(tickLimit: Int = 100, budget: Int = 2) throws(ChronoConstellatorError)
        -> ChronoConstellatorLevel {
        let a: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 2, height: 2, columns: 6)
        let b: [Int] = ChronoConstellatorFixtures.rectangle(column: 1, row: 0, width: 4, height: 3, columns: 6)
        let stars: [ChronoConstellatorStar] = [ChronoConstellatorStar(loop: a, phase: 0, target: 6),
                                               ChronoConstellatorStar(loop: b, phase: 1, target: 16)]
        return try ChronoConstellatorLevel(id: "collision", seed: 9, difficulty: 1, columns: 6, rows: 5, stars: stars,
                                           budget: budget, tickLimit: tickLimit)
    }

    /// The solution of `fixture` as actions: every phase edit, then the hold (if any).
    static func solution(_ fixture: ChronoConstellatorFixture) -> [ChronoConstellatorAction] {
        var actions: [ChronoConstellatorAction] = []
        for star in fixture.phases.indices where fixture.level.stars[star].phase != fixture.phases[star] {
            actions.append(.phase(star, fixture.phases[star]))
        }
        for hold in fixture.holds { actions.append(.hold(hold.star, hold.start, hold.length)) }
        return actions
    }

    /// `fixture`'s level with another tick limit and no tutorial.
    static func level(_ fixture: ChronoConstellatorFixture, tickLimit: Int) throws(ChronoConstellatorError)
        -> ChronoConstellatorLevel {
        let base: ChronoConstellatorLevel = fixture.level
        return try ChronoConstellatorLevel(id: base.id, seed: base.seed, difficulty: base.difficulty,
                                           columns: base.columns, rows: base.rows, stars: base.stars,
                                           budget: base.budget, tickLimit: tickLimit)
    }

    // MARK: - Stage machine

    @Test func stageTableOfHandle() throws {
        let withTutorial: ChronoConstellatorLevel = ChronoConstellatorFixtures.fixture(0).level
        let without: ChronoConstellatorLevel = ChronoConstellatorFixtures.fixture(1).level
        #expect(withTutorial.tutorial)
        #expect(!without.tutorial)

        // loading: only begin.
        var loading = Play(level: withTutorial)
        #expect(loading.stage == .loading)
        for event in Self.events where event != .begin {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(.step(1))) == .stage)
        #expect(Self.refusal(loading, .act(.rewind)) == .stage)
        #expect(Self.refusal(loading, .undo) == .stage)
        #expect(Self.refusal(loading, .redo) == .stage)
        try loading.handle(.begin)
        #expect(loading.stage == .tutorial)

        // tutorial: only dismissTutorial.
        for event in Self.events where event != .dismissTutorial {
            #expect(Self.refusal(loading, .event(event)) == .stage)
        }
        #expect(Self.refusal(loading, .act(.step(1))) == .stage)
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

        // paused: only resume; actions and rewind refused; undo and redo still judged (nothing to undo here).
        for event in Self.events where event != .resume {
            #expect(Self.refusal(direct, .event(event)) == .stage)
        }
        #expect(Self.refusal(direct, .act(.step(1))) == .stage)
        #expect(Self.refusal(direct, .act(.rewind)) == .stage)
        #expect(Self.refusal(direct, .undo) == .action("nothing-to-undo"))
        #expect(Self.refusal(direct, .redo) == .action("nothing-to-redo"))
        try direct.handle(.resume)
        #expect(direct.stage == .playing)
        #expect(direct.records.isEmpty)

        // won: only showResult; then result refuses everything.
        let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(1)
        var won: Play = try Self.playing(fixture.level)
        for action in Self.solution(fixture) { try Self.act(&won, action) }
        try Self.act(&won, .step(fixture.level.tickLimit))
        #expect(won.stage == .won)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(won, .event(event)) == .stage)
        }
        try won.handle(.showResult)
        #expect(won.stage == .result)
        for event in Self.events { #expect(Self.refusal(won, .event(event)) == .stage) }
        #expect(Self.refusal(won, .act(.step(1))) == .stage)
        #expect(Self.refusal(won, .act(.rewind)) == .stage)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)

        // failed: only showResult among events; then result.
        var failed: Play = try Self.playing(try Self.collisionLevel())
        try Self.act(&failed, .step(20))
        #expect(failed.stage == .failed)
        for event in Self.events where event != .showResult {
            #expect(Self.refusal(failed, .event(event)) == .stage)
        }
        #expect(Self.refusal(failed, .act(.step(1))) == .stage)
        #expect(Self.refusal(failed, .act(.phase(0, 1))) == .stage)
        #expect(Self.refusal(failed, .redo) == .stage)
        try failed.handle(.showResult)
        #expect(failed.stage == .result)
        #expect(Self.refusal(failed, .act(.rewind)) == .stage)
        #expect(Self.refusal(failed, .undo) == .stage)
    }

    // MARK: - Fixture solutions

    @Test func fixtureSolutionsWinAtTheirWinTick() throws {
        for index in 0..<200 {
            let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(index)
            var play: Play = try Self.playing(fixture.level)
            let actions: [ChronoConstellatorAction] = Self.solution(fixture)
            for action in actions { try Self.act(&play, action) }
            #expect(play.timeline == ChronoConstellatorFixtures.winningTimeline(fixture), "fixture \(index)")
            #expect(play.remaining >= 0)
            try Self.act(&play, .step(fixture.level.tickLimit))
            #expect(play.stage == .won, "fixture \(index)")
            #expect(play.tick == fixture.winTick, "fixture \(index)")
            #expect(play.failure == nil)
            #expect(play.records.count == actions.count + 1)
            let last: ChronoConstellatorRecord? = play.records.last
            #expect(last?.kind == .step)
            #expect(last?.tick == 0)
            #expect(last?.next == play.fingerprint)
            #expect(play.positions == fixture.level.stars.map(\.target), "fixture \(index)")

            // One tick short: still running, then the next tick wins.
            if fixture.winTick > 1 {
                var short: Play = try Self.playing(fixture.level)
                for action in actions { try Self.act(&short, action) }
                try Self.act(&short, .step(fixture.winTick - 1))
                #expect(short.stage == .playing, "fixture \(index)")
                #expect(short.tick == fixture.winTick - 1)
                try Self.act(&short, .step(1))
                #expect(short.stage == .won)
                #expect(short.tick == fixture.winTick)
            }
        }
    }

    // MARK: - Collision and time at the exact tick

    @Test func collisionAtTheExactTick() throws {
        let level: ChronoConstellatorLevel = try Self.collisionLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .step(8))
        #expect(play.stage == .playing)
        #expect(play.tick == 8)
        #expect(play.failure == nil)
        try Self.act(&play, .step(1))
        #expect(play.stage == .failed)
        #expect(play.tick == 9)
        #expect(play.failure == .collision(0, 1, 1))
        #expect(play.positions == [1, 1])

        // A long step stops at the collision.
        var long: Play = try Self.playing(level)
        try Self.act(&long, .step(50))
        #expect(long.tick == 9)
        #expect(long.failure == .collision(0, 1, 1))
        #expect(long.fingerprint == play.fingerprint)

        // Tick limit one below, at and one above the collision tick: time first below, collision before time at it.
        let below: ChronoConstellatorLevel = try Self.collisionLevel(tickLimit: 8)
        var early: Play = try Self.playing(below)
        try Self.act(&early, .step(7))
        #expect(early.stage == .playing)
        try Self.act(&early, .step(5))
        #expect(early.tick == 8)
        #expect(early.failure == .time)

        let at: ChronoConstellatorLevel = try Self.collisionLevel(tickLimit: 9)
        var exact: Play = try Self.playing(at)
        try Self.act(&exact, .step(9))
        #expect(exact.tick == 9)
        #expect(exact.failure == .collision(0, 1, 1))

        let above: ChronoConstellatorLevel = try Self.collisionLevel(tickLimit: 10)
        var later: Play = try Self.playing(above)
        try Self.act(&later, .step(10))
        #expect(later.tick == 9)
        #expect(later.failure == .collision(0, 1, 1))

        // A two-tick hold on star 1 from tick 1 moves the meeting: from tick 2 star 1 is on cell 7 when t ≡ 0
        // (mod 10) and on cell 1 when t ≡ 1 (mod 10); star 0 is on cell 7 when t ≡ 2 (mod 4) and on cell 1 when t ≡ 1
        // (mod 4), so they first meet at tick 10 on cell 7 (cell 1 not before tick 21), and they never win (star 1 on
        // 16 needs t even, star 0 on 6 needs t odd).
        var held: Play = try Self.playing(level)
        try Self.act(&held, .hold(1, 1, 2))
        try Self.act(&held, .step(9))
        #expect(held.stage == .playing)
        #expect(held.tick == 9)
        try Self.act(&held, .step(1))
        #expect(held.tick == 10)
        #expect(held.failure == .collision(0, 1, 7))
    }

    @Test func timeFailsAtTheExactTickAroundTheWinTick() throws {
        var checked: Int = 0
        for index in 0..<40 {
            let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(index)
            guard fixture.winTick > 1 else { continue }
            let actions: [ChronoConstellatorAction] = Self.solution(fixture)

            // One below the win tick: time fails at the limit, one tick before the stars would align.
            let below: ChronoConstellatorLevel = try Self.level(fixture, tickLimit: fixture.winTick - 1)
            var short: Play = try Self.playing(below)
            for action in actions { try Self.act(&short, action) }
            if fixture.winTick - 1 > 1 {
                try Self.act(&short, .step(fixture.winTick - 2))
                #expect(short.stage == .playing, "fixture \(index)")
            }
            try Self.act(&short, .step(Play.steps.upperBound))
            #expect(short.stage == .failed, "fixture \(index)")
            #expect(short.failure == .time)
            #expect(short.tick == fixture.winTick - 1)

            // At the win tick: the win is decided before time.
            let at: ChronoConstellatorLevel = try Self.level(fixture, tickLimit: fixture.winTick)
            var exact: Play = try Self.playing(at)
            for action in actions { try Self.act(&exact, action) }
            try Self.act(&exact, .step(Play.steps.upperBound))
            #expect(exact.stage == .won, "fixture \(index)")
            #expect(exact.tick == fixture.winTick)

            // One above: won at the win tick, the step stops there.
            let above: ChronoConstellatorLevel = try Self.level(fixture, tickLimit: fixture.winTick + 1)
            var long: Play = try Self.playing(above)
            for action in actions { try Self.act(&long, action) }
            try Self.act(&long, .step(Play.steps.upperBound))
            #expect(long.stage == .won, "fixture \(index)")
            #expect(long.tick == fixture.winTick)
            checked += 1
        }
        #expect(checked >= 20)

        // The default timeline of the collision-free fixture levels fails on time exactly at the limit.
        let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(3)
        let level: ChronoConstellatorLevel = try Self.level(fixture, tickLimit: 50)
        var play: Play = try Self.playing(level)
        var reached: Int = 0
        while play.stage == .playing && reached < 49 {
            try Self.act(&play, .step(1))
            reached += 1
        }
        if play.stage == .playing {
            #expect(play.tick == 49)
            try Self.act(&play, .step(1))
            #expect(play.tick == 50)
            #expect(play.failure == .time)
        }
    }

    // MARK: - Validation order and refusals

    @Test func validationOrderAndEveryRefusal() throws {
        let level: ChronoConstellatorLevel = try Self.collisionLevel(tickLimit: 100, budget: 2)
        let loading = Play(level: level)

        // stage before stale.
        #expect(Self.refusal(loading, .stale(.phase(0, 1))) == .stage)
        var play: Play = try Self.playing(level)

        // stale before range.
        #expect(Self.refusal(play, .stale(.phase(9, 99))) == .stale)
        #expect(Self.refusal(play, .stale(.step(1))) == .stale)

        // range: every operand.
        let outOfRange: [ChronoConstellatorAction] = [
            .phase(-1, 0), .phase(2, 0), .phase(0, 4), .phase(1, 10), .phase(0, -1),
            .hold(2, 1, 1), .hold(0, 0, 1), .hold(0, 1, 0), .hold(0, 1, 61), .hold(0, 100, 2), .hold(-1, 1, 1),
            .release(2, 1), .release(-1, 1),
            .step(0), .step(1_201), .step(-3),
        ]
        for action in outOfRange { #expect(Self.refusal(play, .act(action)) == .action("range"), "\(action)") }

        // same-phase, no-hold at tick 0.
        #expect(Self.refusal(play, .act(.phase(0, 0))) == .action("same-phase"))
        #expect(Self.refusal(play, .act(.phase(1, 1))) == .action("same-phase"))
        #expect(Self.refusal(play, .act(.release(0, 5))) == .action("no-hold"))

        // Fill the budget: a hold and a phase.
        try Self.act(&play, .hold(0, 5, 2))
        try Self.act(&play, .phase(0, 1))
        #expect(play.spent == 2)
        #expect(play.remaining == 0)

        // overlap (and touching) before budget; same-phase before budget; budget otherwise.
        for overlapping in [ChronoConstellatorAction.hold(0, 6, 1), .hold(0, 3, 2), .hold(0, 7, 3), .hold(0, 4, 1)] {
            #expect(Self.refusal(play, .act(overlapping)) == .action("overlap"), "\(overlapping)")
        }
        #expect(Self.refusal(play, .act(.phase(0, 1))) == .action("same-phase"))
        #expect(Self.refusal(play, .act(.release(1, 5))) == .action("no-hold"))
        #expect(Self.refusal(play, .act(.hold(0, 8, 1))) == .budget)
        #expect(Self.refusal(play, .act(.hold(1, 1, 1))) == .budget)
        #expect(Self.refusal(play, .act(.phase(1, 3))) == .budget)

        // A phase change on an already changed star costs nothing more; restoring the default lowers the edits.
        try Self.act(&play, .phase(0, 2))
        #expect(play.spent == 2)
        try Self.act(&play, .phase(0, 0))
        #expect(play.spent == 1)
        try Self.act(&play, .phase(1, 3))
        #expect(play.spent == 2)
        try Self.act(&play, .release(0, 5))
        #expect(play.spent == 1)
        try Self.act(&play, .hold(0, 5, 2))

        // After a step: range before not-at-start, not-at-start before same-phase, overlap, no-hold and budget.
        try Self.act(&play, .step(1))
        #expect(play.tick == 1)
        #expect(Self.refusal(play, .act(.phase(5, 0))) == .action("range"))
        #expect(Self.refusal(play, .act(.hold(0, 1, 61))) == .action("range"))
        #expect(Self.refusal(play, .act(.phase(1, 3))) == .action("not-at-start"))
        #expect(Self.refusal(play, .act(.phase(0, 1))) == .action("not-at-start"))
        #expect(Self.refusal(play, .act(.hold(0, 6, 1))) == .action("not-at-start"))
        #expect(Self.refusal(play, .act(.hold(1, 1, 1))) == .action("not-at-start"))
        #expect(Self.refusal(play, .act(.release(0, 5))) == .action("not-at-start"))
        #expect(Self.refusal(play, .act(.release(1, 9))) == .action("not-at-start"))
        #expect(Self.refusal(play, .stale(.phase(1, 3))) == .stale)

        // Undo and redo refusals.
        var fresh: Play = try Self.playing(level)
        #expect(Self.refusal(fresh, .undo) == .action("nothing-to-undo"))
        #expect(Self.refusal(fresh, .redo) == .action("nothing-to-redo"))
        try Self.act(&fresh, .step(1))
        #expect(Self.refusal(fresh, .redo) == .action("nothing-to-redo"))
    }

    // MARK: - Rewind and won

    @Test func rewindKeepsTheTimelineAndWonIsFinal() throws {
        let level: ChronoConstellatorLevel = try Self.collisionLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .hold(1, 3, 2))
        let start: String = play.fingerprint
        let timeline: ChronoConstellatorTimeline = play.timeline
        try Self.act(&play, .step(4))
        #expect(play.tick == 4)
        try Self.act(&play, .rewind)
        #expect(play.tick == 0)
        #expect(play.timeline == timeline)
        #expect(play.stage == .playing)
        #expect(play.fingerprint == start)
        #expect(play.spent == 1)
        // Rewind at tick 0 is accepted and changes nothing but the records.
        try Self.act(&play, .rewind)
        #expect(play.fingerprint == start)
        #expect(play.records.last?.kind == .rewind)

        // From failed: back to playing at tick 0, failure cleared, timeline kept.
        try Self.act(&play, .step(100))
        #expect(play.stage == .failed)
        #expect(play.failure != nil)
        try Self.act(&play, .rewind)
        #expect(play.stage == .playing)
        #expect(play.tick == 0)
        #expect(play.failure == nil)
        #expect(play.timeline == timeline)
        #expect(play.fingerprint == start)
        // Edits are allowed again after the rewind.
        try Self.act(&play, .release(1, 3))
        #expect(play.spent == 0)

        // Won is final: undo, redo, rewind and any action refused with .stage.
        let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(5)
        var won: Play = try Self.playing(fixture.level)
        for action in Self.solution(fixture) { try Self.act(&won, action) }
        try Self.act(&won, .step(fixture.level.tickLimit))
        #expect(won.stage == .won)
        #expect(!won.canUndo)
        #expect(!won.canRedo)
        #expect(Self.refusal(won, .undo) == .stage)
        #expect(Self.refusal(won, .redo) == .stage)
        #expect(Self.refusal(won, .act(.rewind)) == .stage)
        #expect(Self.refusal(won, .stale(.rewind)) == .stage)
        #expect(Self.refusal(won, .act(.step(1))) == .stage)
        #expect(Self.refusal(won, .act(.phase(0, 0))) == .stage)
    }

    // MARK: - Undo and redo

    @Test func undoAndRedoRestoreExactFingerprints() throws {
        let level: ChronoConstellatorLevel = try Self.collisionLevel(budget: 3)
        var play: Play = try Self.playing(level)
        let actions: [ChronoConstellatorAction] = [.phase(0, 2), .hold(1, 2, 3), .phase(1, 3), .release(1, 2),
                                                   .hold(0, 10, 1), .step(3), .rewind, .step(2)]
        var kinds = Set<ChronoConstellatorRecordKind>()
        for action in actions {
            let before: String = play.fingerprint
            let beforeTimeline: ChronoConstellatorTimeline = play.timeline
            let beforeTick: Int = play.tick
            try Self.act(&play, action)
            let after: String = play.fingerprint
            let afterTick: Int = play.tick
            #expect(play.canUndo)
            #expect(!play.canRedo)
            try play.undo()
            #expect(play.fingerprint == before, "\(action)")
            #expect(play.timeline == beforeTimeline)
            #expect(play.tick == beforeTick)
            #expect(play.records.last?.kind == .undo)
            #expect(play.records.last?.next == before)
            #expect(play.records.last?.previous == after)
            #expect(play.canRedo)
            try play.redo()
            #expect(play.fingerprint == after, "\(action)")
            #expect(play.tick == afterTick)
            #expect(play.records.last?.kind == .redo)
            if let kind = play.records.dropLast(2).last?.kind { kinds.insert(kind) }
        }
        #expect(kinds == [.phase, .hold, .release, .step, .rewind])

        // Undo all the way back to the start, then redo all the way forward.
        var fingerprints: [String] = []
        var walker: Play = try Self.playing(level)
        fingerprints.append(walker.fingerprint)
        for action in actions {
            try Self.act(&walker, action)
            fingerprints.append(walker.fingerprint)
        }
        for index in stride(from: actions.count - 1, through: 0, by: -1) {
            try walker.undo()
            #expect(walker.fingerprint == fingerprints[index])
        }
        #expect(Self.refusal(walker, .undo) == .action("nothing-to-undo"))
        for index in 1...actions.count {
            try walker.redo()
            #expect(walker.fingerprint == fingerprints[index])
        }
        #expect(Self.refusal(walker, .redo) == .action("nothing-to-redo"))

        // A new action clears redo.
        try walker.undo()
        try walker.undo()
        #expect(walker.canRedo)
        try Self.act(&walker, .step(1))
        #expect(!walker.canRedo)
        #expect(Self.refusal(walker, .redo) == .action("nothing-to-redo"))

        // Undo while paused restores the timeline and stays paused.
        var paused: Play = try Self.playing(level)
        try Self.act(&paused, .phase(0, 3))
        try paused.handle(.pause)
        try paused.undo()
        #expect(paused.stage == .paused)
        #expect(paused.timeline == ChronoConstellatorTimeline(level: level))
        try paused.redo()
        #expect(paused.stage == .paused)
        #expect(paused.timeline.phases == [3, 1])
        try paused.handle(.resume)

        // Undo from failed returns to playing with the exact fingerprint before the failing step; redo fails again.
        var failed: Play = try Self.playing(level)
        try Self.act(&failed, .step(4))
        let beforeFail: String = failed.fingerprint
        try Self.act(&failed, .step(10))
        #expect(failed.stage == .failed)
        let failedPrint: String = failed.fingerprint
        #expect(failed.canUndo)
        #expect(!failed.canRedo)
        try failed.undo()
        #expect(failed.stage == .playing)
        #expect(failed.tick == 4)
        #expect(failed.failure == nil)
        #expect(failed.fingerprint == beforeFail)
        try failed.redo()
        #expect(failed.stage == .failed)
        #expect(failed.fingerprint == failedPrint)
        // A rewind from failed is undone back to failed.
        try Self.act(&failed, .rewind)
        #expect(failed.stage == .playing)
        try failed.undo()
        #expect(failed.stage == .failed)
        #expect(failed.fingerprint == failedPrint)
    }

    // MARK: - Seeded traces and replay

    /// A seeded random action for `play`.
    static func randomAction(_ play: Play, random: inout ChronoConstellatorRandom) -> ChronoConstellatorAction {
        let level: ChronoConstellatorLevel = play.level
        let star: Int = random.int(0..<level.stars.count)
        switch random.int(0...5) {
        case 0:
            return .phase(star, random.int(0..<level.stars[star].length))
        case 1:
            let length: Int = random.int(1...min(60, level.tickLimit))
            return .hold(star, random.int(1...max(1, min(40, level.tickLimit - length + 1))), length)
        case 2:
            if !play.timeline.holds.isEmpty && random.bool() {
                let hold: ChronoConstellatorHold = play.timeline.holds[random.int(0..<play.timeline.holds.count)]
                return .release(hold.star, hold.start)
            }
            return .release(star, random.int(1...40))
        case 3, 4:
            return .step(random.int(1...min(60, level.tickLimit)))
        default:
            return .rewind
        }
    }

    @Test func seededTracesReplayIdentically() throws {
        var tampered: Int = 0
        var pausedEdits: Int = 0
        for seed in [ChronoConstellatorFixtures.seed, ChronoConstellatorFixtures.neighbourSeed] {
            var random = ChronoConstellatorRandom(seed: seed)
            for trace in 0..<250 {
                let level: ChronoConstellatorLevel = trace % 2 == 0
                    ? ChronoConstellatorFixtures.fixture(trace / 2).level
                    : ChronoConstellatorFixtures.randomLevel(trace / 2)
                var play: Play = try Self.playing(level)
                // Half the even traces start from the known solution, so wins occur too.
                if trace % 4 == 0 {
                    for action in Self.solution(ChronoConstellatorFixtures.fixture(trace / 2)) {
                        try Self.act(&play, action)
                    }
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

                var replayed: Play = try Play.replay(level: level, records: play.records)
                // Pauses and resumes are not recorded: the replay pauses only where a record was made paused, so a
                // pause or resume after the last record is not reproduced; compare both in playing then.
                if play.stage == .paused && replayed.stage == .playing { try play.handle(.resume) }
                if replayed.stage == .paused && play.stage == .playing { try replayed.handle(.resume) }
                #expect(replayed.records == play.records, "seed \(seed) trace \(trace)")
                #expect(replayed.fingerprint == play.fingerprint, "seed \(seed) trace \(trace)")
                #expect(replayed.stage == play.stage)
                #expect(replayed.tick == play.tick)
                #expect(replayed.failure == play.failure)
                #expect(replayed.timeline == play.timeline)
                #expect(replayed == play, "seed \(seed) trace \(trace)")

                // A tampered record is refused with .malformed("record i").
                if !play.records.isEmpty {
                    let index: Int = random.int(0..<play.records.count)
                    let record: ChronoConstellatorRecord = play.records[index]
                    var records: [ChronoConstellatorRecord] = play.records
                    let tamper: ChronoConstellatorRecord
                    switch trace % 3 {
                    case 0:
                        tamper = ChronoConstellatorRecord(schema: record.schema, seed: record.seed, tick: record.tick,
                                                          kind: record.kind, action: record.action,
                                                          previous: record.previous, next: "0000")
                    case 1:
                        tamper = ChronoConstellatorRecord(schema: record.schema, seed: record.seed &+ 1,
                                                          tick: record.tick, kind: record.kind, action: record.action,
                                                          previous: record.previous, next: record.next)
                    default:
                        tamper = ChronoConstellatorRecord(schema: record.schema, seed: record.seed,
                                                          tick: record.tick + 1, kind: record.kind,
                                                          action: record.action, previous: record.previous,
                                                          next: record.next)
                    }
                    records[index] = tamper
                    do {
                        _ = try Play.replay(level: level, records: records)
                        Issue.record("seed \(seed) trace \(trace): tampered record \(index) replayed")
                    } catch {
                        #expect(error == .malformed("record \(index)"), "seed \(seed) trace \(trace)")
                    }
                    tampered += 1
                }
            }
        }
        #expect(tampered >= 450)
        #expect(pausedEdits >= 20, "undo and redo while paused: \(pausedEdits)")

        // An action record without its action is malformed.
        let level: ChronoConstellatorLevel = try Self.collisionLevel()
        var play: Play = try Self.playing(level)
        try Self.act(&play, .step(2))
        let record: ChronoConstellatorRecord = play.records[0]
        let broken = ChronoConstellatorRecord(schema: record.schema, seed: record.seed, tick: record.tick,
                                              kind: .step, action: nil, previous: record.previous, next: record.next)
        do {
            _ = try Play.replay(level: level, records: [broken])
            Issue.record("a step record without its action replayed")
        } catch {
            #expect(error == .malformed("record 0"))
        }
    }
}
