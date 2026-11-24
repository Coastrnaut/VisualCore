# Contract: R02-G13-09

```swift
extension AcousticConstellatorExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g13.acoustic-constellator.{star, partner, link, unlink, nudge-minus,
// nudge-plus, listen, undo, redo, next-level, reset-view, dismiss-tutorial, hint, failure-undo, retry, campaign, daily,
// practice, level-picker, play-level, replay, replay-step, replay-stop, sound, summary, choice, status, actions, progress,
// message, failure, instruction, hint-text, goal, replay-position}
// AcousticConstellatorControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["v3"] = ["ACNPlayUITests", "ACNReplayUITests"]; "v3" in SERIAL_CHUNKS
```
