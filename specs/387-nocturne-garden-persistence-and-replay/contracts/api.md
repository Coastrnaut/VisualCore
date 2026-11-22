# API contract: R02-G09-07 (NocturneGardenCore additions)

```swift
extension NocturneGardenProgress.Result { public let trace: [NocturneGardenAction]; public let verified: Bool }
extension NocturneGardenProgress {
    public mutating func record(level: Int, movesMade: Int, smallest: Int, mode: NocturneGardenMode = .campaign,
                                trace: [NocturneGardenAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension NocturneGardenMode { case replay(level: Int) }
public enum NocturneGardenReconciliation {
    public static let maxTraceLength: Int   // 40
    public static func netTrace(_ records: [NocturneGardenRecord]) -> [NocturneGardenAction]
    public static func reconcile(_ progress: NocturneGardenProgress) -> (progress: NocturneGardenProgress, dropped: Int)
    public static func verifies(level: Int, result: NocturneGardenProgress.Result) -> Bool
}
// NocturneGardenExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g09.no-replay, r02-g09.replay-end, r02-g09.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// NocturneGardenFeedbackPlan: refusal words for the three codes; a replay step announced like the move.
```
