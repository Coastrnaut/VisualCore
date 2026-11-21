// LissajousLabyrinthRegressionGoldenFrameTests — feature 318 (R02-G02-08) T-R02G0208-005 (FR-R02G0208-004;
// SC-R02G0208-003). Through the one app's session host, each of the 16 code-only golden frames of
// `LissajousLabyrinthGolden.frames` (certified levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 at frame time 0, plus
// the hero frame: level 1 after the hero scenario's one `dial.set`, tier 0) is drawn off screen at the frame-check size
// 1,152 × 768 of `LissajousLabyrinthTest` (clarification Q3; the adapted bound is documented in
// LissajousLabyrinthTestSupport.swift). The snapshot the presenter shows equals
// `LissajousLabyrinthGolden.snapshot(frame)` (level, dials, stage, visits and verdict), so the rendered frame is the
// described one; the picture passes the feature-313/314 frame checks against it (path samples within 2 px of a lit
// pixel, checkpoint rings and obstacles within 0.12 per channel of their colours, background within 0.05 of night);
// and every dial ring's centre and knob of the description projects inside the frame. Seed s opens level
// s % 100 + 1, so a frame of level L opens at seed L − 1. One test per level plus the hero test, each well under
// 10 s. Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion.
#if os(iOS)
import Foundation
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct LissajousLabyrinthRegressionGoldenFrameTests {
    /// The golden frames of `level` without actions (its three tiers), in their fixed order.
    static func tierFrames(level: Int) -> [LissajousLabyrinthGolden.Frame] {
        var list: [LissajousLabyrinthGolden.Frame] = []
        for frame in LissajousLabyrinthGolden.frames where frame.level == level && frame.actions.isEmpty {
            list.append(frame)
        }
        return list
    }

    /// Sends `actions` through the session's action port as `dial.set [dial index, value]`.
    static func apply(_ actions: [LissajousLabyrinthAction], to shell: ExperienceShell<LissajousLabyrinthPresenter>,
                      _ what: String) {
        for action in actions {
            let dial: Int = LissajousLabyrinthExperienceCore.dialOrder.firstIndex(of: action.dial) ?? 0
            let values: [Double] = [Double(dial), Double(action.value)]
            let result: ActionResult = shell.handle(control: "dial.set", values: values)
            #expect(result == .accepted, "\(what): dial.set \(values) gave \(result.code)")
        }
    }

    /// Opens the level of `frame` (seed level − 1) and checks that the engine shows it.
    static func open(_ session: ExperienceSession, level: Int) async throws
        -> ExperienceShell<LissajousLabyrinthPresenter> {
        let seed: UInt64 = UInt64(level - 1)
        #expect(LissajousLabyrinthExperienceCore.levelNumber(forSeed: seed) == level)
        let shell: ExperienceShell<LissajousLabyrinthPresenter> = try await LissajousLabyrinthTest.open(session,
                                                                                                         seed: seed)
        #expect(try #require(shell.engine.core).levelNumber == level)
        return shell
    }

    /// Whether `p` lies inside a `width` × `height` frame.
    static func inside(_ p: Vec2?, width: Int, height: Int) -> Bool {
        guard let p else { return false }
        return p.x >= 0 && p.x <= Double(width) && p.y >= 0 && p.y <= Double(height)
    }

    /// The dial check of the description: each dial ring's centre and its knob at the dial's value project inside the
    /// frame. Returns the misses.
    static func dialMisses(_ snapshot: LissajousLabyrinthSceneSnapshot, width: Int, height: Int) -> [String] {
        let vp: Mat4 = LissajousLabyrinthTest.viewProjection(snapshot, width: width, height: height)
        var misses: [String] = []
        for dial in LissajousLabyrinthDial.allCases {
            let value: Int = snapshot.dials[dial]
            let centre: Vec2? = LissajousLabyrinthSceneGeometry.project(
                LissajousLabyrinthHandles.ringCentre(dial, level: snapshot.level), viewProjection: vp, width: width,
                height: height)
            let knob: Vec2? = LissajousLabyrinthSceneGeometry.project(
                LissajousLabyrinthHandles.knob(dial, value: value, level: snapshot.level), viewProjection: vp,
                width: width, height: height)
            if !inside(centre, width: width, height: height) {
                misses.append("dial \(dial.rawValue): ring centre \(String(describing: centre)) outside the frame")
            }
            if !inside(knob, width: width, height: height) {
                misses.append("dial \(dial.rawValue) = \(value): knob \(String(describing: knob)) outside the frame")
            }
        }
        return misses
    }

    /// Pins `frame`'s tier, renders the 1,152 × 768 still at the frame's time, compares the shown snapshot with the
    /// golden one and runs the frame checks of clarification Q3 and the dial check.
    static func check(_ frame: LissajousLabyrinthGolden.Frame, session: ExperienceSession,
                      shell: ExperienceShell<LissajousLabyrinthPresenter>) throws {
        let width: Int = LissajousLabyrinthGolden.width
        let height: Int = LissajousLabyrinthGolden.height
        LissajousLabyrinthTest.pin(session, shell, tier: frame.tier)
        let rgba: [UInt8] = try LissajousLabyrinthTest.still(session, width: width, height: height, time: frame.time)
        let shown: LissajousLabyrinthSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                  "\(frame.name): no snapshot")
        let golden: LissajousLabyrinthSceneSnapshot = try LissajousLabyrinthGolden.snapshot(frame)
        #expect(shown.time == 0, "\(frame.name): the still's frame time is \(shown.time), not 0")
        #expect(shown.level == golden.level, "\(frame.name): the shown level differs from the golden one")
        #expect(shown.dials == golden.dials, "\(frame.name): dials \(shown.dials), golden \(golden.dials)")
        #expect(shown.stage == golden.stage, "\(frame.name): stage \(shown.stage), golden \(golden.stage)")
        #expect(shown.visits == golden.visits, "\(frame.name): visits \(shown.visits), golden \(golden.visits)")
        #expect(shown.verdict == golden.verdict, "\(frame.name): the verdict differs from the golden one")
        #expect(shell.presenter.fallbackReason == nil, "\(frame.name): \(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.tierLog.last?.tier == frame.tier, "\(frame.name): drawn tier")
        LissajousLabyrinthTest.checkFrame(rgba, snapshot: golden, tier: frame.tier, width: width, height: height,
                                          frame.name)
        let dials: [String] = Self.dialMisses(golden, width: width, height: height)
        #expect(dials.isEmpty, "\(frame.name): \(dials)")
    }

    @Test func theGoldenSetHasSixteenFrames() {
        let frames: [LissajousLabyrinthGolden.Frame] = LissajousLabyrinthGolden.frames
        #expect(frames.count == 16)
        #expect(LissajousLabyrinthGolden.width == LissajousLabyrinthTest.width)
        #expect(LissajousLabyrinthGolden.height == LissajousLabyrinthTest.height)
        #expect(LissajousLabyrinthGolden.tickStep == LissajousLabyrinthTest.tickStep)
        var heroes: Int = 0
        for frame in frames where frame.name == "hero" {
            heroes += 1
            #expect(frame.level == 1 && frame.tier == 0 && !frame.actions.isEmpty)
        }
        #expect(heroes == 1)
        for frame in frames { #expect(frame.time == 0, "\(frame.name): time \(frame.time)") }
        for level in LissajousLabyrinthGolden.levels {
            #expect(Self.tierFrames(level: level).count == 3, "level \(level) has three tier frames")
        }
    }

    @Test(arguments: [1, 21, 41, 61, 81])
    func everyTierFrameOfTheLevelMatchesItsDescription(level: Int) async throws {
        let frames: [LissajousLabyrinthGolden.Frame] = Self.tierFrames(level: level)
        #expect(frames.count == 3, "level \(level): \(frames.count) tier frames")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ExperienceShell<LissajousLabyrinthPresenter> = try await Self.open(session, level: level)
        for frame in frames {
            Self.apply(frame.actions, to: shell, frame.name)
            try Self.check(frame, session: session, shell: shell)
        }
        session.qualityPin = 0
    }

    @Test func theHeroFrameMatchesItsDescription() async throws {
        var heroes: [LissajousLabyrinthGolden.Frame] = []
        for frame in LissajousLabyrinthGolden.frames where frame.name == "hero" { heroes.append(frame) }
        let hero: LissajousLabyrinthGolden.Frame = try #require(heroes.first, "no hero frame in the golden set")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: ExperienceShell<LissajousLabyrinthPresenter> = try await Self.open(session, level: hero.level)
        Self.apply(hero.actions, to: shell, hero.name)
        try Self.check(hero, session: session, shell: shell)
        session.qualityPin = 0
    }
}
#endif
