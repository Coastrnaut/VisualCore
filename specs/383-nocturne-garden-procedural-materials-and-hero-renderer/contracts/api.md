# API contract: R02-G09-03

```swift
// NocturneGardenCore additions (host-testable)
public enum NocturneGardenPalette { public static let ground, mist, mistHighlight, shadow, gold, coral, leak, body, glow,
    lantern, spent, unspent: SIMD3<Double> }
public struct NocturneGardenTier: Sendable, Equatable { public let name: String; public let index: Int
    public let mistLayers: Int; public let stemDepth: Int; public let feather: Double; public let glowShells: Int
    public static let all: [NocturneGardenTier]   // level-0 … level-2
    public static func of(_ index: Int) -> NocturneGardenTier }
public struct NocturneGardenSceneSnapshot: Sendable, Equatable {
    public let width: Int; public let height: Int; public let target: [Int]; public let forbidden: [Int]
    public let shadow: [Int]; public let leaking: [Int]; public let blooms: [NocturneGardenBloom]; public let sun: Int
    public let stage: NocturneGardenStage; public let failure: NocturneGardenFailure?; public let moves: Int
    public let budget: Int; public let levelNumber: Int; public let time: Double
    public init(play: NocturneGardenPlay, levelNumber: Int, time: Double) }
public struct NocturneGardenCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum NocturneGardenSceneGeometry {
    public static func cellSize(_ snapshot: NocturneGardenSceneSnapshot) -> Double                       // 2 / W
    public static func cellCentre(_ cell: Int, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double>
    public static func gaugeBar(_ index: Int, _ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double>
    public static func lantern(_ snapshot: NocturneGardenSceneSnapshot) -> SIMD3<Double>
    public static func bloomBox(_ bloom: Int, _ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier) -> (min: SIMD3<Double>, max: SIMD3<Double>)
    public static func gardenMesh(_ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier, reduceMotion: Bool) throws -> Mesh
    public static func glowMesh(_ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier) throws -> Mesh   // shells over the heads and the lantern
    public static func camera(_ snapshot: NocturneGardenSceneSnapshot, aspect: Double) -> NocturneGardenCamera
    public static func project(_ point: SIMD3<Double>, camera: NocturneGardenCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func gardenPart(_:tier:), glowPart(_:tier:) throws -> NocturneGardenColouredMesh   // fallback colours
}
public enum NocturneGardenShaders { gardenVertex, gardenFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: NocturneGardenTier) -> Double }
public struct NocturneGardenExperienceCore: ExperienceCore { /* bloom.plant, bloom.move, bloom.resize, bloom.remove,
    sun.set, play.undo, play.redo, level.next */
    public func snapshot(time: Double) -> NocturneGardenSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension NocturneGardenExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// NocturneGardenExperience (iOS): NocturneGardenExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// NocturneGardenGardenScene, NocturneGardenControls.
```
