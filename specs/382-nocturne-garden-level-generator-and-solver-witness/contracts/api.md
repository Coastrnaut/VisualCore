# API contract: R02-G09-02 (additions to NocturneGardenCore)

```swift
extension NocturneGardenError { case generation(Int), witness(String) }   // r02-g09.generation, r02-g09.witness
public struct NocturneGardenManifestEntry: Sendable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum NocturneGardenManifest { public static let entries: [NocturneGardenManifestEntry]   // 100, manifest order
    public static let provenance: String }
public struct NocturneGardenBandProfile: Sendable, Equatable { /* fields per data-model.md */
    public static func of(band: Int) -> Self }
public struct NocturneGardenBound: Sendable, Hashable, Codable { public let elevation: Int; public let needed: Int
    public let cover: Int; public let sunMove: Bool; public var smallest: Int { get } }
public struct NocturneGardenSolution: Sendable, Equatable, Codable { public let smallest: Int
    public let actions: [NocturneGardenAction]; public let work: Int }
public enum NocturneGardenSolver {
    public static let workBound: Int                                         // 20,000 plant evaluations
    public static func needed(_ level: NocturneGardenLevel) -> Int           // least shared count meeting p/q vs |T|
    public static func cover(_ level: NocturneGardenLevel, elevation: Int) -> Int
    public static func lowerBound(_ level: NocturneGardenLevel) -> NocturneGardenBound
    public static func solve(_ level: NocturneGardenLevel, workBound: Int = workBound) -> NocturneGardenSolution? }
public struct NocturneGardenDifficulty: Sendable, Hashable, Codable { public let smallest, kinds, sizes, targetCells,
    forbiddenCells, work: Int; public let sunChange: Bool; public let required: NocturneGardenRatio
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct NocturneGardenGenerated: Sendable, Equatable { public let entry: NocturneGardenManifestEntry
    public let level: NocturneGardenLevel; public let solution: NocturneGardenSolution
    public let bound: NocturneGardenBound; public let difficulty: NocturneGardenDifficulty; public let skipped: Int }
public enum NocturneGardenGenerator {
    public static let catalogID: String    // "nocturne-garden"
    public static let maxCandidates: Int   // 256
    public static func levelID(_ number: Int) -> String   // nocturne-garden-NNN
    public static func candidate(_ entry: NocturneGardenManifestEntry, index: Int) -> NocturneGardenLevel?
    public static func generate(_ entry: NocturneGardenManifestEntry) throws(NocturneGardenError) -> NocturneGardenGenerated
    public static func catalogDigest(_ levels: [NocturneGardenLevel]) -> String }
public struct NocturneGardenCounterexample: Sendable, Equatable, Codable { public let actions: [NocturneGardenAction]
    public let shared: Int; public let needed: Int }
public struct NocturneGardenWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func digest(_ mask: NocturneGardenMask) -> String   // first 16 hex of SHA-256 of the sorted cells
    public static func make(_ generated: NocturneGardenGenerated) throws(NocturneGardenError) -> Self
    public static func decode(_ data: Data) throws(NocturneGardenError) -> Self; public func encoded() -> Data }
```
