# Contract: R02-G08-09

```swift
extension FacetedForgeExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g08.faceted-forge.{cut, undo, redo, next-level, depth-down, depth-up, reset-view,
// hint, dismiss-tutorial, failure-undo, retry, campaign, daily, practice, play-level, replay, replay-step, replay-stop,
// piece-picker, direction-picker, depth-picker, level-picker, sound, summary}
// FacetedForgeControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["q3"] = ["FFPlayUITests", "FFReplayUITests"]; "q3" in SERIAL_CHUNKS
```
