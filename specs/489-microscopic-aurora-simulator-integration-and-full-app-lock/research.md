# Research: R02-G19-09

- **R1 — Interface test pattern.** Decision: follow feature 479 (`AW` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `MA` (unused by any UI test class). Rationale: proven in the
  release checks; serial chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones (rejected:
  the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified plan (its wells in placement order, each a slot, a site, a strength 1 … 4 and a sense, read from
  `MicroscopicAuroraExperienceCore.certifiedActions(1)` when the tests are written) is fixed in `MASupport` and
  asserted equal to the Core by an app unit test; for each well the test taps Well − or + until the `slot` value names the well, Site − or +
  until the `site` value names the target site, Strength − or + until the `strength` value is the target, the sense
  toggle until its label matches (presentation only, no action spent), then taps Place, reading the `actions` text
  before and after and counting a press only when the actions-left count moves; finally it taps Play. Rationale: no
  test-only hooks; the constants are checked. Alternatives: dragging the wells on the canvas (rejected:
  depends on the camera's projection) or a debug argument that solves the level (rejected: it bypasses the controls
  under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `MicroscopicAuroraSchemaExamples`
  (payload of that schema, migrated and restored for the expected digest). Rationale: the registry's
  `SnapshotMigrationCheck` already consumes it, and the X gate's AppModelTests need registered examples for a schema
  above 1 (memory schema-examples-before-x-gate).
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `MicroscopicAuroraGolden` (feature 488) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
- **R5 — Identifier list.** Decision: the failure explanation, which shared `failure` with the short failure line (the
  two never show together), gets its own identifier `explanation`; `MicroscopicAuroraControls.identifierNames` pins
  the 48 names and an experience test checks they are unique and that the panel source uses each exactly once.
  Rationale: one identifier per element keeps lookups unambiguous; a renamed identifier would otherwise silently break
  the interface tests. No existing test reads the explanation by identifier.
