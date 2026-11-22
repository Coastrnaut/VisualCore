# API contract: R02-G09-01 (NocturneGardenCore)

```swift
public enum NocturneGardenError: Error, Equatable, Sendable { case level(String), action(String), supply, noop, stage,
    stale, newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g09.*
public enum NocturneGardenKind: String, Sendable, CaseIterable, Codable { case tulip, bell, star, fern, rose, lily
    public var outline: [NocturneGardenLattice] { get }; public var name: String { get } }
public struct NocturneGardenLattice: Sendable, Hashable, Codable { public let x: Int; public let y: Int }
public struct NocturneGardenBloom: Sendable, Hashable, Codable, Comparable {
    public let kind: NocturneGardenKind; public let column: Int; public let row: Int; public let size: Int
    public func castPolygon(elevation: Int) -> [NocturneGardenLattice]       // doubled coordinates
    public func cells(elevation: Int, width: Int, height: Int) -> Set<Int>    // row-major indices in the bed
}
public struct NocturneGardenMask: Sendable, Hashable { public let width: Int; public let height: Int
    public let cells: Set<Int>
    public static func union(_ blooms: [NocturneGardenBloom], elevation: Int, width: Int, height: Int) -> Self
    public func intersection(_ other: Set<Int>) -> Int; public func union(_ other: Set<Int>) -> Int
    public static func matches(mask: Self, target: Set<Int>, required: NocturneGardenRatio) -> Bool
    public static func boundaryDeviation(_ a: Set<Int>, _ b: Set<Int>, width: Int, height: Int) -> Int }
public struct NocturneGardenRatio: Sendable, Hashable, Codable { public let numerator: Int; public let denominator: Int }
public struct NocturneGardenLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(NocturneGardenError);
    encoded() -> Data; static func decode(_:) throws(NocturneGardenError) -> Self; fingerprint */
    public func bloomName(_ index: Int, bloom: NocturneGardenBloom) -> String  // "bloom 1: tulip at column 3, row 0, size 2"
    public func targetDescription() -> String }                                 // FR-R02G0901-013
public enum NocturneGardenFailure: Sendable, Hashable, Codable { case leak(Int), budget; public var code: String }  // leak(move)
public enum NocturneGardenAction: Sendable, Hashable, Codable { case plant(NocturneGardenKind, Int, Int, Int),
    move(Int, Int, Int), resize(Int, Int), remove(Int), sun(Int) }
public enum NocturneGardenStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum NocturneGardenEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum NocturneGardenRecordKind: String, Sendable, Codable { case plant, move, resize, remove, sun, undo, redo }
public struct NocturneGardenRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let move: Int; public let kind: NocturneGardenRecordKind; public let action: NocturneGardenAction?
    public let previous: String; public let next: String }
public struct NocturneGardenPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: NocturneGardenLevel
    public private(set) var stage: NocturneGardenStage, blooms: [NocturneGardenBloom], elevation: Int, moves: Int,
        failure: NocturneGardenFailure?, records: [NocturneGardenRecord]
    public var mask: NocturneGardenMask { get }; public var match: (shared: Int, either: Int) { get }
    public var leak: Int { get }; public var deviation: Int { get }
    public var fingerprint: String { get }; public var remaining: Int { get }; public var canUndo, canRedo: Bool { get }
    public init(level: NocturneGardenLevel)
    public mutating func handle(_ event: NocturneGardenEvent) throws(NocturneGardenError)          // .stage
    public mutating func apply(_ action: NocturneGardenAction, expecting previous: String) throws(NocturneGardenError)
        // order: .stage, .stale, .action(range), .supply, .noop
    public mutating func undo() throws(NocturneGardenError); public mutating func redo() throws(NocturneGardenError)
    public static func replay(level: NocturneGardenLevel, records: [NocturneGardenRecord]) throws(NocturneGardenError) -> NocturneGardenPlay
}
public struct NocturneGardenRules: PuzzleRules { /* State = Position (blooms, sun, moves, outcome), Move = NocturneGardenAction;
    rulesID "r02-g09-nocturne-garden"; moves while playing in the order of data-model.md */ }
```
