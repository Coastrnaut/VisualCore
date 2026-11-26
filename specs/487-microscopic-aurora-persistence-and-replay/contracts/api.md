# API contract: R02-G19-07 (MicroscopicAuroraCore additions)

```swift
extension MicroscopicAuroraProgress.Result { public let trace: [MicroscopicAuroraAction]; public let verified: Bool }
    // each trace entry is `.place(slot:well:)` or `.remove(slot:)` as the kernel applied it; the last is `.play`
extension MicroscopicAuroraProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: MicroscopicAuroraMode = .campaign,
                                trace: [MicroscopicAuroraAction]) -> Bool         // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension MicroscopicAuroraMode { case replay(level: Int) }
public enum MicroscopicAuroraReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [MicroscopicAuroraRecord]) -> [MicroscopicAuroraAction]
    public static func reconcile(_ progress: MicroscopicAuroraProgress) -> (progress: MicroscopicAuroraProgress, dropped: Int)
    public static func verifies(level: Int, result: MicroscopicAuroraProgress.Result) -> Bool
}
// MicroscopicAuroraExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g19.no-replay, r02-g19.replay-end, r02-g19.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// MicroscopicAuroraFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
