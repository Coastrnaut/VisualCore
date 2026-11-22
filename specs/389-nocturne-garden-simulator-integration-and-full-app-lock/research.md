# Research: R02-G09-09

- **R1 — Interface test pattern.** Decision: follow feature 379 (`AE` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified moves (plants as kind, column, row, size; sun moves as elevation) and the pickers' starting picks (the
  level's first supplied kind, column 0, row 0, its smallest size, its opening sun) are fixed constants in `NGSupport`,
  asserted equal to the Core (`NocturneGardenExperienceCore.certifiedActions(1)` and level 1's supply, sizes and sun) by
  an app unit test; for each plant the test steps the kind, column, row and size steppers from the current picks to the
  plant's values (reading each stepper's value) and taps Plant; for a sun move it steps the sun stepper and taps Set
  sun.
  Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that solves the level
  (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `FacetedForgeSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `NocturneGardenGolden` (feature 388) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
