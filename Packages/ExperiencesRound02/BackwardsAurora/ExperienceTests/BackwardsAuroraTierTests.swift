// BackwardsAuroraTierTests — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-002, 004, 006; SC-R02G1003-001, 002;
// clarification Q2). The three quality tiers change only the trailing aurora layers, the pulses and the glow shells,
// never positions: the camera does not depend on the tier, every sample point, ring centre and the gauge's first bar
// project to the same pixels at every tier, the richer tiers build more aurora vertices (trailing layers) and more glow
// vertices (none at level-2); through the one app's session host every tier's off-screen still passes the same reference
// at the same pixels and the same ribbon pixel is cyan at every tier; the presenter's tier log records the first frame
// and each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at every tier and
// several frame times leaves the state digest and the snapshot payload unchanged (renderer purity). Short runs.
#if os(iOS)
import Foundation
import BackwardsAuroraCore
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct BackwardsAuroraTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var layers: [Int] = []
        var pulses: [Int] = []
        var shells: [Int] = []
        for tier in BackwardsAuroraTier.all {
            names.append(tier.name)
            layers.append(tier.trailingLayers)
            pulses.append(tier.pulses)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(layers == [3, 2, 1])
        #expect(pulses == [2, 1, 0])
        #expect(shells == [2, 1, 0])
        #expect(BackwardsAuroraExperienceCore.qualityTiers == 3)
    }

    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<BackwardsAuroraPresenter> = BackwardsAuroraExperience.make(id: BackwardsAuroraTest.id)
        #expect(shell.qualityProfile.count == BackwardsAuroraExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in BackwardsAuroraTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in BackwardsAuroraExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: after the first reversal, every reference point projects and the meshes differ by tier only in size.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 21, 41]
        for number in numbers {
            let core: BackwardsAuroraExperienceCore = try BackwardsAuroraTest.advanced(number)
            let snapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 0, sectionEnd: 1, time: 1)
            let reference: [SIMD2<Double>?] = BackwardsAuroraTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            var auroraSizes: [Int] = []
            var glowSizes: [Int] = []
            for tier in BackwardsAuroraTier.all {
                let what: String = "level \(number) \(tier.name)"
                let aurora: Mesh = try BackwardsAuroraSceneGeometry.auroraMesh(snapshot, tier: tier)
                #expect(!aurora.indices.isEmpty, "\(what): aurora drawn")
                auroraSizes.append(aurora.positions.count)
                let glow: Mesh = try BackwardsAuroraSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow shells")
                }
            }
            // More trailing layers and glow shells on the richer tiers; the places stay.
            #expect(auroraSizes[0] > auroraSizes[1] && auroraSizes[1] > auroraSizes[2], "\(auroraSizes)")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(glowSizes)")
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 40)
        try BackwardsAuroraTest.advance(shell)
        var snapshots: [BackwardsAuroraSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var probes: [Int] = []
        for tier in 0..<3 {
            BackwardsAuroraTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try BackwardsAuroraTest.still(session)
            let snapshot: BackwardsAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            BackwardsAuroraTest.checkFrame(rgba, snapshot: snapshot, "level 41 tier \(tier)")
            pixels.append(BackwardsAuroraTest.referencePixels(snapshot))
            // The same ribbon pixel is cyan at every tier.
            let clear = try #require(BackwardsAuroraTest.firstClearSample(snapshot), "tier \(tier): a clear sample")
            probes.append(clear.k)
            #expect(BackwardsAuroraTest.anyPixel(rgba, near: clear.p, radius: BackwardsAuroraTest.pointRadius,
                                                 width: BackwardsAuroraTest.width, height: BackwardsAuroraTest.height,
                                                 where: BackwardsAuroraTest.isRibbon),
                    "tier \(tier): ribbon at sample \(clear.k)")
        }
        // The same snapshot feeds every tier, so the reference is the same and the ribbon is sampled at the same place.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(probes[0] == probes[1] && probes[1] == probes[2])
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 20)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        #expect(presenter.tierLog == [BackwardsAuroraTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            BackwardsAuroraTest.pin(session, shell, tier: tier)
            try BackwardsAuroraTest.draw(session, frames: 2)
            #expect(presenter.tierLog.last?.tier == tier)
        }
        var tiers: [Int] = []
        for change in presenter.tierLog {
            tiers.append(change.tier)
            #expect(!change.reason.isEmpty, "tier \(change.tier) has a reason")
        }
        #expect(tiers == [0, 1, 2, 0])
        for change in presenter.tierLog.dropFirst() {
            #expect(change.reason == "quality controller changed the tier")
        }
        // Drawing again at the same tier adds nothing.
        try BackwardsAuroraTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BackwardsAuroraTest.open(session, seed: 0)
        try BackwardsAuroraTest.advance(shell)
        let before: String = try BackwardsAuroraTest.digest(shell)
        let payload: Data = try BackwardsAuroraTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            BackwardsAuroraTest.pin(session, shell, tier: tier)
            try BackwardsAuroraTest.draw(session, frames: 3)
            for time in times {
                _ = try BackwardsAuroraTest.still(session, width: 96, height: 64, time: time)
                #expect(try BackwardsAuroraTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try BackwardsAuroraTest.draw(session, frames: 2)
        #expect(try BackwardsAuroraTest.digest(shell) == before)
        #expect(try BackwardsAuroraTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
