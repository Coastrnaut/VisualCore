# API contract: R02-G10-01 (BackwardsAuroraCore)

```swift
public enum BackwardsAuroraError: Error, Equatable, Sendable { case level(String), action(String), noop, stage, stale,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g10.*
public struct BackwardsAuroraWave: Sendable, Hashable, Codable {
    public static let sampleRange: ClosedRange<Int>   // -64 ... 64
    public static let lengthRange: ClosedRange<Int>   // 12 ... 32
    public let samples: [Int]
    public init(_ samples: [Int]) throws(BackwardsAuroraError)                 // .level when out of range
    public var count: Int { get }
    public func bend(at k: Int) -> Int                                         // 1 ... count - 2
    public var bends: [Int] { get }                                            // index 0 is position 1
    public var worstBend: Int { get }
    public func isSmooth(limit: Int) -> Bool
    public func reversed(start: Int, end: Int) -> Self
    public static func seams(start: Int, end: Int, count: Int) -> [Int]        // sorted, interior only
    public func distance(to target: Self) -> (numerator: Int, denominator: Int) // 0/1 when the target is all zero
    public func isPalindrome(start: Int, end: Int) -> Bool
}
public struct BackwardsAuroraLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(BackwardsAuroraError);
    encoded() -> Data; static func decode(_:) throws(BackwardsAuroraError) -> Self; fingerprint */
    public func matched(_ wave: BackwardsAuroraWave) -> [Bool]                 // per checkpoint
    public func wins(_ wave: BackwardsAuroraWave) -> Bool
    public func sampleName(_ position: Int, wave: BackwardsAuroraWave) -> String   // "sample 4: height -12"
    public func checkpointName(_ index: Int, wave: BackwardsAuroraWave) -> String  // "checkpoint 2 at sample 7: matched"
    public func bendDescription(_ wave: BackwardsAuroraWave) -> String             // "worst bend 9 of limit 12"
    public func targetDescription() -> String }                                    // FR-R02G1001-013
public enum BackwardsAuroraFailure: Sendable, Hashable, Codable { case tear(Int, Int), budget; public var code: String }
    // tear(move, seam position)
public enum BackwardsAuroraAction: Sendable, Hashable, Codable { case reverse(Int, Int) }
public enum BackwardsAuroraStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum BackwardsAuroraEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum BackwardsAuroraRecordKind: String, Sendable, Codable { case reverse, undo, redo }
public struct BackwardsAuroraRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let move: Int; public let kind: BackwardsAuroraRecordKind; public let action: BackwardsAuroraAction?
    public let previous: String; public let next: String }
public struct BackwardsAuroraPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: BackwardsAuroraLevel
    public private(set) var stage: BackwardsAuroraStage, wave: BackwardsAuroraWave, spent: Int,
        failure: BackwardsAuroraFailure?, records: [BackwardsAuroraRecord]
    public var matched: [Bool] { get }; public var distance: (numerator: Int, denominator: Int) { get }
    public var worstBend: Int { get }
    public var fingerprint: String { get }; public var remaining: Int { get }; public var canUndo, canRedo: Bool { get }
    public init(level: BackwardsAuroraLevel)
    public mutating func handle(_ event: BackwardsAuroraEvent) throws(BackwardsAuroraError)          // .stage
    public mutating func apply(_ action: BackwardsAuroraAction, expecting previous: String) throws(BackwardsAuroraError)
        // order: .stage, .stale, .action(range or length), .noop
    public mutating func undo() throws(BackwardsAuroraError); public mutating func redo() throws(BackwardsAuroraError)
    public static func replay(level: BackwardsAuroraLevel, records: [BackwardsAuroraRecord]) throws(BackwardsAuroraError) -> BackwardsAuroraPlay
}
public struct BackwardsAuroraRules: PuzzleRules { /* State = Position (wave, spent, outcome), Move = BackwardsAuroraAction;
    rulesID "r02-g10-backwards-aurora"; moves while playing in order of start, then end */ }
```
