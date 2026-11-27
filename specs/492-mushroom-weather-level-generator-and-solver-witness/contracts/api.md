# API contract: R02-G20-02 (additions to MushroomWeatherCore)

```swift
extension MushroomWeatherError { case generation(Int), witness(String) }   // r02-g20.generation, r02-g20.witness
extension MushroomWeatherLevel {
    public static let budgets: ClosedRange<Int>          // 1 … 24 (was 1 … 12)
    public static let siteCounts: ClosedRange<Int>       // 2 … 8
    public let sites: [MushroomWeatherCell]?             // nil: any free floor cell (feature 491); else row-major
    public func allowsPod(_ cell: MushroomWeatherCell) -> Bool   // true without sites; else only on a site
    // init gains `sites: [MushroomWeatherCell]? = nil` (refusals "sites", "sites duplicate", "site off floor",
    // "site on colony", "pod not on a site")
}
// MushroomWeatherPlay: a placement on a cell the level does not allow is refused .action("not a site").
// MushroomWeatherPuzzle: with sites, placement moves use sites only.
public struct MushroomWeatherManifestEntry: Sendable, Hashable, Codable { public let number: Int
    public let seed: UInt64; public let band: Int; public let budget: Int; public let emphasis: String }
public enum MushroomWeatherManifest { public static let entries: [MushroomWeatherManifestEntry]   // 100
    public static let provenance: String }
public struct MushroomWeatherBandProfile: Sendable, Equatable { public let rows, columns, blocked: ClosedRange<Int>
    public let vents, slots, colonies, sites, plan: Int; public let margin: ClosedRange<Int>
    public static func of(band: Int) -> Self }
public struct MushroomWeatherPlan: Sendable, Equatable, Codable { public let actions: [MushroomWeatherAction]
    public let arrangement: MushroomWeatherArrangement
    public let arrangementsByDepth: [Int]   // judged at depths 0 … size − 1 (depth 0 is the start: 1)
    public let nearestMiss: Int; public let work: Int; public var size: Int { get } }
public enum MushroomWeatherSolver {
    public static let workBound: Int        // 1,500 arrangements judged
    public static func plan(_ level: MushroomWeatherLevel, workBound: Int = workBound) -> MushroomWeatherPlan?
    public static func arrangements(_ level: MushroomWeatherLevel, depth: Int) -> [MushroomWeatherArrangement]
        // fixed order: pod count, vent count, pod and vent combinations, moonlight
    public static func distance(_ arrangement: MushroomWeatherArrangement, from start: MushroomWeatherArrangement)
        -> Int
    public static func loss(_ level: MushroomWeatherLevel, report: MushroomWeatherReport) -> Int
    public static func actions(_ arrangement: MushroomWeatherArrangement, level: MushroomWeatherLevel)
        -> [MushroomWeatherAction]          // placements in slot order, vent toggles, moonlight
    public static func replayWins(_ level: MushroomWeatherLevel, actions: [MushroomWeatherAction]) -> Bool }
public struct MushroomWeatherDifficulty: Sendable, Hashable, Codable { public let actions, colonies, narrowestBand,
    sites, vents, arrangementsSearched, work, nearestMiss: Int
    public var puzzleDifficulty: PuzzleDifficulty { get } }
public struct MushroomWeatherGenerated: Sendable, Equatable { public let entry: MushroomWeatherManifestEntry
    public let level: MushroomWeatherLevel; public let plan: MushroomWeatherPlan
    public let difficulty: MushroomWeatherDifficulty; public let skipped: Int }
public enum MushroomWeatherGenerator {
    public static let catalogID: String     // "mushroom-weather"
    public static let maxCandidates: Int    // 64
    public static func levelID(_ number: Int) -> String   // mushroom-weather-NNN
    public static func candidate(_ entry: MushroomWeatherManifestEntry, index: Int) -> MushroomWeatherLevel?
    public static func generate(_ entry: MushroomWeatherManifestEntry, previous: MushroomWeatherLevel?)
        throws(MushroomWeatherError) -> MushroomWeatherGenerated
    public static func catalog() throws(MushroomWeatherError) -> [MushroomWeatherGenerated]   // manifest order
    public static func catalogDigest(_ levels: [MushroomWeatherLevel]) -> String }
public struct MushroomWeatherCounterexample: Sendable, Hashable, Codable {
    public let depth: Int; public let arrangements: Int; public let nearestMiss: Int }
public struct MushroomWeatherWitnessReport: Sendable, Equatable, Codable { /* ledger totals (start, released,
    evaporated, end), each colony's final run, longest run and first cycle out of band, cycles run */ }
public struct MushroomWeatherWitness: Sendable, Equatable, Codable { /* fields per data-model.md */
    public static let schema: Int                                                         // 1
    public static func canonicalText(arrangement: MushroomWeatherArrangement, spent: Int) -> String
    public static func digest(arrangement: MushroomWeatherArrangement, spent: Int) -> String   // first 16 hex
    public static func make(_ generated: MushroomWeatherGenerated) throws(MushroomWeatherError) -> Self
    public static func decode(_ data: Data) throws(MushroomWeatherError) -> Self; public func encoded() -> Data }
```
