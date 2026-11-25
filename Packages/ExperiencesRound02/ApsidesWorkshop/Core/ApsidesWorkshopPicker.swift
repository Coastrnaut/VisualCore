// ApsidesWorkshopPicker — feature 474 (R02-G18-04) T-R02G1804-002 (FR-R02G1804-001 … 003, 005; SC-R02G1804-001, 004;
// clarifications Q1, Q3, Q4). Analytic, deterministic picking of a touch in the drawn Apsides Workshop compass.
// Everything is projected through the drawn camera (`ApsidesWorkshopSceneGeometry.camera(aspect:orbit:)` with the
// view's aspect width / height) into view points (origin top left, x right, y down; the size is the view's size in
// points). A world extent e at a centre c becomes e / (depth · tan(fovY / 2)) · height / 2 view points, depth c's
// distance from the eye along the view axis. Of several hits the handle drawn last wins:
//   1. the orbiter: within its projected radius (0.03) grown by ``ApsidesWorkshopPicker/orbiterAllowance`` (8) points
//      of its projected centre w(P(shown tick));
//   2. the size handle (the apoapsis square at w(P(T/2))): within its projected half-size (0.015) grown by
//      ``ApsidesWorkshopPicker/markerAllowance`` (12) points;
//   3. the knob (the periapsis diamond at w(P(0))): within its projected half-size (0.0175) grown by 12 points;
//   4. the orbit loop: within ``ApsidesWorkshopPicker/loopBand`` (10) points of one of its projected chords
//      w(P(t)) → w(P(t + 1)) (the last back to the first);
//   5. anything else (planets, star, compass, wedges, gauges, bars, backdrop) is empty space, as is unusable input (a
//      non-finite point, a size that is not finite and positive, a snapshot without positions).
// A drag casts the finger onto the sky plane z = 0 (``ApsidesWorkshopPicker/skyPoint(_:size:orbit:)``, lattice units)
// and maps it to steps: the knob's direction d = round(angle / 15°) mod 24 (a point at the star keeps the current
// direction) and eccentricity k = round(20 − 20 r / a) clamped to 0 … 15 at the current size a; the size handle's
// a = round(20 R / (20 + k)) clamped to 8 … 48 at the current eccentricity k. The time crank's tick is the tick whose
// projected kernel position is nearest to the finger (lower on ties). Presentation only: the picker reads the drawn
// snapshot and the view orbit and never changes the kernel. Modelled on feature 464's `CelestialEclipseLabPicker`.
import Foundation

/// What a touch picked in the Apsides Workshop compass (clarification Q1).
public enum ApsidesWorkshopPick: Sendable, Equatable {
    /// The orbiter (the time crank): its projected disc grown by ``ApsidesWorkshopPicker/orbiterAllowance`` points.
    case orbiter
    /// The size handle (the apoapsis square): its projected half-size grown by
    /// ``ApsidesWorkshopPicker/markerAllowance`` points.
    case sizeHandle
    /// The knob (the periapsis diamond): its projected half-size grown by ``ApsidesWorkshopPicker/markerAllowance``
    /// points.
    case knob
    /// The orbit loop: within ``ApsidesWorkshopPicker/loopBand`` points of one of its projected chords.
    case loop
    /// Nothing: unusable input, or no handle and not the loop.
    case empty
}

/// The analytic picker of the Apsides Workshop compass: the orbiter, the size handle, the knob and the orbit loop by
/// their projections through the drawn camera; plus the sky point under a finger, the knob's and the size handle's
/// steps and the time crank's tick (see the file header).
public enum ApsidesWorkshopPicker {
    /// How many view points the orbiter's target reaches beyond its projected radius, 8.
    public static let orbiterAllowance: Double = 8
    /// How many view points an apsis marker's target reaches beyond its projected half-size, 12.
    public static let markerAllowance: Double = 12
    /// How many view points the orbit loop's target reaches either side of its projected chords, 10.
    public static let loopBand: Double = 10
    /// How close to the star (in lattice units) a sky point counts as at the star: the knob then keeps its direction.
    public static let starTolerance: Double = 1e-6

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``ApsidesWorkshopSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: ApsidesWorkshopCamera) -> SIMD2<Double>? {
        guard usable(size), let v = ApsidesWorkshopSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The drawn camera of a view of `size` points from `orbit` (clamped): aspect width / height. Nil for a size that
    /// is not finite and positive.
    public static func camera(size: SIMD2<Double>, orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopCamera? {
        guard usable(size) else { return nil }
        return ApsidesWorkshopSceneGeometry.camera(aspect: size.x / size.y, orbit: orbit)
    }

    /// The length in view points of a camera-facing world extent `extent` at `centre` seen through `camera` in a view
    /// of `size` points: extent / (depth · tan(fovY / 2)) · height / 2, depth the centre's distance along the view
    /// axis. Nil when the centre is not in front of the eye or the size is unusable.
    public static func projectedExtent(_ extent: Double, at centre: SIMD3<Double>, size: SIMD2<Double>,
                                       camera: ApsidesWorkshopCamera) -> Double? {
        typealias G = ApsidesWorkshopSceneGeometry
        guard usable(size) else { return nil }
        let forward: SIMD3<Double> = G.viewBasis(camera).forward
        let depth: Double = G.dot(centre - camera.eye, forward)
        let tanHalf: Double = tan(camera.fovY / 2)
        guard depth.isFinite, depth > 0, tanHalf.isFinite, tanHalf > 0 else { return nil }
        let r: Double = extent / (depth * tanHalf) * size.y / 2
        return r.isFinite ? r : nil
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``ApsidesWorkshopPick/orbiter`` within the orbiter's
    /// projected radius grown by ``orbiterAllowance``; else ``ApsidesWorkshopPick/sizeHandle`` within the apoapsis
    /// square's projected half-size grown by ``markerAllowance``; else ``ApsidesWorkshopPick/knob`` within the
    /// periapsis diamond's likewise; else ``ApsidesWorkshopPick/loop`` within ``loopBand`` of a projected chord of the
    /// current orbit's kernel positions; else ``ApsidesWorkshopPick/empty`` (also for a non-finite point, a size that
    /// is not finite and positive or a snapshot without positions). Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                            orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopPick {
        typealias G = ApsidesWorkshopSceneGeometry
        guard point.x.isFinite, point.y.isFinite, !snapshot.positions.isEmpty,
              let view = camera(size: size, orbit: orbit) else { return .empty }
        let handles: [(pick: ApsidesWorkshopPick, centre: SIMD3<Double>, extent: Double, allowance: Double)] = [
            (pick: .orbiter, centre: G.orbiterCentre(snapshot), extent: G.orbiterRadius, allowance: orbiterAllowance),
            (pick: .sizeHandle, centre: G.handleCentre(snapshot), extent: G.apoapsisSize / 2,
             allowance: markerAllowance),
            (pick: .knob, centre: G.knobCentre(snapshot), extent: G.periapsisSize / 2, allowance: markerAllowance),
        ]
        for handle in handles {
            guard let centre = viewPoint(handle.centre, size: size, camera: view),
                  let reach = projectedExtent(handle.extent, at: handle.centre, size: size, camera: view) else {
                continue
            }
            if distance(point, centre) <= reach + handle.allowance { return handle.pick }
        }
        if let gap = loopDistance(point, size: size, snapshot: snapshot, camera: view), gap <= loopBand {
            return .loop
        }
        return .empty
    }

    /// The distance in view points from `point` to the nearest projected chord w(P(t)) → w(P(t + 1)) of `snapshot`'s
    /// current orbit (the last back to the first) seen through `camera`; nil when no chord projects (every position
    /// behind the eye, no positions) or the size is unusable.
    public static func loopDistance(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                    snapshot: ApsidesWorkshopSceneSnapshot,
                                    camera: ApsidesWorkshopCamera) -> Double? {
        typealias G = ApsidesWorkshopSceneGeometry
        let n: Int = snapshot.positions.count
        guard n > 0, usable(size) else { return nil }
        var projected: [SIMD2<Double>?] = []
        for p in snapshot.positions {
            projected.append(viewPoint(G.world(p, depth: G.planeZ), size: size, camera: camera))
        }
        var best: Double? = nil
        for t in 0..<n {
            guard let a = projected[t], let b = projected[(t + 1) % n] else { continue }
            let d: Double = segmentDistance(point, a, b)
            if best == nil || d < best! { best = d }
        }
        return best
    }

    /// The point of the sky plane z = 0 under view point `point` (origin top left, y down) of a view of `size` points
    /// seen from the camera of `orbit` (clamped), in lattice units (world / (s · 256)): the ray from the eye through
    /// the point cast onto the plane. Nil for a non-finite point, an unusable size, or a ray that does not meet the
    /// plane in front of the eye.
    public static func skyPoint(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                orbit: ApsidesWorkshopViewOrbit) -> SIMD2<Double>? {
        typealias G = ApsidesWorkshopSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(size: size, orbit: orbit) else { return nil }
        let basis: (forward: SIMD3<Double>, right: SIMD3<Double>, up: SIMD3<Double>) = G.viewBasis(view)
        let tanHalf: Double = tan(view.fovY / 2)
        let x: Double = (2 * point.x / size.x - 1) * tanHalf * view.aspect
        let y: Double = (1 - 2 * point.y / size.y) * tanHalf
        let ray: SIMD3<Double> = basis.forward + basis.right * x + basis.up * y
        guard ray.z.isFinite, ray.z < 0 else { return nil }
        let t: Double = (G.planeZ - view.eye.z) / ray.z
        guard t.isFinite, t > 0 else { return nil }
        let hit: SIMD3<Double> = view.eye + ray * t
        let lattice: Double = G.scale * Double(ApsidesWorkshopSky.unit)
        let sky: SIMD2<Double> = SIMD2(hit.x / lattice, hit.y / lattice)
        guard sky.x.isFinite, sky.y.isFinite else { return nil }
        return sky
    }

    /// The orbit a knob drag reads at `point` (view points) in a view of `size` points showing `snapshot` from the
    /// camera of `orbit` (clamped): the current size a kept; the direction step d = round(angle / 15°) mod 24 of the
    /// sky point's angle around the star (anticlockwise from +x; a point within ``starTolerance`` of the star keeps
    /// the current direction) and the eccentricity step k = round(20 − 20 r / a) clamped to 0 … 15, r the sky point's
    /// distance from the star in lattice units (the periapsis lies at a(20 − k) / 20). Nil when the point casts onto no
    /// sky point (``skyPoint(_:size:orbit:)``). The orbit is not checked: whether it is valid
    /// (`ApsidesWorkshopOrbit.isValid`) is the caller's to check.
    public static func knobSteps(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                                 orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopOrbit? {
        guard let sky = skyPoint(point, size: size, orbit: orbit) else { return nil }
        let current: ApsidesWorkshopOrbit = snapshot.orbit
        let r: Double = (sky.x * sky.x + sky.y * sky.y).squareRoot()
        var direction: Int = current.direction
        if r > starTolerance {
            let degrees: Double = atan2(sky.y, sky.x) * 180 / Double.pi
            let step: Int = Int((degrees / 15).rounded(.toNearestOrAwayFromZero))
            direction = ((step % 24) + 24) % 24
        }
        let a: Double = Double(max(current.size, 1))
        let raw: Double = (20 - 20 * r / a).rounded(.toNearestOrAwayFromZero)
        let range: ClosedRange<Int> = ApsidesWorkshopOrbit.eccentricities
        let k: Int = Int(min(max(raw, Double(range.lowerBound)), Double(range.upperBound)))
        return ApsidesWorkshopOrbit(size: current.size, eccentricity: k, direction: direction)
    }

    /// The orbit a size-handle drag reads at `point` (view points) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped): the current eccentricity k and direction kept; the size a = round(20 R / (20 +
    /// k)) clamped to 8 … 48, R the sky point's distance from the star in lattice units (the apoapsis lies at
    /// a(20 + k) / 20). Nil when the point casts onto no sky point. The orbit is not checked: whether it is valid is
    /// the caller's to check.
    public static func handleSize(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                                  orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopOrbit? {
        guard let sky = skyPoint(point, size: size, orbit: orbit) else { return nil }
        let current: ApsidesWorkshopOrbit = snapshot.orbit
        let distance: Double = (sky.x * sky.x + sky.y * sky.y).squareRoot()
        let raw: Double = (20 * distance / Double(20 + current.eccentricity)).rounded(.toNearestOrAwayFromZero)
        let range: ClosedRange<Int> = ApsidesWorkshopOrbit.sizes
        let a: Int = Int(min(max(raw, Double(range.lowerBound)), Double(range.upperBound)))
        return ApsidesWorkshopOrbit(size: a, eccentricity: current.eccentricity, direction: current.direction)
    }

    /// The tick the time crank reads at `point` (view points) in a view of `size` points showing `snapshot` from the
    /// camera of `orbit` (clamped): the tick 0 … period − 1 whose projected kernel position w(P(tick)) is nearest to
    /// the point, the lower tick on ties. The snapshot's shown tick for unusable input (a non-finite point, an unusable
    /// size, no positions, every position behind the eye).
    public static func crankTick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                                 orbit: ApsidesWorkshopViewOrbit) -> Int {
        typealias G = ApsidesWorkshopSceneGeometry
        let fallback: Int = snapshot.shownTick
        guard point.x.isFinite, point.y.isFinite, !snapshot.positions.isEmpty,
              let view = camera(size: size, orbit: orbit) else { return fallback }
        var best: Int = fallback
        var bestDistance: Double = Double.infinity
        for (tick, p) in snapshot.positions.enumerated() {
            guard let q = viewPoint(G.world(p, depth: G.planeZ), size: size, camera: view) else { continue }
            let e: SIMD2<Double> = point - q
            let d2: Double = e.x * e.x + e.y * e.y
            if d2 < bestDistance {
                best = tick
                bestDistance = d2
            }
        }
        return best
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
