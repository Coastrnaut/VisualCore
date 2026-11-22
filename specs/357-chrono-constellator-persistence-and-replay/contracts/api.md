# API contract: R02-G06-07 (ChronoConstellatorCore additions)

```swift
extension ChronoConstellatorProgress.Result { public let trace: [ChronoConstellatorAction]; public let verified: Bool }
extension ChronoConstellatorProgress {
    public mutating func record(level: Int, edits: Int, smallest: Int, mode: ChronoConstellatorMode = .campaign,
                                trace: [ChronoConstellatorAction]) -> Bool               // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension ChronoConstellatorMode { case replay(level: Int) }
public enum ChronoConstellatorReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [ChronoConstellatorRecord]) -> [ChronoConstellatorAction]
    public static func reconcile(_ progress: ChronoConstellatorProgress) -> (progress: ChronoConstellatorProgress, dropped: Int)
    public static func verifies(level: Int, result: ChronoConstellatorProgress.Result) -> Bool
}
// ChronoConstellatorExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g06.no-replay, r02-g06.replay-end, r02-g06.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// ChronoConstellatorFeedbackPlan: refusal words for the three codes; a replay step announced like the action.
```
