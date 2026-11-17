// AnatomyRecoveryDrawTests — feature 129 (A17-P06) T-A17-604 (FR-A17-603; SC-A17-602; clarification Q5). Short runs
// only (well under 10 s, no wall-clock assertion). Through the one app's session host on the simulator, over a
// temporary experience storage removed in tearDown: a non-opening view (tibia selected, cartilage hidden, the camera
// turned, the tibia isolated with ghosts) is saved through accepted actions as `view.json`; a drawing failure injected
// with the presenter's seam (`failNextDraw`, which throws `AnatomyDrawError.injected` once) fails the session and
// leaves `view.json` byte for byte, also after the session is closed. A new session over the same storage opens with
// that view and draws, and opening writes nothing (the file stays byte for byte).
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class AnatomyRecoveryDrawTests: XCTestCase {
    /// The storage of the running test.
    private var temporary: TemporaryAnatomyStorage!

    override func setUp() async throws {
        temporary = TemporaryAnatomyStorage()
    }

    override func tearDown() async throws {
        temporary?.remove()
        temporary = nil
    }

    func testAFailedDrawLeavesTheSavedViewAndANewSessionOpensIt() async throws {
        let name = AnatomyViewDocument.fileName

        let first = ExperienceSession()
        let shell = try await AnatomyTest.open(first, storage: temporary.storage)
        let steps: [(String, [Double])] = [("structure.select", [1]), ("layer.show", [1, 0]), ("camera.turn", [1]),
                                           ("isolate.part", [1])]
        for (control, values) in steps {
            AnatomyTest.accept(shell, control, values)
            try AnatomyTest.frames(first, 1)
        }
        let saved = try AnatomyTest.core(shell).view
        XCTAssertNotEqual(saved, AnatomyViewState.opening)
        XCTAssertNotNil(saved.isolate)
        XCTAssertTrue(temporary.storage.exists(name), "view.json is written")
        let bytes = try temporary.storage.read(name)
        let (stored, dropped) = AnatomyViewDocument.decode(bytes, parts: AnatomyIsolate.bundledPartIDs)
        XCTAssertEqual(try stored.get(), saved, "the file holds the saved view")
        XCTAssertEqual(dropped, [])

        shell.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(first.state, .failed, "a drawing failure fails the session (FR-A17-603)")
        XCTAssertNotNil(first.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try temporary.storage.read(name), bytes, "view.json is unchanged by the failure")
        first.close()
        XCTAssertEqual(first.hostsAlive, 0)
        XCTAssertEqual(try temporary.storage.read(name), bytes, "view.json is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await AnatomyTest.open(second, storage: temporary.storage)
        try AnatomyTest.frames(second, 1)
        XCTAssertNil(second.failure)
        XCTAssertEqual(try AnatomyTest.core(reopened).view, saved, "the new session opens with the saved view")
        XCTAssertEqual(reopened.presenter.viewReadRefusals, 0)
        XCTAssertEqual(second.state, .running, "the new session draws")
        XCTAssertEqual(try temporary.storage.read(name), bytes, "opening the saved view writes nothing")
    }
}
