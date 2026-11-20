// SkyRenderer — feature 218 (R02-F18) T-R02F18-005 (FR-R02F18-005, 006; SC-R02F18-004, 005; clarification Q4; research R5, R6).
// Draws the analytic sky (`vc/sky.glsl`, the GPU port of `SkyModel`) behind a scene on the existing OpenGL ES renderer
// and context, following the `PlanarShadowRenderer` ownership pattern (registry at init, `release()` frees the program).
//
// One full-screen triangle at the far plane (research R6): the vertex stage writes gl_Position = (p, 1, 1), so z = w
// and the window depth is 1; the depth test is LEQUAL with depth writes off, so the sky only lands where nothing nearer
// was drawn and leaves the depth buffer as it was. The fragment stage receives the pixel's NDC (x, y) by interpolation,
// unprojects (x, y, −1) and (x, y, 1) with the inverse view-projection (each divided by its w) and takes far − near as
// the view direction d (the eye ray through the pixel centre); vc_sky normalises it. Blending and face culling are off
// for the draw (the sky is opaque and the triangle is not culled whatever the caller's winding state).
//
// State: the current program, the depth-test enable, depth function and depth write mask, and the blend and cull-face
// enables are restored on return. The framebuffer, viewport, scissor and colour mask are the caller's and are not
// changed. Invalid parameters or a zero or non-finite sun throw `SkyError` before any GL call. The program is rebuilt
// on the next draw after a context recreation.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes

/// Draws the analytic sky of clarification Q4 behind a scene, at the far plane of the bound framebuffer, on the main
/// thread; the program is rebuilt after a context recreation (see the file header).
@MainActor
public final class SkyRenderer {
    let registry: ResourceRegistry
    private var program: ShaderProgram?
    /// Sky draw calls issued since creation.
    var drawCallCount = 0

    static let vertexSource = """
    out vec2 v_ndc;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2)) * 2.0 - 1.0;
        v_ndc = p;
        gl_Position = vec4(p, 1.0, 1.0);
    }
    """
    static let fragmentSource = """
    precision highp float;
    #include "vc/sky.glsl"
    in vec2 v_ndc;
    uniform highp mat4 u_inverseViewProjection;
    uniform highp vec3 u_sun;
    uniform highp vec3 u_zenith;
    uniform highp vec3 u_horizon;
    uniform highp vec3 u_ground;
    uniform highp vec3 u_dusk;
    uniform highp vec3 u_night;
    uniform highp vec3 u_sunColour;
    uniform highp vec3 u_sunShape;
    out vec4 color;
    void main() {
        highp vec4 nearPoint = u_inverseViewProjection * vec4(v_ndc, -1.0, 1.0);
        highp vec4 farPoint = u_inverseViewProjection * vec4(v_ndc, 1.0, 1.0);
        highp vec3 d = farPoint.xyz / farPoint.w - nearPoint.xyz / nearPoint.w;
        color = vec4(vc_sky(d, u_sun, u_zenith, u_horizon, u_ground, u_dusk, u_night, u_sunColour, u_sunShape), 1.0);
    }
    """

    /// Compiles the sky program through `registry`.
    /// - Parameter registry: The registry that owns the program.
    /// - Throws: shader errors from the registry.
    public init(registry: ResourceRegistry) throws {
        self.registry = registry
        try build()
    }

    private func build() throws {
        program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource,
                                       library: ShaderBundle.visualCoreIncludes,
                                       vertexName: "sky.vert", fragmentName: "sky.frag")
    }

    /// Draws the sky seen through the camera whose inverse view-projection (GL clip space) is
    /// `inverseViewProjection`, with the sun towards `sun`, into the bound framebuffer and viewport at depth 1: only
    /// pixels whose depth is still the far value (1) are written, and the depth buffer is not changed. The GL state
    /// listed in the file header is restored on return.
    /// - Parameters:
    ///   - inverseViewProjection: The inverse of projection × view.
    ///   - sun: The direction towards the sun (any non-zero finite length).
    ///   - parameters: The sky settings.
    /// - Throws: ``SkyError/skyParameter(_:)`` for invalid parameters and ``SkyError/direction`` for a zero or
    ///   non-finite sun, before any GL call; registry errors when the program must be rebuilt after a context
    ///   recreation.
    public func draw(inverseViewProjection: Mat4, sun: Vec3, parameters: SkyParameters) throws {
        let p = try parameters.validated()
        guard sun.isFinite, sun.length > 0, (sun / sun.length).isFinite else { throw SkyError.direction }
        if program == nil || program!.generation != registry.generation { try build() }
        guard let program else { return }
        let saved = SavedState.capture()
        defer { saved.restore() }

        vcglEnable(GLenum(GL_DEPTH_TEST))
        vcglDepthFunc(GLenum(GL_LEQUAL))
        vcglDepthMask(GLboolean(GL_FALSE))
        vcglDisable(GLenum(GL_BLEND))
        vcglDisable(GLenum(GL_CULL_FACE))
        program.use()
        program.set("u_inverseViewProjection", matrix4: inverseViewProjection.floats)
        program.set("u_sun", Self.floats(sun))
        program.set("u_zenith", Self.floats(p.zenith))
        program.set("u_horizon", Self.floats(p.horizon))
        program.set("u_ground", Self.floats(p.ground))
        program.set("u_dusk", Self.floats(p.dusk))
        program.set("u_night", Self.floats(p.night))
        program.set("u_sunColour", Self.floats(p.sunColour))
        program.set("u_sunShape", SIMD3<Float>(Float(p.sunRadius), Float(p.glowStrength), Float(p.glowExponent)))
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        drawCallCount += 1
    }

    /// Releases the program back to the registry.
    public func release() {
        if let program { registry.release(program) }
        program = nil
    }

    private static func floats(_ v: Vec3) -> SIMD3<Float> { SIMD3(Float(v.x), Float(v.y), Float(v.z)) }

    /// The GL state a sky draw changes, captured before and restored after it.
    private struct SavedState {
        var program: GLint
        var depthTest: Bool, blend: Bool, cull: Bool
        var depthFunc: GLint
        var depthWrite: GLboolean

        @MainActor
        static func capture() -> SavedState {
            func integer(_ name: Int32) -> GLint { var v: GLint = 0; vcglGetIntegerv(GLenum(name), &v); return v }
            func enabled(_ cap: Int32) -> Bool { vcglIsEnabled(GLenum(cap)) == GLboolean(GL_TRUE) }
            var mask = GLboolean(GL_TRUE)
            vcglGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &mask)
            return SavedState(program: integer(GL_CURRENT_PROGRAM), depthTest: enabled(GL_DEPTH_TEST),
                              blend: enabled(GL_BLEND), cull: enabled(GL_CULL_FACE),
                              depthFunc: integer(GL_DEPTH_FUNC), depthWrite: mask)
        }

        @MainActor
        func restore() {
            func toggle(_ cap: Int32, _ on: Bool) { on ? vcglEnable(GLenum(cap)) : vcglDisable(GLenum(cap)) }
            vcglUseProgram(GLuint(program))
            vcglDepthFunc(GLenum(depthFunc))
            vcglDepthMask(depthWrite)
            toggle(GL_DEPTH_TEST, depthTest)
            toggle(GL_BLEND, blend)
            toggle(GL_CULL_FACE, cull)
        }
    }
}
