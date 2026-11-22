// NocturneGardenSceneGeometry — feature 383 (R02-G09-03) T-R02G0903-004 (FR-R02G0903-001, 002, 004, 006;
// SC-R02G0903-001; clarifications Q1–Q4). The garden of Nocturne Garden, built from a snapshot only. The bed stands
// upright as the mist plane z = 0 with y up: with the cell size u = 2 / W, cell (column c, row r) spans x from −1 + c·u
// to −1 + (c + 1)·u and y from r·u to (r + 1)·u (cell index r·W + c, row 0 at the bottom). Every cell of the kernel's
// mask is a shadow quad on the plane (z = 0.002) with a feathered band of `tier.feather`·u along its boundary edges
// towards non-shadow bed cells (shadow material, the shade the cover 1 … 0); the target's boundary edges carry a gold
// rim (z = 0.003); the forbidden cells a coral hatch (z = 0.001); after a leak failure the leaking cells a cross (z =
// 0.004). Each bloom grows in front of the plane: its head is its kind's outline at headScale·size·u (0.35: the
// lantern magnifies, so the small flower hides little of its own shadow), the foot at the anchor
// cell's lower-left corner, extruded from z = 0.35 to 0.39 (ear-clipped faces and side walls), and its stem an L-system
// of `tier.stemDepth` segments from the foot down to the ground y = −0.2 with a leaf pair per segment. The lantern (the
// sun) is a sphere at x = 1.25, y = (1.15 − 0.25·(e − 1))·H·u, z = 0.3; the move gauge a row of `budget` bars at y =
// −0.1, z = 0.05 from x = −0.9 to 0.9 (the first `moves` spent). The ground is the plane y = −0.2. The fixed authored
// camera looks at the bed's centre from +z, pitched 8° down, fitted per level to the sphere about that centre holding
// the bed widened by the largest head (s·u left, 2·s·u right, 6·s·u above), the stems, the lantern and the gauge, with
// a 5 % margin for aspect 0.4 … 2.5. Depth testing is off on this render path, so the garden mesh is emitted in
// painter's order. Mist drift and bloom sway move by uniforms only: no position depends on the time or Reduce Motion,
// and positions, colours and marks are the same at every tier (tiers change only the feather band, the stem's segments
// and leaves, and the glow shells). Doubles are used for drawing only; nothing here is consulted by the rules.
//
// Feature 384 (R02-G09-04) T-R02G0904-003 (FR-R02G0904-002, 003, 005; SC-R02G0904-002, 004; clarifications Q2, Q3):
// the player's orbit (`NocturneGardenOrbit`: yaw ±35° about +y, pitch 0° … 30° down from the horizon, authored yaw 0
// and pitch 8°) and `camera(_:aspect:orbit:)`, which fits the same per-level framing sphere at every orbit (the fit
// does not depend on the direction, so the 5 % margin holds everywhere; the authored camera is the authored orbit's
// camera, bit for bit); and the drag preview's outline: thin quads of the preview material along the boundary edges
// of the snapshot's `preview` cells (z = 0.0035, drawn right after the target rim).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of the Nocturne Garden scene for one snapshot, aspect and orbit.
///
/// Built only by ``NocturneGardenSceneGeometry/camera(_:aspect:orbit:)`` (and
/// ``NocturneGardenSceneGeometry/camera(_:aspect:)``, its authored orbit). World positions are in bed units (the bed spans x
/// −1 … 1); ``viewProjection`` maps them to GL clip space (right-handed, depth −1 … 1).
public struct NocturneGardenCamera: Sendable, Equatable {
    /// The eye position in world units.
    public let eye: SIMD3<Double>
    /// The point looked at: the bed's centre (0, H·u / 2, 0).
    public let target: SIMD3<Double>
    /// The vertical field of view in radians.
    public let fovY: Double
    /// The aspect ratio (width / height) the camera was fitted for, after clamping to 0.1 … 10 (1 when unusable).
    public let aspect: Double
    /// The near clip distance.
    public let near: Double
    /// The far clip distance.
    public let far: Double
    /// The radius of the bounding sphere about ``target`` the camera was fitted to.
    public let radius: Double
    /// The view matrix: `Mat4.lookAt` from ``eye`` to ``target`` with +y up.
    public let view: Mat4
    /// The projection matrix: `Mat4.perspective` (GL depth range).
    public let projection: Mat4
    /// ``projection`` times ``view``.
    public let viewProjection: Mat4
}

/// The player's view of the garden: a yaw about +y and a pitch above the horizon, both in radians (feature 384,
/// R02-G09-04, clarification Q3). Presentation only: never saved, never read by the rules.
public struct NocturneGardenOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians: the angle of the eye direction above the horizon (the view looks down by it); allowed
    /// ``pitchRange`` (0° … 30°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 8° (``NocturneGardenSceneGeometry/pitch``), the fixed camera of R02-G09-03.
    public static let authored = NocturneGardenOrbit(yaw: 0, pitch: NocturneGardenSceneGeometry.pitch)
    /// The largest yaw either way, 35° in radians.
    public static let yawLimit: Double = 35.0 * Double.pi / 180
    /// The allowed pitches, 0° … 30° in radians.
    public static let pitchRange: ClosedRange<Double> = 0...(30.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −35° … 35° and pitch to 0° … 30°; a non-finite angle becomes the authored one.
    public func clamped() -> NocturneGardenOrbit {
        let y: Double = yaw.isFinite ? yaw : Self.authored.yaw
        let p: Double = pitch.isFinite ? pitch : Self.authored.pitch
        return NocturneGardenOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                   pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// The unit direction from the bed's centre to the eye at the clamped orbit: (sin y · cos p, sin p, cos y · cos p)
    /// with y the yaw and p the pitch; exactly ``NocturneGardenSceneGeometry/eyeDirection`` at ``authored``.
    public var eyeDirection: SIMD3<Double> {
        let o: NocturneGardenOrbit = clamped()
        return SIMD3(sin(o.yaw) * cos(o.pitch), sin(o.pitch), cos(o.yaw) * cos(o.pitch))
    }
}

/// A mesh with one colour per vertex (sRGB RGBA 0 … 1, alpha 1), aligned with `mesh.positions`.
///
/// The colours feed the shared unlit mesh renderer of the fallback path (the shader programs have no colour stream;
/// they read the same information from the normal and uv streams, see ``NocturneGardenSceneGeometry``).
public struct NocturneGardenColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh`, in vertex order.
    public let colours: [Vec4]
}

/// The geometry of the Nocturne Garden scene: places (cell centres, gauge bars, the lantern, bloom boxes), the garden
/// mesh (ground, mist, shadow with its feather, target rim, forbidden hatch, leak crosses, blooms, lantern, gauge), the
/// glow mesh (shells over the heads and the lantern), camera and projection.
///
/// **Vertex streams** (the contract with the shaders; attributes a_position, a_normal, a_uv as bound by
/// `ShaderMeshRenderer`; positions are world units, identity model).
/// - ``gardenMesh(_:tier:reduceMotion:)`` — garden program: `a_normal` the unit shading normal; `a_uv` (material code,
///   shade) with the codes of `NocturneGardenShaders.GardenMaterial` (0 ground, 1 mist, 2 shadow, 3 target rim, 4
///   forbidden hatch, 5 leak cross, 6 bloom body, 7 leaf or stem, 8 lantern, 9 spent bar, 10 unspent bar, 11 head rim,
///   12 drag-preview outline);
///   shade 1 everywhere except on a shadow feather band, whose shade is the shadow cover (1 at the shadow's edge … 0 at
///   the band's outer edge; every shadow quad has cover 1).
/// - ``glowMesh(_:tier:)`` — glow program: `a_normal` the colour (sRGB 0 … 1: bloom glow, or lantern); `a_uv` (glow
///   weight 0 … 1, 0). Shell k = 1 … `tier.glowShells` of a head has weight 0.5^k; the lantern's single shell 0.5.
/// ``NocturneGardenColouredMesh/colours`` gives each vertex's unlit colour for the fallback: on the garden the material
/// colour times the shade (on the shadow the mist mixed toward the shadow by the cover); bodies, stems and leaves
/// through `NocturneGardenShaders.gardenShade`, the lantern and head rims through `emissiveShade` with
/// ``lightDirection``; on the glow the stream colour times the weight.
///
/// Every triangle is wound counter-clockwise seen from its front. Depth testing is off, so the garden mesh is in
/// painter's order: ground, mist, hatch, shadow, feather, rim, preview outline, crosses, the blooms (each stem, leaves, back face, side
/// walls, front face, in canonical order), the lantern, the gauge.
public enum NocturneGardenSceneGeometry {
    /// The material codes of the garden program (`a_uv.x`), shared with ``NocturneGardenShaders``.
    enum Material {
        /// The midnight ground plane.
        static let ground: Double = NocturneGardenShaders.groundMaterial
        /// The mist plane of the bed.
        static let mist: Double = NocturneGardenShaders.mistMaterial
        /// A shadow quad or feather band (`a_uv.y` the cover).
        static let shadow: Double = NocturneGardenShaders.shadowMaterial
        /// The gold rim along a target boundary edge.
        static let targetRim: Double = NocturneGardenShaders.targetRimMaterial
        /// A forbidden cell's hatch quad.
        static let forbiddenHatch: Double = NocturneGardenShaders.forbiddenHatchMaterial
        /// A leak cross arm.
        static let leakCross: Double = NocturneGardenShaders.leakCrossMaterial
        /// A head's front or back face.
        static let bloomBody: Double = NocturneGardenShaders.bloomBodyMaterial
        /// A stem segment or a leaf.
        static let leafStem: Double = NocturneGardenShaders.leafStemMaterial
        /// The lantern sphere.
        static let lantern: Double = NocturneGardenShaders.lanternMaterial
        /// A spent gauge bar.
        static let spentBar: Double = NocturneGardenShaders.spentBarMaterial
        /// An unspent gauge bar.
        static let unspentBar: Double = NocturneGardenShaders.unspentBarMaterial
        /// A head's side wall (the glowing rim).
        static let headRim: Double = NocturneGardenShaders.headRimMaterial
        /// A bar of the drag preview's outline.
        static let preview: Double = NocturneGardenShaders.previewMaterial
    }

    // MARK: Constants (world units unless stated)

    /// The half-width of the bed in world units, 1 (the bed spans x −1 … 1).
    public static let bedHalfWidth = 1.0
    /// The y of the ground plane, −0.2 (the stems end on it).
    public static let groundY = -0.2
    /// The half-width in x of the ground plane, 6.
    public static let groundHalfWidth = 6.0
    /// The nearest z of the ground plane, −0.2.
    public static let groundBack = -0.2
    /// The farthest z (towards the eye) of the ground plane, 1.0.
    public static let groundFront = 1.0
    /// The z of the hatch layer, 0.001.
    public static let hatchZ = 0.001
    /// The z of the shadow layer and its feather, 0.002.
    public static let shadowZ = 0.002
    /// The z of the target rim, 0.003.
    public static let rimZ = 0.003
    /// The z of the drag preview's outline, 0.0035 (above the target rim, below the leak crosses).
    public static let previewZ = 0.0035
    /// The z of the leak crosses, 0.004.
    public static let crossZ = 0.004
    /// The z of a head's back face, 0.35.
    public static let bloomZ = 0.35
    /// The depth of a head's extrusion, 0.04 (front face at z = 0.39).
    public static let headDepth = 0.04
    /// The half-width of a target rim bar, in cells (0.06).
    public static let rimHalfWidth = 0.06
    /// The half-length of a leak-cross arm, in cells (0.6).
    public static let crossArm = 0.6
    /// The half-width of a leak-cross arm, in cells (0.08).
    public static let crossHalfWidth = 0.08
    /// The half-width of a stem, in size·u (0.2).
    public static let stemHalfWidth = 0.2
    /// The sideways bend of an inner stem joint, in size·u (0.15, alternating).
    public static let stemBend = 0.15
    /// The length of a leaf, in size·u (0.8).
    public static let leafLength = 0.8
    /// How much a leaf rises over its length, as a fraction of it (0.35).
    public static let leafRise = 0.35
    /// The half-width of a leaf, as a fraction of its length (0.18).
    public static let leafHalfWidth = 0.18
    /// How far a bloom's stem and leaves may reach sideways from the stem's centre line, in size·u (1.1): the bound
    /// ``bloomBox(_:_:tier:)`` uses at every tier.
    public static let stemReach = 1.1
    /// The x of the lantern, 1.25.
    public static let lanternX = 1.25
    /// The z of the lantern, 0.3.
    public static let lanternZ = 0.3
    /// The radius of the lantern sphere, 0.09.
    public static let lanternRadius = 0.09
    /// The stacks of the lantern sphere, 8.
    public static let lanternStacks = 8
    /// The slices of the lantern sphere, 12.
    public static let lanternSlices = 12
    /// The y of the gauge row, −0.1.
    public static let gaugeY = -0.1
    /// The z of the gauge row, 0.05.
    public static let gaugeZ = 0.05
    /// The x where the gauge row starts, −0.9.
    public static let gaugeStart = -0.9
    /// The x where the gauge row ends, 0.9.
    public static let gaugeEnd = 0.9
    /// The fraction of each bar's slot a bar fills, 0.6.
    public static let gaugeFill = 0.6
    /// The largest bar width, 0.12.
    public static let gaugeMaxWidth = 0.12
    /// The half-height of a gauge bar, 0.03.
    public static let gaugeHalfHeight = 0.03
    /// How much wider glow shell k is than its head: scale 1 + 0.08·k about the outline's vertex mean.
    public static let glowGrowth = 0.08
    /// How far glow shell k sits behind the head's back face: 0.003·k.
    public static let glowLift = 0.003
    /// The glow weight of shell k is glowWeight^k (0.5).
    public static let glowWeight = 0.5
    /// The radius of the lantern's glow disc, as a multiple of the lantern radius (2.2).
    public static let lanternGlowScale = 2.2
    /// The segments of the lantern's glow disc, 16.
    public static let lanternGlowSegments = 16
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's pitch below the horizon in radians (8°).
    public static let pitch = 8.0 * Double.pi / 180
    /// The unit direction from the bed's centre to the eye: (0, sin 8°, cos 8°) — in front (+z), above.
    public static let eyeDirection = SIMD3<Double>(0, sin(pitch), cos(pitch))
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The unit light direction of the fallback colours: normalize(0.35, 0.8, 0.5).
    public static let lightDirection = unit(SIMD3<Double>(0.35, 0.8, 0.5))

    // MARK: Places

    /// The bed width in cells, at least 1.
    static func columns(_ snapshot: NocturneGardenSceneSnapshot) -> Int { max(snapshot.width, 1) }

    /// The bed height in cells, at least 1.
    static func rows(_ snapshot: NocturneGardenSceneSnapshot) -> Int { max(snapshot.height, 1) }

    /// The cell size u = 2 / W in world units (W at least 1).
    public static func cellSize(_ snapshot: NocturneGardenSceneSnapshot) -> Double {
        2 * bedHalfWidth / Double(columns(snapshot))
    }

    /// The centre of `cell` (index r·W + c, row 0 at the bottom) on the mist plane: (−1 + (c + 0.5)·u, (r + 0.5)·u, 0).
    /// A negative cell is treated as 0.
    public static func cellCentre(_ cell: Int, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double> {
        let w: Int = columns(snapshot)
        let index: Int = max(cell, 0)
        let u: Double = cellSize(snapshot)
        return SIMD3(-bedHalfWidth + (Double(index % w) + 0.5) * u, (Double(index / w) + 0.5) * u, 0)
    }

    /// The bed's centre (0, H·u / 2, 0): the point the camera looks at.
    public static func bedCentre(_ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double> {
        SIMD3(0, Double(rows(snapshot)) * cellSize(snapshot) / 2, 0)
    }

    /// The centre of gauge bar `index` of the snapshot's budget: (−0.9 + (index + 0.5) · 1.8 / budget, −0.1, 0.05)
    /// (budget at least 1).
    public static func gaugeBar(_ index: Int, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double> {
        let slot: Double = (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
        return SIMD3(gaugeStart + (Double(index) + 0.5) * slot, gaugeY, gaugeZ)
    }

    /// The material code of every gauge bar, in order: spent for the first `moves` (clamped to 0 … budget), unspent
    /// for the rest; empty for a non-positive budget.
    static func gaugeCodes(_ snapshot: NocturneGardenSceneSnapshot) -> [Double] {
        let budget: Int = max(snapshot.budget, 0)
        let spent: Int = min(max(snapshot.moves, 0), budget)
        var codes: [Double] = []
        for bar in 0..<budget {
            codes.append(bar < spent ? Material.spentBar : Material.unspentBar)
        }
        return codes
    }

    /// The number of spent gauge bars: `moves` clamped to 0 … budget.
    public static func spentBars(_ snapshot: NocturneGardenSceneSnapshot) -> Int {
        min(max(snapshot.moves, 0), max(snapshot.budget, 0))
    }

    /// The lantern's centre: (1.25, (1.15 − 0.25·(e − 1))·H·u, 0.3), the elevation e clamped to 1 … 4.
    public static func lantern(_ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double> {
        let e: Double = Double(min(max(snapshot.sun, 1), 4))
        let height: Double = Double(rows(snapshot)) * cellSize(snapshot)
        return SIMD3(lanternX, (1.15 - 0.25 * (e - 1)) * height, lanternZ)
    }

    /// The world-space box of bloom `bloom`'s head and stem (with its leaves): x from the head's outline bounds and the
    /// stem's reach (``stemReach``·s·u either side of the stem's centre line), y from the ground −0.2 to the head's
    /// top, z from 0.35 to 0.39. The same at every tier (the stem's segments stay inside it); a zero box at the origin
    /// for an unknown bloom.
    public static func bloomBox(_ bloom: Int, _ snapshot: NocturneGardenSceneSnapshot,
                                tier: NocturneGardenTier) -> (min: SIMD3<Double>, max: SIMD3<Double>) {
        guard snapshot.blooms.indices.contains(bloom) else { return (.zero, .zero) }
        let b: NocturneGardenBloom = snapshot.blooms[bloom]
        let head: [SIMD2<Double>] = headOutline(b, snapshot)
        let scale: Double = bloomScale(b, snapshot)
        let stemX: Double = foot(b, snapshot).x + 0.5 * scale
        var low: SIMD2<Double> = SIMD2(stemX - stemReach * scale, groundY)
        var high: SIMD2<Double> = SIMD2(stemX + stemReach * scale, foot(b, snapshot).y)
        for p in head {
            low = SIMD2(min(low.x, p.x), min(low.y, p.y))
            high = SIMD2(max(high.x, p.x), max(high.y, p.y))
        }
        return (SIMD3(low.x, low.y, bloomZ), SIMD3(high.x, high.y, bloomZ + headDepth))
    }

    /// The foot of `bloom`: the anchor cell's lower-left corner (−1 + column·u, row·u).
    static func foot(_ bloom: NocturneGardenBloom, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD2<Double> {
        let u: Double = cellSize(snapshot)
        return SIMD2(-bedHalfWidth + Double(bloom.column) * u, Double(bloom.row) * u)
    }

    /// How large a bloom is drawn against its unstretched shadow outline (0.35): the lantern magnifies, so the small
    /// flower in front of the mist casts the large shadow the kernel's mask holds, and the flower hides little of it
    /// (spec clarification Q1, corrected during implementation on 2026-11-22: drawn at size·u, a head covered its own
    /// shadow and, with two blooms, nearly all of level 1's bed).
    public static let headScale: Double = 0.35

    /// The scale headScale·size·u of `bloom` (size clamped to 1 … 3): heads, stems, leaves and boxes use it.
    static func bloomScale(_ bloom: NocturneGardenBloom, _ snapshot: NocturneGardenSceneSnapshot) -> Double {
        Double(min(max(bloom.size, NocturneGardenBloom.sizes.lowerBound), NocturneGardenBloom.sizes.upperBound))
            * cellSize(snapshot) * headScale
    }

    /// The head outline of `bloom` in the plane: every outline vertex (x, y) at foot + headScale·size·u·(x, y).
    static func headOutline(_ bloom: NocturneGardenBloom, _ snapshot: NocturneGardenSceneSnapshot) -> [SIMD2<Double>] {
        let origin: SIMD2<Double> = foot(bloom, snapshot)
        let scale: Double = bloomScale(bloom, snapshot)
        var result: [SIMD2<Double>] = []
        for p in bloom.kind.outline { result.append(origin + SIMD2(Double(p.x), Double(p.y)) * scale) }
        return result
    }

    // MARK: Meshes

    /// The garden (garden program, real normals, uv (material code, shade)), in painter's order: the ground (y = −0.2,
    /// x ±6, z −0.2 … 1); the mist quad over the bed (z = 0); the forbidden hatch (z = 0.001: one quad per cell, the
    /// program draws the stripes); one shadow quad per mask cell (z = 0.002) and, when `tier.feather` is positive, a
    /// feather band of that many cells outward along each shadow edge that borders a non-shadow bed cell (shade 1 … 0);
    /// the gold rim along every target edge that borders a non-target cell or the bed's border (z = 0.003); the drag
    /// preview's outline along every edge of a `snapshot.preview` cell that borders a non-preview cell or the bed's
    /// border (z = 0.0035, preview material, shade 1, as wide as the rim; nothing when `preview` is empty); after a
    /// leak failure a cross on every leaking cell (z = 0.004); every bloom in canonical order (stem segments and leaf
    /// pairs at z = 0.37, the head's back face at z = 0.35, side walls, front face at z = 0.39); the lantern sphere;
    /// the gauge bars. `reduceMotion` changes nothing here: drift and sway are uniforms of the shaders.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func gardenPart(_ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier,
                                  reduceMotion: Bool = false) throws(MeshError) -> NocturneGardenColouredMesh {
        typealias M = NocturneGardenSceneGeometry.Material
        var parts: Parts = Parts(lit: true)
        let u: Double = cellSize(snapshot)
        let w: Int = columns(snapshot)
        let h: Int = rows(snapshot)
        let count: Int = w * h
        let front: SIMD3<Double> = SIMD3(0, 0, 1)
        // Ground.
        let g: Double = groundHalfWidth
        try parts.polygon([SIMD3(-g, groundY, groundBack), SIMD3(-g, groundY, groundFront),
                           SIMD3(g, groundY, groundFront), SIMD3(g, groundY, groundBack)],
                          normal: SIMD3(0, 1, 0), uv: Vec2(M.ground, 1))
        // Mist.
        let top: Double = Double(h) * u
        try parts.polygon([SIMD3(-bedHalfWidth, 0, 0), SIMD3(bedHalfWidth, 0, 0), SIMD3(bedHalfWidth, top, 0),
                           SIMD3(-bedHalfWidth, top, 0)], normal: front, uv: Vec2(M.mist, 1))
        // Hatch.
        for cell in snapshot.forbidden where cell >= 0 && cell < count {
            try addHatch(cell, snapshot, to: &parts)
        }
        // Shadow and feather.
        let shadow: Set<Int> = Set(snapshot.shadow.filter { $0 >= 0 && $0 < count })
        for cell in snapshot.shadow where cell >= 0 && cell < count {
            try parts.polygon(cellQuad(cell, snapshot, z: shadowZ), normal: front, uv: Vec2(M.shadow, 1))
        }
        let feather: Double = tier.feather.isFinite ? max(tier.feather, 0) * u : 0
        if feather > 0 {
            for cell in snapshot.shadow where cell >= 0 && cell < count {
                for side in 0..<4 {
                    guard let neighbour = neighbour(cell, side: side, width: w, height: h),
                          !shadow.contains(neighbour) else { continue }
                    let (a, b, out) = edge(cell, side: side, snapshot, z: shadowZ)
                    let shift: SIMD3<Double> = out * feather
                    try parts.quad([a, b, b + shift, a + shift], shades: [1, 1, 0, 0], normal: front,
                                   code: M.shadow)
                }
            }
        }
        // Target rim.
        let target: Set<Int> = Set(snapshot.target.filter { $0 >= 0 && $0 < count })
        let half: Double = rimHalfWidth * u
        for cell in snapshot.target where cell >= 0 && cell < count {
            for side in 0..<4 {
                if let other = neighbour(cell, side: side, width: w, height: h), target.contains(other) { continue }
                let (a, b, out) = edge(cell, side: side, snapshot, z: rimZ)
                let along: SIMD3<Double> = unit(b - a) * half
                try parts.polygon([a - along - out * half, b + along - out * half, b + along + out * half,
                                   a - along + out * half], normal: front, uv: Vec2(M.targetRim, 1))
            }
        }
        // Preview outline.
        let preview: Set<Int> = Set(snapshot.preview.filter { $0 >= 0 && $0 < count })
        for cell in preview.sorted() {
            for side in 0..<4 {
                if let other = neighbour(cell, side: side, width: w, height: h), preview.contains(other) { continue }
                let (a, b, out) = edge(cell, side: side, snapshot, z: previewZ)
                let along: SIMD3<Double> = unit(b - a) * half
                try parts.polygon([a - along - out * half, b + along - out * half, b + along + out * half,
                                   a - along + out * half], normal: front, uv: Vec2(M.preview, 1))
            }
        }
        // Leak crosses.
        if snapshot.leakFailure {
            let d1: SIMD3<Double> = unit(SIMD3(1, 1, 0))
            let d2: SIMD3<Double> = unit(SIMD3(1, -1, 0))
            for cell in snapshot.leaking where cell >= 0 && cell < count {
                let c: SIMD3<Double> = cellCentre(cell, snapshot) + SIMD3(0, 0, crossZ)
                try parts.bar(centre: c, along: d1, across: d2, halfLength: crossArm * u,
                              halfWidth: crossHalfWidth * u, normal: front, uv: Vec2(M.leakCross, 1))
                try parts.bar(centre: c, along: d2, across: d1, halfLength: crossArm * u,
                              halfWidth: crossHalfWidth * u, normal: front, uv: Vec2(M.leakCross, 1))
            }
        }
        // Blooms.
        for bloom in snapshot.blooms {
            try addBloom(bloom, snapshot, depth: max(tier.stemDepth, 1), to: &parts)
        }
        // Lantern.
        try addLantern(lantern(snapshot), to: &parts)
        // Gauge.
        let codes: [Double] = gaugeCodes(snapshot)
        let slot: Double = (gaugeEnd - gaugeStart) / Double(max(codes.count, 1))
        let halfWidth: Double = min(gaugeFill * slot, gaugeMaxWidth) / 2
        for (bar, code) in codes.enumerated() {
            try parts.bar(centre: gaugeBar(bar, snapshot), along: SIMD3(1, 0, 0), across: SIMD3(0, 1, 0),
                          halfLength: halfWidth, halfWidth: gaugeHalfHeight, normal: front, uv: Vec2(code, 1))
        }
        return parts.built()
    }

    /// The garden mesh (see ``gardenPart(_:tier:reduceMotion:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func gardenMesh(_ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier,
                                  reduceMotion: Bool = false) throws(MeshError) -> Mesh {
        try gardenPart(snapshot, tier: tier, reduceMotion: reduceMotion).mesh
    }

    /// The glow (glow program, colour in the normal slot, uv (weight, 0)): for k = `tier.glowShells` … 1, every head's
    /// outline scaled by 1 + 0.08·k about its vertex mean, 0.003·k behind the head's back face, bloom glow, weight
    /// 0.5^k; then one disc of radius 2.2 × the lantern radius just behind the lantern, lantern colour, weight 0.5.
    /// Empty when the tier has no glow shells (level-2).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowPart(_ snapshot: NocturneGardenSceneSnapshot,
                                tier: NocturneGardenTier) throws(MeshError) -> NocturneGardenColouredMesh {
        var parts: Parts = Parts(lit: false)
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let front: SIMD3<Double> = SIMD3(0, 0, 1)
        for k in stride(from: shells, through: 1, by: -1) {
            let weight: Double = pow(glowWeight, Double(k))
            let z: Double = bloomZ - glowLift * Double(k)
            for bloom in snapshot.blooms {
                let outline: [SIMD2<Double>] = headOutline(bloom, snapshot)
                guard !outline.isEmpty else { continue }
                let mean: SIMD2<Double> = outline.reduce(SIMD2<Double>(0, 0), +) / Double(outline.count)
                var grown: [SIMD3<Double>] = []
                for p in outline {
                    let q: SIMD2<Double> = mean + (p - mean) * (1 + glowGrowth * Double(k))
                    grown.append(SIMD3(q.x, q.y, z))
                }
                try parts.triangles(grown, earClip(bloom.kind), normal: front, uv: Vec2(weight, 0),
                                    slot: NocturneGardenPalette.glow)
            }
        }
        let centre: SIMD3<Double> = lantern(snapshot) - SIMD3(0, 0, lanternRadius + 0.002)
        let r: Double = lanternRadius * lanternGlowScale
        var disc: [SIMD3<Double>] = []
        for i in 0..<lanternGlowSegments {
            let a: Double = 2 * Double.pi * Double(i) / Double(lanternGlowSegments)
            disc.append(centre + SIMD3(cos(a) * r, sin(a) * r, 0))
        }
        try parts.polygon(disc, normal: front, uv: Vec2(glowWeight, 0), slot: NocturneGardenPalette.lantern)
        return parts.built()
    }

    /// The glow mesh (see ``glowPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowMesh(_ snapshot: NocturneGardenSceneSnapshot,
                                tier: NocturneGardenTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    // MARK: Camera

    /// `aspect` made usable: a non-finite or non-positive aspect becomes 1; others are clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// The radius of the bounding sphere about ``bedCentre(_:)``: the farthest corner of the box holding the bed
    /// widened by the largest head of the level's sizes (s·u left, 2·s·u right, 6·s·u above the top row's foot), the
    /// stems down to the ground, the extruded heads, the lantern sphere and the gauge bars.
    public static func boundingRadius(_ snapshot: NocturneGardenSceneSnapshot) -> Double {
        let u: Double = cellSize(snapshot)
        var largest: Int = NocturneGardenBloom.sizes.lowerBound
        for s in snapshot.sizes { largest = max(largest, min(s, NocturneGardenBloom.sizes.upperBound)) }
        for b in snapshot.blooms { largest = max(largest, min(b.size, NocturneGardenBloom.sizes.upperBound)) }
        let s: Double = Double(largest) * u
        let height: Double = Double(rows(snapshot)) * u
        let l: SIMD3<Double> = lantern(snapshot)
        let r: Double = lanternRadius
        let low: SIMD3<Double> = SIMD3(min(-bedHalfWidth - s, gaugeStart - gaugeMaxWidth),
                                       min(groundY, gaugeY - gaugeHalfHeight), 0)
        let high: SIMD3<Double> = SIMD3(max(bedHalfWidth + 2 * s, l.x + r),
                                        max(height - u + 6 * s, l.y + r), bloomZ + headDepth)
        let c: SIMD3<Double> = bedCentre(snapshot)
        var radius: Double = 0
        for corner in 0..<8 {
            let p: SIMD3<Double> = SIMD3(corner & 1 == 0 ? low.x : high.x, corner & 2 == 0 ? low.y : high.y,
                                         corner & 4 == 0 ? low.z : high.z)
            radius = max(radius, length(p - c))
        }
        return radius
    }

    /// The eye distance that fits a sphere of `radius` for `aspect` with ``fitMargin``: the sphere must lie in the cone
    /// of half-angle α around the view axis, tan α = (1 − 2 · margin) · min(tan(fovY/2), aspect · tan(fovY/2)), so the
    /// distance is radius / sin α.
    static func distance(radius: Double, aspect: Double) -> Double {
        let half: Double = tan(fieldOfView / 2)
        let limit: Double = (1 - 2 * fitMargin) * min(half, usableAspect(aspect) * half)
        return max(radius, 1e-3) / sin(atan(limit))
    }

    /// The fixed authored camera for `snapshot` and `aspect` (width / height): the eye on ``eyeDirection`` from the
    /// bed's centre (in front, +z, pitched 8° down) at the distance that fits ``boundingRadius(_:)``, looking at the
    /// bed's centre with +y up and a 45° vertical field of view. For aspects 0.4 … 2.5 the sphere projects inside the
    /// view with at least 5 % margin on every side. A zero, negative or non-finite aspect is treated as 1; others are
    /// clamped to 0.1 … 10. Depends only on the level (bed, sizes, sun's lantern height is inside the fit at every
    /// elevation it is drawn), never on the tier or the time. The camera of ``NocturneGardenOrbit/authored`` (see
    /// ``camera(_:aspect:orbit:)``).
    public static func camera(_ snapshot: NocturneGardenSceneSnapshot, aspect: Double) -> NocturneGardenCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The camera for `snapshot`, `aspect` (width / height) and `orbit` (clamped, see
    /// ``NocturneGardenOrbit/clamped()``): the eye on ``NocturneGardenOrbit/eyeDirection`` from the bed's centre at the
    /// distance that fits ``boundingRadius(_:)`` (the fit does not depend on the direction, so the 5 % margin holds at
    /// every orbit and aspect 0.4 … 2.5), looking at the bed's centre with +y up (never parallel to the view
    /// direction: the pitch is at most 30°) and a 45° vertical field of view. Aspects are made usable as in
    /// ``camera(_:aspect:)``; at ``NocturneGardenOrbit/authored`` the result equals ``camera(_:aspect:)`` bit for bit.
    /// Presentation only; independent of the tier, the time and the play's progress.
    public static func camera(_ snapshot: NocturneGardenSceneSnapshot, aspect: Double,
                              orbit: NocturneGardenOrbit) -> NocturneGardenCamera {
        let a: Double = usableAspect(aspect)
        let radius: Double = boundingRadius(snapshot)
        let d: Double = distance(radius: radius, aspect: a)
        let target: SIMD3<Double> = bedCentre(snapshot)
        let eye: SIMD3<Double> = target + orbit.eyeDirection * d
        let near: Double = max((d - radius) * 0.5, 1e-3)
        let far: Double = d + radius + 2 * groundHalfWidth + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(target), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return NocturneGardenCamera(eye: eye, target: target, fovY: fieldOfView, aspect: a, near: near, far: far,
                                    radius: radius, view: view, projection: projection,
                                    viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (origin top left, y down; multiply by the viewport size for pixels, the
    /// convention of `ScreenProjection`); nil behind the camera or for non-finite input. Points outside the view give
    /// coordinates outside 0 … 1.
    public static func project(_ point: SIMD3<Double>, camera: NocturneGardenCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    /// `point` in pixels of a `width` × `height` viewport (origin top left, y down); nil for a non-positive size,
    /// behind the camera or for non-finite input.
    public static func pixel(_ point: SIMD3<Double>, camera: NocturneGardenCamera, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0, let v = project(point, camera: camera) else { return nil }
        return Vec2(v.x * Double(width), v.y * Double(height))
    }

    /// The pixel box (min, max) of bloom `bloom`'s ``bloomBox(_:_:tier:)`` in a `width` × `height` viewport: the bounds
    /// of its eight projected corners; nil for an unknown bloom or when a corner does not project.
    public static func bloomPixelBox(_ bloom: Int, _ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier,
                                     camera: NocturneGardenCamera, width: Int,
                                     height: Int) -> (min: Vec2, max: Vec2)? {
        guard snapshot.blooms.indices.contains(bloom) else { return nil }
        let box = bloomBox(bloom, snapshot, tier: tier)
        var low: Vec2 = Vec2(Double.infinity, Double.infinity)
        var high: Vec2 = Vec2(-Double.infinity, -Double.infinity)
        for corner in 0..<8 {
            let p: SIMD3<Double> = SIMD3(corner & 1 == 0 ? box.min.x : box.max.x,
                                         corner & 2 == 0 ? box.min.y : box.max.y,
                                         corner & 4 == 0 ? box.min.z : box.max.z)
            guard let q = pixel(p, camera: camera, width: width, height: height) else { return nil }
            low = Vec2(min(low.x, q.x), min(low.y, q.y))
            high = Vec2(max(high.x, q.x), max(high.y, q.y))
        }
        return (low, high)
    }

    // MARK: Building

    /// The quad of `cell` at depth `z`, counter-clockwise seen from +z.
    static func cellQuad(_ cell: Int, _ snapshot: NocturneGardenSceneSnapshot, z: Double) -> [SIMD3<Double>] {
        let w: Int = columns(snapshot)
        let u: Double = cellSize(snapshot)
        let x0: Double = -bedHalfWidth + Double(cell % w) * u
        let y0: Double = Double(cell / w) * u
        return [SIMD3(x0, y0, z), SIMD3(x0 + u, y0, z), SIMD3(x0 + u, y0 + u, z), SIMD3(x0, y0 + u, z)]
    }

    /// The neighbour of `cell` across side `side` (0 bottom, 1 right, 2 top, 3 left); nil outside the bed.
    static func neighbour(_ cell: Int, side: Int, width: Int, height: Int) -> Int? {
        let c: Int = cell % width
        let r: Int = cell / width
        switch side {
        case 0: return r > 0 ? cell - width : nil
        case 1: return c + 1 < width ? cell + 1 : nil
        case 2: return r + 1 < height ? cell + width : nil
        default: return c > 0 ? cell - 1 : nil
        }
    }

    /// The edge of `cell` on side `side` (0 bottom, 1 right, 2 top, 3 left) at depth `z`: its ends in counter-clockwise
    /// order around the cell and the unit outward direction.
    static func edge(_ cell: Int, side: Int, _ snapshot: NocturneGardenSceneSnapshot,
                     z: Double) -> (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
        let q: [SIMD3<Double>] = cellQuad(cell, snapshot, z: z)
        switch side {
        case 0: return (q[0], q[1], SIMD3(0, -1, 0))
        case 1: return (q[1], q[2], SIMD3(1, 0, 0))
        case 2: return (q[2], q[3], SIMD3(0, 1, 0))
        default: return (q[3], q[0], SIMD3(-1, 0, 0))
        }
    }

    /// Adds the hatch of forbidden `cell`: one quad of the forbidden hatch material, shade 1 (the garden program draws
    /// the diagonal hatch from the world position).
    static func addHatch(_ cell: Int, _ snapshot: NocturneGardenSceneSnapshot,
                         to parts: inout Parts) throws(MeshError) {
        try parts.polygon(cellQuad(cell, snapshot, z: hatchZ), normal: SIMD3(0, 0, 1),
                          uv: Vec2(Material.forbiddenHatch, 1))
    }

    /// Adds one bloom: its stem of `depth` segments (joints from the foot's centre line down to the ground, inner
    /// joints bent ±0.15·s·u alternately) with a leaf pair at each segment's upper joint (z = 0.37), then its head: the
    /// back face (z = 0.35, facing −z), the side walls (outward), the front face (z = 0.39, facing +z).
    static func addBloom(_ bloom: NocturneGardenBloom, _ snapshot: NocturneGardenSceneSnapshot, depth: Int,
                         to parts: inout Parts) throws(MeshError) {
        typealias M = NocturneGardenSceneGeometry.Material
        let scale: Double = bloomScale(bloom, snapshot)
        let footPoint: SIMD2<Double> = foot(bloom, snapshot)
        let stemX: Double = footPoint.x + 0.5 * scale
        let topY: Double = footPoint.y
        let z: Double = bloomZ + headDepth / 2
        let front: SIMD3<Double> = SIMD3(0, 0, 1)
        var joints: [SIMD2<Double>] = []
        for j in 0...depth {
            let y: Double = topY + (groundY - topY) * Double(j) / Double(depth)
            let bend: Double = j == 0 || j == depth ? 0 : (j % 2 == 1 ? stemBend : -stemBend) * scale
            joints.append(SIMD2(stemX + bend, y))
        }
        let halfWidth: Double = stemHalfWidth * scale
        for k in 0..<depth {
            let a: SIMD2<Double> = joints[k]
            let b: SIMD2<Double> = joints[k + 1]
            try parts.polygon([SIMD3(b.x - halfWidth, b.y, z), SIMD3(b.x + halfWidth, b.y, z),
                               SIMD3(a.x + halfWidth, a.y, z), SIMD3(a.x - halfWidth, a.y, z)],
                              normal: front, uv: Vec2(M.leafStem, 1))
            let m: SIMD2<Double> = a
            let length: Double = leafLength * scale
            for direction in [-1.0, 1.0] {
                let base: SIMD3<Double> = SIMD3(m.x, m.y, z)
                let tip: SIMD3<Double> = base + SIMD3(direction * length, leafRise * length, 0)
                let axis: SIMD3<Double> = tip - base
                let across: SIMD3<Double> = unit(SIMD3(-axis.y, axis.x, 0)) * (leafHalfWidth * length)
                let middle: SIMD3<Double> = base + axis * 0.5
                try parts.polygon([base, middle - across, tip, middle + across], normal: front,
                                  uv: Vec2(M.leafStem, 1))
            }
        }
        let outline: [SIMD2<Double>] = headOutline(bloom, snapshot)
        let triangles: [Int] = earClip(bloom.kind)
        let back: [SIMD3<Double>] = outline.map { SIMD3($0.x, $0.y, bloomZ) }
        let face: [SIMD3<Double>] = outline.map { SIMD3($0.x, $0.y, bloomZ + headDepth) }
        try parts.triangles(back, triangles, normal: -front, uv: Vec2(M.bloomBody, 1))
        for i in outline.indices {
            let j: Int = (i + 1) % outline.count
            let d: SIMD2<Double> = outline[j] - outline[i]
            let out: SIMD3<Double> = unit(SIMD3(d.y, -d.x, 0))
            guard out != .zero else { continue }
            try parts.polygon([back[i], back[j], face[j], face[i]], normal: out, uv: Vec2(M.headRim, 1))
        }
        try parts.triangles(face, triangles, normal: front, uv: Vec2(M.bloomBody, 1))
    }

    /// Adds the lantern: a UV sphere of ``lanternRadius`` with ``lanternStacks`` × ``lanternSlices`` faces about
    /// `centre`, outward normals.
    static func addLantern(_ centre: SIMD3<Double>, to parts: inout Parts) throws(MeshError) {
        let uv: Vec2 = Vec2(Material.lantern, 1)
        func point(_ stack: Int, _ slice: Int) -> SIMD3<Double> {
            let theta: Double = Double.pi * Double(stack) / Double(lanternStacks)
            let phi: Double = 2 * Double.pi * Double(slice) / Double(lanternSlices)
            return SIMD3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
        }
        for stack in 0..<lanternStacks {
            for slice in 0..<lanternSlices {
                let n00: SIMD3<Double> = point(stack, slice)
                let n01: SIMD3<Double> = point(stack, slice + 1)
                let n10: SIMD3<Double> = point(stack + 1, slice)
                let n11: SIMD3<Double> = point(stack + 1, slice + 1)
                let ns: [SIMD3<Double>] = [n00, n10, n11, n01]
                var ids: [UInt32] = []
                for n in ns { ids.append(try parts.vertex(centre + n * lanternRadius, slot: n, uv: uv)) }
                let outward: SIMD3<Double> = unit(n00 + n01 + n10 + n11)
                let p: [SIMD3<Double>] = ns.map { centre + $0 * lanternRadius }
                if stack != 0 {
                    try parts.facing(ids[0], ids[1], ids[3], p[0], p[1], p[3], front: outward)
                }
                if stack != lanternStacks - 1 {
                    try parts.facing(ids[1], ids[2], ids[3], p[1], p[2], p[3], front: outward)
                }
            }
        }
    }

    /// The triangles (index triples into `kind.outline`) of the outline by ear clipping on the exact lattice:
    /// repeatedly the first remaining vertex (from the start of the remaining list) that is strictly convex with no
    /// other remaining vertex inside or on its triangle is cut off; if none qualifies (a degenerate remainder), the
    /// first strictly convex vertex, else the first vertex. Deterministic; n − 2 triangles for n vertices.
    public static func earClip(_ kind: NocturneGardenKind) -> [Int] {
        let p: [NocturneGardenLattice] = kind.outline
        var remaining: [Int] = Array(p.indices)
        var result: [Int] = []
        func cross(_ a: NocturneGardenLattice, _ b: NocturneGardenLattice, _ c: NocturneGardenLattice) -> Int {
            (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        while remaining.count > 3 {
            let n: Int = remaining.count
            var chosen: Int?
            var convex: Int?
            for k in 0..<n {
                let a: NocturneGardenLattice = p[remaining[(k + n - 1) % n]]
                let b: NocturneGardenLattice = p[remaining[k]]
                let c: NocturneGardenLattice = p[remaining[(k + 1) % n]]
                guard cross(a, b, c) > 0 else { continue }
                if convex == nil { convex = k }
                var clear: Bool = true
                for m in 0..<n where m != k && m != (k + n - 1) % n && m != (k + 1) % n {
                    let q: NocturneGardenLattice = p[remaining[m]]
                    if cross(a, b, q) >= 0 && cross(b, c, q) >= 0 && cross(c, a, q) >= 0 {
                        clear = false
                        break
                    }
                }
                if clear {
                    chosen = k
                    break
                }
            }
            let k: Int = chosen ?? convex ?? 0
            result.append(contentsOf: [remaining[(k + n - 1) % n], remaining[k], remaining[(k + 1) % n]])
            remaining.remove(at: k)
        }
        if remaining.count == 3 { result.append(contentsOf: remaining) }
        return result
    }

    /// A mesh builder with its colour stream: a colour is recorded for every new vertex (a welded vertex keeps its
    /// first colour; the colour is a function of the normal slot and uv, so welded vertices agree).
    struct Parts {
        var builder: MeshBuilder = MeshBuilder()
        var colours: [Vec4] = []
        /// True for the garden (real normals, colour from the material code); false for the glow (colour slot).
        let lit: Bool

        init(lit: Bool) { self.lit = lit }

        /// The unlit fallback colour of a vertex with `slot` in the normal stream and `uv`: on the garden the material
        /// colour times the shade (on the shadow the mist mixed toward the shadow by the cover), lit materials through
        /// `NocturneGardenShaders.gardenShade`, emissive ones through `emissiveShade`, the flat bed layers and the
        /// ground unlit; on the glow the slot colour times the weight.
        func colour(slot: SIMD3<Double>, uv: Vec2) -> SIMD3<Double> {
            guard lit else { return slot * min(max(uv.x, 0), 1) }
            let shade: Double = uv.y.isFinite ? min(max(uv.y, 0), 1) : 1
            let code: Int = uv.x.isFinite ? Int(uv.x.rounded()) : 0
            let material: NocturneGardenShaders.GardenMaterial = .init(rawValue: code) ?? .ground
            let n: Double = NocturneGardenSceneGeometry.dot(slot, lightDirection)
            switch material {
            case .shadow:
                return NocturneGardenPalette.mist * (1 - shade) + NocturneGardenPalette.shadow * shade
            case .ground, .mist, .targetRim, .forbiddenHatch, .leakCross, .spentBar, .unspentBar, .preview:
                return material.colour * shade
            case .bloomBody, .leafStem:
                return NocturneGardenShaders.gardenShade(base: material.colour * shade, normalDotLight: n)
            case .lantern, .headRim:
                return NocturneGardenShaders.emissiveShade(base: material.colour * shade, normalDotLight: n)
            }
        }

        /// Adds one vertex and returns its index.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, uv: Vec2) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(NocturneGardenSceneGeometry.vec(p),
                                                normal: NocturneGardenSceneGeometry.vec(slot), uv: uv)
            if Int(id) == colours.count {
                let c: SIMD3<Double> = colour(slot: slot, uv: uv)
                colours.append(Vec4(min(max(c.x, 0), 1), min(max(c.y, 0), 1), min(max(c.z, 0), 1), 1))
            }
            return id
        }

        /// Adds a planar convex polygon as a fan from its first corner, wound counter-clockwise seen from the side of
        /// `normal`; `slot` (default: the unit `normal`) goes in the normal stream.
        mutating func polygon(_ p: [SIMD3<Double>], normal: SIMD3<Double>, uv: Vec2,
                              slot: SIMD3<Double>? = nil) throws(MeshError) {
            guard p.count >= 3 else { return }
            var fan: [Int] = []
            for k in 1..<(p.count - 1) { fan.append(contentsOf: [0, k, k + 1]) }
            try triangles(p, fan, normal: normal, uv: uv, slot: slot)
        }

        /// Adds the triangles `indices` (triples into `p`), each wound counter-clockwise seen from the side of
        /// `normal`.
        mutating func triangles(_ p: [SIMD3<Double>], _ indices: [Int], normal: SIMD3<Double>, uv: Vec2,
                                slot: SIMD3<Double>? = nil) throws(MeshError) {
            let s: SIMD3<Double> = slot ?? NocturneGardenSceneGeometry.unit(normal)
            var ids: [UInt32] = []
            for point in p { ids.append(try vertex(point, slot: s, uv: uv)) }
            var t: Int = 0
            while t + 2 < indices.count {
                let a: Int = indices[t]
                let b: Int = indices[t + 1]
                let c: Int = indices[t + 2]
                t += 3
                guard p.indices.contains(a), p.indices.contains(b), p.indices.contains(c) else { continue }
                try facing(ids[a], ids[b], ids[c], p[a], p[b], p[c], front: normal)
            }
        }

        /// Adds a quad (convex, 4 corners) whose corners carry their own shades of material `code`.
        mutating func quad(_ p: [SIMD3<Double>], shades: [Double], normal: SIMD3<Double>,
                           code: Double) throws(MeshError) {
            guard p.count == 4, shades.count == 4 else { return }
            let s: SIMD3<Double> = NocturneGardenSceneGeometry.unit(normal)
            var ids: [UInt32] = []
            for k in 0..<4 { ids.append(try vertex(p[k], slot: s, uv: Vec2(code, shades[k]))) }
            try facing(ids[0], ids[1], ids[2], p[0], p[1], p[2], front: normal)
            try facing(ids[0], ids[2], ids[3], p[0], p[2], p[3], front: normal)
        }

        /// Adds a flat bar (rectangle) about `centre`, `halfLength` along `along` and `halfWidth` along `across`,
        /// facing `normal`.
        mutating func bar(centre: SIMD3<Double>, along: SIMD3<Double>, across: SIMD3<Double>, halfLength: Double,
                          halfWidth: Double, normal: SIMD3<Double>, uv: Vec2) throws(MeshError) {
            let a: SIMD3<Double> = along * halfLength
            let b: SIMD3<Double> = across * halfWidth
            try polygon([centre - a - b, centre + a - b, centre + a + b, centre - a + b], normal: normal, uv: uv)
        }

        /// Adds triangle a, b, c wound so its geometric normal points along `front`.
        mutating func facing(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            if NocturneGardenSceneGeometry.dot(NocturneGardenSceneGeometry.cross(pb - pa, pc - pa), front) < 0 {
                try builder.triangle(a, c, b)
            } else {
                try builder.triangle(a, b, c)
            }
        }

        /// The coloured mesh built so far.
        func built() -> NocturneGardenColouredMesh {
            NocturneGardenColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` normalized, or zero when its length is zero or not finite.
    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let l: Double = length(v)
        return l > 1e-15 && l.isFinite ? v / l : .zero
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }

    /// The dot product of `a` and `b`.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { (a * b).sum() }

    /// The cross product `a` × `b`.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// The Euclidean length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { dot(v, v).squareRoot() }
}
