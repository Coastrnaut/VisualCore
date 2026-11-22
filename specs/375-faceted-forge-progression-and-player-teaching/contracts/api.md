# API contract: R02-G08-05

```swift
extension FacetedForgeSolver {
    public static func solve(_ level: FacetedForgeLevel, from pieces: [FacetedForgePiece], cutsLeft: Int,
                             workBound: Int = workBound) -> FacetedForgeSolution? }   // a winning continuation
public struct FacetedForgePlan: Sendable, Equatable { public let actions: [FacetedForgeAction] }   // first = the hint
public enum FacetedForgeHintKind: String, Sendable, Codable { case cut, stuck }
public struct FacetedForgeHint: Sendable, Equatable { public let level: Int; public let kind: FacetedForgeHintKind
    public let piece: Int?; public let direction: Int?; public let depth: Int?; public var text: String }
public enum FacetedForgeHints {
    public static func plan(_ play: FacetedForgePlay) -> FacetedForgePlan?          // nil: no continuation in the cuts left
    public static func hint(level: Int, play: FacetedForgePlay) -> FacetedForgeHint? }  // playing/paused: the plan's hint; failed: stuck; won: nil
public struct FacetedForgeFailureExplanation: Sendable, Equatable { public let failure: FacetedForgeFailure
    public let cut: Int; public let piece: Int?; public var text: String
    public init?(play: FacetedForgePlay) }
public enum FacetedForgeTutorialStep: String, Sendable, Equatable, Codable { case aim, match, finish, done
    public var text: String
    public func advanced(afterCut: Bool, ended: Bool) -> FacetedForgeTutorialStep }
public struct FacetedForgeProgress: Sendable, Equatable, Codable { /* best cuts made and stars per level, frontier;
    record(level:cutsMade:smallest:) */ public static func stars(cutsMade: Int, smallest: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 67
public enum FacetedForgeMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g08.locked, r02-g08.date; snapshot schema 2 with migration from 1.
```
