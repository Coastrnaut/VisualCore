# API contract: R02-G22-05

```swift
public struct MyceliumArchitectHintPlan: Sendable, Equatable { public let actions: [MyceliumArchitectAction] }
public enum MyceliumArchitectHintKind: String, Sendable, Codable {
    case nutrient, blocker, clear, seed, unseed, run, stuck, retry }
public struct MyceliumArchitectHint: Sendable, Equatable { public let level: Int
    public let kind: MyceliumArchitectHintKind; public let action: MyceliumArchitectAction?; public var text: String }
public enum MyceliumArchitectHints {
    public static let workBound: Int                                                       // 2,000 arrangements judged
    public static func plan(_ play: MyceliumArchitectPlay, certified: [MyceliumArchitectAction]?,
                            workBound: Int = workBound) -> MyceliumArchitectHintPlan?      // nil: none in the actions left
    public static func hint(level: Int, play: MyceliumArchitectPlay,
                            certified: [MyceliumArchitectAction]?) -> MyceliumArchitectHint? } // won / not playing: nil
public struct MyceliumArchitectFailureExplanation: Sendable, Equatable {
    public let failure: MyceliumArchitectFailure; public var text: String
    public init?(play: MyceliumArchitectPlay) }
public enum MyceliumArchitectTutorialStep: String, Sendable, Equatable, Codable { case place, grow, recover, done
    public var text: String
    public func advanced(afterAction: Bool, actionsThisOpening: Int, ended: Bool) -> MyceliumArchitectTutorialStep }
public struct MyceliumArchitectProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:opens:) */
    public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }               // × 11
public enum MyceliumArchitectMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// `certified` is the certified plan's arrangement actions (the witness without its final run).
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// level.next stops wrapping; codes r02-g22.locked, r02-g22.date; digest domain "r02-g22.mycelium-architect.v2";
// snapshot schema 2 with migration from 1.
```
