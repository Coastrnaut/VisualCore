# Contract: R02-G09-09

```swift
extension NocturneGardenExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g09.nocturne-garden.{plant, move, resize, remove, set-sun, undo, redo, next-level,
// reset-view, hint, dismiss-tutorial, failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step,
// replay-stop, kind-picker, column-picker, row-picker, size-picker, bloom-picker, sun-picker, level-picker, sound,
// summary}
// NocturneGardenControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["r3"] = ["NGPlayUITests", "NGReplayUITests"]; "r3" in SERIAL_CHUNKS
```
