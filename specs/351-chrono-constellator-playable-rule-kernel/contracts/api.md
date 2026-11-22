# API contract: R02-G06-01 (ChronoConstellatorCore)

```swift
public enum ChronoConstellatorError: Error, Equatable, Sendable { case level(String), action(String), stage, stale, budget,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g06.*
public enum ChronoConstellatorShape: Int, Sendable, Codable, CaseIterable { case ring, cross, diamond, triangle, square; public var name: String }
public struct ChronoConstellatorStar: Sendable, Hashable, Codable { public let loop: [Int]; public let phase: Int; public let target: Int
    public var description: String }   // "star n (shape): loop of L cells, target row r, column c" (FR-R02G0601-013)
public struct ChronoConstellatorLevel: Sendable, Equatable { /* fields per data-model.md; init throws(ChronoConstellatorError);
    encoded() -> Data; static func decode(_:) throws(ChronoConstellatorError) -> Self; fingerprint; cellCount; isNeighbour(_:_:) */ }
public struct ChronoConstellatorHold: Sendable, Hashable, Codable { public let star: Int; public let start: Int; public let length: Int }
public struct ChronoConstellatorTimeline: Sendable, Hashable, Codable {
    public private(set) var phases: [Int]; public private(set) var holds: [ChronoConstellatorHold]
    public init(level: ChronoConstellatorLevel)
    public func editsInUse(level: ChronoConstellatorLevel) -> Int
    public func held(star: Int, through tick: Int) -> Int
    public func position(star: Int, at tick: Int, level: ChronoConstellatorLevel) -> Int   // closed form, clarification Q2
    public func positions(at tick: Int, level: ChronoConstellatorLevel) -> [Int]
    public var fingerprint: String { get }                                                  // the signed snapshot
}
public enum ChronoConstellatorFailure: Sendable, Hashable, Codable { case collision(Int, Int, Int), time; public var code: String }
public enum ChronoConstellatorVerdict: Sendable, Equatable { case running, won, failed(ChronoConstellatorFailure) }
public enum ChronoConstellatorEvaluation { public static func verdict(positions: [Int], tick: Int, level: ChronoConstellatorLevel) -> ChronoConstellatorVerdict }
public enum ChronoConstellatorAction: Sendable, Hashable, Codable { case phase(Int, Int), hold(Int, Int, Int), release(Int, Int), step(Int), rewind }
public enum ChronoConstellatorStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum ChronoConstellatorEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum ChronoConstellatorRecordKind: String, Sendable, Codable { case phase, hold, release, step, rewind, undo, redo }
public struct ChronoConstellatorRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64; public let tick: Int
    public let kind: ChronoConstellatorRecordKind; public let action: ChronoConstellatorAction?; public let previous: String; public let next: String }
public struct ChronoConstellatorPlay: Sendable, Equatable {
    public static var schema: Int { 1 }; public static let steps: ClosedRange<Int>   // 1 … 1,200
    public let level: ChronoConstellatorLevel
    public private(set) var stage: ChronoConstellatorStage, tick: Int, timeline: ChronoConstellatorTimeline,
        failure: ChronoConstellatorFailure?, records: [ChronoConstellatorRecord]
    public var fingerprint: String { get }; public var remaining: Int { get }; public var canUndo, canRedo: Bool { get }
    public init(level: ChronoConstellatorLevel)
    public mutating func handle(_ event: ChronoConstellatorEvent) throws(ChronoConstellatorError)        // .stage
    public mutating func apply(_ action: ChronoConstellatorAction, expecting previous: String) throws(ChronoConstellatorError)
        // order: .stage, .stale, .action("range" | "not-at-start" | "same-phase" | "overlap" | "no-hold"), .budget
    public mutating func undo() throws(ChronoConstellatorError); public mutating func redo() throws(ChronoConstellatorError)
    public static func replay(level: ChronoConstellatorLevel, records: [ChronoConstellatorRecord]) throws(ChronoConstellatorError) -> ChronoConstellatorPlay
}
public struct ChronoConstellatorRules: PuzzleRules { /* State = Position (timeline, tick, outcome), Move = ChronoConstellatorAction;
    moves at tick 0: phase(i, o) for each star and offset in order, hold(i, s, k) on a bounded grid of starts and lengths,
    then step(tick limit) */ }
```
