# API contract: R02-G18-03

```swift
// ApsidesWorkshopCore additions (host-testable)
public enum ApsidesWorkshopPalette { public static let midnight, midnightTop, speck, wedge, targetWedge, compass, ghost,
    glacial, deepRose, planet, hazard, star, met, unmet, actionsLit, actionsUnlit, broken, glow: SIMD3<Double>
    public static let hex: [String] }
public struct ApsidesWorkshopTier: Sendable, Equatable { public let name: String; public let index: Int
    public let longitudes: Int; public let latitudes: Int   // 0 for flat discs
    public let refinement: Int; public let glowShells: Int
    public static let all: [ApsidesWorkshopTier]   // level-0 … level-2
    public static func of(_ index: Int) -> ApsidesWorkshopTier }
public struct ApsidesWorkshopGauge: Sendable, Equatable { public let target: ApsidesWorkshopTarget
    public let reading: Int; public let deviation: Int; public let met: Bool }
public struct ApsidesWorkshopSceneSnapshot: Sendable, Equatable {
    public let orbit: ApsidesWorkshopOrbit
    public let positions: [ApsidesWorkshopPoint]; public let ghost: [ApsidesWorkshopPoint]
    public let orbiter: ApsidesWorkshopPoint; public let shares: [Int]
    public let periapsisSector: Int; public let periapsisDistance: Int
    public let apoapsisSector: Int; public let apoapsisDistance: Int
    public let planets: [ApsidesWorkshopPlanet]; public let gauges: [ApsidesWorkshopGauge]
    public let failure: ApsidesWorkshopFailure?; public let shownTick: Int; public let period: Int
    public let stage: ApsidesWorkshopStage; public let actionsLeft: Int; public let budget: Int
    public let levelNumber: Int; public let time: Double
    public init(play: ApsidesWorkshopPlay, shownTick: Int, levelNumber: Int, time: Double) }
public struct ApsidesWorkshopCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum ApsidesWorkshopSceneGeometry {
    public static let scale: Double                                       // 0.9 / 16 384
    public static func world(_ point: ApsidesWorkshopPoint, depth: Double) -> SIMD3<Double>
    public static func starCentre() -> SIMD3<Double>
    public static func orbiterCentre(_ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double>
    public static func planetCentre(_ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double>
    public static func gaugeCentre(_ index: Int) -> SIMD3<Double>
    public static func actionsBar(_ index: Int, _ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double>
    public static func refinement(_ snapshot: ApsidesWorkshopSceneSnapshot,
                                  tier: ApsidesWorkshopTier) -> [SIMD3<Double>]   // the ribbon's points, ticks included
    public static func compassMesh(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier) throws -> Mesh
    public static func glowMesh(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier) throws -> Mesh
    public static func camera(aspect: Double) -> ApsidesWorkshopCamera
    public static func project(_ point: SIMD3<Double>, camera: ApsidesWorkshopCamera) -> SIMD2<Double>?   // 0 … 1
    public static func compassPart(_:tier:), glowPart(_:tier:) throws -> ApsidesWorkshopColouredMesh   // fallback
}
public enum ApsidesWorkshopShaders { compassVertex, compassFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: ApsidesWorkshopTier) -> Double
    public static func starPulse(time: Double, reduceMotion: Bool) -> Double }   // 1 with Reduce Motion
public struct ApsidesWorkshopExperienceCore: ExperienceCore { /* orbit.periapsis, orbit.size, orbit.play, play.undo,
    play.redo, level.next, clock.show */
    public func snapshot(time: Double) -> ApsidesWorkshopSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension ApsidesWorkshopExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// ApsidesWorkshopExperience (iOS): ApsidesWorkshopExperience.make(id:storage:reduceMotion:reduceFlashing:),
// presenter, ApsidesWorkshopCompassScene, ApsidesWorkshopControls.
```
