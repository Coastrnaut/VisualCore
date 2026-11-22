// FacetedForgeSceneGeometry — feature 373 (R02-G08-03) T-R02G0803-004 (FR-R02G0803-001, 002, 004, 006; SC-R02G0803-001;
// clarifications Q1–Q4). The crystal of Faceted Forge, built from a snapshot only. World space is the snapshot's: the
// crystal's corner centroid at the origin, the crystal inside the unit sphere, y up. Every piece is moved away from the
// origin along normalize(piece centroid) by the opening — 0.12 (0.2 when won), eased by smoothstep over the first 0.4 s
// of presentation time, or full at once under Reduce Motion; a piece whose centroid is within 1e-9 of the origin stays.
// Each face is drawn from its corners in the given (anticlockwise from outside) order: the face polygon shrunk toward
// its centre by the bevel inset 0.02 in the face plane is fan-triangulated, and the band between the original edge and
// the inset ring is filled with `tier.bevelSegments` strips whose normals blend from the bisector of the face and its
// neighbour across that edge to the face normal. Original faces are ice glass, cut faces amber, bevels highlight. The
// preview polygon is ruby with a dashed rim; a sliver failure's piece carries a cross of two thin bars over its opened
// centroid; the cut mark is a row of `budget` small bars along z = 1.3 from x = −0.9 to 0.9 (the first `cuts` spent),
// tilted to face the camera. The ground is the plane y = −1.3. The authored camera looks at the origin from the front
// (+z), pitched 30° down, fitted to the framing sphere of radius 1.65 with a 5 % margin for aspect 0.4 … 2.5. Depth
// testing is off on this render path, so the crystal mesh is emitted in painter's order: the ground, the pieces back to
// front (each piece's faces back to front), the preview, the sliver cross, the cut mark. Positions, colours and marks
// are the same at every tier; tiers change only the bevel strips and the glow shells. Doubles are used for drawing
// only; nothing here is consulted by the rules.
// Feature 374 (R02-G08-04) T-R02G0804-002 (FR-R02G0804-006; SC-R02G0804-004; clarification Q4): the orbit
// (`FacetedForgeOrbit`: yaw ±40° about +y, pitch 10° … 60° down from the horizon, authored yaw 0 and pitch 30°) and
// `camera(_:aspect:orbit:)`, which fits the framing sphere of radius 1.65 (was 1.45: the cut-mark row's bar ends lie
// about 1.64 from the centre) so the 5 % margin holds at every orbit; the authored camera is the authored orbit's
// camera, bit for bit.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The material codes of the crystal program, carried in `a_uv.x` of
/// ``FacetedForgeSceneGeometry/crystalMesh(_:tier:reduceMotion:orbit:)``.
public enum FacetedForgeMaterial {
    /// The dark ground plane, 0.
    public static let ground = 0.0
    /// The inner (unbevelled) part of an original face: ice glass, 1.
    public static let glass = 1.0
    /// The inner part of a cut face: incandescent amber with a lattice, 2.
    public static let cutFace = 2.0
    /// A bevel strip along a piece edge: the ice highlight, 3.
    public static let bevel = 3.0
    /// The ruby preview polygon and its dashed rim, 4.
    public static let preview = 4.0
    /// The cross over a sliver piece, 5.
    public static let sliverCross = 5.0
    /// A spent bar of the cut mark, 6.
    public static let spentBar = 6.0
    /// An unspent bar of the cut mark, 7.
    public static let unspentBar = 7.0

    /// The palette colour of material `code` (0 … 7; the ground for any other code).
    public static func colour(_ code: Double) -> SIMD3<Double> {
        switch Int(code.isFinite ? code.rounded() : 0) {
        case 1: FacetedForgePalette.ice
        case 2: FacetedForgePalette.amber
        case 3: FacetedForgePalette.highlight
        case 4: FacetedForgePalette.ruby
        case 5: FacetedForgePalette.sliver
        case 6: FacetedForgePalette.spent
        case 7: FacetedForgePalette.unspent
        default: FacetedForgePalette.ground
        }
    }
}

/// The camera of the Faceted Forge scene for one snapshot and aspect.
///
/// Built only by ``FacetedForgeSceneGeometry/camera(_:aspect:orbit:)`` (and
/// ``FacetedForgeSceneGeometry/camera(_:aspect:)``, its authored orbit). World positions are in crystal units (the
/// crystal fits the unit sphere); ``viewProjection`` maps them to GL clip space (right-handed, depth −1 … 1).
public struct FacetedForgeCamera: Sendable, Equatable {
    /// The eye position in world units.
    public let eye: SIMD3<Double>
    /// The point looked at: the crystal centre (the origin).
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

/// The orbit of the Faceted Forge camera: a yaw about the vertical axis and a pitch down from the horizon, both in
/// radians (feature 374). Presentation only: never in the digest, the snapshot or the kernel, and not saved.
///
/// ``FacetedForgeSceneGeometry/camera(_:aspect:orbit:)`` uses the ``clamped()`` orbit, so the eye always stays in front
/// of the crystal and above it (no vertical singularity) and the whole scene stays in view.
public struct FacetedForgeOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians: the angle of the eye direction above the horizon (the view looks down by it); allowed
    /// ``pitchRange`` (10° … 60°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 30° (``FacetedForgeSceneGeometry/pitch``), the fixed camera of R02-G08-03.
    public static let authored = FacetedForgeOrbit(yaw: 0, pitch: FacetedForgeSceneGeometry.pitch)
    /// The largest yaw either way, 40° in radians.
    public static let yawLimit: Double = 40.0 * Double.pi / 180
    /// The allowed pitches, 10° … 60° in radians.
    public static let pitchRange: ClosedRange<Double> = (10.0 * Double.pi / 180)...(60.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −40° … 40° and pitch to 10° … 60°; a non-finite angle becomes the authored one.
    public func clamped() -> FacetedForgeOrbit {
        let y: Double = yaw.isFinite ? yaw : Self.authored.yaw
        let p: Double = pitch.isFinite ? pitch : Self.authored.pitch
        return FacetedForgeOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                 pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// The unit direction from the crystal centre to the eye at the clamped orbit: (sin y · cos p, sin p, cos y · cos
    /// p) with y the yaw and p the pitch; exactly ``FacetedForgeSceneGeometry/eyeDirection`` at ``authored``.
    public var eyeDirection: SIMD3<Double> {
        let o: FacetedForgeOrbit = clamped()
        return SIMD3(sin(o.yaw) * cos(o.pitch), sin(o.pitch), cos(o.yaw) * cos(o.pitch))
    }
}

/// A mesh with one colour per vertex (sRGB RGBA 0 … 1, alpha 1), aligned with `mesh.positions`.
///
/// The colours feed the shared unlit mesh renderer of the fallback path (the shader programs have no colour stream;
/// they read the same information from the normal and uv streams, see ``FacetedForgeSceneGeometry``).
public struct FacetedForgeColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh`, in vertex order.
    public let colours: [Vec4]
}

/// The geometry of the Faceted Forge scene: the opening, opened piece and cut-face centres, the crystal mesh (ground,
/// bevelled pieces, preview, sliver cross, cut mark), the glow mesh (shells over the cut faces), camera and projection.
///
/// **Vertex streams** (the contract with the shaders; attributes a_position, a_normal, a_uv as bound by
/// `ShaderMeshRenderer`; positions are world units, identity model).
/// - ``crystalMesh(_:tier:reduceMotion:orbit:)`` — crystal program: `a_normal` the unit shading normal (the face
///   normal, or on a bevel strip the blend toward the neighbouring face); `a_uv` (material code, shade) with the
///   codes of ``FacetedForgeMaterial``; shade 1 everywhere except ``previewShade`` on the preview fill and 0 (the
///   shaders' rim coordinate) on the preview's dashed rim.
/// - ``glowMesh(_:tier:reduceMotion:orbit:)`` — glow program: `a_normal` the colour (sRGB 0 … 1, amber); `a_uv`
///   (glow weight 0 … 1, 0). Glow shell k = 1 … `tier.glowShells` has weight 0.5^k.
/// ``FacetedForgeColouredMesh/colours`` gives each vertex's unlit colour for the fallback: on the crystal the material
/// colour times the shade times 0.6 + 0.4 · max(normal · ``lightDirection``, 0), on the glow the stream colour times
/// the weight.
///
/// Every triangle is wound counter-clockwise seen from its front. Depth testing is off, so the crystal mesh is in
/// painter's order (see ``pieceOrder(_:reduceMotion:orbit:)``).
public enum FacetedForgeSceneGeometry {
    // MARK: Constants (world units unless stated)

    /// The full opening: how far every piece moves away from the centre, 0.12.
    public static let openingDistance = 0.12
    /// The full opening once the pieces match the target, 0.2.
    public static let wonOpeningDistance = 0.2
    /// The presentation time over which the opening eases in, 0.4 s.
    public static let openingDuration = 0.4
    /// A piece whose centroid is within this distance of the origin does not move, 1e-9.
    public static let centreTolerance = 1e-9
    /// The bevel inset of every face edge, 0.02.
    public static let bevelInset = 0.02
    /// The y of the ground plane, −1.3.
    public static let groundY = -1.3
    /// The half-side of the square ground plane, 3.
    public static let groundHalf = 3.0
    /// The shade of the preview fill, 0.7 (its rim carries the shaders' rim coordinate 0 instead).
    public static let previewShade = 0.7
    /// How far the preview polygon is pushed towards the eye, 0.002.
    public static let previewLift = 0.002
    /// The length of one dash of the preview rim, 0.06.
    public static let dashLength = 0.06
    /// The gap between dashes of the preview rim, 0.04.
    public static let dashGap = 0.04
    /// The half-width of the preview rim, 0.008.
    public static let rimHalfWidth = 0.008
    /// The half-length of a sliver-cross arm, 0.14.
    public static let crossArm = 0.14
    /// The half-width of a sliver-cross arm, 0.018.
    public static let crossHalfWidth = 0.018
    /// The z of the cut mark row, 1.3.
    public static let markZ = 1.3
    /// The y of the cut mark row's centre line, −0.45 (in front of and below the crystal, inside the view).
    public static let markY = -0.45
    /// The x where the cut mark row starts, −0.9.
    public static let markStart = -0.9
    /// The x where the cut mark row ends, 0.9.
    public static let markEnd = 0.9
    /// The fraction of each bar's slot a bar fills, 0.6.
    public static let markFill = 0.6
    /// The largest bar width, 0.12.
    public static let markMaxWidth = 0.12
    /// The half-height of a bar, 0.035.
    public static let markHalfHeight = 0.035
    /// How much wider glow shell k is than its cut face: scale 1 + 0.08·k about the face centre.
    public static let glowGrowth = 0.08
    /// How far glow shell k is pushed out along the face normal: 0.004·k.
    public static let glowLift = 0.004
    /// The glow weight of shell k is glowWeight^k (0.5).
    public static let glowWeight = 0.5
    /// The radius of the framing sphere every camera fits, 1.65: the opened crystal (reach 1.2) and the cut-mark row,
    /// whose bar ends lie about 1.64 from the centre (feature 374; 1.45 before).
    public static let boundingRadius = 1.65
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's pitch below the horizon in radians (30°).
    public static let pitch = 30.0 * Double.pi / 180
    /// The unit direction from the crystal centre to the eye: (0, sin 30°, cos 30°) — in front (+z), above.
    public static let eyeDirection = SIMD3<Double>(0, sin(pitch), cos(pitch))
    /// The camera's unit up vector on screen: (0, cos 30°, −sin 30°).
    public static let screenUp = SIMD3<Double>(0, cos(pitch), -sin(pitch))
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The unit light direction of the fallback colours: normalize(0.35, 0.8, 0.5).
    public static let lightDirection = unit(SIMD3<Double>(0.35, 0.8, 0.5))

    // MARK: Opening and places

    /// The opening: 0.12 (0.2 when won) times smoothstep(0, 0.4 s, time); the full value at once under Reduce Motion
    /// (clarification Q4).
    public static func opening(_ snapshot: FacetedForgeSceneSnapshot, reduceMotion: Bool = false) -> Double {
        let full: Double = snapshot.won ? wonOpeningDistance : openingDistance
        if reduceMotion { return full }
        let t: Double = min(max(snapshot.time / openingDuration, 0), 1)
        return full * t * t * (3 - 2 * t)
    }

    /// The offset of piece `piece`: normalize(centroid) × ``opening(_:reduceMotion:)``; zero for a centroid within
    /// 1e-9 of the origin or an unknown piece.
    public static func offset(piece: Int, _ snapshot: FacetedForgeSceneSnapshot,
                              reduceMotion: Bool = false) -> SIMD3<Double> {
        guard snapshot.pieces.indices.contains(piece) else { return .zero }
        let c: SIMD3<Double> = snapshot.pieces[piece].centroid
        guard length(c) > centreTolerance else { return .zero }
        return unit(c) * opening(snapshot, reduceMotion: reduceMotion)
    }

    /// The opened centroid of piece `piece` (the origin for an unknown piece).
    public static func pieceCentre(_ piece: Int, _ snapshot: FacetedForgeSceneSnapshot,
                                   reduceMotion: Bool = false) -> SIMD3<Double> {
        guard snapshot.pieces.indices.contains(piece) else { return .zero }
        return snapshot.pieces[piece].centroid + offset(piece: piece, snapshot, reduceMotion: reduceMotion)
    }

    /// The opened mean of each cut face's corners, in piece then face order.
    public static func cutFaceCentres(_ snapshot: FacetedForgeSceneSnapshot,
                                      reduceMotion: Bool = false) -> [SIMD3<Double>] {
        var result: [SIMD3<Double>] = []
        for (index, piece) in snapshot.pieces.enumerated() {
            let shift: SIMD3<Double> = offset(piece: index, snapshot, reduceMotion: reduceMotion)
            for (f, face) in piece.faces.enumerated() where f < piece.cutFaces.count && piece.cutFaces[f] {
                guard let c = faceCentre(face, piece.corners) else { continue }
                result.append(c + shift)
            }
        }
        return result
    }

    /// The opened centre of the preview polygon (the mean of its corners plus the chosen piece's offset); nil when the
    /// preview is empty.
    public static func previewCentre(_ snapshot: FacetedForgeSceneSnapshot,
                                     reduceMotion: Bool = false) -> SIMD3<Double>? {
        guard !snapshot.preview.isEmpty else { return nil }
        let mean: SIMD3<Double> = snapshot.preview.reduce(SIMD3<Double>(0, 0, 0), +) / Double(snapshot.preview.count)
        return mean + offset(piece: snapshot.choice.piece, snapshot, reduceMotion: reduceMotion)
    }

    /// The pieces in painter's order for the eye of `orbit` (default the authored one): farthest from the eye first
    /// (ascending opened centroid · `orbit.eyeDirection`), ties by index.
    public static func pieceOrder(_ snapshot: FacetedForgeSceneSnapshot, reduceMotion: Bool = false,
                                  orbit: FacetedForgeOrbit = .authored) -> [Int] {
        let eye: SIMD3<Double> = frame(orbit).eye
        var keyed: [(index: Int, depth: Double)] = []
        for index in snapshot.pieces.indices {
            keyed.append((index, dot(pieceCentre(index, snapshot, reduceMotion: reduceMotion), eye)))
        }
        keyed.sort { a, b in abs(a.depth - b.depth) > 1e-12 ? a.depth < b.depth : a.index < b.index }
        return keyed.map(\.index)
    }

    /// The eye direction, screen up and screen right unit vectors of the clamped `orbit`: exactly ``eyeDirection``,
    /// ``screenUp`` and +x at the authored orbit; otherwise orbit.eyeDirection, (−sin p · sin y, cos p, −sin p · cos y)
    /// and (cos y, 0, −sin y) for yaw y and pitch p (feature 374).
    static func frame(_ orbit: FacetedForgeOrbit) -> (eye: SIMD3<Double>, up: SIMD3<Double>, right: SIMD3<Double>) {
        let o: FacetedForgeOrbit = orbit.clamped()
        if o == .authored { return (eyeDirection, screenUp, SIMD3(1, 0, 0)) }
        return (o.eyeDirection, SIMD3(-sin(o.pitch) * sin(o.yaw), cos(o.pitch), -sin(o.pitch) * cos(o.yaw)),
                SIMD3(cos(o.yaw), 0, -sin(o.yaw)))
    }

    /// The centre x of cut mark bar `bar` of `budget`: −0.9 + (bar + 0.5) · 1.8 / budget.
    public static func markBarCentre(_ bar: Int, budget: Int) -> SIMD3<Double> {
        let slot: Double = (markEnd - markStart) / Double(max(budget, 1))
        return SIMD3(markStart + (Double(bar) + 0.5) * slot, markY, markZ)
    }

    /// The material code of every cut mark bar, in order: ``FacetedForgeMaterial/spentBar`` for the first `cuts`
    /// (clamped to 0 … budget), ``FacetedForgeMaterial/unspentBar`` for the rest; empty for a non-positive budget.
    public static func markCodes(_ snapshot: FacetedForgeSceneSnapshot) -> [Double] {
        let budget: Int = max(snapshot.budget, 0)
        let spent: Int = min(max(snapshot.cuts, 0), budget)
        var codes: [Double] = []
        for bar in 0..<budget {
            codes.append(bar < spent ? FacetedForgeMaterial.spentBar : FacetedForgeMaterial.unspentBar)
        }
        return codes
    }

    // MARK: Meshes

    /// The crystal (crystal program, real normals, uv (material code, shade)), in painter's order: the ground square
    /// (half-side 3, y = −1.3); every piece of ``pieceOrder(_:reduceMotion:orbit:)`` with its faces back to front (each
    /// the inset polygon, code 1 or 2 for a cut face, and its `tier.bevelSegments` bevel strips per edge, code 3); the
    /// preview polygon (code 4, shade 0.7) with its dashed rim (code 4); the sliver cross over the failure piece (code
    /// 5); the cut mark bars (codes 6 and 7). Colours: material colour × shade × (0.6 + 0.4 · max(n · light, 0)). The
    /// painter's order, the preview's facing side and the camera-facing sliver cross and mark bars follow the eye of
    /// `orbit` (``frame(_:)``); the default, the authored orbit, gives the output of R02-G08-03 bit for bit.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func crystalPart(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier,
                                   reduceMotion: Bool = false,
                                   orbit: FacetedForgeOrbit = .authored) throws(MeshError) -> FacetedForgeColouredMesh {
        let view: (eye: SIMD3<Double>, up: SIMD3<Double>, right: SIMD3<Double>) = frame(orbit)
        var parts: Parts = Parts(lit: true)
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        let g: Double = groundHalf
        let y: Double = groundY
        try parts.polygon([SIMD3(-g, y, -g), SIMD3(-g, y, g), SIMD3(g, y, g), SIMD3(g, y, -g)], normal: up,
                          uv: Vec2(FacetedForgeMaterial.ground, 1))
        let segments: Int = max(tier.bevelSegments, 1)
        for index in pieceOrder(snapshot, reduceMotion: reduceMotion, orbit: orbit) {
            let shift: SIMD3<Double> = offset(piece: index, snapshot, reduceMotion: reduceMotion)
            try addPiece(snapshot.pieces[index], shift: shift, segments: segments, eye: view.eye, to: &parts)
        }
        try addPreview(snapshot, reduceMotion: reduceMotion, eye: view.eye, to: &parts)
        if let sliver = snapshot.failurePiece, snapshot.pieces.indices.contains(sliver) {
            let centre: SIMD3<Double> = pieceCentre(sliver, snapshot, reduceMotion: reduceMotion)
            let a: SIMD3<Double> = unit(view.right + view.up)
            let b: SIMD3<Double> = unit(view.right - view.up)
            let uv: Vec2 = Vec2(FacetedForgeMaterial.sliverCross, 1)
            try parts.bar(centre: centre, along: a, across: b, halfLength: crossArm, halfWidth: crossHalfWidth,
                          normal: view.eye, uv: uv)
            try parts.bar(centre: centre, along: b, across: a, halfLength: crossArm, halfWidth: crossHalfWidth,
                          normal: view.eye, uv: uv)
        }
        let codes: [Double] = markCodes(snapshot)
        let slot: Double = (markEnd - markStart) / Double(max(codes.count, 1))
        let halfWidth: Double = min(markFill * slot, markMaxWidth) / 2
        for (bar, code) in codes.enumerated() {
            try parts.bar(centre: markBarCentre(bar, budget: codes.count), along: view.right, across: view.up,
                          halfLength: halfWidth, halfWidth: markHalfHeight, normal: view.eye, uv: Vec2(code, 1))
        }
        return parts.built()
    }

    /// The crystal mesh (see ``crystalPart(_:tier:reduceMotion:orbit:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func crystalMesh(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier,
                                   reduceMotion: Bool = false,
                                   orbit: FacetedForgeOrbit = .authored) throws(MeshError) -> Mesh {
        try crystalPart(snapshot, tier: tier, reduceMotion: reduceMotion, orbit: orbit).mesh
    }

    /// The glow (glow program, colour in the normal slot, uv (weight, 0)): for k = `tier.glowShells` … 1, a copy of
    /// every opened cut face scaled by 1 + 0.08·k about its centre and pushed 0.004·k out along its normal, amber,
    /// weight 0.5^k. Empty when the tier has no glow shells (level-2) or there are no cut faces. The shells are
    /// additive, so their order does not depend on `orbit` (accepted for symmetry with the crystal; any orbit gives
    /// the same mesh).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowPart(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier,
                                reduceMotion: Bool = false,
                                orbit: FacetedForgeOrbit = .authored) throws(MeshError) -> FacetedForgeColouredMesh {
        var parts: Parts = Parts(lit: false)
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        for k in stride(from: shells, through: 1, by: -1) {
            let weight: Double = pow(glowWeight, Double(k))
            for (index, piece) in snapshot.pieces.enumerated() {
                let shift: SIMD3<Double> = offset(piece: index, snapshot, reduceMotion: reduceMotion)
                for (f, face) in piece.faces.enumerated() where f < piece.cutFaces.count && piece.cutFaces[f] {
                    let corners: [SIMD3<Double>] = points(face, piece.corners)
                    guard corners.count >= 3, let c = faceCentre(face, piece.corners) else { continue }
                    let n: SIMD3<Double> = newell(corners)
                    guard length(n) > 0 else { continue }
                    var grown: [SIMD3<Double>] = []
                    for p in corners {
                        grown.append(c + (p - c) * (1 + glowGrowth * Double(k)) + n * (glowLift * Double(k)) + shift)
                    }
                    try parts.polygon(grown, normal: n, uv: Vec2(weight, 0), slot: FacetedForgePalette.amber)
                }
            }
        }
        return parts.built()
    }

    /// The glow mesh (see ``glowPart(_:tier:reduceMotion:orbit:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowMesh(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier,
                                reduceMotion: Bool = false,
                                orbit: FacetedForgeOrbit = .authored) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier, reduceMotion: reduceMotion, orbit: orbit).mesh
    }

    // MARK: Camera

    /// `aspect` made usable: a non-finite or non-positive aspect becomes 1; others are clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// The eye distance that fits a sphere of `radius` for `aspect` with ``fitMargin``: the sphere must lie in the cone
    /// of half-angle α around the view axis, tan α = (1 − 2 · margin) · min(tan(fovY/2), aspect · tan(fovY/2)), so the
    /// distance is radius / sin α.
    static func distance(radius: Double, aspect: Double) -> Double {
        let half: Double = tan(fieldOfView / 2)
        let limit: Double = (1 - 2 * fitMargin) * min(half, usableAspect(aspect) * half)
        return max(radius, 1e-3) / sin(atan(limit))
    }

    /// The fixed authored camera for `snapshot` and `aspect` (width / height): ``camera(_:aspect:orbit:)`` at
    /// ``FacetedForgeOrbit/authored``, bit for bit, so the eye lies on ``eyeDirection`` (in front, +z, pitched 30°
    /// down) at the distance that fits the framing sphere of radius 1.65 about the origin, looking at the origin with
    /// +y up and a 45° vertical field of view. For aspects 0.4 … 2.5 the sphere projects inside the view with at least
    /// 5 % margin on every side. A zero, negative or non-finite aspect is treated as 1; others are clamped to 0.1 … 10.
    /// Independent of the tier, the time and the play.
    public static func camera(_ snapshot: FacetedForgeSceneSnapshot, aspect: Double) -> FacetedForgeCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The camera for `snapshot`, `aspect` (width / height) and `orbit` (clamped, see ``FacetedForgeOrbit/clamped()``):
    /// the eye on ``FacetedForgeOrbit/eyeDirection`` from the origin at the distance that fits the framing sphere of
    /// radius 1.65 (the fit does not depend on the direction, so the 5 % margin holds at every orbit and aspect
    /// 0.4 … 2.5), looking at the origin with +y up (never parallel to the view direction: the pitch is at most 60°)
    /// and a 45° vertical field of view. Aspects are made usable as in ``camera(_:aspect:)``. Presentation only;
    /// independent of the tier, the time and the play.
    public static func camera(_ snapshot: FacetedForgeSceneSnapshot, aspect: Double,
                              orbit: FacetedForgeOrbit) -> FacetedForgeCamera {
        let a: Double = usableAspect(aspect)
        let radius: Double = boundingRadius
        let d: Double = distance(radius: radius, aspect: a)
        let eye: SIMD3<Double> = orbit.eyeDirection * d
        let near: Double = max((d - radius) * 0.5, 1e-3)
        let far: Double = d + 2 * radius - groundY + 1
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: Vec3(0, 0, 0), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return FacetedForgeCamera(eye: eye, target: .zero, fovY: fieldOfView, aspect: a, near: near, far: far,
                                  radius: radius, view: view, projection: projection,
                                  viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (origin top left, y down; multiply by the viewport size for pixels, the
    /// convention of `ScreenProjection`); nil behind the camera or for non-finite input. Points outside the view give
    /// coordinates outside 0 … 1.
    public static func project(_ point: SIMD3<Double>, camera: FacetedForgeCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    /// `point` in pixels of a `width` × `height` viewport (origin top left, y down); nil for a non-positive size,
    /// behind the camera or for non-finite input.
    public static func pixel(_ point: SIMD3<Double>, camera: FacetedForgeCamera, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0, let v = project(point, camera: camera) else { return nil }
        return Vec2(v.x * Double(width), v.y * Double(height))
    }

    // MARK: Building

    /// The faces of `piece` back to front for the unit eye direction `eye`: ascending face centre · eye, ties by
    /// index.
    static func faceOrder(_ piece: FacetedForgeSceneSnapshot.Piece, eye: SIMD3<Double>) -> [Int] {
        var keyed: [(face: Int, depth: Double)] = []
        for (f, face) in piece.faces.enumerated() {
            let c: SIMD3<Double> = faceCentre(face, piece.corners) ?? .zero
            keyed.append((f, dot(c, eye)))
        }
        keyed.sort { a, b in abs(a.depth - b.depth) > 1e-12 ? a.depth < b.depth : a.face < b.face }
        return keyed.map(\.face)
    }

    /// Adds one piece moved by `shift`: its faces back to front for `eye` (``faceOrder(_:eye:)``), each the inset
    /// polygon and the bevel strips of its edges.
    static func addPiece(_ piece: FacetedForgeSceneSnapshot.Piece, shift: SIMD3<Double>, segments: Int,
                         eye: SIMD3<Double>, to parts: inout Parts) throws(MeshError) {
        var normals: [SIMD3<Double>] = []
        var edges: [EdgeKey: [Int]] = [:]
        for (f, face) in piece.faces.enumerated() {
            normals.append(newell(points(face, piece.corners)))
            for i in face.indices {
                edges[EdgeKey(face[i], face[(i + 1) % face.count]), default: []].append(f)
            }
        }
        for f in faceOrder(piece, eye: eye) {
            let face: [Int] = piece.faces[f]
            let p: [SIMD3<Double>] = points(face, piece.corners).map { $0 + shift }
            let n: SIMD3<Double> = normals[f]
            guard p.count >= 3, length(n) > 0 else { continue }
            let cut: Bool = f < piece.cutFaces.count && piece.cutFaces[f]
            let code: Double = cut ? FacetedForgeMaterial.cutFace : FacetedForgeMaterial.glass
            let q: [SIMD3<Double>] = inset(p, normal: n)
            try parts.polygon(q, normal: n, uv: Vec2(code, 1))
            let bevelUV: Vec2 = Vec2(FacetedForgeMaterial.bevel, 1)
            for i in p.indices {
                let j: Int = (i + 1) % p.count
                var neighbour: SIMD3<Double> = n
                for other in edges[EdgeKey(face[i], face[j])] ?? [] where other != f && length(normals[other]) > 0 {
                    neighbour = normals[other]
                }
                let edgeNormal: SIMD3<Double> = unit(n + neighbour) == .zero ? n : unit(n + neighbour)
                for s in 0..<segments {
                    let f0: Double = Double(s) / Double(segments)
                    let f1: Double = Double(s + 1) / Double(segments)
                    let blend: Double = (Double(s) + 0.5) / Double(segments)
                    var slot: SIMD3<Double> = unit(edgeNormal * (1 - blend) + n * blend)
                    if slot == .zero { slot = n }
                    let quad: [SIMD3<Double>] = [p[i] + (q[i] - p[i]) * f0, p[j] + (q[j] - p[j]) * f0,
                                                 p[j] + (q[j] - p[j]) * f1, p[i] + (q[i] - p[i]) * f1]
                    try parts.polygon(quad, normal: n, uv: bevelUV, slot: slot)
                }
            }
        }
    }

    /// Adds the preview polygon (ruby fill, shade 0.7) and its dashed rim (ruby, rim coordinate 0), opened with the
    /// chosen piece's offset and lifted 0.002 towards the eye `eye`, facing the eye side; nothing for an empty
    /// preview.
    static func addPreview(_ snapshot: FacetedForgeSceneSnapshot, reduceMotion: Bool, eye: SIMD3<Double>,
                           to parts: inout Parts) throws(MeshError) {
        guard snapshot.preview.count >= 3 else { return }
        var n: SIMD3<Double> = newell(snapshot.preview)
        guard length(n) > 0 else { return }
        if dot(n, eye) < 0 { n = -n }
        let shift: SIMD3<Double> = offset(piece: snapshot.choice.piece, snapshot, reduceMotion: reduceMotion)
            + n * previewLift
        let p: [SIMD3<Double>] = snapshot.preview.map { $0 + shift }
        try parts.polygon(p, normal: n, uv: Vec2(FacetedForgeMaterial.preview, previewShade))
        // The rim's `a_uv.y` is the shaders' rim coordinate 0 (``FacetedForgeShaders/previewRimWidth``), so the crystal
        // program dashes it as well; the fallback draws it at full shade.
        let uv: Vec2 = Vec2(FacetedForgeMaterial.preview, 0)
        for i in p.indices {
            let a: SIMD3<Double> = p[i]
            let b: SIMD3<Double> = p[(i + 1) % p.count]
            let edge: Double = length(b - a)
            guard edge > 1e-9 else { continue }
            let along: SIMD3<Double> = (b - a) / edge
            let across: SIMD3<Double> = unit(cross(n, along))
            var start: Double = 0
            while start < edge {
                let end: Double = min(start + dashLength, edge)
                let s0: SIMD3<Double> = a + along * start
                let s1: SIMD3<Double> = a + along * end
                try parts.polygon([s0 - across * rimHalfWidth, s1 - across * rimHalfWidth, s1 + across * rimHalfWidth,
                                   s0 + across * rimHalfWidth], normal: n, uv: uv)
                start = end + dashGap
            }
        }
    }

    /// The polygon `p` (normal `normal`) with every edge moved inward by ``bevelInset`` in its plane; each corner moves
    /// at most 45 % of its distance to the polygon's centre, so a small face stays a valid, finite polygon.
    static func inset(_ p: [SIMD3<Double>], normal: SIMD3<Double>) -> [SIMD3<Double>] {
        let n: SIMD3<Double> = unit(normal)
        let centre: SIMD3<Double> = p.reduce(SIMD3<Double>(0, 0, 0), +) / Double(p.count)
        var result: [SIMD3<Double>] = []
        for i in p.indices {
            let previous: SIMD3<Double> = p[(i + p.count - 1) % p.count]
            let next: SIMD3<Double> = p[(i + 1) % p.count]
            let m1: SIMD3<Double> = unit(cross(n, p[i] - previous))
            let m2: SIMD3<Double> = unit(cross(n, next - p[i]))
            var move: SIMD3<Double> = (m1 + m2) * (bevelInset / max(1 + dot(m1, m2), 1e-3))
            let limit: Double = 0.45 * length(centre - p[i])
            let l: Double = length(move)
            if !(l <= limit) { move = l > 0 && l.isFinite ? move * (limit / l) : .zero }
            result.append(p[i] + move)
        }
        return result
    }

    /// An undirected edge between two corner indices.
    struct EdgeKey: Hashable {
        let a: Int
        let b: Int

        init(_ x: Int, _ y: Int) {
            a = min(x, y)
            b = max(x, y)
        }
    }

    /// A mesh builder with its colour stream: a colour is recorded for every new vertex (a welded vertex keeps its
    /// first colour; the colour is a function of the normal slot and uv, so welded vertices agree).
    struct Parts {
        var builder: MeshBuilder = MeshBuilder()
        var colours: [Vec4] = []
        /// True for the crystal (real normals, colour from the material code); false for the glow (colour slot).
        let lit: Bool

        init(lit: Bool) { self.lit = lit }

        /// The unlit fallback colour of a vertex with `slot` in the normal stream and `uv`.
        func colour(slot: SIMD3<Double>, uv: Vec2) -> SIMD3<Double> {
            if lit {
                let light: Double = 0.6 + 0.4 * max(FacetedForgeSceneGeometry.dot(slot, lightDirection), 0)
                // The preview rim carries its rim coordinate (0) in the shade slot; it is drawn at full shade.
                let shade: Double = uv.x == FacetedForgeMaterial.preview && uv.y < previewShade ? 1 : uv.y
                return FacetedForgeMaterial.colour(uv.x) * shade * light
            }
            return slot * min(max(uv.x, 0), 1)
        }

        /// Adds one vertex and returns its index.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, uv: Vec2) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(FacetedForgeSceneGeometry.vec(p),
                                                normal: FacetedForgeSceneGeometry.vec(slot), uv: uv)
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
            let s: SIMD3<Double> = slot ?? FacetedForgeSceneGeometry.unit(normal)
            var ids: [UInt32] = []
            for point in p { ids.append(try vertex(point, slot: s, uv: uv)) }
            for k in 1..<(p.count - 1) {
                try facing(ids[0], ids[k], ids[k + 1], p[0], p[k], p[k + 1], front: normal)
            }
        }

        /// Adds a flat bar (rectangle) about `centre`, `halfLength` along `along` and `halfWidth` along `across`,
        /// facing `normal`.
        mutating func bar(centre: SIMD3<Double>, along: SIMD3<Double>, across: SIMD3<Double>, halfLength: Double,
                          halfWidth: Double, normal: SIMD3<Double>, uv: Vec2) throws(MeshError) {
            let u: SIMD3<Double> = along * halfLength
            let v: SIMD3<Double> = across * halfWidth
            try polygon([centre - u - v, centre + u - v, centre + u + v, centre - u + v], normal: normal, uv: uv)
        }

        /// Adds triangle a, b, c wound so its geometric normal points along `front`.
        mutating func facing(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            if FacetedForgeSceneGeometry.dot(FacetedForgeSceneGeometry.cross(pb - pa, pc - pa), front) < 0 {
                try builder.triangle(a, c, b)
            } else {
                try builder.triangle(a, b, c)
            }
        }

        /// The coloured mesh built so far.
        func built() -> FacetedForgeColouredMesh {
            FacetedForgeColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// The corners of `face` (indices into `corners`; unknown indices skipped).
    static func points(_ face: [Int], _ corners: [SIMD3<Double>]) -> [SIMD3<Double>] {
        var result: [SIMD3<Double>] = []
        for i in face where corners.indices.contains(i) { result.append(corners[i]) }
        return result
    }

    /// The mean of `face`'s corners; nil for a face without known corners.
    static func faceCentre(_ face: [Int], _ corners: [SIMD3<Double>]) -> SIMD3<Double>? {
        let p: [SIMD3<Double>] = points(face, corners)
        guard !p.isEmpty else { return nil }
        return p.reduce(SIMD3<Double>(0, 0, 0), +) / Double(p.count)
    }

    /// The unit normal of polygon `p` by Newell's method (anticlockwise seen from the normal's side); zero when
    /// degenerate.
    static func newell(_ p: [SIMD3<Double>]) -> SIMD3<Double> {
        var n: SIMD3<Double> = .zero
        for i in p.indices {
            let a: SIMD3<Double> = p[i]
            let b: SIMD3<Double> = p[(i + 1) % p.count]
            n += SIMD3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
        }
        return unit(n)
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
