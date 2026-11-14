// OdysseyRecoveryDrawTests — feature 059 (A07-P06) T-A07-606 (FR-A07-611; SC-A07-603; US2). Short runs only.
// Through the one app's session host on the simulator: with a journey saved in the experience's storage, a drawing
// failure injected with the presenter's seam (`failNextDraw`) fails the session and leaves the journey file byte for
// byte; a new session over the same storage opens, draws a non-blank frame and lists the saved journey.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class OdysseyRecoveryDrawTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a07-p06.recovery.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: P05.id, root: root, defaults: defaults)
    }

    func testADrawingFailureFailsTheSessionAndKeepsSavedJourneys() async throws {
        let store = JourneyPresetStore(storage: storage)
        let state = JourneyState(seed: 7, world: .landscape)
        let saved = try XCTUnwrap(store.save(name: "Kept", from: state))
        let fileName = JourneyPreset.fileName(for: saved.id)
        let bytes = try storage.read(fileName)

        let session = ExperienceSession()
        let shell = try await P05.open(session, storage: storage, size: CGSize(width: 160, height: 240))
        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A07-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(fileName), bytes, "the journey file is unchanged after the failure")
        session.close()

        let fresh = ExperienceSession()
        let again = try await P05.open(fresh, storage: storage, size: CGSize(width: 160, height: 240))
        defer { fresh.close() }
        XCTAssertNil(fresh.failure)
        XCTAssertFalse(again === shell, "the new session builds a new experience")
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        let size = host.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(host.readPixels(), width: size.width, height: size.height))
        XCTAssertEqual(fresh.state, .running)
        XCTAssertTrue(again.presenter.presetEntries.contains { $0.id == saved.id && $0.world == .landscape })
        XCTAssertEqual(try storage.read(fileName), bytes, "the journey file is unchanged after the new session")
    }
}
