// AmethystEscapeSceneGeometry — feature 363 (R02-G07-03) T-R02G0703-004 (FR-R02G0703-001, 002, 006; SC-R02G0703-001;
// clarifications Q1–Q3). The crystal of Amethyst Escape, built from a snapshot only: it lies in the xz-plane, y up,
// centred at the origin. With n shells and S sectors, shell k (0 innermost) is the annulus from r_k = 0.2 + k·w to
// r_k + w, w = 0.8 / n; own sector s of shell k sits at world sector (s + o_k) mod S and covers the angles
// 2π·ws/S … 2π·(ws + 1)/S measured from +x towards +z (clockwise seen from above, the kernel's "+1"). Each wedge is a
// prism of height h_k = 0.08 + 0.06·(n − 1 − k), inset 0.04·w on every side, its top edges rounded by the tier's bevel
// segments; a closed outer wall is a platinum rim band on the wedge top and an aperture is a gap in it; wall i is a
// platinum fin (thickness 0.03·w, height h_k + 0.02) on the boundary between own sectors i and i + 1; a blocked wedge is
// dark with a raised cross on top, and the failed pocket's wedge is amber. The pearl is a sphere of radius 0.3·w at its
// pocket's centre (radius r_k + w/2, the absolute sector's middle angle), centre y = h_k + 0.3·w, or on the exit arrow's
// centre once escaped. The exit arrow lies over the exit gap's world sector at radius r_(n−1) + w + 0.06 pointing
// outward; the move bar runs along z = 1.02 from x = −0.8 for 1.6 · moves / budget; the backdrop is the plane y = 0.
// The fixed authored camera looks at the origin from the front (+z), pitched 50° down, fitted to the bounding sphere of
// radius 1.1 with a 5 % margin for aspect 0.4 … 2.5. Depth testing is off on this render path, so the crystal mesh is
// emitted in painter's order: backdrop, wedges back to front (each with its rim band, fins and marks, sides before the
// top), the exit arrow, the move bar. Positions, colours and marks are the same at every tier; tiers change only the
// bevel segments and the glow shells. Doubles are used for drawing only; nothing here is consulted by the rules.
//
// Feature 364 (R02-G07-04) T-R02G0704-003 (clarifications Q1–Q4): the orbit (`AmethystEscapeOrbit`: yaw ±40° about +y,
// pitch 30° … 75° down from the horizon, authored yaw 0 and pitch 50°) and `camera(_:aspect:orbit:)`, which refits the
// same bounding sphere of radius 1.1 so the 5 % margin holds at every orbit; the authored camera is the authored orbit's
// camera, bit for bit. The isolation parameter of `crystalPart(_:tier:isolated:)`: with a shell index, every other
// shell's wedges, rim bands, wall fins and blocked crosses are drawn at shade 0.25 (positions unchanged); nil (the
// default) leaves the mesh exactly as before.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of the Amethyst Escape scene for one snapshot and aspect.
///
/// Built only by ``AmethystEscapeSceneGeometry/camera(_:aspect:orbit:)`` (and
/// ``AmethystEscapeSceneGeometry/camera(_:aspect:)``, its authored orbit). World positions are in crystal units (the
/// outer shell's outer radius is 1); ``viewProjection`` maps them to GL clip space (right-handed, depth −1 … 1).
public struct AmethystEscapeCamera: Sendable, Equatable {
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

/// The orbit of the Amethyst Escape camera: a yaw about the vertical axis and a pitch down from the horizon, both in
/// radians (feature 364). Presentation only: never in the digest, the snapshot or the kernel, and not saved.
///
/// ``AmethystEscapeSceneGeometry/camera(_:aspect:orbit:)`` uses the ``clamped()`` orbit, so the eye always stays in
/// front of the crystal and above it (no vertical singularity) and the whole crystal stays in view.
public struct AmethystEscapeOrbit: Sendable, Equatable {
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

    /// The authored orbit: yaw 0, pitch 50° (``AmethystEscapeSceneGeometry/pitch``), the fixed camera of R02-G07-03.
    public static let authored = AmethystEscapeOrbit(yaw: 0, pitch: AmethystEscapeSceneGeometry.pitch)
    /// The largest yaw either way, 40° in radians.
    public static let yawLimit: Double = 40.0 * Double.pi / 180
    /// The allowed pitches, 30° … 75° in radians.
    public static let pitchRange: ClosedRange<Double> = (30.0 * Double.pi / 180)...(75.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −40° … 40° and pitch to 30° … 75°; a non-finite angle becomes the authored one.
    public func clamped() -> AmethystEscapeOrbit {
        let y: Double = yaw.isFinite ? yaw : Self.authored.yaw
        let p: Double = pitch.isFinite ? pitch : Self.authored.pitch
        return AmethystEscapeOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                   pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// The unit direction from the crystal centre to the eye at the clamped orbit: (sin y · cos p, sin p, cos y · cos p)
    /// with y the yaw and p the pitch; exactly ``AmethystEscapeSceneGeometry/eyeDirection`` at ``authored``.
    public var eyeDirection: SIMD3<Double> {
        let o: AmethystEscapeOrbit = clamped()
        return SIMD3(sin(o.yaw) * cos(o.pitch), sin(o.pitch), cos(o.yaw) * cos(o.pitch))
    }
}

/// A mesh with one colour per vertex (sRGB RGBA 0 … 1, alpha 1), aligned with `mesh.positions`.
///
/// The colours feed the shared unlit mesh renderer of the fallback path (the shader programs have no colour stream; they
/// read the same information from the normal and uv streams, see ``AmethystEscapeSceneGeometry``).
public struct AmethystEscapeColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh`, in vertex order.
    public let colours: [Vec4]
}

/// One wedge of the crystal as the painter's order sees it: its shell, own sector and world sector.
public struct AmethystEscapeWedge: Sendable, Equatable, Hashable {
    /// The shell, 0 (innermost) … shells − 1.
    public let shell: Int
    /// The own sector in its shell, 0 … sectors − 1.
    public let sector: Int
    /// The world sector, (sector + offset) mod sectors.
    public let world: Int
}

/// The geometry of the Amethyst Escape scene: wedge places, the crystal mesh (backdrop, bevelled wedges, rim bands, wall
/// fins, blocked crosses, exit arrow, move bar), the glow mesh (pearl and glow shells), camera and projection.
///
/// **Vertex streams** (the contract with the shaders; attributes a_position, a_normal, a_uv as bound by
/// `ShaderMeshRenderer`; positions are world units, identity model).
/// - ``crystalMesh(_:tier:)`` — crystal program: `a_normal` the real unit face normal; `a_uv` (material code, shade)
///   with codes ``backdropCode`` 0, ``amethystCode`` 1 (open wedge facets), ``platinumCode`` 2 (rim bands, wall fins,
///   blocked crosses, exit arrow, move bar), ``blockedCode`` 3 (blocked wedges) and ``amberCode`` 4 (the failed
///   pocket's wedge); shade 1 everywhere except ``crossShade`` on the blocked crosses.
/// - ``glowMesh(_:tier:)`` — glow program: `a_normal` the colour (sRGB 0 … 1); `a_uv` (glow weight 0 … 1, 0). The pearl
///   core has weight 1; glow shell k = 1 … `tier.glowShells` around the pearl and the exit has weight 0.5^k.
/// ``AmethystEscapeColouredMesh/colours`` gives each vertex's unlit colour for the fallback: on the crystal the material
/// colour times the shade times 0.6 + 0.4 · max(normal.y, 0) (tops at full colour), on the glow the stream colour times
/// the weight.
///
/// Every face is wound counter-clockwise seen from its front (back faces may be culled). Depth testing is off, so the
/// crystal mesh is in painter's order (see ``wedgeOrder(_:)``).
public enum AmethystEscapeSceneGeometry {
    // MARK: Material codes

    /// The crystal material code of the dark backdrop plane, 0.
    public static let backdropCode = 0.0
    /// The crystal material code of an open (unblocked) amethyst wedge, 1.
    public static let amethystCode = 1.0
    /// The crystal material code of platinum: rim bands, wall fins, blocked crosses, exit arrow and move bar, 2.
    public static let platinumCode = 2.0
    /// The crystal material code of a dark blocked wedge, 3.
    public static let blockedCode = 3.0
    /// The crystal material code of the amber failed pocket's wedge, 4.
    public static let amberCode = 4.0

    /// The colour of crystal material `code` (0 … 4; the backdrop for any other code).
    public static func materialColour(_ code: Double) -> SIMD3<Double> {
        switch Int(code.isFinite ? code.rounded() : 0) {
        case 1: AmethystEscapePalette.amethyst
        case 2: AmethystEscapePalette.platinum
        case 3: AmethystEscapePalette.blocked
        case 4: AmethystEscapePalette.amber
        default: AmethystEscapePalette.backdrop
        }
    }

    // MARK: Constants (world units unless stated)

    /// The inner radius of shell 0, 0.2.
    public static let innerRadius = 0.2
    /// The radial span all shells share, 0.8 (so the outer shell ends at radius 1).
    public static let crystalSpan = 0.8
    /// The height of the outermost shell's wedges, 0.08.
    public static let baseHeight = 0.08
    /// The extra height per shell further in, 0.06.
    public static let heightStep = 0.06
    /// The inset of a wedge from its sector's edges, 0.04 · w.
    public static let wedgeInset = 0.04
    /// The bevel radius on a wedge's top edges: min(0.12 · w, 0.3 · h_k).
    public static let bevelWidth = 0.12
    /// The arc pieces of each wedge edge, 4 (the same at every tier).
    public static let arcSegments = 4
    /// The width of a rim band, 0.1 · w.
    public static let rimWidth = 0.1
    /// The height of a rim band above its wedge's top, 0.003.
    public static let rimLift = 0.003
    /// The thickness of a wall fin, 0.03 · w.
    public static let finThickness = 0.03
    /// How far a wall fin rises above its shell's wedges, 0.02.
    public static let finRise = 0.02
    /// The half-length of a blocked cross's arms, 0.25 · w.
    public static let crossArm = 0.25
    /// The width of a blocked cross's arms, 0.06 · w.
    public static let crossWidth = 0.06
    /// How far a blocked cross rises above its wedge's top, 0.012.
    public static let crossRise = 0.012
    /// The shade of a blocked cross (platinum dimmed), 0.6.
    public static let crossShade = 0.6
    /// The shade factor of every shell other than the isolated one (feature 364), 0.25: their wedges, rim bands, wall
    /// fins and blocked crosses have their shade (and fallback colour) multiplied by it.
    public static let isolationShade = 0.25
    /// The pearl's radius, 0.3 · w.
    public static let pearlRadius = 0.3
    /// The latitude bands of the pearl sphere, 8.
    public static let sphereBands = 8
    /// The longitude pieces of the pearl sphere, 16.
    public static let sphereSlices = 16
    /// How much wider each pearl glow shell is: shell k has radius 0.3·w · (1 + 0.35·k).
    public static let pearlShellGrowth = 0.35
    /// The glow weight of glow shell k is shellWeight^k (0.5); the core has weight 1.
    public static let shellWeight = 0.5
    /// The exit arrow's distance beyond the outer shell, 0.06.
    public static let exitDistance = 0.06
    /// The height of the exit arrow above the backdrop, 0.02.
    public static let exitLift = 0.02
    /// The half-length of the exit arrow, 0.035 (tail to tip 0.07).
    public static let arrowHalfLength = 0.035
    /// The half-width of the exit arrow's shaft, 0.015.
    public static let arrowShaft = 0.015
    /// The half-width of the exit arrow's head, 0.035.
    public static let arrowHead = 0.035
    /// The radius of exit glow shell k, 0.05 · (1 + k).
    public static let exitGlowRadius = 0.05
    /// The segments of a full circle (exit glow discs), 32.
    public static let circleSegments = 32
    /// The z of the move bar's centre line, 1.02.
    public static let moveBarZ = 1.02
    /// The x where the move bar starts, −0.8.
    public static let moveBarStart = -0.8
    /// The move bar's full length (at the budget), 1.6.
    public static let moveBarFull = 1.6
    /// The width of the move bar, 0.03.
    public static let moveBarWidth = 0.03
    /// The height of the move bar above the backdrop, 0.004.
    public static let moveBarLift = 0.004
    /// The half-side of the square backdrop plane, 1.1.
    public static let backdropHalf = 1.1
    /// The radius of the bounding sphere the camera fits, 1.1 (the crystal plus the exit arrow).
    public static let boundingRadius = 1.1
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's pitch below the horizon in radians (50°).
    public static let pitch = 50.0 * Double.pi / 180
    /// The unit direction from the crystal centre to the eye: (0, sin 50°, cos 50°) — in front (+z), above.
    public static let eyeDirection = SIMD3<Double>(0, sin(pitch), cos(pitch))
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places

    /// The shell width w = 0.8 / shells (0.8 for an empty snapshot).
    public static func shellWidth(_ snapshot: AmethystEscapeSceneSnapshot) -> Double {
        crystalSpan / Double(max(snapshot.shells.count, 1))
    }

    /// The inner radius r_k = 0.2 + k·w of shell `shell`.
    public static func shellRadius(_ shell: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> Double {
        innerRadius + Double(shell) * shellWidth(snapshot)
    }

    /// The wedge height h_k = 0.08 + 0.06·(n − 1 − k) of shell `shell` (inner shells stand taller).
    public static func shellHeight(_ shell: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> Double {
        baseHeight + heightStep * Double(max(snapshot.shells.count - 1 - shell, 0))
    }

    /// The world sector of own sector `sector` of shell `shell`: (sector + offset) mod sectors (the sector itself for an
    /// unknown shell).
    public static func worldSector(shell: Int, sector: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> Int {
        let offset: Int = snapshot.shells.indices.contains(shell) ? snapshot.shells[shell].offset : 0
        return modulo(sector + offset, max(snapshot.sectors, 1))
    }

    /// The middle angle of world sector `world`, 2π·(world + 0.5)/S, measured from +x towards +z.
    public static func sectorAngle(_ world: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> Double {
        2 * Double.pi * (Double(world) + 0.5) / Double(max(snapshot.sectors, 1))
    }

    /// The unit horizontal direction at `angle`: (cos, 0, sin).
    static func direction(_ angle: Double) -> SIMD3<Double> { SIMD3(cos(angle), 0, sin(angle)) }

    /// The top centre of own sector `sector`'s wedge in shell `shell`: radius r_k + w/2 at its world sector's middle
    /// angle, y = h_k; the origin for an unknown shell or sector.
    public static func wedgeTopCentre(shell: Int, sector: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> SIMD3<Double> {
        guard snapshot.shells.indices.contains(shell), (0..<snapshot.sectors).contains(sector) else { return .zero }
        let r: Double = shellRadius(shell, snapshot) + shellWidth(snapshot) / 2
        let world: Int = worldSector(shell: shell, sector: sector, snapshot)
        return direction(sectorAngle(world, snapshot)) * r + SIMD3(0, shellHeight(shell, snapshot), 0)
    }

    /// The pearl's centre: its pocket's centre (radius r_k + w/2 at the absolute sector's middle angle) at
    /// y = h_k + 0.3·w, or ``exitCentre(_:)`` once the pearl has escaped. A pocket shell beyond the crystal is clamped.
    public static func pearlCentre(_ snapshot: AmethystEscapeSceneSnapshot) -> SIMD3<Double> {
        if snapshot.escaped { return exitCentre(snapshot) }
        let shell: Int = min(max(snapshot.pearl.shell, 0), max(snapshot.shells.count - 1, 0))
        let w: Double = shellWidth(snapshot)
        let r: Double = shellRadius(shell, snapshot) + w / 2
        let world: Int = modulo(snapshot.pearl.sector, max(snapshot.sectors, 1))
        return direction(sectorAngle(world, snapshot)) * r
            + SIMD3(0, shellHeight(shell, snapshot) + pearlRadius * w, 0)
    }

    /// The exit arrow's centre: radius r_(n−1) + w + 0.06 (= 1.06) at the exit gap's world sector's middle angle,
    /// y = 0.02.
    public static func exitCentre(_ snapshot: AmethystEscapeSceneSnapshot) -> SIMD3<Double> {
        let r: Double = innerRadius + crystalSpan + exitDistance
        return direction(sectorAngle(modulo(snapshot.exitGap, max(snapshot.sectors, 1)), snapshot)) * r
            + SIMD3(0, exitLift, 0)
    }

    /// The move bar's length: 1.6 · moves / budget, clamped to 0 … 1.6 (0 for a non-positive budget).
    public static func moveBarLength(_ snapshot: AmethystEscapeSceneSnapshot) -> Double {
        guard snapshot.budget > 0 else { return 0 }
        return moveBarFull * min(max(Double(snapshot.moves) / Double(snapshot.budget), 0), 1)
    }

    /// Every wedge in painter's order: farthest from the +z camera first (ascending z of the wedge top centre), ties by
    /// height ascending, then by shell and sector.
    public static func wedgeOrder(_ snapshot: AmethystEscapeSceneSnapshot) -> [AmethystEscapeWedge] {
        var wedges: [(wedge: AmethystEscapeWedge, z: Double, y: Double)] = []
        for shell in snapshot.shells.indices {
            for sector in 0..<max(snapshot.sectors, 0) {
                let top: SIMD3<Double> = wedgeTopCentre(shell: shell, sector: sector, snapshot)
                let wedge = AmethystEscapeWedge(shell: shell, sector: sector,
                                                world: worldSector(shell: shell, sector: sector, snapshot))
                wedges.append((wedge, top.z, top.y))
            }
        }
        wedges.sort { a, b in
            if abs(a.z - b.z) > 1e-12 { return a.z < b.z }
            if abs(a.y - b.y) > 1e-12 { return a.y < b.y }
            if a.wedge.shell != b.wedge.shell { return a.wedge.shell < b.wedge.shell }
            return a.wedge.sector < b.wedge.sector
        }
        return wedges.map(\.wedge)
    }

    /// An upper bound of every element's y: the tallest wedge's fin (h_0 + 0.02) or the top of the widest pearl glow
    /// shell resting on shell 0 (h_0 + 0.3·w + 0.3·w · (1 + 0.35 · 2)), whichever is higher.
    public static func tallest(_ snapshot: AmethystEscapeSceneSnapshot) -> Double {
        let w: Double = shellWidth(snapshot)
        let h: Double = shellHeight(0, snapshot)
        return max(h + finRise, h + pearlRadius * w * (2 + pearlShellGrowth * 2))
    }

    // MARK: Meshes

    /// The crystal (crystal program, real normals, uv (material code, shade)), in painter's order: the backdrop square
    /// (half-side 1.1, y = 0, code 0); then for every wedge of ``wedgeOrder(_:)`` its bevelled prism (sides, then the
    /// `tier.bevelSegments` bevel bands, then the top; code 1, or 3 when blocked, or 4 for the failed pocket), its rim
    /// band when its outer wall is closed (code 2), its raised cross when blocked (code 2, shade 0.6) and the fin of
    /// every wall standing at its clockwise edge (code 2); then the exit arrow (code 2) and the move bar (code 2).
    /// Colours: ``materialColour(_:)`` × shade × (0.6 + 0.4 · max(n.y, 0)).
    ///
    /// With `isolated` naming a shell (feature 364), every other shell's wedges, rim bands, wall fins and blocked
    /// crosses have their shade multiplied by ``isolationShade`` (0.25; so their fallback colours too); the positions,
    /// the isolated shell, the backdrop, the exit arrow and the move bar are unchanged. Nil (the default), or an index
    /// that names no shell, gives exactly the mesh without isolation.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func crystalPart(_ snapshot: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier,
                                   isolated: Int? = nil) throws(MeshError) -> AmethystEscapeColouredMesh {
        var parts: Parts = Parts(lit: true)
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        let e: Double = backdropHalf
        try parts.quad([SIMD3(-e, 0, -e), SIMD3(-e, 0, e), SIMD3(e, 0, e), SIMD3(e, 0, -e)], front: up,
                       uv: Vec2(backdropCode, 1))
        guard snapshot.sectors > 0, !snapshot.shells.isEmpty else { return parts.built() }
        let w: Double = shellWidth(snapshot)
        let span: Double = 2 * Double.pi / Double(snapshot.sectors)
        var failed: (shell: Int, sector: Int)?
        if case .wedge(let shell, let sector) = snapshot.failure { failed = (shell, modulo(sector, snapshot.sectors)) }
        for wedge in wedgeOrder(snapshot) {
            let shell: AmethystEscapeSceneSnapshot.Shell = snapshot.shells[wedge.shell]
            let dim: Double = isolationFactor(shell: wedge.shell, isolated: isolated, snapshot)
            let blocked: Bool = shell.blocked.contains(wedge.sector)
            var code: Double = blocked ? blockedCode : amethystCode
            if let failed, failed.shell == wedge.shell, failed.sector == wedge.world { code = amberCode }
            let r0: Double = shellRadius(wedge.shell, snapshot)
            let h: Double = shellHeight(wedge.shell, snapshot)
            let frame = WedgeFrame(rIn: r0 + wedgeInset * w, rOut: r0 + w - wedgeInset * w,
                                   a0: Double(wedge.world) * span, a1: Double(wedge.world + 1) * span,
                                   gap: wedgeInset * w, height: h)
            let bevel: Double = min(bevelWidth * w, 0.3 * h)
            try addPrism(frame, bevel: bevel, segments: max(tier.bevelSegments, 1), code: code, shade: dim,
                         to: &parts)
            let topY: Double = h
            if !shell.apertures.contains(wedge.sector) {
                // The rim band along the outer arc of the top cap.
                let outer: Double = frame.rOut - bevel
                let inner: Double = outer - rimWidth * w
                var outerArc: [SIMD3<Double>] = []
                var innerArc: [SIMD3<Double>] = []
                for t in 0...arcSegments {
                    let f: Double = Double(t) / Double(arcSegments)
                    outerArc.append(frame.point(radius: outer, t: f, inset: bevel, y: topY + rimLift))
                    innerArc.append(frame.point(radius: inner, t: f, inset: bevel, y: topY + rimLift))
                }
                for t in 0..<arcSegments {
                    try parts.quad([outerArc[t], outerArc[t + 1], innerArc[t + 1], innerArc[t]], front: up,
                                   uv: Vec2(platinumCode, dim))
                }
            }
            if blocked {
                let centre: SIMD3<Double> = wedgeTopCentre(shell: wedge.shell, sector: wedge.sector, snapshot)
                let angle: Double = sectorAngle(wedge.world, snapshot)
                let radial: SIMD3<Double> = direction(angle)
                let tangent: SIMD3<Double> = SIMD3(-sin(angle), 0, cos(angle))
                let arcHalf: Double = 0.35 * (r0 + w / 2) * span
                let uv: Vec2 = Vec2(platinumCode, crossShade * dim)
                try parts.box(centre: centre, u: radial, v: tangent, halfU: crossArm * w, halfV: crossWidth * w / 2,
                              y0: topY, y1: topY + crossRise, uv: uv)
                try parts.box(centre: centre, u: tangent, v: radial, halfU: min(crossArm * w, arcHalf),
                              halfV: crossWidth * w / 2, y0: topY, y1: topY + crossRise, uv: uv)
            }
            if shell.walls.contains(wedge.sector) {
                // Wall i stands between own sectors i and i + 1: the clockwise edge of this wedge.
                let angle: Double = Double(wedge.world + 1) * span
                let centre: SIMD3<Double> = direction(angle) * (r0 + w / 2)
                try parts.box(centre: centre, u: direction(angle), v: SIMD3(-sin(angle), 0, cos(angle)),
                              halfU: w / 2, halfV: finThickness * w / 2, y0: 0, y1: h + finRise,
                              uv: Vec2(platinumCode, dim))
            }
        }
        // The exit arrow, flat, pointing outward.
        let exit: SIMD3<Double> = exitCentre(snapshot)
        let angle: Double = sectorAngle(modulo(snapshot.exitGap, snapshot.sectors), snapshot)
        let out: SIMD3<Double> = direction(angle)
        let side: SIMD3<Double> = SIMD3(-sin(angle), 0, cos(angle))
        let tail: SIMD3<Double> = exit - out * arrowHalfLength
        let neck: SIMD3<Double> = exit + out * (arrowHalfLength * 0.15)
        let tip: SIMD3<Double> = exit + out * arrowHalfLength
        let arrowUV: Vec2 = Vec2(platinumCode, 1)
        try parts.quad([tail - side * arrowShaft, tail + side * arrowShaft, neck + side * arrowShaft,
                        neck - side * arrowShaft], front: up, uv: arrowUV)
        try parts.triangle([neck - side * arrowHead, neck + side * arrowHead, tip], front: up, uv: arrowUV)
        // The move bar.
        let length: Double = moveBarLength(snapshot)
        if length > 0 {
            let z0: Double = moveBarZ - moveBarWidth / 2
            let z1: Double = moveBarZ + moveBarWidth / 2
            let x0: Double = moveBarStart
            let x1: Double = moveBarStart + length
            try parts.quad([SIMD3(x0, moveBarLift, z0), SIMD3(x0, moveBarLift, z1), SIMD3(x1, moveBarLift, z1),
                            SIMD3(x1, moveBarLift, z0)], front: up, uv: Vec2(platinumCode, 1))
        }
        return parts.built()
    }

    /// The crystal mesh (see ``crystalPart(_:tier:isolated:)``), with `isolated` as there (nil by default).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func crystalMesh(_ snapshot: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier,
                                   isolated: Int? = nil) throws(MeshError) -> Mesh {
        try crystalPart(snapshot, tier: tier, isolated: isolated).mesh
    }

    /// The shade factor of shell `shell` when `isolated` is drawn alone: 1 when `isolated` is nil, names no shell of
    /// `snapshot` or is `shell` itself; ``isolationShade`` otherwise.
    static func isolationFactor(shell: Int, isolated: Int?, _ snapshot: AmethystEscapeSceneSnapshot) -> Double {
        guard let isolated, snapshot.shells.indices.contains(isolated), isolated != shell else { return 1 }
        return isolationShade
    }

    /// The glow (glow program, colour in the normal slot, uv (weight, 0)): for k = `tier.glowShells` … 1 the exit glow
    /// disc of radius 0.05 · (1 + k) at the exit centre (exit colour) and the pearl glow sphere of radius
    /// 0.3·w · (1 + 0.35·k) (pearl colour), weight 0.5^k; then the pearl sphere of radius 0.3·w (8 bands × 16 slices,
    /// pearl colour, weight 1) at ``pearlCentre(_:)``. Colours: the stream colour times the weight.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowPart(_ snapshot: AmethystEscapeSceneSnapshot,
                                tier: AmethystEscapeTier) throws(MeshError) -> AmethystEscapeColouredMesh {
        var parts: Parts = Parts(lit: false)
        let w: Double = shellWidth(snapshot)
        let pearl: SIMD3<Double> = pearlCentre(snapshot)
        let exit: SIMD3<Double> = exitCentre(snapshot)
        let shells: Int = max(tier.glowShells, 0)
        if shells > 0 {
            for k in stride(from: shells, through: 1, by: -1) {
                let weight: Double = pow(shellWeight, Double(k))
                try parts.disc(centre: exit + SIMD3(0, -0.001 * Double(k), 0),
                               radius: exitGlowRadius * Double(1 + k), slot: AmethystEscapePalette.exit,
                               uv: Vec2(weight, 0))
                try parts.sphere(centre: pearl, radius: pearlRadius * w * (1 + pearlShellGrowth * Double(k)),
                                 slot: AmethystEscapePalette.pearl, uv: Vec2(weight, 0))
            }
        }
        try parts.sphere(centre: pearl, radius: pearlRadius * w, slot: AmethystEscapePalette.pearl, uv: Vec2(1, 0))
        return parts.built()
    }

    /// The glow mesh (see ``glowPart(_:tier:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowMesh(_ snapshot: AmethystEscapeSceneSnapshot,
                                tier: AmethystEscapeTier) throws(MeshError) -> Mesh {
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
    /// distance is radius / sin α.
    static func distance(radius: Double, aspect: Double) -> Double {
        let half: Double = tan(fieldOfView / 2)
        let limit: Double = (1 - 2 * fitMargin) * min(half, usableAspect(aspect) * half)
        return max(radius, 1e-3) / sin(atan(limit))
    }

    /// The fixed authored camera for `snapshot` and `aspect` (width / height): ``camera(_:aspect:orbit:)`` at
    /// ``AmethystEscapeOrbit/authored``, bit for bit, so the eye lies on ``eyeDirection`` (in front, +z, pitched 50°
    /// down) at the distance that fits the sphere of radius 1.1 about the origin, looking at the origin with +y up and
    /// a 45° vertical field of view. For aspects 0.4 … 2.5 the sphere projects inside the view with at least 5 % margin
    /// on every side. A zero, negative or non-finite aspect is treated as 1; others are clamped to 0.1 … 10.
    /// Independent of the tier, the time and the play.
    public static func camera(_ snapshot: AmethystEscapeSceneSnapshot, aspect: Double) -> AmethystEscapeCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The camera for `snapshot`, `aspect` (width / height) and `orbit` (clamped, see
    /// ``AmethystEscapeOrbit/clamped()``): the eye on ``AmethystEscapeOrbit/eyeDirection`` from the origin at the
    /// distance that fits the sphere of radius 1.1 (the fit does not depend on the direction, so the 5 % margin holds at
    /// every orbit and aspect 0.4 … 2.5), looking at the origin with +y up (never parallel to the view direction: the
    /// pitch is at most 75°) and a 45° vertical field of view. Aspects are made usable as in ``camera(_:aspect:)``.
    /// Presentation only; independent of the tier, the time and the play.
    public static func camera(_ snapshot: AmethystEscapeSceneSnapshot, aspect: Double,
                              orbit: AmethystEscapeOrbit) -> AmethystEscapeCamera {
        let a: Double = usableAspect(aspect)
        let radius: Double = boundingRadius
        let d: Double = distance(radius: radius, aspect: a)
        let eye: SIMD3<Double> = orbit.eyeDirection * d
        let near: Double = max((d - radius) * 0.5, 1e-3)
        let far: Double = d + 2 * radius + 1
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: Vec3(0, 0, 0), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return AmethystEscapeCamera(eye: eye, target: .zero, fovY: fieldOfView, aspect: a, near: near, far: far,
                                    radius: radius, view: view, projection: projection,
                                    viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (origin top left, y down; multiply by the viewport size for pixels, the
    /// convention of `ScreenProjection`); nil behind the camera or for non-finite input. Points outside the view give
    /// coordinates outside 0 … 1.
    public static func project(_ point: SIMD3<Double>, camera: AmethystEscapeCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    /// `point` in pixels of a `width` × `height` viewport (origin top left, y down); nil for a non-positive size,
    /// behind the camera or for non-finite input.
    public static func pixel(_ point: SIMD3<Double>, camera: AmethystEscapeCamera, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0, let v = project(point, camera: camera) else { return nil }
        return Vec2(v.x * Double(width), v.y * Double(height))
    }

    // MARK: Building

    /// The outline frame of one wedge: radial bounds after the 0.04·w inset, world angles and the arc-length gap kept
    /// from the radial edges.
    struct WedgeFrame {
        let rIn: Double
        let rOut: Double
        let a0: Double
        let a1: Double
        let gap: Double
        let height: Double

        /// The point at `radius` and arc parameter `t` (0 … 1), kept `gap + inset` (arc length) from the radial edges,
        /// at height `y`.
        func point(radius: Double, t: Double, inset: Double, y: Double) -> SIMD3<Double> {
            let delta: Double = min((gap + inset) / max(radius, 1e-6), (a1 - a0) * 0.45)
            let angle: Double = a0 + delta + t * (a1 - a0 - 2 * delta)
            return SIMD3(radius * cos(angle), y, radius * sin(angle))
        }

        /// The closed outline at `inset` and height `y`: the outer arc t = 0 … 1, then the inner arc t = 1 … 0.
        func ring(inset: Double, y: Double, segments: Int) -> [SIMD3<Double>] {
            var loop: [SIMD3<Double>] = []
            for t in 0...segments {
                loop.append(point(radius: rOut - inset, t: Double(t) / Double(segments), inset: inset, y: y))
            }
            for t in stride(from: segments, through: 0, by: -1) {
                loop.append(point(radius: rIn + inset, t: Double(t) / Double(segments), inset: inset, y: y))
            }
            return loop
        }

        /// The wedge's centre axis point at height `y`.
        func centre(y: Double) -> SIMD3<Double> {
            let r: Double = (rIn + rOut) / 2
            let a: Double = (a0 + a1) / 2
            return SIMD3(r * cos(a), y, r * sin(a))
        }
    }

    /// Adds one bevelled prism: vertical sides from y = 0 to h − bevel, `segments` quarter-round bevel bands up to the
    /// top (inset bevel · (1 − cos θ), y = h − bevel + bevel · sin θ), then the flat top cap; uv (code, `shade`).
    static func addPrism(_ frame: WedgeFrame, bevel: Double, segments: Int, code: Double, shade: Double = 1,
                         to parts: inout Parts) throws(MeshError) {
        let uv: Vec2 = Vec2(code, shade)
        let a: Int = arcSegments
        var rings: [[SIMD3<Double>]] = [frame.ring(inset: 0, y: 0, segments: a)]
        for j in 0...segments {
            // The last ring is exactly (inset bevel, y = h), so the top is identical at every tier.
            let theta: Double = Double.pi / 2 * Double(j) / Double(segments)
            let inset: Double = j == segments ? bevel : bevel * (1 - cos(theta))
            let y: Double = j == segments ? frame.height : frame.height - bevel + bevel * sin(theta)
            rings.append(frame.ring(inset: inset, y: y, segments: a))
        }
        for level in 0..<(rings.count - 1) {
            let lower: [SIMD3<Double>] = rings[level]
            let upper: [SIMD3<Double>] = rings[level + 1]
            for i in lower.indices {
                let n: Int = (i + 1) % lower.count
                let p: [SIMD3<Double>] = [lower[i], lower[n], upper[n], upper[i]]
                let mid: SIMD3<Double> = (p[0] + p[1] + p[2] + p[3]) / 4
                let outward: SIMD3<Double> = mid - frame.centre(y: mid.y)
                try parts.quad(p, front: outward + SIMD3(0, 0.25 * length(outward), 0), uv: uv)
            }
        }
        let top: [SIMD3<Double>] = rings[rings.count - 1]
        let count: Int = top.count
        for t in 0..<a {
            // Outer arc t at index t, inner arc t at index count − 1 − t.
            try parts.quad([top[t], top[t + 1], top[count - 2 - t], top[count - 1 - t]], front: SIMD3(0, 1, 0),
                           uv: uv)
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
                return AmethystEscapeSceneGeometry.materialColour(uv.x) * uv.y * (0.6 + 0.4 * max(slot.y, 0))
            }
            return slot * min(max(uv.x, 0), 1)
        }

        /// Adds one vertex and returns its index.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, uv: Vec2) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(AmethystEscapeSceneGeometry.vec(p),
                                                normal: AmethystEscapeSceneGeometry.vec(slot), uv: uv)
            if Int(id) == colours.count {
                let c: SIMD3<Double> = colour(slot: slot, uv: uv)
                colours.append(Vec4(min(max(c.x, 0), 1), min(max(c.y, 0), 1), min(max(c.z, 0), 1), 1))
            }
            return id
        }

        /// Adds a flat (planar) quad p0 p1 p2 p3 in order around it, wound counter-clockwise seen from the side of
        /// `front`; on the crystal its real face normal goes in the normal stream.
        mutating func quad(_ p: [SIMD3<Double>], front: SIMD3<Double>, uv: Vec2,
                           slot: SIMD3<Double>? = nil) throws(MeshError) {
            var normal: SIMD3<Double> = AmethystEscapeSceneGeometry.unit(
                AmethystEscapeSceneGeometry.cross(p[2] - p[0], p[3] - p[1]))
            if AmethystEscapeSceneGeometry.dot(normal, front) < 0 { normal = -normal }
            let s: SIMD3<Double> = slot ?? normal
            var ids: [UInt32] = []
            for i in 0..<4 { ids.append(try vertex(p[i], slot: s, uv: uv)) }
            try facing(ids[0], ids[1], ids[2], p[0], p[1], p[2], front: normal)
            try facing(ids[0], ids[2], ids[3], p[0], p[2], p[3], front: normal)
        }

        /// Adds a flat triangle wound counter-clockwise seen from the side of `front`.
        mutating func triangle(_ p: [SIMD3<Double>], front: SIMD3<Double>, uv: Vec2) throws(MeshError) {
            var normal: SIMD3<Double> = AmethystEscapeSceneGeometry.unit(
                AmethystEscapeSceneGeometry.cross(p[1] - p[0], p[2] - p[0]))
            if AmethystEscapeSceneGeometry.dot(normal, front) < 0 { normal = -normal }
            var ids: [UInt32] = []
            for i in 0..<3 { ids.append(try vertex(p[i], slot: normal, uv: uv)) }
            try facing(ids[0], ids[1], ids[2], p[0], p[1], p[2], front: normal)
        }

        /// Adds a box standing on y0 up to y1 about `centre` (its y ignored) with horizontal unit axes `u`, `v` and
        /// half-extents `halfU`, `halfV`: the four sides, then the top (no bottom).
        mutating func box(centre: SIMD3<Double>, u: SIMD3<Double>, v: SIMD3<Double>, halfU: Double, halfV: Double,
                          y0: Double, y1: Double, uv: Vec2) throws(MeshError) {
            let c: SIMD3<Double> = SIMD3(centre.x, 0, centre.z)
            let corners: [SIMD3<Double>] = [c - u * halfU - v * halfV, c + u * halfU - v * halfV,
                                            c + u * halfU + v * halfV, c - u * halfU + v * halfV]
            let lower: [SIMD3<Double>] = corners.map { $0 + SIMD3(0, y0, 0) }
            let upper: [SIMD3<Double>] = corners.map { $0 + SIMD3(0, y1, 0) }
            for i in 0..<4 {
                let n: Int = (i + 1) % 4
                let mid: SIMD3<Double> = (corners[i] + corners[n]) / 2 - c
                try quad([lower[i], lower[n], upper[n], upper[i]], front: mid, uv: uv)
            }
            try quad(upper, front: SIMD3(0, 1, 0), uv: uv)
        }

        /// Adds a flat up-facing disc (a fan of 32 triangles), `slot` in the normal stream.
        mutating func disc(centre: SIMD3<Double>, radius: Double, slot: SIMD3<Double>, uv: Vec2) throws(MeshError) {
            let n: Int = AmethystEscapeSceneGeometry.circleSegments
            let hub: UInt32 = try vertex(centre, slot: slot, uv: uv)
            for k in 0..<n {
                let a0: Double = 2 * Double.pi * Double(k) / Double(n)
                let a1: Double = 2 * Double.pi * Double(k + 1) / Double(n)
                let p0: SIMD3<Double> = centre + SIMD3(cos(a0), 0, sin(a0)) * radius
                let p1: SIMD3<Double> = centre + SIMD3(cos(a1), 0, sin(a1)) * radius
                let i0: UInt32 = try vertex(p0, slot: slot, uv: uv)
                let i1: UInt32 = try vertex(p1, slot: slot, uv: uv)
                try facing(hub, i0, i1, centre, p0, p1, front: SIMD3(0, 1, 0))
            }
        }

        /// Adds an outward-facing UV sphere (8 bands × 16 slices), `slot` in the normal stream.
        mutating func sphere(centre: SIMD3<Double>, radius: Double, slot: SIMD3<Double>, uv: Vec2) throws(MeshError) {
            let bands: Int = AmethystEscapeSceneGeometry.sphereBands
            let slices: Int = AmethystEscapeSceneGeometry.sphereSlices
            func point(_ band: Int, _ slice: Int) -> SIMD3<Double> {
                let phi: Double = Double.pi * Double(band) / Double(bands)
                let theta: Double = 2 * Double.pi * Double(slice) / Double(slices)
                return centre + SIMD3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * radius
            }
            for band in 0..<bands {
                for slice in 0..<slices {
                    let p00: SIMD3<Double> = point(band, slice)
                    let p01: SIMD3<Double> = point(band, slice + 1)
                    let p10: SIMD3<Double> = point(band + 1, slice)
                    let p11: SIMD3<Double> = point(band + 1, slice + 1)
                    let i00: UInt32 = try vertex(p00, slot: slot, uv: uv)
                    let i01: UInt32 = try vertex(p01, slot: slot, uv: uv)
                    let i10: UInt32 = try vertex(p10, slot: slot, uv: uv)
                    let i11: UInt32 = try vertex(p11, slot: slot, uv: uv)
                    if band > 0 {
                        try facing(i00, i10, i01, p00, p10, p01, front: (p00 + p10 + p01) / 3 - centre)
                    }
                    if band < bands - 1 {
                        try facing(i01, i10, i11, p01, p10, p11, front: (p01 + p10 + p11) / 3 - centre)
                    }
                }
            }
        }

        /// Adds triangle a, b, c wound so its geometric normal points along `front`.
        mutating func facing(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            if AmethystEscapeSceneGeometry.dot(AmethystEscapeSceneGeometry.cross(pb - pa, pc - pa), front) < 0 {
                try builder.triangle(a, c, b)
            } else {
                try builder.triangle(a, b, c)
            }
        }

        /// The coloured mesh built so far.
        func built() -> AmethystEscapeColouredMesh {
            AmethystEscapeColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `value` mod `n` in 0 ..< n (0 for a non-positive n).
    static func modulo(_ value: Int, _ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return ((value % n) + n) % n
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
