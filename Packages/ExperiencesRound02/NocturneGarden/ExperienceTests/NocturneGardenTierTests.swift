// NocturneGardenTierTests — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-002, 004, 006; SC-R02G0903-001, 002;
// clarification Q2). The three quality tiers change only the mist layers, the stem depth, the shadow feather and the
// glow shells, never positions: the camera does not depend on the tier, every bed cell centre, gauge bar and the lantern
// project to the same pixels at every tier, the blooms' boxes are the same, the richer tiers build more garden vertices
// (feather bands, stem segments and leaves) and more glow shells (none at level-2); through the one app's session host
// every tier's off-screen still passes the same reference at the same pixels; the presenter's tier log records the first
// frame and each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at every
// tier and several frame times leaves the state digest and the snapshot payload unchanged (renderer purity). Short runs.
#if os(iOS)
import Foundation
import NocturneGardenCore
import Testing
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct NocturneGardenTierTests {
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var layers: [Int] = []
        var depths: [Int] = []
        var feathers: [Double] = []
        var shells: [Int] = []
        for tier in NocturneGardenTier.all {
            names.append(tier.name)
            layers.append(tier.mistLayers)
            depths.append(tier.stemDepth)
            feathers.append(tier.feather)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(layers == [3, 2, 1])
        #expect(depths == [3, 2, 1])
        #expect(feathers == [0.3, 0.15, 0])
        #expect(shells == [2, 1, 0])
        #expect(NocturneGardenExperienceCore.qualityTiers == 3)
    }

    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<NocturneGardenPresenter> = NocturneGardenExperience.make(id: NocturneGardenTest.id)
        #expect(shell.qualityProfile.count == NocturneGardenExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in NocturneGardenTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in NocturneGardenExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: after the witness's first plant, every reference point projects, the bloom boxes are the same at every
    /// tier and the meshes differ by tier only in size.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 21, 41]
        for number in numbers {
            let core: NocturneGardenExperienceCore = try NocturneGardenTest.advanced(number)
            let snapshot: NocturneGardenSceneSnapshot = core.snapshot(time: 1)
            let reference: [Vec2?] = NocturneGardenTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            let camera: NocturneGardenCamera = NocturneGardenTest.camera(snapshot, width: NocturneGardenTest.width,
                                                                         height: NocturneGardenTest.height)
            var gardenSizes: [Int] = []
            var glowSizes: [Int] = []
            var boxes: [[Vec2]] = []
            for tier in NocturneGardenTier.all {
                let what: String = "level \(number) \(tier.name)"
                let garden: Mesh = try NocturneGardenSceneGeometry.gardenMesh(snapshot, tier: tier)
                #expect(!garden.indices.isEmpty, "\(what): garden drawn")
                gardenSizes.append(garden.positions.count)
                let glow: Mesh = try NocturneGardenSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow shells")
                }
                var corners: [Vec2] = []
                for bloom in snapshot.blooms.indices {
                    let box = try #require(NocturneGardenSceneGeometry.bloomPixelBox(
                        bloom, snapshot, tier: tier, camera: camera, width: NocturneGardenTest.width,
                        height: NocturneGardenTest.height), "\(what): bloom \(bloom) box")
                    corners.append(box.min)
                    corners.append(box.max)
                }
                boxes.append(corners)
            }
            #expect(boxes[0] == boxes[1] && boxes[1] == boxes[2], "level \(number): bloom boxes by tier")
            // More feather, stem segments, leaves and glow shells on the richer tiers; the places stay.
            #expect(gardenSizes[0] > gardenSizes[1] && gardenSizes[1] > gardenSizes[2], "\(gardenSizes)")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(glowSizes)")
        }
    }

    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 40)
        try NocturneGardenTest.advance(shell)
        var snapshots: [NocturneGardenSceneSnapshot] = []
        var pixels: [[Vec2?]] = []
        var gauges: [Int?] = []
        for tier in 0..<3 {
            NocturneGardenTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try NocturneGardenTest.still(session, time: 1)
            let snapshot: NocturneGardenSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            NocturneGardenTest.checkFrame(rgba, snapshot: snapshot, "level 41 tier \(tier)")
            pixels.append(NocturneGardenTest.referencePixels(snapshot))
            gauges.append(NocturneGardenTest.gaugeMisses(rgba, snapshot: snapshot).bar)
        }
        // The same snapshot feeds every tier, so the reference is the same and the gauge is measured at the same bar.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(gauges[0] == gauges[1] && gauges[1] == gauges[2])
        session.qualityPin = 0
    }

    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 20)
        let presenter: NocturneGardenPresenter = shell.presenter
        #expect(presenter.tierLog == [NocturneGardenTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            NocturneGardenTest.pin(session, shell, tier: tier)
            try NocturneGardenTest.draw(session, frames: 2)
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
        try NocturneGardenTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await NocturneGardenTest.open(session, seed: 0)
        try NocturneGardenTest.advance(shell)
        let before: String = try NocturneGardenTest.digest(shell)
        let payload: Data = try NocturneGardenTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            NocturneGardenTest.pin(session, shell, tier: tier)
            try NocturneGardenTest.draw(session, frames: 3)
            for time in times {
                _ = try NocturneGardenTest.still(session, width: 96, height: 64, time: time)
                #expect(try NocturneGardenTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try NocturneGardenTest.draw(session, frames: 2)
        #expect(try NocturneGardenTest.digest(shell) == before)
        #expect(try NocturneGardenTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
