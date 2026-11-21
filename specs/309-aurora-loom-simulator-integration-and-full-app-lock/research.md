# Research: R02-G01-09

- **R1 — Interface test pattern.** Decision: follow A21 (`AU` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the test computes level 1's certified solution from the
  experience's description? No: the interface test cannot import the Core, so it reads the steppers' values and taps
  increment/decrement until each ribbon's wave and phase equal the solution's targets, which the test knows as fixed
  constants of level 1 (pinned in `ALSupport` and asserted by an app unit test against the Core, so a regenerated
  catalog fails loudly). Rationale: no test-only hooks in the app; constants are checked.
- **R3 — Stored examples.** Decision: A18's `schemaExample(version:)` envelope (payload of that schema, migrated and
  restored for the expected digest). Rationale: the registry's `SnapshotMigrationCheck` already consumes it.
- **R4 — Release exclusion.** Decision: forbid `AuroraLoomGolden` and `acceptanceScenarios` in the Release binary's
  symbols. Rationale: both exist only under `DEBUG || VISUALCORE_AUTOMATION`; the existing symbol check proves absence.
