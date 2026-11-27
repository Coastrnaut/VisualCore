# API contract: R02-G21-05

```swift
public struct BinaryGardensHintPlan: Sendable, Equatable { public let actions: [BinaryGardensAction] }
public enum BinaryGardensHintKind: String, Sendable, Codable { case ring, phase, luminosity, tilt, run, stuck, retry }
public struct BinaryGardensHint: Sendable, Equatable { public let level: Int
    public let kind: BinaryGardensHintKind; public let action: BinaryGardensAction?; public var text: String }
public enum BinaryGardensHints {
    public static let workBound: Int                                                  // 2,000 arrangements judged
    public static func plan(_ play: BinaryGardensPlay, certified: BinaryGardensPlan?,
                            workBound: Int = workBound) -> BinaryGardensHintPlan?     // nil: none in the actions left
    public static func hint(level: Int, play: BinaryGardensPlay,
                            certified: BinaryGardensPlan?) -> BinaryGardensHint? }    // won / not playing: nil
public struct BinaryGardensFailureExplanation: Sendable, Equatable {
    public let failure: BinaryGardensFailure; public var text: String
    public init?(play: BinaryGardensPlay) }
public enum BinaryGardensTutorialStep: String, Sendable, Equatable, Codable { case adjust, balance, recover, done
    public var text: String
    public func advanced(afterAction: Bool, actionsThisOpening: Int, ended: Bool) -> BinaryGardensTutorialStep }
public struct BinaryGardensProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:opens:) */
    public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }          // × 13
public enum BinaryGardensMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// level.next stops wrapping; codes r02-g21.locked, r02-g21.date; digest domain "r02-g21.binary-gardens.v2";
// snapshot schema 2 with migration from 1.
```
