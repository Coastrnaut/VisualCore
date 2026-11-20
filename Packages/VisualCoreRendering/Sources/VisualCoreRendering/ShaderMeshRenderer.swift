// ShaderMeshRenderer.swift — draws a generated Mesh with a caller-supplied GLSL ES program (feature 303, R02-G01-03,
// T-R02G0103-006; research R8). `MeshRenderer` shades with a fixed Lambert model; an experience whose material is
// computed in shaders (for example Aurora Loom's ribbons: bevel, interference, glow) needs its own program on the same
// mesh streams. Streams: `a_position` (location 0) and `a_normal` (location 1) interleaved as
// `Mesh.interleavedPositionNormal()`, and `a_uv` (location 2) from `Mesh.uvs` in its own buffer (a constant (0, 0)
// when the mesh has no uvs). The caller sets uniforms through a closure on the bound program; blending, back-face
// culling and depth testing are chosen per draw and restored afterwards. GPU buffers and the program are rebuilt after a
// context recreation, as `MeshRenderer` does.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes

/// How a `ShaderMeshRenderer` draw blends with the framebuffer.
public enum ShaderMeshBlend: Sendable, Equatable {
    /// No blending: the fragment replaces the pixel.
    case opaque
    /// Premultiplied alpha: `src + dst · (1 − src.a)`.
    case premultipliedAlpha
    /// Additive: `src + dst` (for glow).
    case additive
}

/// Draws one generated mesh with a custom program; see the file header for the stream layout.
@MainActor
public final class ShaderMeshRenderer {
    /// The mesh drawn.
    public let mesh: Mesh
    let registry: ResourceRegistry
    let vertexSource: String
    let fragmentSource: String
    let vertexName: String
    let fragmentName: String
    private var program: ShaderProgram?
    private var vertexBuffer: GPUBuffer?
    private var uvBuffer: GPUBuffer?
    private var indexBuffer: GPUBuffer?

    /// Compiles the program and uploads the mesh.
    ///
    /// - Throws: `ShaderError` when a stage fails to expand, compile or link; a `ResourceError` when a buffer cannot be
    ///   made.
    public init(mesh: Mesh, vertex: String, fragment: String, registry: ResourceRegistry,
                vertexName: String = "vertex", fragmentName: String = "fragment") throws {
        self.mesh = mesh
        self.registry = registry
        self.vertexSource = vertex
        self.fragmentSource = fragment
        self.vertexName = vertexName
        self.fragmentName = fragmentName
        try build()
    }

    private func build() throws {
        program = try registry.program(vertex: vertexSource, fragment: fragmentSource, vertexName: vertexName,
                                       fragmentName: fragmentName)
        let vertices = mesh.interleavedPositionNormal()
        let vb = try registry.makeBuffer(bytes: max(4, vertices.count * 4), label: "shader mesh vertices")
        vb.upload(vertices)
        vertexBuffer = vb
        if mesh.uvs.count == mesh.positions.count, !mesh.uvs.isEmpty {
            var floats: [Float] = []
            floats.reserveCapacity(mesh.uvs.count * 2)
            for uv in mesh.uvs {
                floats.append(Float(uv.x))
                floats.append(Float(uv.y))
            }
            let ub = try registry.makeBuffer(bytes: max(4, floats.count * 4), label: "shader mesh uvs")
            ub.upload(floats)
            uvBuffer = ub
        } else {
            uvBuffer = nil
        }
        let ib = try registry.makeBuffer(bytes: max(4, mesh.indices.count * 4), label: "shader mesh indices")
        ib.upload(indices: mesh.indices)
        indexBuffer = ib
    }

    /// Draws the mesh: binds the program, calls `uniforms` with it, binds the streams and draws the triangles with
    /// `blend`, optional back-face culling and optional depth testing (enable it only when the bound framebuffer has a
    /// depth buffer). Blending, culling and depth testing are switched off again afterwards.
    ///
    /// - Throws: what rebuilding after a context recreation throws.
    public func draw(blend: ShaderMeshBlend = .opaque, cullBackFaces: Bool = false, depthTest: Bool = false,
                     uniforms: (ShaderProgram) -> Void) throws {
        if program == nil || program!.generation != registry.generation { try build() }
        guard let program, let vertexBuffer, let indexBuffer, !mesh.indices.isEmpty else { return }
        program.use()
        uniforms(program)
        vertexBuffer.bind()
        vcAttribute(0, components: 3, strideFloats: 6, offsetFloats: 0)
        vcAttribute(1, components: 3, strideFloats: 6, offsetFloats: 3)
        if let uvBuffer {
            uvBuffer.bind()
            vcAttribute(2, components: 2, strideFloats: 2, offsetFloats: 0)
        } else {
            vcglDisableVertexAttribArray(2)
            vcglVertexAttrib4f(2, 0, 0, 0, 1)
        }
        indexBuffer.bind(target: GL_ELEMENT_ARRAY_BUFFER)
        switch blend {
        case .opaque:
            vcglDisable(GLenum(GL_BLEND))
        case .premultipliedAlpha:
            vcglEnable(GLenum(GL_BLEND))
            vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        case .additive:
            vcglEnable(GLenum(GL_BLEND))
            vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE))
        }
        if cullBackFaces {
            vcglEnable(GLenum(GL_CULL_FACE))
            vcglCullFace(GLenum(GL_BACK))
        }
        if depthTest { vcglEnable(GLenum(GL_DEPTH_TEST)) }
        vcglDrawElements(GLenum(GL_TRIANGLES), GLsizei(mesh.indices.count), GLenum(GL_UNSIGNED_INT), nil)
        if depthTest { vcglDisable(GLenum(GL_DEPTH_TEST)) }
        if cullBackFaces { vcglDisable(GLenum(GL_CULL_FACE)) }
        if blend != .opaque { vcglDisable(GLenum(GL_BLEND)) }
        vcglDisableVertexAttribArray(0); vcglDisableVertexAttribArray(1); vcglDisableVertexAttribArray(2)
    }

    /// Releases the buffers and the program; a later draw rebuilds them.
    public func release() {
        if let vertexBuffer { registry.release(vertexBuffer) }
        if let uvBuffer { registry.release(uvBuffer) }
        if let indexBuffer { registry.release(indexBuffer) }
        if let program { registry.release(program) }
        vertexBuffer = nil; uvBuffer = nil; indexBuffer = nil; program = nil
    }
}
