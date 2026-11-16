// MoleculeLeakTests — feature 114 (A15-P05) T-A15-509 (FR-A15-530; SC-A15-505; research D6). The drawing resources of
// Molecular Explorer stay steady over repeated use in the one app's session host on the simulator: after the first
// frames the shell's snapshot is taken; then ten rounds each choose every library molecule in turn
// (`molecule.select`, two frames each), import a small valid XYZ file through the presenter's `importFile(at:)` (a
// temporary file, the copy kept in memory by the factory's importer) and restore the snapshot (two frames). After every
// round the `ResourceLedger` live counts and live bytes per kind equal round 1's and nothing leaked; closing the
// session leaves no GPU object. Short: about 150 frames at 240 × 160 points, no wall-clock assertion.
import Foundation
import XCTest
import VisualCoreDiagnostics
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost

/// Ten rounds of choosing, importing and restoring keep Molecular Explorer's drawing resources steady.
@MainActor
final class MoleculeLeakTests: XCTestCase {
    /// The temporary folder the imported file is written to.
    private var files: URL!

    override func setUp() async throws {
        files = FileManager.default.temporaryDirectory
            .appendingPathComponent("me-leak-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: files)
    }

    func testTenRoundsOfChoosingImportingAndRestoringKeepTheResourcesSteady() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        let presenter = shell.presenter
        try MoleculeTest.frames(session, 2)
        let host = try XCTUnwrap(session.renderHost)
        let first = host.resources.stats
        XCTAssertEqual(first.leaked, 0, "after the first frames")
        let snapshot = try shell.snapshot()
        let url = files.appendingPathComponent("hydrogen chloride.xyz", isDirectory: false)
        try Data("2\nHCl\nCl 0 0 0\nH 1.27 0 0\n".utf8).write(to: url)

        var reference: ResourceLedger.Snapshot?
        for round in 1...10 {
            for index in 0..<MoleculeCore.moleculeCount {
                XCTAssertTrue(presenter.send("molecule.select", [Double(index)], through: shell.port).isAccepted,
                              "round \(round): molecule \(index)")
                try MoleculeTest.frames(session, 2)
                XCTAssertEqual(presenter.lastSelection, index, "round \(round)")
            }
            XCTAssertEqual(presenter.importFile(at: url),
                           .imported(title: "hydrogen chloride", atoms: 2, storageCode: nil), "round \(round)")
            try MoleculeTest.frames(session, 2)
            XCTAssertEqual(try MoleculeTest.core(shell).selection, MoleculeCore.importedSelection, "round \(round)")
            XCTAssertEqual(presenter.lastAtomsDrawn, 2, "round \(round): the import is drawn")

            try shell.restore(snapshot)
            try MoleculeTest.frames(session, 2)
            XCTAssertEqual(try MoleculeTest.core(shell).state, MoleculeState.initial, "round \(round): restored")
            XCTAssertEqual(presenter.lastAtomsDrawn, 3, "round \(round): water is drawn again")

            let stats = host.resources.stats
            XCTAssertEqual(stats.leaked, 0, "round \(round)")
            if let reference {
                XCTAssertEqual(stats.liveCount, reference.liveCount, "round \(round): the same live objects per kind")
                XCTAssertEqual(stats.liveBytes, reference.liveBytes, "round \(round): the same live bytes per kind")
            } else {
                reference = stats
            }
        }
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "closing leaves no GPU object")
        XCTAssertEqual(shell.state, .inactive)
    }
}
