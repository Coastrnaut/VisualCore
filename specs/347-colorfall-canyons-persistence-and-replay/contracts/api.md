# API contract: R02-G05-07 (ColorfallCanyonsCore additions)

```swift
extension ColorfallCanyonsProgress.Result { public let trace: [ColorfallCanyonsAction]; public let verified: Bool }
extension ColorfallCanyonsProgress {
    public mutating func record(level: Int, actions: Int, smallest: Int, mode: ColorfallCanyonsMode = .campaign,
                                trace: [ColorfallCanyonsAction]) -> Bool                 // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension ColorfallCanyonsMode { case replay(level: Int) }
public enum ColorfallCanyonsReconciliation {
    public static func reconcile(_ progress: ColorfallCanyonsProgress) -> (progress: ColorfallCanyonsProgress, dropped: Int)
    public static func verifies(level: Int, result: ColorfallCanyonsProgress.Result) -> Bool
}
// ColorfallCanyonsExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100], "replay.step",
// "replay.stop"; codes r02-g05.no-replay, r02-g05.replay-end, r02-g05.replay; public var reconciliationDropped: Int
// (not digested); "settings.sound" [0…1] sets `public var soundOn: Bool` (snapshotted, not digested). ColorfallCanyonsFeedbackPlan: refusal words for the three codes; a replay step announced like the action.
```
