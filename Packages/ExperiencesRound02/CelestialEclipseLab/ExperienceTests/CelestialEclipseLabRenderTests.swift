// CelestialEclipseLabRenderTests — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-001 … 004, 007;
// clarifications Q1–Q4). Through the one app's session host, drawn off screen at the frame-check size of
// `CelestialEclipseLabTest` (1,152 × 768) at frame time 0 and the shown tick 0: catalog levels 1, 21, 41, 61 and 81
// (seeds 0, 20, 40, 60, 80) at their opening, at each quality tier level-0, level-1 and level-2, match the Core's CPU
// reference of the presenter's last snapshot: at every point at least 6 px from every element drawn after it in the
// painter's order that could hide it, the centre of a body not covered at tick 0 is brighter than the backdrop by 0.25
// in luminance, the first actions bar (lit) has red above blue by 0.08, the timeline strip's centre is 0.1 from the
// backdrop, and the median of every 9 × 9 backdrop patch is within 0.06 of the gradient at its height; the reference
// pixels and the drawn snapshot are the same at every tier; each tier measures body centres summed over the five
// levels. With the first phase change of each level's certified plan made, every tier draws the CPU reference at the
// kernel's positions. The presenter declares no frame probe before it drew a snapshot and two dark corners after, which
// match the drawn still at every tier. A run that fails (found by a short search through the adapter) draws the
// failing mark red above blue (the ember cross, or the broken end mark of a horizon failure), moves no body, is named
// in words, and undo draws the frame before it again; level 1 won by its certified plan through the adapter lights
// every target mark gold, keeps every position the kernel's and passes the same checks. Each test well under 10 s.
#if os(iOS)
import CelestialEclipseLabCore
import Foundation
import Testing
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct CelestialEclipseLabRenderTests {
    /// The catalog levels searched for a failing run, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels' openings matches the CPU reference at the same reference pixels; each tier
    /// measures body centres summed over the levels, the first actions bar and the timeline strip on most levels.
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var bodies: [Int] = [0, 0, 0]
        var bars: [Int] = [0, 0, 0]
        var strips: [Int] = [0, 0, 0]
        for seed in CelestialEclipseLabTest.seeds {
            let counts = try await checkOpening(seed: seed)
            for tier in 0..<3 {
                bodies[tier] += counts.bodies[tier]
                bars[tier] += counts.bars[tier]
                strips[tier] += counts.strips[tier]
            }
        }
        print("celestial-eclipse-lab five openings: bodies per tier \(bodies), bars \(bars), strips \(strips)")
        for tier in 0..<3 {
            #expect(bodies[tier] > 0, "tier \(tier): no body centre measured on the five levels")
            #expect(bars[tier] >= 3, "tier \(tier): the first actions bar was measured on \(bars[tier]) levels")
            #expect(strips[tier] >= 3, "tier \(tier): the timeline strip was measured on \(strips[tier]) levels")
        }
    }

    /// With the first certified phase change made on each of the five levels, every tier draws the CPU reference at
    /// the kernel's positions and the same reference pixels, and passes the frame checks.
    @Test func aPhaseChangeIsDrawnAtTheKernelsPositions() async throws {
        var measured: [Int] = [0, 0, 0]
        for seed in CelestialEclipseLabTest.seeds {
            let number: Int = CelestialEclipseLabExperienceCore.levelNumber(forSeed: seed)
            let first: CelestialEclipseLabAction = try #require(try CelestialEclipseLabTest.certifiedPlan(number).first,
                                                                "level \(number) has a certified change")
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await CelestialEclipseLabTest.open(session, seed: seed)
            #expect(CelestialEclipseLabTest.issue(shell, [first]) == 1)
            let reference: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.coreAfter(number, [first])
            let expected: CelestialEclipseLabSceneSnapshot = reference.snapshot(time: 0)
            var references: [[SIMD2<Double>?]] = []
            for tier in 0..<3 {
                CelestialEclipseLabTest.pin(session, shell, tier: tier)
                let rgba: [UInt8] = try CelestialEclipseLabTest.still(session)
                let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
                let what: String = "level \(number) first change tier \(tier)"
                #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
                #expect(snapshot.actionsLeft == snapshot.budget - 1, "\(what): one action spent")
                #expect(snapshot.positions == CelestialEclipseLabTest.kernelPositions(reference.play, tick: 0),
                        "\(what): the drawn bodies are the kernel's positions")
                #expect(shell.presenter.scene.lastPulse == 1, "\(what): frame time 0")
                let report: CelestialEclipseLabCheckReport = CelestialEclipseLabTest.checkFrame(rgba,
                                                                                                snapshot: snapshot,
                                                                                                what)
                measured[tier] += report.bodiesChecked
                references.append(CelestialEclipseLabTest.referencePixels(snapshot))
            }
            #expect(references[0] == references[1] && references[1] == references[2],
                    "level \(number): tier coordinates")
            session.qualityPin = 0
        }
        print("celestial-eclipse-lab first changes: bodies measured per tier \(measured)")
        #expect(measured[0] == measured[1] && measured[1] == measured[2], "bodies measured \(measured)")
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two dark corners match the drawn still at every
    /// tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<CelestialEclipseLabPresenter> = CelestialEclipseLabExperience.make(
            id: CelestialEclipseLabTest.id)
        let opening: CelestialEclipseLabExperienceCore = try CelestialEclipseLabExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 40)
        for tier in 0..<3 {
            CelestialEclipseLabTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try CelestialEclipseLabTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = CelestialEclipseLabTest.bottomUp(still, width: CelestialEclipseLabTest.width,
                                                                 height: CelestialEclipseLabTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try CelestialEclipseLabTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two dark corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: CelestialEclipseLabTest.width,
                                              height: CelestialEclipseLabTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A run that fails draws the failing mark red above blue; no body moves; the words name the failure; undo draws
    /// the frame before the run again.
    @Test func aFailedRunMarksTheFailingEventBroken() async throws {
        let found: CelestialEclipseLabFailureCase = try #require(
            try CelestialEclipseLabTest.failureCase(candidates: Self.failureLevels),
            "a catalog level with a failing run whose failing mark is clear")
        print("celestial-eclipse-lab failure: level \(found.number), set-up \(found.setUp), horizon \(found.horizon)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: UInt64(found.number - 1))
        // Level-2: nothing glows, so the failing mark is exactly its material colour.
        CelestialEclipseLabTest.pin(session, shell, tier: 2)
        #expect(CelestialEclipseLabTest.issue(shell, found.setUp) == found.setUp.count)
        let digest: String = try CelestialEclipseLabTest.digest(shell)
        let clean: [UInt8] = try CelestialEclipseLabTest.still(session)
        let before: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(shell.handle(control: "clock.run") == .accepted)
        let core: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)")
        let failure: CelestialEclipseLabFailure = try #require(core.play.failure)
        #expect(core.outcome?.code == CelestialEclipseLabExperienceCore.failedCode)
        // The words name what the kernel's reason names.
        let named: String = try #require(CelestialEclipseLabMirror.failureText(failure))
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)")
        #expect(shell.presenter.mirror.failureText == named)
        #expect(shell.presenter.mirror.status == "Failed: " + named)
        // The frame: the drawn snapshot is the CPU reference's, nothing moved, the failing mark is red above blue.
        let rgba: [UInt8] = try CelestialEclipseLabTest.still(session)
        let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.failure == failure)
        #expect(snapshot.stage == .failed)
        #expect(snapshot.positions == before.positions && snapshot.phases == before.phases, "a run moves no body")
        #expect(snapshot.shownTick == before.shownTick, "a run shows the same tick")
        let reference: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.coreAfter(
            found.number, found.setUp + [.run])
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's")
        CelestialEclipseLabTest.checkFrame(rgba, snapshot: snapshot, "failed run")
        let mark = try #require(CelestialEclipseLabTest.failingMark(snapshot), "the failing mark is clear")
        #expect(mark.pixel == found.mark && mark.horizon == found.horizon)
        let marked: Bool = CelestialEclipseLabTest.anyPixel(rgba, near: mark.pixel,
                                                            radius: CelestialEclipseLabTest.pointRadius,
                                                            width: CelestialEclipseLabTest.width,
                                                            height: CelestialEclipseLabTest.height,
                                                            where: CelestialEclipseLabTest.isReddish)
        let seen: SIMD3<Double> = CelestialEclipseLabTest.centre(rgba, mark.pixel)
        #expect(marked, "the failing mark at (\(mark.pixel.x), \(mark.pixel.y)) is \(seen), not red above blue")
        // Undo returns the failed play to the moment before the run.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try CelestialEclipseLabTest.digest(shell) == digest)
        let undone: [UInt8] = try CelestialEclipseLabTest.still(session)
        #expect(undone == clean, "undo draws the frame before the run")
        session.qualityPin = 0
    }

    /// Running level 1 after its certified plan through the shell wins; the won frame lights every target mark gold,
    /// keeps every body at the kernel's position, the reference pixels are the same at level-0 and level-2, and the won
    /// frames pass the checks.
    @Test func aWonLevelLightsTheTargetMarks() async throws {
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(1)
        #expect(!plan.isEmpty, "level 1 has a certified plan")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: 0)
        #expect(CelestialEclipseLabTest.issue(shell, plan) == plan.count)
        _ = try CelestialEclipseLabTest.still(session, width: 96, height: 64)
        let arranged: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(!arranged.isWon && !CelestialEclipseLabSceneGeometry.isWon(arranged), "not won before the run")
        #expect(shell.handle(control: "clock.run") == .accepted)
        let core: CelestialEclipseLabExperienceCore = try CelestialEclipseLabTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == CelestialEclipseLabExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        let reference: CelestialEclipseLabSceneSnapshot = try CelestialEclipseLabTest.coreAfter(1, plan + [.run])
            .snapshot(time: 0)
        var pixels: [[SIMD2<Double>?]] = []
        for tier in [0, 2] {
            CelestialEclipseLabTest.pin(session, shell, tier: tier)
            let won: [UInt8] = try CelestialEclipseLabTest.still(session)
            let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level 1 won, tier \(tier)"
            #expect(snapshot.stage == .won, "\(what)")
            #expect(snapshot.isWon && CelestialEclipseLabSceneGeometry.isWon(snapshot), "\(what): won")
            #expect(snapshot == reference, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.positions == CelestialEclipseLabTest.kernelPositions(core.play, tick: 0),
                    "\(what): the drawn bodies are the kernel's positions")
            #expect(snapshot.failure == nil, "\(what): no failure")
            #expect(snapshot.matched == snapshot.target.count, "\(what): every target matched")
            CelestialEclipseLabTest.checkFrame(won, snapshot: snapshot, what)
            checkLitMarks(won, snapshot, what)
            pixels.append(CelestialEclipseLabTest.referencePixels(snapshot))
        }
        #expect(pixels.count == 2 && pixels[0] == pixels[1], "the tier moves no reference point of the won frame")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// Every matched mark of `snapshot` is a filled diamond; each that is clear of every later element that could hide
    /// it is gold in `rgba` (red above blue by 0.08 and 0.25 brighter than the backdrop); at least one is measured.
    private func checkLitMarks(_ rgba: [UInt8], _ snapshot: CelestialEclipseLabSceneSnapshot, _ what: String) {
        let lit: Int = min(max(snapshot.matched, 0), snapshot.intervals.count)
        for j in 0..<lit {
            let material: Double = CelestialEclipseLabSceneGeometry.markMaterial(j, snapshot)
            #expect(material == CelestialEclipseLabSceneGeometry.materialDiamond, "\(what): mark \(j) is lit")
        }
        let sky = CelestialEclipseLabTest.backdrop(snapshot)
        let clear = CelestialEclipseLabTest.clearLitMarks(snapshot)
        var gold: Int = 0
        for entry in clear {
            let back: Double = sky.map { CelestialEclipseLabTest.luminance($0.gradient(x: entry.pixel.x,
                                                                                     y: entry.pixel.y)) } ?? 0
            let floor: Double = back + CelestialEclipseLabTest.bodyMargin
            let shines: Bool = CelestialEclipseLabTest.anyPixel(
                rgba, near: entry.pixel, radius: CelestialEclipseLabTest.pointRadius,
                width: CelestialEclipseLabTest.width, height: CelestialEclipseLabTest.height,
                where: { c in CelestialEclipseLabTest.isReddish(c) && CelestialEclipseLabTest.luminance(c) >= floor })
            if shines {
                gold += 1
            } else {
                let c: SIMD3<Double> = CelestialEclipseLabTest.centre(rgba, entry.pixel)
                Issue.record("\(what): lit mark \(entry.interval) at (\(entry.pixel.x), \(entry.pixel.y)) is \(c)")
            }
        }
        print("celestial-eclipse-lab \(what): lit marks \(lit), measured \(clear.count), gold \(gold)")
        #expect(!clear.isEmpty, "\(what): no lit mark clear of the later elements")
    }

    /// Draws the opening of the level `seed` prepares at the three tiers and checks it against the CPU reference;
    /// returns the body centres measured and whether the first bar and the strip were measured, per tier.
    private func checkOpening(seed: UInt64) async throws -> (bodies: [Int], bars: [Int], strips: [Int]) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await CelestialEclipseLabTest.open(session, seed: seed)
        let level: Int = CelestialEclipseLabExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try CelestialEclipseLabTest.core(shell).levelNumber == level)
        let expectedCore: CelestialEclipseLabExperienceCore = try CelestialEclipseLabExperienceCore.opening(
            number: level)
        let expected: CelestialEclipseLabSceneSnapshot = expectedCore.snapshot(time: 0)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [CelestialEclipseLabSceneSnapshot] = []
        var bodies: [Int] = []
        var bars: [Int] = []
        var strips: [Int] = []
        for tier in 0..<3 {
            CelestialEclipseLabTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try CelestialEclipseLabTest.still(session)
            let snapshot: CelestialEclipseLabSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownTick == 0, "\(what): the shown tick at the opening")
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget, "\(what): nothing spent at the opening")
            #expect(snapshot.chosenBody == CelestialEclipseLabSceneSnapshot.defaultChoice(expectedCore.play.level),
                    "\(what): the default body is chosen")
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.positions == CelestialEclipseLabTest.kernelPositions(expectedCore.play, tick: 0),
                    "\(what): the drawn bodies are the kernel's positions")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            #expect(shell.presenter.scene.lastPulse == 1, "\(what): frame time 0")
            let report: CelestialEclipseLabCheckReport = CelestialEclipseLabTest.checkFrame(rgba, snapshot: snapshot,
                                                                                            what)
            bodies.append(report.bodiesChecked)
            bars.append(report.barChecked ? 1 : 0)
            strips.append(report.stripChecked ? 1 : 0)
            references.append(CelestialEclipseLabTest.referencePixels(snapshot))
            snapshots.append(snapshot)
        }
        // The tier changes no coordinate and nothing measured.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2], "level \(level): tier snapshots")
        #expect(bodies[0] == bodies[1] && bodies[1] == bodies[2], "level \(level): bodies measured \(bodies)")
        #expect(bars[0] == bars[1] && bars[1] == bars[2], "level \(level): bar measured \(bars)")
        session.qualityPin = 0
        return (bodies, bars, strips)
    }
}
#endif
