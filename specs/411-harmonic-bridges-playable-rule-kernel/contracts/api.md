# API contract: R02-G12-01 (HarmonicBridgesCore)

```swift
public enum HarmonicBridgesError: Error, Equatable, Sendable { case level(String), action(String), noop, stage, stale,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g12.*
public struct HarmonicBridgesIsland: Sendable, Hashable, Codable { public let x: Int; public let y: Int }
public struct HarmonicBridgesTone: Sendable, Hashable, Codable { public let frequency: Int; public let strength: Int }
public struct HarmonicBridgesString: Sendable, Hashable, Codable { public let a: Int; public let b: Int
    public let length: Int; public let peg: Int; public let locked: Bool
    public func mode(of tone: HarmonicBridgesTone, peg: Int) -> Int? }    // n in 1 ... 5 with n * peg == F * length
public enum HarmonicBridgesSwing { public static let samples: Int          // 5
    public static let maxMode: Int                                           // 5
    public static func quarter(mode: Int, sample: Int) -> Int                // 4 sin²(nπk/6) ∈ {0, 1, 3, 4}
    public static func swing(modes: [(mode: Int, strength: Int)]) -> [Int] } // E(1 ... 5)
public struct HarmonicBridgesReport: Sendable, Equatable { public let swings: [[[Int]]]   // [step][string][sample]
    public let bridges: [[Bool]]; public let reached: [[Bool]]               // [step][string], [step][island]
    public var goalReachedInEveryStep: Bool { get } }
public struct HarmonicBridgesLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(HarmonicBridgesError);
    encoded() -> Data; static func decode(_:) throws(HarmonicBridgesError) -> Self; fingerprint */
    public func report(pegs: [Int]) -> HarmonicBridgesReport
    public func stringName(_ index: Int, peg: Int) -> String                 // "string 2, island 0 to island 3, peg 6"
    public func resonanceDescription(_ index: Int, pegs: [Int]) -> String    // "step 1: modes 2 and 3, swing 7 3 4 3 7, a bridge"
    public func progressDescription(report: HarmonicBridgesReport, actionsLeft: Int) -> String }
public enum HarmonicBridgesFailure: Sendable, Hashable, Codable { case broken(step: Int, string: Int?), budget(Int)
    public var code: String }
public enum HarmonicBridgesAction: Sendable, Hashable, Codable { case tune(Int, Int), test }
public enum HarmonicBridgesStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum HarmonicBridgesEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum HarmonicBridgesRecordKind: String, Sendable, Codable { case tune, test, undo, redo }
public struct HarmonicBridgesRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let index: Int; public let kind: HarmonicBridgesRecordKind; public let action: HarmonicBridgesAction?
    public let previous: String; public let next: String }
public struct HarmonicBridgesPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: HarmonicBridgesLevel
    public private(set) var stage: HarmonicBridgesStage, pegs: [Int], actionsSpent: Int,
        report: HarmonicBridgesReport, failure: HarmonicBridgesFailure?, records: [HarmonicBridgesRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: HarmonicBridgesLevel)
    public func pluck(_ string: Int) throws(HarmonicBridgesError) -> String // a query; changes nothing
    public mutating func handle(_ event: HarmonicBridgesEvent) throws(HarmonicBridgesError)        // .stage
    public mutating func apply(_ action: HarmonicBridgesAction, expecting previous: String) throws(HarmonicBridgesError)
        // order: .stage, .stale, .action, .noop
    public mutating func undo() throws(HarmonicBridgesError); public mutating func redo() throws(HarmonicBridgesError)
    public static func replay(level: HarmonicBridgesLevel, records: [HarmonicBridgesRecord]) throws(HarmonicBridgesError) -> HarmonicBridgesPlay
}
public struct HarmonicBridgesRules: PuzzleRules { /* State = Position (pegs, actions spent, outcome),
    Move = HarmonicBridgesAction; rulesID "r02-g12-harmonic-bridges";
    moves while playing: every valid tuning (string, then peg order), then the test; var initialState: Position */ }
```
