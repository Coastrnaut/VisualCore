# API contract: R02-G08-02 (additions to FacetedForgeCore)

```swift
extension FacetedForgeError { case generation(Int), witness(String) }   // r02-g08.generation, r02-g08.witness
// FacetedForgeLevel.budgets widens to 1...20 and FacetedForgeLevel.faceCounts to 4...34.
public struct FacetedForgeManifestEntry: Sendable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum FacetedForgeManifest { public static let entries: [FacetedForgeManifestEntry]   // 100, manifest order
    public static let provenance: String }
public struct FacetedForgeBandProfile: Sendable, Equatable { public let band: Int; public let cuts: ClosedRange<Int>
    public let directions: [Int]; public static func of(band: Int) -> Self }
public struct FacetedForgeSolution: Sendable, Equatable, Codable { public let smallest: Int
    public let actions: [FacetedForgeAction]; public let work: Int }
public enum FacetedForgeSolver {
    public static let workBound: Int                                      // 20,000 cut evaluations
    public static func lowerBound(_ level: FacetedForgeLevel) -> Int      // target pieces − 1
    public static func canPartition(_ pieces: [FacetedForgePiece], into target: [FacetedForgeTargetPiece],
                                    crystal: FacetedForgeFraction) -> Bool
    public static func solve(_ level: FacetedForgeLevel, workBound: Int = workBound) -> FacetedForgeSolution? }
public struct FacetedForgeDifficulty: Sendable, Hashable, Codable { public let smallest, directions, diagonals,
    crystalFaces, pieces, work: Int; public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct FacetedForgeGenerated: Sendable, Equatable { public let entry: FacetedForgeManifestEntry
    public let level: FacetedForgeLevel; public let solution: FacetedForgeSolution
    public let difficulty: FacetedForgeDifficulty; public let skipped: Int }
public enum FacetedForgeGenerator {
    public static let catalogID: String    // "faceted-forge"
    public static let maxCandidates: Int   // 256
    public static let sliver: FacetedForgeFraction   // 1/64
    public static func levelID(_ number: Int) -> String   // faceted-forge-NNN
    public static func candidate(_ entry: FacetedForgeManifestEntry, index: Int) -> FacetedForgeLevel?
    public static func generate(_ entry: FacetedForgeManifestEntry) throws(FacetedForgeError) -> FacetedForgeGenerated
    public static func catalogDigest(_ levels: [FacetedForgeLevel]) -> String }
public struct FacetedForgeCounterexample: Sendable, Equatable, Codable { public let actions: [FacetedForgeAction]
    public let outcome: String; public let cut: Int }   // "open", "sliver" or "budget"
public struct FacetedForgeWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func digest(_ pieces: [FacetedForgePiece]) -> String   // first 16 hex of SHA-256 of the corners
    public static func make(_ generated: FacetedForgeGenerated) throws(FacetedForgeError) -> Self
    public static func decode(_ data: Data) throws(FacetedForgeError) -> Self; public func encoded() -> Data }
```
