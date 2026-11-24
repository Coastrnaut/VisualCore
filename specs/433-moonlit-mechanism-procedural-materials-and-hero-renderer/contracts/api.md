# API contract: R02-G14-03

```swift
// MoonlitMechanismCore additions (host-testable)
public enum MoonlitMechanismPalette { public static let night, paper, ink, gear, rim, blade, lamp, lampGlow, target,
    forbidden, stray, broken, cardLit, cardUnlit, alignLit, alignUnlit, movesLit, movesUnlit, glow: SIMD3<Double>
    public static let gearAlpha: Double; public static let bladeAlpha: Double; public static let hex: [String] }
public struct MoonlitMechanismTier: Sendable, Equatable { public let name: String; public let index: Int
    public let segmentsPerTooth: Int; public let softEdge: Bool; public let glowShells: Int
    public static let all: [MoonlitMechanismTier]   // level-0 … level-2
    public static func of(_ index: Int) -> MoonlitMechanismTier }
public struct MoonlitMechanismSceneSnapshot: Sendable, Equatable {
    public let gears: [MoonlitMechanismGear]; public let phases: [Int]          // at the shown key frame
    public let height: Int; public let lampHeights: Int; public let width: Int; public let rows: Int
    public let shownFrame: Int; public let cast: [Int]; public let target: [Int]; public let forbidden: [Int]
    public let report: MoonlitMechanismRunReport; public let stage: MoonlitMechanismStage
    public let failure: MoonlitMechanismFailure?; public let actionsLeft: Int; public let budget: Int
    public let levelNumber: Int; public let time: Double
    public init(play: MoonlitMechanismPlay, shownFrame: Int, levelNumber: Int, time: Double) }
public struct MoonlitMechanismCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum MoonlitMechanismSceneGeometry {
    public static func cellSize(_ snapshot: MoonlitMechanismSceneSnapshot) -> Double
    public static func cellCentre(_ cell: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double>
    public static func gearCentre(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double>
    public static func gearRimCheckPoint(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double>
    public static func card(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double>
    public static func alignmentPip(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double>
    public static func movesBar(_ index: Int, _ snapshot: MoonlitMechanismSceneSnapshot) -> SIMD3<Double>
    public static func clockworkMesh(_ snapshot: MoonlitMechanismSceneSnapshot, tier: MoonlitMechanismTier, reduceMotion: Bool) throws -> Mesh
    public static func glowMesh(_ snapshot: MoonlitMechanismSceneSnapshot, tier: MoonlitMechanismTier) throws -> Mesh
    public static func camera(_ snapshot: MoonlitMechanismSceneSnapshot, aspect: Double) -> MoonlitMechanismCamera
    public static func project(_ point: SIMD3<Double>, camera: MoonlitMechanismCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func clockworkPart(_:tier:), glowPart(_:tier:) throws -> MoonlitMechanismColouredMesh   // fallback colours
}
public enum MoonlitMechanismShaders { clockworkVertex, clockworkFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: MoonlitMechanismTier) -> Double }
public struct MoonlitMechanismExperienceCore: ExperienceCore { /* handle.turn, gear.reseat, lamp.step, machine.run,
    play.undo, play.redo, level.next, frame.show */
    public func snapshot(time: Double) -> MoonlitMechanismSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension MoonlitMechanismExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// MoonlitMechanismExperience (iOS): MoonlitMechanismExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// MoonlitMechanismClockworkScene, MoonlitMechanismControls.
```
