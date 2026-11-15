// MazeSessionTests — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121, FR-A13-122; clarification Q5;
// SC-A13-105). The A13 adapter inside the one app's session host on the simulator, short runs only (each test well
// under 10 s, no wall-clock assertion): the first frame draws level 1 through the host and describes it in words, and
// actions change the description; a suspension changes nothing; the state saved by the shell restores identically in a
// new session; newer and damaged saved states are refused and the first level opens; a context recreation makes the
// renderer once more, keeps the scene tree and the digest; reopening keeps the drawing resources steady and closing
// leaves no GPU object behind.
import Foundation
import XCTest
import VisualCoreDiagnostics
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
final class MazeSessionTests: XCTestCase {
    func testTheFirstFrameDrawsLevelOneAndDescribesIt() async throws {
        XCTAssertEqual(LightMazeExperience.id?.rawValue, "a13.light-maze")
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let core = try MazeTest.core(shell)
        XCTAssertEqual(core.state, MazeState.initial)
        XCTAssertEqual(presenter.lastSegmentsDrawn, core.beam.segments.count)
        XCTAssertGreaterThan(presenter.lastSegmentsDrawn, 0)
        XCTAssertGreaterThan(presenter.lastTriangleCount, 0)
        XCTAssertEqual(presenter.rebuildCount, 1, "one scene tree for the first state")
        XCTAssertEqual(shell.accessibilitySummary,
                       "Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at the wall; not solved.")
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.mirror.levelIndex, 0)
        XCTAssertEqual(presenter.mirror.turnableCount, 1)
        XCTAssertEqual(presenter.mirror.selectedWords, "No tile selected")
        XCTAssertEqual(presenter.nativeActions, ["level.next", "level.previous", "tile.select", "tile.turn",
                                                 "level.reset"])
        XCTAssertEqual(presenter.gestureActions, [])
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])

        XCTAssertTrue(shell.handle(control: "tile.select", values: [0]).isAccepted)
        XCTAssertEqual(presenter.mirror.selectedWords, "Mirror 1 of 1, leaning left, column 3, row 3",
                       "the description syncs the controls")
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        XCTAssertEqual(shell.accessibilitySummary,
                       "Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at the target; solved.")
        XCTAssertTrue(presenter.mirror.solved)
        try MazeTest.frames(session, 1)
        let trees = presenter.rebuildCount
        XCTAssertGreaterThan(trees, 1, "the turned state rebuilt the tree")
        XCTAssertEqual(presenter.sceneState, try MazeTest.core(shell).state)
        try MazeTest.frames(session, 3)
        XCTAssertEqual(presenter.rebuildCount, trees, "an unchanged state never rebuilds")
        XCTAssertTrue(shell.handle(control: "level.next").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Light Maze: level 2, Around the corner;"),
                      shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.levelIndex, 1)

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertNil(presenter.primitives, "the renderer is released in teardown")
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testASuspensionChangesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session)
        XCTAssertTrue(shell.handle(control: "tile.select", values: [0]).isAccepted)
        try MazeTest.frames(session, 20)
        let before = try MazeTest.core(shell)
        let digest = try shell.engine.digest()
        let stepIndex = shell.engine.stepIndex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try MazeTest.core(shell), before, "nothing changes while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try MazeTest.core(shell), before, "the resume continues from the same state")
        try MazeTest.frames(session, 5)
        XCTAssertEqual(try shell.engine.digest(), digest, "host steps change nothing")
        session.close()
    }

    func testTheSavedStateRestoresIdenticallyInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await MazeTest.open(first)
        XCTAssertTrue(shell.handle(control: "level.select", values: [9]).isAccepted)
        XCTAssertTrue(shell.handle(control: "tile.select", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        try MazeTest.frames(first, 3)
        let snapshot = try shell.snapshot()
        let saved = try MazeTest.core(shell)
        first.close()

        let second = ExperienceSession()
        let restored = try await MazeTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try MazeTest.core(restored)
        XCTAssertEqual(core.state, saved.state, "level, orientations and selection are identical")
        XCTAssertEqual(core.beam, saved.beam)
        try MazeTest.frames(second, 1)
        XCTAssertEqual(restored.presenter.lastSegmentsDrawn, saved.beam.segments.count)
        XCTAssertEqual(restored.accessibilitySummary, saved.canvasDescription)
        second.close()
    }

    func testANewerSavedStateIsRefusedAndTheFirstLevelOpens() async throws {
        let first = ExperienceSession()
        let shell = try await MazeTest.open(first)
        XCTAssertTrue(shell.handle(control: "level.select", values: [4]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let newerEnvelope = try mazeEnvelope(Data(saved.payload.utf8), like: saved, schema: 2)
        let newerPayload = try mazeEnvelope(mazePayload(saved.payload) { $0["schema"] = 2 }, like: saved)

        let cases: [(String, ExperienceSnapshot)] = [("envelope", newerEnvelope), ("payload", newerPayload)]
        for (name, newer) in cases {
            let second = ExperienceSession()
            let opened = try await MazeTest.open(second, snapshot: newer)
            XCTAssertNotNil(second.lastRestoreRefusal, "the newer \(name) is refused")
            XCTAssertEqual(try MazeTest.core(opened).state, MazeState.initial, "\(name): the first level opens")
            XCTAssertThrowsError(try opened.restore(newer), name)
            second.close()
        }
    }

    func testADamagedSavedStateIsRefusedAndTheFirstLevelOpens() async throws {
        let first = ExperienceSession()
        let shell = try await MazeTest.open(first)
        XCTAssertTrue(shell.handle(control: "level.select", values: [2]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let damaged = try mazeEnvelope(mazePayload(saved.payload) { $0["levelIndex"] = 25 }, like: saved)

        let second = ExperienceSession()
        let opened = try await MazeTest.open(second, snapshot: damaged)
        XCTAssertNotNil(second.lastRestoreRefusal, "a level outside 0…19 is refused")
        XCTAssertEqual(try MazeTest.core(opened).state, MazeState.initial, "the first level opens")
        XCTAssertThrowsError(try opened.restore(damaged))
        second.close()
    }

    func testAContextRecreationMakesTheRendererOnceMoreAndKeepsTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session)
        XCTAssertTrue(shell.handle(control: "level.select", values: [15]).isAccepted)
        try MazeTest.frames(session, 1)
        let presenter = shell.presenter
        let renderers = presenter.rendererBuildCount
        let trees = presenter.rebuildCount
        let digest = try shell.engine.digest()
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try shell.engine.digest(), digest)
        try MazeTest.frames(session, 2)
        XCTAssertEqual(presenter.rendererBuildCount, renderers + 1, "the renderer is made once on the new context")
        XCTAssertEqual(presenter.rebuildCount, trees, "the scene tree is CPU data and survives")
        XCTAssertEqual(presenter.lastSegmentsDrawn, try MazeTest.core(shell).beam.segments.count)
        XCTAssertTrue(presenter.isLive)
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    func testReopeningFiveTimesKeepsTheDrawingResourcesSteady() async throws {
        var reference: ResourceLedger.Snapshot?
        for cycle in 1...5 {
            let session = ExperienceSession()
            let shell = try await MazeTest.open(session)
            XCTAssertTrue(shell.handle(control: "tile.select", values: [0]).isAccepted)
            try MazeTest.frames(session, 5)
            let stats = try XCTUnwrap(session.renderHost).resources.stats
            XCTAssertEqual(stats.leaked, 0, "cycle \(cycle)")
            if let reference {
                XCTAssertEqual(stats.liveCount, reference.liveCount, "cycle \(cycle): the same live objects per kind")
                XCTAssertEqual(stats.liveBytes, reference.liveBytes, "cycle \(cycle): the same live bytes per kind")
            } else {
                reference = stats
            }
            session.close()
            XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "cycle \(cycle)")
        }
    }
}
