# API contract: R02-G07-01 (AmethystEscapeCore)

```swift
public enum AmethystEscapeError: Error, Equatable, Sendable { case level(String), action(String), stage, stale, stuck,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g07.*
public struct AmethystEscapeShell: Sendable, Hashable, Codable { public let apertures: [Int]; public let walls: [Int]
    public let blocked: [Int] }
public struct AmethystEscapeLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(AmethystEscapeError);
    encoded() -> Data; static func decode(_:) throws(AmethystEscapeError) -> Self; fingerprint */
    public var exitGap: Int { get }                                       // the outermost shell's one aperture (own sector)
    public func shellName(_ shell: Int) -> String                         // "shell 1 (inner)" … "shell K (outer)"
    public func sectorName(_ sector: Int) -> String                       // "sector s of N", 1-based
    public func description(ofShell shell: Int) -> String }               // apertures, walls and wedges in words (FR-R02G0701-013)
public struct AmethystEscapePocket: Sendable, Hashable, Codable { public let shell: Int; public let sector: Int }
public enum AmethystEscapeTransition: Sendable, Equatable { case moved(AmethystEscapePocket), exited, wedge(AmethystEscapePocket), stuck }
public struct AmethystEscapeCrystal: Sendable, Hashable, Codable {
    public private(set) var offsets: [Int]; public private(set) var pearl: AmethystEscapePocket
    public init(level: AmethystEscapeLevel)
    public func ownSector(_ pocket: AmethystEscapePocket, level: AmethystEscapeLevel) -> Int
    public func rotating(shell: Int, step: Int, level: AmethystEscapeLevel) -> Self   // step ±1; the pearl rides its shell
    public func transition(level: AmethystEscapeLevel) -> AmethystEscapeTransition    // clarification Q2
}
public enum AmethystEscapeFailure: Sendable, Hashable, Codable { case wedge(Int, Int), budget; public var code: String }
public enum AmethystEscapeAction: Sendable, Hashable, Codable { case rotate(Int, Int), advance }
public enum AmethystEscapeStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum AmethystEscapeEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum AmethystEscapeRecordKind: String, Sendable, Codable { case rotate, advance, undo, redo }
public struct AmethystEscapeRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64; public let move: Int
    public let kind: AmethystEscapeRecordKind; public let action: AmethystEscapeAction?; public let previous: String; public let next: String }
public struct AmethystEscapePlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: AmethystEscapeLevel
    public private(set) var stage: AmethystEscapeStage, crystal: AmethystEscapeCrystal, moves: Int,
        failure: AmethystEscapeFailure?, records: [AmethystEscapeRecord]
    public var fingerprint: String { get }; public var remaining: Int { get }; public var canUndo, canRedo: Bool { get }
    public init(level: AmethystEscapeLevel)
    public mutating func handle(_ event: AmethystEscapeEvent) throws(AmethystEscapeError)        // .stage
    public mutating func apply(_ action: AmethystEscapeAction, expecting previous: String) throws(AmethystEscapeError)
        // order: .stage, .stale, .action("range"), .stuck
    public mutating func undo() throws(AmethystEscapeError); public mutating func redo() throws(AmethystEscapeError)
    public static func replay(level: AmethystEscapeLevel, records: [AmethystEscapeRecord]) throws(AmethystEscapeError) -> AmethystEscapePlay
}
public struct AmethystEscapeRules: PuzzleRules {
    public struct Position: Hashable, Codable, Sendable { public enum Outcome: String { case playing, won, failed }
        public let crystal: AmethystEscapeCrystal; public let moves: Int; public let outcome: Outcome }
    /* State = Position, Move = AmethystEscapeAction; rulesID "r02-g07-amethyst-escape";
    moves while playing: rotate(r, +1), rotate(r, −1) for each shell r in order, then advance unless it is stuck */ }
```
