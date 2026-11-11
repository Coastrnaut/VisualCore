// NavigationModelTests — feature 028 T-A03-305 (FR-A03-304; US1 AC1–AC3, US2 AC1–AC3; checklist CHK002).
import FractalExplorerCore
import VisualCoreMath
import VisualCorePersistence
import XCTest
@testable import FractalExplorer

@MainActor
final class NavigationModelTests: XCTestCase {
    private var folders: [URL] = []
    override func tearDown() { folders.forEach { try? FileManager.default.removeItem(at: $0) } }

    private func model(size: Vec2 = Vec2(300, 400), folder: URL? = nil) -> (ExplorerModel, URL) {
        let dir = folder ?? FileManager.default.temporaryDirectory.appendingPathComponent("fe-nav-\(UUID().uuidString)")
        folders.append(dir)
        let m = ExplorerModel(size: size, bookmarksDirectory: dir)
        m.close()
        m.mantissaBitsOverride = 23
        m.pixelsPerPointOverride = 3
        return (m, dir)
    }

    func testSaveReloadAndOpenAtAnotherSizeReturnsTheView() throws {
        let (m, dir) = model()
        m.state.mode = .julia
        m.state.juliaSeed = Vec2(0.285, 0.01)
        m.state.iterationCap = 750
        m.paletteID = "neon"
        m.zoomIn(); m.zoomIn(); m.zoomIn()
        m.apply(m.state.viewport.panned(by: Vec2(37, -12)))
        let saved = m.state
        let entry = try XCTUnwrap(m.saveBookmark(name: "  Spiral  "))
        XCTAssertEqual(entry.name, "Spiral")
        XCTAssertEqual(entry.payload.precision.mantissaBits, 23)

        // A second model on another canvas shape (a relaunch in landscape).
        let (other, _) = model(size: Vec2(844, 390), folder: dir)
        other.reloadBookmarks()
        XCTAssertEqual(other.bookmarks.entries.count, 1)
        other.open(entry.id)
        XCTAssertEqual(other.state.mode, .julia)
        XCTAssertEqual(other.state.juliaSeed, saved.juliaSeed)
        XCTAssertEqual(other.state.iterationCap, 750)
        XCTAssertEqual(other.paletteID, "neon")
        XCTAssertEqual(other.state.viewport.center, saved.viewport.center)
        let span = saved.viewport.unitsPerPoint * 300, back = other.state.viewport.unitsPerPoint * 390
        XCTAssertEqual(back, span, accuracy: span * 1e-12)
        XCTAssertEqual(other.state.viewport.size, Vec2(844, 390))
    }

    func testRenameFavoriteDeleteAndOrdering() throws {
        let (m, _) = model()
        let a = try XCTUnwrap(m.saveBookmark(name: "A"))
        let b = try XCTUnwrap(m.saveBookmark(name: ""))
        XCTAssertEqual(b.name, "Untitled")
        m.setFavorite(a.id, true)
        XCTAssertEqual(m.bookmarks.entries.first?.id, a.id)
        m.renameBookmark(b.id, to: "Bee")
        XCTAssertEqual(m.bookmarks.entry(b.id)?.name, "Bee")
        m.deleteBookmark(a.id)
        XCTAssertEqual(m.bookmarks.entries.map(\.id), [b.id])
        XCTAssertNil(m.bookmarkError)
    }

    func testDamagedFileIsReportedAndKept() throws {
        let (m, dir) = model()
        try XCTUnwrap(m.saveBookmark(name: "Good"))
        let damaged = dir.appendingPathComponent("damaged.json")
        try Data("nonsense".utf8).write(to: damaged)
        m.reloadBookmarks()
        XCTAssertEqual(m.bookmarks.entries.count, 1)
        XCTAssertEqual(m.bookmarks.problems.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: damaged.path))
    }

    func testWriteFailureLeavesListAndViewUnchanged() throws {
        // The folder path is an existing regular file, so no bookmark can be written there.
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("fe-blocker-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        folders.append(blocker)
        let (m, _) = model(folder: blocker)
        m.zoomIn()
        let before = m.state
        XCTAssertNil(m.saveBookmark(name: "Nope"))
        XCTAssertEqual(m.bookmarkError?.hasPrefix("The bookmark was not saved."), true)
        XCTAssertTrue(m.bookmarks.entries.isEmpty)
        XCTAssertEqual(m.state, before)
    }
}
