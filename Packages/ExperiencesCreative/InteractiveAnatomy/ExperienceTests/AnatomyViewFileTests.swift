// AnatomyViewFileTests — feature 126 (A17-P03) T-A17-307 (FR-A17-307; SC-A17-305; clarification Q4). The saved view
// file `view.json` (`AnatomyViewDocument`) in the experience's storage, inside the one app's session host on the
// simulator, short runs only (each test well under 10 s, no wall-clock assertion), over a temporary storage removed in
// tearDown: accepted view-changing actions write the file (`viewWrites` rises) holding the core's view, and a new
// session over the same storage opens with that view after one frame and draws the same pixels; a schema-1 file
// opens migrated with no isolate; damaged, newer, foreign and oversized files leave the opening view and raise
// `viewReadRefusals`; a restored snapshot wins over the file; a storage that refuses the write (a folder named
// `view.json`) raises `viewWriteFailures` and the session keeps running.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// The saved view file through the session host.
@MainActor
final class AnatomyViewFileTests: XCTestCase {
    /// The storage of the running test.
    private var temporary: TemporaryAnatomyStorage!

    override func setUp() async throws {
        temporary = TemporaryAnatomyStorage()
    }

    override func tearDown() async throws {
        temporary?.remove()
        temporary = nil
    }

    /// The part ids of the bundled knee in inventory order.
    private var partIDs: [String] { AnatomyIsolate.bundledPartIDs }

    /// The view stored in `view.json` now.
    private func storedView() throws -> AnatomyViewState {
        let data = try temporary.storage.read(AnatomyViewDocument.fileName)
        let (result, dropped) = AnatomyViewDocument.decode(data, parts: partIDs)
        XCTAssertTrue(dropped.isEmpty, "\(dropped)")
        return try result.get()
    }

    /// Opens a session over the test's storage and draws one more frame, so a stored view is applied.
    private func openOverStorage(_ session: ExperienceSession, snapshot: ExperienceSnapshot? = nil) async throws
        -> ExperienceShell<AnatomyPresenter> {
        let shell = try await AnatomyTest.open(session, snapshot: snapshot, storage: temporary.storage)
        try AnatomyTest.frames(session, 1)
        return shell
    }

    func testAcceptedActionsWriteTheFileAndANewSessionOpensWithIt() async throws {
        let first = ExperienceSession()
        let shell = try await openOverStorage(first)
        let presenter = shell.presenter
        XCTAssertEqual(try AnatomyTest.core(shell).view, AnatomyViewState.opening)
        let writesBefore = presenter.viewWrites
        let steps: [(String, [Double])] = [("structure.select", [5]), ("layer.show", [2, 0]), ("camera.turn", [1]),
                                           ("camera.zoom", [1]), ("isolate.layer", [0])]
        var writes = writesBefore
        for (control, values) in steps {
            AnatomyTest.accept(shell, control, values)
            try AnatomyTest.frames(first, 1)
            XCTAssertGreaterThan(presenter.viewWrites, writes, "\(control) writes the view")
            writes = presenter.viewWrites
            XCTAssertEqual(try storedView(), try AnatomyTest.core(shell).view, "after \(control)")
        }
        XCTAssertTrue(temporary.storage.exists(AnatomyViewDocument.fileName))
        XCTAssertEqual(presenter.viewWriteFailures, 0)
        let saved = try AnatomyTest.core(shell).view
        XCTAssertNotNil(saved.isolate)
        let picture = try AnatomyTest.picture(first)
        first.close()

        let second = ExperienceSession()
        let reopened = try await openOverStorage(second)
        XCTAssertEqual(try AnatomyTest.core(reopened).view, saved, "the new session opens with the saved view")
        XCTAssertEqual(reopened.presenter.viewReadRefusals, 0)
        let again = try AnatomyTest.picture(second)
        XCTAssertEqual(AnatomyTest.differingPixels(picture.rgba, again.rgba), 0, "the saved view draws alike")
        XCTAssertEqual(reopened.accessibilitySummary, try AnatomyTest.core(reopened).describe())
        second.close()
    }

    func testASchemaOneFileOpensMigrated() async throws {
        let view = AnatomyViewState(camera: AnatomyCameraState(turn: 5, tilt: 2, zoom: 1),
                                    visibleLayers: [true, false, true], selection: "knee.tibia", framed: "knee.tibia")
        let file = try anatomyViewFile(anatomySchema1Payload(view), schemaVersion: 1)
        try temporary.storage.write(file, to: AnatomyViewDocument.fileName)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await openOverStorage(session)
        let core = try AnatomyTest.core(shell)
        XCTAssertEqual(core.view, view, "schema 1 opens migrated")
        XCTAssertNil(core.view.isolate, "with no isolate")
        XCTAssertEqual(core.view.schema, AnatomyViewState.schemaVersion)
        XCTAssertEqual(shell.presenter.viewReadRefusals, 0)
    }

    /// A view file with an unknown selection id opens with that id dropped and the rest of the view kept.
    func testAnUnknownIdInTheFileIsDroppedAndTheRestIsKept() async throws {
        let view = AnatomyViewState(camera: AnatomyCameraState(turn: 4, tilt: 1, zoom: 0),
                                    visibleLayers: [true, true, false], selection: "knee.tibia", framed: "knee.tibia")
        let payload = try anatomyPayload(String(decoding: view.encoded(), as: UTF8.self), key: "selection",
                                         value: "knee.bogus")
        try temporary.storage.write(try anatomyViewFile(payload, schemaVersion: AnatomyViewState.schemaVersion),
                                    to: AnatomyViewDocument.fileName)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await openOverStorage(session)
        let core = try AnatomyTest.core(shell)
        XCTAssertNil(core.view.selection, "the unknown id is dropped")
        XCTAssertEqual(core.view.framed, view.framed)
        XCTAssertEqual(core.view.camera, view.camera)
        XCTAssertEqual(core.view.visibleLayers, view.visibleLayers)
        XCTAssertEqual(shell.presenter.viewReadRefusals, 0, "a dropped id is not a refusal")
    }

    func testDamagedNewerForeignAndOversizedFilesLeaveTheOpeningView() async throws {
        let turned = AnatomyViewState(camera: AnatomyCameraState(turn: 4, tilt: 1, zoom: 0),
                                      visibleLayers: [true, true, true], selection: nil, framed: nil)
        var newerPayload = try XCTUnwrap(try JSONSerialization.jsonObject(with: turned.encoded()) as? [String: Any])
        newerPayload["schema"] = AnatomyViewState.schemaVersion + 1
        let newerBody = try JSONSerialization.data(withJSONObject: newerPayload, options: [.sortedKeys])
        let padding = String(repeating: " ", count: AnatomyViewDocument.maxBytes)
        let valid = AnatomyViewDocument.encode(turned)
        let files: [(name: String, data: Data)] = [
            ("not json", Data("{not json".utf8)),
            ("truncated", valid.prefix(valid.count / 2)),
            ("newer", try anatomyViewFile(newerBody, schemaVersion: AnatomyViewState.schemaVersion + 1)),
            ("foreign kind", try anatomyViewFile(turned.encoded(), schemaVersion: AnatomyViewState.schemaVersion,
                                                 kind: "a16.preset")),
            ("too large", valid + Data(padding.utf8)),
        ]
        for file in files {
            try temporary.storage.write(file.data, to: AnatomyViewDocument.fileName)
            let session = ExperienceSession()
            let shell = try await openOverStorage(session)
            XCTAssertEqual(try AnatomyTest.core(shell).view, AnatomyViewState.opening, "\(file.name): opening view")
            XCTAssertGreaterThanOrEqual(shell.presenter.viewReadRefusals, 1, "\(file.name) is refused")
            XCTAssertEqual(session.state, .running, file.name)
            session.close()
        }
    }

    func testARestoredSnapshotWinsOverTheFile() async throws {
        let first = ExperienceSession()
        let shell = try await AnatomyTest.open(first)
        AnatomyTest.accept(shell, "structure.select", [2])
        AnatomyTest.accept(shell, "camera.tilt", [-1])
        let snapshot = try shell.snapshot()
        let restoredView = try AnatomyTest.core(shell).view
        first.close()
        let other = AnatomyViewState(camera: AnatomyCameraState(turn: 7, tilt: 0, zoom: 2),
                                     visibleLayers: [true, true, false], selection: nil, framed: nil)
        try temporary.storage.write(AnatomyViewDocument.encode(other), to: AnatomyViewDocument.fileName)

        let second = ExperienceSession()
        defer { second.close() }
        let opened = try await openOverStorage(second, snapshot: snapshot)
        XCTAssertNil(second.lastRestoreRefusal)
        XCTAssertEqual(try AnatomyTest.core(opened).view, restoredView, "the file applies only to the opening view")
    }

    func testARefusedWriteIsCountedAndTheSessionKeepsRunning() async throws {
        // A folder named view.json: the storage refuses to replace it with a file.
        let blocker = temporary.folder.appendingPathComponent(AnatomyViewDocument.fileName, isDirectory: true)
        try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: true)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await openOverStorage(session)
        let presenter = shell.presenter
        XCTAssertEqual(try AnatomyTest.core(shell).view, AnatomyViewState.opening)
        XCTAssertEqual(presenter.viewWriteFailures, 0)
        AnatomyTest.accept(shell, "camera.turn", [1])
        try AnatomyTest.frames(session, 1)
        XCTAssertGreaterThanOrEqual(presenter.viewWriteFailures, 1, "the refused write is counted")
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try AnatomyTest.core(shell).view.camera.turn, AnatomyCameraState.opening.turn + 1,
                       "the action itself was accepted")
        let failures = presenter.viewWriteFailures
        AnatomyTest.accept(shell, "structure.select", [0])
        let frame = try AnatomyTest.picture(session)
        XCTAssertGreaterThan(AnatomyTest.nonBackdropPixels(frame), 0, "the session still draws")
        XCTAssertGreaterThan(presenter.viewWriteFailures, failures, "every refused write is counted")
        XCTAssertEqual(session.state, .running)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: blocker.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue, "nothing replaced the folder")
    }
}
