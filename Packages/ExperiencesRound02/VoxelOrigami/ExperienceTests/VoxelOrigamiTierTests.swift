// VoxelOrigamiTierTests — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-002, 004, 006; SC-R02G1503-001,
// 002; clarification Q2). The three quality tiers change only the cubes' chamfer bevel, the target wireframe's edge
// width and the glow shells, never positions: the camera depends on neither the tier nor the time, every reference
// point (cube centres, hinge centres, the first covered pip, the first moves bar) projects to the same pixel at every
// tier, richer tiers build more voxel and glow vertices (no glow at level-2), and Reduce Motion draws the same mesh;
// through the one app's session host every tier's off-screen still passes the same reference at the same pixels and the
// same cube is bright at every tier; the presenter's tier log records the first frame and each change with its reason;
// the presenter's quality levels are the Core's three tiers; drawing at every tier and several frame times leaves the
// state digest and the snapshot payload unchanged (renderer purity). Short runs.
#if os(iOS)
import Foundation
import Testing
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VoxelOrigamiCore

@MainActor
@Suite(.serialized) struct VoxelOrigamiTierTests {
    /// The three tiers are level-0 … level-2 with bevel steps, edge widths and glow shells as clarification Q2 lists
    /// them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var bevels: [Int] = []
        var edges: [Double] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in VoxelOrigamiTier.all {
            names.append(tier.name)
            bevels.append(tier.bevelSteps)
            edges.append(tier.edgeWidth)
            shells.append(tier.glowShells)
            gains.append(VoxelOrigamiShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(bevels == [2, 1, 0])
        #expect(edges == [0.06, 0.05, 0.04])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(VoxelOrigamiExperienceCore.qualityTiers == 3)
        #expect(VoxelOrigamiTier.of(-1) == VoxelOrigamiTier.all[0])
        #expect(VoxelOrigamiTier.of(7) == VoxelOrigamiTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<VoxelOrigamiPresenter> = VoxelOrigamiExperience.make(id: VoxelOrigamiTest.id)
        #expect(shell.qualityProfile.count == VoxelOrigamiExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in VoxelOrigamiTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in VoxelOrigamiExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 every reference point projects; the voxel mesh and the glow shrink with
    /// the tier (no glow at level-2); Reduce Motion draws the same mesh; the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let core: VoxelOrigamiExperienceCore = try VoxelOrigamiExperienceCore.opening(number: number)
            let snapshot: VoxelOrigamiSceneSnapshot = core.snapshot(time: 0)
            let reference: [SIMD2<Double>?] = VoxelOrigamiTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(!reference.isEmpty)
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            var voxelSizes: [Int] = []
            var glowSizes: [Int] = []
            for tier in VoxelOrigamiTier.all {
                let what: String = "level \(number) \(tier.name)"
                let voxels: Mesh = try VoxelOrigamiSceneGeometry.voxelMesh(snapshot, tier: tier, reduceMotion: false)
                #expect(!voxels.indices.isEmpty, "\(what): voxels drawn")
                voxelSizes.append(voxels.positions.count)
                let still: Mesh = try VoxelOrigamiSceneGeometry.voxelMesh(snapshot, tier: tier, reduceMotion: true)
                #expect(still == voxels, "\(what): Reduce Motion draws the same mesh")
                let glow: Mesh = try VoxelOrigamiSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow")
                }
            }
            // Fewer bevel facets on cheaper tiers; fewer glow shells.
            #expect(voxelSizes[0] > voxelSizes[1] && voxelSizes[1] > voxelSizes[2], "level \(number): \(voxelSizes)")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "level \(number): \(glowSizes)")
            // The camera is the same for every time (the snapshot's time is presentation only).
            let later: VoxelOrigamiSceneSnapshot = core.snapshot(time: 7.5)
            #expect(VoxelOrigamiTest.referencePixels(later) == reference, "level \(number): time moves nothing")
            let best: VoxelOrigamiTier = VoxelOrigamiTier.all[0]
            let laterMesh: Mesh = try VoxelOrigamiSceneGeometry.voxelMesh(later, tier: best, reduceMotion: true)
            let firstMesh: Mesh = try VoxelOrigamiSceneGeometry.voxelMesh(snapshot, tier: best, reduceMotion: false)
            #expect(laterMesh == firstMesh, "level \(number): the time moves no vertex")
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 60)
        var snapshots: [VoxelOrigamiSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var cubes: [Int] = []
        for tier in 0..<3 {
            VoxelOrigamiTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try VoxelOrigamiTest.still(session)
            let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            VoxelOrigamiTest.checkFrame(rgba, snapshot: snapshot, "level 61 tier \(tier)")
            pixels.append(VoxelOrigamiTest.referencePixels(snapshot))
            // The same cube is bright at every tier.
            let clear = try #require(VoxelOrigamiTest.clearCubes(snapshot).first, "tier \(tier): a clear cube")
            cubes.append(clear.cube)
            let radius: Double = VoxelOrigamiTest.pointRadius
            let bright: Bool = VoxelOrigamiTest.anyPixel(rgba, near: clear.p, radius: radius,
                                                         width: VoxelOrigamiTest.width,
                                                         height: VoxelOrigamiTest.height,
                                                         where: VoxelOrigamiTest.isCubeBright)
            #expect(bright, "tier \(tier): cube \(clear.cube)")
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same and the
        // cube is sampled at the same place.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(cubes[0] == cubes[1] && cubes[1] == cubes[2])
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 20)
        let presenter: VoxelOrigamiPresenter = shell.presenter
        #expect(presenter.tierLog == [VoxelOrigamiTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            VoxelOrigamiTest.pin(session, shell, tier: tier)
            try VoxelOrigamiTest.draw(session, frames: 2)
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
        try VoxelOrigamiTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time leaves the digest and the snapshot payload unchanged (renderer purity).
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 40)
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(41)
        let first: [VoxelOrigamiAction] = Array(turns.prefix(2))
        #expect(VoxelOrigamiTest.issue(shell, first) == first.count)
        let before: String = try VoxelOrigamiTest.digest(shell)
        let payload: Data = try VoxelOrigamiTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            VoxelOrigamiTest.pin(session, shell, tier: tier)
            try VoxelOrigamiTest.draw(session, frames: 3)
            for time in times {
                _ = try VoxelOrigamiTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try VoxelOrigamiTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try VoxelOrigamiTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        session.qualityPin = 0
    }
}
#endif
