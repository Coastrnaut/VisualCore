# API contract: R02-G13-08 (AcousticConstellatorCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum AcousticConstellatorGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [AcousticConstellatorAction] }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> AcousticConstellatorSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// AcousticConstellatorConstellationScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 423; used unchanged).
```

Existing names used unchanged: `AcousticConstellatorSolver.plan`, `.workBound`, `AcousticConstellatorWitness` (decode, fields),
`AcousticConstellatorPlay`, `AcousticConstellatorSceneSnapshot.init(play:levelNumber:time:)`,
`AcousticConstellatorSceneGeometry.camera(_:aspect:)`, `starCentre`, `linkCheckPoint`, `coherenceBar`, `holdPip`, `movesBar`, `project`, `AcousticConstellatorPalette`,
`AcousticConstellatorGenerator`, `ProcessMemory.footprint()`.
