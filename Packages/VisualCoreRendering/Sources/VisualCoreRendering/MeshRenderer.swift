// MeshRenderer.swift — draws a generated Mesh with Lambert lighting through an OrbitCamera
// (feature 006 T-F517; FR-F508, FR-F509; research R7/R8). Back faces are culled; depth testing is left
// to the caller (enable it when the bound framebuffer has a depth buffer). GPU buffers are rebuilt after
// a context recreation. Feature 055 (A07-P02) T-A07-203 (FR-A07-202; gap G-RAILDRAW) adds the free-camera overload
// `draw(model:view:projection:color:fog:)` with optional linear eye-depth fog (MeshFog); the orbit-camera method
// forwards to it with fog nil, whose mix factor is exactly 0, so existing pixels are unchanged. Feature 090 (A12-P02)
// T-A12-203 (FR-A12-201; gap G-MATERIALS; research D1) adds the per-vertex colour stream `init(mesh:colors:registry:)`:
// attribute `a_color` at location 2 in its own buffer multiplies `u_color` before lighting; without colours the
// attribute is disabled with the constant (1, 1, 1, 1), so multiplying by 1.0 leaves existing pixels bit-identical.
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
    private var colorBuffer: GPUBuffer?
    /// Validated per-vertex RGBA as Float32 (4 per vertex), or nil when the mesh has no colour stream.
    private let colorFloats: [Float]?
    /// Direction toward the light in world space.
    public var lightDirection = Vec3(0.3, 0.6, 1).normalized
    /// Ambient light fraction (0…1) added to the Lambert term.
    public var ambient = 0.15

    static let vertexSource = """
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec4 a_color;
    uniform mat4 u_mvp;
    uniform mat4 u_model;
    uniform mat4 u_modelView;
    out vec3 v_normal;
    out float v_depth;
    out vec4 v_color;
    void main() {
        v_color = a_color;
        v_normal = mat3(u_model) * a_normal;
        v_depth = -(u_modelView * vec4(a_position, 1.0)).z;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """
    static let fragmentSource = """
    precision mediump float;
    in vec3 v_normal;
    in highp float v_depth;
    in vec4 v_color;
    uniform vec4 u_color;
    uniform vec3 u_light;
    uniform float u_ambient;
    uniform highp vec3 u_fog;
    uniform vec4 u_fogColor;
    out vec4 color;
    void main() {
        float lambert = max(dot(normalize(v_normal), normalize(u_light)), 0.0);
        vec4 base = u_color * v_color;
        vec4 lit = vec4(base.rgb * (u_ambient + (1.0 - u_ambient) * lambert) * base.a, base.a);
        float f = u_fog.z * clamp((v_depth - u_fog.x) / (u_fog.y - u_fog.x), 0.0, 1.0);
        color = mix(lit, u_fogColor, f);
    }
    """

    /// Uploads the mesh into registry buffers and compiles the shader; throws on budget or shader errors.
    /// Equivalent to `init(mesh:colors:registry:)` with `colors` nil.
    public convenience init(mesh: Mesh, registry: ResourceRegistry) throws {
        try self.init(mesh: mesh, validatedColors: nil, registry: registry)
    }

    /// Uploads the mesh and an optional per-vertex colour stream into registry buffers and compiles the shader.
    ///
    /// - Parameters:
    ///   - mesh: The mesh whose positions, normals and indices are uploaded.
    ///   - colors: One RGBA colour (each component 0…1) per vertex, multiplied with the draw colour before lighting;
    ///     nil keeps the plain behaviour (a constant colour of (1, 1, 1, 1), so pixels are unchanged).
    ///   - registry: The registry that owns the GPU buffers and the program.
    /// - Throws: `MeshError.invalidInput` when `colors` does not hold exactly one colour per position, or holds a
    ///   non-finite component or one outside 0…1; budget or shader errors from the registry.
    public convenience init(mesh: Mesh, colors: [Vec4]?, registry: ResourceRegistry) throws {
        try self.init(mesh: mesh, validatedColors: Self.validatedColorFloats(colors, vertexCount: mesh.positions.count),
                      registry: registry)
    }

    private init(mesh: Mesh, validatedColors: [Float]?, registry: ResourceRegistry) throws {
        self.mesh = mesh
        self.registry = registry
        self.colorFloats = validatedColors
        try build()
    }

    /// Checks one colour per vertex with finite components in 0…1 and flattens them to Float32 RGBA.
    private static func validatedColorFloats(_ colors: [Vec4]?, vertexCount: Int) throws -> [Float]? {
        guard let colors else { return nil }
        guard colors.count == vertexCount else {
            throw MeshError.invalidInput("colour count \(colors.count) does not match the vertex count \(vertexCount)")
        }
        var floats: [Float] = []
        floats.reserveCapacity(colors.count * 4)
        for (i, c) in colors.enumerated() {
            for v in [c.x, c.y, c.z, c.w] {
                guard v.isFinite else { throw MeshError.invalidInput("colour \(i) has a non-finite component") }
                guard v >= 0, v <= 1 else { throw MeshError.invalidInput("colour \(i) has a component \(v) outside 0…1") }
                floats.append(Float(v))
            }
        }
        return floats
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
        if let colorFloats {
            let cb = try registry.makeBuffer(bytes: max(4, colorFloats.count * 4), label: "mesh colours")
            cb.upload(colorFloats)
            colorBuffer = cb
        } else {
            colorBuffer = nil
        }
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
        if let colorBuffer {
            colorBuffer.bind()
            vcAttribute(2, components: 4, strideFloats: 4, offsetFloats: 0)
        } else {
            // The constant attribute value is global GL state: set it on every draw so u_color × 1 is exact.
            vcglDisableVertexAttribArray(2)
            vcglVertexAttrib4f(2, 1, 1, 1, 1)
        }
        indexBuffer.bind(target: GL_ELEMENT_ARRAY_BUFFER)
        vcglEnable(GLenum(GL_CULL_FACE))
        vcglCullFace(GLenum(GL_BACK))
        vcglDrawElements(GLenum(GL_TRIANGLES), GLsizei(mesh.indices.count), GLenum(GL_UNSIGNED_INT), nil)
        vcglDisable(GLenum(GL_CULL_FACE))
        vcglDisableVertexAttribArray(0); vcglDisableVertexAttribArray(1); vcglDisableVertexAttribArray(2)
    }

    /// Releases the vertex, index and colour buffers and the program back to the registry.
    public func release() {
        if let vertexBuffer { registry.release(vertexBuffer) }
        if let indexBuffer { registry.release(indexBuffer) }
        if let colorBuffer { registry.release(colorBuffer) }
        if let program { registry.release(program) }
        vertexBuffer = nil; indexBuffer = nil; colorBuffer = nil; program = nil
    }
}
