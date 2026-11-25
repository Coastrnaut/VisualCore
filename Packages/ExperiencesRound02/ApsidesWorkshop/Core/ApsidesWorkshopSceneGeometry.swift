// ApsidesWorkshopSceneGeometry — feature 473 (R02-G18-03) T-R02G1803-004 (FR-R02G1803-001, 002, 003, 004, 006;
// SC-R02G1803-001; clarifications Q1–Q4). The cosmic compass of Apsides Workshop, built from a snapshot only. x points
// right, y up and z towards the viewer. One fixed scale for every level: a sky point (x, y) in sky units maps to world
// space by w(p, depth) = (x · s, y · s, depth) with s = 0.9 / 16 384, so the sky bound (64 lattice units) lies at
// radius 0.9 and the compass never rescales when the orbit is tuned. Nothing here is consulted by the rules.
//
// Draw order (clarification Q1; depth testing off, so the compass mesh is in painter's order): the elements
// (``ApsidesWorkshopElement``) by kind, then by index within the kind:
//   0. backdrop: one quad at depth −1 facing the eye, large enough to fill the view for aspects 0.25 … 4;
//   1. wedges: one triangle star → P(t) → P(t + 1) per tick t at depth −0.04, `targetWedge` for a tick whose sector
//      (the sector of P(t), as the shares count it) a sweep target names, else `wedge`;
//   2. compass: 8 spokes at multiples of 45° from radius 0.06 to 0.92, 0.006 wide; the rim ring at radius 0.92, 0.012
//      wide (96 segments); s + 1 radial notches across the rim at the middle of sector s (from radius 0.895 to 0.945,
//      0.004 wide, spaced 0.028 rad); a bracket arc at radius 0.96 (0.01 wide, two legs 0.025 inwards) over each sector
//      a sweep target names, and one at radius 0.985 (0.008 wide) over each sector an apsis target names;
//   3. ghost: the starting orbit's positions as a closed ribbon 0.008 wide at depth −0.08;
//   4. orbit: a closed ribbon 0.014 wide through ``refinement(_:tier:)`` (every kernel position in tick order, with
//      `tier.refinement` presentation-only points per tick on the analytic ellipse between ticks); on a contact failure
//      also the struck segment P(tick) → P(tick + 1), 0.024 wide, broken;
//   5. markers: the periapsis diamond 0.035 across at P(0), then the apoapsis square 0.03 across at P(T/2);
//   6. planets: sphere i of radius r · 256 · s at its centre with its hatched hazard ring from r · 256 · s to 0.01
//      outside (broken when a contact names it);
//   7. star: a sphere of radius 2 · 256 · s at the origin;
//   8. orbiter: a sphere of radius 0.03 at P(shown tick);
//   9. gauges: for target i a track at y = −1.08 − 0.07 i from x = −0.9 to 0.9, 0.012 tall (broken when an order, share
//      or apsis failure names target i), mapping 0 … 1000 (sweep share) or 0 … 1280 (apsis distance); its band as a
//      bracket (a line 0.005 wide at y − 0.02 from the band's low to its high and two legs up to y + 0.02); its reading
//      as a disc mark of radius 0.02 (met: filled; else hollow — the shader's; on a won level every mark is met);
//      then `budget` actions bars at y = −1.55 from x = −0.9 to 0.9, each 1.8 / budget wide with a fifth as gap and
//      0.04 tall, lit for the actions left.
// Spheres are `tier.longitudes` × `tier.latitudes` UV spheres, or flat 20-sided discs facing the eye at level-2. The
// glow mesh is drawn last, additively: `tier.glowShells` shells k (outermost first, factor 0.5^k), lifted 0.001 · k
// towards the eye, around the star (growth 0.04 per shell), along the orbit loop (half width 0.007 + 0.012 · k) and
// around the orbiter (growth 0.025 per shell); empty at level-2. A won level changes only the fallback colours of the
// gauge marks (the shader lights them from its won uniform); no position depends on the stage.
//
// Vertex streams (the contract of ``ApsidesWorkshopShaders``; a_uv.x the ``ApsidesWorkshopMaterial`` code): the
// backdrop a_uv.y the height 0 (bottom) … 1 (top) and a_normal.x the horizontal coordinate −1 … +1; wedges a_uv.y 0
// and a_normal zero; strips (spokes, rim, notches, brackets, ribbons, hazard rings, gauge tracks and bands, broken)
// a_uv.y the across coordinate −1 … +1 (a ring's inner edge −1), a_normal zero except on a hazard ring (a_normal.x the
// angle fraction 0 … 1, the seam repeated with 1); spheres a_normal the unit outward normal and a_uv.y 0, a level-2
// disc a_normal ``ApsidesWorkshopShaders/viewDirection`` and a_uv.y the radial coordinate 0 … 1; mark quads (the
// periapsis diamond, the apoapsis square, gauge marks) a_normal.xy the mark-local coordinate (±
// ``ApsidesWorkshopShaders/markQuadExtent`` at the corners, the mark spanning −1 … +1) and a_uv.y 0; bar fans a_uv.y 0
// at the centre and 1 on the outline. Glow mesh: a_normal the base colour, a_uv.x
// ``ApsidesWorkshopShaders/GlowKind/code(factor:)``, a_uv.y 0 on a shell's inner edge (a ribbon's centre line) and 1
// on its outer edge. Every flat triangle winds counter-clockwise seen from the eye, every sphere triangle seen from
// outside. Tiers change only the sphere detail, the orbit ribbon's refinement and the glow: every other position is
// the same at every tier. Doubles are used for drawing only. Modelled on `CelestialEclipseLabSceneGeometry` (463).
//
// Feature 474 (R02-G18-04) T-R02G1804-002 (FR-R02G1804-001 … 004, 006; SC-R02G1804-004; clarifications Q1, Q3, Q4)
// adds the player's view orbit (``ApsidesWorkshopViewOrbit``: yaw ±60° about the vertical axis through the authored
// box centre (0, −0.325, 0), positive moving the eye from the front (+z) towards +x; pitch −20° … +35° about the
// authored view's right axis, positive raising the eye; authored (0, 0)) and `camera(aspect:orbit:)`: the eye's offset
// from the look-at point is pitched (its elevation changed, its length and horizontal direction kept), then the eye
// and the look-at point are yawed together about that axis, and the field of view is refitted exactly as for the fixed
// camera, so the authored box x −1.0 … 1.0, y −1.65 … 1.0, z −0.15 … 0.15 keeps ``fitMargin`` per side at every orbit
// and aspect 0.4 … 2.5. The eye (3.6 from the look-at point, at least 3.6 · cos 35° · cos 60° ≈ 1.47 in front of the
// plane z = 0) stays outside the box. At the authored orbit `camera(aspect:)` (which calls it) is unchanged bit for
// bit. ``knobCentre(_:)`` is w(P(0)) and ``handleCentre(_:)`` w(P(T/2)) of the current orbit. While a pending orbit is
// previewed (`previewOrbit`), the ghost — the preview's kernel positions as a closed dashed ribbon
// ``ghostPreviewWidth`` wide in the plane z = 0 (material 22 ``ApsidesWorkshopMaterial/ghostPreview``, a_uv.y the
// across coordinate, a_normal.x the fraction k / T along the loop with the seam repeated with 1, a_normal.z
// ``ApsidesWorkshopShaders/ghostShapeLine``), then an outlined diamond (``periapsisSize``) at the preview's P(0) and an
// outlined square (``apoapsisSize``) at its P(T/2) (mark quads, a_normal.z the shape) — is drawn right after the apsis
// markers (after every element of kind marker, before the planets); it is not an element, so the paint order and the
// picking are unchanged. The gauge marks are drawn from the snapshot's `previewGauges` (the preview's readings and met
// flags), which equal `gauges` without a preview, so without a preview every mesh is R02-G18-03's. The camera-taking
// overloads `compassMesh(_:tier:camera:)`, `glowMesh(_:tier:camera:)`, `compassPart(_:tier:wonLevel:camera:)` and
// `glowPart(_:tier:camera:)` build the backdrop (a quad facing the eye behind the box), the level-2 discs and the glow
// bands facing the given camera's eye and lift the glow towards it; for the authored camera they equal the overloads
// without a camera, which use the authored camera. The orbit is presentation only: never saved, never read by rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The player's view of the compass: a yaw about the vertical axis through the authored box centre and a pitch about
/// the authored view's right axis, both in radians (feature 474, R02-G18-04). Presentation only: never saved, never
/// read by the rules, never part of the digest.
public struct ApsidesWorkshopViewOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians about the authored view's right axis: positive raises the eye (the compass seen more from
    /// above), negative lowers it; allowed ``pitchRange`` (−20° … +35°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G18-03.
    public static let authored = ApsidesWorkshopViewOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 60° in radians.
    public static let yawLimit: Double = 60.0 * Double.pi / 180
    /// The allowed pitches, −20° … +35° in radians.
    public static let pitchRange: ClosedRange<Double> = (-20.0 * Double.pi / 180)...(35.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −60° … 60° and pitch to −20° … 35°; a non-finite angle becomes 0.
    public func clamped() -> ApsidesWorkshopViewOrbit {
        let y: Double = yaw.isFinite ? yaw : 0
        let p: Double = pitch.isFinite ? pitch : 0
        return ApsidesWorkshopViewOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                        pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }

    /// Whether this orbit lies within the bounds (finite, yaw within ±``yawLimit``, pitch within ``pitchRange``).
    public var isWithinBounds: Bool {
        yaw.isFinite && pitch.isFinite && abs(yaw) <= Self.yawLimit && Self.pitchRange.contains(pitch)
    }
}

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct ApsidesWorkshopCamera: Sendable, Equatable {
    /// The eye position in world units, (0, −0.3, 3.6).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.3, 0).
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
public struct ApsidesWorkshopElement: Sendable, Equatable {
    /// The kind of an element, in the painter's order.
    public enum Kind: Int, Sendable, CaseIterable {
        /// The sky backdrop.
        case backdrop = 0
        /// A swept-area wedge.
        case wedge = 1
        /// The compass (spokes, rim, notches, brackets).
        case compass = 2
        /// The ghost loop.
        case ghost = 3
        /// The orbit loop (with a contact's broken segment).
        case orbit = 4
        /// An apsis marker.
        case marker = 5
        /// A planet with its hazard ring.
        case planet = 6
        /// The star.
        case star = 7
        /// The orbiter.
        case orbiter = 8
        /// A gauge row or an actions bar.
        case gauge = 9
    }

    /// What an element draws.
    public enum Part: Int, Sendable, CaseIterable {
        /// The backdrop.
        case backdrop = 0
        /// The wedge of tick `item`.
        case wedge = 1
        /// The compass.
        case compass = 2
        /// The ghost loop.
        case ghost = 3
        /// The orbit loop.
        case orbit = 4
        /// The periapsis diamond.
        case periapsis = 5
        /// The apoapsis square.
        case apoapsis = 6
        /// Planet `item`.
        case planet = 7
        /// The star.
        case star = 8
        /// The orbiter.
        case orbiter = 9
        /// Target `item`'s gauge (track, band bracket, reading mark).
        case track = 10
        /// Actions bar `item`.
        case bar = 11
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind.
    public let index: Int
    /// What the element draws.
    public let part: Part
    /// The index within its part: tick, planet, target or bar (0 for the single elements).
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
    public static func paintsBefore(_ a: ApsidesWorkshopElement, _ b: ApsidesWorkshopElement) -> Bool {
        if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
        return a.index < b.index
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct ApsidesWorkshopColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Apsides Workshop compass from an `ApsidesWorkshopSceneSnapshot`: places, meshes, camera and projection
/// (see the file header).
public enum ApsidesWorkshopSceneGeometry {
    // MARK: Constants (world units)

    /// World units per sky unit, s = 0.9 / 16 384.
    public static let scale: Double = 0.9 / 16_384
    /// The backdrop's plane.
    public static let backdropDepth: Double = -1
    /// The wedges' plane.
    public static let wedgeDepth: Double = -0.04
    /// The ghost loop's plane.
    public static let ghostDepth: Double = -0.08
    /// The plane of the compass, the orbit loop, the markers, the bodies' centres and the gauges.
    public static let planeZ: Double = 0
    /// A spoke's inner end.
    public static let spokeInner: Double = 0.06
    /// A spoke's outer end.
    public static let spokeOuter: Double = 0.92
    /// A spoke's width.
    public static let spokeWidth: Double = 0.006
    /// The rim's radius.
    public static let rimRadius: Double = 0.92
    /// The rim's width.
    public static let rimWidth: Double = 0.012
    /// The rim's segments.
    public static let rimSegments: Int = 96
    /// A notch's inner end.
    public static let notchInner: Double = 0.895
    /// A notch's outer end.
    public static let notchOuter: Double = 0.945
    /// A notch's width.
    public static let notchWidth: Double = 0.004
    /// The angle between neighbouring notches of a sector, in radians.
    public static let notchSpacing: Double = 0.028
    /// A sweep target's bracket arc radius.
    public static let bracketRadius: Double = 0.96
    /// A sweep target's bracket width.
    public static let bracketWidth: Double = 0.01
    /// A sweep target's bracket legs (inwards from the arc).
    public static let bracketLeg: Double = 0.025
    /// The angle a bracket stops short of its sector's boundaries, in radians.
    public static let bracketInset: Double = 0.06
    /// An apsis target's bracket arc radius.
    public static let apsisBracketRadius: Double = 0.985
    /// An apsis target's bracket width.
    public static let apsisBracketWidth: Double = 0.008
    /// The segments of a bracket arc.
    public static let arcSegments: Int = 12
    /// The ghost loop's width.
    public static let ghostWidth: Double = 0.008
    /// The orbit loop's width.
    public static let orbitWidth: Double = 0.014
    /// The ghost preview loop's width (feature 474).
    public static let ghostPreviewWidth: Double = 0.012
    /// A contact's broken segment width.
    public static let brokenSegmentWidth: Double = 0.024
    /// The periapsis diamond's size across (its half diagonal is the mark unit).
    public static let periapsisSize: Double = 0.035
    /// The apoapsis square's size across (its half side is the mark unit).
    public static let apoapsisSize: Double = 0.03
    /// A hazard ring's width outside the planet.
    public static let hazardWidth: Double = 0.01
    /// The segments of a hazard ring.
    public static let ringSegments: Int = 48
    /// The star's radius, 2 · 256 · s.
    public static let starRadius: Double = Double(ApsidesWorkshopSky.starRadius * ApsidesWorkshopSky.unit) * scale
    /// The orbiter's radius.
    public static let orbiterRadius: Double = 0.03
    /// The first gauge track's centre line.
    public static let gaugeTop: Double = -1.08
    /// The spacing of gauge rows (downwards).
    public static let gaugeSpacing: Double = 0.07
    /// The gauges' left end.
    public static let gaugeStart: Double = -0.9
    /// The gauges' right end.
    public static let gaugeEnd: Double = 0.9
    /// A gauge track's height.
    public static let trackHeight: Double = 0.012
    /// A band bracket's reach above and below its track's centre line.
    public static let bandReach: Double = 0.02
    /// A band bracket's line width.
    public static let bandLine: Double = 0.005
    /// A gauge mark's radius (the mark unit).
    public static let markRadius: Double = 0.02
    /// The actions bars' centre line.
    public static let barsY: Double = -1.55
    /// The share of a slot an actions bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// An actions bar's height.
    public static let barHeight: Double = 0.04
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// The star's glow growth per shell.
    public static let starGlowGrowth: Double = 0.04
    /// The orbit loop's glow growth (half width) per shell.
    public static let orbitGlowGrowth: Double = 0.012
    /// The orbiter's glow growth per shell.
    public static let orbiterGlowGrowth: Double = 0.025
    /// The sides of a glow band.
    public static let glowSides: Int = 24
    /// Lift towards the eye per glow shell.
    public static let glowLift: Double = 0.001
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, -0.3, 3.6)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.3, 0)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner (z covers the spheres of radius up to 8 lattice units).
    public static let boxLow: SIMD3<Double> = SIMD3(-1.0, -1.65, -0.15)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1.0, 1.0, 0.15)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The aspects the backdrop fills.
    public static let backdropAspects: ClosedRange<Double> = 0.25...4

    // MARK: Material codes

    /// The a_uv.x value of `material`.
    public static func code(_ material: ApsidesWorkshopMaterial) -> Double { Double(material.rawValue) }

    /// The fallback colour of material code `code` (unlit; the backdrop's bottom colour; broken for an unknown code).
    public static func colour(of code: Double) -> SIMD3<Double> {
        guard code.isFinite, code >= 0, code == code.rounded(),
              let material = ApsidesWorkshopMaterial(rawValue: Int(code)) else { return ApsidesWorkshopPalette.broken }
        return material.baseColour
    }

    // MARK: Places (the CPU reference)

    /// The world point of sky point `point` at `depth`: (x · s, y · s, depth).
    public static func world(_ point: ApsidesWorkshopPoint, depth: Double) -> SIMD3<Double> {
        SIMD3(Double(point.x) * scale, Double(point.y) * scale, depth)
    }

    /// `index` clamped to 0 … count − 1 (0 when count is 0).
    static func clamped(_ index: Int, _ count: Int) -> Int { min(max(index, 0), max(count - 1, 0)) }

    /// The star's centre, the origin.
    public static func starCentre() -> SIMD3<Double> { SIMD3(0, 0, planeZ) }

    /// The orbiter's centre: w(P(shown tick)).
    public static func orbiterCentre(_ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double> {
        world(snapshot.orbiter, depth: planeZ)
    }

    /// The knob's centre (the periapsis diamond, feature 474): w(P(0)) of the current orbit (the origin without
    /// positions).
    public static func knobCentre(_ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double> {
        guard let first = snapshot.positions.first else { return starCentre() }
        return world(first, depth: planeZ)
    }

    /// The size handle's centre (the apoapsis square, feature 474): w(P(T/2)) of the current orbit (the origin without
    /// positions).
    public static func handleCentre(_ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double> {
        let n: Int = snapshot.positions.count
        guard n > 0 else { return starCentre() }
        return world(snapshot.positions[(n / 2) % n], depth: planeZ)
    }

    /// The ghost preview's loop (feature 474): w of every previewed kernel position in tick order (z = 0); empty when
    /// no pending orbit is previewed.
    public static func ghostLoop(_ snapshot: ApsidesWorkshopSceneSnapshot) -> [SIMD3<Double>] {
        guard snapshot.previewOrbit != nil else { return [] }
        var loop: [SIMD3<Double>] = []
        for p in snapshot.previewPositions { loop.append(world(p, depth: planeZ)) }
        return loop
    }

    /// The centre of planet `index` (clamped; the origin without planets): w of its centre in sky units.
    public static func planetCentre(_ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.planets.isEmpty else { return SIMD3(0, 0, planeZ) }
        let planet: ApsidesWorkshopPlanet = snapshot.planets[clamped(index, snapshot.planets.count)]
        let unit: Int = ApsidesWorkshopSky.unit
        return world(ApsidesWorkshopPoint(x: planet.x * unit, y: planet.y * unit), depth: planeZ)
    }

    /// The drawn radius r · 256 · s of planet `index` (clamped; 0 without planets).
    public static func planetRadius(_ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot) -> Double {
        guard !snapshot.planets.isEmpty else { return 0 }
        let planet: ApsidesWorkshopPlanet = snapshot.planets[clamped(index, snapshot.planets.count)]
        return Double(planet.radius * ApsidesWorkshopSky.unit) * scale
    }

    /// The centre of target `index`'s gauge track: (0, −1.08 − 0.07 · index, 0).
    public static func gaugeCentre(_ index: Int) -> SIMD3<Double> {
        SIMD3((gaugeStart + gaugeEnd) / 2, gaugeTop - gaugeSpacing * Double(index), planeZ)
    }

    /// The x of `value` on a gauge whose scale is 0 … `top`: −0.9 + 1.8 · value / top (value clamped to 0 … top).
    public static func gaugeX(_ value: Int, top: Int) -> Double {
        let t: Double = Double(max(top, 1))
        return gaugeStart + (gaugeEnd - gaugeStart) * min(max(Double(value), 0), t) / t
    }

    /// The centre of target `index`'s reading mark (clamped; the first track's left end without targets), drawn from
    /// the snapshot's `previewGauges` (the preview's reading while a pending orbit is previewed, else `gauges`'s).
    public static func markCentre(_ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double> {
        let drawn: [ApsidesWorkshopGauge] = snapshot.previewGauges
        guard !drawn.isEmpty else { return SIMD3(gaugeStart, gaugeTop, planeZ) }
        let i: Int = clamped(index, drawn.count)
        let gauge: ApsidesWorkshopGauge = drawn[i]
        return SIMD3(gaugeX(gauge.reading, top: gauge.scaleTop), gaugeCentre(i).y, planeZ)
    }

    /// The width of one actions slot, 1.8 / budget.
    public static func actionsSlot(_ snapshot: ApsidesWorkshopSceneSnapshot) -> Double {
        (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of actions bar `index`: (−0.9 + (index + 0.5) · slot, −1.55, 0).
    public static func actionsBar(_ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * actionsSlot(snapshot), barsY, planeZ)
    }

    /// The actions bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litActions(_ snapshot: ApsidesWorkshopSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The sectors the sweep targets name, ascending and each once.
    public static func sweepSectors(_ snapshot: ApsidesWorkshopSceneSnapshot) -> [Int] {
        var sectors: Set<Int> = []
        for gauge in snapshot.gauges where gauge.target.kind == .sweep { sectors.insert(gauge.target.sector) }
        return sectors.sorted()
    }

    /// The sectors the apsis targets name, ascending and each once.
    public static func apsisSectors(_ snapshot: ApsidesWorkshopSceneSnapshot) -> [Int] {
        var sectors: Set<Int> = []
        for gauge in snapshot.gauges where gauge.target.kind != .sweep { sectors.insert(gauge.target.sector) }
        return sectors.sorted()
    }

    /// The planet and tick a contact failure names, nil otherwise.
    public static func contact(_ snapshot: ApsidesWorkshopSceneSnapshot) -> (planet: Int, tick: Int)? {
        if case .contact(let planet, let tick) = snapshot.failure { return (planet: planet, tick: tick) }
        return nil
    }

    /// The target whose gauge an order, share, apsis-sector or apsis-distance failure names, nil otherwise.
    public static func failingGauge(_ snapshot: ApsidesWorkshopSceneSnapshot) -> Int? {
        switch snapshot.failure {
        case .order(let target, _), .share(let target, _, _), .apsisSector(let target, _),
             .apsisDistance(let target, _):
            return target
        case .contact, nil:
            return nil
        }
    }

    /// The material of target `index`'s reading mark: met when the target is met (in the snapshot's `previewGauges`:
    /// the preview's flags while a pending orbit is previewed) or the level is won, else unmet.
    public static func markMaterial(_ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot,
                                    won: Bool) -> ApsidesWorkshopMaterial {
        guard index >= 0, index < snapshot.previewGauges.count else { return .markUnmet }
        return won || snapshot.previewGauges[index].met ? .markMet : .markUnmet
    }

    // MARK: The orbit loop

    /// The eccentric anomaly E solving M = E − e · sin E (Newton from M + e · sin M, at most 32 steps; presentation
    /// only, in `Double`).
    static func eccentricAnomaly(mean: Double, eccentricity e: Double) -> Double {
        var anomaly: Double = mean + e * sin(mean)
        for _ in 0..<32 {
            let f: Double = anomaly - e * sin(anomaly) - mean
            if abs(f) < 1e-14 { break }
            anomaly -= f / (1 - e * cos(anomaly))
        }
        return anomaly
    }

    /// The orbit ribbon's points in order (z = 0): for every tick t, w(P(t)) — exactly the kernel's position — followed
    /// by `tier.refinement` presentation-only points on the analytic ellipse of the snapshot's orbit (a = size · 256,
    /// e = k / 20, turned by 15d°), their eccentric anomalies evenly between those of ticks t and t + 1 (each solved
    /// from its mean anomaly 2π · t / T in `Double`; tick T is tick 0 one turn later). T · (refinement + 1) points.
    public static func refinement(_ snapshot: ApsidesWorkshopSceneSnapshot,
                                  tier: ApsidesWorkshopTier) -> [SIMD3<Double>] {
        let ticks: Int = snapshot.positions.count
        let r: Int = max(tier.refinement, 0)
        var points: [SIMD3<Double>] = []
        points.reserveCapacity(ticks * (r + 1))
        guard r > 0, ticks > 0 else {
            for p in snapshot.positions { points.append(world(p, depth: planeZ)) }
            return points
        }
        let orbit: ApsidesWorkshopOrbit = snapshot.orbit
        let a: Double = Double(orbit.size * ApsidesWorkshopSky.unit)
        let e: Double = Double(orbit.eccentricity) / 20
        let b: Double = a * (1 - e * e).squareRoot()
        let turn: Double = Double(orbit.direction) * Double.pi / 12
        let c: Double = cos(turn)
        let s: Double = sin(turn)
        var anomalies: [Double] = []
        for t in 0..<ticks {
            let mean: Double = 2 * Double.pi * Double(t) / Double(ticks)
            anomalies.append(eccentricAnomaly(mean: mean, eccentricity: e))
        }
        anomalies.append(anomalies[0] + 2 * Double.pi)
        for t in 0..<ticks {
            points.append(world(snapshot.positions[t], depth: planeZ))
            for j in 1...r {
                let anomaly: Double = anomalies[t] + (anomalies[t + 1] - anomalies[t]) * Double(j) / Double(r + 1)
                let x: Double = a * (cos(anomaly) - e)
                let y: Double = b * sin(anomaly)
                points.append(SIMD3((x * c - y * s) * scale, (x * s + y * c) * scale, planeZ))
            }
        }
        return points
    }

    // MARK: Elements

    /// Every element with its centre, in painter's order (by kind, then index; clarification Q1).
    public static func paintOrder(_ snapshot: ApsidesWorkshopSceneSnapshot) -> [ApsidesWorkshopElement] {
        var list: [ApsidesWorkshopElement] = []
        list.append(ApsidesWorkshopElement(kind: .backdrop, index: 0, part: .backdrop, item: 0,
                                           centre: SIMD3(lookAt.x, lookAt.y, backdropDepth)))
        let ticks: Int = snapshot.positions.count
        for t in 0..<ticks {
            let p: SIMD3<Double> = world(snapshot.positions[t], depth: wedgeDepth)
            let q: SIMD3<Double> = world(snapshot.positions[(t + 1) % ticks], depth: wedgeDepth)
            let centroid: SIMD3<Double> = (p + q + SIMD3(0, 0, wedgeDepth)) / 3
            list.append(ApsidesWorkshopElement(kind: .wedge, index: t, part: .wedge, item: t, centre: centroid))
        }
        list.append(ApsidesWorkshopElement(kind: .compass, index: 0, part: .compass, item: 0, centre: starCentre()))
        list.append(ApsidesWorkshopElement(kind: .ghost, index: 0, part: .ghost, item: 0,
                                           centre: mean(snapshot.ghost, depth: ghostDepth)))
        list.append(ApsidesWorkshopElement(kind: .orbit, index: 0, part: .orbit, item: 0,
                                           centre: mean(snapshot.positions, depth: planeZ)))
        if ticks > 0 {
            list.append(ApsidesWorkshopElement(kind: .marker, index: 0, part: .periapsis, item: 0,
                                               centre: world(snapshot.positions[0], depth: planeZ)))
            list.append(ApsidesWorkshopElement(kind: .marker, index: 1, part: .apoapsis, item: 0,
                                               centre: world(snapshot.positions[(ticks / 2) % ticks], depth: planeZ)))
        }
        for i in snapshot.planets.indices {
            list.append(ApsidesWorkshopElement(kind: .planet, index: i, part: .planet, item: i,
                                               centre: planetCentre(i, snapshot)))
        }
        list.append(ApsidesWorkshopElement(kind: .star, index: 0, part: .star, item: 0, centre: starCentre()))
        list.append(ApsidesWorkshopElement(kind: .orbiter, index: 0, part: .orbiter, item: 0,
                                           centre: orbiterCentre(snapshot)))
        let targets: Int = snapshot.gauges.count
        for i in 0..<targets {
            list.append(ApsidesWorkshopElement(kind: .gauge, index: i, part: .track, item: i, centre: gaugeCentre(i)))
        }
        for b in 0..<max(snapshot.budget, 0) {
            list.append(ApsidesWorkshopElement(kind: .gauge, index: targets + b, part: .bar, item: b,
                                               centre: actionsBar(b, snapshot)))
        }
        list.sort(by: ApsidesWorkshopElement.paintsBefore)
        return list
    }

    /// The CPU reference points (clarification Q3) in painter's order: every planet's centre, the star's centre, the
    /// orbiter's centre, the first gauge track's centre and the first actions bar's centre.
    public static func referencePoints(_ snapshot: ApsidesWorkshopSceneSnapshot) -> [ApsidesWorkshopElement] {
        var points: [ApsidesWorkshopElement] = []
        for element in paintOrder(snapshot) {
            switch element.part {
            case .planet, .star, .orbiter: points.append(element)
            case .track where element.item == 0: points.append(element)
            case .bar where element.item == 0: points.append(element)
            default: break
            }
        }
        return points
    }

    /// The mean of w of `points` at `depth` (the origin when empty).
    static func mean(_ points: [ApsidesWorkshopPoint], depth: Double) -> SIMD3<Double> {
        guard !points.isEmpty else { return SIMD3(0, 0, depth) }
        var sum: SIMD3<Double> = SIMD3(0, 0, 0)
        for p in points { sum += world(p, depth: depth) }
        return SIMD3(sum.x / Double(points.count), sum.y / Double(points.count), depth)
    }

    // MARK: Meshes

    /// The compass mesh for the compass program, in painter's order (see the header), seen from the authored camera.
    public static func compassMesh(_ snapshot: ApsidesWorkshopSceneSnapshot,
                                   tier: ApsidesWorkshopTier) throws(MeshError) -> Mesh {
        try compassPart(snapshot, tier: tier).mesh
    }

    /// The compass mesh seen from `camera` (feature 474): the backdrop and the level-2 discs facing its eye
    /// (``compassPart(_:tier:wonLevel:camera:)`` without colours).
    public static func compassMesh(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                                   camera: ApsidesWorkshopCamera) throws(MeshError) -> Mesh {
        try compassPart(snapshot, tier: tier, camera: camera).mesh
    }

    /// The glow mesh for the glow program (`glowPart` without colours), seen from the authored camera; empty at
    /// level-2.
    public static func glowMesh(_ snapshot: ApsidesWorkshopSceneSnapshot,
                                tier: ApsidesWorkshopTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    /// The glow mesh seen from `camera` (feature 474): bands facing its eye and lifted towards it
    /// (``glowPart(_:tier:camera:)`` without colours); empty at level-2.
    public static func glowMesh(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                                camera: ApsidesWorkshopCamera) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier, camera: camera).mesh
    }

    /// The whole compass with fallback colours (each material's palette colour, unlit; the backdrop from midnight at
    /// its bottom to midnight top at its top; on a won level every gauge mark in the met colour) for the shared unlit
    /// renderer: the same positions as ``compassMesh(_:tier:)``. `wonLevel` overrides `snapshot.isWon`; positions never
    /// depend on it. Seen from the authored camera.
    public static func compassPart(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                                   wonLevel: Bool? = nil) throws(MeshError) -> ApsidesWorkshopColouredMesh {
        try compass(snapshot, tier: tier, wonLevel: wonLevel, parts: Parts())
    }

    /// The whole compass with fallback colours seen from `camera` (feature 474): the backdrop (a quad facing the eye
    /// behind the authored box, large enough to fill the view at aspects 0.25 … 4 from that eye) and the level-2 discs
    /// face its eye; every other position is as ``compassPart(_:tier:wonLevel:)``, which it equals for the authored
    /// camera.
    public static func compassPart(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                                   wonLevel: Bool? = nil,
                                   camera: ApsidesWorkshopCamera) throws(MeshError) -> ApsidesWorkshopColouredMesh {
        try compass(snapshot, tier: tier, wonLevel: wonLevel, parts: Parts(camera: camera))
    }

    /// Builds the compass into `parts` (empty, with the view to face): every element in painter's order, the ghost
    /// preview right after the last element of kind marker (see the header).
    static func compass(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier, wonLevel: Bool?,
                        parts start: Parts) throws(MeshError) -> ApsidesWorkshopColouredMesh {
        var parts: Parts = start
        let won: Bool = wonLevel ?? snapshot.isWon
        let ribbon: [SIMD3<Double>] = refinement(snapshot, tier: tier)
        var ghostDrawn: Bool = false
        for element in paintOrder(snapshot) {
            if !ghostDrawn && element.kind.rawValue > ApsidesWorkshopElement.Kind.marker.rawValue {
                try ghostPreview(&parts, snapshot)
                ghostDrawn = true
            }
            try draw(element, into: &parts, snapshot, tier: tier, won: won, ribbon: ribbon)
        }
        if !ghostDrawn { try ghostPreview(&parts, snapshot) }
        return parts.built()
    }

    /// Draws the ghost preview while a pending orbit is previewed (nothing otherwise): the dashed loop through
    /// ``ghostLoop(_:)``, then the outlined diamond at its P(0) and the outlined square at its P(T/2) (see the header).
    static func ghostPreview(_ parts: inout Parts, _ snapshot: ApsidesWorkshopSceneSnapshot) throws(MeshError) {
        let loop: [SIMD3<Double>] = ghostLoop(snapshot)
        let n: Int = loop.count
        guard n > 0 else { return }
        let ghost: Double = code(.ghostPreview)
        try parts.dashedLoop(loop, width: ghostPreviewWidth, code: ghost)
        try parts.mark(centre: loop[0], unit: periapsisSize / 2, code: ghost,
                       shape: ApsidesWorkshopShaders.ghostShapeDiamond)
        try parts.mark(centre: loop[(n / 2) % n], unit: apoapsisSize / 2, code: ghost,
                       shape: ApsidesWorkshopShaders.ghostShapeSquare)
    }

    /// The backdrop's half width and half height: large enough to fill the view at its plane for every aspect in
    /// ``backdropAspects``.
    public static func backdropHalf() -> SIMD2<Double> {
        let distance: Double = eye.z - backdropDepth
        let tall: ApsidesWorkshopCamera = camera(aspect: backdropAspects.lowerBound)
        let wide: ApsidesWorkshopCamera = camera(aspect: backdropAspects.upperBound)
        let halfHeight: Double = distance * tan(tall.fovY / 2) * 1.05
        let halfWidth: Double = distance * tan(wide.fovY / 2) * wide.aspect * 1.05
        return SIMD2(halfWidth, halfHeight)
    }

    /// The backdrop height h (0 at its bottom, 1 at its top; a_uv.y) seen at view point `view` (0 … 1, y down) through
    /// `camera`: the gradient's coordinate at that pixel (the camera looks straight down the z axis).
    public static func backdropHeight(view: SIMD2<Double>, camera: ApsidesWorkshopCamera) -> Double {
        let distance: Double = camera.eye.z - backdropDepth
        let y: Double = camera.target.y + (1 - 2 * view.y) * distance * tan(camera.fovY / 2)
        let half: Double = backdropHalf().y
        return min(max((y - (lookAt.y - half)) / (2 * half), 0), 1)
    }

    /// Draws one element into `parts` (see the header).
    static func draw(_ element: ApsidesWorkshopElement, into parts: inout Parts,
                     _ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier, won: Bool,
                     ribbon: [SIMD3<Double>]) throws(MeshError) {
        typealias P = ApsidesWorkshopPalette
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        switch element.part {
        case .backdrop:
            if let view = parts.view {
                try facingBackdrop(&parts, view.camera)
                return
            }
            let half: SIMD2<Double> = backdropHalf()
            let corners: [SIMD3<Double>] = [c + SIMD3(-half.x, -half.y, 0), c + SIMD3(half.x, -half.y, 0),
                                            c + SIMD3(half.x, half.y, 0), c + SIMD3(-half.x, half.y, 0)]
            try parts.quad(corners, code: code(.backdrop), local: [0, 0, 1, 1],
                           colours: [P.midnight, P.midnight, P.midnightTop, P.midnightTop],
                           slots: [SIMD3(-1, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 0, 0), SIMD3(-1, 0, 0)])
        case .wedge:
            let ticks: Int = snapshot.positions.count
            let p: ApsidesWorkshopPoint = snapshot.positions[i]
            let named: Bool = sweepSectors(snapshot).contains(ApsidesWorkshopSky.sector(of: p))
            let material: ApsidesWorkshopMaterial = named ? .targetWedge : .wedge
            try parts.flatTriangle(SIMD3(0, 0, wedgeDepth), world(p, depth: wedgeDepth),
                                   world(snapshot.positions[(i + 1) % ticks], depth: wedgeDepth),
                                   code: code(material))
        case .compass:
            try compass(&parts, snapshot)
        case .ghost:
            var loop: [SIMD3<Double>] = []
            for p in snapshot.ghost { loop.append(world(p, depth: ghostDepth)) }
            try parts.loop(loop, width: ghostWidth, code: code(.ghost))
        case .orbit:
            try parts.loop(ribbon, width: orbitWidth, code: code(.orbit))
            if let hit = contact(snapshot), !snapshot.positions.isEmpty {
                let n: Int = snapshot.positions.count
                let t: Int = clamped(hit.tick, n)
                try parts.strip(world(snapshot.positions[t], depth: planeZ),
                                world(snapshot.positions[(t + 1) % n], depth: planeZ), width: brokenSegmentWidth,
                                code: code(.broken))
            }
        case .periapsis:
            try parts.mark(centre: c, unit: periapsisSize / 2, code: code(.periapsis))
        case .apoapsis:
            try parts.mark(centre: c, unit: apoapsisSize / 2, code: code(.apoapsis))
        case .planet:
            let r: Double = planetRadius(i, snapshot)
            try body(&parts, centre: c, radius: r, material: .planet, tier: tier)
            let broken: Bool = contact(snapshot)?.planet == i
            try parts.circle(centre: c, inner: r, outer: r + hazardWidth, segments: ringSegments,
                             code: code(broken ? .broken : .hazard), angles: true)
        case .star:
            try body(&parts, centre: c, radius: starRadius, material: .star, tier: tier)
        case .orbiter:
            try body(&parts, centre: c, radius: orbiterRadius, material: .orbiter, tier: tier)
        case .track:
            try gauge(&parts, i, snapshot, won: won)
        case .bar:
            let half: SIMD2<Double> = SIMD2(barFill * actionsSlot(snapshot) / 2, barHeight / 2)
            let material: ApsidesWorkshopMaterial = i < litActions(snapshot) ? .barLit : .barUnlit
            try parts.rectangle(centre: c, half: half, code: code(material))
        }
    }

    /// Draws the backdrop facing `camera`'s eye (feature 474): one quad behind the authored box, at the depth of its
    /// farthest corner along the view plus 1, with the half height and half width that fill the view from that eye at
    /// aspects 0.25 and 4 (``fitted(eye:target:aspect:)``), grown by 5 %; a_uv.y the height 0 … 1 and a_normal.x the
    /// horizontal coordinate −1 … +1 as the authored backdrop.
    static func facingBackdrop(_ parts: inout Parts, _ camera: ApsidesWorkshopCamera) throws(MeshError) {
        typealias P = ApsidesWorkshopPalette
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis(camera)
        var depth: Double = 0
        for index in 0..<8 { depth = max(depth, dot(corner(index) - camera.eye, basis.forward)) }
        depth += 1
        let tall: ApsidesWorkshopCamera = fitted(eye: camera.eye, target: camera.target,
                                                 aspect: backdropAspects.lowerBound)
        let wide: ApsidesWorkshopCamera = fitted(eye: camera.eye, target: camera.target,
                                                 aspect: backdropAspects.upperBound)
        let halfHeight: Double = depth * tan(tall.fovY / 2) * 1.05
        let halfWidth: Double = depth * tan(wide.fovY / 2) * wide.aspect * 1.05
        let centre: SIMD3<Double> = camera.eye + basis.forward * depth
        let w: SIMD3<Double> = basis.right * halfWidth
        let h: SIMD3<Double> = basis.up * halfHeight
        try parts.quad([centre - w - h, centre + w - h, centre + w + h, centre - w + h], code: code(.backdrop),
                       local: [0, 0, 1, 1], colours: [P.midnight, P.midnight, P.midnightTop, P.midnightTop],
                       slots: [SIMD3(-1, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 0, 0), SIMD3(-1, 0, 0)])
    }

    /// Draws the compass: spokes, rim, notches and the target brackets.
    static func compass(_ parts: inout Parts, _ snapshot: ApsidesWorkshopSceneSnapshot) throws(MeshError) {
        let sectors: Int = ApsidesWorkshopSky.sectorCount
        let sectorAngle: Double = 2 * Double.pi / Double(sectors)
        for j in 0..<sectors {
            let d: SIMD3<Double> = direction(sectorAngle * Double(j))
            try parts.strip(d * spokeInner, d * spokeOuter, width: spokeWidth, code: code(.spoke))
        }
        try parts.circle(centre: starCentre(), inner: rimRadius - rimWidth / 2, outer: rimRadius + rimWidth / 2,
                         segments: rimSegments, code: code(.rim))
        for s in 0..<sectors {
            let notches: Int = s + 1
            let middle: Double = sectorAngle * (Double(s) + 0.5)
            for k in 0..<notches {
                let d: SIMD3<Double> = direction(middle + (Double(k) - Double(notches - 1) / 2) * notchSpacing)
                try parts.strip(d * notchInner, d * notchOuter, width: notchWidth, code: code(.notch))
            }
        }
        for s in sweepSectors(snapshot) {
            let from: Double = sectorAngle * Double(s) + bracketInset
            let to: Double = sectorAngle * Double(s + 1) - bracketInset
            try parts.arc(radius: bracketRadius, width: bracketWidth, from: from, to: to, segments: arcSegments,
                          code: code(.bracket))
            for angle in [from, to] {
                let d: SIMD3<Double> = direction(angle)
                try parts.strip(d * (bracketRadius + bracketWidth / 2), d * (bracketRadius - bracketLeg),
                                width: bracketWidth * 0.6, code: code(.bracket))
            }
        }
        for s in apsisSectors(snapshot) {
            try parts.arc(radius: apsisBracketRadius, width: apsisBracketWidth,
                          from: sectorAngle * Double(s) + bracketInset, to: sectorAngle * Double(s + 1) - bracketInset,
                          segments: arcSegments, code: code(.bracket))
        }
    }

    /// Draws target `index`'s gauge: its track (broken when a failure names the target), its band bracket and its
    /// reading mark; the band and the mark from the snapshot's `previewGauges` (the preview's reading while a pending
    /// orbit is previewed; the same targets as `gauges`).
    static func gauge(_ parts: inout Parts, _ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot,
                      won: Bool) throws(MeshError) {
        let gauge: ApsidesWorkshopGauge = snapshot.previewGauges[index]
        let y: Double = gaugeCentre(index).y
        let broken: Bool = failingGauge(snapshot) == index
        try parts.strip(SIMD3(gaugeStart, y, planeZ), SIMD3(gaugeEnd, y, planeZ), width: trackHeight,
                        code: code(broken ? .broken : .gaugeTrack))
        let left: Double = gaugeX(gauge.target.low, top: gauge.scaleTop)
        let right: Double = gaugeX(gauge.target.high, top: gauge.scaleTop)
        let low: Double = y - bandReach
        try parts.strip(SIMD3(left, low, planeZ), SIMD3(right, low, planeZ), width: bandLine, code: code(.gaugeBand))
        try parts.strip(SIMD3(left, low, planeZ), SIMD3(left, y + bandReach, planeZ), width: bandLine,
                        code: code(.gaugeBand))
        if right != left {
            try parts.strip(SIMD3(right, low, planeZ), SIMD3(right, y + bandReach, planeZ), width: bandLine,
                            code: code(.gaugeBand))
        }
        try parts.mark(centre: markCentre(index, snapshot), unit: markRadius,
                       code: code(markMaterial(index, snapshot, won: won)))
    }

    /// Draws a body: a UV sphere of the tier's detail, or a flat disc facing the eye at level-2 (the parts' eye).
    static func body(_ parts: inout Parts, centre: SIMD3<Double>, radius: Double, material: ApsidesWorkshopMaterial,
                     tier: ApsidesWorkshopTier) throws(MeshError) {
        if tier.flatSpheres {
            try parts.disc(centre: centre, radius: radius, sides: ApsidesWorkshopTier.discSides, code: code(material))
        } else {
            try parts.sphere(centre: centre, radius: radius, longitudes: tier.longitudes, latitudes: tier.latitudes,
                             code: code(material))
        }
    }

    /// The glow with fallback colours (the base colour times the factor) for the shared unlit renderer:
    /// `tier.glowShells` shells k (outermost first, factor 0.5^k), lifted 0.001 · k towards the eye: a band of
    /// ``glowSides`` sides around the star (from its radius, growth ``starGlowGrowth``, base
    /// ``ApsidesWorkshopPalette/star``, kind star), a ribbon along the orbit loop (from its centre line, a_uv.y 0, to
    /// half width orbitWidth / 2 + ``orbitGlowGrowth`` · k, a_uv.y 1, base ``ApsidesWorkshopPalette/glow``, kind orbit)
    /// and a band around the orbiter (from its radius, growth ``orbiterGlowGrowth``, base
    /// ``ApsidesWorkshopPalette/glacial``, kind orbiter). a_normal is the base colour and a_uv.x
    /// ``ApsidesWorkshopShaders/GlowKind/code(factor:)``. Empty at level-2. Seen from the authored camera.
    public static func glowPart(_ snapshot: ApsidesWorkshopSceneSnapshot,
                                tier: ApsidesWorkshopTier) throws(MeshError) -> ApsidesWorkshopColouredMesh {
        try glow(snapshot, tier: tier, parts: Parts())
    }

    /// The glow with fallback colours seen from `camera` (feature 474): the star and orbiter bands facing its eye and
    /// every shell lifted 0.001 · k towards it; otherwise as ``glowPart(_:tier:)``, which it equals for the authored
    /// camera.
    public static func glowPart(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                                camera: ApsidesWorkshopCamera) throws(MeshError) -> ApsidesWorkshopColouredMesh {
        try glow(snapshot, tier: tier, parts: Parts(camera: camera))
    }

    /// Builds the glow into `parts` (empty, with the view to face; see ``glowPart(_:tier:)``).
    static func glow(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                     parts start: Parts) throws(MeshError) -> ApsidesWorkshopColouredMesh {
        typealias P = ApsidesWorkshopPalette
        typealias K = ApsidesWorkshopShaders.GlowKind
        var parts: Parts = start
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let ribbon: [SIMD3<Double>] = refinement(snapshot, tier: tier)
        let towards: SIMD3<Double> = parts.towardsEye
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            let lift: SIMD3<Double> = parts.view == nil ? SIMD3(0, 0, glowLift * Double(k))
                : towards * (glowLift * Double(k))
            try parts.glowBand(centre: starCentre() + lift, inner: starRadius,
                               outer: starRadius + starGlowGrowth * Double(k), base: P.star,
                               code: K.star.code(factor: factor), factor: factor)
            var lifted: [SIMD3<Double>] = []
            for p in ribbon { lifted.append(p + lift) }
            try parts.glowRibbon(lifted, half: orbitWidth / 2 + orbitGlowGrowth * Double(k), base: P.glow,
                                 code: K.orbit.code(factor: factor), factor: factor)
            try parts.glowBand(centre: orbiterCentre(snapshot) + lift, inner: orbiterRadius,
                               outer: orbiterRadius + orbiterGlowGrowth * Double(k), base: P.glacial,
                               code: K.orbiter.code(factor: factor), factor: factor)
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

    /// The fixed camera for `aspect`: from (0, −0.3, 3.6) looking at (0, −0.3, 0) with +y up (straight down the z
    /// axis); the vertical field of view is the smallest that holds every corner of the box x −1.0 … 1.0, y −1.65 …
    /// 1.0, z −0.15 … 0.15 inside the view with ``fitMargin`` per side (the box is convex and in front of the eye, so
    /// every point inside it — the compass, every orbit, every planet of the catalog, the gauges and the bars — keeps
    /// a margin of at least 5 % for aspect 0.4 … 2.5). Independent of the snapshot, the tier and the time. Equals
    /// ``camera(aspect:orbit:)`` at ``ApsidesWorkshopViewOrbit/authored`` bit for bit.
    public static func camera(aspect: Double) -> ApsidesWorkshopCamera {
        camera(aspect: aspect, orbit: .authored)
    }

    /// The camera for `orbit` (clamped, see ``ApsidesWorkshopViewOrbit/clamped()``) and `aspect` (feature 474,
    /// T-R02G1804-002): from the orbit's eye looking at its look-at point (``orbitView(_:)``) with +y up (never
    /// parallel: the view stays within 35° of level); the vertical field of view is the smallest that holds every
    /// corner of the box x −1.0 … 1.0, y −1.65 … 1.0, z −0.15 … 0.15 inside the view with ``fitMargin`` per side, so
    /// everything inside the box keeps a margin of at least 5 % at every orbit and aspect 0.4 … 2.5. The eye stays
    /// outside the box. At the authored orbit it is the fixed camera of R02-G18-03, bit for bit. Presentation only;
    /// independent of the snapshot, the tier and the time.
    public static func camera(aspect: Double, orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopCamera {
        let o: ApsidesWorkshopViewOrbit = orbit.clamped()
        guard o.yaw != 0 || o.pitch != 0 else { return authoredCamera(aspect: aspect) }
        let view: (eye: SIMD3<Double>, target: SIMD3<Double>) = orbitView(o)
        return fitted(eye: view.eye, target: view.target, aspect: aspect)
    }

    /// The vertical axis the orbit yaws about passes through the authored box centre (0, −0.325, 0).
    static var orbitPivot: SIMD3<Double> { (boxLow + boxHigh) / 2 }

    /// `p` yawed by `yaw` radians about the vertical axis through ``orbitPivot`` (from +z towards +x).
    static func yawed(_ p: SIMD3<Double>, _ yaw: Double) -> SIMD3<Double> {
        let c: Double = cos(yaw)
        let s: Double = sin(yaw)
        let d: SIMD3<Double> = p - orbitPivot
        return SIMD3(orbitPivot.x + d.x * c + d.z * s, p.y, orbitPivot.z - d.x * s + d.z * c)
    }

    /// The eye and the look-at point of `orbit` (clamped): the authored eye's offset from the look-at point,
    /// (0, 0, 3.6), pitched about the authored view's right axis (its elevation above the horizontal raised by the
    /// pitch, its length and horizontal direction kept) and added to the look-at point; then both points yawed about
    /// the vertical axis through ``orbitPivot``. Exactly ``eye`` and ``lookAt`` at the authored orbit.
    static func orbitView(_ orbit: ApsidesWorkshopViewOrbit) -> (eye: SIMD3<Double>, target: SIMD3<Double>) {
        let o: ApsidesWorkshopViewOrbit = orbit.clamped()
        guard o.yaw != 0 || o.pitch != 0 else { return (eye: eye, target: lookAt) }
        let e: SIMD3<Double> = eye - lookAt
        let horizontal: Double = (e.x * e.x + e.z * e.z).squareRoot()
        let length: Double = dot(e, e).squareRoot()
        let elevation: Double = atan2(e.y, horizontal) + o.pitch
        let across: Double = length * cos(elevation) / horizontal
        let pitched: SIMD3<Double> = lookAt + SIMD3(e.x * across, length * sin(elevation), e.z * across)
        return (eye: yawed(pitched, o.yaw), target: yawed(lookAt, o.yaw))
    }

    /// The camera from `eye` looking at `target` with +y up for `aspect` (made usable): the vertical field of view is
    /// the smallest that holds every corner of the authored box inside the view with ``fitMargin`` per side; near half
    /// the nearest corner's depth (at least 0.001), far the farthest corner's depth plus 3 (past the facing backdrop).
    static func fitted(eye: SIMD3<Double>, target: SIMD3<Double>, aspect: Double) -> ApsidesWorkshopCamera {
        let a: Double = usableAspect(aspect)
        let forward: SIMD3<Double> = unit(target - eye)
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
        let far: Double = farthest + 3
        let view: Mat4 = Mat4.lookAt(eye: vec(eye), target: vec(target), up: Vec3(0, 1, 0))
        let projection: Mat4 = Mat4.perspective(fovY: fovY, aspect: a, near: near, far: far)
        return ApsidesWorkshopCamera(eye: eye, target: target, fovY: fovY, aspect: a, near: near, far: far, view: view,
                                     projection: projection, viewProjection: projection * view)
    }

    /// `camera`'s unit forward, right and up vectors (from its eye towards its target, +y up).
    static func viewBasis(_ camera: ApsidesWorkshopCamera) -> (forward: SIMD3<Double>, right: SIMD3<Double>,
                                                               up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit(camera.target - camera.eye)
        let right: SIMD3<Double> = unit(cross(forward, SIMD3(0, 1, 0)))
        return (forward, right, cross(right, forward))
    }

    /// The fixed camera of R02-G18-03 for `aspect` (see ``camera(aspect:)``), unchanged.
    static func authoredCamera(aspect: Double) -> ApsidesWorkshopCamera {
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
        return ApsidesWorkshopCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far, view: view,
                                     projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: ApsidesWorkshopCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// The unit direction at `angle` (radians, anticlockwise from +x) in the plane z = 0.
    static func direction(_ angle: Double) -> SIMD3<Double> { SIMD3(cos(angle), sin(angle), 0) }

    /// The dot product of `a` and `b`.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

    /// The cross product `a` × `b`.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// `v` scaled to unit length (`v` itself when its length is 0 or not finite).
    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let length: Double = dot(v, v).squareRoot()
        guard length.isFinite, length > 0 else { return v }
        return v / length
    }

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from the eye (+z) or from
    /// outside a sphere.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []
        /// The side every flat piece faces: towards the authored eye.
        static let facing: SIMD3<Double> = SIMD3(0, 0, 1)
        /// The camera the pieces face with its unit view basis (feature 474); nil for the authored camera, whose
        /// pieces are built exactly as in R02-G18-03.
        let view: (camera: ApsidesWorkshopCamera, forward: SIMD3<Double>, right: SIMD3<Double>,
                   up: SIMD3<Double>)?

        /// Parts built for the authored camera.
        init() { view = nil }

        /// Parts built for `camera` (feature 474): the authored parts when it is the authored camera (its eye and
        /// target), else parts whose billboards and backdrop face its eye.
        init(camera: ApsidesWorkshopCamera) {
            typealias G = ApsidesWorkshopSceneGeometry
            if camera.eye == G.eye && camera.target == G.lookAt {
                view = nil
            } else {
                let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(camera)
                view = (camera: camera, forward: basis.forward, right: basis.right, up: basis.up)
            }
        }

        /// The unit direction towards the eye the pieces face: +z for the authored camera, else −forward.
        var towardsEye: SIMD3<Double> {
            guard let v = view else { return Parts.facing }
            return v.forward * -1
        }

        /// Adds (or welds) a vertex at `p` with a_normal `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour` (default the code's).
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>? = nil) throws(MeshError) -> UInt32 {
            typealias G = ApsidesWorkshopSceneGeometry
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
                               _ pc: SIMD3<Double>, facing given: SIMD3<Double>? = nil) throws(MeshError) {
            let facing: SIMD3<Double> = given ?? towardsEye
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

        /// A flat triangle (a wedge: a_uv.y 0, a_normal zero).
        mutating func flatTriangle(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>,
                                   code: Double) throws(MeshError) {
            let zero: SIMD3<Double> = SIMD3(0, 0, 0)
            let ia: UInt32 = try vertex(a, slot: zero, code: code, local: 0)
            let ib: UInt32 = try vertex(b, slot: zero, code: code, local: 0)
            let ic: UInt32 = try vertex(c, slot: zero, code: code, local: 0)
            try triangle((ia, ib, ic), a, b, c)
        }

        /// A quad (corners in order) facing the eye, with uv (`code`, `local[k]`), a_normal per corner `slots`
        /// (default zero), in `colour` (default the code's) or per-corner `colours`.
        mutating func quad(_ p: [SIMD3<Double>], code: Double, local: [Double], colour: SIMD3<Double>? = nil,
                           colours tints: [SIMD3<Double>]? = nil,
                           slots: [SIMD3<Double>]? = nil) throws(MeshError) {
            var ids: [UInt32] = []
            for k in 0..<4 {
                ids.append(try vertex(p[k], slot: slots?[k] ?? SIMD3(0, 0, 0), code: code, local: local[k],
                                      colour: tints?[k] ?? colour))
            }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2])
            try triangle((ids[0], ids[2], ids[3]), p[0], p[2], p[3])
        }

        /// A fan through the convex `outline` around `centre` facing the eye: local 0 at the centre and 1 on the
        /// outline; a_normal `slot` everywhere.
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], code: Double,
                          slot: SIMD3<Double> = SIMD3(0, 0, 0)) throws(MeshError) {
            let c: UInt32 = try vertex(centre, slot: slot, code: code, local: 0)
            var ids: [UInt32] = []
            for p in outline { ids.append(try vertex(p, slot: slot, code: code, local: 1)) }
            for k in outline.indices {
                let j: Int = (k + 1) % outline.count
                try triangle((c, ids[k], ids[j]), centre, outline[k], outline[j])
            }
        }

        /// A strip of `width` from `a` to `b` in the plane facing the eye (a_uv.y −1 … +1 across it, a_normal zero);
        /// nothing for a strip of length 0.
        mutating func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, code: Double) throws(MeshError) {
            let d: SIMD3<Double> = b - a
            let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
            guard length > 0 else { return }
            let w: SIMD3<Double> = SIMD3(d.y / length, -d.x / length, 0) * (width / 2)
            try quad([a + w, b + w, b - w, a - w], code: code, local: [-1, -1, 1, 1])
        }

        /// A closed dashed ribbon of `width` through `points` (feature 474): one strip per segment k (the last back to
        /// the first), a_uv.y −1 … +1 across it and a_normal.x the fraction k / n at its start and (k + 1) / n at its
        /// end (the seam's end repeated with 1), a_normal.z ``ApsidesWorkshopShaders/ghostShapeLine``.
        mutating func dashedLoop(_ points: [SIMD3<Double>], width: Double, code: Double) throws(MeshError) {
            let n: Int = points.count
            guard n >= 2 else { return }
            let shape: Double = ApsidesWorkshopShaders.ghostShapeLine
            for k in 0..<n {
                let a: SIMD3<Double> = points[k]
                let b: SIMD3<Double> = points[(k + 1) % n]
                let d: SIMD3<Double> = b - a
                let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
                guard length > 0 else { continue }
                let w: SIMD3<Double> = SIMD3(d.y / length, -d.x / length, 0) * (width / 2)
                let t0: SIMD3<Double> = SIMD3(Double(k) / Double(n), 0, shape)
                let t1: SIMD3<Double> = SIMD3(k + 1 == n ? 1 : Double(k + 1) / Double(n), 0, shape)
                try quad([a + w, b + w, b - w, a - w], code: code, local: [-1, -1, 1, 1], slots: [t0, t1, t1, t0])
            }
        }

        /// A closed ribbon of `width` through `points` (one strip per segment, the last back to the first).
        mutating func loop(_ points: [SIMD3<Double>], width: Double, code: Double) throws(MeshError) {
            let n: Int = points.count
            guard n >= 2 else { return }
            for k in 0..<n { try strip(points[k], points[(k + 1) % n], width: width, code: code) }
        }

        /// A mark quad of half side ``ApsidesWorkshopShaders/markQuadExtent`` · `unit` around `centre`: a_normal.xy the
        /// mark-local coordinate (± markQuadExtent at the corners), a_normal.z `shape` (0 except on a ghost preview
        /// marker, feature 474), a_uv.y 0.
        mutating func mark(centre: SIMD3<Double>, unit: Double, code: Double, shape: Double = 0) throws(MeshError) {
            let e: Double = ApsidesWorkshopShaders.markQuadExtent
            let h: Double = e * unit
            try quad([centre + SIMD3(-h, -h, 0), centre + SIMD3(h, -h, 0), centre + SIMD3(h, h, 0),
                      centre + SIMD3(-h, h, 0)], code: code, local: [0, 0, 0, 0],
                     slots: [SIMD3(-e, -e, shape), SIMD3(e, -e, shape), SIMD3(e, e, shape), SIMD3(-e, e, shape)])
        }

        /// A rectangle of half size `half` around `centre`, as a fan (a_uv.y 0 at the centre, 1 on the outline).
        mutating func rectangle(centre: SIMD3<Double>, half: SIMD2<Double>, code: Double) throws(MeshError) {
            try fan(centre: centre, outline: [centre + SIMD3(-half.x, -half.y, 0), centre + SIMD3(half.x, -half.y, 0),
                                              centre + SIMD3(half.x, half.y, 0), centre + SIMD3(-half.x, half.y, 0)],
                    code: code)
        }

        /// The circle of `radius` around `centre` (in its z plane) in `segments` + 1 points (the last repeats the
        /// first), anticlockwise from the eye.
        func circlePoints(_ centre: SIMD3<Double>, _ radius: Double, _ segments: Int) -> [SIMD3<Double>] {
            var points: [SIMD3<Double>] = []
            let n: Int = max(segments, 3)
            for k in 0...n {
                points.append(centre + ApsidesWorkshopSceneGeometry.direction(2 * Double.pi * Double(k % n)
                                                                              / Double(n)) * radius)
            }
            return points
        }

        /// The circle of `radius` around `centre` facing the eye in `segments` + 1 points (the last repeats the
        /// first), anticlockwise from the eye: ``circlePoints(_:_:_:)`` for the authored camera, else in the plane of
        /// the view's right and up vectors (feature 474).
        func facingCirclePoints(_ centre: SIMD3<Double>, _ radius: Double, _ segments: Int) -> [SIMD3<Double>] {
            guard let v = view else { return circlePoints(centre, radius, segments) }
            var points: [SIMD3<Double>] = []
            let n: Int = max(segments, 3)
            for k in 0...n {
                let angle: Double = 2 * Double.pi * Double(k % n) / Double(n)
                points.append(centre + (v.right * cos(angle) + v.up * sin(angle)) * radius)
            }
            return points
        }

        /// A flat disc of `sides` sides and `radius` around `centre` facing the eye, as a fan (a_uv.y the radial
        /// coordinate), a_normal ``ApsidesWorkshopShaders/viewDirection``.
        mutating func disc(centre: SIMD3<Double>, radius: Double, sides: Int, code: Double) throws(MeshError) {
            try fan(centre: centre, outline: Array(facingCirclePoints(centre, radius, sides).dropLast()), code: code,
                    slot: ApsidesWorkshopShaders.viewDirection)
        }

        /// A ring between `inner` and `outer` around `centre` in `segments` quads (a_uv.y −1 inner, +1 outer); with
        /// `angles`, a_normal.x the angle fraction 0 … 1 (the seam's vertices repeated with 1.0), otherwise zero.
        mutating func circle(centre: SIMD3<Double>, inner: Double, outer: Double, segments: Int, code: Double,
                             angles: Bool = false) throws(MeshError) {
            let a: [SIMD3<Double>] = circlePoints(centre, inner, segments)
            let b: [SIMD3<Double>] = circlePoints(centre, outer, segments)
            let n: Int = a.count - 1
            for k in 0..<n {
                let s0: SIMD3<Double> = angles ? SIMD3(Double(k) / Double(n), 0, 0) : SIMD3(0, 0, 0)
                let s1: SIMD3<Double> = angles ? SIMD3(Double(k + 1) / Double(n), 0, 0) : SIMD3(0, 0, 0)
                try quad([a[k], b[k], b[k + 1], a[k + 1]], code: code, local: [-1, 1, 1, -1], slots: [s0, s0, s1, s1])
            }
        }

        /// An arc of the ring of `radius` and `width` around the origin from angle `from` to `to` in `segments` quads
        /// (a_uv.y −1 inner, +1 outer).
        mutating func arc(radius: Double, width: Double, from: Double, to: Double, segments: Int,
                          code: Double) throws(MeshError) {
            typealias G = ApsidesWorkshopSceneGeometry
            let n: Int = max(segments, 1)
            for k in 0..<n {
                let d0: SIMD3<Double> = G.direction(from + (to - from) * Double(k) / Double(n))
                let d1: SIMD3<Double> = G.direction(from + (to - from) * Double(k + 1) / Double(n))
                let inner: Double = radius - width / 2
                let outer: Double = radius + width / 2
                try quad([d0 * inner, d0 * outer, d1 * outer, d1 * inner], code: code, local: [-1, 1, 1, -1])
            }
        }

        /// A UV sphere of `radius` around `centre` with `longitudes` × `latitudes` segments (exact poles; a_uv.y 0),
        /// a_normal the outward normal, wound counter-clockwise seen from outside.
        mutating func sphere(centre: SIMD3<Double>, radius: Double, longitudes: Int, latitudes: Int,
                             code: Double) throws(MeshError) {
            let lon: Int = max(longitudes, 3)
            let lat: Int = max(latitudes, 2)
            var ids: [[UInt32]] = []
            var points: [[SIMD3<Double>]] = []
            for i in 0...lat {
                let a: Double = -Double.pi / 2 + Double.pi * Double(i) / Double(lat)
                var row: [UInt32] = []
                var rowPoints: [SIMD3<Double>] = []
                for j in 0...lon {
                    let phi: Double = 2 * Double.pi * Double(j % lon) / Double(lon)
                    let n: SIMD3<Double> = i == 0 ? SIMD3(0, -1, 0)
                        : (i == lat ? SIMD3(0, 1, 0) : SIMD3(cos(a) * cos(phi), sin(a), cos(a) * sin(phi)))
                    let p: SIMD3<Double> = centre + n * radius
                    row.append(try vertex(p, slot: n, code: code, local: 0))
                    rowPoints.append(p)
                }
                ids.append(row)
                points.append(rowPoints)
            }
            for i in 0..<lat {
                for j in 0..<lon {
                    let p00: SIMD3<Double> = points[i][j]
                    let p01: SIMD3<Double> = points[i][j + 1]
                    let p11: SIMD3<Double> = points[i + 1][j + 1]
                    let p10: SIMD3<Double> = points[i + 1][j]
                    let out1: SIMD3<Double> = (p00 + p01 + p11) / 3 - centre
                    let out2: SIMD3<Double> = (p00 + p11 + p10) / 3 - centre
                    try triangle((ids[i][j], ids[i][j + 1], ids[i + 1][j + 1]), p00, p01, p11, facing: out1)
                    try triangle((ids[i][j], ids[i + 1][j + 1], ids[i + 1][j]), p00, p11, p10, facing: out2)
                }
            }
        }

        /// A glow band: a ring of ``ApsidesWorkshopSceneGeometry/glowSides`` sides facing the eye from `inner` (a_uv.y
        /// 0) to `outer` (a_uv.y 1) around `centre`, a_normal the base colour, a_uv.x `code`, coloured base · factor.
        mutating func glowBand(centre: SIMD3<Double>, inner: Double, outer: Double, base: SIMD3<Double>, code: Double,
                               factor: Double) throws(MeshError) {
            let sides: Int = ApsidesWorkshopSceneGeometry.glowSides
            let a: [SIMD3<Double>] = facingCirclePoints(centre, inner, sides)
            let b: [SIMD3<Double>] = facingCirclePoints(centre, outer, sides)
            for k in 0..<(a.count - 1) {
                try quad([a[k], b[k], b[k + 1], a[k + 1]], code: code, local: [0, 1, 1, 0], colour: base * factor,
                         slots: [base, base, base, base])
            }
        }

        /// A glow ribbon along the closed loop `points`: per segment two quads from the centre line (a_uv.y 0) to
        /// either edge at `half` (a_uv.y 1), a_normal the base colour, a_uv.x `code`, coloured base · factor.
        mutating func glowRibbon(_ points: [SIMD3<Double>], half: Double, base: SIMD3<Double>, code: Double,
                                 factor: Double) throws(MeshError) {
            let n: Int = points.count
            guard n >= 2 else { return }
            for k in 0..<n {
                let a: SIMD3<Double> = points[k]
                let b: SIMD3<Double> = points[(k + 1) % n]
                let d: SIMD3<Double> = b - a
                let length: Double = (d.x * d.x + d.y * d.y).squareRoot()
                guard length > 0 else { continue }
                let w: SIMD3<Double> = SIMD3(d.y / length, -d.x / length, 0) * half
                let slots: [SIMD3<Double>] = [base, base, base, base]
                try quad([a, b, b + w, a + w], code: code, local: [0, 0, 1, 1], colour: base * factor, slots: slots)
                try quad([a, b, b - w, a - w], code: code, local: [0, 0, 1, 1], colour: base * factor, slots: slots)
            }
        }

        /// The coloured mesh built so far.
        func built() -> ApsidesWorkshopColouredMesh {
            ApsidesWorkshopColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
