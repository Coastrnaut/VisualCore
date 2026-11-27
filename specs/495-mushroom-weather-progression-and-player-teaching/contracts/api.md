# API contract: R02-G20-05

```swift
public struct MushroomWeatherHintPlan: Sendable, Equatable { public let actions: [MushroomWeatherAction] }
public enum MushroomWeatherHintKind: String, Sendable, Codable { case pod, vent, moonlight, run, stuck }
public struct MushroomWeatherHint: Sendable, Equatable { public let level: Int
    public let kind: MushroomWeatherHintKind; public let action: MushroomWeatherAction?; public var text: String }
public enum MushroomWeatherHints {
    public static let workBound: Int                                                 // 1,500 arrangements judged
    public static func plan(_ play: MushroomWeatherPlay, certified: MushroomWeatherPlan?,
                            workBound: Int = workBound) -> MushroomWeatherHintPlan?  // nil: none in the actions left
    public static func hint(level: Int, play: MushroomWeatherPlay,
                            certified: MushroomWeatherPlan?) -> MushroomWeatherHint? } // won: nil
public struct MushroomWeatherFailureExplanation: Sendable, Equatable {
    public let failure: MushroomWeatherFailure; public var text: String
    public init?(play: MushroomWeatherPlay) }
public enum MushroomWeatherTutorialStep: String, Sendable, Equatable, Codable { case place, balance, recover, done
    public var text: String
    public func advanced(afterAction: Bool, placement: Bool, ended: Bool) -> MushroomWeatherTutorialStep }
public struct MushroomWeatherProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 17
public enum MushroomWeatherMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g20.locked, r02-g20.date; snapshot schema 2 with migration from 1.
```
