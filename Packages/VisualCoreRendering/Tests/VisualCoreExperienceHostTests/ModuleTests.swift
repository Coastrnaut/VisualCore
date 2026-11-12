// ModuleTests — feature 188 T-U02-001: the module exists and reports its version.
import XCTest
import VisualCoreExperienceHost

final class ExperienceHostModuleTests: XCTestCase {
    func testVersionIsNotEmpty() {
        XCTAssertFalse(ExperienceHostInfo.version.isEmpty)
    }

    /// Feature 189 T-U03-001 (FR-U03-063): every text of the session's views comes from the string catalog.
    func testEveryTextKeyResolves() {
        XCTAssertEqual(SessionStrings.Key.allCases.count, 7)
        for key in SessionStrings.Key.allCases {
            let text = SessionStrings.text(key)
            XCTAssertFalse(text.isEmpty, key.rawValue)
            XCTAssertNotEqual(text, key.rawValue, "no text for \(key.rawValue)")
        }
        XCTAssertEqual(SessionStrings.text(.back), "Back")
    }
}
