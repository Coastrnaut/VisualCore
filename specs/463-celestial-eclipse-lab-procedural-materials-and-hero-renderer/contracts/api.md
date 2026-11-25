# API contract: R02-G17-03

```swift
// CelestialEclipseLabCore additions (host-testable)
public enum CelestialEclipseLabPalette { public static let ink, inkTop, speck, disc, discShade, orbit, fixedFrame,
    chosen, corona, coronaGlow, crescentShadow, ember, window, matched, unwanted, faintEvent, playhead, actionsLit,
    actionsUnlit, broken, glow: SIMD3<Double>
    public static let hex: [String] }
public struct CelestialEclipseLabTier: Sendable, Equatable { public let name: String; public let index: Int
    public let longitudes: Int; public let latitudes: Int   // 0 for flat discs
    public let glowShells: Int
    public static let all: [CelestialEclipseLabTier]   // level-0 … level-2
    public static func of(_ index: Int) -> CelestialEclipseLabTier }
public struct CelestialEclipseLabEclipse: Sendable, Equatable { public let front: Int; public let back: Int
    public let visibility: CelestialEclipseLabVisibility }
public struct CelestialEclipseLabSceneSnapshot: Sendable, Equatable {
    public let bodies: [CelestialEclipseLabBody]; public let phases: [Int]
    public let positions: [CelestialEclipseLabVector]   // at the shown tick
    public let eclipses: [CelestialEclipseLabEclipse]    // under way at the shown tick
    public let target: [CelestialEclipseLabTarget]; public let intervals: [CelestialEclipseLabInterval]
    public let matched: Int; public let failure: CelestialEclipseLabFailure?
    public let shownTick: Int; public let horizon: Int; public let chosenBody: Int
    public let stage: CelestialEclipseLabStage; public let actionsLeft: Int; public let budget: Int
    public let levelNumber: Int; public let time: Double
    public init(play: CelestialEclipseLabPlay, chosenBody: Int, shownTick: Int, levelNumber: Int, time: Double) }
public struct CelestialEclipseLabCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum CelestialEclipseLabSceneGeometry {
    public static func scale(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Double
    public static func world(_ position: CelestialEclipseLabVector, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double>
    public static func bodyCentre(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double>
    public static func timelineCentre() -> SIMD3<Double>
    public static func tickPosition(_ tick: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double>
    public static func actionsBar(_ index: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double>
    public static func paintOrder(_ snapshot: CelestialEclipseLabSceneSnapshot, camera: CelestialEclipseLabCamera) -> [CelestialEclipseLabElement]
    public static func skyMesh(_ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier) throws -> Mesh
    public static func glowMesh(_ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier) throws -> Mesh
    public static func camera(_ snapshot: CelestialEclipseLabSceneSnapshot, aspect: Double) -> CelestialEclipseLabCamera
    public static func project(_ point: SIMD3<Double>, camera: CelestialEclipseLabCamera) -> SIMD2<Double>?   // 0 … 1 view coordinates
    public static func skyPart(_:tier:), glowPart(_:tier:) throws -> CelestialEclipseLabColouredMesh   // fallback colours
}
public enum CelestialEclipseLabShaders { skyVertex, skyFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double; public static func glowGain(for tier: CelestialEclipseLabTier) -> Double
    public static func haloPulse(time: Double, reduceMotion: Bool) -> Double }   // 1 with Reduce Motion
public struct CelestialEclipseLabExperienceCore: ExperienceCore { /* orbit.phase, clock.run, play.undo, play.redo,
    level.next, orbit.choose, clock.show */
    public func snapshot(time: Double) -> CelestialEclipseLabSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension CelestialEclipseLabExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// CelestialEclipseLabExperience (iOS): CelestialEclipseLabExperience.make(id:storage:reduceMotion:reduceFlashing:),
// presenter, CelestialEclipseLabSkyScene, CelestialEclipseLabControls.
```
