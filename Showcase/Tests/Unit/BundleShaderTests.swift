// BundleShaderTests — feature 007 T-F604 (FR-F604): bundled shader files load and includes resolve.
import XCTest
import VisualCoreShaderSource
@testable import Showcase

final class BundleShaderTests: XCTestCase {
    func testCommonIncludeIsBundledAndExpands() throws {
        XCTAssertNotNil(BundleShaders.source("common.glsl"))
        let lib = BundleShaders.library()
        let expanded = try lib.expand(source: "#include \"common.glsl\"\nvoid main() {}\n", named: "probe.frag")
        XCTAssertTrue(expanded.text.contains("vec3 hue(float h)"))
        XCTAssertEqual(expanded.origin(ofExpandedLine: expanded.text.split(separator: "\n", omittingEmptySubsequences: false)
            .firstIndex { $0.contains("vec3 hue") }! + 1).file, "common.glsl")
    }
}
