# API contract: R02-G06-03

```swift
// ChronoConstellatorCore additions (host-testable)
public enum ChronoConstellatorPalette { public static let field, grid, silver, star, rose, amber: SIMD3<Double> }
public struct ChronoConstellatorTier: Sendable, Equatable { public let name: String; public let ribbonTicks: Int
    public let segments: Int; public let glowShells: Int; public static let all: [ChronoConstellatorTier]   // level-0 … level-2
    public static func of(_ index: Int) -> ChronoConstellatorTier }
public struct ChronoConstellatorSceneSnapshot: Sendable, Equatable { public let columns, rows: Int
    public let stars: [ChronoConstellatorSceneSnapshot.Star]   // loop, target, cell, history (last 24 ticks, oldest first)
    public let phases: [Int]; public let holds: [ChronoConstellatorHold]; public let stage: ChronoConstellatorStage
    public let failure: ChronoConstellatorFailure?; public let tick: Int; public let tickLimit: Int; public let remaining: Int
    public let levelNumber: Int; public let time: Double
    public init(play: ChronoConstellatorPlay, levelNumber: Int, time: Double) }
public struct ChronoConstellatorCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum ChronoConstellatorSceneGeometry {
    public static func cellSize(_ snapshot: ChronoConstellatorSceneSnapshot) -> Double     // 2 / max(columns, rows)
    public static func cellCentre(_ cell: Int, _ snapshot: ChronoConstellatorSceneSnapshot) -> SIMD3<Double>   // y = 0
    public static func starCentre(_ star: Int, _ snapshot: ChronoConstellatorSceneSnapshot) -> SIMD3<Double>   // y = 0.25·u
    public static func fieldMesh(_ snapshot: ChronoConstellatorSceneSnapshot, tier: ChronoConstellatorTier) throws -> Mesh   // field, grid, tracks
    public static func starMesh(_ snapshot: ChronoConstellatorSceneSnapshot, tier: ChronoConstellatorTier) throws -> Mesh    // nodes, rings, marks
    public static func ribbonMesh(_ snapshot: ChronoConstellatorSceneSnapshot, tier: ChronoConstellatorTier) throws -> Mesh  // history ribbons
    public static func camera(_ snapshot: ChronoConstellatorSceneSnapshot, aspect: Double) -> ChronoConstellatorCamera
    public static func project(_ point: SIMD3<Double>, camera: ChronoConstellatorCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
}
public enum ChronoConstellatorShaders { fieldVertex, fieldFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: ChronoConstellatorTier) -> Double }
public struct ChronoConstellatorExperienceCore: ExperienceCore { /* star.phase, star.hold, star.release, time.step,
    time.rewind, play.undo, play.redo, level.next */ public func snapshot(time: Double) -> ChronoConstellatorSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension ChronoConstellatorExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// ChronoConstellatorExperience (iOS): ChronoConstellatorExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// ChronoConstellatorSkyScene, ChronoConstellatorControls.
```
