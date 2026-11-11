// ParticleRenderer.swift — draws ParticleInstances as instanced soft-edged quads (feature 006 T-F514;
// FR-F507, FR-F508, FR-F512; research R7). Per instance: NDC center, NDC half size, premultiplied color;
// the quad corners come from gl_VertexID, so there is no per-vertex buffer.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
public final class ParticleRenderer {
    let registry: ResourceRegistry
    private var program: ShaderProgram?
    private let instances: DynamicVertexBuffer
    public private(set) var lastInstanceCount = 0

    static let vertexSource = """
    layout(location = 0) in vec4 a_instance;   // center.xy, halfSize.xy (NDC)
    layout(location = 1) in vec4 a_color;      // premultiplied
    out vec4 v_color;
    out vec2 v_local;
    const vec2 corners[6] = vec2[6](vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(1.0, 1.0),
                                    vec2(-1.0, -1.0), vec2(1.0, 1.0), vec2(-1.0, 1.0));
    void main() {
        vec2 k = corners[gl_VertexID % 6];
        v_local = k;
        v_color = a_color;
        gl_Position = vec4(a_instance.xy + k * a_instance.zw, 0.0, 1.0);
    }
    """
    static let fragmentSource = """
    precision mediump float;
    in vec4 v_color;
    in vec2 v_local;
    out vec4 color;
    void main() { color = v_color * (1.0 - smoothstep(0.8, 1.0, length(v_local))); }
    """

    public init(registry: ResourceRegistry) throws {
        self.registry = registry
        instances = DynamicVertexBuffer(registry: registry, label: "particle instances")
        program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
    }

    /// Draws particles (size = diameter in world units) into the bound framebuffer covering `metrics`.
    public func draw(_ particles: [ParticleInstance], camera: Camera2D, metrics: ViewMetrics) throws {
        lastInstanceCount = 0
        guard let toNDC = metrics.worldToNDC(camera: camera), !particles.isEmpty else { return }
        if program == nil || program!.generation != registry.generation {
            program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
        }
        let count = min(particles.count, ParticleSystem.maxCapacity)
        let hx = camera.zoom / metrics.size.x, hy = camera.zoom / metrics.size.y   // NDC per world unit of radius
        var data = [Float](repeating: 0, count: count * 8)
        for i in 0..<count {
            let p = particles[i]
            let c = toNDC.apply(p.position), a = p.color.w
            let r = max(0, p.size.isFinite ? p.size : 0)
            data.replaceSubrange(i * 8 ..< i * 8 + 8, with: [Float(c.x), Float(c.y), Float(r * hx), Float(r * hy),
                                                            Float(p.color.x * a), Float(p.color.y * a), Float(p.color.z * a), Float(a)])
        }
        try instances.upload(data)
        program?.use()
        vcAttribute(0, components: 4, strideFloats: 8, offsetFloats: 0, divisor: 1)
        vcAttribute(1, components: 4, strideFloats: 8, offsetFloats: 4, divisor: 1)
        vcglEnable(GLenum(GL_BLEND))
        vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        vcglDrawArraysInstanced(GLenum(GL_TRIANGLES), 0, 6, GLsizei(count))
        vcglDisable(GLenum(GL_BLEND))
        vcglVertexAttribDivisor(0, 0); vcglVertexAttribDivisor(1, 0)
        vcglDisableVertexAttribArray(0); vcglDisableVertexAttribArray(1)
        lastInstanceCount = count
    }

    public func release() {
        instances.release()
        if let program { registry.release(program) }
        program = nil
    }
}
