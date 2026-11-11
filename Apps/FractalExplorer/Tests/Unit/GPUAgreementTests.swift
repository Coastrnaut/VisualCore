// GPUAgreementTests — feature 027 T-A03-203 (FR-A03-207, SC-A03-202; US3; research R4): the GPU escape classes match
// the FractalMath CPU reference on the default 64 × 64 views in both modes; disagreements only next to the boundary.
import FractalExplorerCore
import VisualCoreMath
import VisualCoreRendering
import XCTest
@testable import FractalExplorer

@MainActor
final class GPUAgreementTests: XCTestCase {
    private let side = 64
    private let viewSize = Vec2(300, 300)

    private func render(_ state: FractalState) throws -> StillImage {
        let scene = FractalScene(snapshot: .init(state: state, paletteID: "sunset", animate: false))
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(scene.errorMessage, scene.errorMessage ?? "")
        return try host.renderOffscreen(width: side, height: side, time: 0)
    }

    private func cpuInterior(_ state: FractalState, _ x: Int, _ y: Int) -> Bool {
        let screen = Vec2((Double(x) + 0.5) / Double(side) * viewSize.x, (Double(y) + 0.5) / Double(side) * viewSize.y)
        return state.escape(at: state.viewport.plane(fromScreen: screen)).interior
    }

    private func agreement(_ state: FractalState) throws -> (share: Double, unexplained: Int, image: StillImage) {
        let image = try render(state)
        var agree = 0, unexplained = 0
        for y in 0..<side {
            for x in 0..<side {
                let p = image.pixel(x: x, y: y)
                let gpuInterior = Int(p.x) <= 1 && Int(p.y) <= 1 && Int(p.z) <= 1
                let cpu = cpuInterior(state, x, y)
                if gpuInterior == cpu { agree += 1; continue }
                var nearBoundary = false
                for dy in -1...1 { for dx in -1...1 {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0, ny >= 0, nx < side, ny < side, cpuInterior(state, nx, ny) != cpu { nearBoundary = true }
                } }
                if !nearBoundary { unexplained += 1 }
            }
        }
        return (Double(agree) / Double(side * side), unexplained, image)
    }

    func testMandelbrotMatchesCPU() throws {
        var s = FractalState(size: viewSize)
        s.viewport = PlaneViewport.framing(width: 6, center: .zero, size: viewSize)   // includes c = 2
        let r = try agreement(s)
        print("GPU/CPU agreement mandelbrot: \(r.share * 100)%, unexplained \(r.unexplained)")
        XCTAssertGreaterThanOrEqual(r.share, 0.99)
        XCTAssertEqual(r.unexplained, 0, "disagreements only next to the boundary")
        let origin = s.viewport.screen(fromPlane: .zero), two = s.viewport.screen(fromPlane: Vec2(2.05, 0))
        let o = r.image.pixel(x: Int(origin.x / 300 * 64), y: Int(origin.y / 300 * 64))
        let t = r.image.pixel(x: Int(two.x / 300 * 64), y: Int(two.y / 300 * 64))
        XCTAssertEqual([o.x, o.y, o.z], [0, 0, 0], "origin interior")
        XCTAssertGreaterThan(Int(t.x) + Int(t.y) + Int(t.z), 30, "c = 2 exterior")
    }

    func testJuliaMatchesCPU() throws {
        var s = FractalState(size: viewSize)
        s.mode = .julia
        let r = try agreement(s)
        print("GPU/CPU agreement julia: \(r.share * 100)%, unexplained \(r.unexplained)")
        XCTAssertGreaterThanOrEqual(r.share, 0.99)
        XCTAssertEqual(r.unexplained, 0)
    }

    func testFrozenPaletteIsStableAndAnimatedPaletteMoves() throws {
        let state = FractalState(size: viewSize)
        let scene = FractalScene(snapshot: .init(state: state, paletteID: "sunset", animate: false))
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let t0 = scene.clock.time
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(scene.clock.time, t0, "animation off: time frozen")
        scene.snapshot.animate = true
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertGreaterThan(scene.clock.time, t0, "animation on: time advances")
    }
}
