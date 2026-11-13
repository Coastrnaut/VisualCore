// ParticleRecoveryTests — feature 038 (A04-P06) T-A04-609 (FR-A04-612, FR-A04-613; US2). Short runs only.
// Through the one app's session host on the simulator: a drawing failure injected with the presenter's seam fails
// the session with a failure and leaves the saved scenes byte for byte; a retry runs again over the same storage and
// lists them. Reduce Flashing caps the scene's brightness at 0.6, and without it the cap is 1. Hosted by the
// VisualCore app.
import XCTest
import ParticleUniverseCore
@testable import ParticleUniverseExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class ParticleRecoveryTests: XCTestCase {
    private var id: ExperienceID { ParticleExperience.id ?? ExperienceID(rawValue: "a04.unknown")! }
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a04-p06.recovery.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    /// The one storage of the test: every experience the factory makes, the retry's included, sees it.
    private var storage: ExperienceStorage { ExperienceStorage(id: id, root: root, defaults: defaults) }

    private func request(reduceFlashing: Bool,
                         made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        let storage = self.storage
        return ExperienceOpenRequest(id: id, seed: ParticleCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let experience = ParticleExperience.make(id: id, storage: storage, reduceMotion: false,
                                                     reduceFlashing: reduceFlashing)
            made(experience)
            return experience
        }
    }

    private func layOut(_ session: ExperienceSession) {
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
    }

    private func render(_ session: ExperienceSession, frames: Int) {
        for _ in 0..<frames { XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false) }
    }

    private func document(_ name: String) throws -> SceneDocument {
        try SceneDocument(name: name, scene: .single(.fountain, seed: 7),
                          force: SavedForce(kind: PlacedForceKind.allCases[0].rawValue, x: 10, y: -20, strength: 1),
                          trailsOn: false, trailStrength: 0.5, additive: true)
    }

    func testADrawingFailureFailsTheSessionAndKeepsSavedScenes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var made: (any Experience)?
        let opened = await session.open(request(reduceFlashing: false) { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let shell = try XCTUnwrap(made as? ExperienceShell<ParticlePresenter>)

        let saved = try XCTUnwrap(shell.presenter.library.save(try document("Kept")))
        let fileName = ParticleLibrary.fileName(for: saved.id)
        let before = try storage.read(fileName)

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A04-612)")
        XCTAssertNotNil(session.failure)
        XCTAssertEqual(try storage.read(fileName), before, "the saved scene is unchanged")

        made = nil
        let retried = await session.retry()
        XCTAssertEqual(retried, .running)
        XCTAssertEqual(session.state, .running)
        XCTAssertNil(session.failure)
        layOut(session)
        render(session, frames: 3)
        let again = try XCTUnwrap(made as? ExperienceShell<ParticlePresenter>)
        XCTAssertFalse(again === shell, "the retry builds a new experience")
        XCTAssertEqual(again.presenter.library.entries.map(\.id), [saved.id])
        XCTAssertEqual(again.presenter.library.entries.map(\.name), ["Kept"])
    }

    func testReduceFlashingCapsBrightnessInTheSession() async throws {
        for (reduceFlashing, cap) in [(true, 0.6), (false, 1.0)] {
            let session = ExperienceSession()
            var made: (any Experience)?
            let opened = await session.open(request(reduceFlashing: reduceFlashing) { made = $0 })
            XCTAssertEqual(opened, .running)
            layOut(session)
            let shell = try XCTUnwrap(made as? ExperienceShell<ParticlePresenter>)
            render(session, frames: 1)
            XCTAssertEqual(shell.presenter.brightnessCap, cap, accuracy: 1e-9,
                           "Reduce Flashing \(reduceFlashing) (FR-A04-613)")
            session.close()
        }
    }
}
