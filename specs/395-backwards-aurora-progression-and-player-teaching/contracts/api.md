# API contract: R02-G10-05

```swift
extension BackwardsAuroraSolver {
    public static func solve(_ level: BackwardsAuroraLevel, from wave: BackwardsAuroraWave, reversalsLeft: Int,
                             workBound: Int = workBound) -> BackwardsAuroraSolution? }   // a winning continuation
public struct BackwardsAuroraPlan: Sendable, Equatable { public let actions: [BackwardsAuroraAction] }   // first = the hint
public enum BackwardsAuroraHintKind: String, Sendable, Codable { case reverse, stuck }
public struct BackwardsAuroraHint: Sendable, Equatable { public let level: Int; public let kind: BackwardsAuroraHintKind
    public let action: BackwardsAuroraAction?; public var text: String }
public enum BackwardsAuroraHints {
    public static func plan(_ play: BackwardsAuroraPlay) -> BackwardsAuroraPlan?          // nil: no continuation
    public static func hint(level: Int, play: BackwardsAuroraPlay) -> BackwardsAuroraHint? }  // won: nil
public struct BackwardsAuroraFailureExplanation: Sendable, Equatable { public let failure: BackwardsAuroraFailure
    public let reversal: Int; public var text: String
    public init?(play: BackwardsAuroraPlay) }
public enum BackwardsAuroraTutorialStep: String, Sendable, Equatable, Codable { case mark, reverse, finish, done
    public var text: String
    public func advanced(afterReversal: Bool, ended: Bool) -> BackwardsAuroraTutorialStep }
public struct BackwardsAuroraProgress: Sendable, Equatable, Codable { /* best reversals made and stars per level,
    frontier; record(level:reversalsMade:smallest:) */ public static func stars(reversalsMade: Int, smallest: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 73
public enum BackwardsAuroraMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g10.locked, r02-g10.date; snapshot schema 2 with migration from 1.
```
