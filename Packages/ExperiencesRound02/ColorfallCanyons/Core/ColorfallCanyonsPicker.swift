// ColorfallCanyonsPicker — feature 344 (R02-G05-04) T-R02G0504-002 (FR-R02G0504-003, 004; SC-R02G0504-001;
// clarification "How is a touch picked?"; research R2). Analytic, deterministic picking of a touch in the drawn
// Colorfall Canyons scene. The touch point (view points, origin top left, y down) becomes the ray of the drawn camera
// (`ColorfallCanyonsSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect) through it, unprojected by the
// shared `ScreenProjection` (R02-F22). The ray is intersected with every block top — the full square of the cell
// (side u) at y = its top height, the same placement and heights as the terrain mesh — and every spring emitter column,
// an axis-aligned box of half-width 0.18·u about the cell centre from the cell top up to the emitter top (cell top +
// 0.6·u); nothing else is hit. The hit with the smallest positive ray distance wins; an emitter, or the top of a
// spring's cell, picks the spring (the smallest spring index when several share a cell), any other top picks the cell.
// When the ray hits nothing, the cell top centre or emitter top whose projection lies within 22 points of the touch
// (the minimum target) and nearest to it is picked, a spring's cell again picking the spring; otherwise the touch is on
// empty space. Exact ties go to the smaller index (cells before emitters). Presentation only: picking reads the drawn
// snapshot and orbit and never the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Colorfall Canyons scene.
public enum ColorfallCanyonsPick: Sendable, Equatable {
    /// The block top of cell `index` (row-major) that is not a spring's cell.
    case cell(Int)
    /// Spring `index` (its emitter column or its cell's top).
    case spring(Int)
    /// Nothing: the ray hit nothing and no target lies within ``ColorfallCanyonsPicker/minimumTarget`` points.
    case empty
}

/// The analytic picker of the Colorfall Canyons scene: touch ray against block tops and emitter columns, nearest hit,
/// with a 22-point minimum touch target.
public enum ColorfallCanyonsPicker {
    /// The minimum touch target in view points: when the ray hits nothing, a projected cell top centre or emitter top
    /// at most this far from the touch is picked.
    public static let minimumTarget: Double = 22
    /// The half-width of an emitter's pick box, in cells u (wider than the drawn 0.12·u column so it is easy to hit).
    public static let emitterHalfWidth: Double = 0.18

    /// The world ray of `camera` through `point` (view points, origin top left, y down) of a view of `size` points:
    /// the origin on the near plane and a unit direction away from the eye. Nil for a non-finite point, a size that is
    /// not finite and positive, a point outside the view, or a degenerate camera.
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           camera: ColorfallCanyonsCamera) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard point.x.isFinite, point.y.isFinite, size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let inverse = camera.viewProjection.inverse,
              let r = ScreenProjection.ray(through: Vec2(point.x, point.y), viewport: Vec2(size.x, size.y),
                                           inverseViewProjection: inverse) else { return nil }
        let direction: SIMD3<Double> = ColorfallCanyonsSceneGeometry.unit(SIMD3(r.direction.x, r.direction.y,
                                                                               r.direction.z))
        let origin: SIMD3<Double> = SIMD3(r.origin.x, r.origin.y, r.origin.z)
        guard direction != .zero, origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return (origin, direction)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: the nearest block top or emitter column the ray
    /// hits, else the nearest projected cell top centre or emitter top within ``minimumTarget`` points, else
    /// ``ColorfallCanyonsPick/empty``. ``ColorfallCanyonsPick/empty`` too for non-finite input, an unusable size or a
    /// point outside the view. Deterministic; exact ties go to the smaller index, cells before emitters.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ColorfallCanyonsSceneSnapshot,
                            orbit: ColorfallCanyonsOrbit) -> ColorfallCanyonsPick {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0, snapshot.cellCount > 0 else { return .empty }
        let camera: ColorfallCanyonsCamera = ColorfallCanyonsSceneGeometry.camera(snapshot, aspect: size.x / size.y,
                                                                                  orbit: orbit)
        guard let r = ray(point, size: size, camera: camera) else { return .empty }
        if let hit = nearestHit(origin: r.origin, direction: r.direction, snapshot: snapshot) { return hit }
        return nearestTarget(point, size: size, snapshot: snapshot, camera: camera)
    }

    /// The smallest spring index whose cell is `cell`, or nil.
    static func spring(at cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> Int? {
        for s in snapshot.springs.indices where snapshot.springs[s].cell == cell { return s }
        return nil
    }

    /// The pick for cell `cell`: its spring when it has one, else the cell.
    static func pick(cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> ColorfallCanyonsPick {
        if let s = spring(at: cell, snapshot) { return .spring(s) }
        return .cell(cell)
    }

    /// The nearest block top or emitter column hit by the ray from `origin` along the unit `direction`, or nil.
    static func nearestHit(origin: SIMD3<Double>, direction: SIMD3<Double>,
                           snapshot: ColorfallCanyonsSceneSnapshot) -> ColorfallCanyonsPick? {
        let u: Double = ColorfallCanyonsSceneGeometry.cellSize(snapshot)
        var best: Double = .infinity
        var result: ColorfallCanyonsPick?
        for cell in 0..<snapshot.cellCount {
            let top: SIMD3<Double> = ColorfallCanyonsSceneGeometry.cellTop(cell, snapshot)
            guard let t = slab(origin: origin, direction: direction, low: top - SIMD3(u / 2, 0, u / 2),
                               high: top + SIMD3(u / 2, 0, u / 2)), t < best else { continue }
            best = t
            result = pick(cell: cell, snapshot)
        }
        for s in snapshot.springs.indices {
            let base: SIMD3<Double> = ColorfallCanyonsSceneGeometry.cellTop(snapshot.springs[s].cell, snapshot)
            let topY: Double = ColorfallCanyonsSceneGeometry.emitterTop(s, snapshot).y
            let half: Double = emitterHalfWidth * u
            guard let t = slab(origin: origin, direction: direction, low: SIMD3(base.x - half, base.y, base.z - half),
                               high: SIMD3(base.x + half, topY, base.z + half)), t < best else { continue }
            best = t
            result = .spring(s)
        }
        return result
    }

    /// The entry distance (> 0) of the ray from `origin` along `direction` into the closed axis-aligned box `low` …
    /// `high` (a box of zero height is a horizontal square), by the slab method; nil when it misses or lies behind.
    static func slab(origin: SIMD3<Double>, direction: SIMD3<Double>, low: SIMD3<Double>,
                     high: SIMD3<Double>) -> Double? {
        var enter: Double = -.infinity
        var exit: Double = .infinity
        for axis in 0..<3 {
            let o: Double = origin[axis], d: Double = direction[axis]
            if abs(d) < 1e-15 {
                if o < low[axis] || o > high[axis] { return nil }
                continue
            }
            var t0: Double = (low[axis] - o) / d
            var t1: Double = (high[axis] - o) / d
            if t0 > t1 { swap(&t0, &t1) }
            enter = max(enter, t0)
            exit = min(exit, t1)
            if enter > exit { return nil }
        }
        guard enter > 0, enter.isFinite else { return nil }
        return enter
    }

    /// The cell top centre or emitter top projected nearest to `point` within ``minimumTarget`` points, or
    /// ``ColorfallCanyonsPick/empty``.
    static func nearestTarget(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ColorfallCanyonsSceneSnapshot,
                              camera: ColorfallCanyonsCamera) -> ColorfallCanyonsPick {
        var best: Double = .infinity
        var result: ColorfallCanyonsPick = .empty
        for cell in 0..<snapshot.cellCount {
            let top: SIMD3<Double> = ColorfallCanyonsSceneGeometry.cellTop(cell, snapshot)
            guard let d = distance(point, top, size: size, camera: camera),
                  d <= minimumTarget, d < best else { continue }
            best = d
            result = pick(cell: cell, snapshot)
        }
        for s in snapshot.springs.indices {
            let top: SIMD3<Double> = ColorfallCanyonsSceneGeometry.emitterTop(s, snapshot)
            guard let d = distance(point, top, size: size, camera: camera),
                  d <= minimumTarget, d < best else { continue }
            best = d
            result = .spring(s)
        }
        return result
    }

    /// The distance in view points from `point` to the projection of `world`; nil behind the camera.
    static func distance(_ point: SIMD2<Double>, _ world: SIMD3<Double>, size: SIMD2<Double>,
                         camera: ColorfallCanyonsCamera) -> Double? {
        guard let v = ColorfallCanyonsSceneGeometry.project(world, camera: camera) else { return nil }
        let dx: Double = v.x * size.x - point.x
        let dy: Double = v.y * size.y - point.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
