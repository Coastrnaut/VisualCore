// MushroomWeatherLightsTests — feature 496 (R02-G20-06) T-R02G2006-004 (FR-R02G2006-004; SC-R02G2006-003;
// clarification Q3). The eased lights over real adapter cores (`MushroomWeatherExperienceCore.opening(number:)`,
// `apply`, `snapshot(time: 0)`) of the certified level the feature seed 2_496 chooses (`levelNumber(forSeed:)`, level
// 97), the level after it (98, opened with `level.next` once 97 is won) and the open level before it (96, chosen with
// `level.select`, the level change of the flicker patterns, since `level.next` needs an open next level): the targets
// (glow 0.7 playing / 1 won / 0.35 failed, the result after a win staying won and after a failure staying failed,
// the predicted report's failure while playing or paused never dimming the glow; won 1 once won, else 0); settle
// jumps and the first step settles; normally a fade
// takes 0.15 s (9 frames at 60 Hz) and turns at once; under Reduce Flashing it takes 0.45 s and a started fade
// finishes before it turns back; bad elapsed times do nothing; the presentation time (held at 0 under Reduce Motion)
// never changes the lights, only the elapsed frame time does; the shown cycle never changes the targets. A scripted win
// (the certified plan, `generated(number:).plan.actions`, its first action undone and redone, then the run and the next
// level) and adversarial flicker — a pod placement undone and redone every frame, a failed run undone and redone every
// frame (so the glow target flips every frame), a failed run and its undo, a win and its retry, a failure followed by
// level changes, a level change every frame, a win and a level change, a failure undone and failed again — each with
// retries every 17, 45 or 300 frames, sampled every 1/60 s for 5 s under Reduce Flashing with every element over its
// own range 0 … 1: no element crosses half its range more than 3 times per second and every complete one-way fade of
// more than half the range takes at least 0.4 s. The measure itself catches a nine-frame flicker without Reduce
// Flashing. No randomness, no clocks; explicit types, plain loops, short runs. Modelled on MicroscopicAuroraLightsTests
// (feature 486).
import Foundation
import Testing
import VisualCoreExperience
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherLightsTests {
    typealias Lights = MushroomWeatherLights
    typealias Core = MushroomWeatherExperienceCore
    typealias Snapshot = MushroomWeatherSceneSnapshot
    typealias Play = MushroomWeatherPlay
    /// The sampling rate, in frames per second.
    static let frameRate: Double = 60
    /// One frame, in seconds.
    static let frame: Double = 1 / 60
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_496
    /// The primary level: the one the feature seed opens (97).
    static let primaryNumber: Int = Core.levelNumber(forSeed: seed)

    /// An adapter action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: MushroomWeatherAction) -> ExperienceAction {
        switch action {
        case let .place(slot, cell): act("pod.place", [Double(slot), Double(cell.row), Double(cell.column)])
        case let .remove(slot): act("pod.remove", [Double(slot)])
        case let .vent(index, open): act("vent.set", [Double(index), open ? 1 : 0])
        case let .moonlight(level): act("moon.set", [Double(level)])
        case .run: act("weather.run")
        }
    }

    /// One frame of a script: an adapter action, a retry (back to the script's start core), or nothing.
    enum Step {
        /// An adapter action (pod, vent, moonlight, run, undo, redo, level change …).
        case action(ExperienceAction)
        /// Back to the start core of the script.
        case retry
        /// Nothing.
        case idle
    }

    /// An undo.
    static let undo: Step = .action(act("play.undo"))
    /// A redo.
    static let redo: Step = .action(act("play.redo"))
    /// The run (from the opening it fails: a certified level's starting arrangement never wins).
    static let run: Step = .action(act("weather.run"))
    /// A change to another level that is always open from the primary level's opening (levels 1 … 97 are open): the
    /// level before it, chosen with `level.select` (`level.next` is refused `r02-g20.locked` until the level is won).
    static let other: Step = .action(act("level.select", [Double(primaryNumber - 1)]))
    /// A change to the next level, accepted once the primary level is won (the win opens it).
    static let next: Step = .action(act("level.next"))

    /// The opening core of the primary level (stage `playing`).
    static func start() throws -> Core { try Core.opening(number: primaryNumber) }

    /// The certified actions of the primary level (the run not included).
    static func planActions() throws -> [MushroomWeatherAction] {
        try Core.generated(number: primaryNumber).plan.actions
    }

    /// The certified winning actions of the primary level followed by the run, as adapter steps.
    static func winning() throws -> [Step] {
        var steps: [Step] = []
        for action in try planActions() { steps.append(.action(act(action))) }
        steps.append(run)
        return steps
    }

    /// A pod placement the opening accepts, which leaves the play in stage `playing`: the plan's first placement, or
    /// the first site no pod holds put into slot 0.
    static func placement() throws -> Step {
        for action in try planActions() {
            if case .place = action { return .action(act(action)) }
        }
        let level: MushroomWeatherLevel = try Core.level(number: primaryNumber)
        let held: [MushroomWeatherCell] = level.start.placedPods
        for site in level.sites ?? [] where !held.contains(site) {
            return .action(act(.place(slot: 0, cell: site)))
        }
        Issue.record("level \(primaryNumber) offers no placement")
        return .idle
    }

    /// The snapshot of `core` at presentation time 0.
    static func snap(_ core: Core) -> Snapshot { core.snapshot(time: 0) }

    /// The snapshot of `play` of the primary level with cycle 0 shown at presentation time 0.
    static func snap(_ play: Play) -> Snapshot {
        Snapshot(play: play, shownCycle: 0, levelNumber: primaryNumber, time: 0)
    }

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

    /// Checks that `lights` rest exactly at the targets of `snapshot`, decided here independently: won in stage
    /// `won` or a result without a failure, failed in stage `failed` or a result with one, playing otherwise.
    static func expectAtTargets(_ lights: Lights, _ snapshot: Snapshot) {
        #expect(lights.isSettled)
        let won: Bool = snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil)
        let failed: Bool = snapshot.stage == .failed || (snapshot.stage == .result && snapshot.failure != nil)
        let glow: Double = won ? 1 : (failed ? 0.35 : 0.7)
        #expect(lights.glow == glow)
        #expect(lights.won == (won ? 1 : 0))
    }

    /// The opening, won and failed snapshots of the primary level.
    static func stages() throws -> (start: Snapshot, won: Snapshot, failed: Snapshot) {
        let opening: Core = try start()
        var winner: Core = opening
        for action in try planActions() { #expect(winner.apply(act(action)) == .accepted) }
        #expect(winner.apply(act(.run)) == .accepted)
        var loser: Core = opening
        #expect(loser.apply(act(.run)) == .accepted)
        let result: (Snapshot, Snapshot, Snapshot) = (snap(opening), snap(winner), snap(loser))
        #expect(result.0.stage == .playing && result.1.stage == .won && result.2.stage == .failed)
        // The opening already carries the predicted report's failure, yet it glows as playing.
        #expect(result.0.failure != nil && result.2.failure != nil)
        return result
    }

    @Test func settleJumpsToTheTargetsOfEveryStage() throws {
        #expect(Self.primaryNumber == 97)
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
        let level: MushroomWeatherLevel = try Core.level(number: Self.primaryNumber)
        var winning: Play = try Core.freshPlay(of: level)
        for action in try Self.planActions() { try winning.apply(action, expecting: winning.fingerprint) }
        try winning.apply(.run, expecting: winning.fingerprint)
        #expect(winning.stage == .won)
        try winning.handle(.showResult)
        let wonResult: Snapshot = Self.snap(winning)
        #expect(wonResult.stage == .result && Lights.isWon(wonResult) && !Lights.isFailed(wonResult))
        var failing: Play = try Core.freshPlay(of: level)
        try failing.apply(.run, expecting: failing.fingerprint)
        #expect(failing.stage == .failed)
        try failing.handle(.showResult)
        let failedResult: Snapshot = Self.snap(failing)
        #expect(failedResult.stage == .result && !Lights.isWon(failedResult) && Lights.isFailed(failedResult))
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: wonResult)
        #expect(lights.glow == 1 && lights.won == 1)
        lights.settle(to: failedResult)
        #expect(lights.glow == 0.35 && lights.won == 0)
        // Paused plays glow as playing, although the predicted report says a run now would fail.
        var paused: Play = try Core.freshPlay(of: level)
        try paused.handle(.pause)
        let pausedSnapshot: Snapshot = Self.snap(paused)
        #expect(pausedSnapshot.failure != nil && !Lights.isFailed(pausedSnapshot))
        lights.settle(to: pausedSnapshot)
        #expect(lights.glow == 0.7 && lights.won == 0)
        // Every action of the plan keeps the playing glow, whatever the report says (the last makes a run win).
        var changing: Play = try Core.freshPlay(of: level)
        for action in try Self.planActions() {
            try changing.apply(action, expecting: changing.fingerprint)
            lights.settle(to: Self.snap(changing))
            #expect(changing.stage == .playing)
            #expect(lights.glow == 0.7 && lights.won == 0)
        }
        #expect(changing.report.wins)
        // The shown cycle never changes the targets.
        var shown: Core = try Self.start()
        var before: Lights = Lights(reducedFlash: true)
        before.settle(to: Self.snap(shown))
        #expect(shown.apply(Self.act("clock.show", [1])) == .accepted)
        #expect(shown.shownCycle == 1)
        var after: Lights = Lights(reducedFlash: true)
        after.settle(to: Self.snap(shown))
        #expect(before == after)
    }

    @Test func onlyTheElapsedFrameTimeMovesTheLightsNotThePresentationTime() throws {
        // Under Reduce Motion the presentation time stays 0; without it, it runs. Both give the same lights, frame by
        // frame, because only the elapsed frame time steps them.
        let opening: Core = try Self.start()
        var winner: Core = opening
        for action in try Self.planActions() { #expect(winner.apply(Self.act(action)) == .accepted) }
        #expect(winner.apply(Self.act(.run)) == .accepted)
        let openingStill: Snapshot = opening.snapshot(time: 0)
        let openingMoving: Snapshot = opening.snapshot(time: 3.25)
        let winnerStill: Snapshot = winner.snapshot(time: 0)
        for reduced in [false, true] {
            var still: Lights = Lights(reducedFlash: reduced)
            var moving: Lights = Lights(reducedFlash: reduced)
            still.settle(to: openingStill)
            moving.settle(to: openingMoving)
            #expect(still == moving)
            for index in 0..<40 {
                let time: Double = 3.25 + Double(index) * 0.7
                still.step(toward: winnerStill, elapsed: Self.frame)
                moving.step(toward: winner.snapshot(time: time), elapsed: Self.frame)
                #expect(still == moving, "frame \(index), reduced flash \(reduced)")
            }
            Self.expectAtTargets(still, winnerStill)
            // Without elapsed time nothing moves, however far the presentation time runs.
            var frozen: Lights = Lights(reducedFlash: reduced)
            frozen.settle(to: openingStill)
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
    /// (back to `start`) every `retryEvery` frames; returns the samples and the number of accepted steps. `cache`
    /// keeps each distinct state's snapshot (equal states give equal snapshots; a speed-up only).
    static func flicker(_ steps: [Step], start: Core, frames: Int, retryEvery: Int, reducedFlash: Bool = true,
                        cache: inout [String: Snapshot]) -> ([[Double]], Int) {
        var core: Core = start
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: snap(core))
        var samples: [[Double]] = [sample(lights)]
        var accepted: Int = 0
        for index in 0..<frames {
            let step: Step = index > 0 && index % retryEvery == 0 ? .retry : steps[index % steps.count]
            if perform(step, &core, start: start) { accepted += 1 }
            let key: String = "\(core.levelNumber) \(core.shownCycle) \(core.play.fingerprint)"
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
        // The certified winning actions and the run, one per frame, the first action undone and redone.
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
        let wonSnapshot: Snapshot = Self.snap(core)
        for _ in 0..<60 {
            lights.step(toward: wonSnapshot, elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, wonSnapshot)
        #expect(lights.glow == 1 && lights.won == 1)
        // The next level dims back to playing.
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == Self.primaryNumber + 1 && core.play.stage == .playing)
        let nextSnapshot: Snapshot = Self.snap(core)
        for _ in 0..<60 {
            lights.step(toward: nextSnapshot, elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, nextSnapshot)
        #expect(lights.glow == 0.7 && lights.won == 0)
        Self.expectWithinLimits(samples, "scripted win")
    }

    /// The flicker patterns, each with its steps and the fewest accepted steps it must make in 300 frames (a retry
    /// clears the history, so the undos and redos after it are refused until the pattern acts or runs again; the bounds
    /// leave room below what the patterns reach, so they only show that the patterns keep changing the state).
    static func patterns() throws -> [(name: String, steps: [Step], least: Int)] {
        let placed: Step = try placement()
        let wins: [Step] = try winning()
        var redone: [Step] = [run]
        for _ in 0..<5 { redone += [undo, redo] }
        redone.append(undo)
        var placedRedone: [Step] = [placed]
        for _ in 0..<5 { placedRedone += [undo, redo] }
        placedRedone.append(undo)
        return [("failed run undone and redone", redone, 150),
                ("pod placement undone and redone", placedRedone, 150),
                ("failed run and undo", [run, undo], 200),
                ("win and retry", wins + [Step.retry], 150),
                ("failure and change level", [run, other, Step.retry], 200),
                ("change level every frame", [other, Step.retry], 200),
                ("win and level change", wins + [next, Step.retry], 150),
                ("failure undone and failed again", [run, undo, redo, undo, run, Step.retry], 200)]
    }

    @Test func adversarialFlickerWithRetriesStaysWithinTheLimits() throws {
        let opening: Core = try Self.start()
        var cache: [String: Snapshot] = [:]
        for retry in [17, 45, 300] {
            for pattern in try Self.patterns() {
                let (samples, accepted): ([[Double]], Int) = Self.flicker(pattern.steps, start: opening, frames: 300,
                                                                          retryEvery: retry, cache: &cache)
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
        // Without Reduce Flashing a failed run undone every 9 frames would blink (a won run is final, so the failure
        // is what flips); the slower fade holds the limit.
        var steps: [Step] = [Self.run]
        for _ in 0..<8 { steps.append(.idle) }
        steps.append(Self.undo)
        for _ in 0..<8 { steps.append(.idle) }
        let opening: Core = try Self.start()
        var cache: [String: Snapshot] = [:]
        let (fast, _): ([[Double]], Int) = Self.flicker(steps, start: opening, frames: 243, retryEvery: 1_000,
                                                         reducedFlash: false, cache: &cache)
        let (slow, _): ([[Double]], Int) = Self.flicker(steps, start: opening, frames: 240, retryEvery: 1_000,
                                                         cache: &cache)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: 60) > 3)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(slow, frameRate: 60) <= 3)
        Self.expectWithinLimits(slow, "nine-frame flicker")
        // Normally every fade ends within 0.15 s of the last change: 9 frames after the last failed run the glow
        // rests at the failed level.
        let last: [Double] = fast[fast.count - 1]
        #expect(last[0] == 0.35 && last[1] == 0)
    }
}
