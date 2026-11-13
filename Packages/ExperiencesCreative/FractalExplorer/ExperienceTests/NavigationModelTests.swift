// NavigationModelTests — feature 028 T-A03-305 (FR-A03-304; US1 AC1–AC3, US2 AC1–AC3; checklist CHK002).
import FractalExplorerCore
import VisualCoreMath
import VisualCorePersistence
import XCTest
@testable import FractalExplorerExperience

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

// Feature 028 T-A03-307 (US3 AC1–AC3, SC-A03-304): the precision mode travels with the bookmark.
@MainActor
final class BookmarkPrecisionTests: XCTestCase {
    private var folders: [URL] = []
    override func tearDown() { folders.forEach { try? FileManager.default.removeItem(at: $0) } }

    private func model(bits: Int, folder: URL) -> ExplorerModel {
        folders.append(folder)
        let m = ExplorerModel(size: Vec2(300, 400), bookmarksDirectory: folder)
        m.close()
        m.mantissaBitsOverride = bits
        m.pixelsPerPointOverride = 3
        return m
    }

    func testDeepBookmarkOpensClampedWithBannerAndNote() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-prec-\(UUID().uuidString)")
        let deep = model(bits: 23, folder: dir)
        for _ in 0..<60 { deep.zoomIn() }
        XCTAssertEqual(deep.notice, .reached)
        let entry = try XCTUnwrap(deep.saveBookmark(name: "Deep"))
        XCTAssertEqual(entry.payload.precision.mantissaBits, 23)
        XCTAssertEqual(entry.payload.precision.level, .beyondLimit)

        let shallow = model(bits: 10, folder: dir)
        shallow.reloadBookmarks()
        shallow.open(entry.id)
        XCTAssertEqual(shallow.notice, .reached)
        XCTAssertEqual(shallow.notice.text, "Precision limit reached — zoom stops here")
        XCTAssertEqual(shallow.bookmarkNote, "Saved at higher precision (23 bits); shown at this device's limit (10 bits)")
        XCTAssertEqual(shallow.state.viewport.center, entry.payload.framing.center)
        let minUnits = PrecisionAdvisor.minimumPixelStep(mantissaBits: 10, magnitude: max(abs(entry.payload.framing.center.x), abs(entry.payload.framing.center.y))) * 3
        XCTAssertEqual(shallow.state.viewport.unitsPerPoint, minUnits, accuracy: minUnits * 1e-12)
        shallow.zoomOut()
        XCTAssertNil(shallow.bookmarkNote, "the note clears on the next zoom")
    }

    func testFittingBookmarkShowsNoNote() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-prec-\(UUID().uuidString)")
        let a = model(bits: 23, folder: dir)
        a.zoomIn(); a.zoomIn()
        let entry = try XCTUnwrap(a.saveBookmark(name: "Shallow"))
        XCTAssertEqual(entry.payload.precision.level, .reliable)
        let b = model(bits: 10, folder: dir)
        b.reloadBookmarks()
        b.open(entry.id)
        XCTAssertNil(b.bookmarkNote, "no clamp, no note")
        XCTAssertNotEqual(b.notice, .reached, "10 bits are near the limit at 4×, but not clamped")
        XCTAssertEqual(b.state.viewport.unitsPerPoint, PlaneFraming(center: entry.payload.framing.center, span: entry.payload.framing.span).viewport(size: Vec2(300, 400)).unitsPerPoint)
        XCTAssertEqual(BookmarksView.label(try XCTUnwrap(b.bookmarks.entry(entry.id))), "Shallow, −0.5 + 0i · zoom 4×")
    }

    func testListLabelNamesALimitedLevel() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-prec-\(UUID().uuidString)")
        let m = model(bits: 23, folder: dir)
        for _ in 0..<60 { m.zoomIn() }
        let entry = try XCTUnwrap(m.saveBookmark(name: "Edge"))
        XCTAssertTrue(BookmarksView.label(entry).hasSuffix("At precision limit"), BookmarksView.label(entry))
    }
}

// Feature 028 T-A03-309 (FR-A03-305; US4 AC1–AC3).
@MainActor
final class GoToModelTests: XCTestCase {
    private func model() -> ExplorerModel {
        let m = ExplorerModel(size: Vec2(300, 400),
                              bookmarksDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("fe-goto-\(UUID().uuidString)"))
        m.close()
        m.mantissaBitsOverride = 23
        m.pixelsPerPointOverride = 3
        return m
    }

    func testGoToCentersAndZooms() {
        let m = model()
        XCTAssertNil(m.goTo(real: "-0.743643887", imaginary: "0.131825904", zoom: "1000", locale: Locale(identifier: "en_US")))
        XCTAssertEqual(m.state.viewport.center, Vec2(-0.743643887, 0.131825904))
        XCTAssertEqual(m.state.spokenDescription, "Mandelbrot set, centered at −0.743644 + 0.131826i, zoom 1000×")
    }

    func testInvalidInputChangesNothing() {
        let m = model()
        let before = m.state
        XCTAssertEqual(m.goTo(real: "x", imaginary: "0", zoom: "1")?.message, "Enter a number")
        XCTAssertEqual(m.goTo(real: "0", imaginary: "9", zoom: "1")?.field, .imaginary)
        XCTAssertEqual(m.goTo(real: "0", imaginary: "0", zoom: "-1")?.field, .zoom)
        XCTAssertEqual(m.state, before)
    }

    func testZoomBeyondTheLimitIsClamped() {
        let m = model()
        XCTAssertNil(m.goTo(real: "-0.75", imaginary: "0.1", zoom: "1e15", locale: Locale(identifier: "en_US")))
        XCTAssertEqual(m.notice, .reached)
        XCTAssertEqual(m.state.viewport.center, Vec2(-0.75, 0.1))
    }
}

// Feature 028 T-A03-311 (US2 AC3): unreadable files are reported to the person.
@MainActor
final class BookmarkProblemsTests: XCTestCase {
    func testProblemsText() {
        XCTAssertNil(BookmarksView.problemsText(count: 0))
        XCTAssertEqual(BookmarksView.problemsText(count: 1), "1 bookmark file could not be read and was left unchanged.")
        XCTAssertEqual(BookmarksView.problemsText(count: 3), "3 bookmark files could not be read and were left unchanged.")
    }

    func testModelProblemsFeedTheNotice() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-problems-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: dir.appendingPathComponent("a.json"))
        try Data("{}".utf8).write(to: dir.appendingPathComponent("b.json"))
        let m = ExplorerModel(size: Vec2(300, 400), bookmarksDirectory: dir)
        m.close()
        m.reloadBookmarks()
        XCTAssertTrue(m.bookmarks.entries.isEmpty)
        XCTAssertEqual(BookmarksView.problemsText(count: m.bookmarks.problems.count),
                       "2 bookmark files could not be read and were left unchanged.")
    }
}
