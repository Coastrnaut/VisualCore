// BackwardsAuroraSceneGeometry — feature 393 (R02-G10-03) T-R02G1003-004 (FR-R02G1003-001, 006; clarification Q1).
// The aurora of Backwards Aurora, built from a snapshot only. The timeline stands upright as the plane z = 0 with y up:
// with u = 2 / N, sample k sits at x = −1 + (k + 0.5)·u and y = 0.6·s(k) / 64. The ribbon is a strip 0.06 high (y ±
// 0.03) through the sample points, each segment between neighbouring samples tessellated into 4 straight steps (the
// drawn path is the kernel's polyline, never a smoothed curve; the vertices at the sample points are exact). Trailing
// aurora layer i (i = 1 … tier.trailingLayers − 1) is a copy of the ribbon at z = −0.06·i, y + 0.04·i. The ghost trail
// is the target's polyline, 0.024 high, at z = −0.05. Each checkpoint is a vertical tick (0.008 wide) from y = −0.7 to
// 0.7 at z = −0.02 with a ring (radius 0.045, line 0.012) at the target height at z = 0.02, a filled disc when matched.
// Every bend above the limit carries a kink cross (two bars, 0.05 across) at its sample point at z = 0.03; a tear a
// larger cross (0.09) at its seam. The chosen section [start, end] is a band from x(start) − u/2 to x(end) + u/2,
// y −0.7 … 0.7, at z = −0.08, with dashed edges. The reversal gauge is a row of `budget` bars at y = −0.85 from
// x = −0.9 to 0.9, the spent ones first. The ground is a midnight plane at z = −0.2 reaching well beyond the view.
// Depth testing is off on this render path, so the mesh is emitted in painter's order: ground, band, trailing layers
// (back to front), ghost, ticks, ribbon, preview ribbon (feature 394), rings and discs, crosses, gauge. The fixed authored camera looks from +z at
// (0, −0.1, 0), fitted so the box x −1 … 1, y −0.95 … 0.75, z −0.2 … 0.05 fits with a margin of at least 5 % for
// aspect 0.4 … 2.5.
//
// Vertex streams (the contract with the shaders): the normal is the lighting normal (+z), uv.x the material code (see
// `Material`), uv.y the signed timeline coordinate t = (x + 1) / 2 clamped to 0 … 1, negated on ribbon and trailing
// vertices inside the chosen section (so pulses run right to left there). Glow meshes carry their colour in the normal
// slot and the glow factor in uv.x. Triangles wind counter-clockwise seen from +z. Pulses and shimmer move by uniforms
// only: no position depends on the time or Reduce Motion, and positions of the ribbon, ghost and markers are the same
// at every tier (tiers change only the trailing layers and the glow shells here). Doubles are used for drawing only;
// nothing here is consulted by the rules.
//
// Feature 394 (R02-G10-04) T-R02G1004-003 (FR-R02G1004-002, 004, 005; SC-R02G1004-004; clarifications Q1, Q3, Q4) adds
// the player's orbit (`BackwardsAuroraOrbit`: yaw ±35° about +y, pitch −15° … +20°, authored (0, 0)) and
// `camera(_:aspect:orbit:)`: the eye orbits about the look-at point (0, −0.1, 0) and its distance refits to the same
// authored box with the same margin at every orbit and aspect 0.4 … 2.5; at the authored orbit the camera equals
// `camera(_:aspect:)` bit for bit. It also adds the freeze preview's ribbon: when the snapshot carries `preview`
// samples, a strip like the ribbon (0.06 high, 4 straight steps per segment, unsigned timeline coordinate) through the
// would-be sample points at z = 0.01 with material code 13 (the shader dashes it along the timeline), emitted right
// after the ribbon and before the rings and crosses.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The fixed authored camera of one frame: eye, target, lens and the matrices built from them.
public struct BackwardsAuroraCamera: Sendable, Equatable {
    /// The eye position in world units.
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.1, 0).
    public let target: SIMD3<Double>
    /// The vertical field of view in radians.
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

/// The player's view of the aurora: a yaw about +y and a pitch above the horizontal, both in radians (feature 394,
/// R02-G10-04, clarification Q4). Presentation only: never saved, never read by the rules.
public struct BackwardsAuroraOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians: the angle of the eye direction above the horizontal through the look-at point (positive:
    /// the eye above, looking down); allowed ``pitchRange`` (−15° … +20°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G10-03 (from +z).
    public static let authored = BackwardsAuroraOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 35° in radians.
    public static let yawLimit: Double = 35.0 * Double.pi / 180
    /// The allowed pitches, −15° … +20° in radians.
    public static let pitchRange: ClosedRange<Double> = (-15.0 * Double.pi / 180)...(20.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −35° … 35° and pitch to −15° … 20°; a non-finite angle becomes the authored one.
    public func clamped() -> BackwardsAuroraOrbit {
        let y: Double = yaw.isFinite ? yaw : Self.authored.yaw
        let p: Double = pitch.isFinite ? pitch : Self.authored.pitch
        return BackwardsAuroraOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                    pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// The unit direction from the look-at point to the eye at the clamped orbit: (sin y · cos p, sin p, cos y · cos p)
    /// with y the yaw and p the pitch; exactly (0, 0, 1) at ``authored``.
    public var eyeDirection: SIMD3<Double> {
        let o: BackwardsAuroraOrbit = clamped()
        return SIMD3(sin(o.yaw) * cos(o.pitch), sin(o.pitch), cos(o.yaw) * cos(o.pitch))
    }

    /// The camera's unit right axis at the clamped orbit, (cos y, 0, −sin y): exactly (1, 0, 0) at ``authored``.
    var rightAxis: SIMD3<Double> {
        let o: BackwardsAuroraOrbit = clamped()
        return SIMD3(cos(o.yaw), 0, -sin(o.yaw))
    }

    /// The camera's unit up axis at the clamped orbit, (−sin y · sin p, cos p, −cos y · sin p): exactly (0, 1, 0) at
    /// ``authored``.
    var upAxis: SIMD3<Double> {
        let o: BackwardsAuroraOrbit = clamped()
        return SIMD3(-sin(o.yaw) * sin(o.pitch), cos(o.pitch), -cos(o.yaw) * sin(o.pitch))
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct BackwardsAuroraColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Backwards Aurora scene from a `BackwardsAuroraSceneSnapshot`: places, meshes, camera and projection.
public enum BackwardsAuroraSceneGeometry {
    /// The material codes written to uv.x (the contract with the shaders).
    enum Material {
        /// The midnight ground.
        static let ground: Double = 0
        /// The section band.
        static let band: Double = 1
        /// The first trailing copy of the ribbon (layer 1).
        static let trailingFirst: Double = 2
        /// The ghost trail.
        static let ghost: Double = 3
        /// A checkpoint tick (and the band's dashed edges).
        static let tick: Double = 4
        /// The ribbon.
        static let ribbon: Double = 5
        /// A checkpoint ring.
        static let ring: Double = 6
        /// A matched checkpoint's disc.
        static let disc: Double = 7
        /// A kink cross.
        static let kink: Double = 8
        /// The tear cross.
        static let tear: Double = 9
        /// A spent gauge bar.
        static let spent: Double = 10
        /// An unspent gauge bar.
        static let unspent: Double = 11
        /// The second trailing copy of the ribbon (layer 2).
        static let trailingSecond: Double = 12
        /// The freeze preview's dashed ribbon (feature 394, R02-G10-04).
        static let preview: Double = 13

        /// The code of trailing layer `layer` (1 or 2; deeper layers reuse the second code).
        static func trailing(_ layer: Int) -> Double { layer <= 1 ? trailingFirst : trailingSecond }
    }

    // MARK: Constants (world units unless stated)

    /// Half the timeline's width.
    public static let halfWidth: Double = 1
    /// World height per sample unit (0.6 / 64).
    public static let heightScale: Double = 0.6 / 64
    /// Half the ribbon's height.
    public static let ribbonHalfHeight: Double = 0.03
    /// Straight steps per segment between neighbouring samples.
    public static let stepsPerSegment: Int = 4
    /// Depth step of each trailing layer (layer i at z = −layerDepth·i).
    public static let layerDepth: Double = 0.06
    /// Height lift of each trailing layer (layer i at y + layerLift·i).
    public static let layerLift: Double = 0.04
    /// The freeze preview ribbon's plane, just in front of the ribbon (feature 394, R02-G10-04).
    public static let previewZ: Double = 0.01
    /// The ghost trail's plane.
    public static let ghostZ: Double = -0.05
    /// Half the ghost trail's height.
    public static let ghostHalfHeight: Double = 0.012
    /// The ticks' plane.
    public static let tickZ: Double = -0.02
    /// Half a tick's width.
    public static let tickHalfWidth: Double = 0.004
    /// The ticks' and band's vertical reach (±).
    public static let markerReach: Double = 0.7
    /// The rings' and discs' plane.
    public static let ringZ: Double = 0.02
    /// A ring's radius (the centre of its line).
    public static let ringRadius: Double = 0.045
    /// A ring's line width.
    public static let ringLine: Double = 0.012
    /// Segments of a ring or disc.
    public static let ringSegments: Int = 24
    /// The crosses' plane.
    public static let crossZ: Double = 0.03
    /// A kink cross's span.
    public static let kinkSpan: Double = 0.05
    /// A kink bar's width.
    public static let kinkWidth: Double = 0.008
    /// The tear cross's span.
    public static let tearSpan: Double = 0.09
    /// A tear bar's width.
    public static let tearWidth: Double = 0.012
    /// The band's plane.
    public static let bandZ: Double = -0.08
    /// The dashes' length along the band's edges.
    public static let dashLength: Double = 0.05
    /// Half a dash's width.
    public static let dashHalfWidth: Double = 0.003
    /// The gauge's height.
    public static let gaugeY: Double = -0.85
    /// The gauge's plane.
    public static let gaugeZ: Double = 0.04
    /// The gauge's left end.
    public static let gaugeStart: Double = -0.9
    /// The gauge's right end.
    public static let gaugeEnd: Double = 0.9
    /// The share of a slot a bar fills.
    public static let gaugeFill: Double = 0.6
    /// The widest bar.
    public static let gaugeMaxWidth: Double = 0.12
    /// Half a bar's height.
    public static let gaugeHalfHeight: Double = 0.03
    /// The ground's plane.
    public static let groundZ: Double = -0.2
    /// Half the ground's size (covers the view at every sanitised aspect).
    public static let groundHalfSize: Double = 32
    /// Extra half height of each glow shell.
    public static let glowGrowth: Double = 0.02
    /// Depth step of each glow shell behind the ribbon.
    public static let glowDrop: Double = 0.002
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// The vertical field of view (45°).
    public static let fieldOfView: Double = Double.pi / 4
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.1, 0)
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-1, -0.95, -0.2)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1, 0.75, 0.05)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places

    /// N, at least 1.
    static func count(_ snapshot: BackwardsAuroraSceneSnapshot) -> Int { max(snapshot.count, 1) }

    /// The sample spacing u = 2 / N.
    public static func spacing(_ snapshot: BackwardsAuroraSceneSnapshot) -> Double {
        2 * halfWidth / Double(count(snapshot))
    }

    /// The x of position `k` (fractional positions allowed): −1 + (k + 0.5)·u.
    static func x(_ k: Double, _ snapshot: BackwardsAuroraSceneSnapshot) -> Double {
        -halfWidth + (k + 0.5) * spacing(snapshot)
    }

    /// The y of sample value `s`: 0.6·s / 64.
    static func y(_ s: Int) -> Double { heightScale * Double(s) }

    /// The timeline coordinate of `x`, (x + 1) / 2 clamped to 0 … 1.
    static func timeline(_ x: Double) -> Double { min(max((x + halfWidth) / (2 * halfWidth), 0), 1) }

    /// The wave's sample `k` (clamped to the wave) on the plane z = 0.
    public static func samplePoint(_ k: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.samples.isEmpty else { return SIMD3(0, 0, 0) }
        let i: Int = min(max(k, 0), snapshot.samples.count - 1)
        return SIMD3(x(Double(i), snapshot), y(snapshot.samples[i]), 0)
    }

    /// The target's sample `k` (clamped) on the ghost plane z = −0.05.
    public static func targetPoint(_ k: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.target.isEmpty else { return SIMD3(0, 0, ghostZ) }
        let i: Int = min(max(k, 0), snapshot.target.count - 1)
        return SIMD3(x(Double(i), snapshot), y(snapshot.target[i]), ghostZ)
    }

    /// The centre of checkpoint `index`'s ring: its x, the target's height there, z = 0.02.
    public static func ringCentre(_ index: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.checkpoints.isEmpty else { return SIMD3(0, 0, ringZ) }
        let position: Int = snapshot.checkpoints[min(max(index, 0), snapshot.checkpoints.count - 1)]
        let t: SIMD3<Double> = targetPoint(position, snapshot)
        return SIMD3(t.x, t.y, ringZ)
    }

    /// The centre of gauge bar `index` (of `budget` slots across x −0.9 … 0.9 at y = −0.85).
    public static func gaugeBar(_ index: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double> {
        let slot: Double = (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
        return SIMD3(gaugeStart + (Double(index) + 0.5) * slot, gaugeY, gaugeZ)
    }

    /// The bars drawn spent: the reversals spent, clamped to 0 … budget.
    public static func spentBars(_ snapshot: BackwardsAuroraSceneSnapshot) -> Int {
        min(max(snapshot.spent, 0), max(snapshot.budget, 0))
    }

    /// The section band's x range: x(start) − u/2 … x(end) + u/2.
    public static func bandRange(_ snapshot: BackwardsAuroraSceneSnapshot) -> ClosedRange<Double> {
        let u: Double = spacing(snapshot)
        let low: Double = x(Double(snapshot.sectionStart), snapshot) - u / 2
        let high: Double = x(Double(snapshot.sectionEnd), snapshot) + u / 2
        return min(low, high)...max(low, high)
    }

    // MARK: Meshes

    /// The whole aurora (every layer but the glow) with fallback colours, in painter's order. `reduceMotion` is
    /// accepted for parity with the shader path; no position depends on it.
    public static func auroraPart(_ snapshot: BackwardsAuroraSceneSnapshot, tier: BackwardsAuroraTier,
                                  reduceMotion: Bool = false) throws(MeshError) -> BackwardsAuroraColouredMesh {
        typealias M = BackwardsAuroraSceneGeometry.Material
        _ = reduceMotion
        var parts: Parts = Parts(lit: true)
        let front: SIMD3<Double> = SIMD3(0, 0, 1)
        let n: Int = snapshot.count
        // Ground.
        let g: Double = groundHalfSize
        try parts.polygon([SIMD3(-g, -g, groundZ), SIMD3(g, -g, groundZ), SIMD3(g, g, groundZ),
                           SIMD3(-g, g, groundZ)], normal: front, code: M.ground)
        // Band with dashed edges.
        if n >= 2 {
            let band: ClosedRange<Double> = bandRange(snapshot)
            try parts.polygon([SIMD3(band.lowerBound, -markerReach, bandZ), SIMD3(band.upperBound, -markerReach, bandZ),
                               SIMD3(band.upperBound, markerReach, bandZ), SIMD3(band.lowerBound, markerReach, bandZ)],
                              normal: front, code: M.band)
            let dashes: Int = Int((2 * markerReach / (2 * dashLength)).rounded(.down))
            for edge in [band.lowerBound, band.upperBound] {
                for d in 0..<dashes {
                    let y0: Double = -markerReach + Double(d) * 2 * dashLength
                    let y1: Double = y0 + dashLength
                    try parts.polygon([SIMD3(edge - dashHalfWidth, y0, bandZ), SIMD3(edge + dashHalfWidth, y0, bandZ),
                                       SIMD3(edge + dashHalfWidth, y1, bandZ), SIMD3(edge - dashHalfWidth, y1, bandZ)],
                                      normal: front, code: M.tick)
                }
            }
        }
        // Trailing layers, back to front.
        let layers: Int = max(tier.trailingLayers, 1)
        if layers > 1 {
            for layer in stride(from: layers - 1, through: 1, by: -1) {
                try addStrip(snapshot, lift: layerLift * Double(layer), z: -layerDepth * Double(layer),
                             halfHeight: ribbonHalfHeight, code: M.trailing(layer), signed: true, slot: nil,
                             to: &parts)
            }
        }
        // Ghost.
        if snapshot.target.count >= 2 {
            for k in 0..<(snapshot.target.count - 1) {
                let a: SIMD3<Double> = targetPoint(k, snapshot)
                let b: SIMD3<Double> = targetPoint(k + 1, snapshot)
                try parts.step(a, b, halfHeight: ghostHalfHeight, code: M.ghost, signA: 1, signB: 1, slot: nil)
            }
        }
        // Ticks.
        for position in snapshot.checkpoints where position >= 0 && position < n {
            let cx: Double = x(Double(position), snapshot)
            try parts.polygon([SIMD3(cx - tickHalfWidth, -markerReach, tickZ),
                               SIMD3(cx + tickHalfWidth, -markerReach, tickZ),
                               SIMD3(cx + tickHalfWidth, markerReach, tickZ),
                               SIMD3(cx - tickHalfWidth, markerReach, tickZ)], normal: front, code: M.tick)
        }
        // Ribbon.
        try addStrip(snapshot, lift: 0, z: 0, halfHeight: ribbonHalfHeight, code: M.ribbon, signed: true, slot: nil,
                     to: &parts)
        // Freeze preview ribbon (feature 394): only while the snapshot carries would-be samples.
        if snapshot.preview.count == n && n >= 2 {
            try addPreview(snapshot, to: &parts)
        }
        // Rings and discs.
        for index in snapshot.checkpoints.indices {
            let position: Int = snapshot.checkpoints[index]
            guard position >= 0 && position < n else { continue }
            let c: SIMD3<Double> = ringCentre(index, snapshot)
            let matched: Bool = index < snapshot.matched.count && snapshot.matched[index]
            if matched {
                try parts.disc(centre: c, radius: ringRadius + ringLine / 2, segments: ringSegments, code: M.disc)
            } else {
                try parts.ring(centre: c, inner: ringRadius - ringLine / 2, outer: ringRadius + ringLine / 2,
                               segments: ringSegments, code: M.ring)
            }
        }
        // Crosses.
        for k in snapshot.kinks where k >= 0 && k < n {
            let p: SIMD3<Double> = samplePoint(k, snapshot)
            try parts.cross(centre: SIMD3(p.x, p.y, crossZ), span: kinkSpan, width: kinkWidth, code: M.kink)
        }
        if let seam = snapshot.tear, n > 0 {
            let p: SIMD3<Double> = samplePoint(seam, snapshot)
            try parts.cross(centre: SIMD3(p.x, p.y, crossZ), span: tearSpan, width: tearWidth, code: M.tear)
        }
        // Gauge.
        let budget: Int = max(snapshot.budget, 0)
        let spent: Int = spentBars(snapshot)
        let slot: Double = (gaugeEnd - gaugeStart) / Double(max(budget, 1))
        let half: Double = min(gaugeFill * slot, gaugeMaxWidth) / 2
        for bar in 0..<budget {
            let c: SIMD3<Double> = gaugeBar(bar, snapshot)
            let lo: Double = c.y - gaugeHalfHeight
            let hi: Double = c.y + gaugeHalfHeight
            try parts.polygon([SIMD3(c.x - half, lo, c.z), SIMD3(c.x + half, lo, c.z), SIMD3(c.x + half, hi, c.z),
                               SIMD3(c.x - half, hi, c.z)],
                              normal: front, code: bar < spent ? M.spent : M.unspent)
        }
        return parts.built()
    }

    /// The aurora mesh for the custom shader (`auroraPart` without colours).
    public static func auroraMesh(_ snapshot: BackwardsAuroraSceneSnapshot, tier: BackwardsAuroraTier,
                                  reduceMotion: Bool = false) throws(MeshError) -> Mesh {
        try auroraPart(snapshot, tier: tier, reduceMotion: reduceMotion).mesh
    }

    /// The glow shells around the ribbon, outermost first (shell k: y ± (0.03 + 0.02·k) at z = −0.002·k), with the
    /// glow colour in the normal slot, uv.x = 0.5^k and uv.y the signed timeline coordinate; empty when the tier has no
    /// glow.
    public static func glowPart(_ snapshot: BackwardsAuroraSceneSnapshot,
                                tier: BackwardsAuroraTier) throws(MeshError) -> BackwardsAuroraColouredMesh {
        var parts: Parts = Parts(lit: false)
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        for k in stride(from: shells, through: 1, by: -1) {
            let weight: Double = pow(glowWeight, Double(k))
            let halfHeight: Double = ribbonHalfHeight + glowGrowth * Double(k)
            try addStrip(snapshot, lift: 0, z: -glowDrop * Double(k), halfHeight: halfHeight,
                         code: weight, signed: true, slot: BackwardsAuroraPalette.glow, to: &parts)
        }
        return parts.built()
    }

    /// The glow mesh for the custom shader (`glowPart` without colours).
    public static func glowMesh(_ snapshot: BackwardsAuroraSceneSnapshot,
                                tier: BackwardsAuroraTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    // MARK: Camera

    /// `aspect` made usable: 1 when not finite and positive, else clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// The eye distance that holds the box with `fitMargin` per side at `aspect`.
    static func distance(aspect: Double) -> Double {
        let half: Double = tan(fieldOfView / 2)
        let limit: Double = 1 - 2 * fitMargin
        let lx: Double = limit * usableAspect(aspect) * half
        let ly: Double = limit * half
        var d: Double = 0
        for corner in 0..<8 {
            let p: SIMD3<Double> = SIMD3(corner & 1 == 0 ? boxLow.x : boxHigh.x, corner & 2 == 0 ? boxLow.y : boxHigh.y,
                                         corner & 4 == 0 ? boxLow.z : boxHigh.z)
            d = max(d, p.z + abs(p.x - lookAt.x) / lx, p.z + abs(p.y - lookAt.y) / ly)
        }
        return d
    }

    /// The fixed camera for `aspect`: from +z looking at (0, −0.1, 0), the distance fitted to the box. The snapshot is
    /// accepted for parity; the camera never moves while a level is played.
    public static func camera(_ snapshot: BackwardsAuroraSceneSnapshot, aspect: Double) -> BackwardsAuroraCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
        let d: Double = distance(aspect: a)
        let eye: SIMD3<Double> = lookAt + SIMD3(0, 0, d)
        let near: Double = max((d - boxHigh.z) * 0.5, 1e-3)
        let far: Double = d - groundZ + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(lookAt), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return BackwardsAuroraCamera(eye: eye, target: lookAt, fovY: fieldOfView, aspect: a, near: near, far: far,
                                     view: view, projection: projection, viewProjection: projection * view)
    }

    /// The camera for `snapshot`, `aspect` (width / height) and `orbit` (clamped, see
    /// ``BackwardsAuroraOrbit/clamped()``): the eye on ``BackwardsAuroraOrbit/eyeDirection`` from the look-at point
    /// (0, −0.1, 0), looking at it with +y up (never parallel: the pitch is at most 20°) and a 45° vertical field of
    /// view, at the smallest distance that holds every corner of the authored box (x −1 … 1, y −0.95 … 0.75, z −0.2 …
    /// 0.05) inside the view with ``fitMargin`` per side; the box is convex, so everything inside it (every sample
    /// point, ring and gauge bar) keeps a margin of at least 5 % at every orbit and aspect 0.4 … 2.5. Aspects are made
    /// usable as in ``camera(_:aspect:)``; at ``BackwardsAuroraOrbit/authored`` the result equals
    /// ``camera(_:aspect:)`` bit for bit. Presentation only; independent of the tier, the time and the play.
    public static func camera(_ snapshot: BackwardsAuroraSceneSnapshot, aspect: Double,
                              orbit: BackwardsAuroraOrbit) -> BackwardsAuroraCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
        let direction: SIMD3<Double> = orbit.eyeDirection
        let right: SIMD3<Double> = orbit.rightAxis
        let up: SIMD3<Double> = orbit.upAxis
        let d: Double = distance(aspect: a, direction: direction, right: right, up: up)
        let eye: SIMD3<Double> = lookAt + direction * d
        var nearest: Double = Double.infinity
        for index in 0..<8 {
            let r: SIMD3<Double> = corner(index) - lookAt
            nearest = min(nearest, d - dot(r, direction))
        }
        var farthest: Double = -Double.infinity
        let g: Double = groundHalfSize
        for index in 0..<4 {
            let p: SIMD3<Double> = SIMD3(index & 1 == 0 ? -g : g, index & 2 == 0 ? -g : g, groundZ)
            farthest = max(farthest, d - dot(p - lookAt, direction))
        }
        let near: Double = max(nearest * 0.5, 1e-3)
        let far: Double = farthest + 2
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(lookAt), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return BackwardsAuroraCamera(eye: eye, target: lookAt, fovY: fieldOfView, aspect: a, near: near, far: far,
                                     view: view, projection: projection, viewProjection: projection * view)
    }

    /// Corner `index` (0 … 7; bit 0 x, bit 1 y, bit 2 z, clear: low) of the authored box.
    static func corner(_ index: Int) -> SIMD3<Double> {
        SIMD3(index & 1 == 0 ? boxLow.x : boxHigh.x, index & 2 == 0 ? boxLow.y : boxHigh.y,
              index & 4 == 0 ? boxLow.z : boxHigh.z)
    }

    /// The dot product of `a` and `b`, summed x, y, z in that order.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    /// The eye distance along `direction` from the look-at point that holds the box with `fitMargin` per side at
    /// `aspect`, for the view axes `right` and `up`: for every corner with r its offset from the look-at point, the
    /// depth d − r·direction must reach |r·right| / lx and |r·up| / ly. Equals ``distance(aspect:)`` at the authored
    /// axes.
    static func distance(aspect: Double, direction: SIMD3<Double>, right: SIMD3<Double>,
                         up: SIMD3<Double>) -> Double {
        let half: Double = tan(fieldOfView / 2)
        let limit: Double = 1 - 2 * fitMargin
        let lx: Double = limit * usableAspect(aspect) * half
        let ly: Double = limit * half
        var d: Double = 0
        for index in 0..<8 {
            let r: SIMD3<Double> = corner(index) - lookAt
            let along: Double = dot(r, direction)
            d = max(d, along + abs(dot(r, right)) / lx, along + abs(dot(r, up)) / ly)
        }
        return d
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: BackwardsAuroraCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// Adds a strip through the wave's samples (lifted by `lift`, at `z`), each segment in `stepsPerSegment` steps;
    /// with `signed`, uv.y is negated inside the chosen section.
    static func addStrip(_ snapshot: BackwardsAuroraSceneSnapshot, lift: Double, z: Double, halfHeight: Double,
                         code: Double, signed: Bool, slot: SIMD3<Double>?, to parts: inout Parts) throws(MeshError) {
        let n: Int = snapshot.count
        guard n >= 2 else { return }
        let steps: Int = stepsPerSegment
        let low: Double = Double(snapshot.sectionStart)
        let high: Double = Double(snapshot.sectionEnd)
        for k in 0..<(n - 1) {
            let a: SIMD3<Double> = samplePoint(k, snapshot)
            let b: SIMD3<Double> = samplePoint(k + 1, snapshot)
            for j in 0..<steps {
                let f0: Double = Double(j) / Double(steps)
                let f1: Double = Double(j + 1) / Double(steps)
                let p0: SIMD3<Double> = j == 0 ? a : a + (b - a) * f0
                let p1: SIMD3<Double> = j + 1 == steps ? b : a + (b - a) * f1
                let q0: SIMD3<Double> = SIMD3(p0.x, p0.y + lift, z)
                let q1: SIMD3<Double> = SIMD3(p1.x, p1.y + lift, z)
                let pos0: Double = Double(k) + f0
                let pos1: Double = Double(k) + f1
                let s0: Double = signed && pos0 >= low && pos0 <= high ? -1 : 1
                let s1: Double = signed && pos1 >= low && pos1 <= high ? -1 : 1
                try parts.step(q0, q1, halfHeight: halfHeight, code: code, signA: s0, signB: s1, slot: slot)
            }
        }
    }

    /// The freeze preview point of position `k` (clamped): x(k), the preview sample's height, z = ``previewZ``; the
    /// look-at point when there is no preview.
    public static func previewPoint(_ k: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.preview.isEmpty else { return SIMD3(lookAt.x, lookAt.y, previewZ) }
        let i: Int = min(max(k, 0), snapshot.preview.count - 1)
        return SIMD3(x(Double(i), snapshot), y(snapshot.preview[i]), previewZ)
    }

    /// Adds the freeze preview ribbon: a strip ±``ribbonHalfHeight`` through the preview points, each segment in
    /// ``stepsPerSegment`` steps (the vertices at the preview points exact), material code 13, uv.y the unsigned
    /// timeline coordinate (the shader dashes along it).
    static func addPreview(_ snapshot: BackwardsAuroraSceneSnapshot, to parts: inout Parts) throws(MeshError) {
        let n: Int = snapshot.preview.count
        guard n >= 2 else { return }
        let steps: Int = stepsPerSegment
        for k in 0..<(n - 1) {
            let a: SIMD3<Double> = previewPoint(k, snapshot)
            let b: SIMD3<Double> = previewPoint(k + 1, snapshot)
            for j in 0..<steps {
                let f0: Double = Double(j) / Double(steps)
                let f1: Double = Double(j + 1) / Double(steps)
                let p0: SIMD3<Double> = j == 0 ? a : a + (b - a) * f0
                let p1: SIMD3<Double> = j + 1 == steps ? b : a + (b - a) * f1
                try parts.step(SIMD3(p0.x, p0.y, previewZ), SIMD3(p1.x, p1.y, previewZ), halfHeight: ribbonHalfHeight,
                               code: Material.preview, signA: 1, signB: 1, slot: nil)
            }
        }
    }

    /// Collects vertices with fallback colours and triangles facing their front.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []
        /// True: colours from the material code; false: the normal slot times uv.x (glow).
        let lit: Bool

        /// Parts with the given colouring.
        init(lit: Bool) { self.lit = lit }

        /// The fallback colour of a vertex.
        func colour(slot: SIMD3<Double>, code: Double) -> SIMD3<Double> {
            guard lit else { return slot * min(max(code, 0), 1) }
            let ground: SIMD3<Double> = BackwardsAuroraPalette.ground
            switch Int(code.rounded()) {
            case 1: return BackwardsAuroraPalette.band
            case 2: return ground + (BackwardsAuroraPalette.ribbon - ground) * 0.55
            case 12: return ground + (BackwardsAuroraPalette.ribbon - ground) * 0.3
            case 3: return BackwardsAuroraPalette.ghost
            case 4, 6: return BackwardsAuroraPalette.ring
            case 5: return BackwardsAuroraPalette.ribbon
            case 7: return BackwardsAuroraPalette.matched
            case 8: return BackwardsAuroraPalette.kink
            case 9: return BackwardsAuroraPalette.tear
            case 10: return BackwardsAuroraPalette.spent
            case 11: return BackwardsAuroraPalette.unspent
            case 13: return BackwardsAuroraPalette.ribbonHighlight
            default: return ground
            }
        }

        /// Adds (or welds) a vertex at `p` with normal slot `slot`, uv (`code`, `t`).
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double,
                             t: Double) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(BackwardsAuroraSceneGeometry.vec(p),
                                                normal: BackwardsAuroraSceneGeometry.vec(slot), uv: Vec2(code, t))
            if Int(id) == colours.count {
                let c: SIMD3<Double> = colour(slot: slot, code: code)
                colours.append(Vec4(min(max(c.x, 0), 1), min(max(c.y, 0), 1), min(max(c.z, 0), 1), 1))
            }
            return id
        }

        /// A convex polygon fanned from its first point, uv.y the clamped timeline coordinate.
        mutating func polygon(_ p: [SIMD3<Double>], normal: SIMD3<Double>, code: Double) throws(MeshError) {
            guard p.count >= 3 else { return }
            var ids: [UInt32] = []
            for point in p {
                ids.append(try vertex(point, slot: normal, code: code,
                                      t: BackwardsAuroraSceneGeometry.timeline(point.x)))
            }
            for k in 1..<(p.count - 1) {
                try facing(ids[0], ids[k], ids[k + 1], p[0], p[k], p[k + 1])
            }
        }

        /// One straight step of a strip from `a` to `b`, `halfHeight` above and below, with a centre row of vertices
        /// exactly on the path; uv.y the timeline coordinate times `signA` / `signB`.
        mutating func step(_ a: SIMD3<Double>, _ b: SIMD3<Double>, halfHeight: Double, code: Double, signA: Double,
                           signB: Double, slot: SIMD3<Double>?) throws(MeshError) {
            let s: SIMD3<Double> = slot ?? SIMD3(0, 0, 1)
            let ta: Double = signA * BackwardsAuroraSceneGeometry.timeline(a.x)
            let tb: Double = signB * BackwardsAuroraSceneGeometry.timeline(b.x)
            let h: SIMD3<Double> = SIMD3(0, halfHeight, 0)
            let pts: [SIMD3<Double>] = [a - h, a, a + h, b - h, b, b + h]
            var ids: [UInt32] = []
            for (i, p) in pts.enumerated() { ids.append(try vertex(p, slot: s, code: code, t: i < 3 ? ta : tb)) }
            for row in 0..<2 {
                try facing(ids[row], ids[3 + row], ids[4 + row], pts[row], pts[3 + row], pts[4 + row])
                try facing(ids[row], ids[4 + row], ids[row + 1], pts[row], pts[4 + row], pts[row + 1])
            }
        }

        /// A filled disc.
        mutating func disc(centre: SIMD3<Double>, radius: Double, segments: Int, code: Double) throws(MeshError) {
            var p: [SIMD3<Double>] = []
            for i in 0..<max(segments, 3) {
                let a: Double = 2 * Double.pi * Double(i) / Double(max(segments, 3))
                p.append(centre + SIMD3(cos(a) * radius, sin(a) * radius, 0))
            }
            try polygon(p, normal: SIMD3(0, 0, 1), code: code)
        }

        /// An annulus between `inner` and `outer`.
        mutating func ring(centre: SIMD3<Double>, inner: Double, outer: Double, segments: Int,
                           code: Double) throws(MeshError) {
            let n: Int = max(segments, 3)
            for i in 0..<n {
                let a0: Double = 2 * Double.pi * Double(i) / Double(n)
                let a1: Double = 2 * Double.pi * Double(i + 1) / Double(n)
                let d0: SIMD3<Double> = SIMD3(cos(a0), sin(a0), 0)
                let d1: SIMD3<Double> = SIMD3(cos(a1), sin(a1), 0)
                try polygon([centre + d0 * inner, centre + d0 * outer, centre + d1 * outer, centre + d1 * inner],
                            normal: SIMD3(0, 0, 1), code: code)
            }
        }

        /// Two diagonal bars `span` across and `width` wide.
        mutating func cross(centre: SIMD3<Double>, span: Double, width: Double, code: Double) throws(MeshError) {
            let r: Double = 0.5.squareRoot()
            let d1: SIMD3<Double> = SIMD3(r, r, 0)
            let d2: SIMD3<Double> = SIMD3(r, -r, 0)
            for (along, across) in [(d1, d2), (d2, d1)] {
                let a: SIMD3<Double> = along * (span / 2)
                let b: SIMD3<Double> = across * (width / 2)
                try polygon([centre - a - b, centre + a - b, centre + a + b, centre - a + b], normal: SIMD3(0, 0, 1),
                            code: code)
            }
        }

        /// Adds the triangle wound counter-clockwise seen from +z; degenerate triangles are skipped.
        mutating func facing(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>) throws(MeshError) {
            let z: Double = (pb.x - pa.x) * (pc.y - pa.y) - (pb.y - pa.y) * (pc.x - pa.x)
            if z > 0 {
                try builder.triangle(a, b, c)
            } else if z < 0 {
                try builder.triangle(a, c, b)
            }
        }

        /// The coloured mesh built so far.
        func built() -> BackwardsAuroraColouredMesh {
            BackwardsAuroraColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
