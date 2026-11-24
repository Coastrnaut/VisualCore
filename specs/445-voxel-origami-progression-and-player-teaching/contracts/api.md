# API contract: R02-G15-05

```swift
extension VoxelOrigamiSolver {
    public static func plan(_ level: VoxelOrigamiLevel, turns: [Int], maxTurns: Int = maxTurns,
                            workBound: Int = workBound) -> VoxelOrigamiPlan? }
    // plan(_:) == plan(level, turns: level.startTurns); nil for turns of the wrong count, a pose that collides, or a
    // pose that already matches
public struct VoxelOrigamiHintPlan: Sendable, Equatable { public let turns: [VoxelOrigamiAction] }   // first = the hint
public enum VoxelOrigamiHintKind: String, Sendable, Codable { case turn, stuck }
public struct VoxelOrigamiHint: Sendable, Equatable { public let level: Int
    public let kind: VoxelOrigamiHintKind; public let action: VoxelOrigamiAction?; public var text: String }
public enum VoxelOrigamiHints {
    public static func plan(_ play: VoxelOrigamiPlay) -> VoxelOrigamiHintPlan?       // nil: no plan in the actions left
    public static func hint(level: Int, play: VoxelOrigamiPlay) -> VoxelOrigamiHint? } // won: nil
public struct VoxelOrigamiFailureExplanation: Sendable, Equatable { public let failure: VoxelOrigamiFailure
    public let action: Int; public var text: String
    public init?(play: VoxelOrigamiPlay) }
public enum VoxelOrigamiTutorialStep: String, Sendable, Equatable, Codable { case turn, compare, recover, done
    public var text: String
    public func advanced(afterTurn: Bool, ended: Bool) -> VoxelOrigamiTutorialStep }
public struct VoxelOrigamiProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 31
public enum VoxelOrigamiMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g15.locked, r02-g15.date; snapshot schema 2 with migration from 1.
```
