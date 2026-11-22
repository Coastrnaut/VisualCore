// AmethystEscapeRenderTests — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-001 … 003, 006; SC-R02G0703-001;
// clarifications Q1, Q3). Through the one app's session host, drawn off screen at the frame-check size of
// `AmethystEscapeTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80), opening and
// after one turn of the innermost shell, at each quality tier level-0, level-1 and level-2, match the Core's CPU
// reference of the presenter's last snapshot: the pearl centre within 3 px of a pixel 0.15 brighter than the backdrop,
// the exit arrow at least 0.1 away from the backdrop, every open wedge top at least 0.05 away from the backdrop, the two
// probe corners within 0.05 of the backdrop. The presenter's frame probes (two backdrop corners) match the drawn still
// at every tier. A turn changes the digest and the frame, undo restores both. Playing the certified solution of level 1
// wins: the description says the pearl escaped and the pearl is drawn at the exit. One test per level, each well under
// 10 s.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
@Suite(.serialized) struct AmethystEscapeRenderTests {
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: seed)
        let level: Int = AmethystEscapeExperienceCore.levelNumber(forSeed: seed)
        #expect(level == Int(seed) + 1)
        #expect(try AmethystEscapeTest.core(shell).levelNumber == level)
        // The opening frame passes the checks too.
        let opening: [UInt8] = try AmethystEscapeTest.still(session)
        let openingSnapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(openingSnapshot.moves == 0)
        #expect(openingSnapshot.stage == .playing)
        AmethystEscapeTest.checkFrame(opening, snapshot: openingSnapshot, "level \(level) opening")
        let before: String = try AmethystEscapeTest.digest(shell)
        #expect(AmethystEscapeTest.advance(shell) == 1, "level \(level): the turn was accepted")
        #expect(try AmethystEscapeTest.digest(shell) != before, "level \(level): the play advanced")
        for tier in 0..<3 {
            AmethystEscapeTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try AmethystEscapeTest.still(session)
            let snapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.time == 0, "the still's frame time is 0")
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.moves == 1, "level \(level): one move spent")
            #expect(snapshot.shells.first?.offset == 1, "level \(level): the innermost shell turned")
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            AmethystEscapeTest.checkFrame(rgba, snapshot: snapshot, "level \(level) tier \(tier)")
            let wedges = AmethystEscapeTest.wedgeMisses(rgba, snapshot: snapshot)
            print("amethyst-escape level \(level) tier \(tier): open wedges checked \(wedges.checked), shells "
                  + "\(snapshot.shells.count), sectors \(snapshot.sectors), stage \(snapshot.stage.rawValue)")
        }
        session.qualityPin = 0
    }

    @Test func aTurnChangesTheFrameAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 20)
        let before: String = try AmethystEscapeTest.digest(shell)
        let first: [UInt8] = try AmethystEscapeTest.still(session)
        let result: ActionResult = shell.handle(control: "shell.rotate", values: [0, 1])
        #expect(result == .accepted, "\(result.code)")
        let turned: String = try AmethystEscapeTest.digest(shell)
        #expect(turned != before, "a turn changes the digest")
        let rgba: [UInt8] = try AmethystEscapeTest.still(session)
        let snapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.moves == 1, "the frame draws the turned state")
        // The wedges of the innermost shell move a sector and the move bar grows: the frame changes.
        #expect(rgba != first, "a turn changes the frame")
        AmethystEscapeTest.checkFrame(rgba, snapshot: snapshot, "level 21 after a turn")
        // Undo restores the earlier digest exactly and the frame is the first one again.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try AmethystEscapeTest.digest(shell) == before)
        let undone: [UInt8] = try AmethystEscapeTest.still(session)
        #expect(undone == first, "undo draws the first frame again")
        // Redo returns to the turned digest.
        #expect(shell.handle(control: "play.redo") == .accepted)
        #expect(try AmethystEscapeTest.digest(shell) == turned)
    }

    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0)
        let before: String = try AmethystEscapeTest.digest(shell)
        #expect(shell.handle(control: "shell.rotate", values: [0, 0]) != .accepted, "a turn by 0 is refused")
        #expect(shell.handle(control: "shell.rotate", values: [0, 0.5]) != .accepted, "a fractional step is refused")
        #expect(shell.handle(control: "shell.rotate", values: [9, 1]) != .accepted, "an unknown shell is refused")
        #expect(shell.handle(control: "play.undo") != .accepted, "nothing to undo")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(try AmethystEscapeTest.digest(shell) == before)
        let rgba: [UInt8] = try AmethystEscapeTest.still(session)
        let snapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.moves == 0)
        AmethystEscapeTest.checkFrame(rgba, snapshot: snapshot, "level 1 after refusals")
    }

    /// The presenter's frame probes (two backdrop corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0)
        AmethystEscapeTest.advance(shell)
        for tier in 0..<3 {
            AmethystEscapeTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try AmethystEscapeTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let rgba: [UInt8] = AmethystEscapeTest.bottomUp(still, width: AmethystEscapeTest.width,
                                                            height: AmethystEscapeTest.height)
            let probes: [FrameProbe] = shell.presenter.probes(try AmethystEscapeTest.core(shell))
            var names: [String] = []
            for probe in probes { names.append(probe.name) }
            #expect(names == ["backdrop-top-left", "backdrop-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: AmethystEscapeTest.width,
                                              height: AmethystEscapeTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }

    /// Playing the certified solution of level 1 through the shell wins: the description says the pearl escaped and the
    /// pearl is drawn at the exit.
    @Test func theCertifiedSolutionDrawsThePearlAtTheExit() async throws {
        let actions: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AmethystEscapeTest.open(session, seed: 0)
        let before: String = try AmethystEscapeTest.digest(shell)
        for (index, action) in actions.enumerated() {
            let issued = AmethystEscapeTest.control(action)
            let result: ActionResult = shell.handle(control: issued.control, values: issued.values)
            #expect(result == .accepted, "action \(index) \(issued.control) \(issued.values): \(result.code)")
        }
        #expect(try AmethystEscapeTest.digest(shell) != before)
        let core: AmethystEscapeExperienceCore = try AmethystEscapeTest.core(shell)
        #expect(core.play.stage == .won, "\(core.play.stage.rawValue)")
        #expect(core.outcome?.code == AmethystEscapeExperienceCore.wonCode)
        let text: String = shell.presenter.describe(core)
        #expect(text.contains("The pearl escaped through the exit gap."), "\(text)")
        #expect(text.contains("The pearl is outside the crystal."), "\(text)")
        #expect(shell.presenter.mirror.status == "Won")
        let rgba: [UInt8] = try AmethystEscapeTest.still(session)
        let snapshot: AmethystEscapeSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.escaped)
        #expect(snapshot.moves == actions.count)
        // The pearl's centre is the exit arrow's centre, and a lit pixel lies there.
        #expect(AmethystEscapeSceneGeometry.pearlCentre(snapshot) == AmethystEscapeSceneGeometry.exitCentre(snapshot))
        let pearl: Vec2 = try #require(AmethystEscapeTest.pearlPixel(snapshot))
        let exit: Vec2 = try #require(AmethystEscapeTest.exitPixel(snapshot))
        #expect(pearl == exit)
        AmethystEscapeTest.checkFrame(rgba, snapshot: snapshot, "level 1 won")
        print("amethyst-escape level 1 won in \(actions.count) moves; pearl drawn at (\(exit.x), \(exit.y))")
    }
}
#endif
