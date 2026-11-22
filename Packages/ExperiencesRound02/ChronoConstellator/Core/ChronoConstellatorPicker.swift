// ChronoConstellatorPicker — feature 354 (R02-G06-04) T-R02G0604-002 (FR-R02G0604-001, 002, 004; SC-R02G0604-001, 003;
// clarifications "How does a drag become a start-phase change?" and "How does scrubbing map to ticks and actions?";
// research R4). Analytic, deterministic picking of a touch in the drawn Chrono Constellator sky. The touch point (view
// points, origin top left, y down; the size is the view's size in points) becomes the ray of the drawn camera
// (`ChronoConstellatorSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect) through it, unprojected by the
// shared `ScreenProjection` (R02-F22). The ray is intersected with every star node's sphere (radius 0.3·u about the
// node centre at 0.25·u); the nearest hit wins, exact ties going to the smaller star index. Otherwise the ray meets the
// field plane y = 0: inside the grid, a hit within 0.25·u of the near edge (z ≥ halfDepth − 0.25·u) is the timeline
// band and picks its x fraction across the grid's width, any other hit picks the cell under it. Otherwise the star node
// whose projected centre lies within 22 points (the minimum target) and nearest to the touch is picked; otherwise the
// touch is on empty space. `loopIndex` gives a star drag's candidate loop index and `tick` a scrub's target tick.
// Presentation only: picking reads the drawn snapshot and orbit and never the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Chrono Constellator sky.
public enum ChronoConstellatorPick: Sendable, Equatable {
    /// Star `index`'s node (its sphere, or its projected centre within ``ChronoConstellatorPicker/minimumTarget``).
    case star(Int)
    /// The field cell `index` (row-major) outside the timeline band.
    case cell(Int)
    /// The timeline band at the near edge, at this x fraction 0 … 1 of the grid's width from its left edge.
    case timeline(Double)
    /// Nothing: no node or field hit and no star centre within ``ChronoConstellatorPicker/minimumTarget`` points.
    case empty
}

/// The analytic picker of the Chrono Constellator sky: the touch ray against the star node spheres and the field
/// plane (cells and the timeline band), with a 22-point minimum touch target.
public enum ChronoConstellatorPicker {
    /// The minimum touch target in view points: when the ray hits no node and misses the grid, a projected star node
    /// centre at most this far from the touch is picked; a star drag's loop cell is found within the same distance.
    public static let minimumTarget: Double = 22
    /// The depth of the timeline band inside the field's near edge, in cells u (0.25).
    public static let timelineBand: Double = 0.25

    /// The world ray of `camera` through `point` (view points, origin top left, y down) of a view of `size` points:
    /// the origin on the near plane and a unit direction away from the eye. Nil for a non-finite point, a size that is
    /// not finite and positive, a point outside the view, or a degenerate camera.
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           camera: ChronoConstellatorCamera) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard point.x.isFinite, point.y.isFinite, size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let inverse = camera.viewProjection.inverse,
              let r = ScreenProjection.ray(through: Vec2(point.x, point.y), viewport: Vec2(size.x, size.y),
                                           inverseViewProjection: inverse) else { return nil }
        let direction: SIMD3<Double> = ChronoConstellatorSceneGeometry.unit(SIMD3(r.direction.x, r.direction.y,
                                                                                 r.direction.z))
        let origin: SIMD3<Double> = SIMD3(r.origin.x, r.origin.y, r.origin.z)
        guard direction != .zero, origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return (origin, direction)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: the nearest star node sphere the ray hits; else the
    /// field plane hit inside the grid, ``ChronoConstellatorPick/timeline(_:)`` within ``timelineBand`` of the near
    /// edge and ``ChronoConstellatorPick/cell(_:)`` elsewhere; else the star whose projected node centre is nearest
    /// within ``minimumTarget`` points; else ``ChronoConstellatorPick/empty``. ``ChronoConstellatorPick/empty`` too for
    /// non-finite input, an unusable size, an empty grid or a point outside the view. Deterministic; exact ties go to
    /// the smaller index.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ChronoConstellatorSceneSnapshot,
                            orbit: ChronoConstellatorOrbit) -> ChronoConstellatorPick {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return .empty }
        if let star = nearestStar(origin: r.origin, direction: r.direction, snapshot: snapshot) { return .star(star) }
        if let hit = fieldHit(origin: r.origin, direction: r.direction), let cell = cell(at: hit, snapshot) {
            let u: Double = ChronoConstellatorSceneGeometry.cellSize(snapshot)
            let halfWidth: Double = Double(snapshot.columns) * u / 2
            let halfDepth: Double = Double(snapshot.rows) * u / 2
            if hit.z >= halfDepth - timelineBand * u {
                return .timeline(min(max((hit.x + halfWidth) / (2 * halfWidth), 0), 1))
            }
            return .cell(cell)
        }
        var best: Double = .infinity
        var result: ChronoConstellatorPick = .empty
        for star in snapshot.stars.indices {
            let centre: SIMD3<Double> = ChronoConstellatorSceneGeometry.starCentre(star, snapshot)
            guard let d = distance(point, centre, size: size, camera: camera), d <= minimumTarget,
                  d < best else { continue }
            best = d
            result = .star(star)
        }
        return result
    }

    /// The candidate loop index of a drag of star `star` at `point` (view points, origin top left, y down) in a view
    /// of `size` points showing `snapshot` from `orbit`: the index on the star's loop of the field cell under the point
    /// (the ray meets y = 0 inside the grid) when that cell is on the loop; else the index of the loop cell whose
    /// projected centre (y = 0) is nearest to the point within ``minimumTarget`` points (exact ties to the smaller
    /// index); else nil. Nil too for an unknown star, an empty loop or unusable input.
    public static func loopIndex(star: Int, at point: SIMD2<Double>, size: SIMD2<Double>,
                                 snapshot: ChronoConstellatorSceneSnapshot,
                                 orbit: ChronoConstellatorOrbit) -> Int? {
        guard snapshot.stars.indices.contains(star), !snapshot.stars[star].loop.isEmpty,
              let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return nil }
        let loop: [Int] = snapshot.stars[star].loop
        if let hit = fieldHit(origin: r.origin, direction: r.direction), let cell = cell(at: hit, snapshot),
           let index = loop.firstIndex(of: cell) {
            return index
        }
        var best: Double = .infinity
        var result: Int?
        for index in loop.indices {
            let centre: SIMD3<Double> = ChronoConstellatorSceneGeometry.cellCentre(loop[index], snapshot)
            guard let d = distance(point, centre, size: size, camera: camera), d <= minimumTarget,
                  d < best else { continue }
            best = d
            result = index
        }
        return result
    }

    /// The target tick of a scrub at `point` (view points, origin top left, y down) in a view of `size` points showing
    /// `snapshot` from `orbit`: round(tickLimit × f) with f = (x − left edge) / grid width of the ray's field-plane
    /// hit, clamped to 0 … 1 (the hit may lie outside the band or the grid); halves round away from zero. Nil when the
    /// ray does not meet the plane y = 0 in front of the eye, or for unusable input.
    public static func tick(at point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ChronoConstellatorSceneSnapshot,
                            orbit: ChronoConstellatorOrbit) -> Int? {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera),
              let hit = fieldHit(origin: r.origin, direction: r.direction) else { return nil }
        let u: Double = ChronoConstellatorSceneGeometry.cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let fraction: Double = min(max((hit.x + halfWidth) / (2 * halfWidth), 0), 1)
        return Int((Double(max(snapshot.tickLimit, 0)) * fraction).rounded())
    }

    // MARK: Internals

    /// The drawn camera for a view of `size` points, or nil for an unusable size or an empty grid.
    static func camera(size: SIMD2<Double>, snapshot: ChronoConstellatorSceneSnapshot,
                       orbit: ChronoConstellatorOrbit) -> ChronoConstellatorCamera? {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0, snapshot.columns > 0,
              snapshot.rows > 0 else { return nil }
        return ChronoConstellatorSceneGeometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// The star whose node sphere the ray from `origin` along the unit `direction` enters first (smallest positive
    /// distance; exact ties to the smaller index), or nil.
    static func nearestStar(origin: SIMD3<Double>, direction: SIMD3<Double>,
                            snapshot: ChronoConstellatorSceneSnapshot) -> Int? {
        let radius: Double = ChronoConstellatorSceneGeometry.nodeRadius
            * ChronoConstellatorSceneGeometry.cellSize(snapshot)
        var best: Double = .infinity
        var result: Int?
        for star in snapshot.stars.indices {
            let centre: SIMD3<Double> = ChronoConstellatorSceneGeometry.starCentre(star, snapshot)
            guard let t = sphere(origin: origin, direction: direction, centre: centre, radius: radius),
                  t < best else { continue }
            best = t
            result = star
        }
        return result
    }

    /// The smallest positive root t of |origin + t·direction − centre| = radius for a unit `direction`, from the
    /// quadratic t² + 2bt + c = 0 with b = (origin − centre)·direction and c = |origin − centre|² − radius²; nil when
    /// the ray misses the sphere or the sphere lies behind it.
    static func sphere(origin: SIMD3<Double>, direction: SIMD3<Double>, centre: SIMD3<Double>,
                       radius: Double) -> Double? {
        let oc: SIMD3<Double> = origin - centre
        let b: Double = ChronoConstellatorSceneGeometry.dot(oc, direction)
        let c: Double = ChronoConstellatorSceneGeometry.dot(oc, oc) - radius * radius
        let discriminant: Double = b * b - c
        guard discriminant >= 0, discriminant.isFinite else { return nil }
        let root: Double = discriminant.squareRoot()
        let near: Double = -b - root
        if near > 0 { return near }
        let far: Double = -b + root
        return far > 0 ? far : nil
    }

    /// The point where the ray from `origin` along `direction` meets the field plane y = 0 in front of it, or nil.
    static func fieldHit(origin: SIMD3<Double>, direction: SIMD3<Double>) -> SIMD3<Double>? {
        guard abs(direction.y) > 1e-15 else { return nil }
        let t: Double = -origin.y / direction.y
        guard t > 0, t.isFinite else { return nil }
        let hit: SIMD3<Double> = origin + direction * t
        return SIMD3(hit.x, 0, hit.z)
    }

    /// The row-major cell under the field point `hit` (column ⌊(x + halfWidth) / u⌋, row ⌊(z + halfDepth) / u⌋, the far
    /// and right edges belonging to the last row and column), or nil outside the grid.
    static func cell(at hit: SIMD3<Double>, _ snapshot: ChronoConstellatorSceneSnapshot) -> Int? {
        guard snapshot.columns > 0, snapshot.rows > 0 else { return nil }
        let u: Double = ChronoConstellatorSceneGeometry.cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let halfDepth: Double = Double(snapshot.rows) * u / 2
        guard abs(hit.x) <= halfWidth, abs(hit.z) <= halfDepth else { return nil }
        let column: Int = min(max(Int(((hit.x + halfWidth) / u).rounded(.down)), 0), snapshot.columns - 1)
        let row: Int = min(max(Int(((hit.z + halfDepth) / u).rounded(.down)), 0), snapshot.rows - 1)
        return row * snapshot.columns + column
    }

    /// The distance in view points from `point` to the projection of `world`; nil behind the camera.
    static func distance(_ point: SIMD2<Double>, _ world: SIMD3<Double>, size: SIMD2<Double>,
                         camera: ChronoConstellatorCamera) -> Double? {
        guard let v = ChronoConstellatorSceneGeometry.project(world, camera: camera) else { return nil }
        let dx: Double = v.x * size.x - point.x
        let dy: Double = v.y * size.y - point.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
