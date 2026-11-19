# Contract: public API (R02-F08), VisualCoreScenes

- `public protocol ParametricCurve: Sendable { var segmentCount: Int { get }; var isClosed: Bool { get }; func position(segment: Int, t: Double) -> Vec3; func derivative(segment: Int, t: Double) -> Vec3 }`
- `public struct CubicBezierChain: ParametricCurve, Equatable { public init(points: [Vec3], closed: Bool) throws(MeshError) }`
- `public struct CatmullRomSpline: ParametricCurve, Equatable { public init(points: [Vec3], closed: Bool) throws(MeshError) }`
- `public struct CurveSamples: Sendable, Equatable { positions, tangents, arcLengths, isClosed; var length: Double }`
- `public enum CurveSampler { public static let maxSamples = 65_536; public static func sample(_ curve: some ParametricCurve, tolerance: Double, budget: Int = maxSamples) throws(MeshError) -> CurveSamples }`
- `public struct CurveFrame: Sendable, Equatable { position, tangent, normal, binormal }`
- `public enum CurveFrames { public static func parallelTransport(_ samples: CurveSamples, initialNormal: Vec3? = nil) throws(MeshError) -> [CurveFrame] }`
- `public enum RibbonWidth: Sendable, Equatable { case constant(Double), perSample([Double]) }`
- `extension Mesh { static func ribbon(_ samples: CurveSamples, width: RibbonWidth, repeatLength: Double = 1, initialNormal: Vec3? = nil, budget: MeshBudget = .default) throws(MeshError) -> Mesh; static func tube(samples: CurveSamples, radius: Double, sides: Int, caps: Bool, repeatLength: Double = 1, budget: MeshBudget = .default) throws(MeshError) -> Mesh; static func merged(_ meshes: [Mesh], budget: MeshBudget = .default) throws(MeshError) -> Mesh }`

## As built (T-R02F08-015, 2026-11-19)

- `CurveSamples.init(positions:closed:) throws(MeshError)` (drops collapses, computes tangents and arc lengths) is the
  only way to build samples; `CubicBezierChain.controlPoints(segment:)`, `CatmullRomSpline.neighbourhood(segment:)`,
  `CatmullRomSpline.alpha`, the stored `points` and `isClosed`; `CurveSampler.maxDepth = 20`.
- A straight segment is detected by its exact cubic control polygon lying within the tolerance of the chord.
- The sampler's budget argument is clamped to 2…65,536; a refusal is `.budget(vertices: count, indices: 0, budget:
  MeshBudget(maxVertices: limit, maxIndices: 0))`.
- `parallelTransport` returns count + 1 frames on a closed curve, the last a seam frame equal to the first.
- Ribbons and tubes are built without welding (exact vertex counts); `Mesh.merged` also refuses a part whose normal or
  texture-coordinate count differs from its position count.
