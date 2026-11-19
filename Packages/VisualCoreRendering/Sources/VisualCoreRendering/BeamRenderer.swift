// BeamRenderer.swift — draws soft-glow beams and points as instanced eye-facing strips in one draw call (feature 209,
// R02-F09, T-R02F09-004; clarifications Q1–Q5; research R2–R4). Per beam the two end points, the width and a
// premultiplied colour are read at divisor 1 from one reused, growing buffer (as `ParticleRenderer`); the six strip
// corners come from gl_VertexID, so there is no per-vertex buffer.
//
// Strip construction, in view space (clarification Q2): with A and B the end points and M their midpoint, e is the unit
// vector from M toward the eye and Π the plane through M facing the eye (normal e). A and B are projected
// orthogonally onto Π (A', B'; M stays M). The strip lies in Π: along d = (B' − A') / |B' − A'| it runs from
// A' − d·(w/2) to B' + d·(w/2), and it is widened by w/2 on each side along s = d × e (perpendicular to d and to the
// view direction). A degenerate segment (|B' − A'| ≤ 10⁻⁵·w/2: zero length or seen end-on) uses an eye-facing square of
// side w centred on M. The fragment interpolates its point P on Π (perspective-correct, so P is the pixel centre's
// ray hit on Π), takes r = distance(P, segment A'B') / (w/2) and writes colour × falloff(r), with
// falloff(r) = exp(−4 r²) for r ≤ 1 and 0 beyond — `BeamProfile.coverage(point: P, a: A', b: B', width: w)`.
// Round ends and a soft glow come from that one formula; a point is the zero-length case.
//
// Blending: `.premultiplied` (ONE, ONE_MINUS_SRC_ALPHA) sorted back to front by the view-space z of the midpoint
// (`InstanceOrder.backToFront`, ties in submission order), or `.additive` (ONE, ONE) unsorted. Depth testing is on
// (the caller's depth function), depth writes are off and face culling is off (a strip can be wound either way); the
// previous enable flags, depth write mask, blend factors and blend equations are restored afterwards. Every refusal
// (`InstancingError`) is thrown before any GL call. GPU objects are rebuilt after a context recreation.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes

/// One beam from `a` to `b` in world space; a zero-length beam (`a == b`) is a round point.
public struct BeamInstance: Sendable, Equatable {
    /// First end point in world space; finite.
    public var a: Vec3
    /// Second end point in world space; finite.
    public var b: Vec3
    /// Full width in world units (the diameter of the round ends); finite and greater than 0.
    public var width: Double
    /// Premultiplied colour (RGBA 0…1) at the beam's centre line; finite.
    public var color: Vec4

    /// Creates a beam from `a` to `b` with full `width` and premultiplied `color`.
    public init(a: Vec3, b: Vec3, width: Double, color: Vec4) {
        self.a = a
        self.b = b
        self.width = width
        self.color = color
    }
}

/// How beams combine with what is already drawn.
public enum BeamBlend: Sendable {
    /// Premultiplied "over" (ONE, ONE_MINUS_SRC_ALPHA); the beams are sorted back to front by midpoint depth.
    case premultiplied
    /// Additive (ONE, ONE); the order does not change the result, so the beams are not sorted.
    case additive
}

/// Draws beams and points as instanced soft-glow strips with one draw call on the main thread; GPU objects are rebuilt
/// after a context recreation.
@MainActor
public final class BeamRenderer {
    /// The most beams one `draw` call accepts; a longer list is refused with `InstancingError.tooMany`.
    public static let maxBeams = 65_536
    /// Floats per beam in the instance buffer: a.xyz, width, b.xyz, padding, premultiplied RGBA.
    static let floatsPerBeam = 12

    let registry: ResourceRegistry
    private var program: ShaderProgram?
    private let instances: DynamicVertexBuffer
    /// Instanced draw calls issued since creation (tests prove "one draw call per list" with it).
    var drawCallCount = 0

    static let vertexSource = """
    layout(location = 0) in vec4 a_start;   // a.xyz (world), full width
    layout(location = 1) in vec4 a_end;     // b.xyz (world), unused
    layout(location = 2) in vec4 a_color;   // premultiplied
    uniform highp mat4 u_view;
    uniform highp mat4 u_projection;
    out highp vec3 v_point;
    flat out highp vec3 v_a;
    flat out highp vec3 v_b;
    flat out highp float v_half;
    flat out vec4 v_color;
    const vec2 corners[6] = vec2[6](vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(1.0, 1.0),
                                    vec2(-1.0, -1.0), vec2(1.0, 1.0), vec2(-1.0, 1.0));
    void main() {
        vec2 k = corners[gl_VertexID % 6];
        highp vec3 a = (u_view * vec4(a_start.xyz, 1.0)).xyz;
        highp vec3 b = (u_view * vec4(a_end.xyz, 1.0)).xyz;
        highp float h = 0.5 * a_start.w;
        highp vec3 m = 0.5 * (a + b);
        highp float lm = length(m);
        highp vec3 e = lm > 0.0 ? -m / lm : vec3(0.0, 0.0, 1.0);
        a -= e * dot(a - m, e);
        b -= e * dot(b - m, e);
        highp vec3 d = b - a;
        highp float len = length(d);
        highp vec3 axis;
        highp vec3 side;
        highp float halfLength;
        if (len > 1e-5 * h) {
            axis = d / len;
            side = normalize(cross(axis, e));
            halfLength = 0.5 * len + h;
        } else {
            highp vec3 up = abs(e.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
            side = normalize(cross(up, e));
            axis = cross(e, side);
            halfLength = h;
            a = m;
            b = m;
        }
        highp vec3 p = m + axis * (k.x * halfLength) + side * (k.y * h);
        v_point = p;
        v_a = a;
        v_b = b;
        v_half = h;
        v_color = a_color;
        gl_Position = u_projection * vec4(p, 1.0);
    }
    """
    static let fragmentSource = """
    precision highp float;
    in highp vec3 v_point;
    flat in highp vec3 v_a;
    flat in highp vec3 v_b;
    flat in highp float v_half;
    flat in vec4 v_color;
    out vec4 color;
    void main() {
        vec3 ab = v_b - v_a;
        float l2 = dot(ab, ab);
        float t = l2 > 0.0 ? clamp(dot(v_point - v_a, ab) / l2, 0.0, 1.0) : 0.0;
        float r = length(v_point - (v_a + t * ab)) / v_half;
        float f = r <= 1.0 ? exp(-4.0 * r * r) : 0.0;
        color = v_color * f;
    }
    """

    /// Creates the instance buffer and compiles the beam program.
    /// - Throws: shader errors from the registry.
    public init(registry: ResourceRegistry) throws {
        self.registry = registry
        instances = DynamicVertexBuffer(registry: registry, label: "beam instances")
        program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
    }

    /// Checks the list and flattens it to the instance buffer layout.
    /// - Throws: `InstancingError.tooMany` above `maxBeams`; for the first bad beam `.notFinite(index)` (an end point,
    ///   the width or a colour component not finite) or `.badWidth(index)` (a finite width ≤ 0).
    static func beamFloats(_ beams: [BeamInstance]) throws(InstancingError) -> [Float] {
        guard beams.count <= maxBeams else { throw .tooMany(count: beams.count, limit: maxBeams) }
        var data: [Float] = []
        data.reserveCapacity(beams.count * floatsPerBeam)
        for (i, beam) in beams.enumerated() {
            let c = beam.color
            guard beam.a.isFinite, beam.b.isFinite, beam.width.isFinite,
                  c.x.isFinite, c.y.isFinite, c.z.isFinite, c.w.isFinite else { throw .notFinite(index: i) }
            guard beam.width > 0 else { throw .badWidth(index: i) }
            data.append(contentsOf: [Float(beam.a.x), Float(beam.a.y), Float(beam.a.z), Float(beam.width),
                                     Float(beam.b.x), Float(beam.b.y), Float(beam.b.z), 0,
                                     Float(c.x), Float(c.y), Float(c.z), Float(c.w)])
        }
        return data
    }

    /// The drawing order for premultiplied blending: indices by ascending view-space z of each beam's midpoint
    /// (farthest first), ties in submission order (`InstanceOrder.backToFront`).
    static func backToFront(_ beams: [BeamInstance], view: Mat4) throws -> [Int] {
        try InstanceOrder.backToFront(depths: beams.map { (view * Vec4(($0.a + $0.b) * 0.5, 1)).z })
    }

    /// Draws every beam of `beams` with one instanced draw call through a camera given as `view` and `projection`
    /// matrices (GL clip space), combined with `blend`. Depth testing is on with depth writes off and culling off; the
    /// previous blend, depth-test, culling, depth-write and blend factor/equation state is restored on return. An empty
    /// list draws nothing and issues no GL call.
    /// - Throws: `InstancingError` (more than `maxBeams`, a non-finite value or a width ≤ 0) before any GL call;
    ///   registry errors when the GPU objects must be rebuilt after a context recreation.
    public func draw(_ beams: [BeamInstance], view: Mat4, projection: Mat4, blend: BeamBlend = .premultiplied) throws {
        var data = try Self.beamFloats(beams)   // refuse before any GL call
        guard !beams.isEmpty else { return }
        if blend == .premultiplied {
            let n = Self.floatsPerBeam, source = data
            for (slot, index) in try Self.backToFront(beams, view: view).enumerated() {
                data.replaceSubrange(slot * n ..< slot * n + n, with: source[index * n ..< index * n + n])
            }
        }
        if program == nil || program!.generation != registry.generation {
            program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
        }
        guard let program else { return }
        let saved = SavedState.capture()
        defer { saved.restore() }
        program.use()
        program.set("u_view", matrix4: view.floats)
        program.set("u_projection", matrix4: projection.floats)
        try instances.upload(data)   // leaves the instance buffer bound to GL_ARRAY_BUFFER
        vcAttribute(0, components: 4, strideFloats: Self.floatsPerBeam, offsetFloats: 0, divisor: 1)
        vcAttribute(1, components: 4, strideFloats: Self.floatsPerBeam, offsetFloats: 4, divisor: 1)
        vcAttribute(2, components: 4, strideFloats: Self.floatsPerBeam, offsetFloats: 8, divisor: 1)
        vcglEnable(GLenum(GL_BLEND))
        vcglBlendEquation(GLenum(GL_FUNC_ADD))
        switch blend {
        case .premultiplied: vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        case .additive: vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE))
        }
        vcglEnable(GLenum(GL_DEPTH_TEST))
        vcglDepthMask(GLboolean(GL_FALSE))
        vcglDisable(GLenum(GL_CULL_FACE))
        vcglDrawArraysInstanced(GLenum(GL_TRIANGLES), 0, 6, GLsizei(beams.count))
        drawCallCount += 1
        for index: GLuint in 0...2 {
            vcglVertexAttribDivisor(index, 0)
            vcglDisableVertexAttribArray(index)
        }
    }

    /// Releases the instance buffer and program back to the registry.
    public func release() {
        instances.release()
        if let program { registry.release(program) }
        program = nil
    }

    /// The GL state a beam draw changes, captured before and restored after it.
    private struct SavedState {
        var blend: Bool, depthTest: Bool, cull: Bool
        var depthWrite: GLboolean
        var factors: [GLint]
        var equations: [GLint]

        @MainActor
        static func capture() -> SavedState {
            func integer(_ name: Int32) -> GLint { var v: GLint = 0; vcglGetIntegerv(GLenum(name), &v); return v }
            var mask = GLboolean(GL_TRUE)
            vcglGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &mask)
            return SavedState(
                blend: vcglIsEnabled(GLenum(GL_BLEND)) == GLboolean(GL_TRUE),
                depthTest: vcglIsEnabled(GLenum(GL_DEPTH_TEST)) == GLboolean(GL_TRUE),
                cull: vcglIsEnabled(GLenum(GL_CULL_FACE)) == GLboolean(GL_TRUE),
                depthWrite: mask,
                factors: [GL_BLEND_SRC_RGB, GL_BLEND_DST_RGB, GL_BLEND_SRC_ALPHA, GL_BLEND_DST_ALPHA].map(integer),
                equations: [GL_BLEND_EQUATION, GL_BLEND_EQUATION_ALPHA].map(integer))   // GL_BLEND_EQUATION = GL_BLEND_EQUATION_RGB
        }

        @MainActor
        func restore() {
            func toggle(_ cap: Int32, _ on: Bool) { on ? vcglEnable(GLenum(cap)) : vcglDisable(GLenum(cap)) }
            vcglBlendFuncSeparate(GLenum(factors[0]), GLenum(factors[1]), GLenum(factors[2]), GLenum(factors[3]))
            vcglBlendEquationSeparate(GLenum(equations[0]), GLenum(equations[1]))
            vcglDepthMask(depthWrite)
            toggle(GL_BLEND, blend)
            toggle(GL_DEPTH_TEST, depthTest)
            toggle(GL_CULL_FACE, cull)
        }
    }
}
