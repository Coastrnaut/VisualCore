// GeometryRecoveryTests — feature 045 (A05-P06) T-A05-606 (FR-A05-611; SC-A05-603; US2). Short runs only.
// Through the one app's session host on the simulator: with two compositions saved in the experience's storage, a
// drawing failure injected with the presenter's seam (`failNextDraw`) fails the session with a failure and leaves the
// saved files byte for byte; a new session over the same storage opens, draws a frame and lists both compositions.
// Hosted by the VisualCore app.
import XCTest
import InfiniteGeometryCore
@testable import InfiniteGeometryExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class GeometryRecoveryTests: XCTestCase {
    private var id: ExperienceID { InfiniteGeometryExperience.id ?? ExperienceID(rawValue: "a05.unknown")! }
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUpWithError() throws {
        suite = "dev.visualcore.a05-p06.recovery.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    /// The one storage of the test: every experience the factory makes sees it.
    private var storage: ExperienceStorage { ExperienceStorage(id: id, root: root, defaults: defaults) }

    private func request(made: @escaping @MainActor (any Experience) -> Void) -> ExperienceOpenRequest {
        let id = self.id
        let storage = self.storage
        return ExperienceOpenRequest(id: id, seed: GeometryCore.manifestSeed, snapshot: nil, refusedSnapshotFails: false) {
            let experience = InfiniteGeometryExperience.make(id: id, storage: storage, reduceMotion: false,
                                                             reduceFlashing: false)
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

    /// Saves two compositions (curated preset 0 with motif seeds 7 and 11) through a library over the test storage; returns the
    /// entries and the bytes of their files by file name.
    private func saveTwo() throws -> (entries: [GeometryLibraryEntry], bytes: [String: Data]) {
        let library = GeometryLibrary(storage: storage)
        var entries: [GeometryLibraryEntry] = []
        for (seed, name) in [(GeometryCore.manifestSeed, "First"), (11, "Second")] as [(UInt64, String)] {
            let core = try GeometryCore(seed: seed)
            let digest = try XCTUnwrap(GeometryControls.digest(of: core))
            entries.append(try XCTUnwrap(library.save(GeometryDocument(core: core, name: name), digest: digest)))
        }
        XCTAssertEqual(library.entries.count, 2)
        var bytes: [String: Data] = [:]
        for entry in entries {
            let name = GeometryLibrary.fileName(for: entry.id)
            bytes[name] = try storage.read(name)
        }
        return (entries, bytes)
    }

    func testADrawingFailureFailsTheSessionAndKeepsSavedCompositions() async throws {
        let (entries, bytes) = try saveTwo()

        let session = ExperienceSession()
        var made: (any Experience)?
        let opened = await session.open(request { made = $0 })
        XCTAssertEqual(opened, .running)
        layOut(session)
        let shell = try XCTUnwrap(made as? ExperienceShell<GeometryPresenter>)
        XCTAssertEqual(Set(try XCTUnwrap(shell.presenter.library).entries.map(\.id)), Set(entries.map(\.id)))

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A05-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        for (name, data) in bytes {
            XCTAssertEqual(try storage.read(name), data, "\(name) is unchanged after the failure")
        }
        session.close()

        // A new session over the same storage opens, draws and lists both compositions.
        let fresh = ExperienceSession()
        defer { fresh.close() }
        made = nil
        let reopened = await fresh.open(request { made = $0 })
        XCTAssertEqual(reopened, .running)
        XCTAssertNil(fresh.failure)
        layOut(fresh)
        XCTAssertTrue(fresh.renderHost?.renderOneFrame(present: false) ?? false, "the new session draws a frame")
        XCTAssertEqual(fresh.state, .running)
        let again = try XCTUnwrap(made as? ExperienceShell<GeometryPresenter>)
        XCTAssertFalse(again === shell, "the new session builds a new experience")
        XCTAssertGreaterThan(again.presenter.drawnCount, 0)
        let library = try XCTUnwrap(again.presenter.library)
        XCTAssertEqual(library.entries.map(\.name), ["First", "Second"])
        XCTAssertEqual(Set(library.entries.map(\.id)), Set(entries.map(\.id)))
        for (name, data) in bytes {
            XCTAssertEqual(try storage.read(name), data, "\(name) is unchanged after the new session")
        }
    }
}
