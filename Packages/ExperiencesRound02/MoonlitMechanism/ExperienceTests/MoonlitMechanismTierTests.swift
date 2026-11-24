// MoonlitMechanismTierTests — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-002, 004, 006; SC-R02G1403-001,
// 002; clarification Q2). The three quality tiers change only the gears' outline segments, the soft shadow edges and
// the glow shells, never positions: the camera depends on neither the tier nor the time, every reference point
// (cast-cell centres, rim check points, the first card, the first alignment pip, the first moves bar) projects to the
// same pixel at every tier, richer tiers build more clockwork and glow vertices (no glow at level-2), and Reduce Motion
// draws the same mesh; through the one app's session host every tier's off-screen still passes the same reference at
// the same pixels and the same cast cell is dark at every tier; the presenter's tier log records the first frame and
// each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at every tier and
// several frame times leaves the state digest and the snapshot payload unchanged (renderer purity). Short runs.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct MoonlitMechanismTierTests {
    /// The three tiers are level-0 … level-2 with outline segments, soft edges and glow shells as clarification Q2
    /// lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var segments: [Int] = []
        var soft: [Bool] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in MoonlitMechanismTier.all {
            names.append(tier.name)
            segments.append(tier.segmentsPerTooth)
            soft.append(tier.softEdge)
            shells.append(tier.glowShells)
            gains.append(MoonlitMechanismShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(segments == [6, 4, 2])
        #expect(soft == [true, true, false])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(MoonlitMechanismExperienceCore.qualityTiers == 3)
        #expect(MoonlitMechanismTier.of(-1) == MoonlitMechanismTier.all[0])
        #expect(MoonlitMechanismTier.of(7) == MoonlitMechanismTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<MoonlitMechanismPresenter> =
            MoonlitMechanismExperience.make(id: MoonlitMechanismTest.id)
        #expect(shell.qualityProfile.count == MoonlitMechanismExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in MoonlitMechanismTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in MoonlitMechanismExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 every reference point projects; the clockwork and glow shrink with the
    /// tier (no glow at level-2); Reduce Motion draws the same mesh; the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let core: MoonlitMechanismExperienceCore = try MoonlitMechanismExperienceCore.opening(number: number)
            let snapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: 0)
            let reference: [SIMD2<Double>?] = MoonlitMechanismTest.referencePixels(snapshot)
            var missing: Int = 0
            for p in reference where p == nil { missing += 1 }
            #expect(!reference.isEmpty)
            #expect(missing == 0, "level \(number): \(missing) reference points without a projection")
            var clockworkSizes: [Int] = []
            var glowSizes: [Int] = []
            for tier in MoonlitMechanismTier.all {
                let what: String = "level \(number) \(tier.name)"
                let clockwork: Mesh = try MoonlitMechanismSceneGeometry.clockworkMesh(snapshot, tier: tier,
                                                                                    reduceMotion: false)
                #expect(!clockwork.indices.isEmpty, "\(what): clockwork drawn")
                clockworkSizes.append(clockwork.positions.count)
                let still: Mesh = try MoonlitMechanismSceneGeometry.clockworkMesh(snapshot, tier: tier,
                                                                                reduceMotion: true)
                #expect(still == clockwork, "\(what): Reduce Motion draws the same mesh")
                let glow: Mesh = try MoonlitMechanismSceneGeometry.glowMesh(snapshot, tier: tier)
                glowSizes.append(glow.positions.count)
                if tier.glowShells == 0 {
                    #expect(glow.indices.isEmpty, "\(what): no glow")
                }
            }
            // Fewer outline segments and no feathers on cheaper tiers; fewer glow shells.
            #expect(clockworkSizes[0] > clockworkSizes[1] && clockworkSizes[1] > clockworkSizes[2],
                    "level \(number): \(clockworkSizes)")
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "level \(number): \(glowSizes)")
            // The camera is the same for every time (the snapshot's time is presentation only).
            let later: MoonlitMechanismSceneSnapshot = core.snapshot(time: 7.5)
            #expect(MoonlitMechanismTest.referencePixels(later) == reference, "level \(number): time moves nothing")
            let best: MoonlitMechanismTier = MoonlitMechanismTier.all[0]
            let laterMesh: Mesh = try MoonlitMechanismSceneGeometry.clockworkMesh(later, tier: best, reduceMotion: true)
            let firstMesh: Mesh = try MoonlitMechanismSceneGeometry.clockworkMesh(snapshot, tier: best,
                                                                                reduceMotion: false)
            #expect(laterMesh == firstMesh, "level \(number): the time moves no vertex")
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: 60)
        var snapshots: [MoonlitMechanismSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var cells: [Int] = []
        for tier in 0..<3 {
            MoonlitMechanismTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MoonlitMechanismTest.still(session)
            let snapshot: MoonlitMechanismSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            MoonlitMechanismTest.checkFrame(rgba, snapshot: snapshot, "level 61 tier \(tier)")
            pixels.append(MoonlitMechanismTest.referencePixels(snapshot))
            // The same cast cell is dark at every tier.
            let clear = try #require(MoonlitMechanismTest.clearCells(snapshot).first, "tier \(tier): a clear cast cell")
            cells.append(clear.cell)
            let radius: Double = MoonlitMechanismTest.pointRadius
            let dark: Bool = MoonlitMechanismTest.anyPixel(rgba, near: clear.p, radius: radius,
                                                           width: MoonlitMechanismTest.width,
                                                           height: MoonlitMechanismTest.height,
                                                           where: MoonlitMechanismTest.isShadow)
            #expect(dark, "tier \(tier): cast cell \(clear.cell)")
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same and the
        // cell is sampled at the same place.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(cells[0] == cells[1] && cells[1] == cells[2])
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: 20)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        #expect(presenter.tierLog == [MoonlitMechanismTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            MoonlitMechanismTest.pin(session, shell, tier: tier)
            try MoonlitMechanismTest.draw(session, frames: 2)
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
        try MoonlitMechanismTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time leaves the digest and the snapshot payload unchanged (renderer purity).
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: 40)
        let moves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(41)
        #expect(MoonlitMechanismTest.issue(shell, Array(moves.prefix(2))) == Swift.min(moves.count, 2))
        let before: String = try MoonlitMechanismTest.digest(shell)
        let payload: Data = try MoonlitMechanismTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            MoonlitMechanismTest.pin(session, shell, tier: tier)
            try MoonlitMechanismTest.draw(session, frames: 3)
            for time in times {
                _ = try MoonlitMechanismTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try MoonlitMechanismTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try MoonlitMechanismTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        session.qualityPin = 0
    }
}
#endif
