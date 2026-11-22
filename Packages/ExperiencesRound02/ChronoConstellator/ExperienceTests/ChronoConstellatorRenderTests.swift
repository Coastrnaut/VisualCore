// ChronoConstellatorRenderTests — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-001 … 003, 006; SC-R02G0603-001;
// clarifications Q1, Q3). Through the one app's session host, drawn off screen at the frame-check size of
// `ChronoConstellatorTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80), after a
// short hold and a few ticks (so ribbons, a hold bar and moved stars exist), at each quality tier level-0, level-1 and
// level-2, match the Core's CPU reference of the presenter's last snapshot: star node centres within 3 px of a pixel
// 0.15 brighter than the field, target rings at least 0.1 away from the field, the two probe corners within 0.05 of the
// field. The presenter's frame probes (two field corners) match the drawn still at every tier. A time step changes the
// digest and the frame, undo restores both. One test per level, each well under 10 s.
#if os(iOS)
import ChronoConstellatorCore
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct ChronoConstellatorRenderTests {
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: seed)
        let level: Int = ChronoConstellatorExperienceCore.levelNumber(forSeed: seed)
        #expect(try ChronoConstellatorTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too.
        let opening: [UInt8] = try ChronoConstellatorTest.still(session)
        let openingSnapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.tick == 0)
        ChronoConstellatorTest.checkFrame(opening, snapshot: openingSnapshot, "level \(level) opening")
        let before: String = try ChronoConstellatorTest.digest(shell)
        let accepted: Int = ChronoConstellatorTest.advance(shell)
        #expect(accepted >= 1, "level \(level): the time step was accepted")
        #expect(try ChronoConstellatorTest.digest(shell) != before, "level \(level): the play advanced")
        for tier in 0..<3 {
            ChronoConstellatorTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
            let snapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.time == 0, "the still's frame time is 0")
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.tick > 0, "level \(level): ticks ran")
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            var ribbons: Int = 0
            for star in snapshot.stars where star.history.count > 1 { ribbons += 1 }
            #expect(ribbons == snapshot.stars.count, "level \(level): every star has a ribbon")
            ChronoConstellatorTest.checkFrame(rgba, snapshot: snapshot, "level \(level) tier \(tier)")
            let stars = ChronoConstellatorTest.starMisses(rgba, snapshot: snapshot)
            let rings = ChronoConstellatorTest.ringMisses(rgba, snapshot: snapshot)
            print("chrono-constellator level \(level) tier \(tier): stars checked \(stars.checked), ring samples "
                  + "\(rings.checked), tick \(snapshot.tick), stage \(snapshot.stage.rawValue), holds "
                  + "\(snapshot.holds.count)")
        }
        session.qualityPin = 0
    }

    @Test func aTimeStepChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 20)
        let before: String = try ChronoConstellatorTest.digest(shell)
        let first: [UInt8] = try ChronoConstellatorTest.still(session)
        let firstSnapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(firstSnapshot.tick == 0)
        let result: ActionResult = shell.handle(control: "time.step", values: [3])
        #expect(result == .accepted, "\(result.code)")
        let stepped: String = try ChronoConstellatorTest.digest(shell)
        #expect(stepped != before, "a time step changes the digest")
        let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
        let snapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        // A step stops at the first tick whose verdict decides the play, so at most 3 ticks ran.
        #expect(snapshot.tick >= 1 && snapshot.tick <= 3, "the frame draws the stepped state")
        // Stars move every tick (loops have at least 4 cells) and ribbons appear: the frame changes.
        #expect(rgba != first, "a time step changes the frame")
        ChronoConstellatorTest.checkFrame(rgba, snapshot: snapshot, "level 21 after time.step 3")
        // Undo restores the earlier digest exactly and the frame is the first one again.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try ChronoConstellatorTest.digest(shell) == before)
        let undone: [UInt8] = try ChronoConstellatorTest.still(session)
        #expect(undone == first, "undo draws the first frame again")
        // Redo returns to the stepped digest (when the step did not end the play; redo is refused in a failed play).
        if snapshot.stage != .failed && snapshot.stage != .won {
            #expect(shell.handle(control: "play.redo") == .accepted)
            #expect(try ChronoConstellatorTest.digest(shell) == stepped)
        }
    }

    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0)
        let before: String = try ChronoConstellatorTest.digest(shell)
        #expect(shell.handle(control: "time.step", values: [0]) != .accepted, "a step of 0 ticks is refused")
        #expect(shell.handle(control: "star.phase", values: [0, 1.5]) != .accepted, "a fractional phase is refused")
        #expect(shell.handle(control: "star.hold", values: [9, 1, 1]) != .accepted, "an unknown star is refused")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(try ChronoConstellatorTest.digest(shell) == before)
        let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
        let snapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.tick == 0 && snapshot.holds.isEmpty)
        ChronoConstellatorTest.checkFrame(rgba, snapshot: snapshot, "level 1 after refusals")
    }

    /// The presenter's frame probes (two field corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0)
        ChronoConstellatorTest.advance(shell)
        for tier in 0..<3 {
            ChronoConstellatorTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try ChronoConstellatorTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = ChronoConstellatorTest.bottomUp(still, width: ChronoConstellatorTest.width,
                                                                height: ChronoConstellatorTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try ChronoConstellatorTest.core(shell))
            var names: [String] = []
            for probe in probes { names.append(probe.name) }
            #expect(names == ["field-top-left", "field-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: ChronoConstellatorTest.width,
                                              height: ChronoConstellatorTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }
}
#endif
