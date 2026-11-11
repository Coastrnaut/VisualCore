// Vectors.swift — Double-precision vectors for coordinates, cameras and simulation (feature 006 T-F502;
// FR-F501, FR-F509; contract specs/006-input-animation-scenes/contracts/interaction-api.md).
// Double keeps coordinate round trips within 0.001 pt at any zoom (research R1); GL code converts to Float.

/// A 2D vector or point.
public struct Vec2: Sendable, Equatable, Hashable, Codable {
    public var x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    public static let zero = Vec2(0, 0)
    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static func * (s: Double, a: Vec2) -> Vec2 { Vec2(a.x * s, a.y * s) }
    public static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }
    /// Component-wise product.
    public func scaled(by s: Vec2) -> Vec2 { Vec2(x * s.x, y * s.y) }
    public func dot(_ b: Vec2) -> Double { x * b.x + y * b.y }
    /// z of the 3D cross product (signed parallelogram area).
    public func cross(_ b: Vec2) -> Double { x * b.y - y * b.x }
    public var length: Double { (x * x + y * y).squareRoot() }
    public var normalized: Vec2 { let l = length; return l > 0 ? self / l : .zero }
    public func distance(to b: Vec2) -> Double { (self - b).length }
    public var isFinite: Bool { x.isFinite && y.isFinite }
}

/// A 3D vector or point.
public struct Vec3: Sendable, Equatable, Hashable, Codable {
    public var x: Double, y: Double, z: Double
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    public static let zero = Vec3(0, 0, 0)
    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static prefix func - (a: Vec3) -> Vec3 { Vec3(-a.x, -a.y, -a.z) }
    public static func * (a: Vec3, s: Double) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public static func * (s: Double, a: Vec3) -> Vec3 { a * s }
    public static func / (a: Vec3, s: Double) -> Vec3 { Vec3(a.x / s, a.y / s, a.z / s) }
    public static func += (a: inout Vec3, b: Vec3) { a = a + b }
    public func dot(_ b: Vec3) -> Double { x * b.x + y * b.y + z * b.z }
    public func cross(_ b: Vec3) -> Vec3 { Vec3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
    public var length: Double { dot(self).squareRoot() }
    public var normalized: Vec3 { let l = length; return l > 0 ? self / l : .zero }
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

/// A 4D vector (homogeneous point or RGBA color).
public struct Vec4: Sendable, Equatable, Hashable, Codable {
    public var x: Double, y: Double, z: Double, w: Double
    public init(_ x: Double, _ y: Double, _ z: Double, _ w: Double) { self.x = x; self.y = y; self.z = z; self.w = w }
    public init(_ v: Vec3, _ w: Double) { self.init(v.x, v.y, v.z, w) }
    public static let zero = Vec4(0, 0, 0, 0)
    public static func + (a: Vec4, b: Vec4) -> Vec4 { Vec4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w) }
    public static func - (a: Vec4, b: Vec4) -> Vec4 { Vec4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w) }
    public static func * (a: Vec4, s: Double) -> Vec4 { Vec4(a.x * s, a.y * s, a.z * s, a.w * s) }
    public func dot(_ b: Vec4) -> Double { x * b.x + y * b.y + z * b.z + w * b.w }
    public var xyz: Vec3 { Vec3(x, y, z) }
    /// Linear interpolation (colors over particle life).
    public func mix(_ b: Vec4, _ t: Double) -> Vec4 { self + (b - self) * t }
}
