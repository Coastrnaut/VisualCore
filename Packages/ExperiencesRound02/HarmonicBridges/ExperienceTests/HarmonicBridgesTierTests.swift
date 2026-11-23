// HarmonicBridgesTierTests — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-002, 004, 006; SC-R02G1203-001,
// 002; clarification Q2). The three quality tiers change only the string motion, the radial wave shells and the glow
// shells, never positions: the camera depends on neither the tier nor the time, every reference point (island tops,
// string midpoints, membrane check points, the gauge's first bar, the first step pip) projects to the same pixel at
// every tier, the bridge mesh without its wave shells holds the same positions at every tier and under Reduce Motion
// (the wave shells only at level-0), and the richer tiers build more glow vertices (none at level-2); through the one
// app's session host every tier's off-screen still passes the same reference at the same pixels and the same island
// top is lit at every tier; the presenter's tier log records the first frame and each change with its reason; the
// presenter's quality levels are the Core's three tiers; drawing at every tier and several frame times leaves the
// state digest and the snapshot payload unchanged (renderer purity). Short runs.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct HarmonicBridgesTierTests {
    /// The three tiers are level-0 … level-2 with motion, wave shells and glow shells as clarification Q2 lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var motion: [Bool] = []
        var waves: [Int] = []
        var shells: [Int] = []
        for tier in HarmonicBridgesTier.all {
            names.append(tier.name)
            motion.append(tier.motion)
            waves.append(tier.waveShells)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(motion == [true, true, false])
        #expect(waves == [2, 0, 0])
        #expect(shells == [2, 1, 0])
        #expect(HarmonicBridgesExperienceCore.qualityTiers == 3)
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<HarmonicBridgesPresenter> =
            HarmonicBridgesExperience.make(id: HarmonicBridgesTest.id)
        #expect(shell.qualityProfile.count == HarmonicBridgesExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in HarmonicBridgesTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in HarmonicBridgesExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: tuned to the certified pegs, every reference point projects and the meshes differ by tier only in the wave
    /// shells and the glow shells.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [2, 41]
        for number in numbers {
            let core: HarmonicBridgesExperienceCore = try HarmonicBridgesTest.tuned(number)
            let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: 0)
            let reference: [SIMD2<Double>?] = HarmonicBridgesTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            var positions: [[Vec3]] = []
            var bridgeSizes: [Int] = []
            var glowSizes: [Int] = []
            for tier in HarmonicBridgesTier.all {
                let what: String = "level \(number) \(tier.name)"
                let bridges: Mesh = try HarmonicBridgesSceneGeometry.bridgeMesh(snapshot, tier: tier,
                                                                                reduceMotion: false)
                #expect(!bridges.indices.isEmpty, "\(what): bridges drawn")
                bridgeSizes.append(bridges.positions.count)
                positions.append(HarmonicBridgesTest.positionsWithoutWaveShells(bridges))
                let glow: Mesh = try HarmonicBridgesSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow shells")
                }
            }
            // The same places at every tier; the wave shells only at level-0; more glow on richer tiers.
            #expect(positions[0] == positions[1] && positions[1] == positions[2], "level \(number): positions")
            #expect(bridgeSizes[0] > bridgeSizes[1] && bridgeSizes[1] == bridgeSizes[2], "\(bridgeSizes)")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(glowSizes)")
            // Reduce Motion moves nothing (it only drops the wave shells and holds the step).
            let still: Mesh = try HarmonicBridgesSceneGeometry.bridgeMesh(snapshot, tier: HarmonicBridgesTier.all[0],
                                                                          reduceMotion: true)
            #expect(HarmonicBridgesTest.positionsWithoutWaveShells(still) == positions[0],
                    "level \(number): Reduce Motion moves nothing")
            // The camera is the same for every time (the snapshot's time only drives uniforms and the shown step).
            let later: HarmonicBridgesSceneSnapshot = core.snapshot(time: 7.5)
            #expect(HarmonicBridgesTest.referencePixels(later) == reference, "level \(number): time moves nothing")
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 40)
        try HarmonicBridgesTest.tune(shell)
        var snapshots: [HarmonicBridgesSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var tops: [Int] = []
        for tier in 0..<3 {
            HarmonicBridgesTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try HarmonicBridgesTest.still(session)
            let snapshot: HarmonicBridgesSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            HarmonicBridgesTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(tier), "level 41 tier \(tier)")
            pixels.append(HarmonicBridgesTest.referencePixels(snapshot))
            // The same island top is lit at every tier.
            let clear = try #require(HarmonicBridgesTest.firstClearTop(snapshot, .tier(tier)),
                                     "tier \(tier): a clear island top")
            tops.append(clear.index)
            let lit: Bool = HarmonicBridgesTest.anyPixel(rgba, near: clear.p, radius: HarmonicBridgesTest.pointRadius,
                                                         width: HarmonicBridgesTest.width,
                                                         height: HarmonicBridgesTest.height,
                                                         where: HarmonicBridgesTest.isTop)
            #expect(lit, "tier \(tier): island \(clear.index)")
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same and the
        // island top is sampled at the same place.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(tops[0] == tops[1] && tops[1] == tops[2])
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 10)
        let presenter: HarmonicBridgesPresenter = shell.presenter
        #expect(presenter.tierLog == [HarmonicBridgesTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            HarmonicBridgesTest.pin(session, shell, tier: tier)
            try HarmonicBridgesTest.draw(session, frames: 2)
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
        try HarmonicBridgesTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time leaves the digest and the snapshot payload unchanged (renderer purity).
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HarmonicBridgesTest.open(session, seed: 1)
        try HarmonicBridgesTest.tune(shell)
        let before: String = try HarmonicBridgesTest.digest(shell)
        let payload: Data = try HarmonicBridgesTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            HarmonicBridgesTest.pin(session, shell, tier: tier)
            try HarmonicBridgesTest.draw(session, frames: 3)
            for time in times {
                _ = try HarmonicBridgesTest.still(session, width: 96, height: 64, time: time)
                #expect(try HarmonicBridgesTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try HarmonicBridgesTest.draw(session, frames: 2)
        #expect(try HarmonicBridgesTest.digest(shell) == before)
        #expect(try HarmonicBridgesTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
