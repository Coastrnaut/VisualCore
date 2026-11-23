# Contract: R02-G12-09

```swift
extension HarmonicBridgesExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g12.harmonic-bridges.{string, peg, tune, test, undo, redo, next-level, reset-view,
// dismiss-tutorial, hint, failure-undo, retry, campaign, daily, practice, level-picker, play-level, replay, replay-step,
// replay-stop, sound, summary, status, actions, message, failure, instruction, hint-text, goal, replay-position}
// HarmonicBridgesControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["u3"] = ["HBPlayUITests", "HBReplayUITests"]; "u3" in SERIAL_CHUNKS
```
