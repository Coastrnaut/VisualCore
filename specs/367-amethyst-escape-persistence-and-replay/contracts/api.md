# API contract: R02-G07-07 (AmethystEscapeCore additions)

```swift
extension AmethystEscapeProgress.Result { public let trace: [AmethystEscapeAction]; public let verified: Bool }
extension AmethystEscapeProgress {
    public mutating func record(level: Int, moves: Int, smallest: Int, mode: AmethystEscapeMode = .campaign,
                                trace: [AmethystEscapeAction]) -> Bool               // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension AmethystEscapeMode { case replay(level: Int) }
public enum AmethystEscapeReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [AmethystEscapeRecord]) -> [AmethystEscapeAction]
    public static func reconcile(_ progress: AmethystEscapeProgress) -> (progress: AmethystEscapeProgress, dropped: Int)
    public static func verifies(level: Int, result: AmethystEscapeProgress.Result) -> Bool
}
// AmethystEscapeExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g07.no-replay, r02-g07.replay-end, r02-g07.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// AmethystEscapeFeedbackPlan: refusal words for the three codes; a replay step announced like the action.
```
