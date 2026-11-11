// MeshRenderer.swift — draws a generated Mesh with Lambert lighting through an OrbitCamera
// (feature 006 T-F517; FR-F508, FR-F509; research R7/R8). Back faces are culled; depth testing is left
// to the caller (enable it when the bound framebuffer has a depth buffer). GPU buffers are rebuilt after
// a context recreation.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes

/// Draws a Mesh with Lambert lighting through an OrbitCamera on the main thread; GPU buffers are rebuilt after a context recreation.
@MainActor
public final class MeshRenderer {
    let registry: ResourceRegistry
    /// The mesh whose positions, normals and indices are uploaded.
    public let mesh: Mesh
    private var program: ShaderProgram?
    private var vertexBuffer: GPUBuffer?
    private var indexBuffer: GPUBuffer?
    /// Direction toward the light in world space.
    public var lightDirection = Vec3(0.3, 0.6, 1).normalized
    /// Ambient light fraction (0…1) added to the Lambert term.
    public var ambient = 0.15

    static let vertexSource = """
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    uniform mat4 u_mvp;
    uniform mat4 u_model;
    out vec3 v_normal;
    void main() {
        v_normal = mat3(u_model) * a_normal;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """
    static let fragmentSource = """
    precision mediump float;
    in vec3 v_normal;
    uniform vec4 u_color;
    uniform vec3 u_light;
    uniform float u_ambient;
    out vec4 color;
    void main() {
        float lambert = max(dot(normalize(v_normal), normalize(u_light)), 0.0);
        color = vec4(u_color.rgb * (u_ambient + (1.0 - u_ambient) * lambert) * u_color.a, u_color.a);
    }
    """

    /// Uploads the mesh into registry buffers and compiles the shader; throws on budget or shader errors.
    public init(mesh: Mesh, registry: ResourceRegistry) throws {
        self.mesh = mesh
        self.registry = registry
        try build()
    }

    private func build() throws {
        program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
        let vertices = mesh.interleavedPositionNormal()
        let vb = try registry.makeBuffer(bytes: max(4, vertices.count * 4), label: "mesh vertices")
        vb.upload(vertices)
        let ib = try registry.makeBuffer(bytes: max(4, mesh.indices.count * 4), label: "mesh indices")
        ib.upload(indices: mesh.indices)
        vertexBuffer = vb
        indexBuffer = ib
    }

    /// Draws with `model` transform and premultiplied-alpha `color` (RGBA 0…1).
    public func draw(model: Mat4 = .identity, camera: OrbitCamera, aspect: Double, color: Vec4) throws {
        if program == nil || program!.generation != registry.generation { try build() }
        guard let program, let vertexBuffer, let indexBuffer, !mesh.indices.isEmpty else { return }
        program.use()
        program.set("u_mvp", matrix4: (camera.viewProjection(aspect: aspect) * model).floats)
        program.set("u_model", matrix4: model.floats)
        program.set("u_color", SIMD4<Float>(Float(color.x), Float(color.y), Float(color.z), Float(color.w)))
        program.set("u_light", SIMD3<Float>(Float(lightDirection.x), Float(lightDirection.y), Float(lightDirection.z)))
        program.set("u_ambient", Float(ambient))
        vertexBuffer.bind()
        vcAttribute(0, components: 3, strideFloats: 6, offsetFloats: 0)
        vcAttribute(1, components: 3, strideFloats: 6, offsetFloats: 3)
        indexBuffer.bind(target: GL_ELEMENT_ARRAY_BUFFER)
        vcglEnable(GLenum(GL_CULL_FACE))
        vcglCullFace(GLenum(GL_BACK))
        vcglDrawElements(GLenum(GL_TRIANGLES), GLsizei(mesh.indices.count), GLenum(GL_UNSIGNED_INT), nil)
        vcglDisable(GLenum(GL_CULL_FACE))
        vcglDisableVertexAttribArray(0); vcglDisableVertexAttribArray(1)
    }

    /// Releases the vertex and index buffers and the program back to the registry.
    public func release() {
        if let vertexBuffer { registry.release(vertexBuffer) }
        if let indexBuffer { registry.release(indexBuffer) }
        if let program { registry.release(program) }
        vertexBuffer = nil; indexBuffer = nil; program = nil
    }
}
