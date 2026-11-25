# Research: R02-G17-09

- **R1 — Interface test pattern.** Decision: follow feature 459 (`SC` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `CEL` (unused by any UI test class). Rationale: proven in the
  release checks; serial chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones (rejected:
  the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified plan (body 1 to phase 2, then body 2 to phase 0) is fixed in `CELSupport`, asserted equal to the Core
  (`CelestialEclipseLabExperienceCore.certifiedActions(1)`) by an app unit test; for each change the test reads the
  planet control's value and taps Planet + or Planet − until the body is chosen, reads the phase control's value and
  taps Phase + or Phase − until the pending phase is the target (presentation only, no action spent), then taps Set
  phase, reading the `actions` text before and after and counting a press only when the actions-left count moves;
  finally it taps Run. Rationale: no test-only hooks; the constants are checked. Alternatives: dragging planets on the
  canvas (rejected: depends on the camera's projection) or a debug argument that solves the level (rejected: it
  bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `StarlitCartoucheSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1 (memory schema-examples-before-x-gate).
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `CelestialEclipseLabGolden` (feature 468) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
- **R5 — Identifier list.** Decision: the failure explanation, which shared `failure` with the short failure line (the
  two never show together), gets its own identifier `explanation`; `CelestialEclipseLabControls.identifierNames` pins
  the 41 names and an experience test checks they are unique and that the panel source uses each exactly once.
  Rationale: one identifier per element keeps lookups unambiguous; a renamed identifier would otherwise silently break
  the interface tests. No existing test reads the explanation by identifier.
