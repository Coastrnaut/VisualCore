// AuroraLoomInvariantTests — feature 301 (R02-G01-01) T-R02G0101-012 (the source's invariants R2-G01-INV-01 … 05 and
// 07 … 09, round2.md section 6.1.3). Each named test gives a direct boundary example and a seeded check of neighbouring
// inputs, as the source asks. INV-06 (content witnesses), INV-10 (renderer purity) and INV-12 (novelty) belong to later
// features; INV-11 (monetization) is superseded (the experience is free).
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

@Suite struct AuroraLoomInvariantTests {
    /// A playing play of a seeded fixture (tutorial dismissed when the level has one).
    static func playing(_ fixture: AuroraLoomFixture) throws -> AuroraLoomPlay {
        var play = AuroraLoomPlay(level: fixture.level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// INV-01 Time: the outcome is a function of integer ticks of 1/120 s over exactly two periods, never of frames.
    @Test func testAuroraLoomTimeBoundary() throws {
        // A drifting ribbon gains one unit per tick: with 2P − 1 ticks inside the tolerance it wins; one tick more of
        // drift (tolerance one lower) and it does not.
        var random = SeededRandom(seed: 2_301)
        for _ in 0..<50 {
            let fixture = AuroraLoomFixture.next(&random)
            let level = fixture.level
            let last: Int = 2 * level.period - 1
            var worstTick: Int = 0
            for n in 0..<(2 * level.period) {
                let value: Int = abs(AuroraLoomHarmony.residual(ribbon: 0, gate: 0, tick: n, steps: fixture.winning,
                                                                level: level))
                if value > 0 { worstTick = n }
            }
            #expect(worstTick <= last)
            // Ticks beyond the two periods never matter: the same residual repeats with period P.
            for n in 0..<level.period {
                let a: Int = AuroraLoomHarmony.residual(ribbon: 1, gate: 2, tick: n, steps: level.startSteps, level: level)
                let b: Int = AuroraLoomHarmony.residual(ribbon: 1, gate: 2, tick: n + level.period, steps: level.startSteps,
                                                        level: level)
                #expect(a == b)
            }
        }
    }

    /// INV-02 Input budget: a move is refused once the allowance ends the level; nothing changes.
    @Test func testAuroraLoomInputbudgetBoundary() throws {
        var random = SeededRandom(seed: 2_302)
        for _ in 0..<50 {
            let fixture = AuroraLoomFixture.next(&random)
            var play = try Self.playing(fixture)
            // Spend every move on ribbon 0's phase without reaching the winning steps.
            var guardSteps: Int = 0
            while play.stage == .playing && guardSteps < 200 {
                guardSteps += 1
                let current: Int = play.steps.phase[0]
                var next: Int = (current + 1) % 16
                if next == fixture.winning.phase[0] { next = (next + 1) % 16 }
                if next == current { next = (next + 1) % 16 }
                try play.apply(AuroraLoomMove(ribbon: 0, control: .phase, step: next), expecting: play.fingerprint)
            }
            #expect(play.spent <= fixture.level.allowance)
            let before: AuroraLoomPlay = play
            #expect(throws: AuroraLoomError.self) {
                var copy: AuroraLoomPlay = play
                try copy.apply(AuroraLoomMove(ribbon: 1, control: .wave, step: (play.steps.wave[1] + 1) % 16),
                               expecting: play.fingerprint)
            }
            #expect(play == before)
            // Out of range on either side is refused with the move code.
            var fresh = try Self.playing(fixture)
            let fp: String = fresh.fingerprint
            #expect(throws: AuroraLoomError.move("range")) {
                try fresh.apply(AuroraLoomMove(ribbon: 3, control: .wave, step: 0), expecting: fp)
            }
            #expect(throws: AuroraLoomError.move("range")) {
                try fresh.apply(AuroraLoomMove(ribbon: 0, control: .wave, step: 16), expecting: fp)
            }
        }
    }

    /// INV-03 Goal: completion is awarded only when every sample is within tolerance (the exact boundary included).
    @Test func testAuroraLoomGoalBoundary() throws {
        var random = SeededRandom(seed: 2_303)
        for _ in 0..<100 {
            let fixture = AuroraLoomFixture.next(&random, offset: true)
            let worst: AuroraLoomMismatch = AuroraLoomHarmony.worst(fixture.winning, level: fixture.level)
            #expect(abs(worst.residual) <= fixture.level.tolerance)
            #expect(AuroraLoomHarmony.wins(fixture.winning, level: fixture.level))
            // Every neighbouring single change either still meets every gate or is not a win.
            for r in 0..<3 {
                var steps: AuroraLoomSteps = fixture.winning
                steps.phase[r] = (steps.phase[r] + 1) % 16
                let w: AuroraLoomMismatch = AuroraLoomHarmony.worst(steps, level: fixture.level)
                #expect(AuroraLoomHarmony.wins(steps, level: fixture.level) == (abs(w.residual) <= fixture.level.tolerance))
            }
        }
    }

    /// INV-04 Repeatability: a seed and trace reproduce identical fingerprints and conclusion.
    @Test func testAuroraLoomRepeatabilityBoundary() throws {
        var random = SeededRandom(seed: 2_304)
        for _ in 0..<50 {
            let fixture = AuroraLoomFixture.next(&random)
            var play = try Self.playing(fixture)
            for r in 0..<3 where play.stage == .playing {
                if play.steps.wave[r] != fixture.winning.wave[r] {
                    try play.apply(AuroraLoomMove(ribbon: r, control: .wave, step: fixture.winning.wave[r]),
                                   expecting: play.fingerprint)
                }
                if play.stage == .playing && play.steps.phase[r] != fixture.winning.phase[r] {
                    try play.apply(AuroraLoomMove(ribbon: r, control: .phase, step: fixture.winning.phase[r]),
                                   expecting: play.fingerprint)
                }
            }
            let again = try AuroraLoomPlay.replay(level: fixture.level, records: play.records)
            #expect(again == play)
            #expect(again.fingerprint == play.fingerprint)
        }
    }

    /// INV-05 Undo: undo restores the prior fingerprint exactly, success state included.
    @Test func testAuroraLoomUndoBoundary() throws {
        var random = SeededRandom(seed: 2_305)
        for _ in 0..<50 {
            let fixture = AuroraLoomFixture.next(&random)
            var play = try Self.playing(fixture)
            let before: AuroraLoomPlay = play
            let next: Int = (play.steps.wave[2] + 3) % 16
            try play.apply(AuroraLoomMove(ribbon: 2, control: .wave, step: next), expecting: play.fingerprint)
            if play.stage != .playing { continue }
            try play.undo()
            #expect(play.steps == before.steps && play.spent == before.spent && play.fingerprint == before.fingerprint)
        }
    }

    /// INV-07 Failure honesty: spending the allowance without a win fails with the worst mismatch named, no solution.
    @Test func testAuroraLoomFailurehonestyBoundary() throws {
        var random = SeededRandom(seed: 2_307)
        var failures: Int = 0
        for _ in 0..<50 {
            let fixture = AuroraLoomFixture.next(&random)
            var play = try Self.playing(fixture)
            var guardSteps: Int = 0
            while play.stage == .playing && guardSteps < 200 {
                guardSteps += 1
                var next: Int = (play.steps.wave[1] + 1) % 16
                if next == fixture.winning.wave[1] { next = (next + 1) % 16 }
                if next == play.steps.wave[1] { next = (next + 1) % 16 }
                try play.apply(AuroraLoomMove(ribbon: 1, control: .wave, step: next), expecting: play.fingerprint)
            }
            if play.stage == .failed {
                failures += 1
                let worst: AuroraLoomMismatch = AuroraLoomHarmony.worst(play.steps, level: fixture.level)
                #expect(play.failure == worst)
                #expect(abs(worst.residual) > fixture.level.tolerance)
                #expect(play.steps != fixture.winning)
            }
        }
        #expect(failures > 0)
    }

    /// INV-08 Stability: every phase, target and residual stays in its range for any reachable steps and ticks.
    @Test func testAuroraLoomStabilityBoundary() throws {
        var random = SeededRandom(seed: 2_308)
        for _ in 0..<100 {
            let fixture = AuroraLoomFixture.next(&random)
            var steps: AuroraLoomSteps = fixture.level.startSteps
            for r in 0..<3 {
                steps.wave[r] = random.int(0...15)
                steps.phase[r] = random.int(0...15)
            }
            let tick: Int = random.int(0...1_000_000)
            for r in 0..<3 {
                for g in 0..<4 {
                    let p: Int = AuroraLoomHarmony.phase(ribbon: r, gate: g, tick: tick, steps: steps, level: fixture.level)
                    let t: Int = AuroraLoomHarmony.target(gate: g, tick: tick, level: fixture.level)
                    let e: Int = AuroraLoomHarmony.residual(ribbon: r, gate: g, tick: tick, steps: steps, level: fixture.level)
                    #expect(p >= 0 && p < 4_096 && t >= 0 && t < 4_096 && e >= -2_048 && e <= 2_047)
                }
            }
        }
    }

    /// INV-09 Save: only complete, versioned, fingerprinted levels and traces are accepted.
    @Test func testAuroraLoomSaveBoundary() throws {
        var random = SeededRandom(seed: 2_309)
        for _ in 0..<30 {
            let fixture = AuroraLoomFixture.next(&random)
            let data: Data = fixture.level.encoded()
            #expect(try AuroraLoomLevel.decode(data) == fixture.level)
            // A truncated save is refused, never half-loaded.
            let cut: Data = data.prefix(data.count / 2)
            #expect(throws: AuroraLoomError.self) { try AuroraLoomLevel.decode(cut) }
            // A trace with an edited record is refused.
            var play = try Self.playing(fixture)
            let next: Int = (play.steps.phase[0] + 5) % 16
            try play.apply(AuroraLoomMove(ribbon: 0, control: .phase, step: next), expecting: play.fingerprint)
            var records: [AuroraLoomRecord] = play.records
            let first: AuroraLoomRecord = records[0]
            records[0] = AuroraLoomRecord(schema: first.schema, seed: first.seed, tick: first.tick, kind: first.kind,
                                          ribbon: first.ribbon, control: first.control, step: first.step,
                                          previous: first.previous, next: String(repeating: "0", count: 64))
            #expect(throws: AuroraLoomError.self) { try AuroraLoomPlay.replay(level: fixture.level, records: records) }
        }
    }
}
