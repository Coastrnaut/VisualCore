# API contract: R02-G05-01 (ColorfallCanyonsCore)

```swift
public enum ColorfallCanyonsError: Error, Equatable, Sendable { case level(String), action(String), stage, stale, budget,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g05.*
public enum ColorfallCanyonsColor: Int, Sendable, Codable, CaseIterable { case cyan, coral, yellow; public var name: String }
public enum ColorfallCanyonsCellKind: Sendable, Hashable, Codable { case open, rock, spring(Int), basin(Int), drain }
public struct ColorfallCanyonsCell: Sendable, Hashable, Codable { public let height: Int; public let kind: ColorfallCanyonsCellKind }
public struct ColorfallCanyonsSpring: Sendable, Hashable, Codable { public let cell: Int; public let color: ColorfallCanyonsColor
    public let release: Int; public let supply: Int; public let open: Bool }
public struct ColorfallCanyonsBasin: Sendable, Hashable, Codable { public let cell: Int; public let capacity: Int; public let fill: Int
    public let shares: [Int]; public let tolerance: Int; public let isProtected: Bool; public let toleratedWrong: Int
    public func wrongMass(_ masses: [Int]) -> Int; public func accepts(_ masses: [Int]) -> Bool }
public struct ColorfallCanyonsLevel: Sendable, Equatable { /* fields per data-model.md; init throws(ColorfallCanyonsError);
    encoded() -> Data; static func decode(_:) throws(ColorfallCanyonsError) -> Self; fingerprint */
    public func neighbours(of cell: Int) -> [Int]        // east, south, west, north; in-grid only
    public func isCarvable(_ cell: Int, heights: [Int]) -> Bool }
public enum ColorfallCanyonsFailure: String, Sendable, Codable, CaseIterable { case contamination, overflow, time }
public enum ColorfallCanyonsVerdict: Sendable, Equatable { case running, won, failed(ColorfallCanyonsFailure) }
public struct ColorfallCanyonsFluid: Sendable, Hashable, Codable {
    public private(set) var tick: Int, heights: [Int], valves: [Bool], supplies: [Int], masses: [[Int]], spilled: [Int], released: [Int]
    public init(level: ColorfallCanyonsLevel)
    public func downhill(of cell: Int, level: ColorfallCanyonsLevel) -> Int?    // nil: pool, basin, drain or rock
    public static func share(_ r: Int, of masses: [Int]) -> [Int]            // largest remainder, ties to lower colour
    public mutating func tick(level: ColorfallCanyonsLevel)                  // one synchronous step
    public func isConserved() -> Bool                                        // released == Σ masses + spilled per colour
    public func verdict(level: ColorfallCanyonsLevel) -> ColorfallCanyonsVerdict   // contamination, overflow, win, time
}
public enum ColorfallCanyonsAction: Sendable, Hashable, Codable { case carve(Int), valve(Int), step(Int) }
public enum ColorfallCanyonsStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum ColorfallCanyonsEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum ColorfallCanyonsRecordKind: String, Sendable, Codable { case carve, valve, step, undo, redo }
public struct ColorfallCanyonsRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64; public let tick: Int
    public let kind: ColorfallCanyonsRecordKind; public let action: ColorfallCanyonsAction?; public let previous: String; public let next: String }
public struct ColorfallCanyonsPlay: Sendable, Equatable {
    public static var schema: Int { 1 }; public static let steps: ClosedRange<Int>   // 1 … 600
    public let level: ColorfallCanyonsLevel
    public private(set) var stage: ColorfallCanyonsStage, fluid: ColorfallCanyonsFluid, spent: Int,
        failure: ColorfallCanyonsFailure?, records: [ColorfallCanyonsRecord]
    public var fingerprint: String { get }; public var remaining: Int { get }; public var canUndo, canRedo: Bool { get }
    public init(level: ColorfallCanyonsLevel)
    public mutating func handle(_ event: ColorfallCanyonsEvent) throws(ColorfallCanyonsError)        // .stage
    public mutating func apply(_ action: ColorfallCanyonsAction, expecting previous: String) throws(ColorfallCanyonsError)
        // order: .stage, .stale, .action("range" | "not-carvable"), .budget
    public mutating func undo() throws(ColorfallCanyonsError); public mutating func redo() throws(ColorfallCanyonsError)
    public static func replay(level: ColorfallCanyonsLevel, records: [ColorfallCanyonsRecord]) throws(ColorfallCanyonsError) -> ColorfallCanyonsPlay
}
public struct ColorfallCanyonsRules: PuzzleRules { /* State = Position (fluid, spent, outcome), Move = ColorfallCanyonsAction;
    moves: carve(c) for each carvable cell in index order, valve(s) for each spring, step(1) */ }
```
