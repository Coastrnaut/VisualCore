// SceneGraph.swift — 2D scene nodes, primitives, world transforms, draw order and hit testing
// (feature 006 T-F511; FR-F506, FR-F512). World space is y-up (Camera2D).
// feature 062 (A08-P02) T-A08-203: polyline (G-TRACESTRIP)
import VisualCoreMath

/// Filled 2D shape drawn at a scene node's local origin.
public enum Primitive: Sendable, Equatable {
    /// Axis-aligned rectangle of `size`, centered on the node origin.
    case rect(Vec2)
    case circle(Double)
    case line(Vec2, Vec2, width: Double)
    /// Simple polygon (≤ 256 points, even-odd fill).
    case polygon([Vec2])
    /// Open stroked path through `points` in order (≤ 8,192 finite points), `width` wide; each non-zero segment draws
    /// exactly like a two-point `.line` of the same width (feature 062, FR-A08-202).
    case polyline([Vec2], width: Double)

    /// Maximum polygon vertex count kept by `bounded`; extra points are dropped.
    public static let maxPolygonPoints = 256
    /// Maximum polyline point count kept by `bounded` (two points per column for 4,096 columns); extra points are dropped.
    public static let maxPolylinePoints = 8_192

    /// The primitive with sizes made non-negative and finite, the polygon truncated to 256 points (FR-F512) and the
    /// polyline reduced to its first 8,192 finite points.
    public var bounded: Primitive {
        func f(_ v: Double) -> Double { v.isFinite ? abs(v) : 0 }
        switch self {
        case .rect(let s): return .rect(Vec2(f(s.x), f(s.y)))
        case .circle(let r): return .circle(f(r))
        case .line(let a, let b, let w): return .line(a, b, width: f(w))
        case .polygon(let p): return .polygon(Array(p.prefix(Self.maxPolygonPoints)))
        case .polyline(let p, let w):
            var kept: [Vec2] = []
            kept.reserveCapacity(Swift.min(p.count, Self.maxPolylinePoints))
            for v in p where v.x.isFinite && v.y.isFinite {
                kept.append(v)
                if kept.count == Self.maxPolylinePoints { break }
            }
            return .polyline(kept, width: f(w))
        }
    }

    /// Distance from `p` to the segment `a`–`b` (to `a` when the segment is a point).
    private static func distance(_ p: Vec2, _ a: Vec2, _ b: Vec2) -> Double {
        let ab = b - a, len2 = ab.dot(ab)
        let t = len2 > 0 ? min(max((p - a).dot(ab) / len2, 0), 1) : 0
        return p.distance(to: a + ab * t)
    }

    /// Whether a local-space point lies inside the shape (for a polyline: within `width / 2` of any segment, or of
    /// its single point; an empty polyline contains nothing).
    public func contains(_ p: Vec2) -> Bool {
        switch self {
        case .rect(let s): return abs(p.x) <= s.x / 2 && abs(p.y) <= s.y / 2
        case .circle(let r): return p.length <= r
        case .line(let a, let b, let w):
            return Self.distance(p, a, b) <= w / 2
        case .polyline(let pts, let w):
            guard let first = pts.first else { return false }
            if pts.count == 1 { return p.distance(to: first) <= w / 2 }
            for i in 1..<pts.count where Self.distance(p, pts[i - 1], pts[i]) <= w / 2 { return true }
            return false
        case .polygon(let pts):
            guard pts.count >= 3 else { return false }
            var inside = false
            var j = pts.count - 1
            for i in pts.indices {
                let pi = pts[i], pj = pts[j]
                if (pi.y > p.y) != (pj.y > p.y), p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x { inside.toggle() }
                j = i
            }
            return inside
        }
    }
}

/// A node in a 2D scene: transform, z-order, visibility, an optional filled primitive and children.
public final class SceneNode {
    /// Caller-defined identifier (not required to be unique; default empty).
    public var id: String
    /// Translation relative to the parent, in world units (y-up).
    public var position: Vec2
    /// Counter-clockwise, radians.
    public var rotation: Double
    /// Per-axis scale relative to the parent (default 1, 1).
    public var scale: Vec2
    /// Draw order among siblings (higher on top; ties keep insertion order).
    public var z: Int
    /// When false, this node and its whole subtree are skipped by `drawList` (default true).
    public var isVisible = true
    /// Shape drawn by this node; assignments are normalized through `Primitive.bounded`.
    public var primitive: Primitive? { didSet { if let p = primitive, p != p.bounded { primitive = p.bounded } } }
    /// Premultiplication happens at draw time; components 0…1.
    public var color: Vec4
    /// Child nodes in insertion order.
    public private(set) var children: [SceneNode] = []
    /// Owning parent node (weak); nil for a root or detached node.
    public private(set) weak var parent: SceneNode?

    /// Creates a node; `primitive` is normalized through `bounded`, `color` defaults to opaque white.
    public init(id: String = "", position: Vec2 = .zero, rotation: Double = 0, scale: Vec2 = Vec2(1, 1), z: Int = 0,
                primitive: Primitive? = nil, color: Vec4 = Vec4(1, 1, 1, 1)) {
        self.id = id; self.position = position; self.rotation = rotation; self.scale = scale; self.z = z
        self.primitive = primitive?.bounded
        self.color = color
    }

    /// Appends `child`, detaching it from any previous parent first.
    public func add(_ child: SceneNode) {
        child.removeFromParent()
        child.parent = self
        children.append(child)
    }

    /// Detaches this node from its parent; no-op for a root.
    public func removeFromParent() {
        parent?.children.removeAll { $0 === self }
        parent = nil
    }

    /// Translate × rotate × scale matrix from local to parent space.
    public var localTransform: Mat3 { Mat3.trs(position, rotation, scale) }

    /// Local → world, through all ancestors.
    public func worldTransform() -> Mat3 {
        var m = localTransform, p = parent
        while let node = p { m = node.localTransform * m; p = node.parent }
        return m
    }

    /// Visible nodes in draw order (back to front) with their world transforms; hidden subtrees are skipped.
    public func drawList(parentTransform: Mat3 = .identity) -> [(node: SceneNode, world: Mat3)] {
        guard isVisible else { return [] }
        let world = parentTransform * localTransform
        var out: [(node: SceneNode, world: Mat3)] = [(self, world)]
        let ordered = children.enumerated().sorted { ($0.element.z, $0.offset) < ($1.element.z, $1.offset) }
        for (_, child) in ordered { out += child.drawList(parentTransform: world) }
        return out
    }

    /// The topmost visible node whose primitive contains the world point.
    public func hitTest(_ world: Vec2) -> SceneNode? {
        let base = parent?.worldTransform() ?? .identity
        for (node, m) in drawList(parentTransform: base).reversed() {
            guard let shape = node.primitive, let inv = m.inverse else { continue }
            if shape.contains(inv.apply(world)) { return node }
        }
        return nil
    }
}
