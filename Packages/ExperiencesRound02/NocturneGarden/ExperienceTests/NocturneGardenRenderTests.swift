// NocturneGardenRenderTests — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-001 … 003, 006, 007;
// SC-R02G0903-001; clarifications Q1, Q3, Q4). Through the one app's session host, drawn off screen at the frame-check
// size of `NocturneGardenTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80), opening
// and after the witness's first plant (the certified solution's actions up to and including its first `bloom.plant`), at
// each quality tier level-0, level-1 and level-2 and at frame times 0 and 1.5 s, match the Core's CPU reference of the
// presenter's last snapshot at every bed cell centre outside the blooms' boxes: shadow cells 0.15 darker than the mist,
// forbidden cells outside the shadow warm (red − blue at least 0.15), target cells outside the shadow 0.15 brighter than
// the shadow; the gauge's first visible bar 0.1 away from the ground; the two probe corners within 0.05 of the ground.
// The presenter's frame probes (two ground corners) match the drawn still at every tier. A plant changes the digest and
// the frame, undo restores the digest and redo the planted one; refused actions change nothing. Playing the certified
// solution of level 1 wins and says so. A leak failure, found by a deterministic search over the certified levels,
// crosses its leaking cells in the leak colour (red − blue at least 0.15 at a leaking cell outside the blooms' boxes).
// Each test well under 10 s.
#if os(iOS)
import Foundation
import NocturneGardenCore
import Testing
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct NocturneGardenRenderTests {
    /// Every tier, at two frame times, after the witness's first plant, matches the CPU reference.
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: seed)
        let level: Int = NocturneGardenExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try NocturneGardenTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too (no bloom, no shadow; the gauge's bars all unspent).
        let opening: [UInt8] = try NocturneGardenTest.still(session)
        let openingSnapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.moves == 0)
        #expect(openingSnapshot.blooms.isEmpty)
        #expect(openingSnapshot.shadow.isEmpty)
        NocturneGardenTest.checkFrame(opening, snapshot: openingSnapshot, "level \(level) opening")
        let before: String = try NocturneGardenTest.digest(shell)
        let prefix: [NocturneGardenAction] = try NocturneGardenTest.firstPlant(level)
        #expect(try NocturneGardenTest.advance(shell) == prefix.count, "level \(level): the first plant was accepted")
        #expect(try NocturneGardenTest.digest(shell) != before, "level \(level): the play advanced")
        let times: [Double] = [0, 1.5]
        for tier in 0..<3 {
            NocturneGardenTest.pin(session, shell, tier: tier)
            for time in times {
                let rgba: [UInt8] = try NocturneGardenTest.still(session, time: time)
                let snapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                let what: String = "level \(level) tier \(tier) time \(time)"
                #expect(snapshot.time == time, "\(what): the still's frame time")
                #expect(snapshot.levelNumber == level)
                #expect(snapshot.moves == prefix.count, "\(what): moves spent")
                #expect(snapshot.blooms.count == 1, "\(what): one bloom planted")
                #expect(!snapshot.shadow.isEmpty, "\(what): the bloom casts a shadow")
                #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
                #expect(shell.presenter.tierLog.last?.tier == tier)
                NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, what)
            }
        }
        session.qualityPin = 0
    }

    /// A plant changes the digest and the frame; undo restores the digest, redo the planted one.
    @Test func aPlantChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 20)
        let before: String = try NocturneGardenTest.digest(shell)
        let first: [UInt8] = try NocturneGardenTest.still(session)
        let prefix: [NocturneGardenAction] = try NocturneGardenTest.firstPlant(21)
        #expect(try NocturneGardenTest.advance(shell) == prefix.count)
        let planted: String = try NocturneGardenTest.digest(shell)
        #expect(planted != before, "a plant changes the digest")
        let rgba: [UInt8] = try NocturneGardenTest.still(session)
        let snapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.blooms.count == 1, "the frame draws the planted state")
        // The bloom, its shadow and the spent gauge bar appear: the frame changes.
        #expect(rgba != first, "a plant changes the frame")
        NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, "level 21 after the first plant")
        // Undo the plant (the last action of the prefix): the digest before it returns and no bloom is drawn.
        #expect(shell.handle(control: "play.undo") == .accepted)
        let undoneSnapshot: NocturneGardenSceneSnapshot = try NocturneGardenTest.core(shell).snapshot(time: 0)
        #expect(undoneSnapshot.blooms.isEmpty)
        if prefix.count == 1 {
            #expect(try NocturneGardenTest.digest(shell) == before)
        }
        let undone: [UInt8] = try NocturneGardenTest.still(session)
        NocturneGardenTest.checkFrame(undone, snapshot: try #require(shell.presenter.lastSnapshot), "level 21 undone")
        // Redo returns to the planted digest.
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try NocturneGardenTest.digest(shell) == planted)
    }

    /// Refused actions change neither the digest nor the frame's reference.
    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        let before: String = try NocturneGardenTest.digest(shell)
        #expect(shell.handle(control: "bloom.plant", values: [6, 0, 0, 1]) != .accepted, "a kind out of range")
        #expect(shell.handle(control: "bloom.plant", values: [0, 0.5, 0, 1]) != .accepted, "a fractional column")
        #expect(shell.handle(control: "sun.set", values: [5]) != .accepted, "an elevation out of range")
        #expect(shell.handle(control: "bloom.remove", values: [0]) != .accepted, "no bloom to remove")
        #expect(shell.handle(control: "play.undo") != .accepted, "nothing to undo")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(try NocturneGardenTest.digest(shell) == before)
        let rgba: [UInt8] = try NocturneGardenTest.still(session)
        let snapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.moves == 0)
        NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, "level 1 after refusals")
    }

    /// The presenter's frame probes (two ground corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        try NocturneGardenTest.advance(shell)
        for tier in 0..<3 {
            NocturneGardenTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try NocturneGardenTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = NocturneGardenTest.bottomUp(still, width: NocturneGardenTest.width,
                                                            height: NocturneGardenTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try NocturneGardenTest.core(shell))
            var names: [String] = []
            for probe in probes { names.append(probe.name) }
            #expect(names == ["ground-top-left", "ground-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: NocturneGardenTest.width,
                                              height: NocturneGardenTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }

    /// Playing the certified solution of level 1 through the shell wins: the description says the shadow matches the
    /// target and the frame passes the checks.
    @Test func theCertifiedSolutionWins() async throws {
        let actions: [NocturneGardenAction] = try NocturneGardenTest.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        let before: String = try NocturneGardenTest.digest(shell)
        for (index, action) in actions.enumerated() {
            let issued = NocturneGardenTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "action \(index) \(issued.control) \(issued.values): \(result.code)")
        }
        #expect(try NocturneGardenTest.digest(shell) != before)
        let core: NocturneGardenExperienceCore = try NocturneGardenTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage.rawValue)")
        #expect(core.outcome?.code == NocturneGardenExperienceCore.wonCode)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The shadow matches the target."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        let rgba: [UInt8] = try NocturneGardenTest.still(session)
        let snapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.stage == .won)
        #expect(snapshot.moves == actions.count)
        NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, "level 1 won")
    }

    /// A leak failure (found by `NocturneGardenTest.leakFailure`) crosses its leaking cells in the leak colour and the
    /// description names the leak.
    @Test func aLeakFailureCrossesItsCells() async throws {
        let found = try #require(try NocturneGardenTest.leakFailure(), "a plant of some level leaks visibly")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: UInt64(found.level - 1))
        for action in found.actions {
            let issued = NocturneGardenTest.control(action)
            #expect(shell.handle(control: issued.control, values: issued.values) == .accepted,
                    "\(issued.control) \(issued.values)")
        }
        let core: NocturneGardenExperienceCore = try NocturneGardenTest.core(shell)
        #expect(core.play.stage == .failed)
        #expect(core.play.failure == .leak(found.actions.count - 1))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("leaked into"), "\(text)")
        #expect(shell.presenter.mirror.status.hasPrefix("Failed: "), "\(shell.presenter.mirror.status)")
        // Level-2 draws no glow shells, so nothing additive lies over the crosses.
        NocturneGardenTest.pin(session, shell, tier: 2)
        // Feature 386: the crosses fade in over 0.15 s of presentation time, so the frame is drawn 1 s later.
        let rgba: [UInt8] = try NocturneGardenTest.still(session, time: 1)
        #expect(shell.presenter.lights.leak == 1, "the crosses have faded in")
        let snapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.leakFailure)
        #expect(!snapshot.leaking.isEmpty)
        let leak = NocturneGardenTest.leakMisses(rgba, snapshot: snapshot)
        #expect(leak.checked > 0, "level \(found.level): a leaking cell outside the blooms' boxes")
        #expect(leak.misses.isEmpty, "\(leak.misses.prefix(8))")
        NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, "leak failure level \(found.level)")
        session.qualityPin = 0
        print("nocturne-garden leak failure: level \(found.level), \(found.actions.count) plants, "
              + "\(snapshot.leaking.count) leaking cells, \(leak.checked) checked")
    }
}
#endif
