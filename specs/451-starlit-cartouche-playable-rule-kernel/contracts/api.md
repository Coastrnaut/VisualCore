# API contract: R02-G16-01 (StarlitCartoucheCore)

```swift
public enum StarlitCartoucheError: Error, Equatable, Sendable { case level(String), action(String), stage, stale,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g16.*
public struct StarlitCartoucheVector: Sendable, Hashable, Codable { public let x: Int; public let y: Int; public let z: Int
    public func squaredDistance(to other: Self) -> Int }
public struct StarlitCartoucheGlyphPoint: Sendable, Hashable, Codable { public let x: Int; public let y: Int }
public struct StarlitCartoucheStar: Sendable, Hashable, Codable { public let orbit: [StarlitCartoucheVector]
    public let glyph: StarlitCartoucheGlyphPoint; public let open: Int; public let close: Int
    public func position(at beat: Int) -> StarlitCartoucheVector }
public struct StarlitCartoucheCorridor: Sendable, Hashable, Codable { public let a: Int; public let b: Int
    public let travel: Int; public func joins(_ i: Int, _ j: Int) -> Bool }
public struct StarlitCartoucheHazard: Sendable, Hashable, Codable { public let corridor: Int; public let from: Int
    public let to: Int }
public struct StarlitCartoucheLeg: Sendable, Hashable { public let from: Int; public let to: Int; public let corridor: Int
    public let wait: Int; public let depart: Int; public let arrive: Int }
public enum StarlitCartoucheChart {
    public static func leg(_ level: StarlitCartoucheLevel, from star: Int, at beat: Int, to destination: Int,
        wait: Int) throws(StarlitCartoucheError) -> StarlitCartoucheLeg          // refusals: .action
    public static func check(_ level: StarlitCartoucheLevel, leg: StarlitCartoucheLeg) -> StarlitCartoucheFailure?
        // departure window, hazard, arrival window, deadline, stroke
    public static func clearance(_ level: StarlitCartoucheLevel, legs: [StarlitCartoucheLeg]) -> Int?
    public static func report(_ level: StarlitCartoucheLevel, star: Int, beat: Int, drawn: Set<Int>,
        legs: [StarlitCartoucheLeg]) -> StarlitCartoucheRouteReport }
public struct StarlitCartoucheRouteReport: Sendable, Equatable { public let star: Int; public let beat: Int
    public let drawn: [Int]; public let missing: [Int]; public let stray: [Int]; public let mismatch: Int
    public let clearance: Int?; public let matched: Bool }
public struct StarlitCartoucheLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(StarlitCartoucheError);
    encoded() -> Data; static func decode(_:) throws(StarlitCartoucheError) -> Self; fingerprint */
    public func starName(_ index: Int) -> String                    // "star 3"
    public func corridorName(_ index: Int) -> String                // "the corridor between star 1 and star 4"
    public func progressDescription(report: StarlitCartoucheRouteReport, actionsLeft: Int) -> String }
public enum StarlitCartoucheFailure: Sendable, Hashable, Codable {
    case departure(star: Int, beat: Int, close: Int); case hazard(corridor: Int, hazard: Int, from: Int, to: Int)
    case arrival(star: Int, beat: Int, open: Int, close: Int); case deadline(beat: Int, deadline: Int)
    case stroke(corridor: Int); case budget(Int); public var code: String }
public enum StarlitCartoucheAction: Sendable, Hashable, Codable { case leg(Int, Int) }   // destination star, wait
public enum StarlitCartoucheStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum StarlitCartoucheEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum StarlitCartoucheRecordKind: String, Sendable, Codable { case leg, undo, redo }
public struct StarlitCartoucheRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let index: Int; public let kind: StarlitCartoucheRecordKind; public let action: StarlitCartoucheAction?
    public let previous: String; public let next: String }
public struct StarlitCartouchePlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: StarlitCartoucheLevel
    public private(set) var stage: StarlitCartoucheStage, star: Int, beat: Int, drawn: Set<Int>,
        legs: [StarlitCartoucheLeg], actionsSpent: Int, report: StarlitCartoucheRouteReport,
        failure: StarlitCartoucheFailure?, records: [StarlitCartoucheRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: StarlitCartoucheLevel)
    public mutating func handle(_ event: StarlitCartoucheEvent) throws(StarlitCartoucheError)
    public mutating func apply(_ action: StarlitCartoucheAction, expecting previous: String) throws(StarlitCartoucheError)
        // order: .stage, .stale, .action
    public mutating func undo() throws(StarlitCartoucheError); public mutating func redo() throws(StarlitCartoucheError)
    public static func replay(level: StarlitCartoucheLevel, records: [StarlitCartoucheRecord]) throws(StarlitCartoucheError) -> StarlitCartouchePlay
}
public struct StarlitCartoucheRules: PuzzleRules { /* State = Position, Move = StarlitCartoucheAction;
    rulesID "r02-g16-starlit-cartouche"; moves per data-model.md; var initialState: Position */ }
```
