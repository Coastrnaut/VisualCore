// BundleTests — feature 190 T-U04-001 (FR-U04-001, FR-U04-003, FR-U04-034, FR-U04-071): what the built app declares.
import XCTest
@testable import VisualCoreApp

final class BundleTests: XCTestCase {
    func testIdentifierAndDisplayName() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.visualcore.VisualCore")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "VisualCore")
    }

    func testNoUsageDescriptionNoURLTypeNoDocumentType() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertTrue(info.keys.filter { $0.hasSuffix("UsageDescription") }.isEmpty, "\(info.keys.sorted())")
        XCTAssertNil(info["CFBundleURLTypes"])
        XCTAssertNil(info["CFBundleDocumentTypes"])
    }

    /// FR-U04-054: the version the about route shows is the short version and the build of the bundle.
    func testTheAboutVersionIsTheBundleVersion() throws {
        let short = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        XCTAssertFalse(short.isEmpty)
        XCTAssertFalse(build.isEmpty)
        XCTAssertEqual(AboutView.version(), "\(short) (\(build))")
    }

    func testTheCatalogFilesAreBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "experiences", withExtension: "json"))
        XCTAssertNotNil(Bundle.main.url(forResource: "categories", withExtension: "json"))
    }
}
