// MyceliumArchitectRenderTests — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-001 … 004, 006, 007, 010;
// SC-R02G2203-001, 002; clarifications Q1–Q4). Through the one app's session host, drawn off screen at the frame-check
// size of `MyceliumArchitectTest` (1,152 × 768) at frame time 0 and the full shown pulse (the pulses run, shown at an
// opening and after every action): catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80) with their certified
// plan made (so the predicted run is the winning one and every terminal is reached), at each quality tier level-0,
// level-1 and level-2, match the Core's CPU reference (`MyceliumArchitectSceneGeometry.referencePoints` and `project`)
// of the presenter's last snapshot: at every point at least 6 px from every element drawn after it in the painter's
// order, the root cap's centre is brighter than the backdrop there by 0.15 in luminance, every reached terminal's
// centre by 0.3 and every unreached one differs by 0.05 (the root or a terminal per frame), the first actions bar (lit)
// has red above blue by 0.08, the weight plate's left margin is 0.05 from the backdrop, and the median of each 9 × 9
// lower-corner patch is within 0.06 of the gradient at its height; the reference pixels and the drawn snapshot are the
// same at every tier (the fuzz and spores move by time and are never reference points). The openings (the starting
// arrangement; terminals unreached) pass the same checks. The presenter declares no frame probe before it drew a
// snapshot and two dark corners after, which match the drawn still at every tier. A run that fails (found by a short
// search through the adapter, e.g. an immediate `growth.run` on a level's opening) draws its failing element broken
// (`MyceliumArchitectPalette.broken`: a ring around the entered toxin or the unreached terminal, or the weight fill
// past the limit) where it was not broken before the run, moves nothing, is named in words, and undo draws the frame
// before it again; level 1 won by its certified plan and `growth.run` opens every terminal and brightens the veins and
// caps (`u_won`) without moving any position and passes the same checks. Each test well under 10 s.
#if os(iOS)
import Foundation
@testable import MyceliumArchitectCore
import Testing
@testable import MyceliumArchitectExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

@MainActor
@Suite(.serialized) struct MyceliumArchitectRenderTests {
    /// The catalog levels searched for a failing run, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels with their certified plan made, at the full shown pulse, matches the CPU
    /// reference at the same reference pixels; every frame measures the root or a terminal, the weight plate's margin
    /// and the first actions bar (when lit).
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in MyceliumArchitectTest.seeds {
            let counts: [Int] = try await checkLevel(seed: seed, arranged: true)
            for tier in 0..<3 { measured[tier] += counts[tier] }
        }
        print("mycelium-architect five levels: frames fully measured per tier \(measured)")
        for tier in 0..<3 {
            #expect(measured[tier] == MyceliumArchitectTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
        }
    }

    /// The five openings (the starting arrangement; the predicted run fails) pass the same checks at every tier.
    @Test func theOpeningsMatchTheReference() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in MyceliumArchitectTest.seeds {
            let counts: [Int] = try await checkLevel(seed: seed, arranged: false)
            for tier in 0..<3 { measured[tier] += counts[tier] }
        }
        print("mycelium-architect five openings: frames fully measured per tier \(measured)")
        for tier in 0..<3 {
            #expect(measured[tier] == MyceliumArchitectTest.seeds.count, "tier \(tier): \(measured[tier]) of 5")
        }
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two dark corners match the drawn still at every
    /// tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<MyceliumArchitectPresenter> =
            MyceliumArchitectExperience.make(id: MyceliumArchitectTest.id)
        let opening: MyceliumArchitectExperienceCore = try MyceliumArchitectExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(41)
        let shell = try await MyceliumArchitectTest.open(session, seed: 40, setUp: plan)
        for tier in 0..<3 {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try MyceliumArchitectTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = MyceliumArchitectTest.bottomUp(still, width: MyceliumArchitectTest.width,
                                                               height: MyceliumArchitectTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try MyceliumArchitectTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two dark corners")
            for probe in probes {
                let found: FrameColorClass? = FrameChecks.probe(probe, rgba: rgba, width: MyceliumArchitectTest.width,
                                                                height: MyceliumArchitectTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A run that fails draws its failing element in the broken colour where it was not broken before the run;
    /// nothing moves; the words name the failure; undo draws the frame before the run again.
    @Test func aFailedRunMarksTheFailingElementBroken() async throws {
        let found: MyceliumArchitectFailureCase = try #require(
            try MyceliumArchitectTest.failureCase(candidates: Self.failureLevels),
            "a catalog level with a failing run whose broken element is clear")
        print("mycelium-architect failure: level \(found.number), set-up \(found.setUp), \(found.code), points "
              + "\(found.points.count)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MyceliumArchitectTest.open(session, seed: UInt64(found.number - 1), setUp: found.setUp)
        // Level-2: nothing glows and no fuzz or spore is drawn, so the broken element is exactly its material colour.
        MyceliumArchitectTest.pin(session, shell, tier: 2)
        let digest: String = try MyceliumArchitectTest.digest(shell)
        let before: [UInt8] = try MyceliumArchitectTest.still(session)
        let beforeSnapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(beforeSnapshot.stage == .playing, "no mark for the predicted failure while playing")
        #expect(shell.handle(control: "growth.run") == .accepted)
        let failedDigest: String = try MyceliumArchitectTest.digest(shell)
        let core: MyceliumArchitectExperienceCore = try MyceliumArchitectTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: MyceliumArchitectFailure = try #require(core.play.failure)
        #expect(failure.code == found.code)
        #expect(core.outcome?.code == MyceliumArchitectExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(MyceliumArchitectMirror.failureText(failure, level: core.play.level))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, nothing moved, the broken element is red.
        let rgba: [UInt8] = try MyceliumArchitectTest.still(session)
        let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.stage == .failed)
        #expect(snapshot.arrangement == beforeSnapshot.arrangement, "a run places and seeds nothing")
        #expect(snapshot.actionsLeft == beforeSnapshot.actionsLeft, "the run spends nothing")
        #expect(snapshot.grown == beforeSnapshot.grown, "the run grows the predicted network")
        #expect(snapshot.shownPulse == snapshot.pulsesRun, "the run shows the full growth")
        #expect(MyceliumArchitectTest.referencePixels(snapshot)
                == MyceliumArchitectTest.referencePixels(beforeSnapshot))
        let reference: MyceliumArchitectExperienceCore = try MyceliumArchitectTest.coreAfter(found.number,
                                                                                             found.setUp + [.run])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        MyceliumArchitectTest.checkFrame(rgba, snapshot: snapshot, tier: 2, "failed run")
        let points: [SIMD2<Double>] = MyceliumArchitectTest.brokenPoints(snapshot)
        #expect(points == found.points, "the broken element's points are the search's")
        #expect(!points.isEmpty, "the broken element is clear")
        var marked: Int = 0
        var unmarkedBefore: Int = 0
        for point in points {
            let red: Bool = MyceliumArchitectTest.anyPixel(rgba, near: point, radius: MyceliumArchitectTest.markRadius,
                                                           width: MyceliumArchitectTest.width,
                                                           height: MyceliumArchitectTest.height,
                                                           where: MyceliumArchitectTest.isBroken)
            if red {
                marked += 1
            } else {
                let seen: SIMD3<Double> = MyceliumArchitectTest.centre(rgba, point)
                Issue.record("\(found.code): the broken element at (\(point.x), \(point.y)) is \(seen), not broken")
            }
            let redBefore: Bool = MyceliumArchitectTest.anyPixel(before, near: point,
                                                                 radius: MyceliumArchitectTest.markRadius,
                                                                 width: MyceliumArchitectTest.width,
                                                                 height: MyceliumArchitectTest.height,
                                                                 where: MyceliumArchitectTest.isBroken)
            if !redBefore { unmarkedBefore += 1 }
        }
        print("mycelium-architect failure \(found.code): broken points marked \(marked) of \(points.count), "
              + "unmarked before the run \(unmarkedBefore)")
        #expect(unmarkedBefore == points.count, "the mark appears only with the failed run")
        // Undo returns the failed run to the moment before the run.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try MyceliumArchitectTest.digest(shell) == digest)
        #expect(failedDigest != digest, "the failed run has its own digest")
        let undone: [UInt8] = try MyceliumArchitectTest.still(session)
        #expect(undone == before, "undo draws the frame before the run")
        session.qualityPin = 0
    }

    /// Making level 1's certified plan and running the growth through the shell wins; every terminal is reached and
    /// open (on the CPU: every terminal is reached at the shown pulse and has its glow shells at level-0; on the GPU:
    /// the won look (`u_won`) brightens the veins and caps, so the frame changes at level-0 and level-2), nothing moves
    /// (the same arrangement, network, shown pulse and reference pixels at level-2 and level-0), and the won frames
    /// pass the checks.
    @Test func aWonLevelOpensEveryTerminal() async throws {
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(1)
        #expect(!plan.isEmpty, "level 1 has a certified plan")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MyceliumArchitectTest.open(session, seed: 0, setUp: plan)
        var arrangedFrames: [Int: [UInt8]] = [:]
        for tier in [2, 0] {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            arrangedFrames[tier] = try MyceliumArchitectTest.still(session)
        }
        let arranged: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(!arranged.isWon, "not won before the run")
        #expect(arranged.failure == nil, "the certified plan's run is predicted to win")
        #expect(shell.handle(control: "growth.run") == .accepted)
        let core: MyceliumArchitectExperienceCore = try MyceliumArchitectTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == MyceliumArchitectExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        let reference: MyceliumArchitectSceneSnapshot = try MyceliumArchitectTest.coreAfter(1, plan + [.run])
            .snapshot(time: 0)
        var pixels: [[SIMD2<Double>?]] = []
        for tier in [2, 0] {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            let won: [UInt8] = try MyceliumArchitectTest.still(session)
            let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level 1 won, tier \(tier)"
            #expect(snapshot.stage == .won && snapshot.isWon, "\(what)")
            #expect(snapshot == reference, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.arrangement == arranged.arrangement, "\(what): the run places nothing")
            #expect(snapshot.grown == arranged.grown, "\(what): the run grows the predicted network")
            #expect(snapshot.shownPulse == arranged.shownPulse, "\(what): the run keeps the full growth shown")
            #expect(snapshot.failure == nil, "\(what): no failure")
            MyceliumArchitectTest.checkFrame(won, snapshot: snapshot, tier: tier, what)
            checkOpen(snapshot, tier: MyceliumArchitectTier.of(tier), what)
            if let before = arrangedFrames[tier] {
                let changed: Int = MyceliumArchitectTest.differingPixels(won, before)
                print("mycelium-architect \(what): \(changed) pixels brightened by the won look")
                #expect(changed > 0, "\(what): the won look brightens the veins and caps")
            }
            pixels.append(MyceliumArchitectTest.referencePixels(snapshot))
        }
        #expect(pixels.count == 2 && pixels[0] == pixels[1], "the tier moves no reference point of the won frame")
        #expect(pixels.first == MyceliumArchitectTest.referencePixels(arranged), "the win moves no reference point")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// CPU: on the won `snapshot` every terminal is reached at the shown pulse, the board mesh keeps the positions of
    /// the same arrangement before the run, and the glow mesh at `tier` has a shell group around every open terminal.
    private func checkOpen(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier, _ what: String) {
        typealias G = MyceliumArchitectSceneGeometry
        for terminal in snapshot.level.terminals.indices {
            #expect(snapshot.isReached(terminal), "\(what): terminal \(terminal) is reached and open")
        }
        var glows: Int = 0
        for element in G.paintOrder(snapshot) where element.kind == .glow { glows += 1 }
        let blooms: Int = G.shownBlooms(snapshot).count
        #expect(glows == 1 + snapshot.level.terminals.count + blooms, "\(what): glow groups \(glows)")
        let glow: Mesh = G.glow(snapshot, tier: tier)
        if tier.glowShells > 0 {
            #expect(!glow.indices.isEmpty, "\(what): the open caps glow")
        } else {
            #expect(glow.indices.isEmpty, "\(what): no glow at level-2")
        }
    }

    /// Draws level `seed % 100 + 1` (with its certified plan when `arranged`) at the full shown pulse at the three
    /// tiers and checks it against the CPU reference; returns, per tier, 1 when the root or a terminal, the weight
    /// plate's margin and the first actions bar (when lit) were all measured.
    private func checkLevel(seed: UInt64, arranged: Bool) async throws -> [Int] {
        let level: Int = MyceliumArchitectExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        let plan: [MyceliumArchitectAction] = arranged ? try MyceliumArchitectTest.certifiedPlan(level) : []
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MyceliumArchitectTest.open(session, seed: seed, setUp: plan)
        #expect(try MyceliumArchitectTest.core(shell).levelNumber == level)
        let expectedCore: MyceliumArchitectExperienceCore = try MyceliumArchitectTest.coreAfter(level, plan)
        let expected: MyceliumArchitectSceneSnapshot = expectedCore.snapshot(time: 0)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [MyceliumArchitectSceneSnapshot] = []
        var measured: [Int] = []
        for tier in 0..<3 {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MyceliumArchitectTest.still(session)
            let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level)\(arranged ? " arranged" : " opening") tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownPulse == snapshot.pulsesRun, "\(what): pulse \(snapshot.shownPulse)")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget - plan.count, "\(what): actions spent")
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            if arranged {
                #expect(snapshot.failure == nil, "\(what): the certified plan's run wins")
                for terminal in snapshot.level.terminals.indices {
                    #expect(snapshot.isReached(terminal), "\(what): terminal \(terminal) reached")
                }
            } else {
                #expect(snapshot.failure != nil, "\(what): a level never starts won")
            }
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            let report: MyceliumArchitectCheckReport = MyceliumArchitectTest.checkFrame(rgba, snapshot: snapshot,
                                                                                        tier: tier, what)
            let barDone: Bool = report.barChecked || MyceliumArchitectSceneGeometry.litActions(snapshot) == 0
            let all: Bool = report.capChecked && report.marginChecked && barDone
            measured.append(all ? 1 : 0)
            references.append(MyceliumArchitectTest.referencePixels(snapshot))
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
