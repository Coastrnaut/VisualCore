# Contract: R02-G19-09

```swift
extension MicroscopicAuroraExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g19.microscopic-aurora.{slot, slot-minus, slot-plus, selection, wells-detail,
// site, site-minus, site-plus, strength, strength-minus, strength-plus, sense, place, remove, freeze, reset-view, tick,
// tick-minus, tick-plus, tick-detail, play, undo, redo, next-level, dismiss-tutorial, hint, campaign, daily, practice,
// level-picker, play-level, replay, replay-step, replay-stop, sound, actions, status, failure, explanation, progress,
// summary, message, tutorial, hint-text, band, stars, goal, replay-position}
// MicroscopicAuroraControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["b4"] = ["MAPlayUITests", "MAReplayUITests"]; "b4" in SERIAL_CHUNKS
```
