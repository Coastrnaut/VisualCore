// MoonlitMechanismPicker — feature 434 (R02-G14-04) T-R02G1404-002 (FR-R02G1404-005, 006; SC-R02G1404-001, 004;
// clarifications Q1, Q5). Analytic, deterministic picking of a touch in the drawn Moonlit Mechanism scene. Every target
// is projected through the drawn camera (`MoonlitMechanismSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect
// width / height) into view points (origin top left, x right, y down; the size is the view's size in points), so the
// touch targets are the same number of points at every orbit. In this order:
//   1. the lamp (`MoonlitMechanismSceneGeometry.lampCentre`) when its centre projects within 22 points of the touch;
//      else the ladder when the touch lies within 22 points of the projected segment from its bottom rung
//      (x 0.12, y 1.30, z 0.35) to its top rung (y 1.30 + 0.03 · (lampHeights − 1));
//   2. a key-frame card (`MoonlitMechanismSceneGeometry.card`, cardWidth × cardHeight on the plane z = −0.6) when the
//      touch lies inside its projected rectangle (a convex quadrilateral) or its centre projects within 22 points; of
//      several, the nearest projected centre, ties (within 1e-6 points) to the lower index;
//   3. a gear when the touch lies inside its projected outline circle grown by 8 points: the circle of world radius
//      R + tooth = (3.4 + 0.35) · s about the gear's centre on its plane, whose projected radius is the largest
//      projected distance from the centre of eight points on that circle (every 45° from +x), so the target never
//      shrinks below the drawn teeth at any orbit; of several, the front-most — the one drawn last
//      (`MoonlitMechanismSceneGeometry.gearOrder`: higher depth, then higher index);
//   4. else empty space (the wall, the pips, the moves bars and the backdrop are never targets).
// Unusable input (a non-finite point, a size that is not finite and positive) picks nothing. `angle(of:about:)` is the
// finger's angle about a gear's projected centre for the gear drag, measured clockwise on screen. Presentation only:
// the picker reads the drawn snapshot and the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Moonlit Mechanism scene.
public enum MoonlitMechanismPick: Sendable, Equatable {
    /// The lamp: its centre projects within ``MoonlitMechanismPicker/minimumTarget`` points of the touch.
    case lamp
    /// The lamp's height ladder: the touch lies within ``MoonlitMechanismPicker/minimumTarget`` points of the projected
    /// segment from its bottom rung to its top rung (and not on the lamp).
    case ladder
    /// Key-frame card `index`: the touch lies inside its projected rectangle or its centre projects within
    /// ``MoonlitMechanismPicker/minimumTarget`` points (the nearest centre, ties to the lower index; no lamp or
    /// ladder).
    case card(Int)
    /// Gear `index`: the touch lies inside its projected outline circle grown by
    /// ``MoonlitMechanismPicker/gearAllowance`` points (the front-most such gear; no lamp, ladder or card).
    case gear(Int)
    /// Nothing: unusable input or no target within reach.
    case empty
}

/// The analytic picker of the Moonlit Mechanism scene: the lamp and its ladder, the key-frame cards and the gears, in
/// that order, each projected through the drawn camera into view points.
public enum MoonlitMechanismPicker {
    /// The minimum touch target in view points, 22: a touch at most this far from the lamp's projected centre, the
    /// ladder's projected segment or a card's projected centre picks it.
    public static let minimumTarget: Double = 22
    /// How many view points a gear's target reaches beyond its projected outline circle, 8.
    public static let gearAllowance: Double = 8
    /// Distances within this many view points of the best so far count as a tie, which goes to the lower index.
    static let tieTolerance: Double = 1e-6
    /// The directions (every 45° from +x, in the gear's plane) sampled for a gear's projected outline radius.
    static let outlineSamples: Int = 8

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``MoonlitMechanismSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: MoonlitMechanismCamera) -> SIMD2<Double>? {
        guard usable(size), let v = MoonlitMechanismSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The shortest distance from `point` to the segment from `a` to `b`: the distance to `a` or `b` itself when the
    /// closest point is an end, to `a` when the segment has no length.
    public static func segmentDistance(_ point: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = b - a
        let lengthSquared: Double = d.x * d.x + d.y * d.y
        guard lengthSquared > 0 else { return distance(point, a) }
        let w: SIMD2<Double> = point - a
        let t: Double = (w.x * d.x + w.y * d.y) / lengthSquared
        if t <= 0 { return distance(point, a) }
        if t >= 1 { return distance(point, b) }
        return distance(point, a + d * t)
    }

    /// The projected centre of gear `gear` in view points (origin top left, y down) of a view of `size` points showing
    /// `snapshot` from the camera of `orbit` (clamped) with aspect width / height: the pivot the gear drag measures its
    /// angle about. Nil for a gear index outside the snapshot, a size that is not finite and positive, or a centre
    /// behind the eye.
    public static func gearCentre(_ gear: Int, size: SIMD2<Double>, snapshot: MoonlitMechanismSceneSnapshot,
                                  orbit: MoonlitMechanismOrbit) -> SIMD2<Double>? {
        guard gear >= 0, gear < snapshot.gears.count, usable(size) else { return nil }
        let camera: MoonlitMechanismCamera = MoonlitMechanismSceneGeometry.camera(snapshot, aspect: size.x / size.y,
                                                                                  orbit: orbit)
        return viewPoint(MoonlitMechanismSceneGeometry.gearCentre(gear, snapshot), size: size, camera: camera)
    }

    /// The angle in radians of `point` about `centre`, both in view points with the origin top left and y growing
    /// downward, measured clockwise on screen: atan2(point.y − centre.y, point.x − centre.x), so 0 points right, π/2
    /// straight down, −π/2 straight up, and the range is −π … π (π for a point straight left). A point on the centre,
    /// or any non-finite input, gives 0. A finger moving clockwise on screen increases the angle (modulo 2π).
    public static func angle(of point: SIMD2<Double>, about centre: SIMD2<Double>) -> Double {
        let dx: Double = point.x - centre.x
        let dy: Double = point.y - centre.y
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return 0 }
        return atan2(dy, dx)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``MoonlitMechanismPick/lamp`` when the lamp's centre
    /// projects within ``minimumTarget`` points; else ``MoonlitMechanismPick/ladder`` within ``minimumTarget`` points
    /// of the projected bottom-to-top rung segment; else ``MoonlitMechanismPick/card(_:)`` for the card whose projected
    /// rectangle holds the touch or whose centre projects within ``minimumTarget`` points (the nearest centre, ties to
    /// the lower index); else ``MoonlitMechanismPick/gear(_:)`` for the front-most gear (drawn last: higher depth, then
    /// higher index) whose projected outline circle of radius (3.4 + 0.35) · s, grown by ``gearAllowance`` points,
    /// holds the touch; else ``MoonlitMechanismPick/empty`` (also for a non-finite point or a size that is not finite
    /// and positive). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MoonlitMechanismSceneSnapshot,
                            orbit: MoonlitMechanismOrbit) -> MoonlitMechanismPick {
        guard point.x.isFinite, point.y.isFinite, usable(size) else { return .empty }
        typealias Geometry = MoonlitMechanismSceneGeometry
        let camera: MoonlitMechanismCamera = Geometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
        // 1. The lamp, then its ladder.
        if let lamp = viewPoint(Geometry.lampCentre(snapshot), size: size, camera: camera),
           distance(point, lamp) <= minimumTarget {
            return .lamp
        }
        let ends: (bottom: SIMD3<Double>, top: SIMD3<Double>) = ladderEnds(snapshot)
        if let a = viewPoint(ends.bottom, size: size, camera: camera),
           let b = viewPoint(ends.top, size: size, camera: camera),
           segmentDistance(point, a, b) <= minimumTarget {
            return .ladder
        }
        // 2. The key-frame cards: inside the projected rectangle or the centre within reach; the nearest centre wins.
        var bestCard: Int? = nil
        var bestCardDistance: Double = Double.infinity
        let half: SIMD2<Double> = SIMD2(Geometry.cardWidth(snapshot) / 2, Geometry.cardHeight / 2)
        for index in snapshot.keyFrames.indices {
            let centre3: SIMD3<Double> = Geometry.card(index, snapshot)
            guard let centre = viewPoint(centre3, size: size, camera: camera) else { continue }
            let d: Double = distance(point, centre)
            var hit: Bool = d <= minimumTarget
            if !hit, let quad = projectedRectangle(centre3, half: half, size: size, camera: camera) {
                hit = inside(point, quad)
            }
            if hit && d < bestCardDistance - tieTolerance {
                bestCard = index
                bestCardDistance = d
            }
        }
        if let index = bestCard { return .card(index) }
        // 3. The gears, front-most first (the reverse of the painter's order).
        let reach: Double = outlineRadius(snapshot)
        for index in Geometry.gearOrder(snapshot).reversed() {
            let centre3: SIMD3<Double> = Geometry.gearCentre(index, snapshot)
            guard let centre = viewPoint(centre3, size: size, camera: camera),
                  let radius = projectedRadius(centre3, centre, world: reach, size: size, camera: camera) else {
                continue
            }
            if distance(point, centre) <= radius + gearAllowance { return .gear(index) }
        }
        return .empty
    }

    // MARK: Internals

    /// The world outline radius of every gear of `snapshot`: R + tooth = (3.4 + 0.35) · s.
    static func outlineRadius(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double {
        (MoonlitMechanismSceneGeometry.rimRadius + MoonlitMechanismSceneGeometry.toothHeight)
            * MoonlitMechanismSceneGeometry.cellSize(snapshot)
    }

    /// The ladder's bottom rung (k = 0) and top rung (k = lampHeights − 1) centres: (0.12, 1.30 + 0.03 · k, 0.35).
    static func ladderEnds(_ snapshot: MoonlitMechanismSceneSnapshot) -> (bottom: SIMD3<Double>, top: SIMD3<Double>) {
        typealias Geometry = MoonlitMechanismSceneGeometry
        let rungs: Int = max(snapshot.lampHeights, 1)
        let top: Double = Geometry.lampBaseY + Geometry.lampStep * Double(rungs - 1)
        return (bottom: SIMD3(Geometry.ladderX, Geometry.lampBaseY, Geometry.lampZ),
                top: SIMD3(Geometry.ladderX, top, Geometry.lampZ))
    }

    /// The projected corners (in order around the rectangle) of the rectangle of half sizes `half` about `centre` in
    /// its plane z = centre.z; nil when a corner is behind the eye.
    static func projectedRectangle(_ centre: SIMD3<Double>, half: SIMD2<Double>, size: SIMD2<Double>,
                                   camera: MoonlitMechanismCamera) -> [SIMD2<Double>]? {
        let signs: [SIMD2<Double>] = [SIMD2(-1, -1), SIMD2(1, -1), SIMD2(1, 1), SIMD2(-1, 1)]
        var quad: [SIMD2<Double>] = []
        for sign in signs {
            let corner: SIMD3<Double> = centre + SIMD3(sign.x * half.x, sign.y * half.y, 0)
            guard let p = viewPoint(corner, size: size, camera: camera) else { return nil }
            quad.append(p)
        }
        return quad
    }

    /// Whether `point` lies inside or on the convex polygon `polygon` (either winding).
    static func inside(_ point: SIMD2<Double>, _ polygon: [SIMD2<Double>]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var positive: Bool = false
        var negative: Bool = false
        for i in polygon.indices {
            let a: SIMD2<Double> = polygon[i]
            let b: SIMD2<Double> = polygon[(i + 1) % polygon.count]
            let side: Double = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if side > 0 { positive = true }
            if side < 0 { negative = true }
        }
        return !(positive && negative)
    }

    /// The projected radius of the circle of world radius `world` about `centre3` in its plane: the largest distance
    /// from the projected centre `centre` of the eight projected circle points every 45° from +x; nil when one is
    /// behind the eye.
    static func projectedRadius(_ centre3: SIMD3<Double>, _ centre: SIMD2<Double>, world: Double, size: SIMD2<Double>,
                                camera: MoonlitMechanismCamera) -> Double? {
        var radius: Double = 0
        for k in 0..<outlineSamples {
            let a: Double = Double(k) * 2 * Double.pi / Double(outlineSamples)
            guard let p = viewPoint(centre3 + SIMD3(cos(a) * world, sin(a) * world, 0), size: size,
                                    camera: camera) else { return nil }
            radius = max(radius, distance(p, centre))
        }
        return radius
    }

    /// Whether `size` is finite and positive in both components.
    static func usable(_ size: SIMD2<Double>) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }

    /// The distance between view points `a` and `b`.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d.x * d.x + d.y * d.y).squareRoot()
    }
}
