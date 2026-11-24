// AcousticConstellatorLightsTests — feature 426 (R02-G13-06) T-R02G1306-004 (FR-R02G1306-004; SC-R02G1306-003;
// clarification Q3). The eased lights over kernel plays of the hand level (`AcousticConstellatorFixtures.handLevel`:
// linking star 1 to star 2 and listening wins; listening at once fails `missing`; a copy with a budget of 1, where the
// link spends the last action and fails `budget`): the targets (glow 0.7 playing / 1 won / 0.35 failed, the result after
// a win staying won and after a failure staying failed; won 1 once won, else 0); settle jumps and the first step
// settles; normally a fade takes 0.15 s (9 frames at 60 Hz) and turns at once; under Reduce Flashing it takes 0.45 s and
// a started fade finishes before it turns back; bad elapsed times do nothing. A scripted win and adversarial flicker —
// a link that spends the last action undone and redone every frame, a failed listen and its undo, a win and its retry,
// a failure followed by level changes, a level change every frame, a failure undone then a win — each with retries
// every 17, 45 or 300 frames, sampled every 1/60 s for 5 s under Reduce Flashing with every element over its own range
// 0 … 1: no element crosses half its range more than 3 times per second and every complete one-way fade of more than
// half the range takes at least 0.4 s. The measure itself catches a nine-frame flicker without Reduce Flashing. No
// randomness, no clocks; explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import AcousticConstellatorCore

@Suite struct AcousticConstellatorLightsTests {
    typealias Lights = AcousticConstellatorLights
    typealias Play = AcousticConstellatorPlay
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Level = AcousticConstellatorLevel
    typealias Action = AcousticConstellatorAction
    /// The sampling rate, in frames per second.
    static let frameRate: Double = 60
    /// One frame, in seconds.
    static let frame: Double = 1 / 60

    /// The hand level with action budget `budget` (otherwise as `AcousticConstellatorFixtures.handLevel()`).
    static func handLevel(budget: Int) -> Level {
        let stars: [AcousticConstellatorStar] = [AcousticConstellatorStar(x: 1, y: 2, z: 3, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 4, y: 5, z: 6, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 7, y: 8, z: 9, rate: 1, phase: 1)]
        do {
            return try Level(id: "hand-three-\(budget)", seed: 9, difficulty: 1, stars: stars,
                             fixedLinks: [AcousticConstellatorLink(a: 0, b: 1)],
                             symbol: [AcousticConstellatorLink(a: 0, b: 1), AcousticConstellatorLink(a: 1, b: 2)],
                             coupling: 2, degreeLimit: 2, linkLimit: 3, snapLimit: 2, threshold: 9, hold: 3,
                             window: 6, budget: budget)
        } catch {
            preconditionFailure("the hand level is valid: \(error)")
        }
    }

    /// The hand level with a budget of 1: the winning link spends it and fails the level; a listen alone fails it.
    static let lowLevel: Level = handLevel(budget: 1)
    /// The hand level with a budget of 5: the winning link and the listen win it.
    static let richLevel: Level = AcousticConstellatorFixtures.handLevel()

    /// The link that completes the symbol (star 1 to star 2).
    static let winningLink: Action = .link(1, 2)
    /// A nudge of star 2 away from its phase; ``retune`` brings it back.
    static let detune: Action = .nudge(2, 1)
    /// The nudge that brings star 2 back.
    static let retune: Action = .nudge(2, -1)
    /// The listen.
    static let listen: Action = .listen

    /// One frame of a script: a kernel action, an undo, a redo, a retry of the primary level, a change to the other
    /// level, or nothing.
    enum Step {
        /// A kernel action.
        case act(Action)
        /// An undo.
        case undo
        /// A redo.
        case redo
        /// A fresh play of the primary level.
        case retry
        /// A fresh play of the other level.
        case other
        /// Nothing.
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
    static func act(_ action: Action, _ play: inout Play) -> Bool {
        do {
            try play.apply(action, expecting: play.fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// `play` after `actions`, every one of which must be accepted.
    static func played(_ level: Level, _ actions: [Action]) throws -> Play {
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

    /// The opening, won and failed snapshots of the hand level.
    static func stages() throws -> (start: Snapshot, won: Snapshot, failed: Snapshot) {
        let start: Snapshot = snap(try fresh(richLevel))
        let won: Snapshot = snap(try played(richLevel, [winningLink, listen]))
        let failed: Snapshot = snap(try played(richLevel, [listen]))
        #expect(won.stage == .won && failed.stage == .failed && start.stage == .playing)
        return (start, won, failed)
    }

    @Test func settleJumpsToTheTargetsOfEveryStage() throws {
        let (start, won, failed): (Snapshot, Snapshot, Snapshot) = try Self.stages()
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.glow == 0 && lights.won == 0)
        #expect(Lights.normalDuration == 0.15 && Lights.reducedFlashDuration == 0.45)
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
        // A link that spends the last action fails as a failed listen does.
        let spent: Snapshot = Self.snap(try Self.played(Self.lowLevel, [Self.winningLink]))
        #expect(spent.stage == .failed)
        lights.settle(to: spent)
        #expect(lights.glow == 0.35 && lights.won == 0)
    }

    @Test func theResultAfterAWinStaysWonAndAfterAFailureStaysFailed() throws {
        var winning: Play = try Self.played(Self.richLevel, [Self.winningLink, Self.listen])
        try winning.handle(.showResult)
        let wonResult: Snapshot = Self.snap(winning)
        #expect(wonResult.stage == .result && Lights.isWon(wonResult) && !Lights.isFailed(wonResult))
        var failing: Play = try Self.played(Self.richLevel, [Self.listen])
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
        #expect(Int((Lights.reducedFlashDuration * Self.frameRate).rounded()) == 27)
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
    /// `primary` every `retryEvery` frames and changing to `secondary` on `.other`; returns the samples and the number
    /// of accepted steps.
    static func flicker(_ steps: [Step], primary: Level, secondary: Level, frames: Int, retryEvery: Int,
                        reducedFlash: Bool = true) throws -> ([[Double]], Int) {
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
        let script: [Action] = [Self.detune, Self.retune, Self.winningLink, Self.listen]
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

    /// The flicker patterns, each with its levels and the fewest accepted steps it must make in 300 frames.
    static func patterns() -> [(name: String, primary: Level, secondary: Level, steps: [Step], least: Int)] {
        var redone: [Step] = [.act(winningLink)]
        for _ in 0..<5 { redone += [.undo, .redo] }
        redone.append(.undo)
        return [("link undone and redone", lowLevel, richLevel, redone, 180),
                ("failed listen and undo", richLevel, lowLevel, [.act(listen), .undo], 250),
                ("win and retry", richLevel, lowLevel, [.act(winningLink), .act(listen), .retry], 250),
                ("failure and change level", lowLevel, richLevel, [.act(winningLink), .other, .retry], 250),
                ("change level every frame", lowLevel, richLevel, [.other, .retry], 250),
                ("win, failure and level change", richLevel, lowLevel,
                 [.act(winningLink), .act(listen), .other, .act(winningLink), .undo, .redo, .retry], 200),
                ("failure, undo and win", richLevel, lowLevel,
                 [.act(listen), .undo, .act(listen), .undo, .act(winningLink), .act(listen), .retry], 200)]
    }

    @Test func adversarialFlickerStaysWithinTheLimits() throws {
        for pattern in Self.patterns() {
            for retry in [17, 45, 300] {
                let (samples, accepted): ([[Double]], Int) = try Self.flicker(pattern.steps, primary: pattern.primary,
                                                                              secondary: pattern.secondary,
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
        // Without Reduce Flashing a failed listen undone every 9 frames would blink (a won play is final, so the
        // failure is what flips); the slower fade holds the limit.
        var steps: [Step] = [.act(Self.listen)]
        for _ in 0..<8 { steps.append(.idle) }
        steps.append(.undo)
        for _ in 0..<8 { steps.append(.idle) }
        let (fast, _): ([[Double]], Int) = try Self.flicker(steps, primary: Self.richLevel, secondary: Self.lowLevel,
                                                             frames: 243, retryEvery: 1_000, reducedFlash: false)
        let (slow, _): ([[Double]], Int) = try Self.flicker(steps, primary: Self.richLevel, secondary: Self.lowLevel,
                                                             frames: 240, retryEvery: 1_000)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: 60) > 3)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(slow, frameRate: 60) <= 3)
        Self.expectWithinLimits(slow, "nine-frame flicker")
        // Normally every fade ends within 0.15 s of the last change: 9 frames after the run's last listen the glow
        // rests at the failed level.
        let last: [Double] = fast[fast.count - 1]
        #expect(last[0] == 0.35 && last[1] == 0)
    }
}
