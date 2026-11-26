# Contract: R02-G18-09

```swift
extension ApsidesWorkshopExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g18.apsides-workshop.{eccentricity, eccentricity-minus, eccentricity-plus,
// direction, direction-minus, direction-plus, size, size-minus, size-plus, orbit-detail, set-periapsis, set-size,
// reset-view, pending-reason, tick, tick-minus, tick-plus, tick-detail, play, undo, redo, next-level, dismiss-tutorial,
// hint, campaign, daily, practice, level-picker, play-level, replay, replay-step, replay-stop, sound, actions, status,
// failure, explanation, progress, summary, message, tutorial, hint-text, band, stars, goal, replay-position}
// ApsidesWorkshopControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["a4"] = ["AWPlayUITests", "AWReplayUITests"]; "a4" in SERIAL_CHUNKS
```
