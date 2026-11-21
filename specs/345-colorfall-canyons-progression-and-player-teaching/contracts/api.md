# API contract: R02-G05-05

```swift
extension ColorfallCanyonsSolver {
    /// A smallest winning edit set applied now to `fluid` (at most min(budget, 3) edits), or nil.
    public static func plan(_ level: ColorfallCanyonsLevel, from fluid: ColorfallCanyonsFluid,
                            budget: Int) -> ColorfallCanyonsSolution? }
public enum ColorfallCanyonsHintKind: String, Sendable, Codable { case carve, valve, run, stuck }
public struct ColorfallCanyonsHint: Sendable, Equatable { public let level: Int; public let kind: ColorfallCanyonsHintKind
    public let cell: Int?; public let spring: Int?; public let ticks: Int; public let planSize: Int; public var text: String }
public enum ColorfallCanyonsHints {
    public static func plan(_ play: ColorfallCanyonsPlay) -> ColorfallCanyonsSolution?          // nil: no win reachable
    public static func hint(level: Int, play: ColorfallCanyonsPlay) -> ColorfallCanyonsHint? }  // playing/paused: the plan's hint; failed: kind stuck; won or other stages: nil
public struct ColorfallCanyonsFailureExplanation: Sendable, Equatable { public let failure: ColorfallCanyonsFailure
    public let basin: Int; public let color: ColorfallCanyonsColor?; public let amount: Int; public let limit: Int
    public let tick: Int; public var text: String; public init?(play: ColorfallCanyonsPlay) }
public enum ColorfallCanyonsTutorialStep: String, Sendable, Equatable, Codable { case steer, run, fill, done
    public var text: String
    /// The step after an accepted action of `kind` (carve, valve, step) or the end of the level; `planEmpty` comes from
    /// ColorfallCanyonsHints.plan of the new state.
    public func advanced(after kind: ColorfallCanyonsRecordKind?, planEmpty: Bool, ended: Bool) -> ColorfallCanyonsTutorialStep }
public struct ColorfallCanyonsProgress: Sendable, Equatable, Codable { /* best actions and stars per level, frontier;
    record(level:actions:smallest:) */ public static func stars(actions: Int, smallest: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 53
public enum ColorfallCanyonsMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g05.locked, r02-g05.date; snapshot schema 2 with migration from 1.
```
