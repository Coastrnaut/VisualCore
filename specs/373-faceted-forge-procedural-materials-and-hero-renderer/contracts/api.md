# API contract: R02-G08-03

```swift
// FacetedForgeCore additions (host-testable)
public enum FacetedForgePalette { public static let ground, ice, highlight, ruby, amber, lattice, sliver, spent, unspent: SIMD3<Double> }
public struct FacetedForgeTier: Sendable, Equatable { public let name: String; public let bevelSegments: Int
    public let dispersionLayers: Int; public let glowShells: Int; public static let all: [FacetedForgeTier]   // level-0 … level-2
    public static func of(_ index: Int) -> FacetedForgeTier }
public struct FacetedForgeSceneSnapshot: Sendable, Equatable {
    public struct Piece { public let corners: [SIMD3<Double>]; public let faces: [[Int]]; public let cutFaces: [Bool]
        public let centroid: SIMD3<Double> }
    public let pieces: [Piece]; public let chosen: Int; public let direction: Int; public let depth: Int
    public let preview: [SIMD3<Double>]          // the chosen piece's cross-section, empty when the plane misses it
    public let stage: FacetedForgeStage; public let failure: FacetedForgeFailure?; public let failurePiece: Int?
    public let cuts: Int; public let budget: Int; public let levelNumber: Int; public let time: Double
    public init(play: FacetedForgePlay, levelNumber: Int, chosen: Int, direction: Int, depth: Int, time: Double) }
public struct FacetedForgeCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum FacetedForgeSceneGeometry {
    public static func opening(_ snapshot: FacetedForgeSceneSnapshot) -> Double               // 0 … 0.12, 0.2 when won
    public static func offset(piece: Int, _ snapshot: FacetedForgeSceneSnapshot) -> SIMD3<Double>
    public static func pieceCentre(_ piece: Int, _ snapshot: FacetedForgeSceneSnapshot) -> SIMD3<Double>   // opened
    public static func cutFaceCentres(_ snapshot: FacetedForgeSceneSnapshot) -> [SIMD3<Double>]          // opened
    public static func previewCentre(_ snapshot: FacetedForgeSceneSnapshot) -> SIMD3<Double>?
    public static func crystalMesh(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier) throws -> Mesh   // ground, pieces back to front, bevels, lattice, preview, marks
    public static func glowMesh(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier) throws -> Mesh      // glow shells over cut faces
    public static func camera(_ snapshot: FacetedForgeSceneSnapshot, aspect: Double) -> FacetedForgeCamera
    public static func project(_ point: SIMD3<Double>, camera: FacetedForgeCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func crystalPart(_:tier:), glowPart(_:tier:) throws -> FacetedForgeColouredMesh   // fallback colours
}
public enum FacetedForgeShaders { crystalVertex, crystalFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: FacetedForgeTier) -> Double }
public struct FacetedForgeExperienceCore: ExperienceCore { /* piece.cut, play.undo, play.redo, level.next */
    public func snapshot(chosen: Int, direction: Int, depth: Int, time: Double) -> FacetedForgeSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension FacetedForgeExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// FacetedForgeExperience (iOS): FacetedForgeExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// FacetedForgeCrystalScene, FacetedForgeControls.
```
