// AuroraLoomLightsTests — feature 306 (R02-G01-06) T-R02G0106-004 (FR-R02G0106-004; clarification Q3;
// SC-R02G0106-003). The eased lights: a scripted win sampled every 1/60 s under Reduce Flashing crosses half the range at
// most 3 times per second and every change of more than half the range takes at least 0.4 s; normally a target is reached
// within 0.15 s and one frame; a target flipping every frame (and other adversarial patterns) still stays at most 3
// crossings per second under Reduce Flashing; settle jumps to the targets; negative and non-finite elapsed times do
// nothing. Explicit types, plain loops, short runs.
import Testing
@testable import AuroraLoomCore
import VisualCoreExperience

@Suite struct AuroraLoomLightsTests {
    typealias Core = AuroraLoomExperienceCore
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60

    /// The `ribbon.move` action for a kernel move.
    static func action(_ move: AuroraLoomMove) -> ExperienceAction {
        let control: Double = move.control == .wave ? 0 : 1
        return ExperienceAction(control: "ribbon.move", values: [Double(move.ribbon), control, Double(move.step)],
                                step: 0)
    }

    /// Plays the certified solution of seed 0, one move per 0.2 s, while stepping lights at 60 Hz for 3 s; returns the
    /// sampled levels (13 per frame) and whether the play was won.
    static func scriptedWin(reducedFlash: Bool) async throws -> (samples: [[Double]], won: Bool) {
        var core: Core = try await Core.prepare(seed: 0)
        let moves: [AuroraLoomMove] = try Core.generated(number: core.levelNumber).solution.moves
        var lights: AuroraLoomLights = AuroraLoomLights(reducedFlash: reducedFlash)
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
            lights.step(toward: core.snapshot(time: seconds * 120), elapsed: Self.frame)
            samples.append(lights.levels)
        }
        return (samples, core.play.stage == .won)
    }

    @Test func scriptedWinUnderReduceFlashing() async throws {
        let run: (samples: [[Double]], won: Bool) = try await Self.scriptedWin(reducedFlash: true)
        #expect(run.won)
        #expect(run.samples.last?.last == 1, "the glow reaches 1")
        let rate: Double = AuroraLoomLights.maxHalfRangeCrossingsPerSecond(run.samples, frameRate: Self.frameRate)
        #expect(rate >= 1 && rate <= 3, "\(rate) crossings per second")
        let shortest: Double = AuroraLoomLights.shortestHalfRangeChange(run.samples, frameRate: Self.frameRate)
        #expect(shortest >= 0.4, "\(shortest) s")
        #expect(shortest.isFinite, "the glow fades in completely, so there is a measured change")
    }

    @Test func scriptedWinNormallyFadesFast() async throws {
        let run: (samples: [[Double]], won: Bool) = try await Self.scriptedWin(reducedFlash: false)
        #expect(run.won)
        let shortest: Double = AuroraLoomLights.shortestHalfRangeChange(run.samples, frameRate: Self.frameRate)
        #expect(shortest > 0 && shortest <= 0.15 + Self.frame + 1e-9, "\(shortest) s")
    }

    @Test func normalTargetsAreReachedWithinDurationAndOneFrame() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let start: AuroraLoomSceneSnapshot = core.snapshot(time: 0)
        let moves: [AuroraLoomMove] = try Core.generated(number: core.levelNumber).solution.moves
        for move in moves { #expect(core.apply(Self.action(move)) == .accepted) }
        let end: AuroraLoomSceneSnapshot = core.snapshot(time: 0)
        let targets: [Double] = AuroraLoomLights.targets(of: end)
        #expect(targets != AuroraLoomLights.targets(of: start))
        for reduced in [false, true] {
            var lights: AuroraLoomLights = AuroraLoomLights(reducedFlash: reduced)
            lights.settle(to: start)
            let duration: Double = reduced ? AuroraLoomLights.reducedFlashDuration : AuroraLoomLights.normalDuration
            let frames: Int = Int((duration * Self.frameRate).rounded()) + 1
            for index in 0..<frames {
                lights.step(toward: end, elapsed: Self.frame)
                if index < frames - 2 { #expect(lights.levels != targets, "not instantly, frame \(index)") }
            }
            #expect(lights.levels == targets, "reduced \(reduced)")
        }
    }

    @Test func adversarialTogglingStaysSlowUnderReduceFlashing() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let playing: AuroraLoomSceneSnapshot = core.snapshot(time: 0)
        var winner: Core = core
        let moves: [AuroraLoomMove] = try Core.generated(number: core.levelNumber).solution.moves
        for move in moves { #expect(winner.apply(Self.action(move)) == .accepted) }
        let won: AuroraLoomSceneSnapshot = winner.snapshot(time: 0)
        #expect(AuroraLoomLights.targets(of: won).last == 1 && AuroraLoomLights.targets(of: playing).last == 0)
        var state: UInt64 = 2_306
        for pattern in 0..<4 {
            var lights: AuroraLoomLights = AuroraLoomLights(reducedFlash: true)
            lights.settle(to: playing)
            var samples: [[Double]] = [lights.levels]
            for frame in 0..<300 {
                let high: Bool
                switch pattern {
                case 0: high = frame % 2 == 0
                case 1: high = frame < 14 || frame % 2 == 0
                case 2: high = frame % 7 < 4
                default:
                    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    high = (state >> 33) & 1 == 1
                }
                lights.step(toward: high ? won : playing, elapsed: Self.frame)
                samples.append(lights.levels)
            }
            let rate: Double = AuroraLoomLights.maxHalfRangeCrossingsPerSecond(samples, frameRate: Self.frameRate)
            #expect(rate <= 3, "pattern \(pattern): \(rate)")
            let shortest: Double = AuroraLoomLights.shortestHalfRangeChange(samples, frameRate: Self.frameRate)
            #expect(shortest >= 0.4, "pattern \(pattern): \(shortest)")
        }
        // Without the commitment, pattern 1 would hover at half the range and cross it every frame: the normal speed
        // with the same pattern shows the measure does detect fast blinking.
        var normal: AuroraLoomLights = AuroraLoomLights(reducedFlash: false)
        normal.settle(to: playing)
        var fast: [[Double]] = [normal.levels]
        for frame in 0..<120 {
            normal.step(toward: frame % 12 < 6 ? won : playing, elapsed: Self.frame)
            fast.append(normal.levels)
        }
        #expect(AuroraLoomLights.maxHalfRangeCrossingsPerSecond(fast, frameRate: Self.frameRate) > 3)
    }

    @Test func settleJumpsAndBadElapsedDoesNothing() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let moves: [AuroraLoomMove] = try Core.generated(number: core.levelNumber).solution.moves
        for move in moves { #expect(core.apply(Self.action(move)) == .accepted) }
        let won: AuroraLoomSceneSnapshot = core.snapshot(time: 0)
        var lights: AuroraLoomLights = AuroraLoomLights(reducedFlash: true)
        #expect(lights.crossings.count == 12 && lights.glow == 0)
        let dark: AuroraLoomLights = lights
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: won, elapsed: elapsed)
            #expect(lights.levels == dark.levels, "elapsed \(elapsed)")
        }
        lights.settle(to: won)
        #expect(lights.levels == AuroraLoomLights.targets(of: won) && lights.glow == 1)
        let settled: AuroraLoomLights = lights
        lights.step(toward: won, elapsed: 10)
        #expect(lights == settled)
    }

    @Test func measuresOnKnownSamples() {
        let ramp: [[Double]] = [[0], [0.25], [0.5], [0.75], [1], [1], [0.5], [0]]
        // Crossings at steps 1 (0.25 → 0.5) and 6 (0.5 → 0): five steps apart, so one per 4-step window, two per 8.
        #expect(AuroraLoomLights.maxHalfRangeCrossingsPerSecond(ramp, frameRate: 4) == 1)
        #expect(AuroraLoomLights.maxHalfRangeCrossingsPerSecond(ramp, frameRate: 8) == 2)
        // Up 0 → 1 in 4 steps (1 s at 4 Hz); down 1 → 0 in 2 steps is unfinished at the end and skipped.
        #expect(AuroraLoomLights.shortestHalfRangeChange(ramp, frameRate: 4) == 1)
        let finished: [[Double]] = ramp + [[0]]
        #expect(AuroraLoomLights.shortestHalfRangeChange(finished, frameRate: 4) == 0.5)
        #expect(AuroraLoomLights.shortestHalfRangeChange([[0], [0.4], [0.4]], frameRate: 4) == .infinity)
        #expect(AuroraLoomLights.maxHalfRangeCrossingsPerSecond([], frameRate: 60) == 0)
    }
}
