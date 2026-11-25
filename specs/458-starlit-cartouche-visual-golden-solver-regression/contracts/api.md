# API contract: R02-G16-08 (StarlitCartoucheCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum StarlitCartoucheGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [StarlitCartoucheAction] }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> StarlitCartoucheSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// StarlitCartoucheChartScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 453; used unchanged).
```

Existing names used unchanged: `StarlitCartoucheSolver.plan`, `.workBound`, `StarlitCartouchePlan` (`legs`,
`statesByDepth`, `work`), `StarlitCartoucheWitness` (decode, fields), `StarlitCartouchePlay`,
`StarlitCartoucheExperienceCore.snapshot(time:)`, `StarlitCartoucheSceneGeometry.camera(_:aspect:)`, `project`,
`starCentre`, `shipCentre`, `trailMidpoint`, `actionsBar`, `litActions`, `StarlitCartouchePalette`,
`StarlitCartoucheGenerator`, `ProcessMemory.footprint()`.
