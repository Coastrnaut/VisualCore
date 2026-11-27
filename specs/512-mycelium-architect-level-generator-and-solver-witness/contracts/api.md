# API contract: R02-G22-02 (additions to MyceliumArchitectCore)

```swift
extension MyceliumArchitectError { case generation(Int); case witness(String) }   // r02-g22.generation, .witness
extension MyceliumArchitectLevel {
    public let sites: [MyceliumArchitectCell]?                                   // nil: placements anywhere (feature 511)
    // public init gains `sites: [MyceliumArchitectCell]? = nil` (last parameter)
}
public struct MyceliumArchitectManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let plannedSeed: UInt64; public let band: Int; public let budget: Int; public let emphasis: String
    public let concept: String }
public enum MyceliumArchitectManifest { public static let entries: [MyceliumArchitectManifestEntry] }   // 100
public struct MyceliumArchitectDifficulty: Sendable, Hashable, Codable { public let witnessLength: Int
    public let terminals: Int; public let boardCells: Int; public let toxins: Int; public let sites: Int
    public let moveSpace: Int; public let searchedBelow: Int; public let work: Int; public let nearestMiss: Int }
public struct MyceliumArchitectSolution: Sendable, Equatable { public let actions: [MyceliumArchitectAction]
    public let work: Int; public let countsByDepth: [Int]; public let nearestMissLoss: Int
    public let nearestMiss: MyceliumArchitectArrangement; public let nearestMissFailure: MyceliumArchitectFailure? }
public enum MyceliumArchitectSolver {
    public static let workBound: Int                                             // 20 000
    public static func loss(_ level: MyceliumArchitectLevel, _ report: MyceliumArchitectReport) -> Int
    public static func solve(_ level: MyceliumArchitectLevel, maxDepth: Int) -> MyceliumArchitectSolution? }
public struct MyceliumArchitectGeneratedLevel: Sendable, Equatable { public let entry: MyceliumArchitectManifestEntry
    public let level: MyceliumArchitectLevel; public let solution: MyceliumArchitectSolution
    public let difficulty: MyceliumArchitectDifficulty; public let skipped: Int }
public enum MyceliumArchitectGenerator {
    public static func generate(_ entry: MyceliumArchitectManifestEntry, previous: MyceliumArchitectLevel?)
        throws(MyceliumArchitectError) -> MyceliumArchitectGeneratedLevel
    public static func catalog() throws(MyceliumArchitectError) -> [MyceliumArchitectGeneratedLevel]
    public static func digest(_ levels: [MyceliumArchitectLevel]) -> String }
public struct MyceliumArchitectWitness: Sendable, Equatable, Codable {
    public static let schema: Int                                                // 1
    public init(generated: MyceliumArchitectGeneratedLevel)
    public func encoded() -> Data
    public static func decode(_ data: Data) throws(MyceliumArchitectError) -> MyceliumArchitectWitness
    public func verify() throws(MyceliumArchitectError) }                         // replays the actions; .witness on mismatch
```
