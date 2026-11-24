# Research: R02-G14-09

- **R1 — Interface test pattern.** Decision: follow feature 429 (`ACN` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `MM` (unused by any UI test class). Rationale: proven in the
  release checks; serial chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones (rejected:
  the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified actions (handle turn +1, lamp step −1, then the run) are fixed constants in `MMSupport`, asserted equal to
  the Core (`MoonlitMechanismExperienceCore.certifiedActions(1)`) by an app unit test; the test taps Turn + and Lamp −,
  reading the `actions` text before and after each tap and counting a press only when the actions-left count moves,
  then taps Run. Level 1's witness needs no gear choice and no re-seat, so the gear chooser stays at its opening value.
  Rationale: no test-only hooks; the constants are checked. Alternatives: dragging gears on the canvas (rejected:
  depends on the camera's projection) or a debug argument that solves the level (rejected: it bypasses the controls
  under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `AcousticConstellatorSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1 (memory schema-examples-before-x-gate).
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `MoonlitMechanismGolden` (feature 438) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
- **R5 — Identifier list.** Decision: `MoonlitMechanismControls.identifierNames` pins the 44 names already in the
  panel; an experience test checks they are unique and that the panel source uses each exactly once. Rationale: the
  names exist but nothing pins them; a renamed identifier would silently break the interface tests.
