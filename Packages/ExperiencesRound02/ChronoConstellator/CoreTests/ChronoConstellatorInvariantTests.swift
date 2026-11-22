// ChronoConstellatorInvariantTests — feature 351 (R02-G06-01) T-R02G0601-006 (FR-R02G0601-012; the source's invariants
// R2-G06-INV-01 … 05 and INV-07 … 10 on Chrono Constellator). Each named test gives a direct boundary example and a seeded
// check of neighbouring inputs (seed 2,356), as the source asks. How each invariant maps onto this kernel (INV-06 content
// and INV-12 novelty belong to R02-G06-02; INV-11 is superseded by the free tier):
// - INV-01 Time: a fixed tick of 1/120 s; the outcome depends on the tick count, not on how ticks are batched (step(n)
//   and n × step(1) reach the same fingerprint); an undecided play fails on time exactly at the tick limit, never before,
//   and a step never runs past the deciding tick.
// - INV-02 Input budget: the edits in use (changed phases plus holds) never exceed the budget; the edit that would is
//   refused with `budget` and changes nothing; re-phasing a changed star and releases do not add an edit; steps, rewinds,
//   undo and redo spend nothing.
// - INV-03 Goal: a win needs every star on its own target on one tick ≥ 1 (an aligned tick 0 is not a win); one star off
//   its target keeps the play from winning; a fixture's timeline wins exactly at its win tick and a neighbouring phase
//   does not.
// - INV-04 Repeatability: the same timeline gives the same positions, records, fingerprints and outcome on independent
//   runs, in any edit order and through replay; an edited record is refused.
// - INV-05 Undo: undo restores the exact prior moment (tick, timeline, positions, stage, failure, fingerprint); redo the
//   later one; a won play is final; a paused play stays paused.
// - INV-07 Failure honesty: a failure names its true reason — a collision names the lower-numbered pair and the shared
//   cell, time is named only at the tick limit — and undo or rewind returns a failed play to playing.
// - INV-08 Stability: level and play fingerprints are stable (pinned values, rebuilt levels, hold order); positions stay
//   on their loops and follow the closed form; ticks and edits stay within their ranges over seeded runs.
// - INV-09 Save: the stored level round-trips byte for byte; truncated and edited stored forms are refused; a stored
//   record trace up to a save point replays to the state at that point.
// - INV-10 Renderer purity: the kernel types are value types; the verdict, positions and fingerprint are functions of the
//   kernel state only (copying, decoding and reading descriptions change nothing); the kernel sources use no clock,
//   random source or UI framework.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorInvariantTests {
    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = ChronoConstellatorFixtures.neighbourSeed

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// A hand-made level on a 6 × 5 grid with two disjoint loops (no collision is possible): star 1 circles the 2 × 2
    /// square [0, 1, 7, 6] from phase 0 with target 7 (index 2); star 2 circles the 3 × 3 ring
    /// [9, 10, 11, 17, 23, 22, 21, 15] from phase `phaseB` with target 22 (index 5). With the default phases star 1 is on
    /// target when t ≡ 2 (mod 4) and star 2 when t ≡ 4 (mod 8), so the default timeline never wins.
    static func sample(phaseB: Int = 1, budget: Int = 3, tickLimit: Int = 100) throws -> ChronoConstellatorLevel {
        let a: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 2, height: 2, columns: 6)
        let b: [Int] = ChronoConstellatorFixtures.rectangle(column: 3, row: 1, width: 3, height: 3, columns: 6)
        let stars: [ChronoConstellatorStar] = [ChronoConstellatorStar(loop: a, phase: 0, target: a[2]),
                                               ChronoConstellatorStar(loop: b, phase: phaseB, target: b[5])]
        return try ChronoConstellatorLevel(id: "sample", seed: seed, difficulty: 1, columns: 6, rows: 5, stars: stars,
                                           budget: budget, tickLimit: tickLimit)
    }

    /// A level whose two 2 × 2 loops share cells 1 and 7: star 1 on [0, 1, 7, 6] from phase 0 (target 0), star 2 on
    /// [1, 2, 8, 7] from phase 2 (target 2). The default timeline never collides and never wins (fails on time); with
    /// star 2 at phase 3 both stand on cell 1 at tick 1.
    static func crossing(tickLimit: Int = 50) throws -> ChronoConstellatorLevel {
        let a: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 2, height: 2, columns: 6)
        let b: [Int] = ChronoConstellatorFixtures.rectangle(column: 1, row: 0, width: 2, height: 2, columns: 6)
        let stars: [ChronoConstellatorStar] = [ChronoConstellatorStar(loop: a, phase: 0, target: 0),
                                               ChronoConstellatorStar(loop: b, phase: 2, target: 2)]
        return try ChronoConstellatorLevel(id: "crossing", seed: seed, difficulty: 1, columns: 6, rows: 5, stars: stars,
                                           budget: 3, tickLimit: tickLimit)
    }

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: ChronoConstellatorLevel) throws -> ChronoConstellatorPlay {
        var play = ChronoConstellatorPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` whose timeline was set to `timeline` through phase and hold actions at tick 0.
    static func edited(_ level: ChronoConstellatorLevel, _ timeline: ChronoConstellatorTimeline,
                       reversed: Bool = false) throws -> ChronoConstellatorPlay {
        var play: ChronoConstellatorPlay = try playing(level)
        for star in level.stars.indices where play.timeline.phases[star] != timeline.phases[star] {
            try play.apply(.phase(star, timeline.phases[star]), expecting: play.fingerprint)
        }
        let holds: [ChronoConstellatorHold] = reversed ? Array(timeline.holds.reversed()) : timeline.holds
        for hold in holds {
            try play.apply(.hold(hold.star, hold.start, hold.length), expecting: play.fingerprint)
        }
        return play
    }

    /// The fixture's winning timeline set and played to the end.
    static func solved(_ fixture: ChronoConstellatorFixture) throws -> ChronoConstellatorPlay {
        var play: ChronoConstellatorPlay = try edited(fixture.level, ChronoConstellatorFixtures.winningTimeline(fixture))
        try play.apply(.step(ChronoConstellatorPlay.steps.upperBound), expecting: play.fingerprint)
        return play
    }

    /// Runs `ticks` ticks as single-tick steps, stopping when the play is decided.
    static func singleSteps(_ play: inout ChronoConstellatorPlay, _ ticks: Int) throws {
        var count: Int = 0
        while play.stage == .playing && count < ticks {
            try play.apply(.step(1), expecting: play.fingerprint)
            count += 1
        }
    }

    /// The first tick 1 … tick limit whose verdict decides `timeline` on `level`, with that verdict.
    static func firstDecision(_ level: ChronoConstellatorLevel,
                              _ timeline: ChronoConstellatorTimeline) -> (tick: Int, verdict: ChronoConstellatorVerdict) {
        for t in 1...level.tickLimit {
            let verdict: ChronoConstellatorVerdict = ChronoConstellatorEvaluation.verdict(
                positions: timeline.positions(at: t, level: level), tick: t, level: level)
            if verdict != .running { return (t, verdict) }
        }
        return (level.tickLimit, .running)
    }

    /// A seeded action for `play`: mostly in range, edits at any tick, steps of 1 … `maxTicks`, rewinds.
    static func randomAction(_ play: ChronoConstellatorPlay, maxTicks: Int,
                             random: inout ChronoConstellatorRandom) -> ChronoConstellatorAction {
        let level: ChronoConstellatorLevel = play.level
        let star: Int = random.int(0..<level.stars.count)
        let roll: Int = random.int(0...9)
        if roll <= 2 {
            return .phase(star, random.int(0..<level.stars[star].length))
        } else if roll <= 4 {
            let length: Int = random.int(1...min(60, level.tickLimit))
            return .hold(star, random.int(1...(level.tickLimit - length + 1)), length)
        } else if roll == 5 {
            for hold in play.timeline.holds where hold.star == star { return .release(hold.star, hold.start) }
            return .release(star, 1)
        } else if roll == 6 {
            return .rewind
        }
        return .step(random.int(1...maxTicks))
    }

    /// A seeded trace of edits, steps, rewinds, undos and redos, at most `actions` long; refused actions are skipped (and
    /// leave no record); a won play ends the trace.
    static func randomPlay(_ level: ChronoConstellatorLevel, actions: Int, maxTicks: Int,
                           random: inout ChronoConstellatorRandom) throws -> ChronoConstellatorPlay {
        var play: ChronoConstellatorPlay = try playing(level)
        for _ in 0..<actions {
            if play.stage == .won { break }
            let roll: Int = random.int(0...9)
            if roll == 0 && play.canUndo {
                try play.undo()
            } else if roll == 1 && play.canRedo {
                try play.redo()
            } else {
                let action: ChronoConstellatorAction = randomAction(play, maxTicks: maxTicks, random: &random)
                let held: ChronoConstellatorPlay = play
                let error: ChronoConstellatorError? = refusal { () throws(ChronoConstellatorError) in
                    try play.apply(action, expecting: play.fingerprint)
                }
                if error != nil && play != held { Issue.record("a refused \(action) changed the play") }
            }
        }
        return play
    }

    /// Whether two plays hold the same kernel state (fingerprint, tick, timeline, positions, stage, spent and failure).
    static func sameState(_ a: ChronoConstellatorPlay, _ b: ChronoConstellatorPlay) -> Bool {
        a.fingerprint == b.fingerprint && a.tick == b.tick && a.timeline == b.timeline && a.positions == b.positions
            && a.stage == b.stage && a.spent == b.spent && a.failure == b.failure
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(ChronoConstellatorError) -> Void) -> ChronoConstellatorError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    // MARK: INV-01 Time

    /// INV-01 Time: a fixed 1/120 s tick; batching does not change the outcome; time fails exactly at the tick limit.
    @Test func testChronoConstellatorTimeBoundary() throws {
        // Direct boundary: the tick is 1/120 s, so 120 ticks are one second.
        #expect(ChronoConstellatorLevel.tickSeconds == 1.0 / 120.0)
        #expect(abs(Double(120) * ChronoConstellatorLevel.tickSeconds - 1.0) < 1e-12)
        // step(n) and n × step(1) reach the same state (the default sample timeline never wins).
        let level: ChronoConstellatorLevel = try Self.sample(tickLimit: 40)
        var batched: ChronoConstellatorPlay = try Self.playing(level)
        try batched.apply(.step(17), expecting: batched.fingerprint)
        var single: ChronoConstellatorPlay = try Self.playing(level)
        try Self.singleSteps(&single, 17)
        #expect(Self.sameState(batched, single))
        #expect(batched.tick == 17 && batched.stage == .playing)
        // Tick limit − 1 is still running; the tick limit fails on time; a step never runs past the deciding tick.
        try batched.apply(.step(level.tickLimit - 1 - 17), expecting: batched.fingerprint)
        #expect(batched.tick == level.tickLimit - 1 && batched.stage == .playing && batched.failure == nil)
        #expect(ChronoConstellatorEvaluation.verdict(positions: batched.positions, tick: batched.tick, level: level)
                    == .running)
        try batched.apply(.step(1_200), expecting: batched.fingerprint)
        #expect(batched.tick == level.tickLimit && batched.stage == .failed && batched.failure == .time)
        try Self.singleSteps(&single, 1_200)
        #expect(Self.sameState(batched, single))
        // A tick limit of 1 fails on the first tick, not at tick 0.
        var shortest: ChronoConstellatorPlay = try Self.playing(try Self.sample(tickLimit: 1))
        #expect(shortest.tick == 0 && shortest.stage == .playing)
        try shortest.apply(.step(5), expecting: shortest.fingerprint)
        #expect(shortest.tick == 1 && shortest.failure == .time)
        // Seeded neighbours: fixtures win at their win tick whether stepped at once or tick by tick; random levels with
        // seeded timelines stop exactly at their first deciding tick (time only at the limit), and one step agrees
        // with seeded batches of any size.
        var random = ChronoConstellatorRandom(seed: Self.seed)
        for index in 0..<30 {
            let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(random.int(0...9_999))
            let straight: ChronoConstellatorPlay = try Self.solved(fixture)
            var ticked: ChronoConstellatorPlay = try Self.edited(fixture.level,
                                                                 ChronoConstellatorFixtures.winningTimeline(fixture))
            try Self.singleSteps(&ticked, 1_200)
            #expect(straight.stage == .won && straight.tick == fixture.winTick && Self.sameState(straight, ticked))
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(index)
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(other, random: &random)
            var one: ChronoConstellatorPlay = try Self.edited(other, timeline)
            var many: ChronoConstellatorPlay = try Self.edited(other, timeline)
            try one.apply(.step(1_200), expecting: one.fingerprint)
            let decision: (tick: Int, verdict: ChronoConstellatorVerdict) = Self.firstDecision(other, timeline)
            #expect(one.tick == decision.tick && one.tick <= other.tickLimit && one.stage != .playing)
            if one.failure == .time { #expect(one.tick == other.tickLimit) }
            while many.stage == .playing {
                try many.apply(.step(random.int(1...37)), expecting: many.fingerprint)
            }
            #expect(Self.sameState(one, many))
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: the edits in use never exceed the budget; the edit that would is refused with `budget` and
    /// changes nothing; steps, rewinds, undo and redo are free.
    @Test func testChronoConstellatorInputbudgetBoundary() throws {
        // Direct boundary: budget 2 — a phase and a hold use it exactly; a further phase or hold is refused.
        let level: ChronoConstellatorLevel = try Self.sample(budget: 2)
        var play: ChronoConstellatorPlay = try Self.playing(level)
        try play.apply(.phase(0, 1), expecting: play.fingerprint)
        #expect(play.spent == 1 && play.remaining == 1)
        try play.apply(.hold(1, 5, 3), expecting: play.fingerprint)
        #expect(play.spent == 2 && play.spent == level.budget && play.remaining == 0)
        let full: ChronoConstellatorPlay = play
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try play.apply(.phase(1, 2), expecting: play.fingerprint) } == .budget)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try play.apply(.hold(0, 10, 2), expecting: play.fingerprint) } == .budget)
        // Earlier checks win over the budget: a stale fingerprint, a range and an overlap are named first.
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try play.apply(.phase(1, 2), expecting: Self.staleFingerprint) } == .stale)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try play.apply(.hold(0, 0, 2), expecting: play.fingerprint) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try play.apply(.hold(1, 8, 2), expecting: play.fingerprint) } == .action("overlap"))
        #expect(play == full)
        // Re-phasing a changed star keeps the edits in use; a phase back to the default frees one; a release frees one.
        try play.apply(.phase(0, 3), expecting: play.fingerprint)
        #expect(play.spent == 2)
        try play.apply(.phase(0, 0), expecting: play.fingerprint)
        #expect(play.spent == 1)
        try play.apply(.hold(0, 10, 2), expecting: play.fingerprint)
        #expect(play.spent == 2)
        try play.apply(.release(1, 5), expecting: play.fingerprint)
        #expect(play.spent == 1)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try play.apply(.release(1, 5), expecting: play.fingerprint) } == .action("no-hold"))
        // Steps, rewinds, undo and redo spend nothing; edits after tick 0 are refused.
        try play.apply(.step(3), expecting: play.fingerprint)
        #expect(play.spent == 1)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try play.apply(.phase(1, 2), expecting: play.fingerprint) } == .action("not-at-start"))
        try play.apply(.rewind, expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        #expect(play.spent == 1 && play.tick == 0)
        // Seeded neighbours: random levels and seeded actions — a refused action leaves the play equal, `budget` is
        // named only when every edit is in use, and the edits in use never exceed the budget.
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 2)
        for index in 0..<40 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(100 + index)
            var p: ChronoConstellatorPlay = try Self.playing(other)
            for _ in 0..<60 {
                if p.stage == .won { break }
                let held: ChronoConstellatorPlay = p
                var action: ChronoConstellatorAction = Self.randomAction(p, maxTicks: 8, random: &random)
                if random.int(0...4) == 0 { action = .phase(random.int(-1...other.stars.count), random.int(-1...33)) }
                if p.tick > 0 && random.int(0...2) == 0 { action = .rewind }
                let stale: Bool = random.int(0...7) == 0
                let previous: String = stale ? Self.staleFingerprint : p.fingerprint
                let error: ChronoConstellatorError? = Self.refusal { () throws(ChronoConstellatorError) in
                    try p.apply(action, expecting: previous)
                }
                if let error {
                    #expect(p == held)
                    if stale && (held.stage == .playing || action == .rewind) { #expect(error == .stale) }
                    if error == .budget { #expect(held.remaining == 0) }
                } else {
                    #expect(!stale)
                    switch action {
                    case .step, .rewind: #expect(p.spent == held.spent && p.timeline == held.timeline)
                    default: #expect(abs(p.spent - held.spent) <= 1 && p.tick == 0)
                    }
                }
                #expect(p.spent >= 0 && p.spent <= other.budget)
                #expect(p.spent == p.timeline.editsInUse(level: other))
            }
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: a win needs every star on its own target on one tick ≥ 1.
    @Test func testChronoConstellatorGoalBoundary() throws {
        // Direct boundary on the verdict: targets 7 and 22 at tick 1 win; at tick 0 they do not; one star off or the
        // targets swapped do not.
        let level: ChronoConstellatorLevel = try Self.sample()
        #expect(ChronoConstellatorEvaluation.verdict(positions: [7, 22], tick: 1, level: level) == .won)
        #expect(ChronoConstellatorEvaluation.verdict(positions: [7, 22], tick: 0, level: level) == .running)
        #expect(ChronoConstellatorEvaluation.verdict(positions: [7, 21], tick: 1, level: level) == .running)
        #expect(ChronoConstellatorEvaluation.verdict(positions: [6, 22], tick: 1, level: level) == .running)
        #expect(ChronoConstellatorEvaluation.verdict(positions: [22, 7], tick: 1, level: level) == .running)
        // A win on the limit tick is a win, not a time failure.
        #expect(ChronoConstellatorEvaluation.verdict(positions: [7, 22], tick: level.tickLimit, level: level) == .won)
        // Direct boundary on play: phase(0, 2) aligns both stars first at tick 4.
        var won: ChronoConstellatorPlay = try Self.playing(level)
        try won.apply(.phase(0, 2), expecting: won.fingerprint)
        try won.apply(.step(3), expecting: won.fingerprint)
        #expect(won.stage == .playing && won.tick == 3 && won.positions != [7, 22])
        try won.apply(.step(1_200), expecting: won.fingerprint)
        #expect(won.stage == .won && won.tick == 4 && won.failure == nil && won.positions == [7, 22])
        // Aligned at tick 0 (phases 2 and 5) is not a win: the play leaves the targets and wins first at tick 8.
        var aligned: ChronoConstellatorPlay = try Self.playing(level)
        try aligned.apply(.phase(0, 2), expecting: aligned.fingerprint)
        try aligned.apply(.phase(1, 5), expecting: aligned.fingerprint)
        #expect(aligned.positions == [7, 22] && aligned.stage == .playing)
        try aligned.apply(.step(7), expecting: aligned.fingerprint)
        #expect(aligned.stage == .playing && aligned.tick == 7)
        try aligned.apply(.step(1), expecting: aligned.fingerprint)
        #expect(aligned.stage == .won && aligned.tick == 8)
        // A hold alone can align them: star 1 held on ticks 1 … 2 reaches its target with star 2 at tick 4.
        var holding: ChronoConstellatorPlay = try Self.playing(level)
        try holding.apply(.hold(0, 1, 2), expecting: holding.fingerprint)
        try holding.apply(.step(1_200), expecting: holding.fingerprint)
        #expect(holding.stage == .won && holding.tick == 4)
        // The default timeline (one star on target at a time) never wins.
        var idle: ChronoConstellatorPlay = try Self.playing(level)
        try idle.apply(.step(1_200), expecting: idle.fingerprint)
        #expect(idle.stage == .failed && idle.failure == .time)
        // Seeded neighbours: a fixture's timeline is aligned first at its win tick; moving one seeded star's phase by
        // ±1 keeps it from winning at that tick; a won random play has every star on its own target at a tick ≥ 1.
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 3)
        for _ in 0..<60 {
            let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(random.int(0...9_999))
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.winningTimeline(fixture)
            let decision: (tick: Int, verdict: ChronoConstellatorVerdict) = Self.firstDecision(fixture.level, timeline)
            #expect(decision.tick == fixture.winTick && decision.verdict == .won)
            let star: Int = random.int(0..<fixture.level.stars.count)
            let length: Int = fixture.level.stars[star].length
            let shift: Int = random.bool() ? 1 : length - 1
            let moved: ChronoConstellatorTimeline = try timeline.settingPhase(
                star: star, to: (timeline.phases[star] + shift) % length, level: fixture.level)
            let positions: [Int] = moved.positions(at: fixture.winTick, level: fixture.level)
            #expect(positions[star] != fixture.level.stars[star].target)
            #expect(ChronoConstellatorEvaluation.verdict(positions: positions, tick: fixture.winTick,
                                                         level: fixture.level) != .won)
        }
        for index in 0..<40 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(200 + index)
            let p: ChronoConstellatorPlay = try Self.randomPlay(other, actions: 30, maxTicks: 40, random: &random)
            var allMet: Bool = true
            for star in other.stars.indices where p.positions[star] != other.stars[star].target { allMet = false }
            if p.stage == .won {
                #expect(allMet && p.tick >= 1)
            } else if p.stage == .playing && p.tick >= 1 {
                #expect(!allMet)
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same timeline gives the same positions, records, fingerprints and outcome.
    @Test func testChronoConstellatorRepeatabilityBoundary() throws {
        // Direct example: a fixture's winning timeline played twice and replayed.
        let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(7)
        let first: ChronoConstellatorPlay = try Self.solved(fixture)
        let second: ChronoConstellatorPlay = try Self.solved(ChronoConstellatorFixtures.fixture(7))
        #expect(first == second && first.records == second.records && first.stage == .won)
        let replayed: ChronoConstellatorPlay = try ChronoConstellatorPlay.replay(level: fixture.level,
                                                                                 records: first.records)
        #expect(replayed == first)
        // An edited record is refused.
        var edited: [ChronoConstellatorRecord] = first.records
        let last: ChronoConstellatorRecord = edited[edited.count - 1]
        edited[edited.count - 1] = ChronoConstellatorRecord(schema: last.schema, seed: last.seed, tick: last.tick,
                                                            kind: last.kind, action: last.action,
                                                            previous: last.previous, next: Self.staleFingerprint)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            _ = try ChronoConstellatorPlay.replay(level: fixture.level, records: edited) }
                == .malformed("record \(edited.count - 1)"))
        // Seeded neighbours: two independent runs of the same seeded trace agree and replay; the same seeded timeline
        // reached with its holds in another order gives the same positions on every tick and the same outcome.
        for index in 0..<40 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(300 + index)
            var randomA = ChronoConstellatorRandom(seed: Self.seed &+ UInt64(index))
            var randomB = ChronoConstellatorRandom(seed: Self.seed &+ UInt64(index))
            let a: ChronoConstellatorPlay = try Self.randomPlay(other, actions: 40, maxTicks: 30, random: &randomA)
            let b: ChronoConstellatorPlay = try Self.randomPlay(ChronoConstellatorFixtures.randomLevel(300 + index),
                                                                actions: 40, maxTicks: 30, random: &randomB)
            #expect(a == b && a.fingerprint == b.fingerprint && a.positions == b.positions)
            for i in 0..<a.records.count {
                #expect(a.records[i].next == b.records[i].next)
                #expect(i == 0 || a.records[i].previous == a.records[i - 1].next)
            }
            let again: ChronoConstellatorPlay = try ChronoConstellatorPlay.replay(level: other, records: a.records)
            #expect(Self.sameState(again, a) && again.records == a.records)
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(other, random: &randomA)
            var forward: ChronoConstellatorPlay = try Self.edited(other, timeline)
            var backward: ChronoConstellatorPlay = try Self.edited(other, timeline, reversed: true)
            #expect(forward.timeline == backward.timeline && forward.fingerprint == backward.fingerprint)
            var tickRandom = ChronoConstellatorRandom(seed: Self.seed &+ 1_000 &+ UInt64(index))
            let ticks: Int = tickRandom.int(1...min(200, other.tickLimit))
            for _ in 0..<ticks where forward.stage == .playing {
                try forward.apply(.step(1), expecting: forward.fingerprint)
                try backward.apply(.step(1), expecting: backward.fingerprint)
                #expect(forward.positions == backward.positions)
            }
            #expect(Self.sameState(forward, backward))
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo restores the exact prior moment including the failure; redo the later one; won is final.
    @Test func testChronoConstellatorUndoBoundary() throws {
        // Direct boundary: an edit undone and redone; a failure undone back to playing and redone.
        let level: ChronoConstellatorLevel = try Self.sample(tickLimit: 30)
        var play: ChronoConstellatorPlay = try Self.playing(level)
        let fresh: ChronoConstellatorPlay = play
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try play.undo() } == .action("nothing-to-undo"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try play.redo() } == .action("nothing-to-redo"))
        try play.apply(.hold(1, 3, 4), expecting: play.fingerprint)
        let holding: ChronoConstellatorPlay = play
        try play.undo()
        #expect(Self.sameState(play, fresh) && play.timeline.holds.isEmpty && play.spent == 0)
        try play.redo()
        #expect(Self.sameState(play, holding) && play.spent == 1)
        try play.apply(.step(5), expecting: play.fingerprint)
        let running: ChronoConstellatorPlay = play
        try play.apply(.step(1_200), expecting: play.fingerprint)
        #expect(play.stage == .failed && play.failure == .time && play.tick == 30)
        let failed: ChronoConstellatorPlay = play
        try play.undo()
        #expect(Self.sameState(play, running) && play.stage == .playing && play.failure == nil && play.tick == 5)
        try play.redo()
        #expect(Self.sameState(play, failed))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try play.redo() } == .stage)
        // A rewind from failed is undone back to the exact failure.
        try play.apply(.rewind, expecting: play.fingerprint)
        #expect(play.stage == .playing && play.tick == 0 && play.timeline == failed.timeline)
        try play.undo()
        #expect(Self.sameState(play, failed))
        // Undo while paused restores the moment and stays paused.
        var paused: ChronoConstellatorPlay = try Self.playing(level)
        try paused.apply(.phase(0, 2), expecting: paused.fingerprint)
        try paused.handle(.pause)
        try paused.undo()
        #expect(paused.stage == .paused && paused.timeline == fresh.timeline && paused.positions == fresh.positions)
        try paused.redo()
        #expect(paused.stage == .paused && paused.timeline.phases == [2, 1])
        // A won play is final.
        var won: ChronoConstellatorPlay = try Self.playing(level)
        try won.apply(.phase(0, 2), expecting: won.fingerprint)
        try won.apply(.step(1_200), expecting: won.fingerprint)
        #expect(won.stage == .won)
        let final: ChronoConstellatorPlay = won
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try won.undo() } == .stage)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try won.redo() } == .stage)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try won.apply(.rewind, expecting: won.fingerprint) } == .stage)
        #expect(won == final)
        // Seeded neighbours: a shadow history of whole states matches every undo and redo of seeded traces.
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 5)
        for index in 0..<40 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(400 + index)
            var p: ChronoConstellatorPlay = try Self.playing(other)
            var history: [ChronoConstellatorPlay] = []
            var future: [ChronoConstellatorPlay] = []
            for _ in 0..<50 {
                if p.stage == .won { break }
                let roll: Int = random.int(0...5)
                let before: ChronoConstellatorPlay = p
                if p.stage == .failed || (roll <= 1 && p.canUndo) {
                    guard p.canUndo else { break }
                    try p.undo()
                    #expect(Self.sameState(p, history.removeLast()))
                    future.append(before)
                } else if roll == 2 && p.canRedo {
                    try p.redo()
                    #expect(Self.sameState(p, future.removeLast()))
                    history.append(before)
                } else {
                    let action: ChronoConstellatorAction = Self.randomAction(p, maxTicks: 60, random: &random)
                    let error: ChronoConstellatorError? = Self.refusal { () throws(ChronoConstellatorError) in
                        try p.apply(action, expecting: before.fingerprint)
                    }
                    if error == nil {
                        history.append(before)
                        future.removeAll()
                    } else {
                        #expect(p == before)
                    }
                }
                #expect(p.canUndo == !history.isEmpty || p.stage == .won)
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: a failure names its true reason, stars and cell; undo or rewind returns to playing.
    @Test func testChronoConstellatorFailurehonestyBoundary() throws {
        // Collision: star 2 at phase 3 meets star 1 on cell 1 at tick 1.
        let level: ChronoConstellatorLevel = try Self.crossing()
        var crash: ChronoConstellatorPlay = try Self.playing(level)
        try crash.apply(.phase(1, 3), expecting: crash.fingerprint)
        #expect(crash.positions == [0, 7])
        try crash.apply(.step(1_200), expecting: crash.fingerprint)
        #expect(crash.stage == .failed && crash.tick == 1 && crash.failure == .collision(0, 1, 1))
        #expect(crash.positions == [1, 1] && crash.failure?.code == "collision")
        // Undo returns to playing at the moment before the step; rewind returns to tick 0 with the timeline kept.
        var undone: ChronoConstellatorPlay = crash
        try undone.undo()
        #expect(undone.stage == .playing && undone.failure == nil && undone.tick == 0 && undone.timeline.phases == [0, 3])
        var rewound: ChronoConstellatorPlay = crash
        try rewound.apply(.rewind, expecting: rewound.fingerprint)
        #expect(rewound.stage == .playing && rewound.failure == nil && rewound.tick == 0)
        #expect(rewound.timeline == crash.timeline && rewound.spent == crash.spent)
        // The default timeline crosses the shared cells without meeting and fails on time at the limit.
        var idle: ChronoConstellatorPlay = try Self.playing(level)
        try idle.apply(.step(1_200), expecting: idle.fingerprint)
        #expect(idle.stage == .failed && idle.failure == .time && idle.tick == level.tickLimit)
        #expect(idle.failure?.code == "time")
        // A hold that keeps star 1 on cell 1 at tick 2 makes star 2 (phase 2) meet it there.
        var held: ChronoConstellatorPlay = try Self.playing(level)
        try held.apply(.hold(0, 2, 1), expecting: held.fingerprint)
        try held.apply(.step(1_200), expecting: held.fingerprint)
        #expect(held.failure == .collision(0, 1, 1) && held.tick == 2 && held.positions == [1, 1])
        // The lower-numbered pair is named, collision is judged before win and time.
        let five: ChronoConstellatorLevel = ChronoConstellatorFixtures.fixture(1).level
        let n: Int = five.stars.count
        var stacked: [Int] = [Int](repeating: 5, count: n)
        #expect(ChronoConstellatorEvaluation.verdict(positions: stacked, tick: 1, level: five)
                    == .failed(.collision(0, 1, 5)))
        stacked[0] = 4
        if n >= 3 {
            #expect(ChronoConstellatorEvaluation.verdict(positions: stacked, tick: 1, level: five)
                        == .failed(.collision(1, 2, 5)))
        }
        #expect(ChronoConstellatorEvaluation.verdict(positions: [3, 3], tick: level.tickLimit, level: level)
                    == .failed(.collision(0, 1, 3)))
        #expect(ChronoConstellatorEvaluation.verdict(positions: [6, 8], tick: level.tickLimit, level: level)
                    == .failed(.time))
        #expect(ChronoConstellatorEvaluation.verdict(positions: [6, 8], tick: level.tickLimit - 1, level: level)
                    == .running)
        // Seeded neighbours: in seeded traces a failure is the verdict of its own tick and positions (the shared cell of
        // the named pair, or the limit for time), no earlier tick decided the play, and undo and rewind return to
        // playing.
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 7)
        var failures: Int = 0
        for index in 0..<60 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(500 + index)
            let p: ChronoConstellatorPlay = try Self.randomPlay(other, actions: 40, maxTicks: 120, random: &random)
            let verdict: ChronoConstellatorVerdict = ChronoConstellatorEvaluation.verdict(positions: p.positions,
                                                                                         tick: p.tick, level: other)
            switch p.stage {
            case .failed:
                failures += 1
                guard let failure = p.failure else {
                    Issue.record("a failed play without a reason")
                    continue
                }
                #expect(verdict == .failed(failure))
                if case .collision(let a, let b, let cell) = failure {
                    #expect(a < b && p.positions[a] == cell && p.positions[b] == cell)
                } else {
                    #expect(p.tick == other.tickLimit)
                }
                let decision: (tick: Int, verdict: ChronoConstellatorVerdict) = Self.firstDecision(other, p.timeline)
                #expect(decision.tick == p.tick && decision.verdict == verdict)
                var u: ChronoConstellatorPlay = p
                if u.canUndo {
                    try u.undo()
                    #expect(u.stage == .playing && u.failure == nil)
                }
                var r: ChronoConstellatorPlay = p
                try r.apply(.rewind, expecting: r.fingerprint)
                #expect(r.stage == .playing && r.failure == nil && r.tick == 0 && r.timeline == p.timeline)
            case .won:
                #expect(p.failure == nil && verdict == .won)
            default:
                #expect(p.failure == nil)
                if p.tick >= 1 { #expect(verdict == .running) }
            }
        }
        #expect(failures > 0)
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: fingerprints and stored levels are stable; positions stay on their loops; values stay in range.
    @Test func testChronoConstellatorStabilityBoundary() throws {
        // Direct boundary: pinned fingerprints of the sample level, its stored form and a fresh play of it.
        let level: ChronoConstellatorLevel = try Self.sample()
        #expect(level.fingerprint == "9f10d16ed5ee92ae78caaedf4979dc45bddd6999a334050a4583b08cde6c800a")
        let fresh: ChronoConstellatorPlay = try Self.playing(level)
        #expect(fresh.fingerprint == "ea4dd217cdd67e9c53295406a19495b207024f9722ee5536ea745eb3e53e0980")
        let rebuilt: ChronoConstellatorLevel = try Self.sample()
        #expect(level.fingerprint.count == 64 && level.fingerprint == rebuilt.fingerprint)
        #expect(level.encoded() == rebuilt.encoded())
        let text: String = String(decoding: level.encoded(), as: UTF8.self)
        #expect(text.hasPrefix("{\"budget\":3,\"columns\":6,\"difficulty\":1,\"fingerprint\":\"\(level.fingerprint)\""))
        // A changed value changes the fingerprint.
        let wider: ChronoConstellatorLevel = try Self.sample(budget: 4)
        let shifted: ChronoConstellatorLevel = try Self.sample(phaseB: 2)
        #expect(level.fingerprint != wider.fingerprint && level.fingerprint != shifted.fingerprint)
        // Holds added in either order give one timeline and fingerprint; positions are periodic in the loop length.
        let a: ChronoConstellatorTimeline = try ChronoConstellatorTimeline(level: level)
            .adding(ChronoConstellatorHold(star: 1, start: 20, length: 3), level: level)
            .adding(ChronoConstellatorHold(star: 0, start: 2, length: 5), level: level)
        let b: ChronoConstellatorTimeline = try ChronoConstellatorTimeline(level: level)
            .adding(ChronoConstellatorHold(star: 0, start: 2, length: 5), level: level)
            .adding(ChronoConstellatorHold(star: 1, start: 20, length: 3), level: level)
        #expect(a == b && a.fingerprint == b.fingerprint)
        #expect(a.position(star: 0, at: 6, level: level) == a.position(star: 0, at: 1, level: level))
        #expect(a.position(star: 0, at: 30, level: level) == a.position(star: 0, at: 34, level: level))
        // Seeded neighbours: over seeded runs every position lies on its star's loop and matches a tick-by-tick walk
        // (one cell per unheld tick), ticks stay within 0 … limit, edits within the budget, and fingerprints of
        // rebuilt (decoded) levels and replays are unchanged.
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 8)
        for index in 0..<40 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(600 + index)
            let p: ChronoConstellatorPlay = try Self.randomPlay(other, actions: 80, maxTicks: 60, random: &random)
            #expect(p.tick >= 0 && p.tick <= other.tickLimit)
            #expect(p.spent >= 0 && p.spent <= other.budget)
            let reread: ChronoConstellatorLevel = try ChronoConstellatorLevel.decode(other.encoded())
            #expect(reread.fingerprint == other.fingerprint)
            for star in other.stars.indices {
                let loop: [Int] = other.stars[star].loop
                var walk: Int = p.timeline.phases[star]
                let limit: Int = min(other.tickLimit, 150)
                for t in 0...limit {
                    if t >= 1 && !p.timeline.isHeld(star: star, on: t) { walk = (walk + 1) % loop.count }
                    let cell: Int = p.timeline.position(star: star, at: t, level: other)
                    #expect(cell == loop[walk])
                    if cell != loop[walk] { break }
                }
                #expect(loop.contains(p.positions[star]))
            }
            for hold in p.timeline.holds {
                #expect(hold.start >= 1 && hold.end <= other.tickLimit
                            && ChronoConstellatorTimeline.holdLengths.contains(hold.length))
            }
            if !p.records.isEmpty {
                let again: ChronoConstellatorPlay = try ChronoConstellatorPlay.replay(level: other, records: p.records)
                #expect(again.fingerprint == p.fingerprint)
            }
        }
    }

    // MARK: INV-09 Save

    /// INV-09 Save: the stored level round-trips; truncated or edited forms are refused; a saved trace replays.
    @Test func testChronoConstellatorSaveBoundary() throws {
        // Direct boundary: the stored form round-trips byte for byte; one byte less is refused; an edited value is
        // refused by its fingerprint; a newer schema is refused by name.
        let level: ChronoConstellatorLevel = try Self.sample()
        let stored: Data = level.encoded()
        let decoded: ChronoConstellatorLevel = try ChronoConstellatorLevel.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let truncated = Data(stored.prefix(stored.count - 1))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            _ = try ChronoConstellatorLevel.decode(truncated) } == .malformed("unreadable"))
        let text: String = String(decoding: stored, as: UTF8.self)
        let budgetEdit = Data(text.replacingOccurrences(of: "\"budget\":3", with: "\"budget\":2").utf8)
        #expect(budgetEdit != stored)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            _ = try ChronoConstellatorLevel.decode(budgetEdit) } == .malformed("fingerprint"))
        let newer = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            _ = try ChronoConstellatorLevel.decode(newer) } == .newerSchema(2))
        // Codable path agrees.
        let viaCodable: ChronoConstellatorLevel = try JSONDecoder().decode(ChronoConstellatorLevel.self,
                                                                           from: try JSONEncoder().encode(level))
        #expect(viaCodable == level)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ChronoConstellatorLevel.self, from: budgetEdit)
        }
        // A saved trace of a won fixture replays to the same win.
        let fixture: ChronoConstellatorFixture = ChronoConstellatorFixtures.fixture(3)
        let solved: ChronoConstellatorPlay = try Self.solved(fixture)
        let savedTrace: Data = try JSONEncoder().encode(solved.records)
        let reloaded: [ChronoConstellatorRecord] = try JSONDecoder().decode([ChronoConstellatorRecord].self,
                                                                            from: savedTrace)
        let resumed: ChronoConstellatorPlay = try ChronoConstellatorPlay.replay(
            level: try ChronoConstellatorLevel.decode(fixture.level.encoded()), records: reloaded)
        #expect(resumed == solved && resumed.stage == .won)
        // Seeded neighbours: random levels round-trip; seeded truncations and single-byte edits are refused; a stored
        // trace cut at a seeded save point replays to the state recorded there.
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 9)
        for index in 0..<30 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(700 + index)
            let bytes: Data = other.encoded()
            let reread: ChronoConstellatorLevel = try ChronoConstellatorLevel.decode(bytes)
            #expect(reread == other)
            for _ in 0..<10 {
                let cut: Int = random.int(0...(bytes.count - 1))
                let prefix = Data(bytes.prefix(cut))
                #expect(Self.refusal { () throws(ChronoConstellatorError) in
                    _ = try ChronoConstellatorLevel.decode(prefix) } != nil)
                var edit: [UInt8] = Array(bytes)
                let at: Int = random.int(0...(edit.count - 1))
                var replacement: UInt8 = UInt8(random.int(33...126))
                if replacement == edit[at] { replacement = replacement == 126 ? 33 : replacement + 1 }
                edit[at] = replacement
                let editedData = Data(edit)
                let outcome: ChronoConstellatorError? = Self.refusal { () throws(ChronoConstellatorError) in
                    _ = try ChronoConstellatorLevel.decode(editedData)
                }
                #expect(outcome != nil, "edit at \(at) of level \(index) was accepted")
            }
            let p: ChronoConstellatorPlay = try Self.randomPlay(other, actions: 30, maxTicks: 30, random: &random)
            guard !p.records.isEmpty else { continue }
            let save: Int = random.int(1...p.records.count)
            let trace: [ChronoConstellatorRecord] = Array(p.records.prefix(save))
            let storedTrace: Data = try JSONEncoder().encode(trace)
            let loaded: [ChronoConstellatorRecord] = try JSONDecoder().decode([ChronoConstellatorRecord].self,
                                                                              from: storedTrace)
            #expect(loaded == trace)
            let restored: ChronoConstellatorPlay = try ChronoConstellatorPlay.replay(
                level: try ChronoConstellatorLevel.decode(bytes), records: loaded)
            #expect(restored.fingerprint == trace[save - 1].next)
            if save == p.records.count { #expect(Self.sameState(restored, p)) }
            // A partial (truncated) stored trace is refused.
            let partial = Data(storedTrace.prefix(storedTrace.count - 1))
            #expect(throws: (any Error).self) {
                _ = try JSONDecoder().decode([ChronoConstellatorRecord].self, from: partial)
            }
        }
    }

    // MARK: INV-10 Renderer purity

    /// The kernel source files (the Core folder beside this test folder).
    static func kernelSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: core.path).sorted()
        var sources: [(name: String, text: String)] = []
        for name in names where name.hasSuffix(".swift") {
            let text: String = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            sources.append((name, text))
        }
        return sources
    }

    /// INV-10 Renderer purity: the kernel is value types with no clock, random or UI dependency; the verdict, positions
    /// and fingerprint depend on the kernel state only.
    @Test func testChronoConstellatorRendererpurityBoundary() throws {
        // Direct example: the kernel types are value types.
        let level: ChronoConstellatorLevel = try Self.sample()
        var play: ChronoConstellatorPlay = try Self.playing(level)
        try play.apply(.hold(1, 2, 3), expecting: play.fingerprint)
        try play.apply(.step(8), expecting: play.fingerprint)
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: level.stars[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.timeline).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: ChronoConstellatorHold(star: 0, start: 1, length: 1)).displayStyle == .struct)
        #expect(Mirror(reflecting: ChronoConstellatorAction.rewind).displayStyle == .enum)
        #expect(Mirror(reflecting: ChronoConstellatorFailure.time).displayStyle == .enum)
        // A copy is independent: changing it leaves the original as it was.
        let original: ChronoConstellatorPlay = play
        var copy: ChronoConstellatorPlay = play
        try copy.apply(.step(1), expecting: copy.fingerprint)
        #expect(play == original && copy.tick == play.tick + 1)
        // Reading descriptions, decoding the level and recomputing positions change nothing.
        let fingerprint: String = play.fingerprint
        let verdict: ChronoConstellatorVerdict = ChronoConstellatorEvaluation.verdict(positions: play.positions,
                                                                                     tick: play.tick, level: level)
        var words: [String] = []
        for star in level.stars.indices { words.append(level.description(ofStar: star)) }
        for shape in ChronoConstellatorShape.allCases { words.append(shape.name) }
        words.append(String(describing: play.stage))
        words.append(String(describing: verdict))
        #expect(words[0] == "star 1 (ring): loop of 4 cells, target row 2, column 2")
        #expect(words[1] == "star 2 (cross): loop of 8 cells, target row 4, column 5")
        #expect(play.fingerprint == fingerprint && play == original)
        let decoded: ChronoConstellatorLevel = try ChronoConstellatorLevel.decode(level.encoded())
        #expect(play.timeline.positions(at: play.tick, level: decoded) == play.positions)
        #expect(ChronoConstellatorEvaluation.verdict(positions: play.positions, tick: play.tick, level: decoded)
                    == verdict)
        let rebuilt: ChronoConstellatorPlay = try ChronoConstellatorPlay.replay(level: decoded, records: play.records)
        #expect(rebuilt.fingerprint == fingerprint)
        // The same state reached by another path (an edit and its undo) has the same fingerprint.
        var detour: ChronoConstellatorPlay = try Self.playing(level)
        try detour.apply(.phase(0, 3), expecting: detour.fingerprint)
        try detour.undo()
        let start: ChronoConstellatorPlay = try Self.playing(level)
        #expect(detour.fingerprint == start.fingerprint)
        // The kernel sources import no UI or GPU framework and read no clock or random source.
        let forbidden: [String] = ["import UIKit", "import SwiftUI", "import AppKit", "import Metal", "import QuartzCore",
                                   "import OpenGLES", "import GameKit", "import CoreMotion", "import Combine",
                                   "Date()", "Date.now", "CFAbsoluteTimeGetCurrent", "CACurrentMediaTime",
                                   "DispatchTime.now", "ContinuousClock", "SuspendingClock", "systemUptime",
                                   "SystemRandomNumberGenerator", ".random(", "arc4random", "UUID()"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count >= 4)
        for source in sources {
            for token in forbidden {
                #expect(!source.text.contains(token), "\(source.name) uses \(token)")
            }
            for line in source.text.split(separator: "\n") {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                let isClass: Bool = trimmed.hasPrefix("class ") || trimmed.hasPrefix("final class ")
                    || trimmed.hasPrefix("public class ") || trimmed.hasPrefix("public final class ")
                    || trimmed.hasPrefix("open class ")
                #expect(!isClass, "\(source.name) declares a reference type: \(trimmed)")
            }
        }
        // Seeded neighbours: for seeded traces, copies, a decoded level and reading descriptions leave the fingerprint,
        // positions and verdict unchanged, and the positions are the closed form of the timeline at the tick.
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 10)
        for index in 0..<40 {
            let other: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(800 + index)
            let p: ChronoConstellatorPlay = try Self.randomPlay(other, actions: 30, maxTicks: 30, random: &random)
            let held: String = p.fingerprint
            let heldPositions: [Int] = p.positions
            let heldVerdict: ChronoConstellatorVerdict = ChronoConstellatorEvaluation.verdict(
                positions: heldPositions, tick: p.tick, level: other)
            var read: Int = 0
            for star in other.stars.indices { read += other.description(ofStar: star).count }
            #expect(read > 0)
            let otherDecoded: ChronoConstellatorLevel = try ChronoConstellatorLevel.decode(other.encoded())
            let timelineCopy: ChronoConstellatorTimeline = p.timeline
            #expect(timelineCopy.positions(at: p.tick, level: otherDecoded) == heldPositions)
            #expect(ChronoConstellatorEvaluation.verdict(positions: heldPositions, tick: p.tick, level: otherDecoded)
                        == heldVerdict)
            #expect(p.fingerprint == held && p.positions == heldPositions)
            let pCopy: ChronoConstellatorPlay = p
            #expect(pCopy.fingerprint == held)
            if !p.records.isEmpty {
                let again: ChronoConstellatorPlay = try ChronoConstellatorPlay.replay(level: otherDecoded,
                                                                                      records: p.records)
                #expect(again.fingerprint == held && again.positions == heldPositions)
            }
        }
    }
}
