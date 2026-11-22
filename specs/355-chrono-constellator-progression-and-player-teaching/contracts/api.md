# API contract: R02-G06-05

```swift
public enum ChronoConstellatorPlan: Sendable, Equatable {
    case run(ticks: Int), rewind, release(star: Int, start: Int), phases([ChronoConstellatorPhaseChange]) }
public struct ChronoConstellatorPhaseChange: Sendable, Equatable { public let star: Int; public let phase: Int }
public enum ChronoConstellatorHintKind: String, Sendable, Codable { case phase, release, rewind, run, stuck }
public struct ChronoConstellatorHint: Sendable, Equatable { public let level: Int; public let kind: ChronoConstellatorHintKind
    public let star: Int?; public let cell: Int?; public let phase: Int?; public let start: Int?; public let ticks: Int
    public var text: String }
public enum ChronoConstellatorHints {
    public static func plan(_ play: ChronoConstellatorPlay) -> ChronoConstellatorPlan?          // nil: no win reachable
    public static func hint(level: Int, play: ChronoConstellatorPlay) -> ChronoConstellatorHint? }  // playing/paused: the plan's hint; failed: stuck; won: nil
public struct ChronoConstellatorFailureExplanation: Sendable, Equatable { public let failure: ChronoConstellatorFailure
    public let tick: Int; public let stars: [Int]; public let cell: Int?; public var text: String
    public init?(play: ChronoConstellatorPlay) }
public enum ChronoConstellatorTutorialStep: String, Sendable, Equatable, Codable { case shift, replay, align, done
    public var text: String
    public func advanced(after kind: ChronoConstellatorRecordKind?, planIsRun: Bool, ended: Bool) -> ChronoConstellatorTutorialStep }
public struct ChronoConstellatorProgress: Sendable, Equatable, Codable { /* best edits and stars per level, frontier;
    record(level:edits:smallest:) */ public static func stars(edits: Int, smallest: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 59
public enum ChronoConstellatorMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g06.locked, r02-g06.date; snapshot schema 2 with migration from 1.
```
