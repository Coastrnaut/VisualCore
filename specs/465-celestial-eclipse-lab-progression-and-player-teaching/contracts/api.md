# API contract: R02-G17-05

```swift
extension CelestialEclipseLabSolver {
    public static func plan(_ level: CelestialEclipseLabLevel, from phases: [Int], maxChanges: Int = maxChanges,
                            workBound: Int = workBound) -> CelestialEclipseLabPlan? }
    // plan(level) == plan(level, from: level.phases); a plan of no changes when the phases already win
public struct CelestialEclipseLabHintPlan: Sendable, Equatable { public let changes: [CelestialEclipseLabAction] }
public enum CelestialEclipseLabHintKind: String, Sendable, Codable { case change, run, stuck }
public struct CelestialEclipseLabHint: Sendable, Equatable { public let level: Int
    public let kind: CelestialEclipseLabHintKind; public let action: CelestialEclipseLabAction?; public var text: String }
public enum CelestialEclipseLabHints {
    public static func plan(_ play: CelestialEclipseLabPlay) -> CelestialEclipseLabHintPlan?     // nil: none in the actions left
    public static func hint(level: Int, play: CelestialEclipseLabPlay) -> CelestialEclipseLabHint? } // won: nil
public struct CelestialEclipseLabFailureExplanation: Sendable, Equatable {
    public let failure: CelestialEclipseLabFailure; public var text: String
    public init?(play: CelestialEclipseLabPlay) }
public enum CelestialEclipseLabTutorialStep: String, Sendable, Equatable, Codable { case phase, order, recover, done
    public var text: String
    public func advanced(afterChange: Bool, ended: Bool) -> CelestialEclipseLabTutorialStep }
public struct CelestialEclipseLabProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 29
public enum CelestialEclipseLabMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g17.locked, r02-g17.date; snapshot schema 2 with migration from 1.
```
