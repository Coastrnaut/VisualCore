// ChronoConstellatorSceneGeometry — feature 353 (R02-G06-03) T-R02G0603-004 (FR-R02G0603-001, 002, 006;
// SC-R02G0603-001; clarifications Q1–Q3; research R1–R4). The sky of Chrono Constellator, built from a snapshot only: the
// grid lies in the xz-plane with cell size u = 2 / max(columns, rows), column c at x = (c − (columns − 1)/2)·u and row r at
// z = (r − (rows − 1)/2)·u (higher rows nearer the camera), y up. The field is an indigo plane at y = 0 with faint grid
// lines; each star's loop is a silver track (width 0.08·u, y = 0.004·u) through its cells' centres; each star is a
// glowing node (radius 0.3·u, centre y = 0.25·u) carrying its shape (ring, cross, diamond, triangle, square); each target
// is a rose ring (outer radius 0.42·u, y = 0.006·u) with its star's shape inside, lit when the star stands on it. Each
// star's history ribbon joins its cells over the tier's last R ticks, each point raised 0.04·u per tick of age above the
// node height, alpha 1 − age / R, `segments` pieces per tick and `glowShells` wider shells; holds are short vertical bars
// at the held cell; a collision cell gets an amber cross. The fixed authored camera looks at the grid centre from the
// front (+z), pitched 55° down, fitted to the bounding sphere about the grid centre (y = 0) whose radius is the distance
// to the farthest corner of the grid at the ribbons' full height (node height + 24 · 0.04·u) plus 0.1, with a 5 % margin
// for every aspect 0.4 … 2.5; the CPU projection is the reference that the simulator frame checks compare with rendered
// pixels. Stars, targets, tracks, marks and the camera are the same at every tier; only the ribbons change. Doubles are
// used for drawing only; nothing here is consulted by the rules.
//
// Feature 354 (R02-G06-04) T-R02G0604-002 (FR-R02G0604-005; SC-R02G0604-004; research R5, R6): the orbit
// (`ChronoConstellatorOrbit`: yaw ±40° about +y, pitch 30° … 75° down from the horizon, authored yaw 0 and pitch 55°)
// and `camera(_:aspect:orbit:)`, which refits the same bounding sphere so the 5 % margin holds at every orbit; the
// authored camera is the authored orbit's camera, bit for bit. `candidatePart(_:_:)` is the pearl ring that outlines
// the candidate cell of a star drag: a thin square ring drawn by the field program with the track material.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of the Chrono Constellator scene for one snapshot and aspect.
///
/// Built only by ``ChronoConstellatorSceneGeometry/camera(_:aspect:orbit:)`` (and ``camera(_:aspect:)``, its authored
/// orbit). World positions are in grid units (the grid's
/// longer side is 2); ``viewProjection`` maps them to GL clip space (right-handed, depth −1 … 1).
public struct ChronoConstellatorCamera: Sendable, Equatable {
    /// The eye position in world units.
    public let eye: SIMD3<Double>
    /// The point looked at: the grid centre (the origin).
    public let target: SIMD3<Double>
    /// The vertical field of view in radians.
    public let fovY: Double
    /// The aspect ratio (width / height) the camera was fitted for, after clamping to 0.1 … 10 (1 when unusable).
    public let aspect: Double
    /// The near clip distance.
    public let near: Double
    /// The far clip distance.
    public let far: Double
    /// The radius of the bounding sphere the camera was fitted to.
    public let radius: Double
    /// The view matrix: `Mat4.lookAt` from ``eye`` to ``target`` with +y up.
    public let view: Mat4
    /// The projection matrix: `Mat4.perspective` (GL depth range).
    public let projection: Mat4
    /// ``projection`` times ``view``.
    public let viewProjection: Mat4
}

/// The orbit of the Chrono Constellator camera: a yaw about the vertical axis and a pitch down from the horizon, both
/// in radians (feature 354). Presentation only: never in the digest, the snapshot or the kernel, and not saved.
///
/// ``ChronoConstellatorSceneGeometry/camera(_:aspect:orbit:)`` uses the ``clamped()`` orbit, so the eye always stays in
/// front of the grid and above it (no vertical singularity) and the whole sky stays in view.
public struct ChronoConstellatorOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians: the angle of the eye direction above the horizon (the view looks down by it); allowed
    /// ``pitchRange`` (30° … 75°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 55° (``ChronoConstellatorSceneGeometry/pitch``), the fixed camera of
    /// R02-G06-03.
    public static let authored = ChronoConstellatorOrbit(yaw: 0, pitch: ChronoConstellatorSceneGeometry.pitch)
    /// The largest yaw either way, 40° in radians.
    public static let yawLimit: Double = 40.0 * Double.pi / 180
    /// The allowed pitches, 30° … 75° in radians.
    public static let pitchRange: ClosedRange<Double> = (30.0 * Double.pi / 180)...(75.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −40° … 40° and pitch to 30° … 75°; a non-finite angle becomes the authored one.
    public func clamped() -> ChronoConstellatorOrbit {
        let y: Double = yaw.isFinite ? yaw : Self.authored.yaw
        let p: Double = pitch.isFinite ? pitch : Self.authored.pitch
        return ChronoConstellatorOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                       pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// The unit direction from the grid centre to the eye at the clamped orbit: (sin y · cos p, sin p, cos y · cos p)
    /// with y the yaw and p the pitch; exactly ``ChronoConstellatorSceneGeometry/eyeDirection`` at ``authored``.
    public var eyeDirection: SIMD3<Double> {
        let o: ChronoConstellatorOrbit = clamped()
        return SIMD3(sin(o.yaw) * cos(o.pitch), sin(o.pitch), cos(o.yaw) * cos(o.pitch))
    }
}

/// A mesh with one colour per vertex (sRGB RGBA 0 … 1, alpha 1), aligned with `mesh.positions`.
///
/// The colours feed the shared unlit mesh renderer of the fallback path (the shader programs have no colour stream; they
/// read the same information from the normal and uv streams, see ``ChronoConstellatorSceneGeometry``).
public struct ChronoConstellatorColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh`, in vertex order.
    public let colours: [Vec4]
}

/// The geometry of the Chrono Constellator scene: cell places, the field with its grid lines, loop tracks, target rings,
/// hold bars and the collision cross, the glowing star nodes, lit target rings and history ribbons, camera and projection.
///
/// **Vertex streams** (the contract with `ChronoConstellatorShaders`; attributes a_position, a_normal, a_uv as bound by
/// `ShaderMeshRenderer`; positions are world units, identity model).
/// - ``fieldMesh(_:tier:)`` — field program: `a_normal` the real unit normal (+y on flat elements, ±z on the two-sided
///   hold bars); `a_uv` (material code, shade) with codes ``fieldCode`` 0 (indigo plane), ``gridCode`` 1 (grid lines),
///   ``trackCode`` 2 (silver tracks and hold bars), ``roseCode`` 4 (target rings and their shapes) and ``amberCode`` 5
///   (collision cross); shade 1, or ``unlit`` 0.5 for a target ring whose star stands elsewhere and an inactive hold.
/// - ``glowMesh(_:tier:)`` = ``starMesh(_:tier:)`` + ``ribbonMesh(_:tier:)`` — glow program: `a_normal` the colour
///   (sRGB 0 … 1); `a_uv` (age in ticks, glow weight 0 … 1). Star nodes and lit target rings have age 0 and weight 1;
///   ribbon points carry their (fractional) age, the shader computing alpha 1 − age / R (the CPU twin is
///   ``ribbonAlpha(age:tier:)``), and weight 1 on the core, 0.5^k on glow shell k.
/// ``ChronoConstellatorColouredMesh/colours`` gives each vertex's unlit colour for the fallback: the material colour
/// times the shade on the field, the stream colour on stars, and rose times ``ribbonAlpha(age:tier:)`` on ribbons.
///
/// Every element faces up (+y) except hold bars, which are two-sided, and ribbon pieces over a held tick, which stand
/// vertical facing the camera (+z). The field and star meshes and the camera are identical at every tier; tiers change
/// only the ribbons (length R, segments per tick, glow shells).
public enum ChronoConstellatorSceneGeometry {
    // MARK: Constants (lengths in cells u unless stated)

    /// The field material code of the indigo plane, 0.
    public static let fieldCode = 0.0
    /// The field material code of the faint grid lines, 1.
    public static let gridCode = 1.0
    /// The field material code of the silver loop tracks and hold bars, 2.
    public static let trackCode = 2.0
    /// The field material code of the star colour, 3 (reserved by the shader contract; the nodes use the glow program).
    public static let starCode = 3.0
    /// The field material code of the rose target rings and their shapes, 4.
    public static let roseCode = 4.0
    /// The field material code of the amber collision cross, 5.
    public static let amberCode = 5.0
    /// The colour of field material `code` (0 … 5; the field colour for any other code).
    public static func materialColour(_ code: Double) -> SIMD3<Double> {
        switch Int(code.isFinite ? code.rounded() : 0) {
        case 1: ChronoConstellatorPalette.grid
        case 2: ChronoConstellatorPalette.silver
        case 3: ChronoConstellatorPalette.star
        case 4: ChronoConstellatorPalette.rose
        case 5: ChronoConstellatorPalette.amber
        default: ChronoConstellatorPalette.field
        }
    }
    /// The height of a lit target ring's glow copy above the field, 0.008 · u.
    public static let glowRingLift = 0.008
    /// The glow weight of ribbon glow shell k is shellWeight^k (0.5); the core has weight 1.
    public static let shellWeight = 0.5
    /// The width of a grid line, 0.02 · u.
    public static let gridWidth = 0.02
    /// The height of the grid lines above the field, 0.002 · u.
    public static let gridLift = 0.002
    /// The width of a loop track, 0.08 · u.
    public static let trackWidth = 0.08
    /// The height of the loop tracks above the field, 0.004 · u.
    public static let trackLift = 0.004
    /// The radius of a star node, 0.3 · u.
    public static let nodeRadius = 0.3
    /// The height of a star node's centre, 0.25 · u.
    public static let nodeHeight = 0.25
    /// The brightness of a star node's disc (its shape is drawn on it at full brightness), 0.4.
    public static let nodeDisc = 0.4
    /// The radius of the shape drawn on a star node, 0.24 · u.
    public static let nodeShapeRadius = 0.24
    /// The stroke width of the shape drawn on a star node, 0.07 · u.
    public static let nodeShapeWidth = 0.07
    /// The height of the shape above its node's disc, 0.002 · u.
    public static let shapeLift = 0.002
    /// The outer radius of a target ring, 0.42 · u.
    public static let targetOuter = 0.42
    /// The inner radius of a target ring, 0.34 · u.
    public static let targetInner = 0.34
    /// The height of the target rings above the field, 0.006 · u.
    public static let targetLift = 0.006
    /// The radius of the star's shape inside its target ring, 0.22 · u.
    public static let targetShapeRadius = 0.22
    /// The stroke width of the shape inside a target ring, 0.05 · u.
    public static let targetShapeWidth = 0.05
    /// The brightness of a target ring whose star stands elsewhere (a lit ring has brightness 1), 0.5.
    public static let unlit = 0.5
    /// The segments of a full circle (discs, rings, ring shapes), 32.
    public static let circleSegments = 32
    /// The rise of a history ribbon point per tick of age, 0.04 · u.
    public static let ribbonRise = 0.04
    /// The half-width of a ribbon's core, 0.05 · u; glow shell k has half-width 0.05 · (1 + k) · u.
    public static let ribbonHalfWidth = 0.05
    /// How far each glow shell lies below the previous one (to avoid coplanar fighting), 0.002 · u.
    public static let shellDrop = 0.002
    /// The height of a hold bar, 0.5 · u (from the field up).
    public static let holdHeight = 0.5
    /// The width of a hold bar, 0.06 · u.
    public static let holdWidth = 0.06
    /// The height of the collision cross, 0.27 · u (just above the star nodes).
    public static let collisionLift = 0.27
    /// The half-length of each arm of the collision cross, 0.4 · u.
    public static let collisionRadius = 0.4
    /// The stroke width of the collision cross, 0.08 · u.
    public static let collisionWidth = 0.08
    /// The added radius of the bounding sphere, 0.1 world units.
    public static let boundingPad = 0.1
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's pitch below the horizon in radians (55°).
    public static let pitch = 55.0 * Double.pi / 180
    /// The unit direction from the grid centre to the eye: (0, sin 55°, cos 55°) — in front (+z), above.
    public static let eyeDirection = SIMD3<Double>(0, sin(pitch), cos(pitch))
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places

    /// The cell size u = 2 / max(columns, rows).
    public static func cellSize(_ snapshot: ChronoConstellatorSceneSnapshot) -> Double {
        2 / Double(max(snapshot.columns, snapshot.rows, 1))
    }

    /// The centre of `cell` at y = 0: x = (c − (columns − 1)/2)·u, z = (r − (rows − 1)/2)·u for column c and row r; the
    /// origin for a cell outside the grid.
    public static func cellCentre(_ cell: Int, _ snapshot: ChronoConstellatorSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.columns > 0, snapshot.rows > 0, (0..<(snapshot.columns * snapshot.rows)).contains(cell) else {
            return .zero
        }
        let u: Double = cellSize(snapshot)
        let column: Double = Double(cell % snapshot.columns)
        let row: Double = Double(cell / snapshot.columns)
        return SIMD3((column - Double(snapshot.columns - 1) / 2) * u, 0, (row - Double(snapshot.rows - 1) / 2) * u)
    }

    /// The centre of star `star`'s node: its current cell's centre at y = 0.25·u; the origin for an unknown star.
    public static func starCentre(_ star: Int, _ snapshot: ChronoConstellatorSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.stars.indices.contains(star) else { return .zero }
        return cellCentre(snapshot.stars[star].cell, snapshot) + SIMD3(0, nodeHeight * cellSize(snapshot), 0)
    }

    /// The centre of star `star`'s target ring: its target cell's centre at y = 0.006·u; the origin for an unknown star.
    public static func targetCentre(_ star: Int, _ snapshot: ChronoConstellatorSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.stars.indices.contains(star) else { return .zero }
        return cellCentre(snapshot.stars[star].target, snapshot) + SIMD3(0, targetLift * cellSize(snapshot), 0)
    }

    /// The shape of star `star`: star i has shape i (ring, cross, diamond, triangle, square; clamped to 0 … 4).
    public static func shape(_ star: Int) -> ChronoConstellatorShape {
        ChronoConstellatorShape(rawValue: min(max(star, 0), ChronoConstellatorShape.allCases.count - 1)) ?? .ring
    }

    /// The cell on which `hold` keeps its star: the star's cell at the hold's first tick, loop[(φ + start − h) mod L]
    /// with h the held ticks through the start (the kernel's position rule); nil for an unknown star or an empty loop.
    public static func heldCell(_ hold: ChronoConstellatorHold, _ snapshot: ChronoConstellatorSceneSnapshot) -> Int? {
        guard snapshot.stars.indices.contains(hold.star), snapshot.phases.indices.contains(hold.star) else { return nil }
        let loop: [Int] = snapshot.stars[hold.star].loop
        guard !loop.isEmpty else { return nil }
        var held: Int = 0
        for other in snapshot.holds where other.star == hold.star && other.start <= hold.start {
            held += min(other.end, hold.start) - other.start + 1
        }
        let step: Int = snapshot.phases[hold.star] + hold.start - held
        return loop[((step % loop.count) + loop.count) % loop.count]
    }

    /// Whether `hold` is in force at the snapshot's tick (start ≤ tick ≤ end).
    public static func isActive(_ hold: ChronoConstellatorHold, _ snapshot: ChronoConstellatorSceneSnapshot) -> Bool {
        hold.start <= snapshot.tick && snapshot.tick <= hold.end
    }

    /// The alpha of a ribbon point `age` ticks old for `tier`: 1 − age / R with R = `tier.ribbonTicks`, clamped to 0 … 1
    /// (0 for a non-finite age).
    public static func ribbonAlpha(age: Double, tier: ChronoConstellatorTier) -> Double {
        guard age.isFinite else { return 0 }
        return min(max(1 - age / Double(max(tier.ribbonTicks, 1)), 0), 1)
    }

    /// The highest y of any element: the ribbons at their full height, node height + 24 · 0.04 (times u), above the
    /// hold bars (0.5·u) and the nodes; the same at every tier so the camera never moves with the tier.
    public static func tallest(_ snapshot: ChronoConstellatorSceneSnapshot) -> Double {
        let ribbon: Double = nodeHeight + Double(ChronoConstellatorTier.historyTicks) * ribbonRise
        return max(ribbon, holdHeight, collisionLift) * cellSize(snapshot)
    }

    /// The radius of the scene's bounding sphere about the grid centre (y = 0): the distance to the farthest corner
    /// (±columns·u/2, ``tallest(_:)``, ±rows·u/2), plus 0.1. Every vertex of every mesh lies inside the box of that
    /// corner, so at least 0.1 inside the sphere.
    public static func boundingRadius(_ snapshot: ChronoConstellatorSceneSnapshot) -> Double {
        let u: Double = cellSize(snapshot)
        let halfWidth: Double = Double(max(snapshot.columns, 1)) * u / 2
        let halfDepth: Double = Double(max(snapshot.rows, 1)) * u / 2
        let y: Double = tallest(snapshot)
        return (halfWidth * halfWidth + halfDepth * halfDepth + y * y).squareRoot() + boundingPad
    }

    // MARK: Meshes

    /// The field (field program, real normals, uv (material code, shade)): the indigo plane over the whole grid at y = 0
    /// (code 0); the faint grid lines on every cell boundary (width 0.02·u, y = 0.002·u, code 1); each star's loop as
    /// silver bars between consecutive cell centres, the last back to the first, with a square joint on every loop cell
    /// (width 0.08·u, y = 0.004·u, code 2); every target's rose ring (radius 0.34 … 0.42·u, y = 0.006·u) with its star's
    /// shape inside (radius 0.22·u), code 4, shade 1 when the star stands on it and 0.5 otherwise; every hold as a
    /// two-sided vertical bar (0.5·u tall, 0.06·u wide) at its held cell, code 2, shade 1 while active and 0.5 otherwise;
    /// and, when the play failed by a collision, an amber diagonal cross (arms 0.4·u, width 0.08·u) at y = 0.27·u on the
    /// collision cell, code 5; and the current-tick mark, a silver bar (code 2, width 0.04·u, centred 0.04·u inside the
    /// near edge at y = 0.004·u) from the left edge for ``tickBarLength(_:)``. Colours: ``materialColour(_:)`` times the
    /// shade. The same at every tier.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func fieldPart(_ snapshot: ChronoConstellatorSceneSnapshot,
                                 tier: ChronoConstellatorTier) throws(MeshError) -> ChronoConstellatorColouredMesh {
        var parts: Parts = Parts()
        let u: Double = cellSize(snapshot)
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        let columns: Int = max(snapshot.columns, 1)
        let rows: Int = max(snapshot.rows, 1)
        let halfWidth: Double = Double(columns) * u / 2
        let halfDepth: Double = Double(rows) * u / 2
        try parts.quad([SIMD3(-halfWidth, 0, -halfDepth), SIMD3(halfWidth, 0, -halfDepth),
                        SIMD3(halfWidth, 0, halfDepth), SIMD3(-halfWidth, 0, halfDepth)],
                       slot: up, front: up, uv: Vec2(fieldCode, 1), colour: materialColour(fieldCode))
        let gridY: Double = gridLift * u
        let g: Double = gridWidth * u / 2
        let gridUV: Vec2 = Vec2(gridCode, 1)
        for c in 0...columns {
            let x: Double = min(max(-halfWidth + Double(c) * u, -halfWidth + g), halfWidth - g)
            try parts.quad([SIMD3(x - g, gridY, -halfDepth), SIMD3(x + g, gridY, -halfDepth),
                            SIMD3(x + g, gridY, halfDepth), SIMD3(x - g, gridY, halfDepth)],
                           slot: up, front: up, uv: gridUV, colour: materialColour(gridCode))
        }
        for r in 0...rows {
            let z: Double = min(max(-halfDepth + Double(r) * u, -halfDepth + g), halfDepth - g)
            try parts.quad([SIMD3(-halfWidth, gridY, z - g), SIMD3(halfWidth, gridY, z - g),
                            SIMD3(halfWidth, gridY, z + g), SIMD3(-halfWidth, gridY, z + g)],
                           slot: up, front: up, uv: gridUV, colour: materialColour(gridCode))
        }
        let trackY: Double = trackLift * u
        let trackUV: Vec2 = Vec2(trackCode, 1)
        let silver: SIMD3<Double> = materialColour(trackCode)
        for star in snapshot.stars {
            let loop: [Int] = star.loop
            for (k, cell) in loop.enumerated() {
                let a: SIMD3<Double> = cellCentre(cell, snapshot) + SIMD3(0, trackY, 0)
                try parts.square(centre: a, half: trackWidth * u / 2, slot: up, uv: trackUV, colour: silver)
                guard loop.count > 1 else { continue }
                let b: SIMD3<Double> = cellCentre(loop[(k + 1) % loop.count], snapshot) + SIMD3(0, trackY, 0)
                try parts.bar(from: a, to: b, width: trackWidth * u, slot: up, uv: trackUV, colour: silver)
            }
        }
        for index in snapshot.stars.indices {
            let shade: Double = snapshot.stars[index].onTarget ? 1 : unlit
            let uv: Vec2 = Vec2(roseCode, shade)
            let colour: SIMD3<Double> = materialColour(roseCode) * shade
            let centre: SIMD3<Double> = targetCentre(index, snapshot)
            try parts.annulus(centre: centre, inner: targetInner * u, outer: targetOuter * u,
                              segments: circleSegments, slot: up, uv: uv, colour: colour)
            try parts.shape(shape(index), centre: centre + SIMD3(0, shapeLift * u / 2, 0),
                            radius: targetShapeRadius * u, width: targetShapeWidth * u, slot: up, uv: uv,
                            colour: colour)
        }
        for hold in snapshot.holds {
            guard let cell = heldCell(hold, snapshot) else { continue }
            let shade: Double = isActive(hold, snapshot) ? 1 : unlit
            let uv: Vec2 = Vec2(trackCode, shade)
            let base: SIMD3<Double> = cellCentre(cell, snapshot)
            let w: Double = holdWidth * u / 2
            let top: Double = holdHeight * u
            let p: [SIMD3<Double>] = [base + SIMD3(-w, 0, 0), base + SIMD3(w, 0, 0), base + SIMD3(w, top, 0),
                                      base + SIMD3(-w, top, 0)]
            for side in [1.0, -1.0] {
                let normal: SIMD3<Double> = SIMD3(0, 0, side)
                try parts.quad(p, slot: normal, front: normal, uv: uv, colour: silver * shade)
            }
        }
        let progress: Double = tickBarLength(snapshot)
        if progress > 0 {
            let z: Double = halfDepth - tickBarInset * u
            let w: Double = tickBarWidth * u / 2
            let y: Double = trackY
            try parts.quad([SIMD3(-halfWidth, y, z - w), SIMD3(-halfWidth + progress, y, z - w),
                            SIMD3(-halfWidth + progress, y, z + w), SIMD3(-halfWidth, y, z + w)],
                           slot: up, front: up, uv: trackUV, colour: silver)
        }
        if case .collision(_, _, let cell) = snapshot.failure {
            let centre: SIMD3<Double> = cellCentre(cell, snapshot) + SIMD3(0, collisionLift * u, 0)
            let r: Double = collisionRadius * u / 2.0.squareRoot()
            let uv: Vec2 = Vec2(amberCode, 1)
            let colour: SIMD3<Double> = materialColour(amberCode)
            try parts.bar(from: centre + SIMD3(-r, 0, -r), to: centre + SIMD3(r, 0, r), width: collisionWidth * u,
                          slot: up, uv: uv, colour: colour)
            try parts.bar(from: centre + SIMD3(-r, 0, r), to: centre + SIMD3(r, 0, -r), width: collisionWidth * u,
                          slot: up, uv: uv, colour: colour)
        }
        return parts.built()
    }

    /// The distance of the current-tick mark's centre line from the field's near edge, in cells (feature 353, converge
    /// T-R02G0603-014): with its width it spans 0.02 … 0.06·u, clear of the target rings, which end 0.08·u from the edge.
    public static let tickBarInset: Double = 0.04
    /// The width of the current-tick mark, in cells.
    public static let tickBarWidth: Double = 0.04

    /// The length of the current-tick mark: tick / tickLimit of the grid's width (columns·u), clamped to 0 … the width;
    /// 0 at tick 0 or with a non-positive limit. The same at every tier.
    public static func tickBarLength(_ snapshot: ChronoConstellatorSceneSnapshot) -> Double {
        guard snapshot.tickLimit > 0 else { return 0 }
        let width: Double = Double(max(snapshot.columns, 1)) * cellSize(snapshot)
        let fraction: Double = min(max(Double(snapshot.tick) / Double(snapshot.tickLimit), 0), 1)
        return width * fraction
    }

    /// The inset of the candidate ring from its cell's edges, 0.08 · u (feature 354, research R6).
    public static let candidateInset: Double = 0.08
    /// The width of the candidate ring's stroke, 0.06 · u.
    public static let candidateWidth: Double = 0.06
    /// The height of the candidate ring above the field, 0.01 · u (above the tracks, targets and grid lines).
    public static let candidateLift: Double = 0.01

    /// The pearl ring that outlines the candidate cell of a star drag (feature 354, research R6), for the field
    /// program: a thin square ring on `cell` whose outer edge lies 0.08·u inside the cell's edges (outer half-side
    /// 0.42·u), with a stroke 0.06·u wide (inner half-side 0.36·u), at y = 0.01·u; four flat up-facing quads,
    /// `a_normal` the real up normal, `a_uv` (``trackCode``, 1), colour silver (``materialColour(_:)`` of the track
    /// code). An empty mesh for a cell outside the grid. Presentation only; the same at every tier.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func candidatePart(_ cell: Int,
                                     _ snapshot: ChronoConstellatorSceneSnapshot)
        throws(MeshError) -> ChronoConstellatorColouredMesh {
        var parts: Parts = Parts()
        guard snapshot.columns > 0, snapshot.rows > 0, (0..<(snapshot.columns * snapshot.rows)).contains(cell) else {
            return parts.built()
        }
        let u: Double = cellSize(snapshot)
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        let centre: SIMD3<Double> = cellCentre(cell, snapshot) + SIMD3(0, candidateLift * u, 0)
        let outer: Double = (0.5 - candidateInset) * u
        let inner: Double = outer - candidateWidth * u
        let uv: Vec2 = Vec2(trackCode, 1)
        let silver: SIMD3<Double> = materialColour(trackCode)
        // Near and far strips across the full outer width, then the left and right strips between them.
        let strips: [(x0: Double, z0: Double, x1: Double, z1: Double)] = [
            (-outer, -outer, outer, -inner), (-outer, inner, outer, outer),
            (-outer, -inner, -inner, inner), (inner, -inner, outer, inner),
        ]
        for s in strips {
            try parts.quad([centre + SIMD3(s.x0, 0, s.z0), centre + SIMD3(s.x1, 0, s.z0),
                            centre + SIMD3(s.x1, 0, s.z1), centre + SIMD3(s.x0, 0, s.z1)],
                           slot: up, front: up, uv: uv, colour: silver)
        }
        return parts.built()
    }

    /// The field mesh (see ``fieldPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func fieldMesh(_ snapshot: ChronoConstellatorSceneSnapshot,
                                 tier: ChronoConstellatorTier) throws(MeshError) -> Mesh {
        try fieldPart(snapshot, tier: tier).mesh
    }

    /// The glowing stars (glow program, colour in the normal slot, uv (age 0, weight 1)): every star's node, a disc of
    /// radius 0.3·u at y = 0.25·u in the star colour × 0.4 with its shape on top (radius 0.24·u, 0.002·u higher) in the
    /// full star colour; and, for every star standing on its target, a rose glow copy of the target ring (radius
    /// 0.34 … 0.42·u) at y = 0.008·u. Colours: the stream colour. The same at every tier.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func starPart(_ snapshot: ChronoConstellatorSceneSnapshot,
                                tier: ChronoConstellatorTier) throws(MeshError) -> ChronoConstellatorColouredMesh {
        var parts: Parts = Parts()
        try addStars(snapshot, to: &parts)
        return parts.built()
    }

    /// Adds the elements of ``starPart(_:tier:)`` to `parts`.
    static func addStars(_ snapshot: ChronoConstellatorSceneSnapshot, to parts: inout Parts) throws(MeshError) {
        let u: Double = cellSize(snapshot)
        let uv: Vec2 = Vec2(0, 1)
        for index in snapshot.stars.indices where snapshot.stars[index].onTarget {
            let rose: SIMD3<Double> = ChronoConstellatorPalette.rose
            let centre: SIMD3<Double> = cellCentre(snapshot.stars[index].target, snapshot)
                + SIMD3(0, glowRingLift * u, 0)
            try parts.annulus(centre: centre, inner: targetInner * u, outer: targetOuter * u,
                              segments: circleSegments, slot: rose, uv: uv, colour: rose)
        }
        for index in snapshot.stars.indices {
            let centre: SIMD3<Double> = starCentre(index, snapshot)
            let disc: SIMD3<Double> = ChronoConstellatorPalette.star * nodeDisc
            try parts.disc(centre: centre, radius: nodeRadius * u, segments: circleSegments, slot: disc, uv: uv,
                           colour: disc)
            let star: SIMD3<Double> = ChronoConstellatorPalette.star
            try parts.shape(shape(index), centre: centre + SIMD3(0, shapeLift * u, 0), radius: nodeShapeRadius * u,
                            width: nodeShapeWidth * u, slot: star, uv: uv, colour: star)
        }
    }

    /// The star mesh (see ``starPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func starMesh(_ snapshot: ChronoConstellatorSceneSnapshot,
                                tier: ChronoConstellatorTier) throws(MeshError) -> Mesh {
        try starPart(snapshot, tier: tier).mesh
    }

    /// The point of star `star`'s history ribbon `age` ticks old (0 … the history it has): the cell centre it stood on
    /// then, raised to (0.25 + 0.04 · age)·u; nil for an unknown star or an age beyond its history.
    public static func ribbonPoint(_ star: Int, age: Int,
                                   _ snapshot: ChronoConstellatorSceneSnapshot) -> SIMD3<Double>? {
        guard snapshot.stars.indices.contains(star), age >= 0 else { return nil }
        let history: [Int] = snapshot.stars[star].history
        guard age < history.count else { return nil }
        let u: Double = cellSize(snapshot)
        return cellCentre(history[history.count - 1 - age], snapshot)
            + SIMD3(0, (nodeHeight + ribbonRise * Double(age)) * u, 0)
    }

    /// The history ribbons (glow program, rose in the normal slot, uv (age, weight)): for every star with history, a
    /// strip through ``ribbonPoint(_:age:_:)`` for ages 0 … n, n = min(R, the ticks it has), split into `tier.segments`
    /// pieces per tick, each strip vertex carrying its (fractional) age. The core has half-width 0.05·u and weight 1;
    /// glow shell k = 1 … `tier.glowShells` has half-width 0.05 · (1 + k)·u, lies 0.002 · k·u lower and has weight 0.5^k.
    /// A piece that moves across the field lies flat, facing up; a piece over a held tick (same cell) stands vertical,
    /// facing +z. Colours: rose × ``ribbonAlpha(age:tier:)``.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func ribbonPart(_ snapshot: ChronoConstellatorSceneSnapshot,
                                  tier: ChronoConstellatorTier) throws(MeshError) -> ChronoConstellatorColouredMesh {
        var parts: Parts = Parts()
        try addRibbons(snapshot, tier: tier, to: &parts)
        return parts.built()
    }

    /// Adds the elements of ``ribbonPart(_:tier:)`` to `parts`.
    static func addRibbons(_ snapshot: ChronoConstellatorSceneSnapshot, tier: ChronoConstellatorTier,
                           to parts: inout Parts) throws(MeshError) {
        let u: Double = cellSize(snapshot)
        let ticks: Int = max(tier.ribbonTicks, 1)
        let pieces: Int = max(tier.segments, 1)
        let shells: Int = max(tier.glowShells, 0)
        let rose: SIMD3<Double> = ChronoConstellatorPalette.rose
        for star in snapshot.stars.indices {
            let n: Int = min(ticks, snapshot.stars[star].history.count - 1)
            guard n >= 1 else { continue }
            for shell in 0...shells {
                let half: Double = ribbonHalfWidth * Double(1 + shell) * u
                let drop: SIMD3<Double> = SIMD3(0, -shellDrop * Double(shell) * u, 0)
                let weight: Double = pow(shellWeight, Double(shell))
                for tick in 0..<n {
                    // From age tick + 1 (older) to age tick (newer).
                    guard let older = ribbonPoint(star, age: tick + 1, snapshot),
                          let newer = ribbonPoint(star, age: tick, snapshot) else { continue }
                    let flat: SIMD3<Double> = SIMD3(newer.x - older.x, 0, newer.z - older.z)
                    let moving: Bool = length(flat) > 1e-12
                    let across: SIMD3<Double> = moving ? unit(SIMD3(-flat.z, 0, flat.x)) : SIMD3(1, 0, 0)
                    let front: SIMD3<Double> = moving ? SIMD3(0, 1, 0) : SIMD3(0, 0, 1)
                    for piece in 0..<pieces {
                        let f0: Double = Double(piece) / Double(pieces)
                        let f1: Double = Double(piece + 1) / Double(pieces)
                        let a: SIMD3<Double> = older + (newer - older) * f0 + drop
                        let b: SIMD3<Double> = older + (newer - older) * f1 + drop
                        let ageA: Double = Double(tick + 1) - f0
                        let ageB: Double = Double(tick + 1) - f1
                        let p: [SIMD3<Double>] = [a - across * half, a + across * half, b + across * half,
                                                  b - across * half]
                        let ages: [Double] = [ageA, ageA, ageB, ageB]
                        var ids: [UInt32] = []
                        for i in 0..<4 {
                            ids.append(try parts.vertex(p[i], slot: rose, uv: Vec2(ages[i], weight),
                                                        colour: rose * ribbonAlpha(age: ages[i], tier: tier)))
                        }
                        try parts.facing(ids[0], ids[1], ids[2], p[0], p[1], p[2], front: front)
                        try parts.facing(ids[0], ids[2], ids[3], p[0], p[2], p[3], front: front)
                    }
                }
            }
        }
    }

    /// The ribbon mesh (see ``ribbonPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func ribbonMesh(_ snapshot: ChronoConstellatorSceneSnapshot,
                                  tier: ChronoConstellatorTier) throws(MeshError) -> Mesh {
        try ribbonPart(snapshot, tier: tier).mesh
    }

    /// Everything the glow program draws: the elements of ``starPart(_:tier:)`` followed by those of
    /// ``ribbonPart(_:tier:)`` in one mesh (no vertex is shared between the two: their uv streams differ), with colours.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowPart(_ snapshot: ChronoConstellatorSceneSnapshot,
                                tier: ChronoConstellatorTier) throws(MeshError) -> ChronoConstellatorColouredMesh {
        var parts: Parts = Parts()
        try addStars(snapshot, to: &parts)
        try addRibbons(snapshot, tier: tier, to: &parts)
        return parts.built()
    }

    /// The glow mesh (see ``glowPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowMesh(_ snapshot: ChronoConstellatorSceneSnapshot,
                                tier: ChronoConstellatorTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }
    // MARK: Camera

    /// `aspect` made usable: a non-finite or non-positive aspect becomes 1; others are clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// The eye distance that fits a sphere of `radius` for `aspect` with ``fitMargin``: the sphere must lie in the cone
    /// of half-angle α around the view axis, tan α = (1 − 2 · margin) · min(tan(fovY/2), aspect · tan(fovY/2)), so the
    /// distance is radius / sin α. Every point of the sphere then projects within NDC ±(1 − 2 · margin) on both axes.
    static func distance(radius: Double, aspect: Double) -> Double {
        let half: Double = tan(fieldOfView / 2)
        let limit: Double = (1 - 2 * fitMargin) * min(half, usableAspect(aspect) * half)
        return max(radius, 1e-3) / sin(atan(limit))
    }

    /// The fixed authored camera for `snapshot` and `aspect` (width / height): ``camera(_:aspect:orbit:)`` at
    /// ``ChronoConstellatorOrbit/authored``, so the eye lies on ``eyeDirection`` (in front, +z, pitched 55° down) from
    /// the grid centre at the distance that fits the sphere of ``boundingRadius(_:)``, looking at the grid centre with
    /// +y up and a 45° vertical field of view. For aspects 0.4 … 2.5 every vertex of every mesh projects inside the
    /// view with at least 5 % margin on every side. A zero, negative or non-finite aspect is treated as 1; others are
    /// clamped to 0.1 … 10. Independent of the tier and of the tick.
    public static func camera(_ snapshot: ChronoConstellatorSceneSnapshot, aspect: Double) -> ChronoConstellatorCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The camera for `snapshot`, `aspect` (width / height) and `orbit` (clamped, see
    /// ``ChronoConstellatorOrbit/clamped()``): the eye on ``ChronoConstellatorOrbit/eyeDirection`` from the grid centre
    /// at the distance that fits the sphere of ``boundingRadius(_:)`` (the fit does not depend on the direction, so the
    /// 5 % margin holds at every orbit and aspect 0.4 … 2.5), looking at the grid centre with +y up (never parallel to
    /// the view direction: the pitch is at most 75°) and a 45° vertical field of view. Aspects are made usable as in
    /// ``camera(_:aspect:)``. Presentation only; independent of the tier and of the tick.
    public static func camera(_ snapshot: ChronoConstellatorSceneSnapshot, aspect: Double,
                              orbit: ChronoConstellatorOrbit) -> ChronoConstellatorCamera {
        let a: Double = usableAspect(aspect)
        let radius: Double = boundingRadius(snapshot)
        let d: Double = distance(radius: radius, aspect: a)
        let eye: SIMD3<Double> = orbit.eyeDirection * d
        let near: Double = max((d - radius) * 0.5, 1e-3)
        let far: Double = d + 2 * radius + 1
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: Vec3(0, 0, 0), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return ChronoConstellatorCamera(eye: eye, target: .zero, fovY: fieldOfView, aspect: a, near: near, far: far,
                                        radius: radius, view: view, projection: projection,
                                        viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (origin top left, y down; multiply by the viewport size for pixels, the
    /// convention of `ScreenProjection`); nil behind the camera or for non-finite input. Points outside the view give
    /// coordinates outside 0 … 1.
    public static func project(_ point: SIMD3<Double>, camera: ChronoConstellatorCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    /// `point` in pixels of a `width` × `height` viewport (origin top left, y down); nil for a non-positive size,
    /// behind the camera or for non-finite input.
    public static func pixel(_ point: SIMD3<Double>, camera: ChronoConstellatorCamera, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0, let v = project(point, camera: camera) else { return nil }
        return Vec2(v.x * Double(width), v.y * Double(height))
    }

    // MARK: Building

    /// A mesh builder with its colour stream: a colour is recorded for every new vertex (a welded vertex keeps its
    /// first colour; within each mesh the colour is a function of the normal slot and uv, so welded vertices agree).
    struct Parts {
        var builder: MeshBuilder = MeshBuilder()
        var colours: [Vec4] = []

        /// Adds one vertex and returns its index.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, uv: Vec2,
                             colour: SIMD3<Double>) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(vec(p), normal: vec(slot), uv: uv)
            if Int(id) == colours.count { colours.append(Vec4(colour.x, colour.y, colour.z, 1)) }
            return id
        }

        /// Adds a flat quad p0 p1 p2 p3 (in order around it) wound to face `front`, `slot` in the normal stream.
        mutating func quad(_ p: [SIMD3<Double>], slot: SIMD3<Double>, front: SIMD3<Double>, uv: Vec2,
                           colour: SIMD3<Double>) throws(MeshError) {
            var ids: [UInt32] = []
            for i in 0..<4 { ids.append(try vertex(p[i], slot: slot, uv: uv, colour: colour)) }
            try facing(ids[0], ids[1], ids[2], p[0], p[1], p[2], front: front)
            try facing(ids[0], ids[2], ids[3], p[0], p[2], p[3], front: front)
        }

        /// Adds a flat up-facing bar from `a` to `b` (in the plane y = a.y) of `width`; nothing when they coincide.
        mutating func bar(from a: SIMD3<Double>, to b: SIMD3<Double>, width: Double, slot: SIMD3<Double>, uv: Vec2,
                          colour: SIMD3<Double>) throws(MeshError) {
            let d: SIMD3<Double> = SIMD3(b.x - a.x, 0, b.z - a.z)
            guard ChronoConstellatorSceneGeometry.length(d) > 1e-12 else { return }
            let across: SIMD3<Double> = ChronoConstellatorSceneGeometry.unit(SIMD3(-d.z, 0, d.x)) * (width / 2)
            let end: SIMD3<Double> = SIMD3(b.x, a.y, b.z)
            try quad([a - across, a + across, end + across, end - across], slot: slot, front: SIMD3(0, 1, 0), uv: uv,
                     colour: colour)
        }

        /// Adds a flat up-facing axis-aligned square of half-size `half` about `centre`.
        mutating func square(centre: SIMD3<Double>, half: Double, slot: SIMD3<Double>, uv: Vec2,
                             colour: SIMD3<Double>) throws(MeshError) {
            try quad([centre + SIMD3(-half, 0, -half), centre + SIMD3(half, 0, -half), centre + SIMD3(half, 0, half),
                      centre + SIMD3(-half, 0, half)], slot: slot, front: SIMD3(0, 1, 0), uv: uv, colour: colour)
        }

        /// Adds a flat up-facing disc (a fan of `segments` triangles), `slot` in the normal stream.
        mutating func disc(centre: SIMD3<Double>, radius: Double, segments: Int, slot: SIMD3<Double>, uv: Vec2,
                           colour: SIMD3<Double>) throws(MeshError) {
            let n: Int = max(segments, 3)
            let hub: UInt32 = try vertex(centre, slot: slot, uv: uv, colour: colour)
            for k in 0..<n {
                let a0: Double = 2 * Double.pi * Double(k) / Double(n)
                let a1: Double = 2 * Double.pi * Double(k + 1) / Double(n)
                let p0: SIMD3<Double> = centre + SIMD3(cos(a0), 0, sin(a0)) * radius
                let p1: SIMD3<Double> = centre + SIMD3(cos(a1), 0, sin(a1)) * radius
                let i0: UInt32 = try vertex(p0, slot: slot, uv: uv, colour: colour)
                let i1: UInt32 = try vertex(p1, slot: slot, uv: uv, colour: colour)
                try facing(hub, i0, i1, centre, p0, p1, front: SIMD3(0, 1, 0))
            }
        }

        /// Adds a flat up-facing full annulus, `slot` in the normal stream.
        mutating func annulus(centre: SIMD3<Double>, inner: Double, outer: Double, segments: Int, slot: SIMD3<Double>,
                              uv: Vec2, colour: SIMD3<Double>) throws(MeshError) {
            let n: Int = max(segments, 3)
            for k in 0..<n {
                let a0: Double = 2 * Double.pi * Double(k) / Double(n)
                let a1: Double = 2 * Double.pi * Double(k + 1) / Double(n)
                let d0: SIMD3<Double> = SIMD3(cos(a0), 0, sin(a0))
                let d1: SIMD3<Double> = SIMD3(cos(a1), 0, sin(a1))
                try quad([centre + d0 * inner, centre + d0 * outer, centre + d1 * outer, centre + d1 * inner],
                         slot: slot, front: SIMD3(0, 1, 0), uv: uv, colour: colour)
            }
        }

        /// Adds `shape` as flat up-facing strokes of `width` within `radius` of `centre`, `slot` in the normal stream:
        /// ring an annulus (radius − width … radius); cross a plus of two bars; diamond the outline through (±r, 0) and
        /// (0, ±r); triangle the outline with its apex away from the camera (−z); square the outline of half-side 0.75·r.
        mutating func shape(_ shape: ChronoConstellatorShape, centre: SIMD3<Double>, radius r: Double, width: Double,
                            slot: SIMD3<Double>, uv: Vec2, colour: SIMD3<Double>) throws(MeshError) {
            var corners: [SIMD3<Double>] = []
            switch shape {
            case .ring:
                try annulus(centre: centre, inner: max(r - width, 0), outer: r,
                            segments: ChronoConstellatorSceneGeometry.circleSegments, slot: slot, uv: uv,
                            colour: colour)
                return
            case .cross:
                try bar(from: centre + SIMD3(-r, 0, 0), to: centre + SIMD3(r, 0, 0), width: width, slot: slot,
                        uv: uv, colour: colour)
                try bar(from: centre + SIMD3(0, 0, -r), to: centre + SIMD3(0, 0, r), width: width, slot: slot,
                        uv: uv, colour: colour)
                return
            case .diamond:
                let inset: Double = r - width / 2
                corners = [SIMD3(inset, 0, 0), SIMD3(0, 0, inset), SIMD3(-inset, 0, 0), SIMD3(0, 0, -inset)]
            case .triangle:
                let inset: Double = r - width / 2
                for degrees in [-90.0, 30.0, 150.0] {
                    let a: Double = degrees * Double.pi / 180
                    corners.append(SIMD3(cos(a), 0, sin(a)) * inset)
                }
            case .square:
                let s: Double = 0.75 * r - width / 2
                corners = [SIMD3(-s, 0, -s), SIMD3(s, 0, -s), SIMD3(s, 0, s), SIMD3(-s, 0, s)]
            }
            for k in corners.indices {
                let a: SIMD3<Double> = centre + corners[k]
                let b: SIMD3<Double> = centre + corners[(k + 1) % corners.count]
                try bar(from: a, to: b, width: width, slot: slot, uv: uv, colour: colour)
                try square(centre: a, half: width / 2, slot: slot, uv: uv, colour: colour)
            }
        }
        /// Adds triangle a, b, c wound so its geometric normal points along `front`.
        mutating func facing(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            if ChronoConstellatorSceneGeometry.dot(ChronoConstellatorSceneGeometry.cross(pb - pa, pc - pa), front) < 0 {
                try builder.triangle(a, c, b)
            } else {
                try builder.triangle(a, b, c)
            }
        }

        /// The coloured mesh built so far.
        func built() -> ChronoConstellatorColouredMesh {
            ChronoConstellatorColouredMesh(mesh: builder.build(), colours: colours)
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
