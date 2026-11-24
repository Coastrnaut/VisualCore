// VoxelOrigamiSceneGeometry — feature 443 (R02-G15-03) T-R02G1503-004 (FR-R02G1503-001, 002, 004, 006; clarifications
// Q1, Q2, Q3, Q4). The voxel scene of Voxel Origami, built from a snapshot only. x points right, y up and z towards
// the default viewer. Kernel cell c maps to world space by w(c) = (c − m) · s, where m is the centre of the bounding
// box of the occupied cells together with the target cells at the best allowed alignment (``VoxelOrigamiSceneSnapshot/
// target``), and s = 1.5 / (e + 1) with e the box's largest extent in cells, so the chain and its target always fit the
// cube −0.75 … 0.75.
//
// Draw order (clarification Q1; depth testing off, so the voxel mesh is in painter's order):
//   1. the night backdrop, one large quad facing the eye behind the authored box;
//   2. the elements (``VoxelOrigamiElement``) back to front by the distance of their centres from the eye (farthest
//      first; ties by kind — target outline, cube, hinge, pip, bar — then by index):
//      - target outline i: a wireframe cube of side 0.96 s at w(target[i]), its 12 edges camera-facing strips of the
//        tier's width (`tier.edgeWidth` · s) in turquoise (a won level flares it to the target glow colour);
//      - cube i: a chamfered cube of side 0.9 s at w(cells[i]) turned by its orientation, frosted ivory: its flat faces
//        and its rounded chamfer of 0.12 of the side in `tier.bevelSteps` facets per half edge (a plain box at
//        level-2), back-facing pieces first; on each face an inner glyph (a diamond of radius 0.2 s: solid turquoise
//        when the cube's cell is a target cell, a hollow grey band 0.13 s … 0.2 s otherwise) and on its own +z face
//        (i mod 6) + 1 dice dots of radius 0.055 s; a failure (``VoxelOrigamiSceneSnapshot/brokenTurn``) outlines the
//        moving and the still cube by a wireframe of side 1.0 s in the broken colour and marks the still cube's cell
//        (the cell they meet in) by a cross of two strips; a won level lights every cube (the fallback colour lifted
//        by ``wonLift``, every cube glowing) without moving anything;
//      - hinge h (1 … n − 1): a camera-facing bar centred on the face between cube h's parent and cube h, 0.6 s long
//        along the hinge axis (parent to cube) and 0.12 s wide, grey; the chosen hinge hot pink (striped by the
//        shader);
//      - covered pip i (one per cube): at (−0.8 + (i + 0.5) · 1.6 / n, −1.05, 0), a square of side
//        min(0.06, 0.6 · slot) facing the camera, lit (filled) for i below the covered count, else an outline a
//        fifth of the side wide;
//      - moves bar i (`budget` bars): at (−0.9 + (i + 0.5) · 1.8 / budget, −1.2, 0), four fifths of its slot wide (a
//        fifth gap) and 0.04 tall, facing the camera, lit for i below the actions left.
// The glow mesh is drawn last, additively: `tier.glowShells` shells k (outermost first) as camera-facing bands around
// every lit cube (on a target cell, or every cube on a won level; from half size 0.5 s, growing 0.12 s per shell) and
// every target cell (from half size 0.55 s, growing 0.1 s per shell), lifted 0.001 · k towards the eye; empty at
// level-2.
//
// Material codes (a_uv.x of the voxel mesh): ``VoxelOrigamiShaders/Material``, 0 backdrop … 13 broken; the local
// coordinate a_uv.y follows ``VoxelOrigamiShaders/Material/localCoordinate``.
//
// Vertex streams (attributes a_position, a_normal, a_uv; the contract with `VoxelOrigamiShaders`). Voxel mesh: a_uv.x
// is the material code and a_uv.y the local coordinate d: strips (target edges, failure outlines and cross strips,
// unchosen hinge bars, hollow glyph rings, unlit pips) −1 on one long side (or the inner edge) and +1 on the other;
// the chosen hinge's bar −1 at the parent's end and +1 at the cube's end (along the axis, for the stripes); fans (flat
// cube faces, solid glyphs, dots, lit pips, moves bars) 0 at the centre vertex and 1 on the outline; chamfer facets
// −1 on the flat face's edge and 0 on the diagonal between two faces (|d| falls to the ridge); the backdrop 0. a_normal
// is the unit outward world-space facet normal on cube faces, bevels, glyphs and dots, and the unit direction towards
// the eye elsewhere. Glow mesh: a_normal is the base colour (``VoxelOrigamiPalette/glow`` for cubes,
// ``VoxelOrigamiPalette/targetGlow`` for target cells), a_uv.x = ``VoxelOrigamiShaders/GlowKind/code(factor:)`` (cube
// 0, target 1; factor 0.5^k; the shader flares the target on a won level) and a_uv.y the shell's radial coordinate r,
// 0 inner and 1 outer. The scene draws with back-face culling on and depth testing off: every triangle winds
// counter-clockwise seen from outside its solid (cube faces, bevels, glyphs and dots) or from the eye (the backdrop,
// strips, bars, pips, outlines and glow), and the index order is the painter's order (the backdrop, then the elements
// farthest first; within a cube its back-facing pieces, then its front-facing pieces, each flat face followed by its
// glyph and dots). Tiers change only the chamfer, the target edge width and the glow: every position named above is
// the same at every tier. Reduce Motion draws the cubes at their cells without a turning preview; this geometry never
// previews a turn, so both draw the same. Doubles are used for drawing only; nothing here is consulted by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct VoxelOrigamiCamera: Sendable, Equatable {
    /// The eye position in world units, (1.4, 1.1, 2.6).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.1, 0).
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
public struct VoxelOrigamiElement: Sendable, Equatable {
    /// The kind of an element, in the tie order of the painter's order.
    public enum Kind: Int, Sendable, CaseIterable {
        /// A target cell's wireframe cube.
        case targetOutline = 0
        /// A cube.
        case cube = 1
        /// A hinge mark.
        case hinge = 2
        /// A covered pip.
        case pip = 3
        /// A moves bar.
        case bar = 4
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind: target cell, cube, hinge (1 … n − 1), pip or bar.
    public let index: Int
    /// The element's centre in world units.
    public let centre: SIMD3<Double>
    /// The distance of the centre from the eye.
    public let distance: Double

    /// An element of the given values.
    public init(kind: Kind, index: Int, centre: SIMD3<Double>, distance: Double) {
        self.kind = kind
        self.index = index
        self.centre = centre
        self.distance = distance
    }

    /// Whether `a` is painted before `b`: farther first, then the lower kind, then the lower index.
    public static func paintsBefore(_ a: VoxelOrigamiElement, _ b: VoxelOrigamiElement) -> Bool {
        if a.distance != b.distance { return a.distance > b.distance }
        if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
        return a.index < b.index
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct VoxelOrigamiColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Voxel Origami scene from a `VoxelOrigamiSceneSnapshot`: places, meshes, camera and projection.
public enum VoxelOrigamiSceneGeometry {
    /// The material codes (shared with the shaders).
    public typealias Material = VoxelOrigamiShaders.Material

    // MARK: Constants (world units, or shares of the cell scale s where stated)

    /// The span the chain and its target fit: s = span / (e + 1).
    public static let span: Double = 1.5
    /// A target wireframe cube's side, in s.
    public static let targetSide: Double = 0.96
    /// A cube's side, in s.
    public static let cubeSide: Double = 0.9
    /// The chamfer as a share of the cube's side (when the tier has bevel steps).
    public static let chamferShare: Double = 0.12
    /// The inner glyph's radius (a diamond), in s.
    public static let glyphRadius: Double = 0.2
    /// The hollow glyph's inner radius, in s.
    public static let glyphInner: Double = 0.13
    /// How far glyphs sit outside their face, in s.
    public static let glyphLift: Double = 0.002
    /// How far dots sit outside their face, in s.
    public static let dotLift: Double = 0.004
    /// A dice dot's radius, in s.
    public static let dotRadius: Double = 0.055
    /// The dice dots' grid spacing, in s.
    public static let dotSpacing: Double = 0.24
    /// A dice dot's segments.
    public static let dotSegments: Int = 8
    /// A hinge bar's length along the axis, in s.
    public static let hingeLength: Double = 0.6
    /// A hinge bar's width, in s.
    public static let hingeWidth: Double = 0.12
    /// A failure outline's wireframe side, in s.
    public static let brokenSide: Double = 1.0
    /// A failure outline's edge width, in s.
    public static let brokenWidth: Double = 0.06
    /// A failure cell mark's strip length, in s.
    public static let markLength: Double = 0.6
    /// A failure cell mark's strip width, in s.
    public static let markWidth: Double = 0.08
    /// The gauges' plane.
    public static let gaugeZ: Double = 0
    /// The covered pips' centre line.
    public static let pipY: Double = -1.05
    /// The covered pips' left end.
    public static let pipStart: Double = -0.8
    /// The covered pips' right end.
    public static let pipEnd: Double = 0.8
    /// A pip's largest side.
    public static let pipSideMax: Double = 0.06
    /// A pip's side as a share of its slot when the slot is narrow.
    public static let pipFill: Double = 0.6
    /// An unlit pip's outline width as a share of its side.
    public static let pipLine: Double = 0.2
    /// The moves bars' centre line.
    public static let movesY: Double = -1.2
    /// The moves bars' left end.
    public static let movesStart: Double = -0.9
    /// The moves bars' right end.
    public static let movesEnd: Double = 0.9
    /// The share of a slot a moves bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// A moves bar's height.
    public static let barHeight: Double = 0.04
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// A lit cube's glow: the inner half size, in s.
    public static let cubeGlowInner: Double = 0.5
    /// A lit cube's glow growth per shell, in s.
    public static let cubeGlowGrowth: Double = 0.12
    /// A target cell's glow: the inner half size, in s.
    public static let targetGlowInner: Double = 0.55
    /// A target cell's glow growth per shell, in s.
    public static let targetGlowGrowth: Double = 0.1
    /// Lift towards the eye per glow shell.
    public static let glowLift: Double = 0.001
    /// How far a won level lifts the cubes' fallback colour towards white.
    public static let wonLift: Double = 0.35
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(1.4, 1.1, 2.6)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.1, 0)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-0.95, -1.25, -0.95)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(0.95, 0.95, 0.95)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places (the CPU reference)

    /// The bounding box (lower and upper corner, in cells) of the occupied cells and the target cells.
    static func bounds(_ snapshot: VoxelOrigamiSceneSnapshot) -> (low: SIMD3<Double>, high: SIMD3<Double>) {
        var cells: [VoxelOrigamiVector] = snapshot.cells
        cells.append(contentsOf: snapshot.target)
        guard let first = cells.first else { return (SIMD3(0, 0, 0), SIMD3(0, 0, 0)) }
        var low: SIMD3<Double> = SIMD3(Double(first.x), Double(first.y), Double(first.z))
        var high: SIMD3<Double> = low
        for cell in cells {
            let p: SIMD3<Double> = SIMD3(Double(cell.x), Double(cell.y), Double(cell.z))
            low = SIMD3(min(low.x, p.x), min(low.y, p.y), min(low.z, p.z))
            high = SIMD3(max(high.x, p.x), max(high.y, p.y), max(high.z, p.z))
        }
        return (low, high)
    }

    /// The centre m of the bounding box of the occupied cells and the target cells, in cells.
    public static func middle(_ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double> {
        let box: (low: SIMD3<Double>, high: SIMD3<Double>) = bounds(snapshot)
        return (box.low + box.high) / 2
    }

    /// The cell scale s = 1.5 / (e + 1), e the largest extent of the box of the occupied and the target cells.
    public static func scale(_ snapshot: VoxelOrigamiSceneSnapshot) -> Double {
        let box: (low: SIMD3<Double>, high: SIMD3<Double>) = bounds(snapshot)
        let extent: SIMD3<Double> = box.high - box.low
        return span / (max(extent.x, extent.y, extent.z) + 1)
    }

    /// The world point of kernel cell `cell`: w(c) = (c − m) · s.
    public static func world(_ cell: VoxelOrigamiVector, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double> {
        let c: SIMD3<Double> = SIMD3(Double(cell.x), Double(cell.y), Double(cell.z))
        return (c - middle(snapshot)) * scale(snapshot)
    }

    /// `index` clamped to 0 … count − 1 (0 when count is 0).
    static func clamped(_ index: Int, _ count: Int) -> Int { min(max(index, 0), max(count - 1, 0)) }

    /// The centre of cube `index` (clamped): w(cells[index]).
    public static func cubeCentre(_ index: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.cells.isEmpty else { return SIMD3(0, 0, 0) }
        return world(snapshot.cells[clamped(index, snapshot.cells.count)], snapshot)
    }

    /// The parent of cube `hinge` (clamped to 1 … n − 1), or 0.
    static func parent(_ hinge: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> Int {
        guard snapshot.cubes.count > 1 else { return 0 }
        let h: Int = min(max(hinge, 1), snapshot.cubes.count - 1)
        return snapshot.cubes[h].parent ?? 0
    }

    /// The centre of hinge `hinge`'s mark (clamped to 1 … n − 1): the middle of the face between its parent and its
    /// cube, (w(parent) + w(cube)) / 2.
    public static func hingeCentre(_ hinge: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.cubes.count > 1 else { return cubeCentre(0, snapshot) }
        let h: Int = min(max(hinge, 1), snapshot.cubes.count - 1)
        return (cubeCentre(parent(h, snapshot), snapshot) + cubeCentre(h, snapshot)) / 2
    }

    /// How far a hinge mark is drawn from its face towards the eye, as a fraction of s: more than half a cell, so the
    /// mark is nearer the eye than both of its cubes' centres and is painted after them (a mark left in the seam
    /// between the two cubes would be hidden by the nearer one).
    public static let hingeLift: Double = 0.55

    /// Where hinge `hinge`'s mark is drawn for `camera`: ``hingeCentre(_:_:)`` moved ``hingeLift`` · s along the ray
    /// towards the eye, so it projects to the same view point as the face's middle.
    public static func hingeMark(_ hinge: Int, _ snapshot: VoxelOrigamiSceneSnapshot,
                                 camera: VoxelOrigamiCamera) -> SIMD3<Double> {
        let centre: SIMD3<Double> = hingeCentre(hinge, snapshot)
        let toEye: SIMD3<Double> = unit(camera.eye - centre)
        return centre + toEye * (hingeLift * scale(snapshot))
    }

    /// The unit world axis of hinge `hinge` (clamped): from its parent's centre to its cube's.
    public static func hingeAxis(_ hinge: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.cubes.count > 1 else { return SIMD3(1, 0, 0) }
        let h: Int = min(max(hinge, 1), snapshot.cubes.count - 1)
        let d: VoxelOrigamiVector = snapshot.cells[h] - snapshot.cells[parent(h, snapshot)]
        let v: SIMD3<Double> = unit(SIMD3(Double(d.x), Double(d.y), Double(d.z)))
        return dot(v, v) > 0 ? v : SIMD3(1, 0, 0)
    }

    /// The width of one pip slot, 1.6 / cubes.
    public static func pipSlot(_ snapshot: VoxelOrigamiSceneSnapshot) -> Double {
        (pipEnd - pipStart) / Double(max(snapshot.cubes.count, 1))
    }

    /// A pip's side, min(0.06, 0.6 · slot).
    public static func pipSide(_ snapshot: VoxelOrigamiSceneSnapshot) -> Double {
        min(pipSideMax, pipFill * pipSlot(snapshot))
    }

    /// The centre of covered pip `index`: (−0.8 + (index + 0.5) · slot, −1.05, 0).
    public static func coveredPip(_ index: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double> {
        SIMD3(pipStart + (Double(index) + 0.5) * pipSlot(snapshot), pipY, gaugeZ)
    }

    /// The covered pips drawn lit: the report's covered count, clamped to 0 … cubes.
    public static func litPips(_ snapshot: VoxelOrigamiSceneSnapshot) -> Int {
        min(max(snapshot.report.covered, 0), snapshot.cubes.count)
    }

    /// The width of one moves slot, 1.8 / budget.
    public static func movesSlot(_ snapshot: VoxelOrigamiSceneSnapshot) -> Double {
        (movesEnd - movesStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of moves bar `index`: (−0.9 + (index + 0.5) · slot, −1.2, 0).
    public static func movesBar(_ index: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double> {
        SIMD3(movesStart + (Double(index) + 0.5) * movesSlot(snapshot), movesY, gaugeZ)
    }

    /// The moves bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litMoves(_ snapshot: VoxelOrigamiSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The won flag: 1 when the level is won (stage won, or result with a matched shape and no failure), else 0. A
    /// won level lights every cube; no position changes.
    public static func wonFlag(_ snapshot: VoxelOrigamiSceneSnapshot) -> Double {
        snapshot.isWon || (snapshot.stage == .result && snapshot.failure == nil && snapshot.report.matched) ? 1 : 0
    }

    /// Whether cube `index` glows: its cell is a target cell, or the level is won.
    public static func isLit(_ index: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> Bool {
        guard index >= 0, index < snapshot.cells.count else { return false }
        return wonFlag(snapshot) == 1 || snapshot.isOnTarget(index)
    }

    /// Every element with its centre and distance from `camera`'s eye, in painter's order: farthest first, ties by
    /// kind (target outline, cube, hinge, pip, bar) then index (clarification Q1). This is the CPU reference of the
    /// cube centres, hinge marks (``hingeMark(_:_:camera:)``), pips and bars.
    public static func paintOrder(_ snapshot: VoxelOrigamiSceneSnapshot,
                                  camera: VoxelOrigamiCamera) -> [VoxelOrigamiElement] {
        var elements: [VoxelOrigamiElement] = []
        func add(_ kind: VoxelOrigamiElement.Kind, _ index: Int, _ centre: SIMD3<Double>) {
            let d: SIMD3<Double> = centre - camera.eye
            elements.append(VoxelOrigamiElement(kind: kind, index: index, centre: centre,
                                                distance: dot(d, d).squareRoot()))
        }
        for index in snapshot.target.indices { add(.targetOutline, index, world(snapshot.target[index], snapshot)) }
        for index in snapshot.cells.indices { add(.cube, index, cubeCentre(index, snapshot)) }
        if snapshot.cubes.count > 1 {
            for hinge in 1..<snapshot.cubes.count { add(.hinge, hinge, hingeMark(hinge, snapshot, camera: camera)) }
        }
        for index in 0..<snapshot.cubes.count { add(.pip, index, coveredPip(index, snapshot)) }
        for index in 0..<max(snapshot.budget, 0) { add(.bar, index, movesBar(index, snapshot)) }
        elements.sort(by: VoxelOrigamiElement.paintsBefore)
        return elements
    }

    /// `a` mixed towards `b` by `t`.
    static func mix(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ t: Double) -> SIMD3<Double> { a + (b - a) * t }

    /// The fallback colour of `material` (unlit): its palette colour (``VoxelOrigamiShaders/Material/colour``).
    public static func colour(_ material: Material) -> SIMD3<Double> { material.colour }

    /// The dice layout of (index mod 6) + 1 dots, in units of ``dotSpacing`` on the face's (u, v) axes.
    public static func dotLayout(_ index: Int) -> [SIMD2<Double>] {
        let count: Int = ((index % 6) + 6) % 6 + 1
        switch count {
        case 1: return [SIMD2(0, 0)]
        case 2: return [SIMD2(-1, -1), SIMD2(1, 1)]
        case 3: return [SIMD2(-1, -1), SIMD2(0, 0), SIMD2(1, 1)]
        case 4: return [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1)]
        case 5: return [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(0, 0), SIMD2(1, 1), SIMD2(-1, 1)]
        default: return [SIMD2(-1, -1), SIMD2(-1, 0), SIMD2(-1, 1), SIMD2(1, -1), SIMD2(1, 0), SIMD2(1, 1)]
        }
    }

    // MARK: Meshes

    /// The voxel mesh for the voxel program, in painter's order (see the header).
    public static func voxelMesh(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier,
                                 reduceMotion: Bool) throws(MeshError) -> Mesh {
        try voxelPart(snapshot, tier: tier, reduceMotion: reduceMotion).mesh
    }

    /// The glow mesh for the glow program (`glowPart` without colours); empty at level-2.
    public static func glowMesh(_ snapshot: VoxelOrigamiSceneSnapshot,
                                tier: VoxelOrigamiTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    /// The voxel scene with fallback colours (unlit palette colours; the cubes lifted towards white on a won level,
    /// the target edges in the target glow colour) for the shared unlit renderer: the same mesh as
    /// ``voxelMesh(_:tier:reduceMotion:)``. `wonLevel` (0 … 1) scales the won look; nil uses ``wonFlag(_:)``.
    /// Positions never depend on it.
    public static func voxelPart(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier,
                                 reduceMotion: Bool = false,
                                 wonLevel: Double? = nil) throws(MeshError) -> VoxelOrigamiColouredMesh {
        _ = reduceMotion
        var parts: Parts = Parts()
        let s: Double = scale(snapshot)
        let won: Double = wonLevel.map { $0.isFinite ? min(max($0, 0), 1) : 0 } ?? wonFlag(snapshot)
        let view: VoxelOrigamiCamera = camera(snapshot, aspect: 1)
        // 1. Backdrop.
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis()
        var depth: Double = 0
        for index in 0..<8 { depth = max(depth, dot(corner(index) - eye, basis.forward)) }
        depth += 1
        let backCentre: SIMD3<Double> = eye + basis.forward * depth
        let half: Double = depth * 3
        try parts.quad([backCentre - basis.right * half - basis.up * half,
                        backCentre + basis.right * half - basis.up * half,
                        backCentre + basis.right * half + basis.up * half,
                        backCentre - basis.right * half + basis.up * half],
                       normal: basis.forward * -1, material: .backdrop, local: [0, 0, 0, 0])
        // 2. Elements back to front.
        let broken: (hinge: Int, moving: Int, still: Int, cell: VoxelOrigamiVector)? = snapshot.brokenTurn
        let targetColour: SIMD3<Double> = mix(VoxelOrigamiPalette.target, VoxelOrigamiPalette.targetGlow, won)
        let faceColour: SIMD3<Double> = mix(VoxelOrigamiPalette.ivory, SIMD3(1, 1, 1), wonLift * won)
        let bevelColour: SIMD3<Double> = mix(VoxelOrigamiPalette.ivoryShade, SIMD3(1, 1, 1), wonLift * won)
        let pieces: [CubePiece] = cubePieces(half: cubeSide * s / 2,
                                             chamfer: tier.bevelSteps > 0 ? chamferShare * cubeSide * s : 0,
                                             steps: max(tier.bevelSteps, 0))
        let targetCells: Set<VoxelOrigamiVector> = Set(snapshot.target)
        for element in paintOrder(snapshot, camera: view) {
            switch element.kind {
            case .targetOutline:
                try parts.wireCube(centre: element.centre, side: targetSide * s, width: tier.edgeWidth * s,
                                   material: .targetEdge, colour: targetColour)
            case .cube:
                let i: Int = element.index
                let solid: Bool = targetCells.contains(snapshot.cells[i])
                try parts.cube(centre: element.centre, rotation: snapshot.orientations[i], pieces: pieces, s: s,
                               solid: solid, dots: dotLayout(i), faceColour: faceColour, bevelColour: bevelColour)
                if let b = broken, b.moving == i || b.still == i {
                    try parts.wireCube(centre: element.centre, side: brokenSide * s, width: brokenWidth * s,
                                       material: .broken, colour: nil)
                }
                if let b = broken, b.still == i {
                    let mark: SIMD3<Double> = world(b.cell, snapshot)
                    let r: Double = markLength * s / 2 / 2.0.squareRoot()
                    try parts.facingStrip(mark + (basis.up * -1 - basis.right) * r, mark + (basis.up + basis.right) * r,
                                          width: markWidth * s, material: .broken, along: false)
                    try parts.facingStrip(mark + (basis.up - basis.right) * r, mark + (basis.right - basis.up) * r,
                                          width: markWidth * s, material: .broken, along: false)
                }
            case .hinge:
                let h: Int = element.index
                let axis: SIMD3<Double> = hingeAxis(h, snapshot)
                let reach: SIMD3<Double> = axis * (hingeLength * s / 2)
                try parts.facingStrip(element.centre - reach, element.centre + reach, width: hingeWidth * s,
                                      material: h == snapshot.chosenHinge ? .hingeChosen : .hinge,
                                      along: h == snapshot.chosenHinge)
            case .pip:
                let side: Double = pipSide(snapshot) / 2
                if element.index < litPips(snapshot) {
                    try parts.billboardRectangle(centre: element.centre, half: SIMD2(side, side), material: .coveredLit)
                } else {
                    let inner: Double = side * (1 - 2 * pipLine)
                    try parts.billboardFrame(centre: element.centre, inner: SIMD2(inner, inner),
                                             outer: SIMD2(side, side), material: .coveredUnlit, code: nil,
                                             normalSlot: nil, colour: nil, radial: false)
                }
            case .bar:
                let barHalf: SIMD2<Double> = SIMD2(barFill * movesSlot(snapshot) / 2, barHeight / 2)
                try parts.billboardRectangle(centre: element.centre, half: barHalf,
                                             material: element.index < litMoves(snapshot) ? .movesLit : .movesUnlit)
            }
        }
        return parts.built()
    }

    /// The glow with fallback colours (the base colour times the factor) for the shared unlit renderer:
    /// `tier.glowShells` shells k (outermost first), each a camera-facing band from the object's half size (a_uv.y 0)
    /// to it grown by k growths (a_uv.y 1): around every lit cube (``isLit(_:_:)``; ``cubeGlowInner``,
    /// ``cubeGlowGrowth``, colour ``VoxelOrigamiPalette/glow``, factor 0.5^k) and every target cell
    /// (``targetGlowInner``, ``targetGlowGrowth``, colour ``VoxelOrigamiPalette/targetGlow``, factor 0.5^k); each
    /// lifted 0.001 · k towards the eye. a_normal is the base colour, a_uv.x =
    /// ``VoxelOrigamiShaders/GlowKind/code(factor:)``.
    /// Empty at level-2.
    public static func glowPart(_ snapshot: VoxelOrigamiSceneSnapshot,
                                tier: VoxelOrigamiTier) throws(MeshError) -> VoxelOrigamiColouredMesh {
        var parts: Parts = Parts()
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let s: Double = scale(snapshot)
        let towards: SIMD3<Double> = viewBasis().forward * -1
        let glow: SIMD3<Double> = VoxelOrigamiPalette.glow
        let targetGlow: SIMD3<Double> = VoxelOrigamiPalette.targetGlow
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            let lift: SIMD3<Double> = towards * (glowLift * Double(k))
            for cell in snapshot.target {
                let f: Double = factor
                let inner: Double = targetGlowInner * s
                let outer: Double = inner + targetGlowGrowth * s * Double(k)
                try parts.billboardFrame(centre: world(cell, snapshot) + lift, inner: SIMD2(inner, inner),
                                         outer: SIMD2(outer, outer), material: .backdrop,
                                         code: VoxelOrigamiShaders.GlowKind.target.code(factor: f),
                                         normalSlot: targetGlow,
                                         colour: targetGlow * f, radial: true)
            }
            for index in snapshot.cells.indices where isLit(index, snapshot) {
                let inner: Double = cubeGlowInner * s
                let outer: Double = inner + cubeGlowGrowth * s * Double(k)
                try parts.billboardFrame(centre: cubeCentre(index, snapshot) + lift, inner: SIMD2(inner, inner),
                                         outer: SIMD2(outer, outer), material: .backdrop,
                                         code: VoxelOrigamiShaders.GlowKind.cube.code(factor: factor), normalSlot: glow,
                                         colour: glow * factor, radial: true)
            }
        }
        return parts.built()
    }

    /// One piece of a cube in its own frame (centre at the origin): a flat face (a quad, with its face index 0 … 5: +x,
    /// −x, +y, −y, +z, −z) or a flat chamfer triangle.
    struct CubePiece {
        /// The corners, anticlockwise seen from outside.
        var corners: [SIMD3<Double>]
        /// The local coordinate of each corner.
        var locals: [Double]
        /// The outward unit normal.
        var normal: SIMD3<Double>
        /// The face index of a flat face; nil for a chamfer facet.
        var face: Int?
        /// The centre of a flat face (normal · half side), or the centroid of a chamfer triangle.
        var faceCentre: SIMD3<Double>
        /// The face's in-plane axes (u, v) of a flat face.
        var axes: (u: SIMD3<Double>, v: SIMD3<Double>)
    }

    /// The unit axis `a` (0 x, 1 y, 2 z).
    static func axisVector(_ a: Int) -> SIMD3<Double> {
        a == 0 ? SIMD3(1, 0, 0) : (a == 1 ? SIMD3(0, 1, 0) : SIMD3(0, 0, 1))
    }

    /// The pieces of a cube of half side `half` whose edges are rounded by `chamfer` in `steps` facets per half edge
    /// (a plain box for 0 steps): each face's grid of samples ±(half − chamfer + chamfer · tan(k/steps · 45°)) is
    /// pushed onto the rounded box (the point clamped to the inner box plus `chamfer` along the unit offset).
    static func cubePieces(half: Double, chamfer: Double, steps: Int) -> [CubePiece] {
        let c: Double = steps > 0 ? min(max(chamfer, 0), half) : 0
        let inner: Double = half - c
        var positive: [Double] = []
        for k in 0...steps {
            let t: Double = steps > 0 ? tan(Double(k) / Double(steps) * Double.pi / 4) : 1
            positive.append(steps > 0 ? inner + c * t : half)
        }
        var samples: [Double] = []
        for value in positive.reversed() { samples.append(-value) }
        samples.append(contentsOf: positive)
        func pushed(_ q: SIMD3<Double>) -> SIMD3<Double> {
            let clampedQ: SIMD3<Double> = SIMD3(min(max(q.x, -inner), inner), min(max(q.y, -inner), inner),
                                                min(max(q.z, -inner), inner))
            let d: SIMD3<Double> = q - clampedQ
            let l: Double = dot(d, d).squareRoot()
            return l > 0 ? clampedQ + d * (c / l) : q
        }
        func band(_ value: Double) -> Double {
            c > 0 ? min(max((abs(value) - inner) / c, 0), 1) : 0
        }
        var pieces: [CubePiece] = []
        for face in 0..<6 {
            let a: Int = face / 2
            let sign: Double = face % 2 == 0 ? 1 : -1
            let n: SIMD3<Double> = axisVector(a) * sign
            let u: SIMD3<Double> = axisVector((a + 1) % 3)
            let v: SIMD3<Double> = axisVector((a + 2) % 3)
            for i in 0..<(samples.count - 1) {
                for j in 0..<(samples.count - 1) {
                    let us: [Double] = [samples[i], samples[i + 1], samples[i + 1], samples[i]]
                    let vs: [Double] = [samples[j], samples[j], samples[j + 1], samples[j + 1]]
                    var corners: [SIMD3<Double>] = []
                    var locals: [Double] = []
                    for k in 0..<4 {
                        corners.append(pushed(n * half + u * us[k] + v * vs[k]))
                        locals.append(max(band(us[k]), band(vs[k])))
                    }
                    if i == steps && j == steps {
                        pieces.append(CubePiece(corners: corners, locals: [1, 1, 1, 1], normal: n, face: face,
                                                faceCentre: n * half, axes: (u, v)))
                        continue
                    }
                    // A chamfer quad as two flat triangles, each with its own outward normal.
                    for tri in [[0, 1, 2], [0, 2, 3]] {
                        let pa: SIMD3<Double> = corners[tri[0]]
                        let pb: SIMD3<Double> = corners[tri[1]]
                        let pc: SIMD3<Double> = corners[tri[2]]
                        let facet: SIMD3<Double> = unit(cross(pb - pa, pc - pa))
                        guard dot(facet, facet) > 0 else { continue }
                        let middle: SIMD3<Double> = (pa + pb + pc) / 3
                        let normal: SIMD3<Double> = dot(facet, middle) < 0 ? facet * -1 : facet
                        pieces.append(CubePiece(corners: [pa, pb, pc],
                                                locals: [locals[tri[0]] - 1, locals[tri[1]] - 1, locals[tri[2]] - 1],
                                                normal: normal, face: nil, faceCentre: middle, axes: (u, v)))
                    }
                }
            }
        }
        return pieces
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

    /// The dot product of `a` and `b`.
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

    /// The authored view's unit forward, right and up vectors (from ``eye`` towards ``lookAt``, +y up).
    static func viewBasis() -> (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit(lookAt - eye)
        let right: SIMD3<Double> = unit(cross(forward, SIMD3(0, 1, 0)))
        return (forward, right, cross(right, forward))
    }

    /// The fixed camera for `aspect`: from (1.4, 1.1, 2.6) looking at (0, −0.1, 0) with +y up; the vertical field of
    /// view is the smallest that holds every corner of the box x −0.95 … 0.95, y −1.25 … 0.95, z −0.95 … 0.95 inside
    /// the view with ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it —
    /// every cube, hinge, target cell, pip and bar — keeps a margin of at least 5 % for aspect 0.4 … 2.5). Independent
    /// of the snapshot (accepted for parity), the tier and the time.
    public static func camera(_ snapshot: VoxelOrigamiSceneSnapshot, aspect: Double) -> VoxelOrigamiCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis()
        let limit: Double = 1 - 2 * fitMargin
        var tanHalf: Double = 0
        var nearest: Double = Double.infinity
        var farthest: Double = 0
        for index in 0..<8 {
            let r: SIMD3<Double> = corner(index) - eye
            let depth: Double = dot(r, basis.forward)
            nearest = min(nearest, depth)
            farthest = max(farthest, depth)
            tanHalf = max(tanHalf, abs(dot(r, basis.up)) / depth / limit,
                          abs(dot(r, basis.right)) / depth / (a * limit))
        }
        let fovY: Double = 2 * atan(tanHalf)
        let near: Double = max(nearest * 0.5, 1e-3)
        let far: Double = farthest + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(lookAt), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return VoxelOrigamiCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far, view: view,
                                  projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: VoxelOrigamiCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from their normal's side.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []

        /// Adds (or welds) a vertex at `p` with normal slot `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour`.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(VoxelOrigamiSceneGeometry.vec(p),
                                                normal: VoxelOrigamiSceneGeometry.vec(slot), uv: Vec2(code, local))
            if Int(id) == colours.count {
                colours.append(Vec4(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from the side `facing` points to; degenerate triangles are
        /// skipped.
        mutating func triangle(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                               _ pc: SIMD3<Double>, facing: SIMD3<Double>) throws(MeshError) {
            let side: Double = VoxelOrigamiSceneGeometry.dot(VoxelOrigamiSceneGeometry.cross(pb - pa, pc - pa), facing)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A quad (corners in order) facing `normal` with local coordinates `local`; uv.x the material's code (or
        /// `code`), normal slot `slot` (default `normal`), in `colour` (default the material's colour).
        mutating func quad(_ p: [SIMD3<Double>], normal: SIMD3<Double>, material: Material, local: [Double],
                           colour: SIMD3<Double>? = nil, code: Double? = nil,
                           slot: SIMD3<Double>? = nil) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? VoxelOrigamiSceneGeometry.colour(material)
            let value: Double = code ?? Double(material.code)
            let n: SIMD3<Double> = slot ?? normal
            var ids: [UInt32] = []
            for k in 0..<4 { ids.append(try vertex(p[k], slot: n, code: value, local: local[k], colour: tint)) }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2], facing: normal)
            try triangle((ids[0], ids[2], ids[3]), p[0], p[2], p[3], facing: normal)
        }

        /// A chamfer triangle `p` with outward normal `normal` and local coordinates `local`.
        mutating func facet(_ p: [SIMD3<Double>], normal: SIMD3<Double>, local: [Double],
                            colour: SIMD3<Double>) throws(MeshError) {
            let code: Double = Double(Material.cubeBevel.code)
            var ids: [UInt32] = []
            for k in 0..<3 { ids.append(try vertex(p[k], slot: normal, code: code, local: local[k], colour: colour)) }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2], facing: normal)
        }

        /// A fan through the convex `outline` around `centre` facing `normal`: local 0 at the centre and 1 on the
        /// outline.
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], normal: SIMD3<Double>, material: Material,
                          colour: SIMD3<Double>? = nil) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? VoxelOrigamiSceneGeometry.colour(material)
            let c: UInt32 = try vertex(centre, slot: normal, code: Double(material.code), local: 0, colour: tint)
            var ids: [UInt32] = []
            for p in outline {
                ids.append(try vertex(p, slot: normal, code: Double(material.code), local: 1, colour: tint))
            }
            for k in outline.indices {
                let j: Int = (k + 1) % outline.count
                try triangle((c, ids[k], ids[j]), centre, outline[k], outline[j], facing: normal)
            }
        }

        /// A frame between the outlines `inner` and `outer` (corresponding points) facing `normal`: local −1 on the
        /// inner and +1 on the outer edge (a strip), or 0 and 1 when `radial` (a glow shell); uv.x `code` (default the
        /// material's), normal slot `slot` (default `normal`).
        mutating func ring(inner: [SIMD3<Double>], outer: [SIMD3<Double>], normal: SIMD3<Double>, material: Material,
                           code: Double? = nil, slot: SIMD3<Double>? = nil, colour: SIMD3<Double>? = nil,
                           radial: Bool = false) throws(MeshError) {
            let lo: Double = radial ? 0 : -1
            for k in inner.indices {
                let j: Int = (k + 1) % inner.count
                try quad([inner[k], outer[k], outer[j], inner[j]], normal: normal, material: material,
                         local: [lo, 1, 1, lo], colour: colour, code: code, slot: slot)
            }
        }

        /// The unit direction from `point` towards the eye.
        static func towardsEye(_ point: SIMD3<Double>) -> SIMD3<Double> {
            let d: SIMD3<Double> = VoxelOrigamiSceneGeometry.unit(VoxelOrigamiSceneGeometry.eye - point)
            return VoxelOrigamiSceneGeometry.dot(d, d) > 0 ? d : SIMD3(0, 0, 1)
        }

        /// The corners of the camera-facing rectangle of half size `half` around `centre`, anticlockwise from the eye.
        static func billboard(_ centre: SIMD3<Double>, _ half: SIMD2<Double>) -> [SIMD3<Double>] {
            let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) =
                VoxelOrigamiSceneGeometry.viewBasis()
            let r: SIMD3<Double> = basis.right * half.x
            let u: SIMD3<Double> = basis.up * half.y
            return [centre - r - u, centre + r - u, centre + r + u, centre - r + u]
        }

        /// A camera-facing rectangle of half size `half` around `centre`, as a fan.
        mutating func billboardRectangle(centre: SIMD3<Double>, half: SIMD2<Double>,
                                         material: Material) throws(MeshError) {
            try fan(centre: centre, outline: Self.billboard(centre, half),
                    normal: VoxelOrigamiSceneGeometry.viewBasis().forward * -1, material: material)
        }

        /// A camera-facing frame between the half sizes `inner` and `outer` around `centre` (local per ``ring``).
        mutating func billboardFrame(centre: SIMD3<Double>, inner: SIMD2<Double>, outer: SIMD2<Double>,
                                     material: Material, code: Double?, normalSlot: SIMD3<Double>?,
                                     colour: SIMD3<Double>?, radial: Bool) throws(MeshError) {
            try ring(inner: Self.billboard(centre, SIMD2(max(inner.x, 0), max(inner.y, 0))),
                     outer: Self.billboard(centre, outer), normal: VoxelOrigamiSceneGeometry.viewBasis().forward * -1,
                     material: material, code: code, slot: normalSlot, colour: colour, radial: radial)
        }

        /// A camera-facing strip of `width` from `a` to `b`: local −1 … +1 across it, or along it (−1 at `a`, +1 at
        /// `b`) when `along`.
        mutating func facingStrip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, material: Material,
                                  along: Bool, colour: SIMD3<Double>? = nil) throws(MeshError) {
            let direction: SIMD3<Double> = b - a
            guard VoxelOrigamiSceneGeometry.dot(direction, direction) > 0 else { return }
            let towards: SIMD3<Double> = Self.towardsEye((a + b) / 2)
            let crossed: SIMD3<Double> = VoxelOrigamiSceneGeometry.cross(direction, towards)
            var side: SIMD3<Double> = VoxelOrigamiSceneGeometry.unit(crossed)
            if VoxelOrigamiSceneGeometry.dot(side, side) == 0 { side = VoxelOrigamiSceneGeometry.viewBasis().right }
            let w: SIMD3<Double> = side * (width / 2)
            try quad([a + w, b + w, b - w, a - w], normal: towards, material: material,
                     local: along ? [-1, 1, 1, -1] : [-1, -1, 1, 1], colour: colour)
        }

        /// The offset of corner `index` (bit 0 x, bit 1 y, bit 2 z; clear: −h) of a cube of half side `h`.
        static func cornerOffset(_ index: Int, _ h: Double) -> SIMD3<Double> {
            SIMD3(index & 1 == 0 ? -h : h, index & 2 == 0 ? -h : h, index & 4 == 0 ? -h : h)
        }

        /// The 12 edges of the axis-aligned wireframe cube of `side` around `centre`, as camera-facing strips of
        /// `width`.
        mutating func wireCube(centre: SIMD3<Double>, side: Double, width: Double, material: Material,
                               colour: SIMD3<Double>?) throws(MeshError) {
            let h: Double = side / 2
            for a in 0..<8 {
                for bit in [1, 2, 4] where a & bit == 0 {
                    let b: Int = a | bit
                    let pa: SIMD3<Double> = centre + Self.cornerOffset(a, h)
                    let pb: SIMD3<Double> = centre + Self.cornerOffset(b, h)
                    try facingStrip(pa, pb, width: width, material: material, along: false, colour: colour)
                }
            }
        }

        /// A cube at `centre` turned by `rotation`: its `pieces` (back-facing first, then by distance from the eye,
        /// farthest first), each flat face followed by its glyph (solid or hollow) and, on the cube's own +z face, the
        /// `dots`.
        mutating func cube(centre: SIMD3<Double>, rotation: VoxelOrigamiRotation, pieces: [CubePiece], s: Double,
                           solid: Bool, dots: [SIMD2<Double>], faceColour: SIMD3<Double>,
                           bevelColour: SIMD3<Double>) throws(MeshError) {
            typealias G = VoxelOrigamiSceneGeometry
            var placed: [(order: Double, facing: Bool, piece: CubePiece)] = []
            for piece in pieces {
                var corners: [SIMD3<Double>] = []
                for p in piece.corners { corners.append(centre + G.rotate(rotation, p)) }
                let normal: SIMD3<Double> = G.rotate(rotation, piece.normal)
                let middle: SIMD3<Double> = centre + G.rotate(rotation, piece.faceCentre)
                let toEye: SIMD3<Double> = G.eye - middle
                let moved: CubePiece = CubePiece(corners: corners, locals: piece.locals, normal: normal,
                                                 face: piece.face, faceCentre: middle,
                                                 axes: (G.rotate(rotation, piece.axes.u),
                                                        G.rotate(rotation, piece.axes.v)))
                placed.append((order: G.dot(toEye, toEye).squareRoot(), facing: G.dot(normal, toEye) > 0, piece: moved))
            }
            placed.sort { x, y in
                if x.facing != y.facing { return !x.facing }
                return x.order > y.order
            }
            for item in placed {
                let piece: CubePiece = item.piece
                guard let face = piece.face else {
                    try facet(piece.corners, normal: piece.normal, local: piece.locals, colour: bevelColour)
                    continue
                }
                let middle: SIMD3<Double> = piece.faceCentre
                try fan(centre: middle, outline: piece.corners, normal: piece.normal, material: .cubeFace,
                        colour: faceColour)
                let u: SIMD3<Double> = piece.axes.u
                let v: SIMD3<Double> = piece.axes.v
                let glyphCentre: SIMD3<Double> = middle + piece.normal * (G.glyphLift * s)
                func diamond(_ r: Double) -> [SIMD3<Double>] {
                    [glyphCentre + u * r, glyphCentre + v * r, glyphCentre - u * r, glyphCentre - v * r]
                }
                if solid {
                    try fan(centre: glyphCentre, outline: diamond(G.glyphRadius * s), normal: piece.normal,
                            material: .glyphSolid)
                } else {
                    try ring(inner: diamond(G.glyphInner * s), outer: diamond(G.glyphRadius * s), normal: piece.normal,
                             material: .glyphHollow)
                }
                guard face == 4 else { continue }
                let dotCentre: SIMD3<Double> = middle + piece.normal * (G.dotLift * s)
                for spot in dots {
                    let c: SIMD3<Double> = dotCentre + (u * spot.x + v * spot.y) * (G.dotSpacing * s)
                    var outline: [SIMD3<Double>] = []
                    for k in 0..<G.dotSegments {
                        let a: Double = 2 * Double.pi * Double(k) / Double(G.dotSegments)
                        outline.append(c + (u * cos(a) + v * sin(a)) * (G.dotRadius * s))
                    }
                    try fan(centre: c, outline: outline, normal: piece.normal, material: .dots)
                }
            }
        }

        /// The coloured mesh built so far.
        func built() -> VoxelOrigamiColouredMesh {
            VoxelOrigamiColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` turned by the integer rotation `r`.
    static func rotate(_ r: VoxelOrigamiRotation, _ v: SIMD3<Double>) -> SIMD3<Double> {
        let m: [Int] = r.m
        return SIMD3(Double(m[0]) * v.x + Double(m[1]) * v.y + Double(m[2]) * v.z,
                     Double(m[3]) * v.x + Double(m[4]) * v.y + Double(m[5]) * v.z,
                     Double(m[6]) * v.x + Double(m[7]) * v.y + Double(m[8]) * v.z)
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
