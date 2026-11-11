// FullScreenShaderSceneTests — feature 012 T-A01-104: uniforms bind, fixed time is deterministic, errors carry file:line,
// context loss rebuilds without leaks.
import XCTest
import VisualCoreTestSupport
@testable import VisualCoreRendering

@MainActor
final class FullScreenShaderSceneTests: XCTestCase {
    static let fragment = """
    precision highp float;
    #include "vc/palette.glsl"
    #include "vc/color.glsl"
    #include "vc/noise.glsl"
    in vec2 v_uv;
    uniform float u_time;
    uniform vec2 u_resolution;
    uniform vec4 u_seed;
    uniform float u_scale;
    out vec4 color;
    void main() {
        float n = vc_fbm(v_uv * u_scale + u_seed.xy * 100.0 + vec2(u_time), 4, 2.0, 0.5) * 0.5 + 0.5;
        color = vec4(vc_srgbEncode(vc_palette(n)), 1.0);
    }
    """

    private func render(_ configure: (FullScreenShaderScene) -> Void, frames: Int = 2) throws -> (pixels: [UInt8], scene: FullScreenShaderScene, host: RenderHost) {
        let scene = FullScreenShaderScene(fragment: Self.fragment, fragmentName: "test.frag", bundle: ShaderBundle(files: [:]))
        configure(scene)
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        for _ in 0..<frames { XCTAssertTrue(host.renderOneFrame(present: false)) }
        return (host.readPixels(), scene, host)
    }

    private func standard(_ s: FullScreenShaderScene) {
        s.parameters = ["scale": 4, "unused": 1]
        s.palette = [SIMD3(0, 0, 0.2), SIMD3(1, 0.3, 0), SIMD3(1, 1, 0.8)]
        s.seedOffsets = SIMD4(0.25, 0.5, 0, 0)
        s.fixedTime = 1.5
    }

    func testFixedTimeIsDeterministicAndParametersMatter() throws {
        let a = try render(standard), b = try render(standard, frames: 5)
        defer { a.host.destroy(); b.host.destroy() }
        XCTAssertNil(a.scene.errorMessage)
        XCTAssertEqual(ImageComparison.compare(a.pixels, b.pixels).maxAbsolute, 0, "same snapshot → identical pixels")
        XCTAssertGreaterThan(ImageStatistics.distinctColors(a.pixels), 8)
        let c = try render { self.standard($0); $0.seedOffsets = SIMD4(0.75, 0.1, 0, 0) }
        let d = try render { self.standard($0); $0.palette = [SIMD3(0, 1, 0), SIMD3(0, 0, 1)] }
        defer { c.host.destroy(); d.host.destroy() }
        XCTAssertGreaterThan(ImageComparison.compare(a.pixels, c.pixels).meanAbsolute, 2, "seed offsets change the image")
        XCTAssertGreaterThan(ImageComparison.compare(a.pixels, d.pixels).meanAbsolute, 20, "palette reaches the shader")
    }

    func testBrokenFragmentReportsFileAndLine() throws {
        let scene = FullScreenShaderScene(fragment: "precision highp float;\nout vec4 color;\nvoid main() {\n  color = vec4(nope);\n}\n",
                                          fragmentName: "broken.frag", bundle: ShaderBundle(files: [:]))
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertTrue(scene.errorMessage?.hasPrefix("broken.frag:4:") ?? false, scene.errorMessage ?? "nil")
        let missing = FullScreenShaderScene(fragmentName: "absent.frag", bundle: ShaderBundle(files: [:]))
        let host2 = try RenderHost(scene: missing)
        host2.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host2.view.layoutIfNeeded()
        _ = host2.renderOneFrame(present: false)
        XCTAssertEqual(missing.errorMessage, "absent.frag: shader file not found")
        host.destroy(); host2.destroy()
        XCTAssertEqual(host.resources.stats.leaked + host2.resources.stats.leaked, 0)
    }

    func testContextLossRebuildsWithoutLeaks() throws {
        let r = try render(standard)
        let before = r.pixels
        r.host.recreateContext()
        XCTAssertTrue(r.host.renderOneFrame(present: false))
        XCTAssertEqual(ImageComparison.compare(before, r.host.readPixels()).maxAbsolute, 0)
        XCTAssertEqual(r.host.resources.stats.leaked, 0)
        r.host.destroy()
        XCTAssertEqual(r.host.resources.stats.leaked, 0)
    }

    func testVec3ArraySetterRespectsDeclaredSize() throws {
        // 10 stops supplied, the shader declares 8: only 8 are written and nothing is warned about the size.
        let r = try render { self.standard($0); $0.palette = (0..<10).map { SIMD3(Float($0) / 10, 0, 0) } }
        defer { r.host.destroy() }
        XCTAssertNil(r.scene.errorMessage)
        XCTAssertEqual(r.host.resources.stats.warnings, [], "u_unused is skipped, the palette fits")
    }
}
