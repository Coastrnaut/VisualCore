# API contract: R02-G06-01 (ChronoConstellatorCore)

```swift
public enum ChronoConstellatorError: Error, Equatable, Sendable { case level(String), action(String), stage, stale, budget,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g06.*
public enum ChronoConstellatorShape: Int, Sendable, Codable, CaseIterable { case ring, cross, diamond, triangle, square; public var name: String }
public struct ChronoConstellatorStar: Sendable, Hashable, Codable { public let loop: [Int]; public let phase: Int; public let target: Int
    public var length: Int { get } }
public struct ChronoConstellatorLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(ChronoConstellatorError);
    encoded() -> Data; static func decode(_:) throws(ChronoConstellatorError) -> Self; fingerprint; cellCount */
    public static func isNeighbour(_ a: Int, _ b: Int, columns: Int) -> Bool; public func isNeighbour(_ a: Int, _ b: Int) -> Bool
    public static func shape(of index: Int) -> ChronoConstellatorShape      // star i has shape i
    public func place(_ cell: Int) -> String                              // "row r, column c", 1-based
    public func description(ofStar index: Int) -> String }  // "star n (shape): loop of L cells, target row r, column c" (FR-R02G0601-013)
public struct ChronoConstellatorHold: Sendable, Hashable, Codable, Comparable { public let star: Int; public let start: Int
    public let length: Int; public var end: Int { get } }                  // ordered by star, then start
public struct ChronoConstellatorTimeline: Sendable, Hashable, Codable {
    public private(set) var phases: [Int]; public private(set) var holds: [ChronoConstellatorHold]
    public init(level: ChronoConstellatorLevel)
    public func editsInUse(level: ChronoConstellatorLevel) -> Int
    public func held(star: Int, through tick: Int) -> Int
    public func isHeld(star: Int, on tick: Int) -> Bool
    public func settingPhase(star:to:level:) throws(ChronoConstellatorError) -> Self   // range, same-phase, budget
    public func adding(_ hold: ChronoConstellatorHold, level:) throws(ChronoConstellatorError) -> Self   // range, overlap, budget
    public func releasing(star:start:level:) throws(ChronoConstellatorError) -> Self   // range, no-hold
    public func position(star: Int, at tick: Int, level: ChronoConstellatorLevel) -> Int   // closed form, clarification Q2
    public func positions(at tick: Int, level: ChronoConstellatorLevel) -> [Int]
    public var fingerprint: String { get }                                                  // the signed snapshot
}
public enum ChronoConstellatorFailure: Sendable, Hashable, Codable { case collision(Int, Int, Int), time
    public var code: String }   // "collision" or "time"
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
    public var fingerprint: String { get }; public var spent: Int { get }   // edits in use
    public var remaining: Int { get }; public var positions: [Int] { get }; public var canUndo, canRedo: Bool { get }
    public init(level: ChronoConstellatorLevel)
    public mutating func handle(_ event: ChronoConstellatorEvent) throws(ChronoConstellatorError)        // .stage
    public mutating func apply(_ action: ChronoConstellatorAction, expecting previous: String) throws(ChronoConstellatorError)
        // order: .stage, .stale, .action("range" | "not-at-start" | "same-phase" | "overlap" | "no-hold"), .budget
    public mutating func undo() throws(ChronoConstellatorError); public mutating func redo() throws(ChronoConstellatorError)
    public static func replay(level: ChronoConstellatorLevel, records: [ChronoConstellatorRecord]) throws(ChronoConstellatorError) -> ChronoConstellatorPlay
}
public struct ChronoConstellatorRules: PuzzleRules {
    public struct Position: Hashable, Codable, Sendable { public enum Outcome: String { case playing, won, failed }
        public let timeline: ChronoConstellatorTimeline; public let tick: Int; public let outcome: Outcome }
    public static let holdStarts: ClosedRange<Int>   // 1 … 32
    public static let holdLengths: ClosedRange<Int>  // 1 … 32
    /* State = Position, Move = ChronoConstellatorAction; rulesID "r02-g06-chrono-constellator";
    moves at tick 0: phase(i, o) for each star i and offset o ≠ current in order, then hold(i, s, k) for each star i, start
    s 1 … 32 and length k 1 … 32 in that order (skipping those the play refuses), then release(i, s) for each hold, then
    step(tick limit); after tick 0 only rewind */ }
```
