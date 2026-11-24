# API contract: R02-G15-07 (VoxelOrigamiCore additions)

```swift
extension VoxelOrigamiProgress.Result { public let trace: [VoxelOrigamiAction]   // .turn(hinge, step) each
   ; public let verified: Bool }
extension VoxelOrigamiProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: VoxelOrigamiMode = .campaign,
                                trace: [VoxelOrigamiAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension VoxelOrigamiMode { case replay(level: Int) }
public enum VoxelOrigamiReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [VoxelOrigamiRecord]) -> [VoxelOrigamiAction]
    public static func reconcile(_ progress: VoxelOrigamiProgress) -> (progress: VoxelOrigamiProgress, dropped: Int)
    public static func verifies(level: Int, result: VoxelOrigamiProgress.Result) -> Bool
}
// VoxelOrigamiExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g15.no-replay, r02-g15.replay-end, r02-g15.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// VoxelOrigamiFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
