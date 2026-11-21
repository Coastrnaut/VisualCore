// AuroraLoomRegressionGoldenFrameTests — feature 308 (R02-G01-08) T-R02G0108-005 (FR-R02G0108-003, 004;
// SC-R02G0108-003; clarification Q3; User Story 2). Through the one app's session host, each of the 16 code-only golden
// frames of `AuroraLoomGolden.frames` (levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at frame time 0, plus the hero
// frame: level 1 after the hero scenario's move, tier 0) is drawn off screen at 96 × 64: the snapshot the presenter shows
// equals `AuroraLoomGolden.snapshot(frame)` (level fingerprint, steps, tick), and the picture passes the feature-303
// frame checks against it (ribbon samples within 2 px of a lit pixel, gate markers within 0.12 per channel of their
// gold, background within 0.05 of night). Seed s opens level s % 100 + 1, so a frame of level L opens at seed L − 1.
// One test per level plus the hero test, each well under 10 s. Synthetic data, explicit types, plain loops, no sleep,
// no wall-clock assertion.
#if os(iOS)
import Foundation
import Testing
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct AuroraLoomRegressionGoldenFrameTests {
    /// The golden frames of `level` without moves (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [AuroraLoomGolden.Frame] {
        var list: [AuroraLoomGolden.Frame] = []
        for frame in AuroraLoomGolden.frames where frame.level == level && frame.moves.isEmpty {
            list.append(frame)
        }
        return list
    }

    /// Sends `moves` through the session's action port as `ribbon.move [ribbon, control, step]`.
    static func apply(_ moves: [AuroraLoomMove], to shell: ExperienceShell<AuroraLoomPresenter>, _ what: String) {
        for move in moves {
            let control: Double = move.control == .wave ? 0 : 1
            let values: [Double] = [Double(move.ribbon), control, Double(move.step)]
            let result: ActionResult = shell.handle(control: "ribbon.move", values: values)
            #expect(result == .accepted, "\(what): move \(values) gave \(result.code)")
        }
    }

    /// Pins `frame`'s tier, renders the 96 × 64 still at frame time 0, compares the shown snapshot with the golden one
    /// and runs the frame checks of clarification Q3.
    static func check(_ frame: AuroraLoomGolden.Frame, session: ExperienceSession,
                      shell: ExperienceShell<AuroraLoomPresenter>) throws {
        let width: Int = AuroraLoomGolden.width
        let height: Int = AuroraLoomGolden.height
        AuroraLoomTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try AuroraLoomTest.still(session, width: width, height: height, time: frame.time)
        let shown: AuroraLoomSceneSnapshot = try #require(shell.presenter.lastSnapshot, "\(frame.name): no snapshot")
        let golden: AuroraLoomSceneSnapshot = try AuroraLoomGolden.snapshot(frame)
        #expect(shown.time == 0, "\(frame.name): the still's frame time is \(shown.time), not 0")
        #expect(shown.level.fingerprint == golden.level.fingerprint, "\(frame.name): level fingerprint differs")
        #expect(shown.steps == golden.steps, "\(frame.name): steps \(shown.steps), golden \(golden.steps)")
        #expect(shown.tick == golden.tick, "\(frame.name): tick \(shown.tick), golden \(golden.tick)")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        AuroraLoomTest.checkFrame(rgba, snapshot: golden, width: width, height: height, frame.name)
    }

    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [AuroraLoomGolden.Frame] = AuroraLoomGolden.frames
        #expect(frames.count == 16)
        #expect(AuroraLoomGolden.width == 96 && AuroraLoomGolden.height == 64)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && !frame.moves.isEmpty)
        }
        #expect(heroes == 1)
        for level in AuroraLoomGolden.levels {
            #expect(Self.tierFrames(level: level).count == 3, "level \(level) has three tier frames")
        }
    }

    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [AuroraLoomGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        let session = ExperienceSession()
        defer { session.close() }
        let seed: UInt64 = UInt64(level - 1)
        let shell = try await AuroraLoomTest.open(session, seed: seed)
        #expect(try #require(shell.engine.core).levelNumber == level)
        for frame in frames {
            Self.apply(frame.moves, to: shell, frame.name)
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [AuroraLoomGolden.Frame] = []
        for frame in AuroraLoomGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: AuroraLoomGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let seed: UInt64 = UInt64(hero.level - 1)
        let shell = try await AuroraLoomTest.open(session, seed: seed)
        #expect(try #require(shell.engine.core).levelNumber == hero.level)
        Self.apply(hero.moves, to: shell, hero.name)
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
