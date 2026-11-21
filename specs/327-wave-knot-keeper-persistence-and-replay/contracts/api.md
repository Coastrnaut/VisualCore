# API contract: R02-G03-07 (WaveKnotKeeperCore additions)

```swift
extension WaveKnotKeeperProgress.Result { public let trace: [WaveKnotKeeperMove]; public let verified: Bool }
extension WaveKnotKeeperProgress {
    public mutating func record(level: Int, moves: Int, shortest: Int, opensNext: Bool,
                                trace: [WaveKnotKeeperMove])                     // verified result
    public mutating func drop(level: Int)                                               // reconciliation only
}
extension WaveKnotKeeperMode { case replay(level: Int) }
public enum WaveKnotKeeperReconciliation {
    public static func reconcile(_ progress: WaveKnotKeeperProgress) -> (progress: WaveKnotKeeperProgress, dropped: Int)
    public static func verifies(level: Int, result: WaveKnotKeeperProgress.Result) -> Bool
}
// WaveKnotKeeperExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop"; codes r02-g03.no-replay, r02-g03.replay-end, r02-g03.replay;
// public var reconciliationDropped: Int (not digested).
```
