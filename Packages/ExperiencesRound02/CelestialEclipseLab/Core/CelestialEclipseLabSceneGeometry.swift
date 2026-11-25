// CelestialEclipseLabSceneGeometry — feature 463 (R02-G17-03) T-R02G1703-004 (FR-R02G1703-001, 002, 004, 006;
// SC-R02G1703-001, 003; clarifications Q1, Q2). The sky of Celestial Eclipse Lab, built from a snapshot only. x points
// right, y up and z towards the default viewer (a greater z is nearer in the rules). A lattice position v maps to world
// space by w(v) = (v − m) · s, where m is the centre of the bounding box of every orbit position of every body widened
// by that body's radius in x and y, and s = 1.5 / (e + 1) with e the box's largest extent, so no disc (centre ± r · s)
// leaves the square −0.75 … 0.75 in x and y at any tick. Bodies are drawn at w(position(at: shown tick, phase)).
//
// Draw order (clarification Q1; depth testing off, so the sky mesh is in painter's order):
//   1. the backdrop, one large quad facing the eye behind the authored box (its gradient and specks are the shader's);
//   2. the elements (``CelestialEclipseLabElement``) by kind — rings, bodies, halos, gauges — the bodies (with their
//      shadow lenses) and halos back to front by the distance of their centres from the eye (ties by index), the rings
//      and the flat gauges by index alone (``CelestialEclipseLabElement/paintsBefore(_:_:)``):
//      - ring i (kind ring, index i): a camera-facing closed ribbon 0.012 wide through w of every orbit position of
//        body i in order, orbit blue; around body i's current centre (index mod 6) + 1 radial notches from r · s +
//        0.018 to r · s + 0.034, the first straight up and the rest evenly spaced anticlockwise; a fixed body also a
//        square frame of half side r · s + 0.055 (0.012 wide);
//      - the chosen ring (kind ring, index = body count): a camera-facing ring of radius r · s + 0.04 (0.012 wide)
//        around the chosen body, dashed by the shader along its angle fraction;
//      - body i (kind body, index i): a sphere of radius r · s (`tier.longitudes` × `tier.latitudes`; a flat
//        camera-facing 20-sided disc at level-2), disc ivory; a body named by the failure ringed in the broken colour
//        at r · s + 0.075 (0.016 wide);
//      - shadow e (kind body, index body count + e, centred on the back body so it is painted right after it): the
//        crescent shadow of eclipse e under way at the shown tick, a fan over ``shadowLens(_:_:segments:)`` — the
//        exact overlap of the front and back circles (world x, y of the kernel positions, radii r · s; the whole
//        back disc when total, the whole front disc when annular) — in the plane z = back z + ``shadowLift`` (never
//        beyond half-way to the front body's z), crescent shadow;
//      - halo e (kind halo, index e of `snapshot.eclipses`): for a total or annular eclipse under way, a camera-facing
//        ring from the front body's rim r · s to r · s + 0.014, corona gold;
//      - the gauges (kind gauge), screen-facing around world points: the timeline strip (index 0) from (−0.9, −1.15,
//        0) to (0.9, −1.15, 0), 0.03 tall, mapping ticks 0 … horizon − 1 (``tickPosition(_:_:)``); bracket k (index
//        1 + k) over target k's window at y = −1.05 (a bar from the open tick − 0.012 to the close tick + 0.012 with
//        two legs 0.03 down, k + 1 square notches 0.014 wide above it; lit gold on a won level; framed in the broken
//        colour for the next target of a horizon failure); mark j (index 1 + T + j) at interval j's first tick on the
//        strip (a filled diamond for a matched event, a cross framed in the broken colour for the failing event, a
//        faint diamond after the last match); the end mark (index 1 + T + I), a broken cross at the strip's end on a
//        horizon failure; the playhead (index 2 + T + I), a vertical line 0.08 tall at the shown tick; actions bar b
//        (index 3 + T + I + b), `budget` bars at y = −1.35 from x = −0.9 to 0.9 (each 1.8 / budget wide with a fifth
//        as gap, 0.04 tall), lit for the actions left. T is the target count and I the interval count.
// The glow mesh is drawn last, additively: `tier.glowShells` shells k (outermost first, factor 0.5^k) as camera-facing
// bands around every halo, the chosen ring and every matched mark, lifted 0.001 · k towards the eye; empty at level-2.
// A won level lights every target bracket (the shader's won uniform; the fallback colours) without moving any position.
//
// Vertex streams (attributes a_position, a_normal, a_uv: the three streams of the shared custom-shader mesh renderer;
// the contract of ``CelestialEclipseLabShaders``, whose material codes these are). Sky mesh: a_uv.x is the material
// code (``materialBackdrop`` 0 … ``materialShadow`` 16). The backdrop: a_uv.y the height 0 (bottom) … 1 (top),
// a_normal.x the horizontal coordinate −1 (left) … +1 (right). Strips (ribbons, notches, frames, legs, the playhead,
// the end mark) and rings: a_uv.y the across coordinate −1 on one side (a ring's inner edge) and +1 on the other;
// a_normal zero except on the chosen ring (a_normal.x the angle fraction 0 … 1, seam repeated with 1) and on a halo
// (a_normal.x 1 for the halo of a matched eclipse, ``isMatched(_:_:)``, else 0). Bodies: a_normal the unit outward
// sphere normal and a_uv.y 0; a level-2 disc a_normal the unit direction towards the eye
// (``CelestialEclipseLabShaders/viewDirection``) and a_uv.y the radial coordinate 0 (centre) … 1 (rim). Marks:
// a_normal.xy the mark-local coordinate (offset from the mark's centre along the view's right and up over ``markSize``;
// a diamond fan (0, 0) at its centre and unit at its corners, a cross's two strips at their corners) with a_uv.y 0 at a
// diamond's centre and 1 on its outline, or the across coordinate on a cross. Fans (bars, bracket notches): a_uv.y 0 at
// the centre and 1 on the outline. Crescent shadows (the renderer binds only these three streams, so the overlap judged
// is geometry, not a mask): a fan with a_uv.y 0 at the lens's centroid and 1 on its outline, a_normal zero,
// ``materialShadow``. Glow mesh: a_normal the base colour, a_uv.x ``glowCode(kind:factor:)`` = 2 · kind + 0.5^k and
// a_uv.y the radial coordinate, 0 inner and 1 outer. The fallback colour streams carry each material's colour
// (``colour(of:)``; the backdrop ink to ink top; the brackets matched gold on a won level). Every triangle winds
// counter-clockwise seen from outside its sphere or from the eye, and the index order is the painter's order. Tiers
// change only the body sphere detail and the glow: every position named above is the same at every tier. Doubles are
// used for drawing only; nothing here is consulted by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct CelestialEclipseLabCamera: Sendable, Equatable {
    /// The eye position in world units, (0.3, 0.2, 3.4).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.25, 0).
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
public struct CelestialEclipseLabElement: Sendable, Equatable {
    /// The kind of an element, in the tie order of the painter's order.
    public enum Kind: Int, Sendable, CaseIterable {
        /// An orbital ring (with its notches and frame) or the chosen ring.
        case ring = 0
        /// A body or a crescent shadow.
        case body = 1
        /// A corona halo.
        case halo = 2
        /// A gauge: the timeline strip, a bracket, a mark, the end mark, the playhead or an actions bar.
        case gauge = 3
    }

    /// What an element draws.
    public enum Part: Int, Sendable, CaseIterable {
        /// Body `item`'s orbital ring with its notches (and frame when fixed).
        case orbit = 0
        /// The chosen body's dashed ring (`item` the chosen body).
        case chosen = 1
        /// Body `item`.
        case body = 2
        /// The halo of eclipse `item` of `snapshot.eclipses`.
        case halo = 3
        /// The timeline strip.
        case strip = 4
        /// Target `item`'s window bracket.
        case bracket = 5
        /// Interval `item`'s event mark.
        case mark = 6
        /// The horizon failure's mark at the strip's end.
        case endMark = 7
        /// The playhead at the shown tick.
        case playhead = 8
        /// Actions bar `item`.
        case bar = 9
        /// The crescent shadow of eclipse `item` of `snapshot.eclipses`.
        case shadow = 10
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind (see ``CelestialEclipseLabSceneGeometry``'s header for the layout).
    public let index: Int
    /// What the element draws.
    public let part: Part
    /// The index within its part: body, eclipse (halo, shadow), target, interval or bar (the chosen body for the
    /// chosen ring, 0 for the single gauges).
    public let item: Int
    /// The element's centre in world units.
    public let centre: SIMD3<Double>
    /// The distance of the centre from the eye.
    public let distance: Double

    /// An element of the given values.
    public init(kind: Kind, index: Int, part: Part, item: Int, centre: SIMD3<Double>, distance: Double) {
        self.kind = kind
        self.index = index
        self.part = part
        self.item = item
        self.centre = centre
        self.distance = distance
    }

    /// Whether `a` is painted before `b`: by kind first (rings, bodies, halos, gauges); bodies (with their shadow
    /// lenses) and halos farther first, then by index; rings and the flat gauges by index alone (the rings lie in the
    /// bodies' layers and the gauges share one plane, so a distance order would paint a ribbon over a body's centre or
    /// the timeline strip over its marks).
    public static func paintsBefore(_ a: CelestialEclipseLabElement, _ b: CelestialEclipseLabElement) -> Bool {
        if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
        if a.kind == .body || a.kind == .halo, a.distance != b.distance { return a.distance > b.distance }
        return a.index < b.index
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct CelestialEclipseLabColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Celestial Eclipse Lab scene from a `CelestialEclipseLabSceneSnapshot`: places, meshes, camera and
/// projection.
public enum CelestialEclipseLabSceneGeometry {
    // MARK: Material codes (a_uv.x of the sky mesh)

    /// The backdrop.
    public static let materialBackdrop: Double = 0
    /// An orbital ring ribbon.
    public static let materialRing: Double = 1
    /// A body's notch.
    public static let materialNotch: Double = 2
    /// A fixed body's square frame.
    public static let materialFrame: Double = 3
    /// A body (sphere or level-2 disc).
    public static let materialBody: Double = 4
    /// A corona halo.
    public static let materialHalo: Double = 5
    /// The chosen body's dashed ring.
    public static let materialChosen: Double = 6
    /// The timeline strip.
    public static let materialStrip: Double = 7
    /// A target window's bracket and its notches.
    public static let materialBracket: Double = 8
    /// A matched event's filled diamond.
    public static let materialDiamond: Double = 9
    /// The failing event's cross.
    public static let materialCross: Double = 10
    /// A faint event mark (after the last match).
    public static let materialFaint: Double = 11
    /// The playhead.
    public static let materialPlayhead: Double = 12
    /// A lit actions bar.
    public static let materialBar: Double = 13
    /// An unlit actions bar.
    public static let materialBarUnlit: Double = 14
    /// What a failure names (outlines, frames, the horizon's end mark).
    public static let materialBroken: Double = 15
    /// A crescent shadow (the overlap of an eclipse's discs).
    public static let materialShadow: Double = 16
    /// The number of material codes (0 … 16, the codes of ``CelestialEclipseLabShaders``).
    public static let materialCount: Int = 17

    // MARK: Glow kinds (a_uv.x of the glow mesh is 2 · kind + factor)

    /// A glow shell around a halo.
    public static let glowHalo: Int = 0
    /// A glow shell around the halo of a matched eclipse.
    public static let glowMatchedHalo: Int = 1
    /// A glow shell around the chosen ring.
    public static let glowChosen: Int = 2
    /// A glow shell around a matched mark.
    public static let glowMark: Int = 3

    /// The glow mesh's a_uv.x for glow kind `kind` and shell factor `factor` (0 … 1): 2 · kind + factor.
    public static func glowCode(kind: Int, factor: Double) -> Double {
        Double(2 * kind) + (factor.isFinite ? min(max(factor, 0), 1) : 0)
    }

    // MARK: Constants (world units)

    /// The span every disc fits: s = span / (e + 1).
    public static let span: Double = 1.5
    /// An orbital ring ribbon's width.
    public static let ringWidth: Double = 0.012
    /// A notch's inner end beyond the body's radius.
    public static let notchInner: Double = 0.018
    /// A notch's outer end beyond the body's radius.
    public static let notchOuter: Double = 0.034
    /// A notch's width.
    public static let notchWidth: Double = 0.008
    /// A fixed body's frame: half side beyond the body's radius.
    public static let frameOffset: Double = 0.055
    /// A fixed body's frame width.
    public static let frameWidth: Double = 0.012
    /// A halo's width outward from the front body's rim.
    public static let haloWidth: Double = 0.014
    /// The chosen ring's radius beyond the body's radius.
    public static let chosenOffset: Double = 0.04
    /// The chosen ring's width.
    public static let chosenWidth: Double = 0.012
    /// A failure outline's radius beyond the body's radius.
    public static let outlineOffset: Double = 0.075
    /// A failure outline's (and a broken frame's) width.
    public static let outlineWidth: Double = 0.016
    /// The segments of every ring and halo.
    public static let ringSegments: Int = 48
    /// The gauges' plane.
    public static let gaugeZ: Double = 0
    /// The timeline strip's centre line.
    public static let timelineY: Double = -1.15
    /// The gauges' left end.
    public static let gaugeStart: Double = -0.9
    /// The gauges' right end.
    public static let gaugeEnd: Double = 0.9
    /// The timeline strip's height.
    public static let stripHeight: Double = 0.03
    /// The brackets' line.
    public static let bracketY: Double = -1.05
    /// A bracket's line width.
    public static let bracketLine: Double = 0.008
    /// A bracket's overhang beyond its window's end ticks.
    public static let bracketOverhang: Double = 0.012
    /// A bracket leg's length (downward).
    public static let bracketLeg: Double = 0.03
    /// The bracket notches' centre line.
    public static let bracketNotchY: Double = -1.025
    /// A bracket notch's side.
    public static let bracketNotchSide: Double = 0.014
    /// The spacing of bracket notches.
    public static let bracketNotchSpacing: Double = 0.024
    /// An event mark's half diagonal.
    public static let markSize: Double = 0.025
    /// A cross's stroke width.
    public static let crossWidth: Double = 0.01
    /// A broken frame's inner half size around a mark.
    public static let markFrame: Double = 0.035
    /// The playhead's half height.
    public static let playheadHalf: Double = 0.04
    /// The playhead's width.
    public static let playheadWidth: Double = 0.008
    /// The actions bars' centre line.
    public static let barsY: Double = -1.35
    /// The share of a slot an actions bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// An actions bar's height.
    public static let barHeight: Double = 0.04
    /// How far a crescent shadow's plane sits in front of the back body's centre (towards +z).
    public static let shadowLift: Double = 0.001
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// A halo's glow growth per shell.
    public static let haloGlowGrowth: Double = 0.03
    /// The chosen ring's glow growth per shell.
    public static let chosenGlowGrowth: Double = 0.025
    /// A matched mark's glow growth per shell.
    public static let markGlowGrowth: Double = 0.015
    /// The sides of a glow band.
    public static let glowSides: Int = 24
    /// Lift towards the eye per glow shell.
    public static let glowLift: Double = 0.001
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(0.3, 0.2, 3.4)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.25, 0)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-0.95, -1.45, -0.95)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(0.95, 0.95, 0.95)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places (the CPU reference)

    /// The bounding box (lower and upper corner, in lattice units) of every orbit position of every body, widened by
    /// that body's radius in x and y.
    static func bounds(_ snapshot: CelestialEclipseLabSceneSnapshot) -> (low: SIMD3<Double>, high: SIMD3<Double>) {
        var low: SIMD3<Double>? = nil
        var high: SIMD3<Double> = SIMD3(0, 0, 0)
        for body in snapshot.bodies {
            let r: Double = Double(body.radius)
            for v in body.orbit {
                let a: SIMD3<Double> = SIMD3(Double(v.x) - r, Double(v.y) - r, Double(v.z))
                let b: SIMD3<Double> = SIMD3(Double(v.x) + r, Double(v.y) + r, Double(v.z))
                if let l = low {
                    low = SIMD3(min(l.x, a.x), min(l.y, a.y), min(l.z, a.z))
                    high = SIMD3(max(high.x, b.x), max(high.y, b.y), max(high.z, b.z))
                } else {
                    low = a
                    high = b
                }
            }
        }
        return (low ?? SIMD3(0, 0, 0), high)
    }

    /// The centre m of the widened bounding box of every orbit position of every body, in lattice units.
    public static func middle(_ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        let box: (low: SIMD3<Double>, high: SIMD3<Double>) = bounds(snapshot)
        return (box.low + box.high) / 2
    }

    /// The lattice scale s = 1.5 / (e + 1), e the largest extent of the widened box.
    public static func scale(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Double {
        let box: (low: SIMD3<Double>, high: SIMD3<Double>) = bounds(snapshot)
        let extent: SIMD3<Double> = box.high - box.low
        return span / (max(extent.x, extent.y, extent.z) + 1)
    }

    /// The world point of lattice position `position`: w(v) = (v − m) · s.
    public static func world(_ position: CelestialEclipseLabVector,
                             _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        let v: SIMD3<Double> = SIMD3(Double(position.x), Double(position.y), Double(position.z))
        return (v - middle(snapshot)) * scale(snapshot)
    }

    /// `index` clamped to 0 … count − 1 (0 when count is 0).
    static func clamped(_ index: Int, _ count: Int) -> Int { min(max(index, 0), max(count - 1, 0)) }

    /// The centre of body `index` (clamped) at the shown tick: w(positions[index]).
    public static func bodyCentre(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.positions.isEmpty else { return SIMD3(0, 0, 0) }
        return world(snapshot.positions[clamped(index, snapshot.positions.count)], snapshot)
    }

    /// The drawn radius r · s of body `index` (clamped; 0 without bodies).
    public static func bodyRadius(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> Double {
        guard !snapshot.bodies.isEmpty else { return 0 }
        return Double(snapshot.bodies[clamped(index, snapshot.bodies.count)].radius) * scale(snapshot)
    }

    /// The centre of body `index`'s orbital ring: the mean of w of its orbit positions.
    public static func ringCentre(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.bodies.isEmpty else { return SIMD3(0, 0, 0) }
        let orbit: [CelestialEclipseLabVector] = snapshot.bodies[clamped(index, snapshot.bodies.count)].orbit
        guard !orbit.isEmpty else { return SIMD3(0, 0, 0) }
        var sum: SIMD3<Double> = SIMD3(0, 0, 0)
        for v in orbit { sum += world(v, snapshot) }
        return sum / Double(orbit.count)
    }

    /// The crescent shadow of `eclipse` as a closed outline in world x and y, anticlockwise seen from +z (the last
    /// point is not repeated): the overlap of the front circle and the back circle (centres the world x and y of the
    /// two bodies' kernel positions at the shown tick, radii r · s). Total: the back circle in `segments` points;
    /// annular: the front circle; partial: the lens of the front circle's arc inside the back circle and the back
    /// circle's arc inside the front circle, `segments` points split between the arcs by their angles (at least 2
    /// pieces each). Empty for an eclipse that is not under way at the shown tick or names a body the level lacks.
    public static func shadowLens(_ eclipse: CelestialEclipseLabEclipse, _ snapshot: CelestialEclipseLabSceneSnapshot,
                                  segments: Int = 48) -> [SIMD2<Double>] {
        let count: Int = snapshot.bodies.count
        guard eclipse.front >= 0, eclipse.front < count, eclipse.back >= 0, eclipse.back < count,
              eclipse.front != eclipse.back, snapshot.eclipses.contains(eclipse) else { return [] }
        let n: Int = max(segments, 8)
        let fc: SIMD3<Double> = bodyCentre(eclipse.front, snapshot)
        let bc: SIMD3<Double> = bodyCentre(eclipse.back, snapshot)
        let a: SIMD2<Double> = SIMD2(fc.x, fc.y)
        let b: SIMD2<Double> = SIMD2(bc.x, bc.y)
        let ra: Double = bodyRadius(eclipse.front, snapshot)
        let rb: Double = bodyRadius(eclipse.back, snapshot)
        func arc(_ c: SIMD2<Double>, _ r: Double, from start: Double, to end: Double, pieces: Int,
                 ends: Bool) -> [SIMD2<Double>] {
            var points: [SIMD2<Double>] = []
            for k in 0...pieces {
                if !ends && (k == 0 || k == pieces) { continue }
                let t: Double = start + (end - start) * Double(k) / Double(pieces)
                points.append(c + SIMD2(cos(t), sin(t)) * r)
            }
            return points
        }
        switch eclipse.visibility {
        case .total:
            return Array(arc(b, rb, from: 0, to: 2 * Double.pi, pieces: n, ends: true).dropLast())
        case .annular:
            return Array(arc(a, ra, from: 0, to: 2 * Double.pi, pieces: n, ends: true).dropLast())
        case .partial:
            let d: SIMD2<Double> = b - a
            let distance: Double = (d.x * d.x + d.y * d.y).squareRoot()
            guard distance > 0, distance < ra + rb else { return [] }
            let theta: Double = atan2(d.y, d.x)
            let alpha: Double = acos(min(max((distance * distance + ra * ra - rb * rb) / (2 * distance * ra), -1), 1))
            let beta: Double = acos(min(max((distance * distance + rb * rb - ra * ra) / (2 * distance * rb), -1), 1))
            let share: Int = Int((Double(n) * alpha / max(alpha + beta, 1e-12)).rounded())
            let pa: Int = min(max(share, 2), n - 2)
            let pb: Int = n - pa
            var outline: [SIMD2<Double>] = arc(a, ra, from: theta - alpha, to: theta + alpha, pieces: pa, ends: true)
            let phi: Double = theta + Double.pi
            outline += arc(b, rb, from: phi - beta, to: phi + beta, pieces: pb, ends: false)
            return outline
        }
    }

    /// The plane of `eclipse`'s shadow: the back body's z plus ``shadowLift``, at most half-way to the front body's
    /// z when that is nearer.
    public static func shadowZ(_ eclipse: CelestialEclipseLabEclipse,
                               _ snapshot: CelestialEclipseLabSceneSnapshot) -> Double {
        let back: Double = bodyCentre(eclipse.back, snapshot).z
        let front: Double = bodyCentre(eclipse.front, snapshot).z
        return front > back ? back + min(shadowLift, (front - back) / 2) : back + shadowLift
    }

    /// Whether the eclipse's class at the shown tick draws a halo: total or annular.
    public static func hasHalo(_ eclipse: CelestialEclipseLabEclipse) -> Bool { eclipse.visibility != .partial }

    /// The timeline strip's centre, (0, −1.15, 0).
    public static func timelineCentre() -> SIMD3<Double> { SIMD3((gaugeStart + gaugeEnd) / 2, timelineY, gaugeZ) }

    /// The point of tick `tick` on the timeline: (−0.9 + 1.8 · tick / (horizon − 1), −1.15, 0) (not clamped).
    public static func tickPosition(_ tick: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        let last: Double = Double(max(snapshot.horizon - 1, 1))
        return SIMD3(gaugeStart + (gaugeEnd - gaugeStart) * Double(tick) / last, timelineY, gaugeZ)
    }

    /// The left and right x of target `index`'s bracket: the open tick − 0.012 and the close tick + 0.012.
    public static func bracketEnds(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> (Double, Double) {
        guard !snapshot.target.isEmpty else { return (0, 0) }
        let t: CelestialEclipseLabTarget = snapshot.target[clamped(index, snapshot.target.count)]
        return (tickPosition(t.open, snapshot).x - bracketOverhang, tickPosition(t.close, snapshot).x + bracketOverhang)
    }

    /// The centre of target `index`'s bracket: (the middle of its ends, −1.05, 0).
    public static func bracketCentre(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        let ends: (Double, Double) = bracketEnds(index, snapshot)
        return SIMD3((ends.0 + ends.1) / 2, bracketY, gaugeZ)
    }

    /// The notch count of target `index`'s bracket: index + 1.
    public static func bracketNotches(_ index: Int) -> Int { max(index, 0) + 1 }

    /// The playhead's centre: the shown tick's point on the timeline.
    public static func playhead(_ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        tickPosition(snapshot.shownTick, snapshot)
    }

    /// The width of one actions slot, 1.8 / budget.
    public static func actionsSlot(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Double {
        (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of actions bar `index`: (−0.9 + (index + 0.5) · slot, −1.35, 0).
    public static func actionsBar(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * actionsSlot(snapshot), barsY, gaugeZ)
    }

    /// The actions bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litActions(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// Whether the level is won (stage won, or the result shown without a failure). A won level lights every target
    /// bracket; no position changes.
    public static func isWon(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Bool {
        snapshot.stage == .won || (snapshot.stage == .result && snapshot.failure == nil)
    }

    /// The two bodies the failure names (front, back), nil without a failure.
    public static func failureBodies(_ snapshot: CelestialEclipseLabSceneSnapshot) -> (front: Int, back: Int)? {
        switch snapshot.failure {
        case .unwanted(let front, let back, _), .window(let front, let back, _, _, _),
             .horizon(let front, let back, _, _):
            return (front: front, back: back)
        case nil:
            return nil
        }
    }

    /// The interval of the failing event of an unwanted or window failure: the first interval from the matched count
    /// on with the failure's bodies and tick; nil otherwise.
    public static func failingInterval(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Int? {
        let wanted: (front: Int, back: Int, tick: Int)
        switch snapshot.failure {
        case .unwanted(let front, let back, let tick), .window(let front, let back, let tick, _, _):
            wanted = (front, back, tick)
        default:
            return nil
        }
        for j in snapshot.intervals.indices where j >= snapshot.matched {
            let i: CelestialEclipseLabInterval = snapshot.intervals[j]
            if i.front == wanted.front && i.back == wanted.back && i.first == wanted.tick { return j }
        }
        return nil
    }

    /// Whether the failure is the horizon's (marked at the strip's end with the next target's bracket framed).
    public static func isHorizonFailure(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Bool {
        if case .horizon = snapshot.failure { return true }
        return false
    }

    /// The bracket a horizon failure frames: the next target (the matched count, clamped), nil otherwise.
    public static func framedBracket(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Int? {
        guard isHorizonFailure(snapshot), !snapshot.target.isEmpty else { return nil }
        return clamped(snapshot.matched, snapshot.target.count)
    }

    /// The material of interval `index`'s mark: a matched diamond before the matched count, the failing cross, else a
    /// faint diamond.
    public static func markMaterial(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> Double {
        if index < snapshot.matched { return materialDiamond }
        if failingInterval(snapshot) == index { return materialCross }
        return materialFaint
    }

    /// The notch count of body `index`'s ring: (index mod 6) + 1.
    public static func notchCount(_ index: Int) -> Int { ((index % 6) + 6) % 6 + 1 }

    /// Every element with its centre and distance from `camera`'s eye, in painter's order (by kind; bodies and halos
    /// farthest first; rings and gauges by index; clarification Q1).
    public static func paintOrder(_ snapshot: CelestialEclipseLabSceneSnapshot,
                                  camera: CelestialEclipseLabCamera) -> [CelestialEclipseLabElement] {
        elements(snapshot, eye: camera.eye)
    }

    /// The CPU reference points (clarification Q3) in painter's order: every body's centre, the timeline strip's
    /// centre, each target bracket, the playhead and the first actions bar.
    public static func referencePoints(_ snapshot: CelestialEclipseLabSceneSnapshot,
                                       camera: CelestialEclipseLabCamera) -> [CelestialEclipseLabElement] {
        var points: [CelestialEclipseLabElement] = []
        for element in paintOrder(snapshot, camera: camera) {
            switch element.part {
            case .body, .strip, .bracket, .playhead: points.append(element)
            case .bar where element.item == 0: points.append(element)
            default: break
            }
        }
        return points
    }

    /// The elements in painter's order seen from `eye`.
    static func elements(_ snapshot: CelestialEclipseLabSceneSnapshot,
                         eye: SIMD3<Double>) -> [CelestialEclipseLabElement] {
        var list: [CelestialEclipseLabElement] = []
        func add(_ kind: CelestialEclipseLabElement.Kind, _ index: Int, _ part: CelestialEclipseLabElement.Part,
                 _ item: Int, _ centre: SIMD3<Double>) {
            let d: SIMD3<Double> = centre - eye
            list.append(CelestialEclipseLabElement(kind: kind, index: index, part: part, item: item, centre: centre,
                                                   distance: dot(d, d).squareRoot()))
        }
        let count: Int = snapshot.bodies.count
        for index in 0..<count { add(.ring, index, .orbit, index, ringCentre(index, snapshot)) }
        if count > 0 {
            let chosen: Int = clamped(snapshot.chosenBody, count)
            add(.ring, count, .chosen, chosen, bodyCentre(chosen, snapshot))
        }
        for index in 0..<count { add(.body, index, .body, index, bodyCentre(index, snapshot)) }
        for index in snapshot.eclipses.indices {
            let e: CelestialEclipseLabEclipse = snapshot.eclipses[index]
            guard e.back >= 0, e.back < count else { continue }
            add(.body, count + index, .shadow, index, bodyCentre(e.back, snapshot))
        }
        for index in snapshot.eclipses.indices where hasHalo(snapshot.eclipses[index]) {
            add(.halo, index, .halo, index, bodyCentre(snapshot.eclipses[index].front, snapshot))
        }
        let targets: Int = snapshot.target.count
        let intervals: Int = snapshot.intervals.count
        add(.gauge, 0, .strip, 0, timelineCentre())
        for k in 0..<targets { add(.gauge, 1 + k, .bracket, k, bracketCentre(k, snapshot)) }
        for j in 0..<intervals {
            add(.gauge, 1 + targets + j, .mark, j, tickPosition(snapshot.intervals[j].first, snapshot))
        }
        if isHorizonFailure(snapshot) {
            add(.gauge, 1 + targets + intervals, .endMark, 0, tickPosition(snapshot.horizon - 1, snapshot))
        }
        add(.gauge, 2 + targets + intervals, .playhead, 0, playhead(snapshot))
        for b in 0..<max(snapshot.budget, 0) {
            add(.gauge, 3 + targets + intervals + b, .bar, b, actionsBar(b, snapshot))
        }
        list.sort(by: CelestialEclipseLabElement.paintsBefore)
        return list
    }

    /// The fallback colour of material code `code` (unlit; the backdrop's bottom colour; broken for an unknown code).
    public static func colour(of code: Double) -> SIMD3<Double> {
        typealias P = CelestialEclipseLabPalette
        switch code {
        case materialBackdrop: return P.ink
        case materialRing, materialNotch, materialStrip: return P.orbit
        case materialFrame: return P.fixedFrame
        case materialBody: return P.disc
        case materialHalo: return P.corona
        case materialChosen: return P.chosen
        case materialBracket: return P.window
        case materialDiamond: return P.matched
        case materialCross: return P.unwanted
        case materialPlayhead: return P.playhead
        case materialBar: return P.actionsLit
        case materialBarUnlit: return P.actionsUnlit
        case materialFaint: return P.faintEvent
        case materialShadow: return P.crescentShadow
        default: return P.broken
        }
    }

    // MARK: Meshes

    /// The sky mesh for the sky program, in painter's order (see the header).
    public static func skyMesh(_ snapshot: CelestialEclipseLabSceneSnapshot,
                               tier: CelestialEclipseLabTier) throws(MeshError) -> Mesh {
        try skyPart(snapshot, tier: tier).mesh
    }

    /// The glow mesh for the glow program (`glowPart` without colours); empty at level-2.
    public static func glowMesh(_ snapshot: CelestialEclipseLabSceneSnapshot,
                                tier: CelestialEclipseLabTier) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier).mesh
    }

    /// The whole sky with fallback colours (unlit palette colours; the backdrop from ink at its bottom to ink top at
    /// its top; on a won level the brackets in the matched colour) for the shared unlit renderer: the same mesh as
    /// ``skyMesh(_:tier:)`` (the shader lights the brackets from its won uniform). `wonLevel` overrides ``isWon(_:)``;
    /// positions and streams never depend on it.
    public static func skyPart(_ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier,
                               wonLevel: Bool? = nil) throws(MeshError) -> CelestialEclipseLabColouredMesh {
        var parts: Parts = Parts(eye: eye, basis: fixedBasis())
        try backdrop(&parts)
        let won: Bool = wonLevel ?? isWon(snapshot)
        for element in elements(snapshot, eye: eye) {
            try draw(element, into: &parts, snapshot, tier: tier, won: won)
        }
        return parts.built()
    }

    /// Draws the backdrop: one large quad facing the eye behind the authored box.
    static func backdrop(_ parts: inout Parts) throws(MeshError) {
        typealias P = CelestialEclipseLabPalette
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = parts.basis
        var depth: Double = 0
        for index in 0..<8 { depth = max(depth, dot(corner(index) - eye, basis.forward)) }
        depth += 1
        let backCentre: SIMD3<Double> = eye + basis.forward * depth
        let half: Double = depth * 3
        try parts.quad([backCentre - basis.right * half - basis.up * half,
                        backCentre + basis.right * half - basis.up * half,
                        backCentre + basis.right * half + basis.up * half,
                        backCentre - basis.right * half + basis.up * half],
                       facing: basis.forward * -1, code: materialBackdrop, local: [0, 0, 1, 1],
                       colours: [P.ink, P.ink, P.inkTop, P.inkTop],
                       slots: [SIMD3(-1, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 0, 0), SIMD3(-1, 0, 0)])
    }

    /// Draws one element into `parts` (see the header).
    static func draw(_ element: CelestialEclipseLabElement, into parts: inout Parts,
                     _ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier,
                     won: Bool) throws(MeshError) {
        let i: Int = element.item
        let c: SIMD3<Double> = element.centre
        let right: SIMD3<Double> = parts.basis.right
        let up: SIMD3<Double> = parts.basis.up
        switch element.part {
        case .orbit:
            let body: CelestialEclipseLabBody = snapshot.bodies[i]
            let n: Int = body.orbit.count
            for k in 0..<n {
                try parts.facingStrip(world(body.orbit[k], snapshot), world(body.orbit[(k + 1) % n], snapshot),
                                      width: ringWidth, code: materialRing)
            }
            let centre: SIMD3<Double> = bodyCentre(i, snapshot)
            let r: Double = bodyRadius(i, snapshot)
            let notches: Int = notchCount(i)
            for k in 0..<notches {
                let a: Double = Double.pi / 2 + 2 * Double.pi * Double(k) / Double(notches)
                let d: SIMD3<Double> = right * cos(a) + up * sin(a)
                try parts.facingStrip(centre + d * (r + notchInner), centre + d * (r + notchOuter), width: notchWidth,
                                      code: materialNotch)
            }
            if body.fixed {
                let h: Double = r + frameOffset
                try parts.frame(centre: centre, inner: SIMD2(h - frameWidth / 2, h - frameWidth / 2),
                                outer: SIMD2(h + frameWidth / 2, h + frameWidth / 2), code: materialFrame)
            }
        case .chosen:
            let radius: Double = bodyRadius(i, snapshot) + chosenOffset
            try parts.circle(centre: c, inner: radius - chosenWidth / 2, outer: radius + chosenWidth / 2,
                             segments: ringSegments, code: materialChosen, angles: true)
        case .body:
            let r: Double = bodyRadius(i, snapshot)
            if tier.flatBodies {
                try parts.disc(centre: c, radius: r, sides: CelestialEclipseLabTier.discSides, code: materialBody)
            } else {
                try parts.sphere(centre: c, radius: r, longitudes: tier.longitudes, latitudes: tier.latitudes)
            }
            if let pair = failureBodies(snapshot), pair.front == i || pair.back == i {
                try parts.circle(centre: c, inner: r + outlineOffset - outlineWidth / 2,
                                 outer: r + outlineOffset + outlineWidth / 2, segments: ringSegments,
                                 code: materialBroken)
            }
        case .shadow:
            let eclipse: CelestialEclipseLabEclipse = snapshot.eclipses[i]
            let z: Double = shadowZ(eclipse, snapshot)
            var outline: [SIMD3<Double>] = []
            var sum: SIMD3<Double> = SIMD3(0, 0, 0)
            for q in shadowLens(eclipse, snapshot) {
                outline.append(SIMD3(q.x, q.y, z))
                sum += SIMD3(q.x, q.y, z)
            }
            if outline.count >= 3 {
                try parts.fan(centre: sum / Double(outline.count), outline: outline,
                              facing: parts.towardsEye(sum / Double(outline.count)), code: materialShadow)
            }
        case .halo:
            let r: Double = bodyRadius(snapshot.eclipses[i].front, snapshot)
            try parts.circle(centre: c, inner: r, outer: r + haloWidth, segments: ringSegments, code: materialHalo,
                             second: isMatched(snapshot.eclipses[i], snapshot) ? 1 : 0)
        case .strip:
            try parts.facingStrip(tickPosition(0, snapshot), tickPosition(snapshot.horizon - 1, snapshot),
                                  width: stripHeight, code: materialStrip)
        case .bracket:
            try bracket(&parts, i, snapshot, won: won)
        case .mark:
            let material: Double = markMaterial(i, snapshot)
            if material == materialCross {
                try cross(&parts, c, code: materialCross, markLocal: true)
                try parts.frame(centre: c, inner: SIMD2(markFrame, markFrame),
                                outer: SIMD2(markFrame + outlineWidth, markFrame + outlineWidth),
                                code: materialBroken)
            } else {
                try parts.diamond(centre: c, half: markSize, code: material)
            }
        case .endMark:
            try cross(&parts, c, code: materialBroken)
        case .playhead:
            try parts.facingStrip(c - SIMD3(0, playheadHalf, 0), c + SIMD3(0, playheadHalf, 0), width: playheadWidth,
                                  code: materialPlayhead)
        case .bar:
            let half: SIMD2<Double> = SIMD2(barFill * actionsSlot(snapshot) / 2, barHeight / 2)
            try parts.rectangle(centre: c, half: half, code: i < litActions(snapshot) ? materialBar : materialBarUnlit)
        }
    }

    /// Draws target `index`'s bracket: its bar, two legs down, index + 1 notches above it (in the matched colour on a
    /// won level) and a broken frame when a horizon failure names it.
    static func bracket(_ parts: inout Parts, _ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot,
                        won: Bool) throws(MeshError) {
        let code: Double = materialBracket
        let tint: SIMD3<Double> = won ? CelestialEclipseLabPalette.matched : colour(of: materialBracket)
        let ends: (Double, Double) = bracketEnds(index, snapshot)
        let left: SIMD3<Double> = SIMD3(ends.0, bracketY, gaugeZ)
        let right: SIMD3<Double> = SIMD3(ends.1, bracketY, gaugeZ)
        let down: SIMD3<Double> = SIMD3(0, -bracketLeg, 0)
        try parts.facingStrip(left, right, width: bracketLine, code: code, colour: tint)
        try parts.facingStrip(left, left + down, width: bracketLine, code: code, colour: tint)
        try parts.facingStrip(right, right + down, width: bracketLine, code: code, colour: tint)
        let notches: Int = bracketNotches(index)
        let middle: Double = (ends.0 + ends.1) / 2
        for k in 0..<notches {
            let x: Double = middle + (Double(k) - Double(notches - 1) / 2) * bracketNotchSpacing
            try parts.rectangle(centre: SIMD3(x, bracketNotchY, gaugeZ),
                                half: SIMD2(bracketNotchSide / 2, bracketNotchSide / 2), code: code, colour: tint)
        }
        if framedBracket(snapshot) == index {
            let top: Double = bracketNotchY + bracketNotchSide / 2 + bracketLine
            let bottom: Double = bracketY - bracketLeg - bracketLine
            let halfWidth: Double = max((ends.1 - ends.0) / 2, Double(notches) * bracketNotchSpacing / 2) + bracketLine
            let halfHeight: Double = (top - bottom) / 2
            let centre: SIMD3<Double> = SIMD3(middle, (top + bottom) / 2, gaugeZ)
            try parts.frame(centre: centre, inner: SIMD2(halfWidth, halfHeight),
                            outer: SIMD2(halfWidth + outlineWidth, halfHeight + outlineWidth), code: materialBroken)
        }
    }

    /// Draws a cross of two diagonal strokes around `centre` (half diagonal ``markSize``); with `markLocal`,
    /// a_normal.xy the mark-local coordinate of every vertex (its offset from `centre` along right and up over
    /// ``markSize``).
    static func cross(_ parts: inout Parts, _ centre: SIMD3<Double>, code: Double,
                      markLocal: Bool = false) throws(MeshError) {
        let a: SIMD3<Double> = (parts.basis.right + parts.basis.up) * (markSize / 2.0.squareRoot())
        let b: SIMD3<Double> = (parts.basis.right - parts.basis.up) * (markSize / 2.0.squareRoot())
        let mark: (centre: SIMD3<Double>, size: Double)? = markLocal ? (centre, markSize) : nil
        try parts.facingStrip(centre - a, centre + a, width: crossWidth, code: code, mark: mark)
        try parts.facingStrip(centre - b, centre + b, width: crossWidth, code: code, mark: mark)
    }

    /// Whether `eclipse` belongs to a matched interval: one of the first `matched` intervals of its pair whose run
    /// holds the shown tick.
    public static func isMatched(_ eclipse: CelestialEclipseLabEclipse,
                                 _ snapshot: CelestialEclipseLabSceneSnapshot) -> Bool {
        for j in snapshot.intervals.indices where j < snapshot.matched {
            let i: CelestialEclipseLabInterval = snapshot.intervals[j]
            if i.front == eclipse.front && i.back == eclipse.back && i.first <= snapshot.shownTick
                && snapshot.shownTick <= i.last { return true }
        }
        return false
    }

    /// The glow with fallback colours (the base colour times the factor) for the shared unlit renderer:
    /// `tier.glowShells` shells k (outermost first, factor 0.5^k), each a camera-facing band of ``glowSides`` sides
    /// from the object's edge (a_uv.y 0) to it grown by k growths (a_uv.y 1): around every halo (from the front body's
    /// r · s + 0.014, growth ``haloGlowGrowth``, base ``CelestialEclipseLabPalette/coronaGlow``, kind ``glowHalo`` or
    /// ``glowMatchedHalo``), the chosen ring (from its outer edge, growth ``chosenGlowGrowth``, base
    /// ``CelestialEclipseLabPalette/chosen``, kind ``glowChosen``) and every matched mark (from ``markSize``, growth
    /// ``markGlowGrowth``, base ``CelestialEclipseLabPalette/glow``, kind ``glowMark``); each lifted 0.001 · k towards
    /// the eye. a_normal is the base colour and a_uv.x ``glowCode(kind:factor:)``. Empty at level-2.
    public static func glowPart(_ snapshot: CelestialEclipseLabSceneSnapshot,
                                tier: CelestialEclipseLabTier) throws(MeshError) -> CelestialEclipseLabColouredMesh {
        typealias P = CelestialEclipseLabPalette
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = fixedBasis()
        var parts: Parts = Parts(eye: eye, basis: basis)
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let towards: SIMD3<Double> = basis.forward * -1
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            let lift: SIMD3<Double> = towards * (glowLift * Double(k))
            for eclipse in snapshot.eclipses where hasHalo(eclipse) {
                let inner: Double = bodyRadius(eclipse.front, snapshot) + haloWidth
                let kind: Int = isMatched(eclipse, snapshot) ? glowMatchedHalo : glowHalo
                try parts.glowBand(centre: bodyCentre(eclipse.front, snapshot) + lift, inner: inner,
                                   outer: inner + haloGlowGrowth * Double(k), base: P.coronaGlow,
                                   code: glowCode(kind: kind, factor: factor), factor: factor)
            }
            if !snapshot.bodies.isEmpty {
                let chosen: Int = clamped(snapshot.chosenBody, snapshot.bodies.count)
                let inner: Double = bodyRadius(chosen, snapshot) + chosenOffset + chosenWidth / 2
                try parts.glowBand(centre: bodyCentre(chosen, snapshot) + lift, inner: inner,
                                   outer: inner + chosenGlowGrowth * Double(k), base: P.chosen,
                                   code: glowCode(kind: glowChosen, factor: factor), factor: factor)
            }
            for j in snapshot.intervals.indices where j < snapshot.matched {
                try parts.glowBand(centre: tickPosition(snapshot.intervals[j].first, snapshot) + lift,
                                   inner: markSize, outer: markSize + markGlowGrowth * Double(k), base: P.glow,
                                   code: glowCode(kind: glowMark, factor: factor), factor: factor)
            }
        }
        return parts.built()
    }

    /// The number of glow objects (halos, the chosen ring, matched marks); every shell draws one band per object.
    public static func glowObjects(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Int {
        var count: Int = snapshot.bodies.isEmpty ? 0 : 1
        for eclipse in snapshot.eclipses where hasHalo(eclipse) { count += 1 }
        return count + min(max(snapshot.matched, 0), snapshot.intervals.count)
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

    /// The fixed camera's unit forward, right and up vectors (from ``eye`` towards ``lookAt``, +y up).
    static func fixedBasis() -> (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit(lookAt - eye)
        let right: SIMD3<Double> = unit(cross(forward, SIMD3(0, 1, 0)))
        return (forward, right, cross(right, forward))
    }

    /// `camera`'s unit forward, right and up vectors (from its eye towards its target, +y up).
    static func viewBasis(_ camera: CelestialEclipseLabCamera) -> (forward: SIMD3<Double>, right: SIMD3<Double>,
                                                                   up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit(camera.target - camera.eye)
        let right: SIMD3<Double> = unit(cross(forward, SIMD3(0, 1, 0)))
        return (forward, right, cross(right, forward))
    }

    /// The fixed camera for `aspect`: from (0.3, 0.2, 3.4) looking at (0, −0.25, 0) with +y up; the vertical field of
    /// view is the smallest that holds every corner of the box x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 inside
    /// the view with ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it —
    /// every disc at every tick, the rings, the timeline and the bars — keeps a margin of at least 5 % for aspect
    /// 0.4 … 2.5). Independent of the snapshot (accepted for parity), the tier and the time.
    public static func camera(_ snapshot: CelestialEclipseLabSceneSnapshot,
                              aspect: Double) -> CelestialEclipseLabCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = fixedBasis()
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
        return CelestialEclipseLabCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far,
                                         view: view, projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: CelestialEclipseLabCamera) -> SIMD2<Double>? {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
              let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point,
              p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD2(p.x, p.y)
    }

    // MARK: Building

    /// Collects vertices with fallback colours and triangles wound counter-clockwise seen from their facing side.
    struct Parts {
        /// The mesh being built.
        var builder: MeshBuilder = MeshBuilder()
        /// One colour per welded vertex.
        var colours: [Vec4] = []
        /// The eye the camera-facing pieces face.
        let eye: SIMD3<Double>
        /// The view's unit forward, right and up vectors.
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>)

        /// Parts built for the eye `eye` and the view basis `basis`.
        init(eye: SIMD3<Double>, basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>)) {
            self.eye = eye
            self.basis = basis
        }

        /// Adds (or welds) a vertex at `p` with a_normal `slot` and uv (`code`, `local`); its fallback colour is
        /// `colour`.
        mutating func vertex(_ p: SIMD3<Double>, slot: SIMD3<Double>, code: Double, local: Double,
                             colour: SIMD3<Double>) throws(MeshError) -> UInt32 {
            typealias G = CelestialEclipseLabSceneGeometry
            let id: UInt32 = try builder.vertex(G.vec(p), normal: G.vec(slot), uv: Vec2(code, local))
            if Int(id) == colours.count {
                colours.append(Vec4(min(max(colour.x, 0), 1), min(max(colour.y, 0), 1), min(max(colour.z, 0), 1), 1))
            }
            return id
        }

        /// Adds the triangle wound counter-clockwise seen from the side `facing` points to; degenerate triangles are
        /// skipped.
        mutating func triangle(_ ids: (UInt32, UInt32, UInt32), _ pa: SIMD3<Double>, _ pb: SIMD3<Double>,
                               _ pc: SIMD3<Double>, facing: SIMD3<Double>) throws(MeshError) {
            typealias G = CelestialEclipseLabSceneGeometry
            let side: Double = G.dot(G.cross(pb - pa, pc - pa), facing)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A quad (corners in order) wound to face `facing`, with uv (`code`, `local[k]`), a_normal per corner `slots`
        /// (default zero), in `colour` (default the code's colour) or per-corner `colours`.
        mutating func quad(_ p: [SIMD3<Double>], facing: SIMD3<Double>, code: Double, local: [Double],
                           colour: SIMD3<Double>? = nil, colours tints: [SIMD3<Double>]? = nil,
                           slots: [SIMD3<Double>]? = nil) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? CelestialEclipseLabSceneGeometry.colour(of: code)
            var ids: [UInt32] = []
            for k in 0..<4 {
                ids.append(try vertex(p[k], slot: slots?[k] ?? SIMD3(0, 0, 0), code: code, local: local[k],
                                      colour: tints?[k] ?? tint))
            }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2], facing: facing)
            try triangle((ids[0], ids[2], ids[3]), p[0], p[2], p[3], facing: facing)
        }

        /// A fan through the convex `outline` around `centre` wound to face `facing`: local 0 at the centre and 1 on
        /// the outline; a_normal `slot` (default zero) at the centre and `slots[k]` (default `slot`) on the outline; in
        /// `colour` (default the code's colour).
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], facing: SIMD3<Double>, code: Double,
                          colour: SIMD3<Double>? = nil, slot: SIMD3<Double> = SIMD3(0, 0, 0),
                          slots: [SIMD3<Double>]? = nil) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? CelestialEclipseLabSceneGeometry.colour(of: code)
            let c: UInt32 = try vertex(centre, slot: slot, code: code, local: 0, colour: tint)
            var ids: [UInt32] = []
            for k in outline.indices {
                ids.append(try vertex(outline[k], slot: slots?[k] ?? slot, code: code, local: 1, colour: tint))
            }
            for k in outline.indices {
                let j: Int = (k + 1) % outline.count
                try triangle((c, ids[k], ids[j]), centre, outline[k], outline[j], facing: facing)
            }
        }

        /// The unit direction from `point` towards the eye.
        func towardsEye(_ point: SIMD3<Double>) -> SIMD3<Double> {
            let d: SIMD3<Double> = CelestialEclipseLabSceneGeometry.unit(eye - point)
            return CelestialEclipseLabSceneGeometry.dot(d, d) > 0 ? d : SIMD3(0, 0, 1)
        }

        /// The corners of the camera-facing rectangle of half size `half` around `centre`, anticlockwise from the eye.
        func billboard(_ centre: SIMD3<Double>, _ half: SIMD2<Double>) -> [SIMD3<Double>] {
            let r: SIMD3<Double> = basis.right * half.x
            let u: SIMD3<Double> = basis.up * half.y
            return [centre - r - u, centre + r - u, centre + r + u, centre - r + u]
        }

        /// The camera-facing circle of `radius` around `centre` in `segments` + 1 points (the last repeats the first),
        /// anticlockwise from the eye.
        func circlePoints(_ centre: SIMD3<Double>, _ radius: Double, _ segments: Int) -> [SIMD3<Double>] {
            var points: [SIMD3<Double>] = []
            let n: Int = max(segments, 3)
            for k in 0...n {
                let a: Double = 2 * Double.pi * Double(k % n) / Double(n)
                points.append(centre + (basis.right * cos(a) + basis.up * sin(a)) * radius)
            }
            return points
        }

        /// A camera-facing rectangle of half size `half` around `centre`, as a fan, in `colour` (default the code's).
        mutating func rectangle(centre: SIMD3<Double>, half: SIMD2<Double>, code: Double,
                                colour: SIMD3<Double>? = nil) throws(MeshError) {
            try fan(centre: centre, outline: billboard(centre, half), facing: basis.forward * -1, code: code,
                    colour: colour)
        }

        /// A camera-facing diamond of half diagonal `half` around `centre`, as a fan; a_normal.xy the mark-local
        /// coordinate (0, 0) at the centre and (0, −1), (1, 0), (0, 1), (−1, 0) at the corners.
        mutating func diamond(centre: SIMD3<Double>, half: Double, code: Double) throws(MeshError) {
            let r: SIMD3<Double> = basis.right * half
            let u: SIMD3<Double> = basis.up * half
            try fan(centre: centre, outline: [centre - u, centre + r, centre + u, centre - r],
                    facing: basis.forward * -1, code: code,
                    slots: [SIMD3(0, -1, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(-1, 0, 0)])
        }

        /// A camera-facing frame between the half sizes `inner` and `outer` around `centre` (local −1 inner, +1 outer).
        mutating func frame(centre: SIMD3<Double>, inner: SIMD2<Double>, outer: SIMD2<Double>,
                            code: Double) throws(MeshError) {
            let a: [SIMD3<Double>] = billboard(centre, inner)
            let b: [SIMD3<Double>] = billboard(centre, outer)
            for k in 0..<4 {
                let j: Int = (k + 1) % 4
                try quad([a[k], b[k], b[j], a[j]], facing: basis.forward * -1, code: code, local: [-1, 1, 1, -1])
            }
        }

        /// A flat camera-facing disc of `sides` sides and `radius` around `centre`, as a fan (local the radial
        /// coordinate), a_normal the unit direction towards the eye.
        mutating func disc(centre: SIMD3<Double>, radius: Double, sides: Int, code: Double) throws(MeshError) {
            try fan(centre: centre, outline: Array(circlePoints(centre, radius, sides).dropLast()),
                    facing: basis.forward * -1, code: code, slot: basis.forward * -1)
        }

        /// A camera-facing ring between `inner` and `outer` around `centre` in `segments` quads (local −1 inner, +1
        /// outer); with `angles`, a_normal.x the angle fraction 0 … 1 (the seam's vertices repeated with 1.0),
        /// otherwise a_normal (`second`, 0, 0).
        mutating func circle(centre: SIMD3<Double>, inner: Double, outer: Double, segments: Int, code: Double,
                             angles: Bool = false, second: Double = 0) throws(MeshError) {
            let a: [SIMD3<Double>] = circlePoints(centre, inner, segments)
            let b: [SIMD3<Double>] = circlePoints(centre, outer, segments)
            let n: Int = a.count - 1
            for k in 0..<n {
                let t0: Double = Double(k) / Double(n)
                let t1: Double = Double(k + 1) / Double(n)
                let s0: SIMD3<Double> = angles ? SIMD3(t0, 0, 0) : SIMD3(second, 0, 0)
                let s1: SIMD3<Double> = angles ? SIMD3(t1, 0, 0) : SIMD3(second, 0, 0)
                try quad([a[k], b[k], b[k + 1], a[k + 1]], facing: basis.forward * -1, code: code,
                         local: [-1, 1, 1, -1], slots: [s0, s0, s1, s1])
            }
        }

        /// A UV sphere of `radius` around `centre` with `longitudes` × `latitudes` segments (exact poles; local 0,
        /// material ``materialBody``), a_normal the outward normal, wound counter-clockwise seen from outside.
        mutating func sphere(centre: SIMD3<Double>, radius: Double, longitudes: Int,
                             latitudes: Int) throws(MeshError) {
            typealias G = CelestialEclipseLabSceneGeometry
            let lon: Int = max(longitudes, 3)
            let lat: Int = max(latitudes, 2)
            let tint: SIMD3<Double> = G.colour(of: G.materialBody)
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
                    row.append(try vertex(p, slot: n, code: G.materialBody, local: 0, colour: tint))
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

        /// A camera-facing strip of `width` from `a` to `b` (local −1 … +1 across it) in `colour` (default the code's);
        /// a_normal zero, or with `mark` each corner's mark-local coordinate (its offset from `mark.centre` along right
        /// and up over `mark.size`); nothing for a strip of length 0.
        mutating func facingStrip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, code: Double,
                                  colour: SIMD3<Double>? = nil,
                                  mark: (centre: SIMD3<Double>, size: Double)? = nil) throws(MeshError) {
            typealias G = CelestialEclipseLabSceneGeometry
            let direction: SIMD3<Double> = b - a
            guard G.dot(direction, direction) > 0 else { return }
            let towards: SIMD3<Double> = towardsEye((a + b) / 2)
            var side: SIMD3<Double> = G.unit(G.cross(direction, towards))
            if G.dot(side, side) == 0 { side = basis.right }
            let w: SIMD3<Double> = side * (width / 2)
            let corners: [SIMD3<Double>] = [a + w, b + w, b - w, a - w]
            var slots: [SIMD3<Double>]? = nil
            if let m = mark {
                var list: [SIMD3<Double>] = []
                for p in corners {
                    let d: SIMD3<Double> = p - m.centre
                    list.append(SIMD3(G.dot(d, basis.right) / m.size, G.dot(d, basis.up) / m.size, 0))
                }
                slots = list
            }
            try quad(corners, facing: towards, code: code, local: [-1, -1, 1, 1], colour: colour, slots: slots)
        }

        /// A glow band: a camera-facing ring of ``glowSides`` sides from `inner` (a_uv.y 0) to `outer` (a_uv.y 1)
        /// around `centre`, a_normal the base colour, a_uv.x `code`, coloured base · factor.
        mutating func glowBand(centre: SIMD3<Double>, inner: Double, outer: Double, base: SIMD3<Double>, code: Double,
                               factor: Double) throws(MeshError) {
            let sides: Int = CelestialEclipseLabSceneGeometry.glowSides
            let a: [SIMD3<Double>] = circlePoints(centre, inner, sides)
            let b: [SIMD3<Double>] = circlePoints(centre, outer, sides)
            for k in 0..<(a.count - 1) {
                try quad([a[k], b[k], b[k + 1], a[k + 1]], facing: basis.forward * -1, code: code,
                         local: [0, 1, 1, 0], colour: base * factor, slots: [base, base, base, base])
            }
        }

        /// The coloured mesh built so far.
        func built() -> CelestialEclipseLabColouredMesh {
            CelestialEclipseLabColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
