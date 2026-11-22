# Feature Specification: R02-G06-09 — Chrono Constellator: simulator integration and full app lock

**Feature Branch**: `359-chrono-constellator-simulator-integration-and-full-app-lock` (spec directory only; work on
`main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G06-09 (migration ledger, game feature of experience R02-G06) · ID namespace FR-R02G0609-###,
SC-R02G0609-###, T-R02G0609-###

**Input**: User description: the archived R02-G06-09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Compile actual target, XCUITest, logic test, all-level solvability and release config" for Chrono Constellator, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/359-chrono-constellator-simulator-integration-and-full-app-lock`; FR-R02G0609-###,
  SC-R02G0609-###, T-R02G0609-###.
- **Packaging (ADR-0009):** "compile actual target" means the one app (`Apps/VisualCore`) with the experience
  `r02-g06.chrono-constellator` (free, a registered candidate) linked; no per-game target, bundle identifier, scheme or
  store listing. The experience stays a candidate until X-R02-G06.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** the same journeys on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 349 (Chrono Constellator's simulator integration and full app lock).

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
349's answers. Facts checked in code (read-only, 2026-11-22): feature 349 (Colorfall Canyons) is the model
(`Apps/VisualCore/Tests/UI/ColorfallCanyons`, namespace `CC`, serial chunk `n3`; identifiers through
`port.identifier(name)`; `ColorfallCanyonsSchemaExamples.swift`); Chrono Constellator's panel
(`ChronoConstellatorControls`) has labels and values but no identifiers, with two Undo and two Rewind buttons (the
failure section's and the play row's) and steppers for the level and the star; its registration in
`Apps/VisualCore/App/ExperienceRegistry.swift` still says "Snapshot schema 1, so no earlier example is stored yet"
although the snapshot is schema 3 since feature 357; the panel's "Sky" element carries the summary and, when won, the
canvas description says "Every star stands on its target." followed by "Stars: k of 3."; `RELEASE_FORBIDDEN` holds
`ChronoConstellatorGolden` (feature 358); the UI chunk keys in `release_check.py` use up to `n3` and not `o3`; no `CR`
namespace exists in the app's tests.

- Q: How do the interface tests find controls and what do they read? → A: every panel control gets the identifier
  `experience.r02-g06.chrono-constellator.<name>` through `port.identifier(name)`: the buttons `phase-down`, `phase-up`,
  `add-hold`, `remove-hold`, `step-1`, `step-10`, `run`, `rewind`, `undo`, `redo`, `next-level`, `reset-view`, `hint`,
  `dismiss-tutorial`, `failure-undo`, `failure-rewind`, `retry`, `campaign`, `daily`, `practice`, `play-level`,
  `replay`, `replay-step`, `replay-stop`, the steppers `star-picker` and `level-picker`, the toggle `sound` and the
  summary element `summary` (the "Sky" element). The tests read the canvas description for the level, the win and the
  stars, and the replay step's value for the replay position. Impact: FR-R02G0609-001, 002.
- Q: Which interface tests exist and how are they grouped? → A: namespace `CR` in
  `Apps/VisualCore/Tests/UI/ChronoConstellator/CRSupport.swift`; `CRPlayUITests` (fresh launch with `-vcResetData
  -vcSkipWelcome -vcCandidates -openExperience r02-g06.chrono-constellator`: dismiss the tutorial, play level 1's
  certified solution with the star picker (stepping to each changed star) and Phase − / Phase + (the shorter way round
  each star's loop to its certified phase), then Run; read "Every star stands on its target" and "Stars: 3 of 3", the
  level picker shows level 2 open; relaunch without reset after sending the app to the background: the stars and level
  2 are kept) and `CRReplayUITests` (after the win, Replay best solution, Step until the replay ends won, Stop back to
  the campaign). They run as a new serial chunk `o3` of `release_check.py` (its key checked unique); each test stays
  under 90 s. Level 1's certified phase changes and default phases are pinned in `CR` and checked against the Core by
  an app unit test. Impact: FR-R02G0609-002, 007; SC-R02G0609-001.
- Q: Which earlier-schema examples are stored and where do they come from? → A:
  `ChronoConstellatorExperienceCore.schemaOneExample()` (the schema-1 saved state of a seeded play of level 1 with one
  phase change that does not win) and `schemaTwoExample()` (schema 2 with progress and level 1 solved, no trace), both
  `MigrationExample`s built in the Core (`ChronoConstellatorSchemaExamples.swift`, modelled on
  `ColorfallCanyonsSchemaExamples`), registered with `examples:`; the app's migration check restores both into schema 3
  with progress kept (a schema-2 result without a trace keeps its stars, as feature 357 reconciles). The registration's
  comment is corrected. Impact: FR-R02G0609-003; SC-R02G0609-002.
- Q: What proves the release configuration excludes test-only code? → A: the existing `app-release-build` and
  `app-release-symbols` steps; `ChronoConstellatorGolden` is already forbidden, and the scenarios exist only under
  `DEBUG || VISUALCORE_AUTOMATION` (covered by the existing `acceptanceScenarios` entry). Impact: FR-R02G0609-004;
  SC-R02G0609-003.
- Q: How is "not available" checked? → A: an app unit test: without `-vcCandidates` the catalog lists
  `r02-g06.chrono-constellator` as not available and the launcher cannot open it; the registry's candidates list
  contains it and `all` does not. Impact: FR-R02G0609-006; SC-R02G0609-002.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game works inside the real app (Priority: P1) 🎯

A tester opens Chrono Constellator from the one app on the simulator, plays level 1 with the panel's star picker, Phase − and Phase + buttons and Run to a win,
sees the stars, opens the next level, replays the best solution and returns after closing the app to find the progress
kept.

**Why this priority**: the game only matters as part of the shipped app; this is the first end-to-end proof there.

**Independent Test**: interface tests launch the app with the candidate made available for testing, drive only the
visible, labelled controls and read the experience's spoken description.

**Acceptance Scenarios**:

1. **Given** a fresh app on the simulator, **When** the tester opens Chrono Constellator, plays level 1's certified solution with
   the star picker, Phase −, Phase + and Run, **Then** the level is won, the stars are shown and the
   next level opens.
2. **Given** a won level, **When** the app is relaunched, **Then** the same progress, stars and open levels are shown.
3. **Given** a solved level, **When** the tester taps Replay and steps through it, **Then** the replay ends won and Stop
   returns to the campaign.

### User Story 2 - The app's logic accepts the game (Priority: P1)

The app's own unit tests open the candidate through the app's registry, play it through the app's engine, restore saved
states of every earlier schema and confirm the candidate is not listed as available.

**Independent Test**: app unit tests with the registry, the engine and the stored migration examples.

### User Story 3 - Both build configurations compile and every level is solvable (Priority: P2)

The app compiles in its debug and release configurations for the simulator with Chrono Constellator linked, and the
solver regression proves all 100 levels solvable as certified.

**Independent Test**: a debug and a release simulator build of the app succeed; the regression of feature 358 passes.

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

- **FR-R02G0609-001**: The panel's controls MUST carry stable accessibility identifiers (experience prefix plus control
  name) in addition to their labels and values.
- **FR-R02G0609-002**: Interface tests in the one app MUST open Chrono Constellator with the candidate testing argument,
  win level 1 through the panel alone, see the stars and the next level, relaunch with progress kept, and replay a
  solved level to its end.
- **FR-R02G0609-003**: The app registration MUST store the schema-1 and schema-2 migration examples, and the app's unit
  tests MUST restore both and open the candidate through the registry and engine.
- **FR-R02G0609-004**: The app MUST compile in the debug and release configurations for the simulator with Chrono
  Constellator linked; test-only code MUST be excluded from release.
- **FR-R02G0609-005**: The all-level solvability regression (feature 358) MUST pass in this gate's evidence.
- **FR-R02G0609-006**: Chrono Constellator MUST stay a candidate: not listed as available, not openable from the catalog
  without the testing argument.
- **FR-R02G0609-007**: Existing tests MUST pass; the release checks that cover the app (interface test groups, app unit
  tests, app build) MUST include the new tests; the reference regression passes.

### Key Entities

- **Interface test group**: the Chrono Constellator interface tests, named in the release checks' groups.
- **Migration example**: a stored saved state of an earlier schema with its expected restore.
- **Build configuration**: debug and release builds of the one app for the simulator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0609-001**: The interface tests win level 1, keep progress over a relaunch and replay a solved level; each
  test finishes in under 90 seconds on the simulator.
- **SC-R02G0609-002**: The app unit tests restore both earlier-schema examples and open the candidate; the candidate is
  not listed as available.
- **SC-R02G0609-003**: Debug and release simulator builds of the app succeed.
- **SC-R02G0609-004**: The solver regression passes for 100 of 100 levels.
- **SC-R02G0609-005**: Existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G0609-006** {device}: after ImplementationLock-100, the same journeys on D1/D2/D3 (feature 360 prepares them).

## Assumptions

- Interface tests follow the app's existing patterns (one namespace of helpers per experience, launch arguments,
  identifiers, short waits), as Colorfall Canyons's `CC` tests.
- The interface tests' 90-second bound sits inside the app's 180-second per-test allowance.
- This feature adds no visuals: identifiers, tests and stored examples only, so the code-only graphics and their
  licensing stay those of features 353 and 356.
- Layout is unchanged: the panel of feature 356 (520 pt wide) on the iPhone and iPad simulators; the interface tests run
  on the iOS 27 iPhone simulator, as the app's interface chunks do.

## Traceability

| Source item (round2.md R2-G06-09) | Requirement |
|---|---|
| Compile actual target | FR-R02G0609-004 |
| XCUITest | FR-R02G0609-001, 002 |
| Logic test | FR-R02G0609-003 |
| All-level solvability | FR-R02G0609-005 |
| Release config | FR-R02G0609-004 |
| Schema migration | FR-R02G0609-003 |
| Excluded scope | device journeys (SC-R02G0609-006), price, per-game app |
