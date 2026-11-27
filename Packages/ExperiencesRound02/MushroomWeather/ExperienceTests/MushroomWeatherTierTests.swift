// MushroomWeatherTierTests — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-002, 004, 007; clarification Q2).
// The three quality tiers change only the lathes (flat at level-2), the droplets, the fronds, the motes and the glow
// shells, never positions: the camera depends on neither the snapshot, the tier nor the time; every reference point
// (the floor centre, every cap centre, the moon centre, the first gauge track's centre, the first actions bar; never a
// droplet or a mote, which move by time) projects to the same pixel at every tier; each placed pod has the tier's
// droplets and the scene the tier's motes; richer tiers build more forest and glow vertices (no glow at level-2); and
// the time moves no vertex. Through the one app's session host every tier's off-screen still passes the same reference
// at the same pixels; the presenter's tier log records the first frame and each change with its reason; the
// presenter's quality levels are the Core's three tiers; drawing at every tier and several frame times, and showing a
// cycle, leave the state digest and the snapshot payload unchanged (renderer purity), and a cycle past the cycles run
// is refused. Short runs.
#if os(iOS)
import Foundation
import MushroomWeatherCore
import Testing
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct MushroomWeatherTierTests {
    /// The three tiers are level-0 … level-2 with lathe segments, droplets, fronds, motes and glow shells as
    /// clarification Q2 lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var segments: [Int] = []
        var droplets: [Int] = []
        var fronds: [Bool] = []
        var motes: [Int] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in MushroomWeatherTier.all {
            names.append(tier.name)
            segments.append(tier.latheSegments)
            droplets.append(tier.droplets)
            fronds.append(tier.fronds)
            motes.append(tier.motes)
            shells.append(tier.glowShells)
            gains.append(MushroomWeatherShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(segments == [16, 10, 0])
        #expect(droplets == [12, 6, 0])
        #expect(fronds == [true, true, false])
        #expect(motes == [8, 4, 0])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(MushroomWeatherTier.all[2].flatCaps && !MushroomWeatherTier.all[0].flatCaps)
        #expect(MushroomWeatherExperienceCore.qualityTiers == 3)
        #expect(MushroomWeatherTier.of(-1) == MushroomWeatherTier.all[0])
        #expect(MushroomWeatherTier.of(7) == MushroomWeatherTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<MushroomWeatherPresenter> =
            MushroomWeatherExperience.make(id: MushroomWeatherTest.id)
        #expect(shell.qualityProfile.count == MushroomWeatherExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in MushroomWeatherTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
        var coreNames: [String] = []
        for level in MushroomWeatherExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 and with their certified plan made (the cycle half the cycles run
    /// shown), every reference point projects; the droplets and motes follow the tier; the forest and glow meshes
    /// shrink with the tier (no glow at level-2); the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(number)
            let states: [MushroomWeatherExperienceCore] = [
                try MushroomWeatherTest.coreAfter(number, []),
                try MushroomWeatherTest.coreAfter(number, plan),
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
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(61)
        let shell = try await MushroomWeatherTest.open(session, seed: 60, setUp: plan)
        var snapshots: [MushroomWeatherSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var measured: [Bool] = []
        for tier in 0..<3 {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MushroomWeatherTest.still(session)
            let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            let report: MushroomWeatherCheckReport = MushroomWeatherTest.checkFrame(rgba, snapshot: snapshot,
                                                                                    tier: tier,
                                                                                    "level 61 tier \(tier)")
            measured.append(report.capsChecked >= 1 && report.trackChecked)
            pixels.append(MushroomWeatherTest.referencePixels(snapshot))
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
        let shell = try await MushroomWeatherTest.open(session, seed: 20)
        let presenter: MushroomWeatherPresenter = shell.presenter
        #expect(presenter.tierLog == [MushroomWeatherTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            try MushroomWeatherTest.draw(session, frames: 2)
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
        try MushroomWeatherTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time, and showing a cycle, leave the digest and the snapshot payload unchanged
    /// (renderer purity); a cycle past the cycles run is refused and changes nothing.
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(41)
        let shell = try await MushroomWeatherTest.open(session, seed: 40, setUp: plan)
        let before: String = try MushroomWeatherTest.digest(shell)
        let payload: Data = try MushroomWeatherTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            try MushroomWeatherTest.draw(session, frames: 3)
            for time in times {
                _ = try MushroomWeatherTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try MushroomWeatherTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try MushroomWeatherTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        // Showing another cycle is presentation only.
        let cycles: Int = try MushroomWeatherTest.core(shell).play.report.cycles
        let cycle: Int = Swift.min(3, cycles)
        let shown: ActionResult = shell.handle(control: "clock.show", values: [Double(cycle)])
        #expect(shown == .accepted, "\(shown.code)")
        _ = try MushroomWeatherTest.still(session, width: 96, height: 64)
        let drawn: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(drawn.shownCycle == cycle, "the cycle is drawn")
        #expect(drawn.shownField == drawn.fields[cycle], "the field of the shown cycle is drawn")
        let squares = MushroomWeatherSceneGeometry.mistSquares(drawn)
        for square in squares {
            let want: Double = MushroomWeatherSceneGeometry.mistShare(drawn.humidity(square.cell),
                                                                      moldBound: drawn.moldBound)
            #expect(square.share == want, "mist \(square.cell) at cycle \(cycle)")
        }
        #expect(try MushroomWeatherTest.digest(shell) == before, "showing leaves the digest")
        #expect(try MushroomWeatherTest.core(shell).snapshotPayload() == payload, "showing leaves the payload")
        // A cycle past the end of the run is refused and changes nothing, the shown cycle included.
        #expect(drawn.cyclesRun < MushroomWeatherExperienceCore.cycleRange.upperBound,
                "the cycles run \(drawn.cyclesRun) are declared")
        let refused: ActionResult = shell.handle(control: "clock.show", values: [Double(drawn.cyclesRun + 1)])
        #expect(refused.code == "action.rule." + MushroomWeatherExperienceRule.cycle, "\(refused.code)")
        #expect(try MushroomWeatherTest.core(shell).shownCycle == cycle)
        #expect(try MushroomWeatherTest.digest(shell) == before)
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// The CPU checks of one state: the reference projects and holds no droplet or mote; each placed pod has the
    /// tier's droplets and the scene the tier's motes; the forest and glow meshes shrink with the tier; no glow at
    /// level-2; the time moves nothing.
    private func checkPositions(_ core: MushroomWeatherExperienceCore, _ what: String) throws {
        typealias G = MushroomWeatherSceneGeometry
        let snapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.shownCycle == MushroomWeatherTest.halfCycle(snapshot.cyclesRun), "\(what): the half cycle")
        let reference: [SIMD2<Double>?] = MushroomWeatherTest.referencePixels(snapshot)
        var missing: Int = 0
        for p in reference where p == nil { missing += 1 }
        #expect(reference.count == MushroomWeatherTest.referenceCount(snapshot),
                "\(what): floor centre, caps, moon, first gauge track, first bar")
        #expect(missing == 0, "\(what): \(missing) reference points without a projection")
        var placed: Int = 0
        for pod in snapshot.pods where pod != nil { placed += 1 }
        var forestSizes: [Int] = []
        var glowSizes: [Int] = []
        for tier in MushroomWeatherTier.all {
            let forest: Mesh = try G.forestMesh(snapshot, tier: tier)
            #expect(!forest.indices.isEmpty, "\(what) \(tier.name): the forest is drawn")
            forestSizes.append(forest.positions.count)
            let glow: Mesh = try G.glowMesh(snapshot, tier: tier)
            glowSizes.append(glow.positions.count)
            if tier.glowShells == 0 {
                #expect(glow.indices.isEmpty, "\(what) \(tier.name): no glow")
            }
            // The decoration that moves by time follows the tier; the reference points never include it.
            var droplets: Int = 0
            for slot in snapshot.pods.indices { droplets += G.droplets(slot, snapshot, tier: tier).count }
            #expect(droplets == placed * tier.droplets, "\(what) \(tier.name): droplets \(droplets)")
            #expect(G.motes(tier: tier).count == tier.motes, "\(what) \(tier.name): motes")
        }
        // Fewer lathe segments, droplets, fronds and motes on cheaper tiers; fewer glow shells.
        #expect(forestSizes[0] > forestSizes[1] && forestSizes[1] > forestSizes[2], "\(what): \(forestSizes)")
        if !snapshot.colonies.isEmpty {
            #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(what): \(glowSizes)")
        }
        // The paint order is the same for every tier and time (it takes no tier), and the time moves no vertex.
        let later: MushroomWeatherSceneSnapshot = core.snapshot(time: 7.5)
        #expect(MushroomWeatherTest.referencePixels(later) == reference, "\(what): time moves nothing")
        #expect(G.paintOrder(later) == G.paintOrder(snapshot), "\(what): time changes no element")
        let best: MushroomWeatherTier = MushroomWeatherTier.all[0]
        let laterMesh: Mesh = try G.forestMesh(later, tier: best)
        let firstMesh: Mesh = try G.forestMesh(snapshot, tier: best)
        #expect(laterMesh.positions == firstMesh.positions, "\(what): the time moves no vertex")
        let laterGlow: Mesh = try G.glowMesh(later, tier: best)
        let firstGlow: Mesh = try G.glowMesh(snapshot, tier: best)
        #expect(laterGlow.positions == firstGlow.positions, "\(what): the time moves no glow vertex")
    }
}
#endif
