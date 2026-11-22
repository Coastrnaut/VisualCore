// AmethystEscapePicker — feature 364 (R02-G07-04) T-R02G0704-003 (FR-R02G0704-001, 002, 004; SC-R02G0704-001;
// clarifications Q1 "How does a drag become a turn?" and Q2 "What is the pearl's touch target and how are taps used?").
// Analytic, deterministic picking of a touch in the drawn Amethyst Escape crystal. The touch point (view points, origin
// top left, y down; the size is the view's size in points) becomes the ray of the drawn camera
// (`AmethystEscapeSceneGeometry.camera(_:aspect:orbit:)` with the view's aspect) through it, unprojected by the shared
// `ScreenProjection` (R02-F22). The pearl wins first: the ray meets the pearl sphere (radius 0.3·w about
// `pearlCentre`), or the touch lies within 22 points (the minimum target) of the pearl centre's projection. Otherwise
// the ray is intersected with each shell's top plane y = h_k from the innermost (tallest) shell outward and the first
// hit whose distance from the axis lies in r_k … r_k + w picks that shell. Otherwise the shell whose projected top-ring
// midline (the circle of radius r_k + w/2 at y = h_k, drawn as a closed polyline of `midlineSegments` chords) passes
// nearest the touch within 22 points is picked; otherwise the touch is on empty space. `angle(shell:at:…)` gives the
// angle atan2(z, x) of the ray's hit on a shell's plane, the quantity a shell drag sweeps (+x towards +z positive, the
// kernel's +1). Presentation only: picking reads the drawn snapshot and orbit and never the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a touch picked in the Amethyst Escape crystal.
public enum AmethystEscapePick: Sendable, Equatable {
    /// The pearl (its sphere, or its projected centre within ``AmethystEscapePicker/minimumTarget``).
    case pearl
    /// Shell `index` (0 innermost): its top annulus under the touch, or its projected top-ring midline within
    /// ``AmethystEscapePicker/minimumTarget``.
    case shell(Int)
    /// Nothing: no pearl, no shell top under the touch and no shell midline within
    /// ``AmethystEscapePicker/minimumTarget`` points.
    case empty
}

/// The analytic picker of the Amethyst Escape crystal: the touch ray against the pearl sphere and the shells' top
/// planes, with a 22-point minimum touch target for the pearl and the shells' top-ring midlines.
public enum AmethystEscapePicker {
    /// The minimum touch target in view points: a touch at most this far from the pearl centre's projection picks the
    /// pearl; when no shell top lies under the touch, a shell whose projected top-ring midline passes at most this far
    /// from it is picked.
    public static let minimumTarget: Double = 22
    /// The chords of the closed polyline that stands for a shell's projected top-ring midline, 128.
    public static let midlineSegments: Int = 128

    /// The world ray of `camera` through `point` (view points, origin top left, y down) of a view of `size` points:
    /// the origin on the near plane and a unit direction away from the eye. Nil for a non-finite point, a size that is
    /// not finite and positive, a point outside the view, or a degenerate camera.
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>,
                           camera: AmethystEscapeCamera) -> (origin: SIMD3<Double>, direction: SIMD3<Double>)? {
        guard point.x.isFinite, point.y.isFinite, size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0,
              let inverse = camera.viewProjection.inverse,
              let r = ScreenProjection.ray(through: Vec2(point.x, point.y), viewport: Vec2(size.x, size.y),
                                           inverseViewProjection: inverse) else { return nil }
        let direction: SIMD3<Double> = AmethystEscapeSceneGeometry.unit(SIMD3(r.direction.x, r.direction.y,
                                                                              r.direction.z))
        let origin: SIMD3<Double> = SIMD3(r.origin.x, r.origin.y, r.origin.z)
        guard direction != .zero, origin.x.isFinite, origin.y.isFinite, origin.z.isFinite else { return nil }
        return (origin, direction)
    }

    /// The pick of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// the camera of `orbit` (clamped) with aspect width / height: ``AmethystEscapePick/pearl`` when the ray meets the
    /// pearl sphere or the point lies within ``minimumTarget`` points of the pearl centre's projection; else
    /// ``AmethystEscapePick/shell(_:)`` for the first shell, innermost outward, whose top plane y = h_k the ray meets
    /// ahead at a distance r_k … r_k + w from the axis; else the shell whose projected top-ring midline passes nearest
    /// within ``minimumTarget`` points (exact ties to the inner shell); else ``AmethystEscapePick/empty``.
    /// ``AmethystEscapePick/empty`` too for non-finite input, an unusable size, a snapshot without shells or sectors,
    /// or a point outside the view. Deterministic.
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: AmethystEscapeSceneSnapshot,
                            orbit: AmethystEscapeOrbit) -> AmethystEscapePick {
        guard let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera) else { return .empty }
        let w: Double = AmethystEscapeSceneGeometry.shellWidth(snapshot)
        let pearl: SIMD3<Double> = AmethystEscapeSceneGeometry.pearlCentre(snapshot)
        if sphere(origin: r.origin, direction: r.direction, centre: pearl,
                  radius: AmethystEscapeSceneGeometry.pearlRadius * w) != nil {
            return .pearl
        }
        if let d = distance(point, pearl, size: size, camera: camera), d <= minimumTarget { return .pearl }
        for shell in snapshot.shells.indices {
            guard let hit = planeHit(origin: r.origin, direction: r.direction,
                                     height: AmethystEscapeSceneGeometry.shellHeight(shell, snapshot)) else {
                continue
            }
            let inner: Double = AmethystEscapeSceneGeometry.shellRadius(shell, snapshot)
            let radial: Double = (hit.x * hit.x + hit.z * hit.z).squareRoot()
            if radial >= inner && radial <= inner + w { return .shell(shell) }
        }
        var best: Double = .infinity
        var result: AmethystEscapePick = .empty
        for shell in snapshot.shells.indices {
            guard let d = midlineDistance(point, shell: shell, size: size, snapshot: snapshot, camera: camera),
                  d <= minimumTarget, d < best else { continue }
            best = d
            result = .shell(shell)
        }
        return result
    }

    /// The angle in radians, atan2(z, x) in −π … π (from +x towards +z positive, the kernel's +1), of the point where
    /// the ray of `point` (view points, origin top left, y down) in a view of `size` points showing `snapshot` from
    /// `orbit` meets the top plane y = h_k of shell `shell` ahead of the eye. Nil for an unknown shell, unusable input,
    /// a point outside the view, or a ray that does not meet the plane ahead.
    public static func angle(shell: Int, at point: SIMD2<Double>, size: SIMD2<Double>,
                             snapshot: AmethystEscapeSceneSnapshot, orbit: AmethystEscapeOrbit) -> Double? {
        guard snapshot.shells.indices.contains(shell),
              let camera = camera(size: size, snapshot: snapshot, orbit: orbit),
              let r = ray(point, size: size, camera: camera),
              let hit = planeHit(origin: r.origin, direction: r.direction,
                                 height: AmethystEscapeSceneGeometry.shellHeight(shell, snapshot)) else { return nil }
        let a: Double = atan2(hit.z, hit.x)
        return a.isFinite ? a : nil
    }

    // MARK: Internals

    /// The drawn camera for a view of `size` points, or nil for an unusable size or a snapshot without shells or
    /// sectors.
    static func camera(size: SIMD2<Double>, snapshot: AmethystEscapeSceneSnapshot,
                       orbit: AmethystEscapeOrbit) -> AmethystEscapeCamera? {
        guard size.x.isFinite, size.y.isFinite, size.x > 0, size.y > 0, !snapshot.shells.isEmpty,
              snapshot.sectors > 0 else { return nil }
        return AmethystEscapeSceneGeometry.camera(snapshot, aspect: size.x / size.y, orbit: orbit)
    }

    /// The smallest positive root t of |origin + t·direction − centre| = radius for a unit `direction`, from the
    /// quadratic t² + 2bt + c = 0 with b = (origin − centre)·direction and c = |origin − centre|² − radius²; nil when
    /// the ray misses the sphere or the sphere lies behind it.
    static func sphere(origin: SIMD3<Double>, direction: SIMD3<Double>, centre: SIMD3<Double>,
                       radius: Double) -> Double? {
        let oc: SIMD3<Double> = origin - centre
        let b: Double = AmethystEscapeSceneGeometry.dot(oc, direction)
        let c: Double = AmethystEscapeSceneGeometry.dot(oc, oc) - radius * radius
        let discriminant: Double = b * b - c
        guard discriminant >= 0, discriminant.isFinite else { return nil }
        let root: Double = discriminant.squareRoot()
        let near: Double = -b - root
        if near > 0 { return near }
        let far: Double = -b + root
        return far > 0 ? far : nil
    }

    /// The point where the ray from `origin` along `direction` meets the horizontal plane y = `height` ahead of it, or
    /// nil.
    static func planeHit(origin: SIMD3<Double>, direction: SIMD3<Double>, height: Double) -> SIMD3<Double>? {
        guard abs(direction.y) > 1e-15 else { return nil }
        let t: Double = (height - origin.y) / direction.y
        guard t > 0, t.isFinite else { return nil }
        let hit: SIMD3<Double> = origin + direction * t
        return SIMD3(hit.x, height, hit.z)
    }

    /// The distance in view points from `point` to the projection of `world`; nil behind the camera.
    static func distance(_ point: SIMD2<Double>, _ world: SIMD3<Double>, size: SIMD2<Double>,
                         camera: AmethystEscapeCamera) -> Double? {
        guard let v = AmethystEscapeSceneGeometry.project(world, camera: camera) else { return nil }
        let dx: Double = v.x * size.x - point.x
        let dy: Double = v.y * size.y - point.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// The distance in view points from `point` to shell `shell`'s projected top-ring midline: the circle of radius
    /// r_k + w/2 at y = h_k, sampled at ``midlineSegments`` equal angles from +x and projected, as a closed polyline
    /// (the nearest point on any chord). The samples are projected as `ScreenProjection.project` does (clip = M·(p, 1)
    /// with M the view-projection, NDC = clip / w, view points ((x + 1)/2 · width, (1 − y)/2 · height)), with the
    /// matrix rows read once. Nil when a sample lies behind the camera or projects to a non-finite point.
    static func midlineDistance(_ point: SIMD2<Double>, shell: Int, size: SIMD2<Double>,
                                snapshot: AmethystEscapeSceneSnapshot, camera: AmethystEscapeCamera) -> Double? {
        let radius: Double = AmethystEscapeSceneGeometry.shellRadius(shell, snapshot)
            + AmethystEscapeSceneGeometry.shellWidth(snapshot) / 2
        let height: Double = AmethystEscapeSceneGeometry.shellHeight(shell, snapshot)
        let m: Mat4 = camera.viewProjection
        let r0: Vec4 = m.row(0), r1: Vec4 = m.row(1), r3: Vec4 = m.row(3)
        var ring: [SIMD2<Double>] = []
        ring.reserveCapacity(midlineSegments)
        for k in 0..<midlineSegments {
            let a: Double = 2 * Double.pi * Double(k) / Double(midlineSegments)
            let x: Double = radius * cos(a), z: Double = radius * sin(a)
            let w: Double = r3.x * x + r3.y * height + r3.z * z + r3.w
            guard w > 0, w.isFinite else { return nil }
            let nx: Double = (r0.x * x + r0.y * height + r0.z * z + r0.w) / w
            let ny: Double = (r1.x * x + r1.y * height + r1.z * z + r1.w) / w
            guard nx.isFinite, ny.isFinite else { return nil }
            ring.append(SIMD2((nx + 1) / 2 * size.x, (1 - ny) / 2 * size.y))
        }
        var best: Double = .infinity
        for k in ring.indices {
            let a: SIMD2<Double> = ring[k]
            let b: SIMD2<Double> = ring[(k + 1) % ring.count]
            let ab: SIMD2<Double> = b - a
            let lengthSquared: Double = (ab * ab).sum()
            let t: Double = lengthSquared > 0 ? min(max(((point - a) * ab).sum() / lengthSquared, 0), 1) : 0
            let d: SIMD2<Double> = a + ab * t - point
            best = min(best, (d * d).sum().squareRoot())
        }
        return best
    }
}
