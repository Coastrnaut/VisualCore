// LissajousLabyrinthShaders — feature 313 (R02-G02-03) T-R02G0203-003 (FR-R02G0203-001, FR-R02G0203-002; clarifications
// Q1, Q2, Q3; research R1, R3). The two GLSL ES 3.00 programs of Lissajous Labyrinth held as source text (data: the core
// issues no GL call), with the names of every uniform they declare, their vertex attributes and the CPU references the
// frame checks use.
//
// Thread program: the luminous harmonic curve, drawn from the camera-facing strip of research R1. Each vertex carries its
// lap fraction (0 ... 1, the sample's tick / 4,096) in `a_uv.x` and its side of the strip (-1 or +1) in `a_uv.y`. The
// fragment stage mixes cobalt toward violet around the lap (seamless at the lap's wrap), softens the edges from |side|
// like an ink line, fades with depth (the front of the scene is up to 15 % brighter than the back), adds a small interference shimmer sin(lap * k + time) (time held at 0 for Reduce Motion), brightens
// the trail behind the tracer head (wrap-around distance, uniforms only, no rebuild) with a copper tint near the head and,
// in a glow pass (`u_glow` > 0, additive), writes a wide soft falloff instead of the crisp core. Solid program: checkpoint
// rings, obstacle icospheres and the head disc in one colour, dimmed unless lit, with a rim term from the facing between
// the normal and the view direction (obstacles). Output is premultiplied alpha. No texture samplers, no image assets and
// no loops.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0) and `a_normal` (location 1)
// interleaved from `Mesh.interleavedPositionNormal()`, `a_uv` (location 2) from `Mesh.uvs` in its own buffer (a constant
// (0, 0) when the mesh has none). Every source starts with `#version 300 es`, the only version line `ShaderLibrary`
// accepts, and states one float precision.

/// The GLSL ES 3.00 sources of Lissajous Labyrinth's thread and solid programs, their uniform and attribute names and the
/// CPU references of what they compute.
public enum LissajousLabyrinthShaders {
    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes as (name, location), in location order: `a_position` (vec3, 0) and `a_normal` (vec3, 1)
    /// from `Mesh.interleavedPositionNormal()`, `a_uv` (vec2, 2) from `Mesh.uvs`, as `ShaderMeshRenderer` binds them.
    /// The thread program reads `a_position` and `a_uv` (x: lap fraction 0 ... 1, y: side -1 or +1); the solid program
    /// reads `a_position` and `a_normal`.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    /// The upper bound the thread shader applies to `u_glow` (Reduce Flashing caps it lower on the CPU).
    public static let maxGlow = 4.0

    /// The extra brightness of the thread at the front of the scene (depth fading, FR-R02G0203-002): the front of the
    /// bounding sphere is drawn at 1 + ``depthFadeGain`` of the colour, the back at 1, linearly in eye distance between
    /// them, so the back never drops below the colour the frame checks expect.
    public static let depthFadeGain = 0.15

    /// The thread's depth fade factor, as the thread vertex shader computes it: 1 + ``depthFadeGain`` at `near` or
    /// nearer, 1 at `far` or farther, linear between (a span under 0.0001 counts as 0.0001). Non-finite input gives 1.
    public static func depthFade(eyeDistance: Double, near: Double, far: Double) -> Double {
        guard eyeDistance.isFinite, near.isFinite, far.isFinite else { return 1 }
        let depth = min(max((eyeDistance - near) / max(far - near, 0.0001), 0), 1)
        return 1 + depthFadeGain * (1 - depth)
    }

    /// The share of its colour an unlit solid keeps (the solid shader's `mix(0.5, 1.0, u_lit)`).
    public static let solidDimShare = 0.5

    /// The thread vertex shader. Uniforms: `u_mvp` (model-view-projection), `u_fadeNear` and `u_fadeFar` (the eye
    /// distances of the bounding sphere's front and back, ``SceneGeometry.depthRange(aspect:snapshot:)``). Passes the lap
    /// fraction, the side and the depth fade of ``depthFade(eyeDistance:near:far:)`` (the eye distance is the clip w of a
    /// perspective projection).
    public static let threadVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_fadeNear;
    uniform float u_fadeFar;
    out float v_lap;
    out float v_side;
    out float v_fade;
    void main() {
        v_lap = a_uv.x;
        v_side = a_uv.y;
        gl_Position = u_mvp * vec4(a_position, 1.0);
        float span = max(u_fadeFar - u_fadeNear, 0.0001);
        float depth = clamp((gl_Position.w - u_fadeNear) / span, 0.0, 1.0);
        v_fade = mix(1.15, 1.0, depth);
    }
    """

    /// The thread fragment shader. Uniforms: `u_head` (the head's lap fraction, 0 ... 1), `u_trail` (the trail length as
    /// a lap fraction, tier trail / 4,096), `u_glow` (0 for the base pass, > 0 the additive glow strength, bounded to
    /// ``maxGlow``), `u_opacity` (0 ... 1), `u_time` (seconds of shimmer; 0 under Reduce Motion) and the palette
    /// `u_cobalt`, `u_violet`, `u_copper` (RGB 0 ... 1). The output is premultiplied RGBA with every component in 0 ... 1.
    public static let threadFragment = """
    #version 300 es
    precision highp float;
    in float v_lap;
    in float v_side;
    in float v_fade;
    uniform float u_head;
    uniform float u_trail;
    uniform float u_glow;
    uniform float u_opacity;
    uniform float u_time;
    uniform vec3 u_cobalt;
    uniform vec3 u_violet;
    uniform vec3 u_copper;
    out vec4 color;
    void main() {
        float lap = fract(v_lap);
        float side = clamp(abs(v_side), 0.0, 1.0);
        float hue = 0.5 - 0.5 * cos(lap * 6.2831853);
        vec3 base = mix(u_cobalt, u_violet, hue);
        float behind = fract(fract(u_head) - lap + 1.0);
        float trail = max(u_trail, 0.0001);
        float inTrail = 1.0 - smoothstep(0.0, trail, behind);
        float nearHead = 1.0 - smoothstep(0.0, trail * 0.15 + 0.002, behind);
        float shimmer = 0.06 * sin(lap * 6.2831853 * 24.0 + u_time * 1.5);
        vec3 lit = mix(base, u_copper, 0.75 * nearHead) * (0.8 + 0.35 * inTrail + shimmer);
        vec3 rgb = clamp((lit + u_violet * (0.15 * inTrail)) * clamp(v_fade, 1.0, 1.15), 0.0, 1.0);
        float glow = clamp(u_glow, 0.0, 4.0);
        float isGlow = step(0.0001, glow);
        float coreAlpha = 1.0 - smoothstep(0.55, 1.0, side);
        float falloff = (1.0 - side) * (1.0 - side);
        float glowAlpha = clamp(0.25 * glow * falloff * (0.35 + 0.65 * inTrail), 0.0, 1.0);
        float alpha = clamp(u_opacity, 0.0, 1.0) * mix(coreAlpha, glowAlpha, isGlow);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The solid vertex shader for checkpoint rings, obstacle icospheres and the head disc. Uniform: `u_mvp`
    /// (model-view-projection). The model part must be a translation and a uniform scale, so the normal passes through
    /// unchanged as the world-space normal.
    public static let solidVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    uniform mat4 u_mvp;
    out vec3 v_normal;
    void main() {
        v_normal = a_normal;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The solid fragment shader. Uniforms: `u_color` (RGB 0 ... 1), `u_lit` (0 ... 1; unlit keeps ``solidDimShare``),
    /// `u_opacity` (0 ... 1), `u_rim` (≥ 0, the rim emphasis; 0 for rings and the head, > 0 for obstacles) and
    /// `u_viewDir` (world-space direction from the eye toward the target). A surface facing the eye shows exactly
    /// ``solidColour(_:lit:)``; the rim adds up to `0.6 * u_rim` of the colour where the surface turns away.
    public static let solidFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    uniform vec3 u_color;
    uniform float u_lit;
    uniform float u_opacity;
    uniform float u_rim;
    uniform vec3 u_viewDir;
    out vec4 color;
    void main() {
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 d = u_viewDir / max(length(u_viewDir), 0.0001);
        float facing = abs(dot(n, d));
        float rim = (1.0 - facing) * (1.0 - facing);
        vec3 body = clamp(u_color, 0.0, 1.0) * mix(0.5, 1.0, clamp(u_lit, 0.0, 1.0));
        vec3 rgb = clamp(body + u_color * (0.6 * clamp(u_rim, 0.0, 1.0) * rim), 0.0, 1.0);
        float alpha = clamp(u_opacity, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// Every uniform the thread program declares, exactly as declared (vertex stage first).
    public static let threadUniforms: [String] = [
        "u_mvp", "u_fadeNear", "u_fadeFar", "u_head", "u_trail", "u_glow", "u_opacity", "u_time", "u_cobalt", "u_violet", "u_copper",
    ]

    /// Every uniform the solid program declares, exactly as declared (vertex stage first).
    public static let solidUniforms: [String] = ["u_mvp", "u_color", "u_lit", "u_opacity", "u_rim", "u_viewDir"]

    /// The uniform lists per program name (`thread`, `solid`).
    public static let uniformNames: [String: [String]] = ["thread": threadUniforms, "solid": solidUniforms]

    /// The head's lap fraction for `headTick` (wrapped into 0 ..< 4,096 ticks, negatives included), the `u_head` value.
    public static func headFraction(tick headTick: Int) -> Double {
        let n = LissajousLabyrinthLap.ticks
        return Double(((headTick % n) + n) % n) / Double(n)
    }

    /// The trail of `tier` as a lap fraction (trail ticks / 4,096), the `u_trail` value.
    public static func trailFraction(_ tier: LissajousLabyrinthTier) -> Double {
        Double(tier.trail) / Double(LissajousLabyrinthLap.ticks)
    }

    /// The colour a solid of `colour` shows where it faces the eye, as the solid fragment shader computes it at opacity
    /// 1: the colour clamped to 0 ... 1 when `lit`, else ``solidDimShare`` of it.
    public static func solidColour(_ colour: SIMD3<Double>, lit: Bool) -> SIMD3<Double> {
        let clamped = SIMD3<Double>(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1))
        return lit ? clamped : clamped * solidDimShare
    }
}
