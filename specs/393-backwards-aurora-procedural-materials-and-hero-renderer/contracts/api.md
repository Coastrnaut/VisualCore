# API contract: R02-G10-03

```swift
// BackwardsAuroraCore additions (host-testable)
public enum BackwardsAuroraPalette { public static let ground, ribbon, ribbonHighlight, glow, ghost, ring, matched, kink,
    tear, band, spent, unspent: SIMD3<Double> }
public struct BackwardsAuroraTier: Sendable, Equatable { public let name: String; public let index: Int
    public let trailingLayers: Int; public let pulses: Int; public let glowShells: Int
    public static let all: [BackwardsAuroraTier]   // level-0 … level-2
    public static func of(_ index: Int) -> BackwardsAuroraTier }
public struct BackwardsAuroraSceneSnapshot: Sendable, Equatable {
    public let samples: [Int]; public let target: [Int]; public let checkpoints: [Int]; public let matched: [Bool]
    public let bendLimit: Int; public let kinks: [Int]; public let tear: Int?
    public let sectionStart: Int; public let sectionEnd: Int   // the chosen section (presentation state)
    public let stage: BackwardsAuroraStage; public let failure: BackwardsAuroraFailure?; public let spent: Int
    public let budget: Int; public let levelNumber: Int; public let time: Double
    public init(play: BackwardsAuroraPlay, levelNumber: Int, sectionStart: Int, sectionEnd: Int, time: Double) }
public struct BackwardsAuroraCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum BackwardsAuroraSceneGeometry {
    public static func samplePoint(_ k: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double>
    public static func targetPoint(_ k: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double>
    public static func ringCentre(_ index: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double>
    public static func gaugeBar(_ index: Int, _ snapshot: BackwardsAuroraSceneSnapshot) -> SIMD3<Double>
    public static func auroraMesh(_ snapshot: BackwardsAuroraSceneSnapshot, tier: BackwardsAuroraTier, reduceMotion: Bool) throws -> Mesh
    public static func glowMesh(_ snapshot: BackwardsAuroraSceneSnapshot, tier: BackwardsAuroraTier) throws -> Mesh   // shells over the ribbon
    public static func camera(_ snapshot: BackwardsAuroraSceneSnapshot, aspect: Double) -> BackwardsAuroraCamera
    public static func project(_ point: SIMD3<Double>, camera: BackwardsAuroraCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func auroraPart(_:tier:), glowPart(_:tier:) throws -> BackwardsAuroraColouredMesh   // fallback colours
}
public enum BackwardsAuroraShaders { auroraVertex, auroraFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: BackwardsAuroraTier) -> Double }
public struct BackwardsAuroraExperienceCore: ExperienceCore { /* wave.reverse, play.undo, play.redo, level.next */
    public func snapshot(sectionStart: Int, sectionEnd: Int, time: Double) -> BackwardsAuroraSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension BackwardsAuroraExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// BackwardsAuroraExperience (iOS): BackwardsAuroraExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// BackwardsAuroraAuroraScene, BackwardsAuroraControls.
```
