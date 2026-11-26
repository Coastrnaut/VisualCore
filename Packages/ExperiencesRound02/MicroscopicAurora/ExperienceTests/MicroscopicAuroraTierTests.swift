// MicroscopicAuroraTierTests — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-002, 004, 007; clarification
// Q2). The three quality tiers change only the capsule detail, the ribbons' length, the fronds and the glow shells,
// never positions: the camera depends on neither the snapshot, the tier nor the time; every reference point (the dish
// centre, the rim's rightmost point, every swimmer at the shown tick, the first site, the coverage track's centre, the
// first actions bar) projects to the same pixel at every tier; every ribbon passes through exactly the kernel
// positions of its ticks and ends at the shown tick at every tier; richer tiers build more dish and glow vertices (no
// glow at level-2); and the time moves no vertex. Through the one app's session host every tier's off-screen still
// passes the same reference at the same pixels; the presenter's tier log records the first frame and each change
// with its reason; the presenter's quality levels are the Core's three tiers; drawing at every tier and several frame
// times, and showing a tick, leave the state digest and the snapshot payload unchanged (renderer purity), and a tick
// past the ticks swum is refused. Short runs.
#if os(iOS)
import Foundation
import MicroscopicAuroraCore
import Testing
@testable import MicroscopicAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct MicroscopicAuroraTierTests {
    /// The three tiers are level-0 … level-2 with capsule segments, ribbon ticks, fronds and glow shells as
    /// clarification Q2 lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var segments: [Int] = []
        var ribbons: [Int] = []
        var fronds: [Bool] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in MicroscopicAuroraTier.all {
            names.append(tier.name)
            segments.append(tier.capsuleSegments)
            ribbons.append(tier.ribbonTicks)
            fronds.append(tier.fronds)
            shells.append(tier.glowShells)
            gains.append(MicroscopicAuroraShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(segments == [12, 8, 0])
        #expect(ribbons == [64, 32, 16])
        #expect(fronds == [true, true, false])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(MicroscopicAuroraTier.all[2].flatCapsules && !MicroscopicAuroraTier.all[0].flatCapsules)
        #expect(MicroscopicAuroraExperienceCore.qualityTiers == 3)
        #expect(MicroscopicAuroraTier.of(-1) == MicroscopicAuroraTier.all[0])
        #expect(MicroscopicAuroraTier.of(7) == MicroscopicAuroraTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<MicroscopicAuroraPresenter> = MicroscopicAuroraExperience.make(
            id: MicroscopicAuroraTest.id)
        #expect(shell.qualityProfile.count == MicroscopicAuroraExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in MicroscopicAuroraTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
        var coreNames: [String] = []
        for level in MicroscopicAuroraExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 and with their certified plan placed (the tick half the ticks swum
    /// shown), every reference point projects; every ribbon holds exactly its kernel positions; the dish and glow
    /// meshes shrink with the tier (no glow at level-2); the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(number)
            let states: [MicroscopicAuroraExperienceCore] = [
                try MicroscopicAuroraTest.coreAfter(number, []),
                try MicroscopicAuroraTest.coreAfter(number, plan),
            ]
            for (stateIndex, core) in states.enumerated() {
                try checkPositions(core, "level \(number) state \(stateIndex)")
            }
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(61)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 60, setUp: plan)
        var snapshots: [MicroscopicAuroraSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var measured: [Bool] = []
        for tier in 0..<3 {
            MicroscopicAuroraTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MicroscopicAuroraTest.still(session)
            let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            let report: MicroscopicAuroraCheckReport = MicroscopicAuroraTest.checkFrame(rgba, snapshot: snapshot,
                                                                                        "level 61 tier \(tier)")
            measured.append(report.swimmersChecked >= 1 && report.trackChecked)
            pixels.append(MicroscopicAuroraTest.referencePixels(snapshot))
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(measured == [true, true, true], "\(measured)")
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MicroscopicAuroraTest.open(session, seed: 20)
        let presenter: MicroscopicAuroraPresenter = shell.presenter
        #expect(presenter.tierLog == [MicroscopicAuroraTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            MicroscopicAuroraTest.pin(session, shell, tier: tier)
            try MicroscopicAuroraTest.draw(session, frames: 2)
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
        try MicroscopicAuroraTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time, and showing a tick, leave the digest and the snapshot payload unchanged
    /// (renderer purity); a tick past the ticks swum is refused and changes nothing.
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(41)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 40, setUp: plan)
        let before: String = try MicroscopicAuroraTest.digest(shell)
        let payload: Data = try MicroscopicAuroraTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            MicroscopicAuroraTest.pin(session, shell, tier: tier)
            try MicroscopicAuroraTest.draw(session, frames: 3)
            for time in times {
                _ = try MicroscopicAuroraTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try MicroscopicAuroraTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try MicroscopicAuroraTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        // Showing another tick is presentation only.
        let shown: ActionResult = shell.handle(control: "clock.show", values: [3])
        #expect(shown == .accepted, "\(shown.code)")
        _ = try MicroscopicAuroraTest.still(session, width: 96, height: 64)
        let drawn: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(drawn.shownTick == 3, "the tick is drawn")
        for i in drawn.positions.indices {
            let want: SIMD3<Double> = MicroscopicAuroraSceneGeometry.world(drawn.positions[i][3],
                                                                           depth: MicroscopicAuroraSceneGeometry.planeZ)
            #expect(MicroscopicAuroraSceneGeometry.swimmerCentre(i, drawn) == want, "swimmer \(i) at tick 3")
        }
        #expect(try MicroscopicAuroraTest.digest(shell) == before, "showing leaves the digest")
        #expect(try MicroscopicAuroraTest.core(shell).snapshotPayload() == payload, "showing leaves the payload")
        // A tick past the end of the swim is refused and changes nothing, the shown tick included.
        let ticks: Int = drawn.ticksSwum
        #expect(ticks < MicroscopicAuroraExperienceCore.tickRange.upperBound, "the ticks swum \(ticks) are declared")
        let refused: ActionResult = shell.handle(control: "clock.show", values: [Double(ticks + 1)])
        #expect(refused.code == "action.rule." + MicroscopicAuroraExperienceRule.tick, "\(refused.code)")
        #expect(try MicroscopicAuroraTest.core(shell).shownTick == 3)
        #expect(try MicroscopicAuroraTest.digest(shell) == before)
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// The CPU checks of one state: the reference projects; every ribbon holds exactly its kernel positions and ends
    /// at the shown tick at every tier; the dish and glow meshes shrink with the tier; no glow at level-2; the time
    /// moves nothing.
    private func checkPositions(_ core: MicroscopicAuroraExperienceCore, _ what: String) throws {
        typealias G = MicroscopicAuroraSceneGeometry
        let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.shownTick == MicroscopicAuroraTest.halfTick(snapshot.ticksSwum), "\(what): the half tick")
        let reference: [SIMD2<Double>?] = MicroscopicAuroraTest.referencePixels(snapshot)
        var missing: Int = 0
        for p in reference where p == nil { missing += 1 }
        #expect(reference.count == MicroscopicAuroraTest.referenceCount(snapshot),
                "\(what): dish centre, rim point, swimmers, first site, coverage track, first bar")
        #expect(missing == 0, "\(what): \(missing) reference points without a projection")
        var dishSizes: [Int] = []
        var glowSizes: [Int] = []
        for tier in MicroscopicAuroraTier.all {
            let dish: Mesh = try G.dishMesh(snapshot, tier: tier)
            #expect(!dish.indices.isEmpty, "\(what) \(tier.name): the dish is drawn")
            dishSizes.append(dish.positions.count)
            let glow: Mesh = try G.glowMesh(snapshot, tier: tier)
            glowSizes.append(glow.positions.count)
            if tier.glowShells == 0 {
                #expect(glow.indices.isEmpty, "\(what) \(tier.name): no glow")
            }
            // Every ribbon is exactly the kernel positions of its ticks, ending at the shown tick.
            var held: Int = 0
            for i in snapshot.positions.indices {
                let ticks: ClosedRange<Int> = G.ribbonTicks(i, snapshot, tier: tier)
                let points: [SIMD3<Double>] = G.ribbon(i, snapshot, tier: tier)
                var want: [SIMD3<Double>] = []
                for t in ticks { want.append(G.world(snapshot.positions[i][t], depth: G.planeZ)) }
                if ticks.upperBound == snapshot.shownTick && points == want { held += 1 }
            }
            #expect(held == snapshot.positions.count, "\(what) \(tier.name): ribbons on kernel positions \(held)")
        }
        // Fewer capsule facets, ribbon points and fronds on cheaper tiers; fewer glow shells.
        #expect(dishSizes[0] > dishSizes[1] && dishSizes[1] > dishSizes[2], "\(what): \(dishSizes)")
        #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(what): \(glowSizes)")
        // The paint order is the same for every tier and time (it takes no tier), and the time moves no vertex.
        let later: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 7.5)
        #expect(MicroscopicAuroraTest.referencePixels(later) == reference, "\(what): time moves nothing")
        #expect(G.paintOrder(later) == G.paintOrder(snapshot), "\(what): time changes no element")
        let best: MicroscopicAuroraTier = MicroscopicAuroraTier.all[0]
        let laterMesh: Mesh = try G.dishMesh(later, tier: best)
        let firstMesh: Mesh = try G.dishMesh(snapshot, tier: best)
        #expect(laterMesh.positions == firstMesh.positions, "\(what): the time moves no vertex")
        let laterGlow: Mesh = try G.glowMesh(later, tier: best)
        let firstGlow: Mesh = try G.glowMesh(snapshot, tier: best)
        #expect(laterGlow.positions == firstGlow.positions, "\(what): the time moves no glow vertex")
    }
}
#endif
