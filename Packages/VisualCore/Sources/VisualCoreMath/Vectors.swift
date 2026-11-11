// Vectors.swift — Double-precision vectors for coordinates, cameras and simulation (feature 006 T-F502;
// FR-F501, FR-F509; contract specs/006-input-animation-scenes/contracts/interaction-api.md).
// Double keeps coordinate round trips within 0.001 pt at any zoom (research R1); GL code converts to Float.

/// A 2D vector or point.
public struct Vec2: Sendable, Equatable, Hashable, Codable {
    /// Horizontal (x) and vertical (y) components.
    public var x: Double, y: Double
    /// Creates a vector from its x and y components.
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    /// The zero vector (origin).
    public static let zero = Vec2(0, 0)
    /// Component-wise sum.
    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    /// Component-wise difference `a - b`.
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    /// Negation of every component.
    public static prefix func - (a: Vec2) -> Vec2 { Vec2(-a.x, -a.y) }
    /// Multiplies every component by the scalar `s`.
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }
    /// Multiplies every component by the scalar `s`.
    public static func * (s: Double, a: Vec2) -> Vec2 { Vec2(a.x * s, a.y * s) }
    /// Divides every component by the scalar `s` (no zero check).
    public static func / (a: Vec2, s: Double) -> Vec2 { Vec2(a.x / s, a.y / s) }
    /// Adds `b` to `a` in place.
    public static func += (a: inout Vec2, b: Vec2) { a = a + b }
    /// Subtracts `b` from `a` in place.
    public static func -= (a: inout Vec2, b: Vec2) { a = a - b }
    /// Component-wise product.
    public func scaled(by s: Vec2) -> Vec2 { Vec2(x * s.x, y * s.y) }
    /// Dot product.
    public func dot(_ b: Vec2) -> Double { x * b.x + y * b.y }
    /// z of the 3D cross product (signed parallelogram area).
    public func cross(_ b: Vec2) -> Double { x * b.y - y * b.x }
    /// Euclidean length.
    public var length: Double { (x * x + y * y).squareRoot() }
    /// Unit-length copy, or `.zero` when the length is 0.
    public var normalized: Vec2 { let l = length; return l > 0 ? self / l : .zero }
    /// Euclidean distance to `b`.
    public func distance(to b: Vec2) -> Double { (self - b).length }
    /// True when both components are finite (no NaN or infinity).
    public var isFinite: Bool { x.isFinite && y.isFinite }
}

/// A 3D vector or point.
public struct Vec3: Sendable, Equatable, Hashable, Codable {
    /// Cartesian components.
    public var x: Double, y: Double, z: Double
    /// Creates a vector from its x, y and z components.
    public init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    /// The zero vector (origin).
    public static let zero = Vec3(0, 0, 0)
    /// Component-wise sum.
    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    /// Component-wise difference `a - b`.
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    /// Negation of every component.
    public static prefix func - (a: Vec3) -> Vec3 { Vec3(-a.x, -a.y, -a.z) }
    /// Multiplies every component by the scalar `s`.
    public static func * (a: Vec3, s: Double) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    /// Multiplies every component by the scalar `s`.
    public static func * (s: Double, a: Vec3) -> Vec3 { a * s }
    /// Divides every component by the scalar `s` (no zero check).
    public static func / (a: Vec3, s: Double) -> Vec3 { Vec3(a.x / s, a.y / s, a.z / s) }
    /// Adds `b` to `a` in place.
    public static func += (a: inout Vec3, b: Vec3) { a = a + b }
    /// Dot product.
    public func dot(_ b: Vec3) -> Double { x * b.x + y * b.y + z * b.z }
    /// Right-handed cross product `self × b`.
    public func cross(_ b: Vec3) -> Vec3 { Vec3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x) }
    /// Euclidean length.
    public var length: Double { dot(self).squareRoot() }
    /// Unit-length copy, or `.zero` when the length is 0.
    public var normalized: Vec3 { let l = length; return l > 0 ? self / l : .zero }
    /// True when all three components are finite (no NaN or infinity).
    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

/// A 4D vector (homogeneous point or RGBA color).
public struct Vec4: Sendable, Equatable, Hashable, Codable {
    /// Components; for colors x, y, z, w are red, green, blue, alpha.
    public var x: Double, y: Double, z: Double, w: Double
    /// Creates a vector from its four components.
    public init(_ x: Double, _ y: Double, _ z: Double, _ w: Double) { self.x = x; self.y = y; self.z = z; self.w = w }
    /// Extends a 3D vector with `w` (1 for a point, 0 for a direction).
    public init(_ v: Vec3, _ w: Double) { self.init(v.x, v.y, v.z, w) }
    /// The zero vector.
    public static let zero = Vec4(0, 0, 0, 0)
    /// Component-wise sum.
    public static func + (a: Vec4, b: Vec4) -> Vec4 { Vec4(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w) }
    /// Component-wise difference `a - b`.
    public static func - (a: Vec4, b: Vec4) -> Vec4 { Vec4(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w) }
    /// Multiplies every component by the scalar `s`.
    public static func * (a: Vec4, s: Double) -> Vec4 { Vec4(a.x * s, a.y * s, a.z * s, a.w * s) }
    /// Four-component dot product.
    public func dot(_ b: Vec4) -> Double { x * b.x + y * b.y + z * b.z + w * b.w }
    /// The first three components, dropping `w` (no perspective divide).
    public var xyz: Vec3 { Vec3(x, y, z) }
    /// Linear interpolation (colors over particle life).
    public func mix(_ b: Vec4, _ t: Double) -> Vec4 { self + (b - self) * t }
}
