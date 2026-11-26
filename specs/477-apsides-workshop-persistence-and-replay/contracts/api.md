# API contract: R02-G18-07 (ApsidesWorkshopCore additions)

```swift
extension ApsidesWorkshopProgress.Result { public let trace: [ApsidesWorkshopAction]; public let verified: Bool }
    // each trace entry is `.periapsis(k, d)` or `.size(a)` as the kernel applied it; the last is `.play`
extension ApsidesWorkshopProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: ApsidesWorkshopMode = .campaign,
                                trace: [ApsidesWorkshopAction]) -> Bool         // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension ApsidesWorkshopMode { case replay(level: Int) }
public enum ApsidesWorkshopReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [ApsidesWorkshopRecord]) -> [ApsidesWorkshopAction]
    public static func reconcile(_ progress: ApsidesWorkshopProgress) -> (progress: ApsidesWorkshopProgress, dropped: Int)
    public static func verifies(level: Int, result: ApsidesWorkshopProgress.Result) -> Bool
}
// ApsidesWorkshopExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g18.no-replay, r02-g18.replay-end, r02-g18.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// ApsidesWorkshopFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
