# API contract: R02-G05-03

```swift
// ColorfallCanyonsCore additions (host-testable)
public enum ColorfallCanyonsPalette { public static let night, sandstone, rock, pearl, cyan, coral, yellow: SIMD3<Double>
    public static func colour(_ color: ColorfallCanyonsColor) -> SIMD3<Double>
    public static func fluid(_ masses: [Int]) -> SIMD3<Double> }         // mass-weighted mix; night for an empty cell
public enum ColorfallCanyonsPattern: Int, Sendable, CaseIterable { case stripes, dots, chevrons
    public static func of(_ color: ColorfallCanyonsColor) -> ColorfallCanyonsPattern }
public struct ColorfallCanyonsTier: Sendable, Equatable { public let name: String; public let subdivision: Int
    public let flowBands: Int; public let glowShells: Int; public static let all: [ColorfallCanyonsTier]   // level-0 … level-2
    public static func of(_ index: Int) -> ColorfallCanyonsTier }
public struct ColorfallCanyonsSceneSnapshot: Sendable, Equatable { public let columns, rows: Int; public let heights: [Int]
    public let grounds: [ColorfallCanyonsGround]; public let springs: [ColorfallCanyonsSceneSnapshot.Spring]
    public let basins: [ColorfallCanyonsBasin]; public let masses: [[Int]]; public let downhill: [Int?]
    public let stage: ColorfallCanyonsStage; public let failure: ColorfallCanyonsFailure?; public let tick: Int
    public let tickLimit: Int; public let remaining: Int; public let levelNumber: Int; public let time: Double
    public init(play: ColorfallCanyonsPlay, levelNumber: Int, time: Double) }
public struct ColorfallCanyonsCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum ColorfallCanyonsSceneGeometry {
    public static func cellSize(_ snapshot: ColorfallCanyonsSceneSnapshot) -> Double      // 2 / max(columns, rows)
    public static func cellTop(_ cell: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double>
    public static func terrainMesh(_ snapshot: ColorfallCanyonsSceneSnapshot, tier: ColorfallCanyonsTier) throws -> Mesh
    public static func fluidMesh(_ snapshot: ColorfallCanyonsSceneSnapshot, tier: ColorfallCanyonsTier) throws -> Mesh
    public static func featureMesh(_ snapshot: ColorfallCanyonsSceneSnapshot, tier: ColorfallCanyonsTier) throws -> Mesh   // springs, basins, drains
    public static func emitterTop(_ spring: Int, _ snapshot: ColorfallCanyonsSceneSnapshot) -> SIMD3<Double>
    public static func camera(_ snapshot: ColorfallCanyonsSceneSnapshot, aspect: Double) -> ColorfallCanyonsCamera
    public static func project(_ point: SIMD3<Double>, camera: ColorfallCanyonsCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
}
public enum ColorfallCanyonsShaders { terrainVertex, terrainFragment, fluidVertex, fluidFragment: String }   // GLSL ES 3.00
public struct ColorfallCanyonsExperienceCore: ExperienceCore { /* canyon.carve, canyon.valve, time.step, play.undo,
    play.redo, level.next */ public func snapshot(time: Double) -> ColorfallCanyonsSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension ColorfallCanyonsExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// ColorfallCanyonsExperience (iOS): ColorfallCanyonsExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// ColorfallCanyonsCanyonScene, ColorfallCanyonsControls.
```
