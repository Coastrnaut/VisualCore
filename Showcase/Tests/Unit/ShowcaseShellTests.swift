// ShowcaseShellTests — feature 007 T-F601: the hosted unit-test bundle runs inside the Showcase app.
import XCTest
@testable import Showcase

final class ShowcaseShellTests: XCTestCase {
    func testBundleIdentifier() { XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.visualcore.Showcase") }
}
