# API contract: R02-G09-05

```swift
extension NocturneGardenSolver {
    public static func solve(_ level: NocturneGardenLevel, from blooms: [NocturneGardenBloom], sun: Int,
                             movesLeft: Int, supplyLeft: [NocturneGardenKind: Int],
                             workBound: Int = workBound) -> NocturneGardenSolution? }   // a winning continuation
public struct NocturneGardenPlan: Sendable, Equatable { public let actions: [NocturneGardenAction] }   // first = the hint
public enum NocturneGardenHintKind: String, Sendable, Codable { case move, stuck }
public struct NocturneGardenHint: Sendable, Equatable { public let level: Int; public let kind: NocturneGardenHintKind
    public let action: NocturneGardenAction?; public var text: String }
public enum NocturneGardenHints {
    public static func plan(_ play: NocturneGardenPlay) -> NocturneGardenPlan?          // nil: no continuation
    public static func hint(level: Int, play: NocturneGardenPlay) -> NocturneGardenHint? }  // won: nil
public struct NocturneGardenFailureExplanation: Sendable, Equatable { public let failure: NocturneGardenFailure
    public let move: Int; public var text: String
    public init?(play: NocturneGardenPlay) }
public enum NocturneGardenTutorialStep: String, Sendable, Equatable, Codable { case plant, shape, finish, done
    public var text: String
    public func advanced(afterMove: Bool, ended: Bool) -> NocturneGardenTutorialStep }
public struct NocturneGardenProgress: Sendable, Equatable, Codable { /* best moves made and stars per level, frontier;
    record(level:movesMade:smallest:) */ public static func stars(movesMade: Int, smallest: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 71
public enum NocturneGardenMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g09.locked, r02-g09.date; snapshot schema 2 with migration from 1.
```
