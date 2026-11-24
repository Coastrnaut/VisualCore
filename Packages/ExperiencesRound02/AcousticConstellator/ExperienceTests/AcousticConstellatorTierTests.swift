// AcousticConstellatorTierTests — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-002, 004, 006; SC-R02G1303-001,
// 002; clarification Q2). The three quality tiers change only the star pulse, the radial wave shells and the glow
// shells, never positions: the camera depends on neither the tier nor the time, every reference point (star centres,
// link check points, the first coherence bar, the first hold pip, the first moves bar) projects to the same pixel at
// every tier, the constellation mesh is the same at every tier and under Reduce Motion at tick 0, and the richer tiers
// build more glow vertices (none at level-2); through the one app's session host every tier's off-screen still passes
// the same reference at the same pixels and the same star centre is lit at every tier; the presenter's tier log
// records the first frame and each change with its reason; the presenter's quality levels are the Core's three tiers;
// drawing at every tier and several frame times leaves the state digest and the snapshot payload unchanged (renderer
// purity). Short runs.
#if os(iOS)
import Foundation
import AcousticConstellatorCore
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct AcousticConstellatorTierTests {
    /// The three tiers are level-0 … level-2 with pulse, wave shells and glow shells as clarification Q2 lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var pulse: [Bool] = []
        var waves: [Int] = []
        var shells: [Int] = []
        for tier in AcousticConstellatorTier.all {
            names.append(tier.name)
            pulse.append(tier.pulse)
            waves.append(tier.waveShells)
            shells.append(tier.glowShells)
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(pulse == [true, true, false])
        #expect(waves == [2, 0, 0])
        #expect(shells == [2, 1, 0])
        #expect(AcousticConstellatorExperienceCore.qualityTiers == 3)
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<AcousticConstellatorPresenter> =
            AcousticConstellatorExperience.make(id: AcousticConstellatorTest.id)
        #expect(shell.qualityProfile.count == AcousticConstellatorExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in AcousticConstellatorTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in AcousticConstellatorExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: arranged to the certified plan, every reference point projects, the constellation mesh is the same at every
    /// tier and the glow shrinks with the tier.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [24, 72]
        for number in numbers {
            let core: AcousticConstellatorExperienceCore = try AcousticConstellatorTest.arranged(number)
            let snapshot: AcousticConstellatorSceneSnapshot = core.snapshot(time: 0)
            let reference: [SIMD2<Double>?] = AcousticConstellatorTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            var meshes: [Mesh] = []
            var glowSizes: [Int] = []
            for tier in AcousticConstellatorTier.all {
                let what: String = "level \(number) \(tier.name)"
                let constellation: Mesh = try AcousticConstellatorSceneGeometry.constellationMesh(
                    snapshot, tier: tier, reduceMotion: false)
                #expect(!constellation.indices.isEmpty, "\(what): constellation drawn")
                meshes.append(constellation)
                let glow: Mesh = try AcousticConstellatorSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow")
                }
            }
            // The same constellation at every tier (the pulse is a shader uniform); more glow on richer tiers.
            #expect(meshes[0] == meshes[1] && meshes[1] == meshes[2], "level \(number): constellation")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(glowSizes)")
            // Reduce Motion moves nothing at time 0 (tick 0 either way).
            let still: Mesh = try AcousticConstellatorSceneGeometry.constellationMesh(
                snapshot, tier: AcousticConstellatorTier.all[0], reduceMotion: true)
            #expect(still == meshes[0], "level \(number): Reduce Motion moves nothing at tick 0")
            // The camera is the same for every time (the snapshot's time only drives the shown tick and uniforms).
            let later: AcousticConstellatorSceneSnapshot = core.snapshot(time: 7.5)
            #expect(AcousticConstellatorTest.referencePixels(later) == reference, "level \(number): time moves nothing")
            let laterMesh: Mesh = try AcousticConstellatorSceneGeometry.constellationMesh(
                later, tier: AcousticConstellatorTier.all[0], reduceMotion: true)
            #expect(laterMesh == meshes[0], "level \(number): Reduce Motion draws tick 0 at any time")
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 71)
        try AcousticConstellatorTest.arrange(shell)
        var snapshots: [AcousticConstellatorSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var stars: [Int] = []
        for tier in 0..<3 {
            AcousticConstellatorTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try AcousticConstellatorTest.still(session)
            let snapshot: AcousticConstellatorSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            AcousticConstellatorTest.checkFrame(rgba, snapshot: snapshot, mode: .tier(tier), "level 72 tier \(tier)")
            pixels.append(AcousticConstellatorTest.referencePixels(snapshot))
            // The same star centre is lit at every tier.
            let clear = try #require(AcousticConstellatorTest.firstClearStar(snapshot), "tier \(tier): a clear star")
            stars.append(clear.index)
            let lit: Bool = AcousticConstellatorTest.anyPixel(rgba, near: clear.p,
                                                              radius: AcousticConstellatorTest.pointRadius,
                                                              width: AcousticConstellatorTest.width,
                                                              height: AcousticConstellatorTest.height,
                                                              where: AcousticConstellatorTest.isWhiteStar)
            #expect(lit, "tier \(tier): star \(clear.index)")
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same and the star
        // is sampled at the same place.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(stars[0] == stars[1] && stars[1] == stars[2])
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 43)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        #expect(presenter.tierLog == [AcousticConstellatorTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            AcousticConstellatorTest.pin(session, shell, tier: tier)
            try AcousticConstellatorTest.draw(session, frames: 2)
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
        try AcousticConstellatorTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time leaves the digest and the snapshot payload unchanged (renderer purity).
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AcousticConstellatorTest.open(session, seed: 59)
        try AcousticConstellatorTest.arrange(shell)
        let before: String = try AcousticConstellatorTest.digest(shell)
        let payload: Data = try AcousticConstellatorTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            AcousticConstellatorTest.pin(session, shell, tier: tier)
            try AcousticConstellatorTest.draw(session, frames: 3)
            for time in times {
                _ = try AcousticConstellatorTest.still(session, width: 96, height: 64, time: time)
                #expect(try AcousticConstellatorTest.digest(shell) == before, "tier \(tier) time \(time)")
            }
        }
        session.qualityPin = 0
        try AcousticConstellatorTest.draw(session, frames: 2)
        #expect(try AcousticConstellatorTest.digest(shell) == before)
        #expect(try AcousticConstellatorTest.core(shell).snapshotPayload() == payload)
    }
}
#endif
