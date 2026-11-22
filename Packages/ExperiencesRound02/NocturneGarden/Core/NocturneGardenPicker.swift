// NocturneGardenPicker — feature 384 (R02-G09-04) T-R02G0904-003 (FR-R02G0904-001, 003, 004; SC-R02G0904-001;
// clarifications Q1 "How is a touch picked?", Q2 "What do taps and drags send?" and Q3 "How do two fingers behave?").
// Analytic, deterministic picking of a touch in the drawn Nocturne Garden. The touch point (view points, origin top
// left, y down; the size is the view's size in points) becomes the ray of the drawn camera
// (`NocturneGardenSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect) through it, unprojected by the shared
// `ScreenProjection` (R02-F22). In order: the lantern (its projected centre within 22 points, the minimum target); the
// blooms (the ray meets a head box, the bounds of the drawn head outline at z = 0.37, the middle of the extrusion —
// else the bloom's projected foot or head centre lies within 22 points; in each stage the bloom whose head centre is
// nearest to the eye wins, ties to the lower index); the bed cell whose square holds the ray's point on z = 0; outside
// the bed when that point lies off the bed; empty space when the ray does not meet z = 0 ahead. `sunElevation` turns a
// vertical lantern drag into whole steps of 48 points (down: a lower sun, a larger elevation) snapped to the nearest
// allowed elevation; `pinchSize` turns a pinch scale into the nearest allowed size. Presentation only: the picker reads
// the drawn snapshot and the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Nocturne Garden.
public enum NocturneGardenPick: Sendable, Equatable {
    /// The lantern (the sun): its projected centre lies within ``NocturneGardenPicker/minimumTarget`` points of the
    /// touch.
    case lantern
    /// Bloom `index` (canonical order of the snapshot): the touch ray meets its head box, or its projected foot or head
    /// centre lies within ``NocturneGardenPicker/minimumTarget`` points.
    case bloom(Int)
    /// Bed cell `index` (row · width + column, row 0 at the bottom): the ray's point on the mist plane z = 0 lies in
    /// its square.
    case cell(Int)
    /// The ray meets the mist plane z = 0 outside the bed (a drag released here removes the bloom).
    case outside
    /// Nothing: unusable input, or the ray does not meet the mist plane ahead of the eye.
    case empty
}

/// The analytic picker of the Nocturne Garden: the touch ray against the lantern, the blooms' heads and the bed, with
/// a 22-point minimum touch target; the sun steps of a lantern drag and the size of a pinch.
public enum NocturneGardenPicker {
    /// The minimum touch target in view points, 22: a touch at most this far from the lantern's projected centre picks
    /// the lantern, and at most this far from a bloom's projected foot or head centre picks that bloom.
    public static let minimumTarget: Double = 22
    /// The vertical drag in view points on the lantern that changes the elevation by one step, 48.
    public static let pointsPerSunStep: Double = 48
    /// The z of the plane the head boxes are tested on, 0.37: the middle of the head's extrusion.
    static let headPlaneZ: Double = NocturneGardenSceneGeometry.bloomZ + NocturneGardenSceneGeometry.headDepth / 2

    /// The world ray of `camera` through `point` (view points, origin top left, y down) of a view of `size` points:
    /// the origin on the near plane and a unit direction away from the eye. Nil for a non-finite point, a size that is
    /// not finite and positive, a point outside the view, or a degenerate camera.
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           camera: NocturneGardenCamera) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard point.x.isFinite, point.y.isFinite, size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let inverse = camera.viewProjection.inverse,
              let r = ScreenProjection.ray(through: Vec2(point.x, point.y), viewport: Vec2(size.x, size.y),
                                           inverseViewProjection: inverse) else { return nil }
        let direction: SIMD3<Double> = NocturneGardenSceneGeometry.unit(SIMD3(r.direction.x, r.direction.y,
                                                                              r.direction.z))
        let origin: SIMD3<Double> = SIMD3(r.origin.x, r.origin.y, r.origin.z)
        guard direction != .zero, origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return (origin, direction)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``NocturneGardenPick/lantern`` when the lantern's
    /// projected centre lies within ``minimumTarget`` points; else ``NocturneGardenPick/bloom(_:)`` for the bloom whose
    /// head box (the bounds of its drawn head outline at z = 0.37) the ray meets ahead, the one whose head centre is
    /// nearest to the eye (ties to the lower index); else the bloom whose projected foot (the anchor cell's lower-left
    /// corner at z = 0.37) or head centre (the head box's centre) lies within ``minimumTarget`` points, again the one
    /// whose head centre is nearest to the eye (ties to the lower index); else ``NocturneGardenPick/cell(_:)`` for the
    /// bed cell holding the ray's point on z = 0 (see ``bedCell(_:size:snapshot:orbit:)``); else
    /// ``NocturneGardenPick/outside`` when that point lies off the bed; else ``NocturneGardenPick/empty`` (no meeting
    /// with z = 0 ahead, non-finite input, an unusable size or a point outside the view). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: NocturneGardenSceneSnapshot,
                            orbit: NocturneGardenOrbit) -> NocturneGardenPick {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return .empty }
        if let l = projected(NocturneGardenSceneGeometry.lantern(snapshot), camera: camera, size: size),
           distance(l, point) <= minimumTarget {
            return .lantern
        }
        var boxHit: Int?
        var boxDistance: Double = .infinity
        var near: Int?
        var nearDistance: Double = .infinity
        let headHit: SIMD3<Double>? = planeHit(origin: r.origin, direction: r.direction, z: headPlaneZ)
        for index in snapshot.blooms.indices {
            let box: (min: SIMD2<Double>, max: SIMD2<Double>) = headBox(index, snapshot)
            let centre: SIMD3<Double> = headCentre(index, snapshot)
            let eyeDistance: Double = NocturneGardenSceneGeometry.length(centre - camera.eye)
            if let h = headHit, h.x >= box.min.x, h.x <= box.max.x, h.y >= box.min.y, h.y <= box.max.y,
               eyeDistance < boxDistance {
                boxDistance = eyeDistance
                boxHit = index
            }
            guard eyeDistance < nearDistance else { continue }
            var within: Bool = false
            for anchor in [footPoint(index, snapshot), centre] {
                if let p = projected(anchor, camera: camera, size: size), distance(p, point) <= minimumTarget {
                    within = true
                }
            }
            if within {
                nearDistance = eyeDistance
                near = index
            }
        }
        if let boxHit { return .bloom(boxHit) }
        if let near { return .bloom(near) }
        guard let cell = bedCell(r, snapshot: snapshot) else { return .empty }
        guard cell.inside else { return .outside }
        return .cell(cell.row * NocturneGardenSceneGeometry.columns(snapshot) + cell.column)
    }

    /// The bed cell under `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot`
    /// from `orbit`: with (x, y) the ray's point on the mist plane z = 0 and u the cell size, column = floor((x + 1) /
    /// u) and row = floor(y / u); `inside` when 0 ≤ column < width and 0 ≤ row < height. Nil when the ray does not meet
    /// z = 0 ahead of the eye (or that point is absurdly far), for non-finite input, an unusable size or a point
    /// outside the view.
    public static func bedCell(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: NocturneGardenSceneSnapshot,
                               orbit: NocturneGardenOrbit) -> (column: Int, row: Int, inside: Bool)? {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return nil }
        return bedCell(r, snapshot: snapshot)
    }

    /// The elevation after a vertical lantern drag of `drag` view points (positive downward) from `elevation`: with
    /// steps = round(drag / ``pointsPerSunStep``) (halves away from zero), the allowed elevation nearest to elevation +
    /// steps, ties to the lower. `elevation` unchanged when `allowed` is empty or `drag` is not finite.
    public static func sunElevation(from elevation: Int, drag: Double, allowed: [Int]) -> Int {
        guard drag.isFinite else { return elevation }
        let steps: Double = min(max((drag / pointsPerSunStep).rounded(), -1e6), 1e6)
        return nearest(allowed, to: Double(elevation) + steps) ?? elevation
    }

    /// The size after a pinch of `scale` (the current finger distance over the distance at the pinch's start) from
    /// `size`: the allowed size nearest to size · scale, ties to the smaller. `size` unchanged when `allowed` is empty
    /// or `scale` is not finite and positive.
    public static func pinchSize(from size: Int, scale: Double, allowed: [Int]) -> Int {
        guard scale.isFinite, scale > 0 else { return size }
        return nearest(allowed, to: Double(size) * scale) ?? size
    }

    // MARK: Internals

    /// The drawn camera for a view of `size` points, or nil for an unusable size.
    static func camera(size: SIMD2<Double>, snapshot: NocturneGardenSceneSnapshot,
                       orbit: NocturneGardenOrbit) -> NocturneGardenCamera? {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0 else { return nil }
        return NocturneGardenSceneGeometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// `world` in view points of a view of `size` points; nil behind the camera.
    static func projected(_ world: SIMD3<Double>, camera: NocturneGardenCamera,
                          size: SIMD2<Double>) -> SIMD2<Double>? {
        guard let v = NocturneGardenSceneGeometry.project(world, camera: camera) else { return nil }
        return SIMD2(v.x * size.x, v.y * size.y)
    }

    /// The distance between view points `a` and `b`.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d * d).sum().squareRoot()
    }

    /// The point where the ray meets the plane at depth `z` ahead (t > 0); nil when parallel, behind or not finite.
    static func planeHit(origin: SIMD3<Double>, direction: SIMD3<Double>, z: Double) -> SIMD3<Double>? {
        guard abs(direction.z) > 1e-15 else { return nil }
        let t: Double = (z - origin.z) / direction.z
        guard t > 0, t.isFinite else { return nil }
        let p: SIMD3<Double> = origin + direction * t
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return SIMD3(p.x, p.y, z)
    }

    /// The bounds (x, y) of bloom `index`'s drawn head outline.
    static func headBox(_ index: Int,
                        _ snapshot: NocturneGardenSceneSnapshot) -> (min: SIMD2<Double>, max: SIMD2<Double>) {
        let outline: [SIMD2<Double>] = NocturneGardenSceneGeometry.headOutline(snapshot.blooms[index], snapshot)
        var low: SIMD2<Double> = SIMD2(Double.infinity, Double.infinity)
        var high: SIMD2<Double> = SIMD2(-Double.infinity, -Double.infinity)
        for p in outline {
            low = SIMD2(min(low.x, p.x), min(low.y, p.y))
            high = SIMD2(max(high.x, p.x), max(high.y, p.y))
        }
        return (low, high)
    }

    /// The centre of bloom `index`'s head box at z = 0.37.
    static func headCentre(_ index: Int, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double> {
        let box: (min: SIMD2<Double>, max: SIMD2<Double>) = headBox(index, snapshot)
        return SIMD3((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, headPlaneZ)
    }

    /// Bloom `index`'s foot (the anchor cell's lower-left corner) at z = 0.37.
    static func footPoint(_ index: Int, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double> {
        let f: SIMD2<Double> = NocturneGardenSceneGeometry.foot(snapshot.blooms[index], snapshot)
        return SIMD3(f.x, f.y, headPlaneZ)
    }

    /// The bed cell of the ray's point on z = 0 (see ``bedCell(_:size:snapshot:orbit:)``).
    static func bedCell(_ r: (origin: SIMD3<Double>, direction: SIMD3<Double>),
                        snapshot: NocturneGardenSceneSnapshot) -> (column: Int, row: Int, inside: Bool)? {
        guard let p = planeHit(origin: r.origin, direction: r.direction, z: 0) else { return nil }
        let u: Double = NocturneGardenSceneGeometry.cellSize(snapshot)
        let c: Double = ((p.x + NocturneGardenSceneGeometry.bedHalfWidth) / u).rounded(.down)
        let row: Double = (p.y / u).rounded(.down)
        guard abs(c) < 1e9, abs(row) < 1e9 else { return nil }
        let column: Int = Int(c)
        let r: Int = Int(row)
        let inside: Bool = column >= 0 && column < NocturneGardenSceneGeometry.columns(snapshot)
            && r >= 0 && r < NocturneGardenSceneGeometry.rows(snapshot)
        return (column, r, inside)
    }

    /// The value of `values` nearest to `target`, ties to the smaller; nil for no values.
    static func nearest(_ values: [Int], to target: Double) -> Int? {
        var best: Int?
        var bestDistance: Double = .infinity
        for value in values.sorted() {
            let d: Double = abs(Double(value) - target)
            if d < bestDistance {
                bestDistance = d
                best = value
            }
        }
        return best
    }
}
