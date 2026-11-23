// EchoCartographerRenderTests — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-001 … 003, 006, 007;
// SC-R02G1103-001; clarifications Q1, Q3, Q5). Through the one app's session host, drawn off screen at the frame-check
// size of `EchoCartographerTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80), at the
// opening and after one pulse from the entry (so walls are known), at each quality tier level-0, level-1 and level-2,
// match the Core's CPU reference of the presenter's last snapshot: at every point at least 6 px from every other
// element, a known floor tile's centre is 0.1 from the ground in luminance; a known wall's top-face centre is 0.08 from
// the ground with green above red by 0.05; the gauge's first bar is 0.1 from the ground (and lit: the gauge-lit
// colour's luminance); the two probe corners are within 0.05 of the ground. The presenter's frame probes (two ground
// corners) match the drawn still at every tier. A pulse changes the digest and the frame, undo restores the digest and
// redo the pulsed one; refused actions change nothing. Playing the certified solution of level 1 wins and says so.
// Each test well under 10 s.
#if os(iOS)
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct EchoCartographerRenderTests {
    /// Every tier, after one pulse from the entry, matches the CPU reference.
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: seed)
        let level: Int = EchoCartographerExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try EchoCartographerTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too (no wall known yet; every gauge bar lit).
        let opening: [UInt8] = try EchoCartographerTest.still(session)
        let openingSnapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.energy == openingSnapshot.budget)
        #expect(openingSnapshot.lastEcho == nil)
        #expect(openingSnapshot.wallCells.isEmpty)
        let openingWhat: String = "level \(level) opening"
        EchoCartographerTest.checkFrame(opening, snapshot: openingSnapshot, known: false, openingWhat)
        let before: String = try EchoCartographerTest.digest(shell)
        #expect(try EchoCartographerTest.advance(shell), "level \(level): the pulse from the entry was accepted")
        #expect(try EchoCartographerTest.digest(shell) != before, "level \(level): the play advanced")
        let expected: EchoCartographerExperienceCore = try EchoCartographerTest.advanced(level)
        let expectedKnowledge: [EchoCartographerKnown] = expected.play.knowledge.cells
        let litLuminance: Double = EchoCartographerTest.luminance(EchoCartographerPalette.gaugeLit)
        for tier in 0..<3 {
            EchoCartographerTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try EchoCartographerTest.still(session)
            let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let what: String = "level \(level) tier \(tier)"
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.energy == snapshot.budget - 1, "\(what): one pulse spent")
            #expect(snapshot.knowledge == expectedKnowledge, "\(what): the drawn knowledge is the kernel's")
            #expect(!snapshot.wallCells.isEmpty, "\(what): the pulse revealed a wall")
            let reason: String = shell.presenter.fallbackReason ?? ""
            #expect(shell.presenter.fallbackReason == nil, "\(reason)")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, what)
            // The gauge's first bar is lit (emissive: the lit colour itself at its centre).
            let p: SIMD2<Double> = try #require(EchoCartographerTest.gaugePixel(snapshot))
            let c: SIMD3<Double> = EchoCartographerTest.centre(rgba, p, width: EchoCartographerTest.width,
                                                               height: EchoCartographerTest.height)
            let lum: Double = EchoCartographerTest.luminance(c)
            #expect(Swift.abs(lum - litLuminance) <= 0.05, "\(what): gauge bar 0 is \(c)")
        }
        session.qualityPin = 0
    }

    /// A pulse changes the digest and the frame; undo restores the digest, redo the pulsed one.
    @Test func aPulseChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 20)
        let before: String = try EchoCartographerTest.digest(shell)
        let first: [UInt8] = try EchoCartographerTest.still(session)
        #expect(try EchoCartographerTest.advance(shell))
        let pulsed: String = try EchoCartographerTest.digest(shell)
        #expect(pulsed != before, "a pulse changes the digest")
        let rgba: [UInt8] = try EchoCartographerTest.still(session)
        let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.energy == snapshot.budget - 1, "the frame draws the pulsed state")
        #expect(snapshot.lastEcho != nil)
        // Walls, floor tiles and rays appear and a gauge bar goes out: the frame changes.
        #expect(rgba != first, "a pulse changes the frame")
        EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, "level 21 after the pulse")
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try EchoCartographerTest.digest(shell) == before)
        let undone: [UInt8] = try EchoCartographerTest.still(session)
        let undoneSnapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(undoneSnapshot.energy == undoneSnapshot.budget)
        #expect(undoneSnapshot.lastEcho == nil)
        #expect(undoneSnapshot.wallCells.isEmpty)
        EchoCartographerTest.checkFrame(undone, snapshot: undoneSnapshot, known: false, "level 21 undone")
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try EchoCartographerTest.digest(shell) == pulsed)
    }

    /// Refused actions change neither the digest nor the frame's reference.
    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        let before: String = try EchoCartographerTest.digest(shell)
        let core: EchoCartographerExperienceCore = try EchoCartographerTest.core(shell)
        let w: Int = core.play.level.chamber.width
        let entry: EchoCartographerCell = core.play.level.entry
        #expect(shell.handle(control: "cell.pulse", values: [0.5, Double(entry.y)]) != .accepted, "a fractional column")
        #expect(shell.handle(control: "cell.pulse", values: [5, 5]) != .accepted, "a pulse from an unknown cell")
        #expect(shell.handle(control: "cell.pulse", values: [Double(w), 0]) != .accepted, "a cell outside the chamber")
        #expect(shell.handle(control: "cell.pulse", values: [16, 0]) != .accepted, "outside the declared range")
        #expect(shell.handle(control: "cell.pulse", values: [Double(entry.x)]) != .accepted, "one value")
        #expect(shell.handle(control: "play.undo") != .accepted, "nothing to undo")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(shell.handle(control: "wave.reverse", values: [0, 1]) != .accepted, "an undeclared control")
        #expect(try EchoCartographerTest.digest(shell) == before)
        let rgba: [UInt8] = try EchoCartographerTest.still(session)
        let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.energy == snapshot.budget)
        #expect(snapshot.lastEcho == nil)
        EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, known: false, "level 1 after refusals")
    }

    /// The presenter's frame probes (two ground corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        try EchoCartographerTest.advance(shell)
        for tier in 0..<3 {
            EchoCartographerTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try EchoCartographerTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = EchoCartographerTest.bottomUp(still, width: EchoCartographerTest.width,
                                                              height: EchoCartographerTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try EchoCartographerTest.core(shell))
            var names: [String] = []
            for probe in probes { names.append(probe.name) }
            #expect(names == ["ground-top-left", "ground-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: EchoCartographerTest.width,
                                              height: EchoCartographerTest.height)
                let seen: String = found?.rawValue ?? "none"
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(seen)")
            }
        }
        session.qualityPin = 0
    }

    /// Playing the certified solution of level 1 through the shell wins: the description says so and the frame passes
    /// the checks (the located beacon's pillar stands on its cell).
    @Test func theCertifiedSolutionWins() async throws {
        let actions: [EchoCartographerAction] = try EchoCartographerTest.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await EchoCartographerTest.open(session, seed: 0)
        let before: String = try EchoCartographerTest.digest(shell)
        for (index, action) in actions.enumerated() {
            let issued = EchoCartographerTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "action \(index) \(issued.control) \(issued.values): \(result.code)")
        }
        #expect(try EchoCartographerTest.digest(shell) != before)
        let core: EchoCartographerExperienceCore = try EchoCartographerTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage.rawValue)")
        #expect(core.outcome?.code == EchoCartographerExperienceCore.wonCode)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("Every beacon is located."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        let rgba: [UInt8] = try EchoCartographerTest.still(session)
        let snapshot: EchoCartographerSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.stage == .won)
        #expect(snapshot.located.count == core.play.level.beacons.count)
        #expect(snapshot.located == core.play.level.beacons, "the located pillar stands on the beacon's cell")
        EchoCartographerTest.checkFrame(rgba, snapshot: snapshot, "level 1 won")
    }
}
#endif
