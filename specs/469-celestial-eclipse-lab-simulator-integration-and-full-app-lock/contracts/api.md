# Contract: R02-G17-09

```swift
extension CelestialEclipseLabExperienceCore {
    public static func schemaExamplePayload(version: Int) -> [String: Any]?   // 1 or 2
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample?
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample?
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample?
}
// Panel identifiers: experience.r02-g17.celestial-eclipse-lab.{planet, planet-minus, planet-plus, planet-detail, phase,
// phase-minus, phase-plus, set-phase, reset-view, tick, tick-minus, tick-plus, tick-detail, run, undo, redo,
// next-level, dismiss-tutorial, hint, campaign, daily, practice, level-picker, play-level, replay, replay-step,
// replay-stop, sound, actions, status, failure, explanation, progress, summary, message, tutorial, hint-text, band,
// stars, goal, replay-position}
// CelestialEclipseLabControls.identifierNames lists them, each once.
// release_check.py: UI_CHUNKS["z3"] = ["CELPlayUITests", "CELReplayUITests"]; "z3" in SERIAL_CHUNKS
```
