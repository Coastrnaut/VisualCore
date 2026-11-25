// StarlitCartoucheSceneGeometry — feature 453 (R02-G16-03) T-R02G1603-004 (FR-R02G1603-001, 002, 003, 004, 006;
// clarifications Q1, Q2, Q3, Q4). The star chart of Starlit Cartouche, built from a snapshot only. x points right, y
// up and z towards the default viewer. A lattice position v maps to world space by w(v) = (v − m) · s, where m is the
// centre of the bounding box of every orbit position of every star and s = 1.5 / (e + 1) with e the box's largest
// extent, so no star leaves the cube −0.75 … 0.75 at any beat. Stars are drawn at w(position(at: beat)).
//
// Draw order (clarification Q1; depth testing off, so the chart mesh is in painter's order):
//   1. the firmament, one large quad facing the eye behind the authored box (its vertical gradient, specks and turn
//      are the shader's; the geometry never turns);
//   2. the elements (``StarlitCartoucheElement``) back to front by the distance of their centres from the eye
//      (farthest first; ties by kind — corridor, hazard, trail, failed leg, star, ship, beacon, chosen, cartouche,
//      actions bar, beat track, wait pip — then by index):
//      - corridor i: a camera-facing ribbon 0.02 wide between its stars' current positions; an undrawn symbol corridor
//        dashed pearl (the shader cuts the dashes from the distance along), every other corridor faint;
//      - hazard h: a camera-facing ribbon 0.06 wide along its corridor, coral while active (from ≤ beat ≤ to), dim
//        otherwise (striped by the shader along it); the hazard a failure met in the broken colour;
//      - trail k: per flown leg a camera-facing ribbon 0.05 wide from w of the from-star's position at departure to w
//        of the to-star's position at arrival, meteor gold, preceded by `tier.ghosts` motion-blur ghosts near its end;
//      - failed leg: the leg a failure broke (``StarlitCartoucheSceneSnapshot/failedLeg``) as a ribbon 0.05 wide in the
//        broken colour;
//      - star i: a sphere of radius 0.07 (`tier.longitudes` × `tier.latitudes`; a flat camera-facing 12-sided disc at
//        level-2), pearl, with a camera-facing ring on which the shader lights (i mod 6) + 1 notches; a star whose
//        window a failure missed is ringed in the broken colour;
//      - ship: a sapphire camera-facing quad on which the shader draws a dart of length 0.14 centred on its place,
//        pointing along its last trail (towards +x before the first leg); its place moves along the last trail by
//        `glide` 0 … 1 (1 at its star);
//      - beacon: a camera-facing ring of radius 0.12 around the beacon star;
//      - chosen: a camera-facing ring of radius 0.1 around the chosen destination (dashed by the shader);
//      - the gauges, screen-facing (laid out on the view's right and up axes around their centres): the cartouche, a
//        5 × 5 grid 0.5 wide centred at (−0.5, −1.2, 0) in which every symbol corridor is a line between its stars'
//        glyph points, dashed until drawn and solid gold once drawn (a stray stroke a failure drew in the broken
//        colour); `budget` actions bars centred at y = −1.05 from x = 0.0 to 0.9 (each 0.9 / budget wide with a fifth
//        as gap, 0.04 tall), lit for the actions left (each framed in the broken colour on a budget failure); the beat
//        track at y = −1.2 from x = 0.0 to 0.9, filled to beat / deadline (framed in the broken colour on a deadline
//        failure); 9 wait pips at y = −1.35 from x = 0.0 to 0.9, pip j standing for wait j and lit for j ≤ the chosen
//        wait.
// The glow mesh is drawn last, additively: `tier.glowShells` shells k (outermost first, factor 0.5^k) as camera-facing
// bands around every star, the ship and every trail, lifted 0.001 · k towards the eye; empty at level-2. A won level
// lights every trail and stroke and lifts the stars' fallback colour without moving any position.
//
// Vertex streams (attributes a_position, a_normal, a_uv; the contract of `StarlitCartoucheShaders.Material/
// localCoordinate`). Chart mesh: a_uv.x is the material code (``StarlitCartoucheShaders/Material``, 0 … 21). The
// firmament: a_uv.y the height 0 (bottom) … 1 (top), a_normal.x the horizontal coordinate −1 (left) … +1 (right).
// Strips (ribbons and rings): a_uv.y the across coordinate −1 on one long side (a ring's inner edge) and +1 on the
// other; a_normal.x the distance along in world units from the ribbon's start on undrawn symbol corridors, hazard tubes
// and undrawn cartouche strokes; the along fraction 0 (tail) … 1 (head) on trails and ghosts, a ghost's fade
// (``StarlitCartoucheShaders/ghostFade(index:count:)``, index 0 nearest the trail's head) in a_normal.y; the angle
// fraction 0 … 1 around the notch ring (seam vertex duplicated with 1.0; a_normal.y the notch count (i mod 6) + 1) and
// the chosen ring; zero on the other strips. Stars: a_normal the unit outward sphere normal and a_uv.y 0; a level-2
// disc a_normal ``StarlitCartoucheShaders/viewDirection`` and a_uv.y the radial coordinate 0 (centre) … 1 (rim). The
// ship: one quad spanning arrow-local ±``StarlitCartoucheShaders/arrowQuadExtent`` with a_normal.xy the arrow-local
// coordinate (u −1 at the tail … +1 at the tip along the heading, 0.07 per unit; v across, 0.05 per unit) and a_uv.y 0.
// Fans (bars, the track, pips): a_uv.y 0 at the centre vertex and 1 on the outline, a_normal zero. Glow mesh: a_normal
// is the base colour (``StarlitCartouchePalette/glow`` for stars, ``StarlitCartouchePalette/shipGlow`` for the ship,
// ``StarlitCartouchePalette/trailGlow`` for trails), a_uv.x ``StarlitCartoucheShaders/GlowKind/code(factor:)`` with
// factor 0.5^k and a_uv.y the radial coordinate, 0 inner and 1 outer. The fallback colour streams carry the material's
// colour (``StarlitCartoucheShaders/Material/colour``; the firmament night to night top), so dashes, stripes, notches
// and the dart's outline appear only on the shader path. Every triangle winds counter-clockwise seen from outside its
// sphere or from the eye, and the index order is the painter's order. Tiers change only the star sphere detail, the
// ghosts and the glow: every position named above is the same at every tier. Doubles are used for drawing only;
// nothing here is consulted by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The camera of one frame: eye, target, lens and the matrices built from them.
public struct StarlitCartoucheCamera: Sendable, Equatable {
    /// The eye position in world units, (1.2, 1.0, 2.8).
    public let eye: SIMD3<Double>
    /// The point looked at, (0, −0.2, 0).
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
public struct StarlitCartoucheElement: Sendable, Equatable {
    /// The kind of an element, in the tie order of the painter's order.
    public enum Kind: Int, Sendable, CaseIterable {
        /// A corridor ribbon.
        case corridor = 0
        /// A hazard tube.
        case hazard = 1
        /// A flown leg's trail.
        case trail = 2
        /// The leg a failure broke.
        case failedLeg = 3
        /// A star.
        case star = 4
        /// The ship.
        case ship = 5
        /// The beacon ring.
        case beacon = 6
        /// The chosen destination's dashed ring.
        case chosen = 7
        /// The cartouche.
        case cartouche = 8
        /// An actions bar.
        case actionsBar = 9
        /// The beat track.
        case beatTrack = 10
        /// A wait pip.
        case waitPip = 11
    }

    /// The kind.
    public let kind: Kind
    /// The index within its kind: corridor, hazard, leg, star, bar or pip (0 for the single elements).
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
    public static func paintsBefore(_ a: StarlitCartoucheElement, _ b: StarlitCartoucheElement) -> Bool {
        if a.distance != b.distance { return a.distance > b.distance }
        if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
        return a.index < b.index
    }
}

/// A mesh with one RGBA colour per vertex, for the shared unlit `MeshRenderer` (the fallback path).
public struct StarlitCartoucheColouredMesh: Sendable, Equatable {
    /// The mesh.
    public let mesh: Mesh
    /// One colour per vertex of `mesh` (components 0 … 1, alpha 1).
    public let colours: [Vec4]
}

/// Builds the Starlit Cartouche scene from a `StarlitCartoucheSceneSnapshot`: places, meshes, camera and projection.
public enum StarlitCartoucheSceneGeometry {
    /// The material codes (shared with the shaders).
    public typealias Material = StarlitCartoucheShaders.Material

    // MARK: Constants (world units)

    /// The span every orbit position fits: s = span / (e + 1).
    public static let span: Double = 1.5
    /// A corridor ribbon's width.
    public static let corridorWidth: Double = 0.02
    /// A hazard tube's width.
    public static let hazardWidth: Double = 0.06
    /// A trail ribbon's width (and the failed leg's).
    public static let trailWidth: Double = 0.05
    /// How far ghost g starts back from its trail's end, per ghost.
    public static let ghostSpacing: Double = 0.05
    /// A ghost's length along its trail.
    public static let ghostLength: Double = 0.06
    /// How much wider than the trail ghost g is, per ghost.
    public static let ghostWidening: Double = 0.02
    /// A star's radius.
    public static let starRadius: Double = 0.07
    /// A star's notch ring: inner radius.
    public static let ringInner: Double = 0.078
    /// A star's notch ring: outer radius.
    public static let ringOuter: Double = 0.098
    /// The segments of every ring.
    public static let ringSegments: Int = 24
    /// The ship arrow's length.
    public static let shipLength: Double = 0.14
    /// The ship arrow's half width at its tail.
    public static let shipHalfWidth: Double = 0.05
    /// The beacon ring's radius.
    public static let beaconRadius: Double = 0.12
    /// The chosen destination ring's radius.
    public static let chosenRadius: Double = 0.1
    /// The beacon and chosen rings' width.
    public static let ringWidth: Double = 0.012
    /// A failure ring's radius around a marked star.
    public static let markRadius: Double = 0.15
    /// A failure ring's width (and a failure frame's).
    public static let markWidth: Double = 0.016
    /// The gauges' plane.
    public static let gaugeZ: Double = 0
    /// The cartouche's centre.
    public static let cartoucheCentreX: Double = -0.5
    /// The cartouche's centre line.
    public static let cartoucheCentreY: Double = -1.2
    /// The cartouche grid's width (5 cells).
    public static let cartoucheWidth: Double = 0.5
    /// The cartouche grid's cells per side.
    public static let cartoucheCells: Int = 5
    /// A grid line's width.
    public static let gridLine: Double = 0.004
    /// A cartouche stroke's width.
    public static let strokeWidth: Double = 0.012
    /// The gauges' left end.
    public static let gaugeStart: Double = 0.0
    /// The gauges' right end.
    public static let gaugeEnd: Double = 0.9
    /// The actions bars' centre line.
    public static let actionsY: Double = -1.05
    /// The share of a slot an actions bar fills (the rest, a fifth, is the gap).
    public static let barFill: Double = 0.8
    /// An actions bar's height.
    public static let barHeight: Double = 0.04
    /// The beat track's centre line.
    public static let trackY: Double = -1.2
    /// The beat track's height.
    public static let trackHeight: Double = 0.03
    /// The wait pips' centre line.
    public static let pipsY: Double = -1.35
    /// The wait pips (waits 0 … 8).
    public static let pipCount: Int = 9
    /// A wait pip's side.
    public static let pipSide: Double = 0.04
    /// Glow factor of shell k is glowWeight^k.
    public static let glowWeight: Double = 0.5
    /// A star's glow growth per shell (from the star's radius).
    public static let starGlowGrowth: Double = 0.03
    /// The ship's glow inner radius.
    public static let shipGlowInner: Double = 0.07
    /// The ship's glow growth per shell.
    public static let shipGlowGrowth: Double = 0.03
    /// A trail's glow growth per shell, per side (from the trail's half width).
    public static let trailGlowGrowth: Double = 0.02
    /// The sides of a glow band around a star or the ship.
    public static let glowSides: Int = 12
    /// Lift towards the eye per glow shell.
    public static let glowLift: Double = 0.001
    /// How far a won level lifts the stars' fallback colour towards white.
    public static let wonLift: Double = 0.35
    /// The eye.
    public static let eye: SIMD3<Double> = SIMD3(1.2, 1.0, 2.8)
    /// The point looked at.
    public static let lookAt: SIMD3<Double> = SIMD3(0, -0.2, 0)
    /// The fitting margin per side in view coordinates (above the required 5 %).
    public static let fitMargin: Double = 0.06
    /// The box the camera holds: lower corner.
    public static let boxLow: SIMD3<Double> = SIMD3(-0.95, -1.45, -0.95)
    /// The box the camera holds: upper corner.
    public static let boxHigh: SIMD3<Double> = SIMD3(0.95, 0.95, 0.95)
    /// The aspects the fit is designed for.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: Places (the CPU reference)

    /// The bounding box (lower and upper corner, in lattice units) of every orbit position of every star.
    static func bounds(_ snapshot: StarlitCartoucheSceneSnapshot) -> (low: SIMD3<Double>, high: SIMD3<Double>) {
        var low: SIMD3<Double>? = nil
        var high: SIMD3<Double> = SIMD3(0, 0, 0)
        for star in snapshot.stars {
            for v in star.orbit {
                let p: SIMD3<Double> = SIMD3(Double(v.x), Double(v.y), Double(v.z))
                if let l = low {
                    low = SIMD3(min(l.x, p.x), min(l.y, p.y), min(l.z, p.z))
                    high = SIMD3(max(high.x, p.x), max(high.y, p.y), max(high.z, p.z))
                } else {
                    low = p
                    high = p
                }
            }
        }
        return (low ?? SIMD3(0, 0, 0), high)
    }

    /// The centre m of the bounding box of every orbit position of every star, in lattice units.
    public static func middle(_ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double> {
        let box: (low: SIMD3<Double>, high: SIMD3<Double>) = bounds(snapshot)
        return (box.low + box.high) / 2
    }

    /// The lattice scale s = 1.5 / (e + 1), e the largest extent of the box of every orbit position.
    public static func scale(_ snapshot: StarlitCartoucheSceneSnapshot) -> Double {
        let box: (low: SIMD3<Double>, high: SIMD3<Double>) = bounds(snapshot)
        let extent: SIMD3<Double> = box.high - box.low
        return span / (max(extent.x, extent.y, extent.z) + 1)
    }

    /// The world point of lattice position `position`: w(v) = (v − m) · s.
    public static func world(_ position: StarlitCartoucheVector,
                             _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double> {
        let v: SIMD3<Double> = SIMD3(Double(position.x), Double(position.y), Double(position.z))
        return (v - middle(snapshot)) * scale(snapshot)
    }

    /// `index` clamped to 0 … count − 1 (0 when count is 0).
    static func clamped(_ index: Int, _ count: Int) -> Int { min(max(index, 0), max(count - 1, 0)) }

    /// The centre of star `index` (clamped) at the snapshot's beat: w(positions[index]).
    public static func starCentre(_ index: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.positions.isEmpty else { return SIMD3(0, 0, 0) }
        return world(snapshot.positions[clamped(index, snapshot.positions.count)], snapshot)
    }

    /// The world start (w of the from-star's position at departure) and end (w of the to-star's position at arrival)
    /// of trail `leg` (clamped); the ship's star twice when no leg was flown.
    public static func trailEnds(_ leg: Int, _ snapshot: StarlitCartoucheSceneSnapshot)
        -> (start: SIMD3<Double>, end: SIMD3<Double>) {
        guard !snapshot.legs.isEmpty, snapshot.departures.count == snapshot.legs.count,
              snapshot.arrivals.count == snapshot.legs.count else {
            let c: SIMD3<Double> = starCentre(snapshot.star, snapshot)
            return (c, c)
        }
        let k: Int = clamped(leg, snapshot.legs.count)
        return (world(snapshot.departures[k], snapshot), world(snapshot.arrivals[k], snapshot))
    }

    /// The midpoint of trail `leg` (clamped).
    public static func trailMidpoint(_ leg: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double> {
        let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = trailEnds(leg, snapshot)
        return (ends.start + ends.end) / 2
    }

    /// `glide` made usable: clamped to 0 … 1, 1 when not finite.
    static func usableGlide(_ glide: Double) -> Double { glide.isFinite ? min(max(glide, 0), 1) : 1 }

    /// The ship's place for `glide` (0 … 1): along its last trail from its start (0) to its end (1), which is the
    /// ship's star at the snapshot's beat; the ship's star before the first leg.
    public static func shipPlace(_ snapshot: StarlitCartoucheSceneSnapshot, glide: Double) -> SIMD3<Double> {
        guard !snapshot.legs.isEmpty else { return starCentre(snapshot.star, snapshot) }
        let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = trailEnds(snapshot.legs.count - 1, snapshot)
        return mix(ends.start, ends.end, usableGlide(glide))
    }

    /// The ship's centre at rest (glide 1): its star's centre.
    public static func shipCentre(_ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double> {
        shipPlace(snapshot, glide: 1)
    }

    /// The unit direction the ship points: along its last trail, +x before the first leg (or for a trail of length 0).
    public static func shipHeading(_ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double> {
        guard !snapshot.legs.isEmpty else { return SIMD3(1, 0, 0) }
        let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = trailEnds(snapshot.legs.count - 1, snapshot)
        let d: SIMD3<Double> = unit(ends.end - ends.start)
        return dot(d, d) > 0 ? d : SIMD3(1, 0, 0)
    }

    /// The ends of the failed leg (w of its from-star's position at departure and w of its to-star's position at
    /// arrival), nil when no leg failed.
    public static func failedLegEnds(_ snapshot: StarlitCartoucheSceneSnapshot)
        -> (start: SIMD3<Double>, end: SIMD3<Double>)? {
        guard let leg = snapshot.failedLeg, leg.from >= 0, leg.from < snapshot.stars.count, leg.to >= 0,
              leg.to < snapshot.stars.count else { return nil }
        return (world(snapshot.stars[leg.from].position(at: leg.depart), snapshot),
                world(snapshot.stars[leg.to].position(at: leg.arrive), snapshot))
    }

    /// The cartouche's centre, (−0.5, −1.2, 0).
    public static func cartoucheCentre() -> SIMD3<Double> { SIMD3(cartoucheCentreX, cartoucheCentreY, gaugeZ) }

    /// The offset (right, up) of glyph point (x, y) from the cartouche's centre: cell centres 0.1 apart, column 0 at
    /// the left and row 0 at the top.
    public static func glyphOffset(_ glyph: StarlitCartoucheGlyphPoint) -> SIMD2<Double> {
        let cell: Double = cartoucheWidth / Double(cartoucheCells)
        let half: Double = Double(cartoucheCells - 1) / 2
        return SIMD2((Double(glyph.x) - half) * cell, (half - Double(glyph.y)) * cell)
    }

    /// The width of one actions slot, 0.9 / budget.
    public static func actionsSlot(_ snapshot: StarlitCartoucheSceneSnapshot) -> Double {
        (gaugeEnd - gaugeStart) / Double(max(snapshot.budget, 1))
    }

    /// The centre of actions bar `index`: (0.0 + (index + 0.5) · slot, −1.05, 0).
    public static func actionsBar(_ index: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * actionsSlot(snapshot), actionsY, gaugeZ)
    }

    /// The actions bars drawn lit: the actions left, clamped to 0 … budget.
    public static func litActions(_ snapshot: StarlitCartoucheSceneSnapshot) -> Int {
        min(max(snapshot.actionsLeft, 0), max(snapshot.budget, 0))
    }

    /// The beat track's centre, (0.45, −1.2, 0).
    public static func beatTrackCentre() -> SIMD3<Double> { SIMD3((gaugeStart + gaugeEnd) / 2, trackY, gaugeZ) }

    /// The beat track's filled share: beat / deadline clamped to 0 … 1.
    public static func trackFill(_ snapshot: StarlitCartoucheSceneSnapshot) -> Double {
        guard snapshot.deadline > 0 else { return 1 }
        return min(max(Double(snapshot.beat) / Double(snapshot.deadline), 0), 1)
    }

    /// The centre of wait pip `index` (0 … 8): (0.0 + (index + 0.5) · 0.1, −1.35, 0).
    public static func waitPip(_ index: Int) -> SIMD3<Double> {
        SIMD3(gaugeStart + (Double(index) + 0.5) * (gaugeEnd - gaugeStart) / Double(pipCount), pipsY, gaugeZ)
    }

    /// The wait pips drawn lit: pip j stands for wait j and is lit for j ≤ the chosen wait, so chosenWait + 1 (1 … 9).
    public static func litPips(_ snapshot: StarlitCartoucheSceneSnapshot) -> Int {
        min(max(snapshot.chosenWait, 0), pipCount - 1) + 1
    }

    /// The won flag: 1 when the level is won (stage won, or result with a matched route and no failure), else 0. A
    /// won level lights every trail and stroke; no position changes.
    public static func wonFlag(_ snapshot: StarlitCartoucheSceneSnapshot) -> Double {
        snapshot.isWon || (snapshot.stage == .result && snapshot.failure == nil && snapshot.report.matched) ? 1 : 0
    }

    /// The star whose window a failure missed (departure or arrival), if any.
    public static func markedStar(_ snapshot: StarlitCartoucheSceneSnapshot) -> Int? {
        switch snapshot.failure {
        case .departure(let star, _, _), .arrival(let star, _, _, _): star
        default: nil
        }
    }

    /// The hazard a failure met, if any.
    public static func markedHazard(_ snapshot: StarlitCartoucheSceneSnapshot) -> Int? {
        if case .hazard(_, let hazard, _, _) = snapshot.failure { return hazard }
        return nil
    }

    /// The stray stroke (corridor) a failure drew, if any.
    public static func markedStroke(_ snapshot: StarlitCartoucheSceneSnapshot) -> Int? {
        if case .stroke(let corridor) = snapshot.failure { return corridor }
        return nil
    }

    /// Whether a deadline failure marks the beat track.
    public static func marksBeatTrack(_ snapshot: StarlitCartoucheSceneSnapshot) -> Bool {
        if case .deadline = snapshot.failure { return true }
        return false
    }

    /// Whether a budget failure marks the actions bars.
    public static func marksActionsBars(_ snapshot: StarlitCartoucheSceneSnapshot) -> Bool {
        if case .budget = snapshot.failure { return true }
        return false
    }

    /// Every element with its centre and distance from `camera`'s eye, in painter's order: farthest first, ties by
    /// kind (corridor, hazard, trail, failed leg, star, ship, beacon, chosen, cartouche, actions bar, beat track, wait
    /// pip) then index (clarification Q1). The ship is at rest (glide 1).
    public static func paintOrder(_ snapshot: StarlitCartoucheSceneSnapshot,
                                  camera: StarlitCartoucheCamera) -> [StarlitCartoucheElement] {
        elements(snapshot, eye: camera.eye, glide: 1)
    }

    /// The CPU reference points (clarification Q3) in painter's order: every star's centre, the ship's centre, the
    /// midpoint of every trail, the cartouche centre and the first actions bar.
    public static func referencePoints(_ snapshot: StarlitCartoucheSceneSnapshot,
                                       camera: StarlitCartoucheCamera) -> [StarlitCartoucheElement] {
        var points: [StarlitCartoucheElement] = []
        for element in paintOrder(snapshot, camera: camera) {
            switch element.kind {
            case .star, .ship, .trail, .cartouche: points.append(element)
            case .actionsBar where element.index == 0: points.append(element)
            default: break
            }
        }
        return points
    }

    /// The elements in painter's order seen from `eye`, the ship placed by `glide`.
    static func elements(_ snapshot: StarlitCartoucheSceneSnapshot, eye: SIMD3<Double>,
                         glide: Double) -> [StarlitCartoucheElement] {
        var list: [StarlitCartoucheElement] = []
        func add(_ kind: StarlitCartoucheElement.Kind, _ index: Int, _ centre: SIMD3<Double>) {
            let d: SIMD3<Double> = centre - eye
            list.append(StarlitCartoucheElement(kind: kind, index: index, centre: centre,
                                                distance: dot(d, d).squareRoot()))
        }
        let count: Int = snapshot.stars.count
        for index in snapshot.corridors.indices {
            let c: StarlitCartoucheCorridor = snapshot.corridors[index]
            guard c.a >= 0, c.b < count else { continue }
            add(.corridor, index, (starCentre(c.a, snapshot) + starCentre(c.b, snapshot)) / 2)
        }
        for index in snapshot.hazards.indices {
            let h: StarlitCartoucheHazard = snapshot.hazards[index]
            guard h.corridor >= 0, h.corridor < snapshot.corridors.count else { continue }
            let c: StarlitCartoucheCorridor = snapshot.corridors[h.corridor]
            guard c.a >= 0, c.b < count else { continue }
            add(.hazard, index, (starCentre(c.a, snapshot) + starCentre(c.b, snapshot)) / 2)
        }
        if snapshot.departures.count == snapshot.legs.count, snapshot.arrivals.count == snapshot.legs.count {
            for index in snapshot.legs.indices { add(.trail, index, trailMidpoint(index, snapshot)) }
        }
        if let ends = failedLegEnds(snapshot) { add(.failedLeg, 0, (ends.start + ends.end) / 2) }
        for index in 0..<count { add(.star, index, starCentre(index, snapshot)) }
        if count > 0 {
            add(.ship, 0, shipPlace(snapshot, glide: glide))
            add(.beacon, 0, starCentre(snapshot.beacon, snapshot))
            add(.chosen, 0, starCentre(snapshot.chosenStar, snapshot))
        }
        add(.cartouche, 0, cartoucheCentre())
        for index in 0..<max(snapshot.budget, 0) { add(.actionsBar, index, actionsBar(index, snapshot)) }
        add(.beatTrack, 0, beatTrackCentre())
        for index in 0..<pipCount { add(.waitPip, index, waitPip(index)) }
        list.sort(by: StarlitCartoucheElement.paintsBefore)
        return list
    }

    /// `a` mixed towards `b` by `t`.
    static func mix(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ t: Double) -> SIMD3<Double> { a + (b - a) * t }

    /// The notch count of star `index`'s ring: (index mod 6) + 1.
    public static func notchCount(_ index: Int) -> Int { ((index % 6) + 6) % 6 + 1 }

    /// The fallback colour of `material` (unlit): the colour the chart vertex shader selects
    /// (``StarlitCartoucheShaders/Material/colour``; the firmament's bottom colour).
    public static func colour(_ material: Material) -> SIMD3<Double> { material.colour }

    // MARK: Meshes

    /// The chart mesh for the chart program, in painter's order (see the header), the ship placed by `glide` 0 … 1.
    public static func chartMesh(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier,
                                 glide: Double) throws(MeshError) -> Mesh {
        try chartPart(snapshot, tier: tier, glide: glide).mesh
    }

    /// The glow mesh for the glow program (`glowPart` without colours); empty at level-2.
    public static func glowMesh(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier,
                                glide: Double = 1) throws(MeshError) -> Mesh {
        try glowPart(snapshot, tier: tier, glide: glide).mesh
    }

    /// The chart with fallback colours (unlit palette colours; the firmament from night at its bottom to night top at
    /// its top; on a won level the trails and drawn strokes towards the trail glow and the stars towards white) for the
    /// shared unlit renderer: the same mesh as ``chartMesh(_:tier:glide:)``. `wonLevel` (0 … 1) scales the won look;
    /// nil uses ``wonFlag(_:)``. Positions never depend on it.
    public static func chartPart(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier,
                                 glide: Double = 1,
                                 wonLevel: Double? = nil) throws(MeshError) -> StarlitCartoucheColouredMesh {
        typealias P = StarlitCartouchePalette
        let view: StarlitCartoucheCamera = camera(snapshot, aspect: 1)
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis(view)
        var parts: Parts = Parts(eye: view.eye, basis: basis)
        let won: Double = wonLevel.map { $0.isFinite ? min(max($0, 0), 1) : 0 } ?? wonFlag(snapshot)
        let trailColour: SIMD3<Double> = mix(P.trail, P.trailGlow, won)
        let starColour: SIMD3<Double> = mix(P.pearl, SIMD3(1, 1, 1), wonLift * won)
        // 1. Firmament.
        var depth: Double = 0
        for index in 0..<8 { depth = max(depth, dot(corner(index) - view.eye, basis.forward)) }
        depth += 1
        let backCentre: SIMD3<Double> = view.eye + basis.forward * depth
        let half: Double = depth * 3
        try parts.quad([backCentre - basis.right * half - basis.up * half,
                        backCentre + basis.right * half - basis.up * half,
                        backCentre + basis.right * half + basis.up * half,
                        backCentre - basis.right * half + basis.up * half],
                       normal: basis.forward * -1, material: .firmament, local: [0, 0, 1, 1],
                       colours: [P.night, P.night, P.nightTop, P.nightTop],
                       slots: [SIMD3(-1, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 0, 0), SIMD3(-1, 0, 0)])
        // 2. Elements back to front.
        let symbol: Set<Int> = Set(snapshot.symbol)
        let drawn: Set<Int> = Set(snapshot.drawn)
        for element in elements(snapshot, eye: view.eye, glide: glide) {
            let i: Int = element.index
            switch element.kind {
            case .corridor:
                let c: StarlitCartoucheCorridor = snapshot.corridors[i]
                let a: SIMD3<Double> = starCentre(c.a, snapshot)
                let b: SIMD3<Double> = starCentre(c.b, snapshot)
                if symbol.contains(i) && !drawn.contains(i) {
                    try parts.alongStrip(a, b, width: corridorWidth, material: .symbolDash)
                } else {
                    try parts.facingStrip(a, b, width: corridorWidth, material: .corridor)
                }
            case .hazard:
                let h: StarlitCartoucheHazard = snapshot.hazards[i]
                let c: StarlitCartoucheCorridor = snapshot.corridors[h.corridor]
                let active: Bool = i < snapshot.active.count && snapshot.active[i]
                let material: Material = markedHazard(snapshot) == i ? .broken : (active ? .hazardActive : .hazardIdle)
                if material == .broken {
                    try parts.facingStrip(starCentre(c.a, snapshot), starCentre(c.b, snapshot), width: hazardWidth,
                                          material: material)
                } else {
                    try parts.alongStrip(starCentre(c.a, snapshot), starCentre(c.b, snapshot), width: hazardWidth,
                                         material: material)
                }
            case .trail:
                let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = trailEnds(i, snapshot)
                let along: SIMD3<Double> = ends.end - ends.start
                let length: Double = dot(along, along).squareRoot()
                if length > 0 {
                    let d: SIMD3<Double> = along / length
                    let ghosts: Int = max(tier.ghosts, 0)
                    for g in stride(from: ghosts, through: 1, by: -1) {
                        let back: Double = min(ghostSpacing * Double(g), length)
                        let tail: Double = min(back + ghostLength, length)
                        let fade: Double = StarlitCartoucheShaders.ghostFade(index: g - 1, count: ghosts)
                        try parts.facingStrip(ends.end - d * tail, ends.end - d * back,
                                              width: trailWidth + ghostWidening * Double(g), material: .trailGhost,
                                              aux: (SIMD3(0, fade, 0), SIMD3(1, fade, 0)), colour: trailColour)
                    }
                }
                try parts.facingStrip(ends.start, ends.end, width: trailWidth, material: .trail,
                                      aux: (SIMD3(0, 0, 0), SIMD3(1, 0, 0)), colour: trailColour)
            case .failedLeg:
                if let ends = failedLegEnds(snapshot) {
                    try parts.facingStrip(ends.start, ends.end, width: trailWidth, material: .broken)
                }
            case .star:
                if tier.flatStars {
                    try parts.disc(centre: element.centre, radius: starRadius, sides: StarlitCartoucheTier.discSides,
                                   material: .starCore, colour: starColour)
                } else {
                    try parts.sphere(centre: element.centre, radius: starRadius, longitudes: tier.longitudes,
                                     latitudes: tier.latitudes, colour: starColour)
                }
                try parts.circle(centre: element.centre, inner: ringInner, outer: ringOuter, segments: ringSegments,
                                 material: .starNotches, angles: true, second: Double(notchCount(i)))
                if markedStar(snapshot) == i {
                    try parts.circle(centre: element.centre, inner: markRadius - markWidth / 2,
                                     outer: markRadius + markWidth / 2, segments: ringSegments, material: .broken)
                }
            case .ship:
                try parts.arrow(centre: element.centre, heading: shipHeading(snapshot))
            case .beacon:
                try parts.circle(centre: element.centre, inner: beaconRadius - ringWidth / 2,
                                 outer: beaconRadius + ringWidth / 2, segments: ringSegments + 8, material: .beaconRing)
            case .chosen:
                try parts.circle(centre: element.centre, inner: chosenRadius - ringWidth / 2,
                                 outer: chosenRadius + ringWidth / 2, segments: 2 * ringSegments,
                                 material: .chosenRing, angles: true)
            case .cartouche:
                try cartouche(&parts, snapshot, centre: element.centre, symbol: symbol, drawn: drawn,
                              strokeColour: trailColour)
            case .actionsBar:
                let barHalf: SIMD2<Double> = SIMD2(barFill * actionsSlot(snapshot) / 2, barHeight / 2)
                try parts.rectangle(centre: element.centre, half: barHalf,
                                    material: i < litActions(snapshot) ? .actionsLit : .actionsUnlit)
                if marksActionsBars(snapshot) {
                    try parts.frame(centre: element.centre, inner: barHalf,
                                    outer: barHalf + SIMD2(markWidth, markWidth), material: .broken)
                }
            case .beatTrack:
                let trackHalf: SIMD2<Double> = SIMD2((gaugeEnd - gaugeStart) / 2, trackHeight / 2)
                let left: SIMD3<Double> = element.centre - basis.right * trackHalf.x
                let fill: Double = trackFill(snapshot)
                let filled: Double = 2 * trackHalf.x * fill
                if fill < 1 {
                    let rest: Double = 2 * trackHalf.x - filled
                    try parts.rectangle(centre: left + basis.right * (filled + rest / 2),
                                        half: SIMD2(rest / 2, trackHalf.y), material: .beatTrackRest)
                }
                if fill > 0 {
                    try parts.rectangle(centre: left + basis.right * (filled / 2), half: SIMD2(filled / 2, trackHalf.y),
                                        material: .beatTrack)
                }
                if marksBeatTrack(snapshot) {
                    try parts.frame(centre: element.centre, inner: trackHalf,
                                    outer: trackHalf + SIMD2(markWidth, markWidth), material: .broken)
                }
            case .waitPip:
                try parts.rectangle(centre: element.centre, half: SIMD2(pipSide / 2, pipSide / 2),
                                    material: i < litPips(snapshot) ? .waitLit : .waitUnlit)
            }
        }
        return parts.built()
    }

    /// Draws the cartouche around `centre`: the grid's 6 + 6 lines, every symbol stroke between its stars' glyph points
    /// (dashed by the shader until drawn, then solid in
    /// `strokeColour`) and a stray stroke a failure drew in the broken colour.
    static func cartouche(_ parts: inout Parts, _ snapshot: StarlitCartoucheSceneSnapshot, centre: SIMD3<Double>,
                          symbol: Set<Int>, drawn: Set<Int>, strokeColour: SIMD3<Double>) throws(MeshError) {
        let right: SIMD3<Double> = parts.basis.right
        let up: SIMD3<Double> = parts.basis.up
        let half: Double = cartoucheWidth / 2
        let cell: Double = cartoucheWidth / Double(cartoucheCells)
        for k in 0...cartoucheCells {
            let o: Double = -half + Double(k) * cell
            try parts.facingStrip(centre + right * o - up * half, centre + right * o + up * half, width: gridLine,
                                  material: .cartoucheGrid)
            try parts.facingStrip(centre - right * half + up * o, centre + right * half + up * o, width: gridLine,
                                  material: .cartoucheGrid)
        }
        func point(_ star: Int) -> SIMD3<Double> {
            let g: SIMD2<Double> = glyphOffset(snapshot.stars[star].glyph)
            return centre + right * g.x + up * g.y
        }
        let count: Int = snapshot.stars.count
        for index in snapshot.corridors.indices {
            let c: StarlitCartoucheCorridor = snapshot.corridors[index]
            guard c.a >= 0, c.b < count else { continue }
            if symbol.contains(index) {
                if drawn.contains(index) {
                    try parts.facingStrip(point(c.a), point(c.b), width: strokeWidth, material: .strokeDrawn,
                                          colour: strokeColour)
                } else {
                    try parts.alongStrip(point(c.a), point(c.b), width: strokeWidth, material: .strokeUndrawn)
                }
            } else if markedStroke(snapshot) == index {
                try parts.facingStrip(point(c.a), point(c.b), width: strokeWidth, material: .broken)
            }
        }
    }

    /// The glow with fallback colours (the base colour times the factor) for the shared unlit renderer:
    /// `tier.glowShells` shells k (outermost first, factor 0.5^k), each a camera-facing band from the object's edge
    /// (a_uv.y 0) to it grown by k growths (a_uv.y 1): around every star (12 sides from ``starRadius``, growth
    /// ``starGlowGrowth``, base ``StarlitCartouchePalette/glow``), the ship placed by `glide` (``shipGlowInner``,
    /// ``shipGlowGrowth``, base ``StarlitCartouchePalette/shipGlow``) and every trail (a band on each side from its
    /// half width, growth ``trailGlowGrowth``, base ``StarlitCartouchePalette/trailGlow``); each lifted 0.001 · k
    /// towards the eye. a_normal is the base colour and a_uv.x ``StarlitCartoucheShaders/GlowKind/code(factor:)``.
    /// Empty at level-2.
    public static func glowPart(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier,
                                glide: Double = 1) throws(MeshError) -> StarlitCartoucheColouredMesh {
        typealias P = StarlitCartouchePalette
        let view: StarlitCartoucheCamera = camera(snapshot, aspect: 1)
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = viewBasis(view)
        var parts: Parts = Parts(eye: view.eye, basis: basis)
        let shells: Int = max(tier.glowShells, 0)
        guard shells > 0 else { return parts.built() }
        let towards: SIMD3<Double> = basis.forward * -1
        let trails: Bool = snapshot.departures.count == snapshot.legs.count
            && snapshot.arrivals.count == snapshot.legs.count
        for k in stride(from: shells, through: 1, by: -1) {
            let factor: Double = pow(glowWeight, Double(k))
            let lift: SIMD3<Double> = towards * (glowLift * Double(k))
            for index in snapshot.stars.indices {
                try parts.glowBand(centre: starCentre(index, snapshot) + lift, inner: starRadius,
                                   outer: starRadius + starGlowGrowth * Double(k), base: P.glow,
                                   code: StarlitCartoucheShaders.GlowKind.star.code(factor: factor), factor: factor)
            }
            if !snapshot.stars.isEmpty {
                try parts.glowBand(centre: shipPlace(snapshot, glide: glide) + lift, inner: shipGlowInner,
                                   outer: shipGlowInner + shipGlowGrowth * Double(k), base: P.shipGlow,
                                   code: StarlitCartoucheShaders.GlowKind.ship.code(factor: factor), factor: factor)
            }
            if trails {
                for index in snapshot.legs.indices {
                    let ends: (start: SIMD3<Double>, end: SIMD3<Double>) = trailEnds(index, snapshot)
                    try parts.glowStrip(ends.start + lift, ends.end + lift, inner: trailWidth / 2,
                                        outer: trailWidth / 2 + trailGlowGrowth * Double(k), base: P.trailGlow,
                                        code: StarlitCartoucheShaders.GlowKind.trail.code(factor: factor),
                                        factor: factor)
                }
            }
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

    /// `camera`'s unit forward, right and up vectors (from its eye towards its target, +y up).
    static func viewBasis(_ camera: StarlitCartoucheCamera) -> (forward: SIMD3<Double>, right: SIMD3<Double>,
                                                                 up: SIMD3<Double>) {
        let forward: SIMD3<Double> = unit(camera.target - camera.eye)
        let right: SIMD3<Double> = unit(cross(forward, SIMD3(0, 1, 0)))
        return (forward, right, cross(right, forward))
    }

    /// The fixed camera for `aspect`: from (1.2, 1.0, 2.8) looking at (0, −0.2, 0) with +y up; the vertical field of
    /// view is the smallest that holds every corner of the box x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 inside
    /// the view with ``fitMargin`` per side (the box is convex and in front of the eye, so every point inside it —
    /// every star at every beat, the rings, the cartouche, bars, track and pips — keeps a margin of at least 5 % for
    /// aspect 0.4 … 2.5). Independent of the snapshot (accepted for parity), the tier and the time.
    public static func camera(_ snapshot: StarlitCartoucheSceneSnapshot, aspect: Double) -> StarlitCartoucheCamera {
        _ = snapshot
        let a: Double = usableAspect(aspect)
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
        return StarlitCartoucheCamera(eye: eye, target: lookAt, fovY: fovY, aspect: a, near: near, far: far,
                                      view: view, projection: projection, viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (x right, y down), or nil when it is not finite or behind the eye.
    public static func project(_ point: SIMD3<Double>, camera: StarlitCartoucheCamera) -> SIMD2<Double>? {
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
            typealias G = StarlitCartoucheSceneGeometry
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
            typealias G = StarlitCartoucheSceneGeometry
            let side: Double = G.dot(G.cross(pb - pa, pc - pa), facing)
            if side > 0 {
                try builder.triangle(ids.0, ids.1, ids.2)
            } else if side < 0 {
                try builder.triangle(ids.0, ids.2, ids.1)
            }
        }

        /// A quad (corners in order) wound to face `facing`, with local coordinates `local`; uv.x the material's code
        /// (or `code`), a_normal per corner `slots` (default zero), in `colour` (default the material's colour) or
        /// per-corner `colours`.
        mutating func quad(_ p: [SIMD3<Double>], normal facing: SIMD3<Double>, material: Material, local: [Double],
                           colour: SIMD3<Double>? = nil, colours tints: [SIMD3<Double>]? = nil, code: Double? = nil,
                           slots: [SIMD3<Double>]? = nil) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? StarlitCartoucheSceneGeometry.colour(material)
            let value: Double = code ?? Double(material.code)
            var ids: [UInt32] = []
            for k in 0..<4 {
                ids.append(try vertex(p[k], slot: slots?[k] ?? SIMD3(0, 0, 0), code: value, local: local[k],
                                      colour: tints?[k] ?? tint))
            }
            try triangle((ids[0], ids[1], ids[2]), p[0], p[1], p[2], facing: facing)
            try triangle((ids[0], ids[2], ids[3]), p[0], p[2], p[3], facing: facing)
        }

        /// A fan through the convex `outline` around `centre` wound to face `facing`: local 0 at the centre and 1 on
        /// the outline; a_normal `slot` (default zero).
        mutating func fan(centre: SIMD3<Double>, outline: [SIMD3<Double>], facing: SIMD3<Double>, material: Material,
                          colour: SIMD3<Double>? = nil, slot: SIMD3<Double> = SIMD3(0, 0, 0)) throws(MeshError) {
            let tint: SIMD3<Double> = colour ?? StarlitCartoucheSceneGeometry.colour(material)
            let code: Double = Double(material.code)
            let c: UInt32 = try vertex(centre, slot: slot, code: code, local: 0, colour: tint)
            var ids: [UInt32] = []
            for p in outline { ids.append(try vertex(p, slot: slot, code: code, local: 1, colour: tint)) }
            for k in outline.indices {
                let j: Int = (k + 1) % outline.count
                try triangle((c, ids[k], ids[j]), centre, outline[k], outline[j], facing: facing)
            }
        }

        /// The unit direction from `point` towards the eye.
        func towardsEye(_ point: SIMD3<Double>) -> SIMD3<Double> {
            let d: SIMD3<Double> = StarlitCartoucheSceneGeometry.unit(eye - point)
            return StarlitCartoucheSceneGeometry.dot(d, d) > 0 ? d : SIMD3(0, 0, 1)
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

        /// A camera-facing rectangle of half size `half` around `centre`, as a fan.
        mutating func rectangle(centre: SIMD3<Double>, half: SIMD2<Double>, material: Material) throws(MeshError) {
            try fan(centre: centre, outline: billboard(centre, half), facing: basis.forward * -1, material: material)
        }

        /// A camera-facing frame between the half sizes `inner` and `outer` around `centre` (local −1 inner, +1 outer).
        mutating func frame(centre: SIMD3<Double>, inner: SIMD2<Double>, outer: SIMD2<Double>,
                            material: Material) throws(MeshError) {
            let a: [SIMD3<Double>] = billboard(centre, inner)
            let b: [SIMD3<Double>] = billboard(centre, outer)
            for k in 0..<4 {
                let j: Int = (k + 1) % 4
                try quad([a[k], b[k], b[j], a[j]], normal: basis.forward * -1, material: material,
                         local: [-1, 1, 1, -1])
            }
        }

        /// A flat camera-facing disc of `sides` sides and `radius` around `centre`, as a fan (local the radial
        /// coordinate), a_normal ``StarlitCartoucheShaders/viewDirection``.
        mutating func disc(centre: SIMD3<Double>, radius: Double, sides: Int, material: Material,
                           colour: SIMD3<Double>) throws(MeshError) {
            try fan(centre: centre, outline: Array(circlePoints(centre, radius, sides).dropLast()),
                    facing: basis.forward * -1, material: material, colour: colour,
                    slot: StarlitCartoucheShaders.viewDirection)
        }

        /// A camera-facing ring between `inner` and `outer` around `centre` in `segments` quads (local −1 inner, +1
        /// outer); with `angles`, a_normal.x the angle fraction 0 … 1 (the seam's vertices repeated with 1.0) and
        /// a_normal.y `second`; a_normal zero otherwise.
        mutating func circle(centre: SIMD3<Double>, inner: Double, outer: Double, segments: Int, material: Material,
                             angles: Bool = false, second: Double = 0) throws(MeshError) {
            let a: [SIMD3<Double>] = circlePoints(centre, inner, segments)
            let b: [SIMD3<Double>] = circlePoints(centre, outer, segments)
            let n: Int = a.count - 1
            for k in 0..<n {
                let t0: Double = Double(k) / Double(n)
                let t1: Double = Double(k + 1) / Double(n)
                let s0: SIMD3<Double> = angles ? SIMD3(t0, second, 0) : SIMD3(0, 0, 0)
                let s1: SIMD3<Double> = angles ? SIMD3(t1, second, 0) : SIMD3(0, 0, 0)
                try quad([a[k], b[k], b[k + 1], a[k + 1]], normal: basis.forward * -1, material: material,
                         local: [-1, 1, 1, -1], slots: [s0, s0, s1, s1])
            }
        }

        /// A UV sphere of `radius` around `centre` with `longitudes` × `latitudes` segments (exact poles; local 0),
        /// a_normal the outward normal, wound counter-clockwise seen from outside.
        mutating func sphere(centre: SIMD3<Double>, radius: Double, longitudes: Int, latitudes: Int,
                             colour: SIMD3<Double>) throws(MeshError) {
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
                    row.append(try vertex(p, slot: n, code: Double(Material.starCore.code), local: 0, colour: colour))
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

        /// The ship: one camera-facing quad centred on `centre` spanning arrow-local ±
        /// ``StarlitCartoucheShaders/arrowQuadExtent`` (u along `heading`, half ``shipLength`` per unit; v across, half
        /// width ``shipHalfWidth`` per unit), a_normal.xy the arrow-local corner; the shader cuts the dart.
        mutating func arrow(centre: SIMD3<Double>, heading: SIMD3<Double>) throws(MeshError) {
            typealias G = StarlitCartoucheSceneGeometry
            let towards: SIMD3<Double> = towardsEye(centre)
            var side: SIMD3<Double> = G.unit(G.cross(towards, heading))
            if G.dot(side, side) == 0 { side = basis.up }
            let e: Double = StarlitCartoucheShaders.arrowQuadExtent
            let corners: [SIMD2<Double>] = [SIMD2(-e, -e), SIMD2(e, -e), SIMD2(e, e), SIMD2(-e, e)]
            var p: [SIMD3<Double>] = []
            var slots: [SIMD3<Double>] = []
            for c in corners {
                p.append(centre + heading * (c.x * G.shipLength / 2) + side * (c.y * G.shipHalfWidth))
                slots.append(SIMD3(c.x, c.y, 0))
            }
            try quad(p, normal: towards, material: .ship, local: [0, 0, 0, 0], slots: slots)
        }

        /// A camera-facing strip of `width` from `a` to `b` (local −1 … +1 across it), a_normal `aux.start` at `a` and
        /// `aux.end` at `b` (default zero).
        mutating func facingStrip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double, material: Material,
                                  aux: (start: SIMD3<Double>, end: SIMD3<Double>) = (SIMD3(0, 0, 0), SIMD3(0, 0, 0)),
                                  colour: SIMD3<Double>? = nil) throws(MeshError) {
            typealias G = StarlitCartoucheSceneGeometry
            let direction: SIMD3<Double> = b - a
            guard G.dot(direction, direction) > 0 else { return }
            let towards: SIMD3<Double> = towardsEye((a + b) / 2)
            var side: SIMD3<Double> = G.unit(G.cross(direction, towards))
            if G.dot(side, side) == 0 { side = basis.right }
            let w: SIMD3<Double> = side * (width / 2)
            try quad([a + w, b + w, b - w, a - w], normal: towards, material: material, local: [-1, -1, 1, 1],
                     colour: colour, slots: [aux.start, aux.end, aux.end, aux.start])
        }

        /// A camera-facing strip of `width` from `a` to `b` with a_normal.x the distance along it in world units (0 at
        /// `a`), for the shader's dashes and stripes.
        mutating func alongStrip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, width: Double,
                                 material: Material) throws(MeshError) {
            let d: SIMD3<Double> = b - a
            let length: Double = StarlitCartoucheSceneGeometry.dot(d, d).squareRoot()
            try facingStrip(a, b, width: width, material: material, aux: (SIMD3(0, 0, 0), SIMD3(length, 0, 0)))
        }

        /// A glow band: a camera-facing 12-sided ring from `inner` (a_uv.y 0) to `outer` (a_uv.y 1) around `centre`,
        /// a_normal the base colour, a_uv.x `code`, coloured base · factor.
        mutating func glowBand(centre: SIMD3<Double>, inner: Double, outer: Double, base: SIMD3<Double>, code: Double,
                               factor: Double) throws(MeshError) {
            let sides: Int = StarlitCartoucheSceneGeometry.glowSides
            let a: [SIMD3<Double>] = circlePoints(centre, inner, sides)
            let b: [SIMD3<Double>] = circlePoints(centre, outer, sides)
            for k in 0..<(a.count - 1) {
                try quad([a[k], b[k], b[k + 1], a[k + 1]], normal: basis.forward * -1, material: .firmament,
                         local: [0, 1, 1, 0], colour: base * factor, code: code, slots: [base, base, base, base])
            }
        }

        /// A glow strip: on each side of the segment `a` … `b`, a camera-facing band from `inner` (a_uv.y 0) to `outer`
        /// (a_uv.y 1) off its axis; a_normal the base colour, a_uv.x `code`.
        mutating func glowStrip(_ a: SIMD3<Double>, _ b: SIMD3<Double>, inner: Double, outer: Double,
                                base: SIMD3<Double>, code: Double, factor: Double) throws(MeshError) {
            typealias G = StarlitCartoucheSceneGeometry
            let direction: SIMD3<Double> = b - a
            guard G.dot(direction, direction) > 0 else { return }
            let towards: SIMD3<Double> = towardsEye((a + b) / 2)
            var side: SIMD3<Double> = G.unit(G.cross(direction, towards))
            if G.dot(side, side) == 0 { side = basis.right }
            for sign in [1.0, -1.0] {
                let i: SIMD3<Double> = side * (inner * sign)
                let o: SIMD3<Double> = side * (outer * sign)
                try quad([a + i, b + i, b + o, a + o], normal: towards, material: .firmament, local: [0, 0, 1, 1],
                         colour: base * factor, code: code, slots: [base, base, base, base])
            }
        }

        /// The coloured mesh built so far.
        func built() -> StarlitCartoucheColouredMesh {
            StarlitCartoucheColouredMesh(mesh: builder.build(), colours: colours)
        }
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }
}
