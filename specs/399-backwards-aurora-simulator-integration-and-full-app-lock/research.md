# Research: R02-G10-09

- **R1 — Interface test pattern.** Decision: follow feature 389 (`NG` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified reversals (start, end) and the steppers' starting section (start 0, end 1) are fixed constants in
  `BASupport`, asserted equal to the Core (`BackwardsAuroraExperienceCore.certifiedActions(1)` and the panel's opening
  section) by an app unit test; for each reversal the test steps the end stepper up first, then the start stepper (so
  the start never has to pass the end), then lowers the end if needed, reading each stepper's value, and taps
  Reverse.
  Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that solves the level
  (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `NocturneGardenSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `BackwardsAuroraGolden` (feature 398) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
