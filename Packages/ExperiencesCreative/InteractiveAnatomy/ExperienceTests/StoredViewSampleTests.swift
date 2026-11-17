// StoredViewSampleTests — feature 129 (A17-P06) T-A17-605 (FR-A17-604; clarification Q5). The committed sample view
// files under `ExperienceTests/Fixtures` are answered by the code that reads them in the app:
//   - `view-v2.json`: a schema-2 envelope of a non-opening view (camera turn 5, tilt 2, zoom 1; cartilage hidden; the
//     tibia selected, framed and isolated with ghosts) opens with that view;
//   - `view-v1.json`: a schema-1 envelope (camera turn 4, tilt −1, zoom 2; ligaments hidden; the femur selected and
//     framed; no isolate) opens migrated to schema 2 with no isolate;
//   - `view-newer.json` (envelope schema 3) and `view-damaged.json` (truncated JSON) leave the opening view and raise
//     `viewReadRefusals`; `AnatomyViewDocument.decode` refuses them with `newer-version` and `damaged`.
// Each sample is installed as `view.json` in a temporary experience storage (removed in tearDown) and is byte for
// byte the sample after a session opened over it (nothing is rewritten on open). Short runs only (well under 10 s, no
// wall-clock assertion), no prompt, no network.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class StoredViewSampleTests: XCTestCase {
    /// The storage of the running test.
    private var temporary: TemporaryAnatomyStorage!

    override func setUp() async throws {
        temporary = TemporaryAnatomyStorage()
    }

    override func tearDown() async throws {
        temporary?.remove()
        temporary = nil
    }

    // MARK: Helpers

    /// The part ids of the bundled knee in inventory order.
    private var partIDs: [String] { AnatomyIsolate.bundledPartIDs }

    /// The bytes of the bundled sample `name` (without extension).
    private func sample(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                                "missing Fixtures/\(name).json")
        return try Data(contentsOf: url)
    }

    /// The view of `view-v2.json`.
    private func v2View() throws -> AnatomyViewState {
        let tibia = try XCTUnwrap(partIDs.firstIndex(of: "knee.tibia"))
        return AnatomyViewState(camera: AnatomyCameraState(turn: 5, tilt: 2, zoom: 1),
                                visibleLayers: [true, false, true], selection: "knee.tibia", framed: "knee.tibia",
                                isolate: AnatomyIsolate(target: .part(tibia), mode: .ghost))
    }

    /// The view of `view-v1.json` after migration.
    private var v1View: AnatomyViewState {
        AnatomyViewState(camera: AnatomyCameraState(turn: 4, tilt: -1, zoom: 2), visibleLayers: [true, true, false],
                         selection: "knee.femur", framed: "knee.femur")
    }

    /// Installs `bytes` as `view.json`, opens a session over the storage, draws one more frame so a stored view is
    /// applied, and returns the core's view and the presenter's read refusals; the session is closed afterwards.
    private func openOver(_ bytes: Data) async throws -> (view: AnatomyViewState, refusals: Int) {
        try temporary.storage.write(bytes, to: AnatomyViewDocument.fileName)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session, storage: temporary.storage)
        try AnatomyTest.frames(session, 1)
        XCTAssertEqual(session.state, .running)
        return (try AnatomyTest.core(shell).view, shell.presenter.viewReadRefusals)
    }

    // MARK: Decoding the samples directly

    func testTheSamplesDecodeOrAreRefusedWithTheirReasons() throws {
        let (v2, v2Dropped) = AnatomyViewDocument.decode(try sample("view-v2"), parts: partIDs)
        XCTAssertEqual(try v2.get(), try v2View())
        XCTAssertEqual(v2Dropped, [])

        let (v1, v1Dropped) = AnatomyViewDocument.decode(try sample("view-v1"), parts: partIDs)
        let migrated = try v1.get()
        XCTAssertEqual(migrated, v1View)
        XCTAssertEqual(migrated.schema, AnatomyViewState.schemaVersion)
        XCTAssertNil(migrated.isolate)
        XCTAssertEqual(v1Dropped, [])

        let refused: [(String, ContentRefusal.Reason)] = [("view-newer", .newerVersion), ("view-damaged", .damaged)]
        for (name, reason) in refused {
            let (result, _) = AnatomyViewDocument.decode(try sample(name), parts: partIDs)
            guard case .failure(let refusal) = result else { XCTFail("\(name) is refused"); continue }
            XCTAssertEqual(refusal.reason, reason, name)
        }
    }

    // MARK: Opening the samples in a session

    func testTheSchemaTwoSampleOpensWithItsView() async throws {
        let bytes = try sample("view-v2")
        let opened = try await openOver(bytes)
        XCTAssertEqual(opened.view, try v2View())
        XCTAssertEqual(opened.refusals, 0)
        XCTAssertEqual(try temporary.storage.read(AnatomyViewDocument.fileName), bytes, "view-v2 stays byte-identical")
    }

    func testTheSchemaOneSampleOpensMigrated() async throws {
        let bytes = try sample("view-v1")
        let opened = try await openOver(bytes)
        XCTAssertEqual(opened.view, v1View)
        XCTAssertEqual(opened.view.schema, AnatomyViewState.schemaVersion, "schema 2 in memory")
        XCTAssertNil(opened.view.isolate)
        XCTAssertEqual(opened.refusals, 0)
        XCTAssertEqual(try temporary.storage.read(AnatomyViewDocument.fileName), bytes, "view-v1 stays byte-identical")
    }

    func testTheNewerAndDamagedSamplesLeaveTheOpeningView() async throws {
        for name in ["view-newer", "view-damaged"] {
            let bytes = try sample(name)
            let opened = try await openOver(bytes)
            XCTAssertEqual(opened.view, AnatomyViewState.opening, "\(name): opening view")
            XCTAssertGreaterThanOrEqual(opened.refusals, 1, "\(name) is refused")
            XCTAssertEqual(try temporary.storage.read(AnatomyViewDocument.fileName), bytes,
                           "\(name) stays byte-identical")
        }
    }
}
