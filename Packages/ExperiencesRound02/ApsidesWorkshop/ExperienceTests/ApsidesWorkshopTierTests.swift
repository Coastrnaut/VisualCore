// ApsidesWorkshopTierTests — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-002, 004, 007; clarification Q2). The
// three quality tiers change only the sphere detail, the orbit loop's refinement between ticks and the glow shells,
// never positions: the camera depends on neither the snapshot, the tier nor the time; every reference point (every
// planet's centre, the star's centre, the orbiter's centre at the shown tick T/2, the first gauge track's centre, the
// first actions bar) projects to the same pixel at every tier; the orbit loop passes through every kernel position at
// every tier (the judged chords stay the kernel's); richer tiers build more compass and glow vertices (no glow at
// level-2); and the time moves no vertex. Through the one app's session host every tier's off-screen still passes the
// same reference at the same pixels; the presenter's tier log records the first frame and each change with its reason;
// the presenter's quality levels are the Core's three tiers; drawing at every tier and several frame times, and showing
// a tick, leave the state digest and the snapshot payload unchanged (renderer purity), and a tick past the period is
// refused. Short runs.
#if os(iOS)
import ApsidesWorkshopCore
import Foundation
import Testing
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct ApsidesWorkshopTierTests {
    /// The three tiers are level-0 … level-2 with sphere segments, refinement and glow shells as clarification Q2
    /// lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var longitudes: [Int] = []
        var latitudes: [Int] = []
        var refinements: [Int] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in ApsidesWorkshopTier.all {
            names.append(tier.name)
            longitudes.append(tier.longitudes)
            latitudes.append(tier.latitudes)
            refinements.append(tier.refinement)
            shells.append(tier.glowShells)
            gains.append(ApsidesWorkshopShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(longitudes == [24, 16, 0])
        #expect(latitudes == [16, 12, 0])
        #expect(refinements == [4, 2, 0])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(ApsidesWorkshopTier.all[2].flatSpheres && !ApsidesWorkshopTier.all[0].flatSpheres)
        #expect(ApsidesWorkshopTier.discSides == 20)
        #expect(ApsidesWorkshopExperienceCore.qualityTiers == 3)
        #expect(ApsidesWorkshopTier.of(-1) == ApsidesWorkshopTier.all[0])
        #expect(ApsidesWorkshopTier.of(7) == ApsidesWorkshopTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<ApsidesWorkshopPresenter> = ApsidesWorkshopExperience.make(
            id: ApsidesWorkshopTest.id)
        #expect(shell.qualityProfile.count == ApsidesWorkshopExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in ApsidesWorkshopTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
        var coreNames: [String] = []
        for level in ApsidesWorkshopExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 and after their first certified tuning (tick T/2 shown), every
    /// reference point projects; the orbit loop holds every kernel position; the compass and glow meshes shrink with
    /// the tier (no glow at level-2); the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let first: ApsidesWorkshopAction = try #require(try ApsidesWorkshopTest.certifiedPlan(number).first)
            let states: [ApsidesWorkshopExperienceCore] = [
                try ApsidesWorkshopTest.coreAfter(number, []),
                try ApsidesWorkshopTest.coreAfter(number, [first]),
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
        let shell = try await ApsidesWorkshopTest.open(session, seed: 60)
        var snapshots: [ApsidesWorkshopSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var measured: [Bool] = []
        for tier in 0..<3 {
            ApsidesWorkshopTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try ApsidesWorkshopTest.still(session)
            let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            let report: ApsidesWorkshopCheckReport = ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot,
                                                                                    "level 61 tier \(tier)")
            measured.append(report.starChecked && report.orbiterChecked)
            pixels.append(ApsidesWorkshopTest.referencePixels(snapshot))
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
        let shell = try await ApsidesWorkshopTest.open(session, seed: 20)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        #expect(presenter.tierLog == [ApsidesWorkshopTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            ApsidesWorkshopTest.pin(session, shell, tier: tier)
            try ApsidesWorkshopTest.draw(session, frames: 2)
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
        try ApsidesWorkshopTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time, and showing a tick, leave the digest and the snapshot payload unchanged
    /// (renderer purity); a tick past the period is refused and changes nothing.
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 40)
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(41)
        let first: [ApsidesWorkshopAction] = Array(plan.prefix(1))
        #expect(ApsidesWorkshopTest.issue(shell, first) == first.count)
        let before: String = try ApsidesWorkshopTest.digest(shell)
        let payload: Data = try ApsidesWorkshopTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            ApsidesWorkshopTest.pin(session, shell, tier: tier)
            try ApsidesWorkshopTest.draw(session, frames: 3)
            for time in times {
                _ = try ApsidesWorkshopTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try ApsidesWorkshopTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try ApsidesWorkshopTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        // Showing another tick is presentation only.
        let shown: ActionResult = shell.handle(control: "clock.show", values: [3])
        #expect(shown == .accepted, "\(shown.code)")
        _ = try ApsidesWorkshopTest.still(session, width: 96, height: 64)
        let drawn: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(drawn.shownTick == 3 && drawn.orbiter == drawn.positions[3], "the tick is drawn")
        #expect(try ApsidesWorkshopTest.digest(shell) == before, "showing leaves the digest")
        #expect(try ApsidesWorkshopTest.core(shell).snapshotPayload() == payload, "showing leaves the payload")
        // A tick past the end of the revolution is refused and changes nothing, the shown tick included.
        let period: Int = drawn.period
        #expect(period <= ApsidesWorkshopExperienceCore.tickRange.upperBound, "the period \(period) is declared")
        let refused: ActionResult = shell.handle(control: "clock.show", values: [Double(period)])
        #expect(refused.code == "action.rule." + ApsidesWorkshopExperienceRule.tick, "\(refused.code)")
        #expect(try ApsidesWorkshopTest.core(shell).shownTick == 3)
        #expect(try ApsidesWorkshopTest.digest(shell) == before)
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// The CPU checks of one state: the reference projects; the orbit loop holds every kernel position at every
    /// tier; compass and glow meshes shrink with the tier; no glow at level-2; the time moves nothing.
    private func checkPositions(_ core: ApsidesWorkshopExperienceCore, _ what: String) throws {
        let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.shownTick == ApsidesWorkshopTest.halfTick(snapshot.period), "\(what): the tick T/2")
        let reference: [SIMD2<Double>?] = ApsidesWorkshopTest.referencePixels(snapshot)
        var missing: Int = 0
        for p in reference where p == nil { missing += 1 }
        #expect(reference.count == ApsidesWorkshopTest.referenceCount(snapshot),
                "\(what): planets, star, orbiter, first track, first bar")
        #expect(missing == 0, "\(what): \(missing) reference points without a projection")
        var compassSizes: [Int] = []
        var glowSizes: [Int] = []
        for tier in ApsidesWorkshopTier.all {
            let compass: Mesh = try ApsidesWorkshopSceneGeometry.compassMesh(snapshot, tier: tier)
            #expect(!compass.indices.isEmpty, "\(what) \(tier.name): the compass is drawn")
            compassSizes.append(compass.positions.count)
            let glow: Mesh = try ApsidesWorkshopSceneGeometry.glowMesh(snapshot, tier: tier)
            glowSizes.append(glow.positions.count)
            if tier.glowShells == 0 {
                #expect(glow.indices.isEmpty, "\(what) \(tier.name): no glow")
            }
            // The judged chords stay the kernel's: every kernel position is a point of the loop at every tier.
            let loop: [SIMD3<Double>] = ApsidesWorkshopSceneGeometry.refinement(snapshot, tier: tier)
            let step: Int = tier.refinement + 1
            let plane: Double = ApsidesWorkshopSceneGeometry.planeZ
            #expect(loop.count == snapshot.positions.count * step, "\(what) \(tier.name): loop points")
            var held: Int = 0
            for t in snapshot.positions.indices where t * step < loop.count {
                let kernel: SIMD3<Double> = ApsidesWorkshopSceneGeometry.world(snapshot.positions[t], depth: plane)
                if loop[t * step] == kernel { held += 1 }
            }
            #expect(held == snapshot.positions.count, "\(what) \(tier.name): kernel positions on the loop \(held)")
        }
        // Fewer sphere facets and refinement points on cheaper tiers; fewer glow shells.
        #expect(compassSizes[0] > compassSizes[1] && compassSizes[1] > compassSizes[2], "\(what): \(compassSizes)")
        #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(what): \(glowSizes)")
        // The camera and every vertex are the same for every time (the snapshot's time is presentation only).
        let later: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 7.5)
        #expect(ApsidesWorkshopTest.referencePixels(later) == reference, "\(what): time moves nothing")
        let best: ApsidesWorkshopTier = ApsidesWorkshopTier.all[0]
        let laterMesh: Mesh = try ApsidesWorkshopSceneGeometry.compassMesh(later, tier: best)
        let firstMesh: Mesh = try ApsidesWorkshopSceneGeometry.compassMesh(snapshot, tier: best)
        #expect(laterMesh.positions == firstMesh.positions, "\(what): the time moves no vertex")
        let laterGlow: Mesh = try ApsidesWorkshopSceneGeometry.glowMesh(later, tier: best)
        let firstGlow: Mesh = try ApsidesWorkshopSceneGeometry.glowMesh(snapshot, tier: best)
        #expect(laterGlow.positions == firstGlow.positions, "\(what): the time moves no glow vertex")
    }
}
#endif
