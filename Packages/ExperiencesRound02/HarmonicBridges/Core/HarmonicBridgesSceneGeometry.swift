// HarmonicBridgesSceneGeometry — feature 413 (R02-G12-03) T-R02G1203-004 (FR-R02G1203-001, 002, 004, 006;
// clarifications Q1, Q2, Q3, Q4). The bridges of Harmonic Bridges, built from a snapshot only. The islands stand on the
// plane y = 0 with x to the right and z towards the viewer: island (gx, gy) of the 16 × 10 drawing grid is at
// X = (gx − 7.5) · 0.12, Z = (gy − 4.5) · 0.12. The mist ground is a plane at y = −0.01 over x −1.1 … 1.1,
// z −0.8 … 1.1; each island a hexagonal prism (vertex radius 0.07, a vertex on +x, height 0.1) with copper faces and its
// six top edges as strips 0.008 thick, each folded over its edge (0.004 on the top, 0.004 down the side, d = 0 on the
// edge), lifted ``edgeLift`` off the faces; a ring (radius 0.1, line 0.012) at y = 0.005 around the start island and a
// four-pointed star (radius 0.1, inner radius 0.035, points on the diagonals) at y = 0.005 around the goal; every island
// the start reaches in the shown step a glow ring (radius 0.085, line 0.012) at y = 0.003; every string a strip 0.012
// wide of 24 segments between its islands' top centres at y = 0.1, drawn at rest (the presentation wave is applied in
// the bridge vertex shader); a string that is a bridge in the shown step a membrane strip 0.05 wide beneath it at
// y = 0.095; on each string the five samples k = 1 … 5 at u = k / 6 as marks 0.02 wide at y = 0.11 — a filled square
// (``HarmonicBridgesMaterial/markFilled``) exactly where the kernel's swing `report.swings[step][string][k − 1]` reaches
// the threshold, a hollow ring (outer radius 0.01, line 0.004) where it does not; the broken string of a broken test
// outlined by a strip 0.004 wide on each side (0.007 … 0.011 from its axis); the window's steps as a row of pips at
// z = 0.8, y = 0 (squares 0.06 wide centred in equal slots across x −0.3 … 0.3; the shown step filled, the others
// outlined with a line 0.01; a broken step's pip framed (0.08 wide, line 0.008) and crossed by two diagonal strips
// 0.008 wide); the moves gauge, a row of `budget` bars at z = 0.95, y = 0 across x −0.9 … 0.9 (each slot 1.8 / budget
// wide, the bar four fifths of it, a fifth gap, 0.05 deep), the first `actionsLeft` bars lit. At level-0 (and not under
// Reduce Motion) every string with a resonant mode in the shown step carries 2 radial wave shells at y = 0.1 around its
// midpoint. The shown step is ``HarmonicBridgesSceneSnapshot/shownStep``, or ``HarmonicBridgesSceneSnapshot/restingStep``
// under Reduce Motion.
//
// Draw order (clarification Q1; depth testing off, back faces culled): the bridge mesh is in painter's order — the
// ground; the flat rings (glow rings, start ring, goal star); the membranes; the wave shells; the strings, the broken
// string's outline and the marks; the islands back to front (ascending Z, far first, then within a row from the outside
// in — descending |X|, then ascending X — because the fixed camera sits at x = 0), each complete (sides, top, edge
// strips); then the pips and the gauge. The glow mesh is drawn last, additively. Every triangle winds counter-clockwise
// seen from the side its face looks at (flat layers from +y, prism faces from outside).
//
// Vertex streams (the contract with `HarmonicBridgesShaders`): `a_uv.x` is the material code
// (``HarmonicBridgesMaterial``), `a_uv.y` the local coordinate d (fans: 0 at the centre vertex, 1 on the outline;
// strips and rings: −1 on one long side (a ring's inner edge), +1 on the other; prism faces 0; ground 0). `a_normal`:
// - ground, flat rings, pips, gauge, the start ring and goal star: (0, 1, 0);
// - membranes and glow rings: (0, 1, won), won = ``wonFlag(_:)`` (1 on a won level: the shader brightens them);
// - prism faces: the outward face normal; edge strips: the normal of the face the half lies on;
// - strings, marks and the broken string's outline: (u, packed modes, θ) — u the position along the string (a mark's
//   u is k / 6 for all its vertices, so it moves rigidly with the wave), θ = atan2(side.z, side.x) of the unit
//   sideways direction side = (−Δz, 0, Δx) / |Δ| from island a to island b, and packed = m₀ + 24·m₁ + 576·m₂ with
//   mᵢ = 4·nᵢ + wᵢ for the shown step's resonant modes nᵢ (1 … 5) and their tone strengths wᵢ (1 … 3), in tone order,
//   0 for a missing mode (``packModes(_:_:)``); packed is 0 when the tier has no motion or under Reduce Motion, so the
//   string is drawn at rest. The shader's wave is side · Σ 0.01 · wᵢ · sin(nᵢπu) · cos(2π nᵢ t / 1.6);
// - wave shells: (centre.x, phase, centre.z), the string's midpoint and the shell's phase k / 2 (k = 0, 1); the
//   vertices lie at radius 0.15 ± 0.005 around the centre and the shader moves each along its direction from the centre
//   to radius r(t) = fract(t / 1.6 + phase) · 0.15 (plus d · 0.005).
// The glow mesh holds the glow shells around the shown step's membranes and reached islands (tier.glowShells, 0 … 2,
// outermost first): the glow colour in the normal slot, uv = (glow factor 0.5^k, won).
// Wave and step move nothing here: every position other than the wave shells' is the same at every tier and under
// Reduce Motion. Doubles are used for drawing only; nothing here is consulted by the rules.
//
// Feature 414 (R02-G12-04) T-R02G1204-002 adds the player's orbit (`HarmonicBridgesOrbit`: yaw ±35° about the vertical
// axis through the authored box centre (0, 0.1, 0.15), pitch −15° … +20° about the authored view's right axis, positive
// raising the eye so the bridges are seen more from above; authored (0, 0)) and `camera(_:aspect:orbit:)`: the eye's
// offset from the look-at point is pitched, then the eye and the look-at point are yawed together about that axis, and
// the field of view is refitted exactly as for the fixed camera so the authored box x −1 … 1, z −0.7 … 1.0, y 0 … 0.2
// keeps ``fitMargin`` (above the required 5 %) per side at every orbit and aspect 0.4 … 2.5. At the authored orbit the
// eye and the look-at point are the authored ones, so `camera(_:aspect:)` (which calls it) is unchanged bit for bit.
// The orbit is presentation only: never saved, never read by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The fixed authored camera of one frame: eye, target, lens and the matrices built from them.
public struct HarmonicBridgesCamera: Sendable, Equatable {
    /// The eye position in world units, (0, 1.9, 1.6) at the authored orbit.
    public let eye: SIMD3<Double>
    /// The point looked at, (0, 0, 0.1) at the authored orbit.
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

/// The player's view of the bridges: a yaw about the vertical axis through the authored box centre and a pitch about
/// the authored view's right axis, both in radians (feature 414, R02-G12-04). Presentation only: never saved, never read
/// by the rules.
public struct HarmonicBridgesOrbit: Sendable, Equatable {
    /// The yaw in radians about +y, from the front (+z) towards +x; allowed −``yawLimit`` … ``yawLimit``.
    public var yaw: Double
    /// The pitch in radians about the view's right axis: positive raises the eye (the bridges seen more from above),
    /// negative lowers it; allowed ``pitchRange`` (−15° … +20°).
    public var pitch: Double

    /// An orbit of the given yaw and pitch in radians (not clamped; see ``clamped()``).
    public init(yaw: Double, pitch: Double) {
        self.yaw = yaw
        self.pitch = pitch
    }

    /// The authored orbit: yaw 0, pitch 0, the fixed camera of R02-G12-03.
    public static let authored = HarmonicBridgesOrbit(yaw: 0, pitch: 0)
    /// The largest yaw either way, 35° in radians.
    public static let yawLimit: Double = 35.0 * Double.pi / 180
    /// The allowed pitches, −15° … +20° in radians.
    public static let pitchRange: ClosedRange<Double> = (-15.0 * Double.pi / 180)...(20.0 * Double.pi / 180)

    /// This orbit with yaw clamped to −35° … 35° and pitch to −15° … 20°; a non-finite angle becomes 0.
    public func clamped() -> HarmonicBridgesOrbit {
        let y: Double = yaw.isFinite ? yaw : 0
        let p: Double = pitch.isFinite ? pitch : 0
        return HarmonicBridgesOrbit(yaw: min(max(y, -Self.yawLimit), Self.yawLimit),
                                    pitch: min(max(p, Self.pitchRange.lowerBound), Self.pitchRange.upperBound))
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct HarmonicBridgesColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Harmonic Bridges scene from a `HarmonicBridgesSceneSnapshot`: places, meshes, camera and projection.
public enum HarmonicBridgesSceneGeometry {
    /// The material codes (shared with the shaders).
    public typealias Material = HarmonicBridgesMaterial

    // MARK: Constants (world units unless stated)

    /// The grid pitch: island (gx, gy) is at ((gx − 7.5)·pitch, 0, (gy − 4.5)·pitch).
    public static let gridPitch: Double = 0.12
    /// The grid's centre column.
    public static let gridCentreX: Double = 7.5
    /// The grid's centre row.
    public static let gridCentreY: Double = 4.5
    /// The ground's plane.
    public static let groundY: Double = -0.01
    /// The ground's extent along x.
    public static let groundX: ClosedRange<Double> = -1.1...1.1
    /// The ground's extent along z.
    public static let groundZ: ClosedRange<Double> = -0.8...1.1
    /// An island prism's vertex radius.
    public static let islandRadius: Double = 0.07
    /// An island prism's height.
    public static let islandHeight: Double = 0.1
    /// An edge strip's thickness (half on the top, half down the side).
    public static let edgeThickness: Double = 0.008
    /// How far edge strips (and glow shells, per shell) are lifted off the faces they lie on.
    public static let edgeLift: Double = 0.001
    /// The plane of the start ring and the goal star.
    public static let markerY: Double = 0.005
    /// The start ring's radius (the centre of its line).
    public static let startRadius: Double = 0.1
    /// The start ring's line width.
    public static let startLine: Double = 0.012
    /// The goal star's outer radius.
    public static let goalRadius: Double = 0.1
    /// The goal star's inner radius.
    public static let goalInner: Double = 0.035
    /// The glow rings' plane.
    public static let glowRingY: Double = 0.003
    /// A glow ring's radius (the centre of its line).
    public static let glowRingRadius: Double = 0.085
    /// A glow ring's line width.
    public static let glowRingLine: Double = 0.012
    /// Segments of the start ring and the glow rings.
    public static let ringSegments: Int = 24
    /// The strings' plane.
    public static let stringY: Double = 0.1
    /// A string's width.
    public static let stringWidth: Double = 0.012
    /// A string's segments.
    public static let stringSegments: Int = 24
    /// The membranes' plane (beneath the strings).
    public static let membraneY: Double = 0.095
    /// A membrane's width.
    public static let membraneWidth: Double = 0.05
    /// The position along the string of the membrane's frame-check point ``membraneMidpoint(_:_:)``: u = 0.25, between
    /// the marks at u = 1/6 and 2/6.
    public static let membraneSampleU: Double = 0.25
    /// The sideways offset of the membrane's frame-check point from the string's axis: clear of the string (half width
    /// 0.006) and its marks (half width 0.01), inside the membrane (half width 0.025).
    public static let membraneSampleOffset: Double = 0.018
    /// The marks' plane.
    public static let markY: Double = 0.11
    /// A mark's width (a filled square's side, a hollow ring's outer diameter).
    public static let markWidth: Double = 0.02
    /// A hollow ring mark's line width.
    public static let markLine: Double = 0.004
    /// Segments of a hollow ring mark.
    public static let markSegments: Int = 12
    /// The broken string's outline: inner and outer distance from its axis.
    public static let outlineBand: ClosedRange<Double> = 0.007...0.011
    /// The wave shells' largest radius.
    public static let shellRadius: Double = 0.15
    /// A wave shell's line width.
    public static let shellLine: Double = 0.01
    /// Segments of a wave shell.
    public static let shellSegments: Int = 32
    /// The pips' centre line.
    public static let pipZ: Double = 0.8
    /// The pips' left end.
    public static let pipStart: Double = -0.3
    /// The pips' right end.
    public static let pipEnd: Double = 0.3
    /// A pip's side.
    public static let pipWidth: Double = 0.06
    /// The line of an outlined pip.
    public static let pipLine: Double = 0.01
    /// The broken pip's frame side.
    public static let brokenFrame: Double = 0.08
    /// The broken pip's frame line and cross width.
    public static let brokenLine: Double = 0.008
    /// The gauge's plane.
    public static let gaugeY: Double = 0
    /// The gauge's centre line.
    public static let gaugeZ: Double = 0.95
    /// The gauge's depth along z.
    public static let gaugeDepth: Double = 0.05
    /// The gauge's left end.
    public static let gaugeStart: Double = -0.9
    /// The gauge's right end.
    public static let gaugeEnd: Double = 0.9
    /// The share of a slot a bar fills (the rest, a fifth, is the gap).
    public static let gaugeFill: Double = 0.8
    /// Extra half width per glow shell around a membrane.
    public static let membraneGlowGrowth: Double = 0.01
    /// Extra radius and height per glow shell around a reached island.
    public static let islandGlowGrowth: Double = 0.012
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// How far a won level lifts the fallback colours of membranes, glow rings and glow shells towards white.
    public static let wonLift: Double = 0.35
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0, 1.9, 1.6)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, 0, 0.1)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-1, 0, -0.7)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(1, 0.2, 1.0)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places (the CPU reference)

    /// The step drawn: ``HarmonicBridgesSceneSnapshot/restingStep`` under Reduce Motion, else
    /// ``HarmonicBridgesSceneSnapshot/shownStep``.
    public static func drawnStep(_ snapshot: HarmonicBridgesSceneSnapshot, reduceMotion: Bool) -> Int {
        reduceMotion ? snapshot.restingStep : snapshot.shownStep
    }

    /// The centre of island `index` (clamped to the islands) on the ground plane: ((gx − 7.5)·0.12, 0, (gy − 4.5)·0.12).
    public static func islandCentre(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.islands.isEmpty else { return SIMD3(0, 0, 0) }
        let island: HarmonicBridgesIsland = snapshot.islands[min(max(index, 0), snapshot.islands.count - 1)]
        return SIMD3((Double(island.x) - gridCentreX) * gridPitch, 0, (Double(island.y) - gridCentreY) * gridPitch)
    }

    /// The top-face centre of island `index`'s prism: (X, 0.1, Z).
    public static func islandTop(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        let c: SIMD3<Double> = islandCentre(index, snapshot)
        return SIMD3(c.x, islandHeight, c.z)
    }

    /// The ends of string `index` (clamped to the strings) at rest: its islands' top centres, a then b.
    public static func stringEnds(_ index: Int,
                                  _ snapshot: HarmonicBridgesSceneSnapshot) -> (a: SIMD3<Double>, b: SIMD3<Double>) {
        guard !snapshot.strings.isEmpty else { return (a: SIMD3(0, stringY, 0), b: SIMD3(0, stringY, 0)) }
        let string: HarmonicBridgesString = snapshot.strings[min(max(index, 0), snapshot.strings.count - 1)]
        return (a: islandTop(string.a, snapshot), b: islandTop(string.b, snapshot))
    }

    /// The unit sideways direction (−Δz, 0, Δx) / |Δ| of string `index` (from island a to island b); (1, 0, 0) for a
    /// string of no length.
    public static func stringSide(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        let ends = stringEnds(index, snapshot)
        let d: SIMD3<Double> = ends.b - ends.a
        let length: Double = (d.x * d.x + d.z * d.z).squareRoot()
        guard length > 0 else { return SIMD3(1, 0, 0) }
        return SIMD3(-d.z / length, 0, d.x / length)
    }

    /// The point at `u` (0 … 1) along string `index` at rest, on the plane `y`.
    public static func stringPoint(_ index: Int, u: Double, y: Double,
                                   _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        let ends = stringEnds(index, snapshot)
        let p: SIMD3<Double> = ends.a + (ends.b - ends.a) * u
        return SIMD3(p.x, y, p.z)
    }

    /// The midpoint of string `index` at rest: (mid X, 0.1, mid Z).
    public static func stringMidpoint(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        stringPoint(index, u: 0.5, y: stringY, snapshot)
    }

    /// The frame-check point of string `index`'s membrane (clarification Q3 as corrected by the lead): at
    /// u = ``membraneSampleU`` (0.25) along the string at rest, on the membrane plane y = 0.095, offset
    /// ``membraneSampleOffset`` (0.018) along ``stringSide(_:_:)``, clear of the string and its marks. The name is kept
    /// from the contract.
    public static func membraneMidpoint(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        stringPoint(index, u: membraneSampleU, y: membraneY, snapshot) + stringSide(index, snapshot) * membraneSampleOffset
    }

    /// The centre of sample mark `sample` (k = 1 … 5) of string `index`: at u = k / 6 on the mark plane y = 0.11.
    public static func markCentre(_ index: Int, sample: Int,
                                  _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        stringPoint(index, u: Double(sample) / 6, y: markY, snapshot)
    }

    /// Whether sample `sample` (k = 1 … 5) of string `index` is drawn filled in `step`: exactly when the kernel's swing
    /// `report.swings[step][index][k − 1]` reaches the threshold.
    public static func isFilled(_ index: Int, sample: Int, step: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> Bool {
        let swings: [[[Int]]] = snapshot.report.swings
        guard step >= 0, step < swings.count, index >= 0, index < swings[step].count, sample >= 1,
              sample <= swings[step][index].count else { return false }
        return swings[step][index][sample - 1] >= snapshot.threshold
    }

    /// The width of one gauge slot, 1.8 / budget.
    public static func gaugeSlot(_ snapshot: HarmonicBridgesSceneSnapshot) -> Double {
        (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of gauge bar `index` (of `budget` slots across x −0.9 … 0.9): (−0.9 + (index + 0.5)·slot, 0, 0.95).
    public static func gaugeBar(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * gaugeSlot(snapshot), gaugeY, gaugeZ)
    }

    /// The bars drawn lit: the actions left, clamped to 0 … budget (the first bars are lit).
    public static func litBars(_ snapshot: HarmonicBridgesSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The width of one pip slot, 0.6 / steps.
    public static func pipSlot(_ snapshot: HarmonicBridgesSceneSnapshot) -> Double {
        (pipEnd - pipStart) / Double(max(snapshot.steps, 1))
    }

    /// The centre of step `index`'s pip: (−0.3 + (index + 0.5)·slot, 0, 0.8).
    public static func stepPip(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double> {
        SIMD3(pipStart + (Double(index) + 0.5) * pipSlot(snapshot), 0, pipZ)
    }

    /// The won flag: 1 when the level is won (stage won, or result without a failure), else 0. A won level brightens
    /// the shown step's membranes, the reached islands' glow rings and the glow shells; no position changes.
    public static func wonFlag(_ snapshot: HarmonicBridgesSceneSnapshot) -> Double {
        snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil) ? 1 : 0
    }

    /// The broken step of a broken test, if any (clamped to the window).
    public static func brokenStep(_ snapshot: HarmonicBridgesSceneSnapshot) -> Int? {
        if case let .broken(step, _)? = snapshot.failure, snapshot.steps > 0 {
            return min(max(step, 0), snapshot.steps - 1)
        }
        return nil
    }

    /// The packed resonant modes of string `index` in `step` (see the header): m₀ + 24·m₁ + 576·m₂ with
    /// mᵢ = 4·nᵢ + wᵢ, in tone order, at most three; 0 when the string resonates nothing.
    public static func packModes(_ index: Int, step: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> Double {
        guard step >= 0, step < snapshot.modes.count, index >= 0, index < snapshot.modes[step].count else { return 0 }
        let modes: [Int] = snapshot.modes[step][index]
        let weights: [Int] = step < snapshot.strengths.count && index < snapshot.strengths[step].count
            ? snapshot.strengths[step][index] : []
        var packed: Int = 0
        var scale: Int = 1
        for i in 0..<min(modes.count, 3) {
            let n: Int = min(max(modes[i], 0), 5)
            let w: Int = i < weights.count ? min(max(weights[i], 0), 3) : 0
            packed += (4 * n + w) * scale
            scale *= 24
        }
        return Double(packed)
    }

    /// The islands in painter's order: ascending Z (far first), then descending |X| (outside in), then ascending X.
    public static func islandOrder(_ snapshot: HarmonicBridgesSceneSnapshot) -> [Int] {
        var order: [Int] = Array(snapshot.islands.indices)
        let islands: [HarmonicBridgesIsland] = snapshot.islands
        order.sort { a, b in
            if islands[a].y != islands[b].y { return islands[a].y < islands[b].y }
            // |X| ∝ |2·gx − 15|, compared in whole numbers.
            let da: Int = abs(2 * islands[a].x - 15)
            let db: Int = abs(2 * islands[b].x - 15)
            if da != db { return da > db }
            if islands[a].x != islands[b].x { return islands[a].x < islands[b].x }
            return a < b
        }
        return order
    }

    /// The fallback colour of `material` (the palette colour the shaders start from).
    public static func colour(_ material: Material) -> SIMD3<Double> {
        switch material {
        case .ground: HarmonicBridgesPalette.ground
        case .islandFace: HarmonicBridgesPalette.islandFace
        case .islandEdge: HarmonicBridgesPalette.islandEdge
        case .startRing: HarmonicBridgesPalette.start
        case .goalStar: HarmonicBridgesPalette.goal
        case .string: HarmonicBridgesPalette.string
        case .membrane: HarmonicBridgesPalette.membrane
        case .markFilled: HarmonicBridgesPalette.markFilled
        case .markHollow: HarmonicBridgesPalette.markHollow
        case .glowRing: HarmonicBridgesPalette.glow
        case .waveShell: HarmonicBridgesPalette.shell
        case .pip: HarmonicBridgesPalette.pip
        case .pipUnlit: HarmonicBridgesPalette.pipUnlit
        case .brokenOutline: HarmonicBridgesPalette.brokenOutline
        case .gaugeLit: HarmonicBridgesPalette.gaugeLit
        case .gaugeUnlit: HarmonicBridgesPalette.gaugeUnlit
        }
    }

    /// `colour` lifted towards white by ``wonLift`` when `won` is 1.
    static func lifted(_ colour: SIMD3<Double>, won: Double) -> SIMD3<Double> {
        colour + (SIMD3(1, 1, 1) - colour) * (wonLift * won)
    }

    // MARK: Meshes

    /// The bridges with fallback colours (unlit palette colours; won membranes and glow rings lifted) for the shared
    /// unlit renderer: the level-2 geometry — strings at rest, no wave shells. Positions equal the bridge mesh's.
    public static func bridgePart(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier,
                                  reduceMotion: Bool = false) throws(MeshError) -> HarmonicBridgesColouredMesh {
        _ = tier
        return try build(snapshot, step: drawnStep(snapshot, reduceMotion: reduceMotion), motion: false, shells: 0)
    }

    /// The bridge mesh for the bridge program, in painter's order: strings at rest with their packed modes when
    /// `tier.motion` and not `reduceMotion`; `tier.waveShells` wave shells per resonating string unless `reduceMotion`.
    public static func bridgeMesh(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier,
                                  reduceMotion: Bool) throws(MeshError) -> Mesh {
        try build(snapshot, step: drawnStep(snapshot, reduceMotion: reduceMotion), motion: tier.motion && !reduceMotion,
                  shells: reduceMotion ? 0 : min(max(tier.waveShells, 0), 2)).mesh
    }

    /// Builds the bridges for `step` in painter's order (see the header).
    static func build(_ snapshot: HarmonicBridgesSceneSnapshot, step: Int, motion: Bool,
                      shells: Int) throws(MeshError) -> HarmonicBridgesColouredMesh {
        var parts: Parts = Parts()
        let up: SIMD3<Double> = SIMD3(0, 1, 0)
        let won: Double = wonFlag(snapshot)
        // Ground.
        let x0: Double = groundX.lowerBound
        let x1: Double = groundX.upperBound
        let z0: Double = groundZ.lowerBound
        let z1: Double = groundZ.upperBound
        try parts.quad([SIMD3(x0, groundY, z0), SIMD3(x1, groundY, z0), SIMD3(x1, groundY, z1), SIMD3(x0, groundY, z1)],
                       front: up, slot: up, material: .ground, local: [0, 0, 0, 0])
        // Flat rings: glow rings of the reached islands, the start ring, the goal star.
        for index in snapshot.islands.indices where snapshot.isReached(index, step: step) {
            let c: SIMD3<Double> = islandCentre(index, snapshot)
            try parts.ring(centre: SIMD3(c.x, glowRingY, c.z), radius: glowRingRadius, line: glowRingLine,
                           segments: ringSegments, material: .glowRing, slot: SIMD3(0, 1, won),
                           colour: lifted(colour(.glowRing), won: won))
        }
        let s: SIMD3<Double> = islandCentre(snapshot.start, snapshot)
        try parts.ring(centre: SIMD3(s.x, markerY, s.z), radius: startRadius, line: startLine, segments: ringSegments,
                       material: .startRing, slot: up, colour: colour(.startRing))
        let g: SIMD3<Double> = islandCentre(snapshot.goal, snapshot)
        var star: [SIMD3<Double>] = []
        for i in 0..<8 {
            let angle: Double = Double.pi / 4 + Double(i) * Double.pi / 4
            let r: Double = i % 2 == 0 ? goalRadius : goalInner
            star.append(SIMD3(g.x + r * cos(angle), markerY, g.z + r * sin(angle)))
        }
        try parts.fan(centre: SIMD3(g.x, markerY, g.z), outline: star, material: .goalStar, slot: up,
                      colour: colour(.goalStar))
        // Membranes of the shown step's bridges.
        for index in snapshot.strings.indices where snapshot.isBridge(index, step: step) {
            try parts.strip(snapshot, string: index, y: membraneY, band: 0...(membraneWidth / 2), material: .membrane,
                            segments: 1, slot: { (_: Double) -> SIMD3<Double> in SIMD3(0, 1, won) },
                            colour: lifted(colour(.membrane), won: won))
        }
        // Wave shells.
        if shells > 0 {
            for index in snapshot.strings.indices where packModes(index, step: step, snapshot) > 0 {
                let c: SIMD3<Double> = stringMidpoint(index, snapshot)
                for k in 0..<shells {
                    let slot: SIMD3<Double> = SIMD3(c.x, Double(k) / 2, c.z)
                    try parts.ring(centre: c, radius: shellRadius, line: shellLine, segments: shellSegments,
                                   material: .waveShell, slot: slot, colour: colour(.waveShell))
                }
            }
        }
        // Strings, the broken string's outline, the marks.
        let broken: Int? = snapshot.brokenString
        for index in snapshot.strings.indices {
            let packed: Double = motion ? packModes(index, step: step, snapshot) : 0
            let side: SIMD3<Double> = stringSide(index, snapshot)
            let theta: Double = atan2(side.z, side.x)
            let wave: (Double) -> SIMD3<Double> = { (u: Double) -> SIMD3<Double> in SIMD3(u, packed, theta) }
            try parts.strip(snapshot, string: index, y: stringY, band: 0...(stringWidth / 2), material: .string,
                            segments: stringSegments, slot: wave, colour: colour(.string))
            if broken == index {
                try parts.strip(snapshot, string: index, y: stringY, band: outlineBand, material: .brokenOutline,
                                segments: stringSegments, slot: wave, colour: colour(.brokenOutline))
            }
            for k in 1...HarmonicBridgesSwing.samples {
                let c: SIMD3<Double> = markCentre(index, sample: k, snapshot)
                let slot: SIMD3<Double> = SIMD3(Double(k) / 6, packed, theta)
                if isFilled(index, sample: k, step: step, snapshot) {
                    let along: SIMD3<Double> = SIMD3(side.z, 0, -side.x) * (markWidth / 2)
                    let across: SIMD3<Double> = side * (markWidth / 2)
                    try parts.fan(centre: c, outline: [c - along - across, c + along - across, c + along + across,
                                                       c - along + across],
                                  material: .markFilled, slot: slot, colour: colour(.markFilled))
                } else {
                    try parts.ring(centre: c, radius: (markWidth - markLine) / 2, line: markLine,
                                   segments: markSegments, material: .markHollow, slot: slot,
                                   colour: colour(.markHollow))
                }
            }
        }
        // Islands, back to front.
        for index in islandOrder(snapshot) {
            try parts.prism(centre: islandCentre(index, snapshot), radius: islandRadius, height: islandHeight)
        }
        // Pips.
        let brokenAt: Int? = brokenStep(snapshot)
        let half: Double = pipWidth / 2
        for index in 0..<snapshot.steps {
            let c: SIMD3<Double> = stepPip(index, snapshot)
            if index == step {
                try parts.fan(centre: c, outline: [SIMD3(c.x - half, 0, c.z - half), SIMD3(c.x + half, 0, c.z - half),
                                                   SIMD3(c.x + half, 0, c.z + half), SIMD3(c.x - half, 0, c.z + half)],
                              material: .pip, slot: up, colour: colour(.pip))
            } else {
                try parts.frame(centre: c, half: half, line: pipLine, material: .pipUnlit)
            }
            if brokenAt == index {
                try parts.frame(centre: c, half: brokenFrame / 2, line: brokenLine, material: .brokenOutline)
                let w: Double = brokenLine / 2
                let diagonals: [(SIMD3<Double>, SIMD3<Double>)] = [
                    (SIMD3(c.x - half, 0, c.z - half), SIMD3(c.x + half, 0, c.z + half)),
                    (SIMD3(c.x - half, 0, c.z + half), SIMD3(c.x + half, 0, c.z - half)),
                ]
                for (a, b) in diagonals {
                    let d: SIMD3<Double> = unit(b - a)
                    let n: SIMD3<Double> = SIMD3(-d.z, 0, d.x) * w
                    try parts.quad([a - n, b - n, b + n, a + n], front: up, slot: up, material: .brokenOutline,
                                   local: [-1, -1, 1, 1])
                }
            }
        }
        // Gauge.
        let budget: Int = max(snapshot.budget, 0)
        let lit: Int = litBars(snapshot)
        let bar: Double = gaugeFill * gaugeSlot(snapshot) / 2
        let depth: Double = gaugeDepth / 2
        for index in 0..<budget {
            let c: SIMD3<Double> = gaugeBar(index, snapshot)
            let material: Material = index < lit ? .gaugeLit : .gaugeUnlit
            try parts.fan(centre: c, outline: [SIMD3(c.x - bar, gaugeY, c.z - depth), SIMD3(c.x + bar, gaugeY, c.z - depth),
                                               SIMD3(c.x + bar, gaugeY, c.z + depth), SIMD3(c.x - bar, gaugeY, c.z + depth)],
                          material: material, slot: up, colour: colour(material))
        }
        return parts.built()
    }

    /// The glow shells around the drawn step's membranes and reached islands, outermost shell first (shell k =
    /// tier.glowShells … 1): a membrane's shell is its strip widened by 0.01·k per side and lifted k·``edgeLift``; an
    /// island's shell its prism grown by 0.012·k in radius and height. The glow colour in the normal slot,
    /// uv = (0.5^k, won); fallback colours the glow colour times the factor, lifted on a won level. Empty when the tier
    /// has no glow.
    public static func glowPart(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier,
                                reduceMotion: Bool = false) throws(MeshError) -> HarmonicBridgesColouredMesh {
        var parts: Parts = Parts()
        let shells: Int = min(max(tier.glowShells, 0), 2)
        guard shells > 0 else { return parts.built() }
        let step: Int = drawnStep(snapshot, reduceMotion: reduceMotion)
        let won: Double = wonFlag(snapshot)
        let glow: SIMD3<Double> = HarmonicBridgesPalette.glow
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            let tint: SIMD3<Double> = lifted(glow * factor, won: won)
            let slotOf: (Double) -> SIMD3<Double> = { (_: Double) -> SIMD3<Double> in glow }
            for index in snapshot.strings.indices where snapshot.isBridge(index, step: step) {
                try parts.strip(snapshot, string: index, y: membraneY + edgeLift * Double(k),
                                band: 0...(membraneWidth / 2 + membraneGlowGrowth * Double(k)), material: .membrane,
                                segments: 1, slot: slotOf, colour: tint, code: factor, fixedLocal: won)
            }
            for index in islandOrder(snapshot) where snapshot.isReached(index, step: step) {
                try parts.prism(centre: islandCentre(index, snapshot), radius: islandRadius + islandGlowGrowth * Double(k),
                                height: islandHeight + islandGlowGrowth * Double(k),
                                glow: (slot: glow, factor: factor, won: won, colour: tint))
            }
        }
        return parts.built()
    }

    /// The glow mesh for the glow program (`glowPart` without colours).
    public static func glowMesh(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier,
                                reduceMotion: Bool = false) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier, reduceMotion: reduceMotion).mesh
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

    /// The fixed camera for `aspect`: from (0, 1.9, 1.6) looking at (0, 0, 0.1) with +y up; the vertical field of view
    /// is the smallest that holds every corner of the box x −1 … 1, y 0 … 0.2, z −0.7 … 1.0 inside the view with
    /// ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it — every island top,
    /// string and membrane, pip and gauge bar — keeps a margin of at least 5 %). The snapshot is accepted for parity;
    /// the camera never moves while a level is played. Equals ``camera(_:aspect:orbit:)`` at
    /// ``HarmonicBridgesOrbit/authored`` bit for bit.
    public static func camera(_ snapshot: HarmonicBridgesSceneSnapshot, aspect: Double) -> HarmonicBridgesCamera {
        camera(snapshot, aspect: aspect, orbit: .authored)
    }

    /// The vertical axis the orbit yaws about passes through the authored box centre (0, 0.1, 0.15).
    static var orbitPivot: SIMD3<Double> { (boxLow + boxHigh) / 2 }

    /// `p` yawed by `yaw` radians about the vertical axis through ``orbitPivot`` (from +z towards +x).
    static func yawed(_ p: SIMD3<Double>, _ yaw: Double) -> SIMD3<Double> {
        let c: Double = cos(yaw)
        let s: Double = sin(yaw)
        let d: SIMD3<Double> = p - orbitPivot
        return SIMD3(orbitPivot.x + d.x * c + d.z * s, p.y, orbitPivot.z - d.x * s + d.z * c)
    }

    /// The eye and the look-at point of `orbit` (clamped): the authored eye's offset from the look-at point,
    /// e = (0, 1.9, 1.5), pitched about the x axis (positive p raises it: (0, e.y·cos p + e.z·sin p,
    /// −e.y·sin p + e.z·cos p)) and added to the look-at point; then both points yawed about the vertical axis through
    /// ``orbitPivot``. Exactly ``eye`` and ``lookAt`` at the authored orbit.
    static func orbitView(_ orbit: HarmonicBridgesOrbit) -> (eye: SIMD3<Double>, target: SIMD3<Double>) {
        let o: HarmonicBridgesOrbit = orbit.clamped()
        guard o.yaw != 0 || o.pitch != 0 else { return (eye: eye, target: lookAt) }
        let e: SIMD3<Double> = eye - lookAt
        let cp: Double = cos(o.pitch)
        let sp: Double = sin(o.pitch)
        let pitched: SIMD3<Double> = lookAt + SIMD3(e.x, e.y * cp + e.z * sp, -e.y * sp + e.z * cp)
        return (eye: yawed(pitched, o.yaw), target: yawed(lookAt, o.yaw))
    }

    /// The camera for `orbit` (clamped, see ``HarmonicBridgesOrbit/clamped()``) and `aspect`: from the orbit's eye
    /// looking at its look-at point (``orbitView(_:)``) with +y up (never parallel: the eye stays at least 36° above the
    /// ground); the vertical field of view is the smallest that holds every corner of the box x −1 … 1, y 0 … 0.2,
    /// z −0.7 … 1.0 inside the view with ``fitMargin`` per side, so everything inside the box — every island top, string
    /// end, pip and gauge bar — keeps a margin of at least 5 % at every orbit and aspect 0.4 … 2.5. Presentation only;
    /// independent of the snapshot, the tier and the time.
    public static func camera(_ snapshot: HarmonicBridgesSceneSnapshot, aspect: Double,
                              orbit: HarmonicBridgesOrbit) -> HarmonicBridgesCamera {
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
        return HarmonicBridgesCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far, view: view,
                                     projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: HarmonicBridgesCamera) -> SIMD2<Double>? {
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
            let id: UInt32 = try builder.vertex(HarmonicBridgesSceneGeometry.vec(p),
                                                normal: HarmonicBridgesSceneGeometry.vec(slot), uv: Vec2(code, local))
            if Int(id) == colours.count {
                colours.append(Vec4(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from the side `front` points to; degenerate triangles are
        /// skipped.
        mutating func facing(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                             _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
            let n: SIMD3<Double> = HarmonicBridgesSceneGeometry.cross(pb - pa, pc - pa)
            let side: Double = HarmonicBridgesSceneGeometry.dot(n, front)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A convex quad (corners in order) facing `front`, normal slot `slot`, local coordinates `local` per corner,
        /// in the material's colour (or `colour`) with uv.x the material code (or `code`).
        mutating func quad(_ p: [SIMD3<Double>], front: SIMD3<Double>, slot: SIMD3<Double>, material: Material,
                           local: [Double], colour: SIMD3<Double>? = nil, code: Double? = nil) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? HarmonicBridgesSceneGeometry.colour(material)
            let value: Double = code ?? Double(material.rawValue)
            var ids: [UInt32] = []
            for k in 0..<4 { ids.append(try vertex(p[k], slot: slot, code: value, local: local[k], colour: tint)) }
            try facing((ids[0], ids[1], ids[2]), p[0], p[1], p[2], front: front)
            try facing((ids[0], ids[2], ids[3]), p[0], p[2], p[3], front: front)
        }

        /// A flat fan facing +y: the centre vertex (d = 0) and the outline's corners (d = 1).
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], material: Material, slot: SIMD3<Double>,
                          colour: SIMD3<Double>) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let code: Double = Double(material.rawValue)
            let c: UInt32 = try vertex(centre, slot: slot, code: code, local: 0, colour: colour)
            var ids: [UInt32] = []
            for p in outline { ids.append(try vertex(p, slot: slot, code: code, local: 1, colour: colour)) }
            for k in 0..<outline.count {
                let j: Int = (k + 1) % outline.count
                try facing((c, ids[k], ids[j]), centre, outline[k], outline[j], front: up)
            }
        }

        /// A flat ring facing +y around `centre` (its plane), line centred on `radius`, d = −1 inside, +1 outside.
        mutating func ring(centre: SIMD3<Double>, radius: Double, line: Double, segments: Int, material: Material,
                           slot: SIMD3<Double>, colour: SIMD3<Double>) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let inner: Double = radius - line / 2
            let outer: Double = radius + line / 2
            for i in 0..<segments {
                let a0: Double = 2 * Double.pi * Double(i) / Double(segments)
                let a1: Double = 2 * Double.pi * Double(i + 1) / Double(segments)
                let d0: SIMD3<Double> = SIMD3(cos(a0), 0, sin(a0))
                let d1: SIMD3<Double> = SIMD3(cos(a1), 0, sin(a1))
                try quad([centre + d0 * inner, centre + d0 * outer, centre + d1 * outer, centre + d1 * inner],
                         front: up, slot: slot, material: material, local: [-1, 1, 1, -1], colour: colour)
            }
        }

        /// A square frame facing +y (outer half side `half`, line `line`), d = −1 inside, +1 outside.
        mutating func frame(centre: SIMD3<Double>, half: Double, line: Double, material: Material) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let o: Double = half
            let i: Double = half - line
            let outer: [SIMD3<Double>] = [SIMD3(centre.x - o, centre.y, centre.z - o), SIMD3(centre.x + o, centre.y, centre.z - o),
                                          SIMD3(centre.x + o, centre.y, centre.z + o), SIMD3(centre.x - o, centre.y, centre.z + o)]
            let inner: [SIMD3<Double>] = [SIMD3(centre.x - i, centre.y, centre.z - i), SIMD3(centre.x + i, centre.y, centre.z - i),
                                          SIMD3(centre.x + i, centre.y, centre.z + i), SIMD3(centre.x - i, centre.y, centre.z + i)]
            for k in 0..<4 {
                let j: Int = (k + 1) % 4
                try quad([inner[k], outer[k], outer[j], inner[j]], front: up, slot: up, material: material,
                         local: [-1, 1, 1, -1])
            }
        }

        /// A strip along string `string` on the plane `y`, in `segments` segments, covering the band `band` of distances
        /// from the axis on both sides (a band from 0: one strip, d = −1 on the side −side, +1 on +side; a band from
        /// above 0: two strips, d = −1 at the inner edge, +1 at the outer). `slot(u)` gives the normal slot at u;
        /// `code` (when given) replaces the material code and `fixedLocal` every local coordinate (glow shells).
        mutating func strip(_ snapshot: HarmonicBridgesSceneSnapshot, string: Int, y: Double, band: ClosedRange<Double>,
                            material: Material, segments: Int, slot: (Double) -> SIMD3<Double>, colour: SIMD3<Double>,
                            code: Double? = nil, fixedLocal: Double? = nil) throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            let side: SIMD3<Double> = HarmonicBridgesSceneGeometry.stringSide(string, snapshot)
            var lanes: [(near: Double, far: Double, dNear: Double, dFar: Double)] = []
            if band.lowerBound <= 0 {
                lanes.append((near: -band.upperBound, far: band.upperBound, dNear: -1, dFar: 1))
            } else {
                lanes.append((near: band.lowerBound, far: band.upperBound, dNear: -1, dFar: 1))
                lanes.append((near: -band.lowerBound, far: -band.upperBound, dNear: -1, dFar: 1))
            }
            for lane in lanes {
                for i in 0..<segments {
                    let u0: Double = Double(i) / Double(segments)
                    let u1: Double = Double(i + 1) / Double(segments)
                    let p0: SIMD3<Double> = HarmonicBridgesSceneGeometry.stringPoint(string, u: u0, y: y, snapshot)
                    let p1: SIMD3<Double> = HarmonicBridgesSceneGeometry.stringPoint(string, u: u1, y: y, snapshot)
                    let corners: [SIMD3<Double>] = [p0 + side * lane.near, p1 + side * lane.near, p1 + side * lane.far,
                                                    p0 + side * lane.far]
                    let value: Double = code ?? Double(material.rawValue)
                    let locals: [Double] = [lane.dNear, lane.dNear, lane.dFar, lane.dFar]
                    let us: [Double] = [u0, u1, u1, u0]
                    var ids: [UInt32] = []
                    for k in 0..<4 {
                        ids.append(try vertex(corners[k], slot: slot(us[k]), code: value, local: fixedLocal ?? locals[k],
                                              colour: colour))
                    }
                    try facing((ids[0], ids[1], ids[2]), corners[0], corners[1], corners[2], front: up)
                    try facing((ids[0], ids[2], ids[3]), corners[0], corners[2], corners[3], front: up)
                }
            }
        }

        /// A hexagonal prism standing on the ground at `centre` (vertex radius `radius`, a vertex on +x, height
        /// `height`): six sides and the top (the hidden bottom omitted), each wound outward; then (without `glow`) its
        /// six top edges as strips folded over the edge. With `glow`, every face carries the glow slot and uv
        /// (factor, won) in the glow colour, and no edge strips are added.
        mutating func prism(centre: SIMD3<Double>, radius: Double, height: Double,
                            glow: (slot: SIMD3<Double>, factor: Double, won: Double, colour: SIMD3<Double>)? = nil)
            throws(MeshError) {
            let up: SIMD3<Double> = SIMD3(0, 1, 0)
            var ring: [SIMD3<Double>] = []
            for i in 0..<6 {
                let angle: Double = Double(i) * Double.pi / 3
                ring.append(SIMD3(centre.x + radius * cos(angle), 0, centre.z + radius * sin(angle)))
            }
            let top: SIMD3<Double> = SIMD3(centre.x, height, centre.z)
            for i in 0..<6 {
                let j: Int = (i + 1) % 6
                let mid: Double = (Double(i) + 0.5) * Double.pi / 3
                let n: SIMD3<Double> = SIMD3(cos(mid), 0, sin(mid))
                let corners: [SIMD3<Double>] = [ring[i], ring[j], ring[j] + up * height, ring[i] + up * height]
                if let glow {
                    try quad(corners, front: n, slot: glow.slot, material: .islandFace, local: [glow.won, glow.won,
                                                                                                glow.won, glow.won],
                             colour: glow.colour, code: glow.factor)
                } else {
                    try quad(corners, front: n, slot: n, material: .islandFace, local: [0, 0, 0, 0])
                }
            }
            // Top cap.
            let faceCode: Double = glow?.factor ?? Double(Material.islandFace.rawValue)
            let faceSlot: SIMD3<Double> = glow?.slot ?? up
            let faceColour: SIMD3<Double> = glow?.colour ?? HarmonicBridgesSceneGeometry.colour(.islandFace)
            let faceLocal: Double = glow?.won ?? 0
            let c: UInt32 = try vertex(top, slot: faceSlot, code: faceCode, local: faceLocal, colour: faceColour)
            var ids: [UInt32] = []
            for p in ring {
                ids.append(try vertex(p + up * height, slot: faceSlot, code: faceCode, local: faceLocal,
                                      colour: faceColour))
            }
            for i in 0..<6 {
                let j: Int = (i + 1) % 6
                try facing((c, ids[i], ids[j]), top, ring[i] + up * height, ring[j] + up * height, front: up)
            }
            guard glow == nil else { return }
            // Top edge strips: half on the top (inward), half down the side, d = 0 on the edge.
            let halfWidth: Double = HarmonicBridgesSceneGeometry.edgeThickness / 2
            let lift: Double = HarmonicBridgesSceneGeometry.edgeLift
            for i in 0..<6 {
                let j: Int = (i + 1) % 6
                let mid: Double = (Double(i) + 0.5) * Double.pi / 3
                let n: SIMD3<Double> = SIMD3(cos(mid), 0, sin(mid))
                let a: SIMD3<Double> = ring[i] + up * height
                let b: SIMD3<Double> = ring[j] + up * height
                let lean: SIMD3<Double> = HarmonicBridgesSceneGeometry.unit(n + up) * lift
                let folds: [(direction: SIMD3<Double>, normal: SIMD3<Double>, d: Double)] = [
                    (direction: -n, normal: up, d: -1), (direction: -up, normal: n, d: 1),
                ]
                for fold in folds {
                    let offset: SIMD3<Double> = fold.direction * halfWidth + fold.normal * lift
                    try quad([a + lean, b + lean, b + offset, a + offset], front: fold.normal, slot: fold.normal,
                             material: .islandEdge, local: [0, 0, fold.d, fold.d])
                }
            }
        }

        /// The coloured mesh built so far.
        func built() -> HarmonicBridgesColouredMesh {
            HarmonicBridgesColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
