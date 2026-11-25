// ApsidesWorkshopRenderTests — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-001 … 004, 006, 007;
// SC-R02G1803-001, 002; clarifications Q1–Q4). Through the one app's session host, drawn off screen at the frame-check
// size of `ApsidesWorkshopTest` (1,152 × 768) at frame time 0 and the shown tick T/2 (`clock.show [period / 2]` sent to
// the core before drawing): catalog levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80) at their opening, at each
// quality tier level-0, level-1 and level-2, match the Core's CPU reference of the presenter's last snapshot: at every
// point at least 6 px from every element drawn after it in the painter's order, the star's centre and the orbiter's
// centre are brighter than the backdrop by 0.25 in luminance, the first actions bar (lit) has red above blue by 0.08,
// the first gauge track's centre is 0.1 from the backdrop, and the median of every 9 × 9 backdrop patch is within 0.06
// of the gradient at its height; the reference pixels and the drawn snapshot are the same at every tier. With the
// first tuning of each level's certified plan made, every tier draws the CPU reference at the kernel's positions. The
// presenter declares no frame probe before it drew a snapshot and two dark corners after, which match the drawn still
// at every tier. A play that fails (found by a short search through the adapter) draws its failing element broken (the
// contact's segment or the failing target's gauge track, red above blue), moves nothing, is named in words, and undo
// draws the frame before it again; level 1 won by its certified plan through the adapter lights every gauge mark
// (deep rose), keeps every position the kernel's and passes the same checks. Each test well under 10 s.
#if os(iOS)
import ApsidesWorkshopCore
import Foundation
import Testing
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct ApsidesWorkshopRenderTests {
    /// The catalog levels searched for a failing play, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels' openings at the shown tick T/2 matches the CPU reference at the same reference
    /// pixels; every frame measures the star, the orbiter, the first gauge track and the first actions bar.
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in ApsidesWorkshopTest.seeds {
            let counts: [Int] = try await checkOpening(seed: seed)
            for tier in 0..<3 { measured[tier] += counts[tier] }
        }
        print("apsides-workshop five openings: frames fully measured per tier \(measured)")
        for tier in 0..<3 {
            #expect(measured[tier] == ApsidesWorkshopTest.seeds.count, "tier \(tier): \(measured[tier]) of 5 levels")
        }
    }

    /// With the first certified tuning made on each of the five levels, every tier draws the CPU reference at the
    /// kernel's positions and the same reference pixels, and passes the frame checks.
    @Test func aTuningIsDrawnAtTheKernelsPositions() async throws {
        for seed in ApsidesWorkshopTest.seeds {
            let number: Int = ApsidesWorkshopExperienceCore.levelNumber(forSeed: seed)
            let first: ApsidesWorkshopAction = try #require(try ApsidesWorkshopTest.certifiedPlan(number).first,
                                                            "level \(number) has a certified tuning")
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await ApsidesWorkshopTest.open(session, seed: seed)
            #expect(ApsidesWorkshopTest.issue(shell, [first]) == 1)
            let reference: ApsidesWorkshopExperienceCore = try ApsidesWorkshopTest.coreAfter(number, [first])
            let expected: ApsidesWorkshopSceneSnapshot = reference.snapshot(time: 0)
            var references: [[SIMD2<Double>?]] = []
            for tier in 0..<3 {
                ApsidesWorkshopTest.pin(session, shell, tier: tier)
                let rgba: [UInt8] = try ApsidesWorkshopTest.still(session)
                let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                let what: String = "level \(number) first tuning tier \(tier)"
                #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
                #expect(snapshot.actionsLeft == snapshot.budget - 1, "\(what): one action spent")
                #expect(snapshot.positions == reference.play.report.positions,
                        "\(what): the drawn orbit is the kernel's positions")
                #expect(snapshot.shownTick == ApsidesWorkshopTest.halfTick(snapshot.period),
                        "\(what): a tuning keeps the shown tick")
                #expect(snapshot.orbiter == snapshot.positions[snapshot.shownTick], "\(what): the orbiter at T/2")
                #expect(shell.presenter.scene.lastPulse == 1, "\(what): frame time 0")
                ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot, what)
                references.append(ApsidesWorkshopTest.referencePixels(snapshot))
            }
            #expect(references[0] == references[1] && references[1] == references[2],
                    "level \(number): tier coordinates")
            session.qualityPin = 0
        }
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two dark corners match the drawn still at every
    /// tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<ApsidesWorkshopPresenter> = ApsidesWorkshopExperience.make(
            id: ApsidesWorkshopTest.id)
        let opening: ApsidesWorkshopExperienceCore = try ApsidesWorkshopExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 40)
        for tier in 0..<3 {
            ApsidesWorkshopTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try ApsidesWorkshopTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = ApsidesWorkshopTest.bottomUp(still, width: ApsidesWorkshopTest.width,
                                                             height: ApsidesWorkshopTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try ApsidesWorkshopTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two dark corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: ApsidesWorkshopTest.width,
                                              height: ApsidesWorkshopTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A play that fails draws its failing element broken (red above blue); nothing moves; the words name the
    /// failure; undo draws the frame before the play again.
    @Test func aFailedPlayMarksTheFailingElementBroken() async throws {
        let found: ApsidesWorkshopFailureCase = try #require(
            try ApsidesWorkshopTest.failureCase(candidates: Self.failureLevels),
            "a catalog level with a failing play whose broken element is clear")
        print("apsides-workshop failure: level \(found.number), set-up \(found.setUp), contact \(found.contact)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: UInt64(found.number - 1))
        // Level-2: nothing glows, so the broken element is exactly its material colour.
        ApsidesWorkshopTest.pin(session, shell, tier: 2)
        #expect(ApsidesWorkshopTest.issue(shell, found.setUp) == found.setUp.count)
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let clean: [UInt8] = try ApsidesWorkshopTest.still(session)
        let before: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(shell.handle(control: "orbit.play") == .accepted)
        let core: ApsidesWorkshopExperienceCore = try ApsidesWorkshopTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: ApsidesWorkshopFailure = try #require(core.play.failure)
        #expect(core.outcome?.code == ApsidesWorkshopExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(ApsidesWorkshopMirror.failureText(failure))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, nothing moved, the broken element is red above blue.
        let rgba: [UInt8] = try ApsidesWorkshopTest.still(session)
        let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.stage == .failed)
        #expect(snapshot.positions == before.positions && snapshot.orbit == before.orbit, "a play moves nothing")
        #expect(snapshot.shownTick == before.shownTick, "a play shows the same tick")
        let reference: ApsidesWorkshopExperienceCore = try ApsidesWorkshopTest.coreAfter(found.number,
                                                                                         found.setUp + [.play])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot, "failed play")
        if found.contact {
            #expect(ApsidesWorkshopSceneGeometry.contact(snapshot) != nil, "a contact names a planet")
        } else {
            #expect(ApsidesWorkshopSceneGeometry.failingGauge(snapshot) != nil, "the failure names a target")
        }
        let point = try #require(ApsidesWorkshopTest.brokenPoint(snapshot), "the broken element is clear")
        #expect(point.pixel == found.point && point.contact == found.contact)
        let marked: Bool = ApsidesWorkshopTest.anyPixel(rgba, near: point.pixel,
                                                        radius: ApsidesWorkshopTest.markRadius,
                                                        width: ApsidesWorkshopTest.width,
                                                        height: ApsidesWorkshopTest.height,
                                                        where: ApsidesWorkshopTest.isReddish)
        let seen: SIMD3<Double> = ApsidesWorkshopTest.centre(rgba, point.pixel)
        #expect(marked, "the broken element at (\(point.pixel.x), \(point.pixel.y)) is \(seen), not red above blue")
        // Undo returns the failed play to the moment before the play.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try ApsidesWorkshopTest.digest(shell) == digest)
        let undone: [UInt8] = try ApsidesWorkshopTest.still(session)
        #expect(undone == clean, "undo draws the frame before the play")
        session.qualityPin = 0
    }

    /// Playing level 1 after its certified plan through the shell wins; the won frame lights every gauge mark (filled,
    /// deep rose), keeps every position the kernel's, the reference pixels are the same at level-0 and level-2, and
    /// the won frames pass the checks.
    @Test func aWonLevelLightsEveryGaugeMark() async throws {
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        #expect(!plan.isEmpty, "level 1 has a certified plan")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: 0)
        #expect(ApsidesWorkshopTest.issue(shell, plan) == plan.count)
        _ = try ApsidesWorkshopTest.still(session, width: 96, height: 64)
        let arranged: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(!arranged.isWon, "not won before the play")
        #expect(shell.handle(control: "orbit.play") == .accepted)
        let core: ApsidesWorkshopExperienceCore = try ApsidesWorkshopTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == ApsidesWorkshopExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        let reference: ApsidesWorkshopSceneSnapshot = try ApsidesWorkshopTest.coreAfter(1, plan + [.play])
            .snapshot(time: 0)
        var pixels: [[SIMD2<Double>?]] = []
        for tier in [0, 2] {
            ApsidesWorkshopTest.pin(session, shell, tier: tier)
            let won: [UInt8] = try ApsidesWorkshopTest.still(session)
            let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level 1 won, tier \(tier)"
            #expect(snapshot.stage == .won && snapshot.isWon, "\(what)")
            #expect(snapshot == reference, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.positions == core.play.report.positions, "\(what): the kernel's positions")
            #expect(snapshot.failure == nil, "\(what): no failure")
            ApsidesWorkshopTest.checkFrame(won, snapshot: snapshot, what)
            checkLitMarks(won, snapshot, what)
            pixels.append(ApsidesWorkshopTest.referencePixels(snapshot))
        }
        #expect(pixels.count == 2 && pixels[0] == pixels[1], "the tier moves no reference point of the won frame")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// Every gauge mark of the won `snapshot` is a met mark; each that is clear of every later element is deep rose
    /// in `rgba` (red above blue by 0.08 and 0.25 brighter than the backdrop); every mark is measured.
    private func checkLitMarks(_ rgba: [UInt8], _ snapshot: ApsidesWorkshopSceneSnapshot, _ what: String) {
        for i in snapshot.gauges.indices {
            let material: ApsidesWorkshopMaterial = ApsidesWorkshopSceneGeometry.markMaterial(i, snapshot,
                                                                                             won: snapshot.isWon)
            #expect(material == .markMet, "\(what): mark \(i) is lit")
            #expect(snapshot.gauges[i].met, "\(what): target \(i) is met")
        }
        let sky = ApsidesWorkshopTest.backdrop()
        let clear = ApsidesWorkshopTest.clearMarks(snapshot)
        var lit: Int = 0
        for entry in clear {
            let back: Double = sky.map { ApsidesWorkshopTest.luminance($0.gradient(x: entry.pixel.x,
                                                                                 y: entry.pixel.y)) } ?? 0
            let floor: Double = back + ApsidesWorkshopTest.brightMargin
            let shines: Bool = ApsidesWorkshopTest.anyPixel(
                rgba, near: entry.pixel, radius: ApsidesWorkshopTest.markRadius,
                width: ApsidesWorkshopTest.width, height: ApsidesWorkshopTest.height,
                where: { c in ApsidesWorkshopTest.isReddish(c) && ApsidesWorkshopTest.luminance(c) >= floor })
            if shines {
                lit += 1
            } else {
                let c: SIMD3<Double> = ApsidesWorkshopTest.centre(rgba, entry.pixel)
                Issue.record("\(what): gauge mark \(entry.target) at (\(entry.pixel.x), \(entry.pixel.y)) is \(c)")
            }
        }
        print("apsides-workshop \(what): gauge marks \(snapshot.gauges.count), measured \(clear.count), lit \(lit)")
        #expect(clear.count == snapshot.gauges.count, "\(what): every gauge mark is clear of the later elements")
    }

    /// Draws the opening of the level `seed` prepares at the tick T/2 at the three tiers and checks it against the
    /// CPU reference; returns, per tier, 1 when the star, the orbiter, the first gauge track and the first actions
    /// bar were all measured.
    private func checkOpening(seed: UInt64) async throws -> [Int] {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ApsidesWorkshopTest.open(session, seed: seed)
        let level: Int = ApsidesWorkshopExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try ApsidesWorkshopTest.core(shell).levelNumber == level)
        let expectedCore: ApsidesWorkshopExperienceCore = try ApsidesWorkshopTest.coreAfter(level, [])
        let expected: ApsidesWorkshopSceneSnapshot = expectedCore.snapshot(time: 0)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [ApsidesWorkshopSceneSnapshot] = []
        var measured: [Int] = []
        for tier in 0..<3 {
            ApsidesWorkshopTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try ApsidesWorkshopTest.still(session)
            let snapshot: ApsidesWorkshopSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownTick == ApsidesWorkshopTest.halfTick(snapshot.period), "\(what): the tick T/2")
            #expect(snapshot.orbiter == snapshot.positions[snapshot.shownTick], "\(what): the orbiter at T/2")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget, "\(what): nothing spent at the opening")
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.positions == expectedCore.play.report.positions,
                    "\(what): the drawn orbit is the kernel's positions")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            #expect(shell.presenter.scene.lastPulse == 1, "\(what): frame time 0")
            let report: ApsidesWorkshopCheckReport = ApsidesWorkshopTest.checkFrame(rgba, snapshot: snapshot, what)
            let all: Bool = report.starChecked && report.orbiterChecked && report.trackChecked && report.barChecked
            measured.append(all ? 1 : 0)
            references.append(ApsidesWorkshopTest.referencePixels(snapshot))
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
