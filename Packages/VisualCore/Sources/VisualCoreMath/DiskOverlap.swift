// DiskOverlap — feature 215 (R02-F15) T-R02F15-005 (FR-R02F15-005; SC-R02F15-004; research R7). The exact overlap
// of two uniform planar disks of radii r₁, r₂ whose centres are d apart. Disjoint or touching disks (d ≥ r₁ + r₂)
// overlap in 0; a disk inside the other (d ≤ |r₁ − r₂|) overlaps in the smaller disk's whole area π·min(r₁, r₂)²;
// otherwise the overlap is the lens
//   A = r₁²·acos(c₁) + r₂²·acos(c₂) − ½·√((−d + r₁ + r₂)(d + r₁ − r₂)(d − r₁ + r₂)(d + r₁ + r₂)),
// with c₁ = (d² + r₁² − r₂²)/(2·d·r₁), c₂ = (d² + r₂² − r₁²)/(2·d·r₂) clamped to [−1, 1] and the product under the root
// clamped to ≥ 0; the result is clamped to [0, π·min(r₁, r₂)²]. The covered fraction divides by the source disk's area
// and is clamped to [0, 1]. Pure and deterministic; units are the caller's (lengths, or radians on the sky).
import Foundation

/// The exact overlap of two uniform planar disks, as an area and as a fraction of one of them.
public enum DiskOverlap {
    /// The area shared by a disk of radius `radiusA` and a disk of radius `radiusB` whose centres are `distance` apart.
    ///
    /// - Returns: 0 for disjoint or touching disks, π·min(r)² when one disk lies inside the other, the analytic lens
    ///   area otherwise; always within [0, π·min(r)²].
    /// - Throws: ``OrbitError/invalidDisk`` when a radius is not finite and positive or the distance is negative or
    ///   not finite.
    public static func area(radiusA: Double, radiusB: Double, distance: Double) throws(OrbitError) -> Double {
        guard radiusA.isFinite, radiusA > 0, radiusB.isFinite, radiusB > 0, distance.isFinite, distance >= 0 else {
            throw .invalidDisk
        }
        let r1 = radiusA, r2 = radiusB, d = distance
        let smaller = min(r1, r2)
        let full = Double.pi * smaller * smaller
        if d >= r1 + r2 { return 0 }
        if d <= abs(r1 - r2) { return full }
        let c1 = min(1, max(-1, (d * d + r1 * r1 - r2 * r2) / (2 * d * r1)))
        let c2 = min(1, max(-1, (d * d + r2 * r2 - r1 * r1) / (2 * d * r2)))
        let product = (-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2)
        let lens = r1 * r1 * acos(c1) + r2 * r2 * acos(c2) - 0.5 * max(0, product).squareRoot()
        return min(full, max(0, lens))
    }

    /// The fraction of a source disk of radius `sourceRadius` covered by an occluding disk of radius
    /// `occluderRadius` whose centre lies `distance` from the source's centre: ``area(radiusA:radiusB:distance:)``
    /// divided by π·`sourceRadius`², clamped to [0, 1].
    ///
    /// - Throws: ``OrbitError/invalidDisk`` under the same conditions as ``area(radiusA:radiusB:distance:)``.
    public static func coveredFraction(sourceRadius: Double, occluderRadius: Double,
                                       distance: Double) throws(OrbitError) -> Double {
        let shared = try area(radiusA: sourceRadius, radiusB: occluderRadius, distance: distance)
        return min(1, max(0, shared / (Double.pi * sourceRadius * sourceRadius)))
    }
}
