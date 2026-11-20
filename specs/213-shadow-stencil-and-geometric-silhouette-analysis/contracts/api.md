# Contract: public API (R02-F13)

VisualCoreScenes (pure):
- `public enum ShadowLight: Sendable, Equatable { case point(Vec3); case directional(Vec3); public static func directional(towards d: Vec3) throws(ShadowError) -> ShadowLight }`
- `public struct ProjectionPlane: Sendable, Equatable { public let plane: ClipPlane; public let origin: Vec3; public let u: Vec3; public let v: Vec3; public init(plane: ClipPlane); public func coordinates(of p: Vec3) -> Vec2; public func point(of q: Vec2) -> Vec3 }`
- `public enum ShadowProjector { public static let maxTriangles = 1_048_576; public static func project(_ p: Vec3, light: ShadowLight, onto: ProjectionPlane) throws(ShadowError) -> Vec2?; public static func projectTriangle(_ a: Vec3, _ b: Vec3, _ c: Vec3, light:, onto:) throws(ShadowError) -> [Vec2]; public static func project(mesh: Mesh, light:, onto:) throws(ShadowError) -> [[Vec2]]; public static func outline(of solid: ConvexSolid, light:, onto:) throws(ShadowError) -> [Vec2]; public static func matrix(light:, onto:) throws(ShadowError) -> Mat4 }`
- `public enum ConvexHull2D { public static func hull(_ points: [Vec2]) -> [Vec2]; public static func area(_ polygon: [Vec2]) -> Double }`
- `public struct CoverageMask: Sendable, Equatable { public static let maxSide = 2_048; public let min: Vec2; public let max: Vec2; public let width: Int; public let height: Int; public private(set) var words: [UInt64]; public init(min: Vec2, max: Vec2, width: Int, height: Int) throws(ShadowError); public mutating func fill(_ polygon: [Vec2]); public mutating func fill(_ polygons: [[Vec2]]); public subscript(x: Int, y: Int) -> Bool { get }; public var count: Int; public var area: Double; public var digest: UInt64; public var cellCentre(x:y:) … }`
- `public struct MaskComparison: Sendable, Equatable { public let intersection: Int; public let union: Int; public var iou: Double; public init(_ a: CoverageMask, _ b: CoverageMask) throws(ShadowError) }`
- `public struct CoverageMaskDocument: Sendable, Equatable { public static let schema = 1; public let mask: CoverageMask; public func encoded() throws -> Data; public static func decode(_ data: Data) throws(ShadowError) -> CoverageMaskDocument }`
- `public enum ShadowError: Error, Equatable, Sendable { …; public var reasonCode: String }`

VisualCoreRendering:
- `@MainActor public final class PlanarShadowRenderer { public init(mesh: Mesh, registry: ResourceRegistry) throws; public var darkness: Double (0…1, default 0.5); public func draw(model: Mat4, light: ShadowLight, plane: ProjectionPlane, view: Mat4, projection: Mat4, viewport: (width: Int, height: Int)) throws; public func release() }` — coverage pass into a pooled target, then one composite; GL state restored.
