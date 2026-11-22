# API contract: R02-G08-07 (FacetedForgeCore additions)

```swift
extension FacetedForgeProgress.Result { public let trace: [FacetedForgeAction]; public let verified: Bool }
extension FacetedForgeProgress {
    public mutating func record(level: Int, cutsMade: Int, smallest: Int, mode: FacetedForgeMode = .campaign,
                                trace: [FacetedForgeAction]) -> Bool               // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension FacetedForgeMode { case replay(level: Int) }
public enum FacetedForgeReconciliation {
    public static let maxTraceLength: Int   // 32
    public static func netTrace(_ records: [FacetedForgeRecord]) -> [FacetedForgeAction]
    public static func reconcile(_ progress: FacetedForgeProgress) -> (progress: FacetedForgeProgress, dropped: Int)
    public static func verifies(level: Int, result: FacetedForgeProgress.Result) -> Bool
}
// FacetedForgeExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g08.no-replay, r02-g08.replay-end, r02-g08.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// FacetedForgeFeedbackPlan: refusal words for the three codes; a replay step announced like the action.
```
