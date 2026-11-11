// TextureUploadTests — feature 007 T-F603: Texture.upload(rgba:) pixels are sampled back by a shader;
// wrong size, wrong format and stale textures are rejected.
import CVisualCoreGL
import XCTest
@testable import VisualCoreRendering

@MainActor
final class TextureUploadTests: XCTestCase {
    private var host: RenderHost?

    static let vertex = """
    out vec2 uv;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """
    static let fragment = """
    precision mediump float;
    in vec2 uv;
    uniform sampler2D u_tex;
    out vec4 color;
    void main() { color = texture(u_tex, uv); }
    """

    func testUploadedPixelsAreSampled() throws {
        // 2×2 texture: bottom row red, green; top row blue, white.
        let pixels: [UInt8] = [255, 0, 0, 255,  0, 255, 0, 255,  0, 0, 255, 255,  255, 255, 255, 255]
        var ok = false
        let p = try DrawHarness.pixels(size: 16, keep: &host) { ctx in
            let tex = try ctx.resources.makeTexture(width: 2, height: 2, label: "upload test")
            ok = tex.upload(rgba: pixels)
            let program = try ctx.resources.program(vertex: Self.vertex, fragment: Self.fragment)
            program.use()
            tex.bind(unit: 0)
            program.set("u_tex", Int32(0))
            vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
            ctx.resources.release(tex)
        }
        XCTAssertTrue(ok)
        XCTAssertEqual(DrawHarness.px(p, 16, 3, 3), SIMD4(255, 0, 0, 255), "bottom-left texel")
        XCTAssertEqual(DrawHarness.px(p, 16, 12, 3), SIMD4(0, 255, 0, 255), "bottom-right texel")
        XCTAssertEqual(DrawHarness.px(p, 16, 3, 12), SIMD4(0, 0, 255, 255), "top-left texel")
        XCTAssertEqual(DrawHarness.px(p, 16, 12, 12), SIMD4(255, 255, 255, 255), "top-right texel")
    }

    func testRejectsWrongSizeFormatAndStaleTextures() throws {
        var results: [Bool] = []
        var stale: Texture?
        let h = try RenderHost(scene: ProbeScene(setup: { ctx in
            let t = try ctx.resources.makeTexture(width: 4, height: 4, label: "t")
            results.append(t.upload(rgba: [UInt8](repeating: 0, count: 15)))          // wrong size
            let f = try ctx.resources.makeTexture(width: 2, height: 2, format: .rgba16f, label: "f")
            results.append(f.upload(rgba: [UInt8](repeating: 0, count: 16)))          // wrong format
            results.append(t.upload(rgba: [UInt8](repeating: 9, count: 64)))          // valid
            if stale == nil { stale = t }
        }))
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        h.recreateContext()
        XCTAssertEqual(results.prefix(3), [false, false, true])
        XCTAssertEqual(stale?.upload(rgba: [UInt8](repeating: 0, count: 64)), false, "texture from the old context")
        h.destroy()
    }
}
