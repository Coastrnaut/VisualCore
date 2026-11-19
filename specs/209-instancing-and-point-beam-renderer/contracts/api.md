# Contract: public API (R02-F09)

VisualCoreScenes (pure): `public enum InstanceOrder { static func backToFront(depths: [Double]) throws(MeshError) -> [Int] }`;
`public enum BeamProfile { static func falloff(_ r: Double) -> Double; static func distanceToSegment(point: Vec3, a: Vec3, b: Vec3) -> Double; static func coverage(point: Vec3, a: Vec3, b: Vec3, width: Double) -> Double }`.

VisualCoreRendering:
- `public struct MeshInstance: Sendable, Equatable { public var model: Mat4; public var color: Vec4 }`
- `@MainActor public final class InstancedMeshRenderer { public static let maxInstances = 16_384; public var lightDirection: Vec3; public var ambient: Double; public init(mesh: Mesh, registry: ResourceRegistry) throws; public func draw(_ instances: [MeshInstance], view: Mat4, projection: Mat4, fog: MeshFog?, translucent: Bool = false) throws; public func release() }`
- `public struct BeamInstance: Sendable, Equatable { public var a: Vec3; public var b: Vec3; public var width: Double; public var color: Vec4 }`
- `public enum BeamBlend: Sendable { case premultiplied, additive }`
- `@MainActor public final class BeamRenderer { public static let maxBeams = 65_536; public init(registry: ResourceRegistry) throws; public func draw(_ beams: [BeamInstance], view: Mat4, projection: Mat4, blend: BeamBlend = .premultiplied) throws; public func release() }`
- `public enum InstancingError: Error, Equatable { case tooMany(count: Int, limit: Int), notFinite(index: Int), badWidth(index: Int) }`
