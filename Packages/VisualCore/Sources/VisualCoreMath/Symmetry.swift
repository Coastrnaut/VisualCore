// Symmetry.swift — feature 040 (A05-P01) T-A05-102 (FR-A05-101 to FR-A05-103; G-SYMMETRY).
// Point groups (cyclic and dihedral, order 1…24) and two wallpaper lattices (square p4m, hexagonal p6m): the images of
// a point and the fold of a point into the fundamental region (research D2). Pure Double math, deterministic.
import Foundation

/// A rosette point group about the origin: `cyclic(n)` (n rotations) or `dihedral(n)` (n rotations and n mirrors).
///
/// The order is meaningful in `orderRange` (1…24); an order outside it is clamped into the range by every member
/// (`order`, `imageCount`, `images(of:)`, `fold(_:)`). Mirrors are taken across the x axis and its rotations.
public enum PointGroup: Sendable, Equatable, Hashable, Codable {
    /// n-fold rotations by 2πk/n, k = 0…n−1.
    case cyclic(Int)
    /// n-fold rotations plus the mirror across the x axis composed with each rotation (2n elements).
    case dihedral(Int)

    /// The supported orders, 1…24.
    public static let orderRange: ClosedRange<Int> = 1...24

    /// The order n, clamped into `orderRange`.
    public var order: Int {
        let n: Int
        switch self {
        case .cyclic(let k), .dihedral(let k): n = k
        }
        return min(max(n, Self.orderRange.lowerBound), Self.orderRange.upperBound)
    }

    /// True when the stored order lies in `orderRange` (no clamping is applied).
    public var isOrderInRange: Bool {
        switch self {
        case .cyclic(let k), .dihedral(let k): return Self.orderRange.contains(k)
        }
    }

    /// The number of images of a generic point: n for cyclic, 2n for dihedral (so `dihedral(1)` has 2: the point
    /// and its mirror).
    public var imageCount: Int {
        switch self {
        case .cyclic: return order
        case .dihedral: return 2 * order
        }
    }

    /// The images of `p`: the identity first, then the rotations by 2πk/n for k = 1…n−1; for a dihedral group these
    /// are followed by the mirrored point (x, −y) rotated by 2πk/n for k = 0…n−1. The count is `imageCount`.
    public func images(of p: Vec2) -> [Vec2] {
        let n = order
        var out: [Vec2] = []
        out.reserveCapacity(imageCount)
        out.append(p)
        for k in 1..<max(n, 1) { out.append(Self.rotate(p, by: 2 * Double.pi * Double(k) / Double(n))) }
        if case .dihedral = self {
            let m = Vec2(p.x, -p.y)
            out.append(m)
            for k in 1..<max(n, 1) { out.append(Self.rotate(m, by: 2 * Double.pi * Double(k) / Double(n))) }
        }
        return out
    }

    /// Folds `p` into the fundamental region, keeping its radius: cyclic n — the wedge 0 ≤ θ < 2π/n; dihedral n —
    /// 0 ≤ θ ≤ π/n (rotate into the 2π/n wedge, then mirror when θ > π/n). The origin maps to itself and a
    /// non-finite point maps to the origin. Idempotent, and every image of `p` folds to the same point.
    public func fold(_ p: Vec2) -> Vec2 {
        guard p.isFinite else { return .zero }
        let r = p.length
        guard r > 0 else { return .zero }
        let wedge = 2 * Double.pi / Double(order)
        let theta = atan2(p.y, p.x)
        var t = theta - (theta / wedge).rounded(.down) * wedge
        if t < 0 { t = 0 }
        switch self {
        case .cyclic:
            // Angles within rounding of the wedge's far edge are the near edge (θ = 0) of the same orbit.
            if t >= wedge - 1e-12 { t = 0 }
        case .dihedral:
            if t >= wedge { t = 0 }
            if t > wedge / 2 { t = wedge - t }
        }
        if t == 0 { return Vec2(r, 0) }
        return Vec2(r * cos(t), r * sin(t))
    }

    /// Rotates `p` counter-clockwise by `angle` radians about the origin.
    static func rotate(_ p: Vec2, by angle: Double) -> Vec2 {
        let c = cos(angle), s = sin(angle)
        return Vec2(c * p.x - s * p.y, s * p.x + c * p.y)
    }
}

/// A wallpaper lattice with its full point group: `square` (p4m: 4-fold rotations and mirrors, 8 images per cell)
/// or `hexagonal` (p6m: 6-fold rotations and mirrors, 12 images per cell). Lattice spacing is 1.
public enum WallpaperLattice: Sendable, Equatable, Hashable, Codable {
    /// Square lattice, basis (1, 0) and (0, 1); point group D4.
    case square
    /// Hexagonal lattice, basis (1, 0) and (½, √3/2); point group D6.
    case hexagonal

    /// The point group applied about every lattice point: `dihedral(4)` or `dihedral(6)`.
    public var pointGroup: PointGroup {
        switch self {
        case .square: return .dihedral(4)
        case .hexagonal: return .dihedral(6)
        }
    }

    /// The number of point-group images per cell: 8 (square) or 12 (hexagonal).
    public var pointGroupImages: Int { pointGroup.imageCount }

    /// The two lattice basis vectors (unit length).
    public var basis: (Vec2, Vec2) {
        switch self {
        case .square: return (Vec2(1, 0), Vec2(0, 1))
        case .hexagonal: return (Vec2(1, 0), Vec2(0.5, 3.0.squareRoot() / 2))
        }
    }

    /// The lattice point i·a + j·b.
    func point(_ i: Int, _ j: Int) -> Vec2 {
        let (a, b) = basis
        return a * Double(i) + b * Double(j)
    }

    /// The ring of lattice coordinates (i, j): Chebyshev distance for square, hex distance for hexagonal.
    func ring(_ i: Int, _ j: Int) -> Int {
        switch self {
        case .square: return max(abs(i), abs(j))
        case .hexagonal: return (abs(i) + abs(j) + abs(i + j)) / 2
        }
    }

    /// The cell centres (lattice points) within `rings` rings of the origin: the origin first, then ring by ring;
    /// within a ring by angle in [0, 2π), then by lattice coordinates. Square gives (2r+1)² centres, hexagonal
    /// 1 + 3r(r+1). A negative `rings` is treated as 0.
    public func cellCenters(rings: Int) -> [Vec2] {
        let r = max(rings, 0)
        var cells: [(ring: Int, angle: Double, i: Int, j: Int)] = []
        for i in -r...r {
            for j in -r...r {
                let k = ring(i, j)
                guard k <= r else { continue }
                let c = point(i, j)
                var angle = k == 0 ? 0 : atan2(c.y, c.x)
                if angle < 0 { angle += 2 * Double.pi }
                cells.append((k, angle, i, j))
            }
        }
        cells.sort { a, b in
            if a.ring != b.ring { return a.ring < b.ring }
            if a.angle != b.angle { return a.angle < b.angle }
            if a.i != b.i { return a.i < b.i }
            return a.j < b.j
        }
        return cells.map { point($0.i, $0.j) }
    }

    /// The images of `p` within `rings` rings: for each cell centre (in `cellCenters(rings:)` order), the
    /// point-group images of `p` (in `PointGroup.images(of:)` order) translated to that centre.
    public func images(of p: Vec2, rings: Int) -> [Vec2] {
        let local = pointGroup.images(of: p)
        return cellCenters(rings: rings).flatMap { c in local.map { c + $0 } }
    }

    /// Folds `p` into the fundamental triangle: translate it relative to the nearest lattice point, then fold with
    /// the point group — square: 0 ≤ y ≤ x ≤ ½; hexagonal: the 30°-60°-90° triangle 0 ≤ θ ≤ π/6 of the hexagonal
    /// cell. Idempotent, periodic under the basis vectors, and every image of `p` folds to the same point. A
    /// non-finite point maps to the origin.
    public func fold(_ p: Vec2) -> Vec2 {
        guard p.isFinite else { return .zero }
        switch self {
        case .square:
            let q = p - Vec2(p.x.rounded(), p.y.rounded())
            let x = abs(q.x), y = abs(q.y)
            return y > x ? Vec2(y, x) : Vec2(x, y)
        case .hexagonal:
            let jf = p.y / (3.0.squareRoot() / 2)
            let iF = p.x - jf / 2
            // The nearest lattice point is a corner of the containing basis parallelogram (Double math, no Int
            // conversion, so very large coordinates cannot trap).
            let i0 = iF.rounded(.down), j0 = jf.rounded(.down)
            let (a, b) = basis
            var best = a * i0 + b * j0
            var bestDistance = (p - best).dot(p - best)
            for (di, dj) in [(1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
                let c = a * (i0 + di) + b * (j0 + dj)
                let d = (p - c).dot(p - c)
                if d < bestDistance { best = c; bestDistance = d }
            }
            return pointGroup.fold(p - best)
        }
    }
}
