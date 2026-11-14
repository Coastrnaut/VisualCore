// PrivacyTests — feature 031 T-A03-601 (FR-A03-601, SC-A03-601; US1 AC1–AC2), after A02's (feature 024). The app
// declares one usage string and stores only the bookmarks the person saves. Entries written by the system (defaults
// keys with Apple prefixes, Library/Caches, Preferences, SplashBoard, Saved Application State) and Debug-only
// automation reports are listed in the output, not hidden, and never count as the app's own data.
import FractalExplorerCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import XCTest
@testable import FractalExplorerExperience

@MainActor
final class PrivacyTests: XCTestCase {
    static let systemKeyPrefixes = ["Apple", "NS", "AK", "com.apple.", "PK", "WebKit", "MSV", "UIKit", "_UI", "XCT", "XC"]
    static let systemLibraryEntries: Set<String> = ["Caches", "Preferences", "SplashBoard", "Saved Application State",
                                                    "HTTPStorages", "Cookies", "WebKit"]

    /// Since feature 193 the declaring app is the one app, whose one Photos add-only string serves every experience's
    /// share sheet; the test reads its target's info properties in the repository's project.yml.
    func testOnlyPhotosAddUsageStringIsDeclared() throws {
        let spec = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("project.yml")
        let lines = try String(contentsOf: spec, encoding: .utf8).components(separatedBy: "\n")
        let targets = try XCTUnwrap(lines.firstIndex(of: "targets:"))
        let start = try XCTUnwrap(lines[targets...].firstIndex(of: "  VisualCore:"), "the one app's target")
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("  ") && !$0.hasPrefix("   ") && $0.hasSuffix(":") }
            ?? lines.endIndex
        let target = lines[start..<end].map { $0.trimmingCharacters(in: .whitespaces) }
        let usage = target.filter { $0.hasPrefix("NS") && $0.contains("UsageDescription:") }
        // Since feature 047 (A06-P01) the app also declares the microphone string of VisualCore Music Lab (live input
        // drives its visuals on the device); this experience still asks for nothing but Photos add.
        XCTAssertEqual(usage.count, 2, "\(usage)")
        XCTAssertTrue(usage.contains { $0.hasPrefix("NSPhotoLibraryAddUsageDescription:") }, "\(usage)")
        XCTAssertTrue(usage.contains { $0.hasPrefix("NSMicrophoneUsageDescription:") }, "\(usage)")
        XCTAssertTrue(target.contains("ITSAppUsesNonExemptEncryption: false"), "export compliance")
    }

    func testSessionStoresOnlyTheSavedBookmark() throws {
        // Since feature 193 the test runs in the experience package's test bundle, which has no app container of its
        // own, so it compares the defaults keys and the Documents and Library listings before and after the session.
        let dir = BookmarkLibrary.defaultDirectory(named: "Bookmarks")
        try? FileManager.default.removeItem(at: dir)
        let fmBefore = FileManager.default
        let bundleIDBefore = Bundle.main.bundleIdentifier ?? "dev.visualcore.FractalExplorer"
        let keysBefore = Set((UserDefaults.standard.persistentDomain(forName: bundleIDBefore) ?? [:]).keys)
        let docsBefore = Set((try? fmBefore.contentsOfDirectory(atPath: fmBefore.urls(for: .documentDirectory,
                                                                                      in: .userDomainMask)[0].path)) ?? [])
        let libBefore = Set((try? fmBefore.contentsOfDirectory(atPath: fmBefore.urls(for: .libraryDirectory,
                                                                                     in: .userDomainMask)[0].path)) ?? [])
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
        let own = keys.filter { key in !keysBefore.contains(key) && !Self.systemKeyPrefixes.contains { key.hasPrefix($0) } }
        print("privacy: defaults keys \(keys.count) (system: \(keys.count - own.count)), app keys \(own)")
        XCTAssertEqual(own, [], "the app writes no defaults keys")

        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let docs = ((try? fm.contentsOfDirectory(atPath: documents.path)) ?? []).sorted()
        print("privacy: Documents \(docs) (Debug-only automation reports excluded)")
        XCTAssertEqual(docs.filter { !docsBefore.contains($0) && !$0.hasPrefix("visualcore-automation-") }, [], "no documents")
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let lib = ((try? fm.contentsOfDirectory(atPath: library.path)) ?? []).sorted()
        print("privacy: Library \(lib)")
        // LanguageModeling holds the system keyboard's dynamic lexicon (`<language>-dynamic.lm`), created by iOS when
        // someone types in a text field (bookmark names, Go to). Provenance checked on the simulator (feature 031):
        // it is allowed only when it contains nothing else.
        let modeling = ((try? fm.contentsOfDirectory(atPath: library.appendingPathComponent("LanguageModeling").path)) ?? []).sorted()
        print("privacy: LanguageModeling \(modeling)")
        XCTAssertTrue(modeling.allSatisfy { $0.hasSuffix("-dynamic.lm") }, "only the keyboard's dynamic lexicon")
        XCTAssertEqual(lib.filter { !libBefore.contains($0) && !Self.systemLibraryEntries.contains($0) && $0 != "Application Support" && $0 != "LanguageModeling" }, [],
                       "only system-managed Library folders and Application Support")
        let support = ((try? fm.contentsOfDirectory(atPath: library.appendingPathComponent("Application Support").path)) ?? []).sorted()
        print("privacy: Application Support \(support)")
        XCTAssertTrue(support.contains("Bookmarks"), "the bookmark folder")
        let bookmarks = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".json") }
        XCTAssertEqual(bookmarks.count, 1, "only the bookmark the person saved")
        XCTAssertEqual(StillCapture.folder(named: ExplorerModel.captureFolderName).fileCount, 0, "no capture left")
        try? fm.removeItem(at: dir)
    }
}
