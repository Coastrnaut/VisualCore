# Research: R02-G05-09

- **R1 — Interface test pattern.** Decision: follow feature 339 (`HC` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified actions (carves, valves, steps) and the order of its carvable cells at the start are fixed constants in
  `CCSupport`, asserted equal to the Core (`ColorfallCanyonsExperienceCore.certifiedActions(1)` and the level's
  carvable cells) by an app unit test; the test steps the cell picker to each certified carve cell (by its index in the
  carvable order, which a carve can change, so the index is recomputed from the pinned order after each carve), taps
  Carve, taps each certified valve button and taps Run. Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that solves the
  level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `ColorfallCanyonsSchemaExamples` (payload of
  that schema, migrated and restored for the expected digest). Rationale: the registry's `SnapshotMigrationCheck`
  already consumes it, and the X gate's AppModelTests need registered examples for a schema above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `ColorfallCanyonsGolden` (feature 348) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
