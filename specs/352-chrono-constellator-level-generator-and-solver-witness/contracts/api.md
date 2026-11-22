# API contract: R02-G06-02 (additions to ChronoConstellatorCore)

```swift
extension ChronoConstellatorError { case generation(Int), witness(String) }   // r02-g06.generation, r02-g06.witness
public struct ChronoConstellatorManifestEntry: Sendable, Hashable, Codable { public let number: Int; public let seed: UInt64
    public let band: Int; public let budget: Int }
public enum ChronoConstellatorManifest { public static let entries: [ChronoConstellatorManifestEntry]   // 100, manifest order
    public static let provenance: String }
public struct ChronoConstellatorBandProfile: Sendable, Equatable { public let columns, rows, stars: Int
    public let smallest: ClosedRange<Int>; public let blocked: Int; public static func of(band: Int) -> Self }
public struct ChronoConstellatorSolution: Sendable, Equatable { public let lowerBound: Int; public let phases: [Int]
    public let window: Int; public let windows: Int; public let blocked: Int; public let work: Int }
public enum ChronoConstellatorSolver {
    public static func misaligned(_ level: ChronoConstellatorLevel, at tick: Int) -> Int          // m(T)
    public static func windowPhases(_ level: ChronoConstellatorLevel, window tick: Int) -> [Int]  // phase-only timeline
    public static func isBlocked(_ level: ChronoConstellatorLevel, window tick: Int) -> Bool
    public static func solve(_ level: ChronoConstellatorLevel) -> ChronoConstellatorSolution? }
public struct ChronoConstellatorDifficulty: Sendable, Hashable, Codable { public let smallest, winTick, stars: Int
    public let loopLengths: [Int]; public let windows, blocked: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }   // shortest = smallest, explored = windows (R02-F24)
public struct ChronoConstellatorGenerated: Sendable, Equatable { public let entry: ChronoConstellatorManifestEntry
    public let level: ChronoConstellatorLevel; public let solution: ChronoConstellatorSolution
    public let difficulty: ChronoConstellatorDifficulty; public let skipped: Int }
public enum ChronoConstellatorGenerator {
    public static let catalogID: String    // "chrono-constellator"
    public static let maxCandidates: Int   // 512
    public static func levelID(_ number: Int) -> String   // chrono-constellator-NNN
    public static func rectangle(column: Int, row: Int, width: Int, height: Int, columns: Int) -> [Int]   // clockwise loop
    public static func winTick(_ level: ChronoConstellatorLevel, timeline: ChronoConstellatorTimeline) -> Int?
    public static func timeline(_ level: ChronoConstellatorLevel, solution: ChronoConstellatorSolution) -> ChronoConstellatorTimeline?
    public static func candidate(_ entry: ChronoConstellatorManifestEntry, index: Int) -> ChronoConstellatorLevel?
    public static func generate(_ entry: ChronoConstellatorManifestEntry) throws(ChronoConstellatorError) -> ChronoConstellatorGenerated
    public static func catalogDigest(_ levels: [ChronoConstellatorLevel]) -> String }
public struct ChronoConstellatorCounterexample: Sendable, Equatable, Codable { public let actions: [ChronoConstellatorAction]
    public let reason: ChronoConstellatorFailure; public let tick: Int }   // the full failure (a collision names stars and cell)
public struct ChronoConstellatorWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static func phaseChanges(for: ChronoConstellatorSolution, level: ChronoConstellatorLevel) -> [ChronoConstellatorAction]
    public static func actions(for: ChronoConstellatorSolution, level: ChronoConstellatorLevel) -> [ChronoConstellatorAction]
    public static func digest(_ positions: [Int]) -> String   // first 16 hex of SHA-256 over each cell as two bytes big-endian
    public static func make(_ generated: ChronoConstellatorGenerated) throws(ChronoConstellatorError) -> Self
    public static func decode(_ data: Data) throws(ChronoConstellatorError) -> Self; public func encoded() -> Data }
```
