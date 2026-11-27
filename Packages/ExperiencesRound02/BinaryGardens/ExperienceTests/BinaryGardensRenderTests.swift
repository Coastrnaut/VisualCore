// BinaryGardensRenderTests — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-001 … 004, 006, 007, 010;
// SC-R02G2103-001, 002; clarifications Q1–Q4). Through the one app's session host, drawn off screen at the frame-check
// size of `BinaryGardensTest` (1,152 × 768) at frame time 0 and shown tick 24 (`clock.show [24]` sent to the core
// before drawing): catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80) with their certified plan made (so
// the predicted run is the winning one), at each quality tier level-0, level-1 and level-2, match the Core's CPU
// reference (`BinaryGardensSceneGeometry.referencePoints` and `project`) of the presenter's last snapshot: at every
// point at least 6 px from every element drawn after it in the painter's order, each world's centre is brighter than
// the backdrop there by 0.15 in luminance (at least one world per frame), each star's centre by 0.4 (at least one star
// per frame), the first actions bar (lit) has red above blue by 0.08, the first gauge plate's left margin is 0.05 from
// the backdrop, and the median of each 9 × 9 lower-corner patch is within 0.06 of the gradient at its height; the
// reference pixels and the drawn snapshot are the same at every tier (coronas and motes move by time and are never
// reference points). The openings (the starting arrangement) pass the same checks. The presenter declares no frame
// probe before it drew a snapshot and two dark corners after, which match the drawn still at every tier. A run that
// fails (found by a short search through the adapter, e.g. an immediate `light.run` on a level's opening) draws its
// failing element broken (`BinaryGardensPalette.broken`: the frozen or scorched world's ring and gauge cell, the
// unstable world's window bracket or required tick, or the wilted or bleached world's bloom marker) where it was not
// broken before the run, moves nothing, is named in words, and undo draws the frame before it again; level 1 won by
// its certified plan and `light.run` makes every world bloom (motes and a raised glow shell around every world at
// level-0) without moving any position and passes the same checks. Each test well under 10 s.
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
@Suite(.serialized) struct BinaryGardensRenderTests {
    /// The catalog levels searched for a failing run, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels with their certified plan made, at tick 24, matches the CPU reference at the same
    /// reference pixels; every frame measures a world, a star, the first gauge plate's margin and the first actions bar
    /// (when lit).
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in BinaryGardensTest.seeds {
            let counts: [Int] = try await checkLevel(seed: seed, arranged: true)
            for tier in 0..<3 { measured[tier] += counts[tier] }
        }
        print("binary-gardens five levels: frames fully measured per tier \(measured)")
        for tier in 0..<3 {
            #expect(measured[tier] == BinaryGardensTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
        }
    }

    /// The five openings (the starting arrangement; the predicted run fails) pass the same checks at every tier.
    @Test func theOpeningsMatchTheReference() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in BinaryGardensTest.seeds {
            let counts: [Int] = try await checkLevel(seed: seed, arranged: false)
            for tier in 0..<3 { measured[tier] += counts[tier] }
        }
        print("binary-gardens five openings: frames fully measured per tier \(measured)")
        for tier in 0..<3 {
            #expect(measured[tier] == BinaryGardensTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
        }
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two dark corners match the drawn still at every
    /// tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<BinaryGardensPresenter> = BinaryGardensExperience.make(id: BinaryGardensTest.id)
        let opening: BinaryGardensExperienceCore = try BinaryGardensExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(41)
        let shell = try await BinaryGardensTest.open(session, seed: 40, setUp: plan)
        for tier in 0..<3 {
            BinaryGardensTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try BinaryGardensTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = BinaryGardensTest.bottomUp(still, width: BinaryGardensTest.width,
                                                           height: BinaryGardensTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try BinaryGardensTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two dark corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: BinaryGardensTest.width,
                                              height: BinaryGardensTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A run that fails draws its failing element in the broken colour where it was not broken before the run;
    /// nothing moves; the words name the failure; undo draws the frame before the run again.
    @Test func aFailedRunMarksTheFailingElementBroken() async throws {
        let found: BinaryGardensFailureCase = try #require(
            try BinaryGardensTest.failureCase(candidates: Self.failureLevels),
            "a catalog level with a failing run whose broken element is clear")
        print("binary-gardens failure: level \(found.number), set-up \(found.setUp), \(found.code), points "
              + "\(found.points.count)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BinaryGardensTest.open(session, seed: UInt64(found.number - 1), setUp: found.setUp)
        // Level-2: nothing glows and no corona or mote moves, so the broken element is exactly its material colour.
        BinaryGardensTest.pin(session, shell, tier: 2)
        let digest: String = try BinaryGardensTest.digest(shell)
        let before: [UInt8] = try BinaryGardensTest.still(session)
        let beforeSnapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(beforeSnapshot.stage == .playing, "no mark for the predicted failure while playing")
        #expect(shell.handle(control: "light.run") == .accepted)
        let failedDigest: String = try BinaryGardensTest.digest(shell)
        let core: BinaryGardensExperienceCore = try BinaryGardensTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: BinaryGardensFailure = try #require(core.play.failure)
        #expect(failure.code == found.code)
        #expect(core.outcome?.code == BinaryGardensExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(BinaryGardensMirror.failureText(failure, level: core.play.level))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, nothing moved, the broken element is red.
        let rgba: [UInt8] = try BinaryGardensTest.still(session)
        let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.stage == .failed)
        #expect(snapshot.arrangement == beforeSnapshot.arrangement, "a run moves no star and tilts nothing")
        #expect(snapshot.actionsLeft == beforeSnapshot.actionsLeft, "the run spends nothing")
        #expect(snapshot.shownTick == beforeSnapshot.shownTick, "the run keeps the shown tick")
        #expect(snapshot.shownTick == BinaryGardensTest.checkTick)
        #expect(BinaryGardensTest.referencePixels(snapshot) == BinaryGardensTest.referencePixels(beforeSnapshot))
        let reference: BinaryGardensExperienceCore = try BinaryGardensTest.coreAfter(found.number,
                                                                                     found.setUp + [.run])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        BinaryGardensTest.checkFrame(rgba, snapshot: snapshot, tier: 2, "failed run")
        let points: [SIMD2<Double>] = BinaryGardensTest.brokenPoints(snapshot)
        #expect(points == found.points, "the broken element's points are the search's")
        #expect(!points.isEmpty, "the broken element is clear")
        var marked: Int = 0
        var unmarkedBefore: Int = 0
        for point in points {
            let red: Bool = BinaryGardensTest.anyPixel(rgba, near: point, radius: BinaryGardensTest.markRadius,
                                                       width: BinaryGardensTest.width,
                                                       height: BinaryGardensTest.height,
                                                       where: BinaryGardensTest.isBroken)
            if red {
                marked += 1
            } else {
                let seen: SIMD3<Double> = BinaryGardensTest.centre(rgba, point)
                Issue.record("\(found.code): the broken element at (\(point.x), \(point.y)) is \(seen), not broken")
            }
            let redBefore: Bool = BinaryGardensTest.anyPixel(before, near: point,
                                                             radius: BinaryGardensTest.markRadius,
                                                             width: BinaryGardensTest.width,
                                                             height: BinaryGardensTest.height,
                                                             where: BinaryGardensTest.isBroken)
            if !redBefore { unmarkedBefore += 1 }
        }
        print("binary-gardens failure \(found.code): broken points marked \(marked) of \(points.count), unmarked "
              + "before the run \(unmarkedBefore)")
        #expect(unmarkedBefore == points.count, "the mark appears only with the failed run")
        // Undo returns the failed run to the moment before the run (the shown tick is presentation only).
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try BinaryGardensTest.digest(shell) == digest)
        #expect(failedDigest != digest, "the failed run has its own digest")
        let undone: [UInt8] = try BinaryGardensTest.still(session)
        #expect(undone == before, "undo draws the frame before the run")
        session.qualityPin = 0
    }

    /// Making level 1's certified plan and running the light through the shell wins; every world blooms (on the CPU:
    /// every world counts as blooming, has the tier's motes at level-0 and its glow shell raised; on the GPU: at
    /// level-0 the frame changes around a world that was not comfortable at the shown tick), nothing moves (the same
    /// arrangement, shown tick and reference pixels at level-2 and level-0), and the won frames pass the checks.
    @Test func aWonLevelBloomsEveryWorld() async throws {
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(1)
        #expect(!plan.isEmpty, "level 1 has a certified plan")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BinaryGardensTest.open(session, seed: 0, setUp: plan)
        var arrangedFrames: [Int: [UInt8]] = [:]
        for tier in [2, 0] {
            BinaryGardensTest.pin(session, shell, tier: tier)
            arrangedFrames[tier] = try BinaryGardensTest.still(session)
        }
        let arranged: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(!arranged.isWon, "not won before the run")
        #expect(arranged.failure == nil, "the certified plan's run is predicted to win")
        #expect(shell.handle(control: "light.run") == .accepted)
        let core: BinaryGardensExperienceCore = try BinaryGardensTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == BinaryGardensExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        let reference: BinaryGardensSceneSnapshot = try BinaryGardensTest.coreAfter(1, plan + [.run])
            .snapshot(time: 0)
        var pixels: [[SIMD2<Double>?]] = []
        for tier in [2, 0] {
            BinaryGardensTest.pin(session, shell, tier: tier)
            let won: [UInt8] = try BinaryGardensTest.still(session)
            let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level 1 won, tier \(tier)"
            #expect(snapshot.stage == .won && snapshot.isWon, "\(what)")
            #expect(snapshot == reference, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.arrangement == arranged.arrangement, "\(what): the run moves no star")
            #expect(snapshot.shownTick == arranged.shownTick, "\(what): the run keeps the shown tick")
            #expect(snapshot.failure == nil, "\(what): no failure")
            BinaryGardensTest.checkFrame(won, snapshot: snapshot, tier: tier, what)
            checkBloom(snapshot, tier: BinaryGardensTier.of(tier), what)
            if tier == 0, let before = arrangedFrames[0] {
                checkBloomFrame(won, before: before, snapshot, what)
            }
            pixels.append(BinaryGardensTest.referencePixels(snapshot))
        }
        #expect(pixels.count == 2 && pixels[0] == pixels[1], "the tier moves no reference point of the won frame")
        #expect(pixels.first == BinaryGardensTest.referencePixels(arranged), "the win moves no reference point")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// CPU: on the won `snapshot` every world blooms, has `tier.motes` motes and its glow shells at full factor; the
    /// system and glow meshes keep the positions of the same snapshot drawn as not won.
    private func checkBloom(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier, _ what: String) {
        typealias G = BinaryGardensSceneGeometry
        for world in snapshot.worlds.indices {
            #expect(G.blooms(world, snapshot, won: true), "\(what): world \(world) blooms")
            let motes: Int = G.motes(world, snapshot, tier: tier, won: true).count
            #expect(motes == tier.motes, "\(what): world \(world) has \(motes) motes, not \(tier.motes)")
        }
        do {
            let won: BinaryGardensColouredMesh = try G.systemPart(snapshot, tier: tier, wonLevel: true)
            let plain: BinaryGardensColouredMesh = try G.systemPart(snapshot, tier: tier, wonLevel: false)
            #expect(won.mesh.positions.count >= plain.mesh.positions.count, "\(what): the won look adds motes only")
            let wonGlow: BinaryGardensColouredMesh = try G.glowPart(snapshot, tier: tier, wonLevel: true)
            let plainGlow: BinaryGardensColouredMesh = try G.glowPart(snapshot, tier: tier, wonLevel: false)
            #expect(wonGlow.mesh.positions == plainGlow.mesh.positions, "\(what): the won glow moves no vertex")
        } catch {
            Issue.record("\(what): \(error)")
        }
    }

    /// GPU, level-0: for every world that was not comfortable at the shown tick before the run (so it did not bloom
    /// then), the won frame differs from the frame before the run within its raised glow shell (its motes and the
    /// shell at full factor). Every world is reported; a level whose worlds were all comfortable already shows them
    /// blooming before the run, and is reported as such.
    private func checkBloomFrame(_ won: [UInt8], before: [UInt8], _ snapshot: BinaryGardensSceneSnapshot,
                                 _ what: String) {
        typealias T = BinaryGardensTest
        typealias G = BinaryGardensSceneGeometry
        var turned: Int = 0
        var candidates: Int = 0
        for world in snapshot.worlds.indices where snapshot.band(world) != .comfortable {
            candidates += 1
            guard let p = T.pixel(G.worldCentre(world, snapshot)) else { continue }
            let changed: Int = T.differingPixels(won, before, near: p, radius: 24)
            if changed > 0 {
                turned += 1
            } else {
                let band: BinaryGardensBand = snapshot.band(world)
                Issue.record("\(what): world \(world) (\(band)) looks the same before and after the win")
            }
        }
        print("binary-gardens \(what): worlds \(snapshot.worlds.count), not comfortable at tick "
              + "\(snapshot.shownTick) before the run \(candidates), turned blooming \(turned)")
        #expect(turned == candidates, "\(what): \(turned) of \(candidates) worlds turned blooming")
    }

    /// Draws level `seed % 100 + 1` (with its certified plan when `arranged`) at tick 24 at the three tiers and checks
    /// it against the CPU reference; returns, per tier, 1 when a world, a star, the first gauge plate's margin and the
    /// first actions bar (when lit) were all measured.
    private func checkLevel(seed: UInt64, arranged: Bool) async throws -> [Int] {
        let level: Int = BinaryGardensExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        let plan: [BinaryGardensAction] = arranged ? try BinaryGardensTest.certifiedPlan(level) : []
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BinaryGardensTest.open(session, seed: seed, setUp: plan)
        #expect(try BinaryGardensTest.core(shell).levelNumber == level)
        let expectedCore: BinaryGardensExperienceCore = try BinaryGardensTest.coreAfter(level, plan)
        let expected: BinaryGardensSceneSnapshot = expectedCore.snapshot(time: 0)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [BinaryGardensSceneSnapshot] = []
        var measured: [Int] = []
        for tier in 0..<3 {
            BinaryGardensTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try BinaryGardensTest.still(session)
            let snapshot: BinaryGardensSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level)\(arranged ? " arranged" : " opening") tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownTick == BinaryGardensTest.checkTick, "\(what): tick \(snapshot.shownTick)")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget - plan.count, "\(what): actions spent")
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            if arranged {
                #expect(snapshot.failure == nil, "\(what): the certified plan's run wins")
            } else {
                #expect(snapshot.failure != nil, "\(what): a level never starts won")
            }
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            let report: BinaryGardensCheckReport = BinaryGardensTest.checkFrame(rgba, snapshot: snapshot, tier: tier,
                                                                                what)
            let barDone: Bool = report.barChecked || BinaryGardensSceneGeometry.litActions(snapshot) == 0
            let all: Bool = report.worldsChecked >= 1 && report.starsChecked >= 1 && report.marginChecked && barDone
            measured.append(all ? 1 : 0)
            references.append(BinaryGardensTest.referencePixels(snapshot))
            snapshots.append(snapshot)
        }
        // The tier changes no coordinate and nothing measured.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2], "level \(level): tier snapshots")
        session.qualityPin = 0
        return measured
    }
}
#endif
