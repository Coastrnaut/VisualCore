# Contract: R02-G16-09

```swift
extension StarlitCartoucheExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g16.starlit-cartouche.{star, star-minus, star-plus, wait, wait-minus, wait-plus,
// fly, leg-detail, undo, redo, next-level, reset-view, dismiss-tutorial, hint, failure-undo, retry, campaign, daily,
// practice, level-picker, play-level, replay, replay-step, replay-stop, sound, summary, status, actions, pending,
// progress, message, failure, explanation, instruction, hint-text, goal, replay-position}
// StarlitCartoucheControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["y3"] = ["SCPlayUITests", "SCReplayUITests"]; "y3" in SERIAL_CHUNKS
```
