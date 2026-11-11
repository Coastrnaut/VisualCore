// PrimitiveRenderer.swift — draws a 2D SceneNode tree (rect, circle, line, polygon) as one batched
// triangle list (feature 006 T-F513; FR-F506, FR-F508, FR-F512; research R7). Vertices are transformed
// to NDC on the CPU (Double precision), colors premultiplied, blended with ONE / ONE_MINUS_SRC_ALPHA.
// GPU objects come from the registry; after a context recreation they are rebuilt on the next draw.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Draws a 2D SceneNode tree as one batched, premultiplied-alpha triangle list on the main thread; GPU objects are rebuilt after a context recreation.
@MainActor
public final class PrimitiveRenderer {
    /// Upper bound on segments per circle.
    public static let maxCircleSegments = 128
    /// Lower bound on segments per circle.
    public static let minCircleSegments = 12

    let registry: ResourceRegistry
    private var program: ShaderProgram?
    private let vertices: DynamicVertexBuffer
    /// Triangles drawn by the last call (tests, diagnostics).
    public private(set) var lastTriangleCount = 0

    static let vertexSource = """
    layout(location = 0) in vec2 a_position;
    layout(location = 1) in vec4 a_color;
    out vec4 v_color;
    void main() { v_color = a_color; gl_Position = vec4(a_position, 0.0, 1.0); }
    """
    static let fragmentSource = """
    precision mediump float;
    in vec4 v_color;
    out vec4 color;
    void main() { color = v_color; }
    """

    /// Creates the vertex buffer and compiles the primitive program; throws on shader errors.
    public init(registry: ResourceRegistry) throws {
        self.registry = registry
        vertices = DynamicVertexBuffer(registry: registry, label: "primitives")
        program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
    }

    /// Draws `root` into the bound framebuffer, whose viewport covers `metrics` (points × scale).
    public func draw(_ root: SceneNode, camera: Camera2D, metrics: ViewMetrics) throws {
        guard let toNDC = metrics.worldToNDC(camera: camera) else { return }
        if program == nil || program!.generation != registry.generation {
            program = try registry.program(vertex: Self.vertexSource, fragment: Self.fragmentSource)
        }
        var data: [Float] = []
        let pointsPerWorld = camera.zoom
        for (node, world) in root.drawList() {
            guard let shape = node.primitive else { continue }
            let m = toNDC * world
            let c = node.color
            let rgba: [Float] = [Float(c.x * c.w), Float(c.y * c.w), Float(c.z * c.w), Float(c.w)]
            let scale = max(world.applyVector(Vec2(1, 0)).length, world.applyVector(Vec2(0, 1)).length)
            for p in Self.triangles(shape, pointsPerUnit: pointsPerWorld * scale) {
                let n = m.apply(p)
                data += [Float(n.x), Float(n.y)] + rgba
            }
        }
        lastTriangleCount = data.count / 18
        guard !data.isEmpty, let program else { return }
        try vertices.upload(data)
        program.use()
        vcAttribute(0, components: 2, strideFloats: 6, offsetFloats: 0)
        vcAttribute(1, components: 4, strideFloats: 6, offsetFloats: 2)
        vcglEnable(GLenum(GL_BLEND))
        vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(data.count / 6))
        vcglDisable(GLenum(GL_BLEND))
        vcglDisableVertexAttribArray(0)
        vcglDisableVertexAttribArray(1)
    }

    /// Releases the vertex buffer and program back to the registry.
    public func release() {
        vertices.release()
        if let program { registry.release(program) }
        program = nil
    }

    /// Circle segment count for a radius on screen (points): about one segment per 3 pt, 12…128.
    static func segments(radius: Double, pointsPerUnit: Double) -> Int {
        let onScreen = radius * pointsPerUnit
        guard onScreen.isFinite else { return minCircleSegments }
        return min(max(Int((2 * .pi * onScreen / 3).rounded(.up)), minCircleSegments), maxCircleSegments)
    }

    /// Local-space triangle vertices (3 per triangle).
    static func triangles(_ shape: Primitive, pointsPerUnit: Double) -> [Vec2] {
        switch shape.bounded {
        case .rect(let s):
            let a = Vec2(-s.x / 2, -s.y / 2), b = Vec2(s.x / 2, -s.y / 2), c = Vec2(s.x / 2, s.y / 2), d = Vec2(-s.x / 2, s.y / 2)
            return [a, b, c, a, c, d]
        case .circle(let r):
            let n = segments(radius: r, pointsPerUnit: pointsPerUnit)
            var out: [Vec2] = []
            out.reserveCapacity(n * 3)
            for i in 0..<n {
                let a0 = 2 * Double.pi * Double(i) / Double(n), a1 = 2 * Double.pi * Double(i + 1) / Double(n)
                out += [.zero, Vec2(cos(a0) * r, sin(a0) * r), Vec2(cos(a1) * r, sin(a1) * r)]
            }
            return out
        case .line(let a, let b, let w):
            let d = (b - a).normalized
            guard d != .zero else { return [] }
            let n = Vec2(-d.y, d.x) * (w / 2)
            return [a + n, a - n, b - n, a + n, b - n, b + n]
        case .polygon(let pts):
            return earClip(pts)
        }
    }

    /// Ear-clipping triangulation of a simple polygon (either winding); O(n²) for ≤ 256 points.
    static func earClip(_ pts: [Vec2]) -> [Vec2] {
        guard pts.count >= 3 else { return [] }
        var area = 0.0
        for i in pts.indices { area += pts[i].cross(pts[(i + 1) % pts.count]) }
        var idx = Array(pts.indices)
        if area < 0 { idx.reverse() }   // make counter-clockwise
        var out: [Vec2] = []
        var guardCount = 0
        while idx.count > 3 && guardCount < 4 * pts.count * pts.count {
            guardCount += 1
            var clipped = false
            for k in idx.indices {
                let i0 = idx[(k + idx.count - 1) % idx.count], i1 = idx[k], i2 = idx[(k + 1) % idx.count]
                let a = pts[i0], b = pts[i1], c = pts[i2]
                guard (b - a).cross(c - b) > 0 else { continue }   // reflex or degenerate
                let containsOther = idx.contains { j in
                    j != i0 && j != i1 && j != i2 && pointInTriangle(pts[j], a, b, c)
                }
                if containsOther { continue }
                out += [a, b, c]
                idx.remove(at: k)
                clipped = true
                break
            }
            if !clipped { break }   // not simple: fall back to a fan for the rest
        }
        if idx.count >= 3 { for k in 1..<(idx.count - 1) { out += [pts[idx[0]], pts[idx[k]], pts[idx[k + 1]]] } }
        return out
    }

    static func pointInTriangle(_ p: Vec2, _ a: Vec2, _ b: Vec2, _ c: Vec2) -> Bool {
        let d1 = (b - a).cross(p - a), d2 = (c - b).cross(p - b), d3 = (a - c).cross(p - c)
        return d1 >= 0 && d2 >= 0 && d3 >= 0
    }
}
