# API contract: R02-G13-03

```swift
// AcousticConstellatorCore additions (host-testable)
public enum AcousticConstellatorPalette { public static let sky, star, hand, silver, teal, guide, broken, coherenceLit,
    coherenceUnlit, thresholdMark, holdLit, holdUnlit, movesLit, movesUnlit, shell, glow: SIMD3<Double>
    public static let hex: [String] }
public struct AcousticConstellatorTier: Sendable, Equatable { public let name: String; public let index: Int
    public let pulse: Bool; public let waveShells: Int; public let glowShells: Int
    public static let all: [AcousticConstellatorTier]   // level-0 … level-2
    public static func of(_ index: Int) -> AcousticConstellatorTier }
public struct AcousticConstellatorSceneSnapshot: Sendable, Equatable {
    public let stars: [AcousticConstellatorStar]; public let links: [AcousticConstellatorLink]
    public let symbol: [AcousticConstellatorLink]; public let phases: [Int]          // starting phases
    public let report: AcousticConstellatorListen; public let threshold: Int; public let hold: Int; public let window: Int
    public let stage: AcousticConstellatorStage; public let failure: AcousticConstellatorFailure?
    public let actionsLeft: Int; public let budget: Int; public let levelNumber: Int; public let time: Double
    public var shownTick: Int { get }   // one tick per 0.25 s, holds the last tick 1 s, loops; 0 at time 0
    public init(play: AcousticConstellatorPlay, levelNumber: Int, time: Double) }
public struct AcousticConstellatorCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum AcousticConstellatorSceneGeometry {
    public static func starCentre(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double>
    public static func linkCheckPoint(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double>
    public static func coherenceBar(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double>
    public static func holdPip(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double>
    public static func movesBar(_ index: Int, _ snapshot: AcousticConstellatorSceneSnapshot) -> SIMD3<Double>
    public static func constellationMesh(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier, reduceMotion: Bool) throws -> Mesh
    public static func glowMesh(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier) throws -> Mesh
    public static func camera(_ snapshot: AcousticConstellatorSceneSnapshot, aspect: Double) -> AcousticConstellatorCamera
    public static func project(_ point: SIMD3<Double>, camera: AcousticConstellatorCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func constellationPart(_:tier:), glowPart(_:tier:) throws -> AcousticConstellatorColouredMesh   // fallback colours
}
public enum AcousticConstellatorShaders { constellationVertex, constellationFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: AcousticConstellatorTier) -> Double }
public struct AcousticConstellatorExperienceCore: ExperienceCore { /* link.add, link.remove, star.nudge, constellation.listen, play.undo, play.redo, level.next */
    public func snapshot(time: Double) -> AcousticConstellatorSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension AcousticConstellatorExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// AcousticConstellatorExperience (iOS): AcousticConstellatorExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// AcousticConstellatorConstellationScene, AcousticConstellatorControls.
```
