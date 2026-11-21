// HueCompassRenderTests — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-001 … 003, 006; SC-R02G0403-001;
// clarifications Q1, Q3). Through the one app's session host, drawn off screen at the frame-check size of
// `HueCompassTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60, 80) at each quality tier
// level-0, level-1 and level-2 match the Core's CPU reference of the presenter's last snapshot (needle tip within 3 px of
// a pixel 0.15 brighter than night, band samples within 0.15 of their band colour away from the needle, background
// within 0.05 of night); after one or two probes the probe marks are lit too, at every tier; a turn changes the digest,
// the needle follows it in the frame and undo restores the digest. One test per level, each well under 10 s.
#if os(iOS)
import Foundation
import HueCompassCore
import Testing
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct HueCompassRenderTests {
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: seed)
        let level: Int = HueCompassExperienceCore.levelNumber(forSeed: seed)
        #expect(try HueCompassTest.core(shell).levelNumber == level)
        for tier in 0..<3 {
            HueCompassTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try HueCompassTest.still(session)
            let snapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.time == 0, "the still's frame time is 0")
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.clues.isEmpty && snapshot.selection == nil && snapshot.target == nil)
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            HueCompassTest.checkFrame(rgba, snapshot: snapshot, "level \(level) tier \(tier)")
        }
        // Probes add pearl marks; the frame still matches at every tier.
        let before: String = try HueCompassTest.digest(shell)
        let probes: Int = try HueCompassTest.probeTwice(shell)
        #expect(probes >= 1, "level \(level): a probe was accepted")
        #expect(try HueCompassTest.digest(shell) != before, "a probe changes the digest")
        for tier in 0..<3 {
            HueCompassTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try HueCompassTest.still(session)
            let snapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(!snapshot.clues.isEmpty)
            #expect(HueCompassSceneGeometry.probeBearings(snapshot).count == probes)
            HueCompassTest.checkFrame(rgba, snapshot: snapshot, "level \(level) tier \(tier) after \(probes) probes")
            let marks = HueCompassTest.markMisses(rgba, snapshot: snapshot)
            print("hue-compass level \(level) tier \(tier): marks checked \(marks.checked), band segments checked "
                  + "\(HueCompassTest.bandMisses(rgba, snapshot: snapshot).checked) of 24")
        }
        session.qualityPin = 0
    }

    @Test func aTurnMovesTheNeedleAndUndoRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 40)
        let start: HueCompassExperienceCore = try HueCompassTest.core(shell)
        let before: String = try HueCompassTest.digest(shell)
        let first: [UInt8] = try HueCompassTest.still(session)
        let firstSnapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        HueCompassTest.checkFrame(first, snapshot: firstSnapshot, "level 41 at the start")
        let result: ActionResult = shell.handle(control: "compass.turn", values: [24])
        #expect(result == .accepted, "\(result.code)")
        #expect(try HueCompassTest.digest(shell) != before, "a turn changes the digest")
        let turned: HueCompassExperienceCore = try HueCompassTest.core(shell)
        #expect(turned.play.bearing == (start.play.bearing + 24) % 96)
        let rgba: [UInt8] = try HueCompassTest.still(session)
        let snapshot: HueCompassSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.bearing == turned.play.bearing, "the frame draws the turned needle")
        HueCompassTest.checkFrame(rgba, snapshot: snapshot, "level 41 after compass.turn")
        #expect(rgba != first, "the turned needle changes the frame")
        // Undo restores the earlier digest exactly and the frame is the first one again.
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try HueCompassTest.digest(shell) == before)
        let undone: [UInt8] = try HueCompassTest.still(session)
        HueCompassTest.checkFrame(undone, snapshot: try #require(shell.presenter.lastSnapshot), "level 41 after undo")
        #expect(undone == first, "undo draws the first frame again")
    }

    @Test func aRefusedActionChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 20)
        let before: String = try HueCompassTest.digest(shell)
        #expect(shell.handle(control: "compass.turn", values: [0]) != .accepted, "a turn of 0 is refused")
        #expect(shell.handle(control: "play.redo") != .accepted, "nothing to redo")
        #expect(try HueCompassTest.digest(shell) == before)
        let rgba: [UInt8] = try HueCompassTest.still(session)
        HueCompassTest.checkFrame(rgba, snapshot: try #require(shell.presenter.lastSnapshot), "level 21 after refusals")
    }

    /// Gate X-R02-G04: the presenter's frame probes (two night corners) match the drawn still at every tier.
    @Test func theFrameProbesMatchTheDrawnFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await HueCompassTest.open(session, seed: 0)
        for tier in 0..<3 {
            HueCompassTest.pin(session, shell, tier: tier)
            let still: [UInt8] = try HueCompassTest.still(session)
            // The still is top-down; FrameChecks reads rows bottom-up, as RenderHost.readPixels gives them.
            let row: Int = HueCompassTest.width * 4
            var rgba: [UInt8] = []
            for y in stride(from: HueCompassTest.height - 1, through: 0, by: -1) {
                rgba.append(contentsOf: still[(y * row)..<((y + 1) * row)])
            }
            let probes: [FrameProbe] = shell.presenter.probes(try HueCompassTest.core(shell))
            #expect(probes.map(\.name) == ["night-top-left", "night-bottom-right"])
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: rgba, width: HueCompassTest.width,
                                              height: HueCompassTest.height)
                #expect(found?.rawValue == probe.expected, "tier \(tier) \(probe.name): \(found?.rawValue ?? "none")")
            }
        }
        session.qualityPin = 0
    }
}
#endif
