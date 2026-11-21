# Feature Specification: R02-G04-09 — Hue Compass: simulator integration and full app lock

**Feature Branch**: `339-hue-compass-simulator-integration-and-full-app-lock` (spec directory only; work on
`main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G04-09 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0409-###,
SC-R02G0409-###, T-R02G0409-###

**Input**: User description: the archived R02-G04-09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Compile actual target, XCUITest, logic test, all-level solvability and release config" for Hue Compass, with
the canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/339-hue-compass-simulator-integration-and-full-app-lock`;
  FR-R02G0409-###, SC-R02G0409-###, T-R02G0409-###.
- **Packaging (ADR-0009):** experience R02-G04 (`r02-g04.hue-compass`, free; a registered candidate) in the one
  VisualCore app. "The actual target" is the one app target with Hue Compass linked; no per-game target, bundle
  identifier, scheme or store listing. Hue Compass stays a candidate (not available to players) until X-R02-G04.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** playing on D1/D2/D3 after ImplementationLock-100 (feature 340
  prepares it). **Owner-only items:** none (no signing is needed for simulator builds).
- **Shared features used:** the app's debug launch arguments (`-vcCandidates`, `-openExperience`, `-vcResetData`,
  `-vcSkipWelcome`), the app's interface test support, the registry's stored migration examples and the release checks.
- **Model:** feature 329 (Wave Knot Keeper), itself after features 319 and 309. Already in place from earlier Hue Compass
  features: panel play with the turn buttons, Probe, the band stepper and Select (features 333, 334), the round-two
  opening seed 0, the test-only golden code in the Release symbol list (feature 338).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
329's answers. Facts checked in code (read-only, 2026-11-21): feature 329 (Wave Knot Keeper) is the model
(`Apps/VisualCore/Tests/UI/WaveKnotKeeper`, namespace `WK`, serial chunk `l3`; identifiers through
`port.identifier(name)`; `WaveKnotKeeperSchemaExamples.swift`); Hue Compass's panel (`HueCompassControls`) has labels
and values but no identifiers; its registration in `Apps/VisualCore/App/ExperienceRegistry.swift` still says "Snapshot
schema 1, so no earlier example is stored yet" although the snapshot is schema 3 since feature 337; the canvas
description (`HueCompassPresenter.describe`) names the level, the bearing and band, the clues, the units and, when won,
"The bearing and hue match. k of 3 stars."; `RELEASE_FORBIDDEN` already holds `HueCompassGolden` (feature 338); the UI
chunk keys in `release_check.py` use up to `l3` and not `m3`; no `HC` namespace exists in the app's tests.

- Q: How do the interface tests find controls and what do they read? → A: every panel control gets the identifier
  `experience.r02-g04.hue-compass.<name>` through `port.identifier(name)`: the buttons `turn-minus-4`, `turn-minus-1`,
  `turn-plus-1`, `turn-plus-4`, `probe`, `select`, `undo`, `redo`, `next-level`, `reset-view`, `hint`,
  `dismiss-tutorial`, `retry`, `campaign`, `daily`, `practice`, `replay`, `replay-step`, `replay-stop`, the stepper
  `band-picker`, the menu `level-picker`, the toggle `sound` and the summary element `summary`. The tests read the canvas
  description for the level, the bearing and the stars, and the replay step's value for the replay position. Impact:
  FR-R02G0409-001, 002.
- Q: Which interface tests exist and how are they grouped? → A: namespace `HC` in
  `Apps/VisualCore/Tests/UI/HueCompass/HCSupport.swift`; `HCPlayUITests` (fresh launch with `-vcResetData
  -vcSkipWelcome -vcCandidates -openExperience r02-g04.hue-compass`: dismiss the tutorial, play level 1's certified
  witness with the turn buttons (each turn split into presses of 4 and 1), Probe, the band stepper and Select, read "The
  bearing and hue match" and "3 of 3 stars", the level picker shows level 2 open; relaunch without reset: the stars and
  level 2 are kept) and `HCReplayUITests` (after the win, Replay, Step until the replay ends won, Stop back to the
  campaign). They run as a new serial chunk `m3` of `release_check.py` (its key checked unique); each test stays under 90
  s. Level 1's start bearing, target, band and witness actions are pinned in `HC` and checked against the Core by an app
  unit test. Impact: FR-R02G0409-002, 007; SC-R02G0409-001.
- Q: Which earlier-schema examples are stored and where do they come from? → A:
  `HueCompassExperienceCore.schemaOneExample()` (the schema-1 saved state of a seeded play of level 1 with one turn
  that does not win) and `schemaTwoExample()` (schema 2 with progress and level 1 solved, no trace), both
  `MigrationExample`s built in the Core (`HueCompassSchemaExamples.swift`, modelled on `WaveKnotKeeperSchemaExamples`),
  registered with `examples:`; the app's migration check restores both into schema 3 with progress kept. The
  registration's comment is corrected. Impact: FR-R02G0409-003; SC-R02G0409-002.
- Q: What proves the release configuration excludes test-only code? → A: the existing `app-release-build` and
  `app-release-symbols` steps; `HueCompassGolden` is already forbidden, and the scenarios exist only under
  `DEBUG || VISUALCORE_AUTOMATION` (covered by the existing `acceptanceScenarios` entry). Impact: FR-R02G0409-004;
  SC-R02G0409-003.
- Q: How is "not available" checked? → A: an app unit test: without `-vcCandidates` the catalog lists
  `r02-g04.hue-compass` as not available and the launcher cannot open it; the registry's candidates list contains it and
  `all` does not. Impact: FR-R02G0409-006; SC-R02G0409-002.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game works inside the real app (Priority: P1) 🎯

A tester opens Hue Compass from the one app on the simulator, plays level 1 with the panel's turn buttons, Probe, band stepper and Select to a win,
sees the stars, opens the next level, replays the best solution and returns after closing the app to find the progress
kept.

**Why this priority**: the game only matters as part of the shipped app; this is the first end-to-end proof there.

**Independent Test**: interface tests launch the app with the candidate made available for testing, drive only the
visible, labelled controls and read the experience's spoken description.

**Acceptance Scenarios**:

1. **Given** a fresh app on the simulator, **When** the tester opens Hue Compass, plays level 1's certified solution with
   the turn buttons, Probe, the band stepper and Select, **Then** the level is won, the stars are shown and the
   next level opens.
2. **Given** a won level, **When** the app is relaunched, **Then** the same progress, stars and open levels are shown.
3. **Given** a solved level, **When** the tester taps Replay and steps through it, **Then** the replay ends won and Stop
   returns to the campaign.

### User Story 2 - The app's logic accepts the game (Priority: P1)

The app's own unit tests open the candidate through the app's registry, play it through the app's engine, restore saved
states of every earlier schema and confirm the candidate is not listed as available.

**Independent Test**: app unit tests with the registry, the engine and the stored migration examples.

### User Story 3 - Both build configurations compile and every level is solvable (Priority: P2)

The app compiles in its debug and release configurations for the simulator with Hue Compass linked, and the
solver regression proves all 100 levels solvable as certified.

**Independent Test**: a debug and a release simulator build of the app succeed; the regression of feature 338 passes.

### Edge Cases

- **Candidate visibility:** without the testing argument the game is not listed as available and cannot be opened from
  the catalog; with it, tests can open it.
- **Earlier saves:** stored schema-1 and schema-2 examples restore through the app and migrate to schema 3.
- **Release builds:** test-only code (scenarios, golden descriptions) is excluded from the release configuration, which
  must still compile.
- **Interface lookup:** every control the tests use has a stable identifier, so tests do not depend on wording.
- **Relaunch:** the interface test sends the app to the background before terminating it, so the save point runs (the
  lesson of feature 309).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0409-001**: The panel's controls MUST carry stable accessibility identifiers (experience prefix plus control
  name) in addition to their labels and values.
- **FR-R02G0409-002**: Interface tests in the one app MUST open Hue Compass with the candidate testing argument,
  win level 1 through the panel alone, see the stars and the next level, relaunch with progress kept, and replay a
  solved level to its end.
- **FR-R02G0409-003**: The app registration MUST store the schema-1 and schema-2 migration examples, and the app's unit
  tests MUST restore both and open the candidate through the registry and engine.
- **FR-R02G0409-004**: The app MUST compile in the debug and release configurations for the simulator with Hue
  Compass linked; test-only code MUST be excluded from release.
- **FR-R02G0409-005**: The all-level solvability regression (feature 338) MUST pass in this gate's evidence.
- **FR-R02G0409-006**: Hue Compass MUST stay a candidate: not listed as available, not openable from the catalog
  without the testing argument.
- **FR-R02G0409-007**: Existing tests MUST pass; the release checks that cover the app (interface test groups, app unit
  tests, app build) MUST include the new tests; the reference regression passes.

### Key Entities

- **Interface test group**: the Hue Compass interface tests, named in the release checks' groups.
- **Migration example**: a stored saved state of an earlier schema with its expected restore.
- **Build configuration**: debug and release builds of the one app for the simulator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0409-001**: The interface tests win level 1, keep progress over a relaunch and replay a solved level; each
  test finishes in under 90 seconds on the simulator.
- **SC-R02G0409-002**: The app unit tests restore both earlier-schema examples and open the candidate; the candidate is
  not listed as available.
- **SC-R02G0409-003**: Debug and release simulator builds of the app succeed.
- **SC-R02G0409-004**: The solver regression passes for 100 of 100 levels.
- **SC-R02G0409-005**: Existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G0409-006** {device}: after ImplementationLock-100, the same journeys on D1/D2/D3 (feature 340 prepares them).

## Assumptions

- Interface tests follow the app's existing patterns (one namespace of helpers per experience, launch arguments,
  identifiers, short waits), as Aurora Loom's `AL` tests.
- The interface tests' 90-second bound sits inside the app's 180-second per-test allowance.

## Traceability

| Source item (round2.md R2-G04-09) | Requirement |
|---|---|
| Compile actual target | FR-R02G0409-004 |
| XCUITest | FR-R02G0409-001, 002 |
| Logic test | FR-R02G0409-003 |
| All-level solvability | FR-R02G0409-005 |
| Release config | FR-R02G0409-004 |
| Schema migration | FR-R02G0409-003 |
| Excluded scope | device journeys (SC-R02G0409-006), price, per-game app |
