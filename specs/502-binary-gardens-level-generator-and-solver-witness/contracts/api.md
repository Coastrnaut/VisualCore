# API contract: R02-G21-02 (additions to BinaryGardensCore)

Existing names are feature 501's, as committed (`BinaryGardensLevel`, `BinaryGardensStar`, `BinaryGardensWorld`,
`BinaryGardensArrangement`, `BinaryGardensReport`, `BinaryGardensWorldLight`, `BinaryGardensBloom`,
`BinaryGardensFailure`, `BinaryGardensAction`, `BinaryGardensSky`, `BinaryGardensPlay`, `BinaryGardensPuzzle`,
`BinaryGardensError`). Every new public name carries `///` documentation.

```swift
extension BinaryGardensError { case generation(Int), witness(String) }   // r02-g21.generation, r02-g21.witness

extension BinaryGardensLevel {
    public static let phaseSteps: [Int]          // [1, 2, 3, 4, 6, 8, 12, 16, 24]
    public let phaseStep: Int                    // 1 (feature 501's behaviour) or a listed divisor
    public func allowsPhase(_ step: Int) -> Bool // 0 … 47 and a multiple of phaseStep
    // public init gains a trailing `phaseStep: Int = 1`; refusals "phase step", "phase off grid" after
    // "nothing adjustable", before "separation" and "already won"; the internal probe(...) gains `phaseStep: Int = 1` and the internal init(…, refusingAWin:) a `phaseStep` parameter;
    // Content gains `phaseStep: Int?` (nil when 1, so omitted from the stored form and the fingerprint text).
}
// BinaryGardensSky.changed: a phase step that is not a multiple of the level's phaseStep is refused
//   .action("off the phase grid") after "phase out of range", before "locked" (the play and the puzzle both call it).
// BinaryGardensSky.isWellFormed: phases must also lie on the grid.
// BinaryGardensPuzzle.moves(in:): phase moves on the grid only (candidates 0, g, 2g, …).

public struct BinaryGardensManifestEntry: Sendable, Hashable, Codable {
    public let number: Int; public let seed: UInt64; public let band: Int; public let budget: Int
    public let emphasis: String
    public init(number: Int, seed: UInt64, band: Int, budget: Int, emphasis: String) }
public enum BinaryGardensManifest {
    public static let entries: [BinaryGardensManifestEntry]   // 100, from planning_index.py levels --experience R02-G21
    public static let provenance: String }                    // round2.md section 6.21.18

public enum BinaryGardensControl: Int, Sendable, Hashable, Codable, CaseIterable {
    case star1Ring, star1Phase, star1Luminosity, star2Ring, star2Phase, star2Luminosity, tilt   // fixed order
    public func isAdjustable(in level: BinaryGardensLevel) -> Bool
    public func values(in level: BinaryGardensLevel) -> [Int]          // legal values ascending (phases on the grid)
    public func value(of arrangement: BinaryGardensArrangement) -> Int
    public func action(_ value: Int) -> BinaryGardensAction
    public func setting(_ value: Int, in arrangement: BinaryGardensArrangement) -> BinaryGardensArrangement }

public struct BinaryGardensPlan: Sendable, Equatable, Codable {
    public let actions: [BinaryGardensAction]            // parent chain from the start; `run` not included
    public let arrangement: BinaryGardensArrangement     // the winning arrangement
    public let arrangementsByDepth: [Int]                // judged at depths 0 … size − 1 (depth 0: 1)
    public let nearestMiss: Int                          // smallest loss at depths 0 … size − 1
    public let nearestMissArrangement: BinaryGardensArrangement
    public let work: Int                                 // arrangements judged, the winning one included
    public var size: Int { get } }                       // actions.count

public enum BinaryGardensSolver {
    public static let workBound: Int                     // 5_000
    public static func plan(_ level: BinaryGardensLevel, maxDepth: Int,
                            workBound: Int = workBound) -> BinaryGardensPlan?
        // breadth-first by actions from the start; depth d + 1 expands depth d in ascending loss (ties: discovery
        // order) with BinaryGardensPuzzle(level:).moves(in:), skipping arrangements already reached at any depth; nil without a
        // win within maxDepth (the band's p, never the budget) or over workBound
    public static func loss(_ level: BinaryGardensLevel, report: BinaryGardensReport) -> Int
    public static func replayWins(_ level: BinaryGardensLevel, actions: [BinaryGardensAction]) -> Bool
        // begin, dismissTutorial when the level has one, each action against the current fingerprint, then run
}

public struct BinaryGardensDifficulty: Sendable, Hashable, Codable {
    public let actions, worlds, narrowestBand, tightestWindow, adjustable, moveSpace, arrangementsSearched, work,
        nearestMiss: Int
    public init(level: BinaryGardensLevel, plan: BinaryGardensPlan)
    public var puzzleDifficulty: PuzzleDifficulty { get } }   // shortest: actions, explored: work

public struct BinaryGardensBandProfile: Sendable, Equatable {
    public let adjustable: Int; public let rings: ClosedRange<Int>; public let ringRadii: ClosedRange<Int>
    public let luminosities: ClosedRange<Int>; public let phaseStep: Int; public let maxTilt: ClosedRange<Int>
    public let worlds: ClosedRange<Int>; public let separation: ClosedRange<Int>; public let maxStarSpeed: Int
    public let trim: Int; public let comfortMargin: ClosedRange<Int>; public let lethalMargin: Int
    public let bloomMargin: Int; public let windowSlack: ClosedRange<Int>; public let tolerance: ClosedRange<Int>
    public let plan: Int
    public static func of(band: Int) -> Self }

public struct BinaryGardensGenerated: Sendable, Equatable {
    public let entry: BinaryGardensManifestEntry; public let level: BinaryGardensLevel
    public let plan: BinaryGardensPlan; public let difficulty: BinaryGardensDifficulty; public let skipped: Int }

public enum BinaryGardensGenerator {
    public static let catalogID: String       // "binary-gardens"
    public static let maxCandidates: Int      // 64
    public static let maxRedraws: Int         // 16
    public static func levelID(_ number: Int) -> String   // binary-gardens-NNN
    public static func candidate(_ entry: BinaryGardensManifestEntry, index: Int) -> BinaryGardensLevel?
        // nil: separation not kept within the redraws, c_lo = 0, λ_hi > 200 000, refused by the level, reducible
    public static func generate(_ entry: BinaryGardensManifestEntry, previous: BinaryGardensLevel?)
        throws(BinaryGardensError) -> BinaryGardensGenerated   // .generation(number) after maxCandidates
    public static func catalog() throws(BinaryGardensError) -> [BinaryGardensGenerated]   // manifest order
    public static func catalogDigest(_ levels: [BinaryGardensLevel]) -> String }
    // internal, tested by agent C: drawing order, bounds(flux:trim:comfort:lethal:bloom:slack:) and isReducible

public struct BinaryGardensCounterexample: Sendable, Hashable, Codable {
    public let depth: Int; public let arrangements: Int; public let nearestMiss: Int
    public let arrangement: BinaryGardensArrangement; public let failure: BinaryGardensFailure }
public struct BinaryGardensWitnessReport: Sendable, Hashable, Codable {
    public struct World: Sendable, Hashable, Codable { public let integral, meanWhole, meanRemainder,
        longestLethalRun, tolerance, window, windowStart, requiredWindow: Int; public let bloom: BinaryGardensBloom }
    public let worlds: [World]; public let minimumSeparationSquared: Int; public let minimumSeparationTick: Int
    public let outcome: String                                                   // "won"
    public init(level: BinaryGardensLevel, report: BinaryGardensReport) }
public struct BinaryGardensWitness: Sendable, Equatable, Codable {   // fields per data-model.md
    public static let schema: Int                                     // 1
    public static func canonicalText(arrangement: BinaryGardensArrangement, spent: Int) -> String
        // "rings=a,b;phases=a,b;luminosities=a,b;tilt=t;spent=s"
    public static func digest(arrangement: BinaryGardensArrangement, spent: Int) -> String   // first 16 hex
    public static func make(_ generated: BinaryGardensGenerated) throws(BinaryGardensError) -> Self
    public static func decode(_ data: Data) throws(BinaryGardensError) -> Self
        // .newerSchema(s); .witness("unreadable" | "schema s" | "level" | "number" | "skipped" | "actions" |
        // "replay <reason>" | "candidate" | "solution" | "counterexample" | "difficulty" | "digests" |
        // "fingerprints" | "report")
    public func encoded() -> Data }                                   // sorted keys, pretty, trailing newline
```
