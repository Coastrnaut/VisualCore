# API contract: R02-G16-02 (additions to StarlitCartoucheCore)

```swift
extension StarlitCartoucheError { case generation(Int), witness(String) }   // r02-g16.generation, r02-g16.witness
// StarlitCartoucheLevel.budgets: 1 … 24 (was 1 … 16)
public struct StarlitCartoucheManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int; public let emphasis: String }
public enum StarlitCartoucheManifest { public static let entries: [StarlitCartoucheManifestEntry]   // 100
    public static let provenance: String }
public struct StarlitCartoucheBandProfile: Sendable, Equatable { public let stars: ClosedRange<Int>
    public let route: ClosedRange<Int>; public let decoys: Int; public let planRange: ClosedRange<Int>
    public static func of(band: Int) -> Self }
public struct StarlitCartouchePlan: Sendable, Equatable, Codable { public let legs: [StarlitCartoucheAction]
    public let statesByDepth: [Int]   // states reached at depths 0 … size − 1 (depth 0 is the start: 1)
    public let work: Int; public var size: Int { get } }
public enum StarlitCartoucheSolver {
    public static let workBound: Int        // 300 000 legs tried
    public static let maxLegs: Int          // 7
    public static func plan(_ level: StarlitCartoucheLevel, maxLegs: Int = maxLegs,
                            workBound: Int = workBound) -> StarlitCartouchePlan?
    public static func wins(_ level: StarlitCartoucheLevel, actions: [StarlitCartoucheAction]) -> Bool }
public struct StarlitCartoucheDifficulty: Sendable, Hashable, Codable { public let legs, stars, corridors, hazards,
    strokes, statesSearched, work: Int; public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct StarlitCartoucheGenerated: Sendable, Equatable { public let entry: StarlitCartoucheManifestEntry
    public let level: StarlitCartoucheLevel; public let plan: StarlitCartouchePlan
    public let difficulty: StarlitCartoucheDifficulty; public let skipped: Int }
public enum StarlitCartoucheGenerator {
    public static let catalogID: String     // "starlit-cartouche"
    public static let maxCandidates: Int    // 256
    public static func levelID(_ number: Int) -> String   // starlit-cartouche-NNN
    public static func candidate(_ entry: StarlitCartoucheManifestEntry, index: Int) -> StarlitCartoucheLevel?
    public static func generate(_ entry: StarlitCartoucheManifestEntry) throws(StarlitCartoucheError) -> StarlitCartoucheGenerated
    public static func catalogDigest(_ levels: [StarlitCartoucheLevel]) -> String }
public struct StarlitCartoucheCounterexample: Sendable, Hashable, Codable {
    public let depth: Int     // plan.size − 1
    public let states: Int    // states reached at exactly that depth (none won)
    public init(depth: Int, states: Int) }
public struct StarlitCartoucheWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static let schema: Int                                   // 1
    public static func canonicalText(star: Int, beat: Int, drawn: [Int]) -> String   // "star=2;beat=7;drawn=0,3"
    public static func digest(star: Int, beat: Int, drawn: [Int]) -> String         // first 16 hex of SHA-256
    public static func make(_ generated: StarlitCartoucheGenerated) throws(StarlitCartoucheError) -> Self
    public static func decode(_ data: Data) throws(StarlitCartoucheError) -> Self; public func encoded() -> Data }
```
