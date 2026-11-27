# API contract: R02-G20-03

```swift
// MushroomWeatherCore additions (host-testable)
public enum MushroomWeatherPalette { public static let midnight, midnightTop, moon, moss, log, frond, mistLow, mistHigh,
    site, stalk, cap, capOut, pod, droplet, vent, band, marker, actionsLit, actionsUnlit, broken, glow: SIMD3<Double>
    public static let hex: [String] }
public struct MushroomWeatherTier: Sendable, Equatable { public let name: String; public let index: Int
    public let latheSegments: Int     // 0 for flat caps and pods
    public let droplets: Int; public let fronds: Bool; public let motes: Int; public let glowShells: Int
    public static let all: [MushroomWeatherTier]   // level-0 … level-2
    public static func of(_ index: Int) -> MushroomWeatherTier }
public struct MushroomWeatherSceneColony: Sendable, Equatable { public let cell: MushroomWeatherCell
    public let low, high: Int; public let survivalFloor: Int?; public let finalRun, longestRun: Int
    public let inBand: Bool }                                   // at the shown cycle
public struct MushroomWeatherSceneSnapshot: Sendable, Equatable {
    public let rows, columns: Int; public let blocked: [MushroomWeatherCell]
    public let fields: [[Int]]                                  // cycle 0 … cyclesRun, row-major
    public let cyclesRun: Int; public let shownCycle: Int; public let moldBound: Int
    public let colonies: [MushroomWeatherSceneColony]; public let requiredCycles: Int
    public let pods: [MushroomWeatherCell?]; public let grownAt: [Int?]
    public let sites: [MushroomWeatherCell]; public let vents: [MushroomWeatherCell]; public let ventsOpen: [Bool]
    public let moonlight: Int
    public let failure: MushroomWeatherFailure?; public let stage: MushroomWeatherStage
    public let actionsLeft: Int; public let budget: Int; public let levelNumber: Int; public let time: Double
    public init(play: MushroomWeatherPlay, shownCycle: Int, levelNumber: Int, time: Double) }
public struct MushroomWeatherCamera: Sendable, Equatable { /* eye, view and projection, aspect */ }
public enum MushroomWeatherSceneGeometry {
    public static func scale(rows: Int, columns: Int) -> Double            // min(1.8 / C, 1.6 / R)
    public static func cellCentre(_ cell: MushroomWeatherCell, _ snapshot: MushroomWeatherSceneSnapshot,
                                  height: Double) -> SIMD3<Double>
    public static func floorCentre() -> SIMD3<Double>
    public static func capCentre(_ colony: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double>
    public static func moonCentre() -> SIMD3<Double>
    public static func gaugeTrackCentre(_ colony: Int) -> SIMD3<Double>
    public static func actionsBar(_ index: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double>
    public static func mistSide(_ humidity: Int, moldBound: Int, scale: Double) -> Double   // s · (0.2 + 0.7·min(1, h/M))
    public static func forestMesh(_ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier) throws -> Mesh
    public static func glowMesh(_ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier) throws -> Mesh
    public static func camera(aspect: Double) -> MushroomWeatherCamera
    public static func project(_ point: SIMD3<Double>, camera: MushroomWeatherCamera) -> SIMD2<Double>?   // 0 … 1
    public static func forestPart(_:tier:), glowPart(_:tier:) throws -> MushroomWeatherColouredMesh   // fallback
}
public enum MushroomWeatherShaders { forestVertex, forestFragment, glowVertex, glowFragment: String   // GLSL ES 3.00
    public static func glowLimit(reduceFlashing: Bool) -> Double
    public static func glowGain(for tier: MushroomWeatherTier) -> Double }
public struct MushroomWeatherExperienceCore: ExperienceCore { /* pod.place, pod.remove, vent.set, moon.set,
    weather.run, play.undo, play.redo, level.next, clock.show */
    public func snapshot(time: Double) -> MushroomWeatherSceneSnapshot }
#if DEBUG || VISUALCORE_AUTOMATION
extension MushroomWeatherExperienceCore { public static func manifest(for id: ExperienceID) -> ScenarioManifest }
#endif
// MushroomWeatherExperience (iOS): MushroomWeatherExperience.make(id:storage:reduceMotion:reduceFlashing:),
// presenter, MushroomWeatherForestScene, MushroomWeatherControls.
```
