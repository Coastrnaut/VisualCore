// MyceliumArchitectShaders — feature 513 (R02-G22-03) T-R02G2203-004 (FR-R02G2203-001, 002; clarifications Q1–Q5;
// research R5–R7; contracts/api.md). The two GLSL ES 3.00 programs of Mycelium Architect held as source text (data:
// the core issues no GL call), with the names of every uniform they declare and the vec4 slots they use, their vertex
// attributes (the three `ShaderMeshRenderer` streams), the material codes the geometry writes into `a_uv.x`, the
// constants the sources are built from and the CPU twins of the encoding and of the glow gain. Presentation only: no
// rule is ever evaluated on these values, and nothing drawn is consulted by the rules.
//
// Board program: the still cave backdrop (a vertical gradient from cave to cave top) with hashed spore points covering
// at most 2 % of its area; the floor plate and grid lines; the dashed site squares; the toxin pools with concentric
// ripples travelling outward (by `u_time` times `u_motion`, so Reduce Motion stills them); the rock blocks lit by a
// fixed light with copper veins drawn by a constant-bounded loop of three octaves; the blocker discs with their ring;
// the nutrient orbs (a placed one with an outer ring) and the dim rings of consumed nutrients; the vein tubes whose
// brightness pulses outward along the path weight fraction with time (stopped under Reduce Motion: the pulse pattern
// stands still); the hyphae blooms (four recursive generations of radial filaments, each doubling the count, from a
// constant-bounded loop and a fixed hash); the sprouts; the translucent luminous root and open terminal caps (emissive
// core, rim light, gills) and the matte closed caps; the gauge plate, weight fill, limit tick, terminal pips (filled
// or hollow) and actions bars (lit or unlit); the hyphae fuzz strands swaying with time; the drifting spores moved by
// time. A won level (`u_won`) brightens the veins and the luminous caps. A broken element (the failure names it) is
// drawn in the broken colour #FF6B5E with its own shape (the geometry picks the shape: a broken hollow pip is a ring, a
// broken site is a dashed outline). Glow program: additive soft shells whose gain `u_glowGain` is capped by
// `u_glowLimit` (Reduce Flashing). No texture sampler, no `discard`, only constant-bounded loops, at most 16 vec4
// uniform slots per program (board 7, glow 7), no random or time-of-day source (every scatter is a fixed hash).
import Foundation

/// The material code a board-program vertex carries in `a_uv.x` (FR-R02G2203-001, 002; clarification Q5), one per
/// kind of element the geometry draws, contiguous from 0 to 23.
///
/// Encoding: `a_uv.x` = code + ``MyceliumArchitectShaders/valueScale`` (0.25) · value + ``MyceliumArchitectShaders/
/// brokenOffset`` (0.5) when broken, where value is a fraction 0 … 1 (so it occupies 0 … 0.25 above the code, and a
/// broken element 0.5 … 0.75). Valued materials: a vein's path weight over the network's largest, the weight fill's
/// fraction, a placed nutrient's placement (1 placed, 0 fixed), a toxin's, fuzz strand's or spore's phase. Streams:
/// the solids (rock, vein, sprout, root and terminal caps) carry their surface normal in `a_normal`; every flat (quad)
/// carries its quad-local coordinate −1 … 1 in `a_normal.xy` and is cut out by signed distance in the fragment shader;
/// the backdrop carries its height 0 … 1 in `a_uv.y` and its plane offsets in `a_normal.xy`.
///
/// Internal to the shaders; the lead reconciles it with the geometry's `MyceliumArchitectMaterial` (same raw values).
enum MyceliumArchitectShaderMaterial: Int, Sendable, CaseIterable, Hashable {
    /// The backdrop quad (opaque): the still cave gradient with hashed spore points.
    case backdrop = 0
    /// The floor plate under the board (quad, square), floor colour.
    case floor = 1
    /// A grid line (quad strip, square), grid colour.
    case grid = 2
    /// A site mark (quad, dashed square outline), site colour.
    case site = 3
    /// A toxin pool (quad, disc with outward ripples), toxin colour.
    case toxin = 4
    /// A rock block (solid, lit) with copper veins, rock colour.
    case rock = 5
    /// A blocker stone (quad, disc with a ring in the ring colour), blocker colour.
    case blocker = 6
    /// A nutrient orb (quad, shaded disc; value 1: placed, with an outer ring), nutrient colour.
    case nutrient = 7
    /// A consumed nutrient (quad, dim ring), nutrient colour.
    case nutrientConsumed = 8
    /// A vein tube (solid, lit; value: path weight fraction, its pulse), emerald.
    case vein = 9
    /// A hyphae bloom where a nutrient was consumed (quad, recursive radial filaments), emerald.
    case bloom = 10
    /// A seed sprout (solid, lit), sprout colour.
    case sprout = 11
    /// The root cap (solid, translucent luminous dome), cap colour.
    case root = 12
    /// A terminal cap not reached (solid, matte closed dome), cap closed colour.
    case terminalClosed = 13
    /// A terminal cap reached (solid, translucent luminous dome), cap open colour.
    case terminalOpen = 14
    /// The weight gauge plate (quad, square), gauge plate colour.
    case gaugePlate = 15
    /// The weight fill (quad, square; value: fill fraction), weight colour.
    case weightFill = 16
    /// The weight limit tick (quad, square), limit colour.
    case limitTick = 17
    /// A reached terminal pip (quad, disc), cap open colour.
    case pipFilled = 18
    /// An unreached terminal pip (quad, ring), ring colour.
    case pipHollow = 19
    /// An action left (quad, square), actions lit colour.
    case actionsLit = 20
    /// An action spent (quad, square), actions unlit colour.
    case actionsUnlit = 21
    /// A hyphae fuzz strand (quad, tapered strand swaying with time; value: phase), spore colour.
    case fuzz = 22
    /// A drifting spore (quad, soft disc moved by time; value: phase), spore colour.
    case spore = 23

    /// The code as the stream carries it.
    var code: Float { Float(rawValue) }

    /// Whether the material carries a value fraction in `a_uv.x`.
    var isValued: Bool {
        switch self {
        case .toxin, .nutrient, .vein, .weightFill, .fuzz, .spore: return true
        default: return false
        }
    }

    /// The camel-case palette colour the board vertex shader selects for this material.
    var paletteName: String {
        switch self {
        case .backdrop: return "cave"
        case .floor: return "floor"
        case .grid: return "grid"
        case .site: return "site"
        case .toxin: return "toxin"
        case .rock: return "rock"
        case .blocker: return "blocker"
        case .nutrient, .nutrientConsumed: return "nutrient"
        case .vein, .bloom: return "emerald"
        case .sprout: return "sprout"
        case .root: return "cap"
        case .terminalClosed: return "capClosed"
        case .terminalOpen, .pipFilled: return "capOpen"
        case .gaugePlate: return "gaugePlate"
        case .weightFill: return "weight"
        case .limitTick: return "limit"
        case .pipHollow: return "ring"
        case .actionsLit: return "actionsLit"
        case .actionsUnlit: return "actionsUnlit"
        case .fuzz, .spore: return "spore"
        }
    }

    /// The GLSL palette constant the board vertex shader selects for this material.
    var paletteConstant: String { MyceliumArchitectShaders.constantName(paletteName) }
}

/// The GLSL ES 3.00 sources of Mycelium Architect's board and glow programs, their uniform and attribute names, the
/// vec4 uniform slots they use and the constants they are built from (FR-R02G2203-001, 002).
public enum MyceliumArchitectShaders {
    /// The version line every source starts with.
    public static let versionLine: String = "#version 300 es"

    /// The vertex attributes both programs read, as (name, location): `a_position` (vec3, 0), `a_normal` (vec3, 1)
    /// and `a_uv` (vec2, 2), as `ShaderMeshRenderer` binds them.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    // MARK: Uniforms

    /// `mat4`: projection × view × model (both programs, vertex stage; positions in world space).
    public static let mvpUniform: String = "u_mvp"
    /// `float`: the presentation time in seconds (board vertex stage; wrapped by ``timeWrap``).
    public static let timeUniform: String = "u_time"
    /// `float`: 1 normally, 0 under Reduce Motion (board vertex stage; multiplies the time, so the vein pulses,
    /// ripples, fuzz and spores stop).
    public static let motionUniform: String = "u_motion"
    /// `float`: the won level's light 0 … 1 (board vertex stage; glow fragment stage raises every factor to 1).
    public static let wonUniform: String = "u_won"
    /// `float`: the glow gain by tier (glow fragment stage).
    public static let glowGainUniform: String = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage; lowered by Reduce Flashing).
    public static let glowLimitUniform: String = "u_glowLimit"

    /// Every uniform the board program declares, each once, in order of declaration (all in the vertex stage).
    public static let boardUniforms: [String] = [mvpUniform, timeUniform, motionUniform, wonUniform]
    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform]
    /// The uniform lists per program name (`board`, `glow`).
    public static let uniformNames: [String: [String]] = ["board": boardUniforms, "glow": glowUniforms]

    /// The GLSL type of every uniform either program declares.
    static let uniformTypes: [String: String] = [
        "u_mvp": "mat4", "u_time": "float", "u_motion": "float", "u_won": "float", "u_glowGain": "float",
        "u_glowLimit": "float",
    ]

    /// The most vec4 uniform slots one program may use (clarification Q5).
    public static let maxUniformVec4s: Int = 16

    /// The vec4 uniform slots each program uses (`board`, `glow`): 4 for a `mat4`, 1 for a scalar or vector.
    public static let uniformSlots: [String: Int] = {
        var result: [String: Int] = [:]
        for (program, names) in uniformNames {
            var slots: Int = 0
            for name in names { slots += uniformTypes[name] == "mat4" ? 4 : 1 }
            result[program] = slots
        }
        return result
    }()

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), generated from
    /// `MyceliumArchitectPalette` in its declaration order (24 entries).
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = {
        var result: [(name: String, colour: SIMD3<Double>)] = []
        for entry in MyceliumArchitectPalette.all {
            result.append((name: constantName(entry.name),
                           colour: SIMD3<Double>(entry.colour.x, entry.colour.y, entry.colour.z)))
        }
        return result
    }()

    /// The GLSL constant name of palette colour `name`: `MA_` plus `name` in upper snake case (capOpen:
    /// `MA_CAP_OPEN`).
    public static func constantName(_ name: String) -> String {
        var result: String = "MA_"
        for c in name {
            if c.isUppercase { result.append("_") }
            result.append(contentsOf: c.uppercased())
        }
        return result
    }

    /// The highest material code (the spore).
    public static let maxMaterial: Int = MyceliumArchitectShaderMaterial.spore.rawValue
    /// The share of `a_uv.x` above the code a value 0 … 1 occupies.
    public static let valueScale: Double = 0.25
    /// The offset added to `a_uv.x` for a broken element.
    public static let brokenOffset: Double = 0.5
    /// The period the presentation time wraps at, in seconds (every rate below completes whole cycles in it).
    public static let timeWrap: Double = 600
    /// The fixed light direction of the lit solids (unit length; from the upper left front, as normalize(0.35, −0.45,
    /// 0.82)).
    public static let lightDirection: SIMD3<Double> = {
        let v: SIMD3<Double> = SIMD3<Double>(0.35, -0.45, 0.82)
        return v / (v * v).sum().squareRoot()
    }()
    /// The ambient share of a lit solid's colour.
    public static let ambient: Double = 0.45
    /// The vein pulse waves along the full path weight.
    public static let veinWaves: Double = 3
    /// The vein pulse rate, cycles per second (outward).
    public static let veinRate: Double = 0.5
    /// The vein brightness floor and swing of the pulse (brightness = floor + swing · pulse).
    public static let veinFloor: Double = 0.75
    /// The vein brightness swing of the pulse.
    public static let veinSwing: Double = 0.45
    /// The toxin ripple rings across the pool's radius.
    public static let toxinRings: Double = 3
    /// The toxin ripple rate, cycles per second (outward).
    public static let toxinRate: Double = 0.25
    /// The copper vein frequency of the first rock octave (per world unit).
    public static let rockFrequency: Double = 40
    /// The copper vein half width (in |sin| units).
    public static let rockVeinWidth: Double = 0.12
    /// The emissive share of a luminous cap.
    public static let capEmissive: Double = 0.55
    /// The rim light of a luminous cap.
    public static let capRim: Double = 0.6
    /// The gill bands of a luminous cap from pole to rim.
    public static let capGills: Double = 14
    /// The alpha of a translucent luminous cap.
    public static let capAlpha: Double = 0.85
    /// The filament half width of a hyphae bloom (in |sin| units).
    public static let bloomWidth: Double = 0.16
    /// The backdrop spore lattice density (cells per plane unit).
    public static let backdropDensity: Double = 18
    /// The share of backdrop lattice cells holding a spore point.
    public static let backdropPresence: Double = 0.25
    /// The radius of a backdrop spore point, in lattice cells.
    public static let backdropRadius: Double = 0.08
    /// The strength of a backdrop spore point over the gradient.
    public static let backdropStrength: Double = 0.7
    /// The drifting spore loop radius, world units.
    public static let sporeDrift: Double = 0.03
    /// The drifting spore rate, loops per second.
    public static let sporeRate: Double = 0.1
    /// The fuzz sway at a strand's tip, world units.
    public static let fuzzSway: Double = 0.006
    /// The fuzz sway rate, cycles per second.
    public static let fuzzRate: Double = 0.5
    /// The feather of every signed-distance edge, in quad-local units.
    public static let markFeather: Double = 0.06
    /// The half width of a ring band, in quad-local units.
    public static let ringHalf: Double = 0.16
    /// The width of a dashed outline, in quad-local units.
    public static let outlineWidth: Double = 0.2
    /// The dashes around a site outline.
    public static let siteDashes: Double = 12
    /// The duty of a dash.
    public static let dashDuty: Double = 0.55
    /// The brightness of a consumed nutrient's dim ring.
    public static let consumedDim: Double = 0.45
    /// The weight of a glow shell's alpha.
    public static let glowWeight: Double = 0.5
    /// The white-hot share at a glow shell's centre.
    public static let glowCore: Double = 0.5
    /// The highest glow gain or limit the glow program accepts.
    public static let maxGlowGain: Double = 1.5

    // MARK: Encoding (the geometry writes these)

    /// The `a_uv.x` a board vertex of `material` writes: its code, plus ``valueScale`` times `value` (clamped to
    /// 0 … 1, non-finite counts as 0; only for a valued material, otherwise ignored), plus ``brokenOffset`` when
    /// `broken`.
    static func encode(_ material: MyceliumArchitectShaderMaterial, value: Double = 0, broken: Bool = false) -> Double {
        let v: Double = material.isValued && value.isFinite ? min(max(value, 0), 1) : 0
        return Double(material.rawValue) + valueScale * v + (broken ? brokenOffset : 0)
    }

    /// What the board vertex shader decodes from `a_uv.x` value `x`: the code ⌊x + 0.001⌋ clamped to
    /// 0 … ``maxMaterial``; broken when the rest is at least ``brokenOffset`` − 0.125; the value (rest − offset) /
    /// ``valueScale`` clamped to 0 … 1. Non-finite or negative counts as the backdrop, value 0, not broken.
    static func decode(_ x: Double) -> (material: MyceliumArchitectShaderMaterial, value: Double, broken: Bool) {
        let raw: Double = x.isFinite ? max(x, 0) : 0
        let code: Double = min(max((raw + 0.001).rounded(.down), 0), Double(maxMaterial))
        let rest: Double = min(max(raw - code, 0), 1)
        let broken: Bool = rest >= brokenOffset - 0.125
        let value: Double = min(max((rest - (broken ? brokenOffset : 0)) / valueScale, 0), 1)
        let material: MyceliumArchitectShaderMaterial =
            MyceliumArchitectShaderMaterial(rawValue: Int(code)) ?? .backdrop
        return (material: material, value: value, broken: broken)
    }

    /// The glow gain the glow fragment shader applies: `gain` capped by `limit`, both clamped to 0 … ``maxGlowGain``
    /// (non-finite counts as 0).
    public static func glowGain(gain: Double, limit: Double) -> Double {
        let g: Double = gain.isFinite ? min(max(gain, 0), maxGlowGain) : 0
        let l: Double = limit.isFinite ? min(max(limit, 0), maxGlowGain) : 0
        return min(g, l)
    }

    /// The share of the backdrop's area the hashed spore points cover at most: presence · π · radius².
    public static var backdropCoverage: Double {
        backdropPresence * Double.pi * backdropRadius * backdropRadius
    }

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func decimals(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String {
        "vec3(\(decimals(v.x)), \(decimals(v.y)), \(decimals(v.z)))"
    }

    /// The `const vec3` lines of the palette colours named (camel-case palette names), in palette order; every colour
    /// when `names` is nil.
    static func paletteBlock(_ names: [String]?) -> String {
        var lines: [String] = []
        for entry in MyceliumArchitectPalette.all where names == nil || names?.contains(entry.name) == true {
            let colour: SIMD3<Double> = SIMD3<Double>(entry.colour.x, entry.colour.y, entry.colour.z)
            lines.append("const vec3 \(constantName(entry.name)) = \(vec3Literal(colour));")
        }
        return lines.joined(separator: "\n")
    }

    /// The `base = mix(base, <constant>, isCode(m, <code>));` lines of every material but the backdrop, in code order.
    static func selectionBlock() -> String {
        var lines: [String] = []
        for material in MyceliumArchitectShaderMaterial.allCases where material != .backdrop {
            let code: String = decimals(Double(material.rawValue))
            lines.append("base = mix(base, \(material.paletteConstant), isCode(m, \(code)));")
        }
        return lines.joined(separator: "\n")
    }

    /// The palette colours the board fragment shader declares.
    static let fragmentColours: [String] = ["cave", "caveTop", "spore", "veinCopper", "ring", "emerald", "glow"]

    /// The board vertex shader. Uniforms: `u_mvp`, `u_time`, `u_motion`, `u_won`. Decodes the material, the broken
    /// mark and the value from `a_uv.x` (``decode(_:)``), wraps the time and multiplies it by the motion (so Reduce
    /// Motion stops every movement), moves the drifting spores on their loops and sways the fuzz strands, selects the
    /// base colour (broken: the broken colour) and passes the normal or quad-local coordinate, the world position, the
    /// material, the value, `a_uv.y`, the moving clock and the won light.
    public static let boardVertex: String = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_time;
    uniform float u_motion;
    uniform float u_won;
    out vec3 v_base;
    out vec3 v_aux;
    out vec3 v_pos;
    out float v_material;
    out float v_value;
    out float v_local;
    out float v_clock;
    out float v_won;
    \(paletteBlock(nil))
    const float MA_MAX_MATERIAL = \(decimals(Double(maxMaterial)));
    const float MA_VALUE_SCALE = \(decimals(valueScale));
    const float MA_BROKEN_OFFSET = \(decimals(brokenOffset));
    const float MA_TIME_WRAP = \(decimals(timeWrap));
    const float MA_SPORE_DRIFT = \(decimals(sporeDrift));
    const float MA_SPORE_RATE = \(decimals(sporeRate));
    const float MA_FUZZ_SWAY = \(decimals(fuzzSway));
    const float MA_FUZZ_RATE = \(decimals(fuzzRate));
    const float MA_TAU = 6.283185;
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float raw = max(a_uv.x, 0.0);
        float m = clamp(floor(raw + 0.001), 0.0, MA_MAX_MATERIAL);
        float rest = clamp(raw - m, 0.0, 1.0);
        float broken = step(MA_BROKEN_OFFSET - 0.125, rest);
        float value = clamp((rest - MA_BROKEN_OFFSET * broken) / MA_VALUE_SCALE, 0.0, 1.0);
        float clock = mod(max(u_time, 0.0), MA_TIME_WRAP) * clamp(u_motion, 0.0, 1.0);
        float isSpore = isCode(m, 23.0);
        float isFuzz = isCode(m, 22.0);
        float loop = MA_TAU * (value + clock * MA_SPORE_RATE);
        float sway = sin(MA_TAU * (value + clock * MA_FUZZ_RATE));
        float tip = clamp((a_normal.y + 1.0) * 0.5, 0.0, 1.0);
        vec3 p = a_position;
        p.xy = p.xy + isSpore * MA_SPORE_DRIFT * vec2(cos(loop) - 1.0, sin(loop));
        p.x = p.x + isFuzz * MA_FUZZ_SWAY * sway * tip;
        vec3 base = MA_CAVE;
        \(selectionBlock())
        base = mix(base, MA_BROKEN, broken);
        v_base = base;
        v_aux = a_normal;
        v_pos = p;
        v_material = m;
        v_value = value;
        v_local = a_uv.y;
        v_clock = clock;
        v_won = clamp(u_won, 0.0, 1.0);
        gl_Position = u_mvp * vec4(p, 1.0);
    }
    """

    /// The board fragment shader (no uniforms). The still backdrop gradient with hashed spore points, the solids lit
    /// by a fixed light (rock with copper veins from a three-octave constant loop, veins pulsing outward along the
    /// path weight, sprouts, matte closed caps, translucent luminous root and open caps), and the signed-distance
    /// flats (square, disc, ring, dashed outline, ripple pool, blocker, nutrient orb, hyphae bloom from a four-
    /// generation constant loop, fuzz strand, soft spore). Every material code selects exactly one coverage rule.
    /// Premultiplied output.
    public static let boardFragment: String = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_aux;
    in vec3 v_pos;
    in float v_material;
    in float v_value;
    in float v_local;
    in float v_clock;
    in float v_won;
    out vec4 color;
    \(paletteBlock(fragmentColours))
    const vec3 MA_LIGHT = \(vec3Literal(lightDirection));
    const float MA_TAU = 6.283185;
    const float MA_AMBIENT = \(decimals(ambient));
    const float MA_VEIN_WAVES = \(decimals(veinWaves));
    const float MA_VEIN_RATE = \(decimals(veinRate));
    const float MA_VEIN_FLOOR = \(decimals(veinFloor));
    const float MA_VEIN_SWING = \(decimals(veinSwing));
    const float MA_TOXIN_RINGS = \(decimals(toxinRings));
    const float MA_TOXIN_RATE = \(decimals(toxinRate));
    const float MA_ROCK_FREQUENCY = \(decimals(rockFrequency));
    const float MA_ROCK_VEIN_WIDTH = \(decimals(rockVeinWidth));
    const float MA_CAP_EMISSIVE = \(decimals(capEmissive));
    const float MA_CAP_RIM = \(decimals(capRim));
    const float MA_CAP_GILLS = \(decimals(capGills));
    const float MA_CAP_ALPHA = \(decimals(capAlpha));
    const float MA_BLOOM_WIDTH = \(decimals(bloomWidth));
    const float MA_BACKDROP_DENSITY = \(decimals(backdropDensity));
    const float MA_BACKDROP_PRESENCE = \(decimals(backdropPresence));
    const float MA_BACKDROP_RADIUS = \(decimals(backdropRadius));
    const float MA_BACKDROP_STRENGTH = \(decimals(backdropStrength));
    const float MA_MARK_FEATHER = \(decimals(markFeather));
    const float MA_RING_HALF = \(decimals(ringHalf));
    const float MA_OUTLINE = \(decimals(outlineWidth));
    const float MA_SITE_DASHES = \(decimals(siteDashes));
    const float MA_DASH_DUTY = \(decimals(dashDuty));
    const float MA_CONSUMED_DIM = \(decimals(consumedDim));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float cover(float dist) {
        return smoothstep(-MA_MARK_FEATHER, MA_MARK_FEATHER, dist);
    }
    float hash(vec2 c) {
        return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
    }
    float band(float r, float centre) {
        return cover(MA_RING_HALF - abs(r - centre));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float value = clamp(v_value, 0.0, 1.0);
        float clock = max(v_clock, 0.0);
        float won = clamp(v_won, 0.0, 1.0);
        float sky = isCode(m, 0.0);
        float square = isCode(m, 1.0) + isCode(m, 2.0) + isCode(m, 15.0) + isCode(m, 16.0) + isCode(m, 17.0);
        square = square + isCode(m, 20.0) + isCode(m, 21.0);
        float dashed = isCode(m, 3.0);
        float pool = isCode(m, 4.0);
        float isRock = isCode(m, 5.0);
        float isBlocker = isCode(m, 6.0);
        float isNutrient = isCode(m, 7.0);
        float ringed = isCode(m, 8.0) + isCode(m, 19.0);
        float isVein = isCode(m, 9.0);
        float isBloom = isCode(m, 10.0);
        float matte = isCode(m, 11.0) + isCode(m, 13.0);
        float luminous = isCode(m, 12.0) + isCode(m, 14.0);
        float disc = isCode(m, 18.0);
        float isFuzz = isCode(m, 22.0);
        float isSpore = isCode(m, 23.0);
        float h = clamp(v_local, 0.0, 1.0);
        vec2 q = floor(v_aux.xy * MA_BACKDROP_DENSITY);
        vec2 f = fract(v_aux.xy * MA_BACKDROP_DENSITY) - 0.5;
        vec2 jitter = (vec2(hash(q + 17.0), hash(q + 31.0)) - 0.5) * (1.0 - 4.0 * MA_BACKDROP_RADIUS);
        float present = step(hash(q), MA_BACKDROP_PRESENCE);
        float speck = 1.0 - smoothstep(MA_BACKDROP_RADIUS * 0.5, MA_BACKDROP_RADIUS, length(f - jitter));
        vec3 gradient = mix(MA_CAVE, MA_CAVE_TOP, h);
        vec3 backdrop = mix(gradient, MA_SPORE, MA_BACKDROP_STRENGTH * speck * present);
        vec3 n = normalize(v_aux + vec3(0.0, 0.0, 0.000001));
        float diffuse = MA_AMBIENT + (1.0 - MA_AMBIENT) * max(dot(n, MA_LIGHT), 0.0);
        vec3 lit = v_base * diffuse;
        float copper = 0.0;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            vec2 w = v_pos.xy * MA_ROCK_FREQUENCY * (1.0 + fi) + vec2(fi * 1.7, fi * 2.3);
            float line = abs(sin(w.x + 1.3 * sin(w.y)));
            copper = max(copper, (1.0 - smoothstep(0.0, MA_ROCK_VEIN_WIDTH, line)) / (1.0 + fi));
        }
        vec3 rockRgb = mix(lit, MA_VEIN_COPPER * (0.6 + 0.4 * diffuse), 0.85 * copper);
        float pulse = 0.5 + 0.5 * sin(MA_TAU * (value * MA_VEIN_WAVES - clock * MA_VEIN_RATE));
        vec3 veinRgb = lit * (MA_VEIN_FLOOR + MA_VEIN_SWING * pulse) + MA_EMERALD * 0.25 * won;
        float facing = clamp(n.z, 0.0, 1.0);
        float rim = (1.0 - facing) * (1.0 - facing);
        float gills = 0.9 + 0.1 * cos(acos(facing) * MA_CAP_GILLS);
        vec3 capRgb = v_base * (MA_CAP_EMISSIVE + (1.0 - MA_CAP_EMISSIVE) * diffuse) * gills;
        capRgb = capRgb + MA_GLOW * (MA_CAP_RIM * rim + 0.25 * won);
        vec2 p = v_aux.xy;
        float r = length(p);
        float squareCover = cover(1.0 - max(abs(p.x), abs(p.y)));
        float discCover = cover(1.0 - r);
        float ringCover = band(r, 1.0 - MA_RING_HALF);
        float edge = max(abs(p.x), abs(p.y));
        float outline = squareCover * (1.0 - cover(1.0 - MA_OUTLINE - edge));
        float turn = fract(atan(p.y, p.x + 0.00001) / MA_TAU * MA_SITE_DASHES);
        float dash = cover(MA_DASH_DUTY * 0.5 - abs(turn - 0.5));
        float ripple = 0.5 + 0.5 * sin(MA_TAU * (r * MA_TOXIN_RINGS - clock * MA_TOXIN_RATE + value));
        vec3 poolRgb = v_base * (0.65 + 0.5 * ripple);
        float stone = cover(0.8 - r);
        vec3 blockerRgb = mix(MA_RING, v_base, stone);
        float orbRadius = 0.75;
        float orbZ = sqrt(max(1.0 - (r / orbRadius) * (r / orbRadius), 0.0));
        vec3 orbNormal = normalize(vec3(p / orbRadius, orbZ + 0.000001));
        float orbLight = MA_AMBIENT + (1.0 - MA_AMBIENT) * max(dot(orbNormal, MA_LIGHT), 0.0);
        float placed = step(0.5, value);
        float orbCover = max(cover(orbRadius - r), placed * band(r, 1.0 - MA_RING_HALF));
        float angle = atan(p.y, p.x + 0.00001);
        float filaments = 0.0;
        for (int g = 0; g < 4; g++) {
            float fg = float(g);
            float count = 3.0 * exp2(fg);
            float twist = hash(vec2(fg, 7.0)) * MA_TAU;
            float strand = 1.0 - smoothstep(0.0, MA_BLOOM_WIDTH, abs(sin(0.5 * count * angle + twist + 2.0 * r)));
            filaments = max(filaments, strand * step(0.22 * fg, r) * (1.0 - 0.15 * fg));
        }
        float bloomCover = max(filaments, cover(0.22 - r)) * discCover;
        vec3 bloomRgb = mix(v_base, MA_GLOW, 0.6 * (1.0 - clamp(r, 0.0, 1.0)));
        float along = clamp((p.y + 1.0) * 0.5, 0.0, 1.0);
        float strandCover = cover(1.0 - 0.7 * along - abs(p.x)) * cover(1.0 - abs(p.y)) * (1.0 - 0.6 * along);
        vec3 fuzzRgb = mix(MA_EMERALD, v_base, along);
        float sporeCover = (1.0 - smoothstep(0.2, 1.0, r)) * 0.8;
        vec3 rgb = v_base;
        rgb = mix(rgb, backdrop, sky);
        rgb = mix(rgb, rockRgb, isRock);
        rgb = mix(rgb, veinRgb, isVein);
        rgb = mix(rgb, lit, matte);
        rgb = mix(rgb, capRgb, luminous);
        rgb = mix(rgb, poolRgb, pool);
        rgb = mix(rgb, blockerRgb, isBlocker);
        rgb = mix(rgb, v_base * orbLight, isNutrient);
        rgb = mix(rgb, v_base * MA_CONSUMED_DIM, isCode(m, 8.0));
        rgb = mix(rgb, bloomRgb, isBloom);
        rgb = mix(rgb, fuzzRgb, isFuzz);
        float coverage = sky + isRock + isVein + matte + MA_CAP_ALPHA * luminous;
        coverage = coverage + squareCover * square + outline * dash * dashed;
        coverage = coverage + discCover * (pool + isBlocker + disc) + orbCover * isNutrient;
        coverage = coverage + ringCover * ringed + bloomCover * isBloom;
        coverage = coverage + strandCover * isFuzz + sporeCover * isSpore;
        float alpha = clamp(coverage, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`; zero means emerald), the glow factor
    /// (`a_uv.x`, 0 … 1) and the shell's radial coordinate (`a_uv.y`, 0 at the centre … 1 at the edge).
    public static let glowVertex: String = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_colour;
    out float v_factor;
    out float v_radius;
    void main() {
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_factor = clamp(a_uv.x, 0.0, 1.0);
        v_radius = clamp(a_uv.y, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`, `u_won`. Gain ``glowGain(gain:limit:)``
    /// (the gain capped by the limit), a won level raising every factor to 1, a white-hot centre fading to the rim;
    /// premultiplied RGBA in 0 … 1, drawn with additive blending.
    public static let glowFragment: String = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_factor;
    in float v_radius;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    uniform float u_won;
    out vec4 color;
    \(paletteBlock(["emerald", "glow"]))
    const float MA_GLOW_WEIGHT = \(decimals(glowWeight));
    const float MA_GLOW_CORE = \(decimals(glowCore));
    const float MA_MAX_GAIN = \(decimals(maxGlowGain));
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, MA_MAX_GAIN), clamp(u_glowLimit, 0.0, MA_MAX_GAIN));
        float won = clamp(u_won, 0.0, 1.0);
        vec3 rgb = mix(MA_EMERALD, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float factor = mix(clamp(v_factor, 0.0, 1.0), 1.0, won);
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        rgb = mix(rgb, MA_GLOW, MA_GLOW_CORE * fade);
        float alpha = clamp(MA_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """
}
