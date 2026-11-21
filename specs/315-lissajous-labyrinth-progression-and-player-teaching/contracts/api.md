# API contract: R02-G02-05 (LissajousLabyrinthCore additions)

```swift
extension LissajousLabyrinthSolver {
    public static func solve(_ level: LissajousLabyrinthLevel, from dials: LissajousLabyrinthDials,
                             winning: [LissajousLabyrinthDials]) -> LissajousLabyrinthSolution?   // nil when unreachable
}
public struct LissajousLabyrinthHint: Sendable, Equatable { public let level: Int; public let dial: LissajousLabyrinthDial
    public let raise: Bool?; public let value: Int?; public let remaining: Int; public let withinActions: Bool; public var text: String }
public enum LissajousLabyrinthHints {
    public static func hint(level: Int, play: LissajousLabyrinthPlay, winning: [LissajousLabyrinthDials]) -> LissajousLabyrinthHint? }  // nil when not playing or unreachable
public struct LissajousLabyrinthFailureExplanation: Sendable, Equatable { public let verdict: LissajousLabyrinthVerdict; public var text: String
    public init?(play: LissajousLabyrinthPlay) }
public enum LissajousLabyrinthTutorialStep: Sendable, Equatable, Codable { case turn(LissajousLabyrinthDial), checkpoints, hints, done
    public var text: String; public static func first(dial: LissajousLabyrinthDial) -> Self
    public func advancedByAction(stage: LissajousLabyrinthStage) -> Self; public func advancedByHint() -> Self }
public enum LissajousLabyrinthMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
public struct LissajousLabyrinthProgress: Sendable, Equatable, Codable {
    public struct Result: Sendable, Equatable, Codable { public let bestActions: Int; public let stars: Int }
    public private(set) var solved: [Int: Result]; public private(set) var frontier: Int
    public init(); public func isOpen(_ level: Int) -> Bool
    public static func stars(actions: Int, shortest: Int) -> Int
    public mutating func record(level: Int, actions: Int, shortest: Int, opensNext: Bool)
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int?    // nil for an impossible date
}
// LissajousLabyrinthExperienceCore: controls + "level.select" [1…100], "mode.daily" [year, month, day], "mode.practice",
// "mode.campaign", "tutorial.dismiss"; schemaVersion 2; migrations 1 → 2; progress and mode in digest and payload; tutorial
// in payload only; derived winning set; codes r02-g02.locked, r02-g02.date.
```
