// LissajousLabyrinthLightsTests — feature 316 (R02-G02-06) T-R02G0206-003 (FR-R02G0206-004; clarification Q3;
// SC-R02G0206-003). The eased lights: the targets (checkpoint visited 1, next 0.5, else 0; obstacle 1 while touched; glow
// 1 when won); a scripted win (a certified level's solution applied one action per 0.2 s) sampled every 1/60 s under
// Reduce Flashing crosses half the range at most 3 times per second and every complete one-way fade of more than half the
// range takes at least 0.4 s; normally a target is reached within 0.15 s and one frame; targets toggled every 1, 2 and 5
// frames (and at random) still stay within both limits under Reduce Flashing; settle jumps to the targets; a change of
// the checkpoint or obstacle count settles; negative and non-finite elapsed times do nothing. Explicit types, plain
// loops, short runs.
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreExperience

@Suite struct LissajousLabyrinthLightsTests {
    typealias Core = LissajousLabyrinthExperienceCore
    typealias Lights = LissajousLabyrinthLights
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// A level with several checkpoints and a multi-action certified solution.
    static let seed: UInt64 = 63

    /// The `dial.set` action for a kernel action.
    static func action(_ move: LissajousLabyrinthAction) -> ExperienceAction {
        let index: Int = Core.dialOrder.firstIndex(of: move.dial) ?? 0
        return ExperienceAction(control: "dial.set", values: [Double(index), Double(move.value)], step: 0)
    }

    /// The certified solution of the level `core` opened.
    static func solution(_ core: Core) throws -> [LissajousLabyrinthAction] {
        try Core.generated(number: core.levelNumber).solution.actions
    }

    /// The flattened targets of `snapshot` (checkpoints, obstacles, glow), in the order of `Lights.levels`.
    static func flatTargets(_ snapshot: LissajousLabyrinthSceneSnapshot) -> [Double] {
        let targets = Lights.targets(snapshot)
        return targets.checkpoints + targets.obstacles + [targets.glow]
    }

    /// Plays the certified solution, one action per 0.2 s, while stepping lights at 60 Hz for 3 s; returns the sampled
    /// levels and whether the play was won.
    static func scriptedWin(reducedFlash: Bool) async throws -> (samples: [[Double]], won: Bool) {
        var core: Core = try await Core.prepare(seed: seed)
        let moves: [LissajousLabyrinthAction] = try solution(core)
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: core.snapshot(time: 0))
        var samples: [[Double]] = [lights.levels]
        var applied: Int = 0
        for frame in 1...180 {
            let seconds: Double = Double(frame) / frameRate
            let due: Int = min(Int(seconds / 0.2), moves.count)
            while applied < due {
                #expect(core.apply(action(moves[applied])) == .accepted)
                applied += 1
            }
            lights.step(toward: core.snapshot(time: seconds), elapsed: Self.frame)
            samples.append(lights.levels)
        }
        return (samples, core.play.stage == .won)
    }

    @Test func targetsFollowTheSnapshot() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let start: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        let first = Lights.targets(start)
        #expect(first.checkpoints.count == start.level.checkpoints.count)
        #expect(first.obstacles.count == start.level.obstacles.count && first.glow == 0)
        for index in 0..<first.checkpoints.count {
            let expected: Double = start.visited(index) ? 1 : (index == start.nextCheckpoint ? 0.5 : 0)
            #expect(first.checkpoints[index] == expected)
        }
        for index in 0..<first.obstacles.count {
            #expect(first.obstacles[index] == (index == start.contactObstacle ? 1 : 0))
        }
        for move in try Self.solution(core) { #expect(core.apply(Self.action(move)) == .accepted) }
        let won = Lights.targets(core.snapshot(time: 0))
        #expect(core.play.stage == .won && won.glow == 1)
        #expect(won.checkpoints.allSatisfy { $0 == 1 } && won.obstacles.allSatisfy { $0 == 0 })
    }

    @Test func scriptedWinUnderReduceFlashing() async throws {
        let run: (samples: [[Double]], won: Bool) = try await Self.scriptedWin(reducedFlash: true)
        #expect(run.won)
        #expect(run.samples.last?.last == 1, "the glow reaches 1")
        let rate: Double = Lights.maxHalfRangeCrossingsPerSecond(run.samples, frameRate: Self.frameRate)
        #expect(rate >= 1 && rate <= 3, "\(rate) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(run.samples, frameRate: Self.frameRate)
        #expect(shortest >= 0.4, "\(shortest) s")
        #expect(shortest.isFinite, "the glow fades in completely, so there is a measured change")
    }

    @Test func scriptedWinNormallyFadesFast() async throws {
        let run: (samples: [[Double]], won: Bool) = try await Self.scriptedWin(reducedFlash: false)
        #expect(run.won)
        let shortest: Double = Lights.shortestHalfRangeChange(run.samples, frameRate: Self.frameRate)
        #expect(shortest > 0 && shortest <= 0.15 + Self.frame + 1e-9, "\(shortest) s")
    }

    @Test func targetsAreReachedWithinDurationAndOneFrame() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let start: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        for move in try Self.solution(core) { #expect(core.apply(Self.action(move)) == .accepted) }
        let end: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        let targets: [Double] = Self.flatTargets(end)
        #expect(targets != Self.flatTargets(start))
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: start)
            let duration: Double = reduced ? Lights.reducedFlashDuration : Lights.normalDuration
            #expect(lights.duration == duration)
            let frames: Int = Int((duration * Self.frameRate).rounded()) + 1
            for index in 0..<frames {
                lights.step(toward: end, elapsed: Self.frame)
                if index < frames - 2 { #expect(lights.levels != targets, "not instantly, frame \(index)") }
            }
            #expect(lights.levels == targets, "reduced \(reduced)")
        }
    }

    @Test func adversarialFlickerStaysSlowUnderReduceFlashing() async throws {
        let core: Core = try await Core.prepare(seed: Self.seed)
        let playing: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        var winner: Core = core
        for move in try Self.solution(core) { #expect(winner.apply(Self.action(move)) == .accepted) }
        let won: LissajousLabyrinthSceneSnapshot = winner.snapshot(time: 0)
        #expect(Lights.targets(won).glow == 1 && Lights.targets(playing).glow == 0)
        var state: UInt64 = 2_316
        // Patterns: toggle every frame, every 2 frames, every 5 frames, hold then every frame, pseudo-random.
        for pattern in 0..<5 {
            var lights: Lights = Lights(reducedFlash: true)
            lights.settle(to: playing)
            var samples: [[Double]] = [lights.levels]
            for frame in 0..<300 {
                let high: Bool
                switch pattern {
                case 0: high = frame % 2 == 0
                case 1: high = (frame / 2) % 2 == 0
                case 2: high = (frame / 5) % 2 == 0
                case 3: high = frame < 14 || frame % 2 == 0
                default:
                    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    high = (state >> 33) & 1 == 1
                }
                lights.step(toward: high ? won : playing, elapsed: Self.frame)
                samples.append(lights.levels)
            }
            let rate: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: Self.frameRate)
            #expect(rate <= 3, "pattern \(pattern): \(rate)")
            let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: Self.frameRate)
            #expect(shortest >= 0.4, "pattern \(pattern): \(shortest)")
        }
        // Pattern 3 holds the glow near half its range (14 frames ≈ 0.52 under Reduce Flashing) before it flickers. The
        // same pattern at the normal speed (held 4 frames ≈ 0.44) blinks across half the range every frame: the measure
        // detects it, so the bound above is meaningful.
        var normal: Lights = Lights(reducedFlash: false)
        normal.settle(to: playing)
        var fast: [[Double]] = [normal.levels]
        for frame in 0..<120 {
            normal.step(toward: frame < 4 || frame % 2 == 0 ? won : playing, elapsed: Self.frame)
            fast.append(normal.levels)
        }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: Self.frameRate) > 3)
    }

    @Test func settleJumpsAndCountChangesSettle() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let start: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.checkpoints.isEmpty && lights.obstacles.isEmpty && lights.glow == 0)
        lights.step(toward: start, elapsed: Self.frame)
        #expect(lights.levels == Self.flatTargets(start), "the first step sizes and settles")
        for move in try Self.solution(core) { #expect(core.apply(Self.action(move)) == .accepted) }
        let end: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        lights.settle(to: end)
        #expect(lights.levels == Self.flatTargets(end) && lights.glow == 1)
        // Another level with a different checkpoint or obstacle count: a step settles at once.
        let other: Core = try await Core.prepare(seed: 0)
        let otherSnapshot: LissajousLabyrinthSceneSnapshot = other.snapshot(time: 0)
        try #require(otherSnapshot.level.checkpoints.count != end.level.checkpoints.count
                     || otherSnapshot.level.obstacles.count != end.level.obstacles.count)
        lights.step(toward: otherSnapshot, elapsed: 0)
        #expect(lights.levels == Self.flatTargets(otherSnapshot))
        #expect(lights.checkpoints.count == otherSnapshot.level.checkpoints.count)
        #expect(lights.obstacles.count == otherSnapshot.level.obstacles.count)
    }

    @Test func negativeAndNonFiniteElapsedDoNothing() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let start: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        for move in try Self.solution(core) { #expect(core.apply(Self.action(move)) == .accepted) }
        let end: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
        for reduced in [false, true] {
            var lights: Lights = Lights(reducedFlash: reduced)
            lights.settle(to: start)
            let before: Lights = lights
            for elapsed in [-1.0, -.infinity, .infinity, .nan, 0] {
                lights.step(toward: end, elapsed: elapsed)
                #expect(lights.levels == before.levels, "elapsed \(elapsed)")
            }
            lights.step(toward: end, elapsed: 10)
            #expect(lights.levels == Self.flatTargets(end))
        }
    }

    @Test func measuresOnHandMadeSamples() {
        #expect(Lights.maxHalfRangeCrossingsPerSecond([], frameRate: 60) == 0)
        #expect(Lights.shortestHalfRangeChange([[0]], frameRate: 60) == .infinity)
        // 0 → 1 in 6 frames and back: two crossings, each fade 0.1 s at 60 Hz.
        var samples: [[Double]] = []
        for index in 0...6 { samples.append([Double(index) / 6]) }
        for index in 0...6 { samples.append([1 - Double(index) / 6]) }
        samples.append([0])
        #expect(Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: 60) == 2)
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: 60)
        #expect(abs(shortest - 0.1) < 1e-9)
        #expect(Lights.shortestHalfRangeChange(samples, frameRate: .nan) == .infinity)
    }
}
