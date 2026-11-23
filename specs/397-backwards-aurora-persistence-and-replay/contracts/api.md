# API contract: R02-G10-07 (BackwardsAuroraCore additions)

```swift
extension BackwardsAuroraProgress.Result { public let trace: [BackwardsAuroraAction]; public let verified: Bool }
extension BackwardsAuroraProgress {
    public mutating func record(level: Int, reversalsMade: Int, smallest: Int, mode: BackwardsAuroraMode = .campaign,
                                trace: [BackwardsAuroraAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension BackwardsAuroraMode { case replay(level: Int) }
public enum BackwardsAuroraReconciliation {
    public static let maxTraceLength: Int   // 40
    public static func netTrace(_ records: [BackwardsAuroraRecord]) -> [BackwardsAuroraAction]
    public static func reconcile(_ progress: BackwardsAuroraProgress) -> (progress: BackwardsAuroraProgress, dropped: Int)
    public static func verifies(level: Int, result: BackwardsAuroraProgress.Result) -> Bool
}
// BackwardsAuroraExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g10.no-replay, r02-g10.replay-end, r02-g10.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// BackwardsAuroraFeedbackPlan: refusal words for the three codes; a replay step announced like the reversal.
```
