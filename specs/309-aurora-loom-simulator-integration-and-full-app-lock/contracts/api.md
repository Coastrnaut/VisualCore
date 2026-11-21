# Contract: R02-G01-09

```swift
extension AuroraLoomExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Presenter (experience, internal): mirror.pending: AuroraLoomSteps? ; func stepPending(ribbon:control:by:) ;
//   func applyPending(port:) -> [ActionResult] ; func clearPending()
// Panel identifiers: experience.r02-g01.aurora-loom.{wave-1…3, phase-1…3, apply, clear, undo, redo, next-level, hint, retry, daily,
// practice, campaign, level-picker, replay, replay-step, replay-stop, sound, skip-tutorial}
// release_check.py: UI_CHUNKS["i3"] = ["ALPlayUITests", "ALReplayUITests"]; "i3" in SERIAL_CHUNKS;
// RELEASE_FORBIDDEN += ["AuroraLoomGolden", "acceptanceScenarios"]
```
