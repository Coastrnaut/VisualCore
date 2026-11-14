// ScopeRecoveryDrawTests — feature 066 (A08-P06) T-A08-606 (FR-A08-611; SC-A08-603; US2). Short runs only.
// Through the one app's session host on the simulator: with a preset saved in the experience's storage (through the
// presenter, as the person saves one), a drawing failure injected with the presenter's seam (`failNextDraw`, which
// throws `ScopeDrawError.injected`) fails the session and leaves the preset file byte for byte; a new session over the
// same storage opens, draws a non-blank frame and lists the saved preset. The test signal is the only source.
import Foundation
import XCTest
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class ScopeRecoveryDrawTests: XCTestCase {
    private var storage: ExperienceStorage!
    private var cleanUp: (@Sendable () -> Void)?

    override func setUpWithError() throws {
        let made = try ScopeTest.temporaryStorage()
        storage = made.storage
        cleanUp = made.cleanUp
    }

    override func tearDown() {
        cleanUp?()
    }

    func testADrawingFailureFailsTheSessionAndKeepsSavedPresets() async throws {
        let session = ExperienceSession()
        let shell = try await ScopeTest.open(session, storage: storage, size: CGSize(width: 160, height: 240))
        let saved = try XCTUnwrap(shell.presenter.savePreset(named: "Kept",
                                                             now: Date(timeIntervalSinceReferenceDate: 300)))
        let fileName = ScopePreset.fileName(for: saved.id)
        let bytes = try storage.read(fileName)

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A08-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(fileName), bytes, "the preset file is unchanged after the failure")
        session.close()

        let fresh = ExperienceSession()
        let again = try await ScopeTest.open(fresh, storage: storage, size: CGSize(width: 160, height: 240))
        defer { fresh.close() }
        XCTAssertNil(fresh.failure)
        XCTAssertFalse(again === shell, "the new session builds a new experience")
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        let size = host.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(host.readPixels(), width: size.width, height: size.height))
        XCTAssertEqual(fresh.state, .running)
        XCTAssertTrue(again.presenter.presetEntries.contains { $0.id == saved.id && $0.settings == saved.settings })
        XCTAssertEqual(try storage.read(fileName), bytes, "the preset file is unchanged after the new session")
    }
}
