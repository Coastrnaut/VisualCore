// StarlitCartouchePicker — feature 454 (R02-G16-04) T-R02G1604-002 (FR-R02G1604-002, 005; SC-R02G1604-001, 004;
// clarifications Q1, Q3). Analytic, deterministic picking of a touch in the drawn Starlit Cartouche chart. Everything
// is projected through the drawn camera (`StarlitCartoucheSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect
// width / height) into view points (origin top left, x right, y down; the size is the view's size in points), with the
// launch preview included (the stars sit at their launch positions, `StarlitCartoucheSceneGeometry.launchCentre`):
//   - a star is hit when the touch lies within its projected ring radius — the ring's outer radius
//     ``StarlitCartoucheSceneGeometry/ringOuter`` (0.098) converted to view points at the star's depth along the view
//     axis, 0.098 / (depth · tan(fovY / 2)) · height / 2 — grown by ``StarlitCartouchePicker/starAllowance`` (8)
//     points; of several hits the front-most wins: the star the painter's order
//     (`StarlitCartoucheSceneGeometry.paintOrder(_:camera:)`) draws last. A hit on the ship's star is the ship;
//   - else the time slider: the bounding box of the nine wait pips' projected corners (each pip a camera-facing square
//     of side ``StarlitCartoucheSceneGeometry/pipSide`` about `waitPip(j)`) grown by 8 points;
//   - anything else (corridors, trails, hazards, the cartouche, bars, track, firmament) is empty space, as is unusable
//     input (a non-finite point, a size that is not finite and positive).
// The slider's wait is the index of the pip whose projected centre is nearest to the touch's projection onto the screen
// line through the projected centres of pips 0 and 8, clamped to 0 … 8. Presentation only: the picker reads the drawn
// snapshot and the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Starlit Cartouche chart (clarification Q1).
public enum StarlitCartouchePick: Sendable, Equatable {
    /// Star `index` (never the ship's star): the front-most star whose projected ring radius, grown by
    /// ``StarlitCartouchePicker/starAllowance`` points, holds the touch.
    case star(Int)
    /// The ship: the front-most star hit is the ship's star.
    case ship
    /// The time slider: no star is hit and the touch lies in the projected wait-pip box grown by
    /// ``StarlitCartouchePicker/starAllowance`` points.
    case slider
    /// Nothing: unusable input, or no star and not the slider.
    case empty
}

/// The analytic picker of the Starlit Cartouche chart: stars by their projected rings (front-most first), the ship's
/// star as the ship, then the wait-pip slider, each projected through the drawn camera into view points.
public enum StarlitCartouchePicker {
    /// How many view points a star's target (and the slider's box) reaches beyond its projected extent, 8.
    public static let starAllowance: Double = 8

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``StarlitCartoucheSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: StarlitCartoucheCamera) -> SIMD2<Double>? {
        guard usable(size), let v = StarlitCartoucheSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The radius in view points of a camera-facing circle of world radius `radius` about `centre` seen through
    /// `camera` in a view of `size` points: radius / (depth · tan(fovY / 2)) · height / 2, depth the centre's distance
    /// along the view axis. Nil when the centre is not in front of the eye or the size is unusable.
    public static func projectedRadius(_ radius: Double, at centre: SIMD3<Double>, size: SIMD2<Double>,
                                       camera: StarlitCartoucheCamera) -> Double? {
        typealias G = StarlitCartoucheSceneGeometry
        guard usable(size) else { return nil }
        let forward: SIMD3<Double> = G.viewBasis(camera).forward
        let depth: Double = G.dot(centre - camera.eye, forward)
        let tanHalf: Double = tan(camera.fovY / 2)
        guard depth.isFinite, depth > 0, tanHalf.isFinite, tanHalf > 0 else { return nil }
        let r: Double = radius / (depth * tanHalf) * size.y / 2
        return r.isFinite ? r : nil
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: the front-most star (drawn last in
    /// ``StarlitCartoucheSceneGeometry/paintOrder(_:camera:)``) whose projected ring radius grown by
    /// ``starAllowance`` points holds the touch — ``StarlitCartouchePick/ship`` when it is the ship's star, else
    /// ``StarlitCartouchePick/star(_:)``; else ``StarlitCartouchePick/slider`` when the touch lies in the projected
    /// wait-pip box grown by ``starAllowance`` points; else ``StarlitCartouchePick/empty`` (also for a non-finite point
    /// or a size that is not finite and positive). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: StarlitCartoucheSceneSnapshot,
                            orbit: StarlitCartoucheOrbit) -> StarlitCartouchePick {
        typealias G = StarlitCartoucheSceneGeometry
        guard point.x.isFinite, point.y.isFinite, usable(size) else { return .empty }
        let camera: StarlitCartoucheCamera = G.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
        let order: [StarlitCartoucheElement] = G.paintOrder(snapshot, camera: camera)
        for element in order.reversed() where element.kind == .star {
            guard let centre = viewPoint(element.centre, size: size, camera: camera),
                  let radius = projectedRadius(G.ringOuter, at: element.centre, size: size, camera: camera)
            else { continue }
            if distance(point, centre) <= radius + starAllowance {
                return element.index == snapshot.star ? .ship : .star(element.index)
            }
        }
        if let box = sliderBox(size: size, camera: camera), point.x >= box.low.x - starAllowance,
           point.x <= box.high.x + starAllowance, point.y >= box.low.y - starAllowance,
           point.y <= box.high.y + starAllowance {
            return .slider
        }
        return .empty
    }

    /// The wait the slider reads at `point` (view points) in a view of `size` points showing `snapshot` from the camera
    /// of `orbit` (clamped): the index of the wait pip whose projected centre is nearest to the point's projection onto
    /// the screen line through the projected centres of pips 0 and 8 (the lower index on ties), clamped to 0 … 8.
    /// The snapshot's chosen wait for unusable input (a non-finite point, an unusable size, a pip behind the eye).
    public static func sliderWait(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                  snapshot: StarlitCartoucheSceneSnapshot, orbit: StarlitCartoucheOrbit) -> Int {
        typealias G = StarlitCartoucheSceneGeometry
        let fallback: Int = min(max(snapshot.chosenWait, 0), G.pipCount - 1)
        guard point.x.isFinite, point.y.isFinite, usable(size) else { return fallback }
        let camera: StarlitCartoucheCamera = G.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
        var centres: [SIMD2<Double>] = []
        for index in 0..<G.pipCount {
            guard let c = viewPoint(G.waitPip(index), size: size, camera: camera) else { return fallback }
            centres.append(c)
        }
        let a: SIMD2<Double> = centres[0]
        let d: SIMD2<Double> = centres[G.pipCount - 1] - a
        let lengthSquared: Double = d.x * d.x + d.y * d.y
        guard lengthSquared > 0, lengthSquared.isFinite else { return fallback }
        let w: SIMD2<Double> = point - a
        let t: Double = (w.x * d.x + w.y * d.y) / lengthSquared
        let foot: SIMD2<Double> = a + d * t
        var best: Int = 0
        var bestDistance: Double = Double.infinity
        for index in centres.indices {
            let e: Double = distance(foot, centres[index])
            if e < bestDistance {
                bestDistance = e
                best = index
            }
        }
        return min(max(best, 0), G.pipCount - 1)
    }

    /// The bounding box (lower and upper corner, view points) of the nine wait pips' projected corners, each pip a
    /// camera-facing square of side ``StarlitCartoucheSceneGeometry/pipSide`` about its centre; nil when a corner is
    /// behind the eye or the size is unusable.
    public static func sliderBox(size: SIMD2<Double>,
                                 camera: StarlitCartoucheCamera) -> (low: SIMD2<Double>, high: SIMD2<Double>)? {
        typealias G = StarlitCartoucheSceneGeometry
        guard usable(size) else { return nil }
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(camera)
        let half: Double = G.pipSide / 2
        var low: SIMD2<Double> = SIMD2(Double.infinity, Double.infinity)
        var high: SIMD2<Double> = SIMD2(-Double.infinity, -Double.infinity)
        for index in 0..<G.pipCount {
            let centre: SIMD3<Double> = G.waitPip(index)
            for sx in [-1.0, 1.0] {
                for sy in [-1.0, 1.0] {
                    let corner: SIMD3<Double> = centre + basis.right * (half * sx) + basis.up * (half * sy)
                    guard let p = viewPoint(corner, size: size, camera: camera) else { return nil }
                    low = SIMD2(min(low.x, p.x), min(low.y, p.y))
                    high = SIMD2(max(high.x, p.x), max(high.y, p.y))
                }
            }
        }
        return (low, high)
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
