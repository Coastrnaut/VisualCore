// LissajousLabyrinthTierTests — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-003, 004, 006; SC-R02G0203-001;
// clarification Q2). The three quality tiers change only sample density, glow and trail, never coordinates: the CPU
// projection puts every sample the tiers share (every 4th lap tick) at the same pixel at level-0, level-1 and level-2,
// and through the one app's session host every tier's off-screen still matches the same reference; the presenter's
// tier log records the first frame and each change with its reason; drawing at every tier and several frame times
// leaves the state digest and the snapshot payload unchanged (renderer purity, R2-G02-INV-10). Short runs only.
#if os(iOS)
import Foundation
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct LissajousLabyrinthTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var strides: [Int] = []
        for tier in LissajousLabyrinthTier.all {
            names.append(tier.name)
            strides.append(tier.stride)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(strides == [1, 2, 4])
        #expect(LissajousLabyrinthExperienceCore.qualityTiers == 3)
        #expect(LissajousLabyrinthTier.all[0].glowPasses == 2 && LissajousLabyrinthTier.all[2].glowPasses == 0)
    }

    @Test func sharedSamplesProjectToTheSamePixels() throws {
        let w = LissajousLabyrinthTest.width, h = LissajousLabyrinthTest.height
        for seed in LissajousLabyrinthTest.seeds {
            let core = try LissajousLabyrinthExperienceCore.opening(number: Int(seed) + 1)
            let snapshot = core.snapshot(time: 0)
            let vp = LissajousLabyrinthTest.viewProjection(snapshot, width: w, height: h)
            var paths: [[Vec3]] = []
            for tier in LissajousLabyrinthTier.all {
                paths.append(LissajousLabyrinthSceneGeometry.path(snapshot, tier: tier))
            }
            #expect(paths[0].count == 4_096 && paths[1].count == 2_048 && paths[2].count == 1_024)
            var mismatches = 0
            var j = 0
            while j < paths[2].count {
                let a = LissajousLabyrinthSceneGeometry.project(paths[0][4 * j], viewProjection: vp, width: w, height: h)
                let b = LissajousLabyrinthSceneGeometry.project(paths[1][2 * j], viewProjection: vp, width: w, height: h)
                let c = LissajousLabyrinthSceneGeometry.project(paths[2][j], viewProjection: vp, width: w, height: h)
                if a == nil || a != b || b != c { mismatches += 1 }
                j += 1
            }
            #expect(mismatches == 0, "level \(seed + 1): \(mismatches) shared samples at different pixels")
            // The checked samples are the same ticks at every tier.
            var ticks: [[Int]] = []
            for tier in LissajousLabyrinthTier.all {
                var list: [Int] = []
                for sample in LissajousLabyrinthTest.checkedSamples(snapshot, tier: tier, viewProjection: vp, width: w,
                                                                   height: h) {
                    list.append(sample.tick)
                }
                ticks.append(list)
            }
            #expect(ticks[0] == ticks[1] && ticks[1] == ticks[2] && ticks[0].count == 128)
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 60)
        var snapshots: [LissajousLabyrinthSceneSnapshot] = []
        for tier in 0..<3 {
            LissajousLabyrinthTest.pin(session, shell, tier: tier)
            let rgba = try LissajousLabyrinthTest.still(session)
            let snapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            LissajousLabyrinthTest.checkFrame(rgba, snapshot: snapshot, tier: tier, "tier \(tier)")
        }
        // The same snapshot (level, dials, verdict, visits, time) feeds every tier, so the reference is the same.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 20)
        let presenter = shell.presenter
        #expect(presenter.tierLog == [LissajousLabyrinthTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            LissajousLabyrinthTest.pin(session, shell, tier: tier)
            try LissajousLabyrinthTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        // Drawing again at the same tier adds nothing.
        try LissajousLabyrinthTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await LissajousLabyrinthTest.open(session, seed: 40)
        let before = try LissajousLabyrinthTest.digest(shell)
        let payload = try #require(shell.engine.core).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            LissajousLabyrinthTest.pin(session, shell, tier: tier)
            try LissajousLabyrinthTest.draw(session, frames: 3)
            for time in times {
                _ = try LissajousLabyrinthTest.still(session, width: 96, height: 64, time: time)
                #expect(try LissajousLabyrinthTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try LissajousLabyrinthTest.draw(session, frames: 2)
        #expect(try LissajousLabyrinthTest.digest(shell) == before)
        #expect(try #require(shell.engine.core).snapshotPayload() == payload)
    }
}
#endif
