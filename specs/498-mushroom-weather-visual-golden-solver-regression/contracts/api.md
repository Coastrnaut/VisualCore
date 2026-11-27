# API contract: R02-G20-08 (MushroomWeatherCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum MushroomWeatherGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [MushroomWeatherAction]; public let cycle: Int }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> MushroomWeatherSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// MushroomWeatherForestScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 493; used unchanged).
```

Existing names used unchanged: `MushroomWeatherSolver.plan`, `.workBound`, `MushroomWeatherPlan` (`actions`,
`arrangementsByDepth`, `work`), `MushroomWeatherWitness` (decode, fields), `MushroomWeatherPlay`,
`MushroomWeatherExperienceCore.snapshot(time:)`, `MushroomWeatherSceneGeometry.camera`, `project`, `floorCentre`,
`capCentre`, `moonCentre`, `gaugeTrackCentre`, `actionsBar`, `litActions`, `MushroomWeatherPalette`,
`MushroomWeatherGenerator`, `ProcessMemory.footprint()`.
