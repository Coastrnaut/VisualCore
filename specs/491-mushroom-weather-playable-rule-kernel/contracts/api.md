# API contract: R02-G20-01 (MushroomWeatherCore)

```swift
public enum MushroomWeatherError: Error, Equatable, Sendable { case level(String), action(String), budget, stage,
    stale, newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g20.*
public struct MushroomWeatherCell: Sendable, Hashable, Codable, Comparable { public let row: Int
    public let column: Int }                                            // row-major order
public struct MushroomWeatherVent: Sendable, Hashable, Codable { public let cell: MushroomWeatherCell
    public let openRate: Int; public let closedRate: Int }
public struct MushroomWeatherColony: Sendable, Hashable, Codable { public let cell: MushroomWeatherCell
    public let low: Int; public let high: Int; public let survivalFloor: Int? }   // nil: not sensitive
public struct MushroomWeatherPodRules: Sendable, Hashable, Codable { public let slots: Int; public let release: Int
    public let grownRelease: Int; public let growthThreshold: Int }
public struct MushroomWeatherArrangement: Sendable, Hashable, Codable { public let pods: [MushroomWeatherCell?]
    public let ventsOpen: [Bool]; public let moonlight: Int }
public enum MushroomWeatherFailure: Sendable, Hashable, Codable {
    case dried(colony: Int, cycle: Int); case mold(cell: MushroomWeatherCell, cycle: Int)
    case unstable(colony: Int, run: Int)
    public var code: String }                                           // dried, mold, unstable
public struct MushroomWeatherLedger: Sendable, Hashable, Codable { public let cycle: Int; public let before: Int
    public let released: Int; public let evaporated: Int; public let after: Int }
public struct MushroomWeatherColonyRuns: Sendable, Hashable { public let finalRun: Int; public let longestRun: Int
    public let firstOutOfBand: Int? }
public struct MushroomWeatherReport: Sendable, Equatable { public let cycles: Int
    public let humidity: [Int]                                          // row-major, blocked cells 0
    public let ledger: [MushroomWeatherLedger]; public let grownAt: [Int?]   // per pod slot
    public let colonies: [MushroomWeatherColonyRuns]
    public let failure: MushroomWeatherFailure?; public var wins: Bool { get } }
public enum MushroomWeatherForest {
    public static let maximumHumidity: Int                              // 10000
    public static func cycle(_ humidity: [Int], level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement,
        grown: [Bool]) -> (humidity: [Int], ledger: MushroomWeatherLedger)   // ledger.cycle 0; run sets it
    public static func run(_ level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement,
        keepFields: Bool) -> (report: MushroomWeatherReport, fields: [[Int]])
    public static func report(_ level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement)
        -> MushroomWeatherReport }
public struct MushroomWeatherLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init
    throws(MushroomWeatherError); encoded() -> Data; static func decode(_:) throws(MushroomWeatherError) -> Self;
    fingerprint; isFloor(_:); index(of:) */
    public func podDescription(_ slot: Int, cell: MushroomWeatherCell?, grownAt: Int?) -> String
        // "pod 2 at row 3, column 7, grown at cycle 18"
    public func colonyDescription(_ index: Int, report: MushroomWeatherReport) -> String
        // "colony 1 at row 5, column 2: 412 units, band 380 … 520, in band for the last 12 of 12 cycles"
    public func progressDescription(report: MushroomWeatherReport, arrangement: MushroomWeatherArrangement,
        actionsLeft: Int) -> String }
public enum MushroomWeatherAction: Sendable, Hashable, Codable { case place(slot: Int, cell: MushroomWeatherCell)
    case remove(slot: Int); case vent(index: Int, open: Bool); case moonlight(level: Int); case run }
public enum MushroomWeatherStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing,
    paused, won, failed, result }
public enum MushroomWeatherEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public struct MushroomWeatherRecord: Sendable, Equatable, Codable { /* per data-model.md */ }
public struct MushroomWeatherPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: MushroomWeatherLevel
    public private(set) var stage: MushroomWeatherStage, arrangement: MushroomWeatherArrangement, actionsSpent: Int,
        report: MushroomWeatherReport, failure: MushroomWeatherFailure?, records: [MushroomWeatherRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }
    public var canUndo, canRedo: Bool { get }
    public init(level: MushroomWeatherLevel)
    public mutating func handle(_ event: MushroomWeatherEvent) throws(MushroomWeatherError)
    public mutating func apply(_ action: MushroomWeatherAction, expecting previous: String)
        throws(MushroomWeatherError)                                    // order: .stage, .stale, .action, .budget
    public mutating func undo() throws(MushroomWeatherError); public mutating func redo() throws(MushroomWeatherError)
    public static func replay(level: MushroomWeatherLevel, records: [MushroomWeatherRecord])
        throws(MushroomWeatherError) -> MushroomWeatherPlay
}
public struct MushroomWeatherPuzzle: PuzzleRules { /* State = Position, Move = MushroomWeatherAction (arrangement
    actions only); rulesID "r02-g20-mushroom-weather"; goal: the predicted run wins */ }
```

The forest's step functions live in `MushroomWeatherForest` and the puzzle contract is `MushroomWeatherPuzzle`, so
the game's name does not clash with its weather type.
