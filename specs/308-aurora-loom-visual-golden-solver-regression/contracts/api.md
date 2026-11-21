# API contract: R02-G01-08 (AuroraLoomCore additions)

```swift
public enum AuroraLoomGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let moves: [AuroraLoomMove] }
    public static let width = 96, height = 64
    public static var frames: [Frame] { get }                              // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> AuroraLoomSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data           // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String              // SHA-256 hex of the description
    public static func manifest() throws -> Data          // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum;
                                                                                  // else the first differing value
}
// AuroraLoomRibbonScene (experience, internal): var liveObjectCount: Int — mesh renderers held (each with its buffers); 0 after release.
```
