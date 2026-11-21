# API contract: R02-G02-07 (LissajousLabyrinthCore additions)

```swift
extension LissajousLabyrinthProgress.Result { public let trace: [LissajousLabyrinthAction]; public let verified: Bool }
extension LissajousLabyrinthProgress {
    public mutating func record(level: Int, actions: Int, shortest: Int, opensNext: Bool,
                                trace: [LissajousLabyrinthAction])                     // verified result
    public mutating func drop(level: Int)                                               // reconciliation only
}
extension LissajousLabyrinthMode { case replay(level: Int) }
public enum LissajousLabyrinthReconciliation {
    public static func reconcile(_ progress: LissajousLabyrinthProgress) -> (progress: LissajousLabyrinthProgress, dropped: Int)
    public static func verifies(level: Int, result: LissajousLabyrinthProgress.Result) -> Bool
}
// LissajousLabyrinthExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop"; codes r02-g02.no-replay, r02-g02.replay-end, r02-g02.replay;
// public var reconciliationDropped: Int (not digested).
```
