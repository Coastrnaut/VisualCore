// ModuleTests — feature 188 T-U02-001: the module exists and reports its version.
import XCTest
import VisualCoreExperienceHost

final class ExperienceHostModuleTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ExperienceHostInfo.version.isEmpty)
    }
}
