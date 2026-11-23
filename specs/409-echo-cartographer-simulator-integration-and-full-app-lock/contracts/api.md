# Contract: R02-G11-09

```swift
extension EchoCartographerExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g11.echo-cartographer.{pulse, claim, mark, undo, redo, next-level, reset-view, hint,
// dismiss-tutorial, failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step, replay-stop,
// column-picker, row-picker, level-picker, sound, summary}
// EchoCartographerControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["t3"] = ["ECGPlayUITests", "ECGReplayUITests"]; "t3" in SERIAL_CHUNKS
```
