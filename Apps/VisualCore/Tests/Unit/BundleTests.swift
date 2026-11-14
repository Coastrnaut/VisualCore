// BundleTests — feature 190 T-U04-001 (FR-U04-001, FR-U04-003, FR-U04-034, FR-U04-071): what the built app declares.
import XCTest
@testable import VisualCoreApp

final class BundleTests: XCTestCase {
    func testIdentifierAndDisplayName() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.visualcore.VisualCore")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "VisualCore")
    }

    /// Feature 193 (FR-U07-020, FR-A01-407): the Photos add-only usage description that the share sheet's "Save Image"
    /// needs for an exported picture (the app itself never calls PhotoKit), and since feature 047 (A06-P01,
    /// FR-A06-106) the microphone description of VisualCore Music Lab's live input, worded from
    /// `Configs/permission-vocabulary.json`; nothing else.
    func testNoUsageDescriptionNoURLTypeNoDocumentType() throws {
        let info = try XCTUnwrap(Bundle.main.infoDictionary)
        XCTAssertEqual(info.keys.filter { $0.hasSuffix("UsageDescription") }.sorted(),
                       ["NSMicrophoneUsageDescription", "NSPhotoLibraryAddUsageDescription"], "\(info.keys.sorted())")
        XCTAssertEqual(info["NSMicrophoneUsageDescription"] as? String,
                       "Listens to sound in the room to drive the visuals; audio stays on this device and is not recorded.")
        XCTAssertEqual(info["NSPhotoLibraryAddUsageDescription"] as? String,
                       "Saves exported artwork to your photo library when you choose Save Image.")
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
