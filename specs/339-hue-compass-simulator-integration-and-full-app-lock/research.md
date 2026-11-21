# Research: R02-G04-09

- **R1 — Interface test pattern.** Decision: follow feature 329 (`WK` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk). Rationale: proven in the release checks; serial chunks avoid idle-wait timeouts
  with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's start
  bearing, target, target band, allowance and certified witness actions (turns, probes, the selection) are fixed
  constants in `HCSupport`, asserted equal to the Core (`HueCompassExperienceCore.generated(number: 1)` and
  `HueCompassWitness.actions(for:level:)`) by an app unit test; the test presses the turn buttons (each turn split into
  presses of 4 and then 1 in its direction), taps Probe, steps the band stepper the shorter way round to the band and
  taps Select. Rationale: no test-only hooks; the constants are checked. Alternatives: a debug argument that solves the
  level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `WaveKnotKeeperSchemaExamples` (payload of
  that schema, migrated and restored for the expected digest). Rationale: the registry's `SnapshotMigrationCheck`
  already consumes it, and the X gate's AppModelTests need registered examples for a schema above 1.
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `HueCompassGolden` (feature 338) and
  `acceptanceScenarios` are already in `RELEASE_FORBIDDEN`. Rationale: the existing symbol check proves absence.
