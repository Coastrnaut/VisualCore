// HarmonicBridgesRenderTests — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-001 … 003, 006, 007;
// SC-R02G1203-001; clarifications Q1, Q3, Q5). Through the one app's session host, drawn off screen at the frame-check
// size of `HarmonicBridgesTest` (1,152 × 768) at frame time 0: certified levels 2, 11, 31, 41 and 61 (seeds 1, 10, 30,
// 40, 60), at the opening and tuned to their certified pegs (so step 0 holds bridges), at each quality tier level-0,
// level-1 and level-2, match the Core's CPU reference of the presenter's last snapshot: at every point at least 6 px
// from every other element, an island's top centre is 0.1 from the ground in luminance with red above blue by 0.05; a
// drawn membrane's check point is 0.08 from the ground with blue above red by 0.05; the gauge's first bar is 0.1 from
// the ground (and lit); the two probe corners are within 0.05 of the ground. The presenter's frame probes (two ground
// corners) match the drawn still at every tier. A tuning changes the digest and the frame, undo restores the digest
// and redo the tuned one; refused actions change nothing. A failed test outlines the broken string and the broken
// step's pip in the broken colour #FF6B4A and the description names them; a won level brightens its bridges. Each test
// well under 10 s.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct HarmonicBridgesRenderTests {
    /// Every tier, tuned to the certified pegs, matches the CPU reference.
    @Test(arguments: [UInt64(1), 10, 30, 40, 60])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: seed)
        let level: Int = HarmonicBridgesExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try HarmonicBridgesTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too (its bridges, if any, are not required).
        let opening: [UInt8] = try HarmonicBridgesTest.still(session)
        let openingSnapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.actionsLeft == openingSnapshot.budget)
        #expect(openingSnapshot.failure == nil)
        HarmonicBridgesTest.checkFrame(opening, snapshot: openingSnapshot, mode: .tier(0), require: false,
                                       "level \(level) opening")
        let before: String = try HarmonicBridgesTest.digest(shell)
        #expect(try HarmonicBridgesTest.tune(shell), "level \(level): the certified tunings were accepted")
        #expect(try HarmonicBridgesTest.digest(shell) != before, "level \(level): the play advanced")
        let expected: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.tuned(level)
        let tunings: Int = try HarmonicBridgesTest.certifiedTunings(level).count
        let litLuminance: Double = HarmonicBridgesTest.luminance(HarmonicBridgesPalette.gaugeLit)
        for tier in 0..<3 {
            HarmonicBridgesTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
            let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownStep == 0)
            #expect(snapshot.actionsLeft == snapshot.budget - tunings, "\(what): the tunings were spent")
            #expect(snapshot.pegs == expected.play.pegs, "\(what): the drawn pegs are the kernel's")
            #expect(snapshot.report == expected.play.report, "\(what): the drawn report is the kernel's")
            #expect(snapshot.report.bridges[0].contains(true), "\(what): step 0 has a bridge")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(tier), what)
            // The gauge's first bar is lit (emissive: the lit colour at its centre, no glow reaches the gauge).
            let p: SIMD2<Double> = try #require(HarmonicBridgesTest.gaugePixel(snapshot))
            let c: SIMD3<Double> = HarmonicBridgesTest.centre(rgba, p, width: HarmonicBridgesTest.width,
                                                              height: HarmonicBridgesTest.height)
            let lum: Double = HarmonicBridgesTest.luminance(c)
            #expect(Swift.abs(lum - litLuminance) <= 0.05, "\(what): gauge bar 0 is \(c)")
        }
        session.qualityPin = 0
    }

    /// A tuning changes the digest and the frame; undo restores the digest, redo the tuned one.
    @Test func aTuningChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 10)
        let before: String = try HarmonicBridgesTest.digest(shell)
        let first: [UInt8] = try HarmonicBridgesTest.still(session)
        let tuning: HarmonicBridgesAction = try #require(try HarmonicBridgesTest.certifiedTunings(11).first)
        #expect(HarmonicBridgesTest.issue(shell, [tuning]) == 1)
        let tuned: String = try HarmonicBridgesTest.digest(shell)
        #expect(tuned != before, "a tuning changes the digest")
        let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.actionsLeft == snapshot.budget - 1, "the frame draws the tuned state")
        // A gauge bar goes out (and the swings change): the frame changes.
        #expect(rgba != first, "a tuning changes the frame")
        HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), require: false, "level 11 tuned once")
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try HarmonicBridgesTest.digest(shell) == before)
        let undone: [UInt8] = try HarmonicBridgesTest.still(session)
        let undoneSnapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(undoneSnapshot.actionsLeft == undoneSnapshot.budget)
        #expect(undone == first, "undo draws the opening frame again")
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try HarmonicBridgesTest.digest(shell) == tuned)
    }

    /// Refused actions change neither the digest nor the frame's reference.
    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 1)
        let before: String = try HarmonicBridgesTest.digest(shell)
        let core: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.core(shell)
        let strings: Int = core.play.level.strings.count
        let peg0: Int = core.play.pegs[0]
        #expect(shell.handle(control: "string.tune", values: [0.5, 3]) != .accepted, "a fractional string")
        #expect(shell.handle(control: "string.tune", values: [0, Double(peg0)]) != .accepted, "the current peg")
        #expect(shell.handle(control: "string.tune", values: [Double(strings), 3]) != .accepted, "an unknown string")
        #expect(shell.handle(control: "string.tune", values: [0, 13]) != .accepted, "outside the declared range")
        #expect(shell.handle(control: "string.tune", values: [0]) != .accepted, "one value")
        #expect(shell.handle(control: "play.undo") != .accepted, "nothing to undo")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(shell.handle(control: "cell.pulse", values: [0, 1]) != .accepted, "an undeclared control")
        #expect(try HarmonicBridgesTest.digest(shell) == before)
        let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.actionsLeft == snapshot.budget)
        HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), require: false,
                                       "level 2 after refusals")
    }

    /// The presenter's frame probes (two ground corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 1)
        try HarmonicBridgesTest.tune(shell)
        for tier in 0..<3 {
            HarmonicBridgesTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try HarmonicBridgesTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = HarmonicBridgesTest.bottomUp(still, width: HarmonicBridgesTest.width,
                                                             height: HarmonicBridgesTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try HarmonicBridgesTest.core(shell))
            var names: [String] = []
            for probe in probes { names.append(probe.name) }
            #expect(names == ["ground-top-left", "ground-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: HarmonicBridgesTest.width,
                                              height: HarmonicBridgesTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A failed test (level 41 tested at its opening pegs breaks in step 0 at string 1) outlines the broken string and
    /// the broken step's pip in #FF6B4A; the description and the mirror name them; undo removes the outline.
    @Test func aFailureOutlinesTheBrokenStepAndString() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 40)
        // At level-2 the strings are at rest, so the outline lies where the CPU reference says.
        HarmonicBridgesTest.pin(session, shell, tier: 2)
        _ = try HarmonicBridgesTest.still(session)
        let clean: [UInt8] = try HarmonicBridgesTest.still(session)
        #expect(shell.handle(control: "crossing.test") == .accepted)
        let core: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage.rawValue)")
        let failure: HarmonicBridgesFailure = try #require(core.play.failure)
        guard case let .broken(step, brokenString) = failure else {
            Issue.record("level 41's opening test fails \(failure), not broken")
            return
        }
        let string: Int = try #require(brokenString, "the crossing breaks at a string")
        #expect(step == 0 && string == 1, "broken at step \(step), string \(string)")
        #expect(core.outcome?.code == HarmonicBridgesExperienceCore.failedCode)
        // Since feature 415 the description and the mirror name the failure with its explanation (the failing test,
        // the broken step and string, the steps reached) and offer undo or retry.
        #expect(HarmonicBridgesSceneSnapshot.failureText(failure) != nil)
        let explanation: HarmonicBridgesFailureExplanation =
            try #require(HarmonicBridgesFailureExplanation(play: core.play))
        let named: String = explanation.text
        #expect(named.hasPrefix("Action 1 (the test) broke the crossing in step 0 at string 1"), "\(named)")
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.brokenString == string)
        #expect(snapshot.shownStep == step, "the broken step is held")
        HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(2), require: false, "broken test")
        // The broken string's outline: beside the string at rest, clear of every island.
        let samples: [SIMD2<Double>] = HarmonicBridgesTest.stringSamples(string, snapshot)
        #expect(!samples.isEmpty, "string \(string) has points clear of the islands")
        let hits: Int = HarmonicBridgesTest.outlineHits(rgba, samples)
        #expect(hits > 0, "the broken string is outlined in #FF6B4A (\(samples.count) samples)")
        #expect(HarmonicBridgesTest.outlineHits(clean, samples) == 0, "no outline before the test")
        // The broken step's pip: framed and crossed; the crossing at its centre is the broken colour.
        let pipCentre: SIMD3<Double> = HarmonicBridgesSceneGeometry.stepPip(step, snapshot)
        let pip: SIMD2<Double> = try #require(HarmonicBridgesTest.pixel(pipCentre, snapshot))
        #expect(HarmonicBridgesTest.outlineHits(rgba, [pip], radius: HarmonicBridgesTest.pointRadius) == 1,
                "the broken step's pip is crossed in #FF6B4A")
        #expect(HarmonicBridgesTest.outlineHits(clean, [pip], radius: HarmonicBridgesTest.pointRadius) == 0,
                "no cross before the test")
        // A refused tuning after the failure changes nothing; undo returns to playing without the outline.
        let digest: String = try HarmonicBridgesTest.digest(shell)
        #expect(shell.handle(control: "crossing.test") != .accepted)
        #expect(try HarmonicBridgesTest.digest(shell) == digest)
        #expect(shell.handle(control: "play.undo") == .accepted)
        let undone: [UInt8] = try HarmonicBridgesTest.still(session)
        #expect(HarmonicBridgesTest.outlineHits(undone, samples) == 0, "undo removes the outline")
        #expect(undone == clean, "undo draws the frame before the test")
        session.qualityPin = 0
    }

    /// Playing the certified solution of level 11 through the shell wins; the won frame brightens the bridges'
    /// membranes (the won lift) at every clear check point and passes the checks.
    @Test func aWonLevelBrightensItsBridges() async throws {
        let actions: [HarmonicBridgesAction] = try HarmonicBridgesTest.certifiedActions(11)
        #expect(actions.last == .test, "the solution ends with a test")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 10)
        HarmonicBridgesTest.pin(session, shell, tier: 2)
        try HarmonicBridgesTest.tune(shell)
        let before: [UInt8] = try HarmonicBridgesTest.still(session)
        let tunedSnapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        HarmonicBridgesTest.checkFrame(before, snapshot: tunedSnapshot, mode: .tier(2), "level 11 tuned")
        #expect(shell.handle(control: "crossing.test") == .accepted)
        let core: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage.rawValue)")
        #expect(core.outcome?.code == HarmonicBridgesExperienceCore.wonCode)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The crossing holds in every step."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        let won: [UInt8] = try HarmonicBridgesTest.still(session)
        let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.stage == .won)
        #expect(snapshot.shownStep == 0)
        #expect(HarmonicBridgesSceneGeometry.wonFlag(snapshot) == 1)
        #expect(snapshot.report == tunedSnapshot.report, "the same bridges are drawn")
        HarmonicBridgesTest.checkFrame(won, snapshot: snapshot, mode: .tier(2), "level 11 won")
        let membranes = HarmonicBridgesTest.clearMembranes(snapshot, .tier(2))
        #expect(!membranes.isEmpty, "a clear membrane check point")
        for membrane in membranes {
            let was: Double = HarmonicBridgesTest.brightest(before, near: membrane.p,
                                                            radius: HarmonicBridgesTest.pointRadius)
            let now: Double = HarmonicBridgesTest.brightest(won, near: membrane.p,
                                                            radius: HarmonicBridgesTest.pointRadius)
            #expect(now >= was + 0.04, "membrane \(membrane.index): \(was) → \(now)")
        }
        session.qualityPin = 0
    }
}
#endif
