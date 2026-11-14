// MusicLabDeniedUsabilityTests — feature 050 (A06-P04) T-A06-408 (FR-A06-414; SC-A06-404; US3). The phase regression
// fixture: with microphone access denied, Music Lab stays fully usable with the demo signal — the microphone is refused
// with the Settings explanation, every scene draws a non-blank picture, a mapping change, a built-in preset and a saved
// preset are all accepted. Short runs only (under 5 s).
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
    private(set) var requests = 0
    func request() async -> MicrophonePermissionState {
        requests += 1
        return .denied
    }
}

@MainActor
final class MusicLabDeniedUsabilityTests: XCTestCase {
    func testEverythingButTheMicrophoneWorksWithAccessDenied() async throws {
        let id = try XCTUnwrap(VisualCoreMusicLabExperience.id)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ml-denied-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "ml-denied-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = ExperienceStorage(id: id, root: root, defaults: defaults)
        let permission = DeniedPermission()
        var made: ExperienceShell<MusicLabPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = VisualCoreMusicLabExperience.make(id: id, permission: permission, factory: .system,
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
        let shell = try XCTUnwrap(made)
        let presenter = shell.presenter
        let host = try XCTUnwrap(session.renderHost)

        // The microphone is refused with the way to Settings; no request; the demo keeps playing.
        let refused = await presenter.chooseMicrophone()
        XCTAssertEqual(refused, .rejected(.rule(code: MusicLabRule.permissionDenied)))
        XCTAssertEqual(permission.requests, 0)
        XCTAssertTrue(presenter.mirror.showsSettingsLink)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.source, .demo)

        // Every scene draws the demo signal.
        for scene in MusicLabScene.allCases {
            XCTAssertTrue(shell.handle(control: "scene.select", values: [Double(scene.rawValue)]).isAccepted)
            for _ in 0..<10 {
                XCTAssertTrue(host.renderOneFrame(present: false))
                try await Task.sleep(for: .milliseconds(16))
            }
            let pixels = host.readPixels()
            let size = host.pixelSize
            XCTAssertTrue(FrameChecks.isNonBlank(pixels, width: size.width, height: size.height), "\(scene)")
        }
        // An editor change, a built-in preset and a saved preset are accepted.
        XCTAssertTrue(shell.handle(control: "mapping.set", values: [2, 0, 0, 2]).isAccepted)
        let builtIn = try XCTUnwrap(MusicPreset.builtIns.first)
        XCTAssertTrue(presenter.apply(builtIn).isAccepted)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.scene, builtIn.scene)
        let saved = try XCTUnwrap(presenter.saveCurrentPreset(named: "Mine"))
        XCTAssertTrue(shell.handle(control: "scene.select", values: [1]).isAccepted)
        XCTAssertTrue(presenter.apply(saved).isAccepted)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.scene, saved.scene)
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.currentChoices, saved.choices)
        session.close()
    }
}
