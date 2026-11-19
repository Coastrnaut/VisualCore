// InstancedMeshRenderer.swift — draws one Mesh many times in a single instanced draw call (feature 209, R02-F09,
// T-R02F09-003; clarifications Q1, Q3, Q4, Q5; research R1, R4). Per instance a model matrix (four vec4 attributes at
// locations 3–6) and a colour (vec4 at location 7) are read at divisor 1 from one reused, growing buffer (as
// `ParticleRenderer`); the divisors are reset to 0 after the draw. The shader is `MeshRenderer`'s with `u_model`
// replaced by the instance matrix (normals by its upper 3 × 3, so a uniform scale is exact and a non-uniform scale is
// approximate): same Lambert term with `lightDirection` and `ambient`, same optional linear fog `MeshFog`. GL state as
// `MeshRenderer`: back faces culled (culling disabled again afterwards), depth testing left to the caller. With
// `translucent: true` the instances are drawn back to front (`InstanceOrder.backToFront` on the view-space z of each
// instance's translation, ties in submission order) with premultiplied blending and depth writes off, and blending is
// disabled and depth writes enabled again afterwards. Every refusal (`InstancingError`) is thrown before any GL call.
// GPU objects are rebuilt after a context recreation.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes

/// One placement of the instanced mesh: its model transform and its colour.
public struct MeshInstance: Sendable, Equatable {
    /// Model transform (column-major, `c3` holds the translation); every component must be finite.
    public var model: Mat4
    /// Colour (RGBA 0…1) as `MeshRenderer.draw` takes it: the shader multiplies rgb by alpha, so a translucent instance
    /// blends to the premultiplied mix `rgb·a + (1 − a)·dst`. Every component must be finite.
    public var color: Vec4

    /// Creates an instance drawn with `model` and `color`.
    public init(model: Mat4, color: Vec4) {
        self.model = model
        self.color = color
    }
}

/// Draws one Mesh at many placements with one instanced draw call on the main thread; GPU objects are rebuilt after a
/// context recreation.
@MainActor
public final class InstancedMeshRenderer {
    /// The most instances one `draw` call accepts; a longer list is refused with `InstancingError.tooMany`.
    public static let maxInstances = 16_384
    /// Floats per instance in the instance buffer: a 4 × 4 matrix and an RGBA colour.
    static let floatsPerInstance = 20

    let registry: ResourceRegistry
    /// The mesh whose positions, normals and indices are uploaded.
    public let mesh: Mesh
    private var program: ShaderProgram?
    private var vertexBuffer: GPUBuffer?
    private var indexBuffer: GPUBuffer?
    private let instances: DynamicVertexBuffer
    /// Direction toward the light in world space (as `MeshRenderer.lightDirection`).
    public var lightDirection = Vec3(0.3, 0.6, 1).normalized
    /// Ambient light fraction (0…1) added to the Lambert term (as `MeshRenderer.ambient`).
    public var ambient = 0.15
    /// Instanced draw calls issued since creation (tests prove "one draw call per list" with it).
    var drawCallCount = 0

    static let vertexSource = """
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 3) in mat4 a_model;
    layout(location = 7) in vec4 a_color;
    uniform mat4 u_viewProjection;
    uniform mat4 u_view;
    out vec3 v_normal;
    out float v_depth;
    out vec4 v_color;
    void main() {
        v_color = a_color;
        v_normal = mat3(a_model) * a_normal;
        vec4 world = a_model * vec4(a_position, 1.0);
        v_depth = -(u_view * world).z;
        gl_Position = u_viewProjection * world;
    }
    """
    static let fragmentSource = """
    precision mediump float;
    in vec3 v_normal;
    in highp float v_depth;
    in vec4 v_color;
    uniform vec3 u_light;
    uniform float u_ambient;
    uniform highp vec3 u_fog;
    uniform vec4 u_fogColor;
    out vec4 color;
    void main() {
        float lambert = max(dot(normalize(v_normal), normalize(u_light)), 0.0);
        vec4 base = v_color;
        vec4 lit = vec4(base.rgb * (u_ambient + (1.0 - u_ambient) * lambert) * base.a, base.a);
        float f = u_fog.z * clamp((v_depth - u_fog.x) / (u_fog.y - u_fog.x), 0.0, 1.0);
        color = mix(lit, u_fogColor, f);
    }
    """

    /// Uploads the mesh into registry buffers, creates the (initially empty) instance buffer and compiles the shader.
    /// - Throws: budget or shader errors from the registry.
    public init(mesh: Mesh, registry: ResourceRegistry) throws {
        self.mesh = mesh
        self.registry = registry
        instances = DynamicVertexBuffer(registry: registry, label: "mesh instances")
        try build()
    }

    private func build() throws {
        program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
        let vertices = mesh.interleavedPositionNormal()
        let vb = try registry.makeBuffer(bytes: max(4, vertices.count * 4), label: "instanced mesh vertices")
        vb.upload(vertices)
        let ib = try registry.makeBuffer(bytes: max(4, mesh.indices.count * 4), label: "instanced mesh indices")
        ib.upload(indices: mesh.indices)
        vertexBuffer = vb
        indexBuffer = ib
    }

    /// Checks the list and flattens it to the instance buffer layout (16 matrix floats, column-major, then RGBA).
    /// - Throws: `InstancingError.tooMany` above `maxInstances`, `.notFinite(index)` for the first instance with a
    ///   non-finite matrix or colour component.
    static func instanceFloats(_ list: [MeshInstance]) throws(InstancingError) -> [Float] {
        guard list.count <= maxInstances else { throw .tooMany(count: list.count, limit: maxInstances) }
        var data: [Float] = []
        data.reserveCapacity(list.count * floatsPerInstance)
        for (i, instance) in list.enumerated() {
            let m = instance.model, c = instance.color
            let values = [m.c0.x, m.c0.y, m.c0.z, m.c0.w, m.c1.x, m.c1.y, m.c1.z, m.c1.w,
                          m.c2.x, m.c2.y, m.c2.z, m.c2.w, m.c3.x, m.c3.y, m.c3.z, m.c3.w, c.x, c.y, c.z, c.w]
            for v in values {
                guard v.isFinite else { throw .notFinite(index: i) }
                data.append(Float(v))
            }
        }
        return data
    }

    /// The drawing order of `list` for translucent drawing: indices by ascending view-space z of each instance's
    /// translation (farthest first), ties in submission order (`InstanceOrder.backToFront`).
    static func backToFront(_ list: [MeshInstance], view: Mat4) throws -> [Int] {
        try InstanceOrder.backToFront(depths: list.map { (view * Vec4($0.model.c3.xyz, 1)).z })
    }

    /// Draws every instance of `instances` with one instanced draw call through a camera given as `view` and
    /// `projection` matrices (GL clip space). Lighting and `fog` are those of `MeshRenderer.draw(model:view:projection:
    /// color:fog:)` (fog nil gives a mix factor of exactly 0). Back faces are culled; depth testing is left to the caller.
    /// With `translucent`, the instances are sorted back to front and blended premultiplied with depth writes off; on
    /// return blending is disabled and depth writes are on. An empty list draws nothing and issues no GL call.
    /// - Throws: `InstancingError` (more than `maxInstances`, or a non-finite value) before any GL call; registry errors
    ///   when the GPU objects must be rebuilt after a context recreation.
    public func draw(_ instances: [MeshInstance], view: Mat4, projection: Mat4, fog: MeshFog?,
                     translucent: Bool = false) throws {
        var data = try Self.instanceFloats(instances)   // refuse before any GL call
        guard !instances.isEmpty, !mesh.indices.isEmpty else { return }
        if translucent {
            let n = Self.floatsPerInstance, source = data
            for (slot, index) in try Self.backToFront(instances, view: view).enumerated() {
                data.replaceSubrange(slot * n ..< slot * n + n, with: source[index * n ..< index * n + n])
            }
        }
        if program == nil || program!.generation != registry.generation { try build() }
        guard let program, let vertexBuffer, let indexBuffer else { return }
        program.use()
        program.set("u_viewProjection", matrix4: (projection * view).floats)
        program.set("u_view", matrix4: view.floats)
        if let fog {
            // As MeshRenderer: clamp into Float range and keep end > start after rounding.
            let start = Float(min(fog.start, 1e30))
            var end = Float(min(fog.end, 2e30))
            if !(end > start) { end = start.nextUp }
            program.set("u_fog", SIMD3<Float>(start, end, 1))
            program.set("u_fogColor", SIMD4<Float>(Float(fog.color.x), Float(fog.color.y), Float(fog.color.z), Float(fog.color.w)))
        } else {
            program.set("u_fog", SIMD3<Float>(0, 1, 0))
            program.set("u_fogColor", SIMD4<Float>(0, 0, 0, 0))
        }
        program.set("u_light", SIMD3<Float>(Float(lightDirection.x), Float(lightDirection.y), Float(lightDirection.z)))
        program.set("u_ambient", Float(ambient))
        vertexBuffer.bind()
        vcAttribute(0, components: 3, strideFloats: 6, offsetFloats: 0)
        vcAttribute(1, components: 3, strideFloats: 6, offsetFloats: 3)
        try self.instances.upload(data)   // leaves the instance buffer bound to GL_ARRAY_BUFFER
        for column in 0..<4 {
            vcAttribute(GLuint(3 + column), components: 4, strideFloats: Self.floatsPerInstance,
                        offsetFloats: column * 4, divisor: 1)
        }
        vcAttribute(7, components: 4, strideFloats: Self.floatsPerInstance, offsetFloats: 16, divisor: 1)
        indexBuffer.bind(target: GL_ELEMENT_ARRAY_BUFFER)
        if translucent {
            vcglEnable(GLenum(GL_BLEND))
            vcglBlendEquation(GLenum(GL_FUNC_ADD))
            vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            vcglDepthMask(GLboolean(GL_FALSE))
        }
        vcglEnable(GLenum(GL_CULL_FACE))
        vcglCullFace(GLenum(GL_BACK))
        vcglDrawElementsInstanced(GLenum(GL_TRIANGLES), GLsizei(mesh.indices.count), GLenum(GL_UNSIGNED_INT), nil,
                                  GLsizei(instances.count))
        drawCallCount += 1
        vcglDisable(GLenum(GL_CULL_FACE))
        if translucent {
            vcglDepthMask(GLboolean(GL_TRUE))
            vcglDisable(GLenum(GL_BLEND))
        }
        for index: GLuint in 3...7 { vcglVertexAttribDivisor(index, 0) }
        for index: GLuint in [0, 1, 3, 4, 5, 6, 7] { vcglDisableVertexAttribArray(index) }
    }

    /// Releases the vertex, index and instance buffers and the program back to the registry.
    public func release() {
        if let vertexBuffer { registry.release(vertexBuffer) }
        if let indexBuffer { registry.release(indexBuffer) }
        instances.release()
        if let program { registry.release(program) }
        vertexBuffer = nil; indexBuffer = nil; program = nil
    }
}
