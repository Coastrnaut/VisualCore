// ColorfallCanyonsInvariantTests — feature 341 (R02-G05-01) T-R02G0501-006 (FR-R02G0501-012; the source's invariants
// R2-G05-INV-01 … 05 and INV-07 … 10, round2.md section 6.5.3 on Colorfall Canyons). Each named test gives a direct
// boundary example and a seeded check of neighbouring inputs (seed 2,346), as the source asks. How each invariant maps
// onto this kernel (INV-06 content and INV-12 novelty belong to R02-G05-02; INV-11 is superseded by the free tier):
// - INV-01 Time: a fixed tick of 1/60 s; the outcome depends on the tick count, not on how ticks are batched (step(n)
//   and n × step(1) reach the same fingerprint); an undecided play fails on time exactly at the tick limit, not before.
// - INV-02 Input budget: carves and valve toggles spend one action each up to the budget, the next one is refused with
//   `budget`; steps, undo and redo spend nothing; a refused action changes nothing.
// - INV-03 Goal: a win only when every target basin holds at least its fill within the tolerance of its mix (fill − 1
//   and one unit beyond the tolerance are not met); one unmet basin keeps the play from winning.
// - INV-04 Repeatability: the same seed and trace give the same records and fingerprints on two independent runs and
//   through replay; an edited record is refused.
// - INV-05 Undo: undo restores the prior fingerprint, including the success or failure state; redo the later one; a won
//   play is final.
// - INV-07 Failure honesty: every failure carries its named reason (contamination, overflow, time — each reachable);
//   the kernel never wins a fixture without the player's actions.
// - INV-08 Stability: heights, masses, supplies, spilled and released amounts stay within their ranges and
//   non-negative over long seeded runs; colours are conserved exactly.
// - INV-09 Save: the stored level round-trips byte for byte; truncated and edited stored forms are refused; a stored
//   record trace up to a save point replays to the state at that point.
// - INV-10 Renderer purity: the verdict and fingerprint are functions of the kernel state only — copying the play,
//   encoding and decoding the level and reading the description strings never change them.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import ColorfallCanyonsCore

@Suite struct ColorfallCanyonsInvariantTests {
    /// The invariant seed.
    static let seed: UInt64 = 2_346

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// A hand-made channel level of 6 × 4 cells: row 1 holds a spring at cell 6 and open cells 7 … 10 whose heights fall
    /// by one per column (12, 11, 10, 9) into the basin at cell 11 (height 0); every other cell is rock except the drain
    /// at cell 23. With `isolated` set a second basin sits walled in at cell 14 (height 15) and never receives fluid.
    /// With release ≤ flow rate, a unit released at tick t reaches the basin at tick t + 5.
    static func channel(color: ColorfallCanyonsColor = .cyan, release: Int = 1, supply: Int = 10, open: Bool = true,
                        capacity: Int = 50, fill: Int = 10, shares: [Int] = [1_000, 0, 0], tolerance: Int = 0,
                        isProtected: Bool = false, toleratedWrong: Int = 0, isolated: Int? = nil, flowRate: Int = 4,
                        budget: Int = 30, tickLimit: Int = 60) throws -> ColorfallCanyonsLevel {
        let columns: Int = 6
        let rows: Int = 4
        var grounds = [ColorfallCanyonsGround](repeating: .rock, count: columns * rows)
        var heights = [Int](repeating: 15, count: columns * rows)
        for column in 0..<columns {
            grounds[columns + column] = .open
            heights[columns + column] = 13 - column
        }
        heights[11] = 0
        grounds[23] = .drain
        heights[23] = 0
        let spring = ColorfallCanyonsSpring(cell: 6, color: color, release: release, supply: supply, open: open)
        var basins: [ColorfallCanyonsBasin] = [
            ColorfallCanyonsBasin(cell: 11, capacity: capacity, fill: fill, shares: shares, tolerance: tolerance,
                                  isProtected: isProtected, toleratedWrong: toleratedWrong),
        ]
        if let isolated {
            grounds[14] = .open
            basins.append(ColorfallCanyonsBasin(cell: 14, capacity: 10, fill: isolated, shares: [1_000, 0, 0],
                                                tolerance: 0, isProtected: false, toleratedWrong: 0))
        }
        return try ColorfallCanyonsLevel(id: "channel", seed: seed, difficulty: 1, columns: columns, rows: rows,
                                         heights: heights, grounds: grounds, springs: [spring], basins: basins,
                                         flowRate: flowRate, budget: budget, tickLimit: tickLimit)
    }

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: ColorfallCanyonsLevel) throws -> ColorfallCanyonsPlay {
        var play = ColorfallCanyonsPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The fixture's known solution played from the start.
    static func solved(_ fixture: ColorfallCanyonsFixture) throws -> ColorfallCanyonsPlay {
        var play: ColorfallCanyonsPlay = try playing(fixture.level)
        for action in fixture.solution where play.stage == .playing {
            try play.apply(action, expecting: play.fingerprint)
        }
        return play
    }

    /// Runs `ticks` ticks as single-tick steps, stopping when the play is decided.
    static func singleSteps(_ play: inout ColorfallCanyonsPlay, _ ticks: Int) throws {
        var count: Int = 0
        while play.stage == .playing && count < ticks {
            try play.apply(.step(1), expecting: play.fingerprint)
            count += 1
        }
    }

    /// A seeded trace of carves, valve toggles, steps of 1 … `maxTicks` ticks, undos and redos, at most `actions` long;
    /// a failed play is undone or ends the trace, a won play ends it. Every chosen action is accepted.
    static func randomPlay(_ level: ColorfallCanyonsLevel, actions: Int, maxTicks: Int,
                           random: inout ColorfallCanyonsRandom) throws -> ColorfallCanyonsPlay {
        var play: ColorfallCanyonsPlay = try playing(level)
        var count: Int = 0
        while count < actions {
            count += 1
            if play.stage == .won { break }
            if play.stage == .failed {
                if random.bool() && play.canUndo { try play.undo() } else { break }
                continue
            }
            let roll: Int = random.int(0...9)
            if roll == 0 && play.canUndo {
                try play.undo()
            } else if roll == 1 && play.canRedo {
                try play.redo()
            } else if (roll == 2 || roll == 3) && play.remaining > 0 {
                let cell: Int = random.int(0...(level.cellCount - 1))
                if level.isCarvable(cell, heights: play.fluid.heights) {
                    try play.apply(.carve(cell), expecting: play.fingerprint)
                } else {
                    try play.apply(.step(random.int(1...maxTicks)), expecting: play.fingerprint)
                }
            } else if roll == 4 && play.remaining > 0 {
                try play.apply(.valve(random.int(0...(level.springs.count - 1))), expecting: play.fingerprint)
            } else {
                try play.apply(.step(random.int(1...maxTicks)), expecting: play.fingerprint)
            }
        }
        return play
    }

    /// Whether two plays hold the same kernel state (fingerprint, fluid, stage, spent and failure).
    static func sameState(_ a: ColorfallCanyonsPlay, _ b: ColorfallCanyonsPlay) -> Bool {
        a.fingerprint == b.fingerprint && a.fluid == b.fluid && a.stage == b.stage && a.spent == b.spent
            && a.failure == b.failure
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(ColorfallCanyonsError) -> Void) -> ColorfallCanyonsError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    // MARK: INV-01 Time

    /// INV-01 Time: a fixed 1/60 s tick; batching does not change the outcome; time fails exactly at the tick limit.
    @Test func testColorfallCanyonsTimeBoundary() throws {
        // Direct boundary: the tick is 1/60 s, so 60 ticks are one second.
        #expect(ColorfallCanyonsLevel.tickSeconds == 1.0 / 60.0)
        #expect(abs(Double(60) * ColorfallCanyonsLevel.tickSeconds - 1.0) < 1e-12)
        // step(n) and n × step(1) reach the same fingerprint (fill 11 of a supply of 10: never won, fails on time).
        let level: ColorfallCanyonsLevel = try Self.channel(fill: 11, tickLimit: 40)
        var batched: ColorfallCanyonsPlay = try Self.playing(level)
        try batched.apply(.step(17), expecting: batched.fingerprint)
        var single: ColorfallCanyonsPlay = try Self.playing(level)
        try Self.singleSteps(&single, 17)
        #expect(Self.sameState(batched, single))
        #expect(batched.fluid.tick == 17 && batched.stage == .playing)
        // Tick limit − 1 is still running; the tick limit fails on time; a step never runs past the deciding tick.
        try batched.apply(.step(level.tickLimit - 1 - 17), expecting: batched.fingerprint)
        #expect(batched.fluid.tick == level.tickLimit - 1 && batched.stage == .playing && batched.failure == nil)
        #expect(batched.fluid.verdict(level: level) == .running)
        try batched.apply(.step(600), expecting: batched.fingerprint)
        #expect(batched.fluid.tick == level.tickLimit && batched.stage == .failed && batched.failure == .time)
        try Self.singleSteps(&single, 600)
        #expect(Self.sameState(batched, single))
        // Seeded neighbours: fixtures without carves fail on time exactly at the limit; random levels with seeded
        // valve toggles agree between one step and seeded batches of any size.
        var random = ColorfallCanyonsRandom(seed: Self.seed)
        for index in 0..<30 {
            let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(random.int(0...9_999))
            var pooled: ColorfallCanyonsPlay = try Self.playing(fixture.level)
            try pooled.apply(.step(fixture.level.tickLimit - 1), expecting: pooled.fingerprint)
            #expect(pooled.stage == .playing && pooled.fluid.tick == fixture.level.tickLimit - 1)
            try pooled.apply(.step(1), expecting: pooled.fingerprint)
            #expect(pooled.stage == .failed && pooled.failure == .time)
            #expect(pooled.fluid.tick == fixture.level.tickLimit)
            // The known solution wins whether its final step is one step or single ticks.
            let straight: ColorfallCanyonsPlay = try Self.solved(fixture)
            var ticked: ColorfallCanyonsPlay = try Self.playing(fixture.level)
            for action in fixture.solution {
                if case .step(let n) = action {
                    try Self.singleSteps(&ticked, n)
                } else {
                    try ticked.apply(action, expecting: ticked.fingerprint)
                }
            }
            #expect(straight.stage == .won && Self.sameState(straight, ticked))
            // A random level: the same valve toggles, then the same tick count in one step or seeded batches.
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(index)
            var one: ColorfallCanyonsPlay = try Self.playing(other)
            var many: ColorfallCanyonsPlay = try Self.playing(other)
            if random.bool() && other.budget > 0 {
                let spring: Int = random.int(0...(other.springs.count - 1))
                try one.apply(.valve(spring), expecting: one.fingerprint)
                try many.apply(.valve(spring), expecting: many.fingerprint)
            }
            let ticks: Int = random.int(1...200)
            try one.apply(.step(ticks), expecting: one.fingerprint)
            var left: Int = ticks
            while left > 0 && many.stage == .playing {
                let batch: Int = random.int(1...min(left, 37))
                try many.apply(.step(batch), expecting: many.fingerprint)
                left -= batch
            }
            #expect(Self.sameState(one, many))
            #expect(one.fluid.tick <= other.tickLimit)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: the budget-th action is accepted, the next refused with `budget`; refused actions spend
    /// nothing and change nothing; steps, undo and redo are free.
    @Test func testColorfallCanyonsInputbudgetBoundary() throws {
        // Direct boundary: budget 3 — two carves and a valve spend it exactly; then carve and valve are refused.
        let level: ColorfallCanyonsLevel = try Self.channel(budget: 3)
        var play: ColorfallCanyonsPlay = try Self.playing(level)
        try play.apply(.carve(8), expecting: play.fingerprint)
        try play.apply(.step(5), expecting: play.fingerprint)
        #expect(play.spent == 1)
        try play.apply(.carve(9), expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        #expect(play.spent == 2 && play.remaining == 1)
        // Refusals before the budget runs out spend nothing.
        let before: ColorfallCanyonsPlay = play
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.carve(8), expecting: Self.staleFingerprint) } == .stale)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.carve(24), expecting: play.fingerprint) } == .action("range"))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.valve(1), expecting: play.fingerprint) } == .action("range"))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.carve(0), expecting: play.fingerprint) } == .action("not-carvable"))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.carve(11), expecting: play.fingerprint) } == .action("not-carvable"))
        #expect(play == before)
        try play.apply(.valve(0), expecting: play.fingerprint)
        #expect(play.spent == 3 && play.spent == level.budget && play.remaining == 0)
        let spentOut: ColorfallCanyonsPlay = play
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.carve(7), expecting: play.fingerprint) } == .budget)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.valve(0), expecting: play.fingerprint) } == .budget)
        #expect(play == spentOut)
        try play.apply(.step(3), expecting: play.fingerprint)
        #expect(play.spent == 3)
        // Undo gives an action back; the redo spends it again.
        try play.undo()
        try play.undo()
        #expect(play.spent == 2)
        try play.redo()
        #expect(play.spent == 3)
        // Seeded neighbours: random levels and random actions — an accepted carve or valve spends exactly one, a step
        // none; a refused action leaves the play equal; spent never exceeds the budget.
        var random = ColorfallCanyonsRandom(seed: Self.seed &+ 2)
        for index in 0..<40 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(100 + index)
            var p: ColorfallCanyonsPlay = try Self.playing(other)
            for _ in 0..<60 where p.stage == .playing {
                let held: ColorfallCanyonsPlay = p
                let roll: Int = random.int(0...5)
                let action: ColorfallCanyonsAction
                if roll <= 2 {
                    action = .carve(random.int(-1...other.cellCount))
                } else if roll <= 4 {
                    action = .valve(random.int(-1...other.springs.count))
                } else {
                    action = .step(random.int(0...8))
                }
                let stale: Bool = random.int(0...7) == 0
                let previous: String = stale ? Self.staleFingerprint : p.fingerprint
                let error: ColorfallCanyonsError? = Self.refusal { () throws(ColorfallCanyonsError) in
                    try p.apply(action, expecting: previous)
                }
                if let error {
                    #expect(p == held)
                    if stale { #expect(error == .stale) }
                    if error == .budget { #expect(held.remaining == 0) }
                } else {
                    #expect(!stale)
                    if case .step = action {
                        #expect(p.spent == held.spent)
                    } else {
                        #expect(p.spent == held.spent + 1)
                        #expect(held.remaining > 0)
                    }
                }
                #expect(p.spent >= 0 && p.spent <= other.budget)
            }
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: a win only when every target basin is met; fill − 1 and one unit beyond the tolerance are not met.
    @Test func testColorfallCanyonsGoalBoundary() throws {
        // Direct boundary on the basin rule: fill 10, cyan 500 ± 100, coral 500 ± 100, no yellow.
        let basin = ColorfallCanyonsBasin(cell: 0, capacity: 50, fill: 10, shares: [500, 500, 0], tolerance: 100,
                                          isProtected: false, toleratedWrong: 0)
        #expect(basin.accepts([5, 5, 0]))
        #expect(!basin.accepts([5, 4, 0]))
        #expect(basin.accepts([4, 6, 0]))
        #expect(!basin.accepts([3, 7, 0]))
        #expect(basin.accepts([4, 5, 1]))
        #expect(!basin.accepts([4, 4, 2]))
        // Direct boundary on play: a supply of 10 reaches the basin at tick 15; fill 10 wins there, fill 11 never wins.
        let exact: ColorfallCanyonsLevel = try Self.channel(fill: 10)
        var won: ColorfallCanyonsPlay = try Self.playing(exact)
        try won.apply(.step(14), expecting: won.fingerprint)
        #expect(won.stage == .playing && won.fluid.masses[11][0] == 9)
        try won.apply(.step(600), expecting: won.fingerprint)
        #expect(won.stage == .won && won.fluid.tick == 15 && won.failure == nil)
        let short: ColorfallCanyonsLevel = try Self.channel(fill: 11)
        var missed: ColorfallCanyonsPlay = try Self.playing(short)
        try missed.apply(.step(600), expecting: missed.fingerprint)
        #expect(missed.stage == .failed && missed.failure == .time && missed.fluid.masses[11][0] == 10)
        // Every target basin: a met channel basin with an unreachable second target never wins; fill 0 there wins.
        var unmet: ColorfallCanyonsPlay = try Self.playing(try Self.channel(fill: 10, isolated: 1))
        try unmet.apply(.step(600), expecting: unmet.fingerprint)
        #expect(unmet.stage == .failed && unmet.failure == .time)
        var met: ColorfallCanyonsPlay = try Self.playing(try Self.channel(fill: 10, isolated: 0))
        try met.apply(.step(600), expecting: met.fingerprint)
        #expect(met.stage == .won && met.fluid.tick == 15)
        // Seeded neighbours: the fill edge (fill − 1 refused, fill and fill + 1 met) and the tolerance edge (exactly the
        // tolerance met, one unit beyond refused) for seeded basins; a won random play has every basin met.
        var random = ColorfallCanyonsRandom(seed: Self.seed &+ 3)
        for _ in 0..<200 {
            let color: Int = random.int(0...2)
            var shares: [Int] = [0, 0, 0]
            shares[color] = 1_000
            let fill: Int = random.int(1...999)
            let mono = ColorfallCanyonsBasin(cell: 0, capacity: 999, fill: fill, shares: shares,
                                             tolerance: random.int(0...500), isProtected: false, toleratedWrong: 0)
            var masses: [Int] = [0, 0, 0]
            masses[color] = fill - 1
            #expect(!mono.accepts(masses))
            masses[color] = fill
            #expect(mono.accepts(masses))
            masses[color] = fill + 1
            #expect(mono.accepts(masses))
            let tolerance: Int = random.int(0...499)
            let mixed = ColorfallCanyonsBasin(cell: 0, capacity: 999, fill: 1, shares: [500, 500, 0],
                                              tolerance: tolerance, isProtected: false, toleratedWrong: 0)
            #expect(mixed.accepts([500 + tolerance, 500 - tolerance, 0]))
            #expect(!mixed.accepts([501 + tolerance, 499 - tolerance, 0]))
        }
        for index in 0..<40 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(200 + index)
            let p: ColorfallCanyonsPlay = try Self.randomPlay(other, actions: 30, maxTicks: 40, random: &random)
            let allMet: Bool = other.basins.allSatisfy { $0.accepts(p.fluid.masses[$0.cell]) }
            if p.stage == .won {
                #expect(allMet && p.fluid.tick >= 1)
            } else if p.stage == .playing && p.fluid.tick >= 1 {
                #expect(!allMet)
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same seed and trace give the same records and fingerprints on every run and replay.
    @Test func testColorfallCanyonsRepeatabilityBoundary() throws {
        // Direct example: a fixture's solution played twice and replayed.
        let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(7)
        let first: ColorfallCanyonsPlay = try Self.solved(fixture)
        let second: ColorfallCanyonsPlay = try Self.solved(ColorfallCanyonsFixtures.fixture(7))
        #expect(first == second && first.records == second.records && first.stage == .won)
        let replayed: ColorfallCanyonsPlay = try ColorfallCanyonsPlay.replay(level: fixture.level,
                                                                             records: first.records)
        #expect(replayed == first)
        // An edited record is refused.
        var edited: [ColorfallCanyonsRecord] = first.records
        let last: ColorfallCanyonsRecord = edited[edited.count - 1]
        edited[edited.count - 1] = ColorfallCanyonsRecord(schema: last.schema, seed: last.seed, tick: last.tick,
                                                          kind: last.kind, action: last.action,
                                                          previous: last.previous, next: Self.staleFingerprint)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            _ = try ColorfallCanyonsPlay.replay(level: fixture.level, records: edited) }
                == .malformed("record \(edited.count - 1)"))
        // Seeded neighbours: two independent runs of the same seeded trace agree, and the trace replays.
        for index in 0..<40 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(300 + index, tutorial: index % 3 == 0)
            var randomA = ColorfallCanyonsRandom(seed: Self.seed &+ UInt64(index))
            var randomB = ColorfallCanyonsRandom(seed: Self.seed &+ UInt64(index))
            let a: ColorfallCanyonsPlay = try Self.randomPlay(other, actions: 40, maxTicks: 30, random: &randomA)
            let b: ColorfallCanyonsPlay = try Self.randomPlay(ColorfallCanyonsFixtures.randomLevel(300 + index,
                                                                                               tutorial: index % 3 == 0),
                                                              actions: 40, maxTicks: 30, random: &randomB)
            #expect(a == b && a.fingerprint == b.fingerprint)
            for i in 0..<a.records.count {
                #expect(a.records[i].next == b.records[i].next)
                #expect(i == 0 || a.records[i].previous == a.records[i - 1].next)
            }
            let again: ColorfallCanyonsPlay = try ColorfallCanyonsPlay.replay(level: other, records: a.records)
            #expect(Self.sameState(again, a) && again.records == a.records)
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo restores the prior fingerprint including the success or failure state; redo the later one.
    @Test func testColorfallCanyonsUndoBoundary() throws {
        // Direct boundary: a valve and a carve undone and redone; a failure undone back to playing and redone.
        let level: ColorfallCanyonsLevel = try Self.channel(fill: 11)
        var play: ColorfallCanyonsPlay = try Self.playing(level)
        let fresh: String = play.fingerprint
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in try play.undo() } == .action("nothing-to-undo"))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in try play.redo() } == .action("nothing-to-redo"))
        try play.apply(.carve(9), expecting: play.fingerprint)
        let carved: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == fresh && play.fluid.heights[9] == 10 && play.spent == 0)
        try play.redo()
        #expect(play.fingerprint == carved && play.fluid.heights[9] == 9 && play.spent == 1)
        try play.apply(.step(5), expecting: play.fingerprint)
        let running: String = play.fingerprint
        try play.apply(.step(600), expecting: play.fingerprint)
        #expect(play.stage == .failed && play.failure == .time)
        let failed: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == running && play.stage == .playing && play.failure == nil)
        try play.redo()
        #expect(play.fingerprint == failed && play.stage == .failed && play.failure == .time)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in try play.redo() } == .stage)
        // A won play is final.
        var won: ColorfallCanyonsPlay = try Self.playing(try Self.channel(fill: 10))
        try won.apply(.step(600), expecting: won.fingerprint)
        #expect(won.stage == .won)
        let final: ColorfallCanyonsPlay = won
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in try won.undo() } == .stage)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in try won.redo() } == .stage)
        #expect(won == final)
        // Seeded neighbours: a shadow history of fingerprints matches every undo and redo of seeded traces.
        var random = ColorfallCanyonsRandom(seed: Self.seed &+ 5)
        for index in 0..<40 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(400 + index)
            var p: ColorfallCanyonsPlay = try Self.playing(other)
            var history: [String] = []
            var future: [String] = []
            for _ in 0..<50 {
                if p.stage == .won { break }
                let roll: Int = random.int(0...5)
                let before: String = p.fingerprint
                if p.stage == .failed || (roll <= 1 && p.canUndo) {
                    guard p.canUndo else { break }
                    try p.undo()
                    #expect(p.fingerprint == history.removeLast())
                    future.append(before)
                    #expect(p.stage == .playing || p.stage == .failed)
                } else if roll == 2 && p.canRedo {
                    try p.redo()
                    #expect(p.fingerprint == future.removeLast())
                    history.append(before)
                } else {
                    let cell: Int = random.int(0...(other.cellCount - 1))
                    if p.remaining > 0 && other.isCarvable(cell, heights: p.fluid.heights) {
                        try p.apply(.carve(cell), expecting: before)
                    } else {
                        try p.apply(.step(random.int(1...40)), expecting: before)
                    }
                    history.append(before)
                    future.removeAll()
                }
                #expect(p.canUndo == !history.isEmpty || p.stage == .won)
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: every failure names its reason; each reason is reachable; no automatic solution.
    @Test func testColorfallCanyonsFailurehonestyBoundary() throws {
        // Contamination: coral into a protected cyan basin that tolerates no wrong colour.
        var tainted: ColorfallCanyonsPlay = try Self.playing(try Self.channel(color: .coral, isProtected: true))
        try tainted.apply(.step(600), expecting: tainted.fingerprint)
        #expect(tainted.stage == .failed && tainted.failure == .contamination && tainted.fluid.tick == 6)
        // The tolerated wrong amount is a boundary: 1 tolerated unit passes the first arrival, the second fails.
        var tolerant: ColorfallCanyonsPlay = try Self.playing(try Self.channel(color: .coral, isProtected: true,
                                                                              toleratedWrong: 1))
        try tolerant.apply(.step(600), expecting: tolerant.fingerprint)
        #expect(tolerant.failure == .contamination && tolerant.fluid.tick == 7)
        // Overflow: capacity 10 below the supply of 12, unprotected.
        var flooded: ColorfallCanyonsPlay = try Self.playing(try Self.channel(supply: 12, capacity: 10, fill: 10,
                                                                             shares: [0, 1_000, 0]))
        try flooded.apply(.step(600), expecting: flooded.fingerprint)
        #expect(flooded.stage == .failed && flooded.failure == .overflow && flooded.fluid.masses[11][0] == 11)
        // Both at once: contamination is named first.
        var both: ColorfallCanyonsPlay = try Self.playing(try Self.channel(color: .coral, release: 4, capacity: 1,
                                                                          fill: 1, isProtected: true, flowRate: 4))
        try both.apply(.step(600), expecting: both.fingerprint)
        #expect(both.failure == .contamination)
        // Time: a closed spring with no actions.
        var idle: ColorfallCanyonsPlay = try Self.playing(try Self.channel(open: false, tickLimit: 30))
        try idle.apply(.step(600), expecting: idle.fingerprint)
        #expect(idle.stage == .failed && idle.failure == .time && idle.fluid.tick == 30)
        // The named reasons are exactly the three, with stable raw values.
        var names: [String] = []
        for failure in ColorfallCanyonsFailure.allCases { names.append(failure.rawValue) }
        #expect(names == ["contamination", "overflow", "time"])
        // Seeded neighbours: fixtures never win without the player's carves (steps and valves alone fail on time), and
        // in seeded traces a failure always carries the reason the verdict names, and a running play has none.
        var random = ColorfallCanyonsRandom(seed: Self.seed &+ 7)
        for _ in 0..<40 {
            let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(random.int(0...9_999))
            var lazy: ColorfallCanyonsPlay = try Self.playing(fixture.level)
            if fixture.solution.contains(.valve(0)) { try lazy.apply(.valve(0), expecting: lazy.fingerprint) }
            while lazy.stage == .playing {
                try lazy.apply(.step(random.int(1...30)), expecting: lazy.fingerprint)
            }
            #expect(lazy.stage == .failed && lazy.failure == .time)
        }
        for index in 0..<40 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(500 + index)
            let p: ColorfallCanyonsPlay = try Self.randomPlay(other, actions: 40, maxTicks: 60, random: &random)
            let verdict: ColorfallCanyonsVerdict = p.fluid.verdict(level: other)
            switch p.stage {
            case .failed:
                if let failure = p.failure {
                    #expect(verdict == .failed(failure))
                } else {
                    Issue.record("a failed play without a reason")
                }
            case .won:
                #expect(p.failure == nil && verdict == .won)
            default:
                #expect(p.failure == nil)
                if p.fluid.tick >= 1 { #expect(verdict == .running) }
            }
        }
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: every height, mass, supply and amount stays within its range and non-negative.
    @Test func testColorfallCanyonsStabilityBoundary() throws {
        // Direct boundary: a cell carved down to height 0 cannot be carved further; out-of-range operands are refused.
        let level: ColorfallCanyonsLevel = try Self.channel()
        var play: ColorfallCanyonsPlay = try Self.playing(level)
        for _ in 0..<9 {
            try play.apply(.carve(10), expecting: play.fingerprint)
        }
        #expect(play.fluid.heights[10] == 0)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.carve(10), expecting: play.fingerprint) } == .action("not-carvable"))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.carve(-1), expecting: play.fingerprint) } == .action("range"))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.step(0), expecting: play.fingerprint) } == .action("range"))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            try play.apply(.step(601), expecting: play.fingerprint) } == .action("range"))
        #expect(play.fluid.heights[10] == 0 && play.spent == 9)
        // Seeded neighbours: long seeded runs on random levels keep every value in range and colours conserved.
        var random = ColorfallCanyonsRandom(seed: Self.seed &+ 8)
        for index in 0..<40 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(600 + index)
            let p: ColorfallCanyonsPlay = try Self.randomPlay(other, actions: 80, maxTicks: 30, random: &random)
            let fluid: ColorfallCanyonsFluid = p.fluid
            #expect(fluid.isConserved())
            #expect(fluid.tick >= 0 && fluid.tick <= other.tickLimit)
            #expect(p.spent >= 0 && p.spent <= other.budget)
            for cell in 0..<other.cellCount {
                #expect(ColorfallCanyonsLevel.heights.contains(fluid.heights[cell]))
                #expect(fluid.heights[cell] <= other.heights[cell])
                for c in 0..<3 { #expect(fluid.masses[cell][c] >= 0) }
            }
            var totalSupply: [Int] = [0, 0, 0]
            for (s, spring) in other.springs.enumerated() {
                #expect(fluid.supplies[s] >= 0 && fluid.supplies[s] <= spring.supply)
                totalSupply[spring.color.rawValue] += spring.supply
            }
            for c in 0..<3 {
                #expect(fluid.spilled[c] >= 0 && fluid.released[c] >= 0)
                #expect(fluid.released[c] <= totalSupply[c] && fluid.released[c] <= 65_535)
            }
            for cell in 0..<other.cellCount where other.grounds[cell] == .rock || other.grounds[cell] == .drain {
                #expect(fluid.volume(cell) == 0)
            }
        }
    }

    // MARK: INV-09 Save

    /// INV-09 Save: the stored level round-trips; truncated or edited forms are refused; a saved trace replays.
    @Test func testColorfallCanyonsSaveBoundary() throws {
        // Direct boundary: the stored form round-trips byte for byte; one byte less is refused; an edited value and an
        // edited fingerprint are refused; a newer schema is refused by name.
        let level: ColorfallCanyonsLevel = try Self.channel()
        let stored: Data = level.encoded()
        let decoded: ColorfallCanyonsLevel = try ColorfallCanyonsLevel.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let truncated = Data(stored.prefix(stored.count - 1))
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            _ = try ColorfallCanyonsLevel.decode(truncated) } == .malformed("unreadable"))
        let text: String = String(decoding: stored, as: UTF8.self)
        let budgetEdit = Data(text.replacingOccurrences(of: "\"budget\":30", with: "\"budget\":29").utf8)
        #expect(budgetEdit != stored)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            _ = try ColorfallCanyonsLevel.decode(budgetEdit) } == .malformed("fingerprint"))
        let newer = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(Self.refusal { () throws(ColorfallCanyonsError) in
            _ = try ColorfallCanyonsLevel.decode(newer) } == .newerSchema(2))
        // Codable path agrees.
        let viaCodable: ColorfallCanyonsLevel = try JSONDecoder().decode(ColorfallCanyonsLevel.self,
                                                                         from: try JSONEncoder().encode(level))
        #expect(viaCodable == level)
        #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(ColorfallCanyonsLevel.self, from: budgetEdit) }
        // Seeded neighbours: random levels round-trip; seeded truncations and single-byte edits are refused; a stored
        // trace cut at a seeded save point replays to the state recorded there.
        var random = ColorfallCanyonsRandom(seed: Self.seed &+ 9)
        for index in 0..<30 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(700 + index)
            let bytes: Data = other.encoded()
            #expect(try ColorfallCanyonsLevel.decode(bytes) == other)
            for _ in 0..<10 {
                let cut: Int = random.int(0...(bytes.count - 1))
                let prefix = Data(bytes.prefix(cut))
                #expect(Self.refusal { () throws(ColorfallCanyonsError) in
                    _ = try ColorfallCanyonsLevel.decode(prefix) } != nil)
                var edit: [UInt8] = Array(bytes)
                let at: Int = random.int(0...(edit.count - 1))
                var replacement: UInt8 = UInt8(random.int(33...126))
                if replacement == edit[at] { replacement = replacement == 126 ? 33 : replacement + 1 }
                edit[at] = replacement
                let editedData = Data(edit)
                let outcome: ColorfallCanyonsError? = Self.refusal { () throws(ColorfallCanyonsError) in
                    _ = try ColorfallCanyonsLevel.decode(editedData)
                }
                #expect(outcome != nil, "edit at \(at) of level \(index) was accepted")
            }
            let p: ColorfallCanyonsPlay = try Self.randomPlay(other, actions: 30, maxTicks: 30, random: &random)
            guard !p.records.isEmpty else { continue }
            let save: Int = random.int(1...p.records.count)
            let trace: [ColorfallCanyonsRecord] = Array(p.records.prefix(save))
            let storedTrace: Data = try JSONEncoder().encode(trace)
            let loaded: [ColorfallCanyonsRecord] = try JSONDecoder().decode([ColorfallCanyonsRecord].self,
                                                                            from: storedTrace)
            #expect(loaded == trace)
            let restored: ColorfallCanyonsPlay = try ColorfallCanyonsPlay.replay(
                level: try ColorfallCanyonsLevel.decode(bytes), records: loaded)
            #expect(restored.fingerprint == trace[save - 1].next)
            if save == p.records.count { #expect(Self.sameState(restored, p)) }
            // A partial (truncated) stored trace is refused.
            let partial = Data(storedTrace.prefix(storedTrace.count - 1))
            #expect(throws: (any Error).self) {
                _ = try JSONDecoder().decode([ColorfallCanyonsRecord].self, from: partial)
            }
        }
    }

    // MARK: INV-10 Renderer purity

    /// INV-10 Renderer purity: the verdict and fingerprint depend on the kernel state only.
    @Test func testColorfallCanyonsRendererpurityBoundary() throws {
        // Direct example: reading every description, copying the play and decoding the level change nothing.
        let level: ColorfallCanyonsLevel = try Self.channel(shares: [500, 500, 0], tolerance: 100)
        var play: ColorfallCanyonsPlay = try Self.playing(level)
        try play.apply(.step(8), expecting: play.fingerprint)
        let fingerprint: String = play.fingerprint
        let verdict: ColorfallCanyonsVerdict = play.fluid.verdict(level: level)
        var words: [String] = []
        for basin in level.basins { words.append(basin.description) }
        for color in ColorfallCanyonsColor.allCases { words.append(color.name) }
        words.append(String(describing: play.stage))
        words.append(String(describing: verdict))
        #expect(words[0] == "at least 10 units: cyan 500 ± 100 per mille, coral 500 ± 100 per mille, yellow none")
        #expect(play.fingerprint == fingerprint && play.fluid.verdict(level: level) == verdict)
        let copy: ColorfallCanyonsPlay = play
        #expect(copy.fingerprint == fingerprint && copy == play)
        let decoded: ColorfallCanyonsLevel = try ColorfallCanyonsLevel.decode(level.encoded())
        #expect(play.fluid.verdict(level: decoded) == verdict)
        let rebuilt: ColorfallCanyonsPlay = try ColorfallCanyonsPlay.replay(level: decoded, records: play.records)
        #expect(rebuilt.fingerprint == fingerprint)
        // The same state reached by another path (an action and its undo) has the same fingerprint.
        var detour: ColorfallCanyonsPlay = try Self.playing(level)
        try detour.apply(.valve(0), expecting: detour.fingerprint)
        try detour.undo()
        #expect(detour.fingerprint == (try Self.playing(level)).fingerprint)
        // Seeded neighbours: for seeded traces, copies, a decoded level and reading descriptions all leave the
        // fingerprint and verdict unchanged, and the verdict recomputed on a copy of the fluid agrees.
        var random = ColorfallCanyonsRandom(seed: Self.seed &+ 10)
        for index in 0..<40 {
            let other: ColorfallCanyonsLevel = ColorfallCanyonsFixtures.randomLevel(800 + index)
            let p: ColorfallCanyonsPlay = try Self.randomPlay(other, actions: 30, maxTicks: 30, random: &random)
            let held: String = p.fingerprint
            let heldVerdict: ColorfallCanyonsVerdict = p.fluid.verdict(level: other)
            var read: Int = 0
            for basin in other.basins { read += basin.description.count }
            #expect(read > 0)
            let fluidCopy: ColorfallCanyonsFluid = p.fluid
            let otherDecoded: ColorfallCanyonsLevel = try ColorfallCanyonsLevel.decode(other.encoded())
            #expect(fluidCopy.verdict(level: otherDecoded) == heldVerdict)
            #expect(p.fingerprint == held)
            let pCopy: ColorfallCanyonsPlay = p
            #expect(pCopy.fingerprint == held)
            if !p.records.isEmpty {
                let again: ColorfallCanyonsPlay = try ColorfallCanyonsPlay.replay(level: otherDecoded,
                                                                                  records: p.records)
                #expect(again.fingerprint == held)
            }
        }
    }
}
