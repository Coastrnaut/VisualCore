# API contract: R02-G01-05 (AuroraLoomCore additions)

```swift
extension AuroraLoomSolver { public static func solve(_ level: AuroraLoomLevel, from steps: AuroraLoomSteps) -> AuroraLoomSolution? }
public struct AuroraLoomHint: Sendable, Equatable { public let level: Int; public let ribbon: Int; public let control: AuroraLoomControl?
    public let step: Int?; public let remaining: Int; public let withinMoves: Bool; public var text: String }
public enum AuroraLoomHints { public static func hint(level: Int, play: AuroraLoomPlay) -> AuroraLoomHint? }   // nil when won/failed
public struct AuroraLoomFailureExplanation: Sendable, Equatable { public let mismatch: AuroraLoomMismatch; public let tolerance: Int; public var text: String
    public init?(play: AuroraLoomPlay) }
public enum AuroraLoomTutorialStep: Sendable, Equatable, Codable { case wave(ribbon: Int), phase(ribbon: Int), harmony, done
    public var text: String; public static func first(ribbon: Int) -> Self
    public func advanced(by record: AuroraLoomRecord, stage: AuroraLoomStage, hintRibbon: Int) -> Self }
public enum AuroraLoomMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
public struct AuroraLoomProgress: Sendable, Equatable, Codable {
    public struct Result: Sendable, Equatable, Codable { public let bestMoves: Int; public let stars: Int }
    public private(set) var solved: [Int: Result]; public var frontier: Int
    public init(); public func isOpen(_ level: Int) -> Bool
    public static func stars(moves: Int, shortest: Int) -> Int
    public mutating func record(level: Int, moves: Int, shortest: Int)
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int?
}
// AuroraLoomExperienceCore: controls + "level.select" [1…100], "mode.daily" [year, month, day], "mode.practice", "mode.campaign",
// "tutorial.dismiss"; schemaVersion 2; migrations 1 → 2; progress and mode in digest and payload; tutorial in payload only (INV-05); codes r02-g01.locked, r02-g01.date.
```
