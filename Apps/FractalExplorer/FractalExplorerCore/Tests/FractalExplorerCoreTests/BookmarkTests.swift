// BookmarkTests — feature 028 T-A03-304 (FR-A03-303, SC-A03-301; US1 AC1–AC2, US2 AC1–AC3).
import Foundation
import Testing
import VisualCoreMath
import VisualCorePersistence
@testable import FractalExplorerCore

private func folder() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("fe-bm-\(UUID().uuidString)") }
private let precision = PrecisionMode(mantissaBits: 23, level: .reliable)

@Suite struct BookmarkTests {
    static let sizes = [Vec2(320, 568), Vec2(568, 320), Vec2(390, 844), Vec2(1024, 1366), Vec2(1366, 1024)]
    struct LCG { var s: UInt64; mutating func next() -> Double { s = s &* 6364136223846793005 &+ 1442695040888963407; return Double(s >> 11) / Double(1 << 53) } }

    @Test func saveReloadOpenReturnsTheSameViewOnEveryShape() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = BookmarkLibrary.bookmarks(directory: dir)
        var r = LCG(s: 7)
        var saved: [(UUID, FractalState)] = []
        for i in 0..<100 {
            var s = FractalState(mode: i % 2 == 0 ? .mandelbrot : .julia, size: Self.sizes[i % 5])
            s.viewport = PlaneViewport(center: Vec2(r.next() * 4 - 2, r.next() * 3 - 1.5),
                                       unitsPerPoint: pow(10, -9 + r.next() * 7), size: s.viewport.size)
            s.juliaSeed = Vec2(r.next() - 0.5, r.next() - 0.5)
            s.iterationCap = 1 + Int(r.next() * 9999)
            let e = try lib.save(Bookmark(state: s, paletteID: Bookmark.paletteIDs[i % 5], precision: precision), name: "B\(i)")
            saved.append((e.id, s))
        }
        var again = BookmarkLibrary.bookmarks(directory: dir)
        again.reload()
        #expect(again.entries.count == 100)
        #expect(again.problems.isEmpty)
        for (id, original) in saved {
            let b = try #require(again.entry(id)).payload
            let span = original.viewport.unitsPerPoint * min(original.viewport.size.x, original.viewport.size.y)
            for size in Self.sizes {
                let s = b.state(size: size)
                #expect(s.mode == original.mode)
                #expect(s.viewport.center == original.viewport.center)
                let back = s.viewport.unitsPerPoint * min(size.x, size.y)
                #expect(abs(back - span) <= 1e-12 * span)
                #expect(s.juliaSeed == original.juliaSeed)
                #expect(s.iterationCap == original.iterationCap)
            }
        }
    }

    @Test func invalidFieldsAreRejected() {
        let good = Bookmark(state: FractalState(size: Vec2(300, 400)), paletteID: "sunset", precision: precision)
        #expect(good.validated() == good)
        var b = good; b.framing = PlaneFraming(center: Vec2(5, 0), span: 1); #expect(b.validated() == nil)
        b = good; b.juliaSeed = Vec2(.nan, 0); #expect(b.validated() == nil)
        b = good; b.iterationCap = 0; #expect(b.validated() == nil)
        b = good; b.iterationCap = 20_000; #expect(b.validated() == nil)
        b = good; b.escapeRadius = 1; #expect(b.validated() == nil)
        b = good; b.paletteID = "monochrome"; #expect(b.validated() == nil)
        b = good; b.precision.mantissaBits = 0; #expect(b.validated() == nil)
        b = good; b.precision.format = "cpu-double"; #expect(b.validated() == nil)
    }

    @Test func damagedFilesAreReportedNotDeleted() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = BookmarkLibrary.bookmarks(directory: dir)
        try lib.save(Bookmark(state: FractalState(size: Vec2(300, 400)), paletteID: "ocean", precision: precision), name: "Home")
        let damaged = dir.appendingPathComponent("broken.json")
        try Data("{}".utf8).write(to: damaged)
        lib.reload()
        #expect(lib.entries.count == 1)
        #expect(lib.problems.count == 1)
        #expect(FileManager.default.fileExists(atPath: damaged.path))
    }

    @Test func precisionModeFromTheAdvisorAndSummary() {
        var s = FractalState(size: Vec2(300, 400))
        #expect(PrecisionMode(viewport: s.viewport, mantissaBits: 23, pixelsPerPoint: 3).level == .reliable)
        s.viewport = PlaneViewport(center: Vec2(-0.5, 0), unitsPerPoint: 0.5 * pow(2.0, -23) * 3 * 4, size: s.viewport.size)
        #expect(PrecisionMode(viewport: s.viewport, mantissaBits: 23, pixelsPerPoint: 3).level == .nearLimit)
        #expect(PrecisionMode(viewport: s.viewport, mantissaBits: 10, pixelsPerPoint: 3).level == .beyondLimit)
        #expect(PrecisionMode.Level.reliable.displayText == nil)
        let b = Bookmark(state: FractalState(size: Vec2(300, 400)), paletteID: "sunset", precision: precision)
        #expect(b.summary == "−0.5 + 0i · zoom 1×")
    }
}
