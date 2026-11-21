# API contract: R02-G04-03

```swift
// HueCompassCore additions (host-testable)
public enum HueCompassPalette { public static let night, pearl, sapphire, ember: SIMD3<Double>
    public static func band(_ band: Int) -> SIMD3<Double> }          // hue band/24, saturation 0.85, value 1.0
public struct HueCompassGlyph: Sendable, Equatable { public let shape: Int; public let marks: Int
    public static func of(band: Int) -> HueCompassGlyph }
public struct HueCompassTier: Sendable, Equatable { public let name: String; public let facets: Int
    public let fogLayers: Int; public let glowShells: Int; public static let all: [HueCompassTier] /* level-0 … level-2 */ }
public struct HueCompassSceneSnapshot: Sendable, Equatable { public let bearing: Int; public let offset: Int
    public let fog: [Int]; public let bearingTolerance: Int; public let bandTolerance: Int; public let clues: [HueCompassClue]
    public let selection: HueCompassSelection?; public let stage: HueCompassStage; public let target: Int?
    public let time: Double; public let levelNumber: Int }
public struct HueCompassCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum HueCompassSceneGeometry {
    public static func direction(_ bearing: Int) -> SIMD3<Double>        // (cos, sin, 0) of 2π·bearing/96
    public static func needleMesh(_ snapshot: HueCompassSceneSnapshot, tier: HueCompassTier) throws -> Mesh
    public static func wheelMesh(_ snapshot: HueCompassSceneSnapshot, tier: HueCompassTier) throws -> Mesh   // ticks, bands, glyphs
    public static func fogMesh(_ snapshot: HueCompassSceneSnapshot, tier: HueCompassTier) throws -> Mesh
    public static func markMesh(_ snapshot: HueCompassSceneSnapshot) throws -> Mesh   // probes, selection, target
    public static func camera(aspect: Double) -> HueCompassCamera
    public static func project(_ point: SIMD3<Double>, camera: HueCompassCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
}
public enum HueCompassShaders { glassVertex, glassFragment, solidVertex, solidFragment: String }   // GLSL ES 3.00
public struct HueCompassExperienceCore: ExperienceCore { /* compass.turn, compass.probe, compass.select, play.undo,
    play.redo, level.next */ public func snapshot(time: Double) -> HueCompassSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension HueCompassExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// HueCompassExperience (iOS): HueCompassExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// HueCompassCompassScene, HueCompassControls.
```
