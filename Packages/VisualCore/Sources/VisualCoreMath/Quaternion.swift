// Quaternion.swift — unit quaternions for 3D rotation (feature 006 T-F502; FR-F509).
import Foundation

public struct Quat: Sendable, Equatable {
    public var x: Double, y: Double, z: Double, w: Double
    public init(x: Double, y: Double, z: Double, w: Double) { self.x = x; self.y = y; self.z = z; self.w = w }
    public static let identity = Quat(x: 0, y: 0, z: 0, w: 1)
    /// Rotation by `angle` radians about `axis` (right-handed).
    public init(axis: Vec3, angle: Double) {
        let a = axis.normalized, s = sin(angle / 2)
        self.init(x: a.x * s, y: a.y * s, z: a.z * s, w: cos(angle / 2))
    }
    public var length: Double { (x * x + y * y + z * z + w * w).squareRoot() }
    public var normalized: Quat { let l = length; return l > 0 ? Quat(x: x / l, y: y / l, z: z / l, w: w / l) : .identity }
    public var conjugate: Quat { Quat(x: -x, y: -y, z: -z, w: w) }
    /// Hamilton product: `a * b` applies b first, then a.
    public static func * (a: Quat, b: Quat) -> Quat {
        Quat(x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
             y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
             z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
             w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
    }
    public func rotate(_ v: Vec3) -> Vec3 {
        let r = self * Quat(x: v.x, y: v.y, z: v.z, w: 0) * conjugate
        return Vec3(r.x, r.y, r.z)
    }
    /// Spherical interpolation along the shortest arc.
    public func slerp(_ to: Quat, _ t: Double) -> Quat {
        var b = to, d = x * b.x + y * b.y + z * b.z + w * b.w
        if d < 0 { b = Quat(x: -b.x, y: -b.y, z: -b.z, w: -b.w); d = -d }
        if d > 0.9995 {
            return Quat(x: x + (b.x - x) * t, y: y + (b.y - y) * t, z: z + (b.z - z) * t, w: w + (b.w - w) * t).normalized
        }
        let theta = acos(d), s = sin(theta)
        let wa = sin((1 - t) * theta) / s, wb = sin(t * theta) / s
        return Quat(x: x * wa + b.x * wb, y: y * wa + b.y * wb, z: z * wa + b.z * wb, w: w * wa + b.w * wb)
    }
    public var matrix: Mat4 { Mat4.rotation(self) }
}
