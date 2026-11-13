// PrivacyTests — feature 024 T-A02-603 (FR-A02-602, FR-A02-606; SC-A02-601, SC-A02-603; US1 AC2–AC3; US3 AC2).
// The app declares one usage string and stores nothing of its own. Entries written by the system (defaults keys
// with Apple prefixes, Library/Caches, Preferences, SplashBoard, Saved Application State) and Debug-only automation
// reports are listed in the output, not hidden, and never count as the app's own data.
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import XCTest
@testable import FluidArtPlaygroundExperience

@MainActor
final class PrivacyTests: XCTestCase {
    static let systemKeyPrefixes = ["Apple", "NS", "AK", "com.apple.", "PK", "WebKit", "MSV", "UIKit", "_UI", "XCT", "XC"]
    static let systemLibraryEntries: Set<String> = ["Caches", "Preferences", "SplashBoard", "Saved Application State",
                                                    "HTTPStorages", "Application Support", "Cookies", "WebKit"]

    /// FR-A02-602: exactly one usage string, Photos add-only, with the documented text.
    /// Since feature 193 the declaring app is the one app, whose one Photos add-only string serves every experience's
    /// share sheet: the test reads its target's info properties in the repository's project.yml.
    func testOnlyPhotosAddUsageStringIsDeclared() throws {
        let spec = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("project.yml")
        let lines = try String(contentsOf: spec, encoding: .utf8).components(separatedBy: "\n")
        let targets = try XCTUnwrap(lines.firstIndex(of: "targets:"))
        let start = try XCTUnwrap(lines[targets...].firstIndex(of: "  VisualCore:"), "the one app's target")
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("  ") && !$0.hasPrefix("   ") && $0.hasSuffix(":") }
            ?? lines.endIndex
        let usage = lines[start..<end].map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("NS") && $0.contains("UsageDescription:") }
        XCTAssertEqual(usage.count, 1)
        XCTAssertTrue(usage.first?.hasPrefix("NSPhotoLibraryAddUsageDescription:") ?? false, "\(usage)")
    }

    /// FR-A02-606: after painting, capturing and closing, the app has written no defaults keys and no files.
    /// Since feature 193 the test runs in the experience package's test bundle, which has no app container of its
    /// own, so it compares the defaults keys and the Documents and Library listings before and after the session:
    /// nothing may appear.
    func testSessionStoresNothing() throws {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let library = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.visualcore.FluidArtPlayground"
        func keys() -> Set<String> { Set((UserDefaults.standard.persistentDomain(forName: bundleID) ?? [:]).keys) }
        func listing(_ url: URL) -> Set<String> { Set((try? fm.contentsOfDirectory(atPath: url.path)) ?? []) }
        let keysBefore = keys(), docsBefore = listing(documents), libBefore = listing(library)
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

        let own = keys().subtracting(keysBefore).filter { key in !Self.systemKeyPrefixes.contains { key.hasPrefix($0) } }
        print("privacy: new defaults keys \(own.sorted())")
        XCTAssertEqual(own, [], "the session writes no defaults keys")
        let newDocs = listing(documents).subtracting(docsBefore).filter { !$0.hasPrefix("visualcore-automation-") }
        print("privacy: new Documents entries \(newDocs.sorted()) (Debug-only automation reports excluded)")
        XCTAssertEqual(newDocs, [], "no documents")
        let newLib = listing(library).subtracting(libBefore).filter { !Self.systemLibraryEntries.contains($0) }
        print("privacy: new Library entries \(newLib.sorted())")
        XCTAssertEqual(newLib, [], "only system-managed Library folders")
        XCTAssertEqual(CaptureModel.folder.fileCount, 0, "the temporary capture was removed on close")
    }
}
