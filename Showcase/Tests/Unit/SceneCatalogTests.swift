// SceneCatalogTests — feature 007 T-F604 (FR-F603, FR-F609): catalog validation and the app catalog.
import XCTest
@testable import Showcase

@MainActor
final class SceneCatalogTests: XCTestCase {
    private func d(_ id: String, title: String = "T") -> SceneDescriptor {
        SceneDescriptor(id: id, title: title, summary: "S", accessibilityDescription: "A", interactionHint: "H") { _ in fatalError() }
    }

    func testValidationRejectsDuplicatesBadIdsAndEmptyText() {
        XCTAssertEqual(SceneCatalog.problems([d("a-b"), d("c")]), [])
        XCTAssertEqual(SceneCatalog.problems([d("a"), d("a")]), ["duplicate id a"])
        XCTAssertEqual(SceneCatalog.problems([d("Bad Id")]), ["id 'Bad Id' is not kebab-case"])
        XCTAssertEqual(SceneCatalog.problems([d("x", title: " ")]), ["x: empty title"])
    }

    func testAppCatalogIsValid() {
        XCTAssertEqual(SceneCatalog.problems(SceneCatalog.all), [])
        // FR-F603: the five README Phase 6 scenes, in order.
        XCTAssertEqual(SceneCatalog.all.map(\.id), ["gradient-texture", "animated-geometry", "distortion", "particles", "post-processing"])
    }

    func testBundleIdentifier() { XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.visualcore.Showcase") }
}
