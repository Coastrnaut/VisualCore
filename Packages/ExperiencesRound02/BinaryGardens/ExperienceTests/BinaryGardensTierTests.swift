// BinaryGardensTierTests — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-002, 004, 007; clarification Q2). The
// three quality tiers change only the cube-sphere tessellation, the corona rays, the trails, the pollen motes and the
// glow shells, never positions: the camera depends on neither the snapshot, the tier nor the time; every reference
// point (the barycentre, every world centre, both star centres, the first gauge plate's left margin, the first actions
// bar; never a trail dot, a ray or a mote) projects to the same pixel at every tier; each star has the tier's corona
// rays, the trails the tier's ticks and each blooming world the tier's motes; richer tiers build more system and glow
// vertices (no glow at level-2); and the time moves no vertex. Through the one app's session host every tier's
// off-screen still passes the same reference at the same pixels; the presenter's tier log records the first frame and
// each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at every tier and
// several frame times, and showing a tick, leave the state digest and the snapshot payload unchanged (renderer
// purity), the shown tick draws the kernel's positions at that tick, and ticks 0 and 49 and a fractional tick are
// refused. Short runs.
#if os(iOS)
import BinaryGardensCore
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct BinaryGardensTierTests {
    /// The three tiers are level-0 … level-2 with cube-sphere quads, corona rays, trail ticks, motes and glow shells
    /// as clarification Q2 lists them.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var quads: [Int] = []
        var rays: [Int] = []
        var trails: [Int] = []
        var motes: [Int] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in BinaryGardensTier.all {
            names.append(tier.name)
            quads.append(tier.faceQuads)
            rays.append(tier.coronaRays)
            trails.append(tier.trailTicks)
            motes.append(tier.motes)
            shells.append(tier.glowShells)
            gains.append(BinaryGardensShaders.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(quads == [8, 5, 3])
        #expect(rays == [12, 6, 0])
        #expect(trails == [8, 4, 0])
        #expect(motes == [8, 4, 0])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(BinaryGardensExperienceCore.qualityTiers == 3)
        #expect(BinaryGardensTier.of(-1) == BinaryGardensTier.all[0])
        #expect(BinaryGardensTier.of(7) == BinaryGardensTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<BinaryGardensPresenter> = BinaryGardensExperience.make(id: BinaryGardensTest.id)
        #expect(shell.qualityProfile.count == BinaryGardensExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in BinaryGardensTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
        #expect(shell.presenter.qualityLevels.count == BinaryGardensExperienceCore.qualityTiers)
        var coreNames: [String] = []
        for level in BinaryGardensExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 and with their certified plan made (tick 24 shown), every reference
    /// point projects; the coronas, trails and motes follow the tier; the system and glow meshes shrink with the tier
    /// (no glow at level-2); the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(number)
            let states: [BinaryGardensExperienceCore] = [
                try BinaryGardensTest.coreAfter(number, []),
                try BinaryGardensTest.coreAfter(number, plan),
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
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(61)
        let shell = try await BinaryGardensTest.open(session, seed: 60, setUp: plan)
        var snapshots: [BinaryGardensSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var measured: [Bool] = []
        for tier in 0..<3 {
            BinaryGardensTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try BinaryGardensTest.still(session)
            let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            let report: BinaryGardensCheckReport = BinaryGardensTest.checkFrame(rgba, snapshot: snapshot, tier: tier,
                                                                                "level 61 tier \(tier)")
            measured.append(report.worldsChecked >= 1 && report.starsChecked >= 1 && report.marginChecked)
            pixels.append(BinaryGardensTest.referencePixels(snapshot))
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
        let shell = try await BinaryGardensTest.open(session, seed: 20)
        let presenter: BinaryGardensPresenter = shell.presenter
        #expect(presenter.tierLog == [BinaryGardensTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            BinaryGardensTest.pin(session, shell, tier: tier)
            try BinaryGardensTest.draw(session, frames: 2)
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
        try BinaryGardensTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time, and showing a tick, leave the digest and the snapshot payload unchanged
    /// (renderer purity); the shown tick draws the kernel's positions at that tick; ticks 0 and 49 and a fractional
    /// tick are refused and change nothing.
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(41)
        let shell = try await BinaryGardensTest.open(session, seed: 40, setUp: plan)
        let before: String = try BinaryGardensTest.digest(shell)
        let payload: Data = try BinaryGardensTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            BinaryGardensTest.pin(session, shell, tier: tier)
            try BinaryGardensTest.draw(session, frames: 3)
            for time in times {
                _ = try BinaryGardensTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try BinaryGardensTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try BinaryGardensTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        // Showing another tick is presentation only, and draws the kernel's positions at that tick.
        let tick: Int = 3
        let shown: ActionResult = shell.handle(control: "clock.show", values: [Double(tick)])
        #expect(shown == .accepted, "\(shown.code)")
        _ = try BinaryGardensTest.still(session, width: 96, height: 64)
        let drawn: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(drawn.shownTick == tick, "the tick is drawn")
        typealias G = BinaryGardensSceneGeometry
        for world in drawn.worlds.indices {
            let want: SIMD3<Double> = G.position(drawn.worlds[world].positions[tick - 1], scale: drawn.fitScale)
            #expect(G.worldCentre(world, drawn) == want, "world \(world) at tick \(tick)")
        }
        for star in 0..<2 {
            let want: SIMD3<Double> = G.position(drawn.starPositions[tick - 1][star], scale: drawn.fitScale)
            #expect(G.starCentre(star, drawn) == want, "star \(star) at tick \(tick)")
        }
        #expect(try BinaryGardensTest.digest(shell) == before, "showing leaves the digest")
        #expect(try BinaryGardensTest.core(shell).snapshotPayload() == payload, "showing leaves the payload")
        // Ticks outside 1 … 48 (inside the declared 0 … 60) and fractional ticks are refused and change nothing.
        let refusals: [(value: Double, code: String)] = [
            (0, "action.rule." + BinaryGardensExperienceRule.tick),
            (49, "action.rule." + BinaryGardensExperienceRule.tick),
            (2.5, "action.rule." + BinaryGardensExperienceRule.notWhole),
        ]
        for refusal in refusals {
            let refused: ActionResult = shell.handle(control: "clock.show", values: [refusal.value])
            #expect(refused.code == refusal.code, "clock.show [\(refusal.value)]: \(refused.code)")
            #expect(try BinaryGardensTest.core(shell).shownTick == tick)
            #expect(try BinaryGardensTest.digest(shell) == before)
        }
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// The CPU checks of one state: the reference projects and holds no trail dot, ray or mote; each star has the
    /// tier's rays, the trails the tier's ticks and each blooming world the tier's motes; the system and glow meshes
    /// shrink with the tier; no glow at level-2; the time moves nothing.
    private func checkPositions(_ core: BinaryGardensExperienceCore, _ what: String) throws {
        typealias G = BinaryGardensSceneGeometry
        let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.shownTick == BinaryGardensTest.checkTick, "\(what): tick 24")
        let reference: [SIMD2<Double>?] = BinaryGardensTest.referencePixels(snapshot)
        var missing: Int = 0
        for p in reference where p == nil { missing += 1 }
        #expect(reference.count == BinaryGardensTest.referenceCount(snapshot),
                "\(what): barycentre, worlds, stars, first gauge margin, first bar")
        #expect(missing == 0, "\(what): \(missing) reference points without a projection")
        var systemSizes: [Int] = []
        var glowSizes: [Int] = []
        for tier in BinaryGardensTier.all {
            let system: Mesh = try G.systemMesh(snapshot, tier: tier)
            #expect(!system.indices.isEmpty, "\(what) \(tier.name): the system is drawn")
            systemSizes.append(system.positions.count)
            let glow: Mesh = try G.glowMesh(snapshot, tier: tier)
            glowSizes.append(glow.positions.count)
            if tier.glowShells == 0 {
                #expect(glow.indices.isEmpty, "\(what) \(tier.name): no glow")
            }
            // The decoration that moves by time follows the tier; the reference points never include it.
            for star in 0..<2 {
                #expect(G.coronaRays(star, snapshot, tier: tier).count == tier.coronaRays,
                        "\(what) \(tier.name): star \(star) rays")
            }
            #expect(G.trailDots(snapshot, tier: tier).count == tier.trailTicks * (2 + snapshot.worlds.count),
                    "\(what) \(tier.name): trail dots")
            for world in snapshot.worlds.indices {
                let want: Int = G.blooms(world, snapshot, won: snapshot.isWon) ? tier.motes : 0
                #expect(G.motes(world, snapshot, tier: tier, won: snapshot.isWon).count == want,
                        "\(what) \(tier.name): world \(world) motes")
            }
            #expect(G.cubeSphere(faceQuads: tier.faceQuads).triangles.count == 12 * tier.faceQuads * tier.faceQuads,
                    "\(what) \(tier.name): cube-sphere triangles")
        }
        // Coarser cube-spheres and fewer rays, trails and motes on cheaper tiers; fewer glow shells.
        #expect(systemSizes[0] > systemSizes[1] && systemSizes[1] > systemSizes[2], "\(what): \(systemSizes)")
        #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(what): \(glowSizes)")
        // The paint order is the same for every tier and time (it takes no tier), and the time moves no vertex.
        let later: BinaryGardensSceneSnapshot = core.snapshot(time: 7.5)
        #expect(BinaryGardensTest.referencePixels(later) == reference, "\(what): time moves nothing")
        #expect(G.paintOrder(later) == G.paintOrder(snapshot), "\(what): time changes no element")
        let best: BinaryGardensTier = BinaryGardensTier.all[0]
        let laterMesh: Mesh = try G.systemMesh(later, tier: best)
        let firstMesh: Mesh = try G.systemMesh(snapshot, tier: best)
        #expect(laterMesh.positions == firstMesh.positions, "\(what): the time moves no vertex")
        let laterGlow: Mesh = try G.glowMesh(later, tier: best)
        let firstGlow: Mesh = try G.glowMesh(snapshot, tier: best)
        #expect(laterGlow.positions == firstGlow.positions, "\(what): the time moves no glow vertex")
    }
}
#endif
