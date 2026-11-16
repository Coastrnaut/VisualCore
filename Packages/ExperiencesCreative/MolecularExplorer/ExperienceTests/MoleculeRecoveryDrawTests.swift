// MoleculeRecoveryDrawTests — feature 115 (A15-P06) T-A15-604 (FR-A15-611; clarification Q5). Short runs only (each
// test well under 10 s, no wall-clock assertion). Through the one app's session host on the simulator, with a temporary
// experience storage: a molecule file is imported through the presenter (writing `import.xyz`, `import-title.txt` and
// `recent.json`) and the label mode is changed (writing `settings.json`); a drawing failure injected with the
// presenter's seam (`failNextDraw`, which throws `MoleculeDrawError.injected` once) fails the session and leaves the
// three files byte for byte, also after the session is closed. The engine state lives in the session snapshot, not in
// the storage: a new session over the same storage, restoring the snapshot taken before the failure, draws the
// imported molecule (selection 5) with the stored title; a new session without a snapshot opens water and shows the
// import again by choosing `imported` from the recent list, which replays the stored copy.
import Foundation
import UIKit
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class MoleculeRecoveryDrawTests: XCTestCase {
    /// The experience's temporary storage.
    private var temporary: TemporaryMoleculeStorage!
    /// The temporary folder the picked file is written to.
    private var files: URL!

    override func setUp() async throws {
        temporary = TemporaryMoleculeStorage()
        files = FileManager.default.temporaryDirectory
            .appendingPathComponent("me-recovery-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        temporary.remove()
        try? FileManager.default.removeItem(at: files)
    }

    /// Opens Molecular Explorer in `session` with a presenter over the temporary storage, optionally restoring
    /// `snapshot`, and attaches the shell's port and activity as the factory does.
    private func open(_ session: ExperienceSession, snapshot: ExperienceSnapshot? = nil) async throws
        -> ExperienceShell<MoleculePresenter> {
        let presenter = TemporaryMoleculeStorage.presenter(temporary.storage)
        let shell = try await MoleculeTest.open(session, snapshot: snapshot, presenter: presenter)
        MolecularExplorerExperience.attach(shell)
        return shell
    }

    /// The bytes of the three stored files: `import.xyz`, `recent.json` and `settings.json`.
    private func storedFiles() throws -> [Data] {
        [try temporary.storage.read(MoleculeImporter.fileName), try temporary.storage.read(RecentMolecules.fileName),
         try temporary.storage.read(MoleculeSettings.fileName)]
    }

    /// Opens a session, imports water from "my water.xyz" and sets the label mode to `selected`, takes the session's
    /// snapshot and the three files' bytes, then fails the session with the seam and closes it, asserting that the
    /// files stay byte for byte. Returns the snapshot taken before the failure and the bytes.
    private func importAndFail() async throws -> (snapshot: ExperienceSnapshot, bytes: [Data]) {
        let session = ExperienceSession()
        let shell = try await open(session)
        let url = files.appendingPathComponent("my water.xyz", isDirectory: false)
        try Data(MoleculeLibraryData.records[0].xyz.utf8).write(to: url)
        XCTAssertEqual(shell.presenter.importFile(at: url), .imported(title: "my water", atoms: 3, storageCode: nil))
        shell.presenter.setLabelMode(.selected)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(try MoleculeTest.core(shell).selection, MoleculeCore.importedSelection)
        let snapshot = try shell.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, MoleculeState.schemaVersion)
        let bytes = try storedFiles()
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName),
                       RecentMolecules(ids: [ImportedMolecule.id, "water"]).encoded())
        XCTAssertEqual(bytes[2], MoleculeSettings(labels: .selected).encoded())
        XCTAssertEqual(session.state, .running)

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A15-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storedFiles(), bytes, "import.xyz, recent.json and settings.json are unchanged")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(try storedFiles(), bytes, "the three files are unchanged after close")
        return (snapshot, bytes)
    }

    func testAFailedDrawLeavesTheFilesAndTheSnapshotRestoresTheImport() async throws {
        let (snapshot, bytes) = try await importAndFail()

        let fresh = ExperienceSession()
        defer { fresh.close() }
        let again = try await open(fresh, snapshot: snapshot)
        XCTAssertNil(fresh.failure)
        XCTAssertNil(fresh.lastRestoreRefusal)
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        XCTAssertEqual(fresh.state, .running)
        let core = try MoleculeTest.core(again)
        XCTAssertEqual(core.selection, MoleculeCore.importedSelection, "the imported molecule is shown")
        XCTAssertEqual(core.imported?.molecule.atoms.count, 3)
        XCTAssertEqual(again.presenter.lastAtomsDrawn, 3)
        XCTAssertEqual(again.presenter.mirror.nameLine, "my water — H2O", "the title comes from import-title.txt")
        XCTAssertEqual(again.presenter.mirror.labelMode, .selected, "the settings are read back")
        XCTAssertEqual(try storedFiles(), bytes, "reopening on the imported molecule rewrites nothing")
    }

    func testAFailedDrawLeavesTheFilesAndTheRecentListReplaysTheImport() async throws {
        let (_, bytes) = try await importAndFail()

        let fresh = ExperienceSession()
        defer { fresh.close() }
        let again = try await open(fresh)
        XCTAssertNil(fresh.failure)
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        XCTAssertEqual(fresh.state, .running)
        XCTAssertEqual(try MoleculeTest.core(again).selection, 0, "without a snapshot the session opens water")
        XCTAssertEqual(again.presenter.mirror.recentIDs, ["water", ImportedMolecule.id],
                       "opening water records it; the recent list still offers the import")
        XCTAssertEqual(again.presenter.mirror.labelMode, .selected)
        XCTAssertEqual(try temporary.storage.read(MoleculeImporter.fileName), bytes[0])

        let chosen = try XCTUnwrap(again.presenter.chooseRecent(ImportedMolecule.id, through: again.port))
        XCTAssertTrue(chosen.isAccepted, "the stored copy is replayed")
        XCTAssertTrue(host.renderOneFrame(present: false))
        let core = try MoleculeTest.core(again)
        XCTAssertEqual(core.selection, MoleculeCore.importedSelection, "the imported molecule is shown again")
        XCTAssertEqual(core.imported?.molecule.atoms.count, 3)
        XCTAssertEqual(again.presenter.lastAtomsDrawn, 3)
        XCTAssertEqual(again.presenter.mirror.nameLine, "my water — H2O")
        XCTAssertEqual(try temporary.storage.read(MoleculeImporter.fileName), bytes[0], "a replay never rewrites it")
        XCTAssertEqual(try temporary.storage.read(MoleculeSettings.fileName), bytes[2])
    }
}
