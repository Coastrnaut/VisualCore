# Research: R02-G12-09

- **R1 — Interface test pattern.** Decision: follow feature 409 (`ECG` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `HB` (unused by any UI test class). Rationale: proven in the
  release checks; serial chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones (rejected:
  the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified actions (tune string 0 to peg 12, then the test) and the panel's opening choice (string 0 at its current
  peg 11) are fixed constants in `HBSupport`, asserted equal to the Core
  (`HarmonicBridgesExperienceCore.certifiedActions(1)` and level 1's starting pegs) by an app unit test; for each tuning
  the test steps the string stepper to the tuning's string and the peg stepper to its peg, reading each stepper's value
  ("string s…", "peg p…") and counting a press only when the value moves, taps Tune, and finally taps Test. Rationale:
  no test-only hooks; the constants are checked. Alternatives: tapping a string on the canvas (rejected: depends on the
  camera's projection) or a debug argument that solves the level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `EchoCartographerSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `HarmonicBridgesGolden` (feature 418) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
- **R5 — Identifier list.** Decision: `HarmonicBridgesControls.identifierNames` pins the 30 names already in the panel;
  an experience test checks they are unique and that the panel source uses each exactly once. Rationale: the names exist
  but nothing pins them; a renamed identifier would silently break the interface tests.
