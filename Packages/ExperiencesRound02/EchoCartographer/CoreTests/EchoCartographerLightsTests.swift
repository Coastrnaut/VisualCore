// EchoCartographerLightsTests — feature 406 (R02-G11-06) T-R02G1106-004 (FR-R02G1106-004; SC-R02G1106-003;
// clarification Q3). The eased lights over kernel plays of the hand level (`EchoCartographerFixtures.handLevel`: entry
// (0, 0), beacons (2, 2) and (6, 0), a miss costs 2): the targets (glow 0.7 playing / 1 won / 0.35 failed, the result
// after a win staying won and after a failure staying failed; won 1 once won, else 0); settle jumps and the first step
// settles; normally a fade takes 0.15 s (9 frames at 60 Hz) and turns at once; under Reduce Flashing it takes 0.45 s
// and a started fade finishes before it turns back; bad elapsed times do nothing. A scripted win and adversarial
// flicker — a pulse that spends the last energy undone and redone every frame, a pulse and its undo, a win and its
// retry, a failure followed by level changes, a level change every frame, a missed claim's failure undone and redone —
// each with retries every 17, 45 or 300 frames, sampled every 1/60 s for 5 s under Reduce Flashing with every element
// over its own range 0 … 1: no element crosses half its range more than 3 times per second and every complete one-way
// fade of more than half the range takes at least 0.4 s. The measure itself catches a nine-frame flicker without Reduce
// Flashing. No randomness; explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import EchoCartographerCore

@Suite struct EchoCartographerLightsTests {
    typealias Lights = EchoCartographerLights
    typealias Play = EchoCartographerPlay
    typealias Snapshot = EchoCartographerSceneSnapshot
    typealias Level = EchoCartographerLevel
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60

    /// The hand level with 1 energy: the opening pulse spends it and fails the level; the two hits alone win.
    static let lowLevel: Level = EchoCartographerFixtures.handLevel(energy: 1)
    /// The hand level with 3 energy: a pulse and one missed claim (cost 2) fail it.
    static let missLevel: Level = EchoCartographerFixtures.handLevel(energy: 3, missCost: 2)
    /// The hand level with 6 energy: the pulse and the two hits win it.
    static let richLevel: Level = EchoCartographerFixtures.handLevel()

    /// The pulse from the entry.
    static let pulse: EchoCartographerAction = .pulse(0, 0)
    /// The claim on the first beacon (a hit).
    static let firstHit: EchoCartographerAction = .claim(2, 2)
    /// The claim on the second beacon (a hit; the last one wins).
    static let secondHit: EchoCartographerAction = .claim(6, 0)
    /// A claim far from both beacons (a miss).
    static let miss: EchoCartographerAction = .claim(0, 4)

    /// One frame of a script: a kernel action, an undo, a redo, a retry of the primary level, a change to the other
    /// level, or nothing.
    enum Step {
        case act(EchoCartographerAction)
        case undo
        case redo
        case retry
        case other
        case idle
    }

    /// A fresh play of `level` in stage `playing`.
    static func fresh(_ level: Level) throws -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// Applies `action` to `play`; true when accepted.
    static func act(_ action: EchoCartographerAction, _ play: inout Play) -> Bool {
        do {
            try play.apply(action, expecting: play.fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// `play` after `actions`, every one of which must be accepted.
    static func played(_ level: Level, _ actions: [EchoCartographerAction]) throws -> Play {
        var play: Play = try fresh(level)
        for action in actions { #expect(act(action, &play), "\(action)") }
        return play
    }

    /// The snapshot of `play` at time 0.
    static func snap(_ play: Play) -> Snapshot { Snapshot(play: play, levelNumber: 1, time: 0) }

    /// One sample of every light, each over its own range 0 … 1: the glow is the gain the scene multiplies its glow
    /// by, 0 (dark) … 1, sampled as is (its midpoint 0.5 lies between the failed 0.35 and the playing 0.7); the won
    /// brightening as it is.
    static func sample(_ lights: Lights) -> [Double] { [lights.glow, lights.won] }

    /// Checks the two flash limits on `samples` under Reduce Flashing.
    static func expectWithinLimits(_ samples: [[Double]], _ label: String) {
        let crossings: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "\(label): \(crossings) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): a half-range fade took \(shortest) s")
    }

    /// Checks that `lights` rest exactly at the targets of `snapshot`.
    static func expectAtTargets(_ lights: Lights, _ snapshot: Snapshot) {
        #expect(lights.isSettled)
        let won: Bool = snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil)
        let glow: Double = won ? 1 : (snapshot.failure == nil ? 0.7 : 0.35)
        #expect(lights.glow == glow)
        #expect(lights.won == (won ? 1 : 0))
    }

    /// The opening, won and failed snapshots of the hand levels.
    static func stages() throws -> (start: Snapshot, won: Snapshot, failed: Snapshot) {
        let start: Snapshot = snap(try fresh(richLevel))
        let won: Snapshot = snap(try played(richLevel, [pulse, firstHit, secondHit]))
        let failed: Snapshot = snap(try played(lowLevel, [pulse]))
        #expect(won.stage == .won && failed.stage == .failed && start.stage == .playing)
        return (start, won, failed)
    }

    @Test func settleJumpsToTheTargetsOfEveryStage() throws {
        let (start, won, failed): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.glow == 0 && lights.won == 0)
        lights.settle(to: won)
        Self.expectAtTargets(lights, won)
        #expect(lights.glow == 1 && lights.won == 1)
        lights.settle(to: failed)
        Self.expectAtTargets(lights, failed)
        #expect(lights.glow == 0.35 && lights.won == 0)
        lights.settle(to: start)
        Self.expectAtTargets(lights, start)
        #expect(lights.glow == 0.7 && lights.won == 0)
        // The first step also settles.
        var first: Lights = Lights(reducedFlash: false)
        first.step(toward: won, elapsed: Self.frame)
        Self.expectAtTargets(first, won)
        // A missed claim that spends the last energy fails as a pulse does.
        let missed: Snapshot = Self.snap(try Self.played(Self.missLevel, [Self.pulse, Self.miss]))
        #expect(missed.stage == .failed)
        lights.settle(to: missed)
        #expect(lights.glow == 0.35 && lights.won == 0)
    }

    @Test func theResultAfterAWinStaysWonAndAfterAFailureStaysFailed() throws {
        var winning: Play = try Self.played(Self.richLevel, [Self.pulse, Self.firstHit, Self.secondHit])
        try winning.handle(.showResult)
        let wonResult: Snapshot = Self.snap(winning)
        #expect(wonResult.stage == .result && Lights.isWon(wonResult) && !Lights.isFailed(wonResult))
        var failing: Play = try Self.played(Self.lowLevel, [Self.pulse])
        try failing.handle(.showResult)
        let failedResult: Snapshot = Self.snap(failing)
        #expect(failedResult.stage == .result && !Lights.isWon(failedResult) && Lights.isFailed(failedResult))
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: wonResult)
        #expect(lights.glow == 1 && lights.won == 1)
        lights.settle(to: failedResult)
        #expect(lights.glow == 0.35 && lights.won == 0)
        // Paused plays glow as playing.
        var paused: Play = try Self.fresh(Self.richLevel)
        try paused.handle(.pause)
        lights.settle(to: Self.snap(paused))
        #expect(lights.glow == 0.7 && lights.won == 0)
    }

    @Test func normalFadesTakeTheNormalDurationAndTurnAtOnce() throws {
        let (start, won, failed): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        let frames: Int = Int((Lights.normalDuration * Self.frameRate).rounded())
        #expect(frames == 9)
        let froms: [Snapshot] = [start, won, start, failed, won, failed]
        let tos: [Snapshot] = [won, start, failed, start, failed, won]
        for index in froms.indices {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: froms[index])
            for _ in 0..<(frames - 1) { lights.step(toward: tos[index], elapsed: Self.frame) }
            #expect(!lights.isSettled, "pair \(index)")
            lights.step(toward: tos[index], elapsed: Self.frame)
            Self.expectAtTargets(lights, tos[index])
        }
        // Normally a changed target turns a fade at once: partway into failing, the undo heads back.
        var turning: Lights = Lights(reducedFlash: false)
        turning.settle(to: start)
        for _ in 0..<4 { turning.step(toward: failed, elapsed: Self.frame) }
        let mid: Double = turning.glow
        #expect(mid < 0.7 && mid > 0.35)
        turning.step(toward: start, elapsed: Self.frame)
        #expect(turning.glow > mid)
        // Under Reduce Flashing the same change takes 0.45 s (27 frames) and a started fade finishes first.
        var slow: Lights = Lights(reducedFlash: true)
        slow.settle(to: start)
        for _ in 0..<26 { slow.step(toward: failed, elapsed: Self.frame) }
        #expect(!slow.isSettled)
        slow.step(toward: failed, elapsed: Self.frame)
        Self.expectAtTargets(slow, failed)
        var firm: Lights = Lights(reducedFlash: true)
        firm.settle(to: start)
        for _ in 0..<4 { firm.step(toward: failed, elapsed: Self.frame) }
        let started: Double = firm.glow
        firm.step(toward: start, elapsed: Self.frame)
        #expect(firm.glow < started)
        for _ in 0..<22 { firm.step(toward: start, elapsed: Self.frame) }
        #expect(firm.glow == 0.35 && !firm.isSettled)
        // Then it turns back, and reaches the playing glow 27 frames later.
        for _ in 0..<27 { firm.step(toward: start, elapsed: Self.frame) }
        Self.expectAtTargets(firm, start)
    }

    @Test func badElapsedTimesDoNothing() throws {
        let (start, won, _): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: start)
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: won, elapsed: elapsed)
            #expect(lights.glow == 0.7 && lights.won == 0, "\(elapsed)")
        }
        #expect(!lights.isSettled)
        lights.step(toward: won, elapsed: Self.frame)
        #expect(lights.glow > 0.7 && lights.won > 0)
    }

    /// Applies `step` to `play` (retry and other start fresh plays of `primary` and `secondary`); true when accepted.
    static func perform(_ step: Step, _ play: inout Play, primary: Level, secondary: Level) throws -> Bool {
        switch step {
        case .act(let action):
            return act(action, &play)
        case .undo:
            do {
                try play.undo()
                return true
            } catch {
                return false
            }
        case .redo:
            do {
                try play.redo()
                return true
            } catch {
                return false
            }
        case .retry:
            play = try fresh(primary)
            return true
        case .other:
            play = try fresh(secondary)
            return true
        case .idle:
            return false
        }
    }

    /// Runs `frames` frames of `steps` (one per frame, refusals allowed) on `primary` under `reducedFlash`, retrying
    /// `primary` every `retryEvery` frames; returns the samples and the number of accepted steps.
    static func flicker(_ steps: [Step], primary: Level, frames: Int, retryEvery: Int,
                        reducedFlash: Bool = true) throws -> ([[Double]], Int) {
        let secondary: Level = primary == richLevel ? lowLevel : richLevel
        var play: Play = try fresh(primary)
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: snap(play))
        var samples: [[Double]] = [sample(lights)]
        var accepted: Int = 0
        for index in 0..<frames {
            let step: Step = index > 0 && index % retryEvery == 0 ? .retry : steps[index % steps.count]
            if try perform(step, &play, primary: primary, secondary: secondary) { accepted += 1 }
            lights.step(toward: snap(play), elapsed: frame)
            samples.append(sample(lights))
        }
        return (samples, accepted)
    }

    @Test func aScriptedWinStaysWithinTheLimits() throws {
        var play: Play = try Self.fresh(Self.richLevel)
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: Self.snap(play))
        var samples: [[Double]] = [Self.sample(lights)]
        let script: [EchoCartographerAction] = [Self.pulse, Self.firstHit, Self.secondHit]
        for action in script {
            #expect(Self.act(action, &play))
            lights.step(toward: Self.snap(play), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        #expect(play.stage == .won)
        for _ in 0..<60 {
            lights.step(toward: Self.snap(play), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, Self.snap(play))
        #expect(lights.glow == 1 && lights.won == 1)
        // The retry dims back to playing.
        play = try Self.fresh(Self.richLevel)
        for _ in 0..<60 {
            lights.step(toward: Self.snap(play), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, Self.snap(play))
        Self.expectWithinLimits(samples, "scripted win")
    }

    /// The flicker patterns, each with its primary level and the fewest accepted steps it must make in 300 frames.
    static func patterns() -> [(name: String, primary: Level, steps: [Step], least: Int)] {
        var redone: [Step] = [.act(pulse)]
        for _ in 0..<5 { redone += [.undo, .redo] }
        redone.append(.undo)
        return [("pulse undone and redone", lowLevel, redone, 180),
                ("pulse and undo", lowLevel, [.act(pulse), .undo], 250),
                ("win and retry", lowLevel, [.act(firstHit), .act(secondHit), .retry], 250),
                ("failure and change level", lowLevel, [.act(pulse), .other, .retry], 250),
                ("change level every frame", lowLevel, [.other, .retry], 250),
                ("miss failure undone and redone", missLevel,
                 [.act(pulse), .act(miss), .undo, .redo, .undo, .redo, .undo, .undo, .retry], 200),
                ("failure, undo and win", richLevel,
                 [.act(miss), .act(miss), .act(miss), .undo, .redo, .undo, .act(firstHit), .act(secondHit), .retry],
                 150)]
    }

    @Test func adversarialFlickerStaysWithinTheLimits() throws {
        for pattern in Self.patterns() {
            for retry in [17, 45, 300] {
                let (samples, accepted): ([[Double]], Int) = try Self.flicker(pattern.steps, primary: pattern.primary,
                                                                              frames: 300, retryEvery: retry)
                let name: String = "\(pattern.name), retry \(retry)"
                #expect(accepted >= pattern.least, "\(name): \(accepted) accepted")
                #expect(samples.count == 301)
                Self.expectWithinLimits(samples, name)
            }
        }
    }

    @Test func theMeasureDetectsFastBlinking() throws {
        // A level blinking 0 ↔ 1 every frame crosses half its range 60 times a second in one-frame fades.
        var samples: [[Double]] = []
        for index in 0..<120 { samples.append([index % 2 == 0 ? 0 : 1, 0.3]) }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: 60) == 60)
        #expect(Lights.shortestHalfRangeChange(samples, frameRate: 60) == 1.0 / 60)
        #expect(Lights.maxHalfRangeCrossingsPerSecond([[0.2]], frameRate: 60) == 0)
        // Small steps near 0.5 cross without a big fade.
        var near: [[Double]] = []
        for index in 0..<60 { near.append([index % 2 == 0 ? 0.49 : 0.51]) }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(near, frameRate: 60) == 59)
        #expect(Lights.shortestHalfRangeChange(near, frameRate: 60) == .infinity)
        // Without Reduce Flashing a failure flipped every 9 frames would blink: the slower fade holds the limit.
        var steps: [Step] = [.act(Self.pulse)]
        for _ in 0..<8 { steps.append(.idle) }
        steps.append(.undo)
        for _ in 0..<8 { steps.append(.idle) }
        let (fast, _): ([[Double]], Int) = try Self.flicker(steps, primary: Self.lowLevel, frames: 243,
                                                             retryEvery: 1_000, reducedFlash: false)
        let (slow, _): ([[Double]], Int) = try Self.flicker(steps, primary: Self.lowLevel, frames: 240,
                                                             retryEvery: 1_000)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: 60) > 3)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(slow, frameRate: 60) <= 3)
        Self.expectWithinLimits(slow, "nine-frame flicker")
        // Normally every fade ends within 0.15 s of the last change: 9 frames after the run's last pulse the glow rests
        // at the failed level.
        let last: [Double] = fast[fast.count - 1]
        #expect(last[0] == 0.35 && last[1] == 0)
    }
}
