# API contract: R02-G05-02 (ColorfallCanyonsCore additions)

```swift
extension ColorfallCanyonsError { case generation(Int) /* r02-g05.generation */; case witness(String) /* r02-g05.witness */ }
public struct ColorfallCanyonsManifestEntry: Sendable, Equatable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum ColorfallCanyonsManifest { public static let entries: [ColorfallCanyonsManifestEntry] }   // 100
public enum ColorfallCanyonsEdit: Sendable, Hashable, Codable, Comparable { case carve(Int), valve(Int)   // carves before valves, by index
    public var action: ColorfallCanyonsAction }
public struct ColorfallCanyonsCounterexample: Sendable, Equatable, Codable { public let edits: [ColorfallCanyonsEdit]
    public let reason: ColorfallCanyonsFailure; public let tick: Int }
public struct ColorfallCanyonsSolution: Sendable, Equatable { public let edits: [ColorfallCanyonsEdit]
    public var smallest: Int { edits.count }; public let work: Int; public let smaller: Int; public let winTick: Int }
public enum ColorfallCanyonsSolver {
    public static let maximumDepth = 4
    public static func moves(_ level: ColorfallCanyonsLevel) -> [ColorfallCanyonsEdit]   // carvable cells, then springs
    public static func routing(_ level: ColorfallCanyonsLevel, heights: [Int]) -> [Int?]   // every cell's downhill
    public static func run(_ level: ColorfallCanyonsLevel, edits: [ColorfallCanyonsEdit]) -> (verdict: ColorfallCanyonsVerdict, tick: Int)?  // nil: illegal set
    public static func solve(_ level: ColorfallCanyonsLevel, depth: Int = maximumDepth) -> ColorfallCanyonsSolution?
}
public struct ColorfallCanyonsDifficulty: Sendable, Equatable, Codable { public let smallest: Int; public let work: Int
    public let winTick: Int; public let springs: Int; public let basins: Int; public let protectedBasins: Int
    public let carvableCells: Int }
public struct ColorfallCanyonsBandProfile: Sendable, Equatable { public let columns: Int; public let rows: Int
    public let springs: Int; public let depressions: Int; public let smallest: ClosedRange<Int>; public static func of(band: Int) -> Self }
public struct ColorfallCanyonsGenerated: Sendable, Equatable { public let entry: ColorfallCanyonsManifestEntry
    public let level: ColorfallCanyonsLevel; public let planted: [ColorfallCanyonsEdit]; public let solution: ColorfallCanyonsSolution
    public let difficulty: ColorfallCanyonsDifficulty; public let skipped: Int }
public enum ColorfallCanyonsGenerator {
    public static let tutorialLevels: ClosedRange<Int>   // 1 … 3
    public static let maximumCandidates = 256
    public static func candidate(_ entry: ColorfallCanyonsManifestEntry, index: Int) -> (level: ColorfallCanyonsLevel, planted: [ColorfallCanyonsEdit])?
    public static func generate(_ entry: ColorfallCanyonsManifestEntry) throws(ColorfallCanyonsError) -> ColorfallCanyonsGenerated
    public static func catalogDigest(_ levels: [ColorfallCanyonsLevel]) -> String
}
public struct ColorfallCanyonsWitness: Sendable, Equatable, Codable {
    public static let schema = 1
    public static func actions(for solution: ColorfallCanyonsSolution, level: ColorfallCanyonsLevel) -> [ColorfallCanyonsAction]
    public static func make(_ generated: ColorfallCanyonsGenerated) throws(ColorfallCanyonsError) -> Self
    public func encoded() -> Data
    public static func decode(_ data: Data) throws(ColorfallCanyonsError) -> Self   // refuses newer, damaged, non-replaying
}
```
