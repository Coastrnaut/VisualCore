// MushroomWeatherSceneGeometry — feature 493 (R02-G20-03) T-R02G2003-004 (FR-R02G2003-001, 002, 003, 004, 006, 007;
// SC-R02G2003-001, 003; clarifications Q1–Q4). The midnight miniature forest of Mushroom Weather, built from a
// snapshot only. x points right, y up the floor and z up from the floor (towards the sky). One fitting rule for every
// level (clarification Q1): cell (r, c) of a floor of R rows and C columns has its centre at
// ((c − (C − 1)/2) · s, ((R − 1)/2 − r) · s, 0) with s = min(1.8 / C, 1.6 / R), so every floor fills the same box and
// nothing a player does changes its size. Nothing here is consulted by the rules.
//
// Draw order (clarification Q1, research R3): the whole forest mesh is drawn with depth testing on, in the fixed order
// of the elements (``MushroomWeatherElement``) by kind, then by index within the kind. The solids (floor, logs and
// stones, fronds, stalks, caps, pods, vents) are resolved by depth; every flat lies on its own plane above what it
// covers (site rings at z 0.01, band rings at 0.012, mist at 0.02, the mold patch at 0.025, gauges and bars at 0 below
// the floor), so the order by kind decides how the translucent flats blend. A "quad of shape half h" spans
// ±``MushroomWeatherShaders/quadExtent`` · h (1.25 h) around its centre; its shape (square, disc or ring of outer
// radius h) spans ±h and the shader cuts it out:
//   0. backdrop: one quad perpendicular to the view axis at distance ``backdropDistance`` from the eye, filling the
//      view for aspects 0.25 … 4; a vertical gradient midnight (bottom) … midnight top (top);
//   1. moon: a disc quad of shape half 0.12 at (1.15, 1.05, −0.5) facing the eye (value: brightness (4 + L)/7), then
//      four phase tick quads of shape half 0.018 at radius 0.16 around it (top, right, bottom, left), the first L + 1
//      `phaseTickLit` (disc) and the others `phaseTickUnlit` (ring);
//   2. floor: per floor cell a square quad of side 0.96 s at z 0 (row-major);
//   3. blocked: per blocked cell (row-major) a log when r + c is even — a cylinder of radius 0.15 s and length 0.8 s
//      along x, its axis at height 0.15 s, with flat ends (12 sides) — otherwise a stone, a low dome 0.36 s in radius
//      and 0.2 s high (12 sides, 4 rings); the same at every tier;
//   4. fronds: at the tiers with `fronds` only: L-system fronds of three generations (strips 0.14 s, 0.09 s, 0.06 s
//      long, 0.03 s, 0.02 s, 0.014 s wide, the first leaning ±0.35 rad from upright, each branch turned ±0.5 rad), in
//      the vertical plane facing the eye, rooted at a front corner of every blocked cell and at every other cell along
//      the floor's four edges; reaching at most 0.3 s from their root; decoration only;
//   5. mist: per floor cell a square quad at z 0.02 of side s · (0.2 + 0.7 · min(1, h/M)) for the kernel's humidity h
//      at the shown cycle (value: min(1, h/M), the shade);
//   6. mark: on a failed play with a mold failure, a `moldPatch` quad of shape half 0.35 s at z 0.025 on the cell;
//   7. site: per pod site a `siteRing` quad of shape half (outer radius) 0.32 s at z 0.01;
//   8. bandRing: per colony a ring quad of outer radius 0.5 s at z 0.012 around the stalk: `bandRingSolid` in band,
//      `bandRingDashed` out of band; broken when a dried failure names the colony;
//   9. stalk: per colony a lathed stalk 0.35 s tall (radius 0.07 s at the foot, 0.05 s at the top), or flat at level-2
//      (a rectangle fan 0.12 s wide from the floor to 0.35 s in the plane facing the eye);
//  10. cap: per colony a lathed umbrella cap of radius 0.42 s (rim at 0.32 s, apex at 0.5 s, closed underneath), `cap`
//      when the colony is in band at the shown cycle, `capOut` otherwise (value: min(1, h/M) of its cell, the bead
//      density); a dried colony's cap wilts (its rim droops to 0.2 s) and is broken; flat at level-2 (a disc fan of
//      radius 0.42 s facing the eye at the cap centre, 24 sides). The cap centre is the colony cell at height 0.45 s;
//  11. pod: per placed pod (by slot) a lathed amber orb of radius 0.18 s (0.26 s once grown by the shown cycle) centred
//      at height 0.1 s and cut at the floor (a disc fan facing the eye at level-2), plus for a grown pod a horizontal
//      `podRing` quad of outer radius r + 0.07 s at its centre (the same at every tier);
//  12. droplets: per placed pod `tier.droplets` disc quads of shape half 0.025 s facing the eye, droplet k at the start
//      of its path (angle 2π (k + ½) / n, radius (0.08 + 0.12 k / n) s, height 0.28 s; value: phase k / n; a_normal.z:
//      ``MushroomWeatherShaders/dropletRise(scale:)``); the vertex shader raises them by time; decoration only;
//  13. motes: `tier.motes` disc quads of shape half 0.01 facing the eye, mote k at the start of its loop of radius
//      ``MushroomWeatherShaders/moteLoopRadius`` (loop centre at angle 2π k / n on the ellipse of radii (0.95, 0.7)
//      around (0, −0.05), height 0.2 + 0.04 · sin(2 · angle); the geometry puts it one radius to +x of that centre;
//      value: phase k / n; a_normal.z: the radius); the vertex shader moves them by time; decoration only;
//  14. vent: per vent a frame of side 0.9 s at height 0.9 s over its cell: four `ventFrame` rail strips 0.06 s wide and
//      four `ventSlat` square quads of shape 0.18 s across, flat when shut, tilted 0.9 rad towards the eye when open;
//  15. gauge: per colony k a row at y = −1.0 − 0.07 k: a `gaugeTrack` strip from x −0.9 to 0.9 (0.012 tall) mapping
//      0 … M, a `bandBracket` quad whose shape spans low … high in x (u −1 … +1) and from the track's centre line
//      (v −1) to 0.026 above it (v +1), and a `marker` disc quad (shape half 0.02) at the colony's humidity at the
//      shown cycle; the marker is broken when an unstable failure names the colony;
//  16. runBar: per colony K square quads from x 0.95 to 1.25 at the gauge row, each a fifth gap, 0.03 tall: the first
//      min(final run, K) `runLit`, the others `runUnlit`; broken when an unstable failure names the colony;
//  17. bar: `budget` actions bar square quads at y = −1.0 − 0.07 · colonies − 0.05, each 1.8 / budget wide with a fifth
//      as gap, 0.04 tall: `barLit` for the actions left, `barUnlit` for the rest.
// The glow mesh is drawn last, additively: `tier.glowShells` shells k (outermost first), each an annulus of
// ``glowSides`` sides facing the eye: around every cap from 0.3 s to 0.42 s + 0.08 s · k at the cap centre (kind cap,
// factor ``MushroomWeatherShaders/glowFactor(inBand:)``) and around each placed pod from 0.6 r to r + 0.06 s · k at its
// centre (kind pod, factor 1). Empty at level-2. A won level moves nothing and changes no stream: the shaders' `u_won`
// lights the out-of-band caps and raises their shells; the fallback colours do the same.
//
// Failures (clarification Q4) are marked only on a failed play (stage `failed`), never for the predicted failure while
// playing: dried — the named colony's cap (wilted) and band ring broken; mold — the `moldPatch` on the named cell;
// unstable — the named colony's marker and run bar broken.
//
// Vertex streams (the contract of ``MushroomWeatherShaders``): a_uv.x =
// ``MushroomWeatherShaders/encode(_:value:broken:)`` (material code + 0.4 · value for the valued materials + 32 when
// broken). Lathed solids (log, stone, stalk, cap, capOut, pod): a_normal the unit outward world normal, a_uv.y 0. Flat
// level-2 solids (stalk, cap, capOut, pod): a_normal zero, a_uv.y the radial coordinate (0 at the centre vertex, 1 on
// the outline). Strips (frond, ventFrame, gaugeTrack): a_normal zero, a_uv.y the across coordinate −1 … +1. Quads
// (moon, ticks, floor, mist, rings, droplet, mote, ventSlat, bandBracket, marker, run bars, actions bars, moldPatch):
// a_normal (u, v, w), (u, v) = ±1.25 at the corners, w 0 except the droplet's rise and the mote's loop radius; a_uv.y
// 0. Backdrop: a_normal zero, a_uv.y the height 0 … 1. Glow mesh: a_normal zero (the shader takes the cap or pod colour
// by kind), a_uv.x ``MushroomWeatherShaders/GlowKind/code(factor:)``, a_uv.y 0 on a shell's inner edge and 1 on its
// outer edge. Every triangle winds counter-clockwise seen from the side it faces (the eye for flats, outside for
// solids). Tiers change only the lathes (flat at level-2), the droplets, the fronds, the motes and the glow: every
// other vertex is the same at every tier. Nothing here depends on the presentation time. Doubles are used for drawing
// only. Modelled on `MicroscopicAuroraSceneGeometry` (483).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct MushroomWeatherCamera: Sendable, Equatable {
    /// The eye position in world units, (0, −1.6, 3.0).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.2, 0).
    public let target: SIMD3<Double>
    /// The vertical field of view in radians (fitted to the authored box at `aspect`).
    public let fovY: Double
    /// The width-to-height ratio used (sanitised to 0.1 … 10).
    public let aspect: Double
    /// The near plane distance.
    public let near: Double
    /// The far plane distance.
    public let far: Double
    /// The view matrix.
    public let view: Mat4
    /// The projection matrix.
    public let projection: Mat4
    /// projection · view (upload with `.floats`).
    public let viewProjection: Mat4
}

/// One drawn element of the scene with its place in the drawing order (clarification Q1).
public struct MushroomWeatherElement: Sendable, Equatable {
    /// The kind of an element, in the drawing order.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The sky backdrop.
        case backdrop = 0
        /// The moon and its phase ticks.
        case moon = 1
        /// A floor cell (`item` its row-major index).
        case floor = 2
        /// A blocked cell's log or stone (`item` its row-major index).
        case blocked = 3
        /// The decorative fronds (nothing at a tier without fronds).
        case fronds = 4
        /// A floor cell's mist (`item` its row-major index).
        case mist = 5
        /// A mold failure's patch (`item` the named cell's row-major index).
        case mark = 6
        /// A pod site's ring (`item` the site).
        case site = 7
        /// A colony's band ring (`item` the colony).
        case bandRing = 8
        /// A colony's stalk (`item` the colony).
        case stalk = 9
        /// A colony's cap (`item` the colony).
        case cap = 10
        /// A placed pod (`item` the slot).
        case pod = 11
        /// A placed pod's droplets (`item` the slot).
        case droplets = 12
        /// The spore motes.
        case motes = 13
        /// A vent (`item` the vent).
        case vent = 14
        /// A colony's gauge row (`item` the colony).
        case gauge = 15
        /// A colony's run bar (`item` the colony).
        case runBar = 16
        /// An actions bar (`item` the bar).
        case bar = 17

        /// Whether the kind is a solid resolved by depth (research R3); the others are flats drawn in this order.
        public var isSolid: Bool {
            switch self {
            case .floor, .blocked, .fronds, .stalk, .cap, .pod, .vent: return true
            default: return false
            }
        }
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind.
    public let index: Int
    /// The item the element draws: cell index, site, colony, slot, vent or bar (0 for the single elements).
    public let item: Int
    /// The element's centre in world units.
    public let centre: SIMD3<Double>

    /// An element of the given values.
    public init(kind: Kind, index: Int, item: Int, centre: SIMD3<Double>) {
        self.kind = kind
        self.index = index
        self.item = item
        self.centre = centre
    }

    /// Whether `a` is drawn before `b`: by kind first, then by index.
    public static func drawsBefore(_ a: MushroomWeatherElement, _ b: MushroomWeatherElement) -> Bool {
        if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
        return a.index < b.index
    }
}

/// A point of the CPU reference (clarification Q3).
public struct MushroomWeatherReferencePoint: Sendable, Equatable {
    /// What the point marks.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The floor centre.
        case floorCentre = 0
        /// A colony's cap centre.
        case cap = 1
        /// The moon centre.
        case moon = 2
        /// The first gauge track's centre.
        case gaugeTrack = 3
        /// The first actions bar's centre.
        case actionsBar = 4
    }

    /// What the point marks.
    public let kind: Kind
    /// The colony index for a cap (0 for the single points).
    public let index: Int
    /// The point in world units.
    public let centre: SIMD3<Double>

    /// A reference point of the given values.
    public init(kind: Kind, index: Int, centre: SIMD3<Double>) {
        self.kind = kind
        self.index = index
        self.centre = centre
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct MushroomWeatherColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Mushroom Weather forest from a `MushroomWeatherSceneSnapshot`: places, meshes, camera and projection
/// (see the file header).
public enum MushroomWeatherSceneGeometry {
    // MARK: Constants (world units; "· s" constants are shares of the cell scale)

    /// The width of the box the floor fills, 1.8 (s = min(1.8 / C, 1.6 / R)).
    public static let floorWidth: Double = 1.8
    /// The height of the box the floor fills, 1.6.
    public static let floorHeight: Double = 1.6
    /// A floor square's side · s.
    public static let floorSquare: Double = 0.96
    /// The moon's centre.
    public static let moonPosition: SIMD3<Double> = SIMD3(1.15, 1.05, -0.5)
    /// The moon's radius.
    public static let moonRadius: Double = 0.12
    /// The radius at which the phase ticks stand around the moon centre.
    public static let tickOrbit: Double = 0.16
    /// A phase tick's radius.
    public static let tickRadius: Double = 0.018
    /// The phase ticks.
    public static let tickCount: Int = 4
    /// A log's length · s.
    public static let logLength: Double = 0.8
    /// A log's radius · s.
    public static let logRadius: Double = 0.15
    /// A stone's radius · s.
    public static let stoneRadius: Double = 0.36
    /// A stone's height · s.
    public static let stoneHeight: Double = 0.2
    /// The sides of a log or a stone (the same at every tier).
    public static let blockedSides: Int = 12
    /// The rings of a stone dome.
    public static let stoneRings: Int = 4
    /// The stem lengths of the three frond generations · s.
    public static let frondLengths: [Double] = [0.14, 0.09, 0.06]
    /// The stem widths of the three frond generations · s.
    public static let frondWidths: [Double] = [0.03, 0.02, 0.014]
    /// The lean of a frond's first stem from upright, in radians.
    public static let frondLean: Double = 0.35
    /// The angle a frond branch turns from its parent, in radians.
    public static let frondBranch: Double = 0.5
    /// How far a frond may reach from its root · s.
    public static let frondReach: Double = 0.3
    /// A frond root's height above the floor · s.
    public static let frondRootHeight: Double = 0.01
    /// The mist plane.
    public static let mistZ: Double = 0.02
    /// The mist's smallest side · s (at h = 0).
    public static let mistBase: Double = 0.2
    /// The mist's growth to its largest side · s (at h ≥ M).
    public static let mistGrowth: Double = 0.7
    /// The mold patch's plane.
    public static let markZ: Double = 0.025
    /// The mold patch's side · s.
    public static let markSide: Double = 0.7
    /// A site ring's outer radius · s (its quad's shape half).
    public static let siteRadius: Double = 0.32
    /// The site rings' plane.
    public static let siteZ: Double = 0.01
    /// A band ring's outer radius · s (its quad's shape half).
    public static let bandRadius: Double = 0.5
    /// The band rings' plane.
    public static let bandZ: Double = 0.012
    /// A stalk's height · s.
    public static let stalkHeight: Double = 0.35
    /// A stalk's radius at its foot · s.
    public static let stalkFoot: Double = 0.07
    /// A stalk's radius at its top · s.
    public static let stalkTop: Double = 0.05
    /// A flat stalk's width · s.
    public static let flatStalkWidth: Double = 0.12
    /// A cap's radius · s.
    public static let capRadius: Double = 0.42
    /// A cap rim's height · s.
    public static let capRim: Double = 0.32
    /// A wilted cap rim's height · s.
    public static let wiltedRim: Double = 0.2
    /// A cap apex's height · s.
    public static let capApex: Double = 0.5
    /// The cap centre's height · s (the reference point).
    public static let capCentreHeight: Double = 0.45
    /// The profile steps of a cap dome or a pod orb.
    public static let profileSteps: Int = 6
    /// The sides of a flat cap or pod disc.
    public static let flatSides: Int = 24
    /// A pod's radius · s.
    public static let podRadius: Double = 0.18
    /// A grown pod's radius · s.
    public static let grownRadius: Double = 0.26
    /// A pod centre's height · s.
    public static let podHeight: Double = 0.1
    /// The gap from a grown pod to its second ring · s.
    public static let podRingGap: Double = 0.03
    /// The width of a grown pod's second ring · s.
    public static let podRingWidth: Double = 0.04
    /// A droplet's half side · s.
    public static let dropletHalf: Double = 0.025
    /// A droplet path's start above the pod centre · s.
    public static let dropletStart: Double = 0.18
    /// A droplet path's inner radius · s.
    public static let dropletInner: Double = 0.08
    /// A droplet path's spread · s.
    public static let dropletSpread: Double = 0.12
    /// A mote's half side.
    public static let moteHalf: Double = 0.01
    /// The ellipse the motes' loop centres lie on: radii (x, y), its centre's y and its height.
    public static let moteLoop: SIMD4<Double> = SIMD4(0.95, 0.7, -0.05, 0.2)
    /// A vent frame's side · s.
    public static let ventSide: Double = 0.9
    /// A vent frame's height · s.
    public static let ventHeight: Double = 0.9
    /// A vent rail's width · s.
    public static let ventRail: Double = 0.06
    /// The slats of a vent.
    public static let ventSlats: Int = 4
    /// A vent slat's width · s.
    public static let slatWidth: Double = 0.18
    /// An open slat's tilt in radians (towards the eye).
    public static let slatTilt: Double = 0.9
    /// The first gauge row's centre line.
    public static let gaugeTop: Double = -1.0
    /// The step between gauge rows.
    public static let gaugeStep: Double = 0.07
    /// The gauges' left end.
    public static let gaugeStart: Double = -0.9
    /// The gauges' right end.
    public static let gaugeEnd: Double = 0.9
    /// A gauge track's height.
    public static let trackHeight: Double = 0.012
    /// A band bracket's offset above its track's centre line.
    public static let bracketOffset: Double = 0.022
    /// The smallest half width of a band bracket's shape (a band of one value).
    public static let bracketMinimum: Double = 0.004
    /// A band bracket's bar height (its shape reaches bracketOffset + bracketHeight / 2 above the track's centre
    /// line).
    public static let bracketHeight: Double = 0.008
    /// A marker's half side.
    public static let markerHalf: Double = 0.02
    /// A run bar's left end.
    public static let runStart: Double = 0.95
    /// A run bar's right end.
    public static let runEnd: Double = 1.25
    /// A run bar segment's height.
    public static let runHeight: Double = 0.03
    /// The gap from the last gauge row to the actions bars.
    public static let barsGap: Double = 0.05
    /// The share of a slot a bar or run segment fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// An actions bar's height.
    public static let barHeight: Double = 0.04
    /// A cap glow band's inner radius · s.
    public static let capGlowInner: Double = 0.3
    /// A glow band's growth per shell · s for caps.
    public static let capGlowGrowth: Double = 0.08
    /// A pod glow band's inner radius as a share of the pod's radius.
    public static let podGlowInner: Double = 0.6
    /// A pod glow band's growth per shell · s.
    public static let podGlowGrowth: Double = 0.06
    /// The sides of a glow band.
    public static let glowSides: Int = 24
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, -1.6, 3.0)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.2, 0)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-1.3, -1.5, 0)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1.3, 1.2, 0.3)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The aspects the backdrop fills.
    public static let backdropAspects: ClosedRange<Double> = 0.25...4
    /// The backdrop's distance from the eye along the view axis (beyond the moon).
    public static let backdropDistance: Double = 6

    // MARK: Material codes

    /// The a_uv.x value of `material` with `value` and the broken mark
    /// (``MushroomWeatherShaders/encode(_:value:broken:)``).
    static func code(_ material: MushroomWeatherMaterial, value: Double = 0, broken: Bool = false) -> Double {
        MushroomWeatherShaders.encode(material, value: value, broken: broken)
    }

    /// The fallback colour of a forest vertex whose a_uv.x is `code`, with won light `won` (0 … 1): the base colour the
    /// forest vertex shader selects (``MushroomWeatherShaders/baseColour(of:value:broken:won:)`` of the decoded
    /// material, value and broken mark).
    public static func colour(of code: Double, won: Double = 0) -> SIMD3<Double> {
        let decoded: (material: MushroomWeatherMaterial, value: Double, broken: Bool) =
            MushroomWeatherShaders.decode(code)
        return MushroomWeatherShaders.baseColour(of: decoded.material, value: decoded.value, broken: decoded.broken,
                                                 won: won)
    }

    // MARK: Places (the CPU reference)

    /// The cell scale s = min(1.8 / C, 1.6 / R) (rows and columns at least 1).
    public static func scale(rows: Int, columns: Int) -> Double {
        min(floorWidth / Double(max(columns, 1)), floorHeight / Double(max(rows, 1)))
    }

    /// The scale of `snapshot`'s floor.
    static func scale(_ snapshot: MushroomWeatherSceneSnapshot) -> Double {
        scale(rows: snapshot.rows, columns: snapshot.columns)
    }

    /// The centre of `cell` at `height` · s: ((c − (C − 1)/2) · s, ((R − 1)/2 − r) · s, height · s).
    public static func cellCentre(_ cell: MushroomWeatherCell, _ snapshot: MushroomWeatherSceneSnapshot,
                                  height: Double) -> SIMD3<Double> {
        let s: Double = scale(snapshot)
        let x: Double = (Double(cell.column) - Double(snapshot.columns - 1) / 2) * s
        let y: Double = (Double(snapshot.rows - 1) / 2 - Double(cell.row)) * s
        return SIMD3(x, y, height * s)
    }

    /// The floor centre, the origin.
    public static func floorCentre() -> SIMD3<Double> { SIMD3(0, 0, 0) }

    /// `index` clamped to 0 … count − 1 (0 when count is 0).
    static func clamped(_ index: Int, _ count: Int) -> Int { min(max(index, 0), max(count - 1, 0)) }

    /// Colony `colony`'s cap centre (clamped; the floor centre without colonies): its cell at height 0.45 s.
    public static func capCentre(_ colony: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.colonies.isEmpty else { return floorCentre() }
        let cell: MushroomWeatherCell = snapshot.colonies[clamped(colony, snapshot.colonies.count)].cell
        return cellCentre(cell, snapshot, height: capCentreHeight)
    }

    /// The moon centre, (1.15, 1.05, −0.5).
    public static func moonCentre() -> SIMD3<Double> { moonPosition }

    /// The centre line of colony `colony`'s gauge row, −1.0 − 0.07 · colony.
    public static func gaugeY(_ colony: Int) -> Double { gaugeTop - gaugeStep * Double(max(colony, 0)) }

    /// Colony `colony`'s gauge track centre: (0, −1.0 − 0.07 · colony, 0).
    public static func gaugeTrackCentre(_ colony: Int) -> SIMD3<Double> {
        SIMD3((gaugeStart + gaugeEnd) / 2, gaugeY(colony), 0)
    }

    /// The x of `value` on a gauge whose scale is 0 … `top`: −0.9 + 1.8 · value / top (value clamped to 0 … top; top
    /// at least 1).
    public static func gaugeX(_ value: Int, top: Int) -> Double {
        let t: Double = Double(max(top, 1))
        return gaugeStart + (gaugeEnd - gaugeStart) * min(max(Double(value), 0), t) / t
    }

    /// Colony `colony`'s marker centre: at the gauge x of its humidity at the shown cycle.
    public static func markerCentre(_ colony: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.colonies.isEmpty else { return gaugeTrackCentre(colony) }
        let k: Int = clamped(colony, snapshot.colonies.count)
        let h: Int = humidity(snapshot.colonies[k].cell, snapshot)
        return SIMD3(gaugeX(h, top: snapshot.moldBound), gaugeY(k), 0)
    }

    /// The centre line of the actions bars, −1.0 − 0.07 · colonies − 0.05.
    public static func barsY(_ snapshot: MushroomWeatherSceneSnapshot) -> Double {
        gaugeTop - gaugeStep * Double(snapshot.colonies.count) - barsGap
    }

    /// The width of one actions slot, 1.8 / budget.
    public static func actionsSlot(_ snapshot: MushroomWeatherSceneSnapshot) -> Double {
        (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of actions bar `index`: (−0.9 + (index + 0.5) · slot, bars y, 0).
    public static func actionsBar(_ index: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * actionsSlot(snapshot), barsY(snapshot), 0)
    }

    /// The actions bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litActions(_ snapshot: MushroomWeatherSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The side of a mist square for humidity `humidity`: s · (0.2 + 0.7 · min(1, h/M)) (h below 0 as 0, M at least
    /// 1).
    public static func mistSide(_ humidity: Int, moldBound: Int, scale: Double) -> Double {
        scale * (mistBase + mistGrowth * mistShare(humidity, moldBound: moldBound))
    }

    /// min(1, h/M) with h below 0 as 0 and M at least 1: the mist's shade and the cap's sparkle density.
    public static func mistShare(_ humidity: Int, moldBound: Int) -> Double {
        min(1, Double(max(humidity, 0)) / Double(max(moldBound, 1)))
    }

    /// The kernel's humidity of `cell` at the shown cycle (0 for a cell outside the field).
    static func humidity(_ cell: MushroomWeatherCell, _ snapshot: MushroomWeatherSceneSnapshot) -> Int {
        guard snapshot.shownCycle < snapshot.fields.count else { return 0 }
        let field: [Int] = snapshot.fields[snapshot.shownCycle]
        let index: Int = cell.row * snapshot.columns + cell.column
        guard cell.row >= 0, cell.column >= 0, cell.column < snapshot.columns, index < field.count else { return 0 }
        return field[index]
    }

    /// The floor cells (every cell not blocked), row-major.
    public static func floorCells(_ snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherCell] {
        let blocked: Set<MushroomWeatherCell> = Set(snapshot.blocked)
        var cells: [MushroomWeatherCell] = []
        for r in 0..<max(snapshot.rows, 0) {
            for c in 0..<max(snapshot.columns, 0) {
                let cell: MushroomWeatherCell = MushroomWeatherCell(row: r, column: c)
                if !blocked.contains(cell) { cells.append(cell) }
            }
        }
        return cells
    }

    /// The mist squares in drawing order: per floor cell its centre at z 0.02, its side and its shade share, from the
    /// kernel's humidity at the shown cycle only.
    public static func mistSquares(_ snapshot: MushroomWeatherSceneSnapshot)
        -> [(cell: MushroomWeatherCell, centre: SIMD3<Double>, side: Double, share: Double)] {
        let s: Double = scale(snapshot)
        var squares: [(cell: MushroomWeatherCell, centre: SIMD3<Double>, side: Double, share: Double)] = []
        for cell in floorCells(snapshot) {
            let h: Int = humidity(cell, snapshot)
            var centre: SIMD3<Double> = cellCentre(cell, snapshot, height: 0)
            centre.z = mistZ
            squares.append((cell: cell, centre: centre, side: mistSide(h, moldBound: snapshot.moldBound, scale: s),
                            share: mistShare(h, moldBound: snapshot.moldBound)))
        }
        return squares
    }

    /// Whether colony `colony`'s cap is lit: in band at the shown cycle, or the level is won.
    public static func capLit(_ colony: Int, _ snapshot: MushroomWeatherSceneSnapshot, won: Bool) -> Bool {
        guard colony >= 0, colony < snapshot.colonies.count else { return won }
        return won || snapshot.colonies[colony].inBand
    }

    /// The colony a dried failure names on a failed play, nil otherwise (no mark for a predicted failure).
    public static func driedColony(_ snapshot: MushroomWeatherSceneSnapshot) -> Int? {
        guard snapshot.stage == .failed, case .dried(let colony, _) = snapshot.failure else { return nil }
        return colony
    }

    /// The cell a mold failure names on a failed play, nil otherwise.
    public static func moldCell(_ snapshot: MushroomWeatherSceneSnapshot) -> MushroomWeatherCell? {
        guard snapshot.stage == .failed, case .mold(let cell, _) = snapshot.failure else { return nil }
        return cell
    }

    /// The colony an unstable failure names on a failed play, nil otherwise.
    public static func unstableColony(_ snapshot: MushroomWeatherSceneSnapshot) -> Int? {
        guard snapshot.stage == .failed, case .unstable(let colony, _) = snapshot.failure else { return nil }
        return colony
    }

    /// Slot `slot`'s pod centre (its cell at height 0.1 s), nil for an empty slot.
    public static func podCentre(_ slot: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double>? {
        guard slot >= 0, slot < snapshot.pods.count, let cell = snapshot.pods[slot] else { return nil }
        return cellCentre(cell, snapshot, height: podHeight)
    }

    /// Slot `slot`'s pod radius: 0.26 s once grown by the shown cycle, else 0.18 s.
    public static func podRadius(_ slot: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> Double {
        (snapshot.isGrown(slot) ? grownRadius : podRadius) * scale(snapshot)
    }

    /// The vent's centre: its cell at height 0.9 s.
    public static func ventCentre(_ index: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.vents.isEmpty else { return floorCentre() }
        return cellCentre(snapshot.vents[clamped(index, snapshot.vents.count)], snapshot, height: ventHeight)
    }

    /// Whether vent `index` is open (shut when the state is missing).
    public static func ventOpen(_ index: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> Bool {
        index >= 0 && index < snapshot.ventsOpen.count && snapshot.ventsOpen[index]
    }

    /// The backdrop's centre: on the view axis at ``backdropDistance`` from the eye.
    public static func backdropCentre() -> SIMD3<Double> { eye + viewBasis().forward * backdropDistance }

    // MARK: Elements

    /// Every element with its centre, in drawing order (by kind, then index; clarification Q1). The same for every
    /// tier.
    public static func paintOrder(_ snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherElement] {
        typealias E = MushroomWeatherElement
        var list: [E] = []
        list.append(E(kind: .backdrop, index: 0, item: 0, centre: backdropCentre()))
        list.append(E(kind: .moon, index: 0, item: 0, centre: moonCentre()))
        let floor: [MushroomWeatherCell] = floorCells(snapshot)
        for (k, cell) in floor.enumerated() {
            list.append(E(kind: .floor, index: k, item: cell.row * snapshot.columns + cell.column,
                          centre: cellCentre(cell, snapshot, height: 0)))
        }
        for (k, cell) in snapshot.blocked.enumerated() {
            list.append(E(kind: .blocked, index: k, item: cell.row * snapshot.columns + cell.column,
                          centre: cellCentre(cell, snapshot, height: 0)))
        }
        list.append(E(kind: .fronds, index: 0, item: 0, centre: floorCentre()))
        for (k, square) in mistSquares(snapshot).enumerated() {
            list.append(E(kind: .mist, index: k, item: square.cell.row * snapshot.columns + square.cell.column,
                          centre: square.centre))
        }
        if let cell = moldCell(snapshot) {
            var centre: SIMD3<Double> = cellCentre(cell, snapshot, height: 0)
            centre.z = markZ
            list.append(E(kind: .mark, index: 0, item: cell.row * snapshot.columns + cell.column, centre: centre))
        }
        for (k, cell) in snapshot.sites.enumerated() {
            var centre: SIMD3<Double> = cellCentre(cell, snapshot, height: 0)
            centre.z = siteZ
            list.append(E(kind: .site, index: k, item: k, centre: centre))
        }
        for (k, colony) in snapshot.colonies.enumerated() {
            var centre: SIMD3<Double> = cellCentre(colony.cell, snapshot, height: 0)
            centre.z = bandZ
            list.append(E(kind: .bandRing, index: k, item: k, centre: centre))
        }
        for (k, colony) in snapshot.colonies.enumerated() {
            list.append(E(kind: .stalk, index: k, item: k,
                          centre: cellCentre(colony.cell, snapshot, height: stalkHeight / 2)))
        }
        for k in snapshot.colonies.indices {
            list.append(E(kind: .cap, index: k, item: k, centre: capCentre(k, snapshot)))
        }
        var pods: Int = 0
        for slot in snapshot.pods.indices {
            guard let centre = podCentre(slot, snapshot) else { continue }
            list.append(E(kind: .pod, index: pods, item: slot, centre: centre))
            list.append(E(kind: .droplets, index: pods, item: slot, centre: centre))
            pods += 1
        }
        list.append(E(kind: .motes, index: 0, item: 0, centre: SIMD3(0, moteLoop.z, moteLoop.w)))
        for k in snapshot.vents.indices {
            list.append(E(kind: .vent, index: k, item: k, centre: ventCentre(k, snapshot)))
        }
        for k in snapshot.colonies.indices {
            list.append(E(kind: .gauge, index: k, item: k, centre: gaugeTrackCentre(k)))
            list.append(E(kind: .runBar, index: k, item: k,
                          centre: SIMD3((runStart + runEnd) / 2, gaugeY(k), 0)))
        }
        for b in 0..<max(snapshot.budget, 0) {
            list.append(E(kind: .bar, index: b, item: b, centre: actionsBar(b, snapshot)))
        }
        list.sort(by: E.drawsBefore)
        return list
    }

    /// The CPU reference points (clarification Q3): the floor centre, every colony's cap centre, the moon centre, the
    /// first gauge track's centre (when the level has colonies) and the first actions bar (when it has a budget).
    public static func referencePoints(_ snapshot: MushroomWeatherSceneSnapshot) -> [MushroomWeatherReferencePoint] {
        typealias R = MushroomWeatherReferencePoint
        var points: [R] = [R(kind: .floorCentre, index: 0, centre: floorCentre())]
        for k in snapshot.colonies.indices { points.append(R(kind: .cap, index: k, centre: capCentre(k, snapshot))) }
        points.append(R(kind: .moon, index: 0, centre: moonCentre()))
        if !snapshot.colonies.isEmpty { points.append(R(kind: .gaugeTrack, index: 0, centre: gaugeTrackCentre(0))) }
        if snapshot.budget > 0 { points.append(R(kind: .actionsBar, index: 0, centre: actionsBar(0, snapshot))) }
        return points
    }

    // MARK: Meshes

    /// The forest mesh for the forest program, in drawing order (see the header).
    public static func forestMesh(_ snapshot: MushroomWeatherSceneSnapshot,
                                  tier: MushroomWeatherTier) throws(MeshError) -> Mesh {
        try forestPart(snapshot, tier: tier).mesh
    }

    /// The glow mesh for the glow program (`glowPart` without colours); empty at level-2.
    public static func glowMesh(_ snapshot: MushroomWeatherSceneSnapshot,
                                tier: MushroomWeatherTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    /// The whole forest with fallback colours for the shared unlit renderer: each vertex in the base colour the forest
    /// vertex shader selects (``colour(of:won:)``: mist shaded by its value, the moon by its brightness, broken parts
    /// in the broken colour, out-of-band caps in the cap colour on a won level), the backdrop from midnight at its
    /// bottom to midnight top at its top. The mesh is ``forestMesh(_:tier:)``; `wonLevel` (default `snapshot.isWon`)
    /// changes only the colours.
    public static func forestPart(_ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier,
                                  wonLevel: Bool? = nil) throws(MeshError) -> MushroomWeatherColouredMesh {
        var parts: Parts = Parts()
        parts.won = (wonLevel ?? snapshot.isWon) ? 1 : 0
        for element in paintOrder(snapshot) {
            try draw(element, into: &parts, snapshot, tier: tier)
        }
        return parts.built()
    }

    /// Draws one element into `parts` (see the header).
    static func draw(_ element: MushroomWeatherElement, into parts: inout Parts,
                     _ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier) throws(MeshError) {
        let s: Double = scale(snapshot)
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        let x: SIMD3<Double> = SIMD3(1, 0, 0)
        let y: SIMD3<Double> = SIMD3(0, 1, 0)
        switch element.kind {
        case .backdrop:
            try backdrop(&parts)
        case .moon:
            try moon(&parts, moonlight: snapshot.moonlight)
        case .floor:
            let h: Double = floorSquare * s / 2
            try parts.shapeQuad(centre: c, u: x, v: y, half: SIMD2(h, h), code: code(.floor))
        case .blocked:
            let row: Int = snapshot.columns > 0 ? i / snapshot.columns : 0
            let column: Int = snapshot.columns > 0 ? i % snapshot.columns : 0
            if (row + column) % 2 == 0 {
                try log(&parts, centre: c, scale: s)
            } else {
                try stone(&parts, centre: c, scale: s)
            }
        case .fronds:
            if tier.fronds {
                for stem in frondStems(snapshot) {
                    try parts.frondStrip(stem.from, stem.to, width: frondWidths[stem.generation] * s,
                                         code: code(.frond))
                }
            }
        case .mist:
            let cell: MushroomWeatherCell = MushroomWeatherCell(row: snapshot.columns > 0 ? i / snapshot.columns : 0,
                                                                column: snapshot.columns > 0
                                                                    ? i % snapshot.columns : 0)
            let h: Int = humidity(cell, snapshot)
            let half: Double = mistSide(h, moldBound: snapshot.moldBound, scale: s) / 2
            try parts.shapeQuad(centre: c, u: x, v: y, half: SIMD2(half, half),
                                code: code(.mist, value: mistShare(h, moldBound: snapshot.moldBound)))
        case .mark:
            let h: Double = markSide * s / 2
            try parts.shapeQuad(centre: c, u: x, v: y, half: SIMD2(h, h), code: code(.moldPatch))
        case .site:
            let r: Double = siteRadius * s
            try parts.shapeQuad(centre: c, u: x, v: y, half: SIMD2(r, r), code: code(.siteRing))
        case .bandRing:
            let r: Double = bandRadius * s
            let material: MushroomWeatherMaterial = capLit(i, snapshot, won: false) ? .bandRingSolid : .bandRingDashed
            try parts.shapeQuad(centre: c, u: x, v: y, half: SIMD2(r, r),
                                code: code(material, broken: driedColony(snapshot) == i))
        case .stalk:
            try stalk(&parts, base: SIMD3(c.x, c.y, 0), scale: s, tier: tier)
        case .cap:
            let broken: Bool = driedColony(snapshot) == i
            let material: MushroomWeatherMaterial = capLit(i, snapshot, won: false) ? .cap : .capOut
            var share: Double = 0
            if !snapshot.colonies.isEmpty {
                let cell: MushroomWeatherCell = snapshot.colonies[clamped(i, snapshot.colonies.count)].cell
                share = mistShare(humidity(cell, snapshot), moldBound: snapshot.moldBound)
            }
            try cap(&parts, centre: c, scale: s, tier: tier, code: code(material, value: share, broken: broken),
                    wilted: broken)
        case .pod:
            let r: Double = podRadius(i, snapshot)
            try pod(&parts, centre: c, radius: r, scale: s, tier: tier, grown: snapshot.isGrown(i))
        case .droplets:
            let rise: Double = MushroomWeatherShaders.dropletRise(scale: s)
            let points: [(centre: SIMD3<Double>, phase: Double)] = droplets(i, snapshot, tier: tier)
            for point in points {
                try parts.billboardQuad(centre: point.centre, half: dropletHalf * s,
                                        code: code(.droplet, value: point.phase), w: rise)
            }
        case .motes:
            let radius: Double = MushroomWeatherShaders.moteLoopRadius
            for point in motes(tier: tier) {
                try parts.billboardQuad(centre: point.centre, half: moteHalf, code: code(.mote, value: point.phase),
                                        w: radius)
            }
        case .vent:
            try vent(&parts, centre: c, scale: s, open: ventOpen(i, snapshot))
        case .gauge:
            try gauge(&parts, i, snapshot)
        case .runBar:
            try runBar(&parts, i, snapshot)
        case .bar:
            let half: SIMD2<Double> = SIMD2(barFill * actionsSlot(snapshot) / 2, barHeight / 2)
            let material: MushroomWeatherMaterial = i < litActions(snapshot) ? .barLit : .barUnlit
            try parts.shapeQuad(centre: c, u: x, v: y, half: half, code: code(material))
        }
    }

    /// Draws the backdrop: a quad on the view axis at ``backdropDistance``, perpendicular to it (a_normal zero, a_uv.y
    /// the height).
    static func backdrop(_ parts: inout Parts) throws(MeshError) {
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis()
        let half: SIMD2<Double> = backdropHalf()
        let c: SIMD3<Double> = backdropCentre()
        let w: SIMD3<Double> = basis.right * half.x
        let h: SIMD3<Double> = basis.up * half.y
        let low: SIMD3<Double> = MushroomWeatherShaders.backdropColour(height: 0)
        let high: SIMD3<Double> = MushroomWeatherShaders.backdropColour(height: 1)
        try parts.quad([c - w - h, c + w - h, c + w + h, c - w + h], code: code(.backdrop), local: [0, 0, 1, 1],
                       colours: [low, low, high, high], facing: -basis.forward)
    }

    /// The moon's brightness (4 + L)/7 for moonlight L (clamped to 0 … 3), the moon's value.
    public static func moonBrightness(_ moonlight: Int) -> Double {
        MushroomWeatherShaders.moonBrightness(moonlight: moonlight)
    }

    /// The centre of phase tick `k` (0 top, 1 right, 2 bottom, 3 left), in the moon's eye-facing plane.
    public static func tickCentre(_ k: Int) -> SIMD3<Double> {
        let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) = billboardBasis(moonPosition)
        let angle: Double = Double.pi / 2 - Double(k) * Double.pi / 2
        return moonPosition + (b.right * cos(angle) + b.up * sin(angle)) * tickOrbit
    }

    /// The phase ticks drawn filled for moonlight L: L + 1 (clamped to 1 … 4).
    public static func filledTicks(_ moonlight: Int) -> Int { min(max(moonlight, 0), 3) + 1 }

    /// Draws the moon disc quad and its four phase tick quads.
    static func moon(_ parts: inout Parts, moonlight: Int) throws(MeshError) {
        try parts.billboardQuad(centre: moonPosition, half: moonRadius,
                                code: code(.moon, value: moonBrightness(moonlight)), w: 0)
        let filled: Int = filledTicks(moonlight)
        for k in 0..<tickCount {
            try parts.billboardQuad(centre: tickCentre(k), half: tickRadius,
                                    code: code(k < filled ? .phaseTickLit : .phaseTickUnlit), w: 0)
        }
    }

    /// Draws a log centred on the cell at `centre`: a cylinder along x of radius 0.15 s and length 0.8 s, axis at
    /// height 0.15 s, with flat ends.
    static func log(_ parts: inout Parts, centre: SIMD3<Double>, scale s: Double) throws(MeshError) {
        let r: Double = logRadius * s
        let half: Double = logLength * s / 2
        let axis: SIMD3<Double> = SIMD3(centre.x, centre.y, r)
        let n: Int = blockedSides
        let material: Double = code(.log)
        var left: [SIMD3<Double>] = []
        var right: [SIMD3<Double>] = []
        var normals: [SIMD3<Double>] = []
        for j in 0...n {
            let a: Double = 2 * Double.pi * Double(j % n) / Double(n)
            let e: SIMD3<Double> = SIMD3(0, cos(a), sin(a))
            normals.append(e)
            left.append(axis + SIMD3(-half, 0, 0) + e * r)
            right.append(axis + SIMD3(half, 0, 0) + e * r)
        }
        for j in 0..<n {
            try parts.quad([left[j], right[j], right[j + 1], left[j + 1]], code: material, local: [0, 0, 0, 0],
                           normals: [normals[j], normals[j], normals[j + 1], normals[j + 1]],
                           facing: normals[j] + normals[j + 1])
        }
        let ends: [(SIMD3<Double>, [SIMD3<Double>], SIMD3<Double>)] = [
            (axis + SIMD3(-half, 0, 0), Array(left.dropLast()), SIMD3(-1, 0, 0)),
            (axis + SIMD3(half, 0, 0), Array(right.dropLast()), SIMD3(1, 0, 0)),
        ]
        for (middle, outline, normal) in ends {
            try parts.fan(centre: middle, outline: outline, code: material, rim: 0, slot: normal, facing: normal)
        }
    }

    /// Draws a stone centred on the cell at `centre`: a dome of radius 0.36 s and height 0.2 s.
    static func stone(_ parts: inout Parts, centre: SIMD3<Double>, scale s: Double) throws(MeshError) {
        let a: Double = stoneRadius * s
        let h: Double = stoneHeight * s
        var profile: [(rho: Double, z: Double, normal: SIMD2<Double>)] = []
        for k in 0...stoneRings {
            let phi: Double = Double.pi / 2 * Double(k) / Double(stoneRings)
            let n: SIMD2<Double> = SIMD2(cos(phi) / a, sin(phi) / h)
            let length: Double = (n.x * n.x + n.y * n.y).squareRoot()
            profile.append((rho: a * cos(phi), z: h * sin(phi), normal: n / length))
        }
        try parts.lathe(base: SIMD3(centre.x, centre.y, 0), profile: profile, segments: blockedSides,
                        code: code(.stone))
    }

    /// The frond roots with their lean sign: a front corner of every blocked cell (+0.38 s, −0.38 s), then every
    /// other cell along the floor's top, bottom, left and right edges.
    public static func frondRoots(_ snapshot: MushroomWeatherSceneSnapshot)
        -> [(root: SIMD3<Double>, lean: Double)] {
        let s: Double = scale(snapshot)
        let z: Double = frondRootHeight * s
        var roots: [(root: SIMD3<Double>, lean: Double)] = []
        for (k, cell) in snapshot.blocked.enumerated() {
            let c: SIMD3<Double> = cellCentre(cell, snapshot, height: 0)
            roots.append((root: SIMD3(c.x + 0.38 * s, c.y - 0.38 * s, z), lean: k % 2 == 0 ? 1 : -1))
        }
        let halfX: Double = Double(snapshot.columns) * s / 2
        let halfY: Double = Double(snapshot.rows) * s / 2
        for column in stride(from: 0, to: max(snapshot.columns, 0), by: 2) {
            let x: Double = cellCentre(MushroomWeatherCell(row: 0, column: column), snapshot, height: 0).x
            roots.append((root: SIMD3(x, halfY, z), lean: column % 4 == 0 ? 1 : -1))
            roots.append((root: SIMD3(x, -halfY, z), lean: column % 4 == 0 ? -1 : 1))
        }
        for row in stride(from: 0, to: max(snapshot.rows, 0), by: 2) {
            let y: Double = cellCentre(MushroomWeatherCell(row: row, column: 0), snapshot, height: 0).y
            roots.append((root: SIMD3(-halfX, y, z), lean: -1))
            roots.append((root: SIMD3(halfX, y, z), lean: 1))
        }
        return roots
    }

    /// The frond stems in drawing order as (from, to, generation): per root a first stem leaning ±``frondLean`` from
    /// upright in the vertical plane facing the eye (the x–z plane), two branches turned ±``frondBranch`` from its tip
    /// and two more from each of theirs.
    public static func frondStems(_ snapshot: MushroomWeatherSceneSnapshot)
        -> [(from: SIMD3<Double>, to: SIMD3<Double>, generation: Int)] {
        let s: Double = scale(snapshot)
        var stems: [(from: SIMD3<Double>, to: SIMD3<Double>, generation: Int)] = []
        for root in frondRoots(snapshot) {
            var tips: [(point: SIMD3<Double>, angle: Double)] = [(point: root.root, angle: frondLean * root.lean)]
            for generation in 0..<frondLengths.count {
                var next: [(point: SIMD3<Double>, angle: Double)] = []
                for tip in tips {
                    let turns: [Double] = generation == 0 ? [0] : [-frondBranch, frondBranch]
                    for turn in turns {
                        let a: Double = tip.angle + turn
                        let end: SIMD3<Double> = tip.point + SIMD3(sin(a), 0, cos(a)) * (frondLengths[generation] * s)
                        stems.append((from: tip.point, to: end, generation: generation))
                        next.append((point: end, angle: a))
                    }
                }
                tips = next
            }
        }
        return stems
    }

    /// Draws a stalk standing on `base`: lathed (foot 0.07 s, top 0.05 s, 0.35 s tall), or at level-2 a flat solid: a
    /// rectangle fan 0.12 s wide from the floor to 0.35 s in the x–z plane facing the eye (a_uv.y 0 at its centre, 1 on
    /// its outline; a_normal zero).
    static func stalk(_ parts: inout Parts, base: SIMD3<Double>, scale s: Double,
                      tier: MushroomWeatherTier) throws(MeshError) {
        let height: Double = stalkHeight * s
        if tier.flatCaps {
            let w: Double = flatStalkWidth * s / 2
            let top: SIMD3<Double> = base + SIMD3(0, 0, height)
            try parts.fan(centre: base + SIMD3(0, 0, height / 2),
                          outline: [base + SIMD3(-w, 0, 0), base + SIMD3(w, 0, 0), top + SIMD3(w, 0, 0),
                                    top + SIMD3(-w, 0, 0)],
                          code: code(.stalk), rim: 1, facing: SIMD3(0, -1, 0))
            return
        }
        let foot: Double = stalkFoot * s
        let topRadius: Double = stalkTop * s
        let slope: Double = (foot - topRadius) / height
        let length: Double = (1 + slope * slope).squareRoot()
        let n: SIMD2<Double> = SIMD2(1 / length, slope / length)
        let profile: [(rho: Double, z: Double, normal: SIMD2<Double>)] = [
            (rho: foot, z: 0, normal: n), (rho: (foot + topRadius) / 2, z: height / 2, normal: n),
            (rho: topRadius, z: height, normal: n),
        ]
        try parts.lathe(base: base, profile: profile, segments: tier.latheSegments, code: code(.stalk))
    }

    /// Draws a cap at `centre` (the cap centre, height 0.45 s) with a_uv.x `material`: lathed (underside disc at the
    /// rim, dome from the rim to the apex; a wilted cap's rim lower), or a disc fan of radius 0.42 s facing the eye at
    /// level-2.
    static func cap(_ parts: inout Parts, centre: SIMD3<Double>, scale s: Double, tier: MushroomWeatherTier,
                    code material: Double, wilted: Bool) throws(MeshError) {
        let radius: Double = capRadius * s
        if tier.flatCaps {
            try parts.billboardDisc(centre: centre, radius: radius, sides: flatSides, code: material)
            return
        }
        let base: SIMD3<Double> = SIMD3(centre.x, centre.y, 0)
        let rim: Double = (wilted ? wiltedRim : capRim) * s
        let apex: Double = capApex * s
        let down: SIMD2<Double> = SIMD2(0, -1)
        let under: [(rho: Double, z: Double, normal: SIMD2<Double>)] = [(rho: 0, z: rim, normal: down),
                                                                        (rho: radius, z: rim, normal: down)]
        try parts.lathe(base: base, profile: under, segments: tier.latheSegments, code: material)
        var dome: [(rho: Double, z: Double, normal: SIMD2<Double>)] = []
        let rise: Double = apex - rim
        for k in 0...profileSteps {
            let phi: Double = Double.pi / 2 * Double(k) / Double(profileSteps)
            let n: SIMD2<Double> = SIMD2(cos(phi) / radius, sin(phi) / rise)
            let length: Double = (n.x * n.x + n.y * n.y).squareRoot()
            dome.append((rho: radius * cos(phi), z: rim + rise * sin(phi), normal: n / length))
        }
        try parts.lathe(base: base, profile: dome, segments: tier.latheSegments, code: material)
    }

    /// Draws a pod at `centre` (height 0.1 s) of `radius`: a lathed orb cut at the floor (a disc fan facing the eye at
    /// level-2) and, when grown, a horizontal `podRing` quad of outer radius r + 0.07 s at its centre.
    static func pod(_ parts: inout Parts, centre: SIMD3<Double>, radius: Double, scale s: Double,
                    tier: MushroomWeatherTier, grown: Bool) throws(MeshError) {
        if tier.flatCaps {
            try parts.billboardDisc(centre: centre, radius: radius, sides: flatSides, code: code(.pod))
        } else {
            let lowest: Double = asin(max(-1, -centre.z / radius))
            var profile: [(rho: Double, z: Double, normal: SIMD2<Double>)] = []
            for k in 0...profileSteps {
                let phi: Double = lowest + (Double.pi / 2 - lowest) * Double(k) / Double(profileSteps)
                profile.append((rho: radius * cos(phi), z: radius * sin(phi), normal: SIMD2(cos(phi), sin(phi))))
            }
            try parts.lathe(base: centre, profile: profile, segments: tier.latheSegments, code: code(.pod))
        }
        if grown {
            let outer: Double = radius + (podRingGap + podRingWidth) * s
            try parts.shapeQuad(centre: centre, u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0), half: SIMD2(outer, outer),
                                code: code(.podRing))
        }
    }

    /// The droplets of slot `slot`'s pod: `tier.droplets` droplets k, each at the start of its path (angle
    /// 2π (k + ½) / n, radius (0.08 + 0.12 · k / n) s from the pod's axis, height 0.1 s + 0.18 s) with phase k / n; the
    /// vertex shader raises it by up to ``MushroomWeatherShaders/dropletRise(scale:)``. Empty for an empty slot.
    public static func droplets(_ slot: Int, _ snapshot: MushroomWeatherSceneSnapshot,
                                tier: MushroomWeatherTier) -> [(centre: SIMD3<Double>, phase: Double)] {
        guard let centre = podCentre(slot, snapshot) else { return [] }
        let s: Double = scale(snapshot)
        let n: Int = max(tier.droplets, 0)
        var points: [(centre: SIMD3<Double>, phase: Double)] = []
        for k in 0..<n {
            let angle: Double = 2 * Double.pi * (Double(k) + 0.5) / Double(n)
            let phase: Double = Double(k) / Double(n)
            let r: Double = (dropletInner + dropletSpread * phase) * s
            points.append((centre: centre + SIMD3(r * cos(angle), r * sin(angle), dropletStart * s), phase: phase))
        }
        return points
    }

    /// The motes: `tier.motes` motes k, loop centre at angle a = 2π k / n on the ellipse of radii (0.95, 0.7) around
    /// (0, −0.05) at height 0.2 + 0.04 · sin(2a); each placed one ``MushroomWeatherShaders/moteLoopRadius`` to +x of
    /// its loop centre (where the vertex shader's loop starts), with phase k / n.
    public static func motes(tier: MushroomWeatherTier) -> [(centre: SIMD3<Double>, phase: Double)] {
        let n: Int = max(tier.motes, 0)
        let radius: Double = MushroomWeatherShaders.moteLoopRadius
        var points: [(centre: SIMD3<Double>, phase: Double)] = []
        for k in 0..<n {
            let a: Double = 2 * Double.pi * Double(k) / Double(n)
            let loop: SIMD3<Double> = SIMD3(moteLoop.x * cos(a), moteLoop.z + moteLoop.y * sin(a),
                                            moteLoop.w + 0.04 * sin(2 * a))
            points.append((centre: loop + SIMD3(radius, 0, 0), phase: Double(k) / Double(n)))
        }
        return points
    }

    /// Draws a vent at `centre` (height 0.9 s): four `ventFrame` rail strips and four `ventSlat` square quads, flat
    /// when shut, tilted 0.9 rad towards the eye about their long axes when open.
    static func vent(_ parts: inout Parts, centre: SIMD3<Double>, scale s: Double, open: Bool) throws(MeshError) {
        let half: Double = ventSide * s / 2
        let rail: Double = ventRail * s
        let m: Double = half - rail / 2
        let frame: Double = code(.ventFrame)
        try parts.strip(centre + SIMD3(-half, -m, 0), centre + SIMD3(half, -m, 0), width: rail, code: frame)
        try parts.strip(centre + SIMD3(half, m, 0), centre + SIMD3(-half, m, 0), width: rail, code: frame)
        try parts.strip(centre + SIMD3(-m, half - rail, 0), centre + SIMD3(-m, -half + rail, 0), width: rail,
                        code: frame)
        try parts.strip(centre + SIMD3(m, -half + rail, 0), centre + SIMD3(m, half - rail, 0), width: rail,
                        code: frame)
        let inner: Double = half - rail
        let pitch: Double = 2 * inner / Double(ventSlats)
        let tilt: Double = open ? slatTilt : 0
        let across: SIMD3<Double> = SIMD3(0, cos(tilt), sin(tilt))
        for k in 0..<ventSlats {
            let middle: SIMD3<Double> = centre + SIMD3(0, -inner + pitch * (Double(k) + 0.5), 0)
            try parts.shapeQuad(centre: middle, u: SIMD3(1, 0, 0), v: across, half: SIMD2(inner, slatWidth * s / 2),
                                code: code(.ventSlat))
        }
    }

    /// Draws colony `colony`'s gauge row: the track strip, the band bracket quad (u −1 at low … +1 at high, v −1 on the
    /// track's centre line … +1 at 0.026 above it) and the marker disc quad (broken when an unstable failure names the
    /// colony).
    static func gauge(_ parts: inout Parts, _ colony: Int, _ snapshot: MushroomWeatherSceneSnapshot) throws(MeshError) {
        let y: Double = gaugeY(colony)
        try parts.strip(SIMD3(gaugeStart, y, 0), SIMD3(gaugeEnd, y, 0), width: trackHeight, code: code(.gaugeTrack))
        guard colony < snapshot.colonies.count else { return }
        let entry: MushroomWeatherSceneColony = snapshot.colonies[colony]
        let low: Double = gaugeX(entry.low, top: snapshot.moldBound)
        let high: Double = gaugeX(max(entry.high, entry.low), top: snapshot.moldBound)
        let halfHeight: Double = (bracketOffset + bracketHeight / 2) / 2
        let halfWidth: Double = max((high - low) / 2, bracketMinimum)
        try parts.shapeQuad(centre: SIMD3((low + high) / 2, y + halfHeight, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0),
                            half: SIMD2(halfWidth, halfHeight), code: code(.bandBracket))
        try parts.shapeQuad(centre: markerCentre(colony, snapshot), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0),
                            half: SIMD2(markerHalf, markerHalf),
                            code: code(.marker, broken: unstableColony(snapshot) == colony))
    }

    /// The centre of run segment `segment` of colony `colony`: K (at least 1) slots from x 0.95 to 1.25.
    public static func runSegmentCentre(_ segment: Int, colony: Int,
                                        _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double> {
        let slot: Double = (runEnd - runStart) / Double(max(snapshot.requiredCycles, 1))
        return SIMD3(runStart + (Double(segment) + 0.5) * slot, gaugeY(colony), 0)
    }

    /// Draws colony `colony`'s run bar: K square quads, the first min(final run, K) `runLit`, the others `runUnlit`;
    /// broken when an unstable failure names the colony.
    static func runBar(_ parts: inout Parts, _ colony: Int,
                       _ snapshot: MushroomWeatherSceneSnapshot) throws(MeshError) {
        let k: Int = max(snapshot.requiredCycles, 1)
        let slot: Double = (runEnd - runStart) / Double(k)
        let half: SIMD2<Double> = SIMD2(barFill * slot / 2, runHeight / 2)
        let run: Int = colony < snapshot.colonies.count ? min(max(snapshot.colonies[colony].finalRun, 0), k) : 0
        let broken: Bool = unstableColony(snapshot) == colony
        for segment in 0..<k {
            try parts.shapeQuad(centre: runSegmentCentre(segment, colony: colony, snapshot), u: SIMD3(1, 0, 0),
                                v: SIMD3(0, 1, 0), half: half,
                                code: code(segment < run ? .runLit : .runUnlit, broken: broken))
        }
    }

    /// The glow with fallback colours (the cap or pod colour times the factor; a won level's caps at factor 1) for the
    /// shared unlit renderer: `tier.glowShells` shells k (outermost first), each an annulus of ``glowSides`` sides
    /// facing the eye — around every cap from 0.3 s to 0.42 s + 0.08 s · k at the cap centre (kind cap, factor
    /// ``MushroomWeatherShaders/glowFactor(inBand:)`` of its colony at the shown cycle) and around each placed pod from
    /// 0.6 r to r + 0.06 s · k at its centre (kind pod, factor 1). a_normal zero, a_uv.x
    /// ``MushroomWeatherShaders/GlowKind/code(factor:)``, a_uv.y 0 inside and 1 outside. Empty at level-2. `wonLevel`
    /// (default `snapshot.isWon`) changes only the colours.
    public static func glowPart(_ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier,
                                wonLevel: Bool? = nil) throws(MeshError) -> MushroomWeatherColouredMesh {
        typealias K = MushroomWeatherShaders.GlowKind
        var parts: Parts = Parts()
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let s: Double = scale(snapshot)
        let won: Bool = wonLevel ?? snapshot.isWon
        for k in stride(from: shells, through: 1, by: -1) {
            for colony in snapshot.colonies.indices {
                let factor: Double = MushroomWeatherShaders.glowFactor(inBand: capLit(colony, snapshot, won: false))
                try parts.glowBand(centre: capCentre(colony, snapshot), inner: capGlowInner * s,
                                   outer: (capRadius + capGlowGrowth * Double(k)) * s, code: K.cap.code(factor: factor),
                                   colour: MushroomWeatherPalette.cap * (won ? 1 : factor))
            }
            for slot in snapshot.pods.indices {
                guard let centre = podCentre(slot, snapshot) else { continue }
                let r: Double = podRadius(slot, snapshot)
                try parts.glowBand(centre: centre, inner: podGlowInner * r, outer: r + podGlowGrowth * s * Double(k),
                                   code: K.pod.code(factor: 1), colour: MushroomWeatherPalette.pod)
            }
        }
        return parts.built()
    }

    // MARK: Camera

    /// The view basis of the fixed camera: forward (unit, eye → target), right (forward × +y) and up (right × forward).
    static func viewBasis() -> (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) {
        let f: SIMD3<Double> = unit(lookAt - eye)
        let r: SIMD3<Double> = unit(cross(f, SIMD3(0, 1, 0)))
        return (forward: f, right: r, up: cross(r, f))
    }

    /// The basis of a part facing the eye at `centre`: right (+z × towards-eye, +x when degenerate), up and the unit
    /// direction towards the eye (right × up).
    static func billboardBasis(_ centre: SIMD3<Double>)
        -> (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) {
        let w: SIMD3<Double> = unit(eye - centre)
        let raw: SIMD3<Double> = cross(SIMD3(0, 0, 1), w)
        let length: Double = (raw.x * raw.x + raw.y * raw.y + raw.z * raw.z).squareRoot()
        let right: SIMD3<Double> = length > 1e-9 ? raw / length : SIMD3(1, 0, 0)
        return (right: right, up: cross(w, right), facing: w)
    }

    /// `aspect` made usable: 1 when not finite and positive, else clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// Corner `index` (0 … 7; bit 0 x, bit 1 y, bit 2 z, clear: low) of the authored box.
    static func corner(_ index: Int) -> SIMD3<Double> {
        SIMD3(index & 1 == 0 ? boxLow.x : boxHigh.x, index & 2 == 0 ? boxLow.y : boxHigh.y,
              index & 4 == 0 ? boxLow.z : boxHigh.z)
    }

    /// The fixed camera for `aspect`: from (0, −1.6, 3.0) looking at (0, −0.2, 0) with +y up; the vertical field of
    /// view is the smallest that holds every corner of the box x −1.3 … 1.3, y −1.5 … 1.2, z 0 … 0.3 inside the view
    /// with ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it keeps a margin
    /// of at least 5 % for aspect 0.4 … 2.5). Independent of the snapshot, the tier and the time.
    public static func camera(aspect: Double) -> MushroomWeatherCamera {
        let a: Double = usableAspect(aspect)
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis()
        let limit: Double = 1 - 2 * fitMargin
        var tanHalf: Double = 0
        var nearest: Double = Double.infinity
        var farthest: Double = 0
        for index in 0..<8 {
            let d: SIMD3<Double> = corner(index) - eye
            let depth: Double = dot(d, basis.forward)
            nearest = min(nearest, depth)
            farthest = max(farthest, depth)
            tanHalf = max(tanHalf, abs(dot(d, basis.up)) / depth / limit,
                          abs(dot(d, basis.right)) / depth / (a * limit))
        }
        let fovY: Double = 2 * atan(tanHalf)
        let near: Double = max(nearest * 0.5, 1e-3)
        let far: Double = max(farthest, backdropDistance) + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(lookAt), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return MushroomWeatherCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far,
                                     view: view, projection: projection, viewProjection: projection * view)
    }

    /// The backdrop's half width and half height: large enough to fill the view at its plane for every aspect in
    /// ``backdropAspects`` (5 % over).
    public static func backdropHalf() -> SIMD2<Double> {
        let tall: MushroomWeatherCamera = camera(aspect: backdropAspects.lowerBound)
        let wide: MushroomWeatherCamera = camera(aspect: backdropAspects.upperBound)
        let tanTall: Double = tan(tall.fovY / 2)
        let tanWide: Double = tan(wide.fovY / 2)
        let halfHeight: Double = backdropDistance * max(tanTall, tanWide) * 1.05
        let halfWidth: Double = backdropDistance * max(tanTall * tall.aspect, tanWide * wide.aspect) * 1.05
        return SIMD2(halfWidth, halfHeight)
    }

    /// The backdrop height h (0 at its bottom, 1 at its top; a_uv.y) seen at view point `view` (0 … 1, y down) through
    /// `camera`: the gradient's coordinate at that pixel (the backdrop is perpendicular to the view axis).
    public static func backdropHeight(view: SIMD2<Double>, camera: MushroomWeatherCamera) -> Double {
        let y: Double = (1 - 2 * view.y) * backdropDistance * tan(camera.fovY / 2)
        let half: Double = backdropHalf().y
        return min(max((y + half) / (2 * half), 0), 1)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: MushroomWeatherCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// The unit vector along `v` ((0, 0, 1) for a zero vector).
    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let length: Double = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
        return length > 0 ? v / length : SIMD3(0, 0, 1)
    }

    /// The cross product a × b.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// The dot product a · b.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from the side they face.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []
        /// The won light the fallback colours use (0 or 1).
        var won: Double = 0
        /// The side floor-parallel flats face: up, towards the eye.
        static let up: SIMD3<Double> = SIMD3(0, 0, 1)
        /// The zero vector (a_normal of strips, flat solids and the backdrop).
        static let zero: SIMD3<Double> = SIMD3(0, 0, 0)

        /// Adds (or welds) a vertex at `p` with a_normal `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour` (default ``MushroomWeatherSceneGeometry/colour(of:won:)`` of the code).
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>? = nil) throws(MeshError) -> UInt32 {
            typealias G = MushroomWeatherSceneGeometry
            let id: UInt32 = try builder.vertex(G.vec(p), normal: G.vec(slot), uv: Vec2(code, local))
            if Int(id) == colours.count {
                let tint: SIMD3<Double> = colour ?? G.colour(of: code, won: won)
                colours.append(Vec4(min(max(tint.x, 0), 1), min(max(tint.y, 0), 1), min(max(tint.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from the side `facing` points to; degenerate triangles are
        /// skipped.
        mutating func triangle(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                               _ pc: SIMD3<Double>, facing: SIMD3<Double>) throws(MeshError) {
            if ids.0 == ids.1 || ids.1 == ids.2 || ids.0 == ids.2 { return }
            let n: SIMD3<Double> = MushroomWeatherSceneGeometry.cross(pb - pa, pc - pa)
            let side: Double = MushroomWeatherSceneGeometry.dot(n, facing)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A quad (corners in order) facing `facing`, with uv (`code`, `local[k]`), a_normal per corner `normals`
        /// (default zero), in per-corner `colours` (default the code's).
        mutating func quad(_ p: [SIMD3<Double>], code: Double, local: [Double], colours tints: [SIMD3<Double>]? = nil,
                           normals: [SIMD3<Double>]? = nil, facing: SIMD3<Double> = Parts.up) throws(MeshError) {
            var ids: [UInt32] = []
            for k in 0..<4 {
                ids.append(try vertex(p[k], slot: normals?[k] ?? Parts.zero, code: code, local: local[k],
                                      colour: tints?[k]))
            }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2], facing: facing)
            try triangle((ids[0], ids[2], ids[3]), p[0], p[2], p[3], facing: facing)
        }

        /// A fan through the convex closed `outline` around `centre` facing `facing`: a_uv.y 0 at the centre and `rim`
        /// on the outline; a_normal `slot` (default zero).
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], code: Double, rim: Double,
                          slot: SIMD3<Double> = Parts.zero, facing: SIMD3<Double> = Parts.up) throws(MeshError) {
            let c: UInt32 = try vertex(centre, slot: slot, code: code, local: 0)
            var ids: [UInt32] = []
            for p in outline { ids.append(try vertex(p, slot: slot, code: code, local: rim)) }
            for k in outline.indices {
                let j: Int = (k + 1) % outline.count
                try triangle((c, ids[k], ids[j]), centre, outline[k], outline[j], facing: facing)
            }
        }

        /// A strip of `width` from `a` to `b` in a floor-parallel plane facing up (a_uv.y −1 … +1 across it, a_normal
        /// zero); nothing for a strip of length 0.
        mutating func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, code: Double) throws(MeshError) {
            let d: SIMD3<Double> = b - a
            let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
            guard length > 0 else { return }
            let w: SIMD3<Double> = SIMD3(d.y / length, -d.x / length, 0) * (width / 2)
            try quad([a + w, b + w, b - w, a - w], code: code, local: [-1, -1, 1, 1])
        }

        /// A frond stem: a strip of `width` from `a` to `b` in the x–z plane facing the eye (−y side), a_uv.y −1 … +1
        /// across it, a_normal zero.
        mutating func frondStrip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double,
                                 code: Double) throws(MeshError) {
            let d: SIMD3<Double> = b - a
            let length: Double = (d.x * d.x + d.z * d.z).squareRoot()
            guard length > 0 else { return }
            let w: SIMD3<Double> = SIMD3(d.z / length, 0, -d.x / length) * (width / 2)
            try quad([a + w, b + w, b - w, a - w], code: code, local: [-1, -1, 1, 1], facing: SIMD3(0, -1, 0))
        }

        /// A quad of shape half `half` around `centre` in the plane of the unit axes `u` and `v` (facing u × v): the
        /// corners at ±``MushroomWeatherShaders/quadExtent`` · half, a_normal (±extent, ±extent, `w`), a_uv.y 0.
        mutating func shapeQuad(centre: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>, half: SIMD2<Double>,
                                code: Double, w: Double = 0) throws(MeshError) {
            let e: Double = MushroomWeatherShaders.quadExtent
            let a: SIMD3<Double> = u * (e * half.x)
            let b: SIMD3<Double> = v * (e * half.y)
            try quad([centre - a - b, centre + a - b, centre + a + b, centre - a + b], code: code, local: [0, 0, 0, 0],
                     normals: [SIMD3(-e, -e, w), SIMD3(e, -e, w), SIMD3(e, e, w), SIMD3(-e, e, w)],
                     facing: MushroomWeatherSceneGeometry.cross(u, v))
        }

        /// A square quad of shape half `half` facing the eye at `centre` (``shapeQuad(centre:u:v:half:code:w:)`` in the
        /// eye-facing basis).
        mutating func billboardQuad(centre: SIMD3<Double>, half: Double, code: Double, w: Double) throws(MeshError) {
            let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) =
                MushroomWeatherSceneGeometry.billboardBasis(centre)
            try shapeQuad(centre: centre, u: b.right, v: b.up, half: SIMD2(half, half), code: code, w: w)
        }

        /// A flat solid: a disc fan of `radius` facing the eye at `centre` in `sides` triangles, a_uv.y 0 at the centre
        /// and 1 on the rim, a_normal zero.
        mutating func billboardDisc(centre: SIMD3<Double>, radius: Double, sides: Int,
                                    code: Double) throws(MeshError) {
            let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) =
                MushroomWeatherSceneGeometry.billboardBasis(centre)
            let n: Int = max(sides, 3)
            var outline: [SIMD3<Double>] = []
            for k in 0..<n {
                let a: Double = 2 * Double.pi * Double(k) / Double(n)
                outline.append(centre + (b.right * cos(a) + b.up * sin(a)) * radius)
            }
            try fan(centre: centre, outline: outline, code: code, rim: 1, facing: b.facing)
        }

        /// A surface of revolution about the vertical axis through `base`: profile points (radius ρ, height z, unit
        /// profile normal (radial, vertical)) in order, `segments` sides (at least 3), a_normal the unit world normal,
        /// a_uv.y 0; each triangle faces along its vertices' normals.
        mutating func lathe(base: SIMD3<Double>, profile: [(rho: Double, z: Double, normal: SIMD2<Double>)],
                            segments: Int, code: Double) throws(MeshError) {
            let n: Int = max(segments, 3)
            guard profile.count >= 2 else { return }
            var rings: [[(point: SIMD3<Double>, normal: SIMD3<Double>)]] = []
            for point in profile {
                var ring: [(point: SIMD3<Double>, normal: SIMD3<Double>)] = []
                for j in 0...n {
                    let a: Double = 2 * Double.pi * Double(j % n) / Double(n)
                    let e: SIMD3<Double> = SIMD3(cos(a), sin(a), 0)
                    let normal: SIMD3<Double> = e * point.normal.x + SIMD3(0, 0, point.normal.y)
                    ring.append((point: base + e * point.rho + SIMD3(0, 0, point.z), normal: normal))
                }
                rings.append(ring)
            }
            for i in 0..<(profile.count - 1) {
                for j in 0..<n {
                    let corners: [(point: SIMD3<Double>, normal: SIMD3<Double>)] = [rings[i][j], rings[i][j + 1],
                                                                                    rings[i + 1][j + 1],
                                                                                    rings[i + 1][j]]
                    var ids: [UInt32] = []
                    for corner in corners {
                        ids.append(try vertex(corner.point, slot: corner.normal, code: code, local: 0))
                    }
                    let out1: SIMD3<Double> = corners[0].normal + corners[1].normal + corners[2].normal
                    let out2: SIMD3<Double> = corners[0].normal + corners[2].normal + corners[3].normal
                    try triangle((ids[0], ids[1], ids[2]), corners[0].point, corners[1].point, corners[2].point,
                                 facing: out1)
                    try triangle((ids[0], ids[2], ids[3]), corners[0].point, corners[2].point, corners[3].point,
                                 facing: out2)
                }
            }
        }

        /// A glow band: an annulus of ``MushroomWeatherSceneGeometry/glowSides`` sides from `inner` (a_uv.y 0) to
        /// `outer` (a_uv.y 1) facing the eye at `centre`, a_normal zero, a_uv.x `code`, fallback colour `colour`.
        mutating func glowBand(centre: SIMD3<Double>, inner: Double, outer: Double, code: Double,
                               colour: SIMD3<Double>) throws(MeshError) {
            let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) =
                MushroomWeatherSceneGeometry.billboardBasis(centre)
            let n: Int = MushroomWeatherSceneGeometry.glowSides
            for k in 0..<n {
                let a0: Double = 2 * Double.pi * Double(k) / Double(n)
                let a1: Double = 2 * Double.pi * Double(k + 1) / Double(n)
                let e0: SIMD3<Double> = b.right * cos(a0) + b.up * sin(a0)
                let e1: SIMD3<Double> = b.right * cos(a1) + b.up * sin(a1)
                try quad([centre + e0 * inner, centre + e0 * outer, centre + e1 * outer, centre + e1 * inner],
                         code: code, local: [0, 1, 1, 0], colours: [colour, colour, colour, colour],
                         facing: b.facing)
            }
        }

        /// The coloured mesh built so far.
        func built() -> MushroomWeatherColouredMesh {
            MushroomWeatherColouredMesh(mesh: builder.build(), colours: colours)
        }
    }
}
