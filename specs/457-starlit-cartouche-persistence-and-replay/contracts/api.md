# API contract: R02-G16-07 (StarlitCartoucheCore additions)

```swift
extension StarlitCartoucheProgress.Result { public let trace: [StarlitCartoucheAction]; public let verified: Bool }
    // each trace entry is `.leg(star, wait)` as the kernel applied it
extension StarlitCartoucheProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: StarlitCartoucheMode = .campaign,
                                trace: [StarlitCartoucheAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension StarlitCartoucheMode { case replay(level: Int) }
public enum StarlitCartoucheReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [StarlitCartoucheRecord]) -> [StarlitCartoucheAction]
    public static func reconcile(_ progress: StarlitCartoucheProgress) -> (progress: StarlitCartoucheProgress, dropped: Int)
    public static func verifies(level: Int, result: StarlitCartoucheProgress.Result) -> Bool
}
// StarlitCartoucheExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g16.no-replay, r02-g16.replay-end, r02-g16.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// StarlitCartoucheFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
