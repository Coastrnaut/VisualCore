# Contract: R02-G03-09

```swift
extension WaveKnotKeeperExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g03.wave-knot-keeper.{point-picker, move-plus-x, move-minus-x, move-plus-y,
// move-minus-y, move-over, move-under, undo, redo, next-level, reset-view, hint, dismiss-tutorial, failure-undo, retry,
// campaign, daily, practice, replay, replay-step, replay-stop, level-picker, sound}
// release_check.py: UI_CHUNKS["l3"] = ["WKPlayUITests", "WKReplayUITests"]; "l3" in SERIAL_CHUNKS
```
