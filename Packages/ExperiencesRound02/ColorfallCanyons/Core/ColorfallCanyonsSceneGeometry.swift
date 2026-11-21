// ColorfallCanyonsSceneGeometry — feature 343 (R02-G05-03) T-R02G0503-004 (FR-R02G0503-001, 006; SC-R02G0503-001, 003;
// clarifications Q1–Q3; research R1, R4). The world of the canyon, built from a snapshot only: the grid lies in the
// xz-plane with cell size u = 2 / max(columns, rows), column c at x = (c − (columns − 1)/2)·u and row r at
// z = (r − (rows − 1)/2)·u (higher rows nearer the camera), y up. Every cell is a bevelled block whose top is at
// y = 0.06·h·u for its current height h (rock +0.5·u, a drain a dark pit at y = 0); springs are glowing emitter columns
// 0.6·u tall in their colour (dimmed ×0.3 when not flowing); basins carry a pearl rim and three target arcs whose
// lengths follow the basin's shares; fluid is a sheet 0.01·u above the top, thickness 0.02·u + 0.04·u·min(V, 24)/24,
// carrying its colour mass weights, its brightness 0.35 + 0.65·min(V, 24)/24 and its flow code (the downhill direction,
// a waterfall where the drop is 2 steps or more, which also gets a falling quad at the shared edge); the flow bands
// themselves are drawn by the fluid shader along that direction, `u_flowBands` = the tier's count. The fixed authored
// camera looks at the grid centre from the front (+z), pitched 50° down, fitted to the bounding sphere about the grid
// centre (y = 0) whose radius is the distance to the farthest corner of the tallest element plus 0.1, with a 5 % margin
// for every aspect 0.4 … 2.5; the CPU projection is the reference that the simulator frame checks compare with
// rendered pixels. Vertex streams follow ColorfallCanyonsShaders (T-R02G0503-003): ShaderMeshRenderer binds only
// a_position, a_normal and a_uv. Doubles are used for drawing only; nothing here is consulted by the rules.
//
// Feature 344 (R02-G05-04) T-R02G0504-002 (FR-R02G0504-004; SC-R02G0504-003; research R3) adds the constrained orbit
// (`ColorfallCanyonsOrbit`: yaw ±40° about +y, pitch 25° … 70° down from the horizon, authored yaw 0 and pitch 50°) and
// `camera(_:aspect:orbit:)`, which refits the same bounding sphere so the 5 % margin holds at every orbit; the authored
// camera is the authored orbit, bit for bit. Presentation only: never in the digest, the snapshot or the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of the Colorfall Canyons scene for one snapshot and aspect.
///
/// Built only by ``ColorfallCanyonsSceneGeometry/camera(_:aspect:orbit:)``
/// (``ColorfallCanyonsSceneGeometry/camera(_:aspect:)`` is its authored orbit). World positions are in grid units (the
/// grid's longer side is 2); ``viewProjection`` maps them to GL clip space (right-handed, depth −1 … 1).
public struct ColorfallCanyonsCamera: Sendable, Equatable {
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

/// The orbit of the Colorfall Canyons camera: a yaw about the vertical axis and a pitch down from the horizon, both in
/// radians. Presentation only: never in the digest, the snapshot or the kernel, and not saved.
///
/// ``ColorfallCanyonsSceneGeometry/camera(_:aspect:orbit:)`` uses the ``clamped()`` orbit, so the eye always stays in
/// front of the grid and above it (no vertical singularity) and the whole canyon stays in view.
public struct ColorfallCanyonsOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians: the angle of the eye direction above the horizon (the view looks down by it); allowed
    /// ``pitchRange`` (25° … 70°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 50° (``ColorfallCanyonsSceneGeometry/pitch``), the fixed camera of R02-G05-03.
    public static let authored = ColorfallCanyonsOrbit(yaw: 0, pitch: ColorfallCanyonsSceneGeometry.pitch)
    /// The largest yaw either way, 40° in radians.
    public static let yawLimit: Double = 40.0 * Double.pi / 180
    /// The allowed pitches, 25° … 70° in radians.
    public static let pitchRange: ClosedRange<Double> = (25.0 * Double.pi / 180)...(70.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −40° … 40° and pitch to 25° … 70°; a non-finite angle becomes the authored one.
    public func clamped() -> ColorfallCanyonsOrbit {
        let y: Double = yaw.isFinite ? yaw : Self.authored.yaw
        let p: Double = pitch.isFinite ? pitch : Self.authored.pitch
        return ColorfallCanyonsOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                     pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// The unit direction from the grid centre to the eye at the clamped orbit: (sin y · cos p, sin p, cos y · cos p)
    /// with y the yaw and p the pitch; exactly ``ColorfallCanyonsSceneGeometry/eyeDirection`` at ``authored``.
    public var eyeDirection: SIMD3<Double> {
        let o: ColorfallCanyonsOrbit = clamped()
        return SIMD3(sin(o.yaw) * cos(o.pitch), sin(o.pitch), cos(o.yaw) * cos(o.pitch))
    }
}

/// A mesh with one colour per vertex (sRGB RGBA 0 … 1, alpha 1), aligned with `mesh.positions`.
///
/// The colours feed the shared unlit mesh renderer of the fallback path (there is no colour stream in the shader
/// programs; they decode the same information from the normal and uv streams, see ``ColorfallCanyonsSceneGeometry``).
public struct ColorfallCanyonsColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh`, in vertex order.
    public let colours: [Vec4]
}

/// The geometry of the Colorfall Canyons scene: cell places, terrain blocks with basin rims, fluid sheets and
/// waterfalls, spring emitters and basin target arcs, camera and projection.
///
/// **Vertex streams** (the contract with ``ColorfallCanyonsShaders``; positions are world units, identity model).
/// - ``terrainMesh(_:tier:)`` — terrain program: `a_normal` the unit generated normal (tops +y, bevels tilted
///   outwards, sides horizontal, rims +y); `a_uv` (material code, shade) with
///   ``ColorfallCanyonsShaders/TerrainMaterial`` codes 0 sandstone (open ground, springs, basins), 1 rock, 2 pearl
///   (basin rims), 3 pit (drains), and shade 1.
/// - ``fluidMesh(_:tier:)`` — fluid program: `a_normal` the colour mass weights (cyan, coral, yellow) of
///   ``ColorfallCanyonsShaders/weights(masses:)``, summing to 1; `a_uv` (brightness, flow code) with
///   ``ColorfallCanyonsPalette/brightness(volume:)`` and ``flowCode(_:_:)``. Every cell's sheet and waterfall have their
///   own vertices (none shared between cells).
/// - ``featureMesh(_:tier:)`` — fluid program: spring emitters and basin target arcs with one-hot weights of their
///   colour, brightness ``emitterBrightness(_:_:)`` (emitters) or 1 (arcs), flow code 0.
/// ``ColorfallCanyonsColouredMesh/colours`` gives each vertex's unlit colour for the fallback: the material colour on
/// terrain (× 0.85 on sloped bevels, × 0.65 on sides), the palette mix times the brightness on fluid and features.
///
/// Every cell, spring, basin, drain, sheet and waterfall sits at the same place at every tier; tiers change only the
/// block top subdivision (4 × 4, 2 × 2, 1 × 1; the coarser grids' vertices are vertices of the finer ones). The flow
/// bands (3, 2, 1) are the fluid shader's `u_flowBands` and the glow shells the scene's; neither is geometry here.
public enum ColorfallCanyonsSceneGeometry {
    // MARK: Constants (lengths in cells u unless stated)

    /// The block top rise per height step, 0.06 · u.
    public static let heightStep = 0.06
    /// The extra rise of a rock slab, 0.5 · u.
    public static let rockLift = 0.5
    /// The horizontal width (and the largest drop) of a block's bevel, 0.08 · u.
    public static let bevel = 0.08
    /// The height of a spring emitter column above its cell top, 0.6 · u.
    public static let emitterHeight = 0.6
    /// The radius of a spring emitter column, 0.12 · u.
    public static let emitterRadius = 0.12
    /// The sides of a spring emitter column, 6.
    public static let emitterSides = 6
    /// The brightness of a spring emitter that is not flowing (valve closed or supply spent), 0.3.
    public static let dimming = 0.3
    /// The gap between a block top and its fluid sheet, 0.01 · u.
    public static let sheetLift = 0.01
    /// The thickness of a sheet of the smallest volume, 0.02 · u.
    public static let sheetBase = 0.02
    /// The thickness a sheet gains up to the volume cap, 0.04 · u.
    public static let sheetGain = 0.04
    /// The volume at which sheets stop thickening and brightening, 24.
    public static let volumeCap = 24
    /// The half-extent of a fluid sheet, 0.47 · u.
    public static let sheetHalf = 0.47
    /// The smallest drop, in height steps, that makes a waterfall, 2.
    public static let waterfallSteps = 2
    /// The half-width of a waterfall, 0.3 · u.
    public static let waterfallHalfWidth = 0.3
    /// How far a waterfall stands into the lower cell from the shared edge, 0.01 · u.
    public static let waterfallOffset = 0.01
    /// The inner radius of a basin's pearl rim, 0.38 · u.
    public static let rimInner = 0.38
    /// The outer radius of a basin's pearl rim, 0.46 · u.
    public static let rimOuter = 0.46
    /// The height of the rim above the basin's cell top, 0.08 · u (above the thickest sheet).
    public static let rimLift = 0.08
    /// The inner radius of a basin's target arcs, 0.28 · u.
    public static let arcInner = 0.28
    /// The outer radius of a basin's target arcs, 0.36 · u.
    public static let arcOuter = 0.36
    /// The height of the target arcs above the basin's cell top, 0.085 · u.
    public static let arcLift = 0.085
    /// The segments of a full rim (each arc uses its share of them, at least 1), 32.
    public static let rimSegments = 32
    /// The added radius of the bounding sphere, 0.1 world units.
    public static let boundingPad = 0.1
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's pitch below the horizon in radians (50°).
    public static let pitch = 50.0 * Double.pi / 180
    /// The unit direction from the grid centre to the eye: (0, sin 50°, cos 50°) — in front (+z), above.
    public static let eyeDirection = SIMD3<Double>(0, sin(pitch), cos(pitch))
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5


    // MARK: Places

    /// The cell size u = 2 / max(columns, rows).
    public static func cellSize(_ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        2 / Double(max(snapshot.columns, snapshot.rows, 1))
    }

    /// The centre of `cell` at y = 0: x = (c − (columns − 1)/2)·u, z = (r − (rows − 1)/2)·u for column c and row r;
    /// the origin for a cell outside the grid.
    public static func cellCentre(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.columns > 0, (0..<snapshot.cellCount).contains(cell) else { return .zero }
        let u: Double = cellSize(snapshot)
        let column: Double = Double(cell % snapshot.columns)
        let row: Double = Double(cell / snapshot.columns)
        return SIMD3((column - Double(snapshot.columns - 1) / 2) * u, 0,
                     (row - Double(snapshot.rows - 1) / 2) * u)
    }

    /// The centre of `cell`'s block top: y = 0.06·h·u for its current height h (clamped to 0 … 15), plus 0.5·u on rock,
    /// and y = 0 on a drain; the origin for a cell outside the grid.
    public static func cellTop(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double> {
        guard (0..<snapshot.cellCount).contains(cell) else { return .zero }
        var p: SIMD3<Double> = cellCentre(cell, snapshot)
        p.y = topHeight(cell, snapshot)
        return p
    }

    /// The height of `cell`'s block top (see ``cellTop(_:_:)``).
    static func topHeight(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        let u: Double = cellSize(snapshot)
        switch snapshot.grounds[cell] {
        case .drain: return 0
        case .rock: return (heightStep * Double(clampedHeight(cell, snapshot)) + rockLift) * u
        case .open: return heightStep * Double(clampedHeight(cell, snapshot)) * u
        }
    }

    /// `cell`'s current height clamped to 0 … 15.
    static func clampedHeight(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Int {
        min(max(snapshot.heights[cell], 0), 15)
    }

    /// The top centre of spring `spring`'s emitter column: its cell top + 0.6·u; the origin for an unknown spring.
    public static func emitterTop(_ spring: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.springs.indices.contains(spring) else { return .zero }
        return cellTop(snapshot.springs[spring].cell, snapshot) + SIMD3(0, emitterHeight * cellSize(snapshot), 0)
    }

    /// The centre of basin `basin`: its cell top centre; the origin for an unknown basin.
    public static func basinCentre(_ basin: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.basins.indices.contains(basin) else { return .zero }
        return cellTop(snapshot.basins[basin].cell, snapshot)
    }

    /// The thickness of a fluid sheet of `volume` units: (0.02 + 0.04 · min(volume, 24) / 24)·u; 0 when empty.
    public static func sheetThickness(volume: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        guard volume > 0 else { return 0 }
        return (sheetBase + sheetGain * Double(min(volume, volumeCap)) / Double(volumeCap)) * cellSize(snapshot)
    }

    /// The y of the top of `cell`'s fluid sheet: top + 0.01·u + thickness; the block top when the cell is empty.
    public static func sheetTop(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        guard (0..<snapshot.cellCount).contains(cell) else { return 0 }
        let volume: Int = snapshot.volume(cell)
        let top: Double = topHeight(cell, snapshot)
        guard volume > 0 else { return top }
        return top + sheetLift * cellSize(snapshot) + sheetThickness(volume: volume, snapshot)
    }

    /// The colour of `cell`'s fluid: ``ColorfallCanyonsPalette/fluid(_:)`` of its masses times
    /// ``ColorfallCanyonsPalette/brightness(volume:)``; black for an empty cell.
    public static func fluidColour(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double> {
        guard (0..<snapshot.cellCount).contains(cell) else { return .zero }
        let volume: Int = snapshot.volume(cell)
        guard volume > 0 else { return .zero }
        return ColorfallCanyonsPalette.fluid(snapshot.masses[cell]) * ColorfallCanyonsPalette.brightness(volume: volume)
    }

    /// The brightness of spring `spring`'s emitter: 1 while it flows, ``dimming`` (0.3) when its valve is closed or its
    /// supply is spent; 0 for an unknown spring.
    public static func emitterBrightness(_ spring: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        guard snapshot.springs.indices.contains(spring) else { return 0 }
        return snapshot.springs[spring].flowing ? 1 : dimming
    }

    /// The colour of spring `spring`'s emitter: its palette colour times ``emitterBrightness(_:_:)``; black when unknown.
    public static func emitterColour(_ spring: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.springs.indices.contains(spring) else { return .zero }
        return ColorfallCanyonsPalette.colour(snapshot.springs[spring].color) * emitterBrightness(spring, snapshot)
    }

    /// The `a_uv.y` flow code of `cell` (``ColorfallCanyonsShaders/flowCode(dx:dz:waterfall:)``): the direction to its
    /// downhill neighbour in model x (columns) and z (rows), plus 4 when the drop is 2 steps or more; 0 without one.
    public static func flowCode(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        guard (0..<snapshot.cellCount).contains(cell), let next = snapshot.downhill[cell] else { return 0 }
        let dx: Int = next % snapshot.columns - cell % snapshot.columns
        let dz: Int = next / snapshot.columns - cell / snapshot.columns
        return ColorfallCanyonsShaders.flowCode(dx: dx, dz: dz, waterfall: isWaterfall(cell, snapshot))
    }

    /// Whether `cell` has a downhill neighbour at least ``waterfallSteps`` (2) height steps lower.
    public static func isWaterfall(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Bool {
        guard (0..<snapshot.cellCount).contains(cell), snapshot.downhill[cell] != nil else { return false }
        return drop(cell, snapshot) >= Double(waterfallSteps) - 1e-9
    }

    /// The drop from `cell` to its downhill neighbour in height steps (block top difference / (0.06·u)); 0 when it has
    /// none.
    public static func drop(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        guard (0..<snapshot.cellCount).contains(cell), let next = snapshot.downhill[cell] else { return 0 }
        return (topHeight(cell, snapshot) - topHeight(next, snapshot)) / (heightStep * cellSize(snapshot))
    }

    /// The highest y of any element of `snapshot`: block tops (rock slabs included), emitter tops, fluid sheets at their
    /// thickest (so the camera stays put as fluid flows), and
    /// basin rims with their arcs.
    public static func tallest(_ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        let u: Double = cellSize(snapshot)
        var y: Double = 0
        for cell in 0..<snapshot.cellCount {
            y = max(y, topHeight(cell, snapshot))
            // Every cell that can hold fluid counts with the thickest sheet (volume at the cap), so the camera does
            // not move as fluid flows (lead, 2026-11-21).
            if snapshot.grounds[cell] != .rock {
                y = max(y, topHeight(cell, snapshot) + sheetLift * u + sheetThickness(volume: volumeCap, snapshot))
            }
        }
        for s in snapshot.springs.indices { y = max(y, emitterTop(s, snapshot).y) }
        for b in snapshot.basins.indices { y = max(y, basinCentre(b, snapshot).y + max(rimLift, arcLift) * u) }
        return y
    }

    /// The radius of the scene's bounding sphere about the grid centre (y = 0): the distance to the farthest corner
    /// (±columns·u/2, ``tallest(_:)``, ±rows·u/2) of the tallest element, plus 0.1. Every vertex of every mesh lies
    /// inside the box of that corner, so at least 0.1 inside the sphere.
    public static func boundingRadius(_ snapshot: ColorfallCanyonsSceneSnapshot) -> Double {
        let u: Double = cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let halfDepth: Double = Double(snapshot.rows) * u / 2
        let y: Double = tallest(snapshot)
        return (halfWidth * halfWidth + halfDepth * halfDepth + y * y).squareRoot() + boundingPad
    }

    // MARK: Meshes

    /// The terrain material of `cell`: sandstone for open ground (springs and basins included), rock, or pit for a
    /// drain.
    public static func material(_ cell: Int,
                                _ snapshot: ColorfallCanyonsSceneSnapshot) -> ColorfallCanyonsShaders.TerrainMaterial {
        guard (0..<snapshot.cellCount).contains(cell) else { return .sandstone }
        switch snapshot.grounds[cell] {
        case .open: return .sandstone
        case .rock: return .rock
        case .drain: return .pit
        }
    }

    /// The terrain (terrain program): one bevelled block per cell with its top subdivided `tier.subdivision` ×
    /// `tier.subdivision`, unit generated normals and uv (material code, 1); and each basin's flat pearl rim (code 2,
    /// normal +y) at 0.08·u above its top. Colours: the material colour (× 0.85 on sloped bevels, × 0.65 on sides).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func terrainPart(_ snapshot: ColorfallCanyonsSceneSnapshot,
                                   tier: ColorfallCanyonsTier) throws(MeshError) -> ColorfallCanyonsColouredMesh {
        var parts: Parts = Parts()
        let u: Double = cellSize(snapshot)
        let s: Int = max(tier.subdivision, 1)
        let half: Double = u / 2
        let inner: Double = half - bevel * u
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        for cell in 0..<snapshot.cellCount {
            let centre: SIMD3<Double> = cellCentre(cell, snapshot)
            let top: Double = topHeight(cell, snapshot)
            let kind: ColorfallCanyonsShaders.TerrainMaterial = material(cell, snapshot)
            let base: SIMD3<Double> = kind.colour
            let uv: Vec2 = Vec2(kind.code, 1)
            // Top: s × s quads facing up.
            for i in 0..<s {
                for j in 0..<s {
                    let x0: Double = -inner + 2 * inner * Double(i) / Double(s)
                    let x1: Double = -inner + 2 * inner * Double(i + 1) / Double(s)
                    let z0: Double = -inner + 2 * inner * Double(j) / Double(s)
                    let z1: Double = -inner + 2 * inner * Double(j + 1) / Double(s)
                    let p: [SIMD3<Double>] = [centre + SIMD3(x0, top, z0), centre + SIMD3(x1, top, z0),
                                              centre + SIMD3(x1, top, z1), centre + SIMD3(x0, top, z1)]
                    try parts.quad(p, slot: up, front: up, uv: uv, colour: base)
                }
            }
            // Bevels: four strips from the top's edge down to the cell's edge, s quads each; then the sides to y = 0.
            let fall: Double = min(bevel * u, top)
            let lower: Double = top - fall
            let directions: [SIMD3<Double>] = [SIMD3(1, 0, 0), SIMD3(0, 0, 1), SIMD3(-1, 0, 0), SIMD3(0, 0, -1)]
            for out in directions {
                let side: SIMD3<Double> = SIMD3(-out.z, 0, out.x)
                let normal: SIMD3<Double> = unit(out * fall + SIMD3(0, bevel * u, 0))
                let shade: SIMD3<Double> = fall > 0 ? base * 0.85 : base
                for k in 0..<s {
                    let a: Double = -1 + 2 * Double(k) / Double(s)
                    let b: Double = -1 + 2 * Double(k + 1) / Double(s)
                    let p: [SIMD3<Double>] = [
                        centre + out * inner + side * (a * inner) + SIMD3(0, top, 0),
                        centre + out * half + side * (a * half) + SIMD3(0, lower, 0),
                        centre + out * half + side * (b * half) + SIMD3(0, lower, 0),
                        centre + out * inner + side * (b * inner) + SIMD3(0, top, 0),
                    ]
                    try parts.quad(p, slot: normal, front: normal, uv: uv, colour: shade)
                }
                if lower > 1e-12 {
                    let p: [SIMD3<Double>] = [
                        centre + out * half - side * half + SIMD3(0, lower, 0),
                        centre + out * half + side * half + SIMD3(0, lower, 0),
                        centre + out * half + side * half,
                        centre + out * half - side * half,
                    ]
                    try parts.quad(p, slot: out, front: out, uv: uv, colour: base * 0.65)
                }
            }
        }
        let pearl: ColorfallCanyonsShaders.TerrainMaterial = .pearl
        for b in snapshot.basins.indices {
            try parts.annulus(centre: basinCentre(b, snapshot) + SIMD3(0, rimLift * u, 0), inner: rimInner * u,
                              outer: rimOuter * u, from: 0, to: 1, segments: rimSegments, slot: up,
                              uv: Vec2(pearl.code, 1), colour: pearl.colour)
        }
        return parts.built()
    }

    /// The terrain mesh (see ``terrainPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func terrainMesh(_ snapshot: ColorfallCanyonsSceneSnapshot,
                                   tier: ColorfallCanyonsTier) throws(MeshError) -> Mesh {
        try terrainPart(snapshot, tier: tier).mesh
    }

    /// The fluid (fluid program): for every cell with volume > 0 a slab (top and four sides) from 0.01·u above its top,
    /// thickness ``sheetThickness(volume:_:)``, half-extent 0.47·u, with weights
    /// ``ColorfallCanyonsShaders/weights(masses:)``, brightness ``ColorfallCanyonsPalette/brightness(volume:)`` and
    /// ``flowCode(_:_:)``; where the drop is 2 steps or more, also a two-sided vertical waterfall 0.6·u wide standing
    /// 0.01·u into the lower cell, from the sheet's top down to 0.01·u above the lower block, with the same stream values.
    /// Colours: ``fluidColour(_:_:)``. The same at every tier (the shader draws the tier's flow bands).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func fluidPart(_ snapshot: ColorfallCanyonsSceneSnapshot,
                                 tier: ColorfallCanyonsTier) throws(MeshError) -> ColorfallCanyonsColouredMesh {
        var parts: Parts = Parts()
        let u: Double = cellSize(snapshot)
        for cell in 0..<snapshot.cellCount where snapshot.volume(cell) > 0 {
            let centre: SIMD3<Double> = cellCentre(cell, snapshot)
            let y0: Double = topHeight(cell, snapshot) + sheetLift * u
            let y1: Double = sheetTop(cell, snapshot)
            let weights: SIMD3<Double> = ColorfallCanyonsShaders.weights(masses: snapshot.masses[cell])
            let uv: Vec2 = Vec2(ColorfallCanyonsPalette.brightness(volume: snapshot.volume(cell)), flowCode(cell, snapshot))
            let colour: SIMD3<Double> = fluidColour(cell, snapshot)
            try parts.box(centre: centre, half: sheetHalf * u, bottom: y0, top: y1, slot: weights, uv: uv,
                          colour: colour)
            guard let next = snapshot.downhill[cell], isWaterfall(cell, snapshot) else { continue }
            let dir: SIMD3<Double> = unit(cellCentre(next, snapshot) - centre)
            let across: SIMD3<Double> = SIMD3(-dir.z, 0, dir.x)
            let edge: SIMD3<Double> = centre + dir * (u / 2 + waterfallOffset * u)
            let w: SIMD3<Double> = across * (waterfallHalfWidth * u)
            let bottom: Double = topHeight(next, snapshot) + sheetLift * u
            let p: [SIMD3<Double>] = [SIMD3(edge.x, y1, edge.z) - w, SIMD3(edge.x, y1, edge.z) + w,
                                      SIMD3(edge.x, bottom, edge.z) + w, SIMD3(edge.x, bottom, edge.z) - w]
            try parts.quad(p, slot: weights, front: dir, uv: uv, colour: colour)
            try parts.quad(p, slot: weights, front: -dir, uv: uv, colour: colour)
        }
        return parts.built()
    }

    /// The fluid mesh (see ``fluidPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func fluidMesh(_ snapshot: ColorfallCanyonsSceneSnapshot,
                                 tier: ColorfallCanyonsTier) throws(MeshError) -> Mesh {
        try fluidPart(snapshot, tier: tier).mesh
    }

    /// The features (fluid program): a hexagonal emitter column 0.6·u tall on each spring (sides and top cap) with
    /// one-hot weights of its colour and brightness ``emitterBrightness(_:_:)``; and each basin's three target arcs at
    /// 0.085·u above its top, radius 0.28 … 0.36·u, arc length ∝ share, starting at +x and turning towards +z in the
    /// order cyan, coral, yellow (a zero share draws nothing), one-hot weights of their colour and brightness 1. Flow
    /// code 0 throughout. Colours: the palette colour times the brightness. The same at every tier.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func featurePart(_ snapshot: ColorfallCanyonsSceneSnapshot,
                                   tier: ColorfallCanyonsTier) throws(MeshError) -> ColorfallCanyonsColouredMesh {
        var parts: Parts = Parts()
        let u: Double = cellSize(snapshot)
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        for s in snapshot.springs.indices {
            let base: SIMD3<Double> = cellTop(snapshot.springs[s].cell, snapshot)
            let topY: Double = emitterTop(s, snapshot).y
            let weights: SIMD3<Double> = oneHot(snapshot.springs[s].color)
            let uv: Vec2 = Vec2(emitterBrightness(s, snapshot), 0)
            let colour: SIMD3<Double> = emitterColour(s, snapshot)
            let r: Double = emitterRadius * u
            var ring: [SIMD3<Double>] = []
            for k in 0..<emitterSides {
                let a: Double = 2 * Double.pi * Double(k) / Double(emitterSides)
                ring.append(SIMD3(base.x + r * cos(a), 0, base.z + r * sin(a)))
            }
            for k in 0..<emitterSides {
                let a: SIMD3<Double> = ring[k], b: SIMD3<Double> = ring[(k + 1) % emitterSides]
                let out: SIMD3<Double> = unit((a + b) / 2 - SIMD3(base.x, 0, base.z))
                let p: [SIMD3<Double>] = [SIMD3(a.x, base.y, a.z), SIMD3(b.x, base.y, b.z),
                                          SIMD3(b.x, topY, b.z), SIMD3(a.x, topY, a.z)]
                try parts.quad(p, slot: weights, front: out, uv: uv, colour: colour)
                try parts.triangle([SIMD3(base.x, topY, base.z), SIMD3(a.x, topY, a.z), SIMD3(b.x, topY, b.z)],
                                   slot: weights, front: up, uv: uv, colour: colour)
            }
        }
        for b in snapshot.basins.indices {
            let basin: ColorfallCanyonsBasin = snapshot.basins[b]
            let centre: SIMD3<Double> = basinCentre(b, snapshot) + SIMD3(0, arcLift * u, 0)
            var start: Double = 0
            for color in ColorfallCanyonsColor.allCases {
                let share: Double = Double(max(basin.shares[color.rawValue], 0)) / 1_000
                guard share > 0 else { continue }
                let end: Double = min(start + share, 1)
                let segments: Int = max(1, Int((Double(rimSegments) * (end - start)).rounded(.up)))
                try parts.annulus(centre: centre, inner: arcInner * u, outer: arcOuter * u, from: start, to: end,
                                  segments: segments, slot: oneHot(color), uv: Vec2(1, 0),
                                  colour: ColorfallCanyonsPalette.colour(color))
                start = end
            }
        }
        return parts.built()
    }

    /// The feature mesh (see ``featurePart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func featureMesh(_ snapshot: ColorfallCanyonsSceneSnapshot,
                                   tier: ColorfallCanyonsTier) throws(MeshError) -> Mesh {
        try featurePart(snapshot, tier: tier).mesh
    }

    /// The one-hot weights (cyan, coral, yellow) of `color`.
    public static func oneHot(_ color: ColorfallCanyonsColor) -> SIMD3<Double> {
        var w: SIMD3<Double> = SIMD3(0, 0, 0)
        w[color.rawValue] = 1
        return w
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
    /// ``ColorfallCanyonsOrbit/authored``, so the eye lies on ``eyeDirection`` (in front, +z, pitched 50° down) from
    /// the grid centre at the distance that fits the sphere of ``boundingRadius(_:)``, looking at the grid centre with
    /// +y up (never parallel to the view direction) and a 45° vertical field of view. For aspects 0.4 … 2.5 every
    /// vertex of every mesh projects inside the view with at least 5 % margin on every side. A zero, negative or
    /// non-finite aspect is treated as 1; others are clamped to 0.1 … 10. Independent of the tier.
    public static func camera(_ snapshot: ColorfallCanyonsSceneSnapshot, aspect: Double) -> ColorfallCanyonsCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The camera for `snapshot`, `aspect` (width / height) and `orbit` (clamped, see
    /// ``ColorfallCanyonsOrbit/clamped()``): the eye on ``ColorfallCanyonsOrbit/eyeDirection`` from the grid centre at
    /// the distance that fits the sphere of ``boundingRadius(_:)`` (the fit does not depend on the direction, so the
    /// 5 % margin holds at every orbit and aspect 0.4 … 2.5), looking at the grid centre with +y up (never parallel to
    /// the view direction: the pitch is at most 70°) and a 45° vertical field of view. Aspects are made usable as in
    /// ``camera(_:aspect:)``. Presentation only; independent of the tier.
    public static func camera(_ snapshot: ColorfallCanyonsSceneSnapshot, aspect: Double,
                              orbit: ColorfallCanyonsOrbit) -> ColorfallCanyonsCamera {
        let a: Double = usableAspect(aspect)
        let radius: Double = boundingRadius(snapshot)
        let d: Double = distance(radius: radius, aspect: a)
        let eye: SIMD3<Double> = orbit.eyeDirection * d
        let near: Double = max((d - radius) * 0.5, 1e-3)
        let far: Double = d + 2 * radius + 1
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: Vec3(0, 0, 0), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return ColorfallCanyonsCamera(eye: eye, target: .zero, fovY: fieldOfView, aspect: a, near: near, far: far,
                                      radius: radius, view: view, projection: projection,
                                      viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (origin top left, y down; multiply by the viewport size for pixels, the
    /// convention of `ScreenProjection`); nil behind the camera or for non-finite input. Points outside the view give
    /// coordinates outside 0 … 1.
    public static func project(_ point: SIMD3<Double>, camera: ColorfallCanyonsCamera) -> SIMD2<Double>? {
        guard let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point else { return nil }
        return SIMD2(p.x, p.y)
    }

    /// `point` in pixels of a `width` × `height` viewport (origin top left, y down); nil for a non-positive size,
    /// behind the camera or for non-finite input.
    public static func pixel(_ point: SIMD3<Double>, camera: ColorfallCanyonsCamera, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0, let v = project(point, camera: camera) else { return nil }
        return Vec2(v.x * Double(width), v.y * Double(height))
    }

    // MARK: Building

    /// A mesh builder with its colour stream: a colour is recorded for every new vertex (a welded vertex keeps its
    /// first colour; within each mesh the colour is a function of the position's element, normal slot and uv, so
    /// welded vertices agree).
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

        /// Adds a flat triangle wound to face `front`, `slot` in the normal stream.
        mutating func triangle(_ p: [SIMD3<Double>], slot: SIMD3<Double>, front: SIMD3<Double>, uv: Vec2,
                               colour: SIMD3<Double>) throws(MeshError) {
            var ids: [UInt32] = []
            for i in 0..<3 { ids.append(try vertex(p[i], slot: slot, uv: uv, colour: colour)) }
            try facing(ids[0], ids[1], ids[2], p[0], p[1], p[2], front: front)
        }

        /// Adds an axis-aligned slab: the top and four sides of the square of half-size `half` about `centre`'s x and
        /// z, from y `bottom` to `top`, faces wound outwards (sides only when the slab has height).
        mutating func box(centre: SIMD3<Double>, half: Double, bottom: Double, top: Double, slot: SIMD3<Double>,
                          uv: Vec2, colour: SIMD3<Double>) throws(MeshError) {
            let x0: Double = centre.x - half, x1: Double = centre.x + half
            let z0: Double = centre.z - half, z1: Double = centre.z + half
            try quad([SIMD3(x0, top, z0), SIMD3(x1, top, z0), SIMD3(x1, top, z1), SIMD3(x0, top, z1)],
                     slot: slot, front: SIMD3(0, 1, 0), uv: uv, colour: colour)
            guard top - bottom > 1e-12 else { return }
            try quad([SIMD3(x1, bottom, z0), SIMD3(x1, bottom, z1), SIMD3(x1, top, z1), SIMD3(x1, top, z0)],
                     slot: slot, front: SIMD3(1, 0, 0), uv: uv, colour: colour)
            try quad([SIMD3(x0, bottom, z0), SIMD3(x0, bottom, z1), SIMD3(x0, top, z1), SIMD3(x0, top, z0)],
                     slot: slot, front: SIMD3(-1, 0, 0), uv: uv, colour: colour)
            try quad([SIMD3(x0, bottom, z1), SIMD3(x1, bottom, z1), SIMD3(x1, top, z1), SIMD3(x0, top, z1)],
                     slot: slot, front: SIMD3(0, 0, 1), uv: uv, colour: colour)
            try quad([SIMD3(x0, bottom, z0), SIMD3(x1, bottom, z0), SIMD3(x1, top, z0), SIMD3(x0, top, z0)],
                     slot: slot, front: SIMD3(0, 0, -1), uv: uv, colour: colour)
        }

        /// Adds a flat annulus facing up at `centre`, from turn fraction `from` to `to` (angle 2π·f from +x towards
        /// +z) in `segments` steps, `slot` in the normal stream.
        mutating func annulus(centre: SIMD3<Double>, inner: Double, outer: Double, from: Double, to: Double,
                              segments: Int, slot: SIMD3<Double>, uv: Vec2, colour: SIMD3<Double>) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let n: Int = max(segments, 1)
            for k in 0..<n {
                let a0: Double = 2 * Double.pi * (from + (to - from) * Double(k) / Double(n))
                let a1: Double = 2 * Double.pi * (from + (to - from) * Double(k + 1) / Double(n))
                let d0: SIMD3<Double> = SIMD3(cos(a0), 0, sin(a0))
                let d1: SIMD3<Double> = SIMD3(cos(a1), 0, sin(a1))
                try quad([centre + d0 * inner, centre + d0 * outer, centre + d1 * outer, centre + d1 * inner],
                         slot: slot, front: up, uv: uv, colour: colour)
            }
        }

        /// Adds triangle a, b, c wound so its geometric normal points along `front`.
        mutating func facing(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            if ColorfallCanyonsSceneGeometry.dot(ColorfallCanyonsSceneGeometry.cross(pb - pa, pc - pa), front) < 0 {
                try builder.triangle(a, c, b)
            } else {
                try builder.triangle(a, b, c)
            }
        }

        /// The coloured mesh built so far.
        func built() -> ColorfallCanyonsColouredMesh {
            ColorfallCanyonsColouredMesh(mesh: builder.build(), colours: colours)
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
