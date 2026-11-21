# Research: R02-G01-09

- **R1 — Interface test pattern.** Decision: follow A21 (`AU` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so it knows level
  1's certified target steps as fixed constants (pinned in `ALSupport`, and an app unit test asserts them equal to the
  Core's certified solution, so a regenerated catalog fails loudly); it reads each stepper's value and taps increment or
  decrement until every ribbon's wave and phase reach the targets. Rationale: no test-only hooks in the app; the
  constants are checked. Alternatives: a debug launch argument that solves the level (rejected: it would bypass the
  player's controls the test must prove).
- **R3 — Stored examples.** Decision: A18's `schemaExample(version:)` envelope (payload of that schema, migrated and
  restored for the expected digest). Rationale: the registry's `SnapshotMigrationCheck` already consumes it.
- **R4 — Release exclusion.** Decision: forbid `AuroraLoomGolden` and `acceptanceScenarios` in the Release binary's
  symbols. Rationale: both exist only under `DEBUG || VISUALCORE_AUTOMATION`; the existing symbol check proves absence.
