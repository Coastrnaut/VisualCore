// PlanarShadowRenderer.swift — feature 213 (R02-F13) T-R02F13-004 (FR-R02F13-005; SC-R02F13-003; research R1, R5;
// clarification Q5). Draws the planar projected shadow of a mesh on the existing OpenGL ES renderer and context, from the
// same projection the CPU scores: the 4 × 4 planar projection of J. Blinn, "Me and my (fake) shadow", IEEE Computer
// Graphics and Applications 8(1), 1988 (`ShadowProjector.matrix(light:onto:)`).
//
// Two passes (research R5, single darkening):
// 1. Coverage. A pooled `.rgba8` target of the viewport size is cleared to 0 and the mesh is drawn into it with
//    gl_Position = projection × view × S × model × p, writing 1. No blending, no depth test and no face culling (the
//    flattened mesh has both windings and both must cover), so a pixel covered several times by overlapping parts of
//    the object still holds exactly 1, as a stencil test would give.
// 2. Composite. The previously bound framebuffer and viewport are restored and one full-screen triangle reads the
//    coverage c of its own pixel (texelFetch, no filtering) and writes the premultiplied (0, 0, 0, darkness × c) with
//    blend (ONE, ONE_MINUS_SRC_ALPHA), so every covered pixel becomes dst × (1 − darkness) exactly once.
//
// S is divided by its homogeneous scale P · l (= trace(S) / 3 for Blinn's M = (P · l) I − l Pᵀ) so the w of every
// projected point below the light is positive (a directional light has P · l = n · d < 0, which would otherwise put the
// shadow behind the clip volume); the projected point is unchanged.
//
// State: the previous framebuffer binding, viewport, clear colour, blend enable, factors and equations, depth-test,
// cull-face and scissor enables, depth write mask, colour mask, active texture unit and its 2D texture binding are
// restored on return (also when a step throws). A light refusal (`ShadowError`) is thrown before any GL call; a target
// that cannot be created throws, draws nothing and leaves the previous framebuffer bound. The programs and mesh buffers
// are rebuilt on the next draw after a context recreation (clarification Q5, spec edge case "a context rebuild").
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes

/// Draws the planar projected shadow of a mesh (Blinn 1988) onto a plane, darkening every covered pixel exactly once,
/// on the main thread; GPU objects are rebuilt after a context recreation (see the file header).
@MainActor
public final class PlanarShadowRenderer {
    let registry: ResourceRegistry
    /// The mesh whose shadow is drawn (positions and indices are uploaded; normals are not used).
    public let mesh: Mesh
    private var coverageProgram: ShaderProgram?
    private var compositeProgram: ShaderProgram?
    private var vertexBuffer: GPUBuffer?
    private var indexBuffer: GPUBuffer?
    /// Coverage and composite draw calls issued since creation (tests prove two calls per shadow with it).
    var drawCallCount = 0

    /// How much a covered pixel is darkened: the destination is multiplied by 1 − darkness. Clamped to 0…1 on
    /// assignment (a NaN becomes 0); the default is 0.5.
    public var darkness: Double = 0.5 {
        didSet { darkness = darkness.isNaN ? 0 : Swift.min(Swift.max(darkness, 0), 1) }
    }

    static let coverageVertexSource = """
    layout(location = 0) in vec3 a_position;
    uniform highp mat4 u_mvp;
    void main() {
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """
    static let coverageFragmentSource = """
    precision mediump float;
    out vec4 color;
    void main() {
        color = vec4(1.0);
    }
    """
    static let compositeVertexSource = """
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """
    static let compositeFragmentSource = """
    precision highp float;
    uniform highp sampler2D u_coverage;
    uniform highp vec2 u_origin;
    uniform float u_darkness;
    out vec4 color;
    void main() {
        float c = texelFetch(u_coverage, ivec2(gl_FragCoord.xy - u_origin), 0).r;
        color = vec4(0.0, 0.0, 0.0, u_darkness * c);
    }
    """

    /// Uploads the mesh positions and indices into registry buffers and compiles the coverage and composite programs.
    /// - Parameters:
    ///   - mesh: The mesh whose shadow is drawn, in model space.
    ///   - registry: The registry that owns the buffers, the programs and the pooled coverage target.
    /// - Throws: budget or shader errors from the registry.
    public init(mesh: Mesh, registry: ResourceRegistry) throws {
        self.mesh = mesh
        self.registry = registry
        try build()
    }

    private func build() throws {
        coverageProgram = try registry.program(vertex: Self.coverageVertexSource, fragment: Self.coverageFragmentSource)
        compositeProgram = try registry.program(vertex: Self.compositeVertexSource, fragment: Self.compositeFragmentSource)
        let vertices = mesh.interleavedPositionNormal()
        let vb = try registry.makeBuffer(bytes: Swift.max(4, vertices.count * 4), label: "shadow vertices")
        vb.upload(vertices)
        let ib = try registry.makeBuffer(bytes: Swift.max(4, mesh.indices.count * 4), label: "shadow indices")
        ib.upload(indices: mesh.indices)
        vertexBuffer = vb
        indexBuffer = ib
    }

    /// The Blinn matrix of `light` onto `plane` divided by its homogeneous scale P · l = trace / 3, so projected points
    /// below the light have w > 0 (see the file header).
    /// - Throws: every light refusal of `ShadowProjector.matrix(light:onto:)`.
    static func normalizedMatrix(light: ShadowLight, plane: ProjectionPlane) throws(ShadowError) -> Mat4 {
        let s = try ShadowProjector.matrix(light: light, onto: plane)
        let scale = (s.c0.x + s.c1.y + s.c2.z + s.c3.w) / 3
        guard scale != 0, scale.isFinite else { return s }
        let k = 1 / scale
        return Mat4(s.c0 * k, s.c1 * k, s.c2 * k, s.c3 * k)
    }

    /// Draws the shadow of the mesh, placed by `model`, cast by `light` onto `plane`, seen through `view` and
    /// `projection` (GL clip space), into the currently bound framebuffer: every pixel the flattened mesh covers is
    /// multiplied by 1 − `darkness` exactly once, however often the mesh overlaps itself there. `viewport` is the size
    /// of the drawn area in pixels (the coverage target's size), starting at the current viewport's origin. The GL
    /// state listed in the file header is restored on return. An empty mesh draws nothing.
    /// - Throws: `ShadowError` (a parallel light, a light below or on the plane, a non-finite or zero light) before any
    ///   GL call; registry errors when the coverage target cannot be created (nothing is drawn and the previous
    ///   framebuffer stays bound) or the GPU objects must be rebuilt after a context recreation.
    public func draw(model: Mat4, light: ShadowLight, plane: ProjectionPlane, view: Mat4, projection: Mat4,
                     viewport: (width: Int, height: Int)) throws {
        let shadow = try Self.normalizedMatrix(light: light, plane: plane)   // refuse before any GL call
        guard !mesh.indices.isEmpty else { return }
        if coverageProgram == nil || compositeProgram == nil || vertexBuffer == nil
            || coverageProgram!.generation != registry.generation || compositeProgram!.generation != registry.generation {
            try build()
        }
        guard let coverageProgram, let compositeProgram, let vertexBuffer, let indexBuffer else { return }
        let saved = SavedState.capture()
        defer { saved.restore() }
        let target = try registry.acquireTarget(width: viewport.width, height: viewport.height, format: .rgba8)
        defer { registry.recycle(target) }

        // Pass 1: coverage (no blending, no depth test, no culling).
        target.bind()
        vcglViewport(0, 0, GLsizei(viewport.width), GLsizei(viewport.height))
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        vcglDisable(GLenum(GL_BLEND))
        vcglDisable(GLenum(GL_DEPTH_TEST))
        vcglDisable(GLenum(GL_CULL_FACE))
        vcglDepthMask(GLboolean(GL_FALSE))
        vcglColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
        vcglClearColor(0, 0, 0, 0)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        coverageProgram.use()
        coverageProgram.set("u_mvp", matrix4: (projection * view * shadow * model).floats)
        vertexBuffer.bind()
        vcAttribute(0, components: 3, strideFloats: 6, offsetFloats: 0)
        indexBuffer.bind(target: GL_ELEMENT_ARRAY_BUFFER)
        vcglDrawElements(GLenum(GL_TRIANGLES), GLsizei(mesh.indices.count), GLenum(GL_UNSIGNED_INT), nil)
        drawCallCount += 1
        vcglDisableVertexAttribArray(0)

        // Pass 2: composite into the previous framebuffer, dst × (1 − darkness × coverage).
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), GLuint(saved.framebuffer))
        vcglViewport(saved.viewport[0], saved.viewport[1], GLsizei(viewport.width), GLsizei(viewport.height))
        if saved.scissor { vcglEnable(GLenum(GL_SCISSOR_TEST)) }
        vcglEnable(GLenum(GL_BLEND))
        vcglBlendEquation(GLenum(GL_FUNC_ADD))
        vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        vcglColorMask(saved.colorMask[0], saved.colorMask[1], saved.colorMask[2], saved.colorMask[3])
        compositeProgram.use()
        target.bindColor(unit: 0)
        compositeProgram.set("u_coverage", Int32(0))
        compositeProgram.set("u_origin", SIMD2<Float>(Float(saved.viewport[0]), Float(saved.viewport[1])))
        compositeProgram.set("u_darkness", Float(darkness))
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        drawCallCount += 1
    }

    /// Releases the mesh buffers and both programs back to the registry (pooled coverage targets belong to the
    /// registry's pool, which frees them on `trimPools()` and at context end).
    public func release() {
        if let vertexBuffer { registry.release(vertexBuffer) }
        if let indexBuffer { registry.release(indexBuffer) }
        if let coverageProgram { registry.release(coverageProgram) }
        if let compositeProgram { registry.release(compositeProgram) }
        vertexBuffer = nil; indexBuffer = nil; coverageProgram = nil; compositeProgram = nil
    }

    /// The GL state a shadow draw changes, captured before and restored after it.
    private struct SavedState {
        var framebuffer: GLint
        var viewport: [GLint]
        var clearColor: [GLfloat]
        var blend: Bool, depthTest: Bool, cull: Bool, scissor: Bool
        var depthWrite: GLboolean
        var colorMask: [GLboolean]
        var factors: [GLint]
        var equations: [GLint]
        var activeTexture: GLint
        var texture: GLint

        @MainActor
        static func capture() -> SavedState {
            func integer(_ name: Int32) -> GLint { var v: GLint = 0; vcglGetIntegerv(GLenum(name), &v); return v }
            func enabled(_ cap: Int32) -> Bool { vcglIsEnabled(GLenum(cap)) == GLboolean(GL_TRUE) }
            var mask = GLboolean(GL_TRUE)
            vcglGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &mask)
            var colorMask = [GLboolean](repeating: GLboolean(GL_TRUE), count: 4)
            vcglGetBooleanv(GLenum(GL_COLOR_WRITEMASK), &colorMask)
            var viewport: [GLint] = [0, 0, 0, 0]
            vcglGetIntegerv(GLenum(GL_VIEWPORT), &viewport)
            var clear: [GLfloat] = [0, 0, 0, 0]
            vcglGetFloatv(GLenum(GL_COLOR_CLEAR_VALUE), &clear)
            let unit = integer(GL_ACTIVE_TEXTURE)
            vcglActiveTexture(GLenum(GL_TEXTURE0))
            let texture = integer(GL_TEXTURE_BINDING_2D)
            vcglActiveTexture(GLenum(unit))
            return SavedState(
                framebuffer: integer(GL_FRAMEBUFFER_BINDING), viewport: viewport, clearColor: clear,
                blend: enabled(GL_BLEND), depthTest: enabled(GL_DEPTH_TEST), cull: enabled(GL_CULL_FACE),
                scissor: enabled(GL_SCISSOR_TEST), depthWrite: mask, colorMask: colorMask,
                factors: [GL_BLEND_SRC_RGB, GL_BLEND_DST_RGB, GL_BLEND_SRC_ALPHA, GL_BLEND_DST_ALPHA].map(integer),
                equations: [GL_BLEND_EQUATION, GL_BLEND_EQUATION_ALPHA].map(integer),   // GL_BLEND_EQUATION = _RGB
                activeTexture: unit, texture: texture)
        }

        @MainActor
        func restore() {
            func toggle(_ cap: Int32, _ on: Bool) { on ? vcglEnable(GLenum(cap)) : vcglDisable(GLenum(cap)) }
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), GLuint(framebuffer))
            vcglViewport(viewport[0], viewport[1], GLsizei(viewport[2]), GLsizei(viewport[3]))
            vcglClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3])
            vcglBlendFuncSeparate(GLenum(factors[0]), GLenum(factors[1]), GLenum(factors[2]), GLenum(factors[3]))
            vcglBlendEquationSeparate(GLenum(equations[0]), GLenum(equations[1]))
            vcglDepthMask(depthWrite)
            vcglColorMask(colorMask[0], colorMask[1], colorMask[2], colorMask[3])
            toggle(GL_BLEND, blend)
            toggle(GL_DEPTH_TEST, depthTest)
            toggle(GL_CULL_FACE, cull)
            toggle(GL_SCISSOR_TEST, scissor)
            vcglActiveTexture(GLenum(GL_TEXTURE0))
            vcglBindTexture(GLenum(GL_TEXTURE_2D), GLuint(texture))
            vcglActiveTexture(GLenum(activeTexture))
        }
    }
}
