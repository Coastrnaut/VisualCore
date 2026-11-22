// FacetedForgeTierTests — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-002, 004, 006; SC-R02G0803-001, 002;
// clarification Q2). The three quality tiers change only the bevel segments, the dispersion layers and the glow shells,
// never positions: the camera does not depend on the tier, the piece, cut face, preview and cut mark reference points
// are the same at every tier, the richer tiers add glow shells over the cut faces; through the one app's session host
// every tier's off-screen still passes the same reference at the same pixels; the presenter's tier log records the
// first frame and each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at
// every tier and several frame times leaves the state digest and the snapshot payload unchanged (renderer purity).
// Short runs only.
#if os(iOS)
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct FacetedForgeTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var bevels: [Int] = []
        var layers: [Int] = []
        var shells: [Int] = []
        for tier in FacetedForgeTier.all {
            names.append(tier.name)
            bevels.append(tier.bevelSegments)
            layers.append(tier.dispersionLayers)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(bevels == [3, 2, 1])
        #expect(layers == [3, 2, 1])
        #expect(shells == [2, 1, 0])
        #expect(FacetedForgeExperienceCore.qualityTiers == 3)
    }

    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<FacetedForgePresenter> = FacetedForgeExperience.make(id: FacetedForgeTest.id)
        #expect(shell.qualityProfile.count == FacetedForgeExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in FacetedForgeTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in FacetedForgeExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: after the first certified cut, every reference point projects and the meshes differ by tier only in the
    /// bevel strips and the glow shells.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 21, 41]
        for number in numbers {
            let core: FacetedForgeExperienceCore = try FacetedForgeTest.advanced(number)
            let snapshot: FacetedForgeSceneSnapshot = core.snapshot(time: 1)
            // The camera and the projection do not depend on the tier; every reference point projects.
            let reference: [Vec2?] = FacetedForgeTest.referencePixels(snapshot, reduceMotion: false)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            #expect(!FacetedForgeSceneGeometry.cutFaceCentres(snapshot).isEmpty, "level \(number): cut faces")
            var crystalSizes: [Int] = []
            var glowSizes: [Int] = []
            for tier in FacetedForgeTier.all {
                let what: String = "level \(number) \(tier.name)"
                let crystal: Mesh = try FacetedForgeSceneGeometry.crystalMesh(snapshot, tier: tier)
                #expect(!crystal.indices.isEmpty, "\(what): crystal drawn")
                crystalSizes.append(crystal.positions.count)
                let glow: Mesh = try FacetedForgeSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow shells")
                }
            }
            // More bevel segments and more glow shells on the richer tiers; the positions of the places stay.
            #expect(crystalSizes[0] > crystalSizes[1] && crystalSizes[1] > crystalSizes[2], "\(crystalSizes)")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(glowSizes)")
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 40)
        let reduceMotion: Bool = shell.presenter.reduceMotion
        try FacetedForgeTest.advance(shell)
        var snapshots: [FacetedForgeSceneSnapshot] = []
        var pixels: [[Vec2?]] = []
        var piecesShown: [Bool] = []
        for tier in 0..<3 {
            FacetedForgeTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try FacetedForgeTest.still(session, time: 1)
            let snapshot: FacetedForgeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            FacetedForgeTest.checkFrame(rgba, snapshot: snapshot, reduceMotion: reduceMotion, expectCutFace: true,
                                        "level 41 tier \(tier)")
            pixels.append(FacetedForgeTest.referencePixels(snapshot, reduceMotion: reduceMotion))
            piecesShown.append(FacetedForgeTest.pieceMisses(rgba, snapshot: snapshot,
                                                            reduceMotion: reduceMotion).misses.isEmpty)
        }
        // The same snapshot feeds every tier, so the reference is the same; the pieces show at the same pixels.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(piecesShown == [true, true, true])
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 20)
        let presenter: FacetedForgePresenter = shell.presenter
        #expect(presenter.tierLog == [FacetedForgeTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            FacetedForgeTest.pin(session, shell, tier: tier)
            try FacetedForgeTest.draw(session, frames: 2)
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
        try FacetedForgeTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await FacetedForgeTest.open(session, seed: 0)
        try FacetedForgeTest.advance(shell)
        let before: String = try FacetedForgeTest.digest(shell)
        let payload: Data = try FacetedForgeTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            FacetedForgeTest.pin(session, shell, tier: tier)
            try FacetedForgeTest.draw(session, frames: 3)
            for time in times {
                _ = try FacetedForgeTest.still(session, width: 96, height: 64, time: time)
                #expect(try FacetedForgeTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try FacetedForgeTest.draw(session, frames: 2)
        #expect(try FacetedForgeTest.digest(shell) == before)
        #expect(try FacetedForgeTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
