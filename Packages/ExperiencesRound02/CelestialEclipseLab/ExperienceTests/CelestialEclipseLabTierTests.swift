// CelestialEclipseLabTierTests — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-002, 004, 007; clarification
// Q2). The three quality tiers change only the body sphere detail and the glow shells, never positions: the camera
// depends on neither the tier nor the time, every reference point (every body's centre, the timeline strip's centre,
// each target bracket, the playhead, the first actions bar) projects to the same pixel at every tier, richer tiers
// build more sky and glow vertices (no glow at level-2), and the time moves no vertex; through the one app's session host
// every tier's off-screen still passes the same reference at the same pixels; the presenter's tier log records the
// first frame and each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at
// every tier and several frame times, and choosing a body and showing a tick, leave the state digest and the snapshot
// payload unchanged (renderer purity). Short runs.
#if os(iOS)
import CelestialEclipseLabCore
import Foundation
import Testing
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct CelestialEclipseLabTierTests {
    /// The three tiers are level-0 … level-2 with sphere segments and glow shells as clarification Q2 lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var longitudes: [Int] = []
        var latitudes: [Int] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in CelestialEclipseLabTier.all {
            names.append(tier.name)
            longitudes.append(tier.longitudes)
            latitudes.append(tier.latitudes)
            shells.append(tier.glowShells)
            gains.append(CelestialEclipseLabShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(longitudes == [24, 16, 0])
        #expect(latitudes == [16, 12, 0])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(CelestialEclipseLabTier.all[2].flatBodies && !CelestialEclipseLabTier.all[0].flatBodies)
        #expect(CelestialEclipseLabTier.discSides == 20)
        #expect(CelestialEclipseLabExperienceCore.qualityTiers == 3)
        #expect(CelestialEclipseLabTier.of(-1) == CelestialEclipseLabTier.all[0])
        #expect(CelestialEclipseLabTier.of(7) == CelestialEclipseLabTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<CelestialEclipseLabPresenter> = CelestialEclipseLabExperience.make(
            id: CelestialEclipseLabTest.id)
        #expect(shell.qualityProfile.count == CelestialEclipseLabExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in CelestialEclipseLabTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
        var coreNames: [String] = []
        for level in CelestialEclipseLabExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 and after their first certified change, every reference point projects;
    /// the sky mesh and the glow shrink with the tier (no glow at level-2); the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let first: CelestialEclipseLabAction = try #require(try CelestialEclipseLabTest.certifiedPlan(number).first)
            let states: [CelestialEclipseLabExperienceCore] = [
                try CelestialEclipseLabExperienceCore.opening(number: number),
                try CelestialEclipseLabTest.coreAfter(number, [first]),
            ]
            for (stateIndex, core) in states.enumerated() {
                try checkPositions(core, "level \(number) state \(stateIndex)")
            }
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks;
    /// the same bodies are bright at every tier.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 60)
        var snapshots: [CelestialEclipseLabSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var bodies: [Int] = []
        for tier in 0..<3 {
            CelestialEclipseLabTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try CelestialEclipseLabTest.still(session)
            let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            let report: CelestialEclipseLabCheckReport = CelestialEclipseLabTest.checkFrame(rgba, snapshot: snapshot,
                                                                                            "level 61 tier \(tier)")
            bodies.append(report.bodiesChecked)
            pixels.append(CelestialEclipseLabTest.referencePixels(snapshot))
        }
        // The same snapshot feeds every tier (stills at the same frame time), so the reference is the same and the
        // same bodies are sampled.
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2])
        #expect(pixels[0] == pixels[1] && pixels[1] == pixels[2])
        #expect(bodies[0] == bodies[1] && bodies[1] == bodies[2], "\(bodies)")
        session.qualityPin = 0
    }

    /// The tier log records the first frame and every tier change, each with its reason.
    @Test func theTierLogRecordsTheFirstFrameAndEveryChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 20)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        #expect(presenter.tierLog == [CelestialEclipseLabTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            CelestialEclipseLabTest.pin(session, shell, tier: tier)
            try CelestialEclipseLabTest.draw(session, frames: 2)
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
        try CelestialEclipseLabTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time, and choosing a body and showing a tick, leave the digest and the snapshot
    /// payload unchanged (renderer purity).
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 40)
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(41)
        let first: [CelestialEclipseLabAction] = Array(plan.prefix(1))
        #expect(CelestialEclipseLabTest.issue(shell, first) == first.count)
        let before: String = try CelestialEclipseLabTest.digest(shell)
        let payload: Data = try CelestialEclipseLabTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            CelestialEclipseLabTest.pin(session, shell, tier: tier)
            try CelestialEclipseLabTest.draw(session, frames: 3)
            for time in times {
                _ = try CelestialEclipseLabTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try CelestialEclipseLabTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try CelestialEclipseLabTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        // Choosing another body and showing another tick is presentation only.
        let core: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.core(shell)
        let mirror: CelestialEclipseLabMirror = shell.presenter.mirror
        _ = shell.presenter.describe(core)
        let body: Int = mirror.nextBody(1)
        let chosen: ActionResult = shell.handle(control: "orbit.choose", values: [Double(body)])
        #expect(chosen == .accepted, "\(chosen.code)")
        let shown: ActionResult = shell.handle(control: "clock.show", values: [3])
        #expect(shown == .accepted, "\(shown.code)")
        _ = try CelestialEclipseLabTest.still(session, width: 96, height: 64)
        let drawn: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(drawn.chosenBody == body && drawn.shownTick == 3, "the choice and the tick are drawn")
        #expect(try CelestialEclipseLabTest.digest(shell) == before, "choosing and showing leave the digest")
        #expect(try CelestialEclipseLabTest.core(shell).snapshotPayload() == payload,
                "choosing and showing leave the payload")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// The CPU checks of one state: the reference projects; sky and glow meshes shrink with the tier; no glow at
    /// level-2; the time moves nothing.
    private func checkPositions(_ core: CelestialEclipseLabExperienceCore, _ what: String) throws {
        let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 0)
        let reference: [SIMD2<Double>?] = CelestialEclipseLabTest.referencePixels(snapshot)
        var missing: Int = 0
        for p in reference where p == nil { missing += 1 }
        let expectedCount: Int = snapshot.bodies.count + snapshot.target.count + 2 + (snapshot.budget > 0 ? 1 : 0)
        #expect(reference.count == expectedCount, "\(what): bodies, strip, brackets, playhead, bar")
        #expect(missing == 0, "\(what): \(missing) reference points without a projection")
        var skySizes: [Int] = []
        var glowSizes: [Int] = []
        for tier in CelestialEclipseLabTier.all {
            let sky: Mesh = try CelestialEclipseLabSceneGeometry.skyMesh(snapshot, tier: tier)
            #expect(!sky.indices.isEmpty, "\(what) \(tier.name): the sky is drawn")
            skySizes.append(sky.positions.count)
            let glow: Mesh = try CelestialEclipseLabSceneGeometry.glowMesh(snapshot, tier: tier)
            glowSizes.append(glow.positions.count)
            if tier.glowShells == 0 {
                #expect(glow.indices.isEmpty, "\(what) \(tier.name): no glow")
            }
        }
        // Fewer sphere facets on cheaper tiers; fewer glow shells.
        #expect(skySizes[0] > skySizes[1] && skySizes[1] > skySizes[2], "\(what): \(skySizes)")
        #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(what): \(glowSizes)")
        // The camera and every vertex are the same for every time (the snapshot's time is presentation only).
        let later: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 7.5)
        #expect(CelestialEclipseLabTest.referencePixels(later) == reference, "\(what): time moves nothing")
        let best: CelestialEclipseLabTier = CelestialEclipseLabTier.all[0]
        let laterMesh: Mesh = try CelestialEclipseLabSceneGeometry.skyMesh(later, tier: best)
        let firstMesh: Mesh = try CelestialEclipseLabSceneGeometry.skyMesh(snapshot, tier: best)
        #expect(laterMesh.positions == firstMesh.positions, "\(what): the time moves no vertex")
        let laterGlow: Mesh = try CelestialEclipseLabSceneGeometry.glowMesh(later, tier: best)
        let firstGlow: Mesh = try CelestialEclipseLabSceneGeometry.glowMesh(snapshot, tier: best)
        #expect(laterGlow.positions == firstGlow.positions, "\(what): the time moves no glow vertex")
    }
}
#endif
