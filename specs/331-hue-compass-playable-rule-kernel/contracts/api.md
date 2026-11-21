# API contract: R02-G04-01 (HueCompassCore)

```swift
public enum HueCompassError: Error, Equatable, Sendable { case level(String), action(String), stage, stale, allowance,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g04.*
public enum HueCompassWheel {
    public static let bearings = 96, bands = 24, bearingsPerBand = 4
    public static let boundaries: [(x: Int, y: Int)]          // 96 constants, angle 2πk/96 × 65 536, rounded
    public static func bearing(x: Int, y: Int) -> Int?         // nil for (0, 0)
    public static func band(of bearing: Int, offset: Int) -> Int
    public static func bearingDistance(_ a: Int, _ b: Int) -> Int   // 0 … 48
    public static func bandDistance(_ a: Int, _ b: Int) -> Int      // 0 … 12
    public static func arc(from: Int, to: Int) -> [Int]        // bearings strictly inside the shorter arc; ccw from `from` on a tie
}
public struct HueCompassClue: Sendable, Hashable, Codable { public let bearing, hueGap, depth: Int }
public enum HueCompassAction: Sendable, Hashable, Codable { case turn(Int), probe, select(bearing: Int, band: Int) }
public struct HueCompassLevel: Sendable, Equatable { /* fields per data-model.md; init throws(HueCompassError); encoded(); decode(_:) */
    public func clue(at bearing: Int) -> HueCompassClue
    public func accepts(bearing: Int, band: Int) -> Bool }
public enum HueCompassStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum HueCompassEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum HueCompassRecordKind: String, Sendable, Codable { case turn, probe, select, undo, redo }
public enum HueCompassFailure: String, Sendable, Codable, CaseIterable { case selection, probes }
public struct HueCompassSelection: Sendable, Hashable, Codable { public let bearing: Int; public let band: Int }
public struct HueCompassRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64; public let tick: Int
    public let kind: HueCompassRecordKind; public let action: HueCompassAction   // undo: the reverse turn; redo: the turn
    public let previous: String; public let next: String }
public struct HueCompassPlay: Sendable, Equatable {
    public static var schema: Int { 1 }; public static let turns: ClosedRange<Int>   // −48 … 48
    public let level: HueCompassLevel
    public private(set) var stage: HueCompassStage, bearing: Int, spent: Int, clues: [HueCompassClue],
        records: [HueCompassRecord], failure: HueCompassFailure?,
        selection: HueCompassSelection?   // pinned in the fingerprint after a zero byte (spec Q5)
    public var fingerprint: String { get }; public var remaining: Int { get }; public var canUndo, canRedo: Bool { get }
    public init(level: HueCompassLevel)
    public mutating func handle(_ event: HueCompassEvent) throws(HueCompassError)            // .stage
    public static func inRange(_ action: HueCompassAction) -> Bool
    public mutating func apply(_ action: HueCompassAction, expecting previous: String) throws(HueCompassError)
        // order: .stage, .stale, .action("range"), .allowance
    public mutating func undo() throws(HueCompassError); public mutating func redo() throws(HueCompassError)
        // .stage, .action("nothing-to-undo" | "nothing-to-redo"); turns only
    public static func replay(level: HueCompassLevel, records: [HueCompassRecord]) throws(HueCompassError) -> HueCompassPlay
}
public struct HueCompassRules: PuzzleRules { /* State = HueCompassRules.Position (bearing, spent, outcome), Move = HueCompassAction;
    moves: turn(+1), turn(−1), probe, select(current bearing, band 0 … 23) */ }
```
