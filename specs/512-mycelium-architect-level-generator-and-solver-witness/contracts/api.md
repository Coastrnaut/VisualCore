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

## Public names beyond this contract (feature 512 convergence, T-R02G2202-014)

The implementation exposes these additional public names; each is documented in the source:

- `MyceliumArchitectBandProfile` and `band(_:)`: the measured band profiles (research R4), read by the generator tests
  and later features (hints, presentation of difficulty).
- `MyceliumArchitectGenerator.catalogID` ("mycelium-architect") and `candidateBound` (1 024): the digest id and the
  candidate bound, named once for the tests.
- `MyceliumArchitectManifest.provenance`: where the entries come from.
- `MyceliumArchitectLevel.isSite(_:)` and `siteCounts`: the play's and puzzle's placement rule and the site range.
- `MyceliumArchitectSolution.length` and its initializer: the plan length, and solutions built by the witness and tests.
- `MyceliumArchitectDifficulty.init(level:solution:)`: the metrics computed from a level and its solution.
- `MyceliumArchitectWitnessReport` (with `Terminal` and `ToxicEntry`) and `MyceliumArchitectCounterexample`: the
  witness file's terminal growth report and counterexample as typed values; `MyceliumArchitectWitness`'s stored fields
  and `canonicalText(arrangement:spent:)` and `digest(arrangement:spent:)`, the per-action state digest.

`MyceliumArchitectWitness.verify()` regenerates the accepted candidate without a previous level: the candidate draw does
not depend on the previous level, only the neighbour rule's skip does, and the neighbour rule is checked by the catalog
tests over the whole catalog.
