// AspectTests — feature 028 T-A03-306 (FR-A03-306, SC-A03-302, SC-A03-303; Phase 03 regression fixture): aspect-ratio
// changes keep the center and the span across the shorter side with square pixels, and the GPU picture at non-square
// sizes matches the CPU reference (no distortion in the shader path).
import FractalExplorerCore
import VisualCoreMath
import VisualCoreRendering
import XCTest
@testable import FractalExplorer

@MainActor
final class AspectTests: XCTestCase {
    struct LCG { var s: UInt64; mutating func next() -> Double { s = s &* 6364136223846793005 &+ 1442695040888963407; return Double(s >> 11) / Double(1 << 53) } }

    func testRandomResizesKeepCenterSpanAndSquarePixels() {
        let m = ExplorerModel(size: Vec2(390, 844))
        m.close()
        m.zoomIn(); m.zoomIn()
        m.apply(m.state.viewport.panned(by: Vec2(40, 25)))
        let center = m.state.viewport.center
        let span = PlaneFraming(m.state.viewport).span
        var r = LCG(s: 99)
        for _ in 0..<100 {
            let size = Vec2(200 + r.next() * 1200, 200 + r.next() * 1200)
            m.resize(to: size)
            let v = m.state.viewport
            XCTAssertEqual(v.center, center)
            XCTAssertEqual(v.unitsPerPoint * min(size.x, size.y), span, accuracy: span * 1e-12)
            let a = v.plane(fromScreen: Vec2(0, 0)), b = v.plane(fromScreen: Vec2(50, 50))
            XCTAssertEqual(abs(b.x - a.x), abs(b.y - a.y), accuracy: 1e-12, "one scale for both axes")
        }
        m.resize(to: Vec2(0, .nan))
        XCTAssertEqual(m.state.viewport.center, center, "an invalid size changes nothing")
    }

    private func agreement(width: Int, height: Int) throws -> (share: Double, unexplained: Int) {
        let viewSize = Vec2(Double(width) * 5, Double(height) * 5)
        let m = ExplorerModel(size: Vec2(300, 300))
        m.close()
        m.resize(to: viewSize)   // the regression path: framing kept across the shape change
        let state = m.state
        let scene = FractalScene(snapshot: .init(state: state, paletteID: "sunset", animate: false))
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: viewSize.x, height: viewSize.y)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(scene.errorMessage)
        let image = try host.renderOffscreen(width: width, height: height, time: 0)
        func cpu(_ x: Int, _ y: Int) -> Bool {
            let p = Vec2((Double(x) + 0.5) / Double(width) * viewSize.x, (Double(y) + 0.5) / Double(height) * viewSize.y)
            return state.escape(at: state.viewport.plane(fromScreen: p)).interior
        }
        var agree = 0, unexplained = 0
        for y in 0..<height {
            for x in 0..<width {
                let p = image.pixel(x: x, y: y)
                let gpu = Int(p.x) <= 1 && Int(p.y) <= 1 && Int(p.z) <= 1
                let c = cpu(x, y)
                if gpu == c { agree += 1; continue }
                var near = false
                for dy in -1...1 { for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0, ny >= 0, nx < width, ny < height, cpu(nx, ny) != c { near = true }
                } }
                if !near { unexplained += 1 }
            }
        }
        return (Double(agree) / Double(width * height), unexplained)
    }

    func testWideGPUPictureMatchesCPU() throws {
        let r = try agreement(width: 64, height: 32)
        print("GPU/CPU agreement 64x32: \(r.share * 100)%, unexplained \(r.unexplained)")
        XCTAssertGreaterThanOrEqual(r.share, 0.99)
        XCTAssertEqual(r.unexplained, 0)
    }

    func testTallGPUPictureMatchesCPU() throws {
        let r = try agreement(width: 32, height: 64)
        print("GPU/CPU agreement 32x64: \(r.share * 100)%, unexplained \(r.unexplained)")
        XCTAssertGreaterThanOrEqual(r.share, 0.99)
        XCTAssertEqual(r.unexplained, 0)
    }
}
