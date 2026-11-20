// SkyRendererTests — feature 218 (R02-F18) T-R02F18-005 (FR-R02F18-005, 006; SC-R02F18-004, 005; clarification Q4; research R5, R6).
// On the simulator through OpenGL ES → ANGLE → Metal, into a 64 × 64 target with a 24-bit depth buffer, cleared to
// black and depth 1.
//
// Expected colour (the method): for every pixel the centre (x + ½, y + ½) gives NDC (2(x + ½)/64 − 1, 2(y + ½)/64 − 1);
// the inverse view-projection maps NDC depths −1 and 1 to two world points (each divided by its w) and far − near is
// the direction d; the pixel must equal round(SkyModel(d, sun) × 255) within 2 per channel, at every pixel. Two cameras:
// level, looking along −z with the sun low behind it (dusk tint, gradient across the horizon), and tilted up and yawed
// with the sun aimed exactly at one pixel centre, so its disc and glow are in view. As in SkyShaderTests no pixel
// centre lies in the disc's 0.004 rad smoothstep band (checked as a precondition), so the float/double difference of
// that very steep ramp cannot show. Further: a quad drawn first at depth 0.5 keeps its colour (the sky is drawn only
// where depth is still far); invalid parameters and a zero sun throw `SkyError` and draw nothing; the program, depth
// and blend state are restored; zero live GPU objects after release and host destroy; a context recreation gives the
// same picture. Errors are captured inside the GL closure because `RenderHost` reports scene errors itself.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class SkyRendererTests: XCTestCase {
    static let size = 64
    static let toleranceBytes = 2
    static let projection = Mat4.perspective(fovY: Double.pi / 3, aspect: 1, near: 0.1, far: 100)

    /// Level camera 1.5 above the ground looking along −z.
    static let levelView = Mat4.lookAt(eye: Vec3(0, 1.5, 0), target: Vec3(0, 1.5, -1), up: Vec3(0, 1, 0))
    /// Camera tilted up by about 19° and yawed to the left.
    static let tiltedView = Mat4.lookAt(eye: Vec3(2, 0.5, 3), target: Vec3(1.5, 0.85, 2), up: Vec3(0, 1, 0))

    /// The sun low behind the level camera (elevation 0.12 rad towards +z).
    static let lowSunBehind = Vec3(0, sin(0.12), cos(0.12))

    /// The direction through the centre of pixel (x, y) for `view` (method in the file header).
    static func direction(_ x: Int, _ y: Int, view: Mat4) throws -> Vec3 {
        let inverse = try XCTUnwrap((projection * view).inverse)
        let nx = (Double(x) + 0.5) / Double(size) * 2 - 1, ny = (Double(y) + 0.5) / Double(size) * 2 - 1
        let near = inverse.applyPoint(Vec3(nx, ny, -1)), far = inverse.applyPoint(Vec3(nx, ny, 1))
        return far - near
    }

    /// The expected bytes of every pixel (row-major, rows bottom-up), after checking that no pixel centre lies in the
    /// disc's smoothstep band.
    static func expected(view: Mat4, sun: Vec3, parameters: SkyParameters = SkyParameters()) throws -> [SIMD3<Int>] {
        let s = sun / sun.length
        let inner = cos(parameters.sunRadius), outer = cos(parameters.sunRadius + 0.004)
        var out: [SIMD3<Int>] = []
        var inBand = 0
        for y in 0..<size {
            for x in 0..<size {
                let d = try direction(x, y, view: view)
                let ds = (d / d.length).dot(s)
                if ds > outer && ds < inner { inBand += 1 }
                let c = try SkyModel.colour(direction: d, sun: sun, parameters: parameters)
                out.append(SIMD3(Int((c.x * 255).rounded()), Int((c.y * 255).rounded()), Int((c.z * 255).rounded())))
            }
        }
        XCTAssertEqual(inBand, 0, "precondition: no pixel centre in the disc's smoothstep band")
        return out
    }

    /// The GL state the renderer promises to restore, plus the framebuffer and viewport it must not change.
    static func state() -> [GLint] {
        func integer(_ name: Int32) -> GLint { var v: GLint = 0; vcglGetIntegerv(GLenum(name), &v); return v }
        var mask = GLboolean(GL_TRUE)
        vcglGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &mask)
        var vp: [GLint] = [0, 0, 0, 0]
        vcglGetIntegerv(GLenum(GL_VIEWPORT), &vp)
        let flags = [GL_BLEND, GL_DEPTH_TEST, GL_CULL_FACE].map { GLint(vcglIsEnabled(GLenum($0))) }
        return [integer(GL_CURRENT_PROGRAM), integer(GL_DEPTH_FUNC), GLint(mask), integer(GL_FRAMEBUFFER_BINDING)]
            + vp + flags
    }

    static let quadVertex = """
    void main() {
        // Two triangles covering the left half of the viewport (x from −1 to 0) at NDC depth 0 (window depth 0.5).
        int i = gl_VertexID;
        vec2 corners[6] = vec2[6](vec2(-1.0, -1.0), vec2(0.0, -1.0), vec2(0.0, 1.0),
                                  vec2(-1.0, -1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0));
        gl_Position = vec4(corners[i], 0.0, 1.0);
    }
    """
    static let quadFragment = """
    precision mediump float;
    out vec4 color;
    void main() { color = vec4(1.0, 0.0, 0.0, 1.0); }
    """

    struct Outcome {
        var pixels: [UInt8]
        var calls: Int
        var error: Error?
        var leaked: Int
        var stateBefore: [GLint]
        var stateAfter: [GLint]
        var glError: GLenum
    }

    /// Draws the sky once with a fresh renderer into a cleared depth target (after the red half quad when `quad`),
    /// with non-default caller state (a bound program, blend and cull face on, depth test off, depth func LESS, depth
    /// writes on), releases everything, destroys the host and returns the pixels and the state before and after.
    func draw(view: Mat4, sun: Vec3, parameters: SkyParameters = SkyParameters(), quad: Bool = false) throws -> Outcome {
        var out = Outcome(pixels: [], calls: -1, error: nil, leaked: -1, stateBefore: [], stateAfter: [],
                          glError: GLenum(1))
        let inverse = try XCTUnwrap((Self.projection * view).inverse)
        let host = try RenderHost(scene: ProbeScene(setup: { ctx in
            let n = Self.size
            let target = try ctx.resources.makeRenderTarget(width: n, height: n, depth: true, label: "sky test")
            target.bind()
            vcglViewport(0, 0, GLsizei(n), GLsizei(n))
            vcglClearColor(0, 0, 0, 1)
            vcglClearDepthf(1)
            vcglDepthMask(GLboolean(GL_TRUE))
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
            let quadProgram = try ctx.resources.program(vertex: Self.quadVertex, fragment: Self.quadFragment,
                                                        vertexName: "quad.vert", fragmentName: "quad.frag")
            quadProgram.use()
            if quad {
                vcglEnable(GLenum(GL_DEPTH_TEST))
                vcglDepthFunc(GLenum(GL_LESS))
                vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 6)
            }
            vcglDisable(GLenum(GL_DEPTH_TEST))
            vcglDepthFunc(GLenum(GL_LESS))
            vcglEnable(GLenum(GL_BLEND))
            vcglEnable(GLenum(GL_CULL_FACE))
            let renderer = try SkyRenderer(registry: ctx.resources)
            out.stateBefore = Self.state()
            do {
                try renderer.draw(inverseViewProjection: inverse, sun: sun, parameters: parameters)
            } catch { out.error = error }
            out.stateAfter = Self.state()
            out.calls = renderer.drawCallCount
            out.glError = vcglGetError()
            vcglDisable(GLenum(GL_BLEND))
            vcglDisable(GLenum(GL_CULL_FACE))
            out.pixels = target.readPixels()
            renderer.release()
            ctx.resources.release(quadProgram)
            ctx.resources.release(target)
        }))
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        host.destroy()
        out.leaked = host.resources.stats.leaked
        XCTAssertEqual(out.glError, GLenum(GL_NO_ERROR))
        XCTAssertEqual(out.leaked, 0, "no GPU object after release and destroy")
        XCTAssertFalse(out.stateBefore.isEmpty)
        XCTAssertEqual(out.stateBefore, out.stateAfter, "program, depth func, depth mask, framebuffer, viewport, enables")
        return out
    }

    /// The largest byte error over the pixels for which `include` is true, with the pixel where it occurs.
    static func maxError(_ pixels: [UInt8], _ expected: [SIMD3<Int>],
                         include: (Int, Int) -> Bool = { _, _ in true }) -> (error: Int, pixel: (Int, Int), count: Int) {
        var worst = 0, at = (0, 0), count = 0
        guard pixels.count == size * size * 4 else { return (Int.max, (-1, -1), 0) }
        for y in 0..<size {
            for x in 0..<size where include(x, y) {
                count += 1
                let i = (y * size + x) * 4, want = expected[y * size + x]
                for c in 0..<3 {
                    let e = abs(Int(pixels[i + c]) - want[c])
                    if e > worst { worst = e; at = (x, y) }
                }
            }
        }
        return (worst, at, count)
    }

    // MARK: Drawn pixels equal SkyModel (SC-R02F18-004)

    func testLevelCameraMatchesTheReference() throws {
        let o = try draw(view: Self.levelView, sun: Self.lowSunBehind)
        XCTAssertNil(o.error)
        XCTAssertEqual(o.calls, 1)
        let (error, pixel, count) = Self.maxError(o.pixels, try Self.expected(view: Self.levelView, sun: Self.lowSunBehind))
        print("SkyRendererTests: level camera, \(count) px, max error \(error)/255 at \(pixel)")
        XCTAssertEqual(count, Self.size * Self.size)
        XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "worst pixel \(pixel)")
        // The horizon is in view: the bottom row (ground) and the top row (sky) differ.
        XCTAssertNotEqual(Array(o.pixels[0..<3]), Array(o.pixels[(Self.size * (Self.size - 1)) * 4..<(Self.size * (Self.size - 1)) * 4 + 3]))
    }

    func testTiltedCameraWithTheSunInViewMatchesTheReference() throws {
        let sun = try Self.direction(40, 44, view: Self.tiltedView)
        let o = try draw(view: Self.tiltedView, sun: sun)
        XCTAssertNil(o.error)
        let (error, pixel, count) = Self.maxError(o.pixels, try Self.expected(view: Self.tiltedView, sun: sun))
        print("SkyRendererTests: tilted camera, \(count) px, max error \(error)/255 at \(pixel)")
        XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "worst pixel \(pixel)")
        let i = (44 * Self.size + 40) * 4
        XCTAssertEqual([o.pixels[i], o.pixels[i + 1], o.pixels[i + 2]], [255, 255, 255], "the sun disc is drawn")
    }

    // MARK: Only where depth is far (research R6)

    func testSkyIsDrawnOnlyWhereDepthIsFar() throws {
        let o = try draw(view: Self.levelView, sun: Self.lowSunBehind, quad: true)
        XCTAssertNil(o.error)
        var quadPixels = 0
        for y in 0..<Self.size {
            for x in 0..<(Self.size / 2) {
                let p = DrawHarness.px(o.pixels, Self.size, x, y)
                XCTAssertEqual(p, SIMD4(255, 0, 0, 255), "quad pixel (\(x), \(y)) keeps its colour")
                quadPixels += 1
            }
        }
        XCTAssertEqual(quadPixels, Self.size * Self.size / 2)
        let expected = try Self.expected(view: Self.levelView, sun: Self.lowSunBehind)
        let (error, pixel, count) = Self.maxError(o.pixels, expected) { x, _ in x >= Self.size / 2 }
        print("SkyRendererTests: behind a quad, \(count) sky px, max error \(error)/255 at \(pixel)")
        XCTAssertEqual(count, Self.size * Self.size / 2)
        XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "the far half is sky, worst pixel \(pixel)")
    }

    // MARK: Refusals

    func testInvalidParametersAndZeroSunThrowAndDrawNothing() throws {
        var bad = SkyParameters()
        bad.glowExponent = 0
        let a = try draw(view: Self.levelView, sun: Self.lowSunBehind, parameters: bad)
        XCTAssertEqual(a.error as? SkyError, .skyParameter("glowExponent"))
        XCTAssertEqual(a.calls, 0)
        XCTAssertTrue(stride(from: 0, to: a.pixels.count, by: 4).allSatisfy { a.pixels[$0] == 0 && a.pixels[$0 + 1] == 0 },
                      "nothing drawn")
        let b = try draw(view: Self.levelView, sun: Vec3(0, 0, 0))
        XCTAssertEqual(b.error as? SkyError, .direction)
        XCTAssertEqual(b.calls, 0)
        XCTAssertTrue(stride(from: 0, to: b.pixels.count, by: 4).allSatisfy { b.pixels[$0] == 0 && b.pixels[$0 + 1] == 0 },
                      "nothing drawn")
    }

    // MARK: Lifetime

    func testReleaseAndContextRecreation() throws {
        let scene = SkyScene()
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        h.view.layoutIfNeeded()
        XCTAssertTrue(h.renderOneFrame(present: false))
        let before = h.readPixels()
        let renderer = scene.renderer
        h.recreateContext()
        XCTAssertTrue(h.renderOneFrame(present: false))
        let after = h.readPixels()
        XCTAssertTrue(scene.renderer === renderer, "the same renderer rebuilt its program")
        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(before, after, "same picture after the context recreation")
        XCTAssertNil(scene.error)
        let live = h.resources.stats.liveCount.values.reduce(0, +)
        scene.renderer?.release()
        XCTAssertEqual(h.resources.stats.liveCount.values.reduce(0, +), live - 1, "the program is released")
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }
}

/// Draws the sky each frame with one renderer kept for the host's lifetime (the window surface has no depth buffer,
/// so the depth test passes everywhere); teardown releases the program and the next draw rebuilds it.
@MainActor
private final class SkyScene: RenderScene {
    private(set) var renderer: SkyRenderer?
    private(set) var error: Error?

    func setup(_ c: RenderContext) throws {
        if renderer == nil { renderer = try SkyRenderer(registry: c.resources) }
    }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        do {
            let inverse = (SkyRendererTests.projection * SkyRendererTests.levelView).inverse ?? .identity
            try renderer?.draw(inverseViewProjection: inverse, sun: SkyRendererTests.lowSunBehind,
                               parameters: SkyParameters())
        } catch { self.error = error }
    }
    func teardown(_ c: RenderContext) { renderer?.release() }
}
