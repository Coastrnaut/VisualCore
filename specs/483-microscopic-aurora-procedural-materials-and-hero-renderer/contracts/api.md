# API contract: R02-G19-03

```swift
// MicroscopicAuroraCore additions (host-testable)
public enum MicroscopicAuroraPalette { public static let abyss, abyssTop, field, frond, rim, stencil, lit, stray, site,
    well, ribbon, swimmer, met, unmet, actionsLit, actionsUnlit, broken, glow: SIMD3<Double>
    public static let hex: [String] }
public struct MicroscopicAuroraTier: Sendable, Equatable { public let name: String; public let index: Int
    public let capsuleSegments: Int   // 0 for flat capsules
    public let ribbonTicks: Int; public let fronds: Bool; public let glowShells: Int
    public static let all: [MicroscopicAuroraTier]   // level-0 … level-2
    public static func of(_ index: Int) -> MicroscopicAuroraTier }
public struct MicroscopicAuroraSceneSnapshot: Sendable, Equatable {
    public let radius: Int
    public let positions: [[MicroscopicAuroraPoint]]      // tick 0 … ticksSwum, per swimmer
    public let velocities: [[MicroscopicAuroraPoint]]
    public let ticksSwum: Int; public let shownTick: Int
    public let density: [Int]; public let litStencil: [MicroscopicAuroraCell]; public let stray: [MicroscopicAuroraCell]
    public let stencil: [MicroscopicAuroraCell]; public let sites: [MicroscopicAuroraCell]
    public let wells: [MicroscopicAuroraWell?]
    public let coverage: Int; public let requiredCoverage: Int
    public let coherence: Int; public let requiredCoherence: Int; public let swarm: Int
    public let coherenceRadius: Int                 // κ, to mark a coherence failure's outlying swimmers
    public let failure: MicroscopicAuroraFailure?; public let stage: MicroscopicAuroraStage
    public let actionsLeft: Int; public let budget: Int; public let levelNumber: Int; public let time: Double
    public init(play: MicroscopicAuroraPlay, shownTick: Int, levelNumber: Int, time: Double) }
public struct MicroscopicAuroraCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum MicroscopicAuroraSceneGeometry {
    public static let scale: Double                                       // 0.9 / 2816
    public static func world(_ point: MicroscopicAuroraPoint, depth: Double) -> SIMD3<Double>
    public static func dishCentre() -> SIMD3<Double>
    public static func rimPoint(_ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double>   // rightmost
    public static func swimmerCentre(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double>
    public static func siteCentre(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double>
    public static func coverageTrackCentre() -> SIMD3<Double>
    public static func actionsBar(_ index: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double>
    public static func ribbon(_ swimmer: Int, _ snapshot: MicroscopicAuroraSceneSnapshot,
                              tier: MicroscopicAuroraTier) -> [SIMD3<Double>]   // kernel positions only
    public static func dishMesh(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier) throws -> Mesh
    public static func glowMesh(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier) throws -> Mesh
    public static func camera(aspect: Double) -> MicroscopicAuroraCamera
    public static func project(_ point: SIMD3<Double>, camera: MicroscopicAuroraCamera) -> SIMD2<Double>?   // 0 … 1
    public static func dishPart(_:tier:), glowPart(_:tier:) throws -> MicroscopicAuroraColouredMesh   // fallback
}
public enum MicroscopicAuroraShaders { dishVertex, dishFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double
    public static func glowGain(for tier: MicroscopicAuroraTier) -> Double }
public struct MicroscopicAuroraExperienceCore: ExperienceCore { /* well.place, well.remove, swim.play, play.undo,
    play.redo, level.next, clock.show */
    public func snapshot(time: Double) -> MicroscopicAuroraSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension MicroscopicAuroraExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// MicroscopicAuroraExperience (iOS): MicroscopicAuroraExperience.make(id:storage:reduceMotion:reduceFlashing:),
// presenter, MicroscopicAuroraDishScene, MicroscopicAuroraControls.
```
