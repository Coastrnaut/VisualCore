// BookmarkReproductionTests — feature 030 T-A03-503 (FR-A03-504, SC-A03-504; US3; research R4; Phase 05 regression
// fixture): saved bookmarks round-trip and reproduce their views — identical pictures on the same canvas, matching
// escape classes on a canvas of another shape.
import FractalExplorerCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FractalExplorer

@MainActor
final class BookmarkReproductionTests: XCTestCase {
    struct LCG { var s: UInt64; mutating func next() -> Double { s = s &* 6364136223846793005 &+ 1442695040888963407; return Double(s >> 11) / Double(1 << 53) } }

    private var dir: URL!
    override func setUp() { dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-repro-\(UUID().uuidString)") }
    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func model(_ size: Vec2) throws -> ExplorerModel {
        let m = ExplorerModel(size: size, system: SystemAccessibility(reduceMotion: true), bookmarksDirectory: dir)
        let host = try XCTUnwrap(m.host)
        host.view.frame = CGRect(x: 0, y: 0, width: size.x, height: size.y)
        host.view.layoutIfNeeded()
        m.resize(to: size)
        m.animate = false
        XCTAssertTrue(host.renderOneFrame(present: false))
        return m
    }

    private func render(_ m: ExplorerModel, _ w: Int, _ h: Int) throws -> StillImage {
        let host = try XCTUnwrap(m.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        return try host.renderOffscreen(width: w, height: h, time: 0)
    }

    func testBookmarksReproduceTheirPictures() throws {
        let size = Vec2(300, 300)
        let original = try model(size)
        defer { original.close() }
        var r = LCG(s: 2026)
        var saved: [(UUID, StillImage, FractalState)] = []
        for i in 0..<10 {
            original.state.mode = i % 2 == 0 ? .mandelbrot : .julia
            original.state.juliaSeed = [Vec2(-0.8, 0.156), Vec2(0.285, 0.01), Vec2(-0.4, 0.6)][i % 3]
            original.state.iterationCap = 50 + Int(r.next() * 1950)
            original.paletteID = Bookmark.paletteIDs[i % 5]
            let zoom = pow(10, r.next() * 4)
            let center = original.state.mode == .mandelbrot ? Vec2(-0.75 + (r.next() - 0.5) * 0.5, (r.next() - 0.5) * 0.5)
                                                            : Vec2((r.next() - 0.5), (r.next() - 0.5))
            original.apply(PlaneFraming(center: center, span: FractalState.defaultWidth(for: original.state.mode) / zoom).viewport(size: size))
            let picture = try render(original, 64, 64)
            let entry = try XCTUnwrap(original.saveBookmark(name: "Place \(i)"))
            saved.append((entry.id, picture, original.state))
        }

        // Same canvas, fresh model after a reload: identical pictures, identical fields.
        let reopened = try model(size)
        defer { reopened.close() }
        reopened.reloadBookmarks()
        XCTAssertEqual(reopened.bookmarks.entries.count, 10)
        for (id, picture, state) in saved {
            reopened.open(id)
            XCTAssertEqual(reopened.state, state, "every field restored")
            let again = try render(reopened, 64, 64)
            var maxDiff = 0
            for y in 0..<64 { for x in 0..<64 {
                let a = picture.pixel(x: x, y: y), b = again.pixel(x: x, y: y)
                maxDiff = max(maxDiff, abs(Int(a.x) - Int(b.x)), abs(Int(a.y) - Int(b.y)), abs(Int(a.z) - Int(b.z)))
            } }
            XCTAssertLessThanOrEqual(maxDiff, 1, "bookmark \(id): channel difference \(maxDiff)")
        }

        // Another shape (2:1): the same bookmark on a 600 × 300 canvas rendered at 128 × 64 has the same plane step per
        // pixel as the original 64 × 64 picture of the 300 × 300 canvas, and its pixel (x + 32, y) sits on the original
        // pixel (x, y)'s plane point. Escape classes at all 4,096 shared points agree ≥ 99% with the original picture.
        let wide = try model(Vec2(600, 300))
        defer { wide.close() }
        wide.reloadBookmarks()
        func interior(_ p: SIMD4<UInt8>) -> Bool { Int(p.x) <= 1 && Int(p.y) <= 1 && Int(p.z) <= 1 }
        for (id, picture, _) in saved {
            wide.open(id)
            let image = try render(wide, 128, 64)
            var agree = 0
            for y in 0..<64 { for x in 0..<64 where interior(picture.pixel(x: x, y: y)) == interior(image.pixel(x: x + 32, y: y)) {
                agree += 1
            } }
            XCTAssertGreaterThanOrEqual(Double(agree) / 4096, 0.99, "bookmark \(id) on 2:1: \(agree)/4096")
        }
    }
}
