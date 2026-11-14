// MusicLabRecoveryDrawTests — feature 052 (A06-P06) T-A06-606 (FR-A06-611; SC-A06-603; US2). Short runs only.
// Through the one app's session host on the simulator: with a preset saved in the experience's storage, a drawing
// failure injected with the presenter's seam (`failNextDraw`) fails the session and leaves the preset file byte for
// byte; a new session over the same storage opens, draws a non-blank frame and lists the preset.
import XCTest
import VisualCoreAudio
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import VisualCoreMusicLabExperience
import VisualCoreMusicLabCore
import VisualCoreRendering

@MainActor
private final class DeniedPermission: MicrophonePermission {
    var state: MicrophonePermissionState { .denied }
    func request() async -> MicrophonePermissionState { .denied }
}

@MainActor
final class MusicLabRecoveryDrawTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a06-p06.recovery.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    private var storage: ExperienceStorage {
        ExperienceStorage(id: VisualCoreMusicLabExperience.id!, root: root, defaults: defaults)
    }

    private func open() async throws -> (ExperienceSession, ExperienceShell<MusicLabPresenter>) {
        let id = try XCTUnwrap(VisualCoreMusicLabExperience.id)
        let storage = self.storage
        var made: ExperienceShell<MusicLabPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: DeniedPermission(), factory: .system,
                                                          storage: storage)
            made = shell
            return shell
        }
        let session = ExperienceSession()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        return (session, try XCTUnwrap(made))
    }

    func testADrawingFailureFailsTheSessionAndKeepsSavedPresets() async throws {
        let store = MusicLabPresetStore(storage: storage)
        let saved = try XCTUnwrap(store.save(name: "Kept", scene: .rings, choices: MusicLabScene.rings.defaultChoices,
                                             palette: .ember))
        let fileName = MusicPreset.fileName(for: saved.id)
        let bytes = try storage.read(fileName)

        let (session, shell) = try await open()
        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A06-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(fileName), bytes, "the preset file is unchanged after the failure")
        session.close()

        let (fresh, again) = try await open()
        defer { fresh.close() }
        XCTAssertNil(fresh.failure)
        XCTAssertFalse(again === shell, "the new session builds a new experience")
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        let size = host.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(host.readPixels(), width: size.width, height: size.height))
        XCTAssertEqual(fresh.state, .running)
        XCTAssertTrue(try XCTUnwrap(again.presenter.presets).entries.contains { $0.id == saved.id && $0.palette == .ember })
        XCTAssertEqual(try storage.read(fileName), bytes, "the preset file is unchanged after the new session")
    }
}
