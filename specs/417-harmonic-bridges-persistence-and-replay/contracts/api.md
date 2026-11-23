# API contract: R02-G12-07 (HarmonicBridgesCore additions)

```swift
extension HarmonicBridgesProgress.Result { public let trace: [HarmonicBridgesAction]; public let verified: Bool }
extension HarmonicBridgesProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: HarmonicBridgesMode = .campaign,
                                trace: [HarmonicBridgesAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension HarmonicBridgesMode { case replay(level: Int) }
public enum HarmonicBridgesReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [HarmonicBridgesRecord]) -> [HarmonicBridgesAction]
    public static func reconcile(_ progress: HarmonicBridgesProgress) -> (progress: HarmonicBridgesProgress, dropped: Int)
    public static func verifies(level: Int, result: HarmonicBridgesProgress.Result) -> Bool
}
// HarmonicBridgesExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g12.no-replay, r02-g12.replay-end, r02-g12.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// HarmonicBridgesFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
