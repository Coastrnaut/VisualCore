# Contract: R02-G02-09

```swift
extension LissajousLabyrinthExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g02.lissajous-labyrinth.{frequency-a, frequency-b, phase-a, phase-c, apply, clear,
// undo, redo, next-level, reset-view, hint, dismiss-tutorial, failure-undo, retry, campaign, daily, practice, replay,
// replay-step, replay-stop, level-picker, sound}
// release_check.py: UI_CHUNKS["k3"] = ["LLPlayUITests", "LLReplayUITests"]; "k3" in SERIAL_CHUNKS
```
