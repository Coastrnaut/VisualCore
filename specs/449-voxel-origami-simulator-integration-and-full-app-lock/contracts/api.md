# Contract: R02-G15-09

```swift
extension VoxelOrigamiExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g15.voxel-origami.{hinge, hinge-minus, hinge-plus, hinge-detail, turn-minus,
// turn-plus, undo, redo, next-level, reset-view, dismiss-tutorial, hint, failure-undo, retry, campaign, daily,
// practice, level-picker, play-level, replay, replay-step, replay-stop, sound, summary, status, actions, pending,
// progress, message, failure, explanation, instruction, hint-text, goal, replay-position}
// VoxelOrigamiControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["x3"] = ["VOPlayUITests", "VOReplayUITests"]; "x3" in SERIAL_CHUNKS
```
