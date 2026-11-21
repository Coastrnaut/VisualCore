// WaveKnotKeeperShaders — feature 323 (R02-G03-03) T-R02G0303-003 (FR-R02G0303-001, FR-R02G0303-002; clarifications
// Q1, Q2, Q4; research R3). The two GLSL ES 3.00 programs of Wave Knot Keeper held as source text (data: the core issues
// no GL call), with the names of every uniform they declare, their vertex attributes and the CPU references the frame
// checks use.
//
// Rope program: the glasslike light rope, drawn on the closed parallel-transport tube of research R1 (world units, model
// identity, real normals). The fragment stage takes a fresnel term from the facing between the normal and the direction
// to the eye, mixes the glass body from sapphire (facing) toward pearl (grazing), adds a brighter pearl rim and an ember
// caustic pulse: `u_pulse` (the snapshot's 0.5 + 0.5 sin(2 pi 0.5 t), 0 ... 1, held at time 0 under Reduce Motion) times
// the vertex's crossing weight (`a_uv.x`, 1 near a crossing on the over-strand, 0 elsewhere; research R3) times the
// glow gain `u_gain` (bounded to `maxGain`; Reduce Flashing caps it lower on the CPU). A glow-shell pass reuses the same
// program with `u_shell` = 1 on a wider tube, drawn additively: a soft sapphire-to-ember falloff strongest where the
// shell faces the eye, scaled by the gain. Solid program: handles (pearl icospheres, ember when selected) and gates
// (translucent sapphire cubes) in one colour with a rim term from the facing toward the view direction and, for gates, a
// bright edge term from the position inside the box `u_boxCenter` +- `u_boxHalf` (mesh space). Output is premultiplied
// alpha. No texture samplers, no image assets and no loops.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0) and `a_normal` (location 1)
// interleaved from `Mesh.interleavedPositionNormal()`, `a_uv` (location 2) from `Mesh.uvs` in its own buffer (a constant
// (0, 0) when the mesh has none). The rope mesh carries its crossing weight in `a_uv.x` (`a_uv.y` is not read). Every
// source starts with `#version 300 es`, the only version line `ShaderLibrary` accepts, and states one float precision.

/// The GLSL ES 3.00 sources of Wave Knot Keeper's rope and solid programs, their uniform and attribute names and the
/// CPU references of what they compute.
public enum WaveKnotKeeperShaders {
    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes as (name, location), in location order: `a_position` (vec3, 0) and `a_normal` (vec3, 1)
    /// from `Mesh.interleavedPositionNormal()`, `a_uv` (vec2, 2) from `Mesh.uvs`, as `ShaderMeshRenderer` binds them.
    /// The rope program reads all three (`a_uv.x`: the crossing weight 0 ... 1); the solid program reads `a_position`
    /// and `a_normal`.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    /// The upper bound the rope shader applies to `u_gain` (the caustic and glow-shell gain).
    public static let maxGain = 2.0

    /// The gain the presenter passes normally.
    public static let standardGain = 1.0

    /// The gain cap under Reduce Flashing (the caustic pulse and the glow shells at half strength).
    public static let reducedFlashingGain = 0.5

    /// The exponent of the rope's fresnel term, (1 - facing)^3.
    public static let fresnelPower = 3.0

    /// The rope vertex shader. Uniforms: `u_mvp` (model-view-projection; the rope mesh is in world units, model identity)
    /// and `u_eye` (the eye position in world units). Passes the normal, the direction to the eye and the crossing weight.
    public static let ropeVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform vec3 u_eye;
    out vec3 v_normal;
    out vec3 v_toEye;
    out float v_weight;
    void main() {
        v_normal = a_normal;
        v_toEye = u_eye - a_position;
        v_weight = clamp(a_uv.x, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The rope fragment shader. Uniforms: `u_pulse` (the caustic pulse brightness 0 ... 1), `u_gain` (the caustic and
    /// glow gain, bounded to ``maxGain``), `u_shell` (0 for the glass core, 1 for an additive glow-shell pass),
    /// `u_opacity` (0 ... 1) and the palette `u_pearl`, `u_sapphire`, `u_ember` (RGB 0 ... 1). The fresnel term is
    /// ``fresnel(facing:)``, the caustic ``caustic(pulse:weight:gain:)``. The output is premultiplied RGBA with every
    /// component in 0 ... 1.
    public static let ropeFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_toEye;
    in float v_weight;
    uniform float u_pulse;
    uniform float u_gain;
    uniform float u_shell;
    uniform float u_opacity;
    uniform vec3 u_pearl;
    uniform vec3 u_sapphire;
    uniform vec3 u_ember;
    out vec4 color;
    void main() {
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 v = v_toEye / max(length(v_toEye), 0.0001);
        float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
        float fresnel = pow(1.0 - facing, 3.0);
        float gain = clamp(u_gain, 0.0, 2.0);
        float caustic = clamp(u_pulse, 0.0, 1.0) * clamp(v_weight, 0.0, 1.0) * gain;
        vec3 body = mix(u_sapphire, u_pearl, 0.35 + 0.65 * fresnel);
        vec3 rim = u_pearl * (0.45 * fresnel);
        vec3 core = clamp(body + rim + u_ember * caustic, 0.0, 1.0);
        float coreAlpha = 0.8 + 0.2 * fresnel;
        vec3 shellColor = clamp(mix(u_sapphire, u_ember, clamp(caustic, 0.0, 1.0)), 0.0, 1.0);
        float shellAlpha = clamp(0.2 * gain * facing * facing * (0.6 + 0.4 * clamp(caustic, 0.0, 1.0)), 0.0, 1.0);
        float isShell = step(0.5, u_shell);
        vec3 rgb = mix(core, shellColor, isShell);
        float alpha = clamp(u_opacity, 0.0, 1.0) * mix(coreAlpha, shellAlpha, isShell);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The solid vertex shader for handles and gates. Uniform: `u_mvp` (model-view-projection). The model part must be a
    /// translation and a uniform scale, so the normal passes through unchanged as the world-space normal; the mesh-space
    /// position is passed for the gate edge term.
    public static let solidVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    uniform mat4 u_mvp;
    out vec3 v_normal;
    out vec3 v_local;
    void main() {
        v_normal = a_normal;
        v_local = a_position;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The solid fragment shader. Uniforms: `u_color` (RGB 0 ... 1), `u_opacity` (0 ... 1; gates translucent), `u_rim`
    /// (0 ... 1, the rim emphasis), `u_viewDir` (world-space direction from the eye toward the target), `u_edge` (0 ... 1,
    /// the edge emphasis; 0 for handles, > 0 for gates), `u_boxCenter` and `u_boxHalf` (the gate box in mesh space). A
    /// surface facing the eye shows exactly ``solidColour(_:)``; the rim adds up to `0.6 * u_rim` of the colour where
    /// the surface turns away; near a box edge (the median of |p - c| / h above ``edgeStart``) the colour lifts toward
    /// white and the alpha toward 1.
    public static let solidFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_local;
    uniform vec3 u_color;
    uniform float u_opacity;
    uniform float u_rim;
    uniform vec3 u_viewDir;
    uniform float u_edge;
    uniform vec3 u_boxCenter;
    uniform vec3 u_boxHalf;
    out vec4 color;
    void main() {
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 d = u_viewDir / max(length(u_viewDir), 0.0001);
        float facing = clamp(abs(dot(n, d)), 0.0, 1.0);
        float rim = (1.0 - facing) * (1.0 - facing);
        vec3 body = clamp(u_color, 0.0, 1.0) * mix(0.7, 1.0, facing);
        vec3 q = abs(v_local - u_boxCenter) / max(abs(u_boxHalf), vec3(0.0001));
        float median = max(min(q.x, q.y), min(max(q.x, q.y), q.z));
        float edge = clamp(u_edge, 0.0, 1.0) * smoothstep(0.86, 0.98, median);
        vec3 shaded = clamp(body + u_color * (0.6 * clamp(u_rim, 0.0, 1.0) * rim), 0.0, 1.0);
        vec3 rgb = clamp(mix(shaded, vec3(1.0), 0.7 * edge), 0.0, 1.0);
        float opacity = clamp(u_opacity, 0.0, 1.0);
        float alpha = clamp(opacity + (1.0 - opacity) * 0.8 * edge, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The median of |p - c| / h from which the gate edge term starts (the solid shader's `smoothstep(0.86, 0.98, ...)`).
    public static let edgeStart = 0.86

    /// Every uniform the rope program declares, exactly as declared (vertex stage first).
    public static let ropeUniforms: [String] = [
        "u_mvp", "u_eye", "u_pulse", "u_gain", "u_shell", "u_opacity", "u_pearl", "u_sapphire", "u_ember",
    ]

    /// Every uniform the solid program declares, exactly as declared (vertex stage first).
    public static let solidUniforms: [String] = [
        "u_mvp", "u_color", "u_opacity", "u_rim", "u_viewDir", "u_edge", "u_boxCenter", "u_boxHalf",
    ]

    /// The uniform lists per program name (`rope`, `solid`).
    public static let uniformNames: [String: [String]] = ["rope": ropeUniforms, "solid": solidUniforms]

    /// The gain the presenter passes: ``standardGain``, or ``reducedFlashingGain`` under Reduce Flashing.
    public static func gain(reduceFlashing: Bool) -> Double {
        reduceFlashing ? reducedFlashingGain : standardGain
    }

    /// The rope's fresnel term for `facing` (|n . v|, clamped to 0 ... 1; non-finite counts as 1): (1 - facing)^3.
    public static func fresnel(facing: Double) -> Double {
        let f = facing.isFinite ? min(max(abs(facing), 0), 1) : 1
        return (1 - f) * (1 - f) * (1 - f)
    }

    /// The ember caustic strength the rope shader adds: pulse and weight clamped to 0 ... 1, gain to 0 ... ``maxGain``,
    /// multiplied (non-finite inputs count as 0).
    public static func caustic(pulse: Double, weight: Double, gain: Double) -> Double {
        func clamped(_ x: Double, _ upper: Double) -> Double { x.isFinite ? min(max(x, 0), upper) : 0 }
        return clamped(pulse, 1) * clamped(weight, 1) * clamped(gain, maxGain)
    }

    /// The colour a solid of `colour` shows where it faces the eye (no edge), as the solid fragment shader computes it at
    /// opacity 1: the colour clamped to 0 ... 1.
    public static func solidColour(_ colour: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3<Double>(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1))
    }
}
