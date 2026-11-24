# API contract: R02-G13-07 (AcousticConstellatorCore additions)

```swift
extension AcousticConstellatorProgress.Result { public let trace: [AcousticConstellatorAction]; public let verified: Bool }
extension AcousticConstellatorProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: AcousticConstellatorMode = .campaign,
                                trace: [AcousticConstellatorAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension AcousticConstellatorMode { case replay(level: Int) }
public enum AcousticConstellatorReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [AcousticConstellatorRecord]) -> [AcousticConstellatorAction]
    public static func reconcile(_ progress: AcousticConstellatorProgress) -> (progress: AcousticConstellatorProgress, dropped: Int)
    public static func verifies(level: Int, result: AcousticConstellatorProgress.Result) -> Bool
}
// AcousticConstellatorExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g13.no-replay, r02-g13.replay-end, r02-g13.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// AcousticConstellatorFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
