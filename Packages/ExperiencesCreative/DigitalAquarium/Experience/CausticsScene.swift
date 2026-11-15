// CausticsScene — feature 071 (A09-P04) T-A09-405 (FR-A09-404, FR-A09-411; clarification Q3; research D3). The water,
// the gravel band and a slowly rippling caustic light pattern drawn by one full-screen fragment shader through
// VisualCore's `FullScreenShaderScene` (the host's context and registry; no context of its own), built from inline
// source with the VisualCore includes (`ShaderBundle(files: [:])`), as Fractal Explorer builds its scene.
//
// Mapping (the presenter's): the 16 × 9 tank (habitat units, y up) is scaled uniformly by `u_scale` pixels per unit
// and centred, so its bottom-left corner lies at the pixel (`u_originX`, `u_originY`) of `gl_FragCoord` (origin
// bottom-left, y up, like the presenter's world). A fragment's tank point is (`gl_FragCoord.xy` − origin) / scale.
//   - Outside the tank (the letterbox): the lit water colour.
//   - Inside: the lit gravel colour below `u_gravelTop` (y 1), the lit water colour above, plus the additive caustic
//     brightness `u_strength × pow(c, 3)`. `c = clamp(1 − 2 |a − b|, 0, 1)` where `a` and `b` are two layers of smooth
//     value noise over the tank point whose lattice wraps in x — `a` at one cell per unit (lattice period 16), `b` at
//     two cells per unit (lattice period 32) — so both, and the pattern, repeat every 16 units in x: seamless across
//     the tank width. The layers drift in opposite directions with `u_time`; drifting along x keeps the wrap.
//   - In the water the caustic fades out with height (full at the gravel top × 0.6, gone above y 8.5) so the water's
//     top band keeps the plain lit water colour the frame probe expects.
// Time: `step / 60 × 0.4` (Reduce Motion: 0, so the pattern holds; pausing holds the step and with it the pattern).
// Strength: 0.04, 0.07 and 0.10 for dim, soft and bright lighting (soft for an unknown level). When the shader cannot
// be prepared, `errorMessage` is set by the inner scene and `isAvailable` is false; the presenter then falls back to
// the Phase 03 clear colour and gravel rectangle.
// Feature 072 (A09-P05) T-A09-506 (FR-A09-511, FR-A09-520; research D3, D4): `u_octaves` (from the drawing budget) is
// 2 for both noise layers (as before) or 1 for the first layer only (`b` held at 0.5, so `c = 1 − 2 |a − 0.5|`); at 0
// the presenter does not draw this scene at all (the plain fallback). `configure(…, brightness:)` multiplies the water
// and gravel colours and the caustic strength by the ambient dimmer's brightness (1 = unchanged).
import VisualCoreMath
import VisualCoreRendering

/// The aquarium's water, gravel and caustic light pattern as one full-screen shader.
@MainActor
final class CausticsScene: RenderScene {
    /// The fragment's name in diagnostics.
    static let fragmentName = "aquarium-caustics.frag"
    /// The caustic strength of the lighting levels dim, soft and bright.
    nonisolated static let strengths = [0.04, 0.07, 0.10]
    /// Pattern time per second of aquarium time.
    nonisolated static let timeRate = 0.4
    /// The period of the pattern in tank x, in habitat units (the tank width).
    nonisolated static let period = 16.0

    /// The fragment shader (GLSL ES 3.00, see the file header).
    static let fragment = """
    precision highp float;
    in vec2 v_uv;
    uniform float u_time;
    uniform float u_scale;
    uniform float u_originX;
    uniform float u_originY;
    uniform float u_tankWidth;
    uniform float u_tankHeight;
    uniform float u_gravelTop;
    uniform float u_strength;
    uniform float u_waterR;
    uniform float u_waterG;
    uniform float u_waterB;
    uniform float u_gravelR;
    uniform float u_gravelG;
    uniform float u_gravelB;
    uniform float u_octaves;
    out vec4 color;

    float cellHash(vec2 c) {
        return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
    }

    // Smooth value noise whose lattice repeats every `period` cells in x.
    float periodicNoise(vec2 p, float period) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        float x0 = mod(i.x, period);
        float x1 = mod(i.x + 1.0, period);
        float a = cellHash(vec2(x0, i.y));
        float b = cellHash(vec2(x1, i.y));
        float c = cellHash(vec2(x0, i.y + 1.0));
        float d = cellHash(vec2(x1, i.y + 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    void main() {
        vec3 water = vec3(u_waterR, u_waterG, u_waterB);
        vec3 gravel = vec3(u_gravelR, u_gravelG, u_gravelB);
        vec2 tank = (gl_FragCoord.xy - vec2(u_originX, u_originY)) / max(u_scale, 1e-4);
        if (tank.x < 0.0 || tank.x > u_tankWidth || tank.y < 0.0 || tank.y > u_tankHeight) {
            color = vec4(water, 1.0);
            return;
        }
        float t = u_time;
        float a = periodicNoise(vec2(tank.x + 0.9 * t, 1.3 * tank.y - 0.4 * t), 16.0);
        float b = u_octaves >= 1.5
            ? periodicNoise(vec2(2.0 * tank.x - 1.3 * t, 2.0 * tank.y + 0.7 * t), 32.0)
            : 0.5;
        float c = clamp(1.0 - 2.0 * abs(a - b), 0.0, 1.0);
        bool onGravel = tank.y < u_gravelTop;
        float fade = onGravel ? 1.0 : 0.6 * (1.0 - smoothstep(u_gravelTop, u_tankHeight - 0.5, tank.y));
        vec3 base = onGravel ? gravel : water;
        color = vec4(min(base + vec3(u_strength * pow(c, 3.0) * fade), vec3(1.0)), 1.0);
    }
    """

    /// The full-screen scene that runs the fragment.
    let inner: FullScreenShaderScene
    /// Whether `setup` ran (and `teardown` did not run since).
    private(set) var isSetUp = false

    /// A scene running ``fragment``, or `fragmentOverride` when given (tests inject a broken source to prove the
    /// fallback).
    init(fragmentOverride: String? = nil) {
        inner = FullScreenShaderScene(fragment: fragmentOverride ?? Self.fragment, fragmentName: Self.fragmentName,
                                      bundle: ShaderBundle(files: [:]))
    }

    /// The shader's first compile or link diagnostic, or nil.
    var errorMessage: String? { inner.errorMessage }

    /// Whether the pattern can be drawn: set up, and the shader built without a diagnostic.
    var isAvailable: Bool { isSetUp && inner.errorMessage == nil }

    /// The pattern time of the last ``configure``.
    var time: Double { inner.fixedTime ?? 0 }

    /// The caustic strength of the last ``configure`` (after the brightness).
    var strength: Double { inner.parameters["strength"] ?? 0 }

    /// The octaves of the last ``configure`` (1 or 2).
    var octaves: Int { Int(inner.parameters["octaves"] ?? 2) }

    /// The caustic strength of lighting `level`: 0.04 dim, 0.07 soft, 0.10 bright (soft for an unknown level).
    nonisolated static func strength(lighting level: Int) -> Double {
        strengths.indices.contains(level) ? strengths[level] : strengths[1]
    }

    /// The pattern time at `step`: step / 60 × 0.4, or 0 with Reduce Motion (the pattern holds).
    nonisolated static func time(step: Int, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : Double(step) / 60 * timeRate
    }

    /// Sets what the next frame draws.
    /// - Parameters:
    ///   - step: The aquarium's step count (the pattern's clock).
    ///   - reduceMotion: Whether the pattern holds still.
    ///   - lighting: The lighting level (the strength).
    ///   - water: The lit water colour.
    ///   - gravel: The lit gravel colour.
    ///   - scale: Pixels per habitat unit.
    ///   - origin: The pixel of the tank's bottom-left corner (y up).
    ///   - tankSize: The tank's width and height in habitat units.
    ///   - gravelTop: The top of the gravel band in habitat units.
    ///   - octaves: The noise layers: 2 both (default), 1 the first only (clamped to 1…2).
    ///   - brightness: The ambient dimmer's colour scale applied to the water, the gravel and the strength (default 1).
    func configure(step: Int, reduceMotion: Bool, lighting: Int, water: Vec4, gravel: Vec4, scale: Double,
                   origin: Vec2, tankSize: Vec2, gravelTop: Double, octaves: Int = 2, brightness: Double = 1) {
        inner.fixedTime = Self.time(step: step, reduceMotion: reduceMotion)
        let b = brightness
        inner.parameters = [
            "scale": scale, "originX": origin.x, "originY": origin.y,
            "tankWidth": tankSize.x, "tankHeight": tankSize.y, "gravelTop": gravelTop,
            "strength": Self.strength(lighting: lighting) * b,
            "waterR": water.x * b, "waterG": water.y * b, "waterB": water.z * b,
            "gravelR": gravel.x * b, "gravelG": gravel.y * b, "gravelB": gravel.z * b,
            "octaves": Double(min(max(octaves, 1), 2)),
        ]
    }

    func setup(_ context: RenderContext) throws {
        try inner.setup(context)
        isSetUp = true
    }

    func resize(_ context: RenderContext) { inner.resize(context) }

    func render(_ context: RenderContext, frame: FrameInfo) throws { try inner.render(context, frame: frame) }

    func teardown(_ context: RenderContext) {
        inner.teardown(context)
        isSetUp = false
    }
}
