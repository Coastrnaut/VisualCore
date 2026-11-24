# API contract: R02-G15-08 (VoxelOrigamiCore additions, DEBUG or VISUALCORE_AUTOMATION only)

```swift
public enum VoxelOrigamiGolden {
    public struct Frame: Sendable, Equatable { public let name: String; public let level: Int; public let tier: Int
        public let time: Double; public let actions: [VoxelOrigamiAction] }
    public static let width = 1_152, height = 768
    public static var frames: [Frame] { get }                               // 16, fixed order
    public static func snapshot(_ frame: Frame) throws -> VoxelOrigamiSceneSnapshot
    public static func description(_ frame: Frame) throws -> Data            // JSON, sorted keys
    public static func digest(_ frame: Frame) throws -> String               // SHA-256 hex of the description
    public static func manifest() throws -> Data           // {"schema":1,"frames":{name: {"description":…, "digest":…}}}
    public static func compare(_ frame: Frame, pinned: Data) throws -> String?   // nil when equal or within one quantum
}
// VoxelOrigamiVoxelScene (experience, internal): var liveObjectCount: Int — GPU objects held; 0 after release()
// (exists since feature 443; used unchanged).
```

Existing names used unchanged: `VoxelOrigamiSolver.plan`, `.workBound`, `VoxelOrigamiPlan` (`turns`, `statesByDepth`,
`work`), `VoxelOrigamiWitness` (decode, fields), `VoxelOrigamiPlay`, `VoxelOrigamiExperienceCore.snapshot(time:)`,
`VoxelOrigamiSceneGeometry.camera(_:aspect:)`, `project`, `world`, `cubeCentre`, `hingeMark`, `coveredPip`, `litPips`,
`movesBar`, `litMoves`, `VoxelOrigamiPalette`, `VoxelOrigamiGenerator`, `ProcessMemory.footprint()`.
