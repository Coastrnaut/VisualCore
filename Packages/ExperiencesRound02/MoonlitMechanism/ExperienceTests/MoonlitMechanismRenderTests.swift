// MoonlitMechanismRenderTests — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-001 … 003, 006, 007;
// SC-R02G1403-001, 002; clarifications Q1, Q3, Q4). Through the one app's session host, drawn off screen at the
// frame-check size of `MoonlitMechanismTest` (1,152 × 768) at frame time 0: catalog levels 1, 21, 41, 61 and 81 (seeds
// 0, 20, 40, 60, 80) at their opening, at each quality tier level-0, level-1 and level-2, match the Core's CPU
// reference of the presenter's last snapshot: at every point at least 6 px from every element drawn over it that could
// hide it, a cast cell's centre is darker than the paper by 0.25 in luminance; a gear's rim point has red above blue by
// 0.08; the first moves bar is 0.1 from the paper (and lit where no gear covers it); the two probe corners are within
// 0.05 of the night; the reference pixels and the drawn snapshot are the same at every tier; each tier measures at
// least one cast-cell centre and one rim point summed over the five levels. The presenter declares no frame probe
// before it drew a snapshot and two night corners after, which match the drawn still at every tier. A failed run
// outlines in the broken colour #FF6B4A what the kernel's reason names — the jammed pair's meshing teeth, the forbidden
// cell, the failing key frame's card — (each found by a short search of the kernel's rules on catalog levels), the
// description and the mirror name it in words, and undo draws the frame before the run again; a won level brightens the
// wall (the won wall's glow shells outside the paper at level-0 and the paper lifted toward the glow colour at
// level-2). Each test well under 10 s.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct MoonlitMechanismRenderTests {
    /// The catalog levels searched for a failing set-up, the checked ones first.
    static let failureLevels: [Int] = [1, 21, 41, 61, 81, 11, 31, 51, 71, 91]

    /// Every tier of the five levels' openings matches the CPU reference at the same reference pixels; each tier
    /// measures at least one cast-cell centre and one rim point summed over the levels (a level whose geometry admits
    /// no clear point of a kind is not required to have one).
    @Test func everyTierMatchesTheReferenceOnFiveLevels() async throws {
        var cells: [Int] = [0, 0, 0]
        var rims: [Int] = [0, 0, 0]
        for seed in MoonlitMechanismTest.seeds {
            let counts = try await checkLevel(seed: seed)
            for tier in 0..<3 {
                cells[tier] += counts.cells[tier]
                rims[tier] += counts.rims[tier]
            }
        }
        print("moonlit-mechanism five levels: cells per tier \(cells), rims per tier \(rims)")
        for tier in 0..<3 {
            #expect(cells[tier] > 0, "tier \(tier): no cast-cell centre measured on the five levels")
            #expect(rims[tier] > 0, "tier \(tier): no rim point measured on the five levels")
        }
    }

    /// No frame probe before a snapshot was drawn; after a frame, the two night corners match the drawn still at
    /// every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let fresh: ExperienceShell<MoonlitMechanismPresenter> =
            MoonlitMechanismExperience.make(id: MoonlitMechanismTest.id)
        let opening: MoonlitMechanismExperienceCore = try MoonlitMechanismExperienceCore.opening(number: 41)
        #expect(fresh.presenter.probes(opening).isEmpty, "no probe before a frame")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: 40)
        for tier in 0..<3 {
            MoonlitMechanismTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try MoonlitMechanismTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = MoonlitMechanismTest.bottomUp(still, width: MoonlitMechanismTest.width,
                                                              height: MoonlitMechanismTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try MoonlitMechanismTest.core(shell))
            #expect(probes.count == 2, "tier \(tier): two night corners")
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: MoonlitMechanismTest.width,
                                              height: MoonlitMechanismTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// A jam outlines the jammed pair's meshing teeth on both gears.
    @Test func aJamOutlinesTheMeshingTeeth() async throws {
        try await checkFailureOutline(.jammed, maxDepth: 2)
    }

    /// A forbidden shadow outlines the forbidden cell.
    @Test func aForbiddenShadowOutlinesTheCell() async throws {
        try await checkFailureOutline(.forbidden, maxDepth: 3)
    }

    /// A required key frame that misses target cells or strays outlines its card.
    @Test func aFailingKeyFrameOutlinesItsCard() async throws {
        try await checkFailureOutline(.card, maxDepth: 2)
    }

    /// Playing the certified solution of level 41 through the shell wins; the won frame brightens the wall: at level-0
    /// the won wall's glow shells lift the night just outside the paper, at level-2 (no glow) the paper is lifted
    /// toward the glow colour (its blue falls), and the won frames pass the checks.
    @Test func aWonLevelBrightensTheWall() async throws {
        let actions: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(41)
        #expect(actions.last == .run, "the solution ends with a run")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: 40)
        let moves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(41)
        #expect(MoonlitMechanismTest.issue(shell, moves) == moves.count)
        MoonlitMechanismTest.pin(session, shell, tier: 0)
        let before0: [UInt8] = try MoonlitMechanismTest.still(session)
        let arranged: MoonlitMechanismSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(MoonlitMechanismSceneGeometry.wonFlag(arranged) == 0)
        MoonlitMechanismTest.pin(session, shell, tier: 2)
        let before2: [UInt8] = try MoonlitMechanismTest.still(session)
        #expect(shell.handle(control: "machine.run") == .accepted)
        let core: MoonlitMechanismExperienceCore = try MoonlitMechanismTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage)")
        #expect(core.outcome?.code == MoonlitMechanismExperienceCore.wonCode)
        _ = shell.presenter.describe(core)
        #expect(shell.presenter.mirror.status == "Won")
        #expect(shell.presenter.mirror.failureText == nil)
        let won2: [UInt8] = try MoonlitMechanismTest.still(session)
        let snapshot: MoonlitMechanismSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.stage == .won)
        #expect(MoonlitMechanismSceneGeometry.wonFlag(snapshot) == 1)
        #expect(snapshot.phases == arranged.phases && snapshot.cast == arranged.cast, "nothing moves on a win")
        MoonlitMechanismTest.checkFrame(won2, snapshot: snapshot, require: false, "level 41 won, level-2")
        // Level-2: the paper is lifted toward the glow colour (blue #C8 toward #B0) over a wide area.
        let drops: Int = MoonlitMechanismTest.bluerDrops(won2, before2)
        #expect(drops >= 5_000, "the won paper is lifted toward the glow colour: \(drops) pixels")
        // Level-0: the wall's glow shells lift the night just outside the paper.
        MoonlitMechanismTest.pin(session, shell, tier: 0)
        let won0: [UInt8] = try MoonlitMechanismTest.still(session)
        MoonlitMechanismTest.checkFrame(won0, snapshot: snapshot, require: false, "level 41 won, level-0")
        let samples: [SIMD2<Double>] = MoonlitMechanismTest.wallGlowSamples(snapshot)
        #expect(!samples.isEmpty, "a point outside the paper clear of the gears and the lamp")
        var brighter: Int = 0
        for p in samples {
            let was: Double = MoonlitMechanismTest.luminance(MoonlitMechanismTest.centre(before0, p))
            let now: Double = MoonlitMechanismTest.luminance(MoonlitMechanismTest.centre(won0, p))
            let note: String = String(format: "wall glow at (%.1f, %.1f): %.3f → %.3f", p.x, p.y, was, now)
            #expect(now >= was + 0.04, "\(note)")
            if now >= was + 0.04 { brighter += 1 }
        }
        print("moonlit-mechanism won wall: \(brighter) of \(samples.count) glow points brighter; \(drops) paper pixels")
        session.qualityPin = 0
    }

    // MARK: Helpers

    /// Draws the opening of the level `seed` prepares at the three tiers and checks it against the CPU reference;
    /// returns the cast-cell centres and rim points measured per tier.
    private func checkLevel(seed: UInt64) async throws -> (cells: [Int], rims: [Int]) {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: seed)
        let level: Int = MoonlitMechanismExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try MoonlitMechanismTest.core(shell).levelNumber == level)
        let expected: MoonlitMechanismSceneSnapshot = try MoonlitMechanismExperienceCore.opening(number: level)
            .snapshot(time: 0)
        let litLuminance: Double = MoonlitMechanismTest.luminance(MoonlitMechanismPalette.movesLit)
        var references: [[SIMD2<Double>?]] = []
        var snapshots: [MoonlitMechanismSceneSnapshot] = []
        var cells: [Int] = []
        var rims: [Int] = []
        for tier in 0..<3 {
            MoonlitMechanismTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try MoonlitMechanismTest.still(session)
            let snapshot: MoonlitMechanismSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.time == 0, "\(what): time \(snapshot.time)")
            #expect(snapshot.shownFrame == 0)
            #expect(snapshot.stage == .playing, "\(what): \(snapshot.stage)")
            #expect(snapshot.actionsLeft == snapshot.budget, "\(what): nothing spent at the opening")
            #expect(snapshot.failure == nil)
            #expect(snapshot == expected, "\(what): the drawn snapshot is the CPU reference's")
            #expect(snapshot.cast == expected.report.frames[0].cast, "\(what): the drawn shadows are the kernel's")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            let report: MoonlitMechanismCheckReport = MoonlitMechanismTest.checkFrame(rgba, snapshot: snapshot,
                                                                                      require: false, what)
            cells.append(report.cellChecked)
            rims.append(report.rimChecked)
            references.append(MoonlitMechanismTest.referencePixels(snapshot))
            snapshots.append(snapshot)
            // An uncovered first moves bar is lit at the opening (emissive: the lit colour at its centre).
            let p: SIMD2<Double> = try #require(MoonlitMechanismTest.movesPixel(snapshot))
            let o: MoonlitMechanismObstacles = MoonlitMechanismTest.obstacles(snapshot)
            if MoonlitMechanismTest.isMovesUncovered(p, o) {
                let c: SIMD3<Double> = MoonlitMechanismTest.centre(rgba, p)
                let lum: Double = MoonlitMechanismTest.luminance(c)
                #expect(Swift.abs(lum - litLuminance) <= 0.05, "\(what): moves bar 0 is \(c)")
            }
        }
        // The tier changes no coordinate and nothing measured.
        #expect(references[0] == references[1] && references[1] == references[2], "level \(level): tier coordinates")
        #expect(snapshots[0] == snapshots[1] && snapshots[1] == snapshots[2], "level \(level): tier snapshots")
        #expect(cells[0] == cells[1] && cells[1] == cells[2], "level \(level): cells measured \(cells)")
        session.qualityPin = 0
        return (cells, rims)
    }

    /// Plays a script that fails as `kind` (found on the catalog levels by a short search of the kernel's rules) at
    /// level-2, where nothing glows, and checks the failure, its words and its outline against the frame before the
    /// run; undo draws the frame before the run again.
    private func checkFailureOutline(_ kind: MoonlitMechanismFailureKind, maxDepth: Int,
                                     sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let found = try #require(try MoonlitMechanismTest.failureCase(kind, candidates: Self.failureLevels,
                                                                      maxDepth: maxDepth),
                                 "a catalog level with a \(kind.rawValue) failure within \(maxDepth) moves",
                                 sourceLocation: sourceLocation)
        print("moonlit-mechanism \(kind.rawValue): level \(found.number), actions \(found.actions)")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await MoonlitMechanismTest.open(session, seed: UInt64(found.number - 1))
        MoonlitMechanismTest.pin(session, shell, tier: 2)
        let setUp: [MoonlitMechanismAction] = Array(found.actions.dropLast())
        #expect(MoonlitMechanismTest.issue(shell, setUp) == setUp.count, sourceLocation: sourceLocation)
        let digest: String = try MoonlitMechanismTest.digest(shell)
        _ = try MoonlitMechanismTest.still(session)
        let clean: [UInt8] = try MoonlitMechanismTest.still(session)
        #expect(shell.handle(control: "machine.run") == .accepted, sourceLocation: sourceLocation)
        let core: MoonlitMechanismExperienceCore = try MoonlitMechanismTest.core(shell)
        #expect(core.play.stage == .failed, "\(core.play.stage)", sourceLocation: sourceLocation)
        let failure: MoonlitMechanismFailure = try #require(core.play.failure, sourceLocation: sourceLocation)
        #expect(kind.matches(failure), "\(failure)", sourceLocation: sourceLocation)
        #expect(core.outcome?.code == MoonlitMechanismExperienceCore.failedCode, sourceLocation: sourceLocation)
        // The words name what the kernel's reason names.
        let named: String = try #require(MoonlitMechanismMirror.failureText(failure), sourceLocation: sourceLocation)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains(named), "\(text)", sourceLocation: sourceLocation)
        #expect(shell.presenter.mirror.failureText == named, sourceLocation: sourceLocation)
        #expect(shell.presenter.mirror.status == "Failed: " + named, sourceLocation: sourceLocation)
        // The frame: the drawn snapshot is the CPU reference's, and the outline is where it says.
        let rgba: [UInt8] = try MoonlitMechanismTest.still(session)
        let snapshot: MoonlitMechanismSceneSnapshot = try #require(shell.presenter.lastSnapshot,
                                                                  sourceLocation: sourceLocation)
        #expect(snapshot.failure == failure, sourceLocation: sourceLocation)
        let reference: MoonlitMechanismExperienceCore = try MoonlitMechanismTest.coreAfter(found.number, found.actions)
        #expect(snapshot == reference.snapshot(time: 0), "the drawn snapshot is the CPU reference's",
                sourceLocation: sourceLocation)
        switch kind {
        case .jammed:
            #expect(MoonlitMechanismSceneGeometry.jammedPair(snapshot) != nil, sourceLocation: sourceLocation)
        case .forbidden:
            #expect(MoonlitMechanismSceneGeometry.brokenCell(snapshot) != nil, sourceLocation: sourceLocation)
        case .card:
            #expect(MoonlitMechanismSceneGeometry.failingCard(snapshot) != nil, sourceLocation: sourceLocation)
        }
        MoonlitMechanismTest.checkFrame(rgba, snapshot: snapshot, require: false, "\(kind.rawValue) failure",
                                        sourceLocation: sourceLocation)
        let samples: [SIMD2<Double>] = found.samples
        let hits: Int = MoonlitMechanismTest.outlineHits(rgba, clean, samples)
        #expect(hits * 2 > samples.count,
                "the \(kind.rawValue) outline in #FF6B4A (\(hits) of \(samples.count) points)",
                sourceLocation: sourceLocation)
        // Undo returns the failed play to the set-up before the run, without the outline.
        #expect(shell.handle(control: "play.undo") == .accepted, sourceLocation: sourceLocation)
        #expect(try MoonlitMechanismTest.digest(shell) == digest, sourceLocation: sourceLocation)
        let undone: [UInt8] = try MoonlitMechanismTest.still(session)
        #expect(MoonlitMechanismTest.outlineHits(undone, clean, samples) == 0, "undo removes the outline",
                sourceLocation: sourceLocation)
        #expect(undone == clean, "undo draws the frame before the run", sourceLocation: sourceLocation)
        session.qualityPin = 0
    }
}
#endif
