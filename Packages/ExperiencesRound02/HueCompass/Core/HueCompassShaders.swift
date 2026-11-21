// HueCompassShaders — feature 333 (R02-G04-03) T-R02G0403-003 (FR-R02G0403-001, FR-R02G0403-002; clarifications Q1,
// Q3, Q4). The two GLSL ES 3.00 programs of Hue Compass held as source text (data: the core issues no GL call), with the
// names of every uniform they declare, their vertex attributes, the constants the sources are built from and the CPU
// references the frame checks use.
//
// Glass program: the faceted glass needle and the probe (pearl), selection (ember) and target (sapphire) marks, drawn
// with real normals. `u_model` places the mesh in the world (a rotation, a translation and a uniform scale: the needle
// turns by it) and `u_mvp` is projection x view x model. The fragment stage takes a fresnel term (1 - facing)^3 from the
// facing between the world normal and the direction to the eye `u_eye`, shades the base colour `u_color` brighter where
// it faces the eye, adds a rim lifted toward white and an emissive glow: the base colour times the glow gain, which is
// `u_gain` capped by the Reduce-Flashing limit `u_gainLimit` (both bounded to `maxGain`). A glow-shell pass reuses the
// program with `u_shell` = 1 on a wider mesh, drawn additively: a soft falloff of the base colour strongest where the
// shell faces the eye, scaled by the capped gain.
//
// Solid program: unlit emissive geometry for the ticks, the band wheel, the glyphs and the fog. The geometry is unlit, so
// `a_normal` carries the vertex's RGB colour (0 ... 1), not a normal. With `u_fog` = 0, `a_uv.x` is a band code: 0 keeps
// the vertex colour (ticks, glyphs), k in 1 ... 24 colours the vertex with band k - 1 by `hcBand`, the same HSV rule and
// constants as `HueCompassPalette.band`. With `u_fog` = 1 (the fog mesh), `a_uv.x` is the brightness (density / 9,
// luminance only: it scales the alpha of the vertex colour) and `a_uv.y` the drift phase (0 ... 1); the vertex moves
// along z by `fogDriftAmplitude` sin(2 pi (`fogDriftHertz` `u_time` + phase)). Reduce Motion is `u_time` held at 0 by
// the presenter. Output of both programs is premultiplied alpha. No texture samplers, no image assets and no loops.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0) and `a_normal` (location 1)
// interleaved from `Mesh.interleavedPositionNormal()`, `a_uv` (location 2) from `Mesh.uvs` in its own buffer (a constant
// (0, 0) when the mesh has none). Every source starts with `#version 300 es`, the only version line `ShaderLibrary`
// accepts, and states one float precision.

import Foundation

/// The GLSL ES 3.00 sources of Hue Compass's glass and solid programs, their uniform and attribute names, the constants
/// they are built from and the CPU references of what they compute.
public enum HueCompassShaders {
    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes as (name, location), in location order: `a_position` (vec3, 0) and `a_normal` (vec3, 1)
    /// from `Mesh.interleavedPositionNormal()`, `a_uv` (vec2, 2) from `Mesh.uvs`, as `ShaderMeshRenderer` binds them.
    /// The glass program reads `a_position` and `a_normal` (a real normal); the solid program reads all three
    /// (`a_normal`: the vertex colour; `a_uv`: band code or fog brightness, and fog drift phase).
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    /// The number of hue bands the GLSL band rule divides the hue circle into (`HueCompassWheel.bands`).
    public static let bandCount: Int = HueCompassWheel.bands

    /// The saturation of every band colour in the GLSL band rule (`HueCompassPalette.bandSaturation`).
    public static let bandSaturation: Double = HueCompassPalette.bandSaturation

    /// The value of every band colour in the GLSL band rule (`HueCompassPalette.bandValue`).
    public static let bandValue: Double = HueCompassPalette.bandValue

    /// The upper bound the glass shader applies to `u_gain` and `u_gainLimit`.
    public static let maxGain: Double = 2.0

    /// The glow gain the presenter passes.
    public static let standardGain: Double = 1.0

    /// The gain limit the presenter passes normally (no cap below ``maxGain``).
    public static let standardGainLimit: Double = 2.0

    /// The gain limit under Reduce Flashing (the glow at half strength).
    public static let reducedFlashingGainLimit: Double = 0.5

    /// The exponent of the glass fresnel term, (1 - facing)^3.
    public static let fresnelPower: Double = 3.0

    /// The amplitude of the fog drift along z, in world units.
    public static let fogDriftAmplitude: Double = 0.01

    /// The frequency of the fog drift, in hertz (one cycle in ten seconds).
    public static let fogDriftHertz: Double = 0.1

    /// The GLSL band rule shared with ``solidVertex``: the constants `HC_BANDS`, `HC_SATURATION`, `HC_VALUE` (from
    /// ``bandCount``, ``bandSaturation``, ``bandValue``) and `vec3 hcBand(int band)`, hue band / 24, by the standard
    /// HSV-to-RGB rule of `HueCompassPalette.band` (a negative band counts as 0; larger bands wrap modulo 24).
    public static let bandFunction = """
    const float HC_BANDS = \(Double(bandCount));
    const float HC_SATURATION = \(bandSaturation);
    const float HC_VALUE = \(bandValue);
    vec3 hcBand(int band) {
        int n = max(band, 0);
        int b = n - (n / \(bandCount)) * \(bandCount);
        float h = float(b) / HC_BANDS * 6.0;
        float sector = floor(h);
        float f = h - sector;
        float v = HC_VALUE;
        float p = v * (1.0 - HC_SATURATION);
        float q = v * (1.0 - HC_SATURATION * f);
        float t = v * (1.0 - HC_SATURATION * (1.0 - f));
        int s = int(sector);
        if (s == 0) { return vec3(v, t, p); }
        if (s == 1) { return vec3(q, v, p); }
        if (s == 2) { return vec3(p, v, t); }
        if (s == 3) { return vec3(p, q, v); }
        if (s == 4) { return vec3(t, p, v); }
        return vec3(v, p, q);
    }
    """

    /// The glass vertex shader. Uniforms: `u_mvp` (projection x view x model), `u_model` (model to world: rotation,
    /// translation and uniform scale) and `u_eye` (the eye position in world units). Passes the world normal and the
    /// direction to the eye.
    public static let glassVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    uniform mat4 u_mvp;
    uniform mat4 u_model;
    uniform vec3 u_eye;
    out vec3 v_normal;
    out vec3 v_toEye;
    void main() {
        vec4 world = u_model * vec4(a_position, 1.0);
        v_normal = mat3(u_model) * a_normal;
        v_toEye = u_eye - world.xyz;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glass fragment shader. Uniforms: `u_color` (the base colour, RGB 0 ... 1: pearl for the needle and probe
    /// marks, ember for the selection, sapphire for the target), `u_opacity` (0 ... 1), `u_gain` (the glow gain) and
    /// `u_gainLimit` (the Reduce-Flashing cap), both bounded to ``maxGain``, and `u_shell` (0 for the glass body, 1 for
    /// an additive glow-shell pass). The fresnel term is ``fresnel(facing:)``, the gain ``glowGain(gain:limit:)``. The
    /// output is premultiplied RGBA with every component in 0 ... 1.
    public static let glassFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_toEye;
    uniform vec3 u_color;
    uniform float u_opacity;
    uniform float u_gain;
    uniform float u_gainLimit;
    uniform float u_shell;
    out vec4 color;
    void main() {
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 v = v_toEye / max(length(v_toEye), 0.0001);
        float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
        float fresnel = pow(1.0 - facing, \(fresnelPower));
        float gain = min(clamp(u_gain, 0.0, \(maxGain)), clamp(u_gainLimit, 0.0, \(maxGain)));
        vec3 base = clamp(u_color, 0.0, 1.0);
        vec3 body = base * (0.55 + 0.45 * facing);
        vec3 rim = mix(base, vec3(1.0), 0.5) * (0.6 * fresnel);
        vec3 glow = base * (0.25 * gain);
        vec3 core = clamp(body + rim + glow, 0.0, 1.0);
        float coreAlpha = 0.75 + 0.25 * fresnel;
        float shellAlpha = clamp(0.25 * gain * facing * facing, 0.0, 1.0);
        float isShell = step(0.5, u_shell);
        vec3 rgb = mix(core, base, isShell);
        float alpha = clamp(u_opacity, 0.0, 1.0) * mix(coreAlpha, shellAlpha, isShell);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The solid vertex shader. Uniforms: `u_mvp` (projection x view x model), `u_time` (presentation time in seconds;
    /// the presenter holds it at 0 under Reduce Motion) and `u_fog` (0 for ticks, wheel and glyphs; 1 for the fog
    /// mesh). Computes the vertex colour (the vertex colour in `a_normal`, or band `a_uv.x - 1` by `hcBand` when
    /// `a_uv.x` >= 0.5 outside fog) and the alpha factor (1, or the fog brightness `a_uv.x`), and moves fog vertices by
    /// ``fogDrift(time:phase:)`` with phase `a_uv.y`.
    public static let solidVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_time;
    uniform float u_fog;
    out vec3 v_color;
    out float v_alpha;
    \(bandFunction)
    void main() {
        float isFog = step(0.5, u_fog);
        float code = a_uv.x;
        float isBand = (1.0 - isFog) * step(0.5, code);
        int band = int(floor(code + 0.5)) - 1;
        v_color = mix(clamp(a_normal, 0.0, 1.0), hcBand(band), isBand);
        v_alpha = mix(1.0, clamp(code, 0.0, 1.0), isFog);
        float drift = \(fogDriftAmplitude) * sin(6.283185307179586 * (\(fogDriftHertz) * u_time + a_uv.y));
        vec3 p = a_position + vec3(0.0, 0.0, isFog * drift);
        gl_Position = u_mvp * vec4(p, 1.0);
    }
    """

    /// The solid fragment shader. Uniform: `u_opacity` (0 ... 1; 1 for ticks, wheel and glyphs, the fog's translucency
    /// for the fog). Emits the vertex colour unlit, premultiplied by `u_opacity` times the alpha factor (see
    /// ``fogAlpha(brightness:opacity:)``).
    public static let solidFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_color;
    in float v_alpha;
    uniform float u_opacity;
    out vec4 color;
    void main() {
        vec3 rgb = clamp(v_color, 0.0, 1.0);
        float alpha = clamp(u_opacity, 0.0, 1.0) * clamp(v_alpha, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// Every uniform the glass program declares, exactly as declared (vertex stage first).
    public static let glassUniforms: [String] = [
        "u_mvp", "u_model", "u_eye", "u_color", "u_opacity", "u_gain", "u_gainLimit", "u_shell",
    ]

    /// Every uniform the solid program declares, exactly as declared (vertex stage first).
    public static let solidUniforms: [String] = ["u_mvp", "u_time", "u_fog", "u_opacity"]

    /// The uniform lists per program name (`glass`, `solid`).
    public static let uniformNames: [String: [String]] = ["glass": glassUniforms, "solid": solidUniforms]

    /// The gain limit the presenter passes as `u_gainLimit`: ``standardGainLimit``, or ``reducedFlashingGainLimit``
    /// under Reduce Flashing.
    public static func gainLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? reducedFlashingGainLimit : standardGainLimit
    }

    /// The glow gain the glass shader applies: `gain` and `limit` each clamped to 0 ... ``maxGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glass fresnel term for `facing` (|n . v|, clamped to 0 ... 1; non-finite counts as 1): (1 - facing)^3.
    public static func fresnel(facing: Double) -> Double {
        let f: Double = facing.isFinite ? min(max(abs(facing), 0), 1) : 1
        return (1 - f) * (1 - f) * (1 - f)
    }

    /// The z offset the solid vertex shader gives a fog vertex of drift `phase` at `time` seconds:
    /// ``fogDriftAmplitude`` sin(2 pi (``fogDriftHertz`` time + phase)); 0 for a non-finite input.
    public static func fogDrift(time: Double, phase: Double) -> Double {
        guard time.isFinite, phase.isFinite else { return 0 }
        return fogDriftAmplitude * sin(2 * Double.pi * (fogDriftHertz * time + phase))
    }

    /// The alpha of a fog fragment of `brightness` (density / 9) at `opacity`, both clamped to 0 ... 1 (non-finite
    /// counts as 0): their product. The premultiplied colour is the vertex colour times this alpha.
    public static func fogAlpha(brightness: Double, opacity: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        return clamped(brightness) * clamped(opacity)
    }

    /// The `a_uv.x` band code of band `band` (taken modulo 24) for the solid program: band + 1.
    public static func bandCode(_ band: Int) -> Double {
        Double(((band % bandCount) + bandCount) % bandCount + 1)
    }
}
