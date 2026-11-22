# API contract: R02-G07-05

```swift
extension AmethystEscapeSolver {
    public static func solve(_ level: AmethystEscapeLevel, from crystal: AmethystEscapeCrystal,
                             maxDepth: Int) -> AmethystEscapeSolution? }   // the shortest escape from `crystal`
public struct AmethystEscapePlan: Sendable, Equatable { public let actions: [AmethystEscapeAction] }   // first = the hint
public enum AmethystEscapeHintKind: String, Sendable, Codable { case turn, advance, stuck }
public struct AmethystEscapeHint: Sendable, Equatable { public let level: Int; public let kind: AmethystEscapeHintKind
    public let shell: Int?; public let step: Int?; public var text: String }
public enum AmethystEscapeHints {
    public static func plan(_ play: AmethystEscapePlay) -> AmethystEscapePlan?          // nil: no escape in the moves left
    public static func hint(level: Int, play: AmethystEscapePlay) -> AmethystEscapeHint? }  // playing/paused: the plan's hint; failed: stuck; won: nil
public struct AmethystEscapeFailureExplanation: Sendable, Equatable { public let failure: AmethystEscapeFailure
    public let move: Int; public let shell: Int; public let sector: Int; public var text: String
    public init?(play: AmethystEscapePlay) }
public enum AmethystEscapeTutorialStep: String, Sendable, Equatable, Codable { case turn, advance, escape, done
    public var text: String
    public func advanced(after kind: AmethystEscapeRecordKind?, ended: Bool) -> AmethystEscapeTutorialStep }
public struct AmethystEscapeProgress: Sendable, Equatable, Codable { /* best moves and stars per level, frontier;
    record(level:moves:smallest:) */ public static func stars(moves: Int, smallest: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 61
public enum AmethystEscapeMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g07.locked, r02-g07.date; snapshot schema 2 with migration from 1.
```
