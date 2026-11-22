// AmethystEscapeShaders — feature 363 (R02-G07-03) T-R02G0703-003 (FR-R02G0703-002, FR-R02G0703-003; clarifications
// on the palette, the tiers, Reduce Motion and Reduce Flashing). The two GLSL ES 3.00 programs of Amethyst Escape held
// as source text (data: the core issues no GL call), with the names of every uniform they declare, their vertex
// attributes, the constants the sources are built from and the CPU references of what they compute.
//
// Crystal program: the dark backdrop, the translucent amethyst wedge facets (alpha ``facetAlpha`` = 0.55), the platinum
// wall fins, marks, exit arrow and move bar, the dark blocked wedges and the amber failure marks. Mesh layout (data
// model, "Mesh streams"): `a_normal` is the surface normal, `a_uv.x` the material code (see `CrystalMaterial`: 0
// backdrop, 1 facet, 2 platinum, 3 blocked, 4 amber), `a_uv.y` the vertex shade 0 ... 1. Lighting is an ambient term
// plus Lambert from `u_lightDir`. Facets get up to ``maxHighlightLayers`` (3) shifting specular highlight layers: layer
// i is a highlight direction turning about the vertical axis at its own rate, driven by `u_time` (the only time
// source), and only the first `u_highlightLayers` layers (the tier's `highlightLayers`, clamped to 0 ... 3) count; the
// loop is bounded by the constant 3. `u_failure` (0 ... 1) mixes every colour toward amber by ``failureTint`` times it.
// Reduce Motion needs nothing here: the scene passes `u_time` = 0, so the highlights stand still.
//
// Glow program: the pearl, the exit glow and their glow shells, drawn with blending. The colour is carried in
// `a_normal` (the mesh builder writes an `AmethystEscapePalette` colour there), `a_uv.x` is the glow weight 0 ... 1 and
// `a_uv.y` is 0. The glow is the colour lifted toward the pearl white by ``coreLift`` and brightened by ``glowWeight``,
// both times the glow weight and the glow gain, which is `u_glowGain` capped by `u_glowLimit` (both clamped to
// ``maxGlowGain``); under Reduce Flashing the presenter passes ``glowGainCap`` as the limit. `u_shell` = 1 draws a glow
// shell (alpha ``shellWeight`` x gain x glow weight). The glow program has no time input: it never pulses.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1)
// from `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with
// `#version 300 es` (VisualCoreShaderSource's `ShaderLibrary.versionLine`) and states one float precision. Plain
// uniforms (at most 16 vec4 slots per program; the crystal program uses 8, the glow program 7), no texture samplers,
// no image assets, no `discard` and one loop, bounded by a constant. Output is premultiplied alpha. Palette constants
// are written with six fixed decimals from `AmethystEscapePalette`, so the shader colours equal the CPU's within 1/255.

import Foundation

/// The GLSL ES 3.00 sources of Amethyst Escape's crystal and glow programs, their uniform and attribute names, the
/// constants they are built from and the CPU references of what they compute (FR-R02G0703-002).
public enum AmethystEscapeShaders {
    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes as (name, location), in location order: `a_position` (vec3, 0) and `a_normal` (vec3, 1)
    /// from `Mesh.interleavedPositionNormal()`, `a_uv` (vec2, 2) from `Mesh.uvs`, as `ShaderMeshRenderer` binds them.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs).
    public static let mvpUniform = "u_mvp"
    /// `vec3`: the direction toward the light in model units (crystal; normalised by the shader).
    public static let lightDirectionUniform = "u_lightDir"
    /// `float`: presentation time in seconds, the only time source of the facet highlights (crystal); the scene passes
    /// 0 under Reduce Motion, so the highlights stand still.
    public static let timeUniform = "u_time"
    /// `float`: the tier's `highlightLayers`, clamped by the shader to 0 ... ``maxHighlightLayers`` (crystal).
    public static let highlightLayersUniform = "u_highlightLayers"
    /// `float`: the amber failure tint strength 0 ... 1 (crystal); 1 while the play shows a failure, 0 otherwise.
    public static let failureUniform = "u_failure"
    /// `float`: the glow gain (glow); see ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"
    /// `float`: 0 for the pearl and exit body, 1 for an additive glow-shell pass (glow).
    public static let shellUniform = "u_shell"

    /// Every uniform the crystal program declares, exactly as declared (vertex stage first).
    public static let crystalUniforms: [String] = [mvpUniform, lightDirectionUniform, timeUniform,
                                                   highlightLayersUniform, failureUniform]

    /// Every uniform the glow program declares, exactly as declared (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, shellUniform]

    /// The uniform lists per program name (`crystal`, `glow`).
    public static let uniformNames: [String: [String]] = ["crystal": crystalUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The dark backdrop, as written into the sources (`AmethystEscapePalette.backdrop`).
    public static let backdrop: SIMD3<Double> = AmethystEscapePalette.backdrop
    /// The translucent amethyst facets, as written into the sources (`AmethystEscapePalette.amethyst`).
    public static let amethyst: SIMD3<Double> = AmethystEscapePalette.amethyst
    /// The shifting facet highlights, as written into the sources (`AmethystEscapePalette.highlight`).
    public static let highlight: SIMD3<Double> = AmethystEscapePalette.highlight
    /// The platinum fins, marks, arrow and move bar, as written into the sources (`AmethystEscapePalette.platinum`).
    public static let platinum: SIMD3<Double> = AmethystEscapePalette.platinum
    /// The dark blocked wedges, as written into the sources (`AmethystEscapePalette.blocked`).
    public static let blocked: SIMD3<Double> = AmethystEscapePalette.blocked
    /// The pearl and the hot glow core, as written into the sources (`AmethystEscapePalette.pearl`).
    public static let pearl: SIMD3<Double> = AmethystEscapePalette.pearl
    /// The amber failure tint and marks, as written into the sources (`AmethystEscapePalette.amber`).
    public static let amber: SIMD3<Double> = AmethystEscapePalette.amber

    /// The alpha of a translucent amethyst facet (every other crystal material is opaque).
    public static let facetAlpha: Double = 0.55
    /// The crystal program's ambient term.
    public static let ambient: Double = 0.55
    /// The crystal program's Lambert weight (ambient + diffuse = 1).
    public static let diffuse: Double = 0.45
    /// The most specular highlight layers on a facet (the richest tier's `highlightLayers`; the loop bound).
    public static let maxHighlightLayers: Int = 3
    /// The specular exponent of a highlight layer.
    public static let shininess: Double = 24
    /// The weight of one highlight layer, times its specular term.
    public static let highlightWeight: Double = 0.35
    /// The turning rate of highlight layer 0 in radians per second; layer i turns at (i + 1) times it.
    public static let highlightSpeed: Double = 0.6
    /// The elevation (y component before normalising) of every highlight direction.
    public static let highlightElevation: Double = 1.2
    /// The highlight phase in radians per model unit along x + z (so neighbouring facets glint apart).
    public static let highlightSpatial: Double = 0.8
    /// How far `u_failure` = 1 mixes a crystal colour toward amber.
    public static let failureTint: Double = 0.35

    /// The emissive glow weight, times the glow gain and the glow weight of the vertex.
    public static let glowWeight: Double = 0.3
    /// How far the glow lifts a colour toward the pearl white, times the glow gain and the glow weight of the vertex.
    public static let coreLift: Double = 0.25
    /// The glow-shell alpha weight, times the glow gain and the glow weight.
    public static let shellWeight: Double = 0.35

    /// The upper bound (the glow gain cap) the glow shader clamps `u_glowGain` and `u_glowLimit` to.
    public static let maxGlowGain: Double = 1.5
    /// The glow gain the presenter passes at a tier with glow shells.
    public static let standardGlowGain: Double = 1.0
    /// The glow limit the presenter passes normally (no cap below ``maxGlowGain``).
    public static let standardGlowLimit: Double = 1.5
    /// The Reduce Flashing cap on the glow gain: the limit the presenter passes under Reduce Flashing, the glow at half
    /// strength (the shared limit Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` uses).
    public static let glowGainCap: Double = 0.5

    /// A crystal material code, written into `a_uv.x` of a crystal-program vertex.
    public enum CrystalMaterial: Int, Sendable, CaseIterable, Hashable {
        /// The dark backdrop (opaque).
        case backdrop = 0
        /// A translucent amethyst wedge facet (alpha ``AmethystEscapeShaders/facetAlpha``, with highlight layers).
        case facet = 1
        /// A platinum wall fin, mark, exit arrow or move bar segment (opaque).
        case platinum = 2
        /// A dark blocked wedge (opaque).
        case blocked = 3
        /// An amber failure mark (opaque).
        case amber = 4

        /// The `a_uv.x` value of the material.
        public var code: Double { Double(rawValue) }

        /// The material's colour as the crystal vertex shader selects it (before shade, light and highlights).
        public var colour: SIMD3<Double> {
            switch self {
            case .backdrop: AmethystEscapeShaders.backdrop
            case .facet: AmethystEscapeShaders.amethyst
            case .platinum: AmethystEscapeShaders.platinum
            case .blocked: AmethystEscapeShaders.blocked
            case .amber: AmethystEscapeShaders.amber
            }
        }

        /// The material's alpha: ``AmethystEscapeShaders/facetAlpha`` for a facet, 1 otherwise.
        public var alpha: Double { self == .facet ? AmethystEscapeShaders.facetAlpha : 1 }
    }

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The crystal vertex shader. Uniform: `u_mvp`. Selects the material colour from `a_uv.x`, scales it by the shade
    /// `a_uv.y` and passes the normal, the model position, the facet flag and the material alpha.
    public static let crystalVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_normal;
    out vec3 v_base;
    out vec3 v_position;
    out float v_isFacet;
    out float v_alpha;
    const vec3 AE_BACKDROP = \(vec3Literal(backdrop));
    const vec3 AE_AMETHYST = \(vec3Literal(amethyst));
    const vec3 AE_PLATINUM = \(vec3Literal(platinum));
    const vec3 AE_BLOCKED = \(vec3Literal(blocked));
    const vec3 AE_AMBER = \(vec3Literal(amber));
    const float AE_FACET_ALPHA = \(fixed(facetAlpha));
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 4.0);
        float isFacet = 1.0 - step(0.5, abs(m - 1.0));
        float isPlatinum = 1.0 - step(0.5, abs(m - 2.0));
        float isBlocked = 1.0 - step(0.5, abs(m - 3.0));
        float isAmber = 1.0 - step(0.5, abs(m - 4.0));
        vec3 base = mix(AE_BACKDROP, AE_AMETHYST, isFacet);
        base = mix(base, AE_PLATINUM, isPlatinum);
        base = mix(base, AE_BLOCKED, isBlocked);
        base = mix(base, AE_AMBER, isAmber);
        v_base = base * clamp(a_uv.y, 0.0, 1.0);
        v_normal = a_normal;
        v_position = a_position;
        v_isFacet = isFacet;
        v_alpha = mix(1.0, AE_FACET_ALPHA, isFacet);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The crystal fragment shader. Uniforms: `u_lightDir`, `u_time`, `u_highlightLayers`, `u_failure`. Ambient
    /// ``ambient`` plus Lambert ``diffuse`` (``crystalShade(base:normalDotLight:)``); on a facet the first
    /// `u_highlightLayers` of ``maxHighlightLayers`` shifting specular layers add highlight colour
    /// (``highlightDirection(layer:time:phase:)``); then the amber failure tint (``failureMix(colour:failure:)``).
    /// Premultiplied, alpha ``facetAlpha`` on a facet and 1 elsewhere.
    public static let crystalFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in vec3 v_position;
    in float v_isFacet;
    in float v_alpha;
    uniform vec3 u_lightDir;
    uniform float u_time;
    uniform float u_highlightLayers;
    uniform float u_failure;
    out vec4 color;
    const vec3 AE_HIGHLIGHT = \(vec3Literal(highlight));
    const vec3 AE_AMBER = \(vec3Literal(amber));
    const int AE_MAX_LAYERS = \(maxHighlightLayers);
    const float AE_AMBIENT = \(fixed(ambient));
    const float AE_DIFFUSE = \(fixed(diffuse));
    const float AE_SHININESS = \(fixed(shininess));
    const float AE_HIGHLIGHT_WEIGHT = \(fixed(highlightWeight));
    const float AE_HIGHLIGHT_SPEED = \(fixed(highlightSpeed));
    const float AE_HIGHLIGHT_ELEVATION = \(fixed(highlightElevation));
    const float AE_HIGHLIGHT_SPATIAL = \(fixed(highlightSpatial));
    const float AE_FAILURE_TINT = \(fixed(failureTint));
    void main() {
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 l = u_lightDir / max(length(u_lightDir), 0.0001);
        float lambert = max(dot(n, l), 0.0);
        vec3 rgb = clamp(v_base, 0.0, 1.0) * (AE_AMBIENT + AE_DIFFUSE * lambert);
        float layers = clamp(u_highlightLayers, 0.0, float(AE_MAX_LAYERS));
        float phase = AE_HIGHLIGHT_SPATIAL * (v_position.x + v_position.z);
        float sparkle = 0.0;
        for (int i = 0; i < AE_MAX_LAYERS; i++) {
            float on = 1.0 - step(layers, float(i));
            float angle = AE_HIGHLIGHT_SPEED * float(i + 1) * u_time + phase + 2.094395 * float(i);
            vec3 h = normalize(vec3(cos(angle), AE_HIGHLIGHT_ELEVATION, sin(angle)));
            sparkle += on * AE_HIGHLIGHT_WEIGHT * pow(max(dot(n, h), 0.0), AE_SHININESS);
        }
        rgb = rgb + AE_HIGHLIGHT * sparkle * step(0.5, v_isFacet);
        rgb = mix(clamp(rgb, 0.0, 1.0), AE_AMBER, AE_FAILURE_TINT * clamp(u_failure, 0.0, 1.0));
        float alpha = clamp(v_alpha, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`) and the glow weight (`a_uv.x`).
    public static let glowVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_colour;
    out float v_glow;
    void main() {
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_glow = clamp(a_uv.x, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`, `u_shell`. Glow ``glowGain(gain:limit:)``,
    /// colour ``glowColour(colour:glow:gain:)``, shell alpha ``shellWeight`` x gain x glow. Premultiplied RGBA in 0 ... 1.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_glow;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    uniform float u_shell;
    out vec4 color;
    const vec3 AE_PEARL = \(vec3Literal(pearl));
    const float AE_GLOW = \(fixed(glowWeight));
    const float AE_CORE = \(fixed(coreLift));
    const float AE_SHELL = \(fixed(shellWeight));
    const float AE_MAX_GAIN = \(fixed(maxGlowGain));
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, AE_MAX_GAIN), clamp(u_glowLimit, 0.0, AE_MAX_GAIN));
        vec3 lifted = mix(v_colour, AE_PEARL, clamp(AE_CORE * gain * v_glow, 0.0, 1.0));
        vec3 core = clamp(lifted * (1.0 + AE_GLOW * gain * v_glow), 0.0, 1.0);
        float isShell = step(0.5, u_shell);
        float shellAlpha = clamp(AE_SHELL * gain * v_glow, 0.0, 1.0);
        vec3 rgb = mix(core, v_colour, isShell);
        float alpha = mix(1.0, shellAlpha, isShell);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``standardGlowGain`` with glow shells, 0 without
    /// (level-2).
    public static func glowGain(for tier: AmethystEscapeTier) -> Double {
        tier.glowShells > 0 ? standardGlowGain : 0
    }

    /// The value the presenter passes as `u_highlightLayers` at `tier`: its `highlightLayers`, clamped to 0 ...
    /// ``maxHighlightLayers``.
    public static func highlightLayers(for tier: AmethystEscapeTier) -> Double {
        Double(min(max(tier.highlightLayers, 0), maxHighlightLayers))
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow body colour for a vertex `colour`, glow weight `glow` and the applied `gain`: the colour lifted toward
    /// the pearl white by ``coreLift`` gain glow, times 1 + ``glowWeight`` gain glow, every component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, glow: Double, gain: Double) -> SIMD3<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        let c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        let g: Double = unit(glow)
        let lift: Double = unit(coreLift * gain * g)
        let lifted: SIMD3<Double> = c + (pearl - c) * lift
        let scaled: SIMD3<Double> = lifted * (1 + glowWeight * gain * g)
        return SIMD3<Double>(unit(scaled.x), unit(scaled.y), unit(scaled.z))
    }

    /// The direction of highlight layer `layer` (0 ... ``maxHighlightLayers`` - 1) at `time` seconds and spatial
    /// `phase` radians, unit length: (cos a, ``highlightElevation``, sin a) normalised, a = ``highlightSpeed`` (layer +
    /// 1) time + phase + layer 2 pi / 3. At `time` 0 (Reduce Motion) it depends on the phase alone.
    public static func highlightDirection(layer: Int, time: Double, phase: Double) -> SIMD3<Double> {
        let t: Double = time.isFinite ? time : 0
        let p: Double = phase.isFinite ? phase : 0
        let i: Double = Double(layer)
        let angle: Double = highlightSpeed * (i + 1) * t + p + 2.094395 * i
        let v: SIMD3<Double> = SIMD3<Double>(cos(angle), highlightElevation, sin(angle))
        let length: Double = (v * v).sum().squareRoot()
        return v / length
    }

    /// The crystal colour for a material colour `base` (after shade) and n . l `normalDotLight`: base x (``ambient`` +
    /// ``diffuse`` max(n . l, 0)), every component in 0 ... 1.
    public static func crystalShade(base: SIMD3<Double>, normalDotLight: Double) -> SIMD3<Double> {
        func unit(_ x: Double) -> Double { min(max(x, 0), 1) }
        let b: SIMD3<Double> = SIMD3<Double>(unit(base.x), unit(base.y), unit(base.z))
        let lit: SIMD3<Double> = b * (ambient + diffuse * max(normalDotLight, 0))
        return SIMD3<Double>(unit(lit.x), unit(lit.y), unit(lit.z))
    }

    /// `colour` mixed toward amber by ``failureTint`` times `failure` (clamped to 0 ... 1; non-finite counts as 0).
    public static func failureMix(colour: SIMD3<Double>, failure: Double) -> SIMD3<Double> {
        let f: Double = failure.isFinite ? min(max(failure, 0), 1) : 0
        return colour + (amber - colour) * (failureTint * f)
    }
}
