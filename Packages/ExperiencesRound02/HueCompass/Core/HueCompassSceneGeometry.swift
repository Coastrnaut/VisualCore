// HueCompassSceneGeometry — feature 333 (R02-G04-03) T-R02G0403-004 (FR-R02G0403-001, 002, 006; SC-R02G0403-001;
// clarifications Q1–Q3; research R1, R2, R4). The world of the compass, built from a snapshot only: the compass lies in
// the xy-plane with bearing b at angle 2πb/96 counter-clockwise from +x (the kernel's angle); the faceted glass needle
// from the centre to radius 0.8; 96 ticks at radius 0.95 … 1.0; the hue wheel of 24 unlit arc segments at radius
// 0.82 … 0.92, each with its grayscale glyph inside radius 0.895 … 0.92 only; 96 fog prisms at radius 1.1 … 1.25 whose
// height (0.04 + 0.03 × density) and brightness (density / 9, gray) follow the density alone, in the tier's stacked
// layers; the pearl probe marks, the ember selection mark and, only once the target is in the snapshot, the sapphire
// target ring at radius 1.32; the fixed authored camera down −z tilted 35° about x fitted to a bounding sphere of radius
// 1.45 about the centre with a 5 % margin for every aspect 0.4 … 2.5; and the CPU projection that the simulator frame
// checks compare with rendered pixels. Vertex contract with HueCompassShaders (ShaderMeshRenderer has only a_position,
// a_normal and a_uv): the glass meshes (needle, marks) keep real unit normals and take their colour from a uniform; the
// unlit meshes (ticks, bands, glyphs, fog) carry their RGB colour 0 … 1 in the NORMAL slot — the wheel with uv (0, 0)
// (u_fog = 0: uv.x = 0 keeps the normal-slot colour), the fog with uv (density / 9, bearing / 96) (u_fog = 1: uv.x scales
// alpha, uv.y is the drift phase; the shader may drift fog tops ±0.01 in z at time ≠ 0, inside the 1.45 sphere). Every
// mesh also comes with a per-vertex colour stream (`HueCompassColouredMesh`) for the shared unlit fallback renderer.
// Doubles are used for drawing only; nothing here is consulted by the rules.
// Feature 334 (R02-G04-04) T-R02G0404-002 (FR-R02G0404-004; SC-R02G0404-003; clarification Q3) adds the camera orbit
// (`HueCompassOrbit`: yaw ±40° about the z axis, tilt 15° … 60° from the z axis, authored yaw 0 and tilt 35°) and
// `camera(aspect:orbit:)`, which refits the same 1.45 bounding sphere so the 5 % margin holds at every orbit; the
// authored camera is the authored orbit. Presentation only: never in the digest, the snapshot or the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of the Hue Compass scene for one aspect.
///
/// Built only by ``HueCompassSceneGeometry/camera(aspect:)`` (the authored orbit) and
/// ``HueCompassSceneGeometry/camera(aspect:orbit:)``. World positions are in compass units (the wheel's outer
/// tick radius is 1); ``viewProjection`` maps them to GL clip space (right-handed, depth −1 … 1).
public struct HueCompassCamera: Sendable, Equatable {
    /// The eye position in world units.
    public let eye: SIMD3<Double>
    /// The point looked at: the compass centre (the origin).
    public let target: SIMD3<Double>
    /// The vertical field of view in radians.
    public let fovY: Double
    /// The aspect ratio (width / height) the camera was fitted for, after clamping to 0.1 … 10 (1 when unusable).
    public let aspect: Double
    /// The near clip distance.
    public let near: Double
    /// The far clip distance.
    public let far: Double
    /// The view-projection matrix: `Mat4.perspective` (GL depth range) times `Mat4.lookAt` with the orbit's
    /// ``HueCompassOrbit/up`` (+y at the authored orbit).
    public let viewProjection: Mat4
}

/// The orbit of the Hue Compass camera (feature 334, R02-G04-04, clarification Q3): a yaw of the eye about the world z
/// axis and a tilt of the eye direction from the z axis, both in radians. Presentation only: never in the digest, the
/// snapshot, the kernel or the save.
///
/// The eye direction is (sin tilt · sin yaw, −sin tilt · cos yaw, cos tilt), so ``authored`` (yaw 0, tilt 35°)
/// reproduces ``HueCompassSceneGeometry/eyeDirection`` exactly: the eye south of the compass (−y), looking at the
/// origin. Positive yaw turns the eye counter-clockwise about +z (seen from above).
public struct HueCompassOrbit: Sendable, Equatable {
    /// The yaw in radians about +z, from the −y side towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The tilt in radians: the angle of the eye direction from +z; allowed ``tiltRange`` (15° … 60°).
    public var tilt: Double

    /// An orbit of the given yaw and tilt in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, tilt: Double) {
        self.yaw = yaw
        self.tilt = tilt
    }

    /// The authored orbit: yaw 0, tilt 35° (``HueCompassSceneGeometry/tilt``).
    public static let authored = HueCompassOrbit(yaw: 0, tilt: HueCompassSceneGeometry.tilt)
    /// The largest yaw either way, 40° in radians.
    public static let yawLimit: Double = 40.0 * Double.pi / 180
    /// The allowed tilts, 15° … 60° in radians.
    public static let tiltRange: ClosedRange<Double> = (15.0 * Double.pi / 180)...(60.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −40° … 40° and tilt to 15° … 60°; a non-finite angle becomes the authored one.
    public func clamped() -> HueCompassOrbit {
        let y: Double = yaw.isFinite ? yaw : Self.authored.yaw
        let t: Double = tilt.isFinite ? tilt : Self.authored.tilt
        return HueCompassOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                               tilt: min(max(t, Self.tiltRange.lowerBound), Self.tiltRange.upperBound))
    }

    /// The unit direction from the compass centre to the eye at the clamped orbit:
    /// (sin t · sin y, −sin t · cos y, cos t) with y the yaw and t the tilt.
    public var eyeDirection: SIMD3<Double> {
        let o: HueCompassOrbit = clamped()
        return SIMD3(sin(o.tilt) * sin(o.yaw), -sin(o.tilt) * cos(o.yaw), cos(o.tilt))
    }

    /// The world up vector of the view at the clamped orbit: +y turned by the yaw about +z, (−sin y, cos y, 0). It is
    /// horizontal and never parallel to the eye direction (the tilt is at least 15°), so the far side of the compass
    /// always appears above its centre and the view never rolls; +y exactly at yaw 0.
    public var up: SIMD3<Double> {
        let o: HueCompassOrbit = clamped()
        return SIMD3(0 - sin(o.yaw), cos(o.yaw), 0)
    }
}

/// A mesh with one colour per vertex (linear RGBA 0 … 1, alpha 1), aligned with `mesh.positions`.
///
/// The colours feed the shared unlit mesh renderer (`MeshRenderer(mesh:colors:registry:)`) of the fallback path; the
/// shaders read the same information from the uv stream (see ``HueCompassSceneGeometry``).
public struct HueCompassColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh`, in vertex order.
    public let colours: [Vec4]
}

/// The geometry of the Hue Compass scene: bearing directions, needle, wheel (ticks, bands, glyphs), fog, marks, camera
/// and projection.
///
/// **Vertex streams** (the contract with ``HueCompassShaders``). Positions are world units with an identity model
/// matrix.
/// - needle (glass): unit flat normals; uv (distance along the needle / 0.8, facet k / facets); colour pearl (uniform).
/// - marks (glass): unit normals; uv (0, kind) with kind 0 pearl probe mark, 0.5 ember selection mark, 1 sapphire
///   target ring; colour from a uniform.
/// - wheel (unlit, `u_fog` 0): the **normal slot holds the RGB colour** — the band colour
///   ``HueCompassPalette/band(_:)`` for band segments, (gray, gray, gray) for ticks and glyphs; uv (0, 0).
/// - fog (unlit, `u_fog` 1): the **normal slot holds the RGB colour** (d/9, d/9, d/9); uv (density / 9, bearing / 96),
///   the brightness that scales alpha and the drift phase.
/// ``HueCompassColouredMesh/colours`` repeats each vertex's colour (pearl, ember or sapphire for the glass meshes).
///
/// Every element sits at the same place at every tier; tiers change only the needle's facets and the fog's layers.
public enum HueCompassSceneGeometry {
    // MARK: Constants

    /// The radius of the needle tip, 0.8.
    public static let needleLength = 0.8
    /// Where the needle's prism body ends and its pyramid tip begins, 0.68 along it.
    public static let needleShoulder = 0.68
    /// The radius of the needle's cross-section, 0.03.
    public static let needleWidth = 0.03
    /// The height of the needle's axis above the compass plane, 0.03 (the needle rests on the plane).
    public static let needleHeight = 0.03
    /// The inner radius of the ticks, 0.95.
    public static let tickInner = 0.95
    /// The outer radius of the ticks, 1.0.
    public static let tickOuter = 1.0
    /// The half-width of a tick, 0.004 world units.
    public static let tickHalfWidth = 0.004
    /// The gray of a tick, 0.85.
    public static let tickGray = 0.85
    /// The inner radius of the hue wheel, 0.82.
    public static let bandInner = 0.82
    /// The outer radius of the hue wheel, 0.92.
    public static let bandOuter = 0.92
    /// The arc steps of each band segment, 8.
    public static let bandArcSteps = 8
    /// The gap kept at each end of a band segment, in bearings (0.15).
    public static let bandInset = 0.15
    /// The radius of the band colour sample of the frame checks, 0.85 (clear of the glyphs).
    public static let bandSampleRadius = 0.85
    /// The inner radius of the glyph region, 0.895.
    public static let glyphInner = 0.895
    /// The outer radius of the glyph region, 0.92.
    public static let glyphOuter = 0.92
    /// The radius of each glyph mark's centre, 0.9075.
    public static let glyphRadius = 0.9075
    /// The half-size of a glyph mark, 0.0105 (so a mark spans radius 0.897 … 0.918).
    public static let glyphHalfSize = 0.0105
    /// The height of the glyphs above the band surface, 0.002.
    public static let glyphLift = 0.002
    /// The segments of a glyph dot or ring, 8.
    public static let glyphSegments = 8
    /// The inner radius of a ring glyph as a fraction of its outer radius, 0.55.
    public static let glyphRingInner = 0.55
    /// The half-width of a bar glyph as a fraction of its half-length, 0.35.
    public static let glyphBarWidth = 0.35
    /// The gray of a glyph on a light band, 0.06.
    public static let glyphDark = 0.06
    /// The gray of a glyph on a dark band, 0.95.
    public static let glyphLight = 0.95
    /// The inner radius of the fog prisms, 1.1.
    public static let fogInner = 1.1
    /// The outer radius of the fog prisms, 1.25.
    public static let fogOuter = 1.25
    /// The angular half-width of a fog prism, in bearings (0.4).
    public static let fogHalfWidth = 0.4
    /// The height of a fog prism at density 0, 0.04.
    public static let fogBaseHeight = 0.04
    /// The height a fog prism gains per density unit, 0.03.
    public static let fogHeightPerDensity = 0.03
    /// The radius of the marks, 1.32.
    public static let markRadius = 1.32
    /// The radius of a pearl probe mark (an octahedron), 0.035.
    public static let probeMarkSize = 0.035
    /// The radius of the ember selection mark (an octahedron), 0.05.
    public static let selectionMarkSize = 0.05
    /// The height of the selection mark's centre, 0.13 (above any probe mark at the same bearing).
    public static let selectionMarkHeight = 0.13
    /// The major radius of the sapphire target ring, 0.07.
    public static let targetRingRadius = 0.07
    /// The tube radius of the sapphire target ring, 0.012.
    public static let targetRingTube = 0.012
    /// The radius of the scene's bounding sphere about the origin, 1.45; every vertex of every mesh lies inside it.
    public static let boundingRadius = 1.45
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's tilt about x in radians (35°).
    public static let tilt = 35.0 * Double.pi / 180
    /// The unit direction from the compass centre to the eye: (0, −sin 35°, cos 35°), so the camera looks down −z,
    /// tilted 35° about x (from the south, +y up the screen).
    public static let eyeDirection = SIMD3<Double>(0, -sin(tilt), cos(tilt))
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places

    /// The unit direction of `bearing` in the compass plane: (cos, sin, 0) of 2π · bearing / 96.
    public static func direction(_ bearing: Int) -> SIMD3<Double> {
        angled(Double(bearing))
    }

    /// The unit direction of a fractional bearing `b`: (cos, sin, 0) of 2π · b / 96.
    static func angled(_ b: Double) -> SIMD3<Double> {
        let a: Double = 2 * Double.pi * b / Double(HueCompassWheel.bearings)
        return SIMD3(cos(a), sin(a), 0)
    }

    /// The needle tip: radius 0.8 at the snapshot's bearing, at ``needleHeight``.
    public static func needleTip(_ snapshot: HueCompassSceneSnapshot) -> SIMD3<Double> {
        direction(snapshot.bearing) * needleLength + SIMD3(0, 0, needleHeight)
    }

    /// The middle bearing of band segment `segment` (taken modulo 24), 4 · segment + 1.5: the segment covers bearings
    /// 4 · segment … 4 · segment + 3.
    public static func bandSegmentMiddle(_ segment: Int) -> Double {
        Double(HueCompassWheel.bearingsPerBand * mod(segment, HueCompassWheel.bands)) + 1.5
    }

    /// The frame checks' colour sample of band segment `segment`: radius 0.85 on the segment's middle angle, on the
    /// compass plane (clear of the glyphs, which lie beyond radius 0.895). The same for every snapshot and tier.
    public static func bandSamplePoint(_ segment: Int) -> SIMD3<Double> {
        angled(bandSegmentMiddle(segment)) * bandSampleRadius
    }

    /// The hue band drawn in segment `segment` of `snapshot`: the band of its first bearing under the level's offset,
    /// `snapshot.band(of: 4 · segment)`.
    public static func bandOfSegment(_ segment: Int, in snapshot: HueCompassSceneSnapshot) -> Int {
        snapshot.band(of: HueCompassWheel.bearingsPerBand * mod(segment, HueCompassWheel.bands))
    }

    /// The colour of band segment `segment` of `snapshot`: ``HueCompassPalette/band(_:)`` of ``bandOfSegment(_:in:)``.
    public static func bandSegmentColour(_ segment: Int, in snapshot: HueCompassSceneSnapshot) -> SIMD3<Double> {
        HueCompassPalette.band(bandOfSegment(segment, in: snapshot))
    }

    /// The gray of the glyph of `band`: ``glyphDark`` when the band colour's luminance (Rec. 709) is at least 0.5,
    /// ``glyphLight`` otherwise, so every glyph contrasts with its band.
    public static func glyphGray(_ band: Int) -> Double {
        let c: SIMD3<Double> = HueCompassPalette.band(band)
        let luminance: Double = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z
        return luminance >= 0.5 ? glyphDark : glyphLight
    }

    /// The centres of the glyph marks of segment `segment` of `snapshot`, one per mark of
    /// ``HueCompassGlyph/of(band:)`` of ``bandOfSegment(_:in:)``, at radius ``glyphRadius`` and height ``glyphLift``,
    /// spaced by a sixth of the segment's span and centred on its middle angle.
    public static func glyphCentres(_ segment: Int, in snapshot: HueCompassSceneSnapshot) -> [SIMD3<Double>] {
        let glyph: HueCompassGlyph = HueCompassGlyph.of(band: bandOfSegment(segment, in: snapshot))
        let slot: Double = (Double(HueCompassWheel.bearingsPerBand) - 2 * bandInset) / 6
        let middle: Double = bandSegmentMiddle(segment)
        var result: [SIMD3<Double>] = []
        for j in 0..<glyph.marks {
            let b: Double = middle + (Double(j) - Double(glyph.marks - 1) / 2) * slot
            result.append(angled(b) * glyphRadius + SIMD3(0, 0, glyphLift))
        }
        return result
    }

    /// The height of a fog prism of `density` (clamped to 0 … 9): 0.04 + 0.03 × density (0.04 … 0.31).
    public static func fogHeight(_ density: Int) -> Double {
        fogBaseHeight + fogHeightPerDensity * Double(min(max(density, 0), 9))
    }

    /// The brightness of a fog prism of `density` (clamped to 0 … 9): density / 9.
    public static func fogBrightness(_ density: Int) -> Double {
        Double(min(max(density, 0), 9)) / 9
    }

    /// The colour of a fog prism of `density`: gray at ``fogBrightness(_:)`` (luminance only).
    public static func fogColour(_ density: Int) -> SIMD3<Double> {
        SIMD3(repeating: fogBrightness(density))
    }

    /// The centre of the top of the fog prism at `bearing` of `snapshot`: radius 1.175 on the bearing, at the prism's
    /// height. The same at every tier.
    public static func fogTop(_ bearing: Int, in snapshot: HueCompassSceneSnapshot) -> SIMD3<Double> {
        let density: Int = snapshot.fog.indices.contains(mod(bearing, HueCompassWheel.bearings))
            ? snapshot.fog[mod(bearing, HueCompassWheel.bearings)] : 0
        return direction(bearing) * ((fogInner + fogOuter) / 2) + SIMD3(0, 0, fogHeight(density))
    }

    /// The bearings that carry a pearl probe mark: each clue's bearing once, in the order first seen.
    public static func probeBearings(_ snapshot: HueCompassSceneSnapshot) -> [Int] {
        var seen: Set<Int> = []
        var result: [Int] = []
        for clue in snapshot.clues {
            let b: Int = mod(clue.bearing, HueCompassWheel.bearings)
            if seen.insert(b).inserted { result.append(b) }
        }
        return result
    }

    /// The centre of the pearl probe mark at `bearing`: radius 1.32, height ``probeMarkSize``.
    public static func probeMarkCentre(_ bearing: Int) -> SIMD3<Double> {
        direction(bearing) * markRadius + SIMD3(0, 0, probeMarkSize)
    }

    /// The centre of the ember selection mark at `bearing`: radius 1.32, height ``selectionMarkHeight``.
    public static func selectionMarkCentre(_ bearing: Int) -> SIMD3<Double> {
        direction(bearing) * markRadius + SIMD3(0, 0, selectionMarkHeight)
    }

    /// The centre of the sapphire target ring at `bearing`: radius 1.32, height ``targetRingTube`` (resting on the
    /// plane, around the probe mark's place).
    public static func targetRingCentre(_ bearing: Int) -> SIMD3<Double> {
        direction(bearing) * markRadius + SIMD3(0, 0, targetRingTube)
    }

    // MARK: Meshes

    /// The needle: a glass prism along the snapshot's bearing whose cross-section is a regular polygon of
    /// `tier.facets` (at least 3) sides and radius ``needleWidth`` about an axis at ``needleHeight``, from the centre
    /// to ``needleShoulder``, closed by a pyramid to the tip at radius 0.8 and by a flat cap at the centre. Flat
    /// shaded: 4 × facets triangles, wound to face outwards. Colour pearl; uv (distance / 0.8, k / facets).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func needlePart(_ snapshot: HueCompassSceneSnapshot,
                                  tier: HueCompassTier) throws(MeshError) -> HueCompassColouredMesh {
        var parts: Parts = Parts()
        let facets: Int = max(tier.facets, 3)
        let d: SIMD3<Double> = direction(snapshot.bearing)
        let side: SIMD3<Double> = SIMD3(-d.y, d.x, 0)
        let up: SIMD3<Double> = SIMD3(0, 0, 1)
        let axis: SIMD3<Double> = up * needleHeight
        let tip: SIMD3<Double> = needleTip(snapshot)
        let pearl: Vec4 = colour(HueCompassPalette.pearl)
        func ring(_ k: Int) -> SIMD3<Double> {
            let phi: Double = 2 * Double.pi * Double(k) / Double(facets)
            return (up * cos(phi) + side * sin(phi)) * needleWidth
        }
        for k in 0..<facets {
            let v: Double = Double(k) / Double(facets)
            let o0: SIMD3<Double> = ring(k), o1: SIMD3<Double> = ring(k + 1)
            let out: SIMD3<Double> = unit(o0 + o1)
            let b0: SIMD3<Double> = axis + o0, b1: SIMD3<Double> = axis + o1
            let s0: SIMD3<Double> = axis + d * needleShoulder + o0, s1: SIMD3<Double> = axis + d * needleShoulder + o1
            // The body facet.
            try parts.quad([b0, b1, s1, s0], normal: out, uvs: [Vec2(0, v), Vec2(0, v),
                                                                 Vec2(needleShoulder / needleLength, v),
                                                                 Vec2(needleShoulder / needleLength, v)],
                           colour: pearl)
            // The tip facet.
            let tipNormal: SIMD3<Double> = orient(unit(cross(s1 - s0, tip - s0)), towards: out + d)
            try parts.triangle([s0, s1, tip], normal: tipNormal,
                               uvs: [Vec2(needleShoulder / needleLength, v), Vec2(needleShoulder / needleLength, v),
                                     Vec2(1, v)], colour: pearl)
            // The cap facet at the centre.
            try parts.triangle([axis, b0, b1], normal: -d, uvs: [Vec2(0, v), Vec2(0, v), Vec2(0, v)], colour: pearl)
        }
        return parts.built()
    }

    /// The needle mesh of ``needlePart(_:tier:)``.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func needleMesh(_ snapshot: HueCompassSceneSnapshot,
                                  tier: HueCompassTier) throws(MeshError) -> Mesh {
        try needlePart(snapshot, tier: tier).mesh
    }

    /// The wheel, the same at every tier, unlit, all faces up (+z) with the RGB colour in the normal slot and uv (0, 0):
    /// 96 flat ticks (radius 0.95 … 1.0, half-width 0.004, gray 0.85, 2 triangles each); 24 band segments on the
    /// compass plane (radius 0.82 … 0.92, segment k over bearings 4k − 0.5 + 0.15 … 4k + 3.5 − 0.15 in 8 arc steps, 16
    /// triangles each, colour ``bandSegmentColour(_:in:)``); and each segment's glyph (``HueCompassGlyph/of(band:)``:
    /// dot 8, bar 2, triangle 1 or ring 16 triangles per mark, at ``glyphCentres(_:in:)``, inside radius 0.895 … 0.92
    /// only, lifted 0.002, gray ``glyphGray(_:)``).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func wheelPart(_ snapshot: HueCompassSceneSnapshot,
                                 tier: HueCompassTier) throws(MeshError) -> HueCompassColouredMesh {
        var parts: Parts = Parts()
        let up: SIMD3<Double> = SIMD3(0, 0, 1)
        let uv: Vec2 = Vec2(0, 0)
        let uv3: [Vec2] = [uv, uv, uv]
        let uv4: [Vec2] = [uv, uv, uv, uv]
        // Ticks.
        let tickRGB: SIMD3<Double> = SIMD3(repeating: tickGray)
        for b in 0..<HueCompassWheel.bearings {
            let d: SIMD3<Double> = direction(b)
            let s: SIMD3<Double> = SIMD3(-d.y, d.x, 0) * tickHalfWidth
            try parts.quad([d * tickInner - s, d * tickOuter - s, d * tickOuter + s, d * tickInner + s], normal: up,
                           uvs: uv4, colour: colour(tickRGB), stored: tickRGB)
        }
        // Bands.
        for k in 0..<HueCompassWheel.bands {
            let rgb: SIMD3<Double> = bandSegmentColour(k, in: snapshot)
            let start: Double = Double(HueCompassWheel.bearingsPerBand * k) - 0.5 + bandInset
            let span: Double = Double(HueCompassWheel.bearingsPerBand) - 2 * bandInset
            for step in 0..<bandArcSteps {
                let a0: SIMD3<Double> = angled(start + span * Double(step) / Double(bandArcSteps))
                let a1: SIMD3<Double> = angled(start + span * Double(step + 1) / Double(bandArcSteps))
                try parts.quad([a0 * bandInner, a1 * bandInner, a1 * bandOuter, a0 * bandOuter], normal: up,
                               uvs: uv4, colour: colour(rgb), stored: rgb)
            }
        }
        // Glyphs.
        for k in 0..<HueCompassWheel.bands {
            let band: Int = bandOfSegment(k, in: snapshot)
            let glyph: HueCompassGlyph = HueCompassGlyph.of(band: band)
            let rgb: SIMD3<Double> = SIMD3(repeating: glyphGray(band))
            let c: Vec4 = colour(rgb)
            for centre in glyphCentres(k, in: snapshot) {
                let radial: SIMD3<Double> = unit(SIMD3(centre.x, centre.y, 0))
                let tangent: SIMD3<Double> = SIMD3(-radial.y, radial.x, 0)
                func at(_ u: Double, _ v: Double) -> SIMD3<Double> { centre + radial * u + tangent * v }
                let h: Double = glyphHalfSize
                switch glyph.shape {
                case 0:
                    for j in 0..<glyphSegments {
                        let p0: Double = 2 * Double.pi * Double(j) / Double(glyphSegments)
                        let p1: Double = 2 * Double.pi * Double(j + 1) / Double(glyphSegments)
                        try parts.triangle([centre, at(h * cos(p0), h * sin(p0)), at(h * cos(p1), h * sin(p1))],
                                           normal: up, uvs: uv3, colour: c, stored: rgb)
                    }
                case 1:
                    let w: Double = h * glyphBarWidth
                    try parts.quad([at(-h, -w), at(h, -w), at(h, w), at(-h, w)], normal: up, uvs: uv4, colour: c,
                                   stored: rgb)
                case 2:
                    try parts.triangle([at(h, 0), at(-h, -h), at(-h, h)], normal: up, uvs: uv3, colour: c,
                                       stored: rgb)
                default:
                    let r: Double = h * glyphRingInner
                    for j in 0..<glyphSegments {
                        let p0: Double = 2 * Double.pi * Double(j) / Double(glyphSegments)
                        let p1: Double = 2 * Double.pi * Double(j + 1) / Double(glyphSegments)
                        try parts.quad([at(r * cos(p0), r * sin(p0)), at(h * cos(p0), h * sin(p0)),
                                        at(h * cos(p1), h * sin(p1)), at(r * cos(p1), r * sin(p1))], normal: up,
                                       uvs: uv4, colour: c, stored: rgb)
                    }
                }
            }
        }
        return parts.built()
    }

    /// The wheel mesh of ``wheelPart(_:tier:)``.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func wheelMesh(_ snapshot: HueCompassSceneSnapshot,
                                 tier: HueCompassTier) throws(MeshError) -> Mesh {
        try wheelPart(snapshot, tier: tier).mesh
    }

    /// The fog, unlit: one prism per bearing b over bearings b ± 0.4 and radius 1.1 … 1.25, of height
    /// ``fogHeight(_:)`` of its density, cut into `tier.fogLayers` (at least 1) stacked slices of equal height with
    /// the same footprint; each slice is a closed box of 12 triangles wound to face outwards, so the mesh has
    /// 96 × 12 × layers triangles. The normal slot holds the colour ``fogColour(_:)`` (density only); uv
    /// (density / 9, b / 96): the brightness and the drift phase.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func fogPart(_ snapshot: HueCompassSceneSnapshot,
                               tier: HueCompassTier) throws(MeshError) -> HueCompassColouredMesh {
        var parts: Parts = Parts()
        let layers: Int = max(tier.fogLayers, 1)
        for b in 0..<HueCompassWheel.bearings {
            let density: Int = snapshot.fog.indices.contains(b) ? snapshot.fog[b] : 0
            let height: Double = fogHeight(density)
            let rgb: SIMD3<Double> = fogColour(density)
            let c: Vec4 = colour(rgb)
            let uv: Vec2 = Vec2(fogBrightness(density), Double(b) / Double(HueCompassWheel.bearings))
            let uvs: [Vec2] = [uv, uv, uv, uv]
            let d0: SIMD3<Double> = angled(Double(b) - fogHalfWidth)
            let d1: SIMD3<Double> = angled(Double(b) + fogHalfWidth)
            let footprint: [SIMD3<Double>] = [d0 * fogInner, d1 * fogInner, d1 * fogOuter, d0 * fogOuter]
            let centre: SIMD3<Double> = direction(b) * ((fogInner + fogOuter) / 2)
            for layer in 0..<layers {
                let z0: Double = height * Double(layer) / Double(layers)
                let z1: Double = height * Double(layer + 1) / Double(layers)
                let low: [SIMD3<Double>] = footprint.map { $0 + SIMD3(0, 0, z0) }
                let high: [SIMD3<Double>] = footprint.map { $0 + SIMD3(0, 0, z1) }
                try parts.quad([low[0], low[3], low[2], low[1]], normal: SIMD3(0, 0, -1), uvs: uvs, colour: c,
                               stored: rgb)
                try parts.quad(high, normal: SIMD3(0, 0, 1), uvs: uvs, colour: c, stored: rgb)
                for e in 0..<4 {
                    let n: Int = (e + 1) % 4
                    let mid: SIMD3<Double> = (footprint[e] + footprint[n]) * 0.5
                    let edge: SIMD3<Double> = footprint[n] - footprint[e]
                    let normal: SIMD3<Double> = orient(unit(cross(edge, SIMD3(0, 0, 1))), towards: mid - centre)
                    try parts.quad([low[e], low[n], high[n], high[e]], normal: normal, uvs: uvs, colour: c,
                                   stored: rgb)
                }
            }
        }
        return parts.built()
    }

    /// The fog mesh of ``fogPart(_:tier:)``.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func fogMesh(_ snapshot: HueCompassSceneSnapshot, tier: HueCompassTier) throws(MeshError) -> Mesh {
        try fogPart(snapshot, tier: tier).mesh
    }

    /// The marks, the same at every tier: a pearl octahedron of radius 0.035 at ``probeMarkCentre(_:)`` for each of
    /// ``probeBearings(_:)`` (8 triangles, uv (0, 0)); an ember octahedron of radius 0.05 at
    /// ``selectionMarkCentre(_:)`` for the selection, if any (8 triangles, uv (0, 0.5)); and, only when
    /// `snapshot.target` is not nil, a sapphire torus of radius 0.07 and tube 0.012 lying on the plane at
    /// ``targetRingCentre(_:)`` (16 × 6 segments, 192 triangles, uv (0, 1)). Wound to face outwards.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func markPart(_ snapshot: HueCompassSceneSnapshot) throws(MeshError) -> HueCompassColouredMesh {
        var parts: Parts = Parts()
        for b in probeBearings(snapshot) {
            try parts.octahedron(probeMarkCentre(b), radius: probeMarkSize, uv: Vec2(0, 0),
                                 colour: colour(HueCompassPalette.pearl))
        }
        if let selection = snapshot.selection {
            try parts.octahedron(selectionMarkCentre(mod(selection.bearing, HueCompassWheel.bearings)),
                                 radius: selectionMarkSize, uv: Vec2(0, 0.5), colour: colour(HueCompassPalette.ember))
        }
        if let target = snapshot.target {
            try parts.torus(targetRingCentre(mod(target, HueCompassWheel.bearings)), radius: targetRingRadius,
                            tube: targetRingTube, uv: Vec2(0, 1), colour: colour(HueCompassPalette.sapphire))
        }
        return parts.built()
    }

    /// The mark mesh of ``markPart(_:)``.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func markMesh(_ snapshot: HueCompassSceneSnapshot) throws(MeshError) -> Mesh {
        try markPart(snapshot).mesh
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

    /// The fixed authored camera for `aspect` (width / height): ``camera(aspect:orbit:)`` at
    /// ``HueCompassOrbit/authored``, so the eye lies on ``eyeDirection`` from the origin at the distance that fits the
    /// bounding sphere of radius 1.45, looking at the origin with +y up and a 45° vertical field of view. For aspects
    /// 0.4 … 2.5 every vertex of the needle, wheel, fog and marks projects inside the view with at least 5 % margin on
    /// every side. Independent of the snapshot and the quality tier.
    public static func camera(aspect: Double) -> HueCompassCamera {
        camera(aspect: aspect, orbit: .authored)
    }

    /// The camera for `aspect` (width / height) and `orbit` (clamped, see ``HueCompassOrbit/clamped()``): the eye on the
    /// orbit's ``HueCompassOrbit/eyeDirection`` from the origin at the distance that fits the bounding sphere of radius
    /// 1.45, looking at the origin with the orbit's ``HueCompassOrbit/up`` and a 45° vertical field of view. The fit is
    /// of the bounding sphere, which does not depend on the view direction, so for every orbit and every aspect
    /// 0.4 … 2.5 every vertex of the scene projects inside the view with at least 5 % margin on every side.
    /// Independent of the snapshot and the quality tier; presentation only.
    public static func camera(aspect: Double, orbit: HueCompassOrbit) -> HueCompassCamera {
        let a: Double = usableAspect(aspect)
        let d: Double = distance(radius: boundingRadius, aspect: a)
        let eye: SIMD3<Double> = orbit.eyeDirection * d
        let near: Double = max((d - boundingRadius) * 0.5, 1e-3)
        let far: Double = d + 2 * boundingRadius + 1
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: Vec3(0, 0, 0), up: vec(orbit.up))
        let projection: Mat4 = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return HueCompassCamera(eye: eye, target: .zero, fovY: fieldOfView, aspect: a, near: near, far: far,
                                viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (origin top left, y down; multiply by the viewport size for pixels, the
    /// convention of ``ScreenProjection``); nil behind the camera or for non-finite input. Points outside the view give
    /// coordinates outside 0 … 1.
    public static func project(_ point: SIMD3<Double>, camera: HueCompassCamera) -> SIMD2<Double>? {
        guard let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point else { return nil }
        return SIMD2(p.x, p.y)
    }

    /// `point` in pixels of a `width` × `height` viewport (origin top left, y down); nil for a non-positive size,
    /// behind the camera or for non-finite input.
    public static func pixel(_ point: SIMD3<Double>, camera: HueCompassCamera, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0, let v = project(point, camera: camera) else { return nil }
        return Vec2(v.x * Double(width), v.y * Double(height))
    }

    // MARK: Building

    /// A mesh builder with its colour stream: a colour is recorded for every new vertex (a welded vertex keeps its
    /// first colour; within each mesh the colour is a function of the uv, so welded vertices agree).
    struct Parts {
        var builder: MeshBuilder = MeshBuilder()
        var colours: [Vec4] = []

        /// Adds one vertex and returns its index.
        mutating func vertex(_ p: SIMD3<Double>, normal: SIMD3<Double>, uv: Vec2,
                             colour: Vec4) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(vec(p), normal: vec(normal), uv: uv)
            if Int(id) == colours.count { colours.append(colour) }
            return id
        }

        /// Adds a flat triangle wound so its geometric normal points along `normal`.
        /// `stored` replaces the normal written to the normal slot (the colour of an unlit mesh); nil stores `normal`.
        mutating func triangle(_ p: [SIMD3<Double>], normal: SIMD3<Double>, uvs: [Vec2], colour: Vec4,
                               stored: SIMD3<Double>? = nil) throws(MeshError) {
            let slot: SIMD3<Double> = stored ?? normal
            let a: UInt32 = try vertex(p[0], normal: slot, uv: uvs[0], colour: colour)
            let b: UInt32 = try vertex(p[1], normal: slot, uv: uvs[1], colour: colour)
            let c: UInt32 = try vertex(p[2], normal: slot, uv: uvs[2], colour: colour)
            try facing(a, b, c, p[0], p[1], p[2], front: normal)
        }

        /// Adds a flat quad p0 p1 p2 p3 (in order around it) as two triangles facing `normal`.
        /// `stored` replaces the normal written to the normal slot (the colour of an unlit mesh); nil stores `normal`.
        mutating func quad(_ p: [SIMD3<Double>], normal: SIMD3<Double>, uvs: [Vec2], colour: Vec4,
                           stored: SIMD3<Double>? = nil) throws(MeshError) {
            let slot: SIMD3<Double> = stored ?? normal
            var ids: [UInt32] = []
            for i in 0..<4 { ids.append(try vertex(p[i], normal: slot, uv: uvs[i], colour: colour)) }
            try facing(ids[0], ids[1], ids[2], p[0], p[1], p[2], front: normal)
            try facing(ids[0], ids[2], ids[3], p[0], p[2], p[3], front: normal)
        }

        /// Adds a flat-shaded octahedron of `radius` about `centre` (8 triangles facing outwards).
        mutating func octahedron(_ centre: SIMD3<Double>, radius: Double, uv: Vec2, colour: Vec4) throws(MeshError) {
            let axes: [SIMD3<Double>] = [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0), SIMD3(0, -1, 0)]
            for i in 0..<4 {
                for z in [1.0, -1.0] {
                    let a: SIMD3<Double> = centre + axes[i] * radius
                    let b: SIMD3<Double> = centre + axes[(i + 1) % 4] * radius
                    let c: SIMD3<Double> = centre + SIMD3(0, 0, z * radius)
                    let n: SIMD3<Double> = unit(axes[i] + axes[(i + 1) % 4] + SIMD3(0, 0, z))
                    try triangle([a, b, c], normal: n, uvs: [uv, uv, uv], colour: colour)
                }
            }
        }

        /// Adds a smooth torus about the vertical axis through `centre`: major `radius`, tube `tube`, 16 × 6
        /// segments (192 triangles facing outwards).
        mutating func torus(_ centre: SIMD3<Double>, radius: Double, tube: Double, uv: Vec2,
                            colour: Vec4) throws(MeshError) {
            let major: Int = 16, minor: Int = 6
            var ids: [UInt32] = []
            var points: [SIMD3<Double>] = []
            var normals: [SIMD3<Double>] = []
            for i in 0..<major {
                let u: Double = 2 * Double.pi * Double(i) / Double(major)
                let radial: SIMD3<Double> = SIMD3(cos(u), sin(u), 0)
                for j in 0..<minor {
                    let v: Double = 2 * Double.pi * Double(j) / Double(minor)
                    let n: SIMD3<Double> = radial * cos(v) + SIMD3(0, 0, sin(v))
                    let p: SIMD3<Double> = centre + radial * radius + n * tube
                    ids.append(try vertex(p, normal: n, uv: uv, colour: colour))
                    points.append(p)
                    normals.append(n)
                }
            }
            for i in 0..<major {
                for j in 0..<minor {
                    let a: Int = i * minor + j, b: Int = i * minor + (j + 1) % minor
                    let c: Int = ((i + 1) % major) * minor + j, d: Int = ((i + 1) % major) * minor + (j + 1) % minor
                    let out: SIMD3<Double> = normals[a] + normals[b] + normals[c] + normals[d]
                    try facing(ids[a], ids[c], ids[d], points[a], points[c], points[d], front: out)
                    try facing(ids[a], ids[d], ids[b], points[a], points[d], points[b], front: out)
                }
            }
        }

        /// Adds triangle a, b, c wound so its geometric normal points along `front`.
        mutating func facing(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            if HueCompassSceneGeometry.dot(HueCompassSceneGeometry.cross(pb - pa, pc - pa), front) < 0 {
                try builder.triangle(a, c, b)
            } else {
                try builder.triangle(a, b, c)
            }
        }

        /// The coloured mesh built so far.
        func built() -> HueCompassColouredMesh {
            HueCompassColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `c` as an opaque `Vec4`.
    static func colour(_ c: SIMD3<Double>) -> Vec4 { Vec4(c.x, c.y, c.z, 1) }

    /// `value` modulo `modulus`, 0 … modulus − 1.
    static func mod(_ value: Int, _ modulus: Int) -> Int {
        let r: Int = value % modulus
        return r < 0 ? r + modulus : r
    }

    /// `v` flipped, if needed, so it points along `towards`.
    static func orient(_ v: SIMD3<Double>, towards: SIMD3<Double>) -> SIMD3<Double> {
        dot(v, towards) < 0 ? -v : v
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
