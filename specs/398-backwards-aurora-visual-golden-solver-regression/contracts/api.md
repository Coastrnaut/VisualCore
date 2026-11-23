# API contract: R02-G10-08 (BackwardsAuroraCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum BackwardsAuroraGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [BackwardsAuroraAction] }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> BackwardsAuroraSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// BackwardsAuroraAuroraScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 393; used unchanged).
```

Existing names used unchanged: `BackwardsAuroraSolver.solve`, `.lowerBound`, `.workBound`, `BackwardsAuroraWitness`
(decode, fields), `BackwardsAuroraPlay`, `BackwardsAuroraSceneSnapshot.init(play:levelNumber:sectionStart:sectionEnd:time:)`,
`BackwardsAuroraSceneGeometry.camera(_:aspect:)`, the sample and ring positions of the scene geometry (`samplePoint`, `ringCentre`, `project`), `BackwardsAuroraPalette`, `BackwardsAuroraGenerator`, `ProcessMemory.footprint()`.
