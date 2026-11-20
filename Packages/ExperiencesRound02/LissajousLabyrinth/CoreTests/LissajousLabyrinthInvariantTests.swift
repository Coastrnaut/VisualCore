// LissajousLabyrinthInvariantTests — feature 311 (R02-G02-01) T-R02G0201-006 (FR-R02G0201-010; the source's invariants
// R2-G02-INV-01 … 05 and 07 … 09, round2.md section 6.2.3). Each named test gives a direct boundary example and a seeded
// check of neighbouring inputs (seed 2,316), as the source asks. INV-06 (content witnesses), INV-10 (renderer purity) and
// INV-12 (novelty) belong to later features; INV-11 (monetization) is superseded (the experience is free).
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreSimulation

@Suite struct LissajousLabyrinthInvariantTests {
    /// A playing play of a fixture (tutorial dismissed when the level has one).
    static func playing(_ level: LissajousLabyrinthLevel) throws -> LissajousLabyrinthPlay {
        var play = LissajousLabyrinthPlay(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A valid action from `dials` (in range, changed, coprime) whose resulting dials do not win `level`; nil when the
    /// seeded draws find none.
    static func losingAction(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel,
                             random: inout SeededRandom) -> LissajousLabyrinthAction? {
        let all: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
        for _ in 0..<64 {
            let dial: LissajousLabyrinthDial = all[random.int(0...3)]
            let value: Int = random.int(dial.range)
            if value == dials[dial] { continue }
            var changed: LissajousLabyrinthDials = dials
            changed[dial] = value
            if !changed.isValid { continue }
            if LissajousLabyrinthLap.verdict(changed, level: level) == .won { continue }
            return LissajousLabyrinthAction(dial: dial, value: value)
        }
        return nil
    }

    /// A reference verdict written independently of the kernel's loop order: every contact (tick, obstacle) and the
    /// in-order checkpoint visits.
    static func referenceVerdict(_ dials: LissajousLabyrinthDials,
                                 level: LissajousLabyrinthLevel) -> LissajousLabyrinthVerdict {
        let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(dials, level: level)
        let count: Int = LissajousLabyrinthLap.ticks
        var firstTick: Int = count
        var firstObstacle: Int = -1
        for o in 0..<level.obstacles.count {
            for n in 0..<count where n < firstTick {
                if LissajousLabyrinthLap.segmentTouches(points[n], points[(n + 1) % count], ball: level.obstacles[o]) {
                    if n < firstTick || (n == firstTick && o < firstObstacle) {
                        firstTick = n
                        firstObstacle = o
                    }
                    break
                }
            }
        }
        if firstObstacle >= 0 { return .contact(obstacle: firstObstacle, tick: firstTick) }
        var next: Int = 0
        for n in 0..<count {
            if next < level.checkpoints.count && LissajousLabyrinthLap.contains(level.checkpoints[next], points[n]) {
                next += 1
            }
        }
        return next == level.checkpoints.count ? .won : .missed(checkpoint: next)
    }

    /// INV-01 Time: the lap is 4,096 integer ticks of 1/240 s; the verdict is a function of the dials and level only.
    @Test func testLissajousLabyrinthTimeBoundary() throws {
        // Direct boundary: the lap constants and the closing tick.
        #expect(LissajousLabyrinthLap.ticks == 4_096)
        #expect(LissajousLabyrinthLap.secondsPerTick == 1.0 / 240.0)
        #expect(abs(LissajousLabyrinthLap.secondsPerTick - 0.004167) < 0.000001)
        var random = SeededRandom(seed: 2_316)
        for _ in 0..<40 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            let level: LissajousLabyrinthLevel = fixture.level
            let dials: LissajousLabyrinthDials = LissajousLabyrinthFixture.dials(&random)
            // Tick 4,096 closes the lap onto tick 0; the neighbours 4,095 and 4,097 are the lap's last and second sample.
            let p0: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 0, dials: dials, level: level)
            let p1: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 1, dials: dials, level: level)
            let pLast: LissajousLabyrinthPoint = LissajousLabyrinthLap.position(tick: 4_095, dials: dials, level: level)
            #expect(LissajousLabyrinthLap.position(tick: 4_096, dials: dials, level: level) == p0)
            #expect(LissajousLabyrinthLap.position(tick: 4_097, dials: dials, level: level) == p1)
            #expect(LissajousLabyrinthLap.position(tick: -1, dials: dials, level: level) == pLast)
            // Any seeded tick repeats a whole lap later.
            let tick: Int = random.int(0...100_000)
            #expect(LissajousLabyrinthLap.position(tick: tick, dials: dials, level: level)
                == LissajousLabyrinthLap.position(tick: tick + 4_096, dials: dials, level: level))
            // The verdict has no clock input: evaluating it twice, and through a play, gives the same answer.
            let a: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(dials, level: level)
            let b: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(dials, level: level)
            #expect(a == b)
            #expect(LissajousLabyrinthLap.samples(dials, level: level).count == 4_096)
            #expect(LissajousLabyrinthLap.verdict(fixture.safe, level: level) == .won)
        }
    }

    /// INV-02 Input budget: the action that spends exactly the allowance is accepted, the next is refused; invalid
    /// frequencies and out-of-range values are refused; a refusal changes nothing.
    @Test func testLissajousLabyrinthInputbudgetBoundary() throws {
        var random = SeededRandom(seed: 2_316)
        var exhausted: Int = 0
        for _ in 0..<30 {
            let allowance: Int = random.int(1...4)
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random, allowance: allowance)
            let level: LissajousLabyrinthLevel = fixture.level
            var play = try Self.playing(level)
            // Out of range on either side of every dial, and a non-coprime frequency pair, are refused unchanged.
            let fresh: LissajousLabyrinthPlay = play
            let fp: String = play.fingerprint
            let outside: [LissajousLabyrinthAction] = [
                LissajousLabyrinthAction(dial: .frequencyA, value: 0), LissajousLabyrinthAction(dial: .frequencyA, value: 10),
                LissajousLabyrinthAction(dial: .frequencyB, value: 0), LissajousLabyrinthAction(dial: .frequencyB, value: 10),
                LissajousLabyrinthAction(dial: .phaseA, value: -1), LissajousLabyrinthAction(dial: .phaseA, value: 16),
                LissajousLabyrinthAction(dial: .phaseC, value: -1), LissajousLabyrinthAction(dial: .phaseC, value: 16),
            ]
            for action in outside {
                #expect(throws: LissajousLabyrinthError.move("range")) { try play.apply(action, expecting: fp) }
                #expect(play == fresh)
            }
            let b: Int = play.dials.frequencyB
            let a: Int = play.dials.frequencyA
            if b > 1 {
                #expect(throws: LissajousLabyrinthError.move("not-coprime")) {
                    try play.apply(LissajousLabyrinthAction(dial: .frequencyA, value: b), expecting: fp)
                }
            } else if a > 1 {
                #expect(throws: LissajousLabyrinthError.move("not-coprime")) {
                    try play.apply(LissajousLabyrinthAction(dial: .frequencyB, value: a), expecting: fp)
                }
            }
            #expect(throws: LissajousLabyrinthError.move("no-change")) {
                try play.apply(LissajousLabyrinthAction(dial: .phaseA, value: play.dials.phaseA), expecting: fp)
            }
            #expect(play == fresh)
            // Seeded neighbouring refusals: a value one past either end of a random dial, and a stale fingerprint.
            for _ in 0..<8 {
                let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[random.int(0...3)]
                let value: Int = random.int(0...1) == 0 ? dial.range.lowerBound - 1 : dial.range.upperBound + 1
                #expect(throws: LissajousLabyrinthError.move("range")) {
                    try play.apply(LissajousLabyrinthAction(dial: dial, value: value), expecting: fp)
                }
                #expect(throws: LissajousLabyrinthError.stale) {
                    try play.apply(LissajousLabyrinthAction(dial: .phaseC, value: (play.dials.phaseC + 1) % 16),
                                   expecting: String(repeating: "0", count: 64))
                }
                #expect(play == fresh)
            }
            // Spend the allowance on losing actions: the last one (spent == allowance) is accepted and fails the play.
            var spentAll: Bool = true
            for k in 0..<allowance {
                guard let action = Self.losingAction(play.dials, level: level, random: &random) else {
                    spentAll = false
                    break
                }
                try play.apply(action, expecting: play.fingerprint)
                #expect(play.spent == k + 1)
            }
            if !spentAll { continue }
            exhausted += 1
            #expect(play.spent == allowance)
            #expect(play.stage == .failed)
            // The next action is refused and changes nothing.
            let ended: LissajousLabyrinthPlay = play
            if let action = Self.losingAction(play.dials, level: level, random: &random) {
                #expect(throws: LissajousLabyrinthError.self) { try play.apply(action, expecting: play.fingerprint) }
            }
            #expect(throws: LissajousLabyrinthError.stage) { try play.redo() }
            #expect(play == ended)
        }
        #expect(exhausted > 0)
    }

    /// INV-03 Goal: a lap wins only when every checkpoint is visited in order with no contact; a sample on the
    /// checkpoint's surface (squared distance r²) is a visit, r² + 1 is not.
    @Test func testLissajousLabyrinthGoalBoundary() throws {
        var random = SeededRandom(seed: 2_316)
        for _ in 0..<20 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            let level: LissajousLabyrinthLevel = fixture.level
            #expect(LissajousLabyrinthLap.verdict(fixture.safe, level: level) == .won)
            // Direct boundary on a sample of the safe lap.
            let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(fixture.safe, level: level)
            let p: LissajousLabyrinthPoint = points[random.int(0...4_095)]
            let r: Int = random.int(64...1_024)
            let sx: Int = p.x > 0 ? -1 : 1
            let sy: Int = p.y > 0 ? -1 : 1
            let onSurface = try LissajousLabyrinthBall(x: p.x + sx * r, y: p.y, z: p.z, radius: r)
            let justOutside = try LissajousLabyrinthBall(x: p.x + sx * r, y: p.y + sy, z: p.z, radius: r)
            #expect(LissajousLabyrinthLap.contains(onSurface, p))
            #expect(!LissajousLabyrinthLap.contains(justOutside, p))
            // A lone checkpoint on the surface of a sample is visited: the lap wins (there are no obstacles).
            var start: LissajousLabyrinthDials = LissajousLabyrinthFixture.dials(&random)
            while start == fixture.safe { start = LissajousLabyrinthFixture.dials(&random) }
            if let surfaceLevel = try? LissajousLabyrinthLevel(id: "surface", seed: 1, band: 1, amplitudes: level.amplitudes,
                                                               frequencyC: level.frequencyC, start: start,
                                                               checkpoints: [onSurface], obstacles: [], allowance: 4) {
                #expect(LissajousLabyrinthLap.verdict(fixture.safe, level: surfaceLevel) == .won)
            }
            // Order matters: the checkpoints reversed must be visited in the reversed order to win.
            if level.checkpoints.count >= 2 {
                let reversed: [LissajousLabyrinthBall] = Array(level.checkpoints.reversed())
                if let reversedLevel = try? LissajousLabyrinthLevel(id: "reversed", seed: 1, band: 1,
                                                                    amplitudes: level.amplitudes,
                                                                    frequencyC: level.frequencyC, start: level.start,
                                                                    checkpoints: reversed, obstacles: level.obstacles,
                                                                    allowance: 4) {
                    #expect(LissajousLabyrinthLap.verdict(fixture.safe, level: reversedLevel)
                        == Self.referenceVerdict(fixture.safe, level: reversedLevel))
                }
            }
            // Seeded neighbouring settings: every valid single-dial neighbour of the winning setting wins exactly when
            // the reference finds no contact and every checkpoint in order.
            for dial in LissajousLabyrinthDial.allCases {
                for delta in [-1, 1] {
                    var near: LissajousLabyrinthDials = fixture.safe
                    near[dial] = fixture.safe[dial] + delta
                    if !near.isValid { continue }
                    let verdict: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(near, level: level)
                    #expect(verdict == Self.referenceVerdict(near, level: level))
                }
            }
        }
    }

    /// INV-04 Repeatability: replaying a trace reproduces every record, fingerprint and the outcome; an edited record is
    /// refused.
    @Test func testLissajousLabyrinthRepeatabilityBoundary() throws {
        var random = SeededRandom(seed: 2_316)
        for _ in 0..<25 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random, allowance: 8)
            let level: LissajousLabyrinthLevel = fixture.level
            var play = try Self.playing(level)
            // A seeded trace of actions, undos and redos.
            var guardSteps: Int = 0
            while play.stage == .playing && guardSteps < 12 {
                guardSteps += 1
                let roll: Int = random.int(0...5)
                if roll == 0 && play.canUndo {
                    try play.undo()
                } else if roll == 1 && play.canRedo {
                    try play.redo()
                } else if let action = Self.losingAction(play.dials, level: level, random: &random) {
                    try play.apply(action, expecting: play.fingerprint)
                }
            }
            if play.records.isEmpty { continue }
            let again: LissajousLabyrinthPlay = try LissajousLabyrinthPlay.replay(level: level, records: play.records)
            #expect(again == play)
            #expect(again.records == play.records)
            #expect(again.fingerprint == play.fingerprint)
            #expect(again.stage == play.stage && again.failure == play.failure)
            // Each record chains: its previous is the prior record's next.
            for i in 1..<play.records.count {
                #expect(play.records[i].previous == play.records[i - 1].next)
                #expect(play.records[i].tick == i)
            }
            // Neighbouring traces: one record with an edited value, previous or next is refused.
            let index: Int = random.int(0...(play.records.count - 1))
            let r: LissajousLabyrinthRecord = play.records[index]
            var edits: [LissajousLabyrinthRecord] = []
            let otherValue: Int = r.dial.range.contains(r.value + 1) ? r.value + 1 : r.value - 1
            edits.append(LissajousLabyrinthRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind, dial: r.dial,
                                                  value: otherValue, previous: r.previous, next: r.next))
            edits.append(LissajousLabyrinthRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind, dial: r.dial,
                                                  value: r.value, previous: String(repeating: "a", count: 64),
                                                  next: r.next))
            edits.append(LissajousLabyrinthRecord(schema: r.schema, seed: r.seed, tick: r.tick, kind: r.kind, dial: r.dial,
                                                  value: r.value, previous: r.previous,
                                                  next: String(repeating: "0", count: 64)))
            edits.append(LissajousLabyrinthRecord(schema: r.schema, seed: r.seed &+ 1, tick: r.tick, kind: r.kind,
                                                  dial: r.dial, value: r.value, previous: r.previous, next: r.next))
            for edited in edits {
                var records: [LissajousLabyrinthRecord] = play.records
                records[index] = edited
                #expect(throws: LissajousLabyrinthError.self) {
                    try LissajousLabyrinthPlay.replay(level: level, records: records)
                }
            }
        }
    }

    /// INV-05 Undo: undo restores the exact prior state and fingerprint; nothing to undo and a finished play refuse it.
    @Test func testLissajousLabyrinthUndoBoundary() throws {
        var random = SeededRandom(seed: 2_316)
        var wins: Int = 0
        for _ in 0..<30 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random, allowance: 8)
            let level: LissajousLabyrinthLevel = fixture.level
            var play = try Self.playing(level)
            // Direct boundary: nothing to undo or redo at zero actions.
            let start: LissajousLabyrinthPlay = play
            #expect(throws: LissajousLabyrinthError.move("nothing-to-undo")) { try play.undo() }
            #expect(throws: LissajousLabyrinthError.move("nothing-to-redo")) { try play.redo() }
            #expect(play == start)
            // Seeded: each losing action undone restores dials, spent and fingerprint; redo restores the after state.
            var history: [String] = [play.fingerprint]
            for _ in 0..<3 {
                guard let action = Self.losingAction(play.dials, level: level, random: &random) else { break }
                let before: LissajousLabyrinthPlay = play
                try play.apply(action, expecting: play.fingerprint)
                if play.stage != .playing { break }
                let after: String = play.fingerprint
                try play.undo()
                #expect(play.dials == before.dials && play.spent == before.spent)
                #expect(play.fingerprint == before.fingerprint)
                try play.redo()
                #expect(play.fingerprint == after)
                history.append(after)
            }
            // Unwinding every action walks the fingerprints back to the start.
            var k: Int = history.count - 1
            while play.canUndo {
                try play.undo()
                k -= 1
                #expect(play.fingerprint == history[k])
            }
            #expect(play.dials == level.start && play.spent == 0)
            // A won play cannot be undone into play (undo is accepted only while playing).
            var winner = try Self.playing(level)
            for dial in LissajousLabyrinthDial.allCases where winner.stage == .playing {
                if winner.dials[dial] == fixture.safe[dial] { continue }
                var changed: LissajousLabyrinthDials = winner.dials
                changed[dial] = fixture.safe[dial]
                if !changed.isValid { continue }
                try winner.apply(LissajousLabyrinthAction(dial: dial, value: fixture.safe[dial]),
                                 expecting: winner.fingerprint)
            }
            if winner.stage == .won {
                wins += 1
                let won: LissajousLabyrinthPlay = winner
                #expect(throws: LissajousLabyrinthError.stage) { try winner.undo() }
                #expect(winner == won)
            }
        }
        #expect(wins > 0)
    }

    /// INV-07 Failure honesty: a failed play names the first contact (obstacle, tick) or the first missed checkpoint,
    /// equal to the lap verdict, and the dials stay where the player left them (no automatic solution).
    @Test func testLissajousLabyrinthFailurehonestyBoundary() throws {
        var random = SeededRandom(seed: 2_316)
        var failures: Int = 0
        for _ in 0..<40 {
            let allowance: Int = random.int(1...3)
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random, allowance: allowance)
            let level: LissajousLabyrinthLevel = fixture.level
            var play = try Self.playing(level)
            var last: LissajousLabyrinthDials = play.dials
            while play.stage == .playing {
                guard let action = Self.losingAction(play.dials, level: level, random: &random) else { break }
                try play.apply(action, expecting: play.fingerprint)
                last[action.dial] = action.value
            }
            guard play.stage == .failed else { continue }
            failures += 1
            let verdict: LissajousLabyrinthVerdict = LissajousLabyrinthLap.verdict(play.dials, level: level)
            #expect(play.failure == verdict)
            #expect(verdict != .won)
            #expect(verdict == Self.referenceVerdict(play.dials, level: level))
            #expect(play.dials == last)
            #expect(play.dials != fixture.safe)
            let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(play.dials, level: level)
            switch verdict {
            case .contact(let obstacle, let tick):
                // The named segment touches the named obstacle; no earlier segment touches any obstacle.
                #expect(LissajousLabyrinthLap.segmentTouches(points[tick], points[(tick + 1) % 4_096],
                                                             ball: level.obstacles[obstacle]))
                for o in 0..<obstacle {
                    #expect(!LissajousLabyrinthLap.segmentTouches(points[tick], points[(tick + 1) % 4_096],
                                                                  ball: level.obstacles[o]))
                }
            case .missed(let checkpoint):
                #expect(checkpoint >= 0 && checkpoint < level.checkpoints.count)
            case .won:
                Issue.record("a failed play cannot carry a won verdict")
            }
            // The failed play refuses every further change and shows its result.
            #expect(throws: LissajousLabyrinthError.stage) { try play.undo() }
            try play.handle(.showResult)
            #expect(play.stage == .result && play.failure == verdict)
        }
        #expect(failures > 0)
    }

    /// INV-08 Stability: every coordinate stays within ±4·1,024; ball ranges are enforced at their edges; the integer
    /// segment test cannot overflow.
    @Test func testLissajousLabyrinthStabilityBoundary() throws {
        // Direct boundary: ball ranges, accepted at the edge and refused one past it.
        _ = try LissajousLabyrinthBall(x: 5_000, y: -5_000, z: 0, radius: 64)
        _ = try LissajousLabyrinthBall(x: 0, y: 0, z: 0, radius: 1_024)
        #expect(throws: LissajousLabyrinthError.level("centre")) {
            try LissajousLabyrinthBall(x: 5_001, y: 0, z: 0, radius: 64)
        }
        #expect(throws: LissajousLabyrinthError.level("centre")) {
            try LissajousLabyrinthBall(x: 0, y: -5_001, z: 0, radius: 64)
        }
        #expect(throws: LissajousLabyrinthError.level("radius")) {
            try LissajousLabyrinthBall(x: 0, y: 0, z: 0, radius: 63)
        }
        #expect(throws: LissajousLabyrinthError.level("radius")) {
            try LissajousLabyrinthBall(x: 0, y: 0, z: 0, radius: 1_025)
        }
        // The worst-case products of the segment test fit in Int: |coordinate difference| ≤ 4,096 + 5,000 per axis.
        let span: Int = 4 * LissajousLabyrinthSine.scale + 5_000
        let worstSquare: Double = 3.0 * Double(span) * Double(span)
        let worstProduct: Double = worstSquare * worstSquare + worstSquare * worstSquare
        #expect(worstProduct < Double(Int.max) / 4)
        let corner = try LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 1_024)
        let p = LissajousLabyrinthPoint(x: -4_096, y: -4_096, z: -4_096)
        let q = LissajousLabyrinthPoint(x: 4_096, y: 4_096, z: 4_096)
        #expect(Self.checkedTouches(p, q, ball: corner) == LissajousLabyrinthLap.segmentTouches(p, q, ball: corner))
        // Seeded: every sample of every lap is in range for amplitudes 1 … 4, and seeded segments agree with a checked
        // (overflow-reporting) computation.
        var random = SeededRandom(seed: 2_316)
        for _ in 0..<20 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            let dials: LissajousLabyrinthDials = LissajousLabyrinthFixture.dials(&random)
            let points: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(dials, level: fixture.level)
            var inRange: Bool = true
            for point in points {
                let ax: Int = fixture.level.amplitudes[0] * 1_024
                let ay: Int = fixture.level.amplitudes[1] * 1_024
                let az: Int = fixture.level.amplitudes[2] * 1_024
                if abs(point.x) > ax || abs(point.y) > ay || abs(point.z) > az { inRange = false }
                if abs(point.x) > 4_096 || abs(point.y) > 4_096 || abs(point.z) > 4_096 { inRange = false }
            }
            #expect(inRange)
            for _ in 0..<50 {
                let a = LissajousLabyrinthPoint(x: random.int(-4_096...4_096), y: random.int(-4_096...4_096),
                                                z: random.int(-4_096...4_096))
                let b = LissajousLabyrinthPoint(x: random.int(-4_096...4_096), y: random.int(-4_096...4_096),
                                                z: random.int(-4_096...4_096))
                let ball = try LissajousLabyrinthBall(x: random.int(-5_000...5_000), y: random.int(-5_000...5_000),
                                                      z: random.int(-5_000...5_000), radius: random.int(64...1_024))
                #expect(Self.checkedTouches(a, b, ball: ball) == LissajousLabyrinthLap.segmentTouches(a, b, ball: ball))
            }
        }
    }

    /// The segment test computed with overflow-reporting arithmetic; nil when any product overflows.
    static func checkedTouches(_ p: LissajousLabyrinthPoint, _ q: LissajousLabyrinthPoint,
                               ball: LissajousLabyrinthBall) -> Bool? {
        func mul(_ a: Int, _ b: Int) -> Int? {
            let r = a.multipliedReportingOverflow(by: b)
            return r.overflow ? nil : r.partialValue
        }
        func dot(_ a: [Int], _ b: [Int]) -> Int? {
            var total: Int = 0
            for i in 0..<3 {
                guard let m = mul(a[i], b[i]) else { return nil }
                let s = total.addingReportingOverflow(m)
                if s.overflow { return nil }
                total = s.partialValue
            }
            return total
        }
        guard let r2 = mul(ball.radius, ball.radius) else { return nil }
        let d: [Int] = [q.x - p.x, q.y - p.y, q.z - p.z]
        let w: [Int] = [ball.x - p.x, ball.y - p.y, ball.z - p.z]
        guard let wd = dot(w, d), let ww = dot(w, w) else { return nil }
        if wd <= 0 { return ww < r2 }
        guard let dd = dot(d, d) else { return nil }
        if wd >= dd {
            let e: [Int] = [ball.x - q.x, ball.y - q.y, ball.z - q.z]
            guard let ee = dot(e, e) else { return nil }
            return ee < r2
        }
        guard let left = mul(ww, dd), let wd2 = mul(wd, wd), let right = mul(r2, dd) else { return nil }
        let diff = left.subtractingReportingOverflow(wd2)
        if diff.overflow { return nil }
        return diff.partialValue < right
    }

    /// INV-09 Save: the stored level round-trips byte for byte; truncated, edited and newer forms are refused.
    @Test func testLissajousLabyrinthSaveBoundary() throws {
        var random = SeededRandom(seed: 2_316)
        for _ in 0..<20 {
            let fixture: LissajousLabyrinthFixture = LissajousLabyrinthFixture.next(&random)
            let level: LissajousLabyrinthLevel = fixture.level
            let data: Data = level.encoded()
            // Direct boundary: the complete form round-trips byte for byte.
            let decoded: LissajousLabyrinthLevel = try LissajousLabyrinthLevel.decode(data)
            #expect(decoded == level)
            #expect(decoded.encoded() == data)
            // A form cut by one byte is refused, never half-loaded.
            #expect(throws: LissajousLabyrinthError.self) { try LissajousLabyrinthLevel.decode(data.prefix(data.count - 1)) }
            #expect(throws: LissajousLabyrinthError.self) { try LissajousLabyrinthLevel.decode(data.prefix(data.count / 2)) }
            // One edited field breaks the fingerprint; a newer schema is refused as such.
            let text: String = String(decoding: data, as: UTF8.self)
            let allowanceKey: String = "\"allowance\":\(level.allowance)"
            let edited: String = text.replacingOccurrences(of: allowanceKey,
                                                           with: "\"allowance\":\(level.allowance % 64 + 1)")
            #expect(edited != text)
            #expect(throws: LissajousLabyrinthError.malformed("fingerprint")) {
                try LissajousLabyrinthLevel.decode(Data(edited.utf8))
            }
            let newer: String = text.replacingOccurrences(of: "\"schema\":1,", with: "\"schema\":2,")
            #expect(newer != text)
            #expect(throws: LissajousLabyrinthError.newerSchema(2)) { try LissajousLabyrinthLevel.decode(Data(newer.utf8)) }
            // Seeded neighbouring forms: any single byte replaced by another is refused.
            var bytes: [UInt8] = Array(data)
            for _ in 0..<10 {
                let index: Int = random.int(0...(bytes.count - 1))
                let original: UInt8 = bytes[index]
                var replacement: UInt8 = UInt8(random.int(32...126))
                if replacement == original { replacement = original == 48 ? 49 : 48 }
                bytes[index] = replacement
                #expect(throws: LissajousLabyrinthError.self) { try LissajousLabyrinthLevel.decode(Data(bytes)) }
                bytes[index] = original
            }
        }
    }
}
