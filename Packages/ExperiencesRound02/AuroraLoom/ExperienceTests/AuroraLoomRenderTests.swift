// AuroraLoomRenderTests — feature 303 (R02-G01-03) T-R02G0103-008 (FR-R02G0103-001 … 003, 006; SC-R02G0103-001, 002;
// clarifications Q1, Q3, Q4; R2-G01-INV-10). Through the one app's session host, drawn off screen at 96 × 64: levels 1,
// 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80) at each quality tier level-0, level-1 and level-2 match the Core's CPU
// reference of the presenter's last snapshot (ribbon samples within 2 px of lit pixels, marker colours within 0.12,
// background within 0.05 of night), and drawing at every tier and several frame times leaves the state digest unchanged
// (renderer purity). One test per level, each well under 10 s.
#if os(iOS)
import Foundation
import Testing
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct AuroraLoomRenderTests {
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: seed)
        let level = AuroraLoomExperienceCore.levelNumber(forSeed: seed)
        #expect(try #require(shell.engine.core).levelNumber == level)
        for tier in 0..<3 {
            AuroraLoomTest.pin(session, shell, tier: tier)
            let rgba = try AuroraLoomTest.still(session)
            let snapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.time == 0, "the still's frame time is 0")
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            AuroraLoomTest.checkFrame(rgba, snapshot: snapshot, "level \(level) tier \(tier)")
        }
        session.qualityPin = 0
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 40)
        let before = try AuroraLoomTest.digest(shell)
        let payload = try #require(shell.engine.core).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0]
        for tier in 0..<3 {
            AuroraLoomTest.pin(session, shell, tier: tier)
            try AuroraLoomTest.draw(session, frames: 3)
            for time in times {
                _ = try AuroraLoomTest.still(session, time: time)
                #expect(try AuroraLoomTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try AuroraLoomTest.draw(session, frames: 2)
        #expect(try AuroraLoomTest.digest(shell) == before)
        #expect(try #require(shell.engine.core).snapshotPayload() == payload)
    }

    @Test func aMoveChangesTheDigestAndTheFrameStillMatches() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 0)
        let before = try AuroraLoomTest.digest(shell)
        let core = try #require(shell.engine.core)
        let wave = core.play.steps.wave[0]
        let result = shell.handle(control: "ribbon.move", values: [0, 0, Double((wave + 1) % 16)])
        #expect(result == .accepted, "\(result.code)")
        #expect(try AuroraLoomTest.digest(shell) != before)
        let rgba = try AuroraLoomTest.still(session)
        let snapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.steps.wave[0] == (wave + 1) % 16)
        AuroraLoomTest.checkFrame(rgba, snapshot: snapshot, "after a move")
    }
}
#endif
