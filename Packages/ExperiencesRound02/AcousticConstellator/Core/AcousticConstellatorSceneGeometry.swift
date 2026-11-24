// AcousticConstellatorSceneGeometry — feature 423 (R02-G13-03) T-R02G1303-004 (FR-R02G1303-001, 002, 004, 006;
// clarifications Q1, Q2, Q3, Q4). The constellation of Acoustic Constellator, built from a snapshot only. Star
// (gx, gy, gz) of the 12 × 12 × 12 drawing grid is at X = (gx − 5.5) · 0.14, Z = (gy − 5.5) · 0.11,
// Y = 0.15 + (gz − 5.5) · 0.02, with x to the right, y up and z towards the viewer. The sky is a plane at y = −0.01 over
// x −1.1 … 1.1, z −0.9 … 1.3; every unlinked symbol pair a dashed guide between its star centres (8 dashes, each the
// middle half of an eighth of the chord, 0.006 wide); every current link a spline strip 0.01 wide (the quadratic curve
// P(u) = A + (B − A)·u + (0, 0.12·u·(1 − u), 0), rising 0.03 above the chord at its middle, 16 segments), silver when its
// phase gap at the drawn tick is above 1 step and teal when it is at most 1 (on a won level every symbol link is drawn in
// ``AcousticConstellatorMaterial/wonLink`` instead); a link the kernel's report snaps on or before the drawn tick as two
// halves (u 0 … 0.35 and 0.65 … 1) with the middle 30 % missing; each star an ellipsoid (radii 0.045 × 0.035 × 0.045,
// 12 segments around, 8 from pole to pole) and its phase hand, a strip 0.006 wide and 0.07 long from above the centre at
// angle phase · 30° (phase 0 towards −z, turning towards +x), 0.04 above the centre. The gauges lie on y = 0: the
// coherence gauge, 12 bars at z = 0.85 in equal slots across x −0.6 … 0.6 (a bar four fifths of its slot, 0.05 deep),
// the first ⌊12 · (A + B√3) / n²⌋ lit, and the threshold mark (three fifths of a slot wide, 0.012 deep) at z = 0.805 over
// bar ⌈12θ / n²⌉ (the first bar is bar 1); the hold gauge, `hold` square pips at z = 1.0 in equal slots across
// x −0.4 … 0.4 (side min(0.05, 0.6 · slot)), the first `run` lit (filled), the others outlined (a frame strip a fifth of
// the side wide) for the coherent run ending on the drawn tick; the moves
// gauge, `budget` bars at z = 1.15 in equal slots across x −0.9 … 0.9 (each slot 1.8 / budget wide, the bar four fifths
// of it, a fifth gap, 0.05 deep), the first `actionsLeft` lit. A `missing` failure outlines the missing pair's guide, a
// `disconnected` failure the snapped link, by strips 0.004 wide on both sides of the axis (guide 0.004 … 0.008 from it,
// link 0.007 … 0.011) in ``AcousticConstellatorMaterial/broken``. The drawn tick is the snapshot's
// ``AcousticConstellatorSceneSnapshot/shownTick``, or tick 0 under Reduce Motion.
//
// Draw order (clarification Q1; depth testing off, back faces culled): the constellation mesh is in painter's order —
// the sky; the flat gauges (coherence bars, threshold mark, hold pips, moves bars); the guides and the broken guide's
// outline; the links and the broken link's outline; the phase hands; then the stars back to front (ascending Z, far side
// first, then ascending X, then ascending Y, then index). The glow mesh (wave shells first, then glow shells outermost
// first) is drawn last, additively. Every triangle winds counter-clockwise seen from the side it faces: flat layers and
// hands from +y, guide and link strips towards the eye, ellipsoids from outside.
//
// Vertex streams (the contract with `AcousticConstellatorShaders`, whose ``AcousticConstellatorMaterial`` and
// ``AcousticConstellatorGlowKind`` give the codes): `a_uv.x` is the material code and `a_uv.y` the local coordinate d:
// strips (guides, links, outlines, hands, unlit hold pips) −1 on one long side (an outline's or frame's inner edge) and
// +1 on the other; fans (coherence bars, the mark, lit hold pips, moves bars) 0 at the centre vertex and 1 on the
// outline; the sky 0; a star its index (0 … 7, the slot of its pulse uniform). `a_normal`:
// - the sky, the gauges, the mark and the pips: (0, 1, 0);
// - guides, links, outlines and hands: (u, item, 0), u the position 0 … 1 along the guide, link or hand and item the
//   symbol pair's index in ``AcousticConstellatorSceneSnapshot/unlinkedSymbolPairs``, the link's index in
//   ``AcousticConstellatorSceneSnapshot/links`` or the star's index;
// - stars: the unit-sphere direction s, with position = centre + (0.045, 0.035, 0.045) ⊙ s drawn unpulsed (the shader
//   applies the pulse 1 + 0.15 · cos(2π · phase / 12)).
// The glow mesh carries the colour in the normal slot (the shell colour or the glow colour, lifted towards white by
// ``wonLift`` around symbol links on a won level), uv.x = ``AcousticConstellatorGlowKind/code(factor:)`` and uv.y the
// wave-shell age 0 … 1 (0 for glow shells): a wave shell (``AcousticConstellatorGlowKind/waveShell``) has factor
// 1 − age (it fades as it expands), a glow shell (``AcousticConstellatorGlowKind/glow``, or
// ``AcousticConstellatorGlowKind/wonGlow`` around a symbol link on a won level) factor 0.5^k for shell k. Wave shells:
// `tier.waveShells` (2 at level-0) strip rings at each star's height around its centre, only on a coherent drawn tick,
// shell k of count at radius 0.12 · age ± 0.005 with age = fract(secondsIntoShownTick / 1 s + k / count) (expanding
// from 0 to 0.12 over 1 s), none under Reduce Motion. Glow shells: `tier.glowShells` (2, 1, 0) around every star (radii
// grown by 0.012 · k) and every unsnapped teal link (and on a won level every symbol link; half width 0.005 + 0.01 · k,
// lifted 0.001 · k).
// Tiers change only the glow mesh: the constellation mesh is identical at every tier (the pulse is a shader uniform).
// Doubles are used for drawing only; nothing here is consulted by the rules.
//
// Feature 426 (R02-G13-06) T-R02G1306-005: `constellationPart` and `glowPart` take a won level `won` (0 … 1, nil = the
// snapshot's won state) that scales the lift of the fallback colours on a won level — a won link's colour runs from
// teal (0) to ``AcousticConstellatorShaders/wonLinkColour`` (1) and a won glow's from the plain glow colour (0) to the
// lifted one (1) — so the unlit fallback fades with the presenter's won light as the shaders do under `u_wonLight`.
// Positions, the streams and every other colour never change; nil is byte-identical to the output before.
//
// Feature 424 (R02-G13-04) T-R02G1304-002 (FR-R02G1304-005; SC-R02G1304-004; clarifications Q1, Q4) adds the player's
// orbit (`AcousticConstellatorOrbit`: yaw ±35° about the vertical axis through the authored box centre
// (0, 0.15, 0.275), pitch −15° … +20° about the authored view's right axis, positive raising the eye so the
// constellation is seen more from above; authored (0, 0)) and `camera(_:aspect:orbit:)`: the eye's offset from the
// look-at point is pitched, then the eye and the look-at point are yawed together about that axis, and the field of view
// is refitted exactly as for the fixed camera so the authored box x −0.9 … 0.9, z −0.7 … 1.25, y 0 … 0.3 keeps
// ``fitMargin`` (above the required 5 %) per side at every orbit and aspect 0.4 … 2.5. At the authored orbit the eye and
// the look-at point are the authored ones, so `camera(_:aspect:)` (which calls it) is unchanged bit for bit. Under any
// other orbit the stars are painted in descending distance of their centres from the orbit's eye (far first, ties by
// the authored order) and the strips are wound to face the orbit's eye; the authored orbit keeps today's order and
// winding. `filamentMesh(from:to:_:)` is the drag preview: a straight strip 0.01 wide in
// ``AcousticConstellatorMaterial/tealLink`` from a star's centre to a world point. The orbit is presentation only:
// never saved, never read by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The player's view of the constellation: a yaw about the vertical axis through the authored box centre and a pitch
/// about the authored view's right axis, both in radians (feature 424, R02-G13-04). Presentation only: never saved,
/// never read by the rules.
public struct AcousticConstellatorOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians about the view's right axis: positive raises the eye (the constellation seen more from
    /// above), negative lowers it; allowed ``pitchRange`` (−15° … +20°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G13-03.
    public static let authored = AcousticConstellatorOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 35° in radians.
    public static let yawLimit: Double = 35.0 * Double.pi / 180
    /// The allowed pitches, −15° … +20° in radians.
    public static let pitchRange: ClosedRange<Double> = (-15.0 * Double.pi / 180)...(20.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −35° … 35° and pitch to −15° … 20°; a non-finite angle becomes 0.
    public func clamped() -> AcousticConstellatorOrbit {
        let y: Double = yaw.isFinite ? yaw : 0
        let p: Double = pitch.isFinite ? pitch : 0
        return AcousticConstellatorOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                         pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }
}

/// The camera of one frame: eye, target, lens and the matrices built from them (the authored camera at the authored
/// orbit).
public struct AcousticConstellatorCamera: Sendable, Equatable {
    /// The eye position in world units, (0, 2.0, 1.7) at the authored orbit.
    public let eye: SIMD3<Double>
    /// The point looked at, (0, 0, 0.2) at the authored orbit.
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

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct AcousticConstellatorColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Acoustic Constellator scene from an `AcousticConstellatorSceneSnapshot`: places, meshes, camera and
/// projection.
public enum AcousticConstellatorSceneGeometry {
    /// The material codes (shared with the shaders).
    public typealias Material = AcousticConstellatorMaterial

    // MARK: Constants (world units unless stated)

    /// The grid pitch along x: star (gx, gy, gz) has X = (gx − 5.5) · 0.14.
    public static let pitchX: Double = 0.14
    /// The grid pitch along z: Z = (gy − 5.5) · 0.11.
    public static let pitchZ: Double = 0.11
    /// The grid pitch along y: Y = 0.15 + (gz − 5.5) · 0.02.
    public static let pitchY: Double = 0.02
    /// The grid's centre on every axis.
    public static let gridCentre: Double = 5.5
    /// The height of the grid's middle layer.
    public static let baseY: Double = 0.15
    /// The sky's plane.
    public static let skyY: Double = -0.01
    /// The sky's extent along x.
    public static let skyX: ClosedRange<Double> = -1.1...1.1
    /// The sky's extent along z.
    public static let skyZ: ClosedRange<Double> = -0.9...1.3
    /// A guide's width.
    public static let guideWidth: Double = 0.006
    /// The dashes of a guide.
    public static let guideDashes: Int = 8
    /// The share of each eighth of a guide its dash covers (centred).
    public static let dashFill: Double = 0.5
    /// The broken guide's outline: inner and outer distance from the guide's axis.
    public static let guideOutline: ClosedRange<Double> = 0.004...0.008
    /// A link's width.
    public static let linkWidth: Double = 0.01
    /// A link's rise above its chord at the middle.
    public static let linkRise: Double = 0.03
    /// A link's segments.
    public static let linkSegments: Int = 16
    /// The share of a snapped link missing at its middle.
    public static let snapGap: Double = 0.3
    /// The broken link's outline: inner and outer distance from the link's axis.
    public static let linkOutline: ClosedRange<Double> = 0.007...0.011
    /// The position along a link of its frame-check point ``linkCheckPoint(_:_:)``.
    public static let checkU: Double = 0.25
    /// The sideways offset of a link's frame-check point from its axis (clear of the strip's half width 0.005).
    public static let checkOffset: Double = 0.015
    /// A star's ellipsoid radii (x, y, z).
    public static let starRadii: SIMD3<Double> = SIMD3(0.045, 0.035, 0.045)
    /// An ellipsoid's segments around the vertical axis.
    public static let starSegments: Int = 12
    /// An ellipsoid's segments from pole to pole.
    public static let starRings: Int = 8
    /// A phase hand's width.
    public static let handWidth: Double = 0.006
    /// A phase hand's length.
    public static let handLength: Double = 0.07
    /// A phase hand's height above its star's centre.
    public static let handLift: Double = 0.04
    /// The gauges' plane.
    public static let gaugeY: Double = 0
    /// The coherence gauge's centre line.
    public static let coherenceZ: Double = 0.85
    /// The coherence gauge's left end.
    public static let coherenceStart: Double = -0.6
    /// The coherence gauge's right end.
    public static let coherenceEnd: Double = 0.6
    /// The coherence bars.
    public static let coherenceCount: Int = 12
    /// The threshold mark's centre line (over the coherence bars).
    public static let markZ: Double = 0.805
    /// The threshold mark's depth along z.
    public static let markDepth: Double = 0.012
    /// The threshold mark's width as a share of a coherence slot.
    public static let markFill: Double = 0.6
    /// The hold gauge's centre line.
    public static let holdZ: Double = 1.0
    /// The hold gauge's left end.
    public static let holdStart: Double = -0.4
    /// The hold gauge's right end.
    public static let holdEnd: Double = 0.4
    /// A hold pip's largest side.
    public static let pipSide: Double = 0.05
    /// A hold pip's side as a share of its slot when the slot is narrow.
    public static let pipFill: Double = 0.6
    /// An unlit hold pip's frame line as a share of its side.
    public static let pipLine: Double = 0.2
    /// The moves gauge's centre line.
    public static let movesZ: Double = 1.15
    /// The moves gauge's left end.
    public static let movesStart: Double = -0.9
    /// The moves gauge's right end.
    public static let movesEnd: Double = 0.9
    /// The depth along z of the coherence and moves bars.
    public static let barDepth: Double = 0.05
    /// The share of a slot a bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// The wave shells' largest radius.
    public static let shellRadius: Double = 0.12
    /// A wave shell's line width.
    public static let shellLine: Double = 0.01
    /// The seconds a wave shell takes to expand to ``shellRadius``.
    public static let shellSeconds: Double = 1.0
    /// Segments of a wave shell.
    public static let shellSegments: Int = 24
    /// Extra radius per glow shell around a star.
    public static let starGlowGrowth: Double = 0.012
    /// Extra half width per glow shell around a link.
    public static let linkGlowGrowth: Double = 0.01
    /// Lift per glow shell around a link.
    public static let glowLift: Double = 0.001
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// How far a won level lifts the fallback colour of symbol links and the colour of their glow towards white.
    public static let wonLift: Double = 0.35
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, 2.0, 1.7)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, 0, 0.2)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-0.9, 0, -0.7)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(0.9, 0.3, 1.25)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places (the CPU reference)

    /// The tick drawn: 0 under Reduce Motion, else ``AcousticConstellatorSceneSnapshot/shownTick``.
    public static func drawnTick(_ snapshot: AcousticConstellatorSceneSnapshot, reduceMotion: Bool) -> Int {
        reduceMotion ? 0 : snapshot.shownTick
    }

    /// The centre of star `index` (clamped to the stars): ((gx − 5.5)·0.14, 0.15 + (gz − 5.5)·0.02, (gy − 5.5)·0.11).
    public static func starCentre(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.stars.isEmpty else { return SIMD3(0, baseY, 0) }
        let star: AcousticConstellatorStar = snapshot.stars[min(max(index, 0), snapshot.stars.count - 1)]
        return SIMD3((Double(star.x) - gridCentre) * pitchX, baseY + (Double(star.z) - gridCentre) * pitchY,
                     (Double(star.y) - gridCentre) * pitchZ)
    }

    /// The unit horizontal sideways direction (−Δz, 0, Δx) / |Δ| of the chord from `a` to `b`; (1, 0, 0) for a chord
    /// with no horizontal length.
    public static func side(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        let dx: Double = b.x - a.x
        let dz: Double = b.z - a.z
        let length: Double = (dx * dx + dz * dz).squareRoot()
        guard length > 0 else { return SIMD3(1, 0, 0) }
        return SIMD3(-dz / length, 0, dx / length)
    }

    /// The star centres of link `index` (clamped to the links), a then b; the first star twice without links.
    static func linkEnds(_ index: Int,
                         _ snapshot: AcousticConstellatorSceneSnapshot) -> (a: SIMD3<Double>, b: SIMD3<Double>) {
        guard !snapshot.links.isEmpty else { return (a: starCentre(0, snapshot), b: starCentre(0, snapshot)) }
        let link: AcousticConstellatorLink = snapshot.links[min(max(index, 0), snapshot.links.count - 1)]
        return (a: starCentre(link.a, snapshot), b: starCentre(link.b, snapshot))
    }

    /// The point at `u` (0 … 1) on the spline from `a` to `b`: the chord point lifted 4 · 0.03 · u · (1 − u).
    public static func splinePoint(_ a: SIMD3<Double>, _ b: SIMD3<Double>, u: Double) -> SIMD3<Double> {
        a + (b - a) * u + SIMD3(0, 4 * linkRise * u * (1 - u), 0)
    }

    /// The point at `u` (0 … 1) on link `index`'s spline.
    public static func linkPoint(_ index: Int, u: Double, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        let ends = linkEnds(index, snapshot)
        return splinePoint(ends.a, ends.b, u: u)
    }

    /// The frame-check point of link `index` (clarification Q3): at u = 0.25 along its spline (links do not move with
    /// the tick, so this is its place at tick 0), offset 0.015 along the chord's sideways direction, clear of the strip.
    public static func linkCheckPoint(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        let ends = linkEnds(index, snapshot)
        return splinePoint(ends.a, ends.b, u: checkU) + side(ends.a, ends.b) * checkOffset
    }

    /// The width of one coherence slot, 1.2 / 12.
    public static var coherenceSlot: Double { (coherenceEnd - coherenceStart) / Double(coherenceCount) }

    /// The centre of coherence bar `index` (0 … 11): (−0.6 + (index + 0.5)·0.1, 0, 0.85).
    public static func coherenceBar(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        _ = snapshot
        return SIMD3(coherenceStart + (Double(index) + 0.5) * coherenceSlot, gaugeY, coherenceZ)
    }

    /// The centre of the threshold mark: over bar ⌈12θ / n²⌉ (counted from 1; bar 0 is drawn over the first bar).
    public static func thresholdMark(_ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        let bar: Int = max(snapshot.thresholdBar, 1) - 1
        return SIMD3(coherenceStart + (Double(bar) + 0.5) * coherenceSlot, gaugeY, markZ)
    }

    /// The width of one hold slot, 0.8 / hold.
    public static func holdSlot(_ snapshot: AcousticConstellatorSceneSnapshot) -> Double {
        (holdEnd - holdStart) / Double(max(snapshot.hold, 1))
    }

    /// A hold pip's side: min(0.05, 0.6 · slot).
    public static func holdPipSide(_ snapshot: AcousticConstellatorSceneSnapshot) -> Double {
        min(pipSide, pipFill * holdSlot(snapshot))
    }

    /// The centre of hold pip `index`: (−0.4 + (index + 0.5)·slot, 0, 1.0).
    public static func holdPip(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        SIMD3(holdStart + (Double(index) + 0.5) * holdSlot(snapshot), gaugeY, holdZ)
    }

    /// The width of one moves slot, 1.8 / budget.
    public static func movesSlot(_ snapshot: AcousticConstellatorSceneSnapshot) -> Double {
        (movesEnd - movesStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of moves bar `index`: (−0.9 + (index + 0.5)·slot, 0, 1.15).
    public static func movesBar(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        SIMD3(movesStart + (Double(index) + 0.5) * movesSlot(snapshot), gaugeY, movesZ)
    }

    /// The moves bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litMoves(_ snapshot: AcousticConstellatorSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The won flag: 1 when the level is won (stage won, or result without a failure), else 0. A won level draws every
    /// symbol link in ``AcousticConstellatorMaterial/wonLink`` and lifts its glow; no position changes.
    public static func wonFlag(_ snapshot: AcousticConstellatorSceneSnapshot) -> Double {
        snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil) ? 1 : 0
    }

    /// Whether link `index` is a pair of the symbol.
    public static func isSymbolLink(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> Bool {
        guard index >= 0, index < snapshot.links.count else { return false }
        return snapshot.symbol.contains(snapshot.links[index])
    }

    /// The material of link `index` at `tick`: ``AcousticConstellatorMaterial/wonLink`` for a symbol link on a won
    /// level, else teal when the kernel's gap at `tick` is at most 1, else silver.
    public static func linkMaterial(_ index: Int, tick: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> Material {
        if wonFlag(snapshot) == 1, isSymbolLink(index, snapshot) { return .wonLink }
        return snapshot.isTeal(index, at: tick) ? .tealLink : .silverLink
    }

    /// The index in ``AcousticConstellatorSceneSnapshot/links`` of the link a `disconnected` failure outlines.
    public static func brokenLinkIndex(_ snapshot: AcousticConstellatorSceneSnapshot) -> Int? {
        guard let link = snapshot.brokenLink else { return nil }
        return snapshot.links.firstIndex(of: link)
    }

    /// The unit direction of star `index`'s phase hand at `tick`: angle φ · 30° from −z towards +x,
    /// (sin a, 0, −cos a).
    public static func handDirection(_ index: Int, tick: Int,
                                     _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double> {
        let phases: [Int] = snapshot.phases(at: tick)
        let phase: Int = index >= 0 && index < phases.count ? phases[index] : 0
        let angle: Double = Double(phase) * Double.pi / 6
        return SIMD3(sin(angle), 0, -cos(angle))
    }

    /// The stars in painter's order for the camera at `orbit` (clamped). At the authored orbit: ascending Z (far side
    /// first), then ascending X, then ascending Y, then index. At any other orbit (feature 424, T-R02G1304-002):
    /// descending distance of the star's centre from the orbit's eye (far first), ties broken by the authored order, so
    /// overlapping stars stay painted back to front when the camera turns.
    public static func starOrder(_ snapshot: AcousticConstellatorSceneSnapshot,
                                 orbit: AcousticConstellatorOrbit = .authored) -> [Int] {
        let stars: [AcousticConstellatorStar] = snapshot.stars
        let clamped: AcousticConstellatorOrbit = orbit.clamped()
        let byDistance: Bool = clamped != .authored
        var distances: [Double] = Array(repeating: 0, count: stars.count)
        if byDistance {
            let eye: SIMD3<Double> = orbitView(clamped).eye
            for index in stars.indices {
                let d: SIMD3<Double> = starCentre(index, snapshot) - eye
                distances[index] = dot(d, d)
            }
        }
        return Array(stars.indices).sorted { a, b in
            if byDistance, distances[a] != distances[b] { return distances[a] > distances[b] }
            if stars[a].y != stars[b].y { return stars[a].y < stars[b].y }
            if stars[a].x != stars[b].x { return stars[a].x < stars[b].x }
            if stars[a].z != stars[b].z { return stars[a].z < stars[b].z }
            return a < b
        }
    }

    /// The fallback colour of `material` (the palette colour the shaders start from; a won link is the shaders'
    /// ``AcousticConstellatorShaders/wonLinkColour``).
    public static func colour(_ material: Material) -> SIMD3<Double> {
        switch material {
        case .sky: AcousticConstellatorPalette.sky
        case .guide: AcousticConstellatorPalette.guide
        case .silverLink: AcousticConstellatorPalette.silver
        case .tealLink: AcousticConstellatorPalette.teal
        case .broken: AcousticConstellatorPalette.broken
        case .star: AcousticConstellatorPalette.star
        case .hand: AcousticConstellatorPalette.hand
        case .coherenceLit: AcousticConstellatorPalette.coherenceLit
        case .coherenceUnlit: AcousticConstellatorPalette.coherenceUnlit
        case .thresholdMark: AcousticConstellatorPalette.thresholdMark
        case .holdLit: AcousticConstellatorPalette.holdLit
        case .holdUnlit: AcousticConstellatorPalette.holdUnlit
        case .movesLit: AcousticConstellatorPalette.movesLit
        case .movesUnlit: AcousticConstellatorPalette.movesUnlit
        case .wonLink: AcousticConstellatorShaders.wonLinkColour
        }
    }

    /// `colour` lifted towards white by ``wonLift`` when `won` is 1.
    static func lifted(_ colour: SIMD3<Double>, won: Double) -> SIMD3<Double> {
        colour + (SIMD3(1, 1, 1) - colour) * (wonLift * won)
    }

    // MARK: Meshes

    /// The constellation mesh for the constellation program, in painter's order (see the header), at the drawn tick
    /// (tick 0 under `reduceMotion`). Identical at every tier: the tier's pulse is applied by a shader uniform. The stars
    /// are in painter's order for `orbit` (``starOrder(_:orbit:)``) and the strips face its eye; positions are the same
    /// at every orbit.
    public static func constellationMesh(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                                         reduceMotion: Bool,
                                         orbit: AcousticConstellatorOrbit = .authored) throws(MeshError) -> Mesh {
        try constellationPart(snapshot, tier: tier, reduceMotion: reduceMotion, orbit: orbit).mesh
    }

    /// The constellation with fallback colours (unlit palette colours) for the shared unlit renderer: the same mesh as
    /// ``constellationMesh(_:tier:reduceMotion:orbit:)`` (which draws the level-2 look when shaded unlit), the stars in
    /// painter's order for `orbit`. `won` (0 … 1, feature 426) scales the won links' fallback colour from teal (0) to
    /// ``AcousticConstellatorShaders/wonLinkColour`` (1), as `u_wonLight` does in the shader; nil keeps the snapshot's
    /// won state at full strength. Positions and streams never change.
    public static func constellationPart(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                                         reduceMotion: Bool = false,
                                         orbit: AcousticConstellatorOrbit = .authored,
                                         won: Double? = nil) throws(MeshError)
        -> AcousticConstellatorColouredMesh {
        _ = tier
        return try build(snapshot, tick: drawnTick(snapshot, reduceMotion: reduceMotion), orbit: orbit, won: won)
    }

    /// The won level `won` made usable (feature 426): clamped to 0 … 1, 1 when not finite; nil when nil (the
    /// snapshot's won state at full strength).
    static func usableWon(_ won: Double?) -> Double? {
        won.map { (level: Double) -> Double in level.isFinite ? min(max(level, 0), 1) : 1 }
    }

    /// The drag preview (feature 424, T-R02G1304-002): a straight strip 0.01 wide (one segment, d = −1 and +1 on its
    /// long sides) in ``AcousticConstellatorMaterial/tealLink`` from the centre of star `star` to the world `point`,
    /// normal slot (u, star, 0), wound to face the authored eye (the strip lies nearly flat and every orbit's eye is
    /// above it). Empty when `star` is not a star of `snapshot`, `point` is not finite or the two coincide.
    public static func filamentMesh(from star: Int, to point: SIMD3<Double>,
                                    _ snapshot: AcousticConstellatorSceneSnapshot) throws(MeshError) -> Mesh {
        var parts: Parts = Parts()
        guard star >= 0, star < snapshot.stars.count, point.x.isFinite, point.y.isFinite, point.z.isFinite else {
            return parts.built().mesh
        }
        let a: SIMD3<Double> = starCentre(star, snapshot)
        let d: SIMD3<Double> = point - a
        guard dot(d, d) > 0 else { return parts.built().mesh }
        try parts.strip(a, point, rise: 0, from: 0, to: 1, segments: 1, band: 0...(linkWidth / 2), material: .tealLink,
                        item: Double(star))
        return parts.built().mesh
    }

    /// Builds the constellation at `tick` in painter's order for `orbit`; `won` scales the won links' fallback colour
    /// (``constellationPart(_:tier:reduceMotion:orbit:won:)``).
    static func build(_ snapshot: AcousticConstellatorSceneSnapshot, tick: Int,
                      orbit: AcousticConstellatorOrbit = .authored,
                      won: Double? = nil) throws(MeshError) -> AcousticConstellatorColouredMesh {
        var parts: Parts = Parts()
        let wonTint: SIMD3<Double>? = usableWon(won).map { (level: Double) -> SIMD3<Double> in
            AcousticConstellatorShaders.wonLinkColour(light: level)
        }
        parts.eye = orbitView(orbit).eye
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        // Sky.
        let x0: Double = skyX.lowerBound
        let x1: Double = skyX.upperBound
        let z0: Double = skyZ.lowerBound
        let z1: Double = skyZ.upperBound
        try parts.quad([SIMD3(x0, skyY, z0), SIMD3(x1, skyY, z0), SIMD3(x1, skyY, z1), SIMD3(x0, skyY, z1)], front: up,
                       slot: up, material: .sky, local: [0, 0, 0, 0])
        // Coherence gauge and its threshold mark.
        let lit: Int = snapshot.coherenceBars(at: tick)
        for index in 0..<coherenceCount {
            try parts.rectangle(centre: coherenceBar(index, snapshot), width: barFill * coherenceSlot, depth: barDepth,
                                material: index < lit ? .coherenceLit : .coherenceUnlit)
        }
        try parts.rectangle(centre: thresholdMark(snapshot), width: markFill * coherenceSlot, depth: markDepth,
                            material: .thresholdMark)
        // Hold pips.
        let run: Int = snapshot.run(at: tick)
        let side: Double = holdPipSide(snapshot)
        for index in 0..<max(snapshot.hold, 0) {
            if index < run {
                try parts.rectangle(centre: holdPip(index, snapshot), width: side, depth: side, material: .holdLit)
            } else {
                try parts.frame(centre: holdPip(index, snapshot), half: side / 2, line: pipLine * side,
                                material: .holdUnlit)
            }
        }
        // Moves gauge.
        let moves: Int = litMoves(snapshot)
        for index in 0..<max(snapshot.budget, 0) {
            try parts.rectangle(centre: movesBar(index, snapshot), width: barFill * movesSlot(snapshot), depth: barDepth,
                                material: index < moves ? .movesLit : .movesUnlit)
        }
        // Guides, then the broken guide's outline.
        let guides: [AcousticConstellatorLink] = snapshot.unlinkedSymbolPairs
        for (item, pair) in guides.enumerated() {
            let a: SIMD3<Double> = starCentre(pair.a, snapshot)
            let b: SIMD3<Double> = starCentre(pair.b, snapshot)
            let step: Double = 1 / Double(guideDashes)
            let inset: Double = step * (1 - dashFill) / 2
            for k in 0..<guideDashes {
                let start: Double = Double(k) * step + inset
                try parts.strip(a, b, rise: 0, from: start, to: start + step - 2 * inset, segments: 1,
                                band: 0...(guideWidth / 2), material: .guide, item: Double(item))
            }
        }
        if let pair = snapshot.brokenGuide {
            let item: Int = guides.firstIndex(of: pair) ?? 0
            try parts.strip(starCentre(pair.a, snapshot), starCentre(pair.b, snapshot), rise: 0, from: 0, to: 1,
                            segments: 1, band: guideOutline, material: .broken, item: Double(item))
        }
        // Links, then the broken link's outline.
        let keep: Double = (1 - snapGap) / 2
        let halfSegments: Int = Int((Double(linkSegments) * keep).rounded(.up))
        for index in snapshot.links.indices {
            let ends = linkEnds(index, snapshot)
            let material: Material = linkMaterial(index, tick: tick, snapshot)
            let tint: SIMD3<Double>? = material == .wonLink ? wonTint : nil
            if snapshot.isSnapped(index, at: tick) {
                try parts.strip(ends.a, ends.b, rise: linkRise, from: 0, to: keep, segments: halfSegments,
                                band: 0...(linkWidth / 2), material: material, item: Double(index), colour: tint)
                try parts.strip(ends.a, ends.b, rise: linkRise, from: 1 - keep, to: 1, segments: halfSegments,
                                band: 0...(linkWidth / 2), material: material, item: Double(index), colour: tint)
            } else {
                try parts.strip(ends.a, ends.b, rise: linkRise, from: 0, to: 1, segments: linkSegments,
                                band: 0...(linkWidth / 2), material: material, item: Double(index), colour: tint)
            }
        }
        if let index = brokenLinkIndex(snapshot) {
            let ends = linkEnds(index, snapshot)
            try parts.strip(ends.a, ends.b, rise: linkRise, from: 0, to: 1, segments: linkSegments, band: linkOutline,
                            material: .broken, item: Double(index))
        }
        // Phase hands.
        for index in snapshot.stars.indices {
            let c: SIMD3<Double> = starCentre(index, snapshot) + SIMD3(0, handLift, 0)
            let d: SIMD3<Double> = handDirection(index, tick: tick, snapshot)
            let n: SIMD3<Double> = SIMD3(-d.z, 0, d.x) * (handWidth / 2)
            let e: SIMD3<Double> = c + d * handLength
            let slots: [SIMD3<Double>] = [SIMD3(0, Double(index), 0), SIMD3(1, Double(index), 0),
                                          SIMD3(1, Double(index), 0), SIMD3(0, Double(index), 0)]
            try parts.quad([c - n, e - n, e + n, c + n], front: up, slots: slots, material: .hand, local: [-1, -1, 1, 1])
        }
        // Stars, back to front for the drawn orbit.
        for index in starOrder(snapshot, orbit: orbit) {
            try parts.ellipsoid(centre: starCentre(index, snapshot), radii: starRadii, code: Material.star.code,
                                local: Double(index), slot: nil, colour: colour(.star))
        }
        return parts.built()
    }

    /// The glow with fallback colours (the base colour times the intensity) for the shared unlit renderer: the wave
    /// shells (`tier.waveShells` per star on a coherent drawn tick, none under `reduceMotion`) and the glow shells
    /// (`tier.glowShells`, outermost first) around every star and every unsnapped teal link (on a won level every
    /// symbol link, its glow lifted). Empty at level-2. The star shells are in painter's order for `orbit`
    /// (``starOrder(_:orbit:)``) and the link glow strips face its eye. `won` (0 … 1, feature 426) scales the won
    /// glow's fallback colour from the plain glow colour (0) to the lifted one (1), as `u_wonLight` does in the shader;
    /// nil keeps the snapshot's won state at full strength. The normal slot (the stream colour) is never scaled.
    public static func glowPart(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                                reduceMotion: Bool = false,
                                orbit: AcousticConstellatorOrbit = .authored,
                                won level: Double? = nil) throws(MeshError)
        -> AcousticConstellatorColouredMesh {
        var parts: Parts = Parts()
        parts.eye = orbitView(orbit).eye
        let tick: Int = drawnTick(snapshot, reduceMotion: reduceMotion)
        let won: Double = wonFlag(snapshot)
        let liftLevel: Double? = usableWon(level)
        // Wave shells.
        let shells: Int = reduceMotion ? 0 : min(max(tier.waveShells, 0), 2)
        if shells > 0, snapshot.isCoherent(at: tick) {
            let shell: SIMD3<Double> = AcousticConstellatorPalette.shell
            for index in snapshot.stars.indices {
                let c: SIMD3<Double> = starCentre(index, snapshot)
                for k in 0..<shells {
                    let phase: Double = snapshot.secondsIntoShownTick / shellSeconds + Double(k) / Double(shells)
                    let age: Double = phase - phase.rounded(.down)
                    let r: Double = shellRadius * age
                    let fade: Double = 1 - age
                    try parts.ring(centre: c, inner: max(0, r - shellLine / 2), outer: r + shellLine / 2,
                                   segments: shellSegments, slot: shell,
                                   code: AcousticConstellatorGlowKind.waveShell.code(factor: fade), age: age,
                                   colour: shell * fade)
                }
            }
        }
        // Glow shells.
        let glows: Int = min(max(tier.glowShells, 0), 2)
        guard glows > 0 else { return parts.built() }
        let glow: SIMD3<Double> = AcousticConstellatorPalette.glow
        for k in stride(from: glows, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            for index in snapshot.links.indices {
                let symbolWon: Bool = won == 1 && isSymbolLink(index, snapshot)
                guard symbolWon || (snapshot.isTeal(index, at: tick) && !snapshot.isSnapped(index, at: tick)) else {
                    continue
                }
                let base: SIMD3<Double> = symbolWon ? lifted(glow, won: 1) : glow
                let tint: SIMD3<Double> = symbolWon && liftLevel != nil ? lifted(glow, won: liftLevel ?? 1) : base
                let kind: AcousticConstellatorGlowKind = symbolWon ? .wonGlow : .glow
                let ends = linkEnds(index, snapshot)
                let lift: SIMD3<Double> = SIMD3(0, glowLift * Double(k), 0)
                try parts.glowStrip(ends.a + lift, ends.b + lift, halfWidth: linkWidth / 2 + linkGlowGrowth * Double(k),
                                    slot: base, code: kind.code(factor: factor), colour: tint * factor)
            }
            for index in starOrder(snapshot, orbit: orbit) {
                let grow: Double = starGlowGrowth * Double(k)
                try parts.ellipsoid(centre: starCentre(index, snapshot), radii: starRadii + SIMD3(grow, grow, grow),
                                    code: AcousticConstellatorGlowKind.glow.code(factor: factor), local: 0, slot: glow,
                                    colour: glow * factor)
            }
        }
        return parts.built()
    }

    /// The glow mesh for the glow program (`glowPart` without colours, in painter's order for `orbit`); empty at
    /// level-2.
    public static func glowMesh(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                                reduceMotion: Bool = false,
                                orbit: AcousticConstellatorOrbit = .authored) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier, reduceMotion: reduceMotion, orbit: orbit).mesh
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

    /// The fixed camera for `aspect`: from (0, 2.0, 1.7) looking at (0, 0, 0.2) with +y up; the vertical field of view
    /// is the smallest that holds every corner of the box x −0.9 … 0.9, y 0 … 0.3, z −0.7 … 1.25 inside the view with
    /// ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it — every star, link,
    /// gauge bar and pip — keeps a margin of at least 5 % for aspect 0.4 … 2.5). The snapshot is accepted for parity.
    /// Equals ``camera(_:aspect:orbit:)`` at ``AcousticConstellatorOrbit/authored`` bit for bit.
    public static func camera(_ snapshot: AcousticConstellatorSceneSnapshot, aspect: Double) -> AcousticConstellatorCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The vertical axis the orbit yaws about passes through the authored box centre (0, 0.15, 0.275).
    static var orbitPivot: SIMD3<Double> { (boxLow + boxHigh) / 2 }

    /// `p` yawed by `yaw` radians about the vertical axis through ``orbitPivot`` (from +z towards +x).
    static func yawed(_ p: SIMD3<Double>, _ yaw: Double) -> SIMD3<Double> {
        let c: Double = cos(yaw)
        let s: Double = sin(yaw)
        let d: SIMD3<Double> = p - orbitPivot
        return SIMD3(orbitPivot.x + d.x * c + d.z * s, p.y, orbitPivot.z - d.x * s + d.z * c)
    }

    /// The eye and the look-at point of `orbit` (clamped): the authored eye's offset from the look-at point,
    /// e = (0, 2.0, 1.5), pitched about the x axis (positive p raises it: (0, e.y·cos p + e.z·sin p,
    /// −e.y·sin p + e.z·cos p)) and added to the look-at point; then both points yawed about the vertical axis through
    /// ``orbitPivot``. Exactly ``eye`` and ``lookAt`` at the authored orbit.
    static func orbitView(_ orbit: AcousticConstellatorOrbit) -> (eye: SIMD3<Double>, target: SIMD3<Double>) {
        let o: AcousticConstellatorOrbit = orbit.clamped()
        guard o.yaw != 0 || o.pitch != 0 else { return (eye: eye, target: lookAt) }
        let e: SIMD3<Double> = eye - lookAt
        let cp: Double = cos(o.pitch)
        let sp: Double = sin(o.pitch)
        let pitched: SIMD3<Double> = lookAt + SIMD3(e.x, e.y * cp + e.z * sp, -e.y * sp + e.z * cp)
        return (eye: yawed(pitched, o.yaw), target: yawed(lookAt, o.yaw))
    }

    /// The camera for `orbit` (clamped, see ``AcousticConstellatorOrbit/clamped()``) and `aspect` (feature 424,
    /// T-R02G1304-002): from the orbit's eye looking at its look-at point (``orbitView(_:)``) with +y up (never
    /// parallel: the eye stays well above the sky); the vertical field of view is the smallest that holds every corner
    /// of the box x −0.9 … 0.9, y 0 … 0.3, z −0.7 … 1.25 inside the view with ``fitMargin`` per side, so everything
    /// inside the box — every star, link, gauge bar and pip — keeps a margin of at least 5 % at every orbit and aspect
    /// 0.4 … 2.5. Presentation only; independent of the snapshot, the tier and the time.
    public static func camera(_ snapshot: AcousticConstellatorSceneSnapshot, aspect: Double,
                              orbit: AcousticConstellatorOrbit) -> AcousticConstellatorCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
        let view0 = orbitView(orbit)
        let eye: SIMD3<Double> = view0.eye
        let lookAt: SIMD3<Double> = view0.target
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
        return AcousticConstellatorCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far,
                                          view: view, projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: AcousticConstellatorCamera) -> SIMD2<Double>? {
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
        /// The eye the strips are wound to face (the authored eye unless an orbit's is set; feature 424).
        var eye: SIMD3<Double> = AcousticConstellatorSceneGeometry.eye

        /// Adds (or welds) a vertex at `p` with normal slot `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour`.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>) throws(MeshError) -> UInt32 {
            let id: UInt32 = try builder.vertex(AcousticConstellatorSceneGeometry.vec(p),
                                                normal: AcousticConstellatorSceneGeometry.vec(slot),
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
            let n: SIMD3<Double> = AcousticConstellatorSceneGeometry.cross(pb - pa, pc - pa)
            let side: Double = AcousticConstellatorSceneGeometry.dot(n, front)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A convex quad (corners in order) facing `front`, one normal slot per corner, local coordinates `local` per
        /// corner, uv.x `code` (default the material's code), in `colour` (default the material's colour).
        mutating func quad(_ p: [SIMD3<Double>], front: SIMD3<Double>, slots: [SIMD3<Double>], material: Material,
                           local: [Double], code: Double? = nil, colour: SIMD3<Double>? = nil) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? AcousticConstellatorSceneGeometry.colour(material)
            let value: Double = code ?? material.code
            var ids: [UInt32] = []
            for k in 0..<4 { ids.append(try vertex(p[k], slot: slots[k], code: value, local: local[k], colour: tint)) }
            try facing((ids[0], ids[1], ids[2]), p[0], p[1], p[2], front: front)
            try facing((ids[0], ids[2], ids[3]), p[0], p[2], p[3], front: front)
        }

        /// A convex quad with one normal slot for every corner.
        mutating func quad(_ p: [SIMD3<Double>], front: SIMD3<Double>, slot: SIMD3<Double>, material: Material,
                           local: [Double]) throws(MeshError) {
            try quad(p, front: front, slots: [slot, slot, slot, slot], material: material, local: local)
        }

        /// A flat rectangle facing +y (`width` along x, `depth` along z) as a fan: the centre (d = 0) and the corners
        /// (d = 1), normal slot (0, 1, 0).
        mutating func rectangle(centre: SIMD3<Double>, width: Double, depth: Double,
                                material: Material) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let code: Double = material.code
            let tint: SIMD3<Double> = AcousticConstellatorSceneGeometry.colour(material)
            let w: Double = width / 2
            let d: Double = depth / 2
            let outline: [SIMD3<Double>] = [centre + SIMD3(-w, 0, -d), centre + SIMD3(w, 0, -d), centre + SIMD3(w, 0, d),
                                            centre + SIMD3(-w, 0, d)]
            let c: UInt32 = try vertex(centre, slot: up, code: code, local: 0, colour: tint)
            var ids: [UInt32] = []
            for p in outline { ids.append(try vertex(p, slot: up, code: code, local: 1, colour: tint)) }
            for k in 0..<4 {
                let j: Int = (k + 1) % 4
                try facing((c, ids[k], ids[j]), centre, outline[k], outline[j], front: up)
            }
        }

        /// A square frame facing +y (outer half side `half`, line `line`) of four strips, d = −1 inside, +1 outside,
        /// normal slot (0, 1, 0).
        mutating func frame(centre: SIMD3<Double>, half: Double, line: Double, material: Material) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let o: Double = half
            let i: Double = max(half - line, 0)
            let outer: [SIMD3<Double>] = [centre + SIMD3(-o, 0, -o), centre + SIMD3(o, 0, -o), centre + SIMD3(o, 0, o),
                                          centre + SIMD3(-o, 0, o)]
            let inner: [SIMD3<Double>] = [centre + SIMD3(-i, 0, -i), centre + SIMD3(i, 0, -i), centre + SIMD3(i, 0, i),
                                          centre + SIMD3(-i, 0, i)]
            for k in 0..<4 {
                let j: Int = (k + 1) % 4
                try quad([inner[k], outer[k], outer[j], inner[j]], front: up, slot: up, material: material,
                         local: [-1, 1, 1, -1])
            }
        }

        /// A strip along the spline from `a` to `b` rising `rise` at its middle, over u `from` … `to` in `segments`
        /// segments, covering the band `band` of distances from the axis along the chord's sideways direction (a band
        /// from 0: one strip, d = −1 on the −side edge, +1 on the +side edge; a band from above 0: two strips, d = −1
        /// at the inner edge, +1 at the outer). Normal slot (u, `item`, 0); wound to face the eye. `colour` overrides the
        /// material's fallback colour (feature 426: a won link at a won level below 1).
        mutating func strip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, rise: Double, from: Double, to: Double,
                            segments: Int, band: ClosedRange<Double>, material: Material,
                            item: Double, colour: SIMD3<Double>? = nil) throws(MeshError) {
            let side: SIMD3<Double> = AcousticConstellatorSceneGeometry.side(a, b)
            var lanes: [(near: Double, far: Double, dNear: Double, dFar: Double)] = []
            if band.lowerBound <= 0 {
                lanes.append((near: -band.upperBound, far: band.upperBound, dNear: -1, dFar: 1))
            } else {
                lanes.append((near: band.lowerBound, far: band.upperBound, dNear: -1, dFar: 1))
                lanes.append((near: -band.lowerBound, far: -band.upperBound, dNear: -1, dFar: 1))
            }
            let count: Int = max(segments, 1)
            let point: (Double) -> SIMD3<Double> = { (u: Double) -> SIMD3<Double> in
                a + (b - a) * u + SIMD3(0, 4 * rise * u * (1 - u), 0)
            }
            for lane in lanes {
                for i in 0..<count {
                    let u0: Double = from + (to - from) * Double(i) / Double(count)
                    let u1: Double = from + (to - from) * Double(i + 1) / Double(count)
                    let p0: SIMD3<Double> = point(u0)
                    let p1: SIMD3<Double> = point(u1)
                    let corners: [SIMD3<Double>] = [p0 + side * lane.near, p1 + side * lane.near, p1 + side * lane.far,
                                                    p0 + side * lane.far]
                    let slots: [SIMD3<Double>] = [SIMD3(u0, item, 0), SIMD3(u1, item, 0), SIMD3(u1, item, 0),
                                                  SIMD3(u0, item, 0)]
                    let front: SIMD3<Double> = eye - (p0 + p1) * 0.5
                    try quad(corners, front: front, slots: slots, material: material,
                             local: [lane.dNear, lane.dNear, lane.dFar, lane.dFar], colour: colour)
                }
            }
        }

        /// A glow strip along the link spline from `a` to `b` (``linkSegments`` segments, half width `halfWidth`):
        /// normal slot `slot` (the colour), uv (`code`, 0); wound to face the eye.
        mutating func glowStrip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, halfWidth: Double, slot: SIMD3<Double>,
                                code: Double, colour: SIMD3<Double>) throws(MeshError) {
            let side: SIMD3<Double> = AcousticConstellatorSceneGeometry.side(a, b) * halfWidth
            let count: Int = AcousticConstellatorSceneGeometry.linkSegments
            for i in 0..<count {
                let u0: Double = Double(i) / Double(count)
                let u1: Double = Double(i + 1) / Double(count)
                let p0: SIMD3<Double> = AcousticConstellatorSceneGeometry.splinePoint(a, b, u: u0)
                let p1: SIMD3<Double> = AcousticConstellatorSceneGeometry.splinePoint(a, b, u: u1)
                let front: SIMD3<Double> = eye - (p0 + p1) * 0.5
                try quad([p0 - side, p1 - side, p1 + side, p0 + side], front: front, slots: [slot, slot, slot, slot],
                         material: .wonLink, local: [0, 0, 0, 0], code: code,
                         colour: colour)
            }
        }

        /// A flat ring facing +y around `centre` (its plane) from radius `inner` to `outer`: normal slot `slot` (the
        /// colour), uv (`code`, `age`).
        mutating func ring(centre: SIMD3<Double>, inner: Double, outer: Double, segments: Int, slot: SIMD3<Double>,
                           code: Double, age: Double, colour: SIMD3<Double>) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            for i in 0..<segments {
                let a0: Double = 2 * Double.pi * Double(i) / Double(segments)
                let a1: Double = 2 * Double.pi * Double(i + 1) / Double(segments)
                let d0: SIMD3<Double> = SIMD3(cos(a0), 0, sin(a0))
                let d1: SIMD3<Double> = SIMD3(cos(a1), 0, sin(a1))
                try quad([centre + d0 * inner, centre + d0 * outer, centre + d1 * outer, centre + d1 * inner], front: up,
                         slots: [slot, slot, slot, slot], material: .wonLink, local: [age, age, age, age], code: code,
                         colour: colour)
            }
        }

        /// An ellipsoid at `centre` with `radii` (``starSegments`` around, ``starRings`` from pole to pole), wound
        /// outward, uv (`code`, `local`); the normal slot is `slot` when given (the glow colour), else each vertex's
        /// unit-sphere direction s (position = centre + radii ⊙ s).
        mutating func ellipsoid(centre: SIMD3<Double>, radii: SIMD3<Double>, code: Double, local: Double,
                                slot: SIMD3<Double>?, colour: SIMD3<Double>) throws(MeshError) {
            let around: Int = AcousticConstellatorSceneGeometry.starSegments
            let rings: Int = AcousticConstellatorSceneGeometry.starRings
            var grid: [[(id: UInt32, p: SIMD3<Double>)]] = []
            for j in 0...rings {
                let theta: Double = Double.pi * Double(j) / Double(rings)
                var row: [(id: UInt32, p: SIMD3<Double>)] = []
                for i in 0..<around {
                    let phi: Double = 2 * Double.pi * Double(i) / Double(around)
                    let direction: SIMD3<Double> = SIMD3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
                    let p: SIMD3<Double> = centre + radii * direction
                    row.append((id: try vertex(p, slot: slot ?? direction, code: code, local: local, colour: colour), p: p))
                }
                grid.append(row)
            }
            for j in 0..<rings {
                for i in 0..<around {
                    let k: Int = (i + 1) % around
                    let q: [(id: UInt32, p: SIMD3<Double>)] = [grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]]
                    let mid: SIMD3<Double> = (q[0].p + q[1].p + q[2].p + q[3].p) * 0.25 - centre
                    try facing((q[0].id, q[1].id, q[2].id), q[0].p, q[1].p, q[2].p, front: mid)
                    try facing((q[0].id, q[2].id, q[3].id), q[0].p, q[2].p, q[3].p, front: mid)
                }
            }
        }

        /// The coloured mesh built so far.
        func built() -> AcousticConstellatorColouredMesh {
            AcousticConstellatorColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
