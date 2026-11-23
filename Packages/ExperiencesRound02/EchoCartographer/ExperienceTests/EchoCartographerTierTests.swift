// EchoCartographerTierTests — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-002, 004, 006; SC-R02G1103-001,
// 002; clarification Q2). The three quality tiers change only the pulse and echo rings, the flare trails and the glow
// shells, never positions: the camera does not depend on the tier, every reference point (floor-tile centres, wall
// tops, the entry, markers, the gauge's first bar) projects to the same pixel at every tier, the chamber mesh without
// its ring field holds the same positions at every tier (the ring field only at the tiers with rings), and the richer
// tiers build more glow vertices (none at level-2); through the one app's session host every tier's off-screen still
// passes the same reference at the same pixels and the same floor-tile pixel is lit at every tier; the presenter's tier
// log records the first frame and each change with its reason; the presenter's quality levels are the Core's three
// tiers; drawing at every tier and several frame times leaves the state digest and the snapshot payload unchanged
// (renderer purity). Short runs.
#if os(iOS)
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct EchoCartographerTierTests {
    /// The three tiers are level-0 … level-2 with rings, trails and glow shells as clarification Q2 lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var rings: [Bool] = []
        var trails: [Bool] = []
        var shells: [Int] = []
        for tier in EchoCartographerTier.all {
            names.append(tier.name)
            rings.append(tier.rings)
            trails.append(tier.flareTrails)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(rings == [true, true, false])
        #expect(trails == [true, false, false])
        #expect(shells == [2, 1, 0])
        #expect(EchoCartographerExperienceCore.qualityTiers == 3)
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<EchoCartographerPresenter> =
            EchoCartographerExperience.make(id: EchoCartographerTest.id)
        #expect(shell.qualityProfile.count == EchoCartographerExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in EchoCartographerTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in EchoCartographerExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: after one pulse from the entry, every reference point projects and the meshes differ by tier only in the
    /// ring field and the glow shells.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 21, 41]
        for number in numbers {
            let core: EchoCartographerExperienceCore = try EchoCartographerTest.advanced(number)
            let snapshot: EchoCartographerSceneSnapshot = core.snapshot(time: 1)
            let reference: [SIMD2<Double>?] = EchoCartographerTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            var positions: [[Vec3]] = []
            var chamberSizes: [Int] = []
            var glowSizes: [Int] = []
            for tier in EchoCartographerTier.all {
                let what: String = "level \(number) \(tier.name)"
                let chamber: Mesh = try EchoCartographerSceneGeometry.chamberMesh(snapshot, tier: tier,
                                                                                  reduceMotion: false)
                #expect(!chamber.indices.isEmpty, "\(what): chamber drawn")
                chamberSizes.append(chamber.positions.count)
                positions.append(EchoCartographerTest.positionsWithoutRingField(chamber))
                let glow: Mesh = try EchoCartographerSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow shells")
                }
            }
            // The same places at every tier; the ring field only where rings are drawn; more glow on richer tiers.
            #expect(positions[0] == positions[1] && positions[1] == positions[2], "level \(number): positions")
            #expect(chamberSizes[0] == chamberSizes[1] && chamberSizes[1] > chamberSizes[2], "\(chamberSizes)")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(glowSizes)")
            // Reduce Motion moves nothing.
            let still: Mesh = try EchoCartographerSceneGeometry.chamberMesh(snapshot, tier: EchoCartographerTier.all[0],
                                                                            reduceMotion: true)
            let moving: Mesh = try EchoCartographerSceneGeometry.chamberMesh(snapshot,
                                                                             tier: EchoCartographerTier.all[0],
                                                                             reduceMotion: false)
            #expect(still.positions == moving.positions, "level \(number): Reduce Motion moves nothing")
            // The camera is the same for every time (the snapshot's time only drives uniforms).
            let later: EchoCartographerSceneSnapshot = core.snapshot(time: 7.5)
            #expect(EchoCartographerTest.referencePixels(later) == reference, "level \(number): time moves nothing")
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 40)
        try EchoCartographerTest.advance(shell)
        var snapshots: [EchoCartographerSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var probes: [Int] = []
        for tier in 0..<3 {
            EchoCartographerTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try EchoCartographerTest.still(session)
            let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, "level 41 tier \(tier)")
            pixels.append(EchoCartographerTest.referencePixels(snapshot))
            // The same floor-tile pixel is lit at every tier.
            let clear = try #require(EchoCartographerTest.firstClearFloor(snapshot), "tier \(tier): a clear floor")
            probes.append(clear.index)
            let lit: Bool = EchoCartographerTest.anyPixel(rgba, near: clear.p, radius: EchoCartographerTest.pointRadius,
                                                          width: EchoCartographerTest.width,
                                                          height: EchoCartographerTest.height,
                                                          where: EchoCartographerTest.isFloor)
            #expect(lit, "tier \(tier): floor \(clear.index)")
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same and the
        // floor is sampled at the same place.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(probes[0] == probes[1] && probes[1] == probes[2])
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 20)
        let presenter: EchoCartographerPresenter = shell.presenter
        #expect(presenter.tierLog == [EchoCartographerTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            EchoCartographerTest.pin(session, shell, tier: tier)
            try EchoCartographerTest.draw(session, frames: 2)
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
        try EchoCartographerTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time leaves the digest and the snapshot payload unchanged (renderer purity).
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        try EchoCartographerTest.advance(shell)
        let before: String = try EchoCartographerTest.digest(shell)
        let payload: Data = try EchoCartographerTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.5, 7.0, 70.0]
        for tier in 0..<3 {
            EchoCartographerTest.pin(session, shell, tier: tier)
            try EchoCartographerTest.draw(session, frames: 3)
            for time in times {
                _ = try EchoCartographerTest.still(session, width: 96, height: 64, time: time)
                #expect(try EchoCartographerTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try EchoCartographerTest.draw(session, frames: 2)
        #expect(try EchoCartographerTest.digest(shell) == before)
        #expect(try EchoCartographerTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
