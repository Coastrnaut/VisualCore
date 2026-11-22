# Contract: R02-G06-09

```swift
extension ChronoConstellatorExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g06.chrono-constellator.{phase-down, phase-up, add-hold, remove-hold, step-1,
// step-10, run, rewind, undo, redo, next-level, reset-view, hint, dismiss-tutorial, failure-undo, failure-rewind, retry,
// campaign, daily, practice, play-level, replay, replay-step, replay-stop, star-picker, level-picker, sound, summary}
// ChronoConstellatorControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["o3"] = ["CRPlayUITests", "CRReplayUITests"]; "o3" in SERIAL_CHUNKS
```
