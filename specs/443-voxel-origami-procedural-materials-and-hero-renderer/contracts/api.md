# API contract: R02-G15-03

```swift
// VoxelOrigamiCore additions (host-testable)
public enum VoxelOrigamiPalette { public static let night, ivory, ivoryShade, target, targetGlow, hinge, hingeChosen,
    glyphSolid, glyphHollow, dots, coveredLit, coveredUnlit, movesLit, movesUnlit, broken, glow: SIMD3<Double>
    public static let hex: [String] }
public struct VoxelOrigamiTier: Sendable, Equatable { public let name: String; public let index: Int
    public let bevelSteps: Int; public let edgeWidth: Double; public let glowShells: Int
    public static let all: [VoxelOrigamiTier]   // level-0 … level-2
    public static func of(_ index: Int) -> VoxelOrigamiTier }
public struct VoxelOrigamiSceneSnapshot: Sendable, Equatable {
    public let cubes: [VoxelOrigamiCube]; public let cells: [VoxelOrigamiVector]; public let orientations: [VoxelOrigamiRotation]
    public let turns: [Int]; public let turnable: [Int]; public let chosenHinge: Int
    public let target: [VoxelOrigamiVector]   // at the best allowed alignment
    public let report: VoxelOrigamiShapeReport; public let stage: VoxelOrigamiStage
    public let failure: VoxelOrigamiFailure?; public let actionsLeft: Int; public let budget: Int
    public let levelNumber: Int; public let time: Double
    public init(play: VoxelOrigamiPlay, chosenHinge: Int, levelNumber: Int, time: Double) }
public struct VoxelOrigamiCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum VoxelOrigamiSceneGeometry {
    public static func scale(_ snapshot: VoxelOrigamiSceneSnapshot) -> Double
    public static func world(_ cell: VoxelOrigamiVector, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double>
    public static func cubeCentre(_ index: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double>
    public static func hingeCentre(_ hinge: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double>
    public static func coveredPip(_ index: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double>
    public static func movesBar(_ index: Int, _ snapshot: VoxelOrigamiSceneSnapshot) -> SIMD3<Double>
    public static func paintOrder(_ snapshot: VoxelOrigamiSceneSnapshot, camera: VoxelOrigamiCamera) -> [VoxelOrigamiElement]
    public static func voxelMesh(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier, reduceMotion: Bool) throws -> Mesh
    public static func glowMesh(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier) throws -> Mesh
    public static func camera(_ snapshot: VoxelOrigamiSceneSnapshot, aspect: Double) -> VoxelOrigamiCamera
    public static func project(_ point: SIMD3<Double>, camera: VoxelOrigamiCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func voxelPart(_:tier:), glowPart(_:tier:) throws -> VoxelOrigamiColouredMesh   // fallback colours
}
public enum VoxelOrigamiShaders { voxelVertex, voxelFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: VoxelOrigamiTier) -> Double }
public struct VoxelOrigamiExperienceCore: ExperienceCore { /* hinge.turn, play.undo, play.redo, level.next, hinge.choose */
    public func snapshot(time: Double) -> VoxelOrigamiSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension VoxelOrigamiExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// VoxelOrigamiExperience (iOS): VoxelOrigamiExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// VoxelOrigamiVoxelScene, VoxelOrigamiControls.
```
