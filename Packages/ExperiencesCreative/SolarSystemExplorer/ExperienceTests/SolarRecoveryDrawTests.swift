// SolarRecoveryDrawTests — feature 108 (A14-P06) T-A14-604 (FR-A14-611; clarification Q5). Short runs only (each test
// well under 10 s, no wall-clock assertion). Through the one app's session host on the simulator: with a view saved in a
// temporary storage and a tour running, a drawing failure injected with the presenter's seam (`failNextDraw`, which
// throws `SolarDrawError.injected` once) fails the session and leaves `view.json` byte for byte; a new session over the
// same storage draws and restores the saved view.
import Foundation
import UIKit
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class SolarRecoveryDrawTests: XCTestCase {
    private func open(_ session: ExperienceSession, storage: ExperienceStorage) async throws
        -> ExperienceShell<SolarPresenter> {
        let id = SolarTest.id
        var made: ExperienceShell<SolarPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = SolarSystemExplorerExperience.make(id: id, storage: storage)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 240, height: 160)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        try SolarTest.frames(session, 1)
        return shell
    }

    func testAFailedDrawLeavesTheSavedViewUntouched() async throws {
        let temporary = TemporarySolarStorage()
        defer { temporary.remove() }
        let session = ExperienceSession()
        let shell = try await open(session, storage: temporary.storage)
        XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
        XCTAssertTrue(shell.handle(control: "scale.mode", values: [1]).isAccepted)
        try SolarTest.frames(session, 1)
        XCTAssertTrue(shell.presenter.saveView())
        let bytes = try temporary.storage.read(SavedView.fileName)
        XCTAssertTrue(shell.handle(control: "tour.start", values: [1]).isAccepted)
        try SolarTest.frames(session, 2)
        XCTAssertEqual(session.state, .running)

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A14-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try temporary.storage.read(SavedView.fileName), bytes, "view.json is unchanged")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(try temporary.storage.read(SavedView.fileName), bytes, "view.json is unchanged after close")

        let fresh = ExperienceSession()
        defer { fresh.close() }
        let again = try await open(fresh, storage: temporary.storage)
        XCTAssertFalse(again.presenter === shell.presenter, "the new session builds a new presenter")
        XCTAssertNil(fresh.failure)
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        XCTAssertEqual(fresh.state, .running)
        let restored = try XCTUnwrap(again.presenter.restoreView(again.port))
        XCTAssertTrue(restored.isAccepted)
        let state = try SolarTest.core(again).state
        XCTAssertEqual(state.selection, 3)
        XCTAssertEqual(state.scaleMode, .trueRelative)
        XCTAssertEqual(try temporary.storage.read(SavedView.fileName), bytes, "restoring never rewrites view.json")
    }
}
