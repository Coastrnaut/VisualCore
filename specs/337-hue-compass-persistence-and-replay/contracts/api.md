# API contract: R02-G04-07 (HueCompassCore additions)

```swift
extension HueCompassProgress.Result { public let trace: [HueCompassAction]; public let verified: Bool }
extension HueCompassProgress {
    public mutating func record(level: Int, units: Int, smallest: Int, mode: HueCompassMode = .campaign,
                                trace: [HueCompassAction]) -> Bool                 // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension HueCompassMode { case replay(level: Int) }
public enum HueCompassReconciliation {
    public static func reconcile(_ progress: HueCompassProgress) -> (progress: HueCompassProgress, dropped: Int)
    public static func verifies(level: Int, result: HueCompassProgress.Result) -> Bool
}
// HueCompassExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100], "replay.step",
// "replay.stop"; codes r02-g04.no-replay, r02-g04.replay-end, r02-g04.replay; public var reconciliationDropped: Int
// (not digested). HueCompassFeedbackPlan: refusal words for the three codes; a replay step announced like the action.
```
