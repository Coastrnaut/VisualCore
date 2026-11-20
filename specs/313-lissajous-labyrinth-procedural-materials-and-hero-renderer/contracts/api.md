# API contract: R02-G02-03 (LissajousLabyrinthCore additions)

```swift
public struct LissajousLabyrinthTier: Sendable, Equatable { public let index, stride, glowPasses, trail: Int
    public static let all: [LissajousLabyrinthTier]; public static func of(_ hostTier: Int) -> Self }
public enum LissajousLabyrinthPalette { public static let night, cobalt, violet, copper: SIMD3<Double> }
public struct LissajousLabyrinthSceneSnapshot: Sendable, Equatable {
    public init(play: LissajousLabyrinthPlay, time: Double)
    public let dials: LissajousLabyrinthDials; public let level: LissajousLabyrinthLevel; public let stage: LissajousLabyrinthStage
    public let verdict: LissajousLabyrinthVerdict; public let visits: [Int]; public let time: Double
    public var headTick: Int }
public enum LissajousLabyrinthSceneGeometry {
    public static let unitsPerKernel: Double   // 1/1,024
    public static func path(_ s: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier) -> [Vec3]
    public static func camera(aspect: Double, snapshot: LissajousLabyrinthSceneSnapshot) -> (eye: Vec3, target: Vec3, fovY: Double)
    public static func project(_ p: Vec3, aspect: Double, snapshot:, width: Int, height: Int) -> Vec2?
    public static func threadMesh(_:tier:) throws -> Mesh; ringMesh; sphereMesh }
public enum LissajousLabyrinthShaders { threadVertex, threadFragment, solidVertex, solidFragment }
public struct LissajousLabyrinthExperienceCore: ExperienceCore { /* dial.set [0…3, 0…15], play.undo, play.redo, level.next */ }
```
