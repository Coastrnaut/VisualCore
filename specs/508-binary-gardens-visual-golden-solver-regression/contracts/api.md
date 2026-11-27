# API contract: R02-G21-08 (BinaryGardensCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum BinaryGardensGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [BinaryGardensAction]; public let tick: Int }
    public static let width = 1_152, height = 768, schema = 1, quantum = 8
    public static let levels: [Int] = [1, 21, 41, 61, 81], dialLevel = 25, tick = 24, time = 0.0
    public static let writeSwitch = "BINARY_GARDENS_WRITE_GOLDEN"
    public static var frames: [Frame] { get }                               // 17, fixed order
    public static func snapshot(_ frame: Frame) throws -> BinaryGardensSceneSnapshot   // no preview, no inspection
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data   // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func writeIfRequested(to file: URL,
        environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Bool   // false without switch
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// BinaryGardensSystemScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 503; used unchanged).
```

`compare` returns a message naming the frame and the first differing value (a position outside one 1/8-pixel quantum,
or any differing count, value, colour or material), or names a pinned digest that is not the digest of its pinned
description.

Existing names used unchanged: `BinaryGardensSolver.plan(_:maxDepth:workBound:)`, `.workBound`, `.replayWins`,
`BinaryGardensPlan` (`actions`, `arrangement`, `arrangementsByDepth`, `nearestMiss`, `nearestMissArrangement`,
`work`), `BinaryGardensBandProfile.of(band:).plan`, `BinaryGardensWitness` (`decode`, fields, `digest(arrangement:
spent:)`), `BinaryGardensCounterexample`, `BinaryGardensLevel` (initialiser, `fingerprint`), `BinaryGardensPlay`
(`handle`, `apply(_:expecting:)`, `fingerprint`, `report`), `BinaryGardensExperienceCore.generated(number:)`,
`level(number:)`, `freshPlay(of:)`, `certifiedActions(_:)`, `heroTick(_:)`, `manifestSeed`, `levelNumber(forSeed:)`,
`BinaryGardensSceneSnapshot(play:shownTick:levelNumber:time:)`, `BinaryGardensSceneGeometry.camera(aspect:)`,
`project`, `referencePoints`, `tiltPipCentre`, `luminosityPips`, `litActions`, `paintOrder`, `BinaryGardensPalette.all`,
`BinaryGardensShaders.materials`, `BinaryGardensTier.all`, `StableHash.sha256Hex`, `ProcessMemory.footprint()`.
