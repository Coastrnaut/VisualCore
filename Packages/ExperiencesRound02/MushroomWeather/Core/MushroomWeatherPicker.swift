// MushroomWeatherPicker — feature 494 (R02-G20-04) T-R02G2004-002 (FR-R02G2004-001 … 005, 007; SC-R02G2004-001, 004;
// clarifications Q1, Q3, Q4). Analytic, deterministic picking of a touch in the drawn Mushroom Weather forest.
// Everything is projected through the drawn camera (`MushroomWeatherSceneGeometry.camera(aspect:orbit:)` with the
// view's aspect width / height) into view points (origin top left, x right, y down; the size is the view's size in
// points). A world extent e at a centre c becomes e / (depth · tan(fovY / 2)) · height / 2 view points, depth c's
// distance from the eye along the view axis. Of several hits the target drawn last wins (clarification Q1: sites, then pods, then vents,
// the moon behind them all, later slots and indices last):
//   1. a vent (higher index first): within the larger half-diagonal of its projected frame (the square of side 0.9 s at
//      height 0.9 s) grown by ``MushroomWeatherPicker/markerAllowance`` (12) points of its projected centre;
//   2. a pod (the committed pods, later slots first): within its projected radius (0.18 s, 0.26 s grown by the shown
//      cycle) grown by 12 points of its projected centre (height 0.1 s);
//   3. a site (higher index first): within its projected ring radius (0.32 s) grown by 12 points of its projected
//      centre (z 0.01);
//   4. the moon: within its projected radius (0.12) grown by 12 points of its projected centre (1.15, 1.05, −0.5);
//   5. the cycle scrubber: within ``MushroomWeatherPicker/scrubberBand`` (14) points of its projected track
//      (x −0.9 … 0.9 at y −0.9, z 0);
//   6. the floor: the finger cast onto the plane z = 0 lies inside the floor rectangle (|x| ≤ C · s / 2,
//      |y| ≤ R · s / 2), i.e. inside the projected floor rectangle;
//   7. anything else (gauges, bars, backdrop, fronds) is empty space, as is unusable input (a non-finite point, a size
//      that is not finite and positive).
// A pod drag's drop target is the site whose projected centre is nearest the finger within
// ``MushroomWeatherPicker/siteReach`` (24) points (the lower index on ties) — no change (nil) when a pod (the dragged
// pod's own or another slot's) stands on it — else removal when the finger lies outside the floor rectangle (or casts
// onto no floor point), else no change. A moon drag reads the level clamp(start + round(−dy / 40), 0, 3) for the
// vertical travel dy in view points (up raises; halves away from zero). The scrubber's cycle is round(fraction ×
// cycles run) (halves away from zero), the fraction the finger's cast on the plane z = 0 along the track,
// (x + 0.9) / 1.8 clamped to 0 … 1. Presentation only: the picker reads the drawn snapshot and the view orbit and never changes the
// kernel. Modelled on feature 484's `MicroscopicAuroraPicker`.
import Foundation

/// What a touch picked in the Mushroom Weather forest (feature 494).
public enum MushroomWeatherPick: Sendable, Equatable {
    /// The pod of this slot: its projected radius grown by ``MushroomWeatherPicker/markerAllowance``.
    case pod(Int)
    /// The site of this index: its projected ring radius grown by ``MushroomWeatherPicker/markerAllowance``.
    case site(Int)
    /// The vent of this index: its projected frame's larger half-diagonal grown by
    /// ``MushroomWeatherPicker/markerAllowance``.
    case vent(Int)
    /// The moon: its projected radius grown by ``MushroomWeatherPicker/markerAllowance``.
    case moon
    /// The cycle scrubber: within ``MushroomWeatherPicker/scrubberBand`` points of its projected track.
    case scrubber
    /// The floor: inside the projected floor rectangle, away from every other target.
    case floor
    /// Nothing: unusable input, or outside every target.
    case empty
}

/// The analytic picker of the Mushroom Weather forest (see the file header).
public enum MushroomWeatherPicker {
    /// How many view points a pod's, site's, vent's or the moon's target reaches beyond its projected size, 12.
    public static let markerAllowance: Double = 12
    /// How many view points the scrubber's target reaches either side of its projected track, 14.
    public static let scrubberBand: Double = 14
    /// How many view points from a site's projected centre a dragged pod snaps to it, 24.
    public static let siteReach: Double = 24
    /// How many view points of vertical travel change the moonlight by one level, 40.
    public static let moonStep: Double = 40

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``MushroomWeatherSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: MushroomWeatherCamera) -> SIMD2<Double>? {
        guard usable(size), let v = MushroomWeatherSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The drawn camera of a view of `size` points from `orbit` (clamped): aspect width / height. Nil for a size that
    /// is not finite and positive.
    public static func camera(size: SIMD2<Double>, orbit: MushroomWeatherViewOrbit) -> MushroomWeatherCamera? {
        guard usable(size) else { return nil }
        return MushroomWeatherSceneGeometry.camera(aspect: size.x / size.y, orbit: orbit)
    }

    /// The length in view points of a world extent `extent` at `centre` seen through `camera` in a view of `size`
    /// points: extent / (depth · tan(fovY / 2)) · height / 2, depth the centre's distance along the view axis. Nil when
    /// the centre is not in front of the eye or the size is unusable.
    public static func projectedExtent(_ extent: Double, at centre: SIMD3<Double>, size: SIMD2<Double>,
                                       camera: MushroomWeatherCamera) -> Double? {
        typealias G = MushroomWeatherSceneGeometry
        guard usable(size) else { return nil }
        let forward: SIMD3<Double> = G.viewBasis(camera).forward
        let depth: Double = G.dot(centre - camera.eye, forward)
        let tanHalf: Double = tan(camera.fovY / 2)
        guard depth.isFinite, depth > 0, tanHalf.isFinite, tanHalf > 0 else { return nil }
        let r: Double = extent / (depth * tanHalf) * size.y / 2
        return r.isFinite ? r : nil
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: a vent, then a pod, then a site, then the moon (each
    /// within its projected size grown by ``markerAllowance``; the target drawn last first), then the scrubber (within
    /// ``scrubberBand`` of its projected track), then the floor (the finger cast inside the floor rectangle), else
    /// ``MushroomWeatherPick/empty`` (also for a non-finite point or a size that is not finite and positive).
    /// Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                            orbit: MushroomWeatherViewOrbit) -> MushroomWeatherPick {
        typealias G = MushroomWeatherSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(size: size, orbit: orbit) else { return .empty }
        var vent: Int = snapshot.vents.count - 1
        while vent >= 0 {
            if let reach = ventReach(vent, size: size, snapshot: snapshot, camera: view),
               let centre = viewPoint(G.ventCentre(vent, snapshot), size: size, camera: view),
               distance(point, centre) <= reach + markerAllowance {
                return .vent(vent)
            }
            vent -= 1
        }
        var slot: Int = snapshot.pods.count - 1
        while slot >= 0 {
            if let centre = G.podCentre(slot, snapshot),
               hits(point, centre: centre, extent: G.podRadius(slot, snapshot), allowance: markerAllowance,
                    size: size, camera: view) {
                return .pod(slot)
            }
            slot -= 1
        }
        let siteRadius: Double = G.siteRadius * G.scale(rows: snapshot.rows, columns: snapshot.columns)
        var index: Int = snapshot.sites.count - 1
        while index >= 0 {
            if hits(point, centre: G.siteCentre(index, snapshot), extent: siteRadius, allowance: markerAllowance,
                    size: size, camera: view) {
                return .site(index)
            }
            index -= 1
        }
        if hits(point, centre: G.moonCentre(), extent: G.moonRadius, allowance: markerAllowance, size: size,
                camera: view) {
            return .moon
        }
        if let gap = scrubberDistance(point, size: size, camera: view), gap <= scrubberBand { return .scrubber }
        if insideFloor(point, size: size, snapshot: snapshot, orbit: orbit) { return .floor }
        return .empty
    }

    /// The larger half-diagonal in view points of vent `index`'s projected frame seen through `camera`; nil when a
    /// corner does not project or the size is unusable.
    public static func ventReach(_ index: Int, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                                 camera: MushroomWeatherCamera) -> Double? {
        let corners: [SIMD3<Double>] = MushroomWeatherSceneGeometry.ventCorners(index, snapshot)
        var projected: [SIMD2<Double>] = []
        for corner in corners {
            guard let p = viewPoint(corner, size: size, camera: camera) else { return nil }
            projected.append(p)
        }
        return max(distance(projected[0], projected[2]), distance(projected[1], projected[3])) / 2
    }

    /// The distance in view points from `point` to the projected scrubber track (the scrubber points of fractions 0
    /// and 1) seen through `camera`; nil when an end does not project or the size is unusable.
    public static func scrubberDistance(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                        camera: MushroomWeatherCamera) -> Double? {
        typealias G = MushroomWeatherSceneGeometry
        guard let a = viewPoint(G.scrubberPoint(0), size: size, camera: camera),
              let b = viewPoint(G.scrubberPoint(1), size: size, camera: camera) else { return nil }
        return segmentDistance(point, a, b)
    }

    /// The point of the plane z = 0 under view point `point` (origin top left, y down) of a view of `size` points
    /// seen from the camera of `orbit` (clamped), in world units (x, y): the ray from the eye through the point cast
    /// onto the plane. Nil for a non-finite point, an unusable size, or a ray that does not meet the plane in front of
    /// the eye. `snapshot` is the drawn snapshot (the plane is the same for every level).
    public static func floorPoint(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                                  orbit: MushroomWeatherViewOrbit) -> SIMD2<Double>? {
        guard let hit = planePoint(point, size: size, orbit: orbit) else { return nil }
        return SIMD2(hit.x, hit.y)
    }

    /// Where slot `slot`'s pod dragged to `point` (view points) in a view of `size` points showing `snapshot` from the
    /// camera of `orbit` (clamped) would go: ``MushroomWeatherPreviewKind/pod(slot:target:)`` with the site whose
    /// projected centre is nearest the point within ``siteReach`` (the lower index on ties) — nil (no change) when a
    /// pod stands on that site (the dragged pod's own or another slot's); else the same kind with a nil target (removal)
    /// when the point lies outside the floor rectangle (or casts onto no floor point); else nil. Nil for unusable input
    /// (a non-finite point, an unusable size) and for a slot without a pod.
    public static func dropTarget(_ point: SIMD2<Double>, slot: Int, size: SIMD2<Double>,
                                  snapshot: MushroomWeatherSceneSnapshot,
                                  orbit: MushroomWeatherViewOrbit) -> MushroomWeatherPreviewKind? {
        typealias G = MushroomWeatherSceneGeometry
        guard point.x.isFinite, point.y.isFinite, slot >= 0, slot < snapshot.pods.count, snapshot.pods[slot] != nil,
              let view = camera(size: size, orbit: orbit) else { return nil }
        var best: Int? = nil
        var bestDistance: Double = Double.infinity
        for index in snapshot.sites.indices {
            guard let centre = viewPoint(G.siteCentre(index, snapshot), size: size, camera: view) else { continue }
            let d: Double = distance(point, centre)
            if d <= siteReach && d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        if let index = best {
            let cell: MushroomWeatherCell = snapshot.sites[index]
            for pod in snapshot.pods where pod == cell { return nil }
            return .pod(slot: slot, target: cell)
        }
        if !insideFloor(point, size: size, snapshot: snapshot, orbit: orbit) { return .pod(slot: slot, target: nil) }
        return nil
    }

    /// The moonlight level a moon drag reads after vertical travel `travel` (view points, positive downwards) from
    /// level `start`: clamp(start + round(−travel / ``moonStep``), 0, 3), halves away from zero (up raises); `start`
    /// itself (clamped) for a non-finite travel.
    public static func moonLevel(start: Int, travel: Double) -> Int {
        let levels: ClosedRange<Int> = MushroomWeatherLevel.moonlightLevels
        let base: Int = min(max(start, levels.lowerBound), levels.upperBound)
        guard travel.isFinite else { return base }
        let steps: Double = (-travel / moonStep).rounded(.toNearestOrAwayFromZero)
        let bounded: Double = min(max(steps, -Double(levels.count)), Double(levels.count))
        return min(max(base + Int(bounded), levels.lowerBound), levels.upperBound)
    }

    /// The cycle the scrubber reads at `point` (view points) in a view of `size` points showing `snapshot` from the
    /// camera of `orbit` (clamped): round(fraction × cycles run) (halves away from zero), the fraction the point's cast
    /// on the plane z = 0 along the track, (x + 0.9) / 1.8 clamped to 0 … 1; always within 0 … cycles run. The
    /// snapshot's shown cycle for unusable input (a non-finite point, an unusable size, a ray missing the plane).
    public static func scrubCycle(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                                  orbit: MushroomWeatherViewOrbit) -> Int {
        typealias G = MushroomWeatherSceneGeometry
        let cycles: Int = max(snapshot.cyclesRun, 0)
        guard let hit = planePoint(point, size: size, orbit: orbit) else {
            return min(max(snapshot.shownCycle, 0), cycles)
        }
        let raw: Double = (hit.x - G.scrubberStart) / (G.scrubberEnd - G.scrubberStart)
        let fraction: Double = raw.isFinite ? min(max(raw, 0), 1) : 0
        let cycle: Int = Int((fraction * Double(cycles)).rounded(.toNearestOrAwayFromZero))
        return min(max(cycle, 0), cycles)
    }

    // MARK: Internals

    /// Whether `point` lies within the projected `extent` of `centre` grown by `allowance` points.
    static func hits(_ point: SIMD2<Double>, centre: SIMD3<Double>, extent: Double, allowance: Double,
                     size: SIMD2<Double>, camera: MushroomWeatherCamera) -> Bool {
        guard let c = viewPoint(centre, size: size, camera: camera),
              let reach = projectedExtent(extent, at: centre, size: size, camera: camera) else { return false }
        return distance(point, c) <= reach + allowance
    }

    /// The world point of the plane z = 0 under view point `point` (see ``floorPoint(_:size:snapshot:orbit:)``).
    static func planePoint(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           orbit: MushroomWeatherViewOrbit) -> SIMD3<Double>? {
        typealias G = MushroomWeatherSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(size: size, orbit: orbit) else { return nil }
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(view)
        let tanHalf: Double = tan(view.fovY / 2)
        let x: Double = (2 * point.x / size.x - 1) * tanHalf * view.aspect
        let y: Double = (1 - 2 * point.y / size.y) * tanHalf
        let ray: SIMD3<Double> = basis.forward + basis.right * x + basis.up * y
        guard ray.z.isFinite, ray.z < 0 else { return nil }
        let t: Double = -view.eye.z / ray.z
        guard t.isFinite, t > 0 else { return nil }
        let hit: SIMD3<Double> = view.eye + ray * t
        guard hit.x.isFinite, hit.y.isFinite else { return nil }
        return SIMD3(hit.x, hit.y, 0)
    }

    /// Whether `point` casts onto the plane z = 0 inside the floor rectangle of `snapshot` (|x| ≤ C · s / 2,
    /// |y| ≤ R · s / 2); false when it casts onto no floor point.
    static func insideFloor(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                            orbit: MushroomWeatherViewOrbit) -> Bool {
        guard let hit = planePoint(point, size: size, orbit: orbit) else { return false }
        let half: SIMD2<Double> = MushroomWeatherSceneGeometry.floorHalf(snapshot)
        return abs(hit.x) <= half.x && abs(hit.y) <= half.y
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

    /// The distance from view point `p` to the segment `a` → `b` (to `a` for a segment of length 0).
    static func segmentDistance(_ p: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        let d: SIMD2<Double> = b - a
        let length2: Double = d.x * d.x + d.y * d.y
        guard length2 > 0 else { return distance(p, a) }
        let w: SIMD2<Double> = p - a
        let t: Double = min(max((w.x * d.x + w.y * d.y) / length2, 0), 1)
        return distance(p, a + d * t)
    }
}
