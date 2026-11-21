# API contract: R02-G03-03

```swift
// WaveKnotKeeperCore additions (host-testable)
public enum WaveKnotKeeperPalette { public static let night, pearl, sapphire, ember: SIMD3<Double> }
public struct WaveKnotKeeperTier: Sendable, Equatable { public let sides: Int; public let cornerSamples: Int
    public let glowShells: Int; public static let all: [WaveKnotKeeperTier] /* level-0 … level-2 */ }
public struct WaveKnotKeeperCrossingMark: Sendable, Equatable { public let segments: (Int, Int) as pair fields
    public let over: Int; public let x: Double; public let y: Double }
public struct WaveKnotKeeperSceneSnapshot: Sendable, Equatable { public let points: [WaveKnotKeeperPoint]
    public let gates: [WaveKnotKeeperGate]; public let target: WaveKnotKeeperTarget; public let summary: WaveKnotKeeperSummary
    public let crossings: [WaveKnotKeeperCrossingMark]; public let stage: WaveKnotKeeperStage; public let selected: Int?
    public let time: Double; public let levelNumber: Int }
public enum WaveKnotKeeperSceneGeometry {
    public static func worldPoints(_ snapshot: WaveKnotKeeperSceneSnapshot) -> [SIMD3<Double>]   // × 1/8
    public static func ropeMesh(_ snapshot: WaveKnotKeeperSceneSnapshot, tier: WaveKnotKeeperTier) throws -> Mesh
    public static func handleMesh() throws -> Mesh; public static func gateMesh(_ gate: WaveKnotKeeperGate) throws -> Mesh
    public static func camera(for snapshot: WaveKnotKeeperSceneSnapshot, aspect: Double) -> WaveKnotKeeperCamera
    public static func project(_ point: SIMD3<Double>, camera: WaveKnotKeeperCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
}
public enum WaveKnotKeeperShaders { ropeVertex, ropeFragment, solidVertex, solidFragment: String }   // GLSL ES 3.00
public struct WaveKnotKeeperExperienceCore: ExperienceCore { /* point.move, point.select, play.undo, play.redo, level.next */
    public func snapshot(time: Double) -> WaveKnotKeeperSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension WaveKnotKeeperExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// WaveKnotKeeperExperience (iOS): WaveKnotKeeperExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// WaveKnotKeeperRopeScene, WaveKnotKeeperControls.
```
