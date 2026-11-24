// VoxelOrigamiRenderTests — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-001 … 003, 006, 007;
// SC-R02G1503-001, 002; clarifications Q1, Q3, Q4). Through the one app's session host, drawn off screen at the
// frame-check size of `VoxelOrigamiTest` (1,152 × 768) at frame time 0: catalog levels 1, 21, 41, 61 and 100 (seeds
// 0, 20, 40, 60, 99) at their opening, at each quality tier level-0, level-1 and level-2, match the Core's CPU
// reference of the presenter's last snapshot: at every point at least 6 px from every element drawn after it in the
// painter's order that could hide it, a cube's centre is brighter than the night by 0.25 in luminance; the chosen
// hinge's centre (or another of its hot-pink stripes) has red above blue by 0.08; the first moves bar is 0.1 from the
// night (and lit at level-2 at the opening); the two probe corners are within 0.05 of the night; the reference pixels
// and the drawn snapshot are the same at every tier; each tier measures at least one cube centre summed over the five
// levels. On every level a hinge whose chosen bar is clear is chosen (`hinge.choose`, presentation only) and drawn hot
// pink at every tier. The presenter declares no frame probe before it drew a snapshot and two night corners after,
// which match the drawn still at every tier. A turn the kernel refuses (a collision or a sweep, found by a short search
// through the adapter on catalog levels) outlines the moving cube and the cube in its way in the broken colour
// #FF6B4A, the description and the mirror name it in words, and undo draws the frame before the turn again; playing
// level 1's certified plan wins and lights every cube (each lit, its glow band brighter than under the Reduce Flashing
// cap). Each test well under 10 s.
#if os(iOS)
import Foundation
import Testing
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VoxelOrigamiCore

@MainActor
@Suite(.serialized) struct VoxelOrigamiRenderTests {
    /// The catalog levels searched for a failing turn, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 100, 11, 31, 51, 71, 91]

    /// Every tier of the five levels' openings matches the CPU reference at the same reference pixels; each tier
    /// measures at least one cube centre summed over the levels.
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var cubes: [Int] = [0, 0, 0]
        var hinges: [Int] = [0, 0, 0]
        for seed in VoxelOrigamiTest.seeds {
            let counts = try await checkLevel(seed: seed)
            for tier in 0..<3 {
                cubes[tier] += counts.cubes[tier]
                hinges[tier] += counts.hinges[tier]
            }
        }
        print("voxel-origami five levels: cubes per tier \(cubes), opening hinges per tier \(hinges)")
        for tier in 0..<3 {
            #expect(cubes[tier] > 0, "tier \(tier): no cube centre measured on the five levels")
        }
    }

    /// On each of the five levels a hinge whose bar has a clear hot-pink point is chosen through the shell (the opening
    /// choice when it is clear) and drawn with red above blue at every tier; at least one level measures one.
    @Test func theChosenHingeIsHotPinkAtEveryTier() async throws {
        var measured: Int = 0
        for seed in VoxelOrigamiTest.seeds {
            let number: Int = VoxelOrigamiExperienceCore.levelNumber(forSeed: seed)
            let opening: VoxelOrigamiExperienceCore = try VoxelOrigamiExperienceCore.opening(number: number)
            guard let hinge = VoxelOrigamiTest.measurableHinge(opening) else {
                print("voxel-origami level \(number): no hinge bar clear of the later elements")
                continue
            }
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await VoxelOrigamiTest.open(session, seed: seed)
            let digest: String = try VoxelOrigamiTest.digest(shell)
            if hinge != opening.chosenHinge {
                #expect(shell.handle(control: "hinge.choose", values: [Double(hinge)]) == .accepted)
            }
            #expect(try VoxelOrigamiTest.core(shell).chosenHinge == hinge)
            #expect(try VoxelOrigamiTest.digest(shell) == digest, "choosing a hinge leaves the digest")
            for tier in 0..<3 {
                VoxelOrigamiTest.pin(session, shell, tier: tier)
                let rgba: [UInt8] = try VoxelOrigamiTest.still(session)
                let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                #expect(snapshot.chosenHinge == hinge)
                let report: VoxelOrigamiCheckReport = VoxelOrigamiTest.checkFrame(
                    rgba, snapshot: snapshot, require: false, "level \(number) hinge \(hinge) tier \(tier)")
                #expect(report.hingeChecked, "level \(number) tier \(tier): hinge \(hinge) measured")
                if report.hingeChecked && tier == 0 { measured += 1 }
            }
            session.qualityPin = 0
        }
        #expect(measured > 0, "no level with a measurable chosen hinge")
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two night corners match the drawn still at
    /// every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<VoxelOrigamiPresenter> = VoxelOrigamiExperience.make(id: VoxelOrigamiTest.id)
        let opening: VoxelOrigamiExperienceCore = try VoxelOrigamiExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: 40)
        for tier in 0..<3 {
            VoxelOrigamiTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try VoxelOrigamiTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = VoxelOrigamiTest.bottomUp(still, width: VoxelOrigamiTest.width,
                                                          height: VoxelOrigamiTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try VoxelOrigamiTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two night corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: VoxelOrigamiTest.width,
                                              height: VoxelOrigamiTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A turn the lattice check refuses outlines the moving cube and the cube in its way; the words name them; undo
    /// draws the frame before the turn again.
    @Test func aFailedTurnOutlinesTheMovingAndTheStillCube() async throws {
        let found = try #require(try VoxelOrigamiTest.failureCase(candidates: Self.failureLevels, maxDepth: 2),
                                 "a catalog level with a collision or sweep within two turns")
        print("voxel-origami failure: level \(found.number), set-up \(found.setUp), failing \(found.failing)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: UInt64(found.number - 1))
        // Level-2: nothing glows, so the outline is the only red that rises.
        VoxelOrigamiTest.pin(session, shell, tier: 2)
        #expect(VoxelOrigamiTest.issue(shell, found.setUp) == found.setUp.count)
        let digest: String = try VoxelOrigamiTest.digest(shell)
        _ = try VoxelOrigamiTest.still(session)
        let clean: [UInt8] = try VoxelOrigamiTest.still(session)
        let before: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let failing = VoxelOrigamiTest.control(found.failing)
        #expect(shell.handle(control: failing.control, values: failing.values) == .accepted)
        let core: VoxelOrigamiExperienceCore = try VoxelOrigamiTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: VoxelOrigamiFailure = try #require(core.play.failure)
        #expect(VoxelOrigamiTest.isTurnFailure(failure), "\(failure)")
        #expect(core.outcome?.code == VoxelOrigamiExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(VoxelOrigamiMirror.failureText(failure))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, the pose did not move, and the outlines are there.
        let rgba: [UInt8] = try VoxelOrigamiTest.still(session)
        let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.cells == before.cells && snapshot.turns == before.turns, "a refused turn moves nothing")
        let reference: VoxelOrigamiExperienceCore = try VoxelOrigamiTest.coreAfter(found.number,
                                                                                   found.setUp + [found.failing])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        let broken = try #require(snapshot.brokenTurn)
        #expect(broken.moving != broken.still)
        VoxelOrigamiTest.checkFrame(rgba, snapshot: snapshot, require: false, "failed turn")
        let movingHits: Int = VoxelOrigamiTest.outlineHits(rgba, clean, found.moving)
        let stillHits: Int = VoxelOrigamiTest.outlineHits(rgba, clean, found.still)
        print("voxel-origami outlines: moving \(movingHits) of \(found.moving.count), still \(stillHits) of "
              + "\(found.still.count)")
        #expect(movingHits * 2 > found.moving.count,
                "the moving cube \(broken.moving) is outlined in #FF6B4A (\(movingHits) of \(found.moving.count))")
        #expect(stillHits * 2 > found.still.count,
                "the cube in its way \(broken.still) is outlined in #FF6B4A (\(stillHits) of \(found.still.count))")
        // Undo returns the failed play to the moment before the turn, without the outlines.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try VoxelOrigamiTest.digest(shell) == digest)
        let undone: [UInt8] = try VoxelOrigamiTest.still(session)
        #expect(VoxelOrigamiTest.outlineHits(undone, clean, found.moving + found.still) == 0, "undo removes them")
        #expect(undone == clean, "undo draws the frame before the turn")
        session.qualityPin = 0
    }

    /// Playing the certified plan of level 1 through the shell wins; every cube is lit (on a target cell, the won
    /// flag set, nothing moved by the win), and at level-0 every cube's glow band is brighter than the same frame under
    /// the Reduce Flashing cap (the glow is the only difference); the won frames pass the checks.
    @Test func aWonLevelLightsEveryCube() async throws {
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        #expect(!turns.isEmpty, "level 1 has a certified plan")
        var stills: [[UInt8]] = []
        var snapshots: [VoxelOrigamiSceneSnapshot] = []
        for reduceFlashing in [false, true] {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await VoxelOrigamiTest.open(session, seed: 0, reduceFlashing: reduceFlashing)
            VoxelOrigamiTest.pin(session, shell, tier: 0)
            #expect(VoxelOrigamiTest.issue(shell, Array(turns.dropLast())) == turns.count - 1)
            _ = try VoxelOrigamiTest.still(session)
            let arranged: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(VoxelOrigamiSceneGeometry.wonFlag(arranged) == 0)
            #expect(VoxelOrigamiTest.issue(shell, Array(turns.suffix(1))) == 1)
            let core: VoxelOrigamiExperienceCore = try VoxelOrigamiTest.core(shell)
            #expect(core.play.stage == .won, "\(core.play.stage)")
            #expect(core.outcome?.code == VoxelOrigamiExperienceCore.wonCode)
            _ = shell.presenter.describe(core)
            #expect(shell.presenter.mirror.status == "Won")
            #expect(shell.presenter.mirror.failureText == nil)
            let won: [UInt8] = try VoxelOrigamiTest.still(session)
            let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.stage == .won)
            #expect(VoxelOrigamiSceneGeometry.wonFlag(snapshot) == 1)
            #expect(snapshot.cells == core.play.pose.cells, "the drawn cubes are the kernel's cells")
            for index in snapshot.cells.indices {
                #expect(VoxelOrigamiSceneGeometry.isLit(index, snapshot), "cube \(index) is lit")
                #expect(snapshot.isOnTarget(index), "cube \(index) lies on a target cell")
            }
            VoxelOrigamiTest.checkFrame(won, snapshot: snapshot, require: false,
                                        "level 1 won, level-0, Reduce Flashing \(reduceFlashing)")
            stills.append(won)
            snapshots.append(snapshot)
            session.qualityPin = 0
        }
        try #require(stills.count == 2 && snapshots.count == 2)
        #expect(snapshots[0] == snapshots[1], "the same won snapshot")
        #expect(stills[0] != stills[1], "the capped glow draws a dimmer won frame")
        // Every cube's inner glow band is brighter at the full glow than under the cap somewhere.
        let snapshot: VoxelOrigamiSceneSnapshot = snapshots[0]
        var glowing: Int = 0
        for index in snapshot.cells.indices {
            let samples: [SIMD2<Double>] = VoxelOrigamiTest.glowBandSamples(index, snapshot)
            var brighter: Int = 0
            for p in samples {
                let full: Double = VoxelOrigamiTest.luminance(VoxelOrigamiTest.centre(stills[0], p))
                let capped: Double = VoxelOrigamiTest.luminance(VoxelOrigamiTest.centre(stills[1], p))
                if full >= capped + 0.03 { brighter += 1 }
            }
            #expect(brighter > 0, "cube \(index): no glow band point brighter than under the cap (\(samples.count))")
            if brighter > 0 { glowing += 1 }
        }
        print("voxel-origami won level 1: \(glowing) of \(snapshot.cells.count) cubes glow")
    }

    // MARK: Helpers

    /// Draws the opening of the level `seed` prepares at the three tiers and checks it against the CPU reference;
    /// returns the cube centres measured and whether the opening's chosen hinge was measured, per tier.
    private func checkLevel(seed: UInt64) async throws -> (cubes: [Int], hinges: [Int]) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await VoxelOrigamiTest.open(session, seed: seed)
        let level: Int = VoxelOrigamiExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try VoxelOrigamiTest.core(shell).levelNumber == level)
        let expectedCore: VoxelOrigamiExperienceCore = try VoxelOrigamiExperienceCore.opening(number: level)
        let expected: VoxelOrigamiSceneSnapshot = expectedCore.snapshot(time: 0)
        let litLuminance: Double = VoxelOrigamiTest.luminance(VoxelOrigamiPalette.movesLit)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [VoxelOrigamiSceneSnapshot] = []
        var cubes: [Int] = []
        var hinges: [Int] = []
        for tier in 0..<3 {
            VoxelOrigamiTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try VoxelOrigamiTest.still(session)
            let snapshot: VoxelOrigamiSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget, "\(what): nothing spent at the opening")
            #expect(snapshot.failure == nil)
            #expect(snapshot.chosenHinge == VoxelOrigamiExperienceCore.openingHinge(of: expectedCore.play),
                    "\(what): the first turnable hinge is chosen")
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.cells == expectedCore.play.pose.cells, "\(what): the drawn cubes are the kernel's cells")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            let report: VoxelOrigamiCheckReport = VoxelOrigamiTest.checkFrame(rgba, snapshot: snapshot,
                                                                              require: false, what)
            cubes.append(report.cubeChecked)
            hinges.append(report.hingeChecked ? 1 : 0)
            references.append(VoxelOrigamiTest.referencePixels(snapshot))
            snapshots.append(snapshot)
            // At level-2 (no glow) a measured first moves bar is lit at the opening (its lit colour at its centre).
            if tier == 2, report.movesChecked {
                let p: SIMD2<Double> = try #require(VoxelOrigamiTest.movesPixel(snapshot))
                let c: SIMD3<Double> = VoxelOrigamiTest.centre(rgba, p)
                let lum: Double = VoxelOrigamiTest.luminance(c)
                #expect(Swift.abs(lum - litLuminance) <= 0.05, "\(what): moves bar 0 is \(c)")
            }
        }
        // The tier changes no coordinate and nothing measured.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2], "level \(level): tier snapshots")
        #expect(cubes[0] == cubes[1] && cubes[1] == cubes[2], "level \(level): cubes measured \(cubes)")
        #expect(hinges[0] == hinges[1] && hinges[1] == hinges[2], "level \(level): hinge measured \(hinges)")
        session.qualityPin = 0
        return (cubes, hinges)
    }
}
#endif
