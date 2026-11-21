# API contract: R02-G03-05

```swift
extension WaveKnotKeeperSolver {
    public static func solve(_ level: WaveKnotKeeperLevel, from points: [WaveKnotKeeperPoint],
                             depth: Int = maximumDepth) -> WaveKnotKeeperSolution?   // nil: none within depth
}
public struct WaveKnotKeeperHint: Sendable, Equatable { public let level: Int; public let point: Int
    public let axis: Int?; public let direction: WaveKnotKeeperDirection?; public let remaining: Int
    public let withinMoves: Bool; public var text: String }
public enum WaveKnotKeeperHints { public static func hint(level: Int, play: WaveKnotKeeperPlay) -> WaveKnotKeeperHint? }
public struct WaveKnotKeeperFailureExplanation: Sendable, Equatable { public let summary: WaveKnotKeeperSummary
    public let target: WaveKnotKeeperTarget; public var text: String; public init?(play: WaveKnotKeeperPlay) }
public enum WaveKnotKeeperTutorialStep: Sendable, Equatable, Codable { case move(Int), signature, hints, done
    public var text: String }
public struct WaveKnotKeeperProgress: Sendable, Equatable, Codable { /* solved, frontier, record(level:moves:shortest:), stars */
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 43
public enum WaveKnotKeeperMode: Sendable, Equatable, Codable { case campaign, practice, daily(year: Int, month: Int, day: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss,
// tutorial.hint; codes r02-g03.locked, r02-g03.date; snapshot schema 2 with migration from 1.
```
