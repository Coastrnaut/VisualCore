// MoleculeSchemaExampleTests — feature 115 (A15-P06) T-A15-606 (FR-A15-612; clarification Q5). The stored examples of
// schemas 1, 2 and 3 (`MoleculeCore.schemaOneExample()`, `schemaTwoExample()`, `schemaThreeExample()`) restore
// through the migration chain into schema 4 with the digest each declares, pass the shared migration check, and open in
// the engine with the values their payload held (no import, no pending import). The digests are computed by the
// examples themselves through the migration and the restore (as Solar System Explorer's are); the expected states here
// are written out by hand, so a migration that changed a value would fail even though the digest follows it.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience

final class MoleculeSchemaExampleTests: XCTestCase {
    /// The experience id `a15.molecular-explorer`.
    private let id = ExperienceID(rawValue: MoleculeCore.experienceID)!

    /// The three stored examples, schema 1 first.
    private func examples() -> [MigrationExample] {
        [MoleculeCore.schemaOneExample(), MoleculeCore.schemaTwoExample(), MoleculeCore.schemaThreeExample()]
            .compactMap { $0 }
    }

    func testThreeExamplesExistWithTheirVersions() throws {
        XCTAssertEqual(examples().map(\.version), [1, 2, 3])
        XCTAssertNil(MoleculeCore.schemaExample(version: 4), "schema 4 is current, not an example")
        XCTAssertNil(MoleculeCore.schemaExample(version: 0))
        for example in examples() {
            let snapshot = try ExperienceSnapshot(data: example.snapshot)
            XCTAssertEqual(snapshot.experience, id)
            XCTAssertEqual(snapshot.schemaVersion, example.version, "the envelope keeps the stored schema")
            XCTAssertEqual(example.expectedDigest.count, 64)
            let object = try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
            let payload = try XCTUnwrap(object as? [String: Any])
            XCTAssertEqual(payload["schema"] as? Int, example.version, "the payload is the stored schema's")
        }
    }

    func testTheSharedMigrationCheckAcceptsTheExamples() async {
        let problems = await SnapshotMigrationCheck.problems(for: MoleculeCore.self, id: id, examples: examples())
        XCTAssertTrue(problems.isEmpty, "\(problems)")
    }

    func testEachExampleOpensWithItsValues() async throws {
        let expected: [MoleculeState] = [
            MoleculeState(selection: 4),
            MoleculeState(selection: 4, mode: .spaceFilling,
                          camera: CameraSettings(turnSteps: 5, tiltSteps: 3, zoomSteps: 1)),
            MoleculeState(selection: 4, mode: .spaceFilling,
                          camera: CameraSettings(turnSteps: 5, tiltSteps: 3, zoomSteps: 1, panX: 2, panY: -1),
                          selectedAtom: 3),
        ]
        XCTAssertEqual(examples().count, expected.count)
        for (example, state) in zip(examples(), expected) {
            var engine = ExperienceEngine<MoleculeCore>(id: id)
            try await engine.prepare(seed: 7)
            try engine.restore(ExperienceSnapshot(data: example.snapshot))
            let core = try XCTUnwrap(engine.core)
            XCTAssertEqual(core.state, state, "schema \(example.version)")
            XCTAssertNil(core.imported, "schema \(example.version): no import")
            XCTAssertNil(core.state.pending, "schema \(example.version): no pending import")
            XCTAssertEqual(try engine.digest().hex, example.expectedDigest, "schema \(example.version)")
            XCTAssertEqual(try moleculeDigest(core), example.expectedDigest, "schema \(example.version)")
        }
    }
}
