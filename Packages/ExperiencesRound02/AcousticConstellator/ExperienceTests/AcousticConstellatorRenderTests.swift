// AcousticConstellatorRenderTests — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-001 … 003, 006, 007;
// SC-R02G1303-001, 002; clarifications Q1, Q3, Q4, Q5). Through the one app's session host, drawn off screen at the
// frame-check size of `AcousticConstellatorTest` (1,152 × 768) at frame time 0: certified levels 24, 44, 60, 72 and 82
// (seeds 23, 43, 59, 71, 81), at the opening and arranged to their certified plans (every symbol pair linked, the stars
// nudged, so tick 0 holds teal links), at each quality tier level-0, level-1 and level-2, match the Core's CPU reference
// of the presenter's last snapshot: at every point at least 6 px from every other element, a star's centre is 0.15
// from the sky in luminance and white (channels within 0.1); a teal link's check point reaches a pixel 0.08 from the
// sky with green above red by 0.05; the first moves bar is 0.1 from the sky (and lit); the two probe corners are
// within 0.05 of the sky; the reference pixels are the same at every tier. The presenter's frame probes (two sky
// corners) match the drawn still at every tier. A link changes the digest and the frame, undo restores the digest and
// the frame and redo the linked one; refused actions change nothing. A failed listen outlines the missing pair's guide
// (level 24 listened to at its opening) or the snapped link (level 11 linked without its nudges) in the broken colour
// #FF6B4A and the description names it; a won level brightens its links. Each test well under 10 s.
#if os(iOS)
import Foundation
import AcousticConstellatorCore
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct AcousticConstellatorRenderTests {
    /// Every tier, arranged to the certified plan, matches the CPU reference at the same reference pixels.
    @Test(arguments: [UInt64(23), 43, 59, 71, 81])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: seed)
        let level: Int = AcousticConstellatorExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try AcousticConstellatorTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too (its teal links, if any, are not required).
        let opening: [UInt8] = try AcousticConstellatorTest.still(session)
        let openingSnapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.actionsLeft == openingSnapshot.budget)
        #expect(openingSnapshot.failure == nil)
        AcousticConstellatorTest.checkFrame(opening, snapshot: openingSnapshot, mode: .tier(0), require: false,
                                            "level \(level) opening")
        let before: String = try AcousticConstellatorTest.digest(shell)
        #expect(try AcousticConstellatorTest.arrange(shell), "level \(level): the certified arrangement was accepted")
        #expect(try AcousticConstellatorTest.digest(shell) != before, "level \(level): the play advanced")
        let expected: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.arranged(level)
        let spent: Int = try AcousticConstellatorTest.certifiedArrangement(level).count
        let litLuminance: Double = AcousticConstellatorTest.luminance(AcousticConstellatorPalette.movesLit)
        var references: [[SIMD2<Double>?]] = []
        for tier in 0..<3 {
            AcousticConstellatorTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
            let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownTick == 0)
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage.rawValue)")
            #expect(snapshot.actionsLeft == snapshot.budget - spent, "\(what): the arrangement was spent")
            #expect(snapshot.links == expected.play.links, "\(what): the drawn links are the kernel's")
            #expect(snapshot.phases == expected.play.phases, "\(what): the drawn phases are the kernel's")
            #expect(snapshot.report == expected.play.report, "\(what): the drawn report is the kernel's")
            #expect(snapshot.unlinkedSymbolPairs.isEmpty, "\(what): every symbol pair is linked")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(tier), what)
            references.append(AcousticConstellatorTest.referencePixels(snapshot))
            // The first moves bar is lit (emissive: the lit colour at its centre; no glow reaches the gauges).
            let p: SIMD2<Double> = try #require(AcousticConstellatorTest.movesPixel(snapshot))
            let c: SIMD3<Double> = AcousticConstellatorTest.centre(rgba, p, width: AcousticConstellatorTest.width,
                                                                   height: AcousticConstellatorTest.height)
            let lum: Double = AcousticConstellatorTest.luminance(c)
            #expect(Swift.abs(lum - litLuminance) <= 0.05, "\(what): moves bar 0 is \(c)")
        }
        // The tier changes no coordinate.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        session.qualityPin = 0
    }

    /// A link changes the digest and the frame; undo restores the digest and the frame, redo the linked one.
    @Test func aLinkChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 43)
        let before: String = try AcousticConstellatorTest.digest(shell)
        let first: [UInt8] = try AcousticConstellatorTest.still(session)
        let link: AcousticConstellatorAction = try #require(try AcousticConstellatorTest.certifiedLinksOnly(44).first)
        #expect(AcousticConstellatorTest.issue(shell, [link]) == 1)
        let linked: String = try AcousticConstellatorTest.digest(shell)
        #expect(linked != before, "a link changes the digest")
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.actionsLeft == snapshot.budget - 1, "the frame draws the linked state")
        // A moves bar goes out and a guide becomes a link: the frame changes.
        #expect(rgba != first, "a link changes the frame")
        AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), require: false,
                                            "level 44 linked once")
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try AcousticConstellatorTest.digest(shell) == before)
        let undone: [UInt8] = try AcousticConstellatorTest.still(session)
        let undoneSnapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(undoneSnapshot.actionsLeft == undoneSnapshot.budget)
        #expect(undone == first, "undo draws the opening frame again")
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try AcousticConstellatorTest.digest(shell) == linked)
    }

    /// Refused actions change neither the digest nor the frame's reference.
    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 23)
        let before: String = try AcousticConstellatorTest.digest(shell)
        let core: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.core(shell)
        let stars: Int = core.play.level.stars.count
        let fixed: AcousticConstellatorLink = try #require(core.play.level.fixedLinks.first, "level 24 has a fixed link")
        let fa: Double = Double(fixed.a)
        let fb: Double = Double(fixed.b)
        #expect(shell.handle(control: "link.add", values: [0.5, 1]) != .accepted, "a fractional star")
        #expect(shell.handle(control: "link.add", values: [0, 0]) != .accepted, "a self link")
        #expect(shell.handle(control: "link.add", values: [fa, fb]) != .accepted, "an existing link")
        if stars < 8 {
            #expect(shell.handle(control: "link.add", values: [0, Double(stars)]) != .accepted, "an unknown star")
        }
        #expect(shell.handle(control: "link.add", values: [0, 8]) != .accepted, "outside the declared range")
        #expect(shell.handle(control: "link.add", values: [0]) != .accepted, "one value")
        #expect(shell.handle(control: "link.remove", values: [fa, fb]) != .accepted, "a fixed link")
        #expect(shell.handle(control: "star.nudge", values: [0, 0]) != .accepted, "a step of 0")
        #expect(shell.handle(control: "star.nudge", values: [0, 2]) != .accepted, "a step outside −1 … 1")
        #expect(shell.handle(control: "play.undo") != .accepted, "nothing to undo")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(shell.handle(control: "string.tune", values: [0, 1]) != .accepted, "an undeclared control")
        #expect(try AcousticConstellatorTest.digest(shell) == before)
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.actionsLeft == snapshot.budget)
        AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(0), require: false,
                                            "level 24 after refusals")
    }

    /// The presenter's frame probes (two sky corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 59)
        try AcousticConstellatorTest.arrange(shell)
        for tier in 0..<3 {
            AcousticConstellatorTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try AcousticConstellatorTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = AcousticConstellatorTest.bottomUp(still, width: AcousticConstellatorTest.width,
                                                                  height: AcousticConstellatorTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try AcousticConstellatorTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two sky corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: AcousticConstellatorTest.width,
                                              height: AcousticConstellatorTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A failed listen at level 24's opening (a symbol pair unlinked) outlines the missing pair's guide in #FF6B4A; the
    /// description and the mirror name it; undo removes the outline.
    @Test func aMissingPairOutlinesItsGuide() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 23)
        // At level-2 nothing pulses or glows, so the outline lies where the CPU reference says.
        AcousticConstellatorTest.pin(session, shell, tier: 2)
        _ = try AcousticConstellatorTest.still(session)
        let clean: [UInt8] = try AcousticConstellatorTest.still(session)
        let opening: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.core(shell)
        let present: Set<AcousticConstellatorLink> = Set(opening.play.links)
        let missing: [AcousticConstellatorLink] = opening.play.level.symbol.filter { !present.contains($0) }
        let lowest: AcousticConstellatorLink = try #require(missing.min(), "level 24 opens with a symbol pair missing")
        #expect(shell.handle(control: "constellation.listen") == .accepted)
        let core: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage.rawValue)")
        let failure: AcousticConstellatorFailure = try #require(core.play.failure)
        #expect(failure == .missing(lowest), "\(failure)")
        #expect(core.outcome?.code == AcousticConstellatorExperienceCore.failedCode)
        // Since feature 425 the description and the mirror name the failure with its explanation (the failing listen,
        // the unlinked pair) and offer undo or retry.
        #expect(AcousticConstellatorSceneSnapshot.failureText(failure) != nil)
        let explanation: AcousticConstellatorFailureExplanation =
            try #require(AcousticConstellatorFailureExplanation(play: core.play))
        let named: String = explanation.text
        #expect(named == "Action 1 (the listen) found the symbol's pair star \(lowest.a) \u{2013} star \(lowest.b) "
            + "unlinked. " + AcousticConstellatorFailureExplanation.advice, "\(named)")
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.brokenGuide == lowest)
        AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(2), require: false, "missing pair")
        // The missing pair's guide outline: along the chord, clear of every star.
        let samples: [SIMD2<Double>] = AcousticConstellatorTest.chordSamples(lowest.a, lowest.b, snapshot)
        #expect(!samples.isEmpty, "guide \(lowest.a)–\(lowest.b) has points clear of the stars")
        let hits: Int = AcousticConstellatorTest.outlineHits(rgba, samples)
        #expect(hits > samples.count / 2, "the missing guide is outlined in #FF6B4A (\(hits) of \(samples.count))")
        #expect(AcousticConstellatorTest.outlineHits(clean, samples) == 0, "no outline before the listen")
        // A refused listen after the failure changes nothing; undo returns to playing without the outline.
        let digest: String = try AcousticConstellatorTest.digest(shell)
        #expect(shell.handle(control: "constellation.listen") != .accepted)
        #expect(try AcousticConstellatorTest.digest(shell) == digest)
        #expect(shell.handle(control: "play.undo") == .accepted)
        let undone: [UInt8] = try AcousticConstellatorTest.still(session)
        #expect(AcousticConstellatorTest.outlineHits(undone, samples) == 0, "undo removes the outline")
        #expect(undone == clean, "undo draws the frame before the listen")
        session.qualityPin = 0
    }

    /// Level 11 linked to its certified plan without the plan's nudges comes apart on a listen (a link snaps); the
    /// snapped link is outlined in #FF6B4A and the description names it.
    @Test func aSnappedLinkIsOutlined() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 10)
        AcousticConstellatorTest.pin(session, shell, tier: 2)
        let links: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedLinksOnly(11)
        #expect(!links.isEmpty)
        #expect(AcousticConstellatorTest.issue(shell, links) == links.count)
        _ = try AcousticConstellatorTest.still(session)
        let clean: [UInt8] = try AcousticConstellatorTest.still(session)
        #expect(shell.handle(control: "constellation.listen") == .accepted)
        let core: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage.rawValue)")
        let failure: AcousticConstellatorFailure = try #require(core.play.failure)
        guard case let .disconnected(_, link) = failure else {
            Issue.record("level 11 without its nudges fails \(failure), not disconnected")
            return
        }
        // Since feature 425 the description names the failure with its explanation (the failing listen, the tick and
        // the snapped link).
        #expect(AcousticConstellatorSceneSnapshot.failureText(failure) != nil)
        let explanation: AcousticConstellatorFailureExplanation =
            try #require(AcousticConstellatorFailureExplanation(play: core.play))
        let named: String = explanation.text
        #expect(named.contains("the link from star \(link.a) to star \(link.b) snapped"), "\(named)")
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.brokenLink == link)
        let index: Int = try #require(AcousticConstellatorSceneGeometry.brokenLinkIndex(snapshot))
        AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(2), require: false, "snapped link")
        let samples: [SIMD2<Double>] = AcousticConstellatorTest.linkSamples(index, snapshot)
        #expect(!samples.isEmpty, "link \(link.a)–\(link.b) has points clear of the stars")
        let hits: Int = AcousticConstellatorTest.outlineHits(rgba, samples)
        #expect(hits > samples.count / 2, "the snapped link is outlined in #FF6B4A (\(hits) of \(samples.count))")
        #expect(AcousticConstellatorTest.outlineHits(clean, samples) == 0, "no outline before the listen")
        session.qualityPin = 0
    }

    /// Playing the certified solution of level 60 through the shell wins; the won frame brightens the symbol links
    /// (teal lifted toward the glow colour) at every clear check point and passes the checks.
    @Test func aWonLevelBrightensItsLinks() async throws {
        let actions: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedActions(60)
        #expect(actions.last == .listen, "the solution ends with a listen")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 59)
        AcousticConstellatorTest.pin(session, shell, tier: 2)
        try AcousticConstellatorTest.arrange(shell)
        let before: [UInt8] = try AcousticConstellatorTest.still(session)
        let arrangedSnapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        AcousticConstellatorTest.checkFrame(before, snapshot: arrangedSnapshot, mode: .tier(2), "level 60 arranged")
        #expect(shell.handle(control: "constellation.listen") == .accepted)
        let core: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage.rawValue)")
        #expect(core.outcome?.code == AcousticConstellatorExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        let won: [UInt8] = try AcousticConstellatorTest.still(session)
        let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.stage == .won)
        #expect(snapshot.shownTick == 0)
        #expect(AcousticConstellatorSceneGeometry.wonFlag(snapshot) == 1)
        #expect(snapshot.links == arrangedSnapshot.links, "the same links are drawn")
        AcousticConstellatorTest.checkFrame(won, snapshot: snapshot, mode: .tier(2), "level 60 won")
        // The arranged frame's clear teal symbol links are brighter once won (teal → the won colour, +0.06).
        var compared: Int = 0
        for link in AcousticConstellatorTest.clearTealLinks(arrangedSnapshot, .tier(2))
            where AcousticConstellatorSceneGeometry.isSymbolLink(link.index, arrangedSnapshot) {
            let radius: Double = AcousticConstellatorTest.linkRadius(link.index, arrangedSnapshot)
            let was: Double = AcousticConstellatorTest.brightest(before, near: link.p, radius: radius)
            let now: Double = AcousticConstellatorTest.brightest(won, near: link.p, radius: radius)
            #expect(now >= was + 0.04, "link \(link.index): \(was) → \(now)")
            compared += 1
        }
        #expect(compared > 0, "a clear teal symbol link")
        session.qualityPin = 0
    }
}
#endif
