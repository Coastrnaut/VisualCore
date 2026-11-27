# Research: R02-G21-09

- **R1 — Interface test pattern.** Decision: follow feature 499 (`MW` namespace, launch arguments, identifiers via
  `port.identifier`, a serial chunk); the namespace is `BG` (unused by any UI test class or folder) and the chunk key
  `d4` (grepped free in `scripts/release_check.py` on 2026-11-27). Rationale: proven in the release checks; serial
  chunks avoid idle-wait timeouts with live rendering. Alternatives: parallel clones (rejected: the oscilloscope lesson
  of feature 066).
- **R2 — Driving a win through the interface.** Decision: the interface test cannot import the Core, so level 1's
  certified plan (read from `docs/games/binary-gardens/levels/001.witness.json`: `{luminosity: {star: 1, index: 0}}`,
  then `{run: {}}`; budget 9; two luminosity levels; only star 2's ring and luminosity adjustable) is fixed in
  `BGSupport` and asserted equal to the Core by an app unit test. The test taps the `star` picker's "Star 2" segment
  until its value reads "star 2" (presentation only, no action spent), checks the `luminosity` value reads "level 2 of
  2", taps `luminosity-minus` and counts the press only when the `actions` text moves from 9 to 8 actions left and the
  value reads "level 1 of 2" (never a second press once it does: the lowest level would be refused); then taps `run`,
  which spends no action (`BinaryGardensPlay` budgets arrangement actions only). Rationale: no test-only hooks; the
  constants are checked. Alternatives: tapping the star on the canvas (rejected: depends on the camera's projection) or
  a debug argument that solves the level (rejected: it bypasses the controls under test).
- **R3 — Stored examples.** Decision: the `schemaExample(version:)` envelope of `MushroomWeatherSchemaExamples` (payload
  of that schema, migrated and restored for the expected digest), seed 2_509. The schema-1 play applies star 2's ring to
  index 1 (`star.ring [1, 1]`, the only adjustable change on level 1 other than the certified one), so it stays playing
  and unwon; the schema-2 result spends 2 actions against the certified 1 (2 stars by feature 505's rule). Rationale:
  the registry's `SnapshotMigrationCheck` already consumes the envelope, and the X gate's AppModelTests need registered
  examples for a schema above 1 (memory schema-examples-before-x-gate).
- **R4 — Release exclusion.** Decision: no new forbidden symbol; `BinaryGardensGolden` is added to `RELEASE_FORBIDDEN`
  by feature 508 and `acceptanceScenarios` is already there. Rationale: the existing symbol check proves absence; the
  scenarios are compiled only under `DEBUG || VISUALCORE_AUTOMATION`.
- **R5 — Identifier list.** Decision: `BinaryGardensControls.identifierNames` pins every identifier the panel carries;
  today 37, each used once in the source (`actions` … `reset-view`, spec clarifications); features 505 … 507 add theirs
  (507's contract names `replay`, `replay-step`, `replay-stop`, `replay-position`; the others follow Mushroom Weather's
  names where the role is the same). An experience test checks the names are unique, carry the prefix
  `experience.r02-g21.binary-gardens.` and appear once each in the panel source. If 505 gives the failure explanation
  the `failure` identifier too, it gets its own `explanation`, as in feature 499. The level line (`targetLabel`) has no
  identifier and none is added: no test reads it. Rationale: one identifier per element keeps lookups unambiguous.
- **R6 — Visibility.** Decision: an app unit test opens the bundled catalog without `-vcCandidates` (not available, no
  tile, not opened) and checks `ExperienceRegistry.candidates` holds the id and `all` does not, as feature 499 did.
