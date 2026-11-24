# API contract: R02-G15-02 (additions to VoxelOrigamiCore)

```swift
extension VoxelOrigamiError { case generation(Int), witness(String) }   // r02-g15.generation, r02-g15.witness
public struct VoxelOrigamiManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int; public let emphasis: String
    public var orientations: VoxelOrigamiOrientations { get } }   // rotate assembly → any, lock shape → fixed, else upright
public enum VoxelOrigamiManifest { public static let entries: [VoxelOrigamiManifestEntry]   // 100
    public static let provenance: String }
public struct VoxelOrigamiBandProfile: Sendable, Equatable { public let cubes: ClosedRange<Int>
    public let scramble: ClosedRange<Int>; public let planRange: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct VoxelOrigamiPlan: Sendable, Equatable, Codable { public let turns: [VoxelOrigamiAction]
    public let statesByDepth: [Int]   // states reached at depths 0 … size − 1 (depth 0 is the start: 1)
    public let work: Int; public var size: Int { get } }
public enum VoxelOrigamiSolver {
    public static let workBound: Int        // 300 000 turns tried
    public static let maxTurns: Int         // 6
    public static func plan(_ level: VoxelOrigamiLevel, maxTurns: Int = maxTurns,
                            workBound: Int = workBound) -> VoxelOrigamiPlan?
    public static func matches(_ level: VoxelOrigamiLevel, actions: [VoxelOrigamiAction]) -> Bool }
public struct VoxelOrigamiDifficulty: Sendable, Hashable, Codable { public let turns, cubes, turnableHinges: Int
    public let orientations: VoxelOrigamiOrientations; public let statesSearched, work: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct VoxelOrigamiGenerated: Sendable, Equatable { public let entry: VoxelOrigamiManifestEntry
    public let level: VoxelOrigamiLevel; public let plan: VoxelOrigamiPlan
    public let difficulty: VoxelOrigamiDifficulty; public let skipped: Int }
public enum VoxelOrigamiGenerator {
    public static let catalogID: String     // "voxel-origami"
    public static let maxCandidates: Int    // 256
    public static func levelID(_ number: Int) -> String   // voxel-origami-NNN
    public static func candidate(_ entry: VoxelOrigamiManifestEntry, index: Int) -> VoxelOrigamiLevel?
    public static func generate(_ entry: VoxelOrigamiManifestEntry) throws(VoxelOrigamiError) -> VoxelOrigamiGenerated
    public static func catalogDigest(_ levels: [VoxelOrigamiLevel]) -> String }
public struct VoxelOrigamiCounterexample: Sendable, Hashable, Codable {
    public let depth: Int     // plan.size − 1
    public let states: Int    // states reached at exactly that depth (none matched)
    public init(depth: Int, states: Int) }
public struct VoxelOrigamiWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static let schema: Int                                   // 1
    public static func canonicalText(turns: [Int]) -> String       // "turns=0,1,3,0"
    public static func digest(turns: [Int]) -> String              // first 16 hex of SHA-256 of canonicalText
    public static func make(_ generated: VoxelOrigamiGenerated) throws(VoxelOrigamiError) -> Self
    public static func decode(_ data: Data) throws(VoxelOrigamiError) -> Self; public func encoded() -> Data }
```
