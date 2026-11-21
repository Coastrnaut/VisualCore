# Research: R02-G03-09

- **R1 — Interface test pattern.** Decision: follow feature 319 (`LL` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's point
  count, allowance and certified solution moves (point, direction index) are fixed constants in `WKSupport`, asserted equal to the
  Core (`WaveKnotKeeperExperienceCore.generated(number: 1)`, the level's points and its solution's moves) by an app unit
  test; for each move the test steps the point picker the shorter way round to the move's point, then taps the move's
  direction button. Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that
  solves the level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `AuroraLoomSchemaExamples` (payload of
  that schema, migrated and restored for the expected digest). Rationale: the registry's `SnapshotMigrationCheck`
  already consumes it, and the X gate's AppModelTests need registered examples for a schema above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `WaveKnotKeeperGolden` (feature 328) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
