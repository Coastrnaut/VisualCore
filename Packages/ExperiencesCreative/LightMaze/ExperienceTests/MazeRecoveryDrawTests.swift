// MazeRecoveryDrawTests — feature 101 (A13-P06) T-A13-604 (FR-A13-611; SC-A13-602; clarification Q5; research D3).
// Short runs only (each test well under 10 s, no wall-clock assertion). Through the one app's session host on the
// simulator: with level 1 solved over a temporary storage (so `progress.json` is written once), a drawing failure
// injected with the presenter's seam (`failNextDraw`, which throws `MazeDrawError.injected` once) fails the session and
// leaves `progress.json` byte for byte; a new session over the same storage loads the same progress and draws.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreUI

@MainActor
final class MazeRecoveryDrawTests: XCTestCase {
    private var temporary: TemporaryMazeStorage!

    override func setUp() async throws {
        temporary = TemporaryMazeStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    func testAFailedDrawLeavesTheProgressFileUntouched() async throws {
        let storage = temporary.storage
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, progressStore: ProgressStore(storage: storage),
                                            soundSink: RecordingMazeSoundSink(),
                                            feedback: ExperienceFeedback(hapticSink: RecordingHapticSink()))
        XCTAssertTrue(shell.handle(control: "tile.select", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        try MazeTest.frames(session, 1)
        XCTAssertTrue(shell.presenter.progress.isSolved(0), "level 1 recorded")
        let bytes = try storage.read(ProgressStore.fileName)
        XCTAssertEqual(bytes, shell.presenter.progress.encoded())
        XCTAssertEqual(session.state, .running)

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A13-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(ProgressStore.fileName), bytes, "progress.json is unchanged")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(try storage.read(ProgressStore.fileName), bytes, "progress.json is unchanged after close")

        let fresh = ExperienceSession()
        defer { fresh.close() }
        let again = try await MazeTest.open(fresh, progressStore: ProgressStore(storage: storage),
                                            soundSink: RecordingMazeSoundSink(),
                                            feedback: ExperienceFeedback(hapticSink: RecordingHapticSink()))
        XCTAssertFalse(again.presenter === shell.presenter, "the new session builds a new presenter")
        XCTAssertNil(fresh.failure)
        XCTAssertNil(again.presenter.progressRefusal)
        XCTAssertEqual(again.presenter.progress, shell.presenter.progress, "the saved progress loads")
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        XCTAssertGreaterThan(again.presenter.lastSegmentsDrawn, 0)
        XCTAssertEqual(fresh.state, .running)
        XCTAssertEqual(try storage.read(ProgressStore.fileName), bytes, "loading never rewrites progress.json")
    }
}
