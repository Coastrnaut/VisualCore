// BackwardsAuroraRenderTests — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-001 … 003, 006, 007;
// SC-R02G1003-001; clarifications Q1, Q3, Q5). Through the one app's session host, drawn off screen at the frame-check
// size of `BackwardsAuroraTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80), opening
// and after the first action of the level's certified solution, at each quality tier level-0, level-1 and level-2,
// match the Core's CPU reference of the presenter's last snapshot: at every sample point clear of the rings, ticks,
// kinks and tear the ribbon is cyan (blue − red at least 0.15) and 0.15 from the ground in luminance; at every target
// point with |s − t| ≥ 8 under the same exclusions the ghost is lilac (red − green at least 0.05) and 0.1 from the ground;
// the gauge's first bar is 0.1 from the ground; the two probe corners are within 0.05 of the ground. The presenter's
// frame probes (two ground corners) match the drawn still at every tier. A reversal changes the digest and the frame,
// undo restores the digest and redo the reversed one; refused actions change nothing. Playing the certified solution of
// level 1 wins and says so. Each test well under 10 s.
#if os(iOS)
import Foundation
import BackwardsAuroraCore
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct BackwardsAuroraRenderTests {
    /// Every tier, after the first action of the certified solution, matches the CPU reference.
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: seed)
        let level: Int = BackwardsAuroraExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try BackwardsAuroraTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too (nothing spent; every gauge bar unspent).
        let opening: [UInt8] = try BackwardsAuroraTest.still(session)
        let openingSnapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.spent == 0)
        #expect(openingSnapshot.tear == nil)
        BackwardsAuroraTest.checkFrame(opening, snapshot: openingSnapshot, "level \(level) opening")
        let before: String = try BackwardsAuroraTest.digest(shell)
        #expect(try BackwardsAuroraTest.advance(shell), "level \(level): the first reversal was accepted")
        #expect(try BackwardsAuroraTest.digest(shell) != before, "level \(level): the play advanced")
        let expected: [Int] = try BackwardsAuroraTest.advanced(level).play.wave.samples
        for tier in 0..<3 {
            BackwardsAuroraTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
            let snapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.spent == 1, "\(what): one reversal spent")
            #expect(snapshot.samples == expected, "\(what): the drawn samples are the kernel's")
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, what)
        }
        session.qualityPin = 0
    }

    /// A reversal changes the digest and the frame; undo restores the digest, redo the reversed one.
    @Test func aReversalChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 20)
        let before: String = try BackwardsAuroraTest.digest(shell)
        let first: [UInt8] = try BackwardsAuroraTest.still(session)
        #expect(try BackwardsAuroraTest.advance(shell))
        let reversed: String = try BackwardsAuroraTest.digest(shell)
        #expect(reversed != before, "a reversal changes the digest")
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
        let snapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.spent == 1, "the frame draws the reversed state")
        // The ribbon moves and a gauge bar is spent: the frame changes.
        #expect(rgba != first, "a reversal changes the frame")
        BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, "level 21 after the first reversal")
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try BackwardsAuroraTest.digest(shell) == before)
        let undone: [UInt8] = try BackwardsAuroraTest.still(session)
        let undoneSnapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(undoneSnapshot.spent == 0)
        BackwardsAuroraTest.checkFrame(undone, snapshot: undoneSnapshot, "level 21 undone")
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try BackwardsAuroraTest.digest(shell) == reversed)
    }

    /// Refused actions change neither the digest nor the frame's reference.
    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0)
        let before: String = try BackwardsAuroraTest.digest(shell)
        let n: Int = try BackwardsAuroraTest.core(shell).play.wave.count
        #expect(shell.handle(control: "wave.reverse", values: [0.5, 2]) != .accepted, "a fractional start")
        #expect(shell.handle(control: "wave.reverse", values: [3, 3]) != .accepted, "a start not before the end")
        #expect(shell.handle(control: "wave.reverse", values: [0, Double(n)]) != .accepted, "an end outside the wave")
        #expect(shell.handle(control: "wave.reverse", values: [40, 41]) != .accepted, "outside the declared range")
        #expect(shell.handle(control: "play.undo") != .accepted, "nothing to undo")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(try BackwardsAuroraTest.digest(shell) == before)
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
        let snapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.spent == 0)
        BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, "level 1 after refusals")
    }

    /// The presenter's frame probes (two ground corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0)
        try BackwardsAuroraTest.advance(shell)
        for tier in 0..<3 {
            BackwardsAuroraTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try BackwardsAuroraTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = BackwardsAuroraTest.bottomUp(still, width: BackwardsAuroraTest.width,
                                                             height: BackwardsAuroraTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try BackwardsAuroraTest.core(shell))
            var names: [String] = []
            for probe in probes { names.append(probe.name) }
            #expect(names == ["ground-top-left", "ground-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: BackwardsAuroraTest.width,
                                              height: BackwardsAuroraTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }

    /// Playing the certified solution of level 1 through the shell wins: the description says so and the frame passes
    /// the checks.
    @Test func theCertifiedSolutionWins() async throws {
        let actions: [BackwardsAuroraAction] = try BackwardsAuroraTest.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0)
        let before: String = try BackwardsAuroraTest.digest(shell)
        var beforeWin: [UInt8] = []
        var beforeSnapshot: BackwardsAuroraSceneSnapshot?
        for (index, action) in actions.enumerated() {
            if index == actions.count - 1 {
                beforeWin = try BackwardsAuroraTest.still(session)
                beforeSnapshot = shell.presenter.lastSnapshot
            }
            let issued = BackwardsAuroraTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "action \(index) \(issued.control) \(issued.values): \(result.code)")
        }
        #expect(try BackwardsAuroraTest.digest(shell) != before)
        let core: BackwardsAuroraExperienceCore = try BackwardsAuroraTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage.rawValue)")
        #expect(core.outcome?.code == BackwardsAuroraExperienceCore.wonCode)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("Every checkpoint matches"), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
        let snapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.stage == .won)
        #expect(snapshot.spent == actions.count)
        #expect(snapshot.kinks.isEmpty, "a won wave is smooth")
        BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, "level 1 won")
        // T-R02G1003-014: the won ribbon is brighter than before the winning reversal, at a sample the reversal left in
        // place, away from every checkpoint, kink and the reversal's seams. The ribbon's centre is already close to the
        // highlight at tier 0 (luminance about 0.9), so the lift measured +0.026 … 0.028 on the iOS 27.2 simulator
        // (2026-11-22); the check asks for half of it.
        let earlier: BackwardsAuroraSceneSnapshot = try #require(beforeSnapshot)
        guard case let .reverse(start, end) = try #require(actions.last) else { return }
        var compared: Int = 0
        for k in 0..<snapshot.count where k < start - 2 || k > end + 2 {
            var clear: Bool = true
            for near in (k - 2)...(k + 2) where earlier.checkpoints.contains(near) || earlier.kinks.contains(near) {
                clear = false
            }
            guard clear, let p = BackwardsAuroraTest.pixel(BackwardsAuroraSceneGeometry.samplePoint(k, snapshot), snapshot),
                  let q = BackwardsAuroraTest.pixel(BackwardsAuroraSceneGeometry.samplePoint(k, earlier), earlier) else { continue }
            let x: Int = Int(p.x.rounded())
            let y: Int = Int(p.y.rounded())
            let after: Double = BackwardsAuroraTest.luminance(BackwardsAuroraTest.colour(rgba, x: x, y: y,
                                                                                        width: BackwardsAuroraTest.width))
            let prior: Double = BackwardsAuroraTest.luminance(BackwardsAuroraTest.colour(
                beforeWin, x: Int(q.x.rounded()), y: Int(q.y.rounded()), width: BackwardsAuroraTest.width))
            #expect(after > prior + 0.015, "sample \(k): won \(after), before \(prior)")
            compared += 1
        }
        #expect(compared > 0, "a sample away from the markers was compared")
    }
}
#endif
