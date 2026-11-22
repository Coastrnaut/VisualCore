# Contract: R02-G07-09

```swift
extension AmethystEscapeExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g07.amethyst-escape.{turn-down, turn-up, advance, undo, redo, next-level,
// show-all-layers, reset-view, hint, dismiss-tutorial, failure-undo, retry, campaign, daily, practice, play-level,
// replay, replay-step, replay-stop, shell-picker, level-picker, sound, summary}
// AmethystEscapeControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["p3"] = ["AEPlayUITests", "AEReplayUITests"]; "p3" in SERIAL_CHUNKS
```
