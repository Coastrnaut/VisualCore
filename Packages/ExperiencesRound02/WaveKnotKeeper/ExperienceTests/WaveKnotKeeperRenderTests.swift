// WaveKnotKeeperRenderTests — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-001 … 003, 006;
// SC-R02G0303-001; clarifications Q1, Q3; R2-G03-INV-10). Through the one app's session host, drawn off screen at the
// frame-check size of `WaveKnotKeeperTest` (1,152 × 768): certified levels 1, 21, 41, 61 and 81 (seeds 0, 20, 40, 60,
// 80) at each quality tier level-0, level-1 and level-2 match the Core's CPU reference of the presenter's last snapshot
// (control points and segment midpoints within 3 px of a pixel 0.15 brighter than night, handle centres pearl within
// 0.15, gate centres tinted towards sapphire, background within 0.05 of night); `point.select` turns that handle ember
// without changing the digest; a legal `point.move` changes the digest and the moved frame still matches. One test per
// level, each well under 10 s.
#if os(iOS)
import Foundation
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
@Suite(.serialized) struct WaveKnotKeeperRenderTests {
    @Test(arguments: [UInt64(0), 20, 40, 60, 80])
    func everyTierMatchesTheReference(seed: UInt64) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: seed)
        let level: Int = WaveKnotKeeperExperienceCore.levelNumber(forSeed: seed)
        #expect(try WaveKnotKeeperTest.core(shell).levelNumber == level)
        for tier in 0..<3 {
            WaveKnotKeeperTest.pin(session, shell, tier: tier)
            let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
            let snapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(snapshot.time == 0, "the still's frame time is 0")
            #expect(snapshot.levelNumber == level)
            #expect(snapshot.selected == nil)
            #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
            #expect(shell.presenter.tierLog.last?.tier == tier)
            WaveKnotKeeperTest.checkFrame(rgba, snapshot: snapshot, "level \(level) tier \(tier)")
            let gates = WaveKnotKeeperTest.gateMisses(rgba, snapshot: snapshot)
            let handles = WaveKnotKeeperTest.handleMisses(rgba, snapshot: snapshot)
            print("wave-knot-keeper level \(level) tier \(tier): handles checked \(handles.checked) of "
                  + "\(snapshot.points.count), gates checked \(gates.checked) of \(snapshot.gates.count)")
            // Band 3 and above (levels 41, 61, 81) have gates, and their centres are checked.
            if level >= 41 {
                #expect(!snapshot.gates.isEmpty, "level \(level) has gates")
                #expect(gates.checked == snapshot.gates.count, "level \(level): gates checked \(gates.checked)")
            }
        }
        // The selected handle turns ember; the selection is presentation only.
        WaveKnotKeeperTest.pin(session, shell, tier: 0)
        // A handle whose centre stays checkable once it is ember (clear of gates and of later-drawn pearl handles).
        let opened: WaveKnotKeeperExperienceCore = try WaveKnotKeeperTest.core(shell)
        var choice: Int?
        for index in 0..<opened.play.points.count {
            let trial = WaveKnotKeeperSceneSnapshot(play: opened.play, levelNumber: level, selected: index, time: 0)
            if WaveKnotKeeperTest.checkableHandles(trial).contains(index) { choice = index }
        }
        let chosen: Int = try #require(choice, "level \(level): a handle clear of gates and later handles")
        let before: String = try WaveKnotKeeperTest.digest(shell)
        let selected: ActionResult = shell.handle(control: "point.select", values: [Double(chosen)])
        #expect(selected == .accepted, "\(selected.code)")
        #expect(try WaveKnotKeeperTest.digest(shell) == before, "point.select leaves the digest")
        let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
        let snapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.selected == chosen)
        WaveKnotKeeperTest.checkFrame(rgba, snapshot: snapshot, "level \(level) point \(chosen) selected")
        let handles = WaveKnotKeeperTest.handleMisses(rgba, snapshot: snapshot)
        #expect(handles.selectedChecked, "level \(level): the selected handle \(chosen) was checked")
        session.qualityPin = 0
    }

    @Test func theCheckedLevelsWithGatesAreBandThreeAndAbove() throws {
        // Clarification Q3's gate check needs gates: bands 1 and 2 have none, bands 3 … 5 have one or two.
        var gates: [Int] = []
        for seed in WaveKnotKeeperTest.seeds {
            let core = try WaveKnotKeeperExperienceCore.opening(number: Int(seed) + 1)
            gates.append(core.snapshot(time: 0).gates.count)
        }
        #expect(gates[0] == 0 && gates[1] == 0, "\(gates)")
        #expect(gates[2] >= 1 && gates[3] >= 1 && gates[4] >= 1, "\(gates)")
    }

    @Test func aMoveChangesTheDigestAndTheFrameStillMatches() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WaveKnotKeeperTest.open(session, seed: 40)
        let core: WaveKnotKeeperExperienceCore = try WaveKnotKeeperTest.core(shell)
        let move = try #require(WaveKnotKeeperTest.legalMove(core), "a legal move on level 41")
        let before: String = try WaveKnotKeeperTest.digest(shell)
        let oldPoints: [WaveKnotKeeperPoint] = core.play.points
        let result: ActionResult = shell.handle(control: "point.move",
                                                values: [Double(move.point), Double(move.direction)])
        #expect(result == .accepted, "\(result.code)")
        #expect(try WaveKnotKeeperTest.digest(shell) != before, "a move changes the digest")
        let moved: WaveKnotKeeperExperienceCore = try WaveKnotKeeperTest.core(shell)
        #expect(moved.play.points != oldPoints)
        #expect(moved.play.spent == 1)
        let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
        let snapshot: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(snapshot.points == moved.play.points, "the frame draws the moved rope")
        WaveKnotKeeperTest.checkFrame(rgba, snapshot: snapshot, "level 41 after point.move")
        // Undo restores the earlier digest exactly and the frame still matches (undo needs stage `playing`).
        try #require(moved.play.stage == .playing, "the first legal move does not end level 41")
        #expect(shell.handle(control: "play.undo") == .accepted)
        #expect(try WaveKnotKeeperTest.digest(shell) == before)
        let undone: [UInt8] = try WaveKnotKeeperTest.still(session)
        WaveKnotKeeperTest.checkFrame(undone, snapshot: try #require(shell.presenter.lastSnapshot),
                                      "level 41 after play.undo")
    }
}
#endif
