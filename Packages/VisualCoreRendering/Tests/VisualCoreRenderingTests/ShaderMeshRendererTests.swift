// ShaderMeshRendererTests — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-001, 002; research R8). On the
// simulator, through the real OpenGL ES → ANGLE → Metal path: a full-view plane drawn with a custom program shows the
// uv stream (red follows u, green follows v); additive and premultiplied blending combine as stated; a mesh without uvs
// reads the constant (0, 0); a broken program throws; release and a later draw rebuild everything without a GL error.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ShaderMeshRendererTests: XCTestCase {
    private var host: RenderHost?

    static let vertex = """
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec2 v_uv;
    void main() {
        v_uv = a_uv;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """
    static let uvFragment = """
    precision mediump float;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = vec4(v_uv, 0.0, 1.0); }
    """
    static let flatFragment = """
    precision mediump float;
    in vec2 v_uv;
    uniform vec4 u_color;
    out vec4 color;
    void main() { color = u_color; }
    """

    /// The unit plane scaled to cover clip space.
    static var fullView: Mat4 { Mat4.scale(Vec3(2, 2, 1)) }

    func testTheUvStreamReachesTheFragmentShader() throws {
        let size = 32
        var error = GLenum(1)
        let p = try DrawHarness.pixels(size: size, keep: &host) { ctx in
            let r = try ShaderMeshRenderer(mesh: Mesh.plane(), vertex: Self.vertex, fragment: Self.uvFragment,
                                           registry: ctx.resources)
            try r.draw { $0.set("u_mvp", matrix4: Self.fullView.floats) }
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        let low = DrawHarness.px(p, size, 1, 1)
        let high = DrawHarness.px(p, size, size - 2, size - 2)
        // Rows may be read bottom-up or top-down; u (red) runs left to right either way.
        XCTAssertLessThan(low.x, 30)
        XCTAssertGreaterThan(high.x, 225)
        XCTAssertGreaterThan(abs(high.y - low.y), 190, "green follows v")
    }

    func testBlendModesCombineAsStated() throws {
        let size = 16
        var error = GLenum(1)
        let p = try DrawHarness.pixels(size: size, keep: &host) { ctx in
            let r = try ShaderMeshRenderer(mesh: Mesh.plane(), vertex: Self.vertex, fragment: Self.flatFragment,
                                           registry: ctx.resources)
            // Opaque red, then additive 0.25 green twice, then premultiplied half blue.
            try r.draw(blend: .opaque) { p in
                p.set("u_mvp", matrix4: Self.fullView.floats); p.set("u_color", SIMD4<Float>(1, 0, 0, 1))
            }
            for _ in 0..<2 {
                try r.draw(blend: .additive) { p in
                    p.set("u_mvp", matrix4: Self.fullView.floats); p.set("u_color", SIMD4<Float>(0, 0.25, 0, 0))
                }
            }
            try r.draw(blend: .premultipliedAlpha) { p in
                p.set("u_mvp", matrix4: Self.fullView.floats); p.set("u_color", SIMD4<Float>(0, 0, 0.5, 0.5))
            }
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        let c = DrawHarness.px(p, size, size / 2, size / 2)
        // red 1 · 0.5 = 128, green 0.5 · 0.5 = 64, blue 0.5 = 128 (±3 for rounding).
        XCTAssertLessThanOrEqual(abs(c.x - 128), 3)
        XCTAssertLessThanOrEqual(abs(c.y - 64), 3)
        XCTAssertLessThanOrEqual(abs(c.z - 128), 3)
    }

    func testAMeshWithoutUvsReadsZeroAndABrokenProgramThrows() throws {
        let size = 16
        var noUV = Mesh.plane()
        noUV.uvs = []
        var thrown = false
        let p = try DrawHarness.pixels(size: size, keep: &host) { ctx in
            let r = try ShaderMeshRenderer(mesh: noUV, vertex: Self.vertex, fragment: Self.uvFragment,
                                           registry: ctx.resources)
            try r.draw { $0.set("u_mvp", matrix4: Self.fullView.floats) }
            r.release()
            do {
                _ = try ShaderMeshRenderer(mesh: Mesh.plane(), vertex: Self.vertex,
                                           fragment: "precision mediump float;\nout vec4 color;\nvoid main() { color = nope; }",
                                           registry: ctx.resources)
            } catch {
                thrown = true
            }
        }
        let c = DrawHarness.px(p, size, size / 2, size / 2)
        XCTAssertEqual(c.x, 0)
        XCTAssertEqual(c.y, 0)
        XCTAssertTrue(thrown, "a program that does not compile is refused")
    }

    func testReleaseThenDrawRebuilds() throws {
        let size = 16
        var error = GLenum(1)
        let p = try DrawHarness.pixels(size: size, keep: &host) { ctx in
            let r = try ShaderMeshRenderer(mesh: Mesh.plane(), vertex: Self.vertex, fragment: Self.flatFragment,
                                           registry: ctx.resources)
            r.release()
            try r.draw { p in
                p.set("u_mvp", matrix4: Self.fullView.floats); p.set("u_color", SIMD4<Float>(0, 1, 0, 1))
            }
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        XCTAssertGreaterThan(DrawHarness.px(p, size, size / 2, size / 2).y, 250)
    }
}
