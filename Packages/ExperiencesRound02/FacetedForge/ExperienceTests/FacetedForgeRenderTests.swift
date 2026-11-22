// FacetedForgeRenderTests — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-001 … 003, 006; SC-R02G0803-001;
// clarifications Q1, Q3, Q5). Through the one app's session host, drawn off screen at the frame-check size of
// `FacetedForgeTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80), opening and after
// the first cut of the level's certified solution (`piece.cut [piece, direction, depth]`), at each quality tier
// level-0, level-1 and level-2 and at frame times 0 (closed) and 1 s (fully opened), match the Core's CPU reference of
// the presenter's last snapshot: every piece centre within 3 px of a pixel 0.1 away from the ground in luminance, once
// the pieces have opened (time 1 s; at time 0 a cut face lies inside the closed crystal) every camera-facing cut face
// centre within 3 px of a warm pixel (red − blue at least 0.15), the preview centre 0.05 away
// from the ground, the cut mark's first bar 0.1 away from the ground, the two probe corners within 0.05 of the ground.
// The presenter's frame probes (two ground corners) match the drawn still at every tier. A cut changes the digest and
// the frame, undo restores the digest and redo the cut one. Playing the certified solution of level 1 wins: the
// description says the pieces match the target and the opening is the won distance. One test per level, each well
// under 10 s.
#if os(iOS)
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct FacetedForgeRenderTests {
    /// Every tier, closed and opened, after the level's first certified cut, matches the CPU reference.
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: seed)
        let reduceMotion: Bool = shell.presenter.reduceMotion
        let level: Int = FacetedForgeExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try FacetedForgeTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too (one piece, no cut face yet).
        let opening: [UInt8] = try FacetedForgeTest.still(session)
        let openingSnapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.cuts == 0)
        #expect(openingSnapshot.pieces.count == 1)
        #expect(openingSnapshot.stage == .playing)
        FacetedForgeTest.checkFrame(opening, snapshot: openingSnapshot, reduceMotion: reduceMotion,
                                    "level \(level) opening")
        let before: String = try FacetedForgeTest.digest(shell)
        #expect(try FacetedForgeTest.advance(shell) == 1, "level \(level): the first certified cut was accepted")
        #expect(try FacetedForgeTest.digest(shell) != before, "level \(level): the play advanced")
        let times: [Double] = [0, 1]
        for tier in 0..<3 {
            FacetedForgeTest.pin(session, shell, tier: tier)
            for time in times {
                let rgba: [UInt8] = try FacetedForgeTest.still(session, time: time)
                let snapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                let what: String = "level \(level) tier \(tier) time \(time)"
                #expect(snapshot.time == time, "\(what): the still's frame time")
                #expect(snapshot.levelNumber == level)
                #expect(snapshot.cuts == 1, "\(what): one cut spent")
                #expect(snapshot.pieces.count >= 2, "\(what): the cut made two pieces")
                #expect(!FacetedForgeSceneGeometry.cutFaceCentres(snapshot).isEmpty, "\(what): cut faces")
                #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
                #expect(shell.presenter.tierLog.last?.tier == tier)
                // The cut faces are checked once the pieces have opened (the opening eases over 0.4 s): at time 0 the
                // crystal is still closed, so a cut face lies inside it, behind the other piece's ice glass.
                let opened: Bool = FacetedForgeSceneGeometry.opening(snapshot, reduceMotion: reduceMotion) > 0.1
                FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: reduceMotion, cutFaces: opened,
                                            expectCutFace: opened, what)
                let faces = FacetedForgeTest.cutFaceMisses(rgba, snapshot: snapshot, reduceMotion: reduceMotion)
                print("faceted-forge \(what): pieces \(snapshot.pieces.count), cut faces checked \(faces.checked), "
                      + "turned away \(faces.away), under the mark \(faces.underMark), preview "
                      + "\(snapshot.preview.isEmpty ? "none" : "\(snapshot.preview.count) corners"), "
                      + "stage \(snapshot.stage.rawValue)")
            }
        }
        session.qualityPin = 0
    }

    /// A cut changes the digest and the frame; undo restores the digest, redo the cut one.
    @Test func aCutChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 20)
        let reduceMotion: Bool = shell.presenter.reduceMotion
        let before: String = try FacetedForgeTest.digest(shell)
        let first: [UInt8] = try FacetedForgeTest.still(session)
        let action: FacetedForgeAction = try #require(FacetedForgeTest.firstCut(21))
        let issued = FacetedForgeTest.control(action)
        let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
        #expect(result == .accepted, "\(result.code)")
        let cut: String = try FacetedForgeTest.digest(shell)
        #expect(cut != before, "a cut changes the digest")
        let rgba: [UInt8] = try FacetedForgeTest.still(session)
        let snapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.cuts == 1, "the frame draws the cut state")
        // The cut face and the spent mark bar appear: the frame changes.
        #expect(rgba != first, "a cut changes the frame")
        FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: reduceMotion, expectCutFace: true,
                                    "level 21 after a cut")
        // Undo restores the earlier digest exactly and draws one piece again.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try FacetedForgeTest.digest(shell) == before)
        let undone: [UInt8] = try FacetedForgeTest.still(session)
        let undoneSnapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(undoneSnapshot.cuts == 0 && undoneSnapshot.pieces.count == 1)
        FacetedForgeTest.checkFrame(undone, snapshot: undoneSnapshot, reduceMotion: reduceMotion, "level 21 undone")
        // Redo returns to the cut digest.
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try FacetedForgeTest.digest(shell) == cut)
    }

    /// Refused actions change neither the digest nor the frame's reference.
    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        let before: String = try FacetedForgeTest.digest(shell)
        #expect(shell.handle(control: "piece.cut", values: [5, 0, 0]) != .accepted, "a piece the play lacks")
        #expect(shell.handle(control: "piece.cut", values: [0, 0.5, 0]) != .accepted, "a fractional direction")
        #expect(shell.handle(control: "piece.cut", values: [0, 13, 0]) != .accepted, "a direction out of range")
        #expect(shell.handle(control: "piece.cut", values: [0, 0, 24]) != .accepted, "a plane that misses")
        #expect(shell.handle(control: "play.undo") != .accepted, "nothing to undo")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(try FacetedForgeTest.digest(shell) == before)
        let rgba: [UInt8] = try FacetedForgeTest.still(session)
        let snapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.cuts == 0)
        FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: shell.presenter.reduceMotion,
                                    "level 1 after refusals")
    }

    /// The presenter's frame probes (two ground corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        try FacetedForgeTest.advance(shell)
        for tier in 0..<3 {
            FacetedForgeTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try FacetedForgeTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = FacetedForgeTest.bottomUp(still, width: FacetedForgeTest.width,
                                                          height: FacetedForgeTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try FacetedForgeTest.core(shell))
            var names: [String] = []
            for probe in probes { names.append(probe.name) }
            #expect(names == ["ground-top-left", "ground-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: FacetedForgeTest.width,
                                              height: FacetedForgeTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }

    /// Playing the certified solution of level 1 through the shell wins: the description says the pieces match the
    /// target, the opening is the won distance and the frame passes the checks.
    @Test func theCertifiedSolutionWinsAndOpensWide() async throws {
        let actions: [FacetedForgeAction] = FacetedForgeExperienceCore.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        let before: String = try FacetedForgeTest.digest(shell)
        for (index, action) in actions.enumerated() {
            let issued = FacetedForgeTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "action \(index) \(issued.control) \(issued.values): \(result.code)")
        }
        #expect(try FacetedForgeTest.digest(shell) != before)
        let core: FacetedForgeExperienceCore = try FacetedForgeTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage.rawValue)")
        #expect(core.outcome?.code == FacetedForgeExperienceCore.wonCode)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The pieces match the target."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        let rgba: [UInt8] = try FacetedForgeTest.still(session, time: 1)
        let snapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.won)
        #expect(snapshot.cuts == actions.count)
        #expect(FacetedForgeSceneGeometry.opening(snapshot) == FacetedForgeSceneGeometry.wonOpeningDistance)
        FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: shell.presenter.reduceMotion,
                                    expectCutFace: true, "level 1 won")
        print("faceted-forge level 1 won in \(actions.count) cuts with \(snapshot.pieces.count) pieces")
    }
}
#endif
