// AcousticConstellatorPicker — feature 424 (R02-G13-04) T-R02G1304-002 (FR-R02G1304-004, 005; SC-R02G1304-001, 004;
// clarifications Q1, Q4). Analytic, deterministic picking of a touch in the drawn Acoustic Constellator scene. Every
// target is projected through the drawn camera (`AcousticConstellatorSceneGeometry.camera(_:aspect:orbit:)` with the
// view's aspect width / height) into view points (origin top left, y down; the size is the view's size in points), so
// the touch target is the same 22 points at every orbit and depth. In this order: a gauge target — a coherence bar
// (`AcousticConstellatorSceneGeometry.coherenceBar`, 12 of them) or a hold pip
// (`AcousticConstellatorSceneGeometry.holdPip`, `hold` of them) whose centre projects within 22 points of the touch
// (the nearest, ties — within 1e-6 points — to the coherence bars and then the lower index); else a star whose centre
// (`AcousticConstellatorSceneGeometry.starCentre`) projects within 22 points (the nearest, ties to the lower star
// index); else a link whose projected spline (17 points of `AcousticConstellatorSceneGeometry.splinePoint`, 16
// segments) lies within 22 points (the nearest, ties to the lower link index); else empty space. The moves gauge and
// the guides are never targets. `starAt` finds the drag target (the nearest star within 22 points, one star excluded)
// and `fingerPoint` the world point under the finger on a horizontal plane (where the drag filament ends). Presentation
// only: the picker reads the drawn snapshot and the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Acoustic Constellator scene.
public enum AcousticConstellatorPick: Sendable, Equatable {
    /// Coherence bar `index` (0 … 11): its centre projects within ``AcousticConstellatorPicker/minimumTarget`` points
    /// of the touch (the nearest gauge target; ties go to the coherence bars, then the lower index).
    case coherence(Int)
    /// Hold pip `index` (0 ..< hold): its centre projects within ``AcousticConstellatorPicker/minimumTarget`` points of
    /// the touch (the nearest gauge target, no coherence bar equally near).
    case hold(Int)
    /// Star `index`: its centre projects within ``AcousticConstellatorPicker/minimumTarget`` points of the touch (the
    /// nearest star, ties to the lower index; no gauge target).
    case star(Int)
    /// Link `index` of ``AcousticConstellatorSceneSnapshot/links``: its projected spline lies within
    /// ``AcousticConstellatorPicker/minimumTarget`` points of the touch (the nearest link, ties to the lower index; no
    /// gauge target and no star).
    case link(Int)
    /// Nothing: unusable input or no target within reach.
    case empty
}

/// The analytic picker of the Acoustic Constellator scene: projected coherence bars and hold pips, star centres and
/// link splines, each with a 22-point minimum touch target, in that order.
public enum AcousticConstellatorPicker {
    /// The minimum touch target in view points, 22: a touch at most this far from a projected target picks it.
    public static let minimumTarget: Double = 22
    /// Distances within this many view points of the best so far count as a tie, which goes to the earlier candidate
    /// (coherence bars before hold pips, then the lower index), so rounding never decides between equal targets.
    static let tieTolerance: Double = 1e-6

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``AcousticConstellatorSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: AcousticConstellatorCamera) -> SIMD2<Double>? {
        guard usable(size), let v = AcousticConstellatorSceneGeometry.project(point, camera: camera) else { return nil }
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

    /// The star whose projected centre lies nearest `point` (view points, origin top left) within ``minimumTarget``
    /// points in a view of `size` points showing `snapshot` from the camera of `orbit` (clamped), ties to the lower
    /// index, star `excluding` never chosen (the dragged star): the drag target. Nil when there is none, for a
    /// non-finite point or a size that is not finite and positive.
    public static func starAt(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: AcousticConstellatorSceneSnapshot,
                              orbit: AcousticConstellatorOrbit, excluding: Int?) -> Int? {
        guard point.x.isFinite, point.y.isFinite, usable(size) else { return nil }
        let camera: AcousticConstellatorCamera = AcousticConstellatorSceneGeometry.camera(snapshot,
                                                                                          aspect: size.x / size.y,
                                                                                          orbit: orbit)
        return nearestStar(point, size: size, snapshot: snapshot, camera: camera, excluding: excluding)
    }

    /// The world point under `point` (view points, origin top left) of a view of `size` points seen through `camera`, on
    /// the horizontal plane y = `height` (the dragged star's height): where the ray from the eye through the touch meets
    /// the plane. Nil when the ray runs parallel to the plane or meets it behind the eye, or for non-finite input or a
    /// size that is not finite and positive.
    public static func fingerPoint(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: AcousticConstellatorCamera,
                                   height: Double) -> SIMD3<Double>? {
        guard point.x.isFinite, point.y.isFinite, height.isFinite, usable(size) else { return nil }
        let forward: SIMD3<Double> = AcousticConstellatorSceneGeometry.unit(camera.target - camera.eye)
        let right: SIMD3<Double> = AcousticConstellatorSceneGeometry.unit(
            AcousticConstellatorSceneGeometry.cross(forward, SIMD3(0, 1, 0)))
        let up: SIMD3<Double> = AcousticConstellatorSceneGeometry.cross(right, forward)
        let t: Double = tan(camera.fovY / 2)
        let nx: Double = 2 * point.x / size.x - 1
        let ny: Double = 1 - 2 * point.y / size.y
        let direction: SIMD3<Double> = forward + right * (nx * t * camera.aspect) + up * (ny * t)
        guard direction.y != 0, direction.y.isFinite else { return nil }
        let k: Double = (height - camera.eye.y) / direction.y
        guard k > 0, k.isFinite else { return nil }
        let p: SIMD3<Double> = camera.eye + direction * k
        guard p.x.isFinite, p.z.isFinite else { return nil }
        return SIMD3(p.x, height, p.z)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``AcousticConstellatorPick/coherence(_:)`` or
    /// ``AcousticConstellatorPick/hold(_:)`` for the gauge target whose centre projects nearest within
    /// ``minimumTarget`` points (ties to the coherence bars, then the lower index); else
    /// ``AcousticConstellatorPick/star(_:)`` for the nearest star centre within ``minimumTarget`` points (ties to the
    /// lower index); else ``AcousticConstellatorPick/link(_:)`` for the link whose projected spline (16 segments) lies
    /// nearest within ``minimumTarget`` points (ties to the lower index); else ``AcousticConstellatorPick/empty`` (also
    /// for a non-finite point or a size that is not finite and positive). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: AcousticConstellatorSceneSnapshot,
                            orbit: AcousticConstellatorOrbit) -> AcousticConstellatorPick {
        guard point.x.isFinite, point.y.isFinite, usable(size) else { return .empty }
        let camera: AcousticConstellatorCamera = AcousticConstellatorSceneGeometry.camera(snapshot,
                                                                                          aspect: size.x / size.y,
                                                                                          orbit: orbit)
        // Gauge targets: the coherence bars, then the hold pips.
        var bestGauge: AcousticConstellatorPick? = nil
        var bestGaugeDistance: Double = Double.infinity
        for index in 0..<AcousticConstellatorSceneGeometry.coherenceCount {
            guard let p = viewPoint(AcousticConstellatorSceneGeometry.coherenceBar(index, snapshot), size: size,
                                    camera: camera) else { continue }
            let d: Double = distance(point, p)
            if d <= minimumTarget && d < bestGaugeDistance - tieTolerance {
                bestGauge = .coherence(index)
                bestGaugeDistance = d
            }
        }
        for index in 0..<max(snapshot.hold, 0) {
            guard let p = viewPoint(AcousticConstellatorSceneGeometry.holdPip(index, snapshot), size: size,
                                    camera: camera) else { continue }
            let d: Double = distance(point, p)
            if d <= minimumTarget && d < bestGaugeDistance - tieTolerance {
                bestGauge = .hold(index)
                bestGaugeDistance = d
            }
        }
        if let gauge = bestGauge { return gauge }
        // Stars.
        if let star = nearestStar(point, size: size, snapshot: snapshot, camera: camera, excluding: nil) {
            return .star(star)
        }
        // Links: the shortest distance to the projected spline.
        var bestLink: Int? = nil
        var bestLinkDistance: Double = Double.infinity
        let segments: Int = AcousticConstellatorSceneGeometry.linkSegments
        for index in snapshot.links.indices {
            let link: AcousticConstellatorLink = snapshot.links[index]
            let a: SIMD3<Double> = AcousticConstellatorSceneGeometry.starCentre(link.a, snapshot)
            let b: SIMD3<Double> = AcousticConstellatorSceneGeometry.starCentre(link.b, snapshot)
            var nearest: Double = Double.infinity
            var previous: SIMD2<Double>? = nil
            for k in 0...segments {
                let world: SIMD3<Double> = AcousticConstellatorSceneGeometry.splinePoint(a, b,
                                                                                         u: Double(k) / Double(segments))
                let current: SIMD2<Double>? = viewPoint(world, size: size, camera: camera)
                if let p0 = previous, let p1 = current { nearest = min(nearest, segmentDistance(point, p0, p1)) }
                previous = current
            }
            if nearest <= minimumTarget && nearest < bestLinkDistance - tieTolerance {
                bestLink = index
                bestLinkDistance = nearest
            }
        }
        if let index = bestLink { return .link(index) }
        return .empty
    }

    // MARK: Internals

    /// The star whose projected centre lies nearest `point` within ``minimumTarget`` points (ties to the lower index),
    /// never `excluding`.
    static func nearestStar(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: AcousticConstellatorSceneSnapshot,
                            camera: AcousticConstellatorCamera, excluding: Int?) -> Int? {
        var best: Int? = nil
        var bestDistance: Double = Double.infinity
        for index in snapshot.stars.indices where index != excluding {
            guard let p = viewPoint(AcousticConstellatorSceneGeometry.starCentre(index, snapshot), size: size,
                                    camera: camera) else { continue }
            let d: Double = distance(point, p)
            if d <= minimumTarget && d < bestDistance - tieTolerance {
                best = index
                bestDistance = d
            }
        }
        return best
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
