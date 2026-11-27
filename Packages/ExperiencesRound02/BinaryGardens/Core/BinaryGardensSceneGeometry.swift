// BinaryGardensSceneGeometry — feature 503 (R02-G21-03) T-R02G2103-004 (FR-R02G2103-001, 002, 003, 004, 006, 007,
// 010; SC-R02G2103-001, 003; clarifications Q1–Q4, Q6; research R1–R4, R7–R11). The star system of Binary Gardens,
// built from a snapshot only. The kernel's base plane is z = 0 (x right, y away from the viewer across the plane, z up
// out of it), the binary's barycentre at the origin. One fit rule per level (clarification Q1, research R1): a kernel
// point (x, y, z) at scale 2^20 is drawn at k · (x, y, z) / 2^20 with k = 0.95 / R, R the largest of the level's ring
// radii and world radii (level constants), so every system fills the same disc of radius 0.95 and nothing a player
// does changes the scale. Every orbit curve is a 48-gon through the kernel's own table points (research R2): a star
// ring's vertex i is the kernel's star position at phase i on that ring at the current tilt and a world orbit's vertex
// i the kernel's world position at phase i, so every body sits exactly on a vertex of its drawn orbit. Nothing here is
// consulted by the rules.
//
// Draw order (research R4): the whole system mesh is drawn in painter's order with depth testing off and no face
// culling (the window surface of the shared renderer has no depth buffer, as feature 493 learned), in the order of the
// elements (``BinaryGardensElement``): by kind, the bodies (both stars and every world) forming one group sorted back
// to front by their distance from the eye (ties: worlds before stars, then index), each body's parts drawn with it;
// within a kind by index. A cube-sphere emits its quads far-first from the fixed eye, so its near side covers its far
// side. A "quad of shape half h" spans ±``BinaryGardensShaders/quadExtent`` · h (1.25 h) around its centre; its shape
// (square, disc or ring of outer radius h) spans ±h and the shader cuts it out:
//   0. backdrop: one quad perpendicular to the view axis at distance ``backdropDistance`` from the eye, filling the
//      view for aspects 0.25 … 4; the still vertical gradient space (bottom) … space top (top) with the starfield;
//   1. tiltDial (when T_max > 0): T_max + 1 pips of shape half 0.015 from (−1.15, 1.08, 0) to the right in steps of
//      0.05, facing the eye, the current tilt's `tiltPipLit` (disc), the others `tiltPipUnlit` (ring);
//   2. ring: per ring radius ρ of the level, its 48 segments (vertex i to i + 1) as strips 0.008 wide (0.012 where a
//      star stands) in the orbit plane at the current tilt: `ringIdle` on the even segments only (dashed) when no star
//      stands on it, every segment `ringStarOne` or `ringStarTwo` when one star does, every segment `ringShared` with
//      its parity in `a_normal.z` when both do;
//   3. orbit: per world, its 48 segments as `orbit` strips 0.006 wide in the base plane;
//   4. trail: at the tiers with trails only: per tick of ``trailTicks(shownTick:count:)`` (age a = 1 … n), a `trail`
//      disc of shape half 0.012 facing the eye at every star's and world's kernel position at that tick (value: the
//      freshness 1 − a / (n + 1)); decoration only;
//   5. world (a body): a cube-sphere of radius 0.07 at its position at the shown tick (``cubeSphere(faceQuads:)``,
//      faceQuads by tier), its band at the shown tick as its material (value: star 1's share / 64 000; a_uv.y: star
//      2's share / 64 000; a_normal: the sphere normal); then j + 1 `worldPip` discs of shape half 0.008 beneath it in
//      the eye-facing plane (0.095 below its centre, 0.022 apart); a frozen or scorched failure naming it adds a
//      `brokenRing` of outer radius 0.1 around it; at the tiers with motes, a comfortable world (every world on a won
//      level) gets `tier.motes` `mote` discs of shape half 0.008 placed one ``BinaryGardensShaders/moteLoopRadius`` to
//      +x of its centre (value: phase k / n; a_normal.z: the radius), which the vertex shader moves round the world;
//   6. star (a body): at the tiers with coronas, `tier.coronaRays` `corona` rays (root at 0.9 r, tip at 1.8 r, at
//      angles 2π k / n in the eye-facing plane; value: phase k / n; a_normal.z: the star); its disc facing the eye of
//      radius r = 0.05 + 0.012 · (luminosity index) at its position at the shown tick (`starOne`, `starTwo`, with the
//      white-hot core in the shader); one pip of shape half 0.008 per luminosity level of the level beneath it (r +
//      0.03 below, 0.022 apart), `luminosityPipLit` up to its current level and `luminosityPipUnlit` above;
//   7. gauge: per world j a row at y = −1.2 − 0.1 · j: a `gaugePlate` from x −0.95 to 1.22 (its quad spanning exactly
//      that, u = ±1) and y ± 0.045; 48 tick
//      cells, cell t at x −0.9 + (t − 0.5) · 1.8/48, 0.8 · 1.8/48 wide, from the baseline y − 0.028 up by
//      ``cellHeight(flux:lethalHigh:)``, its band's cell material (value: its height share); two `guide` strips at the
//      heights of c_lo and c_hi; a `windowBracket` (or `windowBracketShort` when the window is shorter than W) under
//      the longest comfortable window from its start tick over its length (two pieces when it wraps past tick 48), y
//      −0.042 … −0.030 from the row; a `requiredTick` at the boundary W cells after the window's start (after tick 0
//      when there is no comfortable tick); a `tickMarker` disc of shape half 0.006 at y + 0.048 above the shown tick's
//      column; the bloom meter: a `bloomTrack` strip from x 0.97 to 1.2 mapping 0 … max(1, 2 · B_hi), a
//      `bloomBracket` over B_lo … B_hi and a `bloomMarker` disc of shape half 0.012 at min(I, 2 · B_hi);
//   8. actions: `budget` bars at y = −1.2 − 0.1 · worlds − 0.03, each 1.8 / budget wide with a fifth as gap, 0.035
//      tall, `actionsLit` for the actions left, `actionsUnlit` for the rest;
//   9. glow: the glow mesh, drawn last and additively: `tier.glowShells` shells k (outermost first), each an annulus of
//      ``glowSides`` sides facing the eye, around every star from 0.9 r to r + 0.04 · k (kind star, its colour, factor
//      1) and around every world from 0.06 to 0.07 + 0.035 · k (kind world, factor
//      ``BinaryGardensShaders/glowFactor(blooming:)`` of its band at the shown tick). Empty at level-2. A won level
//      moves nothing: the shaders' `u_won` makes every world bloom and raises its shell.
//
// Failures (clarification Q4, research R11) are marked only on a play that failed (stage `failed`, or `result` after a
// failed run), never for the predicted failure while playing: frozen or scorched — a broken ring around the named world
// and its gauge cell at column ((tick − 1) mod 48) + 1; unstable — the named world's window bracket, or, when no tick
// is comfortable (window 0, start 0), its required tick drawn alone; wilted or bleached — its bloom marker.
//
// Vertex streams (the contract of ``BinaryGardensShaders``): a_uv.x = ``BinaryGardensShaders/encode(_:value:broken:)``
// (material code + 0.4 · value for the valued materials + 64 when broken). Worlds: a_normal the unit sphere normal,
// a_uv.y star 2's share / 64 000. Quads (every flat): a_normal (u, v, w), (u, v) = ±1.25 at the corners (the gauge
// plate's u = ±1 at its ends), w 0 except
// ringShared's parity, corona's star and mote's loop radius; a_uv.y 0. Backdrop: a_normal its plane offsets (x, y, 0),
// a_uv.y the height 0 … 1. Glow mesh: a_normal the star's colour for a star shell and zero for a world shell, a_uv.x
// ``BinaryGardensShaders/GlowKind/code(factor:)``, a_uv.y 0 on a shell's inner edge and 1 on its outer edge. Every
// triangle winds counter-clockwise seen from the side it faces (no culling relies on it). Tiers change only the
// tessellation, the coronas, the trails, the motes and the glow: every body, orbit, pip, gauge and bar is the same at
// every tier. Nothing here depends on the presentation time. Doubles are used for drawing only. Modelled on
// `MushroomWeatherSceneGeometry` (feature 493).
//
// Feature 504 (R02-G21-04) T-R02G2104-002 (FR-R02G2104-001 … 010, 015; SC-R02G2104-001, 003, 004, 006;
// clarifications Q1, Q3, Q4; research R5, R6, R9) adds, modelled on feature 494:
//   * the player's view orbit (``BinaryGardensViewOrbit``) and `camera(aspect:orbit:)`: the authored camera frame (eye,
//     look-at point and up direction) is turned rigidly by the pitch about the authored right axis (+x) through the
//     look-at point (positive raises the eye), then by the yaw about the vertical axis (+z) through the authored box
//     centre (0, −0.35, 0) — the look-at point itself, so the camera always looks at it; the field of view stays the
//     authored one for the aspect and the eye moves along the view axis to the larger of the authored distance (≈ 3.60)
//     and the distance at which every corner of the authored box (which already holds every ring at tilt 6, the dial,
//     the gauges and the bars) lies inside the view with ``refitMargin`` per side, so everything inside the box keeps a
//     margin of at least 5 % at every orbit and aspect 0.4 … 2.5 and the eye stays outside the box. At the authored
//     orbit `camera(aspect:)` (which calls it) is the fixed camera of R02-G21-03, bit for bit;
//   * the drawn eye: every part facing the eye (tilt pips, trail dots, world and luminosity pips, broken rings, motes,
//     star discs, corona rays, glow shells, the ghost star and the inspection ring) faces the camera's eye, the bodies
//     sort back to front from it (`paintOrder(_:eye:)`), a cube-sphere emits its quads far-first from it and the
//     backdrop stands perpendicular to its view axis behind the box (`backdropCentre(eye:)`); the camera-taking
//     `systemMesh`, `glowMesh`, `systemPart` and `glowPart` build for a camera, and the overloads without one use the
//     authored camera;
//   * the preview (`snapshot.preview`, research R5): an accepted preview draws the worlds and gauges from the previewed
//     report (``drawnSnapshot(_:)``) — for a luminosity or tilt change also the previewed arrangement and star positions
//     (the star's disc and pips at the previewed level; the rings, stars and dial at the previewed tilt) — and, behind
//     every previewed gauge cell, the committed cell as an outline of four strips ``ghostCellWidth`` wide (the ghost
//     bands, material 39 `ghostCell`, valued by the committed band's index / 4); a ring or phase change keeps the
//     committed stars and rings and adds the ghost star (``ghostStars(_:)``: a dashed ring of the star's disc radius
//     facing the eye, material 38 `ghostStar`, `a_normal.z` the star) at the target's position at the shown tick, right
//     after its star's disc and pips inside that star's element. A refused preview keeps the committed drawing and adds
//     the ghost in the broken colour: at the target for a ring or phase change, at the star with its previewed radius
//     for a luminosity change, at both stars' positions at the previewed tilt for a tilt change;
//   * the inspection marks (research R6): the inspected world gets an `inspectRing` (material 40, ring shape of outer
//     radius ``inspectRingRadius`` facing the eye) after its broken ring, and its gauge row two `inspectBracket` strips
//     (material 41, ``bracketWidth`` wide over y ± ``bracketHalf``) at x ``bracketLeft`` and ``bracketRight`` after
//     the rest of the row.
// Without a preview and an inspection, at the authored camera, every mesh is R02-G21-03's. The orbit, the preview and
// the inspection are presentation only: never saved, never read by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct BinaryGardensCamera: Sendable, Equatable {
    /// The eye position in world units, (0, −2.0, 3.2).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.35, 0).
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

/// One drawn element of the scene with its place in the drawing order (research R4).
public struct BinaryGardensElement: Sendable, Equatable {
    /// The kind of an element, in the drawing order; worlds and stars form one group sorted back to front.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The space backdrop with the starfield.
        case backdrop = 0
        /// The tilt dial (only when T_max > 0).
        case tiltDial = 1
        /// A star ring (`item` its ring index).
        case ring = 2
        /// A world's orbit (`item` the world).
        case orbit = 3
        /// The trails (nothing at a tier without trails).
        case trail = 4
        /// A world with its pips, broken ring and motes (`item` the world).
        case world = 5
        /// A star with its corona and luminosity pips (`item` the star).
        case star = 6
        /// A world's gauge row (`item` the world).
        case gauge = 7
        /// An actions bar (`item` the bar).
        case actions = 8
        /// A glow shell group of the glow mesh (`item` the star 0 … 1, or 2 + the world).
        case glow = 9

        /// Whether the kind is a body (a world or a star), sorted by its distance from the eye.
        public var isBody: Bool { self == .world || self == .star }

        /// The rank the order compares: the bodies share the world's rank.
        var rank: Int { self == .star ? Kind.world.rawValue : rawValue }
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind.
    public let index: Int
    /// The item the element draws: ring, world, star, bar or glow group (0 for the single elements).
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

    /// Whether `a` is drawn before `b`: by kind first (the bodies sharing one rank); two bodies by their distance from
    /// `eye`, the farther first (ties: worlds before stars, then index); otherwise by index.
    public static func drawsBefore(_ a: BinaryGardensElement, _ b: BinaryGardensElement,
                                   eye: SIMD3<Double>) -> Bool {
        if a.kind.rank != b.kind.rank { return a.kind.rank < b.kind.rank }
        if a.kind.isBody && b.kind.isBody {
            let da: Double = BinaryGardensSceneGeometry.length(a.centre - eye)
            let db: Double = BinaryGardensSceneGeometry.length(b.centre - eye)
            if abs(da - db) > 1e-12 { return da > db }
            if a.kind != b.kind { return a.kind == .world }
        }
        return a.index < b.index
    }
}

/// A point of the CPU reference (clarification Q3).
public struct BinaryGardensReferencePoint: Sendable, Equatable {
    /// What the point marks.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The barycentre, the origin.
        case barycentre = 0
        /// A world's centre at the shown tick.
        case world = 1
        /// A star's centre at the shown tick.
        case star = 2
        /// The first gauge plate's left margin, (−0.925, −1.2, 0).
        case gaugeMargin = 3
        /// The first actions bar's centre.
        case actionsBar = 4
    }

    /// What the point marks.
    public let kind: Kind
    /// The world or star index (0 for the single points).
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
public struct BinaryGardensColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Binary Gardens star system from a `BinaryGardensSceneSnapshot`: places, meshes, camera and projection
/// (see the file header).
public enum BinaryGardensSceneGeometry {
    // MARK: Constants (world units)

    /// The disc every system fills: radius 0.95 (k = 0.95 / R).
    public static let discRadius: Double = 0.95
    /// A world's cube-sphere radius.
    public static let worldRadius: Double = 0.07
    /// A star disc's radius at luminosity index 0.
    public static let starBaseRadius: Double = 0.05
    /// A star disc's growth per luminosity index.
    public static let starRadiusStep: Double = 0.012
    /// The first tilt pip's centre.
    public static let tiltDialStart: SIMD3<Double> = SIMD3(-1.15, 1.08, 0)
    /// The step between tilt pips.
    public static let tiltPipStep: Double = 0.05
    /// A tilt pip's radius.
    public static let tiltPipRadius: Double = 0.015
    /// An idle ring dash's width.
    public static let ringWidth: Double = 0.008
    /// A ring's width where a star stands on it.
    public static let starRingWidth: Double = 0.012
    /// An orbit segment's width.
    public static let orbitWidth: Double = 0.006
    /// A trail dot's radius.
    public static let trailRadius: Double = 0.012
    /// A world or luminosity pip's radius.
    public static let pipRadius: Double = 0.008
    /// The step between pips.
    public static let pipStep: Double = 0.022
    /// How far below a world's centre its pips stand (in the eye-facing plane).
    public static let worldPipDrop: Double = 0.095
    /// How far below a star's rim its luminosity pips stand.
    public static let starPipGap: Double = 0.03
    /// A broken ring's outer radius around a world.
    public static let brokenRingRadius: Double = 0.1
    /// A mote's radius.
    public static let moteRadius: Double = 0.008
    /// A corona ray's root as a share of the star's radius.
    public static let coronaRoot: Double = 0.9
    /// A corona ray's tip as a share of the star's radius.
    public static let coronaTip: Double = 1.8
    /// A corona ray's half-width at its root as a share of the star's radius.
    public static let coronaHalfWidth: Double = 0.12
    /// The first gauge row's centre line.
    public static let gaugeTop: Double = -1.2
    /// The step between gauge rows.
    public static let gaugeStep: Double = 0.1
    /// A gauge plate's left edge.
    public static let plateLeft: Double = -0.95
    /// A gauge plate's right edge.
    public static let plateRight: Double = 1.22
    /// A gauge plate's half height.
    public static let plateHalf: Double = 0.045
    /// The x of the reference point on a plate's left margin.
    public static let marginX: Double = -0.925
    /// The tick cells' left end.
    public static let cellsStart: Double = -0.9
    /// The tick cells' right end.
    public static let cellsEnd: Double = 0.9
    /// The cells' baseline below a row's centre line.
    public static let baselineDrop: Double = 0.028
    /// The cell height of a flux of 0.
    public static let cellBase: Double = 0.01
    /// The cell height growth up to F = λ_hi.
    public static let cellGrowth: Double = 0.06
    /// The share of a slot a cell or a bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// A guide line's height.
    public static let guideHeight: Double = 0.003
    /// The window bracket's lower edge below a row's centre line.
    public static let bracketLow: Double = 0.042
    /// The window bracket's upper edge below a row's centre line.
    public static let bracketHigh: Double = 0.030
    /// The required tick's width.
    public static let requiredWidth: Double = 0.004
    /// The required tick's lower edge below a row's centre line.
    public static let requiredLow: Double = 0.045
    /// The required tick's upper edge below a row's centre line.
    public static let requiredHigh: Double = 0.026
    /// The tick marker's height above a row's centre line.
    public static let markerRise: Double = 0.048
    /// The tick marker's radius.
    public static let markerRadius: Double = 0.006
    /// The bloom meter's left end.
    public static let bloomStart: Double = 0.97
    /// The bloom meter's right end.
    public static let bloomEnd: Double = 1.2
    /// The bloom track's height.
    public static let bloomTrackHeight: Double = 0.008
    /// The bloom bracket's half height.
    public static let bloomBracketHalf: Double = 0.012
    /// The smallest half width of a bloom bracket.
    public static let bloomBracketMinimum: Double = 0.003
    /// The bloom marker's radius.
    public static let bloomMarkerRadius: Double = 0.012
    /// The gap from the last gauge row to the actions bars' centre line.
    public static let actionsGap: Double = 0.03
    /// The actions bars' left end.
    public static let actionsStart: Double = -0.9
    /// The actions bars' width in all.
    public static let actionsWidth: Double = 1.8
    /// An actions bar's height.
    public static let actionsHeight: Double = 0.035
    /// A star glow shell's inner radius as a share of the star's radius.
    public static let starGlowInner: Double = 0.9
    /// A star glow shell's growth per shell.
    public static let starGlowGrowth: Double = 0.04
    /// A world glow shell's inner radius.
    public static let worldGlowInner: Double = 0.06
    /// A world glow shell's growth per shell.
    public static let worldGlowGrowth: Double = 0.035
    /// The sides of a glow shell.
    public static let glowSides: Int = 24
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, -2.0, 3.2)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.35, 0)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-1.3, -1.85, -0.85)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1.3, 1.15, 0.85)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The aspects the backdrop fills.
    public static let backdropAspects: ClosedRange<Double> = 0.25...4
    /// The backdrop's distance from the eye along the view axis.
    public static let backdropDistance: Double = 7
    /// The margin per side in view coordinates an orbiting camera refits the authored box to (feature 504; equal to
    /// ``fitMargin``, so the refit is continuous at the authored orbit).
    public static let refitMargin: Double = 0.06
    /// The inspection ring's outer radius around the inspected world (feature 504; outside the 0.1 broken ring).
    public static let inspectRingRadius: Double = 0.115
    /// The width of an inspection bracket strip (feature 504).
    public static let bracketWidth: Double = 0.006
    /// The half height of an inspection bracket strip around its row's centre line (feature 504).
    public static let bracketHalf: Double = 0.05
    /// The x of the left inspection bracket (feature 504), just left of the plate.
    public static let bracketLeft: Double = -0.962
    /// The x of the right inspection bracket (feature 504), just right of the plate.
    public static let bracketRight: Double = 1.232
    /// The width of a ghost cell's outline strips (feature 504).
    public static let ghostCellWidth: Double = 0.003

    // MARK: Material codes and colours

    /// The a_uv.x value of `material` with `value` and the broken mark
    /// (``BinaryGardensShaders/encode(_:value:broken:)``).
    static func code(_ material: BinaryGardensMaterial, value: Double = 0, broken: Bool = false) -> Double {
        BinaryGardensShaders.encode(material, value: value, broken: broken)
    }

    /// The fallback colour of a system vertex whose a_uv.x is `code`, with won light `won` (0 … 1): the base colour the
    /// system vertex shader selects (``BinaryGardensShaders/baseColour(of:value:broken:won:shape:)`` of the decoded
    /// material and broken mark); a world tinted by its band (frost mixed in by a half for lethal low and a quarter for
    /// dim, scorch by a half for lethal high and a quarter for bright; plain mint on a won level).
    public static func colour(of code: Double, won: Double = 0) -> SIMD3<Double> {
        let decoded: (material: BinaryGardensMaterial, value: Double, broken: Bool) = BinaryGardensShaders.decode(code)
        let base: SIMD3<Double> = BinaryGardensShaders.baseColour(of: decoded.material, value: decoded.value,
                                                                  broken: decoded.broken, won: won)
        guard !decoded.broken, let band = decoded.material.band, won < 0.5 else { return base }
        switch band {
        case .lethalLow: return base + (BinaryGardensPalette.frost - base) * 0.5
        case .dim: return base + (BinaryGardensPalette.frost - base) * 0.25
        case .comfortable: return base
        case .bright: return base + (BinaryGardensPalette.scorch - base) * 0.25
        case .lethalHigh: return base + (BinaryGardensPalette.scorch - base) * 0.5
        }
    }

    // MARK: Places (the CPU reference)

    /// The fit scale k = 0.95 / R for R the largest of `ringRadii` and `worldRadii` (R at least 1).
    public static func fitScale(ringRadii: [Int], worldRadii: [Int]) -> Double {
        BinaryGardensSceneSnapshot.fitScale(ringRadii: ringRadii, worldRadii: worldRadii)
    }

    /// Kernel point `point` (scale 2^20) drawn at fit scale `scale`: k · (x, y, z) / 2^20.
    public static func position(_ point: BinaryGardensPoint, scale: Double) -> SIMD3<Double> {
        let unit: Double = Double(BinaryGardensSky.positionScale)
        return SIMD3(Double(point.x) / unit, Double(point.y) / unit, Double(point.z) / unit) * scale
    }

    /// Vertex `step` (0 … 47, read cyclically) of the 48-gon of a star ring of radius `radius` at tilt `tilt`: the
    /// kernel's own star position there, (ρ·C[i]/1024, ρ·S[i]/1024 · C[τ]/1024, ρ·S[i]/1024 · S[τ]/1024) · k.
    public static func ringVertex(radius: Int, step: Int, tilt: Int, scale: Double) -> SIMD3<Double> {
        position(BinaryGardensSky.starPosition(radius: radius, phase: step, tilt: tilt), scale: scale)
    }

    /// Vertex `step` of the 48-gon of a world orbit of radius `radius`: the kernel's world position there,
    /// (a·C[i]/1024, a·S[i]/1024, 0) · k.
    public static func orbitVertex(radius: Int, step: Int, scale: Double) -> SIMD3<Double> {
        position(BinaryGardensSky.worldPosition(radius: radius, phase: step), scale: scale)
    }

    /// Star `star`'s centre at the shown tick: its kernel position drawn at the snapshot's fit scale.
    public static func starCentre(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot) -> SIMD3<Double> {
        position(snapshot.starPoint(star, tick: snapshot.shownTick), scale: snapshot.fitScale)
    }

    /// World `world`'s centre at the shown tick.
    public static func worldCentre(_ world: Int, _ snapshot: BinaryGardensSceneSnapshot) -> SIMD3<Double> {
        position(snapshot.worldPoint(world, tick: snapshot.shownTick), scale: snapshot.fitScale)
    }

    /// Both stars' centres at the shown tick, the values the presenter passes as `u_star1` and `u_star2`.
    public static func starUniforms(_ snapshot: BinaryGardensSceneSnapshot) -> (SIMD3<Double>, SIMD3<Double>) {
        (starCentre(0, snapshot), starCentre(1, snapshot))
    }

    /// A star disc's radius at luminosity index `luminosityIndex` (clamped to 0 … 3): 0.05 + 0.012 · index.
    public static func starRadius(luminosityIndex: Int) -> Double {
        starBaseRadius + starRadiusStep * Double(min(max(luminosityIndex, 0), 3))
    }

    /// Star `star`'s disc radius in `snapshot` (its current luminosity index; public since feature 504).
    public static func starRadius(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot) -> Double {
        let lums: [Int] = snapshot.arrangement.luminosities
        return starRadius(luminosityIndex: lums.indices.contains(star) ? lums[star] : 0)
    }

    /// Tilt pip `step`'s centre: (−1.15 + 0.05 · step, 1.08, 0).
    public static func tiltPipCentre(_ step: Int) -> SIMD3<Double> {
        tiltDialStart + SIMD3(tiltPipStep * Double(step), 0, 0)
    }

    /// The centre line of world `world`'s gauge row, −1.2 − 0.1 · world.
    public static func gaugeY(_ world: Int) -> Double { gaugeTop - gaugeStep * Double(max(world, 0)) }

    /// The reference point on world `world`'s gauge plate's left margin: (−0.925, gauge y, 0).
    public static func gaugeMargin(_ world: Int) -> SIMD3<Double> { SIMD3(marginX, gaugeY(world), 0) }

    /// The width of one tick column, 1.8 / 48.
    public static var cellPitch: Double { (cellsEnd - cellsStart) / Double(BinaryGardensSky.cycle) }

    /// The x of tick `tick`'s column centre (read cyclically): −0.9 + (t − 0.5) · 1.8/48.
    public static func cellX(_ tick: Int) -> Double {
        cellsStart + (Double(BinaryGardensSceneSnapshot.tickIndex(tick)) + 0.5) * cellPitch
    }

    /// Tick `tick`'s column centre on world `world`'s row centre line: (cell x, gauge y, 0) (the cell itself rises
    /// from the baseline 0.028 below it).
    public static func cellCentre(_ world: Int, tick: Int) -> SIMD3<Double> { SIMD3(cellX(tick), gaugeY(world), 0) }

    /// The baseline the cells of world `world` rise from: gauge y − 0.028.
    public static func baseline(_ world: Int) -> Double { gaugeY(world) - baselineDrop }

    /// A cell's height for flux `flux` on a world with lethal high bound `lethalHigh`: 0.01 + 0.06 · min(1, F/λ_hi).
    public static func cellHeight(flux: Int, lethalHigh: Int) -> Double {
        cellBase + cellGrowth * BinaryGardensShaders.heightShare(flux: flux, lethalHigh: lethalHigh)
    }

    /// The bloom meter's top value for a bloom band whose high bound is `bloomHigh`: max(1, 2 · B_hi).
    public static func bloomTop(_ bloomHigh: Int) -> Int { max(1, 2 * bloomHigh) }

    /// The x of `value` on the bloom meter of a world whose high bound is `bloomHigh`: 0.97 + 0.23 · min(value, top)
    /// / top, top = max(1, 2 · B_hi) (value below 0 as 0).
    public static func bloomX(_ value: Int, bloomHigh: Int) -> Double {
        let top: Double = Double(bloomTop(bloomHigh))
        return bloomStart + (bloomEnd - bloomStart) * min(max(Double(value), 0), top) / top
    }

    /// The centre line of the actions bars: −1.2 − 0.1 · worlds − 0.03.
    public static func actionsY(_ snapshot: BinaryGardensSceneSnapshot) -> Double {
        gaugeTop - gaugeStep * Double(snapshot.worlds.count) - actionsGap
    }

    /// The width of one actions slot, 1.8 / budget.
    public static func actionsSlot(_ snapshot: BinaryGardensSceneSnapshot) -> Double {
        actionsWidth / Double(max(snapshot.budget, 1))
    }

    /// The centre of actions bar `index`: (−0.9 + (index + 0.5) · slot, actions y, 0).
    public static func actionsBar(_ index: Int, _ snapshot: BinaryGardensSceneSnapshot) -> SIMD3<Double> {
        SIMD3(actionsStart + (Double(index) + 0.5) * actionsSlot(snapshot), actionsY(snapshot), 0)
    }

    /// The actions bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litActions(_ snapshot: BinaryGardensSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The column of walk tick `tick` (1 … 48 + E): ((tick − 1) mod 48) + 1.
    public static func failureColumn(_ tick: Int) -> Int { BinaryGardensSceneSnapshot.tickIndex(tick) + 1 }

    /// The ticks of the trail before `shownTick`, newest first: ((t − 1 − a) mod 48) + 1 for a = 1 … count (empty for
    /// a count of 0 or less).
    public static func trailTicks(shownTick: Int, count: Int) -> [Int] {
        var ticks: [Int] = []
        if count > 0 {
            for age in 1...count { ticks.append(BinaryGardensSceneSnapshot.tickIndex(shownTick - age) + 1) }
        }
        return ticks
    }

    /// The window pieces of a world: (first tick, last tick) of its longest comfortable window from its start over its
    /// length, split in two when it wraps past tick 48; empty when no tick is comfortable.
    public static func windowPieces(_ world: BinaryGardensSceneWorld) -> [(first: Int, last: Int)] {
        let cycle: Int = BinaryGardensSky.cycle
        let length: Int = min(max(world.longestWindow, 0), cycle)
        guard length > 0, (1...cycle).contains(world.windowStart) else { return [] }
        let end: Int = world.windowStart + length - 1
        if end <= cycle { return [(first: world.windowStart, last: end)] }
        return [(first: world.windowStart, last: cycle), (first: 1, last: end - cycle)]
    }

    /// The x of the required tick of a world: the boundary W cells after its window's start (after tick 0 when no tick
    /// is comfortable), read cyclically: −0.9 + c · 1.8/48 with c = ((start − 1 + W − 1) mod 48) + 1, or c = W.
    public static func requiredX(_ world: BinaryGardensSceneWorld) -> Double {
        let cycle: Int = BinaryGardensSky.cycle
        let required: Int = min(max(world.window, 0), cycle)
        let column: Int
        if world.longestWindow > 0, (1...cycle).contains(world.windowStart) {
            column = ((world.windowStart - 1 + required - 1) % cycle + cycle) % cycle + 1
        } else {
            column = required
        }
        return cellsStart + Double(column) * cellPitch
    }

    /// Whether the snapshot shows a failed play (stage `failed`, or `result` after a failed run): only then is a
    /// failure marked.
    static func marksFailure(_ snapshot: BinaryGardensSceneSnapshot) -> Bool {
        snapshot.failure != nil && (snapshot.stage == .failed || snapshot.stage == .result)
    }

    /// The world and the column of a frozen or scorched failure on a failed play, nil otherwise.
    public static func lethalMark(_ snapshot: BinaryGardensSceneSnapshot) -> (world: Int, column: Int)? {
        guard marksFailure(snapshot) else { return nil }
        switch snapshot.failure {
        case .frozen(let world, let tick), .scorched(let world, let tick): return (world, failureColumn(tick))
        default: return nil
        }
    }

    /// The world an unstable failure names on a failed play, nil otherwise.
    public static func unstableWorld(_ snapshot: BinaryGardensSceneSnapshot) -> Int? {
        guard marksFailure(snapshot), case .unstable(let world, _, _) = snapshot.failure else { return nil }
        return world
    }

    /// The world a wilted or bleached failure names on a failed play, nil otherwise.
    public static func bloomWorld(_ snapshot: BinaryGardensSceneSnapshot) -> Int? {
        guard marksFailure(snapshot) else { return nil }
        switch snapshot.failure {
        case .wilted(let world, _, _, _), .bleached(let world, _, _, _): return world
        default: return nil
        }
    }

    /// Whether world `world` blooms: comfortable at the shown tick (every world on a won level when `won`).
    public static func blooms(_ world: Int, _ snapshot: BinaryGardensSceneSnapshot, won: Bool) -> Bool {
        won || snapshot.band(world) == .comfortable
    }

    /// The backdrop's centre: on the view axis at ``backdropDistance`` from the eye.
    public static func backdropCentre() -> SIMD3<Double> { eye + viewBasis().forward * backdropDistance }

    /// The backdrop's centre seen from `viewer` (feature 504): on the view axis from `viewer` to the look-at point (the
    /// target of every orbit camera) at ``facingBackdropDistance(eye:)``; ``backdropCentre()`` for the authored eye.
    public static func backdropCentre(eye viewer: SIMD3<Double>) -> SIMD3<Double> {
        guard viewer != eye else { return backdropCentre() }
        return viewer + unit(lookAt - viewer) * facingBackdropDistance(eye: viewer)
    }

    /// The distance from `viewer` along its view axis (towards the look-at point) at which the backdrop stands (feature
    /// 504): the larger of ``backdropDistance`` and the farthest box corner's depth plus 1 (``backdropDistance`` for the
    /// authored eye).
    public static func facingBackdropDistance(eye viewer: SIMD3<Double>) -> Double {
        guard viewer != eye else { return backdropDistance }
        let forward: SIMD3<Double> = unit(lookAt - viewer)
        var farthest: Double = 0
        for index in 0..<8 { farthest = max(farthest, dot(corner(index) - viewer, forward)) }
        return max(backdropDistance, farthest + 1)
    }

    // MARK: Preview (feature 504)

    /// The snapshot the system is drawn from (feature 504, research R5): `snapshot` itself without a preview or with a
    /// refused one (the committed drawing), keeping its inspection; with an accepted preview, a copy whose worlds carry
    /// the previewed report's light (flux, shares, bands, lethal run, window and its start, integral and bloom) and,
    /// while the play has not failed, the previewed failure; for a luminosity or tilt change also the previewed
    /// arrangement and star positions; for a ring or phase change the committed arrangement and stars (the ghost star
    /// shows the target). The copy carries no preview and the same inspection.
    public static func drawnSnapshot(_ snapshot: BinaryGardensSceneSnapshot) -> BinaryGardensSceneSnapshot {
        guard let preview = snapshot.preview else { return snapshot }
        guard case .accepted(let arrangement, let report) = preview.outcome,
              report.worlds.count == snapshot.worlds.count else { return snapshot.clearingPreview() }
        let s: BinaryGardensSceneSnapshot = snapshot
        var worlds: [BinaryGardensSceneWorld] = []
        for (index, world) in s.worlds.enumerated() {
            let light: BinaryGardensWorldLight = report.worlds[index]
            worlds.append(BinaryGardensSceneWorld(radius: world.radius, phase: world.phase, speed: world.speed,
                                                  lethalLow: world.lethalLow, comfortLow: world.comfortLow,
                                                  comfortHigh: world.comfortHigh, lethalHigh: world.lethalHigh,
                                                  window: world.window, bloomLow: world.bloomLow,
                                                  bloomHigh: world.bloomHigh, positions: world.positions,
                                                  flux: light.flux, shares: light.shares, bands: light.bands,
                                                  longestLethalRun: light.longestLethalRun,
                                                  longestWindow: light.window, windowStart: light.windowStart,
                                                  integral: light.integral, bloom: light.bloom))
        }
        var drawnArrangement: BinaryGardensArrangement = s.arrangement
        var stars: [[BinaryGardensPoint]] = s.starPositions
        switch preview.change {
        case .luminosity, .tilt:
            drawnArrangement = arrangement
            stars = report.starPositions
        default:
            break
        }
        let failure: BinaryGardensFailure? = marksFailure(s) ? s.failure : report.failure
        let drawn: BinaryGardensSceneSnapshot = BinaryGardensSceneSnapshot(
            ringRadii: s.ringRadii, luminosityLevels: s.luminosityLevels, maxTilt: s.maxTilt, phaseStep: s.phaseStep,
            lethalTolerance: s.lethalTolerance, worlds: worlds, arrangement: drawnArrangement, starPositions: stars,
            shownTick: s.shownTick, failure: failure, stage: s.stage, actionsLeft: s.actionsLeft, budget: s.budget,
            levelNumber: s.levelNumber, time: s.time, starSpeed: s.starSpeed, freedoms: s.freedoms)
        return drawn.inspecting(s.inspectedWorld)
    }

    /// The ghost stars of `snapshot`'s preview (feature 504, research R5), each with its star, centre, radius and
    /// whether the change is refused (drawn in the broken colour): for a ring change the star at its drawn table step
    /// (``BinaryGardensSceneSnapshot/starStep(_:tick:)`` at the shown tick) on the target ring, for a phase change at
    /// the target phase's table step (p + ω · t) mod 48 on its ring, both at the current tilt with the star's current
    /// disc radius; for a refused luminosity change the star with its previewed radius; for a refused tilt change both
    /// stars at their drawn table steps at the previewed tilt. Empty without a preview, for an accepted luminosity or
    /// tilt change (the star itself is drawn previewed) and for a target out of the level's range.
    public static func ghostStars(_ snapshot: BinaryGardensSceneSnapshot)
        -> [(star: Int, centre: SIMD3<Double>, radius: Double, refused: Bool)] {
        guard let preview = snapshot.preview else { return [] }
        let refused: Bool = preview.refusal != nil
        let s: BinaryGardensSceneSnapshot = snapshot
        let t: Int = s.shownTick
        let rings: [Int] = s.arrangement.rings
        func ringRadius(_ star: Int) -> Int? {
            guard rings.indices.contains(star), s.ringRadii.indices.contains(rings[star]) else { return nil }
            return s.ringRadii[rings[star]]
        }
        switch preview.change {
        case .ring(let star, let index):
            guard (0..<2).contains(star), s.ringRadii.indices.contains(index) else { return [] }
            let centre: SIMD3<Double> = ringVertex(radius: s.ringRadii[index], step: s.starStep(star, tick: t),
                                                   tilt: s.arrangement.tilt, scale: s.fitScale)
            return [(star: star, centre: centre, radius: starRadius(star, s), refused: refused)]
        case .phase(let star, let step):
            guard (0..<2).contains(star), (0..<BinaryGardensSky.cycle).contains(step),
                  let radius = ringRadius(star) else { return [] }
            let drawnStep: Int = BinaryGardensSky.phase(step, speed: s.starSpeed, tick: t)
            let centre: SIMD3<Double> = ringVertex(radius: radius, step: drawnStep, tilt: s.arrangement.tilt,
                                                   scale: s.fitScale)
            return [(star: star, centre: centre, radius: starRadius(star, s), refused: refused)]
        case .luminosity(let star, let index):
            guard refused, (0..<2).contains(star), s.luminosityLevels.indices.contains(index) else { return [] }
            return [(star: star, centre: starCentre(star, s), radius: starRadius(luminosityIndex: index),
                     refused: true)]
        case .tilt(let step):
            guard refused, (0...max(s.maxTilt, 0)).contains(step) else { return [] }
            var ghosts: [(star: Int, centre: SIMD3<Double>, radius: Double, refused: Bool)] = []
            for star in 0..<2 {
                guard let radius = ringRadius(star) else { continue }
                let centre: SIMD3<Double> = ringVertex(radius: radius, step: s.starStep(star, tick: t), tilt: step,
                                                       scale: s.fitScale)
                ghosts.append((star: star, centre: centre, radius: starRadius(star, s), refused: true))
            }
            return ghosts
        case .run:
            return []
        }
    }

    /// The ghost cells of world `world`'s committed light `committed` (feature 504): per tick 1 … 48 its committed
    /// cell's outline as four strips ``ghostCellWidth`` wide inside the cell's rectangle (bottom, top, left, right) and
    /// the value of the committed band (its index in `BinaryGardensBand.allCases`, lethal low 0 … lethal high 4, over
    /// 4), which selects its colour.
    public static func ghostCells(_ committed: BinaryGardensSceneWorld, world: Int)
        -> [(value: Double, strips: [(left: Double, right: Double, low: Double, high: Double)])] {
        let base: Double = baseline(world)
        let cellHalf: Double = barFill * cellPitch / 2
        let w: Double = ghostCellWidth
        let bands: [BinaryGardensBand] = BinaryGardensBand.allCases
        var cells: [(value: Double, strips: [(left: Double, right: Double, low: Double, high: Double)])] = []
        for tick in 1...BinaryGardensSky.cycle {
            let index: Int = tick - 1
            let flux: Int = index < committed.flux.count ? committed.flux[index] : 0
            let band: BinaryGardensBand = index < committed.bands.count ? committed.bands[index] : .comfortable
            let top: Double = base + cellHeight(flux: flux, lethalHigh: committed.lethalHigh)
            let x: Double = cellX(tick)
            let left: Double = x - cellHalf
            let right: Double = x + cellHalf
            let strips: [(left: Double, right: Double, low: Double, high: Double)] = [
                (left: left, right: right, low: base, high: base + w),
                (left: left, right: right, low: top - w, high: top),
                (left: left, right: left + w, low: base, high: top),
                (left: right - w, right: right, low: base, high: top),
            ]
            let value: Double = Double(bands.firstIndex(of: band) ?? 2) / Double(bands.count - 1)
            cells.append((value: value, strips: strips))
        }
        return cells
    }

    // MARK: Elements

    /// Every element with its centre, in drawing order (research R4), seen from the authored eye. The same for every
    /// tier.
    public static func paintOrder(_ snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensElement] {
        paintOrder(snapshot, eye: eye)
    }

    /// Every element with its centre, in drawing order, seen from `viewer` (feature 504): the bodies sorted back to front
    /// by their distance from `viewer` (ties: worlds before stars, then index), the backdrop behind the box on its view
    /// axis. Equal to ``paintOrder(_:)`` for the authored eye.
    public static func paintOrder(_ snapshot: BinaryGardensSceneSnapshot,
                                  eye viewer: SIMD3<Double>) -> [BinaryGardensElement] {
        typealias E = BinaryGardensElement
        let origin: SIMD3<Double> = SIMD3(0, 0, 0)
        var list: [E] = [E(kind: .backdrop, index: 0, item: 0, centre: backdropCentre(eye: viewer))]
        if snapshot.maxTilt > 0 {
            list.append(E(kind: .tiltDial, index: 0, item: 0, centre: tiltPipCentre(snapshot.maxTilt / 2)))
        }
        for ring in snapshot.ringRadii.indices { list.append(E(kind: .ring, index: ring, item: ring, centre: origin)) }
        for world in snapshot.worlds.indices {
            list.append(E(kind: .orbit, index: world, item: world, centre: origin))
        }
        list.append(E(kind: .trail, index: 0, item: 0, centre: origin))
        for world in snapshot.worlds.indices {
            list.append(E(kind: .world, index: world, item: world, centre: worldCentre(world, snapshot)))
        }
        for star in 0..<2 { list.append(E(kind: .star, index: star, item: star, centre: starCentre(star, snapshot))) }
        for world in snapshot.worlds.indices {
            list.append(E(kind: .gauge, index: world, item: world,
                          centre: SIMD3((plateLeft + plateRight) / 2, gaugeY(world), 0)))
        }
        for bar in 0..<max(snapshot.budget, 0) {
            list.append(E(kind: .actions, index: bar, item: bar, centre: actionsBar(bar, snapshot)))
        }
        var glow: Int = 0
        for star in 0..<2 {
            list.append(E(kind: .glow, index: glow, item: star, centre: starCentre(star, snapshot)))
            glow += 1
        }
        for world in snapshot.worlds.indices {
            list.append(E(kind: .glow, index: glow, item: 2 + world, centre: worldCentre(world, snapshot)))
            glow += 1
        }
        list.sort { E.drawsBefore($0, $1, eye: viewer) }
        return list
    }

    /// The CPU reference points (clarification Q3): the barycentre, every world's centre, both stars' centres, the
    /// first gauge plate's left margin (when the level has worlds) and the first actions bar (when it has a budget).
    public static func referencePoints(_ snapshot: BinaryGardensSceneSnapshot) -> [BinaryGardensReferencePoint] {
        typealias R = BinaryGardensReferencePoint
        var points: [R] = [R(kind: .barycentre, index: 0, centre: SIMD3(0, 0, 0))]
        for world in snapshot.worlds.indices {
            points.append(R(kind: .world, index: world, centre: worldCentre(world, snapshot)))
        }
        for star in 0..<2 { points.append(R(kind: .star, index: star, centre: starCentre(star, snapshot))) }
        if !snapshot.worlds.isEmpty { points.append(R(kind: .gaugeMargin, index: 0, centre: gaugeMargin(0))) }
        if snapshot.budget > 0 { points.append(R(kind: .actionsBar, index: 0, centre: actionsBar(0, snapshot))) }
        return points
    }

    // MARK: Cube-sphere

    /// The unit cube-sphere of `faceQuads` quads per face edge (at least 1): six faces (+x, −x, +y, −y, +z, −z) of
    /// (n + 1)² vertices each, every cube vertex normalised onto the unit sphere (its normal equals its position), and
    /// 2 n² triangles per face wound counter-clockwise seen from outside.
    public static func cubeSphere(faceQuads: Int) -> (positions: [SIMD3<Double>], normals: [SIMD3<Double>],
                                                     triangles: [SIMD3<Int>]) {
        let n: Int = max(faceQuads, 1)
        var positions: [SIMD3<Double>] = []
        var triangles: [SIMD3<Int>] = []
        for face in cubeFaces {
            let first: Int = positions.count
            for j in 0...n {
                for i in 0...n {
                    let a: Double = -1 + 2 * Double(i) / Double(n)
                    let b: Double = -1 + 2 * Double(j) / Double(n)
                    positions.append(unit(face.normal + face.u * a + face.v * b))
                }
            }
            for j in 0..<n {
                for i in 0..<n {
                    let p00: Int = first + j * (n + 1) + i
                    let p10: Int = p00 + 1
                    let p01: Int = p00 + n + 1
                    let p11: Int = p01 + 1
                    triangles.append(SIMD3(p00, p10, p11))
                    triangles.append(SIMD3(p00, p11, p01))
                }
            }
        }
        return (positions: positions, normals: positions, triangles: triangles)
    }

    /// The six cube faces as (outward normal, u axis, v axis) with u × v = normal.
    static let cubeFaces: [(normal: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>)] = [
        (normal: SIMD3(1, 0, 0), u: SIMD3(0, 1, 0), v: SIMD3(0, 0, 1)),
        (normal: SIMD3(-1, 0, 0), u: SIMD3(0, 0, 1), v: SIMD3(0, 1, 0)),
        (normal: SIMD3(0, 1, 0), u: SIMD3(0, 0, 1), v: SIMD3(1, 0, 0)),
        (normal: SIMD3(0, -1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1)),
        (normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0)),
        (normal: SIMD3(0, 0, -1), u: SIMD3(0, 1, 0), v: SIMD3(1, 0, 0)),
    ]

    // MARK: Meshes

    /// The system mesh for the system program, in drawing order (see the header), seen from the authored camera.
    public static func systemMesh(_ snapshot: BinaryGardensSceneSnapshot,
                                  tier: BinaryGardensTier) throws(MeshError) -> Mesh {
        try systemPart(snapshot, tier: tier).mesh
    }

    /// The system mesh seen from `camera` (feature 504): every eye-facing part facing its eye, the bodies sorted back to
    /// front from it and the backdrop behind the box on its view axis (``systemPart(_:tier:wonLevel:camera:)`` without
    /// colours); equal to ``systemMesh(_:tier:)`` for a camera at the authored eye.
    public static func systemMesh(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                  camera: BinaryGardensCamera) throws(MeshError) -> Mesh {
        try systemPart(snapshot, tier: tier, camera: camera).mesh
    }

    /// The glow mesh for the glow program (``glowPart(_:tier:wonLevel:)`` without colours); empty at level-2. Seen
    /// from the authored camera.
    public static func glowMesh(_ snapshot: BinaryGardensSceneSnapshot,
                                tier: BinaryGardensTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    /// The glow mesh seen from `camera` (feature 504): every shell facing its eye (``glowPart(_:tier:wonLevel:camera:)``
    /// without colours); empty at level-2; equal to ``glowMesh(_:tier:)`` for a camera at the authored eye.
    public static func glowMesh(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                camera: BinaryGardensCamera) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier, camera: camera).mesh
    }

    /// The whole system with fallback colours for the shared unlit renderer: each vertex in its fallback colour
    /// (``colour(of:won:)``: worlds tinted by their band, broken parts in the broken colour, a shared ring's dashes
    /// and a corona ray in their star's colour), the backdrop from space at its bottom to space top at its top. The
    /// mesh is ``systemMesh(_:tier:)``; `wonLevel` (default `snapshot.isWon`) changes only the colours. Seen from the
    /// authored camera; the preview, the ghosts and the inspection marks as in the header (feature 504).
    public static func systemPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                  wonLevel: Bool? = nil) throws(MeshError) -> BinaryGardensColouredMesh {
        try system(snapshot, tier: tier, wonLevel: wonLevel, parts: Parts())
    }

    /// The whole system with fallback colours seen from `camera` (feature 504): every eye-facing part facing its eye,
    /// the bodies sorted back to front from it and the backdrop perpendicular to its view axis behind the box; otherwise
    /// as ``systemPart(_:tier:wonLevel:)``, which it equals for a camera at the authored eye.
    public static func systemPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                  wonLevel: Bool? = nil,
                                  camera: BinaryGardensCamera) throws(MeshError) -> BinaryGardensColouredMesh {
        try system(snapshot, tier: tier, wonLevel: wonLevel, parts: Parts(camera: camera))
    }

    /// Builds the system into `parts` (empty, with the eye to face): every element of the drawn snapshot
    /// (``drawnSnapshot(_:)``) in drawing order from the parts' eye but the glow, with the ghost stars of `snapshot`'s
    /// preview, the ghost bands of an accepted preview and the inspection marks (see the header).
    static func system(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier, wonLevel: Bool?,
                       parts start: Parts) throws(MeshError) -> BinaryGardensColouredMesh {
        var parts: Parts = start
        parts.won = (wonLevel ?? snapshot.isWon) ? 1 : 0
        let drawn: BinaryGardensSceneSnapshot = drawnSnapshot(snapshot)
        let extras: Extras = Extras(ghosts: ghostStars(snapshot),
                                    committed: snapshot.preview?.report == nil ? nil : snapshot.worlds)
        for element in paintOrder(drawn, eye: parts.eye) where element.kind != .glow {
            try draw(element, into: &parts, drawn, tier: tier, extras: extras)
        }
        return parts.built()
    }

    /// What feature 504 adds to the elements: the ghost stars (drawn in their star's element) and, for an accepted
    /// preview, the committed worlds whose cells the ghost bands outline.
    struct Extras {
        /// The ghost stars (``ghostStars(_:)``).
        var ghosts: [(star: Int, centre: SIMD3<Double>, radius: Double, refused: Bool)] = []
        /// The committed worlds behind an accepted preview; nil without one.
        var committed: [BinaryGardensSceneWorld]? = nil
    }

    /// Draws one element into `parts` (see the header), with feature 504's `extras`.
    static func draw(_ element: BinaryGardensElement, into parts: inout Parts, _ snapshot: BinaryGardensSceneSnapshot,
                     tier: BinaryGardensTier, extras: Extras = Extras()) throws(MeshError) {
        let i: Int = element.item
        switch element.kind {
        case .backdrop:
            try backdrop(&parts)
        case .tiltDial:
            for step in 0...max(snapshot.maxTilt, 0) {
                let material: BinaryGardensMaterial = step == snapshot.arrangement.tilt ? .tiltPipLit : .tiltPipUnlit
                try parts.billboardQuad(centre: tiltPipCentre(step), half: tiltPipRadius, code: code(material), w: 0)
            }
        case .ring:
            try ring(&parts, i, snapshot)
        case .orbit:
            guard snapshot.worlds.indices.contains(i) else { return }
            let radius: Int = snapshot.worlds[i].radius
            for step in 0..<BinaryGardensSky.cycle {
                try parts.segment(orbitVertex(radius: radius, step: step, scale: snapshot.fitScale),
                                  orbitVertex(radius: radius, step: step + 1, scale: snapshot.fitScale),
                                  width: orbitWidth, code: code(.orbit))
            }
        case .trail:
            try trails(&parts, snapshot, tier: tier)
        case .world:
            try world(&parts, i, snapshot, tier: tier)
        case .star:
            try star(&parts, i, snapshot, tier: tier)
            for ghost in extras.ghosts where ghost.star == i {
                try parts.billboardQuad(centre: ghost.centre, half: ghost.radius,
                                        code: code(.ghostStar, broken: ghost.refused), w: Double(ghost.star))
            }
        case .gauge:
            var committed: BinaryGardensSceneWorld? = nil
            if let worlds = extras.committed, worlds.indices.contains(i) { committed = worlds[i] }
            try gauge(&parts, i, snapshot, committed: committed)
        case .actions:
            let half: SIMD2<Double> = SIMD2(barFill * actionsSlot(snapshot) / 2, actionsHeight / 2)
            let material: BinaryGardensMaterial = i < litActions(snapshot) ? .actionsLit : .actionsUnlit
            try parts.flatQuad(centre: element.centre, half: half, code: code(material))
        case .glow:
            return
        }
    }

    /// Draws the backdrop: a quad on the view axis at ``backdropDistance``, perpendicular to it (a_normal its plane
    /// offsets, a_uv.y the height); seen from an orbit camera (feature 504), on its view axis at
    /// ``facingBackdropDistance(eye:)`` with ``backdropHalf()`` scaled by that distance over ``backdropDistance`` (the
    /// orbit cameras keep the authored field of view, so it fills the view at aspects 0.25 … 4).
    static func backdrop(_ parts: inout Parts) throws(MeshError) {
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) =
            parts.camera.map { viewBasis($0) } ?? viewBasis()
        let distance: Double = facingBackdropDistance(eye: parts.eye)
        let half: SIMD2<Double> = parts.camera == nil ? backdropHalf() : backdropHalf() * (distance / backdropDistance)
        let c: SIMD3<Double> = parts.camera == nil ? backdropCentre() : parts.eye + basis.forward * distance
        let w: SIMD3<Double> = basis.right * half.x
        let h: SIMD3<Double> = basis.up * half.y
        let low: SIMD3<Double> = BinaryGardensShaders.backdropColour(height: 0)
        let high: SIMD3<Double> = BinaryGardensShaders.backdropColour(height: 1)
        let offsets: [SIMD3<Double>] = [SIMD3(-half.x, -half.y, 0), SIMD3(half.x, -half.y, 0),
                                        SIMD3(half.x, half.y, 0), SIMD3(-half.x, half.y, 0)]
        try parts.quad([c - w - h, c + w - h, c + w + h, c - w + h], code: code(.backdrop), local: [0, 0, 1, 1],
                       colours: [low, low, high, high], normals: offsets, facing: -basis.forward)
    }

    /// The material of ring `ring`'s segments and whether it is dashed: idle (dashed) when no star stands on it, a
    /// star's colour when one does, shared when both do.
    public static func ringMaterial(_ ring: Int, _ snapshot: BinaryGardensSceneSnapshot)
        -> (material: BinaryGardensMaterial, dashed: Bool) {
        let rings: [Int] = snapshot.arrangement.rings
        let one: Bool = rings.count > 0 && rings[0] == ring
        let two: Bool = rings.count > 1 && rings[1] == ring
        switch (one, two) {
        case (true, true): return (.ringShared, false)
        case (true, false): return (.ringStarOne, false)
        case (false, true): return (.ringStarTwo, false)
        case (false, false): return (.ringIdle, true)
        }
    }

    /// Draws ring `ring`: its 48 segments at the current tilt (the even ones only when dashed).
    static func ring(_ parts: inout Parts, _ ring: Int, _ snapshot: BinaryGardensSceneSnapshot) throws(MeshError) {
        guard snapshot.ringRadii.indices.contains(ring) else { return }
        let radius: Int = snapshot.ringRadii[ring]
        let tilt: Int = snapshot.arrangement.tilt
        let style: (material: BinaryGardensMaterial, dashed: Bool) = ringMaterial(ring, snapshot)
        let width: Double = style.dashed ? ringWidth : starRingWidth
        for step in 0..<BinaryGardensSky.cycle where !style.dashed || step % 2 == 0 {
            let parity: Double = style.material == .ringShared ? Double(step % 2) : 0
            let tint: SIMD3<Double> = BinaryGardensShaders.baseColour(of: style.material, value: 0, broken: false,
                                                                      won: 0, shape: parity)
            try parts.segment(ringVertex(radius: radius, step: step, tilt: tilt, scale: snapshot.fitScale),
                              ringVertex(radius: radius, step: step + 1, tilt: tilt, scale: snapshot.fitScale),
                              width: width, code: code(style.material), w: parity, colour: tint)
        }
    }

    /// The trail dots in drawing order: per trail tick (newest first) every star's then every world's kernel position
    /// at that tick, with its freshness 1 − age / (n + 1); empty at a tier without trails.
    public static func trailDots(_ snapshot: BinaryGardensSceneSnapshot,
                                 tier: BinaryGardensTier) -> [(centre: SIMD3<Double>, freshness: Double)] {
        let ticks: [Int] = trailTicks(shownTick: snapshot.shownTick, count: tier.trailTicks)
        var dots: [(centre: SIMD3<Double>, freshness: Double)] = []
        for (age, tick) in ticks.enumerated() {
            let freshness: Double = 1 - Double(age + 1) / Double(ticks.count + 1)
            for star in 0..<2 {
                dots.append((position(snapshot.starPoint(star, tick: tick), scale: snapshot.fitScale), freshness))
            }
            for world in snapshot.worlds.indices {
                dots.append((position(snapshot.worldPoint(world, tick: tick), scale: snapshot.fitScale), freshness))
            }
        }
        return dots
    }

    /// Draws the trails.
    static func trails(_ parts: inout Parts, _ snapshot: BinaryGardensSceneSnapshot,
                       tier: BinaryGardensTier) throws(MeshError) {
        for dot in trailDots(snapshot, tier: tier) {
            try parts.billboardQuad(centre: dot.centre, half: trailRadius, code: code(.trail, value: dot.freshness),
                                    w: 0)
        }
    }

    /// The centre of pip `index` of `count` pips standing `drop` below `centre` in the plane facing `viewer`, 0.022
    /// apart.
    static func pipCentre(_ index: Int, of count: Int, below centre: SIMD3<Double>, drop: Double,
                          eye viewer: SIMD3<Double> = eye) -> SIMD3<Double> {
        let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) = billboardBasis(centre, eye: viewer)
        let offset: Double = (Double(index) - Double(count - 1) / 2) * pipStep
        return centre - b.up * drop + b.right * offset
    }

    /// World `world`'s pip centres (j + 1 of them), facing the authored eye.
    public static func worldPips(_ world: Int, _ snapshot: BinaryGardensSceneSnapshot) -> [SIMD3<Double>] {
        worldPips(world, snapshot, eye: eye)
    }

    /// World `world`'s pip centres in the plane facing `viewer` (feature 504).
    public static func worldPips(_ world: Int, _ snapshot: BinaryGardensSceneSnapshot,
                                 eye viewer: SIMD3<Double>) -> [SIMD3<Double>] {
        let centre: SIMD3<Double> = worldCentre(world, snapshot)
        var pips: [SIMD3<Double>] = []
        for k in 0...max(world, 0) {
            pips.append(pipCentre(k, of: world + 1, below: centre, drop: worldPipDrop, eye: viewer))
        }
        return pips
    }

    /// Star `star`'s luminosity pip centres with their lit flags: one per luminosity level, lit up to its current one;
    /// facing the authored eye.
    public static func luminosityPips(_ star: Int,
                                      _ snapshot: BinaryGardensSceneSnapshot) -> [(centre: SIMD3<Double>, lit: Bool)] {
        luminosityPips(star, snapshot, eye: eye)
    }

    /// Star `star`'s luminosity pip centres with their lit flags in the plane facing `viewer` (feature 504; the picker
    /// reads the drawn eye's).
    public static func luminosityPips(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot,
                                      eye viewer: SIMD3<Double>) -> [(centre: SIMD3<Double>, lit: Bool)] {
        let centre: SIMD3<Double> = starCentre(star, snapshot)
        let count: Int = snapshot.luminosityLevels.count
        let lums: [Int] = snapshot.arrangement.luminosities
        let current: Int = lums.indices.contains(star) ? lums[star] : 0
        let drop: Double = starRadius(star, snapshot) + starPipGap
        var pips: [(centre: SIMD3<Double>, lit: Bool)] = []
        for k in 0..<count {
            pips.append((pipCentre(k, of: count, below: centre, drop: drop, eye: viewer), k <= current))
        }
        return pips
    }

    /// The motes of world `world`: `tier.motes` motes k, each placed one ``BinaryGardensShaders/moteLoopRadius`` to
    /// +x of the world's centre (where the vertex shader's loop starts) with phase k / n; empty unless the world blooms
    /// (``blooms(_:_:won:)``).
    public static func motes(_ world: Int, _ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                             won: Bool) -> [(centre: SIMD3<Double>, phase: Double)] {
        let n: Int = max(tier.motes, 0)
        guard n > 0, blooms(world, snapshot, won: won) else { return [] }
        let start: SIMD3<Double> = worldCentre(world, snapshot) + SIMD3(BinaryGardensShaders.moteLoopRadius, 0, 0)
        var points: [(centre: SIMD3<Double>, phase: Double)] = []
        for k in 0..<n { points.append((centre: start, phase: Double(k) / Double(n))) }
        return points
    }

    /// Draws world `world`: its cube-sphere (quads far-first from the eye), its pips, its broken ring and its motes.
    static func world(_ parts: inout Parts, _ world: Int, _ snapshot: BinaryGardensSceneSnapshot,
                      tier: BinaryGardensTier) throws(MeshError) {
        guard snapshot.worlds.indices.contains(world) else { return }
        let centre: SIMD3<Double> = worldCentre(world, snapshot)
        let material: BinaryGardensMaterial = BinaryGardensMaterial.world(snapshot.band(world))
        let x: Double = code(material, value: BinaryGardensShaders.shareValue(snapshot.share(world, star: 0)))
        let y: Double = BinaryGardensShaders.shareValue(snapshot.share(world, star: 1))
        let sphere = cubeSphere(faceQuads: tier.faceQuads)
        var quads: [(distance: Double, first: Int)] = []
        var t: Int = 0
        while t + 1 < sphere.triangles.count {
            let tri: SIMD3<Int> = sphere.triangles[t]
            let other: SIMD3<Int> = sphere.triangles[t + 1]
            let mid: SIMD3<Double> = (sphere.positions[tri.x] + sphere.positions[tri.y] + sphere.positions[tri.z]
                                      + sphere.positions[other.z]) / 4
            quads.append((distance: length(centre + mid * worldRadius - parts.eye), first: t))
            t += 2
        }
        quads.sort { $0.distance != $1.distance ? $0.distance > $1.distance : $0.first < $1.first }
        for quad in quads {
            for triangle in [sphere.triangles[quad.first], sphere.triangles[quad.first + 1]] {
                var ids: [UInt32] = []
                var points: [SIMD3<Double>] = []
                for index in [triangle.x, triangle.y, triangle.z] {
                    let n: SIMD3<Double> = sphere.normals[index]
                    let p: SIMD3<Double> = centre + sphere.positions[index] * worldRadius
                    ids.append(try parts.vertex(p, slot: n, code: x, local: y))
                    points.append(p)
                }
                let facing: SIMD3<Double> = sphere.normals[triangle.x] + sphere.normals[triangle.y]
                    + sphere.normals[triangle.z]
                try parts.triangle((ids[0], ids[1], ids[2]), points[0], points[1], points[2], facing: facing)
            }
        }
        for pip in worldPips(world, snapshot, eye: parts.eye) {
            try parts.billboardQuad(centre: pip, half: pipRadius, code: code(.worldPip), w: 0)
        }
        if lethalMark(snapshot)?.world == world {
            try parts.billboardQuad(centre: centre, half: brokenRingRadius, code: code(.brokenRing, broken: true),
                                    w: 0)
        }
        if snapshot.inspectedWorld == world {
            try parts.billboardQuad(centre: centre, half: inspectRingRadius, code: code(.inspectRing), w: 0)
        }
        let radius: Double = BinaryGardensShaders.moteLoopRadius
        for mote in motes(world, snapshot, tier: tier, won: snapshot.isWon) {
            try parts.billboardQuad(centre: mote.centre, half: moteRadius, code: code(.mote, value: mote.phase),
                                    w: radius)
        }
    }

    /// Star `star`'s corona rays: `tier.coronaRays` rays k at angle 2π k / n in the eye-facing plane, each as
    /// (centre, along (unit, root → tip), across (unit), half (across, along), phase k / n); facing the authored eye.
    public static func coronaRays(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier)
        -> [(centre: SIMD3<Double>, along: SIMD3<Double>, across: SIMD3<Double>, half: SIMD2<Double>,
             phase: Double)] {
        coronaRays(star, snapshot, tier: tier, eye: eye)
    }

    /// Star `star`'s corona rays in the plane facing `viewer` (feature 504).
    public static func coronaRays(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                  eye viewer: SIMD3<Double>)
        -> [(centre: SIMD3<Double>, along: SIMD3<Double>, across: SIMD3<Double>, half: SIMD2<Double>,
             phase: Double)] {
        let n: Int = max(tier.coronaRays, 0)
        let centre: SIMD3<Double> = starCentre(star, snapshot)
        let r: Double = starRadius(star, snapshot)
        let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) = billboardBasis(centre, eye: viewer)
        var rays: [(centre: SIMD3<Double>, along: SIMD3<Double>, across: SIMD3<Double>, half: SIMD2<Double>,
                    phase: Double)] = []
        for k in 0..<n {
            let a: Double = 2 * Double.pi * Double(k) / Double(n)
            let along: SIMD3<Double> = b.right * cos(a) + b.up * sin(a)
            let across: SIMD3<Double> = cross(b.facing, along)
            let middle: SIMD3<Double> = centre + along * (r * (coronaRoot + coronaTip) / 2)
            rays.append((middle, along, across, SIMD2(r * coronaHalfWidth, r * (coronaTip - coronaRoot) / 2),
                         Double(k) / Double(n)))
        }
        return rays
    }

    /// Draws star `star`: its corona rays, its disc and its luminosity pips.
    static func star(_ parts: inout Parts, _ star: Int, _ snapshot: BinaryGardensSceneSnapshot,
                     tier: BinaryGardensTier) throws(MeshError) {
        let centre: SIMD3<Double> = starCentre(star, snapshot)
        let colour: SIMD3<Double> = star == 0 ? BinaryGardensPalette.starOne : BinaryGardensPalette.starTwo
        for ray in coronaRays(star, snapshot, tier: tier, eye: parts.eye) {
            try parts.shapeQuad(centre: ray.centre, u: ray.across, v: ray.along, half: ray.half,
                                code: code(.corona, value: ray.phase), w: Double(star), colour: colour)
        }
        let disc: BinaryGardensMaterial = star == 0 ? .starOne : .starTwo
        try parts.billboardQuad(centre: centre, half: starRadius(star, snapshot), code: code(disc), w: 0)
        for pip in luminosityPips(star, snapshot, eye: parts.eye) {
            try parts.billboardQuad(centre: pip.centre, half: pipRadius,
                                    code: code(pip.lit ? .luminosityPipLit : .luminosityPipUnlit), w: 0)
        }
    }

    /// Draws world `world`'s gauge row (see the header): with `committed` (an accepted preview's committed world,
    /// feature 504) its cells' outlines right after the plate, behind the previewed cells; the inspection brackets last
    /// when the world is inspected.
    static func gauge(_ parts: inout Parts, _ world: Int, _ snapshot: BinaryGardensSceneSnapshot,
                      committed: BinaryGardensSceneWorld? = nil) throws(MeshError) {
        let y: Double = gaugeY(world)
        try parts.plate(left: plateLeft, right: plateRight, low: y - plateHalf, high: y + plateHalf,
                        code: code(.gaugePlate))
        guard snapshot.worlds.indices.contains(world) else { return }
        let entry: BinaryGardensSceneWorld = snapshot.worlds[world]
        let base: Double = baseline(world)
        let lethal: (world: Int, column: Int)? = lethalMark(snapshot)
        let cellHalf: Double = barFill * cellPitch / 2
        if let ghost = committed {
            for cell in ghostCells(ghost, world: world) {
                for strip in cell.strips {
                    try parts.span(left: strip.left, right: strip.right, low: strip.low, high: strip.high,
                                   code: code(.ghostCell, value: cell.value))
                }
            }
        }
        for tick in 1...BinaryGardensSky.cycle {
            let index: Int = tick - 1
            let flux: Int = index < entry.flux.count ? entry.flux[index] : 0
            let band: BinaryGardensBand = index < entry.bands.count ? entry.bands[index] : .comfortable
            let height: Double = cellHeight(flux: flux, lethalHigh: entry.lethalHigh)
            let share: Double = BinaryGardensShaders.heightShare(flux: flux, lethalHigh: entry.lethalHigh)
            let broken: Bool = lethal?.world == world && lethal?.column == tick
            let x: Double = cellX(tick)
            try parts.span(left: x - cellHalf, right: x + cellHalf, low: base, high: base + height,
                           code: code(BinaryGardensMaterial.cell(band), value: share, broken: broken))
        }
        for bound in [entry.comfortLow, entry.comfortHigh] {
            let level: Double = base + cellHeight(flux: bound, lethalHigh: entry.lethalHigh)
            try parts.span(left: cellsStart, right: cellsEnd, low: level - guideHeight / 2,
                           high: level + guideHeight / 2, code: code(.guide))
        }
        let unstable: Bool = unstableWorld(snapshot) == world
        let short: Bool = entry.longestWindow < entry.window
        for piece in windowPieces(entry) {
            let left: Double = cellsStart + Double(piece.first - 1) * cellPitch
            let right: Double = cellsStart + Double(piece.last) * cellPitch
            try parts.span(left: left, right: right, low: y - bracketLow, high: y - bracketHigh,
                           code: code(short ? .windowBracketShort : .windowBracket, broken: unstable))
        }
        let requiredBroken: Bool = unstable && windowPieces(entry).isEmpty
        let rx: Double = requiredX(entry)
        try parts.span(left: rx - requiredWidth / 2, right: rx + requiredWidth / 2, low: y - requiredLow,
                       high: y - requiredHigh, code: code(.requiredTick, broken: requiredBroken))
        try parts.flatQuad(centre: SIMD3(cellX(snapshot.shownTick), y + markerRise, 0),
                           half: SIMD2(markerRadius, markerRadius), code: code(.tickMarker))
        try parts.span(left: bloomStart, right: bloomEnd, low: y - bloomTrackHeight / 2, high: y + bloomTrackHeight / 2,
                       code: code(.bloomTrack))
        let low: Double = bloomX(entry.bloomLow, bloomHigh: entry.bloomHigh)
        let high: Double = bloomX(max(entry.bloomHigh, entry.bloomLow), bloomHigh: entry.bloomHigh)
        let halfWidth: Double = max((high - low) / 2, bloomBracketMinimum)
        try parts.flatQuad(centre: SIMD3((low + high) / 2, y, 0), half: SIMD2(halfWidth, bloomBracketHalf),
                           code: code(.bloomBracket))
        let marker: Int = min(entry.integral, 2 * entry.bloomHigh)
        try parts.flatQuad(centre: SIMD3(bloomX(marker, bloomHigh: entry.bloomHigh), y, 0),
                           half: SIMD2(bloomMarkerRadius, bloomMarkerRadius),
                           code: code(.bloomMarker, broken: bloomWorld(snapshot) == world))
        if snapshot.inspectedWorld == world {
            for x in [bracketLeft, bracketRight] {
                try parts.span(left: x - bracketWidth / 2, right: x + bracketWidth / 2, low: y - bracketHalf,
                               high: y + bracketHalf, code: code(.inspectBracket))
            }
        }
    }

    /// The glow with fallback colours (a star's colour; the world colour times its factor, or 1 on a won level) for
    /// the shared unlit renderer: `tier.glowShells` shells k (outermost first), each an annulus of ``glowSides``
    /// sides facing the eye — around every star from 0.9 r to r + 0.04 · k (kind star, a_normal its colour, factor 1)
    /// and around every world from 0.06 to 0.07 + 0.035 · k (kind world, a_normal zero, factor
    /// ``BinaryGardensShaders/glowFactor(blooming:)`` of its band at the shown tick). a_uv.y 0 inside and 1 outside.
    /// Empty at level-2. `wonLevel` (default `snapshot.isWon`) changes only the colours.
    public static func glowPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                wonLevel: Bool? = nil) throws(MeshError) -> BinaryGardensColouredMesh {
        try glow(snapshot, tier: tier, wonLevel: wonLevel, parts: Parts())
    }

    /// The glow with fallback colours seen from `camera` (feature 504): every shell facing its eye; otherwise as
    /// ``glowPart(_:tier:wonLevel:)``, which it equals for a camera at the authored eye. Drawn from
    /// ``drawnSnapshot(_:)`` (the previewed light while an accepted preview is drawn).
    public static func glowPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                wonLevel: Bool? = nil,
                                camera: BinaryGardensCamera) throws(MeshError) -> BinaryGardensColouredMesh {
        try glow(snapshot, tier: tier, wonLevel: wonLevel, parts: Parts(camera: camera))
    }

    /// Builds the glow into `parts` (empty, with the eye to face; see ``glowPart(_:tier:wonLevel:)``) from the drawn
    /// snapshot (``drawnSnapshot(_:)``).
    static func glow(_ source: BinaryGardensSceneSnapshot, tier: BinaryGardensTier, wonLevel: Bool?,
                     parts start: Parts) throws(MeshError) -> BinaryGardensColouredMesh {
        typealias K = BinaryGardensShaders.GlowKind
        var parts: Parts = start
        let snapshot: BinaryGardensSceneSnapshot = drawnSnapshot(source)
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let won: Bool = wonLevel ?? source.isWon
        for k in stride(from: shells, through: 1, by: -1) {
            for star in 0..<2 {
                let r: Double = starRadius(star, snapshot)
                let colour: SIMD3<Double> = star == 0 ? BinaryGardensPalette.starOne : BinaryGardensPalette.starTwo
                try parts.glowBand(centre: starCentre(star, snapshot), inner: starGlowInner * r,
                                   outer: r + starGlowGrowth * Double(k), code: K.star.code(factor: 1),
                                   slot: colour, colour: colour)
            }
            for world in snapshot.worlds.indices {
                let factor: Double = BinaryGardensShaders.glowFactor(blooming: blooms(world, snapshot, won: false))
                try parts.glowBand(centre: worldCentre(world, snapshot), inner: worldGlowInner,
                                   outer: worldRadius + worldGlowGrowth * Double(k), code: K.world.code(factor: factor),
                                   slot: SIMD3(0, 0, 0), colour: BinaryGardensPalette.world * (won ? 1 : factor))
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

    /// `camera`'s unit forward, right and up vectors, read from its view matrix (feature 504): for the authored camera
    /// those of ``viewBasis()`` within rounding.
    public static func viewBasis(_ camera: BinaryGardensCamera)
        -> (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) {
        let v: Mat4 = camera.view
        let right: SIMD3<Double> = SIMD3(v.c0.x, v.c1.x, v.c2.x)
        let up: SIMD3<Double> = SIMD3(v.c0.y, v.c1.y, v.c2.y)
        let forward: SIMD3<Double> = SIMD3(-v.c0.z, -v.c1.z, -v.c2.z)
        return (forward: forward, right: right, up: up)
    }

    /// The basis of a part facing the eye at `centre`: right (+z × towards-eye, +x when degenerate), up and the unit
    /// direction towards the eye (right × up).
    static func billboardBasis(_ centre: SIMD3<Double>)
        -> (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) {
        billboardBasis(centre, eye: eye)
    }

    /// The basis of a part at `centre` facing `viewer` (feature 504; ``billboardBasis(_:)`` for the authored eye).
    static func billboardBasis(_ centre: SIMD3<Double>, eye viewer: SIMD3<Double>)
        -> (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) {
        let w: SIMD3<Double> = unit(viewer - centre)
        let raw: SIMD3<Double> = cross(SIMD3(0, 0, 1), w)
        let size: Double = length(raw)
        let right: SIMD3<Double> = size > 1e-9 ? raw / size : SIMD3(1, 0, 0)
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

    /// The fixed camera for `aspect`: from (0, −2.0, 3.2) looking at (0, −0.35, 0) with +y up; the vertical field of
    /// view is the smallest that holds every corner of the box x −1.3 … 1.3, y −1.85 … 1.15, z −0.85 … 0.85 inside the
    /// view with ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it keeps a
    /// margin of at least 5 % for aspect 0.4 … 2.5). Independent of the snapshot, the tier and the time. Equals
    /// ``camera(aspect:orbit:)`` at ``BinaryGardensViewOrbit/authored`` bit for bit (feature 504).
    public static func camera(aspect: Double) -> BinaryGardensCamera {
        camera(aspect: aspect, orbit: .authored)
    }

    /// The camera for `orbit` (clamped, see ``BinaryGardensViewOrbit/clamped()``) and `aspect` (feature 504,
    /// T-R02G2104-002; research R9): the authored frame turned by the orbit (``orbitFrame(_:)``), the authored field of
    /// view for the aspect, and the eye on the turned view axis at the larger of the authored distance (≈ 3.60) and the
    /// distance at which every corner of the authored box lies inside the view with ``refitMargin`` per side, so
    /// everything inside the box keeps a margin of at least 5 % at every orbit and aspect 0.4 … 2.5; the eye stays
    /// outside the box. The target is always the look-at point (the yaw pivot). Near half the nearest corner's depth
    /// (at least 0.001), far past the facing backdrop. At the authored orbit it is the fixed camera of R02-G21-03, bit
    /// for bit. Presentation only; independent of the snapshot, the tier and the time.
    public static func camera(aspect: Double, orbit: BinaryGardensViewOrbit) -> BinaryGardensCamera {
        let o: BinaryGardensViewOrbit = orbit.clamped()
        guard o.yaw != 0 || o.pitch != 0 else { return authoredCamera(aspect: aspect) }
        let a: Double = usableAspect(aspect)
        let fovY: Double = authoredCamera(aspect: a).fovY
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
        let far: Double = max(farthest + 1, backdropDistance) + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eyePoint), target: vec(frame.target), up: vec(up))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return BinaryGardensCamera(eye: eyePoint, target: frame.target, fovY: fovY, aspect: a, near: near, far: far,
                                   view: view, projection: projection, viewProjection: projection * view)
    }

    /// The authored distance from the eye to the look-at point, |(0, −1.65, 3.2)| ≈ 3.60 (feature 504).
    static var authoredDistance: Double {
        let d: SIMD3<Double> = eye - lookAt
        return dot(d, d).squareRoot()
    }

    /// The point the orbit yaws about (feature 504): the authored box centre (0, −0.35, 0), the look-at point.
    static var orbitPivot: SIMD3<Double> { (boxLow + boxHigh) / 2 }

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

    /// The frame of `orbit` (clamped): the look-at point, the unit direction from it back towards the eye and the unit
    /// up direction. The authored frame (look-at (0, −0.35, 0), back along (0, −1.65, 3.2), up ``viewBasis()``'s) is
    /// turned rigidly by −pitch about +x through the look-at point (so a positive pitch raises the eye; the frame never
    /// rolls, even with the eye past the vertical at pitch +35°), then by the yaw about the vertical axis through
    /// ``orbitPivot`` (the look-at point, which therefore stays put).
    static func orbitFrame(_ orbit: BinaryGardensViewOrbit)
        -> (target: SIMD3<Double>, back: SIMD3<Double>, up: SIMD3<Double>) {
        let o: BinaryGardensViewOrbit = orbit.clamped()
        let back0: SIMD3<Double> = unit(eye - lookAt)
        let up0: SIMD3<Double> = viewBasis().up
        let back1: SIMD3<Double> = pitched(back0, -o.pitch)
        let up1: SIMD3<Double> = pitched(up0, -o.pitch)
        let pivot: SIMD3<Double> = SIMD3(orbitPivot.x, orbitPivot.y, 0)
        let target: SIMD3<Double> = pivot + yawed(lookAt - pivot, o.yaw)
        return (target: target, back: unit(yawed(back1, o.yaw)), up: unit(yawed(up1, o.yaw)))
    }

    /// The fixed camera of R02-G21-03 for `aspect` (see ``camera(aspect:)``), unchanged.
    static func authoredCamera(aspect: Double) -> BinaryGardensCamera {
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
        return BinaryGardensCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far, view: view,
                                   projection: projection, viewProjection: projection * view)
    }

    /// The backdrop's half width and half height: large enough to fill the view at its plane for every aspect in
    /// ``backdropAspects`` (5 % over).
    public static func backdropHalf() -> SIMD2<Double> {
        let tall: BinaryGardensCamera = camera(aspect: backdropAspects.lowerBound)
        let wide: BinaryGardensCamera = camera(aspect: backdropAspects.upperBound)
        let tanTall: Double = tan(tall.fovY / 2)
        let tanWide: Double = tan(wide.fovY / 2)
        let halfHeight: Double = backdropDistance * max(tanTall, tanWide) * 1.05
        let halfWidth: Double = backdropDistance * max(tanTall * tall.aspect, tanWide * wide.aspect) * 1.05
        return SIMD2(halfWidth, halfHeight)
    }

    /// The backdrop height h (0 at its bottom, 1 at its top; a_uv.y) seen at view point `view` (0 … 1, y down) through
    /// `camera`: the gradient's coordinate at that pixel (the backdrop is perpendicular to the view axis).
    public static func backdropHeight(view: SIMD2<Double>, camera: BinaryGardensCamera) -> Double {
        let y: Double = (1 - 2 * view.y) * backdropDistance * tan(camera.fovY / 2)
        let half: Double = backdropHalf().y
        return min(max((y + half) / (2 * half), 0), 1)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: BinaryGardensCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
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

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from the side they face.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []
        /// The won light the fallback colours use (0 or 1).
        var won: Double = 0
        /// The eye the eye-facing parts face (feature 504): the authored eye unless an orbit camera is given.
        var eye: SIMD3<Double> = BinaryGardensSceneGeometry.eye
        /// The orbit camera whose view the backdrop faces, nil for the authored camera (feature 504).
        var camera: BinaryGardensCamera? = nil

        /// Parts seen from the authored camera.
        init() {}

        /// Parts seen from `camera` (feature 504): its eye faced; a camera at the authored eye counts as the authored
        /// camera (every orbit camera looks at the look-at point), so its meshes equal the authored ones.
        init(camera: BinaryGardensCamera) {
            if camera.eye != BinaryGardensSceneGeometry.eye {
                eye = camera.eye
                self.camera = camera
            }
        }
        /// The side flats in the base plane face: up, towards the eye.
        static let up: SIMD3<Double> = SIMD3(0, 0, 1)
        /// The zero vector.
        static let zero: SIMD3<Double> = SIMD3(0, 0, 0)

        /// Adds (or welds) a vertex at `p` with a_normal `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour` (default ``BinaryGardensSceneGeometry/colour(of:won:)`` of the code).
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>? = nil) throws(MeshError) -> UInt32 {
            typealias G = BinaryGardensSceneGeometry
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
            let n: SIMD3<Double> = BinaryGardensSceneGeometry.cross(pb - pa, pc - pa)
            let side: Double = BinaryGardensSceneGeometry.dot(n, facing)
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

        /// A quad of shape half `half` around `centre` in the plane of the unit axes `u` and `v` (facing u × v): the
        /// corners at ±``BinaryGardensShaders/quadExtent`` · half, a_normal (±extent, ±extent, `w`), a_uv.y 0, in
        /// `colour` (default the code's).
        mutating func shapeQuad(centre: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>, half: SIMD2<Double>,
                                code: Double, w: Double = 0, colour: SIMD3<Double>? = nil) throws(MeshError) {
            let e: Double = BinaryGardensShaders.quadExtent
            let a: SIMD3<Double> = u * (e * half.x)
            let b: SIMD3<Double> = v * (e * half.y)
            let tints: [SIMD3<Double>]? = colour.map { [$0, $0, $0, $0] }
            try quad([centre - a - b, centre + a - b, centre + a + b, centre - a + b], code: code, local: [0, 0, 0, 0],
                     colours: tints,
                     normals: [SIMD3(-e, -e, w), SIMD3(e, -e, w), SIMD3(e, e, w), SIMD3(-e, e, w)],
                     facing: BinaryGardensSceneGeometry.cross(u, v))
        }

        /// A quad of shape half `half` facing the eye at `centre` (``shapeQuad(centre:u:v:half:code:w:colour:)`` in
        /// the eye-facing basis).
        mutating func billboardQuad(centre: SIMD3<Double>, half: Double, code: Double, w: Double) throws(MeshError) {
            let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) =
                BinaryGardensSceneGeometry.billboardBasis(centre, eye: eye)
            try shapeQuad(centre: centre, u: b.right, v: b.up, half: SIMD2(half, half), code: code, w: w)
        }

        /// A quad of shape half `half` in the base plane (the gauges and bars) around `centre`, facing up.
        mutating func flatQuad(centre: SIMD3<Double>, half: SIMD2<Double>, code: Double) throws(MeshError) {
            try shapeQuad(centre: centre, u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0), half: half, code: code)
        }

        /// A flat quad whose shape spans x `left` … `right` and y `low` … `high` in the base plane.
        mutating func span(left: Double, right: Double, low: Double, high: Double,
                           code: Double) throws(MeshError) {
            try flatQuad(centre: SIMD3((left + right) / 2, (low + high) / 2, 0),
                         half: SIMD2(abs(right - left) / 2, abs(high - low) / 2), code: code)
        }

        /// The gauge plate: a quad from x `left` to `right` (u = ±1 at its ends: the plate's coverage ignores u) whose
        /// shape spans y `low` … `high` (v = ±``BinaryGardensShaders/quadExtent`` at its corners), facing up.
        mutating func plate(left: Double, right: Double, low: Double, high: Double, code: Double) throws(MeshError) {
            let e: Double = BinaryGardensShaders.quadExtent
            let middle: Double = (low + high) / 2
            let half: Double = e * abs(high - low) / 2
            try quad([SIMD3(left, middle - half, 0), SIMD3(right, middle - half, 0), SIMD3(right, middle + half, 0),
                      SIMD3(left, middle + half, 0)], code: code, local: [0, 0, 0, 0],
                     normals: [SIMD3(-1, -e, 0), SIMD3(1, -e, 0), SIMD3(1, e, 0), SIMD3(-1, e, 0)])
        }

        /// A segment strip of `width` from `a` to `b` (a quad whose shape spans the segment along u and the width
        /// across it, across lying radially in the segment's plane about the origin); nothing for a segment of length
        /// 0.
        mutating func segment(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, code: Double, w: Double = 0,
                              colour: SIMD3<Double>? = nil) throws(MeshError) {
            let d: SIMD3<Double> = b - a
            let size: Double = BinaryGardensSceneGeometry.length(d)
            guard size > 0 else { return }
            let along: SIMD3<Double> = d / size
            let middle: SIMD3<Double> = (a + b) / 2
            var radial: SIMD3<Double> = middle - along * BinaryGardensSceneGeometry.dot(middle, along)
            if BinaryGardensSceneGeometry.length(radial) < 1e-12 {
                radial = BinaryGardensSceneGeometry.cross(SIMD3(0, 0, 1), along)
            }
            let across: SIMD3<Double> = BinaryGardensSceneGeometry.unit(radial)
            try shapeQuad(centre: middle, u: along, v: across, half: SIMD2(size / 2, width / 2), code: code, w: w,
                          colour: colour)
        }

        /// A glow band: an annulus of ``BinaryGardensSceneGeometry/glowSides`` sides from `inner` (a_uv.y 0) to
        /// `outer` (a_uv.y 1) facing the eye at `centre`, a_normal `slot`, a_uv.x `code`, fallback colour `colour`.
        mutating func glowBand(centre: SIMD3<Double>, inner: Double, outer: Double, code: Double,
                               slot: SIMD3<Double>, colour: SIMD3<Double>) throws(MeshError) {
            let b: (right: SIMD3<Double>, up: SIMD3<Double>, facing: SIMD3<Double>) =
                BinaryGardensSceneGeometry.billboardBasis(centre, eye: eye)
            let n: Int = BinaryGardensSceneGeometry.glowSides
            for k in 0..<n {
                let a0: Double = 2 * Double.pi * Double(k) / Double(n)
                let a1: Double = 2 * Double.pi * Double(k + 1) / Double(n)
                let e0: SIMD3<Double> = b.right * cos(a0) + b.up * sin(a0)
                let e1: SIMD3<Double> = b.right * cos(a1) + b.up * sin(a1)
                try quad([centre + e0 * inner, centre + e0 * outer, centre + e1 * outer, centre + e1 * inner],
                         code: code, local: [0, 1, 1, 0], colours: [colour, colour, colour, colour],
                         normals: [slot, slot, slot, slot], facing: b.facing)
            }
        }

        /// The coloured mesh built so far.
        func built() -> BinaryGardensColouredMesh {
            BinaryGardensColouredMesh(mesh: builder.build(), colours: colours)
        }
    }
}
