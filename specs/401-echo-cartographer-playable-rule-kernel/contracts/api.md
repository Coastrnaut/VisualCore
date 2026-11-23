# API contract: R02-G11-01 (EchoCartographerCore)

```swift
public enum EchoCartographerError: Error, Equatable, Sendable { case level(String), action(String), noop, stage, stale,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g11.*
public struct EchoCartographerCell: Sendable, Hashable, Codable, Comparable { public let x: Int; public let y: Int }
public enum EchoCartographerDirection: String, Sendable, Codable, CaseIterable { case north, east, south, west }
public struct EchoCartographerRay: Sendable, Equatable, Codable { public let direction: EchoCartographerDirection
    public let open: [EchoCartographerCell]; public let wall: EchoCartographerCell?; public let distance: Int
    public var delay: Int { get } }                                          // 24 * distance
public struct EchoCartographerEcho: Sendable, Equatable, Codable { public let emitter: EchoCartographerCell
    public let rays: [EchoCartographerRay]; public let beaconDistances: [Int]; public var beaconDelays: [Int] { get } }
public struct EchoCartographerChamber: Sendable, Hashable, Codable {
    public static let sizeRange: ClosedRange<Int>                            // 5 ... 16
    public static let ticksPerCell: Int                                       // 24 (round trip)
    public let width: Int; public let height: Int; public let walls: Set<Int> // cell indices y * width + x
    public init(width: Int, height: Int, walls: Set<Int>) throws(EchoCartographerError)
    public func isInside(_ cell: EchoCartographerCell) -> Bool; public func isWall(_ cell: EchoCartographerCell) -> Bool
    public func index(_ cell: EchoCartographerCell) -> Int; public func cell(_ index: Int) -> EchoCartographerCell
    public func ray(from: EchoCartographerCell, _ direction: EchoCartographerDirection) -> EchoCartographerRay
    public func pathLengths(from: EchoCartographerCell) -> [Int?]           // per index; nil when unreachable or a wall
    public func echo(from: EchoCartographerCell, beacons: [EchoCartographerCell]) -> EchoCartographerEcho
}
public struct EchoCartographerLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(EchoCartographerError);
    encoded() -> Data; static func decode(_:) throws(EchoCartographerError) -> Self; fingerprint */
    public func cellName(_ cell: EchoCartographerCell, knowledge: EchoCartographerKnowledge) -> String // "column 3, row 5: open"
    public func echoDescription(_ echo: EchoCartographerEcho) -> String   // "north: wall at 2 cells; …; echoes at 3, 7 cells"
    public func progressDescription(located: Int, energy: Int) -> String } // "1 of 3 beacons located, 7 energy left"
public enum EchoCartographerKnown: String, Sendable, Codable { case unknown, open, wall }
public struct EchoCartographerKnowledge: Sendable, Hashable, Codable { public subscript(_ index: Int) -> EchoCartographerKnown }
public enum EchoCartographerFailure: Sendable, Hashable, Codable { case energy(Int); public var code: String } // the action index
public enum EchoCartographerAction: Sendable, Hashable, Codable { case pulse(Int, Int), claim(Int, Int), mark(Int, Int) }
public enum EchoCartographerStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum EchoCartographerEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum EchoCartographerRecordKind: String, Sendable, Codable { case pulse, claim, mark, undo, redo }
public struct EchoCartographerRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let index: Int; public let kind: EchoCartographerRecordKind; public let action: EchoCartographerAction?
    public let previous: String; public let next: String }
public struct EchoCartographerPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: EchoCartographerLevel
    public private(set) var stage: EchoCartographerStage, knowledge: EchoCartographerKnowledge,
        markers: [EchoCartographerCell], located: [Int: EchoCartographerCell], energy: Int,
        lastEcho: EchoCartographerEcho?, failure: EchoCartographerFailure?, records: [EchoCartographerRecord]
    public var localizationErrors: [Int] { get }; public var totalLocalizationError: Int { get }
    public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: EchoCartographerLevel)
    public mutating func handle(_ event: EchoCartographerEvent) throws(EchoCartographerError)        // .stage
    public mutating func apply(_ action: EchoCartographerAction, expecting previous: String) throws(EchoCartographerError)
        // order: .stage, .stale, .action, .noop
    public mutating func undo() throws(EchoCartographerError); public mutating func redo() throws(EchoCartographerError)
    public static func replay(level: EchoCartographerLevel, records: [EchoCartographerRecord]) throws(EchoCartographerError) -> EchoCartographerPlay
}
public struct EchoCartographerRules: PuzzleRules { /* State = Position (knowledge, located, energy, outcome),
    Move = EchoCartographerAction (pulse and claim only); rulesID "r02-g11-echo-cartographer";
    moves while playing: pulses then claims, each in cell-index order; var initialState: Position */ }
```
