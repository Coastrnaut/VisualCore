# Contract: public API added to VisualCoreScenes (R02-F05)

```swift
public struct MeshBudget: Sendable, Equatable { public var maxVertices: Int; public var maxIndices: Int
  public static let `default`: MeshBudget; public init(maxVertices: Int, maxIndices: Int) }
public enum MeshError: Error, Sendable, Equatable { case budget(vertices: Int, indices: Int, budget: MeshBudget); case invalidInput(String) }
public struct MeshBuilder: Sendable {
  public init(budget: MeshBudget = .default, weldTolerance: Double = 1e-9, weldPositionsOnly: Bool = false)
  public mutating func vertex(_ position: Vec3, normal: Vec3, uv: Vec2) throws(MeshError) -> UInt32
  public mutating func triangle(_ a: UInt32, _ b: UInt32, _ c: UInt32) throws(MeshError)
  public let budget: MeshBudget; public let weldTolerance: Double; public let weldPositionsOnly: Bool
  public var vertexCount: Int { get }; public var indexCount: Int { get }
  public func build() -> Mesh }
extension Mesh {
  public static func surface(columns: Int, rows: Int, closedU: Bool, closedV: Bool, budget: MeshBudget = .default,
                             _ point: (Double, Double) -> Vec3) throws(MeshError) -> Mesh
  public static func revolution(profile: [Vec2], segments: Int, budget: MeshBudget = .default) throws(MeshError) -> Mesh
  public static func extrusion(outline: [Vec2], depth: Double, caps: Bool, budget: MeshBudget = .default) throws(MeshError) -> Mesh
  public static func tube(path: [Vec3], radius: Double, sides: Int, caps: Bool, closed: Bool,
                          budget: MeshBudget = .default) throws(MeshError) -> Mesh
  public static func bevelledBox(size: Vec3, radius: Double, segments: Int, budget: MeshBudget = .default) throws(MeshError) -> Mesh
  public func withSmoothNormals(creaseAngle: Double) -> Mesh
  public func withFlatNormals() -> Mesh
  public var bounds: MeshBounds { get }
  public var digest: String { get }
  public func validate(requireClosed: Bool = false, budget: MeshBudget = .default) -> MeshReport }
public enum MeshBounds: Sendable, Equatable { case empty; case box(min: Vec3, max: Vec3)
  public var center: Vec3? { get }; public var radius: Double? { get }; public func contains(_ p: Vec3, tolerance: Double) -> Bool }
public struct MeshProblem: Sendable, Equatable, Codable { public enum Kind: String, Sendable, Codable, CaseIterable { … }
  public var kind: Kind; public var triangle: Int?; public var vertex: Int?; public var edge: [UInt32]? }
public struct MeshSummary: Sendable, Equatable, Codable { public var vertices: Int; public var triangles: Int
  public var boundaryEdges: Int; public var isClosed: Bool; public var boundsMin: Vec3?; public var boundsMax: Vec3?
  public var volume: Double? }
public struct MeshReport: Sendable, Equatable, Codable, CustomStringConvertible {
  public static let problemLimit = 100; public var problems: [MeshProblem]; public var moreProblems: Int
  public var summary: MeshSummary; public var isValid: Bool { get } }
```

Exact names may change during implementation only through the API baseline update; tests use the names above.
