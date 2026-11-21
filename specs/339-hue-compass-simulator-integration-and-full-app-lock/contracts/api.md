# Contract: R02-G04-09

```swift
extension HueCompassExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g04.hue-compass.{turn-minus-4, turn-minus-1, turn-plus-1, turn-plus-4, probe,
// band-picker, select, undo, redo, next-level, reset-view, hint, dismiss-tutorial, retry, campaign, daily, practice,
// replay, replay-step, replay-stop, level-picker, sound, summary}
// HueCompassControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["m3"] = ["HCPlayUITests", "HCReplayUITests"]; "m3" in SERIAL_CHUNKS
```
