// MyceliumArchitectSceneGeometry — feature 513 (R02-G22-03) T-R02G2203-003 (FR-R02G2203-001, 003, 006;
// SC-R02G2203-003; clarifications Q1–Q5; research R1, R3–R6, R9). The cave floor of Mycelium Architect, built from a
// snapshot only. The board lies in the plane z = 0 (x right, y up the board, z up out of it). One fit rule per level
// (clarification Q1, research R1): with s = 1.9 / max(W, H), cell (c, r) has its centre at ((c + 0.5 − W/2)·s,
// 0.05 + (H/2 − r − 0.5)·s, 0), so every board fills the same square of side 1.9 centred at (0, 0.05) and nothing a
// player does changes the scale. Nothing here is consulted by the rules, and nothing depends on the presentation time.
//
// Draw order (research R4): the board mesh is drawn in painter's order with depth testing off and no face culling (the
// window surface of the shared renderer has no depth buffer), in the order of the elements
// (``MyceliumArchitectElement``), by kind and then by index:
//    0. backdrop: one quad perpendicular to the view axis at ``MyceliumArchitectSceneGeometry/backdropDistance`` from
//       the eye, filling the view for aspects 0.25 … 4 (the still gradient cave … cave top; the spore points are the
//       shader's);
//    1. floor: the floor plate x −0.98 … 0.98, y −0.93 … 1.03, then the W + 1 vertical and H + 1 horizontal `grid`
//       strips on the cell boundaries;
//    2. site: per placement site a dashed square of half 0.4·s (inset by 0.1·s); on a failed play that starved,
//       one more site element: the cell the step could not grow into, marked broken (the dashed broken outline);
//    3. toxin: per toxin a pool of half 0.42·s (value: its hashed ripple phase); on a toxic failure, right after the
//       entered toxin's pool, a broken `pipHollow` ring of half 0.5·s around it;
//    4. rock: per rock a raised block of side 0.9·s and height 0.3·s (top and four sides);
//    5. blocker: per placed blocker a stone disc of half 0.38·s;
//    6. nutrient: per fixed then placed nutrient an orb of half 0.3·s (value 1 for a placed one: the outer ring, 0 for
//       a fixed one); `nutrientConsumed` (the dim ring) once the step that consumed it is shown;
//    7. vein: per shown grown cell but the root, in growth order, one tapered tube of `tier.tubeSides` sides from the
//       parent's centre to the child's, radius 0.16·s − 0.10·s · w / w_max at each end (w that end's path weight,
//       w_max the network's largest), resting on the floor (axis at z = radius);
//    8. bloom: per consumed nutrient whose step is shown, a disc of half 0.22·s at its cell;
//    9. fuzz: one group: at the tiers with fuzz, `tier.fuzzStrands` strands per branch point (a shown cell with two or
//       more shown children; 0 … 0.4·s out) and per open terminal cap (0.3·s … 0.5·s out), at hashed angles;
//   10. spore: one group: at the tiers with spores, `tier.spores` hashed spore dots over the board, beneath the
//       sprouts and caps so this decoration never hides them;
//   11. sprout: per seed, a short tapered tube from the root 0.4·s towards the seeded direction (0.1·s → 0.04·s);
//   12. root: the root cap, a flattened dome of radius 0.36·s and `tier.capSegments` segments;
//   13. terminal: per terminal a flattened dome of radius 0.42·s, `terminalOpen` when ``MyceliumArchitectSceneSnapshot/
//       isReached(_:)`` else `terminalClosed`, with its ring of terminal + 1 pips (half 0.06·s on a circle of 0.5·s,
//       filled when reached, hollow otherwise); for the terminal an unreached failure names, then a broken `pipHollow`
//       ring of half 0.5·s around it;
//   14. gauge: the weight bar: the plate x −0.95 … 0.95, y −1.12 ± 0.045; the fill from x −0.9 over 1.8 · min(weight,
//       budget) / budget (value: that fraction; on an overweight failure the part past the limit broken); the limit
//       tick at the weight limit; the budget end tick at x 0.9 (a `limitTick`, broken on a starved failure);
//   15. pip: per terminal a pip of half 0.018 on the row y = −1.24, 0.06 apart, filled when reached;
//   16. actions: `budget` bars at y = −1.34, each 1.9 / budget wide with a fifth as gap, 0.035 tall, lit for the
//       actions left;
//   17. glow: the glow mesh, drawn last and additively (``glow(_:tier:)``).
// A solid (rock, tube, dome) emits its triangles facing away from the eye first, so its near side covers its far side.
//
// Failures (clarification Q4) are marked only on a play that failed (stage `failed`, or `result` after a failed run),
// never for the predicted failure while playing (as feature 503). The broken mark changes only the colour; the
// geometry chooses the shape: toxic — a broken `pipHollow` ring around the entered toxin; starved — a broken site (the
// dashed outline) on its cell and the broken budget end tick; unreached — a broken `pipHollow` ring around the named
// terminal; overweight — the weight fill past the limit tick broken.
//
// Vertex streams (clarification Q5, research R6): a_uv.x = ``MyceliumArchitectMaterial/encode(_:value:broken:)``, the
// material code + 0.25 · value (a value 0 … 1, for the valued materials only: toxin its ripple phase, nutrient 1 when
// placed, vein its path-weight fraction, weightFill its fill fraction, fuzz and spore their phase k / n) + 0.5 when
// broken; the shader reads code = floor(x + 0.001) and broken when the remainder is at least 0.375.
//   * Flats (floor, grid, site, toxin, blocker, nutrient, nutrientConsumed, bloom, gaugePlate, weightFill, limitTick,
//     pipFilled, pipHollow, actionsLit, actionsUnlit, fuzz, spore): a quad of half (hx, hy) spanning exactly ±hx, ±hy
//     around its centre in the plane z = const facing up; a_normal (u, v, 0) its quad-local coordinate −1 … 1 (a fuzz
//     strand's v runs from −1 at its base to 1 at its tip); a_uv.y 0. The shader cuts the shape out by signed
//     distance.
//   * Solids: a_normal the unit surface normal (a tube vertex: its ring normal). Veins and sprouts: a_uv.y 0 at the
//     parent (root) end and 1 at the child end, a vein's value that end's path-weight fraction. Caps (root,
//     terminalClosed, terminalOpen): a_uv.y the radial share cos φ (1 at the rim, 0 at the apex). Rocks: a_uv.y 1 on
//     the top, 0 on the sides.
//   * Backdrop: a_normal its plane offsets (x, y, 0), a_uv.y the height 0 … 1.
//   * Glow mesh: flat annuli at z = 0.002 facing up; a_normal the glowing element's colour (zero for a bloom: the
//     shader's emerald), a_uv.x the shell factor 0 … 1 (1 for the innermost shell, 1 − (k − 1) / shells for shell k),
//     a_uv.y the radial share 0 (centre) … 1 (the annulus's outer edge).
// Spores, fuzz angles and lengths come from a fixed integer hash, never a random source. Tiers change only the tube
// sides, the cap segments, the fuzz, the spores and the glow: every element centre is the same at every tier. Doubles
// are used for drawing only. Modelled on `BinaryGardensSceneGeometry` (feature 503).
//
// Feature 514 (R02-G22-04) T-R02G2204-002 (FR-R02G2204-006, 008, 013, 014; SC-R02G2204-003, 004, 006; clarifications
// Q3, Q5; research R4, R6, R7) adds, presentation only and modelled on feature 504:
//   * the player's view orbit (``MyceliumArchitectViewOrbit``, carried by the snapshot) and `camera(aspect:orbit:)`: the
//     authored camera frame (eye, look-at point and up direction) is turned rigidly by the pitch about the authored
//     right axis (+x) through the look-at point (positive raises the eye), then by the yaw about the vertical axis (+z)
//     through the look-at point, so the camera always looks at (0, −0.3, 0); the field of view stays the authored one
//     for the aspect and the eye moves along the turned view axis to the larger of the authored distance (≈ 3.22) and
//     the distance at which every corner of the authored box lies inside the view with ``refitMargin`` per side, so
//     everything inside the box (board, gauges, pips, actions bars) keeps a margin of at least 5 % at every orbit within
//     bounds and every aspect 0.4 … 2.5, and the eye stays in front of every corner. At the authored orbit it is
//     `camera(aspect:)`, bit for bit;
//   * the drawn eye (``drawnEye(_:)``): the solids emit their far triangles first as seen from the orbit's eye, and the
//     backdrop stands perpendicular to the orbit's view axis, ``backdropDistance`` − the authored eye distance beyond
//     the look-at point, enlarged so it fills the view of every orbit camera for the aspects 0.25 … 4
//     (``backdropFrame(_:)``); at the authored orbit both are R02-G22-03's;
//   * the ghost veins of an accepted preview (``ghostVeins(_:)``, clarification Q3): every vein of the previewed report
//     (whole growth, every pulse) as ``ghostDashes`` dashes of duty ``ghostDuty`` along the segment from the parent's
//     centre to the child's, flat `limitTick` strips ``ghostWidth``·s wide at height ``ghostLift``·s (above every
//     committed tube), drawn right before the fuzz element, so over the committed veins and blooms and under the
//     sprouts and caps. The shaders have no ghost material, so the dashes are cut geometrically and the shaders are
//     unchanged; a refused preview draws nothing ghostly (the refusal is named in words by the presenter);
//   * the inspection ring (FR-R02G2204-005, 013): a `pipHollow` ring of half ``inspectRing``·s (outside the failure
//     marks' 0.5·s and the terminal pips' circle) around the inspected cell, drawn right before the gauge element, so
//     over every cap.
// Without a preview and an inspection, at the authored orbit, every mesh is R02-G22-03's. The orbit, the tool, the
// preview and the inspection are presentation only: never saved, never read by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The material codes of the board mesh (a_uv.x, clarification Q5), shared with `MyceliumArchitectShaders`, whose
/// GLSL decodes exactly these values.
enum MyceliumArchitectMaterial: Int, Sendable, CaseIterable {
    /// 0: the cave backdrop (gradient cave … cave top with hashed spore points).
    case backdrop = 0
    /// 1: the floor plate under the board.
    case floor = 1
    /// 2: a grid line of the floor.
    case grid = 2
    /// 3: a placement site's dashed square (broken: the cell a starved step could not grow into).
    case site = 3
    /// 4: a toxin pool with concentric ripples (valued: its ripple phase).
    case toxin = 4
    /// 5: a rock block with copper veins.
    case rock = 5
    /// 6: a blocker's stone disc with its ring.
    case blocker = 6
    /// 7: a nutrient orb (valued: 1 for a placed nutrient with its outer ring, 0 for a fixed one).
    case nutrient = 7
    /// 8: a consumed nutrient, the dim ring.
    case nutrientConsumed = 8
    /// 9: a grown vein tube (valued: the path-weight fraction at that end).
    case vein = 9
    /// 10: a bloom where a nutrient was consumed.
    case bloom = 10
    /// 11: a seeded direction's sprout tube.
    case sprout = 11
    /// 12: the root cap.
    case root = 12
    /// 13: a terminal cap not reached by the shown pulse.
    case terminalClosed = 13
    /// 14: a terminal cap reached by the shown pulse.
    case terminalOpen = 14
    /// 15: the weight gauge's plate.
    case gaugePlate = 15
    /// 16: the weight fill (valued: min(weight, budget) / budget; broken: the part past the limit when overweight).
    case weightFill = 16
    /// 17: the limit tick and the budget end tick (broken when starved).
    case limitTick = 17
    /// 18: a filled pip (a reached terminal).
    case pipFilled = 18
    /// 19: a hollow pip (an unreached terminal; broken: the ring around a toxic failure's toxin or an unreached
    /// failure's terminal).
    case pipHollow = 19
    /// 20: a lit actions bar.
    case actionsLit = 20
    /// 21: an unlit actions bar.
    case actionsUnlit = 21
    /// 22: a hyphae fuzz strand (valued: its phase k / n).
    case fuzz = 22
    /// 23: a drifting spore (valued: its phase k / n).
    case spore = 23

    /// The scale of a value in a_uv.x: code + 0.25 · value.
    static let valueScale: Double = 0.25
    /// The offset a broken mark adds to a_uv.x.
    static let brokenOffset: Double = 0.5

    /// Whether the material carries a value: toxin (ripple phase), nutrient (1: placed), vein (path-weight fraction),
    /// weightFill (fill fraction), fuzz and spore (phase).
    var isValued: Bool {
        switch self {
        case .toxin, .nutrient, .vein, .weightFill, .fuzz, .spore: return true
        default: return false
        }
    }

    /// The a_uv.x of `material` with `value` (clamped to 0 … 1; non-finite as 0; ignored for a material without a
    /// value) and the broken mark: code + 0.25 · value + 0.5 when broken.
    static func encode(_ material: MyceliumArchitectMaterial, value: Double = 0, broken: Bool = false) -> Double {
        var v: Double = value.isFinite ? min(max(value, 0), 1) : 0
        if !material.isValued { v = 0 }
        return Double(material.rawValue) + valueScale * v + (broken ? brokenOffset : 0)
    }

    /// The material, value and broken mark of an a_uv.x as the shader reads it (code = floor(x + 0.001), broken when
    /// the remainder is at least 0.375; the inverse of ``encode(_:value:broken:)``; an unknown code reads as the
    /// backdrop).
    static func decode(_ x: Double) -> (material: MyceliumArchitectMaterial, value: Double, broken: Bool) {
        let safe: Double = x.isFinite ? max(x, 0) : 0
        let whole: Double = (safe + 0.001).rounded(.down)
        let fraction: Double = max(safe - whole, 0)
        let broken: Bool = fraction >= 0.375
        let value: Double = min(max((fraction - (broken ? brokenOffset : 0)) / valueScale, 0), 1)
        let material: MyceliumArchitectMaterial = MyceliumArchitectMaterial(rawValue: Int(whole)) ?? .backdrop
        return (material, material.isValued ? value : 0, broken)
    }

    /// The flat fallback colour of the material (the unlit renderer), from ``MyceliumArchitectPalette``; the backdrop
    /// gives its bottom colour (cave).
    var colour: Vec4 {
        typealias P = MyceliumArchitectPalette
        switch self {
        case .backdrop: return P.cave
        case .floor: return P.floor
        case .grid: return P.grid
        case .site: return P.site
        case .toxin: return P.toxin
        case .rock: return P.rock
        case .blocker: return P.blocker
        case .nutrient: return P.nutrient
        case .nutrientConsumed: return Vec4(P.nutrient.x * 0.45, P.nutrient.y * 0.45, P.nutrient.z * 0.45, 1)
        case .vein: return P.emerald
        case .bloom: return P.spore
        case .sprout: return P.sprout
        case .root: return P.cap
        case .terminalClosed: return P.capClosed
        case .terminalOpen: return P.capOpen
        case .gaugePlate: return P.gaugePlate
        case .weightFill: return P.weight
        case .limitTick: return P.limit
        case .pipFilled: return P.capOpen
        case .pipHollow: return P.ring
        case .actionsLit: return P.actionsLit
        case .actionsUnlit: return P.actionsUnlit
        case .fuzz: return P.spore
        case .spore: return P.spore
        }
    }
}

/// The kind of a glow shell, which selects its colour (a_normal of the glow mesh).
enum MyceliumArchitectGlowKind: Int, Sendable, CaseIterable {
    /// A shell around the root cap (a_normal: cap #9FF2D0).
    case root = 0
    /// A shell around an open terminal cap (a_normal: cap open #C9FFE9).
    case terminal = 1
    /// A shell around a bloom (a_normal zero: emerald #2FE08A).
    case bloom = 2

    /// The colour the shell carries in a_normal (zero for a bloom: the shader's emerald).
    var slot: SIMD3<Double> {
        switch self {
        case .root, .terminal: return SIMD3(colour.x, colour.y, colour.z)
        case .bloom: return SIMD3(0, 0, 0)
        }
    }

    /// The shell's fallback colour.
    var colour: Vec4 {
        switch self {
        case .root: return MyceliumArchitectPalette.cap
        case .terminal: return MyceliumArchitectPalette.capOpen
        case .bloom: return MyceliumArchitectPalette.emerald
        }
    }
}

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct MyceliumArchitectCamera: Sendable, Equatable {
    /// The eye position in world units, (0, −1.9, 2.8).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.3, 0).
    public let target: SIMD3<Double>
    /// The vertical field of view in radians (fitted to the authored box at `aspect`).
    public let fovY: Double
    /// The width-to-height ratio used (sanitised to 0.1 … 10; 1 when not finite and positive).
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

/// One drawn element of the scene with its place in the drawing order (research R4).
public struct MyceliumArchitectElement: Sendable, Equatable {
    /// The kind of an element, in the drawing order.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The cave backdrop.
        case backdrop = 0
        /// The floor plate with its grid.
        case floor = 1
        /// A placement site (`item` the site; one past the sites: a starved failure's cell).
        case site = 2
        /// A toxin pool (`item` the toxin).
        case toxin = 3
        /// A rock block (`item` the rock).
        case rock = 4
        /// A placed blocker (`item` the blocker).
        case blocker = 5
        /// A nutrient orb (`item`: fixed nutrients first, then placed ones).
        case nutrient = 6
        /// A vein tube (`item` the grown cell's index, at least 1).
        case vein = 7
        /// A bloom (`item` the consumed nutrient's index in step order).
        case bloom = 8
        /// The hyphae fuzz (one group; nothing at a tier without fuzz).
        case fuzz = 9
        /// The spores (one group; nothing at a tier without spores), beneath the caps so decoration never hides them.
        case spore = 10
        /// A sprout (`item` the seed's index in the arrangement).
        case sprout = 11
        /// The root cap.
        case root = 12
        /// A terminal cap with its pips (`item` the terminal).
        case terminal = 13
        /// The weight gauge.
        case gauge = 14
        /// A terminal pip of the gauge row (`item` the terminal).
        case pip = 15
        /// An actions bar (`item` the bar).
        case actions = 16
        /// A glow shell group of the glow mesh (`item` 0 the root, 1 + t open terminal t, 1 + terminals + b bloom b).
        case glow = 17
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind.
    public let index: Int
    /// The item the element draws (0 for the single elements).
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
}

/// A point of the CPU reference (clarification Q3).
public struct MyceliumArchitectReferencePoint: Sendable, Equatable {
    /// What the point marks.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The board centre, (0, 0.05, 0).
        case boardCentre = 0
        /// The root's cell centre.
        case root = 1
        /// A terminal's cell centre.
        case terminal = 2
        /// The weight plate's left margin, (−0.925, −1.12, 0).
        case gaugeMargin = 3
        /// The first actions bar's centre.
        case actionsBar = 4
    }

    /// What the point marks.
    public let kind: Kind
    /// The terminal index (0 for the single points).
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
public struct MyceliumArchitectColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Mycelium Architect cave floor from a `MyceliumArchitectSceneSnapshot`: places, meshes, camera and
/// projection (see the file header).
public enum MyceliumArchitectSceneGeometry {
    // MARK: Constants (world units; "· s" sizes are shares of the fit scale)

    /// The side of the square every board fills (clarification Q1).
    public static let boardSide: Double = MyceliumArchitectSceneSnapshot.boardSide
    /// The y of the board's centre.
    public static let boardCentreY: Double = 0.05
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, -1.9, 2.8)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.3, 0)
    /// The box the camera holds and every board vertex but the backdrop's lies in: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-1.05, -1.45, 0)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1.05, 1.05, 0.25)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The aspects the backdrop fills.
    public static let backdropAspects: ClosedRange<Double> = 0.25...4
    /// The backdrop's distance from the eye along the view axis.
    public static let backdropDistance: Double = 7
    /// The radius of a failure's broken ring (a `pipHollow`) as a share of s.
    static let markRing: Double = 0.5
    /// The floor plate's lower corner (x, y).
    static let floorLow: SIMD2<Double> = SIMD2(-0.98, -0.93)
    /// The floor plate's upper corner (x, y).
    static let floorHigh: SIMD2<Double> = SIMD2(0.98, 1.03)
    /// A grid line's width as a share of s.
    static let gridWidth: Double = 0.02
    /// A site square's half as a share of s (inset by 0.1·s).
    static let siteHalf: Double = 0.4
    /// A toxin pool's radius as a share of s.
    static let toxinRadius: Double = 0.42
    /// A rock block's side as a share of s.
    static let rockSide: Double = 0.9
    /// A rock block's height as a share of s.
    static let rockHeight: Double = 0.3
    /// A blocker disc's radius as a share of s.
    static let blockerRadius: Double = 0.38
    /// A nutrient orb's radius as a share of s.
    static let nutrientRadius: Double = 0.3
    /// A vein's radius at path weight 0 as a share of s.
    static let veinRootRadius: Double = 0.16
    /// A vein's radius at the largest path weight as a share of s.
    static let veinTipRadius: Double = 0.06
    /// A bloom's radius as a share of s.
    static let bloomRadius: Double = 0.22
    /// A branch-point fuzz strand's length as a share of s.
    static let fuzzLength: Double = 0.4
    /// Where a cap fuzz strand starts, as a share of s.
    static let capFuzzStart: Double = 0.3
    /// Where a cap fuzz strand ends, as a share of s.
    static let capFuzzEnd: Double = 0.5
    /// A fuzz strand's width as a share of s.
    static let fuzzWidth: Double = 0.025
    /// A sprout's length as a share of s.
    static let sproutLength: Double = 0.4
    /// A sprout's radius at the root as a share of s.
    static let sproutRootRadius: Double = 0.1
    /// A sprout's radius at its tip as a share of s.
    static let sproutTipRadius: Double = 0.04
    /// The root cap's radius as a share of s.
    static let rootCapRadius: Double = 0.36
    /// A terminal cap's radius as a share of s.
    static let terminalCapRadius: Double = 0.42
    /// A cap dome's height as a share of its radius.
    static let capHeight: Double = 0.55
    /// The latitude rings of a cap dome below its apex.
    static let capRings: Int = 4
    /// The radius of a terminal's pip ring as a share of s.
    static let capPipRing: Double = 0.5
    /// A terminal cap pip's half as a share of s.
    static let capPipHalf: Double = 0.06
    /// A spore's half.
    static let sporeHalf: Double = 0.012
    /// The farthest the shader may drift a spore from its vertex position, in x and y.
    static let sporeDrift: Double = 0.04
    /// The lowest spore height.
    static let sporeLow: Double = 0.06
    /// The highest spore height.
    static let sporeHigh: Double = 0.2
    /// The weight plate's left end.
    static let plateLeft: Double = -0.95
    /// The weight plate's right end.
    static let plateRight: Double = 0.95
    /// The weight plate's centre line.
    static let gaugeY: Double = -1.12
    /// The weight plate's half height.
    static let plateHalf: Double = 0.045
    /// The x of the reference point on the plate's left margin.
    static let marginX: Double = -0.925
    /// The fill's left end (weight 0).
    static let fillStart: Double = -0.9
    /// The fill's right end (the nutrient budget).
    static let fillEnd: Double = 0.9
    /// The fill's half height.
    static let fillHalf: Double = 0.015
    /// A tick's half width.
    static let tickHalfWidth: Double = 0.003
    /// A tick's half height.
    static let tickHalfHeight: Double = 0.035
    /// The terminal pip row's centre line.
    static let pipRowY: Double = -1.24
    /// A pip's half on the row.
    static let pipHalf: Double = 0.018
    /// The step between pips on the row.
    static let pipStep: Double = 0.06
    /// The actions bars' centre line.
    static let actionsY: Double = -1.34
    /// The actions bars' left end.
    static let actionsStart: Double = -0.95
    /// The actions bars' width in all.
    static let actionsWidth: Double = 1.9
    /// An actions bar's height.
    static let actionsHeight: Double = 0.035
    /// The share of a slot a bar fills (the rest, a fifth, is the gap).
    static let barFill: Double = 0.8
    /// The height of the glow annuli.
    static let glowLift: Double = 0.002
    /// A glow shell's inner radius as a share of its element's radius.
    static let glowInner: Double = 0.9
    /// A glow shell's growth per shell as a share of s.
    static let glowGrowth: Double = 0.08
    /// The sides of a glow annulus.
    static let glowSides: Int = 24
    /// The margin per side in view coordinates an orbiting camera refits the authored box to (feature 514; equal to
    /// ``fitMargin``, so the refit is continuous at the authored orbit).
    public static let refitMargin: Double = 0.06
    /// The width of a ghost vein's dashes as a share of s (feature 514).
    public static let ghostWidth: Double = 0.06
    /// The height of a ghost vein's dashes as a share of s, above every committed tube (top 0.32·s) (feature 514).
    public static let ghostLift: Double = 0.34
    /// The dashes along one ghost vein (feature 514).
    public static let ghostDashes: Int = 3
    /// The share of each dash's slot a ghost dash fills (feature 514).
    public static let ghostDuty: Double = 0.55
    /// The half size of the inspection ring around the inspected cell as a share of s (feature 514).
    public static let inspectRing: Double = 0.56
    /// The aspects whose orbit cameras the orbit backdrop is sized for (feature 514; spans ``backdropAspects``).
    static let orbitBackdropAspects: [Double] = [0.25, 0.4, 0.6, 0.8, 1, 1.25, 1.6, 2, 2.5, 3.2, 4]
    /// The safety factor on the orbit backdrop's size (feature 514).
    static let orbitBackdropSlack: Double = 1.1

    // MARK: Places (the CPU reference)

    /// The fit scale s = 1.9 / max(W, H) (W and H at least 1).
    public static func fitScale(width: Int, height: Int) -> Double {
        MyceliumArchitectSceneSnapshot.fitScale(width: width, height: height)
    }

    /// Cell `cell`'s centre on a W × H board at fit scale `scale`: ((c + 0.5 − W/2)·s, 0.05 + (H/2 − r − 0.5)·s, 0).
    public static func centre(_ cell: MyceliumArchitectCell, width: Int, height: Int,
                              scale: Double) -> SIMD3<Double> {
        let x: Double = (Double(cell.column) + 0.5 - Double(width) / 2) * scale
        let y: Double = boardCentreY + (Double(height) / 2 - Double(cell.row) - 0.5) * scale
        return SIMD3(x, y, 0)
    }

    /// Cell `cell`'s centre in `snapshot`'s level.
    static func centre(_ cell: MyceliumArchitectCell, _ snapshot: MyceliumArchitectSceneSnapshot) -> SIMD3<Double> {
        centre(cell, width: snapshot.level.width, height: snapshot.level.height, scale: snapshot.fitScale)
    }

    /// The board centre, (0, 0.05, 0).
    public static var boardCentre: SIMD3<Double> { SIMD3(0, boardCentreY, 0) }

    /// The reference point on the weight plate's left margin, (−0.925, −1.12, 0).
    public static var gaugeMargin: SIMD3<Double> { SIMD3(marginX, gaugeY, 0) }

    /// The width of one actions slot, 1.9 / budget.
    static func actionsSlot(_ snapshot: MyceliumArchitectSceneSnapshot) -> Double {
        actionsWidth / Double(max(snapshot.budget, 1))
    }

    /// The centre of actions bar `index`: (−0.95 + (index + 0.5) · slot, −1.34, 0).
    public static func actionsBar(_ index: Int, _ snapshot: MyceliumArchitectSceneSnapshot) -> SIMD3<Double> {
        SIMD3(actionsStart + (Double(index) + 0.5) * actionsSlot(snapshot), actionsY, 0)
    }

    /// The actions bars drawn lit: the actions left, clamped to 0 … budget.
    static func litActions(_ snapshot: MyceliumArchitectSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The centre of terminal `terminal`'s pip on the gauge row: x 0.06 apart around 0, y −1.24.
    static func rowPip(_ terminal: Int, count: Int) -> SIMD3<Double> {
        SIMD3((Double(terminal) - Double(count - 1) / 2) * pipStep, pipRowY, 0)
    }

    /// The x of `value` on the weight bar: −0.9 + 1.8 · min(max(value, 0), budget) / budget (budget at least 1).
    static func weightX(_ value: Int, budget: Int) -> Double {
        let top: Double = Double(max(budget, 1))
        return fillStart + (fillEnd - fillStart) * min(max(Double(value), 0), top) / top
    }

    /// The CPU reference points (clarification Q3): the board centre, the root's centre, every terminal's centre, the
    /// weight plate's left margin and the first actions bar (when the level has a budget).
    public static func referencePoints(_ snapshot: MyceliumArchitectSceneSnapshot) -> [MyceliumArchitectReferencePoint] {
        typealias R = MyceliumArchitectReferencePoint
        var points: [R] = [R(kind: .boardCentre, index: 0, centre: boardCentre),
                           R(kind: .root, index: 0, centre: centre(snapshot.level.root, snapshot))]
        for (index, terminal) in snapshot.level.terminals.enumerated() {
            points.append(R(kind: .terminal, index: index, centre: centre(terminal, snapshot)))
        }
        points.append(R(kind: .gaugeMargin, index: 0, centre: gaugeMargin))
        if snapshot.budget > 0 { points.append(R(kind: .actionsBar, index: 0, centre: actionsBar(0, snapshot))) }
        return points
    }

    // MARK: Failures

    /// Whether the snapshot shows a failed play (stage `failed`, or `result` after a failed run): only then is a
    /// failure marked.
    static func marksFailure(_ snapshot: MyceliumArchitectSceneSnapshot) -> Bool {
        snapshot.failure != nil && (snapshot.stage == .failed || snapshot.stage == .result)
    }

    /// The cell a toxic failure entered, on a failed play.
    static func toxicCell(_ snapshot: MyceliumArchitectSceneSnapshot) -> MyceliumArchitectCell? {
        guard marksFailure(snapshot), case .toxic(_, _, let cell) = snapshot.failure else { return nil }
        return cell
    }

    /// The cell a starved step could not grow into, on a failed play.
    static func starvedCell(_ snapshot: MyceliumArchitectSceneSnapshot) -> MyceliumArchitectCell? {
        guard marksFailure(snapshot), case .starved(_, _, let cell, _, _) = snapshot.failure else { return nil }
        return cell
    }

    /// The terminal an unreached failure names, on a failed play.
    static func unreachedTerminal(_ snapshot: MyceliumArchitectSceneSnapshot) -> Int? {
        guard marksFailure(snapshot), case .unreached(let terminal) = snapshot.failure else { return nil }
        return terminal
    }

    /// Whether an overweight failure is marked.
    static func isOverweight(_ snapshot: MyceliumArchitectSceneSnapshot) -> Bool {
        guard marksFailure(snapshot), case .overweight = snapshot.failure else { return false }
        return true
    }

    // MARK: Network

    /// A vein's radius at path weight `weight` of a network whose largest path weight is `largest`:
    /// s · (0.16 − 0.10 · w / w_max) (0.16·s when w_max is 0).
    static func veinRadius(weight: Int, largest: Int, scale: Double) -> Double {
        scale * (veinRootRadius - (veinRootRadius - veinTipRadius) * weightShare(weight, largest: largest))
    }

    /// The path-weight fraction w / w_max, clamped to 0 … 1 (0 when w_max is 0).
    static func weightShare(_ weight: Int, largest: Int) -> Double {
        guard largest > 0 else { return 0 }
        return min(max(Double(weight) / Double(largest), 0), 1)
    }

    /// The grown indices drawn as veins: every shown grown cell but the root with a parent the snapshot has, in growth
    /// order.
    static func shownVeins(_ snapshot: MyceliumArchitectSceneSnapshot) -> [Int] {
        var veins: [Int] = []
        for index in snapshot.grown.indices where index > 0 && snapshot.isShown(index) {
            guard index < snapshot.parents.count, let parent = snapshot.parents[index],
                  snapshot.grown.indices.contains(parent) else { continue }
            veins.append(index)
        }
        return veins
    }

    /// The consumed nutrients whose step is shown, as (index in step order, cell).
    static func shownBlooms(_ snapshot: MyceliumArchitectSceneSnapshot) -> [(index: Int, cell: MyceliumArchitectCell)] {
        var blooms: [(index: Int, cell: MyceliumArchitectCell)] = []
        for (index, cell) in snapshot.consumed.enumerated() {
            guard let grown = snapshot.grown.firstIndex(of: cell), snapshot.isShown(grown) else { continue }
            blooms.append((index, cell))
        }
        return blooms
    }

    /// The branch points: the shown grown cells with two or more shown children, in growth order.
    static func branchPoints(_ snapshot: MyceliumArchitectSceneSnapshot) -> [Int] {
        var children: [Int] = Array(repeating: 0, count: snapshot.grown.count)
        for index in shownVeins(snapshot) {
            if let parent = snapshot.parents[index] { children[parent] += 1 }
        }
        var points: [Int] = []
        for index in children.indices where children[index] >= 2 && snapshot.isShown(index) { points.append(index) }
        return points
    }

    /// The fixed integer hash of (`a`, `b`) as a value in 0 ..< 1 (never a random source).
    static func hash(_ a: Int, _ b: Int) -> Double {
        var x: UInt64 = (UInt64(bitPattern: Int64(a)) &* 0x9E37_79B9_7F4A_7C15)
            ^ (UInt64(bitPattern: Int64(b)) &* 0xC2B2_AE3D_27D4_EB4F)
        x ^= x >> 33
        x = x &* 0xFF51_AFD7_ED55_8CCD
        x ^= x >> 33
        x = x &* 0xC4CE_B9FE_1A85_EC53
        x ^= x >> 33
        return Double(x >> 11) / 9_007_199_254_740_992
    }

    /// The fuzz strands of `snapshot` at `tier`, each as (from, to, phase k / n): per branch point n strands from its
    /// centre out to 0.4·s · (0.7 + 0.3 · hash), per open terminal cap n strands from 0.3·s to 0.5·s; strand k at angle
    /// 2π (k + 0.5 · hash) / n. Empty at a tier without fuzz.
    static func fuzzStrands(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier)
        -> [(from: SIMD3<Double>, to: SIMD3<Double>, phase: Double)] {
        let n: Int = max(tier.fuzzStrands, 0)
        guard n > 0 else { return [] }
        let s: Double = snapshot.fitScale
        var strands: [(from: SIMD3<Double>, to: SIMD3<Double>, phase: Double)] = []
        for point in branchPoints(snapshot) {
            let c: SIMD3<Double> = centre(snapshot.grown[point], snapshot)
            for k in 0..<n {
                let angle: Double = 2 * Double.pi * (Double(k) + 0.5 * hash(point, k)) / Double(n)
                let length: Double = fuzzLength * s * (0.7 + 0.3 * hash(k, point + 7_919))
                let d: SIMD3<Double> = SIMD3(cos(angle), sin(angle), 0)
                strands.append((c, c + d * length, Double(k) / Double(n)))
            }
        }
        for (terminal, cell) in snapshot.level.terminals.enumerated() where snapshot.isReached(terminal) {
            let c: SIMD3<Double> = centre(cell, snapshot)
            for k in 0..<n {
                let angle: Double = 2 * Double.pi * (Double(k) + 0.5 * hash(1_000 + terminal, k)) / Double(n)
                let d: SIMD3<Double> = SIMD3(cos(angle), sin(angle), 0)
                strands.append((c + d * (capFuzzStart * s), c + d * (capFuzzEnd * s), Double(k) / Double(n)))
            }
        }
        return strands
    }

    /// The spores at `tier`, each as (centre, phase k / n): `tier.spores` hashed points with x in ±0.85, y in
    /// −0.8 … 0.9 and z in 0.06 … 0.2 (the shader drifts each by at most 0.04 in x and y). Empty at a tier without spores.
    static func spores(_ tier: MyceliumArchitectTier) -> [(centre: SIMD3<Double>, phase: Double)] {
        let n: Int = max(tier.spores, 0)
        var points: [(centre: SIMD3<Double>, phase: Double)] = []
        for k in 0..<n {
            let x: Double = -0.85 + 1.7 * hash(k, 1)
            let y: Double = -0.8 + 1.7 * hash(k, 2)
            let z: Double = sporeLow + (sporeHigh - sporeLow) * hash(k, 3)
            points.append((SIMD3(x, y, z), Double(k) / Double(n)))
        }
        return points
    }

    /// The unit direction of `direction` on the board plane: (dc, −dr) normalised (rows grow downwards).
    static func planeDirection(_ direction: MyceliumArchitectDirection) -> SIMD3<Double> {
        let offset: (column: Int, row: Int) = direction.offset
        return unit(SIMD3(Double(offset.column), -Double(offset.row), 0))
    }

    // MARK: Elements

    /// Every element with its centre, in drawing order (research R4). The same for every tier; the shown pulse changes
    /// only the veins, blooms and glow groups listed.
    public static func paintOrder(_ snapshot: MyceliumArchitectSceneSnapshot) -> [MyceliumArchitectElement] {
        typealias E = MyceliumArchitectElement
        let level: MyceliumArchitectLevel = snapshot.level
        var list: [E] = [E(kind: .backdrop, index: 0, item: 0, centre: backdropFrame(snapshot.orbit).centre),
                         E(kind: .floor, index: 0, item: 0, centre: boardCentre)]
        let sites: [MyceliumArchitectCell] = level.sites ?? []
        for (index, cell) in sites.enumerated() {
            list.append(E(kind: .site, index: index, item: index, centre: centre(cell, snapshot)))
        }
        if let cell = starvedCell(snapshot) {
            list.append(E(kind: .site, index: sites.count, item: sites.count, centre: centre(cell, snapshot)))
        }
        for (index, cell) in level.toxins.enumerated() {
            list.append(E(kind: .toxin, index: index, item: index, centre: centre(cell, snapshot)))
        }
        for (index, cell) in level.rocks.enumerated() {
            list.append(E(kind: .rock, index: index, item: index, centre: centre(cell, snapshot)))
        }
        for (index, cell) in snapshot.arrangement.blockers.enumerated() {
            list.append(E(kind: .blocker, index: index, item: index, centre: centre(cell, snapshot)))
        }
        let nutrients: [MyceliumArchitectCell] = level.fixedNutrients + snapshot.arrangement.nutrients
        for (index, cell) in nutrients.enumerated() {
            list.append(E(kind: .nutrient, index: index, item: index, centre: centre(cell, snapshot)))
        }
        for (index, vein) in shownVeins(snapshot).enumerated() {
            guard let parent = snapshot.parents[vein] else { continue }
            let mid: SIMD3<Double> = (centre(snapshot.grown[parent], snapshot) + centre(snapshot.grown[vein], snapshot)) / 2
            list.append(E(kind: .vein, index: index, item: vein, centre: mid))
        }
        let blooms: [(index: Int, cell: MyceliumArchitectCell)] = shownBlooms(snapshot)
        for (index, bloom) in blooms.enumerated() {
            list.append(E(kind: .bloom, index: index, item: bloom.index, centre: centre(bloom.cell, snapshot)))
        }
        list.append(E(kind: .fuzz, index: 0, item: 0, centre: boardCentre))
        list.append(E(kind: .spore, index: 0, item: 0, centre: boardCentre))
        let rootCentre: SIMD3<Double> = centre(level.root, snapshot)
        for (index, direction) in snapshot.arrangement.seeds.enumerated() {
            let tip: SIMD3<Double> = rootCentre + planeDirection(direction) * (sproutLength * snapshot.fitScale)
            list.append(E(kind: .sprout, index: index, item: index, centre: (rootCentre + tip) / 2))
        }
        list.append(E(kind: .root, index: 0, item: 0, centre: rootCentre))
        for (index, cell) in level.terminals.enumerated() {
            list.append(E(kind: .terminal, index: index, item: index, centre: centre(cell, snapshot)))
        }
        list.append(E(kind: .gauge, index: 0, item: 0, centre: SIMD3((plateLeft + plateRight) / 2, gaugeY, 0)))
        for index in level.terminals.indices {
            list.append(E(kind: .pip, index: index, item: index, centre: rowPip(index, count: level.terminals.count)))
        }
        for bar in 0..<max(snapshot.budget, 0) {
            list.append(E(kind: .actions, index: bar, item: bar, centre: actionsBar(bar, snapshot)))
        }
        var glow: Int = 0
        list.append(E(kind: .glow, index: glow, item: 0, centre: rootCentre))
        glow += 1
        for (index, cell) in level.terminals.enumerated() where snapshot.isReached(index) {
            list.append(E(kind: .glow, index: glow, item: 1 + index, centre: centre(cell, snapshot)))
            glow += 1
        }
        for (index, bloom) in blooms.enumerated() {
            list.append(E(kind: .glow, index: glow, item: 1 + level.terminals.count + index,
                          centre: centre(bloom.cell, snapshot)))
            glow += 1
        }
        return list
    }

    // MARK: Meshes

    /// The board mesh for the board program at `tier`, in drawing order (see the header): every element but the glow.
    /// Never fails: the mesh stays far inside the default budget (a 32 × 32 board with a full network is under 60 000
    /// vertices); should a budget ever be exceeded, the elements built so far are returned.
    public static func board(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier) -> Mesh {
        boardPart(snapshot, tier: tier).mesh
    }

    /// The glow mesh for the glow program at `tier` (see the header's streams): `tier.glowShells` shells k (outermost
    /// first, factor 1 − (k − 1) / shells),
    /// each a flat annulus around the root (0.9 · 0.36·s … 0.36·s + 0.08·s · k), every open terminal cap (from 0.42·s)
    /// and every shown bloom (from 0.22·s). Empty at level-2.
    public static func glow(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier) -> Mesh {
        glowPart(snapshot, tier: tier).mesh
    }

    /// The board mesh with fallback colours for the shared unlit renderer: each vertex in its material's palette
    /// colour (``MyceliumArchitectMaterial/colour``; broken parts in the broken colour), the backdrop from cave at its
    /// bottom to cave top at its top. The mesh is ``board(_:tier:)``.
    public static func boardPart(_ snapshot: MyceliumArchitectSceneSnapshot,
                                 tier: MyceliumArchitectTier) -> MyceliumArchitectColouredMesh {
        var parts: Parts = Parts()
        parts.eye = drawnEye(snapshot.orbit)
        do {
            for element in paintOrder(snapshot) where element.kind != .glow {
                // Feature 514: the ghost veins right before the fuzz, the inspection ring right before the gauge.
                if element.kind == .fuzz { try ghosts(&parts, snapshot) }
                if element.kind == .gauge { try inspection(&parts, snapshot) }
                try draw(element, into: &parts, snapshot, tier: tier)
            }
        } catch {
            return parts.built()
        }
        return parts.built()
    }

    /// The unlit fallback (clarification Q4): the level-2 board with palette colours (``boardPart(_:tier:)`` at
    /// level-2), drawn by the shared unlit mesh renderer when a program fails to compile or link.
    public static func fallback(_ snapshot: MyceliumArchitectSceneSnapshot) -> MyceliumArchitectColouredMesh {
        boardPart(snapshot, tier: MyceliumArchitectTier.of(2))
    }

    /// The glow mesh with fallback colours (each shell in its kind's colour); see ``glow(_:tier:)``.
    public static func glowPart(_ snapshot: MyceliumArchitectSceneSnapshot,
                                tier: MyceliumArchitectTier) -> MyceliumArchitectColouredMesh {
        var parts: Parts = Parts()
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let s: Double = snapshot.fitScale
        let level: MyceliumArchitectLevel = snapshot.level
        let blooms: [(index: Int, cell: MyceliumArchitectCell)] = shownBlooms(snapshot)
        do {
            for k in stride(from: shells, through: 1, by: -1) {
                let grow: Double = glowGrowth * s * Double(k)
                let factor: Double = 1 - Double(k - 1) / Double(shells)
                try parts.glowBand(centre: centre(level.root, snapshot), inner: glowInner * rootCapRadius * s,
                                   outer: rootCapRadius * s + grow, factor: factor, kind: .root)
                for (index, cell) in level.terminals.enumerated() where snapshot.isReached(index) {
                    try parts.glowBand(centre: centre(cell, snapshot), inner: glowInner * terminalCapRadius * s,
                                       outer: terminalCapRadius * s + grow, factor: factor,
                                       kind: .terminal)
                }
                for bloom in blooms {
                    try parts.glowBand(centre: centre(bloom.cell, snapshot), inner: glowInner * bloomRadius * s,
                                       outer: bloomRadius * s + grow, factor: factor, kind: .bloom)
                }
            }
        } catch {
            return parts.built()
        }
        return parts.built()
    }

    /// The a_uv.x of `material` with `value` and the broken mark.
    static func code(_ material: MyceliumArchitectMaterial, value: Double = 0, broken: Bool = false) -> Double {
        MyceliumArchitectMaterial.encode(material, value: value, broken: broken)
    }

    /// Draws one element into `parts` (see the header).
    static func draw(_ element: MyceliumArchitectElement, into parts: inout Parts,
                     _ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier) throws(MeshError) {
        let s: Double = snapshot.fitScale
        let level: MyceliumArchitectLevel = snapshot.level
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        switch element.kind {
        case .backdrop:
            try backdrop(&parts, orbit: snapshot.orbit)
        case .floor:
            try floor(&parts, snapshot)
        case .site:
            let broken: Bool = i >= (level.sites ?? []).count
            try parts.flatQuad(centre: c, half: SIMD2(siteHalf * s, siteHalf * s), code: code(.site, broken: broken))
        case .toxin:
            try parts.flatQuad(centre: c, half: SIMD2(toxinRadius * s, toxinRadius * s),
                               code: code(.toxin, value: hash(i, 4_099)))
            if toxicCell(snapshot) == level.toxins[i] {
                try parts.flatQuad(centre: c, half: SIMD2(markRing * s, markRing * s),
                                   code: code(.pipHollow, broken: true))
            }
        case .rock:
            try rock(&parts, centre: c, scale: s)
        case .blocker:
            try parts.flatQuad(centre: c, half: SIMD2(blockerRadius * s, blockerRadius * s), code: code(.blocker))
        case .nutrient:
            let cell: MyceliumArchitectCell = (level.fixedNutrients + snapshot.arrangement.nutrients)[i]
            let placed: Bool = i >= level.fixedNutrients.count
            var eaten: Bool = false
            for bloom in shownBlooms(snapshot) where bloom.cell == cell { eaten = true }
            try parts.flatQuad(centre: c, half: SIMD2(nutrientRadius * s, nutrientRadius * s),
                               code: eaten ? code(.nutrientConsumed) : code(.nutrient, value: placed ? 1 : 0))
        case .vein:
            guard let parent = snapshot.parents[i] else { return }
            let largest: Int = snapshot.largestPathWeight
            let wa: Int = snapshot.pathWeights.indices.contains(parent) ? snapshot.pathWeights[parent] : 0
            let wb: Int = snapshot.pathWeights.indices.contains(i) ? snapshot.pathWeights[i] : 0
            try tube(&parts, from: centre(snapshot.grown[parent], snapshot), to: centre(snapshot.grown[i], snapshot),
                     radii: SIMD2(veinRadius(weight: wa, largest: largest, scale: s),
                                  veinRadius(weight: wb, largest: largest, scale: s)),
                     codes: SIMD2(code(.vein, value: weightShare(wa, largest: largest)),
                                  code(.vein, value: weightShare(wb, largest: largest))),
                     sides: tier.tubeSides)
        case .bloom:
            try parts.flatQuad(centre: c, half: SIMD2(bloomRadius * s, bloomRadius * s), code: code(.bloom))
        case .fuzz:
            for strand in fuzzStrands(snapshot, tier: tier) {
                try parts.segment(strand.from, strand.to, width: max(fuzzWidth * s, 0.003), code: code(.fuzz, value: strand.phase))
            }
        case .sprout:
            let root: SIMD3<Double> = centre(level.root, snapshot)
            let tip: SIMD3<Double> = root + planeDirection(snapshot.arrangement.seeds[i]) * (sproutLength * s)
            try tube(&parts, from: root, to: tip, radii: SIMD2(sproutRootRadius * s, sproutTipRadius * s),
                     codes: SIMD2(code(.sprout), code(.sprout)), sides: tier.tubeSides)
        case .root:
            try dome(&parts, centre: c, radius: rootCapRadius * s, code: code(.root), segments: tier.capSegments)
        case .terminal:
            let reached: Bool = snapshot.isReached(i)
            let material: MyceliumArchitectMaterial = reached ? .terminalOpen : .terminalClosed
            try dome(&parts, centre: c, radius: terminalCapRadius * s,
                     code: code(material), segments: tier.capSegments)
            for pip in capPips(i, centre: c, scale: s) {
                try parts.flatQuad(centre: pip, half: SIMD2(capPipHalf * s, capPipHalf * s),
                                   code: code(reached ? .pipFilled : .pipHollow))
            }
            if unreachedTerminal(snapshot) == i {
                try parts.flatQuad(centre: c, half: SIMD2(markRing * s, markRing * s),
                                   code: code(.pipHollow, broken: true))
            }
        case .spore:
            for spore in spores(tier) {
                try parts.flatQuad(centre: spore.centre, half: SIMD2(sporeHalf, sporeHalf), code: code(.spore, value: spore.phase))
            }
        case .gauge:
            try gauge(&parts, snapshot)
        case .pip:
            try parts.flatQuad(centre: c, half: SIMD2(pipHalf, pipHalf),
                               code: code(snapshot.isReached(i) ? .pipFilled : .pipHollow))
        case .actions:
            let half: SIMD2<Double> = SIMD2(barFill * actionsSlot(snapshot) / 2, actionsHeight / 2)
            let material: MyceliumArchitectMaterial = i < litActions(snapshot) ? .actionsLit : .actionsUnlit
            try parts.flatQuad(centre: c, half: half, code: code(material))
        case .glow:
            return
        }
    }

    /// The centres of terminal `terminal`'s ring of terminal + 1 pips: on a circle of 0.5·s around `centre`, starting
    /// straight up the board and going clockwise, 2π / (terminal + 1) … apart, at most 2π / 7 apart.
    static func capPips(_ terminal: Int, centre c: SIMD3<Double>, scale: Double) -> [SIMD3<Double>] {
        let count: Int = max(terminal, 0) + 1
        let step: Double = 2 * Double.pi / Double(max(count, 7))
        var pips: [SIMD3<Double>] = []
        for k in 0..<count {
            let angle: Double = Double.pi / 2 - step * (Double(k) - Double(count - 1) / 2)
            pips.append(c + SIMD3(cos(angle), sin(angle), 0) * (capPipRing * scale))
        }
        return pips
    }

    /// Draws the backdrop: a quad on the view axis at ``backdropDistance``, perpendicular to it (a_normal its plane
    /// offsets, a_uv.y the height; colours cave at the bottom, cave top at the top); for a non-authored `orbit` the
    /// quad of ``backdropFrame(_:)`` (feature 514).
    static func backdrop(_ parts: inout Parts, orbit: MyceliumArchitectViewOrbit = .authored) throws(MeshError) {
        let frame: (centre: SIMD3<Double>, forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>,
                    half: SIMD2<Double>) = backdropFrame(orbit)
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) =
            (forward: frame.forward, right: frame.right, up: frame.up)
        let half: SIMD2<Double> = frame.half
        let c: SIMD3<Double> = frame.centre
        let w: SIMD3<Double> = basis.right * half.x
        let h: SIMD3<Double> = basis.up * half.y
        let low: Vec4 = MyceliumArchitectPalette.cave
        let high: Vec4 = MyceliumArchitectPalette.caveTop
        let offsets: [SIMD3<Double>] = [SIMD3(-half.x, -half.y, 0), SIMD3(half.x, -half.y, 0),
                                        SIMD3(half.x, half.y, 0), SIMD3(-half.x, half.y, 0)]
        try parts.quad([c - w - h, c + w - h, c + w + h, c - w + h], code: code(.backdrop), local: [0, 0, 1, 1],
                       colours: [low, low, high, high], normals: offsets, facing: -basis.forward)
    }

    /// Draws the floor plate and its grid lines on the cell boundaries.
    static func floor(_ parts: inout Parts, _ snapshot: MyceliumArchitectSceneSnapshot) throws(MeshError) {
        try parts.plate(left: floorLow.x, right: floorHigh.x, low: floorLow.y, high: floorHigh.y, code: code(.floor))
        let s: Double = snapshot.fitScale
        let w: Int = snapshot.level.width
        let h: Int = snapshot.level.height
        let left: Double = -Double(w) / 2 * s
        let top: Double = boardCentreY + Double(h) / 2 * s
        let half: Double = gridWidth * s / 2
        for column in 0...w {
            let x: Double = left + Double(column) * s
            try parts.span(left: x - half, right: x + half, low: top - Double(h) * s, high: top, code: code(.grid))
        }
        for row in 0...h {
            let y: Double = top - Double(row) * s
            try parts.span(left: left, right: left + Double(w) * s, low: y - half, high: y + half, code: code(.grid))
        }
    }

    /// Draws the weight gauge: plate, fill (the part past the limit broken on an overweight failure), limit tick and
    /// budget end tick (broken on a starved failure).
    static func gauge(_ parts: inout Parts, _ snapshot: MyceliumArchitectSceneSnapshot) throws(MeshError) {
        try parts.plate(left: plateLeft, right: plateRight, low: gaugeY - plateHalf, high: gaugeY + plateHalf,
                        code: code(.gaugePlate))
        let budget: Int = max(snapshot.nutrientBudget, 1)
        let weight: Int = snapshot.totalWeight
        let share: Double = min(max(Double(weight), 0), Double(budget)) / Double(budget)
        let end: Double = weightX(weight, budget: budget)
        let limitX: Double = weightX(snapshot.weightLimit, budget: budget)
        if isOverweight(snapshot) && end > limitX {
            try parts.span(left: fillStart, right: limitX, low: gaugeY - fillHalf, high: gaugeY + fillHalf,
                           code: code(.weightFill, value: share))
            try parts.span(left: limitX, right: end, low: gaugeY - fillHalf, high: gaugeY + fillHalf,
                           code: code(.weightFill, value: share, broken: true))
        } else {
            try parts.span(left: fillStart, right: end, low: gaugeY - fillHalf, high: gaugeY + fillHalf,
                           code: code(.weightFill, value: share))
        }
        try parts.flatQuad(centre: SIMD3(limitX, gaugeY, 0), half: SIMD2(tickHalfWidth, tickHalfHeight),
                           code: code(.limitTick))
        try parts.flatQuad(centre: SIMD3(fillEnd, gaugeY, 0), half: SIMD2(tickHalfWidth, tickHalfHeight),
                           code: code(.limitTick, broken: starvedCell(snapshot) != nil))
    }

    /// Draws a rock block of side 0.9·s and height 0.3·s at `centre` (top a_uv.y 1, sides 0).
    static func rock(_ parts: inout Parts, centre c: SIMD3<Double>, scale: Double) throws(MeshError) {
        let a: Double = rockSide * scale / 2
        let h: Double = rockHeight * scale
        var solid: Solid = Solid()
        let x: SIMD3<Double> = SIMD3(1, 0, 0)
        let y: SIMD3<Double> = SIMD3(0, 1, 0)
        let z: SIMD3<Double> = SIMD3(0, 0, 1)
        let rc: Double = code(.rock)
        let top: [SIMD3<Double>] = [c + SIMD3(-a, -a, h), c + SIMD3(a, -a, h), c + SIMD3(a, a, h), c + SIMD3(-a, a, h)]
        solid.face(top, normal: z, code: rc, local: 1)
        let sides: [(normal: SIMD3<Double>, along: SIMD3<Double>)] = [(x, y), (-x, -y), (y, -x), (-y, x)]
        for side in sides {
            let base: SIMD3<Double> = c + side.normal * a
            solid.face([base - side.along * a, base + side.along * a,
                        base + side.along * a + z * h, base - side.along * a + z * h],
                       normal: side.normal, code: rc, local: 0)
        }
        try solid.emit(into: &parts)
    }

    /// Draws a tapered tube of `sides` sides (at least 3) from `a` to `b` resting on the floor: ring k at each end is
    /// the end's point lifted by its radius r plus r · (cos θ · side + sin θ · up), θ = 2π k / n, side the horizontal
    /// normal of the axis and up +z (so z spans 0 … 2r); a_normal the ring normal, a_uv.y 0 at `a` and 1 at `b`, a_uv.x
    /// the end's code. Nothing for ends at the same place.
    static func tube(_ parts: inout Parts, from a: SIMD3<Double>, to b: SIMD3<Double>, radii: SIMD2<Double>,
                     codes: SIMD2<Double>, sides: Int) throws(MeshError) {
        let flat: SIMD3<Double> = SIMD3(b.x - a.x, b.y - a.y, 0)
        guard length(flat) > 1e-12 else { return }
        let along: SIMD3<Double> = unit(flat)
        let side: SIMD3<Double> = unit(cross(along, SIMD3(0, 0, 1)))
        let up: SIMD3<Double> = SIMD3(0, 0, 1)
        let n: Int = max(sides, 3)
        var solid: Solid = Solid()
        var ring: [[Int]] = [[], []]
        let ends: [SIMD3<Double>] = [a, b]
        for e in 0..<2 {
            let r: Double = e == 0 ? radii.x : radii.y
            let axis: SIMD3<Double> = SIMD3(ends[e].x, ends[e].y, r)
            for k in 0..<n {
                let theta: Double = 2 * Double.pi * Double(k) / Double(n)
                let normal: SIMD3<Double> = side * cos(theta) + up * sin(theta)
                ring[e].append(solid.vertex(axis + normal * r, normal: normal, code: e == 0 ? codes.x : codes.y,
                                            local: Double(e)))
            }
        }
        for k in 0..<n {
            let k1: Int = (k + 1) % n
            solid.quad(ring[0][k], ring[0][k1], ring[1][k1], ring[1][k])
        }
        try solid.emit(into: &parts)
    }

    /// Draws a flattened dome (a cap) of `radius` and height 0.55 · radius at `centre` with `segments` segments (at
    /// least 3) and four latitude rings below the apex; a_normal the ellipsoid normal, a_uv.y the radial share cos φ.
    static func dome(_ parts: inout Parts, centre c: SIMD3<Double>, radius: Double, code value: Double,
                     segments: Int) throws(MeshError) {
        let n: Int = max(segments, 3)
        let h: Double = capHeight * radius
        var solid: Solid = Solid()
        var rings: [[Int]] = []
        for j in 0..<capRings {
            let phi: Double = Double(j) / Double(capRings) * Double.pi / 2
            var ring: [Int] = []
            for k in 0..<n {
                let theta: Double = 2 * Double.pi * Double(k) / Double(n)
                let p: SIMD3<Double> = c + SIMD3(radius * cos(phi) * cos(theta), radius * cos(phi) * sin(theta),
                                                 h * sin(phi))
                let normal: SIMD3<Double> = unit(SIMD3(h * cos(phi) * cos(theta), h * cos(phi) * sin(theta),
                                                       radius * sin(phi)))
                ring.append(solid.vertex(p, normal: normal, code: value, local: cos(phi)))
            }
            rings.append(ring)
        }
        let apex: Int = solid.vertex(c + SIMD3(0, 0, h), normal: SIMD3(0, 0, 1), code: value, local: 0)
        for j in 0..<(capRings - 1) {
            for k in 0..<n {
                let k1: Int = (k + 1) % n
                solid.quad(rings[j][k], rings[j][k1], rings[j + 1][k1], rings[j + 1][k])
            }
        }
        for k in 0..<n { solid.triangle(rings[capRings - 1][k], rings[capRings - 1][(k + 1) % n], apex) }
        try solid.emit(into: &parts)
    }

    // MARK: Camera

    /// The view basis of the fixed camera: forward (unit, eye → target), right (forward × +y) and up (right × forward).
    static func viewBasis() -> (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) {
        let f: SIMD3<Double> = unit(lookAt - eye)
        let r: SIMD3<Double> = unit(cross(f, SIMD3(0, 1, 0)))
        return (forward: f, right: r, up: cross(r, f))
    }

    /// `aspect` made usable: 1 when not finite and positive (a zero-size view), else clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// Corner `index` (0 … 7; bit 0 x, bit 1 y, bit 2 z, clear: low) of the authored box.
    static func corner(_ index: Int) -> SIMD3<Double> {
        SIMD3(index & 1 == 0 ? boxLow.x : boxHigh.x, index & 2 == 0 ? boxLow.y : boxHigh.y,
              index & 4 == 0 ? boxLow.z : boxHigh.z)
    }

    /// The fixed camera for `aspect` (research R9): from (0, −1.9, 2.8) looking at (0, −0.3, 0) with +y up; the vertical
    /// field of view is the smallest that holds every corner of the box x −1.05 … 1.05, y −1.45 … 1.05, z 0 … 0.25
    /// inside the view with ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside
    /// it keeps a margin of at least 5 % for aspect 0.4 … 2.5). A non-finite or non-positive aspect (a zero-size view)
    /// uses 1. Independent of the snapshot, the tier and the time.
    public static func camera(aspect: Double) -> MyceliumArchitectCamera {
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
        return MyceliumArchitectCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far,
                                       view: view, projection: projection, viewProjection: projection * view)
    }

    /// The backdrop's centre: on the view axis at ``backdropDistance`` from the eye.
    public static func backdropCentre() -> SIMD3<Double> { eye + viewBasis().forward * backdropDistance }

    /// The backdrop's half width and half height: large enough to fill the view at its plane for every aspect in
    /// ``backdropAspects`` (5 % over).
    public static func backdropHalf() -> SIMD2<Double> {
        let tall: MyceliumArchitectCamera = camera(aspect: backdropAspects.lowerBound)
        let wide: MyceliumArchitectCamera = camera(aspect: backdropAspects.upperBound)
        let tanTall: Double = tan(tall.fovY / 2)
        let tanWide: Double = tan(wide.fovY / 2)
        let halfHeight: Double = backdropDistance * max(tanTall, tanWide) * 1.05
        let halfWidth: Double = backdropDistance * max(tanTall * tall.aspect, tanWide * wide.aspect) * 1.05
        return SIMD2(halfWidth, halfHeight)
    }

    /// The backdrop height h (0 at its bottom, 1 at its top; a_uv.y) seen at view point `view` (0 … 1, y down) through
    /// `camera`: the gradient's coordinate at that pixel (the backdrop is perpendicular to the view axis).
    public static func backdropHeight(view: SIMD2<Double>, camera: MyceliumArchitectCamera) -> Double {
        let y: Double = (1 - 2 * view.y) * backdropDistance * tan(camera.fovY / 2)
        let half: Double = backdropHalf().y
        return min(max((y + half) / (2 * half), 0), 1)
    }

    /// The backdrop colour at height `height` (0 … 1, clamped): cave mixed towards cave top.
    public static func backdropColour(height: Double) -> Vec4 {
        let t: Double = height.isFinite ? min(max(height, 0), 1) : 0
        let a: Vec4 = MyceliumArchitectPalette.cave
        let b: Vec4 = MyceliumArchitectPalette.caveTop
        return Vec4(a.x * (1 - t) + b.x * t, a.y * (1 - t) + b.y * t, a.z * (1 - t) + b.z * t, 1)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: MyceliumArchitectCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Orbit, ghosts and inspection (feature 514)

    /// The camera for `orbit` (clamped, see ``MyceliumArchitectViewOrbit/clamped()``) and `aspect` (feature 514,
    /// T-R02G2204-002; FR-R02G2204-008): the authored frame turned by the orbit (``orbitFrame(_:)``), the authored field
    /// of view for the aspect, and the eye on the turned view axis at the larger of the authored distance (≈ 3.22) and
    /// the distance at which every corner of the authored box lies inside the view with ``refitMargin`` per side, so
    /// everything inside the box keeps a margin of at least 5 % at every orbit and aspect 0.4 … 2.5; every corner stays
    /// in front of the eye. The target is always the look-at point (the yaw pivot). Near half the nearest corner's depth
    /// (at least 0.001), far 2 past the larger of the farthest corner's depth + 1 and the orbit backdrop. At the
    /// authored orbit it is ``camera(aspect:)``, bit for bit. Presentation only; independent of the snapshot, the tier
    /// and the time.
    public static func camera(aspect: Double, orbit: MyceliumArchitectViewOrbit) -> MyceliumArchitectCamera {
        let o: MyceliumArchitectViewOrbit = orbit.clamped()
        guard o.yaw != 0 || o.pitch != 0 else { return camera(aspect: aspect) }
        let a: Double = usableAspect(aspect)
        let fovY: Double = camera(aspect: a).fovY
        let frame: (target: SIMD3<Double>, back: SIMD3<Double>, up: SIMD3<Double>) = orbitFrame(o)
        let forward: SIMD3<Double> = -frame.back
        let right: SIMD3<Double> = unit(cross(forward, frame.up))
        let up: SIMD3<Double> = cross(right, forward)
        let tanHalf: Double = tan(fovY / 2)
        let limit: Double = 1 - 2 * refitMargin
        var distance: Double = authoredDistance
        for index in 0..<8 {
            let r: SIMD3<Double> = corner(index) - frame.target
            let along: Double = dot(r, forward)
            let vertical: Double = abs(dot(r, up)) / (limit * tanHalf) - along
            let horizontal: Double = abs(dot(r, right)) / (limit * tanHalf * a) - along
            distance = max(distance, vertical, horizontal)
        }
        let eyePoint: SIMD3<Double> = frame.target + frame.back * distance
        var nearest: Double = Double.infinity
        var farthest: Double = 0
        for index in 0..<8 {
            let depth: Double = dot(corner(index) - eyePoint, forward)
            nearest = min(nearest, depth)
            farthest = max(farthest, depth)
        }
        let near: Double = max(nearest * 0.5, 1e-3)
        let far: Double = max(farthest + 1, distance + orbitBackdropOffset) + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eyePoint), target: vec(frame.target), up: vec(up))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return MyceliumArchitectCamera(eye: eyePoint, target: frame.target, fovY: fovY, aspect: a, near: near,
                                       far: far, view: view, projection: projection,
                                       viewProjection: projection * view)
    }

    /// The authored distance from the eye to the look-at point, |(0, −1.6, 2.8)| ≈ 3.22 (feature 514).
    static var authoredDistance: Double {
        let d: SIMD3<Double> = eye - lookAt
        return dot(d, d).squareRoot()
    }

    /// How far beyond the look-at point an orbit's backdrop stands along the view axis: ``backdropDistance`` − the
    /// authored distance (≈ 3.78; the authored backdrop's offset) (feature 514).
    static var orbitBackdropOffset: Double { backdropDistance - authoredDistance }

    /// `v` turned by `angle` radians about +x (the authored right axis), counter-clockwise seen from +x.
    static func pitched(_ v: SIMD3<Double>, _ angle: Double) -> SIMD3<Double> {
        let c: Double = cos(angle)
        let s: Double = sin(angle)
        return SIMD3(v.x, v.y * c - v.z * s, v.y * s + v.z * c)
    }

    /// `v` turned by `angle` radians about +z, counter-clockwise seen from above.
    static func yawed(_ v: SIMD3<Double>, _ angle: Double) -> SIMD3<Double> {
        let c: Double = cos(angle)
        let s: Double = sin(angle)
        return SIMD3(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
    }

    /// The frame of `orbit` (clamped; feature 514): the look-at point, the unit direction from it back towards the eye
    /// and the unit up direction. The authored frame (back along (0, −1.6, 2.8), up ``viewBasis()``'s) is turned
    /// rigidly by −pitch about +x (so a positive pitch raises the eye; the frame never rolls, even with the eye just past
    /// the vertical at pitch +35°), then by the yaw about +z; the look-at point is the pivot and stays put.
    static func orbitFrame(_ orbit: MyceliumArchitectViewOrbit)
        -> (target: SIMD3<Double>, back: SIMD3<Double>, up: SIMD3<Double>) {
        let o: MyceliumArchitectViewOrbit = orbit.clamped()
        let back0: SIMD3<Double> = unit(eye - lookAt)
        let up0: SIMD3<Double> = viewBasis().up
        let back1: SIMD3<Double> = pitched(back0, -o.pitch)
        let up1: SIMD3<Double> = pitched(up0, -o.pitch)
        return (target: lookAt, back: unit(yawed(back1, o.yaw)), up: unit(yawed(up1, o.yaw)))
    }

    /// `camera`'s unit forward, right and up vectors, read from its view matrix (feature 514): for the authored camera
    /// those of ``viewBasis()`` within rounding.
    public static func viewBasis(_ camera: MyceliumArchitectCamera)
        -> (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) {
        let v: Mat4 = camera.view
        let right: SIMD3<Double> = SIMD3(v.c0.x, v.c1.x, v.c2.x)
        let up: SIMD3<Double> = SIMD3(v.c0.y, v.c1.y, v.c2.y)
        let forward: SIMD3<Double> = SIMD3(-v.c0.z, -v.c1.z, -v.c2.z)
        return (forward: forward, right: right, up: up)
    }

    /// The eye the board mesh is built for (feature 514): ``eye`` at the authored orbit, else the eye of the orbit's
    /// camera at aspect 1 (an orbit camera's eye moves only along its view axis with the aspect, so the far-first
    /// emission of the solids is the same for every aspect but in extreme cases).
    public static func drawnEye(_ orbit: MyceliumArchitectViewOrbit) -> SIMD3<Double> {
        guard !orbit.isAuthored else { return eye }
        return camera(aspect: 1, orbit: orbit).eye
    }

    /// The backdrop quad of `orbit` (feature 514): its centre, the view axis it is perpendicular to, its right and up
    /// directions and its half size. At the authored orbit R02-G22-03's (``backdropCentre()``, ``viewBasis()``,
    /// ``backdropHalf()``); otherwise centred ``orbitBackdropOffset`` beyond the look-at point on the orbit's view axis,
    /// with ``backdropHalf()`` scaled by the largest (eye distance + offset) / ``backdropDistance`` of the orbit's
    /// cameras at ``orbitBackdropAspects`` and by ``orbitBackdropSlack``, so it fills the view of every orbit camera.
    static func backdropFrame(_ orbit: MyceliumArchitectViewOrbit)
        -> (centre: SIMD3<Double>, forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>,
            half: SIMD2<Double>) {
        guard !orbit.isAuthored else {
            let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis()
            return (centre: backdropCentre(), forward: basis.forward, right: basis.right, up: basis.up,
                    half: backdropHalf())
        }
        let frame: (target: SIMD3<Double>, back: SIMD3<Double>, up: SIMD3<Double>) = orbitFrame(orbit)
        let forward: SIMD3<Double> = -frame.back
        let right: SIMD3<Double> = unit(cross(forward, frame.up))
        let up: SIMD3<Double> = cross(right, forward)
        var scale: Double = 1
        for aspect in orbitBackdropAspects {
            let view: MyceliumArchitectCamera = camera(aspect: aspect, orbit: orbit)
            let d: SIMD3<Double> = view.eye - view.target
            scale = max(scale, (dot(d, d).squareRoot() + orbitBackdropOffset) / backdropDistance)
        }
        let half: SIMD2<Double> = backdropHalf() * (scale * orbitBackdropSlack)
        return (centre: frame.target + forward * orbitBackdropOffset, forward: forward, right: right, up: up,
                half: half)
    }

    /// The backdrop's centre seen from `orbit` (feature 514): ``backdropFrame(_:)``'s centre; ``backdropCentre()`` at
    /// the authored orbit.
    public static func backdropCentre(orbit: MyceliumArchitectViewOrbit) -> SIMD3<Double> {
        backdropFrame(orbit).centre
    }

    /// The ghost veins of `snapshot`'s preview (feature 514, clarification Q3): for an accepted preview, every vein of
    /// the previewed report (each grown cell but the root with a parent the report has, in growth order, whatever the
    /// shown pulse) as the segment from the parent's centre to the child's at height ``ghostLift``·s; empty without a
    /// preview or for a refused one.
    static func ghostVeins(_ snapshot: MyceliumArchitectSceneSnapshot)
        -> [(from: SIMD3<Double>, to: SIMD3<Double>)] {
        guard let report = snapshot.preview?.report else { return [] }
        let s: Double = snapshot.fitScale
        let lift: SIMD3<Double> = SIMD3(0, 0, ghostLift * s)
        var veins: [(from: SIMD3<Double>, to: SIMD3<Double>)] = []
        for index in report.grown.indices where index > 0 {
            guard index < report.parents.count, let parent = report.parents[index],
                  report.grown.indices.contains(parent) else { continue }
            veins.append((from: centre(report.grown[parent], snapshot) + lift,
                          to: centre(report.grown[index], snapshot) + lift))
        }
        return veins
    }

    /// The ``ghostDashes`` dashes of a ghost vein from `a` to `b` (feature 514): dash k spans the shares
    /// (k + (1 − duty) / 2) / n … (k + (1 + duty) / 2) / n of the segment, duty ``ghostDuty``.
    static func ghostDashSegments(from a: SIMD3<Double>, to b: SIMD3<Double>)
        -> [(from: SIMD3<Double>, to: SIMD3<Double>)] {
        let n: Int = max(ghostDashes, 1)
        var dashes: [(from: SIMD3<Double>, to: SIMD3<Double>)] = []
        for k in 0..<n {
            let t0: Double = (Double(k) + (1 - ghostDuty) / 2) / Double(n)
            let t1: Double = (Double(k) + (1 + ghostDuty) / 2) / Double(n)
            dashes.append((from: a + (b - a) * t0, to: a + (b - a) * t1))
        }
        return dashes
    }

    /// Draws the ghost veins of `snapshot`'s accepted preview as dashed flat `limitTick` strips ``ghostWidth``·s wide
    /// (feature 514); nothing without a preview or for a refused one.
    static func ghosts(_ parts: inout Parts, _ snapshot: MyceliumArchitectSceneSnapshot) throws(MeshError) {
        let width: Double = ghostWidth * snapshot.fitScale
        for vein in ghostVeins(snapshot) {
            for dash in ghostDashSegments(from: vein.from, to: vein.to) {
                try parts.segment(dash.from, dash.to, width: width, code: code(.limitTick))
            }
        }
    }

    /// Draws the inspection ring (feature 514): a `pipHollow` ring of half ``inspectRing``·s around the inspected cell;
    /// nothing without an inspection or for a cell off the board.
    static func inspection(_ parts: inout Parts, _ snapshot: MyceliumArchitectSceneSnapshot) throws(MeshError) {
        guard let cell = snapshot.inspectedCell, snapshot.level.contains(cell) else { return }
        let half: Double = inspectRing * snapshot.fitScale
        try parts.flatQuad(centre: centre(cell, snapshot), half: SIMD2(half, half), code: code(.pipHollow))
    }

    // MARK: Building

    /// The length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    /// The unit vector along `v` ((0, 0, 1) for a zero vector).
    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let size: Double = length(v)
        return size > 0 ? v / size : SIMD3(0, 0, 1)
    }

    /// The cross product a × b.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// The dot product a · b.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }

    /// A convex solid collected before emission: vertices (position, normal, a_uv) and triangles, emitted with the
    /// triangles facing away from the eye first, so its near side covers its far side.
    struct Solid {
        /// The vertices: position, unit normal, a_uv.x and a_uv.y.
        var vertices: [(p: SIMD3<Double>, n: SIMD3<Double>, code: Double, local: Double)] = []
        /// The triangles as vertex indices.
        var triangles: [SIMD3<Int>] = []

        /// Adds a vertex and returns its index.
        mutating func vertex(_ p: SIMD3<Double>, normal: SIMD3<Double>, code: Double, local: Double) -> Int {
            vertices.append((p, normal, code, local))
            return vertices.count - 1
        }

        /// Adds a triangle.
        mutating func triangle(_ a: Int, _ b: Int, _ c: Int) { triangles.append(SIMD3(a, b, c)) }

        /// Adds the quad a, b, c, d as two triangles.
        mutating func quad(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
            triangle(a, b, c)
            triangle(a, c, d)
        }

        /// Adds a flat face (four corners in order) with one normal.
        mutating func face(_ corners: [SIMD3<Double>], normal: SIMD3<Double>, code: Double, local: Double) {
            var ids: [Int] = []
            for corner in corners { ids.append(vertex(corner, normal: normal, code: code, local: local)) }
            quad(ids[0], ids[1], ids[2], ids[3])
        }

        /// Emits the solid into `parts`: back-facing triangles (their mean normal pointing away from the eye) first,
        /// then the front-facing ones, each wound counter-clockwise seen from outside.
        func emit(into parts: inout Parts) throws(MeshError) {
            typealias G = MyceliumArchitectSceneGeometry
            for pass in 0..<2 {
                for t in triangles {
                    let a = vertices[t.x]
                    let b = vertices[t.y]
                    let c = vertices[t.z]
                    let outward: SIMD3<Double> = a.n + b.n + c.n
                    let middle: SIMD3<Double> = (a.p + b.p + c.p) / 3
                    let front: Bool = G.dot(outward, parts.eye - middle) > 0
                    if (pass == 0) == front { continue }
                    let ia: UInt32 = try parts.vertex(a.p, slot: a.n, code: a.code, local: a.local)
                    let ib: UInt32 = try parts.vertex(b.p, slot: b.n, code: b.code, local: b.local)
                    let ic: UInt32 = try parts.vertex(c.p, slot: c.n, code: c.code, local: c.local)
                    try parts.triangle((ia, ib, ic), a.p, b.p, c.p, facing: outward)
                }
            }
        }
    }

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from the side they face.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []
        /// The eye the solids are emitted for, far triangles first (feature 514: ``drawnEye(_:)`` of the snapshot's
        /// orbit; the authored eye by default).
        var eye: SIMD3<Double> = MyceliumArchitectSceneGeometry.eye
        /// The side flats face: up.
        static let up: SIMD3<Double> = SIMD3(0, 0, 1)
        /// The zero vector.
        static let zero: SIMD3<Double> = SIMD3(0, 0, 0)

        /// Adds (or welds) a vertex at `p` with a_normal `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour` (default the decoded material's palette colour, the broken colour when broken).
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: Vec4? = nil) throws(MeshError) -> UInt32 {
            typealias G = MyceliumArchitectSceneGeometry
            let id: UInt32 = try builder.vertex(G.vec(p), normal: G.vec(slot), uv: Vec2(code, local))
            if Int(id) == colours.count {
                let decoded = MyceliumArchitectMaterial.decode(code)
                let tint: Vec4 = colour ?? (decoded.broken ? MyceliumArchitectPalette.broken : decoded.material.colour)
                colours.append(Vec4(min(max(tint.x, 0), 1), min(max(tint.y, 0), 1), min(max(tint.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from the side `facing` points to; degenerate triangles are
        /// skipped.
        mutating func triangle(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                               _ pc: SIMD3<Double>, facing: SIMD3<Double>) throws(MeshError) {
            if ids.0 == ids.1 || ids.1 == ids.2 || ids.0 == ids.2 { return }
            let n: SIMD3<Double> = MyceliumArchitectSceneGeometry.cross(pb - pa, pc - pa)
            let side: Double = MyceliumArchitectSceneGeometry.dot(n, facing)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A quad (corners in order) facing `facing`, with uv (`code`, `local[k]`), a_normal per corner `normals`
        /// (default zero), in per-corner `colours` (default the code's).
        mutating func quad(_ p: [SIMD3<Double>], code: Double, local: [Double], colours tints: [Vec4]? = nil,
                           normals: [SIMD3<Double>]? = nil, facing: SIMD3<Double> = Parts.up) throws(MeshError) {
            var ids: [UInt32] = []
            for k in 0..<4 {
                ids.append(try vertex(p[k], slot: normals?[k] ?? Parts.zero, code: code, local: local[k],
                                      colour: tints?[k]))
            }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2], facing: facing)
            try triangle((ids[0], ids[2], ids[3]), p[0], p[2], p[3], facing: facing)
        }

        /// A quad of half `half` around `centre` in the plane of the unit axes `u` and `v` (facing u × v): the corners
        /// at ±half, a_normal (±1, ±1, 0) the quad-local coordinate, a_uv.y 0.
        mutating func shapeQuad(centre: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>, half: SIMD2<Double>,
                                code: Double) throws(MeshError) {
            let a: SIMD3<Double> = u * half.x
            let b: SIMD3<Double> = v * half.y
            try quad([centre - a - b, centre + a - b, centre + a + b, centre - a + b], code: code, local: [0, 0, 0, 0],
                     normals: [SIMD3(-1, -1, 0), SIMD3(1, -1, 0), SIMD3(1, 1, 0), SIMD3(-1, 1, 0)],
                     facing: MyceliumArchitectSceneGeometry.cross(u, v))
        }

        /// A quad of half `half` in the plane z = centre.z around `centre`, facing up.
        mutating func flatQuad(centre: SIMD3<Double>, half: SIMD2<Double>, code: Double) throws(MeshError) {
            try shapeQuad(centre: centre, u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0), half: half, code: code)
        }

        /// A plate-like strip spanning exactly x `left` … `right` and y `low` … `high` in the board plane (a grid line
        /// or a weight fill part: ``plate(left:right:low:high:code:)``).
        mutating func span(left: Double, right: Double, low: Double, high: Double, code: Double) throws(MeshError) {
            try plate(left: left, right: right, low: low, high: high, code: code)
        }

        /// A plate: a quad spanning exactly x `left` … `right` and y `low` … `high` in the board plane, a_normal
        /// (±1, ±1, 0) at its corners, facing up.
        mutating func plate(left: Double, right: Double, low: Double, high: Double, code: Double) throws(MeshError) {
            try quad([SIMD3(left, low, 0), SIMD3(right, low, 0), SIMD3(right, high, 0), SIMD3(left, high, 0)],
                     code: code, local: [0, 0, 0, 0],
                     normals: [SIMD3(-1, -1, 0), SIMD3(1, -1, 0), SIMD3(1, 1, 0), SIMD3(-1, 1, 0)])
        }

        /// A flat strip of `width` from `a` to `b` in the plane z = a.z, facing up: the quad-local u runs across the
        /// strip and v from −1 at `a` (the base) to 1 at `b` (the tip); nothing for a segment of length 0.
        mutating func segment(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, code: Double) throws(MeshError) {
            let d: SIMD3<Double> = SIMD3(b.x - a.x, b.y - a.y, 0)
            let size: Double = MyceliumArchitectSceneGeometry.length(d)
            guard size > 0 else { return }
            let along: SIMD3<Double> = d / size
            let across: SIMD3<Double> = SIMD3(along.y, -along.x, 0)
            try shapeQuad(centre: (a + b) / 2, u: across, v: along, half: SIMD2(width / 2, size / 2), code: code)
        }

        /// A glow band: a flat annulus of ``MyceliumArchitectSceneGeometry/glowSides`` sides at z = 0.002 around
        /// `centre` from `inner` (a_uv.y inner / outer) to `outer` (a_uv.y 1), facing up; a_uv.x `factor`, a_normal the
        /// kind's slot colour, the fallback colour the kind's colour.
        mutating func glowBand(centre: SIMD3<Double>, inner: Double, outer: Double, factor: Double,
                               kind: MyceliumArchitectGlowKind) throws(MeshError) {
            let n: Int = MyceliumArchitectSceneGeometry.glowSides
            let c: SIMD3<Double> = SIMD3(centre.x, centre.y, MyceliumArchitectSceneGeometry.glowLift)
            let colour: Vec4 = kind.colour
            let slot: SIMD3<Double> = kind.slot
            let radial: Double = outer > 0 ? min(max(inner / outer, 0), 1) : 0
            for k in 0..<n {
                let a0: Double = 2 * Double.pi * Double(k) / Double(n)
                let a1: Double = 2 * Double.pi * Double(k + 1) / Double(n)
                let e0: SIMD3<Double> = SIMD3(cos(a0), sin(a0), 0)
                let e1: SIMD3<Double> = SIMD3(cos(a1), sin(a1), 0)
                try quad([c + e0 * inner, c + e0 * outer, c + e1 * outer, c + e1 * inner],
                         code: factor, local: [radial, 1, 1, radial], colours: [colour, colour, colour, colour],
                         normals: [slot, slot, slot, slot])
            }
        }

        /// The coloured mesh built so far.
        func built() -> MyceliumArchitectColouredMesh {
            MyceliumArchitectColouredMesh(mesh: builder.build(), colours: colours)
        }
    }
}
