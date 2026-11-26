# API contract: R02-G19-02 (additions to MicroscopicAuroraCore)

```swift
extension MicroscopicAuroraError { case generation(Int), witness(String) }   // r02-g19.generation, r02-g19.witness
extension MicroscopicAuroraLevel {
    public static let budgets: ClosedRange<Int>          // 1 … 24 (was 1 … 12)
    public static let siteCounts: ClosedRange<Int>       // 2 … 8
    public let sites: [MicroscopicAuroraCell]?           // nil: anywhere (feature 481); else row-major, distinct
    public func allows(_ cell: MicroscopicAuroraCell) -> Bool   // usable, and a site when sites are listed
    // init gains `sites: [MicroscopicAuroraCell]? = nil` (refusals "sites", "site outside", "sites duplicate",
    // "well not on a site")
}
// MicroscopicAuroraPlay: a placement on a cell the level does not allow is refused .action("not a site").
// MicroscopicAuroraPuzzle: with sites, moves place wells on sites only (≤ 3 × 8 × 8 = 192 placements).
public struct MicroscopicAuroraManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int; public let emphasis: String }
public enum MicroscopicAuroraManifest { public static let entries: [MicroscopicAuroraManifestEntry]   // 100
    public static let provenance: String }
public struct MicroscopicAuroraBandProfile: Sendable, Equatable { public let swarm: ClosedRange<Int>
    public let lengths: ClosedRange<Int>; public let sites: Int; public let plan: Int
    public let stencil: ClosedRange<Int>; public let coverage: ClosedRange<Int>
    public static func of(band: Int) -> Self }
public struct MicroscopicAuroraPlan: Sendable, Equatable, Codable { public let actions: [MicroscopicAuroraAction]
    public let wells: [MicroscopicAuroraWell]
    public let setsByDepth: [Int]     // sets judged at depths 0 … size − 1 (depth 0 is no well: 1)
    public let nearestMiss: Int; public let work: Int; public var size: Int { get } }
public enum MicroscopicAuroraSolver {
    public static let workBound: Int        // 1,200 sets judged
    public static func plan(_ level: MicroscopicAuroraLevel, workBound: Int = workBound) -> MicroscopicAuroraPlan?
    public static func sets(sites: [MicroscopicAuroraCell], size: Int) -> [[MicroscopicAuroraWell]]   // fixed order
    public static func loss(_ level: MicroscopicAuroraLevel, report: MicroscopicAuroraReport) -> Int
    public static func placements(_ wells: [MicroscopicAuroraWell]) -> [MicroscopicAuroraAction]       // slot order
    public static func replayWins(_ level: MicroscopicAuroraLevel, actions: [MicroscopicAuroraAction]) -> Bool }
public struct MicroscopicAuroraDifficulty: Sendable, Hashable, Codable { public let placements, stencil, coverage,
    swarm, sites, setsSearched, work, nearestMiss: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct MicroscopicAuroraGenerated: Sendable, Equatable { public let entry: MicroscopicAuroraManifestEntry
    public let level: MicroscopicAuroraLevel; public let plan: MicroscopicAuroraPlan
    public let difficulty: MicroscopicAuroraDifficulty; public let skipped: Int }
public enum MicroscopicAuroraGenerator {
    public static let catalogID: String     // "microscopic-aurora"
    public static let maxCandidates: Int    // 64
    public static func levelID(_ number: Int) -> String   // microscopic-aurora-NNN
    public static func candidate(_ entry: MicroscopicAuroraManifestEntry, index: Int) -> MicroscopicAuroraLevel?
    public static func generate(_ entry: MicroscopicAuroraManifestEntry, previous: MicroscopicAuroraLevel?)
        throws(MicroscopicAuroraError) -> MicroscopicAuroraGenerated
    public static func catalog() throws(MicroscopicAuroraError) -> [MicroscopicAuroraGenerated]   // manifest order
    public static func catalogDigest(_ levels: [MicroscopicAuroraLevel]) -> String }
public struct MicroscopicAuroraCounterexample: Sendable, Hashable, Codable {
    public let depth: Int; public let sets: Int; public let nearestMiss: Int }
public struct MicroscopicAuroraWitnessReport: Sendable, Equatable, Codable { /* lit stencil cells, coverage, groups,
    smallest coherence and its tick, ticks swum */ }
public struct MicroscopicAuroraWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static let schema: Int                                                         // 1
    public static func canonicalText(wells: [MicroscopicAuroraWell?], spent: Int) -> String
    public static func digest(wells: [MicroscopicAuroraWell?], spent: Int) -> String      // first 16 hex of SHA-256
    public static func make(_ generated: MicroscopicAuroraGenerated) throws(MicroscopicAuroraError) -> Self
    public static func decode(_ data: Data) throws(MicroscopicAuroraError) -> Self; public func encoded() -> Data }
```
