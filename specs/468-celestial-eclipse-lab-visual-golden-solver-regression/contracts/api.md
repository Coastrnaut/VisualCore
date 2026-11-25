# API contract: R02-G17-08 (CelestialEclipseLabCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum CelestialEclipseLabGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [CelestialEclipseLabAction]; public let tick: Int }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> CelestialEclipseLabSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// CelestialEclipseLabSkyScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 463; used unchanged).
```

Existing names used unchanged: `CelestialEclipseLabSolver.plan`, `.workBound`, `CelestialEclipseLabPlan` (`actions`,
`settingsByDepth`, `work`), `CelestialEclipseLabWitness` (decode, fields), `CelestialEclipseLabPlay`,
`CelestialEclipseLabExperienceCore.snapshot(time:)`, `CelestialEclipseLabSceneGeometry.camera`, `project`,
`bodyCentre`, `shadowLens`, `hasHalo`, `playhead`, `actionsBar`, `litActions`, `CelestialEclipseLabPalette`,
`CelestialEclipseLabGenerator`, `ProcessMemory.footprint()`.
