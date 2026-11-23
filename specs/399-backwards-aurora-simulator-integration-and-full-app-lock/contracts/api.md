# Contract: R02-G10-09

```swift
extension BackwardsAuroraExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g10.backwards-aurora.{reverse, undo, redo, next-level, reset-view, hint,
// dismiss-tutorial, failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step, replay-stop,
// start-picker, end-picker, level-picker, sound, summary}
// BackwardsAuroraControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["s3"] = ["BAPlayUITests", "BAReplayUITests"]; "s3" in SERIAL_CHUNKS
```
