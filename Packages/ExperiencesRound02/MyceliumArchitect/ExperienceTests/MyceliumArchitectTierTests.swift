// MyceliumArchitectTierTests — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-002, 003, 004, 007; clarifications
// Q1, Q2). The three quality tiers change only the vein tube sides, the cap segments, the hyphae fuzz, the spores and
// the glow shells, never positions or colours: the camera depends on neither the snapshot, the tier nor the time; every
// reference point (the board centre, the root, every terminal, the weight plate's left margin, the first actions bar;
// never a fuzz strand or a spore) projects to the same pixel at every tier; the painter's order takes no tier; the fuzz
// has the tier's strands at every branch point and open cap and the spores the tier's count; richer tiers build more
// board and glow vertices (no glow at level-2); the palette colours drawn (the fallback colours of the board mesh,
// spores and fuzz aside) are the same at every tier; and the time moves no vertex. Through the one app's session host
// every tier's off-screen still passes the same reference at the same pixels; the presenter's tier log records the
// first frame and each change with its reason; the presenter's quality levels are the Core's three tiers; drawing at
// every tier and several frame times, and showing a pulse, leave the state digest and the snapshot payload unchanged
// (renderer purity), the shown pulse draws exactly the segments grown up to it, and a pulse above the pulses run and a
// fractional pulse are refused. Short runs.
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
@Suite(.serialized) struct MyceliumArchitectTierTests {
    /// The three tiers are level-0 … level-2 with tube sides, cap segments, fuzz strands, spores and glow shells as
    /// clarification Q2 lists them; the glow gain falls with the tier and is 0 at level-2.
    @Test func theTiersAreTheCatalogLevels() {
        var names: [String] = []
        var sides: [Int] = []
        var segments: [Int] = []
        var strands: [Int] = []
        var spores: [Int] = []
        var shells: [Int] = []
        var gains: [Double] = []
        for tier in MyceliumArchitectTier.all {
            names.append(tier.name)
            sides.append(tier.tubeSides)
            segments.append(tier.capSegments)
            strands.append(tier.fuzzStrands)
            spores.append(tier.spores)
            shells.append(tier.glowShells)
            gains.append(MyceliumArchitectBoardScene.glowGain(for: tier))
        }
        #expect(names == ["level-0", "level-1", "level-2"])
        #expect(sides == [8, 6, 4])
        #expect(segments == [16, 12, 8])
        #expect(strands == [6, 3, 0])
        #expect(spores == [24, 12, 0])
        #expect(shells == [2, 1, 0])
        #expect(gains[0] > gains[1] && gains[1] > gains[2] && gains[2] == 0, "\(gains)")
        #expect(MyceliumArchitectExperienceCore.qualityTiers == 3)
        #expect(MyceliumArchitectTier.of(-1) == MyceliumArchitectTier.all[0])
        #expect(MyceliumArchitectTier.of(7) == MyceliumArchitectTier.all[2])
    }

    /// The presenter's quality levels are the Core's tiers, by count and by name.
    @Test func thePresentersQualityLevelsAreTheCoresTiers() {
        let shell: ExperienceShell<MyceliumArchitectPresenter> =
            MyceliumArchitectExperience.make(id: MyceliumArchitectTest.id)
        #expect(shell.qualityProfile.count == MyceliumArchitectExperienceCore.qualityTiers)
        var names: [String] = []
        for level in shell.qualityProfile.levels { names.append(level.name) }
        var tierNames: [String] = []
        for tier in MyceliumArchitectTier.all { tierNames.append(tier.name) }
        #expect(names == tierNames)
        #expect(shell.presenter.qualityLevels == tierNames)
        #expect(shell.presenter.qualityLevels.count == MyceliumArchitectExperienceCore.qualityTiers)
        var coreNames: [String] = []
        for level in MyceliumArchitectExperienceCore.qualityProfile.levels { coreNames.append(level.name) }
        #expect(names == coreNames)
    }

    /// CPU: at the opening of levels 1 and 61 and with their certified plan made, every reference point projects;
    /// the fuzz and spores follow the tier; the board and glow meshes shrink with the tier (no glow at level-2); the
    /// colours drawn are the same at every tier; the time moves nothing.
    @Test func everyTierSharesTheSamePositions() throws {
        let numbers: [Int] = [1, 61]
        for number in numbers {
            let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(number)
            let states: [MyceliumArchitectExperienceCore] = [
                try MyceliumArchitectTest.coreAfter(number, []),
                try MyceliumArchitectTest.coreAfter(number, plan),
            ]
            for (stateIndex, core) in states.enumerated() {
                checkPositions(core, "level \(number) state \(stateIndex)")
            }
        }
    }

    /// Through the host, every tier draws the same snapshot at the same reference pixels and passes the frame checks.
    @Test func everyTierDrawsTheSamePositions() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(61)
        let shell = try await MyceliumArchitectTest.open(session, seed: 60, setUp: plan)
        var snapshots: [MyceliumArchitectSceneSnapshot] = []
        var pixels: [[SIMD2<Double>?]] = []
        var measured: [Bool] = []
        for tier in 0..<3 {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MyceliumArchitectTest.still(session)
            let snapshot: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            snapshots.append(snapshot)
            let report: MyceliumArchitectCheckReport = MyceliumArchitectTest.checkFrame(rgba, snapshot: snapshot,
                                                                                        tier: tier,
                                                                                        "level 61 tier \(tier)")
            measured.append(report.capChecked && report.marginChecked)
            pixels.append(MyceliumArchitectTest.referencePixels(snapshot))
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
        let shell = try await MyceliumArchitectTest.open(session, seed: 20)
        let presenter: MyceliumArchitectPresenter = shell.presenter
        #expect(presenter.tierLog == [MyceliumArchitectTierChange(tier: 0, reason: "first frame")])
        let order: [Int] = [1, 2, 0]
        for tier in order {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            try MyceliumArchitectTest.draw(session, frames: 2)
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
        try MyceliumArchitectTest.draw(session, frames: 3)
        #expect(presenter.tierLog.count == 4)
    }

    /// Drawing at every tier and frame time, and showing a pulse, leave the digest and the snapshot payload unchanged
    /// (renderer purity); the shown pulse draws exactly the segments grown up to it; a pulse above the pulses run and a
    /// fractional pulse are refused and change nothing.
    @Test func drawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let plan: [MyceliumArchitectAction] = try MyceliumArchitectTest.certifiedPlan(41)
        let shell = try await MyceliumArchitectTest.open(session, seed: 40, setUp: plan)
        let before: String = try MyceliumArchitectTest.digest(shell)
        let payload: Data = try MyceliumArchitectTest.core(shell).snapshotPayload()
        let times: [Double] = [0, 0.25, 1.3, 7.0, 70.0]
        for tier in 0..<3 {
            MyceliumArchitectTest.pin(session, shell, tier: tier)
            try MyceliumArchitectTest.draw(session, frames: 3)
            for time in times {
                _ = try MyceliumArchitectTest.still(session, width: 96, height: 64, time: time)
            }
            #expect(try MyceliumArchitectTest.digest(shell) == before, "tier \(tier): the digest moved")
            let now: Data = try MyceliumArchitectTest.core(shell).snapshotPayload()
            #expect(now == payload, "tier \(tier): the payload moved")
        }
        // Showing an earlier pulse is presentation only, and draws exactly the segments grown up to it.
        _ = try MyceliumArchitectTest.still(session, width: 96, height: 64)
        let full: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(full.time == 0 && full.shownPulse == full.pulsesRun, "the full growth at time 0")
        #expect(full.pulsesRun >= 1, "the certified plan grows")
        let pulse: Int = full.pulsesRun / 2
        let shown: ActionResult = shell.handle(control: "growth.show", values: [Double(pulse)])
        #expect(shown == .accepted, "\(shown.code)")
        _ = try MyceliumArchitectTest.still(session, width: 96, height: 64)
        let drawn: MyceliumArchitectSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(drawn.shownPulse == pulse, "the pulse is drawn")
        typealias G = MyceliumArchitectSceneGeometry
        var want: [Int] = []
        for index in drawn.grown.indices where index > 0 && drawn.grownPulses[index] <= pulse { want.append(index) }
        var veins: [Int] = []
        for element in G.paintOrder(drawn) where element.kind == .vein { veins.append(element.item) }
        #expect(veins == want, "the veins grown up to pulse \(pulse)")
        let fullVeins: Int = drawn.grown.count - 1
        #expect(veins.count <= fullVeins)
        let best: MyceliumArchitectTier = MyceliumArchitectTier.all[0]
        let partMesh: Mesh = G.board(drawn, tier: best)
        let fullMesh: Mesh = G.board(full, tier: best)
        #expect(partMesh.positions.count <= fullMesh.positions.count, "fewer veins, no more vertices")
        #expect(MyceliumArchitectTest.referencePixels(drawn) == MyceliumArchitectTest.referencePixels(full),
                "the shown pulse moves no reference point")
        #expect(try MyceliumArchitectTest.digest(shell) == before, "showing leaves the digest")
        #expect(try MyceliumArchitectTest.core(shell).snapshotPayload() == payload, "showing leaves the payload")
        // A pulse above the pulses run (inside the declared 0 … 128) and a fractional pulse are refused.
        let refusals: [(value: Double, code: String)] = [
            (Double(full.pulsesRun + 1), "action.rule." + MyceliumArchitectExperienceRule.pulse),
            (0.5, "action.rule." + MyceliumArchitectExperienceRule.notWhole),
        ]
        for refusal in refusals {
            let refused: ActionResult = shell.handle(control: "growth.show", values: [refusal.value])
            #expect(refused.code == refusal.code, "growth.show [\(refusal.value)]: \(refused.code)")
            #expect(try MyceliumArchitectTest.core(shell).shownPulse == pulse)
            #expect(try MyceliumArchitectTest.digest(shell) == before)
        }
        // Showing the full growth again draws the full network.
        #expect(shell.handle(control: "growth.show", values: [Double(full.pulsesRun)]) == .accepted)
        _ = try MyceliumArchitectTest.still(session, width: 96, height: 64)
        #expect(shell.presenter.lastSnapshot == full, "the full growth is drawn again")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// The fallback colours of `part` as text keys, `skip` left out.
    private func colourKeys(_ part: MyceliumArchitectColouredMesh, skip: [Vec4]) -> Set<String> {
        var skipped: Set<String> = []
        for colour in skip { skipped.insert(key(colour)) }
        var keys: Set<String> = []
        for colour in part.colours {
            let k: String = key(colour)
            if !skipped.contains(k) { keys.insert(k) }
        }
        return keys
    }

    /// A colour as a text key (three decimals per channel).
    private func key(_ c: Vec4) -> String {
        String(format: "%.3f %.3f %.3f", c.x, c.y, c.z)
    }

    /// The CPU checks of one state: the reference projects and holds no fuzz strand or spore; the fuzz has the tier's
    /// strands at every branch point and open cap and the spores the tier's count; the board and glow meshes shrink
    /// with the tier; no glow at level-2; the colours drawn are the same at every tier; the time moves nothing.
    private func checkPositions(_ core: MyceliumArchitectExperienceCore, _ what: String) {
        typealias G = MyceliumArchitectSceneGeometry
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.shownPulse == snapshot.pulsesRun, "\(what): the full growth")
        let reference: [SIMD2<Double>?] = MyceliumArchitectTest.referencePixels(snapshot)
        var missing: Int = 0
        for p in reference where p == nil { missing += 1 }
        #expect(reference.count == MyceliumArchitectTest.referenceCount(snapshot),
                "\(what): board centre, root, terminals, weight margin, first bar")
        #expect(missing == 0, "\(what): \(missing) reference points without a projection")
        var openCaps: Int = 0
        for terminal in snapshot.level.terminals.indices where snapshot.isReached(terminal) { openCaps += 1 }
        let branchPoints: Int = G.branchPoints(snapshot).count
        var boardSizes: [Int] = []
        var glowSizes: [Int] = []
        var colourSets: [Set<String>] = []
        let decoration: [Vec4] = [MyceliumArchitectPalette.spore]
        for tier in MyceliumArchitectTier.all {
            let part: MyceliumArchitectColouredMesh = G.boardPart(snapshot, tier: tier)
            #expect(!part.mesh.indices.isEmpty, "\(what) \(tier.name): the board is drawn")
            boardSizes.append(part.mesh.positions.count)
            colourSets.append(colourKeys(part, skip: decoration))
            let glow: Mesh = G.glow(snapshot, tier: tier)
            glowSizes.append(glow.positions.count)
            if tier.glowShells == 0 {
                #expect(glow.indices.isEmpty, "\(what) \(tier.name): no glow")
            }
            // The decoration that moves by time follows the tier; the reference points never include it.
            #expect(G.spores(tier).count == tier.spores, "\(what) \(tier.name): spores")
            let strands: Int = G.fuzzStrands(snapshot, tier: tier).count
            #expect(strands == tier.fuzzStrands * (branchPoints + openCaps), "\(what) \(tier.name): fuzz strands")
        }
        // Coarser tubes and caps and less fuzz and fewer spores on cheaper tiers; fewer glow shells.
        #expect(boardSizes[0] > boardSizes[1] && boardSizes[1] > boardSizes[2], "\(what): \(boardSizes)")
        #expect(glowSizes[0] > glowSizes[1] && glowSizes[1] > glowSizes[2], "\(what): \(glowSizes)")
        // The colours drawn (spores and fuzz aside) are the same at every tier.
        #expect(colourSets[0] == colourSets[1] && colourSets[1] == colourSets[2], "\(what): the tier changes a colour")
        // The paint order is the same for every tier and time (it takes no tier), and the time moves no vertex.
        let later: MyceliumArchitectSceneSnapshot = core.snapshot(time: 7.5)
        #expect(MyceliumArchitectTest.referencePixels(later) == reference, "\(what): time moves nothing")
        #expect(G.paintOrder(later) == G.paintOrder(snapshot), "\(what): time changes no element")
        let best: MyceliumArchitectTier = MyceliumArchitectTier.all[0]
        #expect(G.board(later, tier: best).positions == G.board(snapshot, tier: best).positions,
                "\(what): the time moves no vertex")
        #expect(G.glow(later, tier: best).positions == G.glow(snapshot, tier: best).positions,
                "\(what): the time moves no glow vertex")
    }
}
#endif
