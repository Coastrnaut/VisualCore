// BackwardsAuroraPicker — feature 394 (R02-G10-04) T-R02G1004-003 (FR-R02G1004-001, 004; SC-R02G1004-001;
// clarification Q1 "How is a touch picked?"). Analytic, deterministic picking of a touch in the drawn Backwards Aurora.
// The touch point (view points, origin top left, y down; the size is the view's size in points) becomes the ray of the
// drawn camera (`BackwardsAuroraSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect) through it, unprojected
// by the shared `ScreenProjection` (R02-F22), and meets the timeline plane z = 0 at (x, y). In order: an end of the
// chosen section (its sample point projected within 22 points of the touch, the minimum target; the nearer end first,
// ties to the start); the band (x within x(start) − u/2 … x(end) + u/2 and |y| ≤ 0.7: the band with the sample column
// under x); a sample (the column x(k) ± u/2 holding x, with |y| ≤ 0.75); else empty space. `column` gives the sample
// column under a point clamped to the wave (for end drags). Presentation only: the picker reads the drawn snapshot and
// the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Backwards Aurora.
public enum BackwardsAuroraPick: Sendable, Equatable {
    /// The chosen section's start: its projected sample point lies within ``BackwardsAuroraPicker/minimumTarget``
    /// points of the touch (and no nearer than the end's).
    case start
    /// The chosen section's end: its projected sample point lies within ``BackwardsAuroraPicker/minimumTarget`` points
    /// of the touch and nearer than the start's.
    case end
    /// The band of the chosen section, with the sample column under the touch (start … end).
    case band(Int)
    /// Sample `k`: its column x(k) ± u/2 holds the ray's point on z = 0, with |y| ≤ 0.75.
    case sample(Int)
    /// Nothing: unusable input, no meeting with z = 0 ahead of the eye, or a point off the timeline.
    case empty
}

/// The analytic picker of the Backwards Aurora: the touch ray against the section's ends, the band and the sample
/// columns of the timeline plane, with a 22-point minimum touch target.
public enum BackwardsAuroraPicker {
    /// The minimum touch target in view points, 22: a touch at most this far from an end's projected sample point
    /// picks that end.
    public static let minimumTarget: Double = 22
    /// The band's vertical reach on the timeline plane, |y| ≤ 0.7 (the drawn band).
    public static let bandReach: Double = BackwardsAuroraSceneGeometry.markerReach
    /// A sample column's vertical reach on the timeline plane, |y| ≤ 0.75.
    public static let sampleReach: Double = 0.75

    /// The world ray of `camera` through `point` (view points, origin top left, y down) of a view of `size` points:
    /// the origin on the near plane and a unit direction away from the eye. Nil for a non-finite point, a size that is
    /// not finite and positive, a point outside the view, or a degenerate camera.
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           camera: BackwardsAuroraCamera) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard point.x.isFinite, point.y.isFinite, size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let inverse = camera.viewProjection.inverse,
              let r = ScreenProjection.ray(through: Vec2(point.x, point.y), viewport: Vec2(size.x, size.y),
                                           inverseViewProjection: inverse) else { return nil }
        let raw: SIMD3<Double> = SIMD3(r.direction.x, r.direction.y, r.direction.z)
        let length: Double = (raw * raw).sum().squareRoot()
        guard length.isFinite, length > 0 else { return nil }
        let direction: SIMD3<Double> = raw / length
        let origin: SIMD3<Double> = SIMD3(r.origin.x, r.origin.y, r.origin.z)
        guard origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return (origin, direction)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``BackwardsAuroraPick/start`` or
    /// ``BackwardsAuroraPick/end`` when that end's projected sample point lies within ``minimumTarget`` points (the
    /// nearer end, ties to the start); else, with (x, y) the ray's point on z = 0 and u = 2 / N,
    /// ``BackwardsAuroraPick/band(_:)`` when x lies within x(start) − u/2 … x(end) + u/2 and |y| ≤ 0.7 (the column
    /// under x, clamped to start … end); else ``BackwardsAuroraPick/sample(_:)`` when x lies within −1 … 1 (the column
    /// x(k) ± u/2 holding x, k = floor((x + 1) / u) clamped to 0 … N − 1) and |y| ≤ 0.75; else
    /// ``BackwardsAuroraPick/empty`` (also for no meeting with z = 0 ahead, non-finite input, an unusable size, a point
    /// outside the view or an empty wave). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: BackwardsAuroraSceneSnapshot,
                            orbit: BackwardsAuroraOrbit) -> BackwardsAuroraPick {
        let n: Int = snapshot.count
        guard n >= 1, let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return .empty }
        var startDistance: Double = .infinity
        var endDistance: Double = .infinity
        if let s = projected(BackwardsAuroraSceneGeometry.samplePoint(snapshot.sectionStart, snapshot), camera: camera,
                             size: size) {
            startDistance = distance(s, point)
        }
        if let e = projected(BackwardsAuroraSceneGeometry.samplePoint(snapshot.sectionEnd, snapshot), camera: camera,
                             size: size) {
            endDistance = distance(e, point)
        }
        if min(startDistance, endDistance) <= minimumTarget {
            return startDistance <= endDistance ? .start : .end
        }
        guard let hit = planeHit(origin: r.origin, direction: r.direction, z: 0) else { return .empty }
        let band: ClosedRange<Double> = BackwardsAuroraSceneGeometry.bandRange(snapshot)
        if band.contains(hit.x) && abs(hit.y) <= bandReach {
            let k: Int = rawColumn(hit.x, snapshot)
            return .band(min(max(k, snapshot.sectionStart), snapshot.sectionEnd))
        }
        let half: Double = BackwardsAuroraSceneGeometry.halfWidth
        if hit.x >= -half && hit.x <= half && abs(hit.y) <= sampleReach {
            return .sample(min(max(rawColumn(hit.x, snapshot), 0), n - 1))
        }
        return .empty
    }

    /// The sample column under `point` (view points, origin top left, y down) in a view of `size` points showing
    /// `snapshot` from `orbit`: with x the ray's point on z = 0 and u = 2 / N, floor((x + 1) / u) clamped to 0 … N − 1.
    /// Nil when the ray does not meet z = 0 ahead of the eye, for non-finite input, an unusable size, a point outside
    /// the view or an empty wave.
    public static func column(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: BackwardsAuroraSceneSnapshot,
                              orbit: BackwardsAuroraOrbit) -> Int? {
        let n: Int = snapshot.count
        guard n >= 1, let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera),
              let hit = planeHit(origin: r.origin, direction: r.direction, z: 0) else { return nil }
        return min(max(rawColumn(hit.x, snapshot), 0), n - 1)
    }

    // MARK: Internals

    /// The drawn camera for a view of `size` points, or nil for an unusable size.
    static func camera(size: SIMD2<Double>, snapshot: BackwardsAuroraSceneSnapshot,
                       orbit: BackwardsAuroraOrbit) -> BackwardsAuroraCamera? {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0 else { return nil }
        return BackwardsAuroraSceneGeometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// `world` in view points of a view of `size` points; nil behind the camera.
    static func projected(_ world: SIMD3<Double>, camera: BackwardsAuroraCamera,
                          size: SIMD2<Double>) -> SIMD2<Double>? {
        guard let v = BackwardsAuroraSceneGeometry.project(world, camera: camera) else { return nil }
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

    /// The unclamped sample column of timeline x, floor((x + 1) / u), bounded to ±10⁹ so it always fits an `Int`.
    static func rawColumn(_ x: Double, _ snapshot: BackwardsAuroraSceneSnapshot) -> Int {
        let u: Double = BackwardsAuroraSceneGeometry.spacing(snapshot)
        let f: Double = ((x + BackwardsAuroraSceneGeometry.halfWidth) / u).rounded(.down)
        return Int(min(max(f, -1e9), 1e9))
    }
}
