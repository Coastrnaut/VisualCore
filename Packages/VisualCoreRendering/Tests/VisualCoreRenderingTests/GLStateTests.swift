// GLStateTests — feature 008 T-F704 (FR-F704): after a foreign renderer leaves GL state dirty, a VisualCore draw
// fails (negative control) unless GLState.resetForVisualCore runs first.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class GLStateTests: XCTestCase {
    private var host: RenderHost?

    /// Leaves the state a foreign engine might: bound VAO/program/buffers, blending, culling of our winding,
    /// a tiny scissor, a disabled color mask, another texture unit and unpack alignment.
    private func dirty(_ ctx: RenderContext) throws {
        var vao: GLuint = 0
        vcglGenVertexArrays(1, &vao)
        vcglBindVertexArray(vao)
        let p = try ctx.resources.program(vertex: ShaderProgramTests.vertex, fragment: """
        precision mediump float; out vec4 c; void main() { c = vec4(0.0, 1.0, 0.0, 1.0); }
        """)
        p.use()
        vcglEnable(GLenum(GL_BLEND)); vcglBlendFunc(GLenum(GL_ZERO), GLenum(GL_ONE))
        vcglEnable(GLenum(GL_CULL_FACE)); vcglCullFace(GLenum(GL_FRONT))
        vcglEnable(GLenum(GL_SCISSOR_TEST)); vcglScissor(0, 0, 1, 1)
        vcglColorMask(GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_FALSE))
        vcglActiveTexture(GLenum(GL_TEXTURE3))
        vcglPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
    }

    private func drawRed(_ ctx: RenderContext) throws {
        let root = SceneNode(primitive: .rect(Vec2(40, 40)), color: Vec4(1, 0, 0, 1))
        try PrimitiveRenderer(registry: ctx.resources).draw(root, camera: Camera2D(), metrics: ViewMetrics(size: Vec2(32, 32), scale: 1))
    }

    func testDirtyStateBreaksVisualCoreDrawingWithoutReset() throws {
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            try self.dirty(ctx)
            try self.drawRed(ctx)
        }
        XCTAssertNotEqual(DrawHarness.px(p, 32, 16, 16), SIMD4(255, 0, 0, 255), "negative control: the dirty state blocks the draw")
    }

    func testResetRestoresVisualCoreDrawing() throws {
        var unpack: GLint = 0, unit: GLint = 0
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            let t = try ctx.resources.makeRenderTarget(width: 32, height: 32, label: "foreign")
            try self.dirty(ctx)
            GLState.resetForVisualCore(framebuffer: t.handle.name, width: 32, height: 32)
            vcglGetIntegerv(GLenum(GL_UNPACK_ALIGNMENT), &unpack)
            vcglGetIntegerv(GLenum(GL_ACTIVE_TEXTURE), &unit)
            // Draw into the harness target again (the reset bound `t`); rebinding is the caller's normal step.
            ctx.resources.release(t)
        }
        XCTAssertEqual(unpack, 4)
        XCTAssertEqual(unit, GLint(GL_TEXTURE0))
        _ = p
        let q = try DrawHarness.pixels(keep: &host) { ctx in
            var fb: GLint = 0
            vcglGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &fb)
            try self.dirty(ctx)
            GLState.resetForVisualCore(framebuffer: UInt32(fb), width: 32, height: 32)
            try self.drawRed(ctx)
        }
        for (x, y) in [(16, 16), (1, 1), (30, 30)] {
            XCTAssertEqual(DrawHarness.px(q, 32, x, y), SIMD4(255, 0, 0, 255), "pixel \(x),\(y) drawn after reset")
        }
    }
}
