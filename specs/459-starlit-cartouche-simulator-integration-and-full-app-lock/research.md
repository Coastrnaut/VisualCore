# Research: R02-G16-09

- **R1 — Interface test pattern.** Decision: follow feature 449 (`VO` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `SC` (unused by any UI test class). Rationale: proven in the
  release checks; serial chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones (rejected:
  the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified actions (to star 4 after 1 beat, then to star 5 after 0 beats) are fixed constants in `SCSupport`, asserted
  equal to the Core (`StarlitCartoucheExperienceCore.certifiedActions(1)`) by an app unit test; for each leg the test
  reads the star and wait controls' values and taps Star + or Star − and Wait + or Wait − until the leg is chosen
  (presentation only, no action spent), then taps Fly, reading the `actions` text before and after each tap and counting
  a press only when the actions-left count moves. Rationale: no test-only hooks; the constants are checked.
  Alternatives: tapping stars on the canvas (rejected: depends on the camera's projection) or a debug argument that
  solves the level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `VoxelOrigamiSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1 (memory schema-examples-before-x-gate).
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `StarlitCartoucheGolden` (feature 458) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
- **R5 — Identifier list.** Decision: `StarlitCartoucheControls.identifierNames` pins the 37 names already in the
  panel; an experience test checks they are unique and that the panel source uses each exactly once. Rationale: the
  names exist but nothing pins them; a renamed identifier would silently break the interface tests.
