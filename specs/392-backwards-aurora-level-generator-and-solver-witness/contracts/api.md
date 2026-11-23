# API contract: R02-G10-02 (additions to BackwardsAuroraCore)

```swift
extension BackwardsAuroraError { case generation(Int), witness(String) }   // r02-g10.generation, r02-g10.witness
public struct BackwardsAuroraManifestEntry: Sendable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum BackwardsAuroraManifest { public static let entries: [BackwardsAuroraManifestEntry]   // 100, manifest order
    public static let provenance: String }
public struct BackwardsAuroraBandProfile: Sendable, Equatable { /* fields per data-model.md */
    public static func of(band: Int) -> Self }
public struct BackwardsAuroraBound: Sendable, Hashable, Codable { public let badBends: Int; public var smallest: Int { get } }
public struct BackwardsAuroraSolution: Sendable, Equatable, Codable { public let smallest: Int
    public let actions: [BackwardsAuroraAction]; public let work: Int }
public enum BackwardsAuroraSolver {
    public static let workBound: Int                                                 // 20,000 reversals evaluated
    public static func badBends(_ wave: BackwardsAuroraWave, limit: Int) -> Int      // interior |b| > limit
    public static func lowerBound(_ level: BackwardsAuroraLevel) -> BackwardsAuroraBound
    public static func solve(_ level: BackwardsAuroraLevel, workBound: Int = workBound) -> BackwardsAuroraSolution?
    public static func wins(_ level: BackwardsAuroraLevel, actions: [BackwardsAuroraAction]) -> Bool }
public struct BackwardsAuroraDifficulty: Sendable, Hashable, Codable { public let smallest, length, checkpoints,
    reversedSamples, longestSection, badBends, bendLimit, breakingMargin, work: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct BackwardsAuroraGenerated: Sendable, Equatable { public let entry: BackwardsAuroraManifestEntry
    public let level: BackwardsAuroraLevel; public let solution: BackwardsAuroraSolution
    public let bound: BackwardsAuroraBound; public let difficulty: BackwardsAuroraDifficulty; public let skipped: Int }
public enum BackwardsAuroraGenerator {
    public static let catalogID: String    // "backwards-aurora"
    public static let maxCandidates: Int   // 256
    public static func levelID(_ number: Int) -> String   // backwards-aurora-NNN
    public static func candidate(_ entry: BackwardsAuroraManifestEntry, index: Int) -> BackwardsAuroraLevel?
    public static func generate(_ entry: BackwardsAuroraManifestEntry) throws(BackwardsAuroraError) -> BackwardsAuroraGenerated
    public static func catalogDigest(_ levels: [BackwardsAuroraLevel]) -> String }
public struct BackwardsAuroraCounterexample: Sendable, Equatable, Codable { public let actions: [BackwardsAuroraAction]
    public let badBends: Int }
public struct BackwardsAuroraWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func digest(_ wave: BackwardsAuroraWave) -> String   // first 16 hex of SHA-256 of the samples
    public static func make(_ generated: BackwardsAuroraGenerated) throws(BackwardsAuroraError) -> Self
    public static func decode(_ data: Data) throws(BackwardsAuroraError) -> Self; public func encoded() -> Data }
```
