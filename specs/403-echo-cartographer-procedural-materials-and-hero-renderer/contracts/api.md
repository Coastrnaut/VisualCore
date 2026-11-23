# API contract: R02-G11-03

```swift
// EchoCartographerCore additions (host-testable)
public enum EchoCartographerPalette { public static let ground, floor, wallFace, wallEdge, flare, pulse, entry, marker,
    pillar, glow, gaugeLit, gaugeUnlit: SIMD3<Double>; public static let hex: [String] }
public struct EchoCartographerTier: Sendable, Equatable { public let name: String; public let index: Int
    public let rings: Bool; public let flareTrails: Bool; public let glowShells: Int
    public static let all: [EchoCartographerTier]   // level-0 … level-2
    public static func of(_ index: Int) -> EchoCartographerTier }
public struct EchoCartographerSceneSnapshot: Sendable, Equatable {
    public let width: Int; public let height: Int; public let knowledge: [EchoCartographerKnown]
    public let entry: EchoCartographerCell; public let markers: [EchoCartographerCell]; public let located: [EchoCartographerCell]
    public let lastEcho: EchoCartographerEcho?; public let stage: EchoCartographerStage
    public let failure: EchoCartographerFailure?; public let energy: Int; public let budget: Int
    public let levelNumber: Int; public let time: Double
    public init(play: EchoCartographerPlay, levelNumber: Int, time: Double) }
public struct EchoCartographerCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum EchoCartographerSceneGeometry {
    public static func cellCentre(_ cell: EchoCartographerCell, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double>
    public static func wallTop(_ cell: EchoCartographerCell, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double>
    public static func gaugeBar(_ index: Int, _ snapshot: EchoCartographerSceneSnapshot) -> SIMD3<Double>
    public static func chamberMesh(_ snapshot: EchoCartographerSceneSnapshot, tier: EchoCartographerTier, reduceMotion: Bool) throws -> Mesh
    public static func glowMesh(_ snapshot: EchoCartographerSceneSnapshot, tier: EchoCartographerTier) throws -> Mesh
    public static func camera(_ snapshot: EchoCartographerSceneSnapshot, aspect: Double) -> EchoCartographerCamera
    public static func project(_ point: SIMD3<Double>, camera: EchoCartographerCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func chamberPart(_:tier:), glowPart(_:tier:) throws -> EchoCartographerColouredMesh   // fallback colours
}
public enum EchoCartographerShaders { chamberVertex, chamberFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: EchoCartographerTier) -> Double }
public struct EchoCartographerExperienceCore: ExperienceCore { /* cell.pulse, cell.claim, cell.mark, play.undo, play.redo, level.next */
    public func snapshot(time: Double) -> EchoCartographerSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension EchoCartographerExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// EchoCartographerExperience (iOS): EchoCartographerExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// EchoCartographerChamberScene, EchoCartographerControls.
```
