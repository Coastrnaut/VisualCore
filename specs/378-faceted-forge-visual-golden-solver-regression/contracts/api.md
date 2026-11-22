# API contract: R02-G08-08 (FacetedForgeCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum FacetedForgeGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [FacetedForgeAction] }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> FacetedForgeSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// FacetedForgeCrystalScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release().
```

Existing names used unchanged: `FacetedForgeSolver.solve`, `.lowerBound`, `.workBound`, `FacetedForgeWitness`
(decode, fields), `FacetedForgePlay`, `FacetedForgeSceneSnapshot.init(play:levelNumber:choice:time:)`,
`FacetedForgePreviewChoice.initial(_:)`, `FacetedForgeSceneGeometry.camera(_:aspect:)`, `.pixel(_:camera:width:height:)`,
`.pieceCentre`, `.previewCentre`, `FacetedForgePalette`, `FacetedForgeGenerator`, `ProcessMemory.footprint()`.
