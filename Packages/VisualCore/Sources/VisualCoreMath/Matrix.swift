// Matrix.swift — 2D affine (Mat3) and 3D (Mat4) column-major matrices (feature 006 T-F502; FR-F501, FR-F509).
import Foundation
// Column-major like GLSL: m[c][r]; `floats` uploads straight into a uniform.

/// 3×3 matrix used for 2D affine transforms (points are (x, y, 1)).
public struct Mat3: Sendable, Equatable {
    public var c0: Vec3, c1: Vec3, c2: Vec3
    public init(_ c0: Vec3, _ c1: Vec3, _ c2: Vec3) { self.c0 = c0; self.c1 = c1; self.c2 = c2 }
    public static let identity = Mat3(Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1))
    public static func translation(_ t: Vec2) -> Mat3 { Mat3(Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(t.x, t.y, 1)) }
    public static func scale(_ s: Vec2) -> Mat3 { Mat3(Vec3(s.x, 0, 0), Vec3(0, s.y, 0), Vec3(0, 0, 1)) }
    /// Counter-clockwise rotation in a y-up space (radians).
    public static func rotation(_ a: Double) -> Mat3 {
        let c = cos(a), s = sin(a)
        return Mat3(Vec3(c, s, 0), Vec3(-s, c, 0), Vec3(0, 0, 1))
    }
    /// Translate · rotate · scale (the usual node transform).
    public static func trs(_ t: Vec2, _ r: Double, _ s: Vec2) -> Mat3 { translation(t) * rotation(r) * scale(s) }

    public func row(_ i: Int) -> Vec3 {
        switch i { case 0: Vec3(c0.x, c1.x, c2.x); case 1: Vec3(c0.y, c1.y, c2.y); default: Vec3(c0.z, c1.z, c2.z) }
    }
    public static func * (a: Mat3, b: Mat3) -> Mat3 {
        func col(_ v: Vec3) -> Vec3 { Vec3(a.row(0).dot(v), a.row(1).dot(v), a.row(2).dot(v)) }
        return Mat3(col(b.c0), col(b.c1), col(b.c2))
    }
    public static func * (a: Mat3, v: Vec3) -> Vec3 { Vec3(a.row(0).dot(v), a.row(1).dot(v), a.row(2).dot(v)) }
    /// Transforms a point (w = 1).
    public func apply(_ p: Vec2) -> Vec2 { let r = self * Vec3(p.x, p.y, 1); return Vec2(r.x, r.y) }
    /// Transforms a direction (w = 0).
    public func applyVector(_ v: Vec2) -> Vec2 { let r = self * Vec3(v.x, v.y, 0); return Vec2(r.x, r.y) }
    public var determinant: Double { c0.dot(c1.cross(c2)) }
    /// Inverse, or nil when singular.
    public var inverse: Mat3? {
        let det = determinant
        guard det != 0, det.isFinite else { return nil }
        let r0 = c1.cross(c2) / det, r1 = c2.cross(c0) / det, r2 = c0.cross(c1) / det
        return Mat3(Vec3(r0.x, r1.x, r2.x), Vec3(r0.y, r1.y, r2.y), Vec3(r0.z, r1.z, r2.z))
    }
    public var floats: [Float] { [c0, c1, c2].flatMap { [Float($0.x), Float($0.y), Float($0.z)] } }
}

/// 4×4 matrix for 3D transforms and projections (GL clip space, z ∈ [-1, 1]).
public struct Mat4: Sendable, Equatable {
    public var c0: Vec4, c1: Vec4, c2: Vec4, c3: Vec4
    public init(_ c0: Vec4, _ c1: Vec4, _ c2: Vec4, _ c3: Vec4) { self.c0 = c0; self.c1 = c1; self.c2 = c2; self.c3 = c3 }
    public static let identity = Mat4(Vec4(1, 0, 0, 0), Vec4(0, 1, 0, 0), Vec4(0, 0, 1, 0), Vec4(0, 0, 0, 1))
    public static func translation(_ t: Vec3) -> Mat4 { Mat4(Vec4(1, 0, 0, 0), Vec4(0, 1, 0, 0), Vec4(0, 0, 1, 0), Vec4(t, 1)) }
    public static func scale(_ s: Vec3) -> Mat4 { Mat4(Vec4(s.x, 0, 0, 0), Vec4(0, s.y, 0, 0), Vec4(0, 0, s.z, 0), Vec4(0, 0, 0, 1)) }
    public static func rotation(_ q: Quat) -> Mat4 {
        let q = q.normalized
        let (x, y, z, w) = (q.x, q.y, q.z, q.w)
        return Mat4(Vec4(1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0),
                    Vec4(2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0),
                    Vec4(2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0),
                    Vec4(0, 0, 0, 1))
    }
    /// Right-handed perspective (camera looks down −z), GL depth range.
    public static func perspective(fovY: Double, aspect: Double, near: Double, far: Double) -> Mat4 {
        let f = 1 / tan(fovY / 2)
        return Mat4(Vec4(f / aspect, 0, 0, 0), Vec4(0, f, 0, 0),
                    Vec4(0, 0, (far + near) / (near - far), -1), Vec4(0, 0, 2 * far * near / (near - far), 0))
    }
    /// Right-handed view matrix.
    public static func lookAt(eye: Vec3, target: Vec3, up: Vec3) -> Mat4 {
        let f = (target - eye).normalized, s = f.cross(up).normalized, u = s.cross(f)
        return Mat4(Vec4(s.x, u.x, -f.x, 0), Vec4(s.y, u.y, -f.y, 0), Vec4(s.z, u.z, -f.z, 0),
                    Vec4(-s.dot(eye), -u.dot(eye), f.dot(eye), 1))
    }
    public func row(_ i: Int) -> Vec4 {
        func g(_ v: Vec4) -> Double { [v.x, v.y, v.z, v.w][i] }
        return Vec4(g(c0), g(c1), g(c2), g(c3))
    }
    public static func * (a: Mat4, v: Vec4) -> Vec4 { Vec4(a.row(0).dot(v), a.row(1).dot(v), a.row(2).dot(v), a.row(3).dot(v)) }
    public static func * (a: Mat4, b: Mat4) -> Mat4 { Mat4(a * b.c0, a * b.c1, a * b.c2, a * b.c3) }
    /// Transforms a point with perspective divide.
    public func applyPoint(_ p: Vec3) -> Vec3 { let r = self * Vec4(p, 1); return r.w != 0 ? r.xyz / r.w : r.xyz }
    public func applyVector(_ v: Vec3) -> Vec3 { (self * Vec4(v, 0)).xyz }
    /// Inverse by cofactors, or nil when singular.
    public var inverse: Mat4? {
        let m = [c0, c1, c2, c3].flatMap { [$0.x, $0.y, $0.z, $0.w] }   // column-major
        var inv = [Double](repeating: 0, count: 16)
        inv[0] = m[5]*m[10]*m[15] - m[5]*m[11]*m[14] - m[9]*m[6]*m[15] + m[9]*m[7]*m[14] + m[13]*m[6]*m[11] - m[13]*m[7]*m[10]
        inv[4] = -m[4]*m[10]*m[15] + m[4]*m[11]*m[14] + m[8]*m[6]*m[15] - m[8]*m[7]*m[14] - m[12]*m[6]*m[11] + m[12]*m[7]*m[10]
        inv[8] = m[4]*m[9]*m[15] - m[4]*m[11]*m[13] - m[8]*m[5]*m[15] + m[8]*m[7]*m[13] + m[12]*m[5]*m[11] - m[12]*m[7]*m[9]
        inv[12] = -m[4]*m[9]*m[14] + m[4]*m[10]*m[13] + m[8]*m[5]*m[14] - m[8]*m[6]*m[13] - m[12]*m[5]*m[10] + m[12]*m[6]*m[9]
        inv[1] = -m[1]*m[10]*m[15] + m[1]*m[11]*m[14] + m[9]*m[2]*m[15] - m[9]*m[3]*m[14] - m[13]*m[2]*m[11] + m[13]*m[3]*m[10]
        inv[5] = m[0]*m[10]*m[15] - m[0]*m[11]*m[14] - m[8]*m[2]*m[15] + m[8]*m[3]*m[14] + m[12]*m[2]*m[11] - m[12]*m[3]*m[10]
        inv[9] = -m[0]*m[9]*m[15] + m[0]*m[11]*m[13] + m[8]*m[1]*m[15] - m[8]*m[3]*m[13] - m[12]*m[1]*m[11] + m[12]*m[3]*m[9]
        inv[13] = m[0]*m[9]*m[14] - m[0]*m[10]*m[13] - m[8]*m[1]*m[14] + m[8]*m[2]*m[13] + m[12]*m[1]*m[10] - m[12]*m[2]*m[9]
        inv[2] = m[1]*m[6]*m[15] - m[1]*m[7]*m[14] - m[5]*m[2]*m[15] + m[5]*m[3]*m[14] + m[13]*m[2]*m[7] - m[13]*m[3]*m[6]
        inv[6] = -m[0]*m[6]*m[15] + m[0]*m[7]*m[14] + m[4]*m[2]*m[15] - m[4]*m[3]*m[14] - m[12]*m[2]*m[7] + m[12]*m[3]*m[6]
        inv[10] = m[0]*m[5]*m[15] - m[0]*m[7]*m[13] - m[4]*m[1]*m[15] + m[4]*m[3]*m[13] + m[12]*m[1]*m[7] - m[12]*m[3]*m[5]
        inv[14] = -m[0]*m[5]*m[14] + m[0]*m[6]*m[13] + m[4]*m[1]*m[14] - m[4]*m[2]*m[13] - m[12]*m[1]*m[6] + m[12]*m[2]*m[5]
        inv[3] = -m[1]*m[6]*m[11] + m[1]*m[7]*m[10] + m[5]*m[2]*m[11] - m[5]*m[3]*m[10] - m[9]*m[2]*m[7] + m[9]*m[3]*m[6]
        inv[7] = m[0]*m[6]*m[11] - m[0]*m[7]*m[10] - m[4]*m[2]*m[11] + m[4]*m[3]*m[10] + m[8]*m[2]*m[7] - m[8]*m[3]*m[6]
        inv[11] = -m[0]*m[5]*m[11] + m[0]*m[7]*m[9] + m[4]*m[1]*m[11] - m[4]*m[3]*m[9] - m[8]*m[1]*m[7] + m[8]*m[3]*m[5]
        inv[15] = m[0]*m[5]*m[10] - m[0]*m[6]*m[9] - m[4]*m[1]*m[10] + m[4]*m[2]*m[9] + m[8]*m[1]*m[6] - m[8]*m[2]*m[5]
        let det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12]
        guard det != 0, det.isFinite else { return nil }
        let r = inv.map { $0 / det }
        return Mat4(Vec4(r[0], r[1], r[2], r[3]), Vec4(r[4], r[5], r[6], r[7]), Vec4(r[8], r[9], r[10], r[11]), Vec4(r[12], r[13], r[14], r[15]))
    }
    public var floats: [Float] { [c0, c1, c2, c3].flatMap { [Float($0.x), Float($0.y), Float($0.z), Float($0.w)] } }
}
