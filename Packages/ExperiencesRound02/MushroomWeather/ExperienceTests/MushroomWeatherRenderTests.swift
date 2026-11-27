// MushroomWeatherRenderTests — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-001 … 004, 006, 007;
// SC-R02G2003-001, 002; clarifications Q1–Q4). Through the one app's session host, drawn off screen at the frame-check
// size of `MushroomWeatherTest` (1,152 × 768) at frame time 0 and the shown cycle half the cycles run
// (`clock.show [cycles / 2]` sent to the core before drawing): catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40,
// 60, 80) with their certified plan made (so the predicted run is the winning one), at each quality tier level-0,
// level-1 and level-2, match the Core's CPU reference (`MushroomWeatherSceneGeometry.referencePoints` and `project`)
// of the presenter's last snapshot: at every point at least 6 px from every element drawn after it in the painter's
// order, each cap's centre is brighter than moss by 0.2 in luminance (at least one cap per frame), the moon is 0.1
// from the backdrop, the first actions bar (lit) has red above blue by 0.08, the first gauge track's centre is 0.1
// from the backdrop, and the median of each 9 × 9 lower-corner patch is within 0.06 of the gradient at its height;
// the reference pixels and the drawn snapshot are the same at every tier (droplets and motes move by time and are
// never reference points). The openings (no pods) pass the same checks. The presenter declares no frame probe before
// it drew a snapshot and two dark corners after, which match the drawn still at every tier. A run that fails (found
// by a short search through the adapter, e.g. an immediate `weather.run` on a level's opening) draws its failing
// element broken (`MushroomWeatherPalette.broken`: the dried colony's cap, the mold patch, or the unstable colony's
// marker and run bar) where it was not broken before the run, moves nothing, is named in words, and undo draws the
// frame before it again; level 1 won by its certified plan and `weather.run` lights every cap (each clear cap centre
// is the cap colour at level-2, out-of-band caps included), keeps every pod and passes the same checks. Each test well
// under 10 s.
#if os(iOS)
import Foundation
import MushroomWeatherCore
import Testing
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MushroomWeatherRenderTests {
    /// The catalog levels searched for a failing run, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels with their certified plan made, at the cycle half the cycles run, matches the
    /// CPU reference at the same reference pixels; every frame measures a cap, the first gauge track and the first
    /// actions bar (when lit); the moon is measured on some level at every tier.
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var measured: [Int] = [0, 0, 0]
        var moons: [Int] = [0, 0, 0]
        for seed in MushroomWeatherTest.seeds {
            let counts = try await checkLevel(seed: seed, placed: true)
            for tier in 0..<3 {
                measured[tier] += counts.measured[tier]
                moons[tier] += counts.moons[tier]
            }
        }
        print("mushroom-weather five levels: frames fully measured per tier \(measured), moon measured \(moons)")
        for tier in 0..<3 {
            #expect(measured[tier] == MushroomWeatherTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
            #expect(moons[tier] >= 1, "tier \(tier): the moon was never clear")
        }
    }

    /// The five openings (no pods; the predicted run may fail) pass the same checks at every tier.
    @Test func theOpeningsMatchTheReference() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in MushroomWeatherTest.seeds {
            let counts = try await checkLevel(seed: seed, placed: false)
            for tier in 0..<3 { measured[tier] += counts.measured[tier] }
        }
        print("mushroom-weather five openings: frames fully measured per tier \(measured)")
        for tier in 0..<3 {
            #expect(measured[tier] == MushroomWeatherTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
        }
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two dark corners match the drawn still at every
    /// tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<MushroomWeatherPresenter> =
            MushroomWeatherExperience.make(id: MushroomWeatherTest.id)
        let opening: MushroomWeatherExperienceCore = try MushroomWeatherExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(41)
        let shell = try await MushroomWeatherTest.open(session, seed: 40, setUp: plan)
        for tier in 0..<3 {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try MushroomWeatherTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = MushroomWeatherTest.bottomUp(still, width: MushroomWeatherTest.width,
                                                             height: MushroomWeatherTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try MushroomWeatherTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two dark corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: MushroomWeatherTest.width,
                                              height: MushroomWeatherTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A run that fails draws its failing element in the broken colour where it was not broken before the run;
    /// nothing moves; the words name the failure; undo draws the frame before the run again.
    @Test func aFailedRunMarksTheFailingElementBroken() async throws {
        let found: MushroomWeatherFailureCase = try #require(
            try MushroomWeatherTest.failureCase(candidates: Self.failureLevels),
            "a catalog level with a failing run whose broken element is clear")
        print("mushroom-weather failure: level \(found.number), set-up \(found.setUp), \(found.code), points "
              + "\(found.points.count)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MushroomWeatherTest.open(session, seed: UInt64(found.number - 1), setUp: found.setUp)
        // Level-2: nothing glows and the caps are flat, so the broken element is exactly its material colour.
        MushroomWeatherTest.pin(session, shell, tier: 2)
        let digest: String = try MushroomWeatherTest.digest(shell)
        let before: [UInt8] = try MushroomWeatherTest.still(session)
        let beforeSnapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(beforeSnapshot.stage == .playing, "no mark for the predicted failure while playing")
        #expect(shell.handle(control: "weather.run") == .accepted)
        let failedDigest: String = try MushroomWeatherTest.digest(shell)
        let core: MushroomWeatherExperienceCore = try MushroomWeatherTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: MushroomWeatherFailure = try #require(core.play.failure)
        #expect(failure.code == found.code)
        #expect(core.outcome?.code == MushroomWeatherExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(MushroomWeatherMirror.failureText(failure, level: core.play.level))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, nothing moved, the broken element is red.
        let rgba: [UInt8] = try MushroomWeatherTest.still(session)
        let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.stage == .failed)
        #expect(snapshot.pods == beforeSnapshot.pods, "a run moves no pod")
        #expect(snapshot.ventsOpen == beforeSnapshot.ventsOpen && snapshot.moonlight == beforeSnapshot.moonlight)
        #expect(snapshot.actionsLeft == beforeSnapshot.actionsLeft, "the run spends nothing")
        #expect(snapshot.shownCycle == beforeSnapshot.shownCycle, "the run keeps the shown cycle")
        #expect(MushroomWeatherTest.referencePixels(snapshot) == MushroomWeatherTest.referencePixels(beforeSnapshot))
        let reference: MushroomWeatherExperienceCore = try MushroomWeatherTest.coreAfter(found.number,
                                                                                         found.setUp + [.run])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        MushroomWeatherTest.checkFrame(rgba, snapshot: snapshot, tier: 2, "failed run")
        let points: [SIMD2<Double>] = MushroomWeatherTest.brokenPoints(snapshot)
        #expect(points == found.points, "the broken element's points are the search's")
        #expect(!points.isEmpty, "the broken element is clear")
        var marked: Int = 0
        var unmarkedBefore: Int = 0
        for point in points {
            let red: Bool = MushroomWeatherTest.anyPixel(rgba, near: point, radius: MushroomWeatherTest.markRadius,
                                                         width: MushroomWeatherTest.width,
                                                         height: MushroomWeatherTest.height,
                                                         where: MushroomWeatherTest.isBroken)
            if red {
                marked += 1
            } else {
                let seen: SIMD3<Double> = MushroomWeatherTest.centre(rgba, point)
                Issue.record("\(found.code): the broken element at (\(point.x), \(point.y)) is \(seen), not broken")
            }
            let redBefore: Bool = MushroomWeatherTest.anyPixel(before, near: point,
                                                               radius: MushroomWeatherTest.markRadius,
                                                               width: MushroomWeatherTest.width,
                                                               height: MushroomWeatherTest.height,
                                                               where: MushroomWeatherTest.isBroken)
            if !redBefore { unmarkedBefore += 1 }
        }
        print("mushroom-weather failure \(found.code): broken points marked \(marked) of \(points.count), unmarked "
              + "before the run \(unmarkedBefore)")
        #expect(unmarkedBefore == points.count, "the mark appears only with the failed run")
        // Undo returns the failed run to the moment before the run (the shown cycle is presentation only).
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try MushroomWeatherTest.digest(shell) == digest)
        #expect(failedDigest != digest, "the failed run has its own digest")
        let undone: [UInt8] = try MushroomWeatherTest.still(session)
        #expect(undone == before, "undo draws the frame before the run")
        session.qualityPin = 0
    }

    /// Making level 1's certified plan and running the weather through the shell wins; the won frame lights every cap
    /// (each clear cap centre is the cap colour at level-2, the caps out of band at the shown cycle included), keeps
    /// every pod, the reference pixels are the same at level-0 and level-2, and the won frames pass the checks.
    @Test func aWonLevelLightsEveryCap() async throws {
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(1)
        #expect(!plan.isEmpty, "level 1 has a certified plan")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MushroomWeatherTest.open(session, seed: 0, setUp: plan)
        MushroomWeatherTest.pin(session, shell, tier: 2)
        let arrangedFrame: [UInt8] = try MushroomWeatherTest.still(session)
        let arranged: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(!arranged.isWon, "not won before the run")
        #expect(shell.handle(control: "weather.run") == .accepted)
        let core: MushroomWeatherExperienceCore = try MushroomWeatherTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == MushroomWeatherExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        // Feature 496: the won look fades in by the frame clock (0.15 s), so one frame a second later settles it; the
        // checked frames are then drawn at time 0 again (no elapsed time, the lights stay settled).
        _ = try MushroomWeatherTest.still(session, time: 1)
        let reference: MushroomWeatherSceneSnapshot = try MushroomWeatherTest.coreAfter(1, plan + [.run])
            .snapshot(time: 0)
        var pixels: [[SIMD2<Double>?]] = []
        for tier in [2, 0] {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            let won: [UInt8] = try MushroomWeatherTest.still(session)
            let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level 1 won, tier \(tier)"
            #expect(snapshot.stage == .won && snapshot.isWon, "\(what)")
            #expect(snapshot == reference, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.pods == arranged.pods, "\(what): the run moves no pod")
            #expect(snapshot.shownCycle == arranged.shownCycle, "\(what): the run keeps the shown cycle")
            #expect(snapshot.failure == nil, "\(what): no failure")
            MushroomWeatherTest.checkFrame(won, snapshot: snapshot, tier: tier, what)
            if tier == 2 { checkLitCaps(won, before: arrangedFrame, snapshot, what) }
            pixels.append(MushroomWeatherTest.referencePixels(snapshot))
        }
        #expect(pixels.count == 2 && pixels[0] == pixels[1], "the tier moves no reference point of the won frame")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// Every cap of the won `snapshot` is lit in `rgba` (level-2, flat caps): each cap whose centre is clear of every
    /// later element is the cap colour within 0.1 there; a cap out of band at the shown cycle was not the cap colour
    /// in `before` (the frame before the run, same geometry), so the won look lit it. At least one cap is measured.
    private func checkLitCaps(_ rgba: [UInt8], before: [UInt8], _ snapshot: MushroomWeatherSceneSnapshot,
                              _ what: String) {
        typealias T = MushroomWeatherTest
        let o: MushroomWeatherTestLayout = T.layout(snapshot, tier: 2)
        var measured: Int = 0
        var passed: Int = 0
        var turned: Int = 0
        for k in snapshot.colonies.indices {
            guard let rank = o.rank(.cap, k) else { continue }
            let found: [SIMD2<Double>] = T.clearPixels([MushroomWeatherSceneGeometry.capCentre(k, snapshot)],
                                                       after: rank, o, width: T.width, height: T.height)
            guard let p = found.first else { continue }
            measured += 1
            let lit: Bool = T.anyPixel(rgba, near: p, radius: T.markRadius, width: T.width, height: T.height,
                                       where: T.isLitCap)
            if lit {
                passed += 1
            } else {
                Issue.record("\(what): cap \(k) at (\(p.x), \(p.y)) is \(T.centre(rgba, p)), not lit")
            }
            if !snapshot.colonies[k].inBand {
                let litBefore: Bool = T.isLitCap(T.centre(before, p))
                #expect(!litBefore, "\(what): out-of-band cap \(k) was already the lit colour before the run")
                if !litBefore && lit { turned += 1 }
            }
        }
        print("mushroom-weather \(what): caps \(snapshot.colonies.count), measured \(measured), lit \(passed), "
              + "turned lit by the win \(turned)")
        #expect(measured >= 1, "\(what): no cap was clear of the later elements")
        #expect(passed == measured, "\(what): \(passed) of \(measured) caps lit")
    }

    /// Draws level `seed % 100 + 1` (with its certified plan when `placed`) at the cycle half the cycles run at the
    /// three tiers and checks it against the CPU reference; returns, per tier, 1 when a cap, the first gauge track and
    /// the first actions bar (when lit) were all measured, and 1 when the moon was measured.
    private func checkLevel(seed: UInt64, placed: Bool) async throws -> (measured: [Int], moons: [Int]) {
        let level: Int = MushroomWeatherExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        let plan: [MushroomWeatherAction] = placed ? try MushroomWeatherTest.certifiedPlan(level) : []
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MushroomWeatherTest.open(session, seed: seed, setUp: plan)
        #expect(try MushroomWeatherTest.core(shell).levelNumber == level)
        let expectedCore: MushroomWeatherExperienceCore = try MushroomWeatherTest.coreAfter(level, plan)
        let expected: MushroomWeatherSceneSnapshot = expectedCore.snapshot(time: 0)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [MushroomWeatherSceneSnapshot] = []
        var measured: [Int] = []
        var moons: [Int] = []
        for tier in 0..<3 {
            MushroomWeatherTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MushroomWeatherTest.still(session)
            let snapshot: MushroomWeatherSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level)\(placed ? " placed" : " opening") tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownCycle == MushroomWeatherTest.halfCycle(snapshot.cyclesRun), "\(what): half cycle")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget - plan.count, "\(what): actions spent")
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            if placed {
                #expect(snapshot.failure == nil, "\(what): the certified plan's run wins")
                #expect(snapshot.cyclesRun == expectedCore.play.level.length, "\(what): the whole run")
            }
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            let report: MushroomWeatherCheckReport = MushroomWeatherTest.checkFrame(rgba, snapshot: snapshot,
                                                                                    tier: tier, what)
            let barDone: Bool = report.barChecked || MushroomWeatherSceneGeometry.litActions(snapshot) == 0
            let all: Bool = report.capsChecked >= 1 && report.trackChecked && barDone
            measured.append(all ? 1 : 0)
            moons.append(report.moonChecked ? 1 : 0)
            references.append(MushroomWeatherTest.referencePixels(snapshot))
            snapshots.append(snapshot)
        }
        // The tier changes no coordinate and nothing measured.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2], "level \(level): tier snapshots")
        session.qualityPin = 0
        return (measured, moons)
    }
}
#endif
