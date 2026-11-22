// ChronoConstellatorTierTests — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-002, 004, 006; SC-R02G0603-001,
// 002; clarification Q2). The three quality tiers change only the ribbon length, the ribbon segments and the glow
// shells, never coordinates: the camera does not depend on the tier, the field (grid, tracks, targets, holds, marks)
// and star meshes are identical at every tier and every ribbon starts at its star's node centre; through the one app's
// session host every tier's off-screen still matches the same reference at the same star pixels; the presenter's tier
// log records the first frame and each change with its reason; the presenter's quality levels are the Core's three
// tiers; drawing at every tier and several frame times leaves the state digest and the snapshot payload unchanged
// (renderer purity). Short runs only.
#if os(iOS)
import ChronoConstellatorCore
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct ChronoConstellatorTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var ticks: [Int] = []
        var segments: [Int] = []
        var shells: [Int] = []
        for tier in ChronoConstellatorTier.all {
            names.append(tier.name)
            ticks.append(tier.ribbonTicks)
            segments.append(tier.segments)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(ticks == [24, 12, 6])
        #expect(segments == [4, 2, 1])
        #expect(shells == [2, 1, 0])
        #expect(ChronoConstellatorExperienceCore.qualityTiers == 3)
    }

    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<ChronoConstellatorPresenter> =
            ChronoConstellatorExperience.make(id: ChronoConstellatorTest.id)
        #expect(shell.qualityProfile.count == ChronoConstellatorExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in ChronoConstellatorTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in ChronoConstellatorExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    @Test func everyTierSharesTheSameCoordinates() throws {
        let numbers: [Int] = [1, 21, 41]
        for number in numbers {
            let core: ChronoConstellatorExperienceCore = try ChronoConstellatorTest.advanced(number)
            let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
            // The camera and the projection do not depend on the tier; every reference point projects.
            let reference: [Vec2?] = ChronoConstellatorTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            let best: ChronoConstellatorTier = ChronoConstellatorTier.of(0)
            let field0: Mesh = try ChronoConstellatorSceneGeometry.fieldMesh(snapshot, tier: best)
            let stars0: Mesh = try ChronoConstellatorSceneGeometry.starMesh(snapshot, tier: best)
            for tier in ChronoConstellatorTier.all {
                let what: String = "level \(number) \(tier.name)"
                #expect(try ChronoConstellatorSceneGeometry.fieldMesh(snapshot, tier: tier) == field0,
                        "\(what): grid, tracks, targets and marks")
                #expect(try ChronoConstellatorSceneGeometry.starMesh(snapshot, tier: tier) == stars0, "\(what): stars")
                // Every ribbon's newest point is its star's node centre, at every tier.
                for star in 0..<snapshot.stars.count {
                    let newest: SIMD3<Double>? = ChronoConstellatorSceneGeometry.ribbonPoint(star, age: 0, snapshot)
                    #expect(newest == ChronoConstellatorSceneGeometry.starCentre(star, snapshot),
                            "\(what): ribbon \(star) starts at its node")
                }
                // The ribbons are the only part that changes: fewer ticks and segments at cheaper tiers.
                let ribbons: Mesh = try ChronoConstellatorSceneGeometry.ribbonMesh(snapshot, tier: tier)
                #expect(!ribbons.indices.isEmpty, "\(what): ribbons drawn")
            }
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 40)
        ChronoConstellatorTest.advance(shell)
        var snapshots: [ChronoConstellatorSceneSnapshot] = []
        var pixels: [[Double]] = []
        var lit: [[Int]] = []
        for tier in 0..<3 {
            ChronoConstellatorTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try ChronoConstellatorTest.still(session)
            let snapshot: ChronoConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            ChronoConstellatorTest.checkFrame(rgba, snapshot: snapshot, "level 41 tier \(tier)")
            let starPixels: [Double] = ChronoConstellatorTest.starPixels(snapshot)
            pixels.append(starPixels)
            // The stars found lit at their reference pixels at this tier.
            var found: [Int] = []
            let threshold: Double = ChronoConstellatorTest.fieldLuminance + ChronoConstellatorTest.litMargin
            for star in 0..<snapshot.stars.count {
                let px: Double = starPixels[2 * star]
                let py: Double = starPixels[2 * star + 1]
                guard px.isFinite, py.isFinite else { continue }
                if ChronoConstellatorTest.anyPixel(rgba, near: px, py, radius: ChronoConstellatorTest.pointRadius,
                                                   width: ChronoConstellatorTest.width,
                                                   height: ChronoConstellatorTest.height, minimum: threshold,
                                                   above: true, reference: 0) {
                    found.append(star)
                }
            }
            lit.append(found)
        }
        // The same snapshot feeds every tier, so the reference is the same; the same stars show at the same pixels.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2], "\(pixels)")
        #expect(lit[0] == lit[1] && lit[1] == lit[2], "\(lit)")
        var all: [Int] = []
        for star in 0..<snapshots[0].stars.count { all.append(star) }
        #expect(lit[0] == all)
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 20)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        #expect(presenter.tierLog == [ChronoConstellatorTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            ChronoConstellatorTest.pin(session, shell, tier: tier)
            try ChronoConstellatorTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        // Drawing again at the same tier adds nothing.
        try ChronoConstellatorTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ChronoConstellatorTest.open(session, seed: 0)
        ChronoConstellatorTest.advance(shell)
        let before: String = try ChronoConstellatorTest.digest(shell)
        let payload: Data = try ChronoConstellatorTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            ChronoConstellatorTest.pin(session, shell, tier: tier)
            try ChronoConstellatorTest.draw(session, frames: 3)
            for time in times {
                _ = try ChronoConstellatorTest.still(session, width: 96, height: 64, time: time)
                #expect(try ChronoConstellatorTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try ChronoConstellatorTest.draw(session, frames: 2)
        #expect(try ChronoConstellatorTest.digest(shell) == before)
        #expect(try ChronoConstellatorTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
