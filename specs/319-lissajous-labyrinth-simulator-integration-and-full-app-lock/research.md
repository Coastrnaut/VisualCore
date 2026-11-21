# Research: R02-G02-09

- **R1 — Interface test pattern.** Decision: follow feature 309 (`AL` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's start
  dials and certified final dials are fixed constants in `LLSupport`, asserted equal to the Core
  (`LissajousLabyrinthExperienceCore.generated(number: 1)`, the level's start and its solution's final dials) by an app
  unit test; the test taps each stepper's increment or decrement the shorter way round until its value reaches the
  target, then Apply. Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that
  solves the level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `AuroraLoomSchemaExamples` (payload of
  that schema, migrated and restored for the expected digest). Rationale: the registry's `SnapshotMigrationCheck`
  already consumes it, and the X gate's AppModelTests need registered examples for a schema above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `LissajousLabyrinthGolden` (feature 318) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
