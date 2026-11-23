# Research: R02-G11-09

- **R1 — Interface test pattern.** Decision: follow feature 399 (`BA` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `ECG` because `EC` is Effects Composer's. Rationale: proven in
  the release checks; serial chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones
  (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified actions (pulses from (0, 3) and (0, 2), then a claim at (1, 2)) and the cursor's starting cell (the entry,
  column 0, row 3) are fixed constants in `ECGSupport`, asserted equal to the Core
  (`EchoCartographerExperienceCore.certifiedActions(1)` and level 1's entry) by an app unit test; for each action the
  test steps the column and row steppers from the cursor's current cell to the action's cell, reading each stepper's
  value ("column c", "row r"), and taps Pulse or Claim. Rationale: no test-only hooks; the constants are checked.
  Alternatives: tapping the canvas cell (rejected: depends on the camera's projection) or a debug argument that solves
  the level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `BackwardsAuroraSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `EchoCartographerGolden` (feature 408) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
