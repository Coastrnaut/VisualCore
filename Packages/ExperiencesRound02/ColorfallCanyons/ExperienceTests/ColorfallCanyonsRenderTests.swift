// ColorfallCanyonsRenderTests — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-001 … 003, 006; SC-R02G0503-001;
// clarifications Q1, Q3). Through the one app's session host, drawn off screen at the frame-check size of
// `ColorfallCanyonsTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80), after every
// closed valve is opened and the fluid has run a few ticks (so the emitters flow and sheets exist), at each quality
// tier level-0, level-1 and level-2, match the Core's CPU reference of the presenter's last snapshot: flowing emitter
// tops within 3 px of a pixel 0.15 brighter than night, open cell top centres at least 0.1 away from night (every dry
// front-row cell, at least 80 % of all), background corners within 0.05 of night. The presenter's frame probes (two
// night corners) match the drawn still at every tier. A time step changes the digest and undo restores it. One test per
// level, each well under 10 s.
#if os(iOS)
import ColorfallCanyonsCore
import Foundation
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ColorfallCanyonsRenderTests {
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: seed)
        let level: Int = ColorfallCanyonsExperienceCore.levelNumber(forSeed: seed)
        #expect(try ColorfallCanyonsTest.core(shell).levelNumber == level)
        let before: String = try ColorfallCanyonsTest.digest(shell)
        let accepted: Int = try ColorfallCanyonsTest.flow(shell)
        #expect(accepted >= 1, "level \(level): the time step was accepted")
        #expect(try ColorfallCanyonsTest.digest(shell) != before, "level \(level): the fluid ran")
        for tier in 0..<3 {
            ColorfallCanyonsTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
            let snapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.time == 0, "the still's frame time is 0")
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.tick > 0, "level \(level): ticks ran")
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            var wet: Int = 0
            for cell in 0..<snapshot.cellCount where snapshot.volume(cell) > 0 { wet += 1 }
            #expect(wet > 0, "level \(level): fluid exists after the ticks")
            ColorfallCanyonsTest.checkFrame(rgba, snapshot: snapshot, "level \(level) tier \(tier)")
            let emitters = ColorfallCanyonsTest.emitterMisses(rgba, snapshot: snapshot)
            let cells = ColorfallCanyonsTest.cellResults(rgba, snapshot: snapshot)
            print("colorfall-canyons level \(level) tier \(tier): emitters checked \(emitters.checked), dimmed "
                  + "\(emitters.dimmed); open cells \(cells.passed) of \(cells.checked), front row "
                  + "\(cells.strictChecked); wet cells \(wet)")
        }
        session.qualityPin = 0
    }

    @Test func aTimeStepChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 20)
        let before: String = try ColorfallCanyonsTest.digest(shell)
        let first: [UInt8] = try ColorfallCanyonsTest.still(session)
        let firstSnapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.tick == 0)
        let result: ActionResult = shell.handle(control: "time.step", values: [3])
        #expect(result == .accepted, "\(result.code)")
        let stepped: String = try ColorfallCanyonsTest.digest(shell)
        #expect(stepped != before, "a time step changes the digest")
        let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
        let snapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        // A step stops at the first tick whose verdict decides the play, so at most 3 ticks ran.
        #expect(snapshot.tick >= 1 && snapshot.tick <= 3, "the frame draws the stepped state")
        var anyFlowing: Bool = false
        for spring in snapshot.springs where spring.flowing { anyFlowing = true }
        if anyFlowing { #expect(rgba != first, "fluid released by an open spring changes the frame") }
        ColorfallCanyonsTest.checkFrame(rgba, snapshot: snapshot, "level 21 after time.step 3")
        // Undo restores the earlier digest exactly and the frame is the first one again.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try ColorfallCanyonsTest.digest(shell) == before)
        let undone: [UInt8] = try ColorfallCanyonsTest.still(session)
        #expect(undone == first, "undo draws the first frame again")
        // Redo returns to the stepped digest.
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try ColorfallCanyonsTest.digest(shell) == stepped)
    }

    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0)
        let before: String = try ColorfallCanyonsTest.digest(shell)
        #expect(shell.handle(control: "time.step", values: [0]) != .accepted, "a step of 0 ticks is refused")
        #expect(shell.handle(control: "canyon.valve", values: [1.5]) != .accepted, "a fractional spring is refused")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(try ColorfallCanyonsTest.digest(shell) == before)
        let rgba: [UInt8] = try ColorfallCanyonsTest.still(session)
        let snapshot: ColorfallCanyonsSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        // The opening frame: only the open springs flow; the cell and background checks hold as well.
        ColorfallCanyonsTest.checkFrame(rgba, snapshot: snapshot, "level 1 after refusals")
    }

    /// The presenter's frame probes (two night corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ColorfallCanyonsTest.open(session, seed: 0)
        try ColorfallCanyonsTest.flow(shell)
        for tier in 0..<3 {
            ColorfallCanyonsTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try ColorfallCanyonsTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = ColorfallCanyonsTest.bottomUp(still, width: ColorfallCanyonsTest.width,
                                                              height: ColorfallCanyonsTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try ColorfallCanyonsTest.core(shell))
            #expect(probes.map(\.name) == ["night-top-left", "night-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: ColorfallCanyonsTest.width,
                                              height: ColorfallCanyonsTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }
}
#endif
