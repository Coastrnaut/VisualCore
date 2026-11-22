// NocturneGardenLightsTests — feature 386 (R02-G09-06) T-R02G0906-004 (FR-R02G0906-004; SC-R02G0906-003;
// clarification Q3). The eased lights of level 100 (no leak allowed), driven through the adapter exactly as the panel
// sends its actions: the targets (glow 0.7 playing / 1 won / 0.35 failed, leak 1 while the failure is a leak); a
// scripted win (the certified solution, one action per frame) and adversarial flicker (a leak failure undone and
// repeated every frame, undo and redo of it, a win and its retry, a failure and level changes, retries every 17, 45 or
// 300 frames), sampled every 1/60 s under Reduce Flashing with every element over its own range (the glow gain 0 … 1,
// the leak crosses 0 … 1): no element crosses half its range more than 3 times per second and every complete one-way
// fade of more than half the range takes at least 0.4 s; normally a fade takes 0.15 s; settle jumps; the first step
// settles and later level changes fade; a budget failure dims the glow without the leak crosses; the result after a
// win stays won; negative or non-finite elapsed times do nothing. No randomness; explicit types, plain loops, short
// runs.
import Foundation
import Testing
@testable import NocturneGardenCore
import VisualCoreExperience

@Suite struct NocturneGardenLightsTests {
    typealias Lights = NocturneGardenLights
    typealias Core = NocturneGardenExperienceCore
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// The level every test plays (no leak allowed; levels 1 … 99 are open from it).
    static let levelNumber: Int = 100
    /// The other open level used for level changes.
    static let otherNumber: Int = 1

    /// The panel action `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func action(_ kernel: NocturneGardenAction) -> ExperienceAction {
        switch kernel {
        case let .plant(kind, column, row, size):
            action("bloom.plant", [Double(kind.order), Double(column), Double(row), Double(size)])
        case let .move(bloom, column, row):
            action("bloom.move", [Double(bloom), Double(column), Double(row)])
        case let .resize(bloom, size):
            action("bloom.resize", [Double(bloom), Double(size)])
        case let .remove(bloom):
            action("bloom.remove", [Double(bloom)])
        case let .sun(elevation):
            action("sun.set", [Double(elevation)])
        }
    }

    /// The retry action: the same level selected again.
    static var retry: ExperienceAction { action("level.select", [Double(levelNumber)]) }

    /// The level change action: the other open level selected.
    static var other: ExperienceAction { action("level.select", [Double(otherNumber)]) }

    /// The opening state of the level (campaign; the levels up to it open).
    static func opening() throws -> Core {
        try Core.opening(number: levelNumber)
    }

    /// The certified winning actions of the level.
    static func scriptedWin() throws -> [ExperienceAction] {
        var result: [ExperienceAction] = []
        for kernel in try Core.generated(number: levelNumber).solution.actions { result.append(action(kernel)) }
        return result
    }

    /// The won state of the level.
    static func won() throws -> Core {
        var core: Core = try opening()
        for item in try scriptedWin() { _ = core.apply(item) }
        #expect(core.play.stage == .won)
        return core
    }

    /// A first plant that fails the play with a leak: every supplied kind at the largest allowed size on every cell,
    /// in order (as `NocturneGardenExperienceCoreTests` searches).
    static func leakPlant() throws -> ExperienceAction {
        let core: Core = try opening()
        let level: NocturneGardenLevel = core.play.level
        let size: Int = try #require(level.sizes.sorted().last)
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 {
            for cell in 0..<level.cellCount {
                var copy: Core = core
                let plant: ExperienceAction = action(.plant(kind, cell % level.width, cell / level.width, size))
                if copy.apply(plant) == .accepted, case .leak = copy.play.failure { return plant }
            }
        }
        Issue.record("no leaking plant on level \(levelNumber)")
        throw CancellationError()
    }

    /// The failed (leak) state of the level.
    static func leaked() throws -> Core {
        var core: Core = try opening()
        #expect(core.apply(try leakPlant()) == .accepted)
        #expect(core.play.stage == .failed)
        return core
    }

    /// One sample of every light, each over its own range 0 … 1: the glow is the gain the scene multiplies its bloom
    /// glow by, 0 (dark, before the first snapshot) … 1, so it is sampled as is (its midpoint 0.5 lies between the
    /// failed 0.35 and the playing 0.7); the leak crosses as is.
    static func sample(_ lights: Lights) -> [Double] {
        [lights.glow, lights.leak]
    }

    /// Checks the two flash limits on `samples` under Reduce Flashing.
    static func expectWithinLimits(_ samples: [[Double]], _ label: String) {
        let crossings: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "\(label): \(crossings) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): a half-range fade took \(shortest) s")
    }

    /// Checks that `lights` rest exactly at the targets of `snapshot`.
    static func expectAtTargets(_ lights: Lights, _ snapshot: NocturneGardenSceneSnapshot) {
        #expect(lights.isSettled)
        let won: Bool = snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil)
        let glow: Double = won ? 1 : (snapshot.failure == nil ? 0.7 : 0.35)
        #expect(lights.glow == glow)
        #expect(lights.leak == (snapshot.leakFailure ? 1 : 0))
    }

    @Test func settleJumpsToTheTargets() throws {
        let start: NocturneGardenSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: NocturneGardenSceneSnapshot = try Self.won().snapshot(time: 0)
        let failed: NocturneGardenSceneSnapshot = try Self.leaked().snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.glow == 0 && lights.leak == 0)
        lights.settle(to: won)
        Self.expectAtTargets(lights, won)
        #expect(lights.glow == 1 && lights.leak == 0)
        lights.settle(to: failed)
        Self.expectAtTargets(lights, failed)
        #expect(lights.glow == 0.35 && lights.leak == 1)
        lights.settle(to: start)
        Self.expectAtTargets(lights, start)
        #expect(lights.glow == 0.7 && lights.leak == 0)
        // The first step also settles.
        var first: Lights = Lights(reducedFlash: false)
        first.step(toward: won, elapsed: Self.frame)
        Self.expectAtTargets(first, won)
    }

    @Test func theResultAfterAWinStaysWonAndAfterAFailureStaysFailed() throws {
        var winning: NocturneGardenPlay = try Self.won().play
        try winning.handle(.showResult)
        #expect(winning.stage == .result && winning.failure == nil)
        let wonResult: NocturneGardenSceneSnapshot = NocturneGardenSceneSnapshot(play: winning,
                                                                                  levelNumber: Self.levelNumber,
                                                                                  time: 0)
        #expect(Lights.isWon(wonResult))
        var failing: NocturneGardenPlay = try Self.leaked().play
        try failing.handle(.showResult)
        let failedResult: NocturneGardenSceneSnapshot = NocturneGardenSceneSnapshot(play: failing,
                                                                                     levelNumber: Self.levelNumber,
                                                                                     time: 0)
        #expect(!Lights.isWon(failedResult) && failedResult.leakFailure)
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: wonResult)
        #expect(lights.glow == 1 && lights.leak == 0)
        lights.settle(to: failedResult)
        #expect(lights.glow == 0.35 && lights.leak == 1)
    }

    @Test func aBudgetFailureDimsWithoutTheLeakCrosses() throws {
        // Sun changes on the empty bed until the budget is spent: failed by budget, never by a leak.
        var core: Core = try Self.opening()
        let budget: Int = core.play.level.budget
        for _ in 0..<budget {
            var sun: ExperienceAction? = nil
            for elevation in core.play.level.elevations.sorted() where elevation != core.play.elevation && sun == nil {
                sun = Self.action("sun.set", [Double(elevation)])
            }
            let item: ExperienceAction = try #require(sun)
            #expect(core.apply(item) == .accepted)
        }
        try #require(core.play.failure == .budget)
        let failed: NocturneGardenSceneSnapshot = core.snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: failed)
        Self.expectAtTargets(lights, failed)
        #expect(lights.glow == 0.35 && lights.leak == 0)
    }

    @Test func aLevelChangeOrRetryFades() throws {
        let start: NocturneGardenSceneSnapshot = try Self.opening().snapshot(time: 0)
        let failed: NocturneGardenSceneSnapshot = try Self.leaked().snapshot(time: 0)
        let other: NocturneGardenSceneSnapshot = try Core.opening(number: Self.otherNumber).snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: failed)
        lights.step(toward: other, elapsed: Self.frame)
        #expect(!lights.isSettled && lights.leak > 0 && lights.leak < 1)
        for _ in 0..<27 { lights.step(toward: start, elapsed: Self.frame) }
        Self.expectAtTargets(lights, start)
    }

    @Test func normalModeFadesInTheDuration() throws {
        let start: NocturneGardenSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: NocturneGardenSceneSnapshot = try Self.won().snapshot(time: 0)
        let failed: NocturneGardenSceneSnapshot = try Self.leaked().snapshot(time: 0)
        let frames: Int = Int((Lights.normalDuration * Self.frameRate).rounded())
        #expect(frames == 9)
        let pairs: [(NocturneGardenSceneSnapshot, NocturneGardenSceneSnapshot)] = [(start, won), (won, start),
                                                                                   (start, failed), (failed, start),
                                                                                   (won, failed)]
        for (from, to) in pairs {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: from)
            for _ in 0..<(frames - 1) { lights.step(toward: to, elapsed: Self.frame) }
            #expect(!lights.isSettled)
            lights.step(toward: to, elapsed: Self.frame)
            Self.expectAtTargets(lights, to)
        }
        // Normally a changed target turns a fade at once: partway into failing, the undo heads back.
        var turning: Lights = Lights(reducedFlash: false)
        turning.settle(to: start)
        for _ in 0..<4 { turning.step(toward: failed, elapsed: Self.frame) }
        let mid: Double = turning.leak
        turning.step(toward: start, elapsed: Self.frame)
        #expect(turning.leak < mid)
        // Under Reduce Flashing the same change takes 0.45 s and a started fade finishes first.
        var slow: Lights = Lights(reducedFlash: true)
        slow.settle(to: start)
        for _ in 0..<26 { slow.step(toward: failed, elapsed: Self.frame) }
        #expect(!slow.isSettled)
        slow.step(toward: failed, elapsed: Self.frame)
        Self.expectAtTargets(slow, failed)
        var firm: Lights = Lights(reducedFlash: true)
        firm.settle(to: start)
        for _ in 0..<4 { firm.step(toward: failed, elapsed: Self.frame) }
        let started: Double = firm.leak
        firm.step(toward: start, elapsed: Self.frame)
        #expect(firm.leak > started)
    }

    @Test func badElapsedTimesDoNothing() throws {
        let start: NocturneGardenSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: NocturneGardenSceneSnapshot = try Self.won().snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: start)
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: won, elapsed: elapsed)
            #expect(lights.glow == 0.7 && lights.leak == 0, "\(elapsed)")
        }
        #expect(!lights.isSettled)
        lights.step(toward: won, elapsed: Self.frame)
        #expect(lights.glow > 0.7)
    }

    @Test func aScriptedWinStaysWithinTheLimits() throws {
        var core: Core = try Self.opening()
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: core.snapshot(time: 0))
        var samples: [[Double]] = [Self.sample(lights)]
        for item in try Self.scriptedWin() where core.play.stage == .playing {
            #expect(core.apply(item) == .accepted)
            lights.step(toward: core.snapshot(time: 0), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        #expect(core.play.stage == .won)
        for _ in 0..<60 {
            lights.step(toward: core.snapshot(time: 0), elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, core.snapshot(time: 0))
        #expect(lights.glow == 1)
        Self.expectWithinLimits(samples, "scripted win")
    }

    /// Runs `frames` frames of a flicker `pattern` (one action per frame, refusals allowed) on the level under
    /// `reducedFlash`, retrying the level every `retryEvery` frames; returns the samples and the accepted actions.
    static func flicker(pattern: [ExperienceAction], frames: Int, retryEvery: Int,
                        reducedFlash: Bool = true) throws -> ([[Double]], Int) {
        var core: Core = try opening()
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: core.snapshot(time: 0))
        var samples: [[Double]] = [sample(lights)]
        var accepted: Int = 0
        for index in 0..<frames {
            let item: ExperienceAction = index > 0 && index % retryEvery == 0 ? retry : pattern[index % pattern.count]
            if core.apply(item) == .accepted { accepted += 1 }
            lights.step(toward: core.snapshot(time: 0), elapsed: frame)
            samples.append(sample(lights))
        }
        return (samples, accepted)
    }

    /// The flicker patterns: a leak failure undone and repeated every frame, its undo and redo, a win and its retry,
    /// a failure followed by level changes, and a level change every frame.
    static func patterns() throws -> [(String, [ExperienceAction])] {
        let fail: ExperienceAction = try leakPlant()
        let undo: ExperienceAction = action("play.undo")
        let redo: ExperienceAction = action("play.redo")
        var flip: [ExperienceAction] = []
        let redone: [ExperienceAction] = [fail, undo, redo, undo, redo, undo]
        for _ in 0..<20 { flip += [fail, undo] }
        return [("leak and undo", flip + [retry]),
                ("undo and redo", redone + [retry]),
                ("win and retry", try scriptedWin() + [retry]),
                ("fail and change level", [fail, other, retry]),
                ("change level every frame", [other, retry])]
    }

    @Test func adversarialFlickerStaysWithinTheLimits() throws {
        for (label, pattern) in try Self.patterns() {
            for retry in [17, 45, 300] {
                let (samples, accepted): ([[Double]], Int) = try Self.flicker(pattern: pattern, frames: 300,
                                                                              retryEvery: retry)
                #expect(accepted > 100, "\(label) retry \(retry): \(accepted) accepted")
                Self.expectWithinLimits(samples, "\(label) retry \(retry)")
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
        // Without Reduce Flashing a leak failure flipped every 9 frames would blink: the slower fade holds the limit.
        let fail: ExperienceAction = try Self.leakPlant()
        var pattern: [ExperienceAction] = []
        for _ in 0..<20 {
            pattern.append(fail)
            pattern += Array(repeating: Self.action("tutorial.dismiss"), count: 8)
            pattern.append(Self.action("play.undo"))
            pattern += Array(repeating: Self.action("tutorial.dismiss"), count: 8)
        }
        let (fast, _): ([[Double]], Int) = try Self.flicker(pattern: pattern, frames: 240, retryEvery: 1_000,
                                                             reducedFlash: false)
        let (slow, _): ([[Double]], Int) = try Self.flicker(pattern: pattern, frames: 240, retryEvery: 1_000)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: 60) > 3)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(slow, frameRate: 60) <= 3)
        Self.expectWithinLimits(slow, "nine-frame flicker")
    }
}
