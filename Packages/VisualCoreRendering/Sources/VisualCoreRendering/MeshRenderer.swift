// MeshRenderer.swift — draws a generated Mesh with Lambert lighting through an OrbitCamera
// (feature 006 T-F517; FR-F508, FR-F509; research R7/R8). Back faces are culled; depth testing is left
// to the caller (enable it when the bound framebuffer has a depth buffer). GPU buffers are rebuilt after
// a context recreation. Feature 055 (A07-P02) T-A07-203 (FR-A07-202; gap G-RAILDRAW) adds the free-camera overload
// `draw(model:view:projection:color:fog:)` with optional linear eye-depth fog (MeshFog); the orbit-camera method
// forwards to it with fog nil, whose mix factor is exactly 0, so existing pixels are unchanged.
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
    uniform mat4 u_modelView;
    out vec3 v_normal;
    out float v_depth;
    void main() {
        v_normal = mat3(u_model) * a_normal;
        v_depth = -(u_modelView * vec4(a_position, 1.0)).z;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """
    static let fragmentSource = """
    precision mediump float;
    in vec3 v_normal;
    in highp float v_depth;
    uniform vec4 u_color;
    uniform vec3 u_light;
    uniform float u_ambient;
    uniform highp vec3 u_fog;
    uniform vec4 u_fogColor;
    out vec4 color;
    void main() {
        float lambert = max(dot(normalize(v_normal), normalize(u_light)), 0.0);
        vec4 lit = vec4(u_color.rgb * (u_ambient + (1.0 - u_ambient) * lambert) * u_color.a, u_color.a);
        float f = u_fog.z * clamp((v_depth - u_fog.x) / (u_fog.y - u_fog.x), 0.0, 1.0);
        color = mix(lit, u_fogColor, f);
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

    /// Draws with `model` transform and premultiplied-alpha `color` (RGBA 0…1) through `camera`; forwards to
    /// `draw(model:view:projection:color:fog:)` with the camera's view and projection and no fog.
    public func draw(model: Mat4 = .identity, camera: OrbitCamera, aspect: Double, color: Vec4) throws {
        try draw(model: model, view: camera.view(), projection: camera.projection(aspect: aspect), color: color, fog: nil)
    }

    /// Draws with `model` transform and premultiplied-alpha `color` (RGBA 0…1) through a free camera given as `view`
    /// and `projection` matrices (GL clip space). With `fog`, the colour is mixed linearly in eye-space depth toward
    /// the fog colour (factor clamp((depth − start) / (end − start), 0, 1)); with nil the factor is exactly 0.
    public func draw(model: Mat4, view: Mat4, projection: Mat4, color: Vec4, fog: MeshFog?) throws {
        if program == nil || program!.generation != registry.generation { try build() }
        guard let program, let vertexBuffer, let indexBuffer, !mesh.indices.isEmpty else { return }
        program.use()
        program.set("u_mvp", matrix4: (projection * view * model).floats)
        program.set("u_model", matrix4: model.floats)
        program.set("u_modelView", matrix4: (view * model).floats)
        if let fog {
            // Clamp into Float range and keep end > start after rounding so the shader never divides by zero.
            let start = Float(min(fog.start, 1e30))
            var end = Float(min(fog.end, 2e30))
            if !(end > start) { end = start.nextUp }
            program.set("u_fog", SIMD3<Float>(start, end, 1))
            program.set("u_fogColor", SIMD4<Float>(Float(fog.color.x), Float(fog.color.y), Float(fog.color.z), Float(fog.color.w)))
        } else {
            program.set("u_fog", SIMD3<Float>(0, 1, 0))
            program.set("u_fogColor", SIMD4<Float>(0, 0, 0, 0))
        }
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
