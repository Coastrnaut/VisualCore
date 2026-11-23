// HarmonicBridgesPicker — feature 414 (R02-G12-04) T-R02G1204-002 (FR-R02G1204-004, 005; SC-R02G1204-001, 004; research
// R1). Analytic, deterministic picking of a touch in the drawn Harmonic Bridges scene. Every target is projected
// through the drawn camera (`HarmonicBridgesSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect width /
// height) into view points (origin top left, y down; the size is the view's size in points), so the touch target is the
// same 22 points at every orbit and depth. In this order: a step pip whose centre
// (`HarmonicBridgesSceneGeometry.stepPip`) projects within 22 points of the touch (the nearest, ties — within 1e-6
// points — to the lower step); else the goal island, when its top centre (`HarmonicBridgesSceneGeometry.islandTop`)
// projects within 22 points; else the string whose projected segment between its islands' top centres
// (`HarmonicBridgesSceneGeometry.stringEnds`) lies within 22 points (the nearest, ties to the lower string index, so
// overlapping collinear strings go to the lower one); else empty space. Presentation only: the picker reads the drawn
// snapshot and the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Harmonic Bridges scene.
public enum HarmonicBridgesPick: Sendable, Equatable {
    /// The pip of this window step: its centre projects within ``HarmonicBridgesPicker/minimumTarget`` points of the
    /// touch (the nearest pip, ties to the lower step).
    case pip(Int)
    /// The goal island: its top centre projects within ``HarmonicBridgesPicker/minimumTarget`` points of the touch (and
    /// no pip does).
    case goal
    /// This string: its projected segment between its islands' top centres lies within
    /// ``HarmonicBridgesPicker/minimumTarget`` points of the touch (the nearest string, ties to the lower index; no pip
    /// and not the goal).
    case string(Int)
    /// Nothing: unusable input or no target within reach.
    case empty
}

/// The analytic picker of the Harmonic Bridges scene: projected step pips, the goal island's top centre and the string
/// segments, each with a 22-point minimum touch target, in that order.
public enum HarmonicBridgesPicker {
    /// The minimum touch target in view points, 22: a touch at most this far from a projected target picks it.
    public static let minimumTarget: Double = 22
    /// Distances within this many view points of the best so far count as a tie, which goes to the lower step or
    /// string index: collinear strings that overlap (level 100's strings 3, 6 and 9 run along one row of islands) are
    /// equally near mathematically, and rounding must not decide between them.
    static let tieTolerance: Double = 1e-6

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``HarmonicBridgesSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: HarmonicBridgesCamera) -> SIMD2<Double>? {
        guard usable(size), let v = HarmonicBridgesSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The shortest distance from `point` to the segment from `a` to `b`: the distance to `a` or `b` itself when the
    /// closest point is an end (so two strings sharing an island tie exactly there), to `a` when the segment has no
    /// length.
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

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``HarmonicBridgesPick/pip(_:)`` when a step pip's
    /// centre projects within ``minimumTarget`` points (the nearest, ties to the lower step); else
    /// ``HarmonicBridgesPick/goal`` when the goal island's top centre does; else ``HarmonicBridgesPick/string(_:)`` for
    /// the string whose projected segment lies nearest within ``minimumTarget`` points (ties to the lower index); else
    /// ``HarmonicBridgesPick/empty`` (also for a non-finite point or a size that is not finite and positive).
    /// Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: HarmonicBridgesSceneSnapshot,
                            orbit: HarmonicBridgesOrbit) -> HarmonicBridgesPick {
        guard point.x.isFinite, point.y.isFinite, usable(size) else { return .empty }
        let camera: HarmonicBridgesCamera = HarmonicBridgesSceneGeometry.camera(snapshot, aspect: size.x / size.y,
                                                                                orbit: orbit)
        var bestPip: Int? = nil
        var bestPipDistance: Double = Double.infinity
        for step in 0..<max(snapshot.steps, 0) {
            guard let p = viewPoint(HarmonicBridgesSceneGeometry.stepPip(step, snapshot), size: size,
                                    camera: camera) else { continue }
            let d: Double = distance(point, p)
            if d <= minimumTarget && d < bestPipDistance - tieTolerance {
                bestPip = step
                bestPipDistance = d
            }
        }
        if let step = bestPip { return .pip(step) }
        if snapshot.goal >= 0, snapshot.goal < snapshot.islands.count,
           let g = viewPoint(HarmonicBridgesSceneGeometry.islandTop(snapshot.goal, snapshot), size: size, camera: camera),
           distance(point, g) <= minimumTarget {
            return .goal
        }
        var bestString: Int? = nil
        var bestStringDistance: Double = Double.infinity
        for index in snapshot.strings.indices {
            let ends = HarmonicBridgesSceneGeometry.stringEnds(index, snapshot)
            guard let a = viewPoint(ends.a, size: size, camera: camera),
                  let b = viewPoint(ends.b, size: size, camera: camera) else { continue }
            let d: Double = segmentDistance(point, a, b)
            if d <= minimumTarget && d < bestStringDistance - tieTolerance {
                bestString = index
                bestStringDistance = d
            }
        }
        if let index = bestString { return .string(index) }
        return .empty
    }

    // MARK: Internals

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
