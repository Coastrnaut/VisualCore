// EchoCartographerSceneGeometry — feature 403 (R02-G11-03) T-R02G1103-004 (FR-R02G1103-001, 003, 006; clarifications
// Q1, Q2, Q4). The chamber of Echo Cartographer, built from a snapshot only. The floor is the plane y = 0 with x to the
// right and z towards the viewer: with the cell pitch s = 1.8 / max(W, H), cell (x, y) is centred at
// X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s. The abyss ground is a plane at y = −0.01 over the chamber plus 0.1
// on each side; every cell known open carries a floor tile 0.9·s wide at y = 0; the entry is a diamond (a square of side
// 0.5·s rotated 45°) at y = 0.005; each marker a ring of radius 0.32·s and line 0.06·s at y = 0.01; each ray of the last
// pulse a strip 0.05·s wide at y = 0.015 from the emitter's centre to the struck wall cell's near face, or the chamber's
// edge, (distance − 0.5)·s away (the radius the shader's pulse ring reaches the wall at); the ring field, the quad the
// shader draws the pulse and echo rings on, covers the chamber at y = 0.02 and is emitted only at a tier with rings.
// Every cell known wall carries a block 0.92·s wide and 0.5·s high (dark faces: top and four sides) with its 12 edges as
// strips 0.05·s thick, each folded over its edge (0.025·s on each adjacent face, d = 0 on the edge; a bottom edge folds
// onto the floor plane outside the block), lifted ``edgeLift`` off the faces; each located beacon a pillar 0.3·s wide
// and 0.8·s high; the energy gauge is a row of `budget` bars at y = 0, centred on z = 1.0, 0.06 deep, spread from
// x = −0.9 to 0.9 (each slot 1.8 / budget wide, the bar four fifths of it, a fifth gap), lit for the energy left, the
// first bars lit. Nothing is drawn on an unknown cell (a marker the player put there excepted: a marker is the player's
// own note) and no unlocated beacon is drawn: the snapshot holds neither.
//
// Draw order (coordinator design change, 2026-11-23): the scene draws with depth testing off and back-face culling on,
// so the chamber mesh is in painter's order — the flat layers first (ground, floor tiles, entry, markers, rays, ring
// field), then the solids (wall blocks and pillars) back to front: rows by ascending Z (far first) and, within a row,
// from the outside in (descending |X|, then ascending X), because the fixed camera sits at x = 0 and a block nearer the
// centre covers the inner side face of its outer neighbour; each solid complete (faces, then its edge strips); the
// gauge last. Every triangle winds counter-clockwise seen from the side its face looks at (flat layers: from +y; solid
// faces: from outside), so culling removes exactly the back faces.
//
// Vertex streams (the contract with `EchoCartographerShaders`, whose header is authoritative): `a_uv.x` is the material
// code (``EchoCartographerShaders/ChamberMaterial``), `a_uv.y` the local edge coordinate d (fans: 0 at the centre vertex,
// 1 on the outline; strips: −1 on one long side, +1 on the other; solids and the ring field: 0), `a_normal` the surface
// normal except on wall edge strips, whose `a_normal` is (the struck distance in cells from the last pulse, 0, 0), 0 for a
// wall the last pulse did not strike. The glow mesh holds the glow shells around edges and pillars (tier.glowShells, 0 …
// 2): the glow colour in the normal slot, uv = (glow factor 0.5^k, 0). Rings and flares move by uniforms only: no
// position depends on the time or Reduce Motion, and every position other than the ring field's is the same at every
// tier. The fixed camera looks from eye (0, 2.4, 1.9) at (0, 0, 0.05) with +y up; its vertical field of view is fitted
// so the box x −1 … 1, z −1 … 1.1, y 0 … 0.8 fits with ``fitMargin`` (above the required 5 %) per side for aspect
// 0.4 … 2.5. Doubles are used for drawing only; nothing here is consulted by the rules.
//
// Feature 404 (R02-G11-04) T-R02G1104-002 adds the player's orbit (`EchoCartographerOrbit`: yaw ±35° about the world
// y axis through the look-at point, pitch −15° … +20° about the camera's right axis, positive raising the eye so the
// chamber is seen more from above; authored (0, 0)) and `camera(_:aspect:orbit:)`: the authored eye rotated about the
// look-at point (0, 0, 0.05), the field of view refitted exactly as for the fixed camera so the same box keeps
// ``fitMargin`` per side at every orbit and aspect 0.4 … 2.5. At the authored orbit the eye is the authored one, so
// `camera(_:aspect:)` (which calls it) is unchanged bit for bit.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The fixed authored camera of one frame: eye, target, lens and the matrices built from them.
public struct EchoCartographerCamera: Sendable, Equatable {
    /// The eye position in world units, (0, 2.4, 1.9) at the authored orbit.
    public let eye: SIMD3<Double>
    /// The point looked at, (0, 0, 0.05).
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

/// The player's view of the chamber: a yaw about the world y axis and a pitch about the camera's right axis, both in
/// radians, applied to the authored eye about the authored look-at point (feature 404, R02-G11-04). Presentation only:
/// never saved, never read by the rules.
public struct EchoCartographerOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians about the camera's right axis: positive raises the eye (the chamber seen more from above),
    /// negative lowers it; allowed ``pitchRange`` (−15° … +20°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G11-03.
    public static let authored = EchoCartographerOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 35° in radians.
    public static let yawLimit: Double = 35.0 * Double.pi / 180
    /// The allowed pitches, −15° … +20° in radians.
    public static let pitchRange: ClosedRange<Double> = (-15.0 * Double.pi / 180)...(20.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −35° … 35° and pitch to −15° … 20°; a non-finite angle becomes 0.
    public func clamped() -> EchoCartographerOrbit {
        let y: Double = yaw.isFinite ? yaw : 0
        let p: Double = pitch.isFinite ? pitch : 0
        return EchoCartographerOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                     pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct EchoCartographerColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// The CPU reference points the simulator frame checks sample (clarification Q3), all in world units on the drawn
/// surfaces.
public struct EchoCartographerReferencePoints: Sendable, Equatable {
    /// The centre of every known-open cell's floor tile, in cell order.
    public let floors: [SIMD3<Double>]
    /// The top-face centre of every known wall's block, in cell order.
    public let walls: [SIMD3<Double>]
    /// The entry diamond's centre.
    public let entry: SIMD3<Double>
    /// The centre of every marker ring, in marker order.
    public let markers: [SIMD3<Double>]
    /// The centre of the gauge's first bar.
    public let firstGaugeBar: SIMD3<Double>
}

/// Builds the Echo Cartographer scene from an `EchoCartographerSceneSnapshot`: places, meshes, camera and projection.
public enum EchoCartographerSceneGeometry {
    /// The material codes (shared with the shaders).
    public typealias Material = EchoCartographerShaders.ChamberMaterial

    // MARK: Constants (world units unless stated)

    /// The chamber's extent: s = ``chamberSpan`` / max(W, H).
    public static let chamberSpan: Double = 1.8
    /// The ground's plane.
    public static let groundY: Double = -0.01
    /// The ground's reach beyond the chamber on each side.
    public static let groundBorder: Double = 0.1
    /// A floor tile's width in cells.
    public static let tileWidth: Double = 0.9
    /// The entry diamond's plane.
    public static let entryY: Double = 0.005
    /// The entry diamond's side in cells (a square rotated 45°).
    public static let entrySide: Double = 0.5
    /// The marker rings' plane.
    public static let markerY: Double = 0.01
    /// A marker ring's radius (the centre of its line) in cells.
    public static let markerRadius: Double = 0.32
    /// A marker ring's line width in cells.
    public static let markerLine: Double = 0.06
    /// Segments of a marker ring.
    public static let markerSegments: Int = 32
    /// The rays' plane.
    public static let rayY: Double = 0.015
    /// A ray's width in cells.
    public static let rayWidth: Double = 0.05
    /// The ring field's plane.
    public static let ringY: Double = 0.02
    /// A wall block's width in cells.
    public static let wallWidth: Double = 0.92
    /// A wall block's height in cells.
    public static let wallHeight: Double = 0.5
    /// A wall edge strip's thickness in cells (half on each adjacent face).
    public static let edgeThickness: Double = 0.05
    /// How far edge strips (and glow shells, per shell) are lifted off the faces they lie on.
    public static let edgeLift: Double = 0.001
    /// A pillar's width in cells.
    public static let pillarWidth: Double = 0.3
    /// A pillar's height in cells.
    public static let pillarHeight: Double = 0.8
    /// The gauge's plane.
    public static let gaugeY: Double = 0
    /// The gauge's centre line.
    public static let gaugeZ: Double = 1.0
    /// The gauge's depth along z.
    public static let gaugeDepth: Double = 0.06
    /// The gauge's left end.
    public static let gaugeStart: Double = -0.9
    /// The gauge's right end.
    public static let gaugeEnd: Double = 0.9
    /// The share of a slot a bar fills (the rest, a fifth, is the gap).
    public static let gaugeFill: Double = 0.8
    /// Extra half width per glow shell around an edge, in cells (two shells stay inside the wall's cell).
    public static let edgeGlowGrowth: Double = 0.006
    /// Extra half width and height per glow shell around a pillar, in cells.
    public static let pillarGlowGrowth: Double = 0.025
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, 2.4, 1.9)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, 0, 0.05)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-1, 0, -1)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1, 0.8, 1.1)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places (the CPU reference)

    /// The cell pitch s = 1.8 / max(W, H).
    public static func cellSize(_ snapshot: EchoCartographerSceneSnapshot) -> Double {
        chamberSpan / Double(max(snapshot.width, snapshot.height, 1))
    }

    /// The chamber's half extents (W·s / 2, H·s / 2) along x and z.
    public static func halfExtent(_ snapshot: EchoCartographerSceneSnapshot) -> SIMD2<Double> {
        let s: Double = cellSize(snapshot)
        return SIMD2(Double(snapshot.width) * s / 2, Double(snapshot.height) * s / 2)
    }

    /// The centre of `cell` on the floor plane: (X, 0, Z) with X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s.
    public static func cellCentre(_ cell: EchoCartographerCell, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double> {
        let s: Double = cellSize(snapshot)
        return SIMD3((Double(cell.x) + 0.5 - Double(snapshot.width) / 2) * s, 0,
                     (Double(cell.y) + 0.5 - Double(snapshot.height) / 2) * s)
    }

    /// The top-face centre of a wall block on `cell`: (X, 0.5·s, Z).
    public static func wallTop(_ cell: EchoCartographerCell, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double> {
        let c: SIMD3<Double> = cellCentre(cell, snapshot)
        return SIMD3(c.x, wallHeight * cellSize(snapshot), c.z)
    }

    /// The top-face centre of a pillar on `cell`: (X, 0.8·s, Z).
    public static func pillarTop(_ cell: EchoCartographerCell, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double> {
        let c: SIMD3<Double> = cellCentre(cell, snapshot)
        return SIMD3(c.x, pillarHeight * cellSize(snapshot), c.z)
    }

    /// The entry diamond's centre: (X, 0.005, Z) of the entry.
    public static func entryCentre(_ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double> {
        let c: SIMD3<Double> = cellCentre(snapshot.entry, snapshot)
        return SIMD3(c.x, entryY, c.z)
    }

    /// The centre of marker `index`'s ring (clamped to the markers): (X, 0.01, Z); the chamber's centre at y = 0.01
    /// when there is no marker.
    public static func markerCentre(_ index: Int, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.markers.isEmpty else { return SIMD3(0, markerY, 0) }
        let cell: EchoCartographerCell = snapshot.markers[min(max(index, 0), snapshot.markers.count - 1)]
        let c: SIMD3<Double> = cellCentre(cell, snapshot)
        return SIMD3(c.x, markerY, c.z)
    }

    /// The width of one gauge slot, 1.8 / budget.
    public static func gaugeSlot(_ snapshot: EchoCartographerSceneSnapshot) -> Double {
        (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of gauge bar `index` (of `budget` slots across x −0.9 … 0.9): (−0.9 + (index + 0.5)·slot, 0, 1.0).
    public static func gaugeBar(_ index: Int, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * gaugeSlot(snapshot), gaugeY, gaugeZ)
    }

    /// The bars drawn lit: the energy left, clamped to 0 … budget (the first bars are lit).
    public static func litBars(_ snapshot: EchoCartographerSceneSnapshot) -> Int {
        min(max(snapshot.energy, 0), max(snapshot.budget, 0))
    }

    /// The struck distance in cells of every wall the last pulse struck, by cell (empty without a pulse).
    /// The won flag of the wall edge strips: 1 when the level is won (every beacon located), else 0 (feature 403
    /// convergence, T-R02G1103-014; the spec's edge case "the chamber's known walls brighten").
    public static func wonFlag(_ snapshot: EchoCartographerSceneSnapshot) -> Double {
        snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil) ? 1 : 0
    }

    public static func struckDistances(_ snapshot: EchoCartographerSceneSnapshot) -> [EchoCartographerCell: Int] {
        var result: [EchoCartographerCell: Int] = [:]
        guard let echo = snapshot.lastEcho else { return result }
        for ray in echo.rays {
            if let wall = ray.wall { result[wall] = ray.distance }
        }
        return result
    }

    /// The end of `ray` from the emitter's centre: (distance − 0.5)·s along its direction, the struck wall cell's near
    /// face or the chamber's edge, on the floor plane.
    public static func rayEnd(_ ray: EchoCartographerRay, from emitter: EchoCartographerCell,
                              _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double> {
        let s: Double = cellSize(snapshot)
        let start: SIMD3<Double> = cellCentre(emitter, snapshot)
        let (dx, dy) = ray.direction.step
        let length: Double = (Double(max(ray.distance, 1)) - 0.5) * s
        return SIMD3(start.x + Double(dx) * length, 0, start.z + Double(dy) * length)
    }

    /// The reference points of the simulator frame checks: every known-open cell's centre, every known wall's top-face
    /// centre, the entry, every marker's centre and the gauge's first bar (clarification Q3).
    public static func referencePoints(_ snapshot: EchoCartographerSceneSnapshot) -> EchoCartographerReferencePoints {
        var floors: [SIMD3<Double>] = []
        for cell in snapshot.openCells { floors.append(cellCentre(cell, snapshot)) }
        var walls: [SIMD3<Double>] = []
        for cell in snapshot.wallCells { walls.append(wallTop(cell, snapshot)) }
        var markers: [SIMD3<Double>] = []
        for index in snapshot.markers.indices { markers.append(markerCentre(index, snapshot)) }
        return EchoCartographerReferencePoints(floors: floors, walls: walls, entry: entryCentre(snapshot),
                                               markers: markers, firstGaugeBar: gaugeBar(0, snapshot))
    }

    /// The solids (known walls and located beacons' pillars) in painter's order: ascending Z (far first), then
    /// descending |X| (outside in), then ascending X. `isWall` tells a block from a pillar.
    public static func solidOrder(_ snapshot: EchoCartographerSceneSnapshot) -> [(cell: EchoCartographerCell, isWall: Bool)] {
        var solids: [(cell: EchoCartographerCell, isWall: Bool)] = []
        for cell in snapshot.wallCells { solids.append((cell: cell, isWall: true)) }
        for cell in snapshot.located where snapshot.known(cell) != .wall { solids.append((cell: cell, isWall: false)) }
        let w: Int = snapshot.width
        solids.sort { a, b in
            if a.cell.y != b.cell.y { return a.cell.y < b.cell.y }
            // |X| ∝ |2x + 1 − W|, compared in whole numbers.
            let da: Int = abs(2 * a.cell.x + 1 - w)
            let db: Int = abs(2 * b.cell.x + 1 - w)
            if da != db { return da > db }
            return a.cell.x < b.cell.x
        }
        return solids
    }

    // MARK: Meshes

    /// The chamber with fallback colours (unlit palette colours, no flare) for the shared unlit renderer: the chamber
    /// mesh without the ring field, which only the shader can draw.
    public static func chamberPart(_ snapshot: EchoCartographerSceneSnapshot,
                                   tier: EchoCartographerTier) throws(MeshError) -> EchoCartographerColouredMesh {
        try build(snapshot, ringField: false)
    }

    /// The chamber mesh for the chamber program, in painter's order; the ring field only when `tier.rings`.
    /// `reduceMotion` is accepted for parity with the shader path (the shader draws rings and flares at rest); no
    /// position depends on it.
    public static func chamberMesh(_ snapshot: EchoCartographerSceneSnapshot, tier: EchoCartographerTier,
                                   reduceMotion: Bool) throws(MeshError) -> Mesh {
        _ = reduceMotion
        return try build(snapshot, ringField: tier.rings).mesh
    }

    /// Builds the chamber in painter's order: ground, floor tiles, entry, markers, rays, ring field (when `ringField`),
    /// solids back to front (each block's faces then its 12 edge strips; pillars), gauge.
    static func build(_ snapshot: EchoCartographerSceneSnapshot,
                      ringField: Bool) throws(MeshError) -> EchoCartographerColouredMesh {
        var parts: Parts = Parts()
        let s: Double = cellSize(snapshot)
        let half: SIMD2<Double> = halfExtent(snapshot)
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        // Ground.
        let gx: Double = half.x + groundBorder
        let gz: Double = half.y + groundBorder
        try parts.quad([SIMD3(-gx, groundY, -gz), SIMD3(gx, groundY, -gz), SIMD3(gx, groundY, gz),
                        SIMD3(-gx, groundY, gz)], normal: up, slot: up, material: .ground, local: [0, 0, 0, 0])
        // Floor tiles.
        let tile: Double = tileWidth * s / 2
        for cell in snapshot.openCells {
            let c: SIMD3<Double> = cellCentre(cell, snapshot)
            try parts.fan(centre: c, outline: [SIMD3(c.x - tile, 0, c.z - tile), SIMD3(c.x + tile, 0, c.z - tile),
                                               SIMD3(c.x + tile, 0, c.z + tile), SIMD3(c.x - tile, 0, c.z + tile)],
                          material: .floor)
        }
        // Entry diamond.
        let e: SIMD3<Double> = entryCentre(snapshot)
        let tip: Double = entrySide * s / 2 * 2.0.squareRoot()
        try parts.fan(centre: e, outline: [SIMD3(e.x, entryY, e.z - tip), SIMD3(e.x + tip, entryY, e.z),
                                           SIMD3(e.x, entryY, e.z + tip), SIMD3(e.x - tip, entryY, e.z)],
                      material: .entry)
        // Marker rings.
        let inner: Double = (markerRadius - markerLine / 2) * s
        let outer: Double = (markerRadius + markerLine / 2) * s
        for index in snapshot.markers.indices {
            let c: SIMD3<Double> = markerCentre(index, snapshot)
            for i in 0..<markerSegments {
                let a0: Double = 2 * Double.pi * Double(i) / Double(markerSegments)
                let a1: Double = 2 * Double.pi * Double(i + 1) / Double(markerSegments)
                let d0: SIMD3<Double> = SIMD3(cos(a0), 0, sin(a0))
                let d1: SIMD3<Double> = SIMD3(cos(a1), 0, sin(a1))
                try parts.quad([c + d0 * inner, c + d0 * outer, c + d1 * outer, c + d1 * inner], normal: up, slot: up,
                               material: .marker, local: [-1, 1, 1, -1])
            }
        }
        // Rays of the last pulse.
        if let echo = snapshot.lastEcho {
            let start: SIMD3<Double> = cellCentre(echo.emitter, snapshot)
            let w: Double = rayWidth * s / 2
            for ray in echo.rays {
                let end: SIMD3<Double> = rayEnd(ray, from: echo.emitter, snapshot)
                let (dx, dy) = ray.direction.step
                let side: SIMD3<Double> = SIMD3(Double(-dy), 0, Double(dx)) * w
                let a: SIMD3<Double> = SIMD3(start.x, rayY, start.z)
                let b: SIMD3<Double> = SIMD3(end.x, rayY, end.z)
                try parts.quad([a - side, b - side, b + side, a + side], normal: up, slot: up, material: .ray,
                               local: [-1, -1, 1, 1])
            }
        }
        // Ring field.
        if ringField {
            try parts.quad([SIMD3(-half.x, ringY, -half.y), SIMD3(half.x, ringY, -half.y),
                            SIMD3(half.x, ringY, half.y), SIMD3(-half.x, ringY, half.y)], normal: up, slot: up,
                           material: .ring, local: [0, 0, 0, 0])
        }
        // Solids, back to front.
        let struck: [EchoCartographerCell: Int] = struckDistances(snapshot)
        // Feature 403 convergence (T-R02G1103-014): on a won level every known wall's edges carry the won flag in the
        // normal slot's y, which the shader lifts toward the flare colour at every tier (no position changes).
        let wonFlag: Double = wonFlag(snapshot)
        for solid in solidOrder(snapshot) {
            let c: SIMD3<Double> = cellCentre(solid.cell, snapshot)
            if solid.isWall {
                let h: Double = wallWidth * s / 2
                let top: Double = wallHeight * s
                try parts.box(centre: c, half: h, height: top, material: .wallFace, slot: nil)
                let distance: Double = Double(struck[solid.cell] ?? 0)
                try parts.edges(centre: c, half: h, height: top, halfWidth: edgeThickness * s / 2, lift: edgeLift,
                                material: .wallEdge, slot: SIMD3(distance, wonFlag, 0), glow: nil)
            } else {
                try parts.box(centre: c, half: pillarWidth * s / 2, height: pillarHeight * s, material: .pillar,
                              slot: nil)
            }
        }
        // Gauge.
        let budget: Int = max(snapshot.budget, 0)
        let lit: Int = litBars(snapshot)
        let bar: Double = gaugeFill * gaugeSlot(snapshot) / 2
        let depth: Double = gaugeDepth / 2
        for index in 0..<budget {
            let c: SIMD3<Double> = gaugeBar(index, snapshot)
            try parts.fan(centre: c, outline: [SIMD3(c.x - bar, gaugeY, c.z - depth), SIMD3(c.x + bar, gaugeY, c.z - depth),
                                               SIMD3(c.x + bar, gaugeY, c.z + depth), SIMD3(c.x - bar, gaugeY, c.z + depth)],
                          material: index < lit ? .gaugeLit : .gaugeUnlit)
        }
        return parts.built()
    }

    /// The glow shells around every wall's edges and every pillar, outermost shell first (shell k = tier.glowShells …
    /// 1): edge shell k is the folded strip widened to 0.025·s + 0.006·s·k per side and lifted (k + 1)·``edgeLift``;
    /// pillar shell k is the pillar grown by 0.025·s·k in half width and height. The glow colour in the normal slot,
    /// uv = (0.5^k, 0); fallback colours the glow colour times the factor. Solids in painter's order within a shell.
    /// Empty when the tier has no glow.
    public static func glowPart(_ snapshot: EchoCartographerSceneSnapshot,
                                tier: EchoCartographerTier) throws(MeshError) -> EchoCartographerColouredMesh {
        var parts: Parts = Parts()
        let shells: Int = min(max(tier.glowShells, 0), 2)
        guard shells > 0 else { return parts.built() }
        let s: Double = cellSize(snapshot)
        let solids: [(cell: EchoCartographerCell, isWall: Bool)] = solidOrder(snapshot)
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            for solid in solids {
                let c: SIMD3<Double> = cellCentre(solid.cell, snapshot)
                if solid.isWall {
                    try parts.edges(centre: c, half: wallWidth * s / 2, height: wallHeight * s,
                                    halfWidth: (edgeThickness / 2 + edgeGlowGrowth * Double(k)) * s,
                                    lift: edgeLift * Double(k + 1), material: .wallEdge,
                                    slot: EchoCartographerPalette.glow, glow: factor)
                } else {
                    try parts.box(centre: c, half: (pillarWidth / 2 + pillarGlowGrowth * Double(k)) * s,
                                  height: (pillarHeight + pillarGlowGrowth * Double(k)) * s, material: .pillar,
                                  slot: EchoCartographerPalette.glow, glow: factor)
                }
            }
        }
        return parts.built()
    }

    /// The glow mesh for the glow program (`glowPart` without colours).
    public static func glowMesh(_ snapshot: EchoCartographerSceneSnapshot,
                                tier: EchoCartographerTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
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

    /// The dot product of `a` and `b`, summed x, y, z in that order.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    /// The cross product a × b.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// `v` scaled to unit length (unchanged when zero).
    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let l: Double = dot(v, v).squareRoot()
        return l > 0 ? v / l : v
    }

    /// The fixed camera for `aspect`: from (0, 2.4, 1.9) looking at (0, 0, 0.05) with +y up; the vertical field of view
    /// is the smallest that holds every corner of the box x −1 … 1, y 0 … 0.8, z −1 … 1.1 inside the view with
    /// ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it — every cell centre,
    /// wall top, pillar and gauge bar — keeps a margin of at least 5 %). The snapshot is accepted for parity; the camera
    /// never moves while a level is played. Equals ``camera(_:aspect:orbit:)`` at ``EchoCartographerOrbit/authored``
    /// bit for bit.
    public static func camera(_ snapshot: EchoCartographerSceneSnapshot, aspect: Double) -> EchoCartographerCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The eye of `orbit` (clamped): the authored eye's offset from the look-at point, with e = (0, 2.4, 1.85), first
    /// pitched about the x axis (positive p raises it: (0, e.y·cos p + e.z·sin p, −e.y·sin p + e.z·cos p)), then yawed
    /// about +y (z′ → (z′·sin y, z′·cos y)), added back to the look-at point. Exactly ``eye`` at the authored orbit.
    public static func orbitEye(_ orbit: EchoCartographerOrbit) -> SIMD3<Double> {
        let o: EchoCartographerOrbit = orbit.clamped()
        guard o.yaw != 0 || o.pitch != 0 else { return eye }
        let e: SIMD3<Double> = eye - lookAt
        let cp: Double = cos(o.pitch)
        let sp: Double = sin(o.pitch)
        let y: Double = e.y * cp + e.z * sp
        let z: Double = -e.y * sp + e.z * cp
        return lookAt + SIMD3(z * sin(o.yaw), y, z * cos(o.yaw))
    }

    /// The camera for `orbit` (clamped, see ``EchoCartographerOrbit/clamped()``) and `aspect`: from ``orbitEye(_:)``
    /// looking at (0, 0, 0.05) with +y up (never parallel: the eye stays at least 37° above the floor); the vertical
    /// field of view is the smallest that holds every corner of the box x −1 … 1, y 0 … 0.8, z −1 … 1.1 inside the view
    /// with ``fitMargin`` per side, so everything inside the box keeps a margin of at least 5 % at every orbit and
    /// aspect 0.4 … 2.5. Presentation only; independent of the snapshot, the tier and the time.
    public static func camera(_ snapshot: EchoCartographerSceneSnapshot, aspect: Double,
                              orbit: EchoCartographerOrbit) -> EchoCartographerCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
        let eye: SIMD3<Double> = orbitEye(orbit)
        let forward: SIMD3<Double> = unit(lookAt - eye)
        let right: SIMD3<Double> = unit(cross(forward, SIMD3(0, 1, 0)))
        let up: SIMD3<Double> = cross(right, forward)
        let limit: Double = 1 - 2 * fitMargin
        var tanHalf: Double = 0
        var nearest: Double = Double.infinity
        var farthest: Double = 0
        for index in 0..<8 {
            let r: SIMD3<Double> = corner(index) - eye
            let depth: Double = dot(r, forward)
            nearest = min(nearest, depth)
            farthest = max(farthest, depth)
            tanHalf = max(tanHalf, abs(dot(r, up)) / depth / limit, abs(dot(r, right)) / depth / (a * limit))
        }
        let fovY: Double = 2 * atan(tanHalf)
        let near: Double = max(nearest * 0.5, 1e-3)
        let far: Double = farthest + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(lookAt), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return EchoCartographerCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far,
                                      view: view, projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: EchoCartographerCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// Collects vertices with fallback colours and triangles wound to face their front.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []

        /// Adds (or welds) a vertex at `p` with normal slot `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour`.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(EchoCartographerSceneGeometry.vec(p),
                                                normal: EchoCartographerSceneGeometry.vec(slot),
                                                uv: Vec2(code, local))
            if Int(id) == colours.count {
                colours.append(Vec4(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from the side `front` points to; degenerate triangles are
        /// skipped.
        mutating func facing(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            let n: SIMD3<Double> = EchoCartographerSceneGeometry.cross(pb - pa, pc - pa)
            let side: Double = EchoCartographerSceneGeometry.dot(n, front)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A convex quad (corners in order) facing `normal`, normal slot `slot`, local coordinates `local` per corner;
        /// `glow` (when given) replaces the material code with the glow factor and colours it slot × factor.
        mutating func quad(_ p: [SIMD3<Double>], normal: SIMD3<Double>, slot: SIMD3<Double>, material: Material,
                           local: [Double], glow: Double? = nil) throws(MeshError) {
            let code: Double = glow ?? material.code
            let colour: SIMD3<Double> = glow.map { slot * $0 } ?? material.colour
            var ids: [UInt32] = []
            for k in 0..<4 {
                ids.append(try vertex(p[k], slot: slot, code: code, local: glow == nil ? local[k] : 0, colour: colour))
            }
            try facing((ids[0], ids[1], ids[2]), p[0], p[1], p[2], front: normal)
            try facing((ids[0], ids[2], ids[3]), p[0], p[2], p[3], front: normal)
        }

        /// A flat fan facing +y: the centre vertex (d = 0) and the outline's corners (d = 1).
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], material: Material) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let c: UInt32 = try vertex(centre, slot: up, code: material.code, local: 0, colour: material.colour)
            var ids: [UInt32] = []
            for p in outline {
                ids.append(try vertex(p, slot: up, code: material.code, local: 1, colour: material.colour))
            }
            for k in 0..<outline.count {
                let j: Int = (k + 1) % outline.count
                try facing((c, ids[k], ids[j]), centre, outline[k], outline[j], front: up)
            }
        }

        /// A box standing on the floor at `centre` (top and four sides; the hidden bottom omitted), `half` wide on each
        /// side and `height` high, each face wound outward. The normal slot is the face normal, or `slot` when given
        /// (glow); local coordinates 0.
        mutating func box(centre: SIMD3<Double>, half: Double, height: Double, material: Material,
                          slot: SIMD3<Double>?, glow: Double? = nil) throws(MeshError) {
            let x0: Double = centre.x - half
            let x1: Double = centre.x + half
            let z0: Double = centre.z - half
            let z1: Double = centre.z + half
            let faces: [(normal: SIMD3<Double>, corners: [SIMD3<Double>])] = [
                (normal: SIMD3(0, 0, -1), corners: [SIMD3(x0, 0, z0), SIMD3(x1, 0, z0), SIMD3(x1, height, z0),
                                                    SIMD3(x0, height, z0)]),
                (normal: SIMD3(-1, 0, 0), corners: [SIMD3(x0, 0, z0), SIMD3(x0, 0, z1), SIMD3(x0, height, z1),
                                                    SIMD3(x0, height, z0)]),
                (normal: SIMD3(1, 0, 0), corners: [SIMD3(x1, 0, z0), SIMD3(x1, 0, z1), SIMD3(x1, height, z1),
                                                   SIMD3(x1, height, z0)]),
                (normal: SIMD3(0, 0, 1), corners: [SIMD3(x0, 0, z1), SIMD3(x1, 0, z1), SIMD3(x1, height, z1),
                                                   SIMD3(x0, height, z1)]),
                (normal: SIMD3(0, 1, 0), corners: [SIMD3(x0, height, z0), SIMD3(x1, height, z0), SIMD3(x1, height, z1),
                                                   SIMD3(x0, height, z1)]),
            ]
            for face in faces {
                try quad(face.corners, normal: face.normal, slot: slot ?? face.normal, material: material,
                         local: [0, 0, 0, 0], glow: glow)
            }
        }

        /// The 12 edge strips of the box at `centre` (`half`, `height`), each folded over its edge: `halfWidth` onto
        /// each adjacent face (a bottom edge: up its side face and outward on the floor plane), d = 0 on the edge, −1
        /// and +1 on the far sides, lifted `lift` off the faces, wound to face outward (up on the floor plane).
        mutating func edges(centre: SIMD3<Double>, half: Double, height: Double, halfWidth: Double, lift: Double,
                            material: Material, slot: SIMD3<Double>, glow: Double?) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let sides: [SIMD3<Double>] = [SIMD3(0, 0, -1), SIMD3(1, 0, 0), SIMD3(0, 0, 1), SIMD3(-1, 0, 0)]
            // (edge start, edge end, (direction, normal) of the half with d = −1, of the half with d = +1).
            var list: [(a: SIMD3<Double>, b: SIMD3<Double>, first: (SIMD3<Double>, SIMD3<Double>),
                        second: (SIMD3<Double>, SIMD3<Double>))] = []
            for (i, n) in sides.enumerated() {
                let t: SIMD3<Double> = sides[(i + 1) % 4]
                let mid: SIMD3<Double> = SIMD3(centre.x + n.x * half, 0, centre.z + n.z * half)
                let a0: SIMD3<Double> = mid - t * half
                let b0: SIMD3<Double> = mid + t * half
                // Top edge: on the top face (inward) and on the side face (down).
                list.append((a: a0 + up * height, b: b0 + up * height, first: (-n, up), second: (-up, n)))
                // Bottom edge: up the side face and outward on the floor plane.
                list.append((a: a0, b: b0, first: (up, n), second: (n, up)))
                // Vertical edge at the corner between side n and side t.
                let corner: SIMD3<Double> = b0
                list.append((a: corner, b: corner + up * height, first: (-t, n), second: (-n, t)))
            }
            for edge in list {
                let lean: SIMD3<Double> = EchoCartographerSceneGeometry.unit(edge.first.1 + edge.second.1) * lift
                let ca: SIMD3<Double> = edge.a + lean
                let cb: SIMD3<Double> = edge.b + lean
                for (fold, d) in [(edge.first, -1.0), (edge.second, 1.0)] {
                    let offset: SIMD3<Double> = fold.0 * halfWidth + fold.1 * lift
                    try quad([ca, cb, edge.b + offset, edge.a + offset], normal: fold.1, slot: slot, material: material,
                             local: [0, 0, d, d], glow: glow)
                }
            }
        }

        /// The coloured mesh built so far.
        func built() -> EchoCartographerColouredMesh {
            EchoCartographerColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
