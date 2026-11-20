// SDFShape — feature 211 (R02-F11) T-R02F11-002 (FR-R02F11-001, FR-R02F11-002, FR-R02F11-006, FR-R02F11-008;
// clarifications Q1, Q2, Q4; research R2, R3, R10). A constructive signed-distance description: primitives (plane,
// sphere, box, rounded box, capsule, torus), set operations (union, intersection, subtraction, smooth union) and
// transforms (translation, unit-quaternion rotation, uniform scale). The CPU evaluates it here — the proxy that decides
// hits, containment and contacts — and `glslFunction(name:)` emits the same description for the shader. Every
// description is a distance bound (|∇d| ≤ 1): the primitives and the hard operations are exact or bounds, the
// polynomial smooth minimum never exceeds the hard union, rotation and translation keep distances, and a uniform
// scale multiplies them by s; a non-uniform scale is not representable. Formulas: Inigo Quilez, "3D distance
// functions" and "smooth minimum" (MIT); see docs/architecture/sdf-proxies.md.
//
// A description is built only through the validating makers below (research R10: a Swift enum cannot share a case
// name with a throwing maker, so the tree is the read-only `node` of a struct).
import Foundation
import VisualCoreMath

/// A validated constructive signed-distance description (see the file header).
public struct SDFShape: Sendable, Equatable {
    /// The most nodes a description may have.
    public static let maxNodes = 256
    /// The deepest a description may be (a primitive alone has depth 1).
    public static let maxDepth = 32
    /// The most children a union or an intersection may have.
    public static let maxChildren = 32

    /// One node of the description tree; read it to inspect or store a description, build one with the makers.
    public indirect enum Node: Sendable, Equatable {
        /// The half-space below the plane n · p = offset (n of unit length; negative below).
        case plane(normal: Vec3, offset: Double)
        /// A sphere of `radius` at the origin.
        case sphere(radius: Double)
        /// An axis-aligned box with these half extents, centred at the origin.
        case box(halfExtents: Vec3)
        /// A box whose edges are rounded by `radius` (the outer size stays `halfExtents`).
        case roundedBox(halfExtents: Vec3, radius: Double)
        /// The points within `radius` of the segment from `a` to `b`.
        case capsule(a: Vec3, b: Vec3, radius: Double)
        /// A torus around the y axis: ring radius `major`, tube radius `minor`.
        case torus(major: Double, minor: Double)
        /// The union (minimum) of the children.
        case union([Node])
        /// The intersection (maximum) of the children.
        case intersection([Node])
        /// The first shape with the second removed: max(a, −b).
        case subtraction(Node, Node)
        /// The polynomial smooth union of two shapes with smoothing `radius` (0 is the hard union).
        case smoothUnion(Node, Node, radius: Double)
        /// The shape moved by `offset`.
        case translated(Node, offset: Vec3)
        /// The shape turned by the unit quaternion `rotation`.
        case rotated(Node, rotation: Quat)
        /// The shape scaled uniformly by `factor` > 0.
        case scaled(Node, factor: Double)
    }

    /// The description tree.
    public let node: Node
    /// How many nodes the description has.
    public let nodeCount: Int
    /// How deep the description is (a primitive alone has depth 1).
    public let depth: Int

    private init(_ node: Node, nodeCount: Int, depth: Int) throws(SDFError) {
        guard nodeCount <= Self.maxNodes else { throw .tooManyNodes(nodeCount) }
        guard depth <= Self.maxDepth else { throw .tooDeep(depth) }
        self.node = node
        self.nodeCount = nodeCount
        self.depth = depth
    }

    private static func leaf(_ node: Node) throws(SDFError) -> SDFShape { try SDFShape(node, nodeCount: 1, depth: 1) }

    private static func check(_ value: Double, _ name: String) throws(SDFError) {
        guard value.isFinite else { throw .nonFinite(name) }
    }

    private static func check(_ v: Vec3, _ name: String) throws(SDFError) {
        guard v.x.isFinite, v.y.isFinite, v.z.isFinite else { throw .nonFinite(name) }
    }

    private static func positive(_ value: Double, _ name: String) throws(SDFError) {
        try check(value, name)
        guard value > 0 else { throw .nonPositive(name) }
    }

    // MARK: Primitives

    /// The half-space below the plane through `normal · p = offset`; `normal` must be finite and non-zero and is
    /// normalised.
    public static func plane(normal: Vec3, offset: Double) throws(SDFError) -> SDFShape {
        try check(normal, "normal")
        try check(offset, "offset")
        guard normal.length > 0 else { throw .zeroDirection("normal") }
        return try leaf(.plane(normal: normal.normalized, offset: offset))
    }

    /// A sphere of `radius` > 0 at the origin.
    public static func sphere(radius: Double) throws(SDFError) -> SDFShape {
        try positive(radius, "radius")
        return try leaf(.sphere(radius: radius))
    }

    /// An axis-aligned box with half extents > 0, centred at the origin.
    public static func box(halfExtents: Vec3) throws(SDFError) -> SDFShape {
        try positive(halfExtents.x, "halfExtents.x")
        try positive(halfExtents.y, "halfExtents.y")
        try positive(halfExtents.z, "halfExtents.z")
        return try leaf(.box(halfExtents: halfExtents))
    }

    /// A box with half extents > 0 and edges rounded by 0 < `radius` ≤ the smallest half extent.
    public static func roundedBox(halfExtents: Vec3, radius: Double) throws(SDFError) -> SDFShape {
        _ = try box(halfExtents: halfExtents)
        try positive(radius, "radius")
        guard radius <= min(halfExtents.x, halfExtents.y, halfExtents.z) else { throw .nonPositive("radius") }
        return try leaf(.roundedBox(halfExtents: halfExtents, radius: radius))
    }

    /// The points within `radius` > 0 of the segment from `a` to `b` (a ≠ b).
    public static func capsule(a: Vec3, b: Vec3, radius: Double) throws(SDFError) -> SDFShape {
        try check(a, "a")
        try check(b, "b")
        try positive(radius, "radius")
        guard (b - a).length > 0 else { throw .zeroDirection("segment") }
        return try leaf(.capsule(a: a, b: b, radius: radius))
    }

    /// A torus around the y axis with 0 < `minor` < `major`.
    public static func torus(major: Double, minor: Double) throws(SDFError) -> SDFShape {
        try positive(major, "major")
        try positive(minor, "minor")
        guard minor < major else { throw .nonPositive("minor") }
        return try leaf(.torus(major: major, minor: minor))
    }

    // MARK: Operations

    private static func combine(_ children: [SDFShape], _ make: ([Node]) -> Node) throws(SDFError) -> SDFShape {
        guard (1...maxChildren).contains(children.count) else { throw .nonPositive("children") }
        let count = children.reduce(1) { $0 + $1.nodeCount }
        let deepest = children.map(\.depth).max() ?? 0
        return try SDFShape(make(children.map(\.node)), nodeCount: count, depth: deepest + 1)
    }

    /// The union (minimum) of 1…32 shapes.
    public static func union(_ shapes: [SDFShape]) throws(SDFError) -> SDFShape {
        try combine(shapes) { .union($0) }
    }

    /// The intersection (maximum) of 1…32 shapes.
    public static func intersection(_ shapes: [SDFShape]) throws(SDFError) -> SDFShape {
        try combine(shapes) { .intersection($0) }
    }

    /// `a` with `b` removed: max(d_a, −d_b).
    public static func subtraction(_ a: SDFShape, _ b: SDFShape) throws(SDFError) -> SDFShape {
        try SDFShape(.subtraction(a.node, b.node), nodeCount: a.nodeCount + b.nodeCount + 1,
                     depth: max(a.depth, b.depth) + 1)
    }

    /// The polynomial smooth union of `a` and `b` with a finite smoothing `radius` ≥ 0 (0 is the hard union).
    public static func smoothUnion(_ a: SDFShape, _ b: SDFShape, radius: Double) throws(SDFError) -> SDFShape {
        try check(radius, "radius")
        guard radius >= 0 else { throw .nonPositive("radius") }
        return try SDFShape(.smoothUnion(a.node, b.node, radius: radius), nodeCount: a.nodeCount + b.nodeCount + 1,
                            depth: max(a.depth, b.depth) + 1)
    }

    /// This shape moved by a finite `offset`.
    public func translated(by offset: Vec3) throws(SDFError) -> SDFShape {
        try Self.check(offset, "offset")
        return try SDFShape(.translated(node, offset: offset), nodeCount: nodeCount + 1, depth: depth + 1)
    }

    /// This shape turned by `rotation`, which must be finite and of unit length within 1e-9.
    public func rotated(by rotation: Quat) throws(SDFError) -> SDFShape {
        guard rotation.x.isFinite, rotation.y.isFinite, rotation.z.isFinite, rotation.w.isFinite else {
            throw .nonFinite("rotation")
        }
        guard abs(rotation.length - 1) <= 1e-9 else { throw .notUnitRotation }
        return try SDFShape(.rotated(node, rotation: rotation), nodeCount: nodeCount + 1, depth: depth + 1)
    }

    /// This shape scaled uniformly by a finite `factor` > 0.
    public func scaled(by factor: Double) throws(SDFError) -> SDFShape {
        try Self.positive(factor, "factor")
        return try SDFShape(.scaled(node, factor: factor), nodeCount: nodeCount + 1, depth: depth + 1)
    }

    /// Rebuilds a shape from a stored tree, re-validating every node through the makers (used by `SDFDocument`).
    public static func validated(_ node: Node) throws(SDFError) -> SDFShape {
        switch node {
        case let .plane(n, h): return try plane(normal: n, offset: h)
        case let .sphere(r): return try sphere(radius: r)
        case let .box(b): return try box(halfExtents: b)
        case let .roundedBox(b, r): return try roundedBox(halfExtents: b, radius: r)
        case let .capsule(a, b, r): return try capsule(a: a, b: b, radius: r)
        case let .torus(R, r): return try torus(major: R, minor: r)
        case let .union(children):
            var shapes: [SDFShape] = []
            for child in children { shapes.append(try validated(child)) }
            return try union(shapes)
        case let .intersection(children):
            var shapes: [SDFShape] = []
            for child in children { shapes.append(try validated(child)) }
            return try intersection(shapes)
        case let .subtraction(a, b): return try subtraction(validated(a), validated(b))
        case let .smoothUnion(a, b, k): return try smoothUnion(validated(a), validated(b), radius: k)
        case let .translated(child, t): return try validated(child).translated(by: t)
        case let .rotated(child, q): return try validated(child).rotated(by: q)
        case let .scaled(child, s): return try validated(child).scaled(by: s)
        }
    }

    // MARK: Evaluation

    /// The signed distance from `p` to the surface: negative inside, positive outside, a lower bound of the true
    /// distance where the description is not exact (smooth union, subtraction, intersection).
    public func distance(at p: Vec3) -> Double { Self.distance(node, p) }

    /// Whether `p` is strictly inside (distance < 0).
    public func contains(_ p: Vec3) -> Bool { distance(at: p) < 0 }

    /// The unit outward normal at `p`: the normalised central-difference gradient with step 1e-6 · max(1, |p|);
    /// (0, 1, 0) where the gradient has zero length.
    public func normal(at p: Vec3) -> Vec3 {
        let h = 1e-6 * max(1, p.length)
        let g = Vec3(distance(at: p + Vec3(h, 0, 0)) - distance(at: p - Vec3(h, 0, 0)),
                     distance(at: p + Vec3(0, h, 0)) - distance(at: p - Vec3(0, h, 0)),
                     distance(at: p + Vec3(0, 0, h)) - distance(at: p - Vec3(0, 0, h)))
        let l = g.length
        guard l > 0, l.isFinite else { return Vec3(0, 1, 0) }
        return g / l
    }

    /// The polynomial smooth minimum of `a` and `b` with radius `k` ≥ 0; the plain minimum at k = 0; never above it.
    public static func smoothMin(_ a: Double, _ b: Double, _ k: Double) -> Double {
        guard k > 0 else { return min(a, b) }
        let h = min(max(0.5 + 0.5 * (b - a) / k, 0), 1)
        return b + (a - b) * h - k * h * (1 - h)
    }

    private static func distance(_ node: Node, _ p: Vec3) -> Double {
        switch node {
        case let .plane(n, h):
            return n.dot(p) - h
        case let .sphere(r):
            return p.length - r
        case let .box(b):
            return boxDistance(p, b)
        case let .roundedBox(b, r):
            return boxDistance(p, b - Vec3(r, r, r)) - r
        case let .capsule(a, b, r):
            let pa = p - a, ba = b - a
            let t = min(max(pa.dot(ba) / ba.dot(ba), 0), 1)
            return (pa - ba * t).length - r
        case let .torus(R, r):
            let q = (Vec2(p.x, p.z).length - R, p.y)
            return (q.0 * q.0 + q.1 * q.1).squareRoot() - r
        case let .union(children):
            return children.reduce(Double.infinity) { min($0, distance($1, p)) }
        case let .intersection(children):
            return children.reduce(-Double.infinity) { max($0, distance($1, p)) }
        case let .subtraction(a, b):
            return max(distance(a, p), -distance(b, p))
        case let .smoothUnion(a, b, k):
            return smoothMin(distance(a, p), distance(b, p), k)
        case let .translated(child, t):
            return distance(child, p - t)
        case let .rotated(child, q):
            return distance(child, q.conjugate.rotate(p))
        case let .scaled(child, s):
            return distance(child, p / s) * s
        }
    }

    private static func boxDistance(_ p: Vec3, _ b: Vec3) -> Double {
        let q = Vec3(abs(p.x) - b.x, abs(p.y) - b.y, abs(p.z) - b.z)
        let outside = Vec3(max(q.x, 0), max(q.y, 0), max(q.z, 0)).length
        return outside + min(max(q.x, max(q.y, q.z)), 0)
    }
}
