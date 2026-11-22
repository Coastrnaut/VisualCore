// ChronoConstellatorLightsTests — feature 356 (R02-G06-06) T-R02G0606-003 (FR-R02G0606-004; SC-R02G0606-003;
// clarification Q3). The eased lights of certified level 1, driven through the adapter exactly as the panel sends its
// actions: the targets (rings 1 lit / 0.5, nodes 1 on target / 0.7, glow 1 when won, collision mark 1 on a collision);
// a scripted win (the certified phase changes, then steps of 1 tick, one action per frame) and adversarial flicker (a
// phase changed onto a target and undone every frame, a tick and its undo, steps of 1 tick and a rewind, a failing run
// and its rewind, a collision undone or rewound, a win and its retry through `level.select`, and retries every 17, 45
// or 300 frames), sampled every 1/60 s under Reduce Flashing with every element normalised to its own range: no element
// crosses half its range more than 3 times per second and every complete one-way fade of more than half the range takes
// at least 0.4 s; normally a target is reached within 0.15 s; settle jumps; a new level settles and resizes; negative
// and non-finite elapsed times do nothing; the measure detects fast blinking. Explicit types, plain loops, short runs,
// no wall-clock asserts.
import Testing
@testable import ChronoConstellatorCore
import VisualCoreExperience

@Suite struct ChronoConstellatorLightsTests {
    typealias Lights = ChronoConstellatorLights
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// The certified level every test plays.
    static let levelNumber: Int = 1

    /// The panel action `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func action(_ kernel: ChronoConstellatorAction) -> ExperienceAction {
        switch kernel {
        case .phase(let star, let offset):
            return action("star.phase", [Double(star), Double(offset)])
        case .hold(let star, let start, let length):
            return action("star.hold", [Double(star), Double(start), Double(length)])
        case .release(let star, let start):
            return action("star.release", [Double(star), Double(start)])
        case .step(let ticks):
            return action("time.step", [Double(ticks)])
        case .rewind:
            return action("time.rewind")
        }
    }

    /// The retry action: the same level selected again.
    static var retry: ExperienceAction { action("level.select", [Double(levelNumber)]) }

    /// The opening state of certified level 1.
    static func opening() throws -> ChronoConstellatorExperienceCore {
        try ChronoConstellatorExperienceCore.opening(number: levelNumber)
    }

    /// The certified level 1 and its proof.
    static func generated() throws -> ChronoConstellatorGenerated {
        try ChronoConstellatorExperienceCore.generated(number: levelNumber)
    }

    /// The certified win of level 1: its phase changes, then steps of 1 tick up to the tick limit.
    static func scriptedWin() throws -> [ExperienceAction] {
        let generated: ChronoConstellatorGenerated = try generated()
        var result: [ExperienceAction] = []
        for kernel in ChronoConstellatorWitness.actions(for: generated.solution, level: generated.level) {
            if case .step(let ticks) = kernel {
                for _ in 0..<ticks { result.append(action("time.step", [1])) }
            } else {
                result.append(action(kernel))
            }
        }
        return result
    }

    /// The opening of level 1 played through `actions` while the play is playing.
    static func played(_ actions: [ExperienceAction]) throws -> ChronoConstellatorExperienceCore {
        var core: ChronoConstellatorExperienceCore = try opening()
        for item in actions where core.play.stage == .playing { _ = core.apply(item) }
        return core
    }

    /// The won state of level 1.
    static func won() throws -> ChronoConstellatorExperienceCore {
        let core: ChronoConstellatorExperienceCore = try played(try scriptedWin())
        #expect(core.play.stage == .won)
        return core
    }

    /// The first single phase change of level 1 (star order, then offset order) after which a run to the tick limit
    /// ends in a collision, with that run; nil when none does.
    static func collidingRun() throws -> [ChronoConstellatorAction]? {
        let level: ChronoConstellatorLevel = try generated().level
        for star in level.stars.indices {
            for offset in 0..<level.stars[star].loop.count where offset != level.stars[star].phase {
                var play: ChronoConstellatorPlay = try ChronoConstellatorExperienceCore.freshPlay(of: level)
                let run: [ChronoConstellatorAction] = [.phase(star, offset), .step(level.tickLimit)]
                var accepted: Bool = true
                for kernel in run {
                    do {
                        try play.apply(kernel, expecting: play.fingerprint)
                    } catch {
                        accepted = false
                    }
                }
                if accepted, case .collision = play.failure { return run }
            }
        }
        return nil
    }

    /// One sample of every light, each normalised to 0 … 1 over its own range: rings (level − 0.5) / 0.5, nodes
    /// (level − 0.7) / 0.3, the glow and the collision mark.
    static func sample(_ lights: Lights) -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(lights.rings.count + lights.nodes.count + 2)
        for ring in lights.rings {
            values.append((ring - Lights.ringUnlit) / (Lights.ringLit - Lights.ringUnlit))
        }
        for node in lights.nodes {
            values.append((node - Lights.nodeOffTarget) / (Lights.nodeOnTarget - Lights.nodeOffTarget))
        }
        values.append(lights.glow)
        values.append(lights.collision)
        return values
    }

    /// Checks the two flash limits on `samples` under Reduce Flashing.
    static func expectWithinLimits(_ samples: [[Double]], _ label: String) {
        let crossings: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "\(label): \(crossings) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): a half-range fade took \(shortest) s")
    }

    /// Checks that `lights` rest exactly at the targets of `snapshot`.
    static func expectAtTargets(_ lights: Lights, _ snapshot: ChronoConstellatorSceneSnapshot) {
        #expect(lights.isSettled)
        #expect(lights.rings.count == snapshot.stars.count && lights.nodes.count == snapshot.stars.count)
        for index in 0..<min(lights.rings.count, snapshot.stars.count) {
            let on: Bool = snapshot.stars[index].onTarget
            #expect(lights.rings[index] == (on ? 1 : 0.5), "ring \(index)")
            #expect(lights.nodes[index] == (on ? 1 : 0.7), "node \(index)")
        }
        #expect(lights.glow == (snapshot.stage == .won ? 1 : 0))
        var collided: Bool = false
        if case .collision = snapshot.failure { collided = true }
        #expect(lights.collision == (collided ? 1 : 0))
    }

    @Test func settleJumpsToTheTargets() throws {
        let start: ChronoConstellatorSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: ChronoConstellatorSceneSnapshot = try Self.won().snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.rings.isEmpty && lights.nodes.isEmpty && lights.glow == 0 && lights.collision == 0)
        lights.settle(to: won)
        Self.expectAtTargets(lights, won)
        #expect(lights.glow == 1)
        for ring in lights.rings { #expect(ring == 1) }
        lights.settle(to: start)
        Self.expectAtTargets(lights, start)
        // The first step also settles.
        var first: Lights = Lights(reducedFlash: false)
        first.step(toward: won, elapsed: Self.frame)
        Self.expectAtTargets(first, won)
    }

    @Test func aCollisionLightsTheMark() throws {
        let witness: ChronoConstellatorWitness = try ChronoConstellatorWitness.make(try Self.generated())
        let colliding: [ChronoConstellatorAction]? = try Self.collidingRun()
        try #require(colliding != nil)
        let runs: [[ChronoConstellatorAction]] = [witness.unedited.actions, witness.nearMiss.actions, colliding ?? []]
        var collisions: Int = 0
        for run in runs {
            var core: ChronoConstellatorExperienceCore = try Self.opening()
            for kernel in run { #expect(core.apply(Self.action(kernel)) == .accepted) }
            #expect(core.play.stage == .failed)
            let failed: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
            if case .collision = failed.failure { collisions += 1 }
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: failed)
            Self.expectAtTargets(lights, failed)
            // A rewind clears the failure: the mark fades out within 0.15 s.
            #expect(core.apply(Self.action("time.rewind")) == .accepted)
            let rewound: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
            for _ in 0..<9 { lights.step(toward: rewound, elapsed: Self.frame) }
            Self.expectAtTargets(lights, rewound)
            #expect(lights.collision == 0)
        }
        #expect(collisions >= 1)
    }

    @Test func aNewLevelSettlesAndResizes() throws {
        let start: ChronoConstellatorSceneSnapshot = try Self.opening().snapshot(time: 0)
        let other: ChronoConstellatorSceneSnapshot = try ChronoConstellatorExperienceCore.opening(number: 2)
            .snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: start)
        lights.step(toward: other, elapsed: Self.frame)
        Self.expectAtTargets(lights, other)
        lights.step(toward: start, elapsed: Self.frame)
        Self.expectAtTargets(lights, start)
        // A retry of the same level is a fade, not a jump.
        let won: ChronoConstellatorSceneSnapshot = try Self.won().snapshot(time: 0)
        lights.step(toward: won, elapsed: Self.frame)
        #expect(!lights.isSettled && lights.glow > 0 && lights.glow < 1)
    }

    @Test func normalModeReachesTargetsWithinTheDuration() throws {
        let start: ChronoConstellatorSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: ChronoConstellatorSceneSnapshot = try Self.won().snapshot(time: 0)
        let frames: Int = Int((Lights.normalDuration * Self.frameRate).rounded())
        #expect(frames == 9)
        // From the start to the won state and back (a retry), both ways within 0.15 s, not one frame sooner.
        let pairs: [(ChronoConstellatorSceneSnapshot, ChronoConstellatorSceneSnapshot)] = [(start, won), (won, start)]
        for (from, to) in pairs {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: from)
            for _ in 0..<(frames - 1) { lights.step(toward: to, elapsed: Self.frame) }
            #expect(!lights.isSettled && lights.glow > 0 && lights.glow < 1)
            lights.step(toward: to, elapsed: Self.frame)
            Self.expectAtTargets(lights, to)
        }
        // Under Reduce Flashing the same change takes 0.45 s.
        var slow: Lights = Lights(reducedFlash: true)
        slow.settle(to: start)
        for _ in 0..<26 { slow.step(toward: won, elapsed: Self.frame) }
        #expect(!slow.isSettled)
        slow.step(toward: won, elapsed: Self.frame)
        Self.expectAtTargets(slow, won)
    }

    @Test func badElapsedTimesDoNothing() throws {
        let start: ChronoConstellatorSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: ChronoConstellatorSceneSnapshot = try Self.won().snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: start)
        let before: Lights = lights
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: won, elapsed: elapsed)
            #expect(lights.rings == before.rings && lights.nodes == before.nodes, "\(elapsed)")
            #expect(lights.glow == 0 && lights.collision == 0, "\(elapsed)")
        }
        #expect(!lights.isSettled)
        lights.step(toward: won, elapsed: Self.frame)
        #expect(lights.glow > 0)
    }

    @Test func aScriptedWinStaysWithinTheLimits() throws {
        var core: ChronoConstellatorExperienceCore = try Self.opening()
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
        // The win glow faded in over 0.45 s, a complete one-way fade of the whole range.
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: Self.frameRate)
        #expect(shortest.isFinite)
    }

    /// Runs `frames` frames of a flicker `pattern` (one action per frame, refusals allowed) on level 1 under Reduce
    /// Flashing, retrying the level every `retryEvery` frames; returns the samples and the accepted actions.
    static func flicker(pattern: [ExperienceAction], frames: Int, retryEvery: Int) throws -> ([[Double]], Int) {
        var core: ChronoConstellatorExperienceCore = try opening()
        var lights: Lights = Lights(reducedFlash: true)
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

    @Test func adversarialFlickerStaysWithinTheLimits() throws {
        let generated: ChronoConstellatorGenerated = try Self.generated()
        let level: ChronoConstellatorLevel = generated.level
        let witness: ChronoConstellatorWitness = try ChronoConstellatorWitness.make(generated)
        var patterns: [(String, [ExperienceAction])] = []
        for star in level.stars.indices {
            // A phase that puts the star on its target at tick 0, changed and undone every frame.
            let loop: [Int] = level.stars[star].loop
            if let offset = loop.firstIndex(of: level.stars[star].target), offset != level.stars[star].phase {
                patterns.append(("star \(star) onto target and undo",
                                 [Self.action("star.phase", [Double(star), Double(offset)]), Self.action("play.undo")]))
            }
        }
        #expect(!patterns.isEmpty)
        patterns.append(("tick and undo", [Self.action("time.step", [1]), Self.action("play.undo")]))
        let ticks: ExperienceAction = Self.action("time.step", [1])
        patterns.append(("ticks and rewind", [ticks, ticks, ticks, Self.action("time.rewind")]))
        var failing: [ExperienceAction] = []
        for kernel in witness.unedited.actions { failing.append(Self.action(kernel)) }
        patterns.append(("fail and rewind", failing + [Self.action("time.rewind")]))
        var nearMiss: [ExperienceAction] = []
        for kernel in witness.nearMiss.actions { nearMiss.append(Self.action(kernel)) }
        patterns.append(("near miss and undo", nearMiss + [Self.action("play.undo")]))
        var colliding: [ExperienceAction] = []
        for kernel in try Self.collidingRun() ?? [] { colliding.append(Self.action(kernel)) }
        #expect(!colliding.isEmpty)
        patterns.append(("collide and undo", colliding + [Self.action("play.undo")]))
        patterns.append(("collide and rewind", colliding + [Self.action("time.rewind")]))
        var winning: [ExperienceAction] = []
        for kernel in ChronoConstellatorWitness.actions(for: generated.solution, level: level) {
            winning.append(Self.action(kernel))
        }
        patterns.append(("win and retry", winning + [Self.retry]))
        let retries: [Int] = [17, 45, 300]
        for (label, pattern) in patterns {
            for retry in retries {
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
        // Without Reduce Flashing a per-frame flicker would blink: the slower fade is what holds the limit.
        var fast: Lights = Lights(reducedFlash: false)
        var slow: Lights = Lights(reducedFlash: true)
        let start: ChronoConstellatorSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: ChronoConstellatorSceneSnapshot = try Self.won().snapshot(time: 0)
        fast.settle(to: start)
        slow.settle(to: start)
        var fastSamples: [[Double]] = []
        var slowSamples: [[Double]] = []
        for index in 0..<120 {
            let target: ChronoConstellatorSceneSnapshot = (index / 9) % 2 == 0 ? won : start
            fast.step(toward: target, elapsed: Self.frame)
            slow.step(toward: target, elapsed: Self.frame)
            fastSamples.append([fast.glow])
            slowSamples.append([slow.glow])
        }
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fastSamples, frameRate: 60) > 3)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(slowSamples, frameRate: 60) <= 3)
    }
}
