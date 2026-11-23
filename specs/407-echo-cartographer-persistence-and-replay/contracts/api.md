# API contract: R02-G11-07 (EchoCartographerCore additions)

```swift
extension EchoCartographerProgress.Result { public let trace: [EchoCartographerAction]; public let verified: Bool }
extension EchoCartographerProgress {
    public mutating func record(level: Int, energySpent: Int, certified: Int, mode: EchoCartographerMode = .campaign,
                                trace: [EchoCartographerAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension EchoCartographerMode { case replay(level: Int) }
public enum EchoCartographerReconciliation {
    public static let maxTraceLength: Int   // 128
    public static func netTrace(_ records: [EchoCartographerRecord]) -> [EchoCartographerAction]
    public static func reconcile(_ progress: EchoCartographerProgress) -> (progress: EchoCartographerProgress, dropped: Int)
    public static func verifies(level: Int, result: EchoCartographerProgress.Result) -> Bool
}
// EchoCartographerExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g11.no-replay, r02-g11.replay-end, r02-g11.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// EchoCartographerFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
