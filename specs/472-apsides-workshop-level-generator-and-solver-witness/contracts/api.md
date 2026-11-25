# API contract: R02-G18-02 (additions to ApsidesWorkshopCore)

```swift
extension ApsidesWorkshopError { case generation(Int), witness(String) }   // r02-g18.generation, r02-g18.witness
public struct ApsidesWorkshopManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int; public let emphasis: String }
public enum ApsidesWorkshopManifest { public static let entries: [ApsidesWorkshopManifestEntry]   // 100
    public static let provenance: String }
public struct ApsidesWorkshopBandProfile: Sendable, Equatable { public let periods: [Int]
    public let targets: ClosedRange<Int>; public let apsisTargets: ClosedRange<Int>
    public let sweepHalfWidth: ClosedRange<Int>; public let apsisHalfWidth: ClosedRange<Int>
    public let planets: ClosedRange<Int>; public let levers: ClosedRange<Int>; public let planRange: ClosedRange<Int>
    public static func of(band: Int) -> Self }
public struct ApsidesWorkshopPlan: Sendable, Equatable, Codable { public let actions: [ApsidesWorkshopAction]
    public let orbit: ApsidesWorkshopOrbit
    public let orbitsByDepth: [Int]   // orbits judged at depths 0 … size − 1 (depth 0 is the start: 1)
    public let work: Int; public var size: Int { get } }
public enum ApsidesWorkshopSolver {
    public static let workBound: Int        // 16 000 orbits judged
    public static func plan(_ level: ApsidesWorkshopLevel, workBound: Int = workBound) -> ApsidesWorkshopPlan?
    public static func orbits(from start: ApsidesWorkshopOrbit, depth: Int) -> [ApsidesWorkshopOrbit]  // in search order
    public static func tunings(from start: ApsidesWorkshopOrbit, to target: ApsidesWorkshopOrbit)
        -> [ApsidesWorkshopAction]                                      // a valid order
    public static func wins(_ level: ApsidesWorkshopLevel, orbit: ApsidesWorkshopOrbit) -> Bool }
public struct ApsidesWorkshopDifficulty: Sendable, Hashable, Codable { public let tunings, targets, apsisTargets,
    planets, narrowestShareBand, narrowestDistanceRange, orbitsSearched, work: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct ApsidesWorkshopGenerated: Sendable, Equatable { public let entry: ApsidesWorkshopManifestEntry
    public let level: ApsidesWorkshopLevel; public let plan: ApsidesWorkshopPlan
    public let difficulty: ApsidesWorkshopDifficulty; public let skipped: Int }
public enum ApsidesWorkshopGenerator {
    public static let catalogID: String     // "apsides-workshop"
    public static let maxCandidates: Int    // 256
    public static func levelID(_ number: Int) -> String   // apsides-workshop-NNN
    public static func candidate(_ entry: ApsidesWorkshopManifestEntry, index: Int) -> ApsidesWorkshopLevel?
    public static func generate(_ entry: ApsidesWorkshopManifestEntry, previous: ApsidesWorkshopLevel?)
        throws(ApsidesWorkshopError) -> ApsidesWorkshopGenerated
    public static func catalog() throws(ApsidesWorkshopError) -> [ApsidesWorkshopGenerated]   // manifest order
    public static func catalogDigest(_ levels: [ApsidesWorkshopLevel]) -> String }
public struct ApsidesWorkshopCounterexample: Sendable, Hashable, Codable {
    public let depth: Int       // plan.size − 1
    public let orbits: Int      // orbits judged at exactly that depth (none won)
    public init(depth: Int, orbits: Int) }
public struct ApsidesWorkshopWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static let schema: Int                                                    // 1
    public static func canonicalText(orbit: ApsidesWorkshopOrbit, spent: Int) -> String  // "orbit=24,5,6;spent=2"
    public static func digest(orbit: ApsidesWorkshopOrbit, spent: Int) -> String         // first 16 hex of SHA-256
    public static func make(_ generated: ApsidesWorkshopGenerated) throws(ApsidesWorkshopError) -> Self
    public static func decode(_ data: Data) throws(ApsidesWorkshopError) -> Self; public func encoded() -> Data }
```
