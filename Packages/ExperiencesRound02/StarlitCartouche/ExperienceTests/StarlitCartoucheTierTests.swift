// StarlitCartoucheTierTests — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-002, 004, 007; clarification
// Q2). The three quality tiers change only the star sphere detail, the trails' motion-blur ghosts and the glow shells,
// never positions: the camera depends on neither the tier nor the time, every reference point (every star's centre,
// the ship's centre, every trail's midpoint, the cartouche's centre, the first actions bar) projects to the same pixel
// at every tier, richer tiers build more chart and glow vertices (no glow at level-2), the time moves no vertex and the
// glide moves only the ship; through the one app's session host every tier's off-screen still passes the same
// reference at the same pixels; the presenter's tier log records the first frame and each change with its reason; the
// presenter's quality levels are the Core's three tiers; drawing at every tier and several frame times, and choosing a
// destination, leave the state digest and the snapshot payload unchanged (renderer purity). Short runs.
#if os(iOS)
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct StarlitCartoucheTierTests {
    /// The three tiers are level-0 … level-2 with sphere segments, ghosts and glow shells as clarification Q2 lists
    /// them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var longitudes: [Int] = []
        var latitudes: [Int] = []
        var ghosts: [Int] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in StarlitCartoucheTier.all {
            names.append(tier.name)
            longitudes.append(tier.longitudes)
            latitudes.append(tier.latitudes)
            ghosts.append(tier.ghosts)
            shells.append(tier.glowShells)
            gains.append(StarlitCartoucheShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(longitudes == [16, 12, 0])
        #expect(latitudes == [12, 8, 0])
        #expect(ghosts == [3, 1, 0])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(StarlitCartoucheTier.all[2].flatStars && !StarlitCartoucheTier.all[0].flatStars)
        #expect(StarlitCartoucheExperienceCore.qualityTiers == 3)
        #expect(StarlitCartoucheTier.of(-1) == StarlitCartoucheTier.all[0])
        #expect(StarlitCartoucheTier.of(7) == StarlitCartoucheTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<StarlitCartouchePresenter> = StarlitCartoucheExperience.make(
            id: StarlitCartoucheTest.id)
        #expect(shell.qualityProfile.count == StarlitCartoucheExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in StarlitCartoucheTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        var coreNames: [String] = []
        for level in StarlitCartoucheExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 and after their first certified leg, every reference point projects;
    /// the chart mesh and the glow shrink with the tier (no glow at level-2); the time moves nothing; the glide moves
    /// only the ship.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let first: StarlitCartoucheAction = try #require(try StarlitCartoucheTest.certifiedLegs(number).first)
            let states: [StarlitCartoucheExperienceCore] = [
                try StarlitCartoucheExperienceCore.opening(number: number),
                try StarlitCartoucheTest.coreAfter(number, [first]),
            ]
            for (stateIndex, core) in states.enumerated() {
                try checkPositions(core, "level \(number) state \(stateIndex)")
            }
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks;
    /// the same star is bright at every tier.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 60)
        var snapshots: [StarlitCartoucheSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var stars: [Int] = []
        for tier in 0..<3 {
            StarlitCartoucheTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try StarlitCartoucheTest.still(session)
            let snapshot: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            let report: StarlitCartoucheCheckReport = StarlitCartoucheTest.checkFrame(rgba, snapshot: snapshot,
                                                                                      "level 61 tier \(tier)")
            stars.append(report.starsChecked)
            pixels.append(StarlitCartoucheTest.referencePixels(snapshot))
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same and the
        // same stars are sampled.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(stars[0] == stars[1] && stars[1] == stars[2], "\(stars)")
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 20)
        let presenter: StarlitCartouchePresenter = shell.presenter
        #expect(presenter.tierLog == [StarlitCartoucheTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            StarlitCartoucheTest.pin(session, shell, tier: tier)
            try StarlitCartoucheTest.draw(session, frames: 2)
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
        try StarlitCartoucheTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time, and choosing a destination and a wait, leave the digest and the snapshot
    /// payload unchanged (renderer purity).
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StarlitCartoucheTest.open(session, seed: 40)
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(41)
        let first: [StarlitCartoucheAction] = Array(legs.prefix(1))
        #expect(StarlitCartoucheTest.issue(shell, first) == first.count)
        let before: String = try StarlitCartoucheTest.digest(shell)
        let payload: Data = try StarlitCartoucheTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            StarlitCartoucheTest.pin(session, shell, tier: tier)
            try StarlitCartoucheTest.draw(session, frames: 3)
            for time in times {
                _ = try StarlitCartoucheTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try StarlitCartoucheTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try StarlitCartoucheTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        // Choosing another destination and wait is presentation only.
        let core: StarlitCartoucheExperienceCore = try StarlitCartoucheTest.core(shell)
        let mirror: StarlitCartoucheMirror = shell.presenter.mirror
        _ = shell.presenter.describe(core)
        let destination: Int = mirror.nextDestination(1)
        let chosen: ActionResult = shell.handle(control: "route.choose", values: [Double(destination), 3])
        #expect(chosen == .accepted, "\(chosen.code)")
        _ = try StarlitCartoucheTest.still(session, width: 96, height: 64)
        let drawn: StarlitCartoucheSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(drawn.chosenStar == destination && drawn.chosenWait == 3, "the choice is drawn")
        #expect(try StarlitCartoucheTest.digest(shell) == before, "choosing leaves the digest")
        #expect(try StarlitCartoucheTest.core(shell).snapshotPayload() == payload, "choosing leaves the payload")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// The CPU checks of one state: the reference projects; chart and glow meshes shrink with the tier; no glow at
    /// level-2; the time moves nothing; the glide moves only the ship (and nothing before the first leg).
    private func checkPositions(_ core: StarlitCartoucheExperienceCore, _ what: String) throws {
        let snapshot: StarlitCartoucheSceneSnapshot = core.snapshot(time: 0)
        let reference: [SIMD2<Double>?] = StarlitCartoucheTest.referencePixels(snapshot)
        var missing: Int = 0
        for p in reference where p == nil { missing += 1 }
        #expect(reference.count >= snapshot.stars.count + 3, "\(what): stars, ship, cartouche, bar")
        #expect(missing == 0, "\(what): \(missing) reference points without a projection")
        var chartSizes: [Int] = []
        var glowSizes: [Int] = []
        for tier in StarlitCartoucheTier.all {
            let chart: Mesh = try StarlitCartoucheSceneGeometry.chartMesh(snapshot, tier: tier, glide: 1)
            #expect(!chart.indices.isEmpty, "\(what) \(tier.name): the chart is drawn")
            chartSizes.append(chart.positions.count)
            let glow: Mesh = try StarlitCartoucheSceneGeometry.glowMesh(snapshot, tier: tier, glide: 1)
            glowSizes.append(glow.positions.count)
            if tier.glowShells == 0 {
                #expect(glow.indices.isEmpty, "\(what) \(tier.name): no glow")
            }
        }
        // Fewer sphere facets and ghosts on cheaper tiers; fewer glow shells.
        #expect(chartSizes[0] > chartSizes[1] && chartSizes[1] > chartSizes[2], "\(what): \(chartSizes)")
        #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(what): \(glowSizes)")
        // The camera and every vertex are the same for every time (the snapshot's time is presentation only).
        let later: StarlitCartoucheSceneSnapshot = core.snapshot(time: 7.5)
        #expect(StarlitCartoucheTest.referencePixels(later) == reference, "\(what): time moves nothing")
        let best: StarlitCartoucheTier = StarlitCartoucheTier.all[0]
        let laterMesh: Mesh = try StarlitCartoucheSceneGeometry.chartMesh(later, tier: best, glide: 1)
        let firstMesh: Mesh = try StarlitCartoucheSceneGeometry.chartMesh(snapshot, tier: best, glide: 1)
        #expect(laterMesh.positions == firstMesh.positions, "\(what): the time moves no vertex")
        // The glide moves the ship along its newest trail, nothing before the first leg; the reference is at rest.
        let start: Mesh = try StarlitCartoucheSceneGeometry.chartMesh(snapshot, tier: best, glide: 0)
        if snapshot.legs.isEmpty {
            #expect(start.positions == firstMesh.positions, "\(what): no glide before the first leg")
        } else {
            #expect(start.positions != firstMesh.positions, "\(what): the glide moves the ship")
            #expect(start.positions.count == firstMesh.positions.count, "\(what): and only moves it")
        }
    }
}
#endif
