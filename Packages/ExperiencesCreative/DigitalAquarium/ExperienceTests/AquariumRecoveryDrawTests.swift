// AquariumRecoveryDrawTests — feature 073 (A09-P06) T-A09-605 (FR-A09-611; SC-A09-602; US2; research D3). Short runs
// only. Through the one app's session host on the simulator: with an aquarium saved in the experience's storage
// (through the presenter, as the person saves one), a drawing failure injected with the presenter's seam
// (`failNextDraw`, which throws `AquariumDrawError.injected`) fails the session and leaves the saved file byte for
// byte; a new session over the same storage opens, draws a non-blank frame and lists the saved aquarium.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class AquariumRecoveryDrawTests: XCTestCase {
    private var storage: ExperienceStorage!
    private var cleanUp: (@Sendable () -> Void)?

    override func setUpWithError() throws {
        let suite = "dev.visualcore.a09-p06.recovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        storage = ExperienceStorage(id: ExperienceID(rawValue: "a09.recovery-test")!, root: root, defaults: defaults)
        cleanUp = {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    override func tearDown() {
        cleanUp?()
    }

    func testADrawingFailureFailsTheSessionAndKeepsSavedAquariums() async throws {
        let size = CGSize(width: 160, height: 90)
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size, storage: storage)
        XCTAssertTrue(shell.presenter.saveAquarium(named: "Kept"), shell.presenter.library?.lastFailure ?? "")
        let saved = try XCTUnwrap(shell.presenter.library?.entries.first)
        XCTAssertEqual(saved.name, "Kept")
        let fileName = AquariumLibrary.fileName(for: saved.id)
        let bytes = try storage.read(fileName)

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A09-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(fileName), bytes, "the saved file is unchanged after the failure")
        session.close()

        let fresh = ExperienceSession()
        let again = try await AquariumTest.open(fresh, size: size, storage: storage)
        defer { fresh.close() }
        XCTAssertNil(fresh.failure)
        XCTAssertFalse(again === shell, "the new session builds a new experience")
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        let pixels = host.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(host.readPixels(), width: pixels.width, height: pixels.height))
        XCTAssertEqual(fresh.state, .running)
        XCTAssertEqual(again.presenter.library?.entries, [saved], "the new session lists the saved aquarium")
        XCTAssertEqual(try storage.read(fileName), bytes, "the saved file is unchanged after the new session")
    }
}
