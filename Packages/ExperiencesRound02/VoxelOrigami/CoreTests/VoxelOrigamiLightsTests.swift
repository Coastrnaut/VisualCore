// VoxelOrigamiLightsTests — feature 446 (R02-G15-06) T-R02G1506-004 (FR-R02G1506-004; SC-R02G1506-003;
// clarification Q3). The eased lights over real adapter cores (`VoxelOrigamiExperienceCore.opening(number:)`, `apply`,
// `snapshot(time: 0)`) of the certified level the feature seed 2_446 chooses (`levelNumber(forSeed:)`, level 47) and
// the level before it (46, open from that opening, chosen with `level.select`): the targets (glow 0.7 playing / 1 won /
// 0.35 failed, the result after a win staying won and after a failure staying failed; won 1 once won, else 0); settle
// jumps and the first step settles; normally a fade takes 0.15 s (9 frames at 60 Hz) and turns at once; under Reduce
// Flashing it takes 0.45 s and a started fade finishes before it turns back; bad elapsed times do nothing; the
// presentation time (held at 0 under Reduce Motion) never changes the lights, only the elapsed frame time does. A
// scripted win (the certified plan, `generated(number:).plan.turns`, with an undo and redo, then the next level) and
// adversarial flicker — a turn that spends the last action undone and redone every frame, a failing turn and its undo,
// a win and its retry, a failure followed by level changes, a level change every frame, a win and a level change, a
// failure undone and failed again — each with retries every 17, 45 or 300 frames, sampled every 1/60 s for 5 s under
// Reduce Flashing with every element over its own range 0 … 1: no element crosses half its range more than 3 times
// per second and every complete one-way fade of more than half the range takes at least 0.4 s. The measure itself
// catches a nine-frame flicker without Reduce Flashing. No randomness, no clocks; explicit types, plain loops, short
// runs.
import Foundation
import Testing
import VisualCoreExperience
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiLightsTests {
    typealias Lights = VoxelOrigamiLights
    typealias Core = VoxelOrigamiExperienceCore
    typealias Snapshot = VoxelOrigamiSceneSnapshot
    /// The sampling rate, in frames per second.
    static let frameRate: Double = 60
    /// One frame, in seconds.
    static let frame: Double = 1 / 60
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_446
    /// The primary level: the one the feature seed opens (47).
    static let primaryNumber: Int = Core.levelNumber(forSeed: seed)
    /// The other level: the one before it, open from the primary opening.
    static let otherNumber: Int = primaryNumber - 1

    /// An adapter action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: VoxelOrigamiAction) -> ExperienceAction {
        switch action {
        case let .turn(hinge, step): act("hinge.turn", [Double(hinge), Double(step)])
        }
    }

    /// One frame of a script: an adapter action, a retry (back to the script's start core), or nothing.
    enum Step {
        /// An adapter action (turn, undo, redo, level choice …).
        case action(ExperienceAction)
        /// Back to the start core of the script.
        case retry
        /// Nothing.
        case idle
    }

    /// Hinge 1 turned forward a quarter (from the primed core it spends the budget and fails).
    static let turn: Step = .action(act("hinge.turn", [1, 1]))
    /// An undo.
    static let undo: Step = .action(act("play.undo"))
    /// A redo.
    static let redo: Step = .action(act("play.redo"))
    /// A change to the other level.
    static let other: Step = .action(act("level.select", [Double(otherNumber)]))

    /// The opening core of the primary level (stage `playing`).
    static func start() throws -> Core { try Core.opening(number: primaryNumber) }

    /// The certified winning turns of the primary level, as adapter steps.
    static func winning() throws -> [Step] {
        var steps: [Step] = []
        for action in try Core.generated(number: primaryNumber).plan.turns { steps.append(.action(act(action))) }
        return steps
    }

    /// The primary opening with one action left: hinge 1 turned forward and back until a single action remains (an
    /// even number of turns, so the pose is the opening's), so the next turn spends the budget and fails the level.
    static func primed() throws -> Core {
        var core: Core = try start()
        var forward: Bool = true
        while core.play.actionsLeft > 1 {
            #expect(core.apply(act("hinge.turn", [1, forward ? 1 : -1])) == .accepted)
            forward.toggle()
        }
        #expect(core.play.stage == .playing && core.play.actionsLeft == 1)
        return core
    }

    /// The snapshot of `core` at presentation time 0.
    static func snap(_ core: Core) -> Snapshot { core.snapshot(time: 0) }

    /// One sample of every light, each over its own range 0 … 1: the glow (a gain, 0 dark … 1; its midpoint 0.5 lies
    /// between the failed 0.35 and the playing 0.7) and the won look as they are.
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

    /// The opening, won and failed (the budget spent) snapshots of the primary level.
    static func stages() throws -> (start: Snapshot, won: Snapshot, failed: Snapshot) {
        let opening: Core = try start()
        var winner: Core = opening
        for action in try Core.generated(number: primaryNumber).plan.turns {
            #expect(winner.apply(act(action)) == .accepted)
        }
        var loser: Core = try primed()
        #expect(loser.apply(act("hinge.turn", [1, 1])) == .accepted)
        let result: (Snapshot, Snapshot, Snapshot) = (snap(opening), snap(winner), snap(loser))
        #expect(result.0.stage == .playing && result.1.stage == .won && result.2.stage == .failed)
        #expect(result.2.failure != nil)
        return result
    }

    @Test func settleJumpsToTheTargetsOfEveryStage() throws {
        #expect(Self.primaryNumber == 47 && Self.otherNumber == 46)
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
    }

    @Test func theResultAfterAWinStaysWonAndAfterAFailureStaysFailed() throws {
        let level: VoxelOrigamiLevel = try Core.level(number: Self.primaryNumber)
        var winning: VoxelOrigamiPlay = try Core.freshPlay(of: level)
        for action in try Core.generated(number: Self.primaryNumber).plan.turns {
            try winning.apply(action, expecting: winning.fingerprint)
        }
        try winning.handle(.showResult)
        let wonResult: Snapshot = Snapshot(play: winning, chosenHinge: 1, levelNumber: Self.primaryNumber, time: 0)
        #expect(wonResult.stage == .result && Lights.isWon(wonResult) && !Lights.isFailed(wonResult))
        var failing: VoxelOrigamiPlay = (try Self.primed()).play
        try failing.apply(.turn(1, 1), expecting: failing.fingerprint)
        #expect(failing.stage == .failed)
        try failing.handle(.showResult)
        let failedResult: Snapshot = Snapshot(play: failing, chosenHinge: 1, levelNumber: Self.primaryNumber, time: 0)
        #expect(failedResult.stage == .result && !Lights.isWon(failedResult) && Lights.isFailed(failedResult))
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: wonResult)
        #expect(lights.glow == 1 && lights.won == 1)
        lights.settle(to: failedResult)
        #expect(lights.glow == 0.35 && lights.won == 0)
        // Paused plays glow as playing.
        var paused: VoxelOrigamiPlay = try Core.freshPlay(of: level)
        try paused.handle(.pause)
        lights.settle(to: Snapshot(play: paused, chosenHinge: 1, levelNumber: Self.primaryNumber, time: 0))
        #expect(lights.glow == 0.7 && lights.won == 0)
        // The chosen hinge never changes the targets.
        var chosen: Core = try Self.start()
        var before: Lights = Lights(reducedFlash: true)
        before.settle(to: Self.snap(chosen))
        #expect(chosen.apply(Self.act("hinge.choose", [5])) == .accepted)
        var after: Lights = Lights(reducedFlash: true)
        after.settle(to: Self.snap(chosen))
        #expect(before == after)
    }

    @Test func onlyTheElapsedFrameTimeMovesTheLightsNotThePresentationTime() throws {
        // Under Reduce Motion the presentation time stays 0; without it, it runs. Both give the same lights, frame by
        // frame, because only the elapsed frame time steps them.
        let opening: Core = try Self.start()
        var winner: Core = opening
        for action in try Core.generated(number: Self.primaryNumber).plan.turns {
            #expect(winner.apply(Self.act(action)) == .accepted)
        }
        for reduced in [false, true] {
            var still: Lights = Lights(reducedFlash: reduced)
            var moving: Lights = Lights(reducedFlash: reduced)
            still.settle(to: opening.snapshot(time: 0))
            moving.settle(to: opening.snapshot(time: 3.25))
            #expect(still == moving)
            for index in 0..<40 {
                let time: Double = 3.25 + Double(index) * 0.7
                still.step(toward: winner.snapshot(time: 0), elapsed: Self.frame)
                moving.step(toward: winner.snapshot(time: time), elapsed: Self.frame)
                #expect(still == moving, "frame \(index), reduced flash \(reduced)")
            }
            Self.expectAtTargets(still, Self.snap(winner))
            // Without elapsed time nothing moves, however far the presentation time runs.
            var frozen: Lights = Lights(reducedFlash: reduced)
            frozen.settle(to: opening.snapshot(time: 0))
            for index in 0..<10 { frozen.step(toward: winner.snapshot(time: Double(index) * 10), elapsed: 0) }
            #expect(frozen.glow == 0.7 && frozen.won == 0 && !frozen.isSettled)
        }
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

    /// Applies `step` to `core` (a retry restores `start`); true when accepted.
    static func perform(_ step: Step, _ core: inout Core, start: Core) -> Bool {
        switch step {
        case .action(let action):
            return core.apply(action) == .accepted
        case .retry:
            core = start
            return true
        case .idle:
            return false
        }
    }

    /// Runs `frames` frames of `steps` (one per frame, refusals allowed) from `start` under `reducedFlash`, retrying
    /// (back to `start`) every `retryEvery` frames; returns the samples and the number of accepted steps.
    static func flicker(_ steps: [Step], start: Core, frames: Int, retryEvery: Int,
                        reducedFlash: Bool = true) -> ([[Double]], Int) {
        var core: Core = start
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: snap(core))
        var samples: [[Double]] = [sample(lights)]
        var accepted: Int = 0
        // Equal states give equal snapshots, so each distinct state is snapshotted once (a speed-up only).
        var cache: [String: Snapshot] = [:]
        for index in 0..<frames {
            let step: Step = index > 0 && index % retryEvery == 0 ? .retry : steps[index % steps.count]
            if perform(step, &core, start: start) { accepted += 1 }
            let key: String = "\(core.levelNumber) \(core.chosenHinge) \(core.play.fingerprint)"
            let snapshot: Snapshot = cache[key] ?? snap(core)
            cache[key] = snapshot
            lights.step(toward: snapshot, elapsed: frame)
            samples.append(sample(lights))
        }
        return (samples, accepted)
    }

    @Test func aScriptedWinStaysWithinTheLimits() throws {
        var core: Core = try Self.start()
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: Self.snap(core))
        var samples: [[Double]] = [Self.sample(lights)]
        // The certified winning turns, one per frame, the first undone and redone.
        let wins: [Step] = try Self.winning()
        var script: [Step] = [wins[0], Self.undo, Self.redo]
        for index in 1..<wins.count { script.append(wins[index]) }
        let opening: Core = core
        for step in script {
            #expect(Self.perform(step, &core, start: opening))
            lights.step(toward: Self.snap(core), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        #expect(core.play.stage == .won)
        for _ in 0..<60 {
            lights.step(toward: Self.snap(core), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, Self.snap(core))
        #expect(lights.glow == 1 && lights.won == 1)
        // The next level dims back to playing.
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == Self.primaryNumber + 1 && core.play.stage == .playing)
        for _ in 0..<60 {
            lights.step(toward: Self.snap(core), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, Self.snap(core))
        #expect(lights.glow == 0.7 && lights.won == 0)
        Self.expectWithinLimits(samples, "scripted win")
    }

    /// The flicker patterns, each with its start core, its steps and the fewest accepted steps it must make in 300
    /// frames.
    static func patterns() throws -> [(name: String, start: Core, steps: [Step], least: Int)] {
        let opening: Core = try start()
        let ready: Core = try primed()
        let wins: [Step] = try winning()
        var redone: [Step] = [turn]
        for _ in 0..<5 { redone += [undo, redo] }
        redone.append(undo)
        return [("turn undone and redone", ready, redone, 250),
                ("failing turn and undo", ready, [turn, undo], 250),
                ("win and retry", opening, wins + [Step.retry], 250),
                ("failure and change level", ready, [turn, other, Step.retry], 250),
                ("change level every frame", opening, [other, Step.retry], 250),
                ("win and level change", opening, wins + [other, Step.retry], 250),
                ("failure undone and failed again", ready, [turn, undo, redo, undo, turn, Step.retry], 250)]
    }

    /// Runs every flicker pattern with retries every `retry` frames and checks the limits.
    static func expectFlickerWithinLimits(retry: Int) throws {
        for pattern in try patterns() {
            let (samples, accepted): ([[Double]], Int) = flicker(pattern.steps, start: pattern.start,
                                                                 frames: 300, retryEvery: retry)
            let name: String = "\(pattern.name), retry \(retry)"
            #expect(accepted >= pattern.least, "\(name): \(accepted) accepted")
            #expect(samples.count == 301)
            expectWithinLimits(samples, name)
        }
    }

    @Test func adversarialFlickerWithRetriesEvery17FramesStaysWithinTheLimits() throws {
        try Self.expectFlickerWithinLimits(retry: 17)
    }

    @Test func adversarialFlickerWithRetriesEvery45FramesStaysWithinTheLimits() throws {
        try Self.expectFlickerWithinLimits(retry: 45)
    }

    @Test func adversarialFlickerWithRetriesEvery300FramesStaysWithinTheLimits() throws {
        try Self.expectFlickerWithinLimits(retry: 300)
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
        // Without Reduce Flashing a failing turn undone every 9 frames would blink (a won play is final, so the
        // failure is what flips); the slower fade holds the limit.
        var steps: [Step] = [Self.turn]
        for _ in 0..<8 { steps.append(.idle) }
        steps.append(Self.undo)
        for _ in 0..<8 { steps.append(.idle) }
        let ready: Core = try Self.primed()
        let (fast, _): ([[Double]], Int) = Self.flicker(steps, start: ready, frames: 243, retryEvery: 1_000,
                                                         reducedFlash: false)
        let (slow, _): ([[Double]], Int) = Self.flicker(steps, start: ready, frames: 240, retryEvery: 1_000)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: 60) > 3)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(slow, frameRate: 60) <= 3)
        Self.expectWithinLimits(slow, "nine-frame flicker")
        // Normally every fade ends within 0.15 s of the last change: 9 frames after the last failing turn the glow
        // rests at the failed level.
        let last: [Double] = fast[fast.count - 1]
        #expect(last[0] == 0.35 && last[1] == 0)
    }
}
