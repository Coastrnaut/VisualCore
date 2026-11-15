// SolarSchemaExampleTests — feature 108 (A14-P06) T-A14-606 (FR-A14-612; clarification Q5). The stored examples of
// schemas 1, 2 and 3 restore through the migration chain into schema 4 with the digest each declares, pass the shared
// migration check, and open in the engine with the values their payload held (the clock paused at rate 0, no tour).
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience

final class SolarSchemaExampleTests: XCTestCase {
    private let id = ExperienceID(rawValue: SolarCore.experienceID)!

    private func examples() -> [MigrationExample] {
        [SolarCore.schemaOneExample(), SolarCore.schemaTwoExample(), SolarCore.schemaThreeExample()].compactMap { $0 }
    }

    func testThreeExamplesExistWithTheirVersions() {
        XCTAssertEqual(examples().map(\.version), [1, 2, 3])
        XCTAssertNil(SolarCore.schemaExample(version: 4), "schema 4 is current, not an example")
    }

    func testTheSharedMigrationCheckAcceptsTheExamples() async {
        let problems = await SnapshotMigrationCheck.problems(for: SolarCore.self, id: id, examples: examples())
        XCTAssertTrue(problems.isEmpty, "\(problems)")
    }

    func testEachExampleOpensWithItsValues() async throws {
        let expected: [SolarState] = [
            SolarState(selection: 3),
            try XCTUnwrap(SolarState(selection: 3, dayOffset: 30, yawSteps: 1, pitchDegrees: 45, zoomSteps: 2)),
            try XCTUnwrap(SolarState(selection: 3, dayOffset: 30, yawSteps: 1, pitchDegrees: 45, zoomSteps: 2,
                                     scaleMode: .trueRelative)),
        ]
        for (example, state) in zip(examples(), expected) {
            var engine = ExperienceEngine<SolarCore>(id: id)
            try await engine.prepare(seed: 7)
            try engine.restore(ExperienceSnapshot(data: example.snapshot))
            let core = try XCTUnwrap(engine.core)
            XCTAssertEqual(core.state, state, "schema \(example.version)")
            XCTAssertFalse(core.state.playing)
            XCTAssertEqual(core.state.tourIndex, -1)
            XCTAssertEqual(try engine.digest().hex, example.expectedDigest, "schema \(example.version)")
        }
    }
}
