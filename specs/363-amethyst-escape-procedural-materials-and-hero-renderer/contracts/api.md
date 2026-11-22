# API contract: R02-G07-03

```swift
// AmethystEscapeCore additions (host-testable)
public enum AmethystEscapePalette { public static let backdrop, amethyst, highlight, platinum, blocked, pearl, exit, amber: SIMD3<Double> }
public struct AmethystEscapeTier: Sendable, Equatable { public let name: String; public let bevelSegments: Int
    public let highlightLayers: Int; public let glowShells: Int; public static let all: [AmethystEscapeTier]   // level-0 … level-2
    public static func of(_ index: Int) -> AmethystEscapeTier }
public struct AmethystEscapeSceneSnapshot: Sendable, Equatable { public let sectors: Int
    public let shells: [AmethystEscapeSceneSnapshot.Shell]   // apertures, walls, blocked, offset
    public let pearl: AmethystEscapePocket; public let exitGap: Int; public let stage: AmethystEscapeStage
    public let failure: AmethystEscapeFailure?; public let moves: Int; public let budget: Int
    public let levelNumber: Int; public let time: Double
    public init(play: AmethystEscapePlay, levelNumber: Int, time: Double) }
public struct AmethystEscapeCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum AmethystEscapeSceneGeometry {
    public static func shellWidth(_ snapshot: AmethystEscapeSceneSnapshot) -> Double            // 0.8 / shells
    public static func shellHeight(_ shell: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> Double
    public static func worldSector(shell: Int, sector: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> Int
    public static func wedgeTopCentre(shell: Int, sector: Int, _ snapshot: AmethystEscapeSceneSnapshot) -> SIMD3<Double>
    public static func pearlCentre(_ snapshot: AmethystEscapeSceneSnapshot) -> SIMD3<Double>
    public static func exitCentre(_ snapshot: AmethystEscapeSceneSnapshot) -> SIMD3<Double>
    public static func crystalMesh(_ snapshot: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier) throws -> Mesh   // backdrop, wedges, fins, marks
    public static func glowMesh(_ snapshot: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier) throws -> Mesh      // pearl, exit arrow, glow shells
    public static func camera(_ snapshot: AmethystEscapeSceneSnapshot, aspect: Double) -> AmethystEscapeCamera
    public static func project(_ point: SIMD3<Double>, camera: AmethystEscapeCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
}
public enum AmethystEscapeShaders { crystalVertex, crystalFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: AmethystEscapeTier) -> Double }
public struct AmethystEscapeExperienceCore: ExperienceCore { /* shell.rotate, pearl.advance, play.undo, play.redo,
    level.next */ public func snapshot(time: Double) -> AmethystEscapeSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension AmethystEscapeExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// AmethystEscapeExperience (iOS): AmethystEscapeExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// AmethystEscapeCrystalScene, AmethystEscapeControls.
```
