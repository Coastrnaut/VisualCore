# Contract: R02-G05-09

```swift
extension ColorfallCanyonsExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g05.colorfall-canyons.{carve, valve-0, valve-1, valve-2, step-1,
// step-10, run, undo, redo, next-level, reset-view, hint, dismiss-tutorial, failure-undo, retry, campaign, daily, practice,
// play-level, replay, replay-step, replay-stop, cell-picker, level-picker, sound, summary}
// ColorfallCanyonsControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["n3"] = ["CCPlayUITests", "CCReplayUITests"]; "n3" in SERIAL_CHUNKS
```
