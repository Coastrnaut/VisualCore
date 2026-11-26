# API contract: R02-G19-05

```swift
public struct MicroscopicAuroraHintPlan: Sendable, Equatable { public let actions: [MicroscopicAuroraAction] }
public enum MicroscopicAuroraHintKind: String, Sendable, Codable { case place, remove, play, stuck }
public struct MicroscopicAuroraHint: Sendable, Equatable { public let level: Int
    public let kind: MicroscopicAuroraHintKind; public let action: MicroscopicAuroraAction?; public var text: String }
public enum MicroscopicAuroraHints {
    public static let workBound: Int                                                       // 1,200 sets judged
    public static func plan(_ play: MicroscopicAuroraPlay, certified: [MicroscopicAuroraWell]?,
                            workBound: Int = workBound) -> MicroscopicAuroraHintPlan?      // nil: none in the actions left
    public static func hint(level: Int, play: MicroscopicAuroraPlay,
                            certified: [MicroscopicAuroraWell]?) -> MicroscopicAuroraHint? } // won: nil
public struct MicroscopicAuroraFailureExplanation: Sendable, Equatable {
    public let failure: MicroscopicAuroraFailure; public var text: String
    public init?(play: MicroscopicAuroraPlay) }
public enum MicroscopicAuroraTutorialStep: String, Sendable, Equatable, Codable { case place, cover, recover, done
    public var text: String
    public func advanced(afterAction: Bool, placement: Bool, ended: Bool) -> MicroscopicAuroraTutorialStep }
public struct MicroscopicAuroraProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 19
public enum MicroscopicAuroraMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g19.locked, r02-g19.date; snapshot schema 2 with migration from 1.
```
