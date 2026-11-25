// StarlitCartoucheShaders — feature 453 (R02-G16-03) T-R02G1603-003 (FR-R02G1603-001, 002, 004, 006, 007;
// clarifications Q1–Q4). The two GLSL ES 3.00 programs of Starlit Cartouche held as source text (data: the core issues
// no GL call), with the names of every uniform they declare, their vertex attributes, the material codes shared with
// `StarlitCartoucheSceneGeometry`, the constants the sources are built from and the CPU references of what they
// compute. Presentation only: no rule is ever evaluated on these values, and nothing drawn is consulted by the rules.
//
// Chart program: the firmament backdrop, the corridors (symbol corridors not yet drawn dashed pearl, the others faint),
// the striped hazard tubes (coral while active, dim otherwise), the meteor-gold trails and their motion-blur ghosts,
// the pearl stars (layered core, limb and corona from the sphere normal) and their notch rings, the sapphire ship
// arrow, the beacon ring, the chosen destination's dashed ring, the cartouche grid and strokes (dashed pearl until
// drawn, solid gold once drawn), the actions bars, the beat track, the wait pips and the broken colour of a failure.
// Vertex streams (the geometry states the same contract): `a_uv.x` is the material code (``Material``, raw values 0 …
// 22 in declaration order), `a_uv.y` the primary local coordinate and `a_normal` either the sphere normal (stars) or a
// secondary local coordinate; ``Material/localCoordinate`` states per material what the geometry writes: on the
// firmament `a_uv.y` is the height h (0 at the bottom, 1 at the top) and `a_normal.x` the horizontal coordinate s (-1
// on the left edge, +1 on the right); on a strip (a ribbon or ring) `a_uv.y` is the across coordinate d, -1 on one long
// side and +1 on the other, and `a_normal.x` carries, where the material needs it, the distance along the ribbon in
// world units (dashes, hazard stripes), the along fraction 0 … 1 from tail to head (trails, ghosts; a ghost's fade 0 …
// 1 in `a_normal.y`) or the angle fraction 0 … 1 around a ring (notches with the notch count in `a_normal.y`, the
// chosen ring's dashes; the seam vertex is duplicated with 1.0); on a star `a_normal` is the sphere normal in world
// space and `a_uv.y` 0 (a level-2 flat disc: normal ``viewDirection``, `a_uv.y` the radial coordinate, 0 at the centre
// and 1 on the rim); on the ship's quad `a_normal.xy` is the arrow-local coordinate (u -1 at the tail … +1 at the tip,
// v -1 … +1 across; the quad spans ``arrowQuadExtent``); on a fan (bars, pips) `a_uv.y` is 0 at the centre vertex and 1
// on every outline vertex.
//
// Signed-distance shading: the soft outline coverage 1 - smoothstep(1 - ``edgeFeather``, 1, |d|)
// (``edgeCoverage(local:)``) on every mark; the firmament is opaque. Dashes (undrawn symbol corridors and cartouche
// strokes) keep ``dashDuty`` of each ``dashPeriod`` along (``dashCoverage(along:)``); hazard stripes slant by
// ``hazardSlant`` and darken the gaps to ``hazardGap`` (``hazardStripe(along:across:)``); a notch ring is lit at (index
// mod 6) + 1 notches and rests at ``ringRest`` between (``notchCoverage(angle:count:)``); the chosen ring has
// ``ringDashes`` dashes (``ringDashCoverage(angle:)``); the ship is a dart whose signed distance
// (``arrowDistance(u:v:)``) is feathered by ``arrowFeather``, with a lighter keel. A star is shaded in three layers
// from mu = n · ``viewDirection`` (``starShade(mu:)``): the limb from the pearl shade to pearl, the core lifted toward
// white, the corona toward the glow colour at grazing angles. The firmament is a vertical gradient from night to night
// top with sparse hashed specks (``speckCoverage(height:horizontal:angle:)``, under 5 % of its pixels) on a cylinder of
// ``cellsAround`` cells turned by `u_firmamentAngle` (``firmamentAngle(time:reduceMotion:)``: 0.02 rad/s, 0 with Reduce
// Motion). A won level (`u_won`, 0 … 1) flares the trails, ghosts and drawn strokes toward the trail-glow colour by
// ``flareLift`` and seals the cartouche grid in gold by ``sealLift`` at every tier.
//
// Glow program: the glow shells around the stars, the ship and the lit trails, drawn additively and last. The colour is
// carried in `a_normal` (a zero colour falls back to the glow, ship-glow or trail-glow colour by kind), `a_uv.x` is 2 ·
// kind + factor (``GlowKind``: 0 star, 1 ship, 2 trail; factor 0 … 1) and `a_uv.y` the shell's radial coordinate r, 0
// on its inner edge and 1 on its outer edge. The alpha is ``glowWeight`` times the gain, the factor and (1 - r)²; a
// trail shell's factor is times ``trailRest`` on a level not won, rising to 1 with `u_won`, so the trails flare on a
// won level; the gain is `u_glowGain` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing
// the presenter passes ``glowGainCap`` as the limit, so no glow, the won flare included, exceeds the cap.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1) and
// `a_uv` (location 2). Every source starts with `#version 300 es` and states one float precision. Plain uniforms in the
// default block (at most 16 vec4 slots per program; the chart program uses 6: u_mvp 4, u_won and u_firmamentAngle 1
// each; the glow program 7: u_mvp 4, u_glowGain, u_glowLimit and u_won 1 each), no texture samplers, no image assets,
// no `discard` and no loops. Output is premultiplied alpha. Palette constants are written with six fixed decimals from
// `StarlitCartouchePalette`, so the shader colours equal the CPU's within 1e-6.
//
// Feature 454 (R02-G16-04) T-R02G1604-002 (FR-R02G1604-003; clarification Q3) adds material 22 `preview`: the launch
// preview's dashed sapphire ribbon (the ship colour; a strip with `a_normal.x` the distance along in world units,
// dashed like an undrawn symbol corridor by ``dashCoverage(along:)``).

import Foundation

/// The GLSL ES 3.00 sources of Starlit Cartouche's chart and glow programs, their uniform and attribute names, the
/// material codes, the constants they are built from and the CPU references of what they compute (FR-R02G1603-001,
/// 002, 004).
public enum StarlitCartoucheShaders {
    /// A chart-program material code, written into `a_uv.x` of a chart vertex (shared with
    /// `StarlitCartoucheSceneGeometry`; raw values 0 … 22 in declaration order).
    public enum Material: Int, Sendable, CaseIterable, Hashable {
        /// The firmament backdrop quad (opaque; `a_uv.y` height, `a_normal.x` horizontal coordinate).
        case firmament = 0
        /// A corridor off the symbol, or a symbol corridor already drawn: a faint ribbon (strip).
        case corridor = 1
        /// A symbol corridor not yet drawn: a dashed pearl ribbon (strip; `a_normal.x` distance along).
        case symbolDash = 2
        /// An active hazard tube: coral stripes (strip; `a_normal.x` distance along).
        case hazardActive = 3
        /// An idle hazard tube: dim stripes (strip; `a_normal.x` distance along).
        case hazardIdle = 4
        /// A flown leg's meteor-gold trail, brighter toward its head (strip; `a_normal.x` along fraction).
        case trail = 5
        /// A motion-blur ghost of a trail's end (strip; `a_normal.x` along fraction, `a_normal.y` fade; level-0 and 1).
        case trailGhost = 6
        /// A star sphere (normal = sphere normal) or a level-2 flat disc (normal ``viewDirection``, `a_uv.y` radial).
        case starCore = 7
        /// The ring of (index mod 6) + 1 notches around a star (strip ring; `a_normal.x` angle fraction, `a_normal.y`
        /// notch count).
        case starNotches = 8
        /// The sapphire ship arrow (a quad; `a_normal.xy` arrow-local coordinate).
        case ship = 9
        /// The beacon ring around the beacon star (strip ring).
        case beaconRing = 10
        /// The chosen destination's dashed sapphire ring (strip ring; `a_normal.x` angle fraction).
        case chosenRing = 11
        /// A line of the cartouche's 5 × 5 grid (strip); sealed in gold on a won level.
        case cartoucheGrid = 12
        /// A symbol stroke in the cartouche not yet drawn: dashed pearl (strip; `a_normal.x` distance along).
        case strokeUndrawn = 13
        /// A symbol stroke in the cartouche once drawn: solid gold (strip).
        case strokeDrawn = 14
        /// A lit actions bar, an action left (fan).
        case actionsLit = 15
        /// An unlit actions bar, an action spent (fan).
        case actionsUnlit = 16
        /// The beat track's filled part, beat / deadline of its length (fan).
        case beatTrack = 17
        /// The beat track's unfilled rest (fan; the unlit gauge colour).
        case beatTrackRest = 18
        /// A lit wait pip, up to the chosen wait (fan).
        case waitLit = 19
        /// An unlit wait pip (fan).
        case waitUnlit = 20
        /// What a failure names: the failing leg, the missed star's ring, the hazard met, the stray stroke or the gauge
        /// a deadline or budget failure marks (strip).
        case broken = 21
        /// The launch preview (feature 454): a dashed ribbon in the ship colour from the ship's star at the launch beat
        /// to the destination at arrival (strip; `a_normal.x` distance along).
        case preview = 22

        /// How the geometry fills `a_uv.y` and `a_normal` for a material.
        public enum LocalCoordinate: Sendable, Hashable {
            /// The firmament: `a_uv.y` height h 0 … 1 (bottom to top), `a_normal.x` horizontal s -1 … +1.
            case firmament
            /// A strip: `a_uv.y` d -1 on one long side, +1 on the other; `a_normal` unused (zero).
            case strip
            /// A strip with `a_normal.x` the distance along it in world units from its start (dashes, stripes).
            case stripAlong
            /// A strip with `a_normal.x` the along fraction 0 (tail) … 1 (head).
            case trail
            /// A strip with `a_normal.x` the along fraction and `a_normal.y` the ghost's fade
            /// (``ghostFade(index:count:)``).
            case ghost
            /// A star: `a_normal` the sphere normal, `a_uv.y` 0 (a flat disc: normal ``viewDirection``, `a_uv.y`
            /// radial).
            case sphere
            /// A ring strip with `a_normal.x` the angle fraction 0 … 1 (seam duplicated with 1.0) and, on a notch ring,
            /// `a_normal.y` the notch count 1 … 6.
            case ring
            /// The ship's quad: `a_normal.xy` the arrow-local coordinate (u tail -1 … tip +1, v -1 … +1), `a_uv.y` 0.
            case arrow
            /// A fan from a centre vertex (`a_uv.y` 0) to the outline's corners (`a_uv.y` 1).
            case fan
        }

        /// The `a_uv.x` value of the material.
        public var code: Float { Float(rawValue) }

        /// The material's colour as the chart vertex shader selects it (before the fragment shader's gradient, specks,
        /// stripes, star layers, keel and won flare).
        public var colour: SIMD3<Double> {
            switch self {
            case .firmament: StarlitCartouchePalette.night
            case .corridor: StarlitCartouchePalette.corridor
            case .symbolDash, .strokeUndrawn: StarlitCartouchePalette.symbolDash
            case .hazardActive: StarlitCartouchePalette.hazardActive
            case .hazardIdle: StarlitCartouchePalette.hazardIdle
            case .trail, .trailGhost, .strokeDrawn: StarlitCartouchePalette.trail
            case .starCore: StarlitCartouchePalette.pearl
            case .starNotches, .cartoucheGrid: StarlitCartouchePalette.pearlShade
            case .ship: StarlitCartouchePalette.ship
            case .beaconRing: StarlitCartouchePalette.beacon
            case .chosenRing: StarlitCartouchePalette.chosen
            case .actionsLit: StarlitCartouchePalette.actionsLit
            case .actionsUnlit, .beatTrackRest: StarlitCartouchePalette.actionsUnlit
            case .beatTrack: StarlitCartouchePalette.beatTrack
            case .waitLit: StarlitCartouchePalette.waitLit
            case .waitUnlit: StarlitCartouchePalette.waitUnlit
            case .broken: StarlitCartouchePalette.broken
            case .preview: StarlitCartouchePalette.ship
            }
        }

        /// Whether the material is opaque over its whole area (no soft outline): only the firmament.
        public var isSolid: Bool { self == .firmament }

        /// How the geometry fills `a_uv.y` and `a_normal` for the material.
        public var localCoordinate: LocalCoordinate {
            switch self {
            case .firmament: .firmament
            case .symbolDash, .hazardActive, .hazardIdle, .strokeUndrawn, .preview: .stripAlong
            case .trail: .trail
            case .trailGhost: .ghost
            case .starCore: .sphere
            case .starNotches, .chosenRing: .ring
            case .ship: .arrow
            case .corridor, .beaconRing, .cartoucheGrid, .strokeDrawn, .broken: .strip
            case .actionsLit, .actionsUnlit, .beatTrack, .beatTrackRest, .waitLit, .waitUnlit: .fan
            }
        }
    }

    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around a star (a zero colour counts as the glow colour).
        case star = 0
        /// A glow shell around the ship (a zero colour counts as the ship-glow colour).
        case ship = 1
        /// A glow shell around a lit trail (a zero colour counts as the trail-glow colour); its factor is also times
        /// ``StarlitCartoucheShaders/trailRest`` on a level not won, rising to 1 with `u_won`.
        case trail = 2

        /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts
        /// as 0).
        public func code(factor: Double) -> Double {
            let f: Double = factor.isFinite ? min(max(factor, 0), 1) : 0
            return Double(2 * rawValue) + f
        }

        /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 2, factor
        /// x - 2 · kind clamped to 0 … 1 (x clamped to 0 … 5; non-finite counts as 0).
        public static func decode(_ x: Double) -> (kind: GlowKind, factor: Double) {
            let v: Double = x.isFinite ? min(max(x, 0), 5) : 0
            let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 2)
            let factor: Double = min(max(v - Double(2 * k), 0), 1)
            return (kind: GlowKind(rawValue: k) ?? .star, factor: factor)
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
    /// `float`: the won level's light, 0 … 1 (chart vertex stage: flares the trails, ghosts and drawn strokes and seals
    /// the cartouche grid; glow fragment stage: raises the trail shells' factor to 1); 0 on a level not won.
    public static let wonUniform = "u_won"
    /// `float`: the firmament's turn about the vertical axis in radians (chart fragment stage):
    /// ``firmamentAngle(time:reduceMotion:)``.
    public static let firmamentAngleUniform = "u_firmamentAngle"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the chart program declares, each once, in order of declaration (vertex stage first).
    public static let chartUniforms: [String] = [mvpUniform, wonUniform, firmamentAngleUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform]

    /// The uniform lists per program name (`chart`, `glow`).
    public static let uniformNames: [String: [String]] = ["chart": chartUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette colour.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "SC_NIGHT", colour: StarlitCartouchePalette.night),
        (name: "SC_NIGHT_TOP", colour: StarlitCartouchePalette.nightTop),
        (name: "SC_SPECK", colour: StarlitCartouchePalette.speck),
        (name: "SC_PEARL", colour: StarlitCartouchePalette.pearl),
        (name: "SC_PEARL_SHADE", colour: StarlitCartouchePalette.pearlShade),
        (name: "SC_CORRIDOR", colour: StarlitCartouchePalette.corridor),
        (name: "SC_SYMBOL_DASH", colour: StarlitCartouchePalette.symbolDash),
        (name: "SC_TRAIL", colour: StarlitCartouchePalette.trail),
        (name: "SC_TRAIL_GLOW", colour: StarlitCartouchePalette.trailGlow),
        (name: "SC_SHIP", colour: StarlitCartouchePalette.ship),
        (name: "SC_SHIP_GLOW", colour: StarlitCartouchePalette.shipGlow),
        (name: "SC_BEACON", colour: StarlitCartouchePalette.beacon),
        (name: "SC_CHOSEN", colour: StarlitCartouchePalette.chosen),
        (name: "SC_HAZARD_ACTIVE", colour: StarlitCartouchePalette.hazardActive),
        (name: "SC_HAZARD_IDLE", colour: StarlitCartouchePalette.hazardIdle),
        (name: "SC_ACTIONS_LIT", colour: StarlitCartouchePalette.actionsLit),
        (name: "SC_ACTIONS_UNLIT", colour: StarlitCartouchePalette.actionsUnlit),
        (name: "SC_BEAT_TRACK", colour: StarlitCartouchePalette.beatTrack),
        (name: "SC_WAIT_LIT", colour: StarlitCartouchePalette.waitLit),
        (name: "SC_WAIT_UNLIT", colour: StarlitCartouchePalette.waitUnlit),
        (name: "SC_BROKEN", colour: StarlitCartouchePalette.broken),
        (name: "SC_GLOW", colour: StarlitCartouchePalette.glow),
    ]

    /// The unit direction from the scene toward the authored eye (eye (1.2, 1.0, 2.8) looking at (0, -0.2, 0)), the
    /// view direction the star layers are shaded against; a level-2 flat disc writes it as its normal.
    public static let viewDirection: SIMD3<Double> = {
        let raw: SIMD3<Double> = SIMD3<Double>(1.2, 1.2, 2.8)
        let length: Double = (raw * raw).sum().squareRoot()
        return raw / length
    }()

    /// The width of the soft outline as a share of the across coordinate: coverage falls from 1 at |d| = 1 - feather
    /// to 0 at |d| = 1.
    public static let edgeFeather: Double = 0.25

    /// 2π as written into the chart fragment shader (the firmament angle is wrapped by it).
    public static let tau: Double = 2 * Double.pi
    /// The firmament's turn rate in radians per second of presentation time (clarification Q1).
    public static let firmamentTurnRate: Double = 0.02
    /// Half the azimuth span of the firmament quad in radians: s = ±1 maps to ±``skySpan`` about the turn angle.
    public static let skySpan: Double = 0.6
    /// The speck cells around the firmament's full turn (a whole number, so the cells wrap seamlessly).
    public static let cellsAround: Double = 720
    /// The speck cells per radian of azimuth, ``cellsAround`` / 2π.
    public static let cellsPerRadian: Double = 720 / (2 * Double.pi)
    /// The speck cells from the bottom (h = 0) to the top (h = 1) of the firmament.
    public static let cellsUp: Double = 80
    /// The share of cells holding a speck.
    public static let speckDensity: Double = 0.06
    /// A speck's radius in cell units: full inside half of it, fading to 0 at it.
    public static let speckRadius: Double = 0.22
    /// How far a speck's centre is jittered inside its cell, in cell units (±half of it).
    public static let speckJitter: Double = 0.5
    /// The dimmest speck's share of the speck colour (the brightest has 1).
    public static let speckDim: Double = 0.45

    /// The period of the dashes along an undrawn symbol corridor or cartouche stroke, in world units.
    public static let dashPeriod: Double = 0.06
    /// The share of a dash period that is drawn, from its start.
    public static let dashDuty: Double = 0.55
    /// The period of a hazard tube's stripes along it, in world units.
    public static let hazardPeriod: Double = 0.05
    /// The share of a hazard stripe period at the full hazard colour, from its start.
    public static let hazardDuty: Double = 0.5
    /// How far a stripe slants: the along distance added per unit of the across coordinate.
    public static let hazardSlant: Double = 0.02
    /// The share of the hazard colour kept in a stripe gap.
    public static let hazardGap: Double = 0.45
    /// The share of the trail colour at a trail's tail (rising to 1 at its head).
    public static let trailTail: Double = 0.6
    /// How far a won level lifts the trails, ghosts and drawn strokes toward the trail-glow colour, times `u_won`.
    public static let flareLift: Double = 0.6
    /// The alpha of a ghost at fade 1 and its head, times its fade and along fraction.
    public static let ghostAlpha: Double = 0.5
    /// The mu below which a star's limb darkens from pearl toward the pearl shade (smoothstep(0, limbEdge, mu)).
    public static let limbEdge: Double = 0.5
    /// The mu where a star's core begins to lift toward white.
    public static let coreStart: Double = 0.85
    /// How far a star's core (mu = 1) is lifted toward white.
    public static let coreLift: Double = 0.3
    /// The power of the corona's rise toward grazing angles, (1 - mu)^power.
    public static let coronaPower: Double = 4
    /// How far the corona lifts a star's limb toward the glow colour at mu = 0.
    public static let coronaLift: Double = 0.35
    /// The share of a notch period around a star's ring that is a lit notch, centred in the period.
    public static let notchDuty: Double = 0.24
    /// The alpha of a notch ring between its notches.
    public static let ringRest: Double = 0.4
    /// The dashes around the chosen destination's ring.
    public static let ringDashes: Double = 12
    /// The share of a chosen-ring dash period that is drawn, from its start.
    public static let ringDashDuty: Double = 0.6
    /// The arrow-local u of the dart's notch apex (the tail corners are at (-1, ±1), the tip at (1, 0)).
    public static let arrowNotch: Double = -0.4
    /// The soft edge of the dart in arrow-local units: coverage smoothstep(-feather, feather, distance).
    public static let arrowFeather: Double = 0.06
    /// The arrow-local extent the geometry's ship quad spans on each axis (-extent … +extent), room for the feather.
    public static let arrowQuadExtent: Double = 1.25
    /// How far the ship's keel (v = 0) is lifted toward the ship-glow colour, falling to 0 at |v| = 1/3.
    public static let keelLift: Double = 0.35
    /// The alpha of a cartouche grid line on a level not won.
    public static let gridAlpha: Double = 0.35
    /// How far a won level seals the cartouche grid: its colour toward gold and its alpha toward 1, times `u_won`.
    public static let sealLift: Double = 0.8

    /// The alpha weight of the glow, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// The share of a trail shell's factor shown on a level not won (it rises to 1 with `u_won`).
    public static let trailRest: Double = 0.5
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

    /// 1 / |(1, 1 + ``arrowNotch``)|, the normalisation of the dart's notch edges.
    static let arrowNotchNorm: Double = 1 / (1 + (1 + arrowNotch) * (1 + arrowNotch)).squareRoot()

    /// 1 / √5, the normalisation of the dart's outer edges.
    static let arrowEdgeNorm: Double = 1 / 5.0.squareRoot()

    /// The chart vertex shader. Uniforms: `u_mvp`, `u_won`. Selects the material colour from `a_uv.x`; passes the
    /// secondary coordinate or normal (`a_normal`), the material code, the local coordinate and the won light.
    public static let chartVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_won;
    out vec3 v_base;
    out vec3 v_aux;
    out float v_material;
    out float v_local;
    out float v_won;
    const vec3 SC_NIGHT = \(vec3Literal(StarlitCartouchePalette.night));
    const vec3 SC_CORRIDOR = \(vec3Literal(StarlitCartouchePalette.corridor));
    const vec3 SC_SYMBOL_DASH = \(vec3Literal(StarlitCartouchePalette.symbolDash));
    const vec3 SC_HAZARD_ACTIVE = \(vec3Literal(StarlitCartouchePalette.hazardActive));
    const vec3 SC_HAZARD_IDLE = \(vec3Literal(StarlitCartouchePalette.hazardIdle));
    const vec3 SC_TRAIL = \(vec3Literal(StarlitCartouchePalette.trail));
    const vec3 SC_PEARL = \(vec3Literal(StarlitCartouchePalette.pearl));
    const vec3 SC_PEARL_SHADE = \(vec3Literal(StarlitCartouchePalette.pearlShade));
    const vec3 SC_SHIP = \(vec3Literal(StarlitCartouchePalette.ship));
    const vec3 SC_BEACON = \(vec3Literal(StarlitCartouchePalette.beacon));
    const vec3 SC_CHOSEN = \(vec3Literal(StarlitCartouchePalette.chosen));
    const vec3 SC_ACTIONS_LIT = \(vec3Literal(StarlitCartouchePalette.actionsLit));
    const vec3 SC_ACTIONS_UNLIT = \(vec3Literal(StarlitCartouchePalette.actionsUnlit));
    const vec3 SC_BEAT_TRACK = \(vec3Literal(StarlitCartouchePalette.beatTrack));
    const vec3 SC_WAIT_LIT = \(vec3Literal(StarlitCartouchePalette.waitLit));
    const vec3 SC_WAIT_UNLIT = \(vec3Literal(StarlitCartouchePalette.waitUnlit));
    const vec3 SC_BROKEN = \(vec3Literal(StarlitCartouchePalette.broken));
    const float SC_MAX_MATERIAL = \(fixed(Double(Material.allCases.count - 1)));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, SC_MAX_MATERIAL);
        vec3 base = SC_NIGHT;
        base = mix(base, SC_CORRIDOR, isCode(m, 1.0));
        base = mix(base, SC_SYMBOL_DASH, isCode(m, 2.0));
        base = mix(base, SC_HAZARD_ACTIVE, isCode(m, 3.0));
        base = mix(base, SC_HAZARD_IDLE, isCode(m, 4.0));
        base = mix(base, SC_TRAIL, isCode(m, 5.0));
        base = mix(base, SC_TRAIL, isCode(m, 6.0));
        base = mix(base, SC_PEARL, isCode(m, 7.0));
        base = mix(base, SC_PEARL_SHADE, isCode(m, 8.0));
        base = mix(base, SC_SHIP, isCode(m, 9.0));
        base = mix(base, SC_BEACON, isCode(m, 10.0));
        base = mix(base, SC_CHOSEN, isCode(m, 11.0));
        base = mix(base, SC_PEARL_SHADE, isCode(m, 12.0));
        base = mix(base, SC_SYMBOL_DASH, isCode(m, 13.0));
        base = mix(base, SC_TRAIL, isCode(m, 14.0));
        base = mix(base, SC_ACTIONS_LIT, isCode(m, 15.0));
        base = mix(base, SC_ACTIONS_UNLIT, isCode(m, 16.0));
        base = mix(base, SC_BEAT_TRACK, isCode(m, 17.0));
        base = mix(base, SC_ACTIONS_UNLIT, isCode(m, 18.0));
        base = mix(base, SC_WAIT_LIT, isCode(m, 19.0));
        base = mix(base, SC_WAIT_UNLIT, isCode(m, 20.0));
        base = mix(base, SC_BROKEN, isCode(m, 21.0));
        base = mix(base, SC_SHIP, isCode(m, 22.0));
        v_base = base;
        v_aux = a_normal;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0);
        v_won = clamp(u_won, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The chart fragment shader. Uniform: `u_firmamentAngle`. The firmament gradient and turning specks
    /// (``firmamentColour(height:horizontal:angle:)``), signed-distance coverage from the local coordinates
    /// (``edgeCoverage(local:)``, ``dashCoverage(along:)``, ``hazardStripe(along:across:)``,
    /// ``notchCoverage(angle:count:)``, ``ringDashCoverage(angle:)``, ``arrowCoverage(u:v:)``), the layered stars
    /// (``starShade(mu:)``), the trail taper and ghosts (``trailColour(along:won:)``, ``ghostAlpha(along:fade:)``) and
    /// the won flare and seal. Premultiplied.
    public static let chartFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_aux;
    in float v_material;
    in float v_local;
    in float v_won;
    uniform float u_firmamentAngle;
    out vec4 color;
    const vec3 SC_NIGHT = \(vec3Literal(StarlitCartouchePalette.night));
    const vec3 SC_NIGHT_TOP = \(vec3Literal(StarlitCartouchePalette.nightTop));
    const vec3 SC_SPECK = \(vec3Literal(StarlitCartouchePalette.speck));
    const vec3 SC_PEARL = \(vec3Literal(StarlitCartouchePalette.pearl));
    const vec3 SC_PEARL_SHADE = \(vec3Literal(StarlitCartouchePalette.pearlShade));
    const vec3 SC_TRAIL = \(vec3Literal(StarlitCartouchePalette.trail));
    const vec3 SC_TRAIL_GLOW = \(vec3Literal(StarlitCartouchePalette.trailGlow));
    const vec3 SC_SHIP_GLOW = \(vec3Literal(StarlitCartouchePalette.shipGlow));
    const vec3 SC_GLOW = \(vec3Literal(StarlitCartouchePalette.glow));
    const vec3 SC_VIEW_DIR = \(vec3Literal(viewDirection));
    const float SC_EDGE_FEATHER = \(fixed(edgeFeather));
    const float SC_TAU = \(fixed(tau));
    const float SC_SKY_SPAN = \(fixed(skySpan));
    const float SC_CELLS_AROUND = \(fixed(cellsAround));
    const float SC_CELLS_PER_RADIAN = \(fixed(cellsPerRadian));
    const float SC_CELLS_UP = \(fixed(cellsUp));
    const float SC_SPECK_DENSITY = \(fixed(speckDensity));
    const float SC_SPECK_RADIUS = \(fixed(speckRadius));
    const float SC_SPECK_JITTER = \(fixed(speckJitter));
    const float SC_SPECK_DIM = \(fixed(speckDim));
    const float SC_DASH_PERIOD = \(fixed(dashPeriod));
    const float SC_DASH_DUTY = \(fixed(dashDuty));
    const float SC_HAZARD_PERIOD = \(fixed(hazardPeriod));
    const float SC_HAZARD_DUTY = \(fixed(hazardDuty));
    const float SC_HAZARD_SLANT = \(fixed(hazardSlant));
    const float SC_HAZARD_GAP = \(fixed(hazardGap));
    const float SC_TRAIL_TAIL = \(fixed(trailTail));
    const float SC_FLARE_LIFT = \(fixed(flareLift));
    const float SC_GHOST_ALPHA = \(fixed(ghostAlpha));
    const float SC_LIMB_EDGE = \(fixed(limbEdge));
    const float SC_CORE_START = \(fixed(coreStart));
    const float SC_CORE_LIFT = \(fixed(coreLift));
    const float SC_CORONA_POWER = \(fixed(coronaPower));
    const float SC_CORONA_LIFT = \(fixed(coronaLift));
    const float SC_NOTCH_DUTY = \(fixed(notchDuty));
    const float SC_RING_REST = \(fixed(ringRest));
    const float SC_RING_DASHES = \(fixed(ringDashes));
    const float SC_RING_DASH_DUTY = \(fixed(ringDashDuty));
    const float SC_ARROW_NOTCH = \(fixed(arrowNotch));
    const float SC_ARROW_NOTCH_NORM = \(fixed(arrowNotchNorm));
    const float SC_ARROW_EDGE_NORM = \(fixed(arrowEdgeNorm));
    const float SC_ARROW_FEATHER = \(fixed(arrowFeather));
    const float SC_KEEL_LIFT = \(fixed(keelLift));
    const float SC_GRID_ALPHA = \(fixed(gridAlpha));
    const float SC_SEAL_LIFT = \(fixed(sealLift));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float hash(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float arrowDistance(vec2 p) {
        vec2 tip = p - vec2(1.0, 0.0);
        float e1 = dot(tip, vec2(1.0, 2.0)) * SC_ARROW_EDGE_NORM;
        float e2 = dot(tip, vec2(1.0, -2.0)) * SC_ARROW_EDGE_NORM;
        vec2 q = p - vec2(SC_ARROW_NOTCH, 0.0);
        float n1 = dot(q, vec2(-1.0, -(1.0 + SC_ARROW_NOTCH))) * SC_ARROW_NOTCH_NORM;
        float n2 = dot(q, vec2(-1.0, 1.0 + SC_ARROW_NOTCH)) * SC_ARROW_NOTCH_NORM;
        return min(min(-e1, -e2), max(-n1, -n2));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float edge = 1.0 - smoothstep(1.0 - SC_EDGE_FEATHER, 1.0, d);
        float won = clamp(v_won, 0.0, 1.0);
        float sky = isCode(m, 0.0);
        float h = clamp(v_local, 0.0, 1.0);
        float turn = mod(u_firmamentAngle, SC_TAU);
        float azimuth = clamp(v_aux.x, -1.0, 1.0) * SC_SKY_SPAN + turn;
        vec2 cellPos = vec2(azimuth * SC_CELLS_PER_RADIAN, h * SC_CELLS_UP);
        vec2 cell = floor(cellPos);
        cell.x = mod(cell.x, SC_CELLS_AROUND);
        float pick = hash(cell);
        float jitter = hash(cell + vec2(17.0, 59.0));
        vec2 f = fract(cellPos) - 0.5 - (vec2(jitter, fract(jitter * 7.0)) - 0.5) * SC_SPECK_JITTER;
        float speck = step(1.0 - SC_SPECK_DENSITY, pick);
        speck = speck * (1.0 - smoothstep(SC_SPECK_RADIUS * 0.5, SC_SPECK_RADIUS, length(f)));
        vec3 gradient = mix(SC_NIGHT, SC_NIGHT_TOP, h);
        vec3 firmament = mix(gradient, SC_SPECK, speck * mix(SC_SPECK_DIM, 1.0, fract(pick * 13.0)));
        float along = v_aux.x;
        float dash = 1.0 - step(SC_DASH_DUTY, fract(along / SC_DASH_PERIOD));
        float stripe = 1.0 - step(SC_HAZARD_DUTY, fract((along + v_local * SC_HAZARD_SLANT) / SC_HAZARD_PERIOD));
        float t = clamp(v_aux.x, 0.0, 1.0);
        float fade = clamp(v_aux.y, 0.0, 1.0);
        float nl = length(v_aux);
        float facing = clamp(dot(v_aux / max(nl, 0.0001), SC_VIEW_DIR), 0.0, 1.0);
        float mu = mix(1.0, facing, step(0.0001, nl));
        vec3 star = mix(SC_PEARL_SHADE, SC_PEARL, smoothstep(0.0, SC_LIMB_EDGE, mu));
        star = mix(star, vec3(1.0), SC_CORE_LIFT * smoothstep(SC_CORE_START, 1.0, mu));
        star = mix(star, SC_GLOW, SC_CORONA_LIFT * pow(1.0 - mu, SC_CORONA_POWER));
        float count = clamp(floor(v_aux.y + 0.5), 1.0, 6.0);
        float notch = 1.0 - step(SC_NOTCH_DUTY * 0.5, abs(fract(t * count) - 0.5));
        float ringDash = 1.0 - step(SC_RING_DASH_DUTY, fract(t * SC_RING_DASHES));
        float arrow = smoothstep(-SC_ARROW_FEATHER, SC_ARROW_FEATHER, arrowDistance(v_aux.xy));
        float keel = SC_KEEL_LIFT * max(1.0 - abs(v_aux.y) * 3.0, 0.0);
        float isHazard = isCode(m, 3.0) + isCode(m, 4.0);
        float isGolden = isCode(m, 5.0) + isCode(m, 6.0) + isCode(m, 14.0);
        vec3 rgb = mix(v_base, firmament, sky);
        rgb = mix(rgb, v_base * mix(SC_HAZARD_GAP, 1.0, stripe), isHazard);
        rgb = mix(rgb, v_base * mix(SC_TRAIL_TAIL, 1.0, t), isCode(m, 5.0));
        rgb = mix(rgb, SC_TRAIL_GLOW, SC_FLARE_LIFT * won * isGolden);
        rgb = mix(rgb, star, isCode(m, 7.0));
        rgb = mix(rgb, SC_PEARL, notch * isCode(m, 8.0));
        rgb = mix(rgb, SC_SHIP_GLOW, keel * isCode(m, 9.0));
        rgb = mix(rgb, SC_TRAIL, SC_SEAL_LIFT * won * isCode(m, 12.0));
        float coverage = edge;
        coverage = coverage * mix(1.0, dash, isCode(m, 2.0) + isCode(m, 13.0) + isCode(m, 22.0));
        coverage = coverage * mix(1.0, SC_GHOST_ALPHA * fade * t, isCode(m, 6.0));
        coverage = coverage * mix(1.0, mix(SC_RING_REST, 1.0, notch), isCode(m, 8.0));
        coverage = coverage * mix(1.0, ringDash, isCode(m, 11.0));
        coverage = coverage * mix(1.0, mix(SC_GRID_ALPHA, 1.0, SC_SEAL_LIFT * won), isCode(m, 12.0));
        coverage = mix(coverage, arrow, isCode(m, 9.0));
        coverage = mix(coverage, 1.0, sky);
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
        float x = clamp(a_uv.x, 0.0, 5.0);
        float kind = clamp(floor(x * 0.5), 0.0, 2.0);
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
    const vec3 SC_GLOW = \(vec3Literal(StarlitCartouchePalette.glow));
    const vec3 SC_SHIP_GLOW = \(vec3Literal(StarlitCartouchePalette.shipGlow));
    const vec3 SC_TRAIL_GLOW = \(vec3Literal(StarlitCartouchePalette.trailGlow));
    const float SC_GLOW_WEIGHT = \(fixed(glowWeight));
    const float SC_TRAIL_REST = \(fixed(trailRest));
    const float SC_MAX_GAIN = \(fixed(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, SC_MAX_GAIN), clamp(u_glowLimit, 0.0, SC_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isShip = isCode(kind, 1.0);
        float isTrail = isCode(kind, 2.0);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 fallback = mix(mix(SC_GLOW, SC_SHIP_GLOW, isShip), SC_TRAIL_GLOW, isTrail);
        vec3 rgb = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float factor = clamp(v_factor, 0.0, 1.0) * mix(1.0, mix(SC_TRAIL_REST, 1.0, won), isTrail);
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        float alpha = clamp(SC_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The firmament's turn angle in radians the presenter passes as `u_firmamentAngle`: ``firmamentTurnRate`` times
    /// `time` (seconds of presentation time), or 0 with Reduce Motion; a non-finite time counts as 0, so the result is
    /// finite for any input.
    public static func firmamentAngle(time: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion, time.isFinite else { return 0 }
        let angle: Double = firmamentTurnRate * time
        return angle.isFinite ? angle : 0
    }

    /// The soft-outline coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 … 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// The dash at distance `along` (world units) of an undrawn symbol corridor, cartouche stroke or the launch preview
    /// (feature 454): 1 where
    /// fract(along / ``dashPeriod``) < ``dashDuty``, else 0 (non-finite counts as 0, a dash start).
    public static func dashCoverage(along: Double) -> Double {
        let a: Double = along.isFinite ? along : 0
        return fract(a / dashPeriod) < dashDuty ? 1 : 0
    }

    /// The hazard stripe at distance `along` and across coordinate `across` (clamped to -1 … 1): 1 (full hazard colour)
    /// where fract((along + across · ``hazardSlant``) / ``hazardPeriod``) < ``hazardDuty``, else 0 (the gap, the hazard
    /// colour times ``hazardGap``); non-finite values count as 0.
    public static func hazardStripe(along: Double, across: Double) -> Double {
        let a: Double = along.isFinite ? along : 0
        let d: Double = across.isFinite ? min(max(across, -1), 1) : 0
        return fract((a + d * hazardSlant) / hazardPeriod) < hazardDuty ? 1 : 0
    }

    /// The notch at angle fraction `angle` (clamped to 0 … 1) around a ring of `count` notches (clamped to 1 … 6): 1
    /// where |fract(angle · count) - 0.5| < ``notchDuty`` / 2, else 0 (the ring rests at ``ringRest`` alpha there).
    public static func notchCoverage(angle: Double, count: Int) -> Double {
        let a: Double = angle.isFinite ? min(max(angle, 0), 1) : 0
        let n: Double = Double(min(max(count, 1), 6))
        return abs(fract(a * n) - 0.5) < notchDuty * 0.5 ? 1 : 0
    }

    /// The dash at angle fraction `angle` (clamped to 0 … 1) around the chosen ring: 1 where fract(angle ·
    /// ``ringDashes``) < ``ringDashDuty``, else 0.
    public static func ringDashCoverage(angle: Double) -> Double {
        let a: Double = angle.isFinite ? min(max(angle, 0), 1) : 0
        return fract(a * ringDashes) < ringDashDuty ? 1 : 0
    }

    /// The signed distance of arrow-local point (`u`, `v`) to the ship's dart, positive inside: the triangle with tip
    /// (1, 0) and tail corners (-1, ±1) less the notch between the tail corners and (``arrowNotch``, 0). Non-finite
    /// coordinates count as far outside (-1).
    public static func arrowDistance(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return -1 }
        let e1: Double = ((u - 1) * 1 + v * 2) * arrowEdgeNorm
        let e2: Double = ((u - 1) * 1 - v * 2) * arrowEdgeNorm
        let qx: Double = u - arrowNotch
        let n1: Double = (-qx - v * (1 + arrowNotch)) * arrowNotchNorm
        let n2: Double = (-qx + v * (1 + arrowNotch)) * arrowNotchNorm
        return min(min(-e1, -e2), max(-n1, -n2))
    }

    /// The ship's coverage at arrow-local point (`u`, `v`): smoothstep(-``arrowFeather``, ``arrowFeather``,
    /// ``arrowDistance(u:v:)``).
    public static func arrowCoverage(u: Double, v: Double) -> Double {
        smoothstep(-arrowFeather, arrowFeather, arrowDistance(u: u, v: v))
    }

    /// The layered colour of a star at mu = n · ``viewDirection`` (clamped to 0 … 1; non-finite counts as 1, a flat
    /// disc): the limb from the pearl shade to pearl by smoothstep(0, ``limbEdge``, mu), the core lifted toward white
    /// by ``coreLift`` · smoothstep(``coreStart``, 1, mu), then the corona toward the glow colour by ``coronaLift`` ·
    /// (1 - mu)^``coronaPower``.
    public static func starShade(mu: Double) -> SIMD3<Double> {
        let m: Double = mu.isFinite ? min(max(mu, 0), 1) : 1
        let shade: SIMD3<Double> = StarlitCartouchePalette.pearlShade
        let pearl: SIMD3<Double> = StarlitCartouchePalette.pearl
        var c: SIMD3<Double> = shade + (pearl - shade) * smoothstep(0, limbEdge, m)
        c += (SIMD3<Double>(1, 1, 1) - c) * (coreLift * smoothstep(coreStart, 1, m))
        c += (StarlitCartouchePalette.glow - c) * (coronaLift * pow(1 - m, coronaPower))
        return c
    }

    /// The layered colour of a star with sphere normal `normal` (any length; a zero or non-finite normal counts as
    /// facing the eye, mu = 1): ``starShade(mu:)`` of the normalised normal · ``viewDirection``.
    public static func starShade(normal: SIMD3<Double>) -> SIMD3<Double> {
        let finite: Bool = normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        let length: Double = finite ? (normal * normal).sum().squareRoot() : 0
        guard length >= 0.0001 else { return starShade(mu: 1) }
        return starShade(mu: ((normal / length) * viewDirection).sum())
    }

    /// The trail colour at along fraction `along` (0 tail … 1 head, clamped; non-finite counts as the head) and won
    /// light `won` (clamped to 0 … 1; non-finite counts as 0): the trail colour times ``trailTail`` … 1, lifted toward
    /// the trail-glow colour by ``flareLift`` times `won`.
    public static func trailColour(along: Double, won: Double) -> SIMD3<Double> {
        let t: Double = along.isFinite ? min(max(along, 0), 1) : 1
        let w: Double = won.isFinite ? min(max(won, 0), 1) : 0
        let base: SIMD3<Double> = StarlitCartouchePalette.trail * (trailTail + (1 - trailTail) * t)
        return base + (StarlitCartouchePalette.trailGlow - base) * (flareLift * w)
    }

    /// The fade the geometry writes into `a_normal.y` for ghost `index` (0 nearest the trail's head) of `count`:
    /// (count - index) / (count + 1), falling with the index; 0 outside 0 ..< count.
    public static func ghostFade(index: Int, count: Int) -> Double {
        guard count > 0, index >= 0, index < count else { return 0 }
        return Double(count - index) / Double(count + 1)
    }

    /// A ghost's alpha (before the soft outline) at along fraction `along` with fade `fade` (both clamped to 0 … 1;
    /// non-finite counts as 0): ``ghostAlpha`` · fade · along.
    public static func ghostAlpha(along: Double, fade: Double) -> Double {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        return ghostAlpha * unit(fade) * unit(along)
    }

    /// The firmament's hash of a speck cell (`x`, `y`), 0 ..< 1, as the chart fragment shader computes it (in Float).
    public static func hash(_ x: Double, _ y: Double) -> Double {
        func fr(_ v: Float) -> Float { v - v.rounded(.down) }
        var p: SIMD3<Float> = SIMD3<Float>(fr(Float(x) * 0.1031), fr(Float(y) * 0.1031), fr(Float(x) * 0.1031))
        let yzx: SIMD3<Float> = SIMD3<Float>(p.y, p.z, p.x) + SIMD3<Float>(33.33, 33.33, 33.33)
        let dot: Float = (p * yzx).sum()
        p += SIMD3<Float>(dot, dot, dot)
        return Double(fr((p.x + p.y) * p.z))
    }

    /// The speck coverage (0 … 1) of the firmament at height `height` (0 … 1), horizontal coordinate `horizontal`
    /// (-1 … 1) and turn `angle` (radians; wrapped by 2π): the speck of its cell on the cylinder of ``cellsAround``
    /// cells, when the cell's hash is at least 1 - ``speckDensity``, fading from ``speckRadius`` / 2 to ``speckRadius``
    /// around its jittered centre. Non-finite inputs count as 0.
    public static func speckCoverage(height: Double, horizontal: Double, angle: Double) -> Double {
        let h: Double = height.isFinite ? min(max(height, 0), 1) : 0
        let s: Double = horizontal.isFinite ? min(max(horizontal, -1), 1) : 0
        let a: Double = angle.isFinite ? angle : 0
        let turn: Double = a - tau * (a / tau).rounded(.down)
        let px: Double = (s * skySpan + turn) * cellsPerRadian
        let py: Double = h * cellsUp
        let rawX: Double = px.rounded(.down)
        let cx: Double = rawX - cellsAround * (rawX / cellsAround).rounded(.down)
        let cy: Double = py.rounded(.down)
        let pick: Double = hash(cx, cy)
        guard pick >= 1 - speckDensity else { return 0 }
        let jitter: Double = hash(cx + 17, cy + 59)
        let fx: Double = fract(px) - 0.5 - (jitter - 0.5) * speckJitter
        let fy: Double = fract(py) - 0.5 - (fract(jitter * 7) - 0.5) * speckJitter
        let r: Double = (fx * fx + fy * fy).squareRoot()
        return 1 - smoothstep(speckRadius * 0.5, speckRadius, r)
    }

    /// The firmament colour at height `height` (0 bottom … 1 top), horizontal coordinate `horizontal` and turn
    /// `angle`: the gradient from night to night top, lifted toward the speck colour by the speck coverage times its
    /// brightness ``speckDim`` … 1 (``speckCoverage(height:horizontal:angle:)``).
    public static func firmamentColour(height: Double, horizontal: Double, angle: Double) -> SIMD3<Double> {
        let h: Double = height.isFinite ? min(max(height, 0), 1) : 0
        let night: SIMD3<Double> = StarlitCartouchePalette.night
        let gradient: SIMD3<Double> = night + (StarlitCartouchePalette.nightTop - night) * h
        let speck: Double = speckCoverage(height: height, horizontal: horizontal, angle: angle)
        guard speck > 0 else { return gradient }
        let s: Double = horizontal.isFinite ? min(max(horizontal, -1), 1) : 0
        let a: Double = angle.isFinite ? angle : 0
        let turn: Double = a - tau * (a / tau).rounded(.down)
        let rawX: Double = ((s * skySpan + turn) * cellsPerRadian).rounded(.down)
        let cx: Double = rawX - cellsAround * (rawX / cellsAround).rounded(.down)
        let pick: Double = hash(cx, (h * cellsUp).rounded(.down))
        let brightness: Double = speckDim + (1 - speckDim) * fract(pick * 13)
        return gradient + (StarlitCartouchePalette.speck - gradient) * (speck * brightness)
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: StarlitCartoucheTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 … ``maxGlowGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the glow, ship-glow or trail-glow colour by `kind`), glow
    /// factor `factor`, radial coordinate `radius`, the applied `gain` and won light `won`, before premultiplying: the
    /// colour, with alpha ``glowWeight`` · gain · factor · (1 - radius)², the factor of a trail shell also times
    /// ``trailRest`` + (1 - ``trailRest``) · won; every component clamped to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            switch kind {
            case .star: c = StarlitCartouchePalette.glow
            case .ship: c = StarlitCartouchePalette.shipGlow
            case .trail: c = StarlitCartouchePalette.trailGlow
            }
        }
        let flare: Double = kind == .trail ? trailRest + (1 - trailRest) * unit(won) : 1
        let r: Double = 1 - unit(radius)
        let k: Double = gain.isFinite ? gain : 0
        return SIMD4<Double>(c.x, c.y, c.z, unit(glowWeight * k * unit(factor) * flare * r * r))
    }

    /// GLSL's fract(`x`).
    static func fract(_ x: Double) -> Double { x - x.rounded(.down) }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
