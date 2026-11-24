# API contract: R02-G14-07 (MoonlitMechanismCore additions)

```swift
extension MoonlitMechanismProgress.Result { public let trace: [MoonlitMechanismAction]; public let verified: Bool }
extension MoonlitMechanismProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: MoonlitMechanismMode = .campaign,
                                trace: [MoonlitMechanismAction]) -> Bool             // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension MoonlitMechanismMode { case replay(level: Int) }
public enum MoonlitMechanismReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [MoonlitMechanismRecord]) -> [MoonlitMechanismAction]
    public static func reconcile(_ progress: MoonlitMechanismProgress) -> (progress: MoonlitMechanismProgress, dropped: Int)
    public static func verifies(level: Int, result: MoonlitMechanismProgress.Result) -> Bool
}
// MoonlitMechanismExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g14.no-replay, r02-g14.replay-end, r02-g14.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// MoonlitMechanismFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
