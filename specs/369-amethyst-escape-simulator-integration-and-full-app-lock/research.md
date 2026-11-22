# Research: R02-G07-09

- **R1 — Interface test pattern.** Decision: follow feature 359 (`CR` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified actions (turns of a shell by ±1 and advances) and the shell picker's starting shell are fixed constants in
  `AESupport`, asserted equal to the Core (`AmethystEscapeExperienceCore.certifiedActions(1)`) by an app unit test; for
  each turn the test steps the shell picker to that shell and taps Turn + or Turn −; for each advance it taps Advance.
  Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that solves the level
  (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `ChronoConstellatorSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `AmethystEscapeGolden` (feature 368) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
