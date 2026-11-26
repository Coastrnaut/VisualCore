// MicroscopicAuroraPicker — feature 484 (R02-G19-04) T-R02G1904-002 (FR-R02G1904-001 … 003, 006; SC-R02G1904-001,
// 004). Analytic, deterministic picking of a touch in the drawn Microscopic Aurora dish. Everything is projected
// through the drawn camera (`MicroscopicAuroraSceneGeometry.camera(aspect:orbit:)` with the view's aspect width /
// height) into view points (origin top left, x right, y down; the size is the view's size in points). A world extent e
// at a centre c becomes e / (depth · tan(fovY / 2)) · height / 2 view points, depth c's distance from the eye along the
// view axis. Of several hits the target drawn last wins:
//   1. a well (the committed wells, later slots first): within its projected spiral radius (0.45 cell) grown by
//      ``MicroscopicAuroraPicker/markerAllowance`` (12) points of its projected centre;
//   2. a site (higher index first): within its projected ring radius (0.35 cell) grown by 12 points;
//   3. the scrubber: within ``MicroscopicAuroraPicker/scrubberBand`` (14) points of its projected track
//      (x −0.9 … 0.9 at y −1.31);
//   4. the field: the finger cast onto the dish plane z = 0 lies inside the enclosure (distance from the dish centre
//      at most R · 256 dish units);
//   5. anything else is empty space, as is unusable input (a non-finite point, a size that is not finite and
//      positive).
// A drag casts the finger onto the dish plane (``MicroscopicAuroraPicker/dishPoint(_:size:orbit:)``, dish units: x
// right, y down the dish, the enclosure centred at (3072, 3072)). A dragged well's drop target is the site whose
// projected centre is nearest the finger within ``MicroscopicAuroraPicker/siteReach`` (24) points (the lower index on
// ties) — no change (nil) when it is the well's own site or another well's — else removal when the finger lies outside
// the enclosure, else no change. The scrubber's tick is round(fraction × ticks swum), the fraction the finger's point
// on the dish plane along the track (x from −0.9 to 0.9), clamped to 0 … 1. Presentation only: the picker reads the
// drawn snapshot and the view orbit and never changes the kernel. Modelled on feature 474's `ApsidesWorkshopPicker`.
import Foundation

/// What a touch picked in the Microscopic Aurora dish (feature 484).
public enum MicroscopicAuroraPick: Sendable, Equatable {
    /// The well of this slot: its projected spiral radius grown by ``MicroscopicAuroraPicker/markerAllowance``.
    case well(Int)
    /// The site of this index: its projected ring radius grown by ``MicroscopicAuroraPicker/markerAllowance``.
    case site(Int)
    /// The swim scrubber: within ``MicroscopicAuroraPicker/scrubberBand`` points of its projected track.
    case scrubber
    /// The dish field: inside the projected enclosure, away from wells and sites.
    case field
    /// Nothing: unusable input, or outside every target.
    case empty
}

/// The analytic picker of the Microscopic Aurora dish (see the file header).
public enum MicroscopicAuroraPicker {
    /// How many view points a well's or site's target reaches beyond its projected radius, 12.
    public static let markerAllowance: Double = 12
    /// How many view points the scrubber's target reaches either side of its projected track, 14.
    public static let scrubberBand: Double = 14
    /// How many view points from a site's projected centre a dragged well snaps to it, 24.
    public static let siteReach: Double = 24

    /// World `point` in view points (origin top left, x right, y down) of a view of `size` points seen through
    /// `camera`: ``MicroscopicAuroraSceneGeometry/project(_:camera:)`` scaled by the size. Nil when the point is not
    /// finite or behind the eye, or the size is not finite and positive.
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>,
                                 camera: MicroscopicAuroraCamera) -> SIMD2<Double>? {
        guard usable(size), let v = MicroscopicAuroraSceneGeometry.project(point, camera: camera) else { return nil }
        let p: SIMD2<Double> = SIMD2(v.x * size.x, v.y * size.y)
        guard p.x.isFinite, p.y.isFinite else { return nil }
        return p
    }

    /// The drawn camera of a view of `size` points from `orbit` (clamped): aspect width / height. Nil for a size that
    /// is not finite and positive.
    public static func camera(size: SIMD2<Double>, orbit: MicroscopicAuroraViewOrbit) -> MicroscopicAuroraCamera? {
        guard usable(size) else { return nil }
        return MicroscopicAuroraSceneGeometry.camera(aspect: size.x / size.y, orbit: orbit)
    }

    /// The length in view points of a world extent `extent` at `centre` seen through `camera` in a view of `size`
    /// points: extent / (depth · tan(fovY / 2)) · height / 2, depth the centre's distance along the view axis. Nil when
    /// the centre is not in front of the eye or the size is unusable.
    public static func projectedExtent(_ extent: Double, at centre: SIMD3<Double>, size: SIMD2<Double>,
                                       camera: MicroscopicAuroraCamera) -> Double? {
        typealias G = MicroscopicAuroraSceneGeometry
        guard usable(size) else { return nil }
        let forward: SIMD3<Double> = G.viewBasis(camera).forward
        let depth: Double = G.dot(centre - camera.eye, forward)
        let tanHalf: Double = tan(camera.fovY / 2)
        guard depth.isFinite, depth > 0, tanHalf.isFinite, tanHalf > 0 else { return nil }
        let r: Double = extent / (depth * tanHalf) * size.y / 2
        return r.isFinite ? r : nil
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``MicroscopicAuroraPick/well(_:)`` within a
    /// committed well's projected spiral radius grown by ``markerAllowance`` (later slots first); else
    /// ``MicroscopicAuroraPick/site(_:)`` within a site's projected ring radius grown by ``markerAllowance`` (higher
    /// index first); else ``MicroscopicAuroraPick/scrubber`` within ``scrubberBand`` of the projected track; else
    /// ``MicroscopicAuroraPick/field`` when the finger casts inside the enclosure; else
    /// ``MicroscopicAuroraPick/empty`` (also for a non-finite point or a size that is not finite and positive).
    /// Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MicroscopicAuroraSceneSnapshot,
                            orbit: MicroscopicAuroraViewOrbit) -> MicroscopicAuroraPick {
        typealias G = MicroscopicAuroraSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(size: size, orbit: orbit) else { return .empty }
        let wellRadius: Double = G.wellRadiusShare * G.cellSide
        var slot: Int = snapshot.wells.count - 1
        while slot >= 0 {
            if let centre = G.wellCentre(slot, snapshot),
               hits(point, centre: centre, extent: wellRadius, allowance: markerAllowance, size: size, camera: view) {
                return .well(slot)
            }
            slot -= 1
        }
        let siteRadius: Double = G.siteRadiusShare * G.cellSide
        var index: Int = snapshot.sites.count - 1
        while index >= 0 {
            let centre: SIMD3<Double> = G.cellCentre(snapshot.sites[index])
            if hits(point, centre: centre, extent: siteRadius, allowance: markerAllowance, size: size, camera: view) {
                return .site(index)
            }
            index -= 1
        }
        if let gap = scrubberDistance(point, size: size, camera: view), gap <= scrubberBand { return .scrubber }
        if insideEnclosure(point, size: size, snapshot: snapshot, orbit: orbit) { return .field }
        return .empty
    }

    /// The distance in view points from `point` to the projected scrubber track (the scrubber points of fractions 0
    /// and 1) seen through `camera`; nil when an end does not project or the size is unusable.
    public static func scrubberDistance(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                        camera: MicroscopicAuroraCamera) -> Double? {
        typealias G = MicroscopicAuroraSceneGeometry
        guard let a = viewPoint(G.scrubberPoint(0), size: size, camera: camera),
              let b = viewPoint(G.scrubberPoint(1), size: size, camera: camera) else { return nil }
        return segmentDistance(point, a, b)
    }

    /// The point of the dish plane z = 0 under view point `point` (origin top left, y down) of a view of `size` points
    /// seen from the camera of `orbit` (clamped), in dish units (x right, y down the dish; world (x, y) maps to
    /// (3072 + x / s, 3072 − y / s)): the ray from the eye through the point cast onto the plane. Nil for a non-finite
    /// point, an unusable size, or a ray that does not meet the plane in front of the eye.
    public static func dishPoint(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                 orbit: MicroscopicAuroraViewOrbit) -> SIMD2<Double>? {
        guard let hit = planePoint(point, size: size, orbit: orbit) else { return nil }
        typealias G = MicroscopicAuroraSceneGeometry
        let c: Double = Double(MicroscopicAuroraDish.centre)
        let dish: SIMD2<Double> = SIMD2(c + hit.x / G.scale, c - hit.y / G.scale)
        guard dish.x.isFinite, dish.y.isFinite else { return nil }
        return dish
    }

    /// Where a well of slot `slot` dragged to `point` (view points) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) would go: ``MicroscopicAuroraPreviewTarget/site(_:)`` of the site whose
    /// projected centre is nearest the point within ``siteReach`` (the lower index on ties) — nil (no change) when that
    /// site is the dragged well's own or another slot's well's; else ``MicroscopicAuroraPreviewTarget/removal`` when
    /// the point lies outside the projected enclosure (or casts onto no dish point); else nil. Nil for unusable input
    /// (a non-finite point, an unusable size). Whether the slot holds a well is the caller's to check.
    public static func dropTarget(_ point: SIMD2<Double>, slot: Int, size: SIMD2<Double>,
                                  snapshot: MicroscopicAuroraSceneSnapshot,
                                  orbit: MicroscopicAuroraViewOrbit) -> MicroscopicAuroraPreviewTarget? {
        typealias G = MicroscopicAuroraSceneGeometry
        guard point.x.isFinite, point.y.isFinite, let view = camera(size: size, orbit: orbit) else { return nil }
        var best: Int? = nil
        var bestDistance: Double = Double.infinity
        for (index, site) in snapshot.sites.enumerated() {
            guard let centre = viewPoint(G.cellCentre(site), size: size, camera: view) else { continue }
            let d: Double = distance(point, centre)
            if d <= siteReach && d < bestDistance {
                best = index
                bestDistance = d
            }
        }
        if let index = best {
            let cell: MicroscopicAuroraCell = snapshot.sites[index]
            // The dragged well's own site (slot `slot`) and every other well's site mean no change.
            for well in snapshot.wells {
                if let well, well.cell == cell { return nil }
            }
            return .site(cell)
        }
        if !insideEnclosure(point, size: size, snapshot: snapshot, orbit: orbit) { return .removal }
        return nil
    }

    /// The tick the scrubber reads at `point` (view points) in a view of `size` points showing `snapshot` from the
    /// camera of `orbit` (clamped): round(fraction × ticks swum) (halves away from zero), the fraction the point's
    /// cast on the dish plane along the track, (x + 0.9) / 1.8 clamped to 0 … 1; always within 0 … ticks swum. The
    /// snapshot's shown tick for unusable input (a non-finite point, an unusable size, a ray missing the plane).
    public static func scrubTick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MicroscopicAuroraSceneSnapshot,
                                 orbit: MicroscopicAuroraViewOrbit) -> Int {
        typealias G = MicroscopicAuroraSceneGeometry
        let ticks: Int = max(snapshot.ticksSwum, 0)
        guard let hit = planePoint(point, size: size, orbit: orbit) else {
            return min(max(snapshot.shownTick, 0), ticks)
        }
        let raw: Double = (hit.x - G.scrubberStart) / (G.scrubberEnd - G.scrubberStart)
        let fraction: Double = raw.isFinite ? min(max(raw, 0), 1) : 0
        let tick: Int = Int((fraction * Double(ticks)).rounded(.toNearestOrAwayFromZero))
        return min(max(tick, 0), ticks)
    }

    // MARK: Internals

    /// Whether `point` lies within the projected `extent` of `centre` grown by `allowance` points.
    static func hits(_ point: SIMD2<Double>, centre: SIMD3<Double>, extent: Double, allowance: Double,
                     size: SIMD2<Double>, camera: MicroscopicAuroraCamera) -> Bool {
        guard let c = viewPoint(centre, size: size, camera: camera),
              let reach = projectedExtent(extent, at: centre, size: size, camera: camera) else { return false }
        return distance(point, c) <= reach + allowance
    }

    /// The world point of the plane z = 0 under view point `point` (see ``dishPoint(_:size:orbit:)``).
    static func planePoint(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           orbit: MicroscopicAuroraViewOrbit) -> SIMD3<Double>? {
        typealias G = MicroscopicAuroraSceneGeometry
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
        guard hit.x.isFinite, hit.y.isFinite else { return nil }
        return hit
    }

    /// Whether `point` casts onto the dish plane inside the enclosure of `snapshot` (distance from the dish centre at
    /// most R · 256 dish units); false when it casts onto no dish point.
    static func insideEnclosure(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                snapshot: MicroscopicAuroraSceneSnapshot,
                                orbit: MicroscopicAuroraViewOrbit) -> Bool {
        guard let dish = dishPoint(point, size: size, orbit: orbit) else { return false }
        let c: Double = Double(MicroscopicAuroraDish.centre)
        let r: Double = Double(snapshot.radius * MicroscopicAuroraDish.unit)
        let dx: Double = dish.x - c
        let dy: Double = dish.y - c
        return dx * dx + dy * dy <= r * r
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
