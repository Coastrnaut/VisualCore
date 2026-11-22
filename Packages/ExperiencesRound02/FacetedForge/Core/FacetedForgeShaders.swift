// FacetedForgeShaders — feature 373 (R02-G08-03) T-R02G0803-003 (FR-R02G0803-002, FR-R02G0803-004, FR-R02G0803-007;
// clarifications on the palette, the tiers, Reduce Motion and Reduce Flashing). The two GLSL ES 3.00 programs of
// Faceted Forge held as source text (data: the core issues no GL call), with the names of every uniform they declare,
// their vertex attributes, the constants the sources are built from and the CPU references of what they compute.
//
// Crystal program: the dark ground, the translucent ice-glass original faces (alpha ``glassAlpha`` = 0.45, raised by
// the fresnel term), the incandescent cut faces with their lattice, the bevels, the translucent ruby preview plane with
// its dashed rim, the sliver cross and the spent and unspent bars of the cut mark. Mesh layout (data model, "Mesh
// streams"): `a_normal` is the surface normal, `a_uv.x` the material code (see `CrystalMaterial`: 0 ground, 1 glass,
// 2 cut face, 3 bevel, 4 preview, 5 sliver cross, 6 spent bar, 7 unspent bar, 8 lattice), `a_uv.y` the vertex shade
// 0 ... 1, except on the preview, where it is the rim coordinate (0 on the polygon's outline, 1 at its centre; the
// geometry fans the polygon from its centre). Lighting is an ambient term plus Lambert from `u_lightDir`.
// Glass: ice plus a fresnel highlight (`u_eye` gives the view direction) and up to ``maxDispersionLayers`` (3) faux
// dispersion layers, bands of ruby, amber and highlight colour sliding across the glass with `u_time` (the only time
// source); only the first `u_layers` layers (the tier's `dispersionLayers`, clamped to 0 ... 3) count; the loop is
// bounded by the constant 3. Cut face: an amber-to-ruby interior (amber facing the eye, ruby at grazing angles), lit
// mostly by its own emission, under a lattice of lattice-coloured grid lines computed triplanarly from the world
// position, so the cue is a pattern as well as a colour. Preview: ruby, its rim band (rim coordinate below
// ``previewRimWidth``) dashed by a 3D checker of the world position: dashes are opaque highlight colour, gaps stay
// ruby. Every other material is its palette colour, flat, with the simple lighting. Reduce Motion needs nothing here:
// the scene passes `u_time` = 0, so the dispersion stands still.
//
// Glow program: the glow shells over the cut faces, drawn additively. The colour is carried in `a_normal` (the mesh
// builder writes a `FacetedForgePalette` colour there), `a_uv.x` is the glow weight 0 ... 1 and `a_uv.y` is 0. The
// glow is the colour lifted toward the lattice gold by ``coreLift`` times the glow weight and the glow gain, with alpha
// ``glowWeight`` times the same; the glow gain is `u_glow` capped by `u_glowLimit` (both clamped to ``maxGlowGain``);
// under Reduce Flashing the presenter passes ``glowGainCap`` as the limit. The glow program has no time input: it
// never pulses.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1)
// from `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with
// `#version 300 es` (VisualCoreShaderSource's `ShaderLibrary.versionLine`) and states one float precision. Plain
// uniforms (at most 16 vec4 slots per program; the crystal program uses 8, the glow program 6), no texture samplers,
// no image assets, no `discard` and one loop, bounded by a constant. Output is premultiplied alpha. Palette constants
// are written with six fixed decimals from `FacetedForgePalette`, so the shader colours equal the CPU's within 1/255.

import Foundation

/// The GLSL ES 3.00 sources of Faceted Forge's crystal and glow programs, their uniform and attribute names, the
/// material codes, the constants they are built from and the CPU references of what they compute (FR-R02G0803-002).
public enum FacetedForgeShaders {
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
    /// `vec3`: the camera position in model units (crystal), for the view direction of the fresnel term.
    public static let eyeUniform = "u_eye"
    /// `float`: presentation time in seconds, the only time source of the dispersion shimmer (crystal); the scene
    /// passes 0 under Reduce Motion, so the shimmer stands still.
    public static let timeUniform = "u_time"
    /// `float`: the tier's `dispersionLayers`, clamped by the shader to 0 ... ``maxDispersionLayers`` (crystal).
    public static let layersUniform = "u_layers"
    /// `float`: the glow gain (glow); see ``glowGain(gain:limit:)``.
    public static let glowUniform = "u_glow"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the crystal program declares, exactly as declared (vertex stage first).
    public static let crystalUniforms: [String] = [mvpUniform, lightDirectionUniform, eyeUniform, timeUniform,
                                                   layersUniform]

    /// Every uniform the glow program declares, exactly as declared (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowUniform, glowLimitUniform]

    /// The uniform lists per program name (`crystal`, `glow`).
    public static let uniformNames: [String: [String]] = ["crystal": crystalUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Material codes

    /// The material code of the dark ground plane (`a_uv.x` = 0).
    public static let groundMaterial: Double = CrystalMaterial.ground.code
    /// The material code of an original (ice-glass) face (`a_uv.x` = 1).
    public static let glassMaterial: Double = CrystalMaterial.glass.code
    /// The material code of a cut face, incandescent with a lattice (`a_uv.x` = 2).
    public static let cutFaceMaterial: Double = CrystalMaterial.cutFace.code
    /// The material code of a bevel strip along a piece edge (`a_uv.x` = 3).
    public static let bevelMaterial: Double = CrystalMaterial.bevel.code
    /// The material code of the preview plane; its `a_uv.y` is the rim coordinate (`a_uv.x` = 4).
    public static let previewMaterial: Double = CrystalMaterial.preview.code
    /// The material code of the sliver cross on a failed piece (`a_uv.x` = 5).
    public static let sliverCrossMaterial: Double = CrystalMaterial.sliverCross.code
    /// The material code of a spent bar of the cut mark (`a_uv.x` = 6).
    public static let spentBarMaterial: Double = CrystalMaterial.spentBar.code
    /// The material code of an unspent bar of the cut mark (`a_uv.x` = 7).
    public static let unspentBarMaterial: Double = CrystalMaterial.unspentBar.code
    /// The material code of a lattice strut drawn as geometry, flat lattice colour (`a_uv.x` = 8).
    public static let latticeMaterial: Double = CrystalMaterial.lattice.code

    // MARK: Constants

    /// The dark ground, as written into the sources (`FacetedForgePalette.ground`).
    public static let ground: SIMD3<Double> = FacetedForgePalette.ground
    /// The ice glass of the original faces, as written into the sources (`FacetedForgePalette.ice`).
    public static let ice: SIMD3<Double> = FacetedForgePalette.ice
    /// The fresnel highlight, bevels and preview dashes, as written into the sources (`FacetedForgePalette.highlight`).
    public static let highlight: SIMD3<Double> = FacetedForgePalette.highlight
    /// The ruby preview plane and grazing cut faces, as written into the sources (`FacetedForgePalette.ruby`).
    public static let ruby: SIMD3<Double> = FacetedForgePalette.ruby
    /// The incandescent inner amber of the cut faces, as written into the sources (`FacetedForgePalette.amber`).
    public static let amber: SIMD3<Double> = FacetedForgePalette.amber
    /// The lattice on the cut faces and the glow core, as written into the sources (`FacetedForgePalette.lattice`).
    public static let lattice: SIMD3<Double> = FacetedForgePalette.lattice
    /// The sliver cross, as written into the sources (`FacetedForgePalette.sliver`).
    public static let sliver: SIMD3<Double> = FacetedForgePalette.sliver
    /// A spent bar of the cut mark, as written into the sources (`FacetedForgePalette.spent`).
    public static let spent: SIMD3<Double> = FacetedForgePalette.spent
    /// An unspent bar of the cut mark, as written into the sources (`FacetedForgePalette.unspent`).
    public static let unspent: SIMD3<Double> = FacetedForgePalette.unspent

    /// The base alpha of an ice-glass face (the fresnel term raises it toward 1).
    public static let glassAlpha: Double = 0.45
    /// The alpha of the preview plane's interior and rim gaps (rim dashes are opaque).
    public static let previewAlpha: Double = 0.6
    /// The crystal program's ambient term.
    public static let ambient: Double = 0.55
    /// The crystal program's Lambert weight (ambient + diffuse = 1).
    public static let diffuse: Double = 0.45
    /// The exponent of the fresnel term (1 - |n . v|) ^ power.
    public static let fresnelPower: Double = 3
    /// The weight of the fresnel highlight colour on the glass.
    public static let fresnelWeight: Double = 0.6
    /// How much the fresnel term adds to the glass alpha.
    public static let fresnelAlpha: Double = 0.4
    /// The most faux-dispersion layers on the glass (the richest tier's `dispersionLayers`; the loop bound).
    public static let maxDispersionLayers: Int = 3
    /// The weight of one dispersion band, times its band value 0 ... 1 and its tint.
    public static let dispersionWeight: Double = 0.12
    /// The spatial frequency of the dispersion bands in radians per model unit.
    public static let dispersionFrequency: Double = 9
    /// The sliding rate of dispersion layer 0 in radians per second; layer i slides at (i + 1) times it.
    public static let dispersionSpeed: Double = 0.8
    /// The share of a cut face's colour that is emission, independent of the light (the rest is Lambert).
    public static let cutEmission: Double = 0.8
    /// The lattice grid lines per model unit on a cut face.
    public static let latticeFrequency: Double = 8
    /// The lattice line half-width in grid cells (a line covers distances below it, fading from half of it).
    public static let latticeWidth: Double = 0.08
    /// How far a lattice line mixes the cut face's interior toward the lattice colour.
    public static let latticeStrength: Double = 0.85
    /// The rim band of the preview plane, in rim coordinate (0 on the outline, 1 at the centre).
    public static let previewRimWidth: Double = 0.15
    /// The dash cells per model unit of the preview rim's 3D checker.
    public static let dashFrequency: Double = 12

    /// The alpha weight of the glow, times the glow gain and the glow weight of the vertex.
    public static let glowWeight: Double = 0.5
    /// How far the glow lifts a colour toward the lattice gold, times the glow gain and the glow weight.
    public static let coreLift: Double = 0.3

    /// The upper bound (the glow gain cap) the glow shader clamps `u_glow` and `u_glowLimit` to.
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
        /// The dark ground plane (opaque).
        case ground = 0
        /// An original face: translucent ice glass with fresnel highlight and dispersion layers.
        case glass = 1
        /// A cut face: incandescent amber-to-ruby interior under a lattice (opaque).
        case cutFace = 2
        /// A bevel strip along a piece edge, highlight colour (opaque).
        case bevel = 3
        /// The translucent ruby preview plane with its dashed rim; `a_uv.y` is the rim coordinate.
        case preview = 4
        /// The sliver cross on a failed piece (opaque).
        case sliverCross = 5
        /// A spent bar of the cut mark, ruby (opaque).
        case spentBar = 6
        /// An unspent bar of the cut mark (opaque).
        case unspentBar = 7
        /// A lattice strut drawn as geometry, flat lattice colour (opaque).
        case lattice = 8

        /// The `a_uv.x` value of the material.
        public var code: Double { Double(rawValue) }

        /// The material's colour as the crystal vertex shader selects it (before shade, light and patterns).
        public var colour: SIMD3<Double> {
            switch self {
            case .ground: FacetedForgeShaders.ground
            case .glass: FacetedForgeShaders.ice
            case .cutFace: FacetedForgeShaders.amber
            case .bevel: FacetedForgeShaders.highlight
            case .preview: FacetedForgeShaders.ruby
            case .sliverCross: FacetedForgeShaders.sliver
            case .spentBar: FacetedForgeShaders.spent
            case .unspentBar: FacetedForgeShaders.unspent
            case .lattice: FacetedForgeShaders.lattice
            }
        }

        /// The material's base alpha: ``FacetedForgeShaders/glassAlpha`` for glass,
        /// ``FacetedForgeShaders/previewAlpha`` for the preview, 1 otherwise.
        public var alpha: Double {
            switch self {
            case .glass: FacetedForgeShaders.glassAlpha
            case .preview: FacetedForgeShaders.previewAlpha
            default: 1
            }
        }
    }

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The crystal vertex shader. Uniform: `u_mvp`. Selects the material colour from `a_uv.x`, scales it by the shade
    /// `a_uv.y` (not on the preview, whose `a_uv.y` is the rim coordinate) and passes the normal, the model position,
    /// the material code, `a_uv.y` and the material alpha.
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
    out float v_material;
    out float v_shade;
    out float v_alpha;
    const vec3 FF_GROUND = \(vec3Literal(ground));
    const vec3 FF_ICE = \(vec3Literal(ice));
    const vec3 FF_AMBER = \(vec3Literal(amber));
    const vec3 FF_HIGHLIGHT = \(vec3Literal(highlight));
    const vec3 FF_RUBY = \(vec3Literal(ruby));
    const vec3 FF_SLIVER = \(vec3Literal(sliver));
    const vec3 FF_SPENT = \(vec3Literal(spent));
    const vec3 FF_UNSPENT = \(vec3Literal(unspent));
    const vec3 FF_LATTICE = \(vec3Literal(lattice));
    const float FF_GLASS_ALPHA = \(fixed(glassAlpha));
    const float FF_PREVIEW_ALPHA = \(fixed(previewAlpha));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 8.0);
        float isGlass = isCode(m, 1.0);
        float isPreview = isCode(m, 4.0);
        vec3 base = mix(FF_GROUND, FF_ICE, isGlass);
        base = mix(base, FF_AMBER, isCode(m, 2.0));
        base = mix(base, FF_HIGHLIGHT, isCode(m, 3.0));
        base = mix(base, FF_RUBY, isPreview);
        base = mix(base, FF_SLIVER, isCode(m, 5.0));
        base = mix(base, FF_SPENT, isCode(m, 6.0));
        base = mix(base, FF_UNSPENT, isCode(m, 7.0));
        base = mix(base, FF_LATTICE, isCode(m, 8.0));
        float shade = clamp(a_uv.y, 0.0, 1.0);
        v_base = base * mix(shade, 1.0, isPreview);
        v_normal = a_normal;
        v_position = a_position;
        v_material = m;
        v_shade = shade;
        v_alpha = mix(mix(1.0, FF_GLASS_ALPHA, isGlass), FF_PREVIEW_ALPHA, isPreview);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The crystal fragment shader. Uniforms: `u_lightDir`, `u_eye`, `u_time`, `u_layers`. Ambient ``ambient`` plus
    /// Lambert ``diffuse`` (``crystalShade(base:normalDotLight:)``); glass adds the fresnel highlight
    /// (``fresnel(normalDotView:)``) and the first `u_layers` of ``maxDispersionLayers`` dispersion bands
    /// (``dispersionBand(layer:time:position:)``); a cut face is the amber-to-ruby interior under the lattice
    /// (``lattice(position:normal:)``); the preview's rim is dashed (``previewDash(position:)``). Premultiplied.
    public static let crystalFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in vec3 v_position;
    in float v_material;
    in float v_shade;
    in float v_alpha;
    uniform vec3 u_lightDir;
    uniform vec3 u_eye;
    uniform float u_time;
    uniform float u_layers;
    out vec4 color;
    const vec3 FF_HIGHLIGHT = \(vec3Literal(highlight));
    const vec3 FF_RUBY = \(vec3Literal(ruby));
    const vec3 FF_AMBER = \(vec3Literal(amber));
    const vec3 FF_LATTICE = \(vec3Literal(lattice));
    const int FF_MAX_LAYERS = \(maxDispersionLayers);
    const float FF_AMBIENT = \(fixed(ambient));
    const float FF_DIFFUSE = \(fixed(diffuse));
    const float FF_FRESNEL_POWER = \(fixed(fresnelPower));
    const float FF_FRESNEL_WEIGHT = \(fixed(fresnelWeight));
    const float FF_FRESNEL_ALPHA = \(fixed(fresnelAlpha));
    const float FF_DISPERSION_WEIGHT = \(fixed(dispersionWeight));
    const float FF_DISPERSION_FREQUENCY = \(fixed(dispersionFrequency));
    const float FF_DISPERSION_SPEED = \(fixed(dispersionSpeed));
    const float FF_CUT_EMISSION = \(fixed(cutEmission));
    const float FF_LATTICE_FREQUENCY = \(fixed(latticeFrequency));
    const float FF_LATTICE_WIDTH = \(fixed(latticeWidth));
    const float FF_LATTICE_STRENGTH = \(fixed(latticeStrength));
    const float FF_RIM_WIDTH = \(fixed(previewRimWidth));
    const float FF_DASH_FREQUENCY = \(fixed(dashFrequency));
    float gridLine(float u) {
        float d = abs(fract(u + 0.5) - 0.5);
        return 1.0 - smoothstep(0.5 * FF_LATTICE_WIDTH, FF_LATTICE_WIDTH, d);
    }
    void main() {
        float m = floor(v_material + 0.5);
        float isGlass = 1.0 - step(0.5, abs(m - 1.0));
        float isCut = 1.0 - step(0.5, abs(m - 2.0));
        float isPreview = 1.0 - step(0.5, abs(m - 4.0));
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 l = u_lightDir / max(length(u_lightDir), 0.0001);
        vec3 e = u_eye - v_position;
        vec3 v = e / max(length(e), 0.0001);
        float lambert = max(dot(n, l), 0.0);
        float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
        float fresnel = pow(1.0 - facing, FF_FRESNEL_POWER);
        vec3 lit = clamp(v_base, 0.0, 1.0) * (FF_AMBIENT + FF_DIFFUSE * lambert);
        float layers = clamp(u_layers, 0.0, float(FF_MAX_LAYERS));
        vec3 shimmer = vec3(0.0);
        for (int i = 0; i < FF_MAX_LAYERS; i++) {
            float on = 1.0 - step(layers, float(i));
            float k = float(i);
            vec3 axis = normalize(vec3(cos(2.094395 * k), 0.6, sin(2.094395 * k)));
            float phase = FF_DISPERSION_FREQUENCY * dot(v_position, axis) + 2.094395 * k;
            float band = 0.5 + 0.5 * sin(phase + FF_DISPERSION_SPEED * (k + 1.0) * u_time);
            vec3 tint = mix(FF_RUBY, mix(FF_AMBER, FF_HIGHLIGHT, step(1.5, k)), step(0.5, k));
            shimmer += on * FF_DISPERSION_WEIGHT * band * tint;
        }
        vec3 glass = lit + FF_HIGHLIGHT * (FF_FRESNEL_WEIGHT * fresnel) + shimmer;
        float heat = 1.0 - facing;
        float glowLight = FF_CUT_EMISSION + (1.0 - FF_CUT_EMISSION) * lambert;
        vec3 interior = mix(FF_AMBER, FF_RUBY, heat) * glowLight * clamp(v_shade, 0.0, 1.0);
        vec3 g = v_position * FF_LATTICE_FREQUENCY;
        vec3 an = abs(n);
        vec3 w = an / max(an.x + an.y + an.z, 0.0001);
        float lx = max(gridLine(g.y), gridLine(g.z));
        float ly = max(gridLine(g.x), gridLine(g.z));
        float lz = max(gridLine(g.x), gridLine(g.y));
        float grid = dot(w, vec3(lx, ly, lz));
        vec3 cut = mix(interior, FF_LATTICE, FF_LATTICE_STRENGTH * grid);
        float rim = 1.0 - step(FF_RIM_WIDTH, v_shade);
        vec3 cell = floor(v_position * FF_DASH_FREQUENCY);
        float dash = mod(cell.x + cell.y + cell.z, 2.0);
        float rimOn = rim * dash;
        vec3 preview = mix(lit, FF_HIGHLIGHT, rimOn);
        vec3 rgb = mix(lit, glass, isGlass);
        rgb = mix(rgb, cut, isCut);
        rgb = mix(rgb, preview, isPreview);
        rgb = clamp(rgb, 0.0, 1.0);
        float alpha = clamp(v_alpha + isGlass * FF_FRESNEL_ALPHA * fresnel, 0.0, 1.0);
        alpha = mix(alpha, 1.0, isPreview * rimOn);
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

    /// The glow fragment shader. Uniforms: `u_glow`, `u_glowLimit`. Gain ``glowGain(gain:limit:)``, colour and alpha
    /// ``glowColour(colour:glow:gain:)``; premultiplied RGBA in 0 ... 1, drawn with additive blending.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_glow;
    uniform float u_glow;
    uniform float u_glowLimit;
    out vec4 color;
    const vec3 FF_LATTICE = \(vec3Literal(lattice));
    const float FF_GLOW = \(fixed(glowWeight));
    const float FF_CORE = \(fixed(coreLift));
    const float FF_MAX_GAIN = \(fixed(maxGlowGain));
    void main() {
        float gain = min(clamp(u_glow, 0.0, FF_MAX_GAIN), clamp(u_glowLimit, 0.0, FF_MAX_GAIN));
        vec3 rgb = mix(v_colour, FF_LATTICE, clamp(FF_CORE * gain * v_glow, 0.0, 1.0));
        float alpha = clamp(FF_GLOW * gain * v_glow, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glow` at `tier`: ``standardGlowGain`` with glow shells, 0 without
    /// (level-2).
    public static func glowGain(for tier: FacetedForgeTier) -> Double {
        tier.glowShells > 0 ? standardGlowGain : 0
    }

    /// The value the presenter passes as `u_layers` at `tier`: its `dispersionLayers`, clamped to 0 ...
    /// ``maxDispersionLayers``.
    public static func dispersionLayers(for tier: FacetedForgeTier) -> Double {
        Double(min(max(tier.dispersionLayers, 0), maxDispersionLayers))
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow for a vertex `colour`, glow weight `glow` and the applied `gain`, before premultiplying: the colour
    /// lifted toward the lattice gold by ``coreLift`` gain glow (rgb) and the alpha ``glowWeight`` gain glow, every
    /// component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, glow: Double, gain: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        let c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        let g: Double = unit(glow)
        let k: Double = gain.isFinite ? gain : 0
        let lift: Double = unit(coreLift * k * g)
        let lifted: SIMD3<Double> = c + (lattice - c) * lift
        return SIMD4<Double>(unit(lifted.x), unit(lifted.y), unit(lifted.z), unit(glowWeight * k * g))
    }

    /// The crystal colour for a material colour `base` (after shade) and n . l `normalDotLight`: base x (``ambient`` +
    /// ``diffuse`` max(n . l, 0)), every component in 0 ... 1.
    public static func crystalShade(base: SIMD3<Double>, normalDotLight: Double) -> SIMD3<Double> {
        func unit(_ x: Double) -> Double { min(max(x, 0), 1) }
        let b: SIMD3<Double> = SIMD3<Double>(unit(base.x), unit(base.y), unit(base.z))
        let lit: SIMD3<Double> = b * (ambient + diffuse * max(normalDotLight, 0))
        return SIMD3<Double>(unit(lit.x), unit(lit.y), unit(lit.z))
    }

    /// The fresnel term for n . v `normalDotView`: (1 - |n . v|) ^ ``fresnelPower``, |n . v| clamped to 0 ... 1
    /// (non-finite counts as facing the eye, 0).
    public static func fresnel(normalDotView: Double) -> Double {
        let facing: Double = normalDotView.isFinite ? min(abs(normalDotView), 1) : 1
        return pow(1 - facing, fresnelPower)
    }

    /// The band value 0 ... 1 of dispersion layer `layer` (0 ... ``maxDispersionLayers`` - 1) at `time` seconds and
    /// model `position`: 0.5 + 0.5 sin(``dispersionFrequency`` (p . axis) + layer 2 pi / 3 + ``dispersionSpeed``
    /// (layer + 1) time), axis = (cos(layer 2 pi / 3), 0.6, sin(layer 2 pi / 3)) normalised. At `time` 0 (Reduce
    /// Motion) it depends on the position alone.
    public static func dispersionBand(layer: Int, time: Double, position: SIMD3<Double>) -> Double {
        let t: Double = time.isFinite ? time : 0
        let k: Double = Double(layer)
        let raw: SIMD3<Double> = SIMD3<Double>(cos(2.094395 * k), 0.6, sin(2.094395 * k))
        let axis: SIMD3<Double> = raw / (raw * raw).sum().squareRoot()
        let phase: Double = dispersionFrequency * (position * axis).sum() + 2.094395 * k
        return 0.5 + 0.5 * sin(phase + dispersionSpeed * (k + 1) * t)
    }

    /// The lattice line strength 0 ... 1 of grid coordinate `u` (``latticeFrequency`` times a position component): 1
    /// within ``latticeWidth`` / 2 of an integer, 0 from ``latticeWidth`` on, smoothstep between.
    public static func gridLine(_ u: Double) -> Double {
        guard u.isFinite else { return 0 }
        let f: Double = (u + 0.5) - (u + 0.5).rounded(.down)
        let d: Double = abs(f - 0.5)
        let lo: Double = 0.5 * latticeWidth
        let hi: Double = latticeWidth
        let x: Double = min(max((d - lo) / (hi - lo), 0), 1)
        return 1 - x * x * (3 - 2 * x)
    }

    /// The triplanar lattice strength 0 ... 1 on a cut face at model `position` with `normal`: the grid lines of the
    /// two axes across each face direction, weighted by |normal| normalised to sum 1.
    public static func lattice(position: SIMD3<Double>, normal: SIMD3<Double>) -> Double {
        let g: SIMD3<Double> = position * latticeFrequency
        let an: SIMD3<Double> = SIMD3<Double>(abs(normal.x), abs(normal.y), abs(normal.z))
        let w: SIMD3<Double> = an / max(an.sum(), 0.0001)
        let lx: Double = max(gridLine(g.y), gridLine(g.z))
        let ly: Double = max(gridLine(g.x), gridLine(g.z))
        let lz: Double = max(gridLine(g.x), gridLine(g.y))
        return w.x * lx + w.y * ly + w.z * lz
    }

    /// Whether the preview rim is a dash (1) or a gap (0) at model `position`: the parity of the sum of the
    /// ``dashFrequency`` cell indices along x, y and z (a 3D checker, so any rim edge alternates).
    public static func previewDash(position: SIMD3<Double>) -> Double {
        let c: SIMD3<Double> = (position * dashFrequency).rounded(.down)
        let s: Double = c.sum()
        return s - 2 * (s / 2).rounded(.down)
    }
}
