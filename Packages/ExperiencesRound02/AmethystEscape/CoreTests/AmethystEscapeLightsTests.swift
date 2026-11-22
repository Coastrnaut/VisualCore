// AmethystEscapeLightsTests — feature 366 (R02-G07-06) T-R02G0706-004 (FR-R02G0706-004; SC-R02G0706-003;
// clarification Q3). The eased lights of the level seed 2_366 chooses, driven through the adapter exactly as the panel
// sends its actions: the targets (pearl 1 playing / 0.6 failed, exit 0.5 / 1 escaped, wedge 1 when failed in a blocked
// wedge); a scripted win (the certified solution, one action per frame) and adversarial flicker (a wedge failure undone
// and repeated every frame, undo and redo of it, a win and its retry, a failure and level changes, retries every 17,
// 45 or 300 frames), sampled every 1/60 s under Reduce Flashing with every element normalised to its own range: no
// element crosses half its range more than 3 times per second and every complete one-way fade of more than half the
// range takes at least 0.4 s; normally a fade takes 0.15 s; settle jumps; the first step settles and later level
// changes fade; negative or non-finite elapsed times do nothing. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import AmethystEscapeCore
import VisualCoreExperience

@Suite struct AmethystEscapeLightsTests {
    typealias Lights = AmethystEscapeLights
    typealias Core = AmethystEscapeExperienceCore
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// The seed every test prepares from (level `2_366 % 100 + 1`).
    static let seed: UInt64 = 2_366
    /// The level the seed chooses.
    static var levelNumber: Int { Core.levelNumber(forSeed: seed) }

    /// The panel action `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func action(_ kernel: AmethystEscapeAction) -> ExperienceAction {
        switch kernel {
        case .rotate(let shell, let step): action("shell.rotate", [Double(shell), Double(step)])
        case .advance: action("pearl.advance")
        }
    }

    /// The retry action: the same level selected again.
    static var retry: ExperienceAction { action("level.select", [Double(levelNumber)]) }

    /// The opening state of the seed's level (campaign; the levels up to it open).
    static func opening() throws -> Core {
        try Core.opening(number: levelNumber)
    }

    /// The certified winning actions of the seed's level.
    static func scriptedWin() throws -> [ExperienceAction] {
        var result: [ExperienceAction] = []
        for kernel in try Core.generated(number: levelNumber).solution.actions { result.append(action(kernel)) }
        return result
    }

    /// The won state of the seed's level.
    static func won() throws -> Core {
        var core: Core = try opening()
        for item in try scriptedWin() { _ = core.apply(item) }
        #expect(core.play.stage == .won)
        return core
    }

    /// The shortest kernel action sequence (breadth first over turns of every shell by ±1 and advances, at most 8
    /// actions) from the opening play of the seed's level whose last action drops the pearl into a blocked wedge;
    /// nil when there is none that short.
    static func wedgeRun() throws -> [AmethystEscapeAction]? {
        let level: AmethystEscapeLevel = try Core.level(number: levelNumber)
        var moves: [AmethystEscapeAction] = [.advance]
        for shell in level.shells.indices {
            moves.append(.rotate(shell, 1))
            moves.append(.rotate(shell, -1))
        }
        var frontier: [(AmethystEscapePlay, [AmethystEscapeAction])] = [(try Core.freshPlay(of: level), [])]
        var seen: Set<String> = []
        for _ in 0..<8 {
            var next: [(AmethystEscapePlay, [AmethystEscapeAction])] = []
            for (play, path) in frontier {
                for move in moves {
                    var copy: AmethystEscapePlay = play
                    do {
                        try copy.apply(move, expecting: copy.fingerprint)
                    } catch {
                        continue
                    }
                    if case .wedge = copy.failure { return path + [move] }
                    guard copy.stage == .playing else { continue }
                    let key: String = "\(copy.crystal)"
                    if seen.insert(key).inserted { next.append((copy, path + [move])) }
                }
            }
            frontier = next
        }
        return nil
    }

    /// The setup before a wedge failure and the failing action, as adapter actions.
    static func wedgeSetup() throws -> ([ExperienceAction], ExperienceAction) {
        let run: [AmethystEscapeAction]? = try wedgeRun()
        try #require(run != nil)
        let kernel: [AmethystEscapeAction] = run ?? []
        var setup: [ExperienceAction] = []
        for item in kernel.dropLast() { setup.append(action(item)) }
        return (setup, action(kernel.last ?? .advance))
    }

    /// One sample of every light, each normalised to 0 … 1 over its own range: pearl (level − 0.6) / 0.4, exit
    /// (level − 0.5) / 0.5, wedge as is.
    static func sample(_ lights: Lights) -> [Double] {
        [(lights.pearl - Lights.pearlFailed) / (Lights.pearlPlaying - Lights.pearlFailed),
         (lights.exit - Lights.exitResting) / (Lights.exitEscaped - Lights.exitResting),
         lights.wedge]
    }

    /// Checks the two flash limits on `samples` under Reduce Flashing.
    static func expectWithinLimits(_ samples: [[Double]], _ label: String) {
        let crossings: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "\(label): \(crossings) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): a half-range fade took \(shortest) s")
    }

    /// Checks that `lights` rest exactly at the targets of `snapshot`.
    static func expectAtTargets(_ lights: Lights, _ snapshot: AmethystEscapeSceneSnapshot) {
        #expect(lights.isSettled)
        #expect(lights.pearl == (snapshot.failure == nil ? 1 : 0.6))
        #expect(lights.exit == (snapshot.escaped ? 1 : 0.5))
        var wedged: Bool = false
        if case .wedge = snapshot.failure { wedged = true }
        #expect(lights.wedge == (wedged ? 1 : 0))
    }

    /// The failed (blocked wedge) state of the seed's level.
    static func wedged() throws -> Core {
        let (setup, fail): ([ExperienceAction], ExperienceAction) = try wedgeSetup()
        var core: Core = try opening()
        for item in setup { #expect(core.apply(item) == .accepted) }
        #expect(core.apply(fail) == .accepted)
        #expect(core.play.stage == .failed)
        return core
    }

    @Test func settleJumpsToTheTargets() throws {
        let start: AmethystEscapeSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: AmethystEscapeSceneSnapshot = try Self.won().snapshot(time: 0)
        let failed: AmethystEscapeSceneSnapshot = try Self.wedged().snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.pearl == 0 && lights.exit == 0 && lights.wedge == 0)
        lights.settle(to: won)
        Self.expectAtTargets(lights, won)
        #expect(lights.exit == 1 && lights.pearl == 1 && lights.wedge == 0)
        lights.settle(to: failed)
        Self.expectAtTargets(lights, failed)
        #expect(lights.pearl == 0.6 && lights.exit == 0.5 && lights.wedge == 1)
        lights.settle(to: start)
        Self.expectAtTargets(lights, start)
        // The first step also settles.
        var first: Lights = Lights(reducedFlash: false)
        first.step(toward: won, elapsed: Self.frame)
        Self.expectAtTargets(first, won)
    }

    @Test func aLevelChangeOrRetryFades() throws {
        let start: AmethystEscapeSceneSnapshot = try Self.opening().snapshot(time: 0)
        let failed: AmethystEscapeSceneSnapshot = try Self.wedged().snapshot(time: 0)
        let other: AmethystEscapeSceneSnapshot = try Core.opening(number: Self.levelNumber - 1).snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: failed)
        lights.step(toward: other, elapsed: Self.frame)
        #expect(!lights.isSettled && lights.wedge > 0 && lights.wedge < 1)
        for _ in 0..<27 { lights.step(toward: start, elapsed: Self.frame) }
        Self.expectAtTargets(lights, start)
    }

    @Test func normalModeFadesInTheDuration() throws {
        let start: AmethystEscapeSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: AmethystEscapeSceneSnapshot = try Self.won().snapshot(time: 0)
        let failed: AmethystEscapeSceneSnapshot = try Self.wedged().snapshot(time: 0)
        let frames: Int = Int((Lights.normalDuration * Self.frameRate).rounded())
        #expect(frames == 9)
        let pairs: [(AmethystEscapeSceneSnapshot, AmethystEscapeSceneSnapshot)] = [(start, won), (won, start),
                                                                                   (start, failed), (failed, start)]
        for (from, to) in pairs {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: from)
            for _ in 0..<(frames - 1) { lights.step(toward: to, elapsed: Self.frame) }
            #expect(!lights.isSettled)
            lights.step(toward: to, elapsed: Self.frame)
            Self.expectAtTargets(lights, to)
        }
        // Normally a changed target turns a fade at once: halfway into failing, the undo heads back.
        var turning: Lights = Lights(reducedFlash: false)
        turning.settle(to: start)
        for _ in 0..<4 { turning.step(toward: failed, elapsed: Self.frame) }
        let mid: Double = turning.wedge
        turning.step(toward: start, elapsed: Self.frame)
        #expect(turning.wedge < mid)
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
        let started: Double = firm.wedge
        firm.step(toward: start, elapsed: Self.frame)
        #expect(firm.wedge > started)
    }

    @Test func badElapsedTimesDoNothing() throws {
        let start: AmethystEscapeSceneSnapshot = try Self.opening().snapshot(time: 0)
        let won: AmethystEscapeSceneSnapshot = try Self.won().snapshot(time: 0)
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: start)
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: won, elapsed: elapsed)
            #expect(lights.pearl == 1 && lights.exit == 0.5 && lights.wedge == 0, "\(elapsed)")
        }
        #expect(!lights.isSettled)
        lights.step(toward: won, elapsed: Self.frame)
        #expect(lights.exit > 0.5)
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
        #expect(lights.exit == 1)
        Self.expectWithinLimits(samples, "scripted win")
        // The exit glow faded in over 0.45 s, a complete one-way fade of its whole range.
        #expect(Lights.shortestHalfRangeChange(samples, frameRate: Self.frameRate) == 27 / Self.frameRate)
    }

    /// Runs `frames` frames of a flicker `pattern` (one action per frame, refusals allowed) on the seed's level under
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

    /// The flicker patterns: a wedge failure undone and repeated every frame, its undo and redo, a win and its retry,
    /// and a failure followed by level changes.
    static func patterns() throws -> [(String, [ExperienceAction])] {
        let (setup, fail): ([ExperienceAction], ExperienceAction) = try wedgeSetup()
        let undo: ExperienceAction = action("play.undo")
        let redo: ExperienceAction = action("play.redo")
        var flip: [ExperienceAction] = setup
        var redone: [ExperienceAction] = setup + [fail]
        for _ in 0..<20 {
            flip += [fail, undo]
            redone += [undo, redo]
        }
        let other: ExperienceAction = action("level.select", [Double(levelNumber - 1)])
        return [("wedge and undo", flip + [retry]),
                ("undo and redo", redone + [retry]),
                ("win and retry", try scriptedWin() + [retry]),
                ("fail and change level", setup + [fail, other, retry]),
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
        // Without Reduce Flashing a wedge failure flipped every 9 frames would blink: the slower fade holds the limit.
        let (setup, fail): ([ExperienceAction], ExperienceAction) = try Self.wedgeSetup()
        var pattern: [ExperienceAction] = setup
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
