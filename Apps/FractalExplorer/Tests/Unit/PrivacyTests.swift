// PrivacyTests — feature 031 T-A03-601 (FR-A03-601, SC-A03-601; US1 AC1–AC2), after A02's (feature 024). The app
// declares one usage string and stores only the bookmarks the person saves. Entries written by the system (defaults
// keys with Apple prefixes, Library/Caches, Preferences, SplashBoard, Saved Application State) and Debug-only
// automation reports are listed in the output, not hidden, and never count as the app's own data.
import FractalExplorerCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import XCTest
@testable import FractalExplorer

@MainActor
final class PrivacyTests: XCTestCase {
    static let systemKeyPrefixes = ["Apple", "NS", "AK", "com.apple.", "PK", "WebKit", "MSV", "UIKit", "_UI", "XCT", "XC"]
    static let systemLibraryEntries: Set<String> = ["Caches", "Preferences", "SplashBoard", "Saved Application State",
                                                    "HTTPStorages", "Cookies", "WebKit"]

    func testOnlyPhotosAddUsageStringIsDeclared() {
        let info = Bundle(for: ExplorerModel.self).infoDictionary ?? Bundle.main.infoDictionary ?? [:]
        let usage = info.keys.filter { $0.hasSuffix("UsageDescription") }.sorted()
        XCTAssertEqual(usage, ["NSPhotoLibraryAddUsageDescription"])
        XCTAssertEqual(info["NSPhotoLibraryAddUsageDescription"] as? String,
                       "Fractal Explorer saves your captured picture to Photos only when you choose Save Image.")
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false, "export compliance")
    }

    func testSessionStoresOnlyTheSavedBookmark() throws {
        let dir = BookmarkLibrary.defaultDirectory(named: "Bookmarks")
        try? FileManager.default.removeItem(at: dir)
        let model = ExplorerModel(size: Vec2(300, 400))
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        host.view.layoutIfNeeded()
        model.handle(PointerEvent(id: 1, phase: .began, location: Vec2(50, 100), timestamp: 0))
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(120, 220), timestamp: 0.05))
        model.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(150, 260), timestamp: 0.1))
        model.doubleCap()
        XCTAssertNotNil(model.saveBookmark(name: "Privacy check"))
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.captureStill()
        model.startTour("seahorse", now: 0)
        model.tourTick(now: 5)
        model.close()

        let bundleID = Bundle.main.bundleIdentifier ?? "dev.visualcore.FractalExplorer"
        let keys = Array((UserDefaults.standard.persistentDomain(forName: bundleID) ?? [:]).keys).sorted()
        let own = keys.filter { key in !Self.systemKeyPrefixes.contains { key.hasPrefix($0) } }
        print("privacy: defaults keys \(keys.count) (system: \(keys.count - own.count)), app keys \(own)")
        XCTAssertEqual(own, [], "the app writes no defaults keys")

        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docs = ((try? fm.contentsOfDirectory(atPath: documents.path)) ?? []).sorted()
        print("privacy: Documents \(docs) (Debug-only automation reports excluded)")
        XCTAssertEqual(docs.filter { !$0.hasPrefix("visualcore-automation-") }, [], "no documents")
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let lib = ((try? fm.contentsOfDirectory(atPath: library.path)) ?? []).sorted()
        print("privacy: Library \(lib)")
        // LanguageModeling holds the system keyboard's dynamic lexicon (`<language>-dynamic.lm`), created by iOS when
        // someone types in a text field (bookmark names, Go to). Provenance checked on the simulator (feature 031):
        // it is allowed only when it contains nothing else.
        let modeling = ((try? fm.contentsOfDirectory(atPath: library.appendingPathComponent("LanguageModeling").path)) ?? []).sorted()
        print("privacy: LanguageModeling \(modeling)")
        XCTAssertTrue(modeling.allSatisfy { $0.hasSuffix("-dynamic.lm") }, "only the keyboard's dynamic lexicon")
        XCTAssertEqual(lib.filter { !Self.systemLibraryEntries.contains($0) && $0 != "Application Support" && $0 != "LanguageModeling" }, [],
                       "only system-managed Library folders and Application Support")
        let support = ((try? fm.contentsOfDirectory(atPath: library.appendingPathComponent("Application Support").path)) ?? []).sorted()
        print("privacy: Application Support \(support)")
        XCTAssertEqual(support, ["Bookmarks"], "only the bookmark folder")
        let bookmarks = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".json") }
        XCTAssertEqual(bookmarks.count, 1, "only the bookmark the person saved")
        XCTAssertEqual(StillCapture.folder(named: ExplorerModel.captureFolderName).fileCount, 0, "no capture left")
        try? fm.removeItem(at: dir)
    }
}
