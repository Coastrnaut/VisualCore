// Contacts2D.swift — 2D rigid-body contact generation for circles and oriented boxes: a shape, a pose, a contact
// manifold and `Contacts2D.collide` for circle–circle, circle–box, box–circle and box–box (separating-axis test with
// reference-face clipping) (feature 082 (A11-P01) T-A11-102 (FR-A11-101); contract specs/082-pp-p01-model/contracts/
// api.md; research D1). Every function is pure and deterministic; non-finite poses or non-positive sizes never report
// a contact.
import Foundation
import VisualCoreMath

/// A convex 2D collision shape in its own local frame, centred on the origin.
public enum Shape2D: Sendable, Equatable, Codable {
    /// A circle with the given radius in world units.
    case circle(radius: Double)
    /// An axis-aligned box in local space with the given half extents (half width, half height) in world units.
    case box(halfExtents: Vec2)

    /// Area of the shape: π·r² for a circle, 4·hx·hy for a box.
    public var area: Double {
        switch self {
        case .circle(let radius): return Double.pi * radius * radius
        case .box(let h): return 4 * h.x * h.y
        }
    }

    /// Moment of inertia about the centre for the given mass: m·r²/2 for a circle (solid disc) and m·(w² + h²)/12 for a
    /// box with width w = 2·hx and height h = 2·hy.
    public func inertia(mass: Double) -> Double {
        switch self {
        case .circle(let radius): return mass * radius * radius / 2
        case .box(let h):
            let w = 2 * h.x, ht = 2 * h.y
            return mass * (w * w + ht * ht) / 12
        }
    }

    /// True when every size is finite and strictly positive.
    var isValid: Bool {
        switch self {
        case .circle(let radius): return radius.isFinite && radius > 0
        case .box(let h): return h.isFinite && h.x > 0 && h.y > 0
        }
    }
}

/// The placement of a shape in the world: the position of its centre and its rotation in radians (counter-clockwise).
public struct Pose2D: Sendable, Equatable {
    /// Position of the shape's centre in world units.
    public var position: Vec2
    /// Rotation in radians, counter-clockwise.
    public var angle: Double

    /// Creates a pose from a position and an angle in radians (default 0).
    public init(position: Vec2, angle: Double = 0) {
        self.position = position
        self.angle = angle
    }

    /// Maps a point from the shape's local frame to world space: rotate by `angle`, then translate by `position`.
    public func toWorld(_ local: Vec2) -> Vec2 { position + rotate(local) }

    /// Maps a world-space point into the shape's local frame: the inverse of `toWorld(_:)`.
    public func toLocal(_ world: Vec2) -> Vec2 {
        let d = world - position
        let c = cos(angle), s = sin(angle)
        return Vec2(c * d.x + s * d.y, -s * d.x + c * d.y)
    }

    /// Rotates a direction by `angle` without translating it.
    func rotate(_ v: Vec2) -> Vec2 {
        let c = cos(angle), s = sin(angle)
        return Vec2(c * v.x - s * v.y, s * v.x + c * v.y)
    }

    /// True when the position and the angle are finite.
    var isFinite: Bool { position.isFinite && angle.isFinite }
}

/// The contact between two shapes: a unit normal pointing from the first shape to the second, the penetration depth
/// (≥ 0) and one or two contact points in world space.
public struct ContactManifold2D: Sendable, Equatable {
    /// Unit normal pointing from the first shape to the second.
    public var normal: Vec2
    /// Penetration depth along the normal, ≥ 0; 0 means the shapes touch within `Contacts2D.tolerance`.
    public var depth: Double
    /// One or two contact points in world space.
    public var points: [Vec2]

    /// Creates a manifold from its normal, depth and points.
    public init(normal: Vec2, depth: Double, points: [Vec2]) {
        self.normal = normal
        self.depth = depth
        self.points = points
    }
}

/// Pure, deterministic contact generation between circles and oriented boxes.
public enum Contacts2D {
    /// Slack added to every contact comparison so that exactly touching shapes count as touching (depth 0) despite
    /// rounding.
    public static let tolerance: Double = 1e-9

    /// Returns the contact between shape `a` at `poseA` and shape `b` at `poseB`, or nil when they are separated by more
    /// than `tolerance`, when a pose is not finite or when a size is not finite and positive. The normal points from `a`
    /// to `b`; swapping the arguments flips it.
    public static func collide(_ a: Shape2D, _ poseA: Pose2D, _ b: Shape2D, _ poseB: Pose2D) -> ContactManifold2D? {
        guard a.isValid, b.isValid, poseA.isFinite, poseB.isFinite else { return nil }
        switch (a, b) {
        case let (.circle(ra), .circle(rb)):
            return circleCircle(poseA.position, ra, poseB.position, rb)
        case let (.circle(ra), .box(hb)):
            guard let m = boxCircle(hb, poseB, poseA.position, ra) else { return nil }
            return ContactManifold2D(normal: -m.normal, depth: m.depth, points: m.points)
        case let (.box(ha), .circle(rb)):
            return boxCircle(ha, poseA, poseB.position, rb)
        case let (.box(ha), .box(hb)):
            return boxBox(ha, poseA, hb, poseB)
        }
    }

    // MARK: Circle–circle

    private static func circleCircle(_ ca: Vec2, _ ra: Double, _ cb: Vec2, _ rb: Double) -> ContactManifold2D? {
        let d = cb - ca
        let distance = d.length
        let reach = ra + rb
        guard distance.isFinite, distance <= reach + tolerance else { return nil }
        let normal = distance > 0 ? d / distance : Vec2(0, 1)
        let depth = max(reach - distance, 0)
        let point = ca + normal * (ra - depth / 2)
        return ContactManifold2D(normal: normal, depth: depth, points: [point])
    }

    // MARK: Box–circle (normal from the box to the circle)

    private static func boxCircle(_ h: Vec2, _ pose: Pose2D, _ center: Vec2, _ r: Double) -> ContactManifold2D? {
        let local = pose.toLocal(center)
        let clamped = Vec2(min(max(local.x, -h.x), h.x), min(max(local.y, -h.y), h.y))
        let d = local - clamped
        let distance = d.length
        guard distance.isFinite else { return nil }
        if distance > 0 {
            guard distance <= r + tolerance else { return nil }
            let normal = pose.rotate(d / distance)
            return ContactManifold2D(normal: normal, depth: max(r - distance, 0), points: [pose.toWorld(clamped)])
        }
        // Centre inside (or on the surface of) the box: push out along the face of least penetration.
        let dx = h.x - abs(local.x), dy = h.y - abs(local.y)
        let localNormal: Vec2
        let localPoint: Vec2
        let faceDepth: Double
        if dx <= dy {
            let sx: Double = local.x < 0 ? -1 : 1
            localNormal = Vec2(sx, 0)
            localPoint = Vec2(sx * h.x, local.y)
            faceDepth = dx
        } else {
            let sy: Double = local.y < 0 ? -1 : 1
            localNormal = Vec2(0, sy)
            localPoint = Vec2(local.x, sy * h.y)
            faceDepth = dy
        }
        return ContactManifold2D(normal: pose.rotate(localNormal), depth: faceDepth + r,
                                 points: [pose.toWorld(localPoint)])
    }

    // MARK: Box–box

    /// A box as a counter-clockwise quad in world space with the outward normal of each edge i → i + 1.
    private struct Quad {
        var vertices: [Vec2]
        var normals: [Vec2]

        init(_ h: Vec2, _ pose: Pose2D) {
            vertices = [Vec2(-h.x, -h.y), Vec2(h.x, -h.y), Vec2(h.x, h.y), Vec2(-h.x, h.y)].map(pose.toWorld)
            normals = [Vec2(0, -1), Vec2(1, 0), Vec2(0, 1), Vec2(-1, 0)].map(pose.rotate)
        }
    }

    /// The largest separation of `q2` from any face of `q1` and the index of that face (first index on ties).
    private static func maxSeparation(_ q1: Quad, _ q2: Quad) -> (separation: Double, face: Int) {
        var best = -Double.infinity
        var face = 0
        for i in 0..<4 {
            let n = q1.normals[i], v = q1.vertices[i]
            var s = Double.infinity
            for w in q2.vertices { s = min(s, n.dot(w - v)) }
            if s > best { best = s; face = i }
        }
        return (best, face)
    }

    /// Keeps the part of the segment (one or two points) on the side where n·p − offset ≤ 0.
    private static func clip(_ points: [Vec2], _ n: Vec2, _ offset: Double) -> [Vec2] {
        guard points.count == 2 else {
            return points.filter { n.dot($0) - offset <= tolerance }
        }
        let d0 = n.dot(points[0]) - offset, d1 = n.dot(points[1]) - offset
        var out: [Vec2] = []
        if d0 <= 0 { out.append(points[0]) }
        if d1 <= 0 { out.append(points[1]) }
        if d0 * d1 < 0 {
            let t = d0 / (d0 - d1)
            out.append(points[0] + (points[1] - points[0]) * t)
        }
        return out
    }

    private static func boxBox(_ ha: Vec2, _ poseA: Pose2D, _ hb: Vec2, _ poseB: Pose2D) -> ContactManifold2D? {
        let qa = Quad(ha, poseA), qb = Quad(hb, poseB)
        let sa = maxSeparation(qa, qb)
        guard sa.separation.isFinite, sa.separation <= tolerance else { return nil }
        let sb = maxSeparation(qb, qa)
        guard sb.separation.isFinite, sb.separation <= tolerance else { return nil }

        // Reference face: the one of least penetration, biased towards the first box so the choice does not flicker
        // between nearly equal faces from one step to the next.
        let bias = 0.01 * min(ha.x, ha.y, hb.x, hb.y)
        let flip = sb.separation > 0.95 * sa.separation + bias
        let ref = flip ? qb : qa, inc = flip ? qa : qb
        let face = flip ? sb.face : sa.face
        let refNormal = ref.normals[face]

        // Incident edge: the edge of the other box whose normal is most anti-parallel to the reference normal.
        var incFace = 0
        var minDot = Double.infinity
        for i in 0..<4 {
            let d = inc.normals[i].dot(refNormal)
            if d < minDot { minDot = d; incFace = i }
        }
        let incident = [inc.vertices[incFace], inc.vertices[(incFace + 1) % 4]]

        let v1 = ref.vertices[face], v2 = ref.vertices[(face + 1) % 4]
        let tangent = (v2 - v1).normalized
        var clipped = clip(incident, -tangent, -tangent.dot(v1))
        clipped = clip(clipped, tangent, tangent.dot(v2))

        var points: [Vec2] = []
        var depth = 0.0
        for p in clipped {
            let separation = refNormal.dot(p - v1)
            if separation <= tolerance {
                points.append(p)
                depth = max(depth, -separation)
            }
        }
        if points.isEmpty {
            // Corner-to-corner grazing contacts can clip away the whole incident edge: fall back to the deepest
            // incident vertex.
            var best = Double.infinity
            var bestPoint = inc.vertices[0]
            for w in inc.vertices {
                let s = refNormal.dot(w - v1)
                if s < best { best = s; bestPoint = w }
            }
            guard best <= tolerance else { return nil }
            points = [bestPoint]
            depth = max(-best, 0)
        }
        let normal = flip ? -refNormal : refNormal
        return ContactManifold2D(normal: normal, depth: depth, points: Array(points.prefix(2)))
    }
}
