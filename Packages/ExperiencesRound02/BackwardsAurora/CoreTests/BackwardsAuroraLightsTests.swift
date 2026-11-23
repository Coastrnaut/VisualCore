// BackwardsAuroraLightsTests — feature 396 (R02-G10-06) T-R02G1006-004 (FR-R02G1006-004; SC-R02G1006-003;
// clarification Q3). The eased lights of the fixture level (seed 2_396: level 97, which can tear), driven through the
// adapter exactly as the panel sends its actions: the targets (glow 0.7 playing / 1 won / 0.35 failed, won 1 once won,
// tear 1 while the failure is a tear, preview 1 while a preview shows); a scripted win (the certified solution, one
// action per frame) and adversarial flicker (a tear undone and repeated every frame, undo and redo of it, a win and its
// retry, a tear followed by level changes, a level change every frame, retries every 17, 45 or 300 frames, each with
// previews never shown, held and released every frame, or held and released every 5 frames), sampled every 1/60 s
// under Reduce Flashing with every element over its own range 0 … 1: no element crosses half its range more than 3
// times per second and every complete one-way fade of more than half the range takes at least 0.4 s; normally a fade
// takes 0.15 s; settle jumps; the first step settles and later level changes fade; a budget failure dims the glow
// without the tear cross; the result after a win stays won; negative or non-finite elapsed times do nothing. No
// randomness; explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import BackwardsAuroraCore
import VisualCoreExperience

@Suite struct BackwardsAuroraLightsTests {
    typealias Lights = BackwardsAuroraLights
    typealias Core = BackwardsAuroraExperienceCore
    typealias Snapshot = BackwardsAuroraSceneSnapshot
    static let frameRate: Double = 60
    static let frame: Double = 1 / 60
    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_396
    /// The level every test plays: the one the fixture seed picks (97; levels 1 … 97 are open from it).
    static let levelNumber: Int = Core.levelNumber(forSeed: fixtureSeed)
    /// The other open level used for level changes.
    static let otherNumber: Int = 1

    /// The panel action `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func action(_ kernel: BackwardsAuroraAction) -> ExperienceAction {
        switch kernel {
        case let .reverse(start, end):
            action("wave.reverse", [Double(start), Double(end)])
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

    /// The snapshot of `core` with a fixed section and time.
    static func snap(_ core: Core) -> Snapshot {
        core.snapshot(sectionStart: 0, sectionEnd: 1, time: 0)
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

    /// The first reversal that tears the aurora on the level (as `BackwardsAuroraExperienceCoreTests` searches).
    static func tearReverse() throws -> ExperienceAction {
        let core: Core = try opening()
        let count: Int = core.play.wave.count
        for start in 0..<(count - 1) {
            for end in (start + 1)..<count {
                var copy: Core = core
                let item: ExperienceAction = action("wave.reverse", [Double(start), Double(end)])
                if copy.apply(item) == .accepted, case .tear? = copy.play.failure { return item }
            }
        }
        Issue.record("no tearing reversal on level \(levelNumber)")
        throw CancellationError()
    }

    /// The failed (torn) state of the level.
    static func torn() throws -> Core {
        var core: Core = try opening()
        #expect(core.apply(try tearReverse()) == .accepted)
        #expect(core.play.stage == .failed)
        return core
    }

    /// One sample of every light, each over its own range 0 … 1: the glow is the gain the scene multiplies its glow by,
    /// 0 (dark, before the first snapshot) … 1, so it is sampled as is (its midpoint 0.5 lies between the failed 0.35
    /// and the playing 0.7); the won lift, the tear cross and the preview ribbon as they are.
    static func sample(_ lights: Lights) -> [Double] {
        [lights.glow, lights.won, lights.tear, lights.preview]
    }

    /// Checks the two flash limits on `samples` under Reduce Flashing.
    static func expectWithinLimits(_ samples: [[Double]], _ label: String) {
        let crossings: Double = Lights.maxHalfRangeCrossingsPerSecond(samples, frameRate: frameRate)
        #expect(crossings <= 3, "\(label): \(crossings) crossings per second")
        let shortest: Double = Lights.shortestHalfRangeChange(samples, frameRate: frameRate)
        #expect(shortest >= 0.4, "\(label): a half-range fade took \(shortest) s")
    }

    /// Checks that `lights` rest exactly at the targets of `snapshot` and `previewing`.
    static func expectAtTargets(_ lights: Lights, _ snapshot: Snapshot, previewing: Bool) {
        #expect(lights.isSettled)
        let won: Bool = snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil)
        let glow: Double = won ? 1 : (snapshot.failure == nil ? 0.7 : 0.35)
        #expect(lights.glow == glow)
        #expect(lights.won == (won ? 1 : 0))
        #expect(lights.tear == (snapshot.tear != nil ? 1 : 0))
        #expect(lights.preview == (previewing ? 1 : 0))
    }

    @Test func theFixtureLevelCanTear() throws {
        #expect(Self.levelNumber == 97)
        let failed: Core = try Self.torn()
        #expect(Self.snap(failed).tear != nil)
    }

    @Test func settleJumpsToTheTargetsOfEveryStage() throws {
        let start: Snapshot = Self.snap(try Self.opening())
        let won: Snapshot = Self.snap(try Self.won())
        let failed: Snapshot = Self.snap(try Self.torn())
        var lights: Lights = Lights(reducedFlash: true)
        #expect(lights.glow == 0 && lights.won == 0 && lights.tear == 0 && lights.preview == 0)
        lights.settle(to: won, previewing: false)
        Self.expectAtTargets(lights, won, previewing: false)
        #expect(lights.glow == 1 && lights.won == 1 && lights.tear == 0 && lights.preview == 0)
        lights.settle(to: failed, previewing: true)
        Self.expectAtTargets(lights, failed, previewing: true)
        #expect(lights.glow == 0.35 && lights.won == 0 && lights.tear == 1 && lights.preview == 1)
        lights.settle(to: start, previewing: true)
        Self.expectAtTargets(lights, start, previewing: true)
        #expect(lights.glow == 0.7 && lights.won == 0 && lights.tear == 0 && lights.preview == 1)
        lights.settle(to: start, previewing: false)
        #expect(lights.preview == 0 && lights.isSettled)
        // The first step also settles.
        var first: Lights = Lights(reducedFlash: false)
        first.step(toward: won, previewing: true, elapsed: Self.frame)
        Self.expectAtTargets(first, won, previewing: true)
    }

    @Test func theResultAfterAWinStaysWonAndAfterAFailureStaysFailed() throws {
        var winning: BackwardsAuroraPlay = try Self.won().play
        try winning.handle(.showResult)
        #expect(winning.stage == .result && winning.failure == nil)
        let wonResult: Snapshot = Snapshot(play: winning, levelNumber: Self.levelNumber, sectionStart: 0,
                                           sectionEnd: 1, time: 0)
        #expect(Lights.isWon(wonResult))
        var failing: BackwardsAuroraPlay = try Self.torn().play
        try failing.handle(.showResult)
        let failedResult: Snapshot = Snapshot(play: failing, levelNumber: Self.levelNumber, sectionStart: 0,
                                              sectionEnd: 1, time: 0)
        #expect(!Lights.isWon(failedResult) && failedResult.tear != nil)
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: wonResult, previewing: false)
        #expect(lights.glow == 1 && lights.won == 1 && lights.tear == 0)
        lights.settle(to: failedResult, previewing: false)
        #expect(lights.glow == 0.35 && lights.won == 0 && lights.tear == 1)
    }

    @Test func aBudgetFailureDimsWithoutTheTearCross() throws {
        // Level 1 (breaking limit 128): a neutral pair reversed until the budget is spent fails by budget, never by a
        // tear.
        var core: Core = try Core.opening(number: 1)
        let neutral: ExperienceAction = try #require(BackwardsAuroraExperienceCoreTests.neutralReverse(core))
        for _ in 0..<core.play.level.budget { #expect(core.apply(neutral) == .accepted) }
        try #require(core.play.failure == .budget)
        let failed: Snapshot = Self.snap(core)
        var lights: Lights = Lights(reducedFlash: false)
        lights.settle(to: failed, previewing: false)
        Self.expectAtTargets(lights, failed, previewing: false)
        #expect(lights.glow == 0.35 && lights.tear == 0 && lights.won == 0)
    }

    @Test func aLevelChangeOrRetryFades() throws {
        let start: Snapshot = Self.snap(try Self.opening())
        let failed: Snapshot = Self.snap(try Self.torn())
        let other: Snapshot = Self.snap(try Core.opening(number: Self.otherNumber))
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: failed, previewing: false)
        lights.step(toward: other, previewing: false, elapsed: Self.frame)
        #expect(!lights.isSettled && lights.tear > 0 && lights.tear < 1)
        for _ in 0..<27 { lights.step(toward: start, previewing: false, elapsed: Self.frame) }
        Self.expectAtTargets(lights, start, previewing: false)
    }

    @Test func normalModeSettlesWithinTheDuration() throws {
        let start: Snapshot = Self.snap(try Self.opening())
        let won: Snapshot = Self.snap(try Self.won())
        let failed: Snapshot = Self.snap(try Self.torn())
        let frames: Int = Int((Lights.normalDuration * Self.frameRate).rounded())
        #expect(frames == 9)
        let pairs: [(Snapshot, Snapshot, Bool, Bool)] = [(start, won, false, false), (won, start, false, false),
                                                         (start, failed, false, false), (failed, start, false, false),
                                                         (won, failed, false, false), (start, start, false, true),
                                                         (start, start, true, false), (failed, won, true, false)]
        for (from, to, before, after) in pairs {
            var lights: Lights = Lights(reducedFlash: false)
            lights.settle(to: from, previewing: before)
            for _ in 0..<(frames - 1) { lights.step(toward: to, previewing: after, elapsed: Self.frame) }
            #expect(!lights.isSettled)
            lights.step(toward: to, previewing: after, elapsed: Self.frame)
            Self.expectAtTargets(lights, to, previewing: after)
        }
        // Normally a changed target turns a fade at once: partway into tearing, the undo heads back.
        var turning: Lights = Lights(reducedFlash: false)
        turning.settle(to: start, previewing: false)
        for _ in 0..<4 { turning.step(toward: failed, previewing: false, elapsed: Self.frame) }
        let mid: Double = turning.tear
        turning.step(toward: start, previewing: false, elapsed: Self.frame)
        #expect(turning.tear < mid)
        // Under Reduce Flashing the same change takes 0.45 s and a started fade finishes first.
        var slow: Lights = Lights(reducedFlash: true)
        slow.settle(to: start, previewing: false)
        for _ in 0..<26 { slow.step(toward: failed, previewing: true, elapsed: Self.frame) }
        #expect(!slow.isSettled)
        slow.step(toward: failed, previewing: true, elapsed: Self.frame)
        Self.expectAtTargets(slow, failed, previewing: true)
        var firm: Lights = Lights(reducedFlash: true)
        firm.settle(to: start, previewing: false)
        for _ in 0..<4 { firm.step(toward: failed, previewing: true, elapsed: Self.frame) }
        let started: Double = firm.tear
        let shown: Double = firm.preview
        firm.step(toward: start, previewing: false, elapsed: Self.frame)
        #expect(firm.tear > started && firm.preview > shown)
    }

    @Test func badElapsedTimesDoNothing() throws {
        let start: Snapshot = Self.snap(try Self.opening())
        let won: Snapshot = Self.snap(try Self.won())
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: start, previewing: false)
        let bad: [Double] = [-1, -.infinity, .infinity, .nan, 0]
        for elapsed in bad {
            lights.step(toward: won, previewing: true, elapsed: elapsed)
            #expect(lights.glow == 0.7 && lights.won == 0 && lights.preview == 0, "\(elapsed)")
        }
        #expect(!lights.isSettled)
        lights.step(toward: won, previewing: true, elapsed: Self.frame)
        #expect(lights.glow > 0.7 && lights.won > 0 && lights.preview > 0)
    }

    @Test func aScriptedWinStaysWithinTheLimits() throws {
        var core: Core = try Self.opening()
        var lights: Lights = Lights(reducedFlash: true)
        lights.settle(to: Self.snap(core), previewing: false)
        var samples: [[Double]] = [Self.sample(lights)]
        for item in try Self.scriptedWin() where core.play.stage == .playing {
            #expect(core.apply(item) == .accepted)
            lights.step(toward: Self.snap(core), previewing: false, elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        #expect(core.play.stage == .won)
        for _ in 0..<60 {
            lights.step(toward: Self.snap(core), previewing: false, elapsed: Self.frame)
            samples.append(Self.sample(lights))
        }
        Self.expectAtTargets(lights, Self.snap(core), previewing: false)
        #expect(lights.glow == 1 && lights.won == 1)
        Self.expectWithinLimits(samples, "scripted win")
    }

    /// Runs `frames` frames of a flicker `pattern` (one action per frame, refusals allowed) on the level under
    /// `reducedFlash`, retrying the level every `retryEvery` frames and showing a preview on the frames `previewing`
    /// picks; returns the samples and the accepted actions.
    static func flicker(pattern: [ExperienceAction], frames: Int, retryEvery: Int, previewing: (Int) -> Bool,
                        reducedFlash: Bool = true) throws -> ([[Double]], Int) {
        var core: Core = try opening()
        var lights: Lights = Lights(reducedFlash: reducedFlash)
        lights.settle(to: snap(core), previewing: previewing(0))
        var samples: [[Double]] = [sample(lights)]
        var accepted: Int = 0
        for index in 0..<frames {
            let item: ExperienceAction = index > 0 && index % retryEvery == 0 ? retry : pattern[index % pattern.count]
            if core.apply(item) == .accepted { accepted += 1 }
            lights.step(toward: snap(core), previewing: previewing(index + 1), elapsed: frame)
            samples.append(sample(lights))
        }
        return (samples, accepted)
    }

    /// The flicker patterns: a tear undone and repeated every frame, its undo and redo, a win and its retry, a tear
    /// followed by level changes, and a level change every frame.
    static func patterns() throws -> [(String, [ExperienceAction])] {
        let fail: ExperienceAction = try tearReverse()
        let undo: ExperienceAction = action("play.undo")
        let redo: ExperienceAction = action("play.redo")
        var flip: [ExperienceAction] = []
        let redone: [ExperienceAction] = [fail, undo, redo, undo, redo, undo]
        for _ in 0..<20 { flip += [fail, undo] }
        return [("tear and undo", flip + [retry]),
                ("undo and redo", redone + [retry]),
                ("win and retry", try scriptedWin() + [retry]),
                ("tear and change level", [fail, other, retry]),
                ("change level every frame", [other, retry])]
    }

    /// The preview patterns: never shown, held and released every frame, held and released every 5 frames.
    static let previewPatterns: [String] = ["no preview", "preview every frame", "preview every 5 frames"]

    /// Whether preview pattern `pattern` (an index of ``previewPatterns``) shows a preview on frame `frame`.
    static func previewShows(pattern: Int, frame: Int) -> Bool {
        switch pattern {
        case 0: false
        case 1: frame % 2 == 1
        default: (frame / 5) % 2 == 1
        }
    }

    @Test func adversarialFlickerStaysWithinTheLimits() throws {
        for (label, pattern) in try Self.patterns() {
            for (index, previewLabel) in Self.previewPatterns.enumerated() {
                for retry in [17, 45, 300] {
                    let previewing: (Int) -> Bool = { Self.previewShows(pattern: index, frame: $0) }
                    let (samples, accepted): ([[Double]], Int) = try Self.flicker(pattern: pattern, frames: 300,
                                                                                  retryEvery: retry,
                                                                                  previewing: previewing)
                    let name: String = "\(label), \(previewLabel), retry \(retry)"
                    #expect(accepted > 100, "\(name): \(accepted) accepted")
                    Self.expectWithinLimits(samples, name)
                }
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
        // Without Reduce Flashing a tear flipped every 9 frames, with a preview flipped alongside, would blink: the
        // slower fade holds the limit.
        let fail: ExperienceAction = try Self.tearReverse()
        var pattern: [ExperienceAction] = []
        for _ in 0..<20 {
            pattern.append(fail)
            pattern += Array(repeating: Self.action("tutorial.dismiss"), count: 8)
            pattern.append(Self.action("play.undo"))
            pattern += Array(repeating: Self.action("tutorial.dismiss"), count: 8)
        }
        let previewing: (Int) -> Bool = { ($0 / 9) % 2 == 1 }
        let (fast, _): ([[Double]], Int) = try Self.flicker(pattern: pattern, frames: 240, retryEvery: 1_000,
                                                             previewing: previewing, reducedFlash: false)
        let (slow, _): ([[Double]], Int) = try Self.flicker(pattern: pattern, frames: 240, retryEvery: 1_000,
                                                             previewing: previewing)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(fast, frameRate: 60) > 3)
        #expect(Lights.maxHalfRangeCrossingsPerSecond(slow, frameRate: 60) <= 3)
        Self.expectWithinLimits(slow, "nine-frame flicker")
    }
}
