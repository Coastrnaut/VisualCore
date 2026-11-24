// VoxelOrigamiShaders — feature 443 (R02-G15-03) T-R02G1503-003 (FR-R02G1503-001, 002, 004; clarifications Q1–Q5).
// The two GLSL ES 3.00 programs of Voxel Origami held as source text (data: the core issues no GL call), with the names
// of every uniform they declare, their vertex attributes, the material codes shared with `VoxelOrigamiSceneGeometry`,
// the constants the sources are built from and the CPU references of what they compute. Presentation only: no rule is
// ever evaluated on these values, and nothing drawn is consulted by the rules.
//
// Voxel program: the night backdrop, the turquoise target wireframe edges, the frosted-ivory cube faces and their
// chamfer bevels, the inner glyphs (solid on a target cell, hollow ring otherwise), the dots naming a cube, the grey
// hinge bars and the chosen hinge's hot-pink striped bar, the covered pips, the moves bars and the broken outline.
// Vertex streams (the geometry states the same contract): `a_uv.x` is the material code (``Material``, raw values
// 0 … 13 in declaration order) and `a_uv.y` the local coordinate d, whose meaning ``Material/localCoordinate`` states
// per material: on a strip (target edges, bevels, hollow glyph rings, hinge bars, unlit pips, broken outline) d is -1
// on one long side and +1 on the other; on a fan (cube faces, solid glyphs, dots, lit pips, moves bars: one centre
// vertex and the outline's corners) d is 0 at the centre and 1 on every outline vertex; along the chosen hinge's bar
// d runs from -1 at one end to +1 at the other; on the backdrop d is 0. `a_normal` is the face normal in world space:
// the voxel program lights the cube faces and bevels with it (faceted Lambert shading); every other material is
// emissive at its palette colour, so the colour cues hold whatever normal the geometry writes.
//
// Signed-distance shading from d: the soft outline coverage 1 - smoothstep(1 - ``edgeFeather``, 1, |d|)
// (``edgeCoverage(local:)``) on every mark (strips and fans); the solid materials (backdrop, cube face, bevel) are
// opaque. A cube face is frosted: the ivory darkens toward the shade colour near its outline by ``frostEdge`` times
// smoothstep(``frostStart``, 1, |d|); a bevel strip runs from the shade colour on its sides to a sheen toward the
// ivory along its ridge, ``bevelSheen`` (1 - |d|); both are then lit by ``ambient`` + ``diffuse`` max(n · l, 0) with l
// ``lightDirection`` (``cubeShade(material:normal:local:)``). The chosen hinge's bar carries ``stripeCount`` hot-pink
// stripes along it, each ``stripeDuty`` of its period and centred in it, with the hinge grey between them, so the
// bar's centre is pink (``stripeCoverage(local:)``). A won level (`u_won`, 0 … 1) flares the target wireframe toward
// the target-glow colour by ``flareLift`` times `u_won` (``targetColour(won:)``) at every tier.
//
// Glow program: the glow shells around the lit cubes and the target outline, drawn additively and last. The colour is
// carried in `a_normal` (a zero colour falls back to the glow colour on a cube shell and to the target-glow colour on
// a target shell), `a_uv.x` is 2 · kind + factor (``GlowKind``: 0 cube, 1 target; factor the glow factor 0 … 1;
// ``GlowKind/code(factor:)``) and `a_uv.y` the shell's radial coordinate r, 0 on its inner edge and 1 on its outer
// edge. The alpha is ``glowWeight`` times the gain, the factor and the fade (1 - r)²; a target shell's factor is also
// times ``targetRest`` on a level not won, rising to 1 with `u_won`, so the target outline flares on a won level; the
// gain is `u_glowGain` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter
// passes ``glowGainCap`` as the limit, so no glow, the won flare included, exceeds the cap. No program has a time input.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1) and
// `a_uv` (location 2). Every source starts with `#version 300 es` and states one float precision. Plain uniforms in the
// default block (at most 16 vec4 slots per program; the voxel program uses 5: u_mvp 4, u_won 1; the glow program 7:
// u_mvp 4, u_glowGain, u_glowLimit and u_won 1 each), no texture samplers, no image assets, no `discard` and no loops.
// Output is premultiplied alpha. Palette constants are written with six fixed decimals from `VoxelOrigamiPalette`, so
// the shader colours equal the CPU's within 1e-6.

import Foundation

/// The GLSL ES 3.00 sources of Voxel Origami's voxel and glow programs, their uniform and attribute names, the material
/// codes, the constants they are built from and the CPU references of what they compute (FR-R02G1503-001, 002, 004).
public enum VoxelOrigamiShaders {
    /// A voxel-program material code, written into `a_uv.x` of a voxel vertex (shared with
    /// `VoxelOrigamiSceneGeometry`; raw values 0 … 13 in declaration order).
    public enum Material: Float, Sendable, CaseIterable, Hashable {
        /// The night backdrop quad (d = 0; opaque).
        case backdrop = 0
        /// An edge of a target cell's wireframe cube (strip); flared toward the target glow on a won level.
        case targetEdge = 1
        /// A cube face (fan; opaque): frosted ivory, darkening toward its outline, lit from its normal.
        case cubeFace = 2
        /// A chamfer bevel strip between two faces (strip; opaque): shade colour with a sheen along its ridge, lit
        /// from its normal (level-0 and level-1 only).
        case cubeBevel = 3
        /// The solid inner glyph of a cube on a target cell (fan).
        case glyphSolid = 4
        /// The hollow inner glyph ring of a cube off the target (strip).
        case glyphHollow = 5
        /// A dot naming a cube, (index mod 6) + 1 per cube on its +z face (fan disc).
        case dots = 6
        /// A hinge bar (strip across its width).
        case hinge = 7
        /// The chosen hinge's bar: hot-pink stripes on the hinge grey (d along the bar, -1 at one end, +1 at the other).
        case hingeChosen = 8
        /// A lit covered pip, a covered target cell (fan).
        case coveredLit = 9
        /// An unlit covered pip: an outlined square (strip).
        case coveredUnlit = 10
        /// A lit moves bar, an action left (fan).
        case movesLit = 11
        /// An unlit moves bar, an action spent (fan).
        case movesUnlit = 12
        /// The outline of what a failure names: the moving cube, the cube in its way and their cell (strip).
        case broken = 13

        /// How the geometry fills `a_uv.y` for a material.
        public enum LocalCoordinate: Sendable, Hashable {
            /// No edge: d = 0 everywhere.
            case none
            /// A fan from a centre vertex (d = 0) to the outline's corners (d = 1).
            case fan
            /// A strip or ring: d = -1 on one long side, +1 on the other.
            case strip
            /// Along a bar: d = -1 at one end, +1 at the other (the chosen hinge's stripes).
            case along
        }

        /// The `a_uv.x` value of the material.
        public var code: Float { rawValue }

        /// The material's colour as the voxel vertex shader selects it (the target edge unflared, before the face
        /// frost, bevel sheen, lighting and stripes of the fragment shader).
        public var colour: SIMD3<Double> {
            switch self {
            case .backdrop: VoxelOrigamiPalette.night
            case .targetEdge: VoxelOrigamiPalette.target
            case .cubeFace: VoxelOrigamiPalette.ivory
            case .cubeBevel: VoxelOrigamiPalette.ivoryShade
            case .glyphSolid: VoxelOrigamiPalette.glyphSolid
            case .glyphHollow: VoxelOrigamiPalette.glyphHollow
            case .dots: VoxelOrigamiPalette.dots
            case .hinge: VoxelOrigamiPalette.hinge
            case .hingeChosen: VoxelOrigamiPalette.hingeChosen
            case .coveredLit: VoxelOrigamiPalette.coveredLit
            case .coveredUnlit: VoxelOrigamiPalette.coveredUnlit
            case .movesLit: VoxelOrigamiPalette.movesLit
            case .movesUnlit: VoxelOrigamiPalette.movesUnlit
            case .broken: VoxelOrigamiPalette.broken
            }
        }

        /// Whether the material is opaque over its whole area (no soft outline): the backdrop, the cube faces and the
        /// bevels, so a cube shows no seam between its faces.
        public var isSolid: Bool {
            switch self {
            case .backdrop, .cubeFace, .cubeBevel: true
            default: false
            }
        }

        /// Whether the fragment shader lights the material from its normal (the cube faces and bevels).
        public var isLit: Bool { self == .cubeFace || self == .cubeBevel }

        /// How the geometry fills `a_uv.y` for the material.
        public var localCoordinate: LocalCoordinate {
            switch self {
            case .backdrop: .none
            case .hingeChosen: .along
            case .cubeFace, .glyphSolid, .dots, .coveredLit, .movesLit, .movesUnlit: .fan
            case .targetEdge, .cubeBevel, .glyphHollow, .hinge, .coveredUnlit, .broken: .strip
            }
        }
    }

    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around a lit cube (a zero colour counts as the glow colour).
        case cube = 0
        /// A glow shell around the target outline (a zero colour counts as the target-glow colour); its factor is also
        /// times ``VoxelOrigamiShaders/targetRest`` on a level not won, rising to 1 with `u_won`.
        case target = 1

        /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts
        /// as 0).
        public func code(factor: Double) -> Double {
            let f: Double = factor.isFinite ? min(max(factor, 0), 1) : 0
            return Double(2 * rawValue) + f
        }

        /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 1, factor
        /// x - 2 · kind clamped to 0 … 1 (x clamped to 0 … 3; non-finite counts as 0).
        public static func decode(_ x: Double) -> (kind: GlowKind, factor: Double) {
            let v: Double = x.isFinite ? min(max(x, 0), 3) : 0
            let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 1)
            let factor: Double = min(max(v - Double(2 * k), 0), 1)
            return (kind: GlowKind(rawValue: k) ?? .cube, factor: factor)
        }
    }

    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes as (name, location), in location order: `a_position` (vec3, 0), `a_normal` (vec3, 1) and
    /// `a_uv` (vec2, 2), as `ShaderMeshRenderer` binds them.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs, vertex stage).
    public static let mvpUniform = "u_mvp"
    /// `float`: the won level's light, 0 … 1 (voxel vertex stage: flares the target wireframe toward the target-glow
    /// colour; glow fragment stage: raises the target shells' factor to 1); 0 on a level not won.
    public static let wonUniform = "u_won"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the voxel program declares, each once, in order of declaration (vertex stage first).
    public static let voxelUniforms: [String] = [mvpUniform, wonUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform]

    /// The uniform lists per program name (`voxel`, `glow`).
    public static let uniformNames: [String: [String]] = ["voxel": voxelUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette colour.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "VO_NIGHT", colour: VoxelOrigamiPalette.night),
        (name: "VO_IVORY", colour: VoxelOrigamiPalette.ivory),
        (name: "VO_IVORY_SHADE", colour: VoxelOrigamiPalette.ivoryShade),
        (name: "VO_TARGET", colour: VoxelOrigamiPalette.target),
        (name: "VO_TARGET_GLOW", colour: VoxelOrigamiPalette.targetGlow),
        (name: "VO_HINGE", colour: VoxelOrigamiPalette.hinge),
        (name: "VO_HINGE_CHOSEN", colour: VoxelOrigamiPalette.hingeChosen),
        (name: "VO_GLYPH_SOLID", colour: VoxelOrigamiPalette.glyphSolid),
        (name: "VO_GLYPH_HOLLOW", colour: VoxelOrigamiPalette.glyphHollow),
        (name: "VO_DOTS", colour: VoxelOrigamiPalette.dots),
        (name: "VO_COVERED_LIT", colour: VoxelOrigamiPalette.coveredLit),
        (name: "VO_COVERED_UNLIT", colour: VoxelOrigamiPalette.coveredUnlit),
        (name: "VO_MOVES_LIT", colour: VoxelOrigamiPalette.movesLit),
        (name: "VO_MOVES_UNLIT", colour: VoxelOrigamiPalette.movesUnlit),
        (name: "VO_BROKEN", colour: VoxelOrigamiPalette.broken),
        (name: "VO_GLOW", colour: VoxelOrigamiPalette.glow),
    ]

    /// The unit direction toward the key light in world space (y up), as written into the voxel fragment shader.
    public static let lightDirection: SIMD3<Double> = {
        let raw: SIMD3<Double> = SIMD3<Double>(0.35, 0.8, 0.5)
        let length: Double = (raw * raw).sum().squareRoot()
        return raw / length
    }()

    /// The width of the soft outline as a share of the local coordinate: coverage falls from 1 at |d| = 1 - feather to
    /// 0 at |d| = 1.
    public static let edgeFeather: Double = 0.15
    /// Where a cube face's frost begins, as |d| from its centre (0) to its outline (1).
    public static let frostStart: Double = 0.7
    /// How far a cube face's frost darkens the ivory toward the shade colour at its outline.
    public static let frostEdge: Double = 0.6
    /// How far a bevel's ridge (1 - |d|) lifts the shade colour toward the ivory.
    public static let bevelSheen: Double = 0.5
    /// The ambient share of the faceted lighting of the cube faces and bevels.
    public static let ambient: Double = 0.55
    /// The diffuse share of the faceted lighting: the light is ``ambient`` + diffuse · max(n · l, 0), at most 1.
    public static let diffuse: Double = 0.45
    /// The hot-pink stripes along the chosen hinge's bar.
    public static let stripeCount: Double = 5
    /// The share of a stripe period that is hot pink, centred in the period (the rest is the hinge grey).
    public static let stripeDuty: Double = 0.6
    /// How far a won level flares the target wireframe toward the target-glow colour, times `u_won`.
    public static let flareLift: Double = 0.7

    /// The alpha weight of the glow, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// The share of a target shell's factor shown on a level not won (it rises to 1 with `u_won`).
    public static let targetRest: Double = 0.4
    /// The upper bound the glow shader clamps `u_glowGain` and `u_glowLimit` to.
    public static let maxGlowGain: Double = 1.5
    /// The glow gain per glow shell the presenter passes (level-0: 2 shells, level-1: 1), plus ``glowGainBase``.
    public static let glowGainPerShell: Double = 0.5
    /// The glow gain base added to ``glowGainPerShell`` times the shells at a tier with glow shells.
    public static let glowGainBase: Double = 0.5
    /// The glow limit the presenter passes normally (no cap below ``maxGlowGain``).
    public static let standardGlowLimit: Double = 1.5
    /// The Reduce Flashing cap on the glow gain: the limit the presenter passes under Reduce Flashing (the shared
    /// limit 0.5 of the round-two games).
    public static let glowGainCap: Double = 0.5

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The voxel vertex shader. Uniforms: `u_mvp`, `u_won`. Selects the material colour from `a_uv.x` (the target edge
    /// flared toward the target-glow colour by ``flareLift`` times `u_won`); passes the normal, the material code and
    /// the local coordinate to the fragment stage.
    public static let voxelVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_won;
    out vec3 v_base;
    out vec3 v_normal;
    out float v_material;
    out float v_local;
    const vec3 VO_NIGHT = \(vec3Literal(VoxelOrigamiPalette.night));
    const vec3 VO_TARGET = \(vec3Literal(VoxelOrigamiPalette.target));
    const vec3 VO_TARGET_GLOW = \(vec3Literal(VoxelOrigamiPalette.targetGlow));
    const vec3 VO_IVORY = \(vec3Literal(VoxelOrigamiPalette.ivory));
    const vec3 VO_IVORY_SHADE = \(vec3Literal(VoxelOrigamiPalette.ivoryShade));
    const vec3 VO_GLYPH_SOLID = \(vec3Literal(VoxelOrigamiPalette.glyphSolid));
    const vec3 VO_GLYPH_HOLLOW = \(vec3Literal(VoxelOrigamiPalette.glyphHollow));
    const vec3 VO_DOTS = \(vec3Literal(VoxelOrigamiPalette.dots));
    const vec3 VO_HINGE = \(vec3Literal(VoxelOrigamiPalette.hinge));
    const vec3 VO_HINGE_CHOSEN = \(vec3Literal(VoxelOrigamiPalette.hingeChosen));
    const vec3 VO_COVERED_LIT = \(vec3Literal(VoxelOrigamiPalette.coveredLit));
    const vec3 VO_COVERED_UNLIT = \(vec3Literal(VoxelOrigamiPalette.coveredUnlit));
    const vec3 VO_MOVES_LIT = \(vec3Literal(VoxelOrigamiPalette.movesLit));
    const vec3 VO_MOVES_UNLIT = \(vec3Literal(VoxelOrigamiPalette.movesUnlit));
    const vec3 VO_BROKEN = \(vec3Literal(VoxelOrigamiPalette.broken));
    const float VO_FLARE_LIFT = \(fixed(flareLift));
    const float VO_MAX_MATERIAL = \(fixed(Double(Material.allCases.count - 1)));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, VO_MAX_MATERIAL);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 base = mix(VO_NIGHT, mix(VO_TARGET, VO_TARGET_GLOW, VO_FLARE_LIFT * won), isCode(m, 1.0));
        base = mix(base, VO_IVORY, isCode(m, 2.0));
        base = mix(base, VO_IVORY_SHADE, isCode(m, 3.0));
        base = mix(base, VO_GLYPH_SOLID, isCode(m, 4.0));
        base = mix(base, VO_GLYPH_HOLLOW, isCode(m, 5.0));
        base = mix(base, VO_DOTS, isCode(m, 6.0));
        base = mix(base, VO_HINGE, isCode(m, 7.0));
        base = mix(base, VO_HINGE_CHOSEN, isCode(m, 8.0));
        base = mix(base, VO_COVERED_LIT, isCode(m, 9.0));
        base = mix(base, VO_COVERED_UNLIT, isCode(m, 10.0));
        base = mix(base, VO_MOVES_LIT, isCode(m, 11.0));
        base = mix(base, VO_MOVES_UNLIT, isCode(m, 12.0));
        base = mix(base, VO_BROKEN, isCode(m, 13.0));
        float plain = isCode(m, 0.0);
        v_base = base;
        v_normal = a_normal;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0) * (1.0 - plain);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The voxel fragment shader. No uniforms. Signed-distance coverage from the local coordinate
    /// (``edgeCoverage(local:)``; the solid materials opaque), the frosted face and the bevel sheen lit from the face
    /// normal (``cubeShade(material:normal:local:)``) and the chosen hinge's stripes (``stripeCoverage(local:)``).
    /// Premultiplied.
    public static let voxelFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_normal;
    in float v_material;
    in float v_local;
    out vec4 color;
    const vec3 VO_IVORY = \(vec3Literal(VoxelOrigamiPalette.ivory));
    const vec3 VO_IVORY_SHADE = \(vec3Literal(VoxelOrigamiPalette.ivoryShade));
    const vec3 VO_HINGE = \(vec3Literal(VoxelOrigamiPalette.hinge));
    const vec3 VO_LIGHT_DIR = \(vec3Literal(lightDirection));
    const float VO_EDGE_FEATHER = \(fixed(edgeFeather));
    const float VO_FROST_START = \(fixed(frostStart));
    const float VO_FROST_EDGE = \(fixed(frostEdge));
    const float VO_BEVEL_SHEEN = \(fixed(bevelSheen));
    const float VO_AMBIENT = \(fixed(ambient));
    const float VO_DIFFUSE = \(fixed(diffuse));
    const float VO_STRIPE_COUNT = \(fixed(stripeCount));
    const float VO_STRIPE_DUTY = \(fixed(stripeDuty));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float isFace = isCode(m, 2.0);
        float isBevel = isCode(m, 3.0);
        float solid = isCode(m, 0.0) + isFace + isBevel;
        float edge = 1.0 - smoothstep(1.0 - VO_EDGE_FEATHER, 1.0, d);
        float coverage = mix(edge, 1.0, solid);
        vec3 face = mix(VO_IVORY, VO_IVORY_SHADE, VO_FROST_EDGE * smoothstep(VO_FROST_START, 1.0, d));
        vec3 bevel = mix(VO_IVORY_SHADE, VO_IVORY, VO_BEVEL_SHEEN * (1.0 - d));
        vec3 rgb = mix(v_base, face, isFace);
        rgb = mix(rgb, bevel, isBevel);
        float nl = length(v_normal);
        vec3 n = v_normal / max(nl, 0.0001);
        float lambert = VO_AMBIENT + VO_DIFFUSE * max(dot(n, VO_LIGHT_DIR), 0.0) * step(0.0001, nl);
        rgb = rgb * mix(1.0, lambert, isFace + isBevel);
        float t = (clamp(v_local, -1.0, 1.0) + 1.0) * 0.5;
        float phase = fract(t * VO_STRIPE_COUNT);
        float stripe = 1.0 - step(VO_STRIPE_DUTY * 0.5, abs(phase - 0.5));
        rgb = mix(rgb, VO_HINGE, (1.0 - stripe) * isCode(m, 8.0));
        float alpha = clamp(coverage, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`), the kind and glow factor decoded from
    /// `a_uv.x` (``GlowKind/decode(_:)``) and the shell's radial coordinate (`a_uv.y`).
    public static let glowVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_colour;
    out float v_kind;
    out float v_factor;
    out float v_radius;
    void main() {
        float x = clamp(a_uv.x, 0.0, 3.0);
        float kind = clamp(floor(x * 0.5), 0.0, 1.0);
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_kind = kind;
        v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);
        v_radius = clamp(a_uv.y, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`, `u_won`. Gain ``glowGain(gain:limit:)``,
    /// colour and alpha ``glowColour(colour:kind:factor:radius:gain:won:)``; premultiplied RGBA in 0 … 1, drawn with
    /// additive blending.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_kind;
    in float v_factor;
    in float v_radius;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    uniform float u_won;
    out vec4 color;
    const vec3 VO_TARGET_GLOW = \(vec3Literal(VoxelOrigamiPalette.targetGlow));
    const vec3 VO_GLOW = \(vec3Literal(VoxelOrigamiPalette.glow));
    const float VO_GLOW_WEIGHT = \(fixed(glowWeight));
    const float VO_TARGET_REST = \(fixed(targetRest));
    const float VO_MAX_GAIN = \(fixed(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, VO_MAX_GAIN), clamp(u_glowLimit, 0.0, VO_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isTarget = isCode(kind, 1.0);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 fallback = mix(VO_GLOW, VO_TARGET_GLOW, isTarget);
        vec3 rgb = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float factor = clamp(v_factor, 0.0, 1.0) * mix(1.0, mix(VO_TARGET_REST, 1.0, won), isTarget);
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        float alpha = clamp(VO_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The soft-outline coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 … 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// The chosen hinge's stripe at local coordinate `local` along its bar (clamped to -1 … 1; non-finite counts as the
    /// bar's centre): 1 (hot pink) where |fract(t · ``stripeCount``) - 0.5| < ``stripeDuty`` / 2 with t = (local + 1) / 2,
    /// else 0 (hinge grey). The bar's centre (local 0) is pink.
    public static func stripeCoverage(local: Double) -> Double {
        let d: Double = local.isFinite ? min(max(local, -1), 1) : 0
        let t: Double = (d + 1) * 0.5 * stripeCount
        let phase: Double = t - t.rounded(.down)
        return abs(phase - 0.5) < stripeDuty * 0.5 ? 1 : 0
    }

    /// The faceted light of a cube face or bevel with `normal` (any length; a zero or non-finite normal gets the
    /// ambient light only): ``ambient`` + ``diffuse`` · max(n · ``lightDirection``, 0), within ``ambient`` … 1.
    public static func light(normal: SIMD3<Double>) -> Double {
        let finite: Bool = normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        let length: Double = finite ? (normal * normal).sum().squareRoot() : 0
        guard length >= 0.0001 else { return ambient }
        let n: SIMD3<Double> = normal / length
        return ambient + diffuse * max((n * lightDirection).sum(), 0)
    }

    /// The colour the voxel fragment shader gives a lit `material` (``Material/cubeFace`` or ``Material/cubeBevel``)
    /// with `normal` at local coordinate `local` (|local| clamped to 0 … 1; non-finite counts as 1): the frosted face
    /// (ivory toward the shade colour by ``frostEdge`` · smoothstep(``frostStart``, 1, |d|)) or the bevel (the shade
    /// colour toward the ivory by ``bevelSheen`` (1 - |d|)), times ``light(normal:)``; any other material its palette
    /// colour, unlit.
    public static func cubeShade(material: Material, normal: SIMD3<Double>, local: Double) -> SIMD3<Double> {
        let d: Double = local.isFinite ? min(abs(local), 1) : 1
        let ivory: SIMD3<Double> = VoxelOrigamiPalette.ivory
        let shade: SIMD3<Double> = VoxelOrigamiPalette.ivoryShade
        switch material {
        case .cubeFace:
            let frost: Double = frostEdge * smoothstep(frostStart, 1, d)
            return (ivory + (shade - ivory) * frost) * light(normal: normal)
        case .cubeBevel:
            return (shade + (ivory - shade) * (bevelSheen * (1 - d))) * light(normal: normal)
        default:
            return material.colour
        }
    }

    /// The target wireframe's colour at won light `won` (clamped to 0 … 1; non-finite counts as 0): the target colour
    /// flared toward the target-glow colour by ``flareLift`` times `won`.
    public static func targetColour(won: Double) -> SIMD3<Double> {
        let w: Double = won.isFinite ? min(max(won, 0), 1) : 0
        return VoxelOrigamiPalette.target + (VoxelOrigamiPalette.targetGlow - VoxelOrigamiPalette.target) * (flareLift * w)
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: VoxelOrigamiTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 … ``maxGlowGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the glow colour on a cube shell, the target-glow colour on a
    /// target shell), `kind`, glow factor `factor`, radial coordinate `radius`, the applied `gain` and won light `won`,
    /// before premultiplying: the colour, with alpha ``glowWeight`` · gain · factor · (1 - radius)², the factor of a
    /// target shell also times ``targetRest`` + (1 - ``targetRest``) · won; every component clamped to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            c = kind == .target ? VoxelOrigamiPalette.targetGlow : VoxelOrigamiPalette.glow
        }
        let flare: Double = kind == .target ? targetRest + (1 - targetRest) * unit(won) : 1
        let r: Double = 1 - unit(radius)
        let k: Double = gain.isFinite ? gain : 0
        return SIMD4<Double>(c.x, c.y, c.z, unit(glowWeight * k * unit(factor) * flare * r * r))
    }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
