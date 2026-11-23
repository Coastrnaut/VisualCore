// EchoCartographerPicker — feature 404 (R02-G11-04) T-R02G1104-002. Analytic, deterministic picking of a touch in the
// drawn Echo Cartographer chamber. The touch point (view points, origin top left, y down; the size is the view's size in
// points) becomes the ray of the drawn camera (`EchoCartographerSceneGeometry.camera(_:aspect:orbit:)` with the view's
// aspect) through it, unprojected by the shared `ScreenProjection` (R02-F22). In order: a marker whose ring centre as
// drawn (`EchoCartographerSceneGeometry.markerCentre`, y = 0.01) projects within 22 points of the touch (the minimum
// target; the nearest, ties to the lower cell index y·W + x); else the chamber cell whose square holds the ray's point
// on the floor plane y = 0 (cell (x, y) centred at X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s); else empty space.
// Presentation only: the picker reads the drawn snapshot and the orbit and never changes the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Echo Cartographer chamber.
public enum EchoCartographerPick: Sendable, Equatable {
    /// The marker on this cell: its ring centre projects within ``EchoCartographerPicker/minimumTarget`` points of the
    /// touch (the nearest marker, ties to the lower cell index).
    case marker(EchoCartographerCell)
    /// The chamber cell whose square on the floor plane y = 0 holds the touch ray's point.
    case cell(EchoCartographerCell)
    /// Nothing: unusable input, no meeting with the floor ahead of the eye, or a point off the chamber.
    case empty
}

/// The analytic picker of the Echo Cartographer chamber: the touch ray against the markers (a 22-point minimum touch
/// target) and the floor cells.
public enum EchoCartographerPicker {
    /// The minimum touch target in view points, 22: a touch at most this far from a marker's projected ring centre
    /// picks that marker.
    public static let minimumTarget: Double = 22

    /// The world ray of `camera` through `point` (view points, origin top left, y down) of a view of `size` points:
    /// the origin on the near plane and a unit direction away from the eye. Nil for a non-finite point, a size that is
    /// not finite and positive, a point outside the view, or a degenerate camera.
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           camera: EchoCartographerCamera) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard point.x.isFinite, point.y.isFinite, size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let inverse = camera.viewProjection.inverse,
              let r = ScreenProjection.ray(through: Vec2(point.x, point.y), viewport: Vec2(size.x, size.y),
                                           inverseViewProjection: inverse) else { return nil }
        let raw: SIMD3<Double> = SIMD3(r.direction.x, r.direction.y, r.direction.z)
        let length: Double = (raw * raw).sum().squareRoot()
        guard length.isFinite, length > 0 else { return nil }
        let origin: SIMD3<Double> = SIMD3(r.origin.x, r.origin.y, r.origin.z)
        guard origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return (origin, raw / length)
    }

    /// The chamber cell under `point` (view points, origin top left, y down) in a view of `size` points showing
    /// `snapshot` from `orbit` (clamped): the cell whose square holds the ray's point (X, 0, Z) on the floor plane,
    /// x = floor(X / s + W / 2), y = floor(Z / s + H / 2) with s the cell size. Nil outside the chamber, when the ray
    /// does not meet the floor ahead of the eye, for non-finite input, an unusable size or a point outside the view.
    public static func floorCell(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: EchoCartographerSceneSnapshot,
                                 orbit: EchoCartographerOrbit) -> EchoCartographerCell? {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return nil }
        return cell(origin: r.origin, direction: r.direction, snapshot: snapshot)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``EchoCartographerPick/marker(_:)`` when a marker's
    /// ring centre projects within ``minimumTarget`` points (the nearest, ties to the lower cell index y·W + x); else
    /// ``EchoCartographerPick/cell(_:)`` of ``floorCell(_:size:snapshot:orbit:)``; else ``EchoCartographerPick/empty``
    /// (also for non-finite input, an unusable size or a point outside the view). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: EchoCartographerSceneSnapshot,
                            orbit: EchoCartographerOrbit) -> EchoCartographerPick {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return .empty }
        var best: EchoCartographerCell? = nil
        var bestDistance: Double = Double.infinity
        for index in snapshot.markers.indices {
            let marker: EchoCartographerCell = snapshot.markers[index]
            guard let p = projected(EchoCartographerSceneGeometry.markerCentre(index, snapshot), camera: camera,
                                    size: size) else { continue }
            let d: Double = distance(p, point)
            guard d <= minimumTarget else { continue }
            if precedes(marker, d, best, bestDistance, snapshot) {
                best = marker
                bestDistance = d
            }
        }
        if let marker = best { return .marker(marker) }
        if let c = cell(origin: r.origin, direction: r.direction, snapshot: snapshot) { return .cell(c) }
        return .empty
    }

    // MARK: Internals

    /// The drawn camera for a view of `size` points, or nil for an unusable size.
    static func camera(size: SIMD2<Double>, snapshot: EchoCartographerSceneSnapshot,
                       orbit: EchoCartographerOrbit) -> EchoCartographerCamera? {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0 else { return nil }
        return EchoCartographerSceneGeometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// `world` in view points of a view of `size` points; nil behind the camera.
    static func projected(_ world: SIMD3<Double>, camera: EchoCartographerCamera,
                          size: SIMD2<Double>) -> SIMD2<Double>? {
        guard let v = EchoCartographerSceneGeometry.project(world, camera: camera) else { return nil }
        return SIMD2(v.x * size.x, v.y * size.y)
    }

    /// The distance between view points `a` and `b`.
    static func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = a - b
        return (d * d).sum().squareRoot()
    }

    /// Whether the marker on `cell` at `distance` points wins over the best so far (`current` at `currentDistance`;
    /// nil: none yet): it is nearer, or equally near on a lower cell index.
    static func precedes(_ cell: EchoCartographerCell, _ distance: Double, _ current: EchoCartographerCell?,
                         _ currentDistance: Double, _ snapshot: EchoCartographerSceneSnapshot) -> Bool {
        guard let current else { return true }
        if distance != currentDistance { return distance < currentDistance }
        return cellIndex(cell, snapshot) < cellIndex(current, snapshot)
    }

    /// The row-major index y·W + x of `cell` in the chamber of `snapshot`.
    static func cellIndex(_ cell: EchoCartographerCell, _ snapshot: EchoCartographerSceneSnapshot) -> Int {
        cell.y * snapshot.width + cell.x
    }

    /// The chamber cell holding the point where the ray meets the floor plane y = 0 ahead (t > 0); nil when parallel,
    /// behind, not finite or outside the chamber.
    static func cell(origin: SIMD3<Double>, direction: SIMD3<Double>,
                     snapshot: EchoCartographerSceneSnapshot) -> EchoCartographerCell? {
        guard abs(direction.y) > 1e-15 else { return nil }
        let t: Double = -origin.y / direction.y
        guard t > 0, t.isFinite else { return nil }
        let hit: SIMD3<Double> = origin + direction * t
        guard hit.x.isFinite, hit.z.isFinite else { return nil }
        let s: Double = EchoCartographerSceneGeometry.cellSize(snapshot)
        let fx: Double = (hit.x / s + Double(snapshot.width) / 2).rounded(.down)
        let fz: Double = (hit.z / s + Double(snapshot.height) / 2).rounded(.down)
        guard fx >= 0, fx < Double(snapshot.width), fz >= 0, fz < Double(snapshot.height) else { return nil }
        return EchoCartographerCell(x: Int(fx), y: Int(fz))
    }
}
