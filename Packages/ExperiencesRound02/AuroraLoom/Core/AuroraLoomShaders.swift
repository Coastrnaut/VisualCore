// AuroraLoomShaders — feature 303 (R02-G01-03) T-R02G0103-004 (FR-R02G0103-002; clarifications Q1, Q3, Q4; research R5).
// The two GLSL ES 3.00 programs of Aurora Loom held as source text (data: the core issues no GL call), with the names of
// every uniform they declare, their vertex attributes and the palette colours of the unlit fallback.
//
// Ribbon program: the vertex stage displaces each vertex of a `Mesh.ribbon` sheet along its normal by a small travelling
// wave (amplitude by layer; amplitude 0 or a held phase gives a still sheet for Reduce Motion) and passes the across
// coordinate u (0 ... 1), the along coordinate v (arc length), the layer share and the normal. The fragment stage shades
// a bevel from u (bright edges, darker core), adds an interference shimmer from two travelling sinusoids of v, mixes the
// ribbon's base colour toward its highlight colour, dims the sheet unless its gates are matched (`u_lit`), adds an
// emissive term scaled by the glow gain (the caller caps it for Reduce Flashing; the shader bounds it to 0 ... 4) and
// writes premultiplied alpha with the layer opacity. Gate program: rings and target markers in one colour, dimmed to
// ``AuroraLoomShaders/gateDimShare`` unless lit. No texture samplers, no image assets and no loops.
//
// Attributes follow the shared mesh upload: `Mesh.interleavedPositionNormal()` (VisualCoreScenes, 6 floats per vertex)
// feeds `a_position` at location 0 and `a_normal` at location 1, as in VisualCoreRendering's `MeshRenderer` and
// `InstancedMeshRenderer`; the ribbon's `Mesh.uvs` go in their own buffer as `a_uv` at location 2 (the slot
// `MeshRenderer` gives its own per-vertex stream). Every source starts with `#version 300 es`, the only version line
// `ShaderLibrary` (VisualCoreShaderSource, `ShaderLibrary.versionLine`) accepts, and states a float precision.

/// The GLSL ES 3.00 sources of Aurora Loom's ribbon and gate programs, their uniform and attribute names and the palette
/// colours of the unlit fallback.
public enum AuroraLoomShaders {
    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes of both programs as (name, location), in location order: `a_position` (vec3, 0) and
    /// `a_normal` (vec3, 1) from `Mesh.interleavedPositionNormal()`, `a_uv` (vec2, 2) from `Mesh.uvs`. The gate program
    /// reads only `a_position`.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    /// The share of its colour a gate ring or marker keeps while unlit (the shader's `mix(0.45, 1.0, u_lit)`).
    public static let gateDimShare = 0.45

    /// The upper bound the ribbon shader applies to `u_glowGain` (Reduce Flashing caps it lower on the CPU).
    public static let maxGlowGain = 4.0

    /// The ribbon vertex shader. Uniforms: `u_mvp` (model-view-projection), `u_model` (model, for the normal),
    /// `u_wavePhase` (radians; held still for Reduce Motion), `u_waveAmplitude` (scene units, ≥ 0; 0 for no
    /// displacement) and `u_layer` (the layer's depth share, 0 ... 1).
    public static let ribbonVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform mat4 u_model;
    uniform float u_wavePhase;
    uniform float u_waveAmplitude;
    uniform float u_layer;
    out vec2 v_uv;
    out vec3 v_normal;
    out float v_layer;
    void main() {
        float wave = sin(a_uv.y * 6.2831853 * 1.5 - u_wavePhase + u_layer * 1.7) * (0.6 + 0.4 * sin(a_uv.x * 3.1415927));
        vec3 displaced = a_position + a_normal * (u_waveAmplitude * wave);
        v_uv = a_uv;
        v_normal = mat3(u_model) * a_normal;
        v_layer = u_layer;
        gl_Position = u_mvp * vec4(displaced, 1.0);
    }
    """

    /// The ribbon fragment shader. Uniforms: `u_baseColor` and `u_highlightColor` (RGB 0 ... 1, the ribbon's palette
    /// colour and its highlight), `u_shimmerPhase` (radians; held still for Reduce Motion), `u_lit` (0 ... 1, whether
    /// the ribbon's gates are matched), `u_glowGain` (≥ 0, bounded to ``maxGlowGain``) and `u_opacity` (the layer
    /// opacity, 0 ... 1). The output is premultiplied RGBA with every component in 0 ... 1.
    public static let ribbonFragment = """
    #version 300 es
    precision mediump float;
    in highp vec2 v_uv;
    in vec3 v_normal;
    in float v_layer;
    uniform vec3 u_baseColor;
    uniform vec3 u_highlightColor;
    uniform highp float u_shimmerPhase;
    uniform float u_lit;
    uniform float u_glowGain;
    uniform float u_opacity;
    out vec4 color;
    void main() {
        float edge = abs(v_uv.x * 2.0 - 1.0);
        float bevel = smoothstep(0.55, 1.0, edge);
        float core = 0.85 + 0.15 * bevel;
        highp float a = sin(v_uv.y * 6.2831853 * 3.0 - u_shimmerPhase);
        highp float b = sin(v_uv.y * 6.2831853 * 5.0 + u_shimmerPhase * 1.3 + v_layer * 2.0);
        float shimmer = 0.5 + 0.25 * a + 0.25 * b;
        float lit = clamp(u_lit, 0.0, 1.0);
        float facing = 0.9 + 0.1 * abs(normalize(v_normal).y);
        vec3 base = mix(u_baseColor, u_highlightColor, clamp(0.6 * bevel + 0.25 * shimmer * lit, 0.0, 1.0));
        vec3 diffuse = base * core * facing * mix(0.9, 1.0, lit);
        float glow = clamp(u_glowGain, 0.0, 4.0);
        vec3 emissive = u_highlightColor * glow * (0.15 * bevel + 0.1 * shimmer) * lit;
        vec3 rgb = clamp(diffuse + emissive, 0.0, 1.0);
        float alpha = clamp(u_opacity, 0.0, 1.0) * (0.85 + 0.15 * bevel);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The gate vertex shader for rings and markers. Uniforms: `u_mvp` (model-view-projection) and `u_pointSize`
    /// (pixels, for markers drawn as points).
    public static let gateVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    uniform mat4 u_mvp;
    uniform float u_pointSize;
    void main() {
        gl_PointSize = max(u_pointSize, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The gate fragment shader. Uniforms: `u_color` (RGB 0 ... 1), `u_lit` (0 ... 1; unlit keeps
    /// ``gateDimShare`` of the colour) and `u_opacity` (0 ... 1). The output is premultiplied RGBA.
    public static let gateFragment = """
    #version 300 es
    precision mediump float;
    uniform vec3 u_color;
    uniform float u_lit;
    uniform float u_opacity;
    out vec4 color;
    void main() {
        float alpha = clamp(u_opacity, 0.0, 1.0);
        vec3 rgb = clamp(u_color, 0.0, 1.0) * mix(0.45, 1.0, clamp(u_lit, 0.0, 1.0));
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// Every uniform the ribbon program declares, exactly as declared (vertex stage first).
    public static let ribbonUniforms: [String] = [
        "u_mvp", "u_model", "u_wavePhase", "u_waveAmplitude", "u_layer",
        "u_baseColor", "u_highlightColor", "u_shimmerPhase", "u_lit", "u_glowGain", "u_opacity",
    ]

    /// Every uniform the gate program declares, exactly as declared (vertex stage first).
    public static let gateUniforms: [String] = ["u_mvp", "u_pointSize", "u_color", "u_lit", "u_opacity"]

    /// The palette colour of `ribbon` for the unlit fallback (teal, magenta, gold; any index wraps modulo 3, negative
    /// indices included).
    public static func fallbackColour(ribbon: Int) -> SIMD3<Double> {
        let colours = AuroraLoomPalette.ribbons
        let n = colours.count
        return colours[((ribbon % n) + n) % n]
    }

    /// The colour a gate ring or marker of `colour` shows, as the gate fragment shader computes it at opacity 1:
    /// the colour clamped to 0 ... 1 when `lit`, else ``gateDimShare`` of it.
    public static func gateColour(_ colour: SIMD3<Double>, lit: Bool) -> SIMD3<Double> {
        let clamped = SIMD3<Double>(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1))
        return lit ? clamped : clamped * gateDimShare
    }
}
