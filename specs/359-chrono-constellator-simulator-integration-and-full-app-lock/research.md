# Research: R02-G06-09

- **R1 — Interface test pattern.** Decision: follow feature 349 (`CC` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified phase changes and every star's default phase and loop length are fixed constants in `CRSupport`, asserted
  equal to the Core (`ChronoConstellatorExperienceCore.certifiedActions(1)` and the level's stars) by an app unit test;
  for each changed star the test steps the star picker to it, taps Phase + or Phase − the shorter way round its loop
  from the default to the certified phase (Phase + when (target − default) mod L ≤ L/2), then taps Run. Rationale: no
  test-only hooks; the constants are checked. Alternatives: a debug argument that solves the level (rejected: it
  bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `ColorfallCanyonsSchemaExamples` (payload of
  that schema, migrated and restored for the expected digest). Rationale: the registry's `SnapshotMigrationCheck`
  already consumes it, and the X gate's AppModelTests need registered examples for a schema above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `ChronoConstellatorGolden` (feature 358) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
