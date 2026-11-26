// MicroscopicAuroraRenderTests — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-001 … 004, 006, 007;
// SC-R02G1903-001, 002; clarifications Q1–Q4). Through the one app's session host, drawn off screen at the
// frame-check size of `MicroscopicAuroraTest` (1,152 × 768) at frame time 0 and the shown tick half the ticks swum
// (`clock.show [ticks / 2]` sent to the core before drawing): catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40,
// 60, 80) with their certified plan placed (so the swim is the winning one and the swimmers move), at each quality
// tier level-0, level-1 and level-2, match the Core's CPU reference of the presenter's last snapshot: at every point
// at least 6 px from every element drawn after it in the painter's order, each swimmer's centre is brighter than the
// dish field by 0.25 in luminance (at least one swimmer per frame), the rim's rightmost point is 0.1 from the
// backdrop, the first actions bar (lit) has blue above green by 0.08, the coverage track's centre is 0.1 from the
// backdrop, and the median of every 9 × 9 corner patch is within 0.06 of the gradient at its height; the reference
// pixels and the drawn snapshot are the same at every tier. The openings (no wells) pass the same checks. The
// presenter declares no frame probe before it drew a snapshot and two dark corners after, which match the drawn
// still at every tier. A play that fails (found by a short search through the adapter, e.g. a level's opening
// played without wells) draws its failing element broken (red above green and blue), moves nothing, is named in
// words, and undo draws the frame before it again; level 1 won by its certified plan lights every stencil cell (the
// unlit outlines turn to the lit colour, the lit cells stay lit), keeps every position and passes the same checks.
// Each test well under 10 s.
#if os(iOS)
import Foundation
import MicroscopicAuroraCore
import Testing
@testable import MicroscopicAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MicroscopicAuroraRenderTests {
    /// The catalog levels searched for a failing play, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels with their certified plan placed, at the tick half the ticks swum, matches the
    /// CPU reference at the same reference pixels; every frame measures a swimmer, the coverage track and the first
    /// actions bar; the rim point is measured on some level.
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var measured: [Int] = [0, 0, 0]
        var rims: [Int] = [0, 0, 0]
        for seed in MicroscopicAuroraTest.seeds {
            let counts = try await checkLevel(seed: seed, placed: true)
            for tier in 0..<3 {
                measured[tier] += counts.measured[tier]
                rims[tier] += counts.rims[tier]
            }
        }
        print("microscopic-aurora five levels: frames fully measured per tier \(measured), rim measured \(rims)")
        for tier in 0..<3 {
            #expect(measured[tier] == MicroscopicAuroraTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
            #expect(rims[tier] >= 1, "tier \(tier): the rim point was never clear")
        }
    }

    /// The five openings (no wells; the swim may fail early) pass the same checks at every tier.
    @Test func theOpeningsMatchTheReference() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in MicroscopicAuroraTest.seeds {
            let counts = try await checkLevel(seed: seed, placed: false)
            for tier in 0..<3 { measured[tier] += counts.measured[tier] }
        }
        print("microscopic-aurora five openings: frames fully measured per tier \(measured)")
        for tier in 0..<3 {
            #expect(measured[tier] == MicroscopicAuroraTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
        }
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two dark corners match the drawn still at every
    /// tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<MicroscopicAuroraPresenter> = MicroscopicAuroraExperience.make(
            id: MicroscopicAuroraTest.id)
        let opening: MicroscopicAuroraExperienceCore = try MicroscopicAuroraExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(41)
        let shell = try await MicroscopicAuroraTest.open(session, seed: 40, setUp: plan)
        for tier in 0..<3 {
            MicroscopicAuroraTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try MicroscopicAuroraTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = MicroscopicAuroraTest.bottomUp(still, width: MicroscopicAuroraTest.width,
                                                               height: MicroscopicAuroraTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try MicroscopicAuroraTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two dark corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: MicroscopicAuroraTest.width,
                                              height: MicroscopicAuroraTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A play that fails draws its failing element broken (red above green and blue); nothing moves; the words name
    /// the failure; undo draws the frame before the play again.
    @Test func aFailedPlayMarksTheFailingElementBroken() async throws {
        let found: MicroscopicAuroraFailureCase = try #require(
            try MicroscopicAuroraTest.failureCase(candidates: Self.failureLevels),
            "a catalog level with a failing play whose broken element is clear")
        print("microscopic-aurora failure: level \(found.number), set-up \(found.setUp), \(found.code), points "
              + "\(found.points.count)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MicroscopicAuroraTest.open(session, seed: UInt64(found.number - 1), setUp: found.setUp,
                                                         atHalf: false)
        // Level-2: nothing glows, so the broken element is exactly its material colour.
        MicroscopicAuroraTest.pin(session, shell, tier: 2)
        let digest: String = try MicroscopicAuroraTest.digest(shell)
        let before: [UInt8] = try MicroscopicAuroraTest.still(session)
        let beforeSnapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(shell.handle(control: "swim.play") == .accepted)
        try MicroscopicAuroraTest.showHalf(shell)
        let shownDigest: String = try MicroscopicAuroraTest.digest(shell)
        let core: MicroscopicAuroraExperienceCore = try MicroscopicAuroraTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: MicroscopicAuroraFailure = try #require(core.play.failure)
        #expect(failure.code == found.code)
        #expect(core.outcome?.code == MicroscopicAuroraExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(MicroscopicAuroraMirror.failureText(failure))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, nothing moved, the broken element is red.
        let rgba: [UInt8] = try MicroscopicAuroraTest.still(session)
        let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.stage == .failed)
        #expect(snapshot.positions == beforeSnapshot.positions, "a play moves nothing")
        #expect(snapshot.wells == beforeSnapshot.wells && snapshot.actionsLeft == beforeSnapshot.actionsLeft)
        let reference: MicroscopicAuroraExperienceCore = try MicroscopicAuroraTest.coreAfter(found.number,
                                                                                             found.setUp + [.play])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        MicroscopicAuroraTest.checkFrame(rgba, snapshot: snapshot, "failed play")
        let points: [SIMD2<Double>] = MicroscopicAuroraTest.brokenPoints(snapshot)
        #expect(points == found.points, "the broken element's points are the search's")
        #expect(!points.isEmpty, "the broken element is clear")
        var marked: Int = 0
        for point in points {
            let red: Bool = MicroscopicAuroraTest.anyPixel(rgba, near: point, radius: MicroscopicAuroraTest.markRadius,
                                                           width: MicroscopicAuroraTest.width,
                                                           height: MicroscopicAuroraTest.height,
                                                           where: MicroscopicAuroraTest.isBroken)
            if red {
                marked += 1
            } else {
                let seen: SIMD3<Double> = MicroscopicAuroraTest.centre(rgba, point)
                Issue.record("\(found.code): the broken element at (\(point.x), \(point.y)) is \(seen), not red")
            }
        }
        print("microscopic-aurora failure \(found.code): broken points red \(marked) of \(points.count)")
        // Undo returns the failed play to the moment before the play (the shown tick is presentation only).
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try MicroscopicAuroraTest.digest(shell) == digest)
        #expect(shownDigest != digest, "the failed play has its own digest")
        let shownBack: ActionResult = shell.handle(control: "clock.show", values: [Double(beforeSnapshot.shownTick)])
        #expect(shownBack == .accepted, "\(shownBack.code)")
        let undone: [UInt8] = try MicroscopicAuroraTest.still(session)
        #expect(undone == before, "undo draws the frame before the play")
        session.qualityPin = 0
    }

    /// Playing level 1 after its certified plan through the shell wins; the won frame lights every stencil cell
    /// (each measured unlit outline turns toward the lit colour against the frame before the play, each measured
    /// lit cell is the lit colour), keeps every position, the reference pixels are the same at level-0 and level-2,
    /// and the won frames pass the checks.
    @Test func aWonLevelLightsEveryStencilCell() async throws {
        let plan: [MicroscopicAuroraAction] = try MicroscopicAuroraTest.certifiedPlan(1)
        #expect(!plan.isEmpty, "level 1 has a certified plan")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MicroscopicAuroraTest.open(session, seed: 0, setUp: plan)
        MicroscopicAuroraTest.pin(session, shell, tier: 2)
        let arrangedFrame: [UInt8] = try MicroscopicAuroraTest.still(session)
        let arranged: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(!arranged.isWon, "not won before the play")
        #expect(shell.handle(control: "swim.play") == .accepted)
        let core: MicroscopicAuroraExperienceCore = try MicroscopicAuroraTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == MicroscopicAuroraExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        // Feature 486: the won look fades in by the frame clock (0.15 s), so one frame a second later settles it; the
        // checked frames are then drawn at time 0 again (no elapsed time, the lights stay settled).
        _ = try MicroscopicAuroraTest.still(session, time: 1)
        let reference: MicroscopicAuroraSceneSnapshot = try MicroscopicAuroraTest.coreAfter(1, plan + [.play])
            .snapshot(time: 0)
        var pixels: [[SIMD2<Double>?]] = []
        for tier in [2, 0] {
            MicroscopicAuroraTest.pin(session, shell, tier: tier)
            let won: [UInt8] = try MicroscopicAuroraTest.still(session)
            let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level 1 won, tier \(tier)"
            #expect(snapshot.stage == .won && snapshot.isWon, "\(what)")
            #expect(snapshot == reference, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.positions == arranged.positions, "\(what): the play moves nothing")
            #expect(snapshot.failure == nil, "\(what): no failure")
            MicroscopicAuroraTest.checkFrame(won, snapshot: snapshot, what)
            if tier == 2 { checkLitStencil(won, before: arrangedFrame, snapshot, what) }
            pixels.append(MicroscopicAuroraTest.referencePixels(snapshot))
        }
        #expect(pixels.count == 2 && pixels[0] == pixels[1], "the tier moves no reference point of the won frame")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// Every stencil cell of the won `snapshot` is lit in `rgba` (level-2): a lit cell whose centre is clear of
    /// every later element is the lit colour within 0.1 there; an unlit cell's outline points that are clear turn
    /// toward the lit colour against `before` (the frame before the play, same geometry): within 1.5 px some pixel's
    /// green rises by 0.05 and is above its red. At least one cell is measured.
    private func checkLitStencil(_ rgba: [UInt8], before: [UInt8], _ snapshot: MicroscopicAuroraSceneSnapshot,
                                 _ what: String) {
        typealias T = MicroscopicAuroraTest
        let o: MicroscopicAuroraTestLayout = T.layout(snapshot)
        var lit: Set<Int> = []
        for cell in snapshot.litStencil { lit.insert(cell.index) }
        var measured: Int = 0
        var passed: Int = 0
        for cell in snapshot.stencil {
            let centre: SIMD3<Double> = MicroscopicAuroraSceneGeometry.cellCentre(cell)
            if lit.contains(cell.index) {
                guard let rank = o.rank(.litCell, cell.index) else { continue }
                let found: [SIMD2<Double>] = T.clearPixels([centre], after: rank, o, width: T.width, height: T.height)
                guard let p = found.first else { continue }
                measured += 1
                let ok: Bool = T.anyPixel(rgba, near: p, radius: T.markRadius, width: T.width, height: T.height,
                                          where: { T.channelDistance($0, MicroscopicAuroraPalette.lit) <= 0.1 })
                if ok {
                    passed += 1
                } else {
                    Issue.record("\(what): lit cell \(cell) at (\(p.x), \(p.y)) is \(T.centre(rgba, p))")
                }
                continue
            }
            guard let rank = o.rank(.outline, cell.index) else { continue }
            let found: [SIMD2<Double>] = T.clearPixels(T.outlinePoints(centre), after: rank, o, width: T.width,
                                                       height: T.height)
            guard let p = found.first else { continue }
            measured += 1
            var rises: Bool = false
            for spot in T.pixelsNear(p, radius: T.markRadius, width: T.width, height: T.height) {
                let now: SIMD3<Double> = T.colour(rgba, x: spot.x, y: spot.y, width: T.width)
                let then: SIMD3<Double> = T.colour(before, x: spot.x, y: spot.y, width: T.width)
                if now.y - then.y >= 0.05 && now.y > now.x { rises = true }
            }
            if rises {
                passed += 1
            } else {
                Issue.record("\(what): the outline of \(cell) at (\(p.x), \(p.y)) did not light")
            }
        }
        print("microscopic-aurora \(what): stencil cells \(snapshot.stencil.count), measured \(measured), "
              + "lit \(passed)")
        #expect(measured >= 1, "\(what): no stencil cell was clear of the later elements")
        #expect(passed == measured, "\(what): \(passed) of \(measured) stencil cells lit")
    }

    /// Draws level `seed % 100 + 1` (with its certified plan when `placed`) at the tick half the ticks swum at the
    /// three tiers and checks it against the CPU reference; returns, per tier, 1 when a swimmer, the coverage track
    /// and the first actions bar (when lit) were all measured, and 1 when the rim point was measured.
    private func checkLevel(seed: UInt64, placed: Bool) async throws -> (measured: [Int], rims: [Int]) {
        let level: Int = MicroscopicAuroraExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        let plan: [MicroscopicAuroraAction] = placed ? try MicroscopicAuroraTest.certifiedPlan(level) : []
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MicroscopicAuroraTest.open(session, seed: seed, setUp: plan)
        #expect(try MicroscopicAuroraTest.core(shell).levelNumber == level)
        let expectedCore: MicroscopicAuroraExperienceCore = try MicroscopicAuroraTest.coreAfter(level, plan)
        let expected: MicroscopicAuroraSceneSnapshot = expectedCore.snapshot(time: 0)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [MicroscopicAuroraSceneSnapshot] = []
        var measured: [Int] = []
        var rims: [Int] = []
        for tier in 0..<3 {
            MicroscopicAuroraTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MicroscopicAuroraTest.still(session)
            let snapshot: MicroscopicAuroraSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level)\(placed ? " placed" : " opening") tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownTick == MicroscopicAuroraTest.halfTick(snapshot.ticksSwum), "\(what): half tick")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget - plan.count, "\(what): actions spent")
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            if placed {
                #expect(snapshot.failure == nil, "\(what): the certified plan's swim wins")
                #expect(snapshot.ticksSwum == expectedCore.play.level.length, "\(what): the whole swim")
                var moved: Int = 0
                for track in snapshot.positions where track[snapshot.shownTick] != track[0] { moved += 1 }
                #expect(moved == snapshot.positions.count, "\(what): \(moved) swimmers moved")
            }
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            let report: MicroscopicAuroraCheckReport = MicroscopicAuroraTest.checkFrame(rgba, snapshot: snapshot,
                                                                                        what)
            let barDone: Bool = report.barChecked || MicroscopicAuroraSceneGeometry.litActions(snapshot) == 0
            let all: Bool = report.swimmersChecked >= 1 && report.trackChecked && barDone
            measured.append(all ? 1 : 0)
            rims.append(report.rimChecked ? 1 : 0)
            references.append(MicroscopicAuroraTest.referencePixels(snapshot))
            snapshots.append(snapshot)
        }
        // The tier changes no coordinate and nothing measured.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2], "level \(level): tier snapshots")
        session.qualityPin = 0
        return (measured, rims)
    }
}
#endif
