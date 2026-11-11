// FractalStateTests — feature 026 T-A03-103 (FR-A03-101, FR-A03-105, FR-A03-106; SC-A03-104; clarifications 4–5;
// analyze G1).
import FractalExplorerCore
import VisualCoreMath
import XCTest

final class FractalStateTests: XCTestCase {
    private let size = Vec2(400, 800)

    func testDefaults() {
        let s = FractalState(size: size)
        XCTAssertEqual(s.mode, .mandelbrot)
        XCTAssertEqual(s.viewport.center, Vec2(-0.5, 0))
        XCTAssertEqual(s.viewport.unitsPerPoint, 4.0 / 400, accuracy: 1e-15)
        XCTAssertEqual(s.juliaSeed, Vec2(-0.8, 0.156))
        XCTAssertEqual(s.iterationCap, 200)
        XCTAssertEqual(s.escapeRadius, 2)
        XCTAssertEqual(s.zoom, 1, accuracy: 1e-12)
    }

    func testValidation() {
        var s = FractalState(size: size)
        s.iterationCap = 0
        XCTAssertEqual(s.iterationCap, 1)
        s.iterationCap = 20_000
        XCTAssertEqual(s.iterationCap, 10_000)
        s.escapeRadius = 1
        XCTAssertEqual(s.escapeRadius, 2)
        s.escapeRadius = .nan
        XCTAssertEqual(s.escapeRadius, 2)
        s.juliaSeed = Vec2(.nan, 1)
        XCTAssertEqual(s.juliaSeed, Vec2(-0.8, 0.156), "a non-finite seed keeps the previous one")
        s.juliaSeed = Vec2(3, 0)
        XCTAssertEqual(s.juliaSeed, Vec2(3, 0), "seeds outside |c| <= 2 are allowed")
    }

    func testModeSwitchReframes() {
        var s = FractalState(size: size)
        s.viewport = s.viewport.pinched(by: 50, anchor: Vec2(100, 100))
        s.mode = .julia
        XCTAssertEqual(s.viewport.center, .zero)
        XCTAssertEqual(s.viewport.unitsPerPoint, 3.2 / 400, accuracy: 1e-15)
        XCTAssertEqual(s.viewport.size, size)
        XCTAssertEqual(s.zoom, 1, accuracy: 1e-12)
    }

    func testSpokenDescription() {
        var s = FractalState(size: size)
        XCTAssertEqual(s.spokenDescription, "Mandelbrot set, centered at −0.5 + 0i, zoom 1×")
        s.mode = .julia
        XCTAssertEqual(s.spokenDescription, "Julia set for seed −0.8 + 0.156i, centered at 0 + 0i, zoom 1×")
        s.viewport = s.viewport.pinched(by: 2.5e7, anchor: Vec2(200, 400))
        XCTAssertTrue(s.spokenDescription.hasSuffix("zoom 2.5e7×"), s.spokenDescription)
        s.viewport = s.viewport.pinched(by: 1 / 2.5e7 * 37, anchor: Vec2(200, 400))
        XCTAssertTrue(s.spokenDescription.hasSuffix("zoom 37×"), s.spokenDescription)
        s.viewport = s.viewport.pinched(by: 1e4 / 37, anchor: Vec2(200, 400))
        XCTAssertTrue(s.spokenDescription.hasSuffix("zoom 1e4×"), s.spokenDescription)
    }

    func testExplanations() {
        let m = FractalExplanations.text(for: .mandelbrot)
        let j = FractalExplanations.text(for: .julia)
        XCTAssertTrue(m.contains("z² + c"))
        XCTAssertTrue(j.contains("seed"))
        XCTAssertTrue(j.contains("connected"), "the Mandelbrot-Julia relation")
        XCTAssertTrue(j.contains("dust"), "seeds outside the Mandelbrot set")
        XCTAssertNotEqual(m, j)
    }

    func testPreviewKnownPixelsAndDeterminism() {
        var s = FractalState(size: Vec2(300, 300))
        s.viewport = PlaneViewport.framing(width: 6, center: .zero, size: Vec2(300, 300))   // x in -3...3
        let p = FractalPreview.render(s, maxSide: 120, requestID: 7)
        XCTAssertEqual(p.width, 120)
        XCTAssertEqual(p.height, 120)
        XCTAssertEqual(p.requestID, 7)
        func pixel(_ plane: Vec2) -> (Int, Int) {
            let screen = s.viewport.screen(fromPlane: plane)
            return (Int(screen.x / 300 * 120), Int(screen.y / 300 * 120))
        }
        let origin = pixel(.zero), two = pixel(Vec2(2.02, 0))
        XCTAssertEqual(p.rgb(origin.0, origin.1), [0, 0, 0], "origin is interior (black)")
        XCTAssertGreaterThan(p.rgb(two.0, two.1)[0], 0, "c = 2 is exterior")
        XCTAssertEqual(FractalPreview.render(s, maxSide: 120, requestID: 8).rgba, p.rgba, "deterministic")
        let wide = FractalPreview.render(FractalState(size: Vec2(400, 800)), maxSide: 160, requestID: 1)
        XCTAssertEqual(wide.height, 160)
        XCTAssertEqual(wide.width, 80, "aspect kept, longer side = maxSide")
        XCTAssertEqual(FractalPreview.render(s, maxSide: 999, requestID: 1).width, FractalPreview.maximumSide, "budget capped")
    }
}
