// PrivacyTests — feature 024 T-A02-603 (FR-A02-602, FR-A02-606; SC-A02-601, SC-A02-603; US1 AC2–AC3; US3 AC2).
// The app declares one usage string and stores nothing of its own. Entries written by the system (defaults keys
// with Apple prefixes, Library/Caches, Preferences, SplashBoard, Saved Application State) and Debug-only automation
// reports are listed in the output, not hidden, and never count as the app's own data.
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import XCTest
@testable import FluidArtPlayground

@MainActor
final class PrivacyTests: XCTestCase {
    static let systemKeyPrefixes = ["Apple", "NS", "AK", "com.apple.", "PK", "WebKit", "MSV", "UIKit", "_UI", "XCT", "XC"]
    static let systemLibraryEntries: Set<String> = ["Caches", "Preferences", "SplashBoard", "Saved Application State",
                                                    "HTTPStorages", "Application Support", "Cookies", "WebKit"]

    /// FR-A02-602: exactly one usage string, Photos add-only, with the documented text.
    func testOnlyPhotosAddUsageStringIsDeclared() {
        let info = Bundle(for: PlaygroundModel.self).infoDictionary ?? Bundle.main.infoDictionary ?? [:]
        let usage = info.keys.filter { $0.hasSuffix("UsageDescription") }.sorted()
        XCTAssertEqual(usage, ["NSPhotoLibraryAddUsageDescription"])
        XCTAssertEqual(info["NSPhotoLibraryAddUsageDescription"] as? String,
                       "Fluid Art Playground saves your captured picture to Photos only when you choose Save Image.")
    }

    /// FR-A02-606: after painting, capturing and closing, the app has written no defaults keys and no files.
    func testSessionStoresNothing() throws {
        let model = PlaygroundModel()
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 200, height: 400)
        host.view.layoutIfNeeded()
        model.handle(PointerEvent(id: 1, phase: .began, location: Vec2(50, 100), timestamp: 0))
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(120, 220), timestamp: 0.05))
        model.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(150, 260), timestamp: 0.1))
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        model.configuration.viscosity = 0.3
        model.togglePause()
        model.setDetail(.low)
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.captureStill()
        model.close()

        let bundleID = Bundle.main.bundleIdentifier ?? "dev.visualcore.FluidArtPlayground"
        let keys = Array((UserDefaults.standard.persistentDomain(forName: bundleID) ?? [:]).keys).sorted()
        let own = keys.filter { key in !Self.systemKeyPrefixes.contains { key.hasPrefix($0) } }
        print("privacy: defaults keys \(keys.count) (system: \(keys.count - own.count)), app keys \(own)")
        XCTAssertEqual(own, [], "the app writes no defaults keys")

        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docs = ((try? fm.contentsOfDirectory(atPath: documents.path)) ?? []).sorted()
        let ownDocs = docs.filter { !$0.hasPrefix("visualcore-automation-") }
        print("privacy: Documents \(docs) (Debug-only automation reports excluded)")
        XCTAssertEqual(ownDocs, [], "no documents")
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let lib = ((try? fm.contentsOfDirectory(atPath: library.path)) ?? []).sorted()
        print("privacy: Library \(lib)")
        XCTAssertEqual(lib.filter { !Self.systemLibraryEntries.contains($0) }, [], "only system-managed Library folders")
        XCTAssertEqual(CaptureModel.folder.fileCount, 0, "the temporary capture was removed on close")
    }
}
