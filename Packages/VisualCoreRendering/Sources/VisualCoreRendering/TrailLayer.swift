// TrailLayer.swift — decaying trail images on a ping-pong pair (feature 035 A04-P03 T-A04-304; gap G-BLENDTRAIL;
// FR-A04-302, FR-A04-303; research R1, R2). Each frame: fade the previous image (VisualCoreSimulation's TrailDecay
// model), draw new content on top, composite to the output with an optional brightness cap, swap. RGBA8 targets work
// on every GL ES 3.0 path; the longer edge is capped so memory stays bounded. Reusable by any trail or afterglow
// effect (A04 particles, A10 Neon Arcade, A21 Aurora).
import CVisualCoreGL
import VisualCoreSimulation

/// A fading trail image: `frame(delta:output:draw:)` decays the last image, lets the caller draw into it and
/// composites it to `output`. Main thread only, with the owning host's context current (inside scene callbacks).
@MainActor
public final class TrailLayer {
    /// The longest edge of the trail targets in pixels; larger requests are scaled down keeping the aspect ratio.
    public static let maxEdge = 2_048

    /// Target width in pixels (after the `maxEdge` cap).
    public let width: Int
    /// Target height in pixels (after the `maxEdge` cap).
    public let height: Int
    /// The fraction of brightness kept per 1/60 s, clamped to `TrailDecay.strengthRange` (0 clears every frame).
    public var strength: Double = 0 { didSet { strength = TrailDecay.clampedStrength(strength) } }
    /// The largest value any color channel may have in the composited output, 0…1 (default 1: no cap). Reduce
    /// Flashing uses it to bound trail and additive brightness.
    public var brightnessCap: Double = 1 {
        didSet { brightnessCap = brightnessCap.isFinite ? min(max(brightnessCap, 0), 1) : 1 }
    }

    /// The opaque color under the trail in the composite (straight RGB 0…1, default black): the trail image is
    /// premultiplied, so the output is `trail.rgb + background × (1 − trail.a)`, then capped.
    public var background: SIMD3<Float> = .zero

    private var pair: PingPongTarget?
    private var decay: FieldPass?
    private var composite: FieldPass?

    static let decaySource = """
    precision highp float;
    uniform sampler2D uPrev;
    uniform float uFactor;
    uniform float uSubtract;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = max(texture(uPrev, v_uv) * uFactor - vec4(uSubtract / 255.0), vec4(0.0)); }
    """

    static let compositeSource = """
    precision highp float;
    uniform sampler2D uTrail;
    uniform float uCap;
    uniform vec4 uBackground;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec4 t = texture(uTrail, v_uv);
        color = vec4(min(t.rgb + uBackground.rgb * (1.0 - t.a), vec3(uCap)), 1.0);
    }
    """

    /// The target size for a drawable of `width` × `height`: the longer edge scaled down to `maxEdge`, each edge ≥ 1;
    /// nil for a non-positive size.
    public static func fittedSize(width: Int, height: Int) -> (width: Int, height: Int)? {
        guard width > 0, height > 0 else { return nil }
        let longer = max(width, height)
        guard longer > maxEdge else { return (width, height) }
        let k = Double(maxEdge) / Double(longer)
        return (max(1, Int((Double(width) * k).rounded())), max(1, Int((Double(height) * k).rounded())))
    }

    /// Creates cleared RGBA8 targets fitted to `width` × `height` and the two passes; throws for a non-positive size,
    /// a budget or allocation failure, or a shader error (everything created so far is released first).
    public init(registry: ResourceRegistry, width: Int, height: Int) throws {
        guard let size = Self.fittedSize(width: width, height: height) else {
            throw RenderHostError.allocation("trail layer size \(width)×\(height)", 0)
        }
        self.width = size.width
        self.height = size.height
        let pair = try PingPongTarget(registry: registry, width: size.width, height: size.height, format: .rgba8, label: "trail")
        do {
            decay = try FieldPass(registry: registry, fragment: Self.decaySource, inputs: ["uPrev"], label: "trail.decay")
            composite = try FieldPass(registry: registry, fragment: Self.compositeSource, inputs: ["uTrail"], label: "trail.composite")
        } catch {
            decay?.release()
            pair.release()
            throw error
        }
        self.pair = pair
        clear()
    }

    /// True while the targets exist and belong to the current context.
    public var isValid: Bool { pair?.isValid ?? false }

    /// The latest composited trail image (the target drawn last), for diagnostics and tests; nil after `release()`.
    public var image: RenderTarget? { pair?.read }

    /// Erases the trail: both targets become transparent black.
    public func clear() {
        guard let pair, pair.isValid else { return }
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        vcglClearColor(0, 0, 0, 0)
        for target in [pair.read, pair.write] {
            target.bind()
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        }
    }

    /// One frame of `delta` seconds: fade the previous image, call `draw` with the target bound (viewport set to its
    /// size) so new content lands on top, composite the result to `output` with `brightnessCap`, then swap. Throws if
    /// the layer was released or belongs to a lost context, or if a pass fails.
    public func frame(delta: Double, output: FieldPass.Output, draw: (RenderTarget) throws -> Void) throws {
        guard let pair, pair.isValid, let decay, let composite else { throw RenderHostError.contextLost }
        try decay.run(output: .target(pair.write), inputs: ["uPrev": pair.read],
                      uniforms: ["uFactor": .float(Float(TrailDecay.factor(strength: strength, delta: delta))),
                                 "uSubtract": .float(Float(TrailDecay.subtraction(delta: delta)))])
        pair.write.bind()
        vcglViewport(0, 0, GLsizei(width), GLsizei(height))
        try draw(pair.write)
        try composite.run(output: output, inputs: ["uTrail": pair.write], uniforms: ["uCap": .float(Float(brightnessCap)),
                                                                                        "uBackground": .vec4(SIMD4(background, 1))])
        pair.swap()
    }

    /// Releases both targets and passes (idempotent).
    public func release() {
        decay?.release(); decay = nil
        composite?.release(); composite = nil
        pair?.release(); pair = nil
    }
}
