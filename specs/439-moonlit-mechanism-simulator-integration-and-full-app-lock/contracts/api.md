# Contract: R02-G14-09

```swift
extension MoonlitMechanismExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g14.moonlit-mechanism.{gear, gear-minus, gear-plus, gear-detail, turn-minus,
// turn-plus, reseat-minus, reseat-plus, lamp, lamp-minus, lamp-plus, frame, frame-minus, frame-plus, run, undo, redo,
// next-level, reset-view, dismiss-tutorial, hint, failure-undo, retry, campaign, daily, practice, level-picker,
// play-level, replay, replay-step, replay-stop, sound, summary, status, actions, pending, progress, message, failure,
// explanation, instruction, hint-text, goal, replay-position}
// MoonlitMechanismControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["w3"] = ["MMPlayUITests", "MMReplayUITests"]; "w3" in SERIAL_CHUNKS
```
