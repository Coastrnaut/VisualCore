# API contract: R02-G16-03

```swift
// StarlitCartoucheCore additions (host-testable)
public enum StarlitCartouchePalette { public static let night, nightTop, speck, pearl, pearlShade, corridor, symbolDash,
    trail, trailGlow, ship, shipGlow, beacon, chosen, hazardActive, hazardIdle, actionsLit, actionsUnlit, beatTrack,
    waitLit, waitUnlit, broken, glow: SIMD3<Double>
    public static let hex: [String] }
public struct StarlitCartoucheTier: Sendable, Equatable { public let name: String; public let index: Int
    public let longitudes: Int; public let latitudes: Int   // 0 for flat discs
    public let ghosts: Int; public let glowShells: Int
    public static let all: [StarlitCartoucheTier]   // level-0 … level-2
    public static func of(_ index: Int) -> StarlitCartoucheTier }
public struct StarlitCartoucheSceneSnapshot: Sendable, Equatable {
    public let stars: [StarlitCartoucheStar]; public let positions: [StarlitCartoucheVector]   // at the beat
    public let corridors: [StarlitCartoucheCorridor]; public let hazards: [StarlitCartoucheHazard]; public let active: [Bool]
    public let legs: [StarlitCartoucheLeg]; public let departures: [StarlitCartoucheVector]; public let arrivals: [StarlitCartoucheVector]
    public let drawn: [Int]; public let symbol: [Int]; public let star: Int; public let beat: Int
    public let beacon: Int; public let deadline: Int; public let chosenStar: Int; public let chosenWait: Int
    public let report: StarlitCartoucheRouteReport; public let stage: StarlitCartoucheStage
    public let failure: StarlitCartoucheFailure?; public let failedLeg: StarlitCartoucheLeg?   // from the last record
    public let actionsLeft: Int; public let budget: Int
    public let levelNumber: Int; public let time: Double
    public init(play: StarlitCartouchePlay, chosenStar: Int, chosenWait: Int, levelNumber: Int, time: Double) }
public struct StarlitCartoucheCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum StarlitCartoucheSceneGeometry {
    public static func scale(_ snapshot: StarlitCartoucheSceneSnapshot) -> Double
    public static func world(_ position: StarlitCartoucheVector, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double>
    public static func starCentre(_ index: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double>
    public static func shipCentre(_ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double>
    public static func trailMidpoint(_ leg: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double>
    public static func cartoucheCentre() -> SIMD3<Double>
    public static func actionsBar(_ index: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double>
    public static func paintOrder(_ snapshot: StarlitCartoucheSceneSnapshot, camera: StarlitCartoucheCamera) -> [StarlitCartoucheElement]
    public static func chartMesh(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier, glide: Double) throws -> Mesh
    public static func glowMesh(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier) throws -> Mesh
    public static func camera(_ snapshot: StarlitCartoucheSceneSnapshot, aspect: Double) -> StarlitCartoucheCamera
    public static func project(_ point: SIMD3<Double>, camera: StarlitCartoucheCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func chartPart(_:tier:), glowPart(_:tier:) throws -> StarlitCartoucheColouredMesh   // fallback colours
}
public enum StarlitCartoucheShaders { chartVertex, chartFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: StarlitCartoucheTier) -> Double
    public static func firmamentAngle(time: Double, reduceMotion: Bool) -> Double }   // 0.02 rad/s, 0 with Reduce Motion
public struct StarlitCartoucheExperienceCore: ExperienceCore { /* route.fly, play.undo, play.redo, level.next, route.choose */
    public func snapshot(time: Double) -> StarlitCartoucheSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension StarlitCartoucheExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// StarlitCartoucheExperience (iOS): StarlitCartoucheExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// StarlitCartoucheChartScene, StarlitCartoucheControls.
```
