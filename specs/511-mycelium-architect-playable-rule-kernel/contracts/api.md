# API contract: R02-G22-01 (MyceliumArchitectCore)

Every public symbol carries `///` documentation; everything a consumer does not need is `internal`. Tips and terminals
are 0-based in code and numbered from 1 in words.

```swift
public enum MyceliumArchitectError: Error, Equatable, Sendable { case level(String), action(String), budget, stage,
    stale, newerSchema(Int), malformed(String); public var reasonCode: String }
    // r02-g22.level, .action, .budget, .stage, .stale, .newer-schema, .malformed
public struct MyceliumArchitectCell: Sendable, Hashable, Codable, Comparable { public let column: Int
    public let row: Int; public init(column: Int, row: Int) }           // ordered by (row, column)
public enum MyceliumArchitectDirection: Int, Sendable, Codable, CaseIterable { case north, northEast, east,
    southEast, south, southWest, west, northWest
    public var offset: (column: Int, row: Int) { get }; public var isDiagonal: Bool { get }
    public func turn(to other: MyceliumArchitectDirection) -> Int; public var words: String { get } }
public struct MyceliumArchitectArrangement: Sendable, Hashable, Codable { public let nutrients: [MyceliumArchitectCell]
    public let blockers: [MyceliumArchitectCell]; public let seeds: [MyceliumArchitectDirection] }   // sorted
public enum MyceliumArchitectFailure: Sendable, Hashable, Codable {
    case toxic(pulse: Int, tip: Int, cell: MyceliumArchitectCell)
    case starved(pulse: Int, tip: Int, cell: MyceliumArchitectCell, weight: Int, budget: Int)
    case unreached(terminal: Int); case overweight(weight: Int, limit: Int)
    public var code: String }                                           // toxic, starved, unreached, overweight
public struct MyceliumArchitectStep: Sendable, Equatable { public let pulse: Int; public let tip: Int
    public let from: MyceliumArchitectCell; public let direction: MyceliumArchitectDirection
    public let to: MyceliumArchitectCell; public let score: Int; public let weight: Int
    public let consumed: Bool; public let newTip: Int? }
public struct MyceliumArchitectReport: Sendable, Equatable {
    public let field: [[Int]]                                           // [row][column], before growth
    public let steps: [MyceliumArchitectStep]
    public let grown: [MyceliumArchitectCell: Int]                      // cell → pulse grown (root: 0)
    public let parents: [MyceliumArchitectCell: MyceliumArchitectCell]
    public let nodeCount: Int; public let totalWeight: Int; public let pulsesRun: Int
    public let terminalPulses: [Int?]; public let terminalPathWeights: [Int?]
    public let failure: MyceliumArchitectFailure?; public var wins: Bool { get } }
public enum MyceliumArchitectGrowth {
    public static let orthogonalWeight: Int                             // 2
    public static let diagonalWeight: Int                               // 3
    public static let nodeCap: Int                                      // 2048
    public static func field(_ level: MyceliumArchitectLevel, nutrients: [MyceliumArchitectCell]) -> [[Int]]
    public static func report(_ level: MyceliumArchitectLevel, arrangement: MyceliumArchitectArrangement)
        -> MyceliumArchitectReport }                                    // growth and judge: starved, toxic, unreached, overweight
public struct MyceliumArchitectLevel: Sendable, Equatable, Codable {
    public static let schema: Int                                       // 1
    public let id: String; public let seed: UInt64; public let difficulty: Int
    public let width: Int; public let height: Int; public let root: MyceliumArchitectCell
    public let terminals: [MyceliumArchitectCell]; public let rocks: [MyceliumArchitectCell]
    public let toxins: [MyceliumArchitectCell]; public let fixedNutrients: [MyceliumArchitectCell]
    public let strength: Int; public let reach: Int; public let curvature: Int; public let obstacle: Int
    public let maxNutrients: Int; public let maxBlockers: Int; public let maxSeeds: Int
    public let startSeeds: [MyceliumArchitectDirection]; public let pulses: Int
    public let nutrientBudget: Int; public let weightLimit: Int; public let budget: Int
    public let tutorial: Bool; public let fingerprint: String
    public init(id: String, seed: UInt64, difficulty: Int, width: Int, height: Int, root: MyceliumArchitectCell,
        terminals: [MyceliumArchitectCell], rocks: [MyceliumArchitectCell], toxins: [MyceliumArchitectCell],
        fixedNutrients: [MyceliumArchitectCell], strength: Int, reach: Int, curvature: Int, obstacle: Int,
        maxNutrients: Int, maxBlockers: Int, maxSeeds: Int, startSeeds: [MyceliumArchitectDirection], pulses: Int,
        nutrientBudget: Int, weightLimit: Int, budget: Int, tutorial: Bool) throws(MyceliumArchitectError)
    public var start: MyceliumArchitectArrangement { get }
    public func isEmpty(_ cell: MyceliumArchitectCell, in arrangement: MyceliumArchitectArrangement) -> Bool
    public func encoded() -> Data
    public static func decode(_ data: Data) throws(MyceliumArchitectError) -> MyceliumArchitectLevel
    public func cellDescription(_ cell: MyceliumArchitectCell, arrangement: MyceliumArchitectArrangement,
        report: MyceliumArchitectReport) -> String
        // "(9, 4): nutrient value 36, empty, grown at pulse 7"
    public func stepDescription(_ step: MyceliumArchitectStep) -> String
        // "tip 2 at pulse 7: east to (9, 4), score 12"
    public func terminalDescription(_ terminal: Int, report: MyceliumArchitectReport) -> String
        // "terminal 1 reached at pulse 11, path weight 23"
    public func failureDescription(_ failure: MyceliumArchitectFailure) -> String
        // "tip 3 grew into toxin at (5, 6) on pulse 9"
    public func progressDescription(report: MyceliumArchitectReport, actionsLeft: Int) -> String
        // "branch weight 41 of 48, budget 60; 2 of 3 terminals reached; 4 actions left"
}
public enum MyceliumArchitectAction: Sendable, Hashable, Codable { case nutrient(MyceliumArchitectCell)
    case blocker(MyceliumArchitectCell); case clear(MyceliumArchitectCell)
    case seed(MyceliumArchitectDirection); case unseed(MyceliumArchitectDirection); case run }
public enum MyceliumArchitectStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing,
    paused, won, failed, result }
public enum MyceliumArchitectEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public struct MyceliumArchitectRecord: Sendable, Equatable, Codable { public let schema: Int
    public let levelSeed: UInt64; public let index: Int; public let kind: Kind
    public let action: MyceliumArchitectAction?; public let previous: String; public let next: String
    public enum Kind: String, Sendable, Codable, CaseIterable { case nutrient, blocker, clear, seed, unseed, run,
        undo, redo, begin, dismissTutorial, pause, resume, showResult } }
public struct MyceliumArchitectPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: MyceliumArchitectLevel
    public private(set) var stage: MyceliumArchitectStage, arrangement: MyceliumArchitectArrangement,
        actionsSpent: Int, report: MyceliumArchitectReport, failure: MyceliumArchitectFailure?,
        records: [MyceliumArchitectRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }
    public var canUndo: Bool { get }; public var canRedo: Bool { get }
    public init(level: MyceliumArchitectLevel)
    public mutating func handle(_ event: MyceliumArchitectEvent) throws(MyceliumArchitectError)
    public mutating func apply(_ action: MyceliumArchitectAction, expecting previous: String)
        throws(MyceliumArchitectError)                                  // order: .stage, .stale, .action, .budget
    public mutating func undo() throws(MyceliumArchitectError); public mutating func redo() throws(MyceliumArchitectError)
    public static func replay(level: MyceliumArchitectLevel, records: [MyceliumArchitectRecord])
        throws(MyceliumArchitectError) -> MyceliumArchitectPlay        // another level or a broken chain: .malformed
}
public struct MyceliumArchitectPuzzle: PuzzleRules {
    public struct Position: Hashable, Codable, Sendable { public let arrangement: MyceliumArchitectArrangement
        public let actionsSpent: Int; public init(arrangement: MyceliumArchitectArrangement, actionsSpent: Int) }
    public typealias State = Position; public typealias Move = MyceliumArchitectAction   // arrangement actions only
    public let level: MyceliumArchitectLevel
    public init(level: MyceliumArchitectLevel)
    public var rulesID: String { get }                                  // "r02-g22-mycelium-architect"
    public var initialState: Position { get }
    public func moves(in state: Position) -> [MyceliumArchitectAction]  // order of research R14
    public func apply(_ move: MyceliumArchitectAction, to state: Position) -> Position?
    public func isSolved(_ state: Position) -> Bool }                   // MyceliumArchitectGrowth.report(...).wins
```

`MyceliumArchitectPlay` and `MyceliumArchitectPuzzle` agree: a move is legal in the puzzle exactly when
`apply(_:expecting:)` accepts it in `playing` with actions left, and both produce the same arrangement. No existing
module's API changes; no VisualCore API baseline update is needed.
