# API contract: R02-G01-07 (AuroraLoomCore additions)

```swift
extension AuroraLoomProgress.Result { public let trace: [AuroraLoomMove]; public let verified: Bool }
extension AuroraLoomProgress {
    public mutating func record(level: Int, moves: Int, shortest: Int, trace: [AuroraLoomMove])   // verified result
}
public enum AuroraLoomReconciliation {
    public static func reconcile(_ progress: AuroraLoomProgress) -> (progress: AuroraLoomProgress, dropped: Int)
    public static func verifies(level: Int, result: AuroraLoomProgress.Result) -> Bool
}
// AuroraLoomExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100], "replay.step",
// "replay.stop"; mode .replay(level:); codes r02-g01.no-replay, r02-g01.replay-end, r02-g01.replay;
// public var reconciliationDropped: Int (not digested).
```
