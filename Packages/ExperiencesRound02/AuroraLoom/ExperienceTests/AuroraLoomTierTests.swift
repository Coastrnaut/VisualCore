// AuroraLoomTierTests — feature 303 (R02-G01-03) T-R02G0103-008 (FR-R02G0103-004, 006; SC-R02G0103-001; clarification
// Q2). The three quality tiers change only density, layers and glow: through the one app's session host, at 96 × 64
// off screen, every tier keeps the ribbons, markers and background on the same CPU reference positions; the presenter's
// tier log records each tier change with its reason; and the minimal tier (level-2) is not brighter on average than the
// richest (level-0). Short runs only.
#if os(iOS)
import Foundation
import Testing
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct AuroraLoomTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        for tier in AuroraLoomTier.all { names.append(tier.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(AuroraLoomExperienceCore.qualityTiers == 3)
        #expect(AuroraLoomTier.all[0].layers == 5 && AuroraLoomTier.all[2].layers == 1)
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 60)
        var snapshots: [AuroraLoomSceneSnapshot] = []
        for tier in 0..<3 {
            AuroraLoomTest.pin(session, shell, tier: tier)
            let rgba = try AuroraLoomTest.still(session)
            let snapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            AuroraLoomTest.checkFrame(rgba, snapshot: snapshot, "tier \(tier)")
        }
        // The same snapshot (steps, level, time) feeds every tier, so the reference positions are the same.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        let aspect = Double(AuroraLoomTest.width) / Double(AuroraLoomTest.height)
        for gate in 0..<4 {
            let a = AuroraLoomSceneGeometry.markerPixel(gate: gate, snapshot: snapshots[0], aspect: aspect,
                                                        width: AuroraLoomTest.width, height: AuroraLoomTest.height)
            let b = AuroraLoomSceneGeometry.markerPixel(gate: gate, snapshot: snapshots[2], aspect: aspect,
                                                        width: AuroraLoomTest.width, height: AuroraLoomTest.height)
            #expect(a?.x == b?.x && a?.y == b?.y, "gate \(gate)")
        }
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsEveryChangeWithItsReason() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 20)
        let presenter = shell.presenter
        #expect(presenter.tierLog == [AuroraLoomTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            AuroraLoomTest.pin(session, shell, tier: tier)
            try AuroraLoomTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        // Drawing again at the same tier adds nothing.
        try AuroraLoomTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func theMinimalTierIsNotBrighterThanTheRichest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraLoomTest.open(session, seed: 0)
        AuroraLoomTest.pin(session, shell, tier: 0)
        let richest = AuroraLoomTest.meanLuminance(try AuroraLoomTest.still(session))
        AuroraLoomTest.pin(session, shell, tier: 2)
        let minimal = AuroraLoomTest.meanLuminance(try AuroraLoomTest.still(session))
        print("aurora-loom tiers: mean luminance level-0 \(richest), level-2 \(minimal)")
        let night = AuroraLoomTest.nightLuminance
        #expect(minimal > night, "level-2 draws something: \(minimal)")
        #expect(richest + 0.005 >= minimal, "level-0 \(richest) vs level-2 \(minimal)")
        session.qualityPin = 0
    }
}
#endif
