# API contract: R02-G12-03

```swift
// HarmonicBridgesCore additions (host-testable)
public enum HarmonicBridgesPalette { public static let ground, islandFace, islandEdge, string, membrane, markFilled,
    markHollow, start, goal, glow, shell, pip, pipUnlit, gaugeLit, gaugeUnlit: SIMD3<Double>; public static let hex: [String] }
public struct HarmonicBridgesTier: Sendable, Equatable { public let name: String; public let index: Int
    public let motion: Bool; public let waveShells: Int; public let glowShells: Int
    public static let all: [HarmonicBridgesTier]   // level-0 … level-2
    public static func of(_ index: Int) -> HarmonicBridgesTier }
public struct HarmonicBridgesSceneSnapshot: Sendable, Equatable {
    public let islands: [HarmonicBridgesIsland]; public let strings: [HarmonicBridgesString]; public let pegs: [Int]
    public let report: HarmonicBridgesReport; public let modes: [[[Int]]]   // [step][string] resonant modes
    public let strengths: [[[Int]]]; public let threshold: Int; public let start: Int; public let goal: Int
    public let stage: HarmonicBridgesStage; public let failure: HarmonicBridgesFailure?
    public let actionsLeft: Int; public let budget: Int; public let levelNumber: Int; public let time: Double
    public var shownStep: Int { get }   // cycles every 1.2 s while playing; 0 at time 0
    public init(play: HarmonicBridgesPlay, levelNumber: Int, time: Double) }
public struct HarmonicBridgesCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum HarmonicBridgesSceneGeometry {
    public static func islandTop(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double>
    public static func stringMidpoint(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double>
    public static func membraneMidpoint(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double>
    public static func gaugeBar(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double>
    public static func stepPip(_ index: Int, _ snapshot: HarmonicBridgesSceneSnapshot) -> SIMD3<Double>
    public static func bridgeMesh(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier, reduceMotion: Bool) throws -> Mesh
    public static func glowMesh(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier) throws -> Mesh
    public static func camera(_ snapshot: HarmonicBridgesSceneSnapshot, aspect: Double) -> HarmonicBridgesCamera
    public static func project(_ point: SIMD3<Double>, camera: HarmonicBridgesCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func bridgePart(_:tier:), glowPart(_:tier:) throws -> HarmonicBridgesColouredMesh   // fallback colours
}
public enum HarmonicBridgesShaders { bridgeVertex, bridgeFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: HarmonicBridgesTier) -> Double }
public struct HarmonicBridgesExperienceCore: ExperienceCore { /* string.tune, crossing.test, play.undo, play.redo, level.next */
    public func snapshot(time: Double) -> HarmonicBridgesSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension HarmonicBridgesExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// HarmonicBridgesExperience (iOS): HarmonicBridgesExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter,
// HarmonicBridgesBridgeScene, HarmonicBridgesControls.
```
