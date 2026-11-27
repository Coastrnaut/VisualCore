# Contract: R02-G21-09

```swift
extension BinaryGardensExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 2_509) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 2_509) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 2_509) -> MigrationExample?
}
// Panel identifiers: experience.r02-g21.binary-gardens.<name>, today (features 503, 504): actions, status, tutorial,
// failure, progress, message, preview-refusal, star, star-detail, ring-minus, ring, ring-plus, phase-minus, phase,
// phase-plus, luminosity-minus, luminosity, luminosity-plus, tilt-minus, tilt, tilt-plus, tick-minus, tick, tick-plus,
// run, tick-detail, undo, redo, next-level, ring-choice, luminosity-choice, phase-target, set-phase, tilt-choice,
// inspect, inspect-detail, reset-view; added by 505 … 507 (expected: dismiss-tutorial, hint, hint-text, stars, goal,
// band, explanation, campaign, daily, practice, level-picker, play-level, summary, sound, replay, replay-step,
// replay-stop, replay-position), pinned as built.
// BinaryGardensControls.identifierNames lists them, each once.
// ExperienceRegistry.binaryGardens: examples: [schemaOneExample(), schemaTwoExample()].compactMap { $0 }
// release_check.py: UI_CHUNKS["d4"] = ["BGPlayUITests", "BGReplayUITests"]; "d4" in SERIAL_CHUNKS
```
