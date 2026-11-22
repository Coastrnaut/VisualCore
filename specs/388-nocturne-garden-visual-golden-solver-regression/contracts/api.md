# API contract: R02-G09-08 (NocturneGardenCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum NocturneGardenGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [NocturneGardenAction] }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> NocturneGardenSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// NocturneGardenGardenScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 384; used unchanged).
```

Existing names used unchanged: `NocturneGardenSolver.solve`, `.lowerBound`, `.workBound`, `NocturneGardenWitness`
(decode, fields), `NocturneGardenPlay`, `NocturneGardenSceneSnapshot.init(play:levelNumber:time:)`,
`NocturneGardenSceneGeometry.camera(_:aspect:)`, the head and lantern positions of the scene geometry, `NocturneGardenPalette`, `NocturneGardenGenerator`, `ProcessMemory.footprint()`.
