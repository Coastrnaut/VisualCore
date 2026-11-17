// AnatomySchemaExampleTests — X-A17 follow-through (2026-11-16). The stored schema-1 example
// (`AnatomyCore.schemaOneExample()`) restores through the migration chain into view schema 2 with the digest it
// declares, passes the shared migration check, and opens in the engine with the values its payload held and no isolate.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience

final class AnatomySchemaExampleTests: XCTestCase {
    /// The experience id `a17.interactive-anatomy`.
    private let id = ExperienceID(rawValue: AnatomyCore.experienceID)!

    func testOneExampleExistsForSchemaOneOnly() throws {
        let example = try XCTUnwrap(AnatomyCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        XCTAssertNil(AnatomyCore.schemaExample(version: AnatomyViewState.schemaVersion), "schema 2 is current")
        XCTAssertNil(AnatomyCore.schemaExample(version: 0))
    }

    func testTheSharedMigrationCheckAcceptsTheExample() async throws {
        let example = try XCTUnwrap(AnatomyCore.schemaOneExample())
        let problems = await SnapshotMigrationCheck.problems(for: AnatomyCore.self, id: id, examples: [example])
        XCTAssertTrue(problems.isEmpty, "\(problems)")
    }

    func testTheExampleOpensWithItsValues() async throws {
        let example = try XCTUnwrap(AnatomyCore.schemaOneExample())
        var engine = ExperienceEngine<AnatomyCore>(id: id)
        try await engine.prepare(seed: 7)
        try engine.restore(ExperienceSnapshot(data: example.snapshot))
        let view = try XCTUnwrap(engine.core).view
        XCTAssertEqual(view.camera, AnatomyCameraState(turn: 5, tilt: 2, zoom: 1))
        XCTAssertEqual(view.visibleLayers, [true, true, false])
        XCTAssertEqual(view.selection, "knee.tibia")
        XCTAssertEqual(view.framed, "knee.tibia")
        XCTAssertNil(view.isolate, "schema 1 has no isolate")
        XCTAssertEqual(view.schema, AnatomyViewState.schemaVersion)
    }
}
