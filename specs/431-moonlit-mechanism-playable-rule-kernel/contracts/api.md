# API contract: R02-G14-01 (MoonlitMechanismCore)

```swift
public enum MoonlitMechanismError: Error, Equatable, Sendable { case level(String), action(String), stage, stale,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g14.*
public struct MoonlitMechanismCell: Sendable, Hashable, Codable { public let column: Int; public let row: Int }
public struct MoonlitMechanismGear: Sendable, Hashable, Codable { public let teeth: Int; public let phase: Int
    public let blades: [Bool]; public let depth: Int; public let centre: MoonlitMechanismCell; public let parent: Int?
    public let alignment: Int; public let slots: [[MoonlitMechanismCell]] }   // slot offsets (dc, dr)
public struct MoonlitMechanismKeyFrame: Sendable, Hashable, Codable { public let turns: Int; public let target: [Int]
    public let required: Bool }   // target: cell numbers row by row
public enum MoonlitMechanismTrain {
    public static func direction(_ gears: [MoonlitMechanismGear], _ index: Int) -> Int          // +1 even distance, −1 odd
    public static func turned(_ gears: [MoonlitMechanismGear], phases: [Int], by turns: Int) -> [Int]
    public static func alignmentError(_ gears: [MoonlitMechanismGear], phases: [Int], child: Int) -> Int
    public static func cast(_ gears: [MoonlitMechanismGear], phases: [Int], height: Int, width: Int, rows: Int) -> [Int] }
public enum MoonlitMechanismOutcome: Sendable, Hashable { case won, jammed(child: Int), forbidden(frame: Int, cell: Int),
    missing(frame: Int, count: Int), stray(frame: Int, count: Int) }
public struct MoonlitMechanismFrameReport: Sendable, Equatable { public let phases: [Int]; public let cast: [Int]
    public let covered: Int; public let missing: Int; public let stray: Int; public let forbidden: [Int] }
public struct MoonlitMechanismRunReport: Sendable, Equatable { public let errors: [Int]; public let frames: [MoonlitMechanismFrameReport]
    public let outcome: MoonlitMechanismOutcome }
public struct MoonlitMechanismLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(MoonlitMechanismError);
    encoded() -> Data; static func decode(_:) throws(MoonlitMechanismError) -> Self; fingerprint */
    public func run(phases: [Int], height: Int) -> MoonlitMechanismRunReport
    public func gearName(_ index: Int, phase: Int) -> String            // "gear 2, 12 teeth, phase 5"
    public func lampName(_ height: Int) -> String                      // "lamp height 1 of 3"
    public func progressDescription(report: MoonlitMechanismRunReport, actionsLeft: Int) -> String }
public enum MoonlitMechanismFailure: Sendable, Hashable, Codable { case jammed(Int), forbidden(frame: Int, cell: Int),
    missing(frame: Int, count: Int), stray(frame: Int, count: Int), budget(Int); public var code: String }
public enum MoonlitMechanismAction: Sendable, Hashable, Codable { case turn(Int), reseat(Int, Int), lamp(Int), run }
public enum MoonlitMechanismStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum MoonlitMechanismEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum MoonlitMechanismRecordKind: String, Sendable, Codable { case turn, reseat, lamp, run, undo, redo }
public struct MoonlitMechanismRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let index: Int; public let kind: MoonlitMechanismRecordKind; public let action: MoonlitMechanismAction?
    public let previous: String; public let next: String }
public struct MoonlitMechanismPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: MoonlitMechanismLevel
    public private(set) var stage: MoonlitMechanismStage, phases: [Int], height: Int, actionsSpent: Int,
        report: MoonlitMechanismRunReport, failure: MoonlitMechanismFailure?, records: [MoonlitMechanismRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: MoonlitMechanismLevel)
    public mutating func handle(_ event: MoonlitMechanismEvent) throws(MoonlitMechanismError)        // .stage
    public mutating func apply(_ action: MoonlitMechanismAction, expecting previous: String) throws(MoonlitMechanismError)
        // order: .stage, .stale, .action
    public mutating func undo() throws(MoonlitMechanismError); public mutating func redo() throws(MoonlitMechanismError)
    public static func replay(level: MoonlitMechanismLevel, records: [MoonlitMechanismRecord]) throws(MoonlitMechanismError) -> MoonlitMechanismPlay
}
public struct MoonlitMechanismRules: PuzzleRules { /* State = Position (phases, height, actions spent, outcome),
    Move = MoonlitMechanismAction; rulesID "r02-g14-moonlit-mechanism"; moves per data-model.md;
    var initialState: Position */ }
```
