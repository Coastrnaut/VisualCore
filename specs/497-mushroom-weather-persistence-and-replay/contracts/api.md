# API contract: R02-G20-07 (MushroomWeatherCore additions)

```swift
extension MushroomWeatherProgress.Result { public let trace: [MushroomWeatherAction]; public let verified: Bool }
    // each trace entry is a pod, vent or moonlight action as the kernel applied it; the last is `.run`
extension MushroomWeatherProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: MushroomWeatherMode = .campaign,
                                trace: [MushroomWeatherAction]) -> Bool         // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension MushroomWeatherMode { case replay(level: Int) }
public enum MushroomWeatherReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [MushroomWeatherRecord]) -> [MushroomWeatherAction]
    public static func reconcile(_ progress: MushroomWeatherProgress) -> (progress: MushroomWeatherProgress, dropped: Int)
    public static func verifies(level: Int, result: MushroomWeatherProgress.Result) -> Bool
}
// MushroomWeatherExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g20.no-replay, r02-g20.replay-end, r02-g20.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// MushroomWeatherFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
