// Motif.swift — feature 040 (A05-P01) T-A05-103 (FR-A05-112, FR-A05-113; spec Clarifications: the motif).
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The seeded shape a composition repeats: the only seeded element of a preset (spec Clarifications).
///
/// For the 2D kinds it is a convex, counter-clockwise polygon of 3–7 points strictly inside the fundamental region of the
/// kind's group (coordinates in the group's own frame, before any view scaling):
/// - `kaleidoscope`: the dihedral(order) wedge 0 ≤ θ ≤ π/order, vertices at radius 0.15…0.9;
/// - `squareTiling`: the p4m triangle 0 ≤ y ≤ x ≤ ½ of the unit cell;
/// - `hexTiling`: the part of the p6m triangle within the wedge 0 ≤ θ ≤ π/6 at radius ≤ 0.45 (inside the cell's
///   inscribed circle for a neighbour distance of 1, so the cell images never overlap).
///
/// Construction: a centre is drawn well inside the region; 3–7 points are placed on a circle around it at sorted,
/// jittered angles (points on a circle in angle order always form a convex polygon, and the jitter keeps every gap
/// below π); the polygon is then shrunk about the centre by factors of 0.8 until every vertex lies inside the region
/// with a margin of 1e-3. The region is convex, so the whole polygon lies inside it (the kaleidoscope's inner radius
/// 0.15 bounds the vertices only).
///
/// For `solid` the motif is instead a revolution profile of 5–9 points in the (radius, height) plane: it starts and
/// ends on the axis (radius 0, heights −0.6…−0.3 and 0.3…0.6) so the revolved petal closes with two poles; the interior
/// points have radius 0.05…0.5 and strictly increasing heights.
public struct Motif: Sendable, Equatable {
    /// The polygon vertices (counter-clockwise), or for `solid` the profile from bottom to top.
    public let points: [Vec2]

    /// Margin by which every 2D vertex lies inside its region.
    static let margin = 1e-3

    /// The motif for `seed`, deterministic on every platform (`SeededRandom(seed:)`); `order` is clamped to 1…24 and is
    /// used by the kaleidoscope wedge only.
    public static func make(seed: UInt64, kind: GeometryPreset.Kind, order: Int) -> Motif {
        var rng = SeededRandom(seed: seed)
        let n = min(max(order, GeometryPreset.orderRange.lowerBound), GeometryPreset.orderRange.upperBound)
        switch kind {
        case .solid:
            return Motif(points: profile(&rng))
        case .kaleidoscope:
            let alpha = Double.pi / Double(n)
            let theta = alpha * rng.range(0.3...0.7), r = rng.range(0.35...0.65)
            return convex(&rng, centre: Vec2(r * cos(theta), r * sin(theta)), radius: 0.25) {
                isInside($0, kind: .kaleidoscope, order: n)
            }
        case .squareTiling:
            var w = (0..<3).map { _ in rng.range(0.2...0.8) }
            let total = w.reduce(0, +)
            w = w.map { $0 / total }
            let centre = Vec2(0.5, 0) * w[1] + Vec2(0.5, 0.5) * w[2]
            return convex(&rng, centre: centre, radius: 0.2) { isInside($0, kind: .squareTiling, order: n) }
        case .hexTiling:
            let theta = Double.pi / 6 * rng.range(0.3...0.7), r = rng.range(0.2...0.3)
            return convex(&rng, centre: Vec2(r * cos(theta), r * sin(theta)), radius: 0.15) {
                isInside($0, kind: .hexTiling, order: n)
            }
        }
    }

    /// Whether `p` lies inside the 2D fundamental region of `kind` with `margin` to spare (always false for `solid`).
    static func isInside(_ p: Vec2, kind: GeometryPreset.Kind, order: Int) -> Bool {
        switch kind {
        case .kaleidoscope:
            let r = p.length
            return inWedge(p, alpha: .pi / Double(order)) && r >= 0.15 && r <= 0.9
        case .squareTiling:
            return p.y >= margin && (p.x - p.y) / 2.0.squareRoot() >= margin && 0.5 - p.x >= margin
        case .hexTiling:
            return inWedge(p, alpha: .pi / 6) && p.length <= 0.45 - margin
        case .solid:
            return false
        }
    }

    /// Whether `p` lies in the wedge 0 ≤ θ ≤ alpha (alpha ≤ π) at least `margin` from both boundary rays' lines.
    private static func inWedge(_ p: Vec2, alpha: Double) -> Bool {
        p.y >= margin && p.cross(Vec2(cos(alpha), sin(alpha))) >= margin
    }

    /// A convex polygon of 3–7 points around `centre`, shrunk until `inside` holds for every vertex.
    private static func convex(_ rng: inout SeededRandom, centre: Vec2, radius: Double,
                               inside: (Vec2) -> Bool) -> Motif {
        let count = rng.int(3...7)
        let start = rng.range(0...(2 * Double.pi))
        let directions = (0..<count).map { k -> Vec2 in
            let a = start + 2 * Double.pi * (Double(k) + rng.range(-0.2...0.2)) / Double(count)
            return Vec2(cos(a), sin(a))
        }
        var r = radius
        var points = directions.map { centre + $0 * r }
        var steps = 0
        while !points.allSatisfy(inside), steps < 400 {
            r *= 0.8
            points = directions.map { centre + $0 * r }
            steps += 1
        }
        return Motif(points: points)
    }

    /// A revolution profile of 5–9 points from the bottom pole to the top pole.
    private static func profile(_ rng: inout SeededRandom) -> [Vec2] {
        let count = rng.int(5...9)
        let bottom = rng.range(-0.6 ... -0.3), top = rng.range(0.3...0.6)
        let interior = count - 2
        var points = [Vec2(0, bottom)]
        for k in 1...interior {
            let t = (Double(k) + rng.range(-0.3...0.3)) / Double(interior + 1)
            points.append(Vec2(rng.range(0.05...0.5), bottom + (top - bottom) * t))
        }
        points.append(Vec2(0, top))
        return points
    }
}
