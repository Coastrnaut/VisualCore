// MicroscopicAuroraSceneGeometry — feature 483 (R02-G19-03) T-R02G1903-004 (FR-R02G1903-001, 002, 003, 004, 006;
// SC-R02G1903-001; clarifications Q1–Q4). The microscope dish of Microscopic Aurora, built from a snapshot only. x
// points right, y up and z towards the viewer. One fixed scale for every level: a dish point (x, y) in dish units maps
// to world space by w(p, depth) = ((x − 3072) · s, (3072 − y) · s, depth) with s = 0.9 / 2816, so an enclosure of 11
// cells has its rim at radius 0.9 and the dish never rescales between levels. The dish's y axis points down the
// screen (row 0 at the top). Nothing here is consulted by the rules.
//
// Draw order (clarification Q1; depth testing off, so the dish mesh is in painter's order): the elements
// (``MicroscopicAuroraElement``) by kind, then by index within the kind:
//   0. backdrop: one quad at depth −1 facing the eye, large enough to fill the view for aspects 0.25 … 4;
//   1. field: a disc of radius R · 256 · s (96 sides);
//   2. fronds: at the tiers with `fronds` only, 24 L-system fronds of three generations rooted just outside the rim
//      (stems 0.03, 0.018 and 0.011 long, 0.005, 0.0035 and 0.0025 wide, branching ±0.5 rad), reaching at most 0.07
//      beyond the rim; decoration only;
//   3. rim: the ring at the enclosure radius, 0.012 wide (96 segments); on an exit failure then a radial mark 0.014
//      wide from 0.03 inside to 0.03 outside the rim at the angle of the escaping swimmer's last position, broken;
//   4. stencil: each stencil cell's outline, four strips of side 256 · s, 0.004 wide (extended by half the width at
//      both ends so the corners close); broken for an unlit stencil cell on a coverage failure;
//   5. cells: each lit cell (lit stencil cells and stray cells, row-major) a cell quad inset by 10 % (the cell spans
//      ±0.4 cell, the quad ±0.5 cell = ``MicroscopicAuroraShaders/markQuadExtent`` · 0.4 cell); then, on a
//      connectedness failure, the named cell's outline 0.008 wide, broken;
//   6. sites: a ring of radius 0.35 cell, 0.005 wide (32 segments), at each site's centre;
//   7. wells: per slot with a well a spiral of strength + 1 half-turns from 0.1 to 0.45 cell (12 segments per
//      half-turn, 0.006 wide) turning the way the kernel's curl turns the swimmers (in dish coordinates the angle grows
//      with the sense's sign, so after the y flip a counterclockwise well turns clockwise on screen), then its
//      arrowhead (0.016 long, 0.018 across) at the spiral's outer end pointing along it;
//   8. ribbons: for each swimmer a strip 0.01 wide through its kernel positions of ticks max(0, shown − L) … shown (L
//      = `tier.ribbonTicks`; no other point), its along coordinate 0 at the tail and 1 at the head;
//   9. swimmers: each a tapered capsule 0.05 long and 0.016 wide centred on its kernel position at the shown tick,
//      oriented along its velocity there (+x for a still swimmer); `tier.capsuleSegments` around and along (the first
//      fifth of the bands, at least one, the heliotrope tail tip), or flat at level-2 (two quads from the axis to the
//      sides and two half-disc ends of 8 segments, the tail end the tail tip); broken (whole) when a failure names it;
//  10. gauges: the coverage track at y = −1.08 and the coherence track at y = −1.15 from x = −0.9 to 0.9, 0.012 tall,
//      mapping 0 … 1000 and 0 … N; each with a requirement tick (0.005 wide, ±0.025) and a reading mark of radius 0.02
//      (met: filled; else hollow — the shader's; on a won level every mark is met); then `budget` actions bars at y =
//      −1.25, each 1.8 / budget wide with a fifth as gap and 0.04 tall, lit for the actions left.
// The glow mesh is drawn last, additively: `tier.glowShells` shells k (outermost first, factor 0.5^k), lifted 0.001 · k
// towards the eye: a band of ``glowSides`` sides around each swimmer (from radius 0.01, growth 0.02 per shell) and a
// band along each ribbon (half width 0.005 + 0.008 · k, its factor times the along coordinate); empty at level-2. A won
// level moves nothing: the shader lights every stencil outline (and the fallback colours them lit), every mark is met.
//
// Failures (clarification Q4) are marked in the broken colour: an exit — the escaping swimmer and the rim mark; a
// coherence failure — every swimmer outside the largest linked group (κ = `coherenceRadius` cells, the kernel's link
// rule; ties go to the group of the lowest index) at the failing tick; a coverage failure — the unlit stencil outlines;
// a connectedness failure — the named cell's outline.
//
// Vertex streams (the contract of ``MicroscopicAuroraShaders``; a_uv.x the ``MicroscopicAuroraMaterial`` code): the
// backdrop a_uv.y the height 0 (bottom) … 1 (top) and a_normal.x the horizontal coordinate −1 … +1; flat fills (field,
// arrowheads) a_uv.y 0 and a_normal zero; strips (fronds, rim, outlines, site rings, spirals, ribbons, tracks, ticks,
// broken marks) a_uv.y the across coordinate −1 … +1 (a ring's inner edge −1), a_normal zero; a ribbon's a_uv.x
// ``MicroscopicAuroraShaders/ribbonCode(along:)``; capsules a_normal the unit outward normal and a_uv.y 0, a flat
// capsule a_normal zero and a_uv.y 0 on its axis and 1 on its outline; cell and mark quads a_normal.xy the quad-local
// coordinate (± ``MicroscopicAuroraShaders/markQuadExtent`` at the corners, the shape spanning −1 … +1) and a_uv.y 0;
// bar fans a_uv.y 0 at the centre and 1 on the outline. Glow mesh: a_normal the base colour, a_uv.x
// ``MicroscopicAuroraShaders/GlowKind/code(factor:)``, a_uv.y 0 on a shell's inner edge (a ribbon's centre line) and 1
// on its outer edge. Every flat triangle winds counter-clockwise seen from the eye, every capsule triangle seen from
// outside. Tiers change only the capsules, the ribbons' length, the fronds and the glow: every other position is the
// same at every tier. Doubles are used for drawing only. Modelled on `ApsidesWorkshopSceneGeometry` (473).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct MicroscopicAuroraCamera: Sendable, Equatable {
    /// The eye position in world units, (0, −0.15, 3.4).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.15, 0).
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

/// One drawn element of the scene with its place in the painter's order (clarification Q1).
public struct MicroscopicAuroraElement: Sendable, Equatable {
    /// The kind of an element, in the painter's order.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The water backdrop.
        case backdrop = 0
        /// The dish field.
        case field = 1
        /// The decorative fronds.
        case fronds = 2
        /// The rim (with an exit's mark).
        case rim = 3
        /// A stencil cell's outline.
        case stencil = 4
        /// A lit cell (or a connectedness failure's named cell).
        case cell = 5
        /// A well site's ring.
        case site = 6
        /// A well's spiral and arrowhead.
        case well = 7
        /// A swimmer's ribbon.
        case ribbon = 8
        /// A swimmer's capsule.
        case swimmer = 9
        /// A gauge or an actions bar.
        case gauge = 10
    }

    /// What an element draws.
    public enum Part: Int, Sendable, CaseIterable {
        /// The backdrop.
        case backdrop = 0
        /// The field.
        case field = 1
        /// The fronds (nothing at a tier without fronds).
        case fronds = 2
        /// The rim.
        case rim = 3
        /// An exit failure's mark on the rim.
        case rimMark = 4
        /// The outline of the stencil cell whose row-major index is `item`.
        case outline = 5
        /// The lit cell whose row-major index is `item`.
        case litCell = 6
        /// The outline of the cell a connectedness failure names (row-major index `item`).
        case namedCell = 7
        /// Site `item`.
        case site = 8
        /// The well of slot `item`.
        case well = 9
        /// Swimmer `item`'s ribbon.
        case ribbon = 10
        /// Swimmer `item`'s capsule.
        case swimmer = 11
        /// The coverage gauge.
        case coverageTrack = 12
        /// The coherence gauge.
        case coherenceTrack = 13
        /// Actions bar `item`.
        case bar = 14
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind.
    public let index: Int
    /// What the element draws.
    public let part: Part
    /// The index within its part: cell index, site, slot, swimmer or bar (0 for the single elements).
    public let item: Int
    /// The element's centre in world units.
    public let centre: SIMD3<Double>

    /// An element of the given values.
    public init(kind: Kind, index: Int, part: Part, item: Int, centre: SIMD3<Double>) {
        self.kind = kind
        self.index = index
        self.part = part
        self.item = item
        self.centre = centre
    }

    /// Whether `a` is painted before `b`: by kind first, then by index (the scene is planar seen from the eye, so a
    /// fixed order by kind is exact).
    public static func paintsBefore(_ a: MicroscopicAuroraElement, _ b: MicroscopicAuroraElement) -> Bool {
        if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
        return a.index < b.index
    }
}

/// A point of the CPU reference (clarification Q3).
public struct MicroscopicAuroraReferencePoint: Sendable, Equatable {
    /// What the point marks.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The dish centre (the field).
        case dishCentre = 0
        /// The rim's rightmost point.
        case rimPoint = 1
        /// A swimmer's centre at the shown tick.
        case swimmer = 2
        /// The first site's centre.
        case site = 3
        /// The coverage track's centre.
        case coverageTrack = 4
        /// The first actions bar's centre.
        case actionsBar = 5
    }

    /// What the point marks.
    public let kind: Kind
    /// The swimmer, site or bar index (0 for the single points).
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
public struct MicroscopicAuroraColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Microscopic Aurora dish from a `MicroscopicAuroraSceneSnapshot`: places, meshes, camera and projection
/// (see the file header).
public enum MicroscopicAuroraSceneGeometry {
    // MARK: Constants (world units)

    /// World units per dish unit, s = 0.9 / 2816.
    public static let scale: Double = 0.9 / 2816
    /// One cell's side in world units, 256 · s.
    public static let cellSide: Double = Double(MicroscopicAuroraDish.unit) * scale
    /// The backdrop's plane.
    public static let backdropDepth: Double = -1
    /// The plane of everything else (the capsules are centred on it).
    public static let planeZ: Double = 0
    /// The sides of the field disc.
    public static let fieldSides: Int = 96
    /// The rim's width.
    public static let rimWidth: Double = 0.012
    /// The rim's segments.
    public static let rimSegments: Int = 96
    /// The number of fronds.
    public static let frondCount: Int = 24
    /// The gap between the rim's centre line and a frond's root.
    public static let frondRoot: Double = 0.006
    /// The stem lengths of the three frond generations.
    public static let frondLengths: [Double] = [0.03, 0.018, 0.011]
    /// The stem widths of the three frond generations.
    public static let frondWidths: [Double] = [0.005, 0.0035, 0.0025]
    /// The angle a frond branch turns from its parent, in radians.
    public static let frondBranch: Double = 0.5
    /// How far a frond may reach beyond the rim.
    public static let frondReach: Double = 0.07
    /// An exit mark's reach inside and outside the rim.
    public static let exitMarkReach: Double = 0.03
    /// An exit mark's width.
    public static let exitMarkWidth: Double = 0.014
    /// A stencil outline's line width.
    public static let outlineWidth: Double = 0.004
    /// The named cell's outline width on a connectedness failure.
    public static let namedOutlineWidth: Double = 0.008
    /// The inset of a lit cell on each side, as a share of the cell.
    public static let litInset: Double = 0.1
    /// A site ring's radius, as a share of the cell.
    public static let siteRadiusShare: Double = 0.35
    /// A site ring's width.
    public static let siteWidth: Double = 0.005
    /// A site ring's segments.
    public static let siteSegments: Int = 32
    /// A well spiral's outer radius, as a share of the cell.
    public static let wellRadiusShare: Double = 0.45
    /// A well spiral's inner radius, as a share of the cell.
    public static let wellInnerShare: Double = 0.1
    /// A well spiral's width.
    public static let wellWidth: Double = 0.006
    /// A well spiral's segments per half-turn.
    public static let wellSegmentsPerHalfTurn: Int = 12
    /// A well arrowhead's length.
    public static let arrowLength: Double = 0.016
    /// A well arrowhead's width across its base.
    public static let arrowWidth: Double = 0.018
    /// A ribbon's width.
    public static let ribbonWidth: Double = 0.01
    /// A capsule's length.
    public static let capsuleLength: Double = 0.05
    /// A capsule's width.
    public static let capsuleWidth: Double = 0.016
    /// A capsule's radius at the tail end as a share of its head radius (the taper).
    public static let capsuleTaper: Double = 0.75
    /// The segments of a flat capsule's half-disc ends.
    public static let flatEndSegments: Int = 8
    /// The coverage track's centre line.
    public static let coverageY: Double = -1.08
    /// The coherence track's centre line.
    public static let coherenceY: Double = -1.15
    /// The gauges' left end.
    public static let gaugeStart: Double = -0.9
    /// The gauges' right end.
    public static let gaugeEnd: Double = 0.9
    /// A gauge track's height.
    public static let trackHeight: Double = 0.012
    /// A requirement tick's reach above and below its track's centre line.
    public static let tickReach: Double = 0.025
    /// A requirement tick's width.
    public static let tickWidth: Double = 0.005
    /// A gauge mark's radius (the mark unit).
    public static let markRadius: Double = 0.02
    /// The actions bars' centre line.
    public static let barsY: Double = -1.25
    /// The share of a slot an actions bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// An actions bar's height.
    public static let barHeight: Double = 0.04
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// A swimmer glow band's inner radius.
    public static let swimmerGlowInner: Double = 0.01
    /// A swimmer glow band's growth per shell.
    public static let swimmerGlowGrowth: Double = 0.02
    /// A ribbon glow band's growth (half width) per shell.
    public static let ribbonGlowGrowth: Double = 0.008
    /// The sides of a glow band.
    public static let glowSides: Int = 24
    /// Lift towards the eye per glow shell.
    public static let glowLift: Double = 0.001
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, -0.15, 3.4)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.15, 0)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner (z covers the capsules and the glow lift).
    public static let boxLow: SIMD3<Double> = SIMD3(-1.0, -1.35, -0.02)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1.0, 1.0, 0.02)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The aspects the backdrop fills.
    public static let backdropAspects: ClosedRange<Double> = 0.25...4

    // MARK: Material codes

    /// The a_uv.x value of `material`.
    static func code(_ material: MicroscopicAuroraMaterial) -> Double { Double(material.rawValue) }

    /// The fallback colour of material code `code` (unlit; a ribbon code counts as the ribbon; broken for a code that
    /// is not finite or outside the materials).
    public static func colour(of code: Double) -> SIMD3<Double> {
        guard code.isFinite, code >= 0, code < Double(MicroscopicAuroraMaterial.allCases.count) - 0.5 else {
            return MicroscopicAuroraPalette.broken
        }
        return MicroscopicAuroraMaterial.decode(code).baseColour
    }

    // MARK: Places (the CPU reference)

    /// The world point of dish point `point` at `depth`: ((x − 3072) · s, (3072 − y) · s, depth).
    public static func world(_ point: MicroscopicAuroraPoint, depth: Double) -> SIMD3<Double> {
        worldDish(Double(point.x), Double(point.y), depth: depth)
    }

    /// The world point of the dish point (x, y) in fractional dish units at `depth`.
    static func worldDish(_ x: Double, _ y: Double, depth: Double) -> SIMD3<Double> {
        let c: Double = Double(MicroscopicAuroraDish.centre)
        return SIMD3((x - c) * scale, (c - y) * scale, depth)
    }

    /// `index` clamped to 0 … count − 1 (0 when count is 0).
    static func clamped(_ index: Int, _ count: Int) -> Int { min(max(index, 0), max(count - 1, 0)) }

    /// The dish centre, the origin.
    public static func dishCentre() -> SIMD3<Double> { SIMD3(0, 0, planeZ) }

    /// The enclosure radius in world units, R · 256 · s.
    public static func rimRadius(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Double {
        Double(snapshot.radius * MicroscopicAuroraDish.unit) * scale
    }

    /// The rim's rightmost point, (R · 256 · s, 0, 0).
    public static func rimPoint(_ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double> {
        SIMD3(rimRadius(snapshot), 0, planeZ)
    }

    /// The centre of cell `cell`: w of its centre.
    public static func cellCentre(_ cell: MicroscopicAuroraCell) -> SIMD3<Double> {
        world(cell.centre, depth: planeZ)
    }

    /// Swimmer `index`'s centre (clamped; the dish centre without swimmers): w of its kernel position at the shown
    /// tick.
    public static func swimmerCentre(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double> {
        guard let track = track(index, snapshot) else { return dishCentre() }
        return world(track[clamped(snapshot.shownTick, track.count)], depth: planeZ)
    }

    /// The positions of swimmer `index` (clamped), nil without swimmers or positions.
    static func track(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraPoint]? {
        guard !snapshot.positions.isEmpty else { return nil }
        let track: [MicroscopicAuroraPoint] = snapshot.positions[clamped(index, snapshot.positions.count)]
        return track.isEmpty ? nil : track
    }

    /// Swimmer `index`'s axis: the unit world direction of its velocity at the shown tick, (1, 0, 0) for a still
    /// swimmer (or without a velocity).
    public static func swimmerAxis(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.velocities.isEmpty else { return SIMD3(1, 0, 0) }
        let list: [MicroscopicAuroraPoint] = snapshot.velocities[clamped(index, snapshot.velocities.count)]
        guard !list.isEmpty else { return SIMD3(1, 0, 0) }
        let v: MicroscopicAuroraPoint = list[clamped(snapshot.shownTick, list.count)]
        let x: Double = Double(v.x)
        let y: Double = -Double(v.y)
        let length: Double = (x * x + y * y).squareRoot()
        guard length > 0 else { return SIMD3(1, 0, 0) }
        return SIMD3(x / length, y / length, 0)
    }

    /// The centre of site `index` (clamped; the dish centre without sites).
    public static func siteCentre(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.sites.isEmpty else { return dishCentre() }
        return cellCentre(snapshot.sites[clamped(index, snapshot.sites.count)])
    }

    /// The coverage track's centre: (0, −1.08, 0).
    public static func coverageTrackCentre() -> SIMD3<Double> {
        SIMD3((gaugeStart + gaugeEnd) / 2, coverageY, planeZ)
    }

    /// The coherence track's centre: (0, −1.15, 0).
    public static func coherenceTrackCentre() -> SIMD3<Double> {
        SIMD3((gaugeStart + gaugeEnd) / 2, coherenceY, planeZ)
    }

    /// The x of `value` on a gauge whose scale is 0 … `top`: −0.9 + 1.8 · value / top (value clamped to 0 … top; top
    /// at least 1).
    public static func gaugeX(_ value: Int, top: Int) -> Double {
        let t: Double = Double(max(top, 1))
        return gaugeStart + (gaugeEnd - gaugeStart) * min(max(Double(value), 0), t) / t
    }

    /// The coherence gauge's top: the swarm size (at least 1).
    public static func coherenceTop(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Int { max(snapshot.swarm, 1) }

    /// The coverage reading mark's centre.
    public static func coverageMark(_ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeX(snapshot.coverage, top: 1000), coverageY, planeZ)
    }

    /// The coherence reading mark's centre (the smallest coherence).
    public static func coherenceMark(_ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeX(snapshot.coherence, top: coherenceTop(snapshot)), coherenceY, planeZ)
    }

    /// Whether the coverage mark is met: the coverage reaches its requirement, or the level is won.
    public static func coverageMet(_ snapshot: MicroscopicAuroraSceneSnapshot, won: Bool) -> Bool {
        won || snapshot.coverage >= snapshot.requiredCoverage
    }

    /// Whether the coherence mark is met: the smallest coherence reaches its requirement, or the level is won.
    public static func coherenceMet(_ snapshot: MicroscopicAuroraSceneSnapshot, won: Bool) -> Bool {
        won || snapshot.coherence >= snapshot.requiredCoherence
    }

    /// The width of one actions slot, 1.8 / budget.
    public static func actionsSlot(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Double {
        (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of actions bar `index`: (−0.9 + (index + 0.5) · slot, −1.25, 0).
    public static func actionsBar(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * actionsSlot(snapshot), barsY, planeZ)
    }

    /// The actions bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litActions(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The ticks swimmer `index`'s ribbon passes through: max(0, shown − L) … shown (L = `tier.ribbonTicks`), clamped
    /// to its positions.
    public static func ribbonTicks(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot,
                                   tier: MicroscopicAuroraTier) -> ClosedRange<Int> {
        let count: Int = track(index, snapshot)?.count ?? 1
        let head: Int = clamped(snapshot.shownTick, count)
        return max(0, head - max(tier.ribbonTicks, 0))...head
    }

    /// Swimmer `swimmer`'s ribbon points, tail first: w of exactly its kernel positions at ``ribbonTicks(_:_:tier:)``
    /// (no interpolated point); empty without positions.
    public static func ribbon(_ swimmer: Int, _ snapshot: MicroscopicAuroraSceneSnapshot,
                              tier: MicroscopicAuroraTier) -> [SIMD3<Double>] {
        guard let track = track(swimmer, snapshot) else { return [] }
        var points: [SIMD3<Double>] = []
        for t in ribbonTicks(swimmer, snapshot, tier: tier) { points.append(world(track[t], depth: planeZ)) }
        return points
    }

    /// The swimmers drawn broken: the escaping swimmer of an exit failure, or every swimmer outside the largest
    /// linked group at a coherence failure's tick; empty otherwise.
    public static func brokenSwimmers(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Set<Int> {
        switch snapshot.failure {
        case .exit(let swimmer, _):
            return [swimmer]
        case .coherence(let tick, _):
            let group: Set<Int> = Set(largestGroup(snapshot, tick: tick))
            var outside: Set<Int> = []
            for i in snapshot.positions.indices where !group.contains(i) { outside.insert(i) }
            return outside
        default:
            return []
        }
    }

    /// The largest group of swimmers linked within κ = `coherenceRadius` cells at `tick` (clamped to each track), as
    /// ascending indices; among groups of equal size the one holding the lowest index (the kernel's link rule, the
    /// size the kernel's coherence counts).
    public static func largestGroup(_ snapshot: MicroscopicAuroraSceneSnapshot, tick: Int) -> [Int] {
        let n: Int = snapshot.positions.count
        var points: [MicroscopicAuroraPoint] = []
        for i in 0..<n {
            let track: [MicroscopicAuroraPoint] = snapshot.positions[i]
            points.append(track.isEmpty ? MicroscopicAuroraPoint(x: 0, y: 0) : track[clamped(tick, track.count)])
        }
        let r: Int = max(snapshot.coherenceRadius, 0) * MicroscopicAuroraDish.unit
        let r2: Int = r * r
        var seen: [Bool] = Array(repeating: false, count: n)
        var best: [Int] = []
        for start in 0..<n where !seen[start] {
            seen[start] = true
            var stack: [Int] = [start]
            var group: [Int] = []
            while let a = stack.popLast() {
                group.append(a)
                for b in 0..<n where !seen[b] {
                    let dx: Int = points[a].x - points[b].x
                    let dy: Int = points[a].y - points[b].y
                    if dx * dx + dy * dy <= r2 {
                        seen[b] = true
                        stack.append(b)
                    }
                }
            }
            if group.count > best.count { best = group }
        }
        return best.sorted()
    }

    /// The unit world direction from the dish centre to the escaping swimmer's last position on an exit failure, nil
    /// otherwise ((1, 0, 0) for a position at the centre).
    public static func exitDirection(_ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double>? {
        guard case .exit(let swimmer, _) = snapshot.failure, let track = track(swimmer, snapshot) else { return nil }
        let p: SIMD3<Double> = world(track[track.count - 1], depth: planeZ)
        let length: Double = (p.x * p.x + p.y * p.y).squareRoot()
        guard length > 0 else { return SIMD3(1, 0, 0) }
        return SIMD3(p.x / length, p.y / length, 0)
    }

    /// The row-major indices of the stencil cells whose outlines are broken: the unlit stencil cells on a coverage
    /// failure, none otherwise.
    public static func brokenOutlines(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Set<Int> {
        guard case .coverage = snapshot.failure else { return [] }
        var lit: Set<Int> = []
        for cell in snapshot.litStencil { lit.insert(cell.index) }
        var broken: Set<Int> = []
        for cell in snapshot.stencil where !lit.contains(cell.index) { broken.insert(cell.index) }
        return broken
    }

    /// The cell a connectedness failure names, nil otherwise.
    public static func namedCell(_ snapshot: MicroscopicAuroraSceneSnapshot) -> MicroscopicAuroraCell? {
        if case .connectedness(let cell) = snapshot.failure { return cell }
        return nil
    }

    /// The lit cells drawn, row-major and each once: the lit stencil cells and the stray cells.
    public static func litCells(_ snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraCell] {
        var cells: Set<MicroscopicAuroraCell> = Set(snapshot.litStencil)
        for cell in snapshot.stray { cells.insert(cell) }
        return cells.sorted()
    }

    // MARK: Elements

    /// Every element with its centre, in painter's order (by kind, then index; clarification Q1). The same for every
    /// tier and stage.
    public static func paintOrder(_ snapshot: MicroscopicAuroraSceneSnapshot) -> [MicroscopicAuroraElement] {
        typealias E = MicroscopicAuroraElement
        var list: [E] = []
        list.append(E(kind: .backdrop, index: 0, part: .backdrop, item: 0,
                      centre: SIMD3(lookAt.x, lookAt.y, backdropDepth)))
        list.append(E(kind: .field, index: 0, part: .field, item: 0, centre: dishCentre()))
        list.append(E(kind: .fronds, index: 0, part: .fronds, item: 0, centre: dishCentre()))
        list.append(E(kind: .rim, index: 0, part: .rim, item: 0, centre: dishCentre()))
        if let d = exitDirection(snapshot) {
            list.append(E(kind: .rim, index: 1, part: .rimMark, item: 0, centre: d * rimRadius(snapshot)))
        }
        for (k, cell) in snapshot.stencil.enumerated() {
            list.append(E(kind: .stencil, index: k, part: .outline, item: cell.index, centre: cellCentre(cell)))
        }
        let lit: [MicroscopicAuroraCell] = litCells(snapshot)
        for (k, cell) in lit.enumerated() {
            list.append(E(kind: .cell, index: k, part: .litCell, item: cell.index, centre: cellCentre(cell)))
        }
        if let cell = namedCell(snapshot) {
            list.append(E(kind: .cell, index: lit.count, part: .namedCell, item: cell.index,
                          centre: cellCentre(cell)))
        }
        for (k, cell) in snapshot.sites.enumerated() {
            list.append(E(kind: .site, index: k, part: .site, item: k, centre: cellCentre(cell)))
        }
        var wells: Int = 0
        for (slot, well) in snapshot.wells.enumerated() {
            guard let well else { continue }
            list.append(E(kind: .well, index: wells, part: .well, item: slot, centre: cellCentre(well.cell)))
            wells += 1
        }
        for i in snapshot.positions.indices {
            list.append(E(kind: .ribbon, index: i, part: .ribbon, item: i, centre: swimmerCentre(i, snapshot)))
        }
        for i in snapshot.positions.indices {
            list.append(E(kind: .swimmer, index: i, part: .swimmer, item: i, centre: swimmerCentre(i, snapshot)))
        }
        list.append(E(kind: .gauge, index: 0, part: .coverageTrack, item: 0, centre: coverageTrackCentre()))
        list.append(E(kind: .gauge, index: 1, part: .coherenceTrack, item: 0, centre: coherenceTrackCentre()))
        for b in 0..<max(snapshot.budget, 0) {
            list.append(E(kind: .gauge, index: 2 + b, part: .bar, item: b, centre: actionsBar(b, snapshot)))
        }
        list.sort(by: E.paintsBefore)
        return list
    }

    /// The CPU reference points (clarification Q3): the dish centre, the rim's rightmost point, every swimmer at the
    /// shown tick, the first site (when the level lists sites), the coverage track's centre and the first actions bar.
    public static func referencePoints(_ snapshot: MicroscopicAuroraSceneSnapshot)
        -> [MicroscopicAuroraReferencePoint] {
        typealias R = MicroscopicAuroraReferencePoint
        var points: [R] = [R(kind: .dishCentre, index: 0, centre: dishCentre()),
                           R(kind: .rimPoint, index: 0, centre: rimPoint(snapshot))]
        for i in snapshot.positions.indices {
            points.append(R(kind: .swimmer, index: i, centre: swimmerCentre(i, snapshot)))
        }
        if !snapshot.sites.isEmpty { points.append(R(kind: .site, index: 0, centre: siteCentre(0, snapshot))) }
        points.append(R(kind: .coverageTrack, index: 0, centre: coverageTrackCentre()))
        if snapshot.budget > 0 { points.append(R(kind: .actionsBar, index: 0, centre: actionsBar(0, snapshot))) }
        return points
    }

    // MARK: Meshes

    /// The dish mesh for the dish program, in painter's order (see the header).
    public static func dishMesh(_ snapshot: MicroscopicAuroraSceneSnapshot,
                                tier: MicroscopicAuroraTier) throws(MeshError) -> Mesh {
        try dishPart(snapshot, tier: tier).mesh
    }

    /// The glow mesh for the glow program (`glowPart` without colours); empty at level-2.
    public static func glowMesh(_ snapshot: MicroscopicAuroraSceneSnapshot,
                                tier: MicroscopicAuroraTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    /// The whole dish with fallback colours (each material's palette colour, unlit; the backdrop from abyss at its
    /// bottom to abyss top at its top; a ribbon from the field colour at its tail to the ribbon colour at its head; on
    /// a won level every stencil outline in the lit colour and every mark met) for the shared unlit renderer: the same
    /// positions as ``dishMesh(_:tier:)``. `wonLevel` overrides `snapshot.isWon`; positions never depend on it.
    public static func dishPart(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier,
                                wonLevel: Bool? = nil) throws(MeshError) -> MicroscopicAuroraColouredMesh {
        var parts: Parts = Parts()
        let won: Bool = wonLevel ?? snapshot.isWon
        let broken: Set<Int> = brokenSwimmers(snapshot)
        let outlines: Set<Int> = brokenOutlines(snapshot)
        for element in paintOrder(snapshot) {
            try draw(element, into: &parts, snapshot, tier: tier, won: won, brokenSwimmers: broken,
                     brokenOutlines: outlines)
        }
        return parts.built()
    }

    /// The backdrop's half width and half height: large enough to fill the view at its plane for every aspect in
    /// ``backdropAspects``.
    public static func backdropHalf() -> SIMD2<Double> {
        let distance: Double = eye.z - backdropDepth
        let tall: MicroscopicAuroraCamera = camera(aspect: backdropAspects.lowerBound)
        let wide: MicroscopicAuroraCamera = camera(aspect: backdropAspects.upperBound)
        let halfHeight: Double = distance * tan(tall.fovY / 2) * 1.05
        let halfWidth: Double = distance * tan(wide.fovY / 2) * wide.aspect * 1.05
        return SIMD2(halfWidth, halfHeight)
    }

    /// The backdrop height h (0 at its bottom, 1 at its top; a_uv.y) seen at view point `view` (0 … 1, y down) through
    /// `camera`: the gradient's coordinate at that pixel (the camera looks straight down the z axis).
    public static func backdropHeight(view: SIMD2<Double>, camera: MicroscopicAuroraCamera) -> Double {
        let distance: Double = camera.eye.z - backdropDepth
        let y: Double = camera.target.y + (1 - 2 * view.y) * distance * tan(camera.fovY / 2)
        let half: Double = backdropHalf().y
        return min(max((y - (lookAt.y - half)) / (2 * half), 0), 1)
    }

    /// Draws one element into `parts` (see the header).
    static func draw(_ element: MicroscopicAuroraElement, into parts: inout Parts,
                     _ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier, won: Bool,
                     brokenSwimmers: Set<Int>, brokenOutlines: Set<Int>) throws(MeshError) {
        typealias P = MicroscopicAuroraPalette
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        switch element.part {
        case .backdrop:
            let half: SIMD2<Double> = backdropHalf()
            let corners: [SIMD3<Double>] = [c + SIMD3(-half.x, -half.y, 0), c + SIMD3(half.x, -half.y, 0),
                                            c + SIMD3(half.x, half.y, 0), c + SIMD3(-half.x, half.y, 0)]
            try parts.quad(corners, code: code(.backdrop), local: [0, 0, 1, 1],
                           colours: [P.abyss, P.abyss, P.abyssTop, P.abyssTop],
                           slots: [SIMD3(-1, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 0, 0), SIMD3(-1, 0, 0)])
        case .field:
            let outline: [SIMD3<Double>] = Array(Parts.circlePoints(c, rimRadius(snapshot), fieldSides).dropLast())
            try parts.fan(centre: c, outline: outline, code: code(.field), rim: 0)
        case .fronds:
            if tier.fronds { try fronds(&parts, snapshot) }
        case .rim:
            let r: Double = rimRadius(snapshot)
            try parts.circle(centre: c, inner: r - rimWidth / 2, outer: r + rimWidth / 2, segments: rimSegments,
                             code: code(.rim))
        case .rimMark:
            let r: Double = rimRadius(snapshot)
            let d: SIMD3<Double> = exitDirection(snapshot) ?? SIMD3(1, 0, 0)
            try parts.strip(d * (r - exitMarkReach), d * (r + exitMarkReach), width: exitMarkWidth,
                            code: code(.broken))
        case .outline:
            let isBroken: Bool = brokenOutlines.contains(i)
            try outline(&parts, centre: c, width: outlineWidth, code: code(isBroken ? .broken : .stencil),
                        colour: !isBroken && won ? P.lit : nil)
        case .litCell:
            let cell: MicroscopicAuroraCell = MicroscopicAuroraCell(row: i / MicroscopicAuroraDish.cells,
                                                                    column: i % MicroscopicAuroraDish.cells)
            let inStencil: Bool = snapshot.stencil.contains(cell)
            try parts.mark(centre: c, unit: cellSide * (0.5 - litInset), code: code(inStencil ? .litCell : .strayCell))
        case .namedCell:
            try outline(&parts, centre: c, width: namedOutlineWidth, code: code(.broken), colour: nil)
        case .site:
            let r: Double = siteRadiusShare * cellSide
            try parts.circle(centre: c, inner: r - siteWidth / 2, outer: r + siteWidth / 2, segments: siteSegments,
                             code: code(.siteRing))
        case .well:
            if let well = snapshot.wells[i] { try spiral(&parts, well) }
        case .ribbon:
            try ribbonStrip(&parts, ribbon(i, snapshot, tier: tier))
        case .swimmer:
            try capsule(&parts, centre: c, axis: swimmerAxis(i, snapshot), tier: tier,
                        broken: brokenSwimmers.contains(i))
        case .coverageTrack:
            try gauge(&parts, y: coverageY, requirement: gaugeX(snapshot.requiredCoverage, top: 1000),
                      mark: coverageMark(snapshot), met: coverageMet(snapshot, won: won))
        case .coherenceTrack:
            try gauge(&parts, y: coherenceY,
                      requirement: gaugeX(snapshot.requiredCoherence, top: coherenceTop(snapshot)),
                      mark: coherenceMark(snapshot), met: coherenceMet(snapshot, won: won))
        case .bar:
            let half: SIMD2<Double> = SIMD2(barFill * actionsSlot(snapshot) / 2, barHeight / 2)
            let material: MicroscopicAuroraMaterial = i < litActions(snapshot) ? .barLit : .barUnlit
            try parts.rectangle(centre: c, half: half, code: code(material))
        }
    }

    /// The frond stems in drawing order as (from, to, generation): `frondCount` fronds at angles 2π (k + ½) / count,
    /// each a stem from radius rim + ``frondRoot`` outwards, two branches turned ±``frondBranch`` from its tip and two
    /// more from each of theirs.
    public static func frondStems(_ snapshot: MicroscopicAuroraSceneSnapshot)
        -> [(from: SIMD3<Double>, to: SIMD3<Double>, generation: Int)] {
        var stems: [(from: SIMD3<Double>, to: SIMD3<Double>, generation: Int)] = []
        let root: Double = rimRadius(snapshot) + frondRoot
        for k in 0..<frondCount {
            let angle: Double = 2 * Double.pi * (Double(k) + 0.5) / Double(frondCount)
            var tips: [(point: SIMD3<Double>, angle: Double)] = [(point: direction(angle) * root, angle: angle)]
            for generation in 0..<frondLengths.count {
                var next: [(point: SIMD3<Double>, angle: Double)] = []
                for tip in tips {
                    let turns: [Double] = generation == 0 ? [0] : [-frondBranch, frondBranch]
                    for turn in turns {
                        let a: Double = tip.angle + turn
                        let end: SIMD3<Double> = tip.point + direction(a) * frondLengths[generation]
                        stems.append((from: tip.point, to: end, generation: generation))
                        next.append((point: end, angle: a))
                    }
                }
                tips = next
            }
        }
        return stems
    }

    /// Draws the fronds (strips, frond colour).
    static func fronds(_ parts: inout Parts, _ snapshot: MicroscopicAuroraSceneSnapshot) throws(MeshError) {
        for stem in frondStems(snapshot) {
            try parts.strip(stem.from, stem.to, width: frondWidths[stem.generation], code: code(.frond))
        }
    }

    /// Draws the outline of the cell centred at `centre`: four strips of side ``cellSide`` and `width`, each extended
    /// by half the width at both ends.
    static func outline(_ parts: inout Parts, centre: SIMD3<Double>, width: Double, code: Double,
                        colour: SIMD3<Double>?) throws(MeshError) {
        let h: Double = cellSide / 2
        let e: Double = width / 2
        let edges: [(SIMD3<Double>, SIMD3<Double>)] = [
            (SIMD3(-h - e, -h, 0), SIMD3(h + e, -h, 0)), (SIMD3(h, -h - e, 0), SIMD3(h, h + e, 0)),
            (SIMD3(h + e, h, 0), SIMD3(-h - e, h, 0)), (SIMD3(-h, h + e, 0), SIMD3(-h, -h - e, 0)),
        ]
        for (a, b) in edges { try parts.strip(centre + a, centre + b, width: width, code: code, colour: colour) }
    }

    /// The spiral points of `well`, centre outwards: radius from 0.1 to 0.45 cell over strength + 1 half-turns in
    /// ``wellSegmentsPerHalfTurn`` segments each, the angle growing with the sense's sign in dish coordinates (the way
    /// the kernel's curl sign · (−dy, dx) turns the swimmers), mapped to world space.
    public static func spiralPoints(_ well: MicroscopicAuroraWell) -> [SIMD3<Double>] {
        let halfTurns: Int = max(well.strength, 0) + 1
        let segments: Int = halfTurns * wellSegmentsPerHalfTurn
        let total: Double = Double(halfTurns) * Double.pi
        let unit: Double = Double(MicroscopicAuroraDish.unit)
        let inner: Double = wellInnerShare * unit
        let outer: Double = wellRadiusShare * unit
        let centre: MicroscopicAuroraPoint = well.cell.centre
        let sign: Double = Double(well.sense.sign)
        var points: [SIMD3<Double>] = []
        for k in 0...segments {
            let f: Double = Double(k) / Double(segments)
            let theta: Double = sign * total * f
            let r: Double = inner + (outer - inner) * f
            points.append(worldDish(Double(centre.x) + r * cos(theta), Double(centre.y) + r * sin(theta),
                                    depth: planeZ))
        }
        return points
    }

    /// The arrowhead of `well` as (tip, base left, base right): at the spiral's outer end, pointing along its last
    /// segment.
    public static func arrowhead(_ well: MicroscopicAuroraWell) -> (tip: SIMD3<Double>, left: SIMD3<Double>,
                                                                     right: SIMD3<Double>) {
        let points: [SIMD3<Double>] = spiralPoints(well)
        let end: SIMD3<Double> = points[points.count - 1]
        let d: SIMD3<Double> = end - points[points.count - 2]
        let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
        let t: SIMD3<Double> = length > 0 ? d / length : SIMD3(1, 0, 0)
        let n: SIMD3<Double> = SIMD3(-t.y, t.x, 0) * (arrowWidth / 2)
        return (tip: end + t * arrowLength, left: end + n, right: end - n)
    }

    /// Draws `well`'s spiral (strips) and arrowhead (a flat fill).
    static func spiral(_ parts: inout Parts, _ well: MicroscopicAuroraWell) throws(MeshError) {
        let points: [SIMD3<Double>] = spiralPoints(well)
        for k in 0..<(points.count - 1) {
            try parts.strip(points[k], points[k + 1], width: wellWidth, code: code(.wellSpiral))
        }
        let arrow = arrowhead(well)
        try parts.flatTriangle(arrow.tip, arrow.left, arrow.right, code: code(.wellArrow))
    }

    /// Draws a ribbon through `points` (tail first): a strip of ``ribbonWidth`` per segment, a_uv.x
    /// ``MicroscopicAuroraShaders/ribbonCode(along:)`` with along k / n at point k, coloured from the field at the
    /// tail to the ribbon colour at the head; zero-length segments are skipped.
    static func ribbonStrip(_ parts: inout Parts, _ points: [SIMD3<Double>]) throws(MeshError) {
        let n: Int = points.count - 1
        guard n >= 1 else { return }
        for k in 0..<n {
            let a: SIMD3<Double> = points[k]
            let b: SIMD3<Double> = points[k + 1]
            let d: SIMD3<Double> = b - a
            let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
            guard length > 0 else { continue }
            let w: SIMD3<Double> = SIMD3(d.y / length, -d.x / length, 0) * (ribbonWidth / 2)
            let fa: Double = Double(k) / Double(n)
            let fb: Double = Double(k + 1) / Double(n)
            let ca: Double = MicroscopicAuroraShaders.ribbonCode(along: fa)
            let cb: Double = MicroscopicAuroraShaders.ribbonCode(along: fb)
            let field: SIMD3<Double> = MicroscopicAuroraPalette.field
            let ribbon: SIMD3<Double> = MicroscopicAuroraPalette.ribbon
            let ta: SIMD3<Double> = field + (ribbon - field) * fa
            let tb: SIMD3<Double> = field + (ribbon - field) * fb
            try parts.quad([a + w, b + w, b - w, a - w], codes: [ca, cb, cb, ca], local: [-1, -1, 1, 1],
                           colours: [ta, tb, tb, ta])
        }
    }

    /// The radius of a capsule at along coordinate t (−1 tail … +1 head): half its width, tapered linearly from
    /// ``capsuleTaper`` at the tail to 1 at the head, times the rounded profile (1 − t⁴)^¼.
    public static func capsuleRadius(_ t: Double) -> Double {
        let u: Double = min(max(t, -1), 1)
        let taper: Double = capsuleTaper + (1 - capsuleTaper) * (u + 1) / 2
        return capsuleWidth / 2 * taper * pow(max(1 - u * u * u * u, 0), 0.25)
    }

    /// Draws a swimmer's capsule centred at `centre` along unit `axis` (see the header).
    static func capsule(_ parts: inout Parts, centre: SIMD3<Double>, axis: SIMD3<Double>,
                        tier: MicroscopicAuroraTier, broken: Bool) throws(MeshError) {
        let body: Double = code(broken ? .broken : .swimmer)
        let tail: Double = code(broken ? .broken : .swimmerTail)
        let side: SIMD3<Double> = SIMD3(-axis.y, axis.x, 0)
        let half: Double = capsuleLength / 2
        if tier.flatCapsules {
            let r: Double = capsuleWidth / 2
            let reach: Double = half - r
            let head: SIMD3<Double> = centre + axis * reach
            let back: SIMD3<Double> = centre - axis * reach
            for s in [1.0, -1.0] {
                try parts.quad([back, head, head + side * (r * s), back + side * (r * s)], code: body,
                               local: [0, 0, 1, 1])
            }
            var front: [SIMD3<Double>] = []
            var rear: [SIMD3<Double>] = []
            for k in 0...flatEndSegments {
                let phi: Double = -Double.pi / 2 + Double.pi * Double(k) / Double(flatEndSegments)
                front.append(head + (axis * cos(phi) + side * sin(phi)) * r)
                rear.append(back + (axis * -cos(phi) + side * -sin(phi)) * r)
            }
            try parts.openFan(centre: head, arc: front, code: body)
            try parts.openFan(centre: back, arc: rear, code: tail)
            return
        }
        let m: Int = max(tier.capsuleSegments, 3)
        let around: Int = max(tier.capsuleSegments, 3)
        let tailBands: Int = max(1, m / 5)
        let up: SIMD3<Double> = SIMD3(0, 0, 1)
        for band in 0..<m {
            let material: Double = band < tailBands ? tail : body
            var rings: [[(point: SIMD3<Double>, normal: SIMD3<Double>)]] = []
            for i in [band, band + 1] {
                let t: Double = -1 + 2 * Double(i) / Double(m)
                let rho: Double = capsuleRadius(t)
                let h: Double = 1e-5
                let slope: Double = (capsuleRadius(min(t + h, 1)) - capsuleRadius(max(t - h, -1)))
                    / (min(t + h, 1) - max(t - h, -1))
                var ring: [(point: SIMD3<Double>, normal: SIMD3<Double>)] = []
                for j in 0...around {
                    let psi: Double = 2 * Double.pi * Double(j % around) / Double(around)
                    let e: SIMD3<Double> = side * cos(psi) + up * sin(psi)
                    var n: SIMD3<Double> = abs(t) >= 1 ? axis * (t > 0 ? 1 : -1) : e * half - axis * slope
                    let length: Double = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
                    n = length > 0 ? n / length : axis
                    ring.append((point: centre + axis * (t * half) + e * rho, normal: n))
                }
                rings.append(ring)
            }
            for j in 0..<around {
                let corners: [(point: SIMD3<Double>, normal: SIMD3<Double>)] = [rings[0][j], rings[0][j + 1],
                                                                                rings[1][j + 1], rings[1][j]]
                var ids: [UInt32] = []
                for corner in corners {
                    ids.append(try parts.vertex(corner.point, slot: corner.normal, code: material, local: 0))
                }
                let out1: SIMD3<Double> = corners[0].normal + corners[1].normal + corners[2].normal
                let out2: SIMD3<Double> = corners[0].normal + corners[2].normal + corners[3].normal
                try parts.triangle((ids[0], ids[1], ids[2]), corners[0].point, corners[1].point, corners[2].point,
                                   facing: out1)
                try parts.triangle((ids[0], ids[2], ids[3]), corners[0].point, corners[2].point, corners[3].point,
                                   facing: out2)
            }
        }
    }

    /// Draws a gauge at `y`: its track, its requirement tick at x `requirement` and its reading mark at `mark`.
    static func gauge(_ parts: inout Parts, y: Double, requirement: Double, mark: SIMD3<Double>,
                      met: Bool) throws(MeshError) {
        try parts.strip(SIMD3(gaugeStart, y, planeZ), SIMD3(gaugeEnd, y, planeZ), width: trackHeight,
                        code: code(.gaugeTrack))
        try parts.strip(SIMD3(requirement, y - tickReach, planeZ), SIMD3(requirement, y + tickReach, planeZ),
                        width: tickWidth, code: code(.requirementTick))
        try parts.mark(centre: mark, unit: markRadius, code: code(met ? .markMet : .markUnmet))
    }

    /// The glow with fallback colours (the base colour times the factor) for the shared unlit renderer:
    /// `tier.glowShells` shells k (outermost first, factor 0.5^k), lifted 0.001 · k towards the eye: a band of
    /// ``glowSides`` sides around each swimmer (from ``swimmerGlowInner``, growth ``swimmerGlowGrowth``, base
    /// ``MicroscopicAuroraPalette/glow``, kind swimmer) and a band along each ribbon (from its centre line, a_uv.y 0,
    /// to half width ribbonWidth / 2 + ``ribbonGlowGrowth`` · k, a_uv.y 1, base ``MicroscopicAuroraPalette/ribbon``,
    /// kind ribbon, the factor times the along coordinate). a_normal is the base colour and a_uv.x
    /// ``MicroscopicAuroraShaders/GlowKind/code(factor:)``. Empty at level-2.
    public static func glowPart(_ snapshot: MicroscopicAuroraSceneSnapshot,
                                tier: MicroscopicAuroraTier) throws(MeshError) -> MicroscopicAuroraColouredMesh {
        typealias P = MicroscopicAuroraPalette
        typealias K = MicroscopicAuroraShaders.GlowKind
        var parts: Parts = Parts()
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        var ribbons: [[SIMD3<Double>]] = []
        for i in snapshot.positions.indices { ribbons.append(ribbon(i, snapshot, tier: tier)) }
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            let lift: SIMD3<Double> = SIMD3(0, 0, glowLift * Double(k))
            for points in ribbons {
                var lifted: [SIMD3<Double>] = []
                for p in points { lifted.append(p + lift) }
                try parts.glowRibbon(lifted, half: ribbonWidth / 2 + ribbonGlowGrowth * Double(k), base: P.ribbon,
                                     kind: K.ribbon, factor: factor)
            }
            for i in snapshot.positions.indices {
                try parts.glowBand(centre: swimmerCentre(i, snapshot) + lift, inner: swimmerGlowInner,
                                   outer: swimmerGlowInner + swimmerGlowGrowth * Double(k), base: P.glow,
                                   code: K.swimmer.code(factor: factor), factor: factor)
            }
        }
        return parts.built()
    }

    // MARK: Camera

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

    /// The fixed camera for `aspect`: from (0, −0.15, 3.4) looking at (0, −0.15, 0) with +y up (straight down the z
    /// axis); the vertical field of view is the smallest that holds every corner of the box x −1.0 … 1.0, y −1.35 …
    /// 1.0, z −0.02 … 0.02 inside the view with ``fitMargin`` per side (the box is convex and in front of the eye, so
    /// every point inside it — the dish, the fronds, every swimmer, the gauges and the bars — keeps a margin of at
    /// least 5 % for aspect 0.4 … 2.5). Independent of the snapshot, the tier and the time.
    public static func camera(aspect: Double) -> MicroscopicAuroraCamera {
        let a: Double = usableAspect(aspect)
        let limit: Double = 1 - 2 * fitMargin
        var tanHalf: Double = 0
        var nearest: Double = Double.infinity
        var farthest: Double = 0
        for index in 0..<8 {
            let r: SIMD3<Double> = corner(index) - eye
            let depth: Double = -r.z                       // forward is −z
            nearest = min(nearest, depth)
            farthest = max(farthest, depth)
            tanHalf = max(tanHalf, abs(r.y) / depth / limit, abs(r.x) / depth / (a * limit))
        }
        let fovY: Double = 2 * atan(tanHalf)
        let near: Double = max(nearest * 0.5, 1e-3)
        let far: Double = max(farthest, eye.z - backdropDepth) + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(lookAt), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return MicroscopicAuroraCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far,
                                       view: view, projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: MicroscopicAuroraCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// The unit direction at `angle` (radians, anticlockwise from +x) in the plane z = 0.
    static func direction(_ angle: Double) -> SIMD3<Double> { SIMD3(cos(angle), sin(angle), 0) }

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from the eye (+z) or from
    /// outside a capsule.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []
        /// The side every flat piece faces: towards the eye.
        static let facing: SIMD3<Double> = SIMD3(0, 0, 1)

        /// Adds (or welds) a vertex at `p` with a_normal `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour` (default the code's).
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>? = nil) throws(MeshError) -> UInt32 {
            typealias G = MicroscopicAuroraSceneGeometry
            let id: UInt32 = try builder.vertex(G.vec(p), normal: G.vec(slot), uv: Vec2(code, local))
            if Int(id) == colours.count {
                let tint: SIMD3<Double> = colour ?? G.colour(of: code)
                colours.append(Vec4(min(max(tint.x, 0), 1), min(max(tint.y, 0), 1), min(max(tint.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from the side `facing` points to; degenerate triangles are
        /// skipped.
        mutating func triangle(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                               _ pc: SIMD3<Double>, facing: SIMD3<Double> = Parts.facing) throws(MeshError) {
            let u: SIMD3<Double> = pb - pa
            let v: SIMD3<Double> = pc - pa
            let n: SIMD3<Double> = SIMD3(u.y * v.z - u.z * v.y, u.z * v.x - u.x * v.z, u.x * v.y - u.y * v.x)
            let side: Double = n.x * facing.x + n.y * facing.y + n.z * facing.z
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A flat triangle (a flat fill: a_uv.y 0, a_normal zero).
        mutating func flatTriangle(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>,
                                   code: Double) throws(MeshError) {
            let zero: SIMD3<Double> = SIMD3(0, 0, 0)
            let ia: UInt32 = try vertex(a, slot: zero, code: code, local: 0)
            let ib: UInt32 = try vertex(b, slot: zero, code: code, local: 0)
            let ic: UInt32 = try vertex(c, slot: zero, code: code, local: 0)
            try triangle((ia, ib, ic), a, b, c)
        }

        /// A quad (corners in order) facing the eye, with uv (`code` or per-corner `codes`, `local[k]`), a_normal
        /// per corner `slots` (default zero), in `colour` (default the code's) or per-corner `colours`.
        mutating func quad(_ p: [SIMD3<Double>], code: Double = 0, codes: [Double]? = nil, local: [Double],
                           colour: SIMD3<Double>? = nil, colours tints: [SIMD3<Double>]? = nil,
                           slots: [SIMD3<Double>]? = nil) throws(MeshError) {
            var ids: [UInt32] = []
            for k in 0..<4 {
                ids.append(try vertex(p[k], slot: slots?[k] ?? SIMD3(0, 0, 0), code: codes?[k] ?? code,
                                      local: local[k], colour: tints?[k] ?? colour))
            }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2])
            try triangle((ids[0], ids[2], ids[3]), p[0], p[2], p[3])
        }

        /// A fan through the convex closed `outline` around `centre` facing the eye: local 0 at the centre and `rim`
        /// on the outline; a_normal zero.
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], code: Double,
                          rim: Double = 1) throws(MeshError) {
            let zero: SIMD3<Double> = SIMD3(0, 0, 0)
            let c: UInt32 = try vertex(centre, slot: zero, code: code, local: 0)
            var ids: [UInt32] = []
            for p in outline { ids.append(try vertex(p, slot: zero, code: code, local: rim)) }
            for k in outline.indices {
                let j: Int = (k + 1) % outline.count
                try triangle((c, ids[k], ids[j]), centre, outline[k], outline[j])
            }
        }

        /// An open fan from `centre` through consecutive points of `arc` (local 0 at the centre, 1 on the arc;
        /// a_normal zero), facing the eye.
        mutating func openFan(centre: SIMD3<Double>, arc: [SIMD3<Double>], code: Double) throws(MeshError) {
            let zero: SIMD3<Double> = SIMD3(0, 0, 0)
            let c: UInt32 = try vertex(centre, slot: zero, code: code, local: 0)
            var ids: [UInt32] = []
            for p in arc { ids.append(try vertex(p, slot: zero, code: code, local: 1)) }
            for k in 0..<(arc.count - 1) {
                try triangle((c, ids[k], ids[k + 1]), centre, arc[k], arc[k + 1])
            }
        }

        /// A strip of `width` from `a` to `b` in the plane facing the eye (a_uv.y −1 … +1 across it, a_normal zero),
        /// in `colour` (default the code's); nothing for a strip of length 0.
        mutating func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, code: Double,
                            colour: SIMD3<Double>? = nil) throws(MeshError) {
            let d: SIMD3<Double> = b - a
            let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
            guard length > 0 else { return }
            let w: SIMD3<Double> = SIMD3(d.y / length, -d.x / length, 0) * (width / 2)
            try quad([a + w, b + w, b - w, a - w], code: code, local: [-1, -1, 1, 1], colour: colour)
        }

        /// A mark or cell quad of half side ``MicroscopicAuroraShaders/markQuadExtent`` · `unit` around `centre`:
        /// a_normal.xy the quad-local coordinate (± markQuadExtent at the corners), a_uv.y 0.
        mutating func mark(centre: SIMD3<Double>, unit: Double, code: Double) throws(MeshError) {
            let e: Double = MicroscopicAuroraShaders.markQuadExtent
            let h: Double = e * unit
            try quad([centre + SIMD3(-h, -h, 0), centre + SIMD3(h, -h, 0), centre + SIMD3(h, h, 0),
                      centre + SIMD3(-h, h, 0)], code: code, local: [0, 0, 0, 0],
                     slots: [SIMD3(-e, -e, 0), SIMD3(e, -e, 0), SIMD3(e, e, 0), SIMD3(-e, e, 0)])
        }

        /// A rectangle of half size `half` around `centre`, as a fan (a_uv.y 0 at the centre, 1 on the outline).
        mutating func rectangle(centre: SIMD3<Double>, half: SIMD2<Double>, code: Double) throws(MeshError) {
            try fan(centre: centre, outline: [centre + SIMD3(-half.x, -half.y, 0), centre + SIMD3(half.x, -half.y, 0),
                                              centre + SIMD3(half.x, half.y, 0), centre + SIMD3(-half.x, half.y, 0)],
                    code: code)
        }

        /// The circle of `radius` around `centre` (in its z plane) in `segments` + 1 points (the last repeats the
        /// first), anticlockwise from the eye.
        static func circlePoints(_ centre: SIMD3<Double>, _ radius: Double, _ segments: Int) -> [SIMD3<Double>] {
            var points: [SIMD3<Double>] = []
            let n: Int = max(segments, 3)
            for k in 0...n {
                points.append(centre + MicroscopicAuroraSceneGeometry.direction(2 * Double.pi * Double(k % n)
                                                                                / Double(n)) * radius)
            }
            return points
        }

        /// A ring between `inner` and `outer` around `centre` in `segments` quads (a_uv.y −1 inner, +1 outer;
        /// a_normal zero).
        mutating func circle(centre: SIMD3<Double>, inner: Double, outer: Double, segments: Int,
                             code: Double) throws(MeshError) {
            let a: [SIMD3<Double>] = Parts.circlePoints(centre, inner, segments)
            let b: [SIMD3<Double>] = Parts.circlePoints(centre, outer, segments)
            for k in 0..<(a.count - 1) {
                try quad([a[k], b[k], b[k + 1], a[k + 1]], code: code, local: [-1, 1, 1, -1])
            }
        }

        /// A glow band: a ring of ``MicroscopicAuroraSceneGeometry/glowSides`` sides from `inner` (a_uv.y 0) to
        /// `outer` (a_uv.y 1) around `centre`, a_normal the base colour, a_uv.x `code`, coloured base · factor.
        mutating func glowBand(centre: SIMD3<Double>, inner: Double, outer: Double, base: SIMD3<Double>, code: Double,
                               factor: Double) throws(MeshError) {
            let sides: Int = MicroscopicAuroraSceneGeometry.glowSides
            let a: [SIMD3<Double>] = Parts.circlePoints(centre, inner, sides)
            let b: [SIMD3<Double>] = Parts.circlePoints(centre, outer, sides)
            for k in 0..<(a.count - 1) {
                try quad([a[k], b[k], b[k + 1], a[k + 1]], code: code, local: [0, 1, 1, 0], colour: base * factor,
                         slots: [base, base, base, base])
            }
        }

        /// A glow band along the open polyline `points` (tail first): per segment two quads from the centre line
        /// (a_uv.y 0) to either edge at `half` (a_uv.y 1), a_normal the base colour, a_uv.x `kind`'s code of factor
        /// · along (along k / n at point k), coloured base · factor · along; zero-length segments are skipped.
        mutating func glowRibbon(_ points: [SIMD3<Double>], half: Double, base: SIMD3<Double>,
                                 kind: MicroscopicAuroraShaders.GlowKind, factor: Double) throws(MeshError) {
            let n: Int = points.count - 1
            guard n >= 1 else { return }
            for k in 0..<n {
                let a: SIMD3<Double> = points[k]
                let b: SIMD3<Double> = points[k + 1]
                let d: SIMD3<Double> = b - a
                let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
                guard length > 0 else { continue }
                let w: SIMD3<Double> = SIMD3(d.y / length, -d.x / length, 0) * half
                let fa: Double = factor * Double(k) / Double(n)
                let fb: Double = factor * Double(k + 1) / Double(n)
                let codes: [Double] = [kind.code(factor: fa), kind.code(factor: fb), kind.code(factor: fb),
                                       kind.code(factor: fa)]
                let tints: [SIMD3<Double>] = [base * fa, base * fb, base * fb, base * fa]
                let slots: [SIMD3<Double>] = [base, base, base, base]
                try quad([a, b, b + w, a + w], codes: codes, local: [0, 0, 1, 1], colours: tints, slots: slots)
                try quad([a, b, b - w, a - w], codes: codes, local: [0, 0, 1, 1], colours: tints, slots: slots)
            }
        }

        /// The coloured mesh built so far.
        func built() -> MicroscopicAuroraColouredMesh {
            MicroscopicAuroraColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
