// GroundPick — feature 090 (A12-P02) T-A12-204 (FR-A12-221; clarification 2; research D5). The ground point a tap ray
// meets over a height field. The ray is first intersected with the world box (x and z over the field's extent, −6…6 m
// for every preset; y over `WorldPreset.heightRange`, −1…1.6 m) by `Ray3.intersect(boxMin:boxMax:)`, which gives the
// entry distance (0 when the ray starts inside); the exit distance comes from the same slab test here. From the entry
// the ray is marched in steps of half a cell until its point lies at or below the terrain height there (the last step
// is shortened to end exactly at the exit), and the crossing is then bisected 40 times (a half-cell interval of at
// most 0.125 m shrinks below 1e-12 m). The result is the crossing point with y set to the terrain height there, or nil
// when the ray misses the box or leaves it without meeting the terrain (a sky ray). A ray that enters the box already
// below the terrain hits at the entry. Pure: the same ray and field give the same answer.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Resolves a ray to a point on the terrain.
public enum GroundPick {
    /// The number of bisection steps after the march brackets a crossing.
    public static let bisections = 40

    /// The world box of `field`: its x and z extent, y over `WorldPreset.heightRange`.
    public static func box(of field: HeightField) -> (min: Vec3, max: Vec3) {
        let lowY = WorldPreset.heightRange.lowerBound, highY = WorldPreset.heightRange.upperBound
        return (Vec3(field.originX, lowY, field.originZ),
                Vec3(field.originX + Double(field.columns) * field.cellSize, highY,
                     field.originZ + Double(field.rows) * field.cellSize))
    }

    /// The terrain point `ray` meets over `field` (y is the terrain height there), or nil for a miss.
    public static func hit(ray: Ray3, field: HeightField) -> Vec3? {
        let (lo, hi) = box(of: field)
        guard let entry = ray.intersect(boxMin: lo, boxMax: hi), let exit = exitDistance(ray, lo, hi),
              exit >= entry.distance else { return nil }
        let start = max(entry.distance, 0)
        func above(_ t: Double) -> Bool {
            let p = point(ray, t)
            return p.y > field.height(atX: p.x, z: p.z)
        }
        if !above(start) { return surface(ray, start, field) }
        let step = field.cellSize / 2
        let steps = Int(((exit - start) / step).rounded(.up))
        var previous = start
        for k in 1...max(steps, 1) {
            let t = min(start + Double(k) * step, exit)
            if !above(t) {
                var a = previous, b = t
                for _ in 0..<bisections {
                    let m = (a + b) / 2
                    if above(m) { a = m } else { b = m }
                }
                return surface(ray, b, field)
            }
            previous = t
            if t >= exit { break }
        }
        return nil
    }

    /// The ray's point at distance `t`.
    private static func point(_ ray: Ray3, _ t: Double) -> Vec3 { ray.origin + ray.direction * t }

    /// The ray's point at `t` with y set to the terrain height there.
    private static func surface(_ ray: Ray3, _ t: Double, _ field: HeightField) -> Vec3 {
        let p = point(ray, t)
        return Vec3(p.x, field.height(atX: p.x, z: p.z), p.z)
    }

    /// The distance at which `ray` leaves the box (slab test), or nil when it never is inside it at t ≥ 0.
    private static func exitDistance(_ ray: Ray3, _ lo: Vec3, _ hi: Vec3) -> Double? {
        var tFar = Double.infinity, tNear = -Double.infinity
        let o = [ray.origin.x, ray.origin.y, ray.origin.z], d = [ray.direction.x, ray.direction.y, ray.direction.z]
        let mins = [lo.x, lo.y, lo.z], maxs = [hi.x, hi.y, hi.z]
        for axis in 0..<3 {
            if abs(d[axis]) < 1e-12 {
                if o[axis] < mins[axis] || o[axis] > maxs[axis] { return nil }
                continue
            }
            let t1 = (mins[axis] - o[axis]) / d[axis], t2 = (maxs[axis] - o[axis]) / d[axis]
            tNear = max(tNear, min(t1, t2))
            tFar = min(tFar, max(t1, t2))
        }
        guard tFar >= max(tNear, 0) else { return nil }
        return tFar
    }
}
