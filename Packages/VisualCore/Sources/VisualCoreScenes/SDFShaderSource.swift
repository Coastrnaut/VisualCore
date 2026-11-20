// SDFShaderSource — feature 211 (R02-F11) T-R02F11-006 (FR-R02F11-003; research R7). Emits an `SDFShape` description as
// a straight-line GLSL ES 3.00 function `float <name>(vec3 p)` that evaluates the same distance as
// `SDFShape.distance(at:)` in float: primitives call vc/sdf.glsl and vc/sdfshape.glsl, operations call the vc_op*
// helpers, and transforms become new local points (translation p − t, rotation by the inverse rotation as a mat3
// literal, uniform scale p / s with the child's distance multiplied by s). No recursion and no loops are emitted.
import Foundation
import VisualCoreMath

extension SDFShape {
    /// This description as the GLSL ES 3.00 function `float <name>(vec3 p)`, returning the same signed distance as
    /// `distance(at:)` (in float). The shader that uses it must include `vc/sdf.glsl` and then `vc/sdfshape.glsl`
    /// before the function, for example `#include "vc/sdf.glsl"` and `#include "vc/sdfshape.glsl"`. Locals are
    /// numbered `p1`, `d1`, …; `name` must be a valid GLSL identifier.
    public func glslFunction(name: String = "vc_sdfShape") -> String {
        var emitter = SDFGLSLEmitter()
        let result = emitter.emit(node, point: "p")
        var text = "float \(name)(vec3 p) {\n"
        for line in emitter.lines { text += "    \(line)\n" }
        text += "    return \(result);\n}\n"
        return text
    }
}

/// Builds the straight-line body of `SDFShape.glslFunction(name:)`.
struct SDFGLSLEmitter {
    /// The emitted statements, in order.
    private(set) var lines: [String] = []
    private var points = 0
    private var distances = 0

    /// A GLSL float literal of `value` with nine significant digits, always with a decimal point or an exponent.
    static func float(_ value: Double) -> String {
        var text = String(format: "%.9g", value)
        if !text.contains(".") && !text.contains("e") { text += ".0" }
        return text
    }

    /// A GLSL `vec3` literal of `v`.
    static func vec3(_ v: Vec3) -> String { "vec3(\(float(v.x)), \(float(v.y)), \(float(v.z)))" }

    private mutating func newPoint(_ expression: String) -> String {
        points += 1
        lines.append("vec3 p\(points) = \(expression);")
        return "p\(points)"
    }

    private mutating func newDistance(_ expression: String) -> String {
        distances += 1
        lines.append("float d\(distances) = \(expression);")
        return "d\(distances)"
    }

    /// Emits the statements for `node` evaluated at the local point `point` and returns the distance variable.
    mutating func emit(_ node: SDFShape.Node, point: String) -> String {
        typealias F = SDFGLSLEmitter
        switch node {
        case let .plane(n, h):
            return newDistance("vc_sdPlane(\(point), \(F.vec3(n)), \(F.float(h)))")
        case let .sphere(r):
            return newDistance("vc_sdSphere(\(point), \(F.float(r)))")
        case let .box(b):
            return newDistance("vc_sdBox(\(point), \(F.vec3(b)))")
        case let .roundedBox(b, r):
            return newDistance("vc_sdRoundBox(\(point), \(F.vec3(b)), \(F.float(r)))")
        case let .capsule(a, b, r):
            return newDistance("vc_sdCapsule(\(point), \(F.vec3(a)), \(F.vec3(b)), \(F.float(r)))")
        case let .torus(R, r):
            return newDistance("vc_sdTorus(\(point), vec2(\(F.float(R)), \(F.float(r))))")
        case let .union(children), let .intersection(children):
            let op: String
            if case .union = node { op = "vc_opUnion" } else { op = "vc_opIntersect" }
            var result = emit(children[0], point: point)
            for child in children.dropFirst() {
                let next = emit(child, point: point)
                result = newDistance("\(op)(\(result), \(next))")
            }
            return result
        case let .subtraction(a, b):
            let da = emit(a, point: point), db = emit(b, point: point)
            return newDistance("vc_opSubtract(\(da), \(db))")
        case let .smoothUnion(a, b, k):
            let da = emit(a, point: point), db = emit(b, point: point)
            return newDistance("vc_opSmoothUnion(\(da), \(db), \(F.float(k)))")
        case let .translated(child, t):
            return emit(child, point: newPoint("\(point) - \(F.vec3(t))"))
        case let .rotated(child, q):
            // The CPU evaluates the child at q.conjugate.rotate(p); its columns are the images of the unit axes
            // (GLSL mat3 constructors are column-major).
            let inverse = q.conjugate
            let c0 = inverse.rotate(Vec3(1, 0, 0)), c1 = inverse.rotate(Vec3(0, 1, 0)), c2 = inverse.rotate(Vec3(0, 0, 1))
            return emit(child, point: newPoint("mat3(\(F.vec3(c0)), \(F.vec3(c1)), \(F.vec3(c2))) * \(point)"))
        case let .scaled(child, s):
            let inner = emit(child, point: newPoint("\(point) / \(F.float(s))"))
            return newDistance("\(inner) * \(F.float(s))")
        }
    }
}
