# Research: R02-G13-09

- **R1 — Interface test pattern.** Decision: follow feature 419 (`HB` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `ACN` (`AC` is Ambient Clock's; `ACN` is unused by any UI test class). Rationale: proven in the
  release checks; serial chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones (rejected:
  the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified actions (link stars 0 and 1, then a listen) and the panel's opening choice (star 0, partner 1) are fixed
  constants in `ACNSupport`, asserted equal to the Core (`AcousticConstellatorExperienceCore.certifiedActions(1)` and the
  presenter's opening choice) by an app unit test; for each link the test steps the star and partner steppers to the
  link's stars only when their values differ (reading each stepper's value and counting a press only when the value
  moves), taps Link, and finally taps Listen. Rationale:
  no test-only hooks; the constants are checked. Alternatives: dragging between stars on the canvas (rejected: depends on the
  camera's projection) or a debug argument that solves the level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `HarmonicBridgesSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `AcousticConstellatorGolden` (feature 428) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
- **R5 — Identifier list.** Decision: `AcousticConstellatorControls.identifierNames` pins the 35 names already in the panel;
  an experience test checks they are unique and that the panel source uses each exactly once. Rationale: the names exist
  but nothing pins them; a renamed identifier would silently break the interface tests.
