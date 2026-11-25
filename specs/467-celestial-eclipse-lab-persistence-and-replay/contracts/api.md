# API contract: R02-G17-07 (CelestialEclipseLabCore additions)

```swift
extension CelestialEclipseLabProgress.Result { public let trace: [CelestialEclipseLabAction]; public let verified: Bool }
    // each trace entry is `.phase(body, offset)` as the kernel applied it; the last is `.run`
extension CelestialEclipseLabProgress {
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: CelestialEclipseLabMode = .campaign,
                                trace: [CelestialEclipseLabAction]) -> Bool         // verified result
    public mutating func drop(level: Int)                                           // reconciliation only
}
extension CelestialEclipseLabMode { case replay(level: Int) }
public enum CelestialEclipseLabReconciliation {
    public static let maxTraceLength: Int   // 64
    public static func netTrace(_ records: [CelestialEclipseLabRecord]) -> [CelestialEclipseLabAction]
    public static func reconcile(_ progress: CelestialEclipseLabProgress) -> (progress: CelestialEclipseLabProgress, dropped: Int)
    public static func verifies(level: Int, result: CelestialEclipseLabProgress.Result) -> Bool
}
// CelestialEclipseLabExperienceCore: schemaVersion 3; migrations 1 → 2 → 3; actions + "replay.start" [1…100],
// "replay.step", "replay.stop", "settings.sound" [0…1]; codes r02-g17.no-replay, r02-g17.replay-end, r02-g17.replay;
// public var reconciliationDropped: Int (not digested); public var soundOn: Bool (snapshotted, not digested).
// CelestialEclipseLabFeedbackPlan: refusal words for the three codes; a replay step announced like the action it applies.
```
