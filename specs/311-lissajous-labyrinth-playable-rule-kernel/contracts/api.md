# API contract: R02-G02-01 (LissajousLabyrinthCore)

```swift
public enum LissajousLabyrinthError: Error, Equatable, Sendable {
    case level(String), move(String), stage, stale, allowance, newerSchema(Int), malformed(String)
    public var reasonCode: String   // r02-g02.level | .move | .stage | .stale | .allowance | .newer-schema | .malformed
}
public enum LissajousLabyrinthSine {
    public static let unitsPerTurn = 4_096; public static let scale = 1_024
    public static func sin(_ angle: Int) -> Int; public static func cos(_ angle: Int) -> Int   // any Int angle, wrapped
    public static var tableDigest: String { get }                                                 // SHA-256 hex of the table
}
public struct LissajousLabyrinthBall: Sendable, Equatable, Hashable, Codable { public let x, y, z, radius: Int
    public init(x: Int, y: Int, z: Int, radius: Int) throws(LissajousLabyrinthError) }
public enum LissajousLabyrinthDial: String, Sendable, Codable, CaseIterable { case frequencyA, frequencyB, phaseA, phaseC }
public struct LissajousLabyrinthDials: Sendable, Equatable, Hashable, Codable {
    public var frequencyA, frequencyB, phaseA, phaseC: Int
    public init(frequencyA: Int, frequencyB: Int, phaseA: Int, phaseC: Int)
    public subscript(dial: LissajousLabyrinthDial) -> Int { get set }
    public var isValid: Bool { get }   // ranges and gcd(frequencyA, frequencyB) == 1
}
public struct LissajousLabyrinthLevel: Sendable, Equatable, Codable {
    public static var schema: Int { 1 }
    public let id: String; public let seed: UInt64; public let band: Int; public let amplitudes: [Int]; public let frequencyC: Int
    public let start: LissajousLabyrinthDials; public let checkpoints: [LissajousLabyrinthBall]; public let obstacles: [LissajousLabyrinthBall]
    public let allowance: Int; public let tutorial: Bool; public let fingerprint: String
    public init(id:seed:band:amplitudes:frequencyC:start:checkpoints:obstacles:allowance:tutorial:) throws(LissajousLabyrinthError)
    public func encoded() -> Data; public static func decode(_ data: Data) throws(LissajousLabyrinthError) -> LissajousLabyrinthLevel
}
public enum LissajousLabyrinthVerdict: Sendable, Equatable, Hashable { case won, contact(obstacle: Int, tick: Int), missed(checkpoint: Int) }
public enum LissajousLabyrinthLap {
    public static let ticks = 4_096
    public static func position(tick: Int, dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel) -> (x: Int, y: Int, z: Int)
    public static func segmentTouches(_ p: (x: Int, y: Int, z: Int), _ q: (x: Int, y: Int, z: Int), ball: LissajousLabyrinthBall) -> Bool
    public static func verdict(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel) -> LissajousLabyrinthVerdict
}
public struct LissajousLabyrinthAction: Sendable, Equatable, Hashable, Codable { public var dial: LissajousLabyrinthDial; public var value: Int }
public enum LissajousLabyrinthStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum LissajousLabyrinthEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum LissajousLabyrinthRecordKind: String, Sendable, Codable { case action, undo, redo }
public struct LissajousLabyrinthRecord: Sendable, Equatable, Codable { schema, seed, tick, kind, dial, value, previous, next }
public struct LissajousLabyrinthPlay: Sendable, Equatable {
    public let level; public private(set) var stage, dials, spent, records; public private(set) var failure: LissajousLabyrinthVerdict?
    public init(level:); public var fingerprint: String; public var canUndo: Bool; public var canRedo: Bool
    public mutating func handle(_ event:) throws(LissajousLabyrinthError)
    public mutating func apply(_ action:, expecting previous: String) throws(LissajousLabyrinthError)   // .stage, .stale, .move("range"|"no-change"|"not-coprime"), .allowance
    public mutating func undo() throws(LissajousLabyrinthError); public mutating func redo() throws(LissajousLabyrinthError)
    public static func replay(level:, records:) throws(LissajousLabyrinthError) -> LissajousLabyrinthPlay
}
public struct LissajousLabyrinthRules: PuzzleRules { State = LissajousLabyrinthDials; Move = LissajousLabyrinthAction; rulesID "r02-g02-lissajous-labyrinth" }
```
