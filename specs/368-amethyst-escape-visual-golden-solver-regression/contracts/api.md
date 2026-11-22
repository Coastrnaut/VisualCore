# API contract: R02-G07-08 (AmethystEscapeCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum AmethystEscapeGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [AmethystEscapeAction] }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> AmethystEscapeSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// AmethystEscapeCrystalScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release().
```

Existing names used unchanged: `AmethystEscapeSolver.solve`, `.stateCount`, `AmethystEscapeWitness` (decode, fields,
`replay`), `AmethystEscapePlay`, `AmethystEscapeSceneSnapshot.init(play:levelNumber:time:)`,
`AmethystEscapeSceneGeometry.camera(_:aspect:)`, `.pixel(_:camera:width:height:)`, `.pearlCentre`, `.exitCentre`,
`.wedgeOrder`, `.wedgeTopCentre`, `.moveBarLength`, `AmethystEscapePalette`, `AmethystEscapeGenerator`,
`ProcessMemory.footprint()`.
