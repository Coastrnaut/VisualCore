# Research: R02-G08-09

- **R1 — Interface test pattern.** Decision: follow feature 369 (`AE` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified cuts (piece, direction, depth) and the pickers' starting choice (`FacetedForgePreviewChoice.initial`) are
  fixed constants in `FFSupport`, asserted equal to the Core (`FacetedForgeExperienceCore.certifiedActions(1)` and the
  initial choice of level 1's fresh play) by an app unit test; for each cut the test steps the piece, direction and
  depth steppers from the current choice to the cut's values (reading each stepper's value) and taps Cut.
  Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that solves the level
  (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `AmethystEscapeSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `FacetedForgeGolden` (feature 378) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
