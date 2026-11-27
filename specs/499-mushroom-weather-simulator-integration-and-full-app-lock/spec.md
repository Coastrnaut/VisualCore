# Feature Specification: R02-G20-09 — Mushroom Weather: simulator integration and full app lock

**Feature Branch**: `499-mushroom-weather-simulator-integration-and-full-app-lock` (spec directory only; work on
`main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G20-09 (migration ledger, game feature of experience R02-G20) · ID namespace FR-R02G2009-###,
SC-R02G2009-###, T-R02G2009-###

**Input**: User description: the archived R02-G20-09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Compile actual target, XCUITest, logic test, all-level solvability and release config" for Mushroom Weather, with
the canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/499-mushroom-weather-simulator-integration-and-full-app-lock`;
  FR-R02G2009-###, SC-R02G2009-###, T-R02G2009-###.
- **Packaging (ADR-0009):** "compile actual target" means the one app (`Apps/VisualCore`) with the experience
  `r02-g20.mushroom-weather` (free, a registered candidate) linked; no per-game target, bundle identifier, scheme
  or store listing (the source's `Apps/MushroomWeather` and `Packages/GameModules/MushroomWeatherCore` are
  superseded by the experience module in `Packages/ExperiencesRound02`). The experience stays a candidate until
  X-R02-G20.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** the same journeys on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 489 (Microscopic Aurora's simulator integration and full app lock), adapted to placing spore
  pods, changing vents and moonlight and letting the weather run.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
489's answers where the games agree. Facts checked in code and specs (read-only, 2026-11-26): feature 489 (Microscopic
Aurora) is the model (`Apps/VisualCore/Tests/UI/MicroscopicAurora` with `MASupport.swift`, `MAPlayUITests.swift`,
`MAReplayUITests.swift`, serial chunk `b4`; `MicroscopicAuroraControls.identifierNames`;
`MicroscopicAuroraSchemaExamples.swift`); Mushroom Weather's panel (features 493 … 497) gives every control a label, a
value and an identifier through `port.identifier(name)` as Microscopic Aurora's does; its snapshot is schema 3 after
feature 497 (schema 1 `{level, records}`, 2 adds the mode, progress and the tutorial, 3 adds the sound choice and traces);
the canvas description of a won level says "Every colony stayed in its band." (feature 496) and the panel's `stars` text
reads "Best: 3 of 3 stars" once a level is won with its certified count; level 1's certified plan is a pod at row 2,
column 5 in slot 0 and vent 0 closed (`docs/games/mushroom-weather/levels/001.witness.json`), then the run; the
tutorial shows on levels 1 … 3; the UI chunk keys in `release_check.py` in use are a3, a4, b3, b4, c3, d3 … z3 and
g2 … z2, j4 (`c4` is free); no UI test class uses the prefix `MW`.

- Q: How do the interface tests find controls and what do they read? → A: through the identifiers the panel carries
  (`experience.r02-g20.mushroom-weather.<name>`); the failure explanation has its own identifier `explanation`, and this
  feature pins the full list as `MushroomWeatherControls.identifierNames` with a test that every name is unique and
  used once in the panel. The tests read the canvas description for the level and the win, the `stars` text for the
  stars, the `actions` text to confirm each action took effect, the slot and site controls' values before Place is
  pressed, each vent toggle's value, and the replay step's value for the replay position. Impact: FR-R02G2009-001, 002.
- Q: Which interface tests exist and how are they grouped? → A: namespace `MW` in
  `Apps/VisualCore/Tests/UI/MushroomWeather/MWSupport.swift`; `MWPlayUITests` (fresh launch with `-vcResetData
  -vcSkipWelcome -vcCandidates -openExperience r02-g20.mushroom-weather`: dismiss the tutorial, play level 1's certified
  plan — choose slot 1, move the site with Site − / Site + to the target (reading the control's value after a press so a
  lost tap is retried), press Place (counting it only when the actions-left count moves), toggle vent 1 (identifier
  `vent-0`) closed — then Run; read "Every colony stayed in its band." and "Best: 3 of 3 stars", the level picker shows
  level 2 open; relaunch without reset after sending the app to the background: the stars and level 2 are kept) and
  `MWReplayUITests` (after
  the win, Replay best solution, Step until the replay ends won, Stop back to the campaign). They run as a new serial
  chunk `c4` of `release_check.py` (its key checked unique); each test stays under 90 s apart from the simulator's
  automation-session setup of each app launch (about 30 s per launch, and a relaunch test launches twice). Level 1's
  certified plan is pinned in `MW` and checked against the Core by an app unit test. Impact: FR-R02G2009-002, 007;
  SC-R02G2009-001.
- Q: Which earlier-schema examples are stored and where do they come from? → A:
  `MushroomWeatherExperienceCore.schemaOneExample()` (the schema-1 saved state `{level: 1, records}` of a play of level 1
  with one pod placed that does not win, so it is still playing) and `schemaTwoExample()` (schema 2 with progress, the
  campaign mode, the tutorial done and level 1 solved with its stars at one action above the certified count, no trace),
  both `MigrationExample`s built in the Core (`MushroomWeatherSchemaExamples.swift`, modelled on
  `MicroscopicAuroraSchemaExamples`), registered with `examples:`; the app's migration check restores both into schema
  3 with progress kept (a schema-2 result without a trace keeps its stars unverified, as feature 497 reconciles). The
  registration's comment is corrected. Impact: FR-R02G2009-003; SC-R02G2009-002.
- Q: What proves the release configuration excludes test-only code? → A: the existing `app-release-build` and
  `app-release-symbols` steps; `MushroomWeatherGolden` is forbidden by feature 498, and the scenarios exist only under
  `DEBUG || VISUALCORE_AUTOMATION` (covered by the existing `acceptanceScenarios` entry). Impact: FR-R02G2009-004;
  SC-R02G2009-003.
- Q: How is "not available" checked? → A: an app unit test: without `-vcCandidates` the catalog lists
  `r02-g20.mushroom-weather` as not available and the launcher cannot open it; the registry's candidates list contains
  it and `all` does not. Impact: FR-R02G2009-006; SC-R02G2009-002.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game works inside the real app (Priority: P1) 🎯

A tester opens Mushroom Weather from the one app on the simulator, plays level 1 with the panel's slot and site
controls, its Place button, its vent toggle and its Run button to a win, sees the stars, opens the next level, replays the
best solution and returns after closing the app to find the progress kept.

**Why this priority**: the game only matters as part of the shipped app; this is the first end-to-end proof there.

**Independent Test**: interface tests launch the app with the candidate made available for testing, drive only the
visible, labelled controls and read the experience's spoken texts.

**Acceptance Scenarios**:

1. **Given** a fresh app on the simulator, **When** the tester opens Mushroom Weather and plays level 1's certified
   solution (its pod placement and vent change, then the run of the weather) with the panel's buttons, **Then** the
   experience says "Every colony stayed in its band.", the stars read "Best: 3 of 3 stars", and level 2 is open in the level picker.
2. **Given** a won level, **When** the app is relaunched, **Then** the same progress, stars and open levels are shown.
3. **Given** a solved level, **When** the tester starts the replay and steps through it, **Then** the replay ends won
   and stopping it returns to the campaign.

### User Story 2 - The app's logic accepts the game (Priority: P1)

The app's own unit tests open the candidate through the app's registry, play it through the app's engine, restore saved
states of every earlier schema and confirm the candidate is not listed as available.

**Independent Test**: app unit tests with the registry, the engine and the stored migration examples.

### User Story 3 - Both build configurations compile and every level is solvable (Priority: P2)

The app compiles in its debug and release configurations for the simulator with Mushroom Weather linked, and the
solver regression proves all 100 levels solvable as certified.

**Independent Test**: a debug and a release simulator build of the app succeed; the regression of feature 498 passes.

### Edge Cases

- **Candidate visibility:** without the testing argument the game is not listed as available and cannot be opened from
  the catalog; with it, tests can open it.
- **Earlier saves:** stored saved states of every earlier schema (1 and 2) restore through the app and migrate to the
  current schema (3).
- **Release builds:** test-only code (scenarios, golden descriptions) is excluded from the release configuration, which
  must still compile.
- **Interface lookup:** every control the tests use has a stable identifier, so tests do not depend on wording; the
  chosen slot and site are read from their controls' values before Place is pressed, and Run is pressed only after
  every action shows in the actions count.
- **Relaunch:** the interface test sends the app to the background before terminating it, so the save point runs (the
  lesson of feature 309).
- **Tutorial:** level 1 opens with its tutorial; the test dismisses it before playing.
- **A lost tap:** a button press whose effect does not show (the actions count or the chosen value does not move) is
  not counted, so a lost tap cannot skew the play.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2009-001**: The panel's controls MUST carry stable accessibility identifiers (experience prefix plus control
  name) in addition to their labels and values, and the list of names MUST be pinned and checked unique.
- **FR-R02G2009-002**: Interface tests in the one app MUST open Mushroom Weather with the candidate testing
  argument, win level 1 through the panel alone, see the stars and the next level, relaunch with progress kept, and
  replay a solved level to its end.
- **FR-R02G2009-003**: The app registration MUST store a migration example of every earlier snapshot schema (1 and 2),
  and the app's unit tests MUST restore each and open the candidate through the registry and engine.
- **FR-R02G2009-004**: The app MUST compile in the debug and release configurations for the simulator with Microscopic
  Aurora linked; test-only code MUST be excluded from release.
- **FR-R02G2009-005**: The all-level solvability regression (feature 498) MUST pass in this gate's evidence.
- **FR-R02G2009-006**: Mushroom Weather MUST stay a candidate: not listed as available, not openable from the
  catalog without the testing argument.
- **FR-R02G2009-007**: Existing tests MUST pass; the release checks that cover the app (interface test groups, app unit
  tests, app build) MUST include the new tests; the reference regression passes.

### Key Entities

- **Interface test group**: the Mushroom Weather interface tests, named in the release checks' groups.
- **Migration example**: a stored saved state of an earlier schema with its expected restore.
- **Build configuration**: debug and release builds of the one app for the simulator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2009-001**: The interface tests win level 1, keep progress over a relaunch and replay a solved level; each
  test finishes in under 90 seconds on the simulator, not counting the simulator's automation-session setup of each app
  launch (about 30 s per launch; a relaunch test launches twice), and within the app's 180-second per-test allowance.
- **SC-R02G2009-002**: The app unit tests restore both earlier-schema examples and open the candidate; the candidate is
  not listed as available.
- **SC-R02G2009-003**: Debug and release simulator builds of the app succeed.
- **SC-R02G2009-004**: The solver regression passes for 100 of 100 levels.
- **SC-R02G2009-005**: Existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G2009-006** {device}: after ImplementationLock-100, the same journeys on D1/D2/D3 (feature 500 prepares them).

## Assumptions

- Interface tests follow the app's existing patterns (one namespace of helpers per experience, launch arguments,
  identifiers, short waits), as Microscopic Aurora's interface tests.
- The interface tests' 90-second bound sits inside the app's 180-second per-test allowance.
- This feature adds no visuals: identifiers, tests and stored examples only, so the code-only graphics and their
  licensing stay those of features 493 and 496; nothing here uses third-party material.
- Layout is unchanged: the panel of feature 486 on the iPhone and iPad simulators; the interface tests run on the iOS 27
  iPhone simulator, as the app's interface chunks do.
- Observability: interface test failures name the control and the expected text; the release checks print one line per
  group.

## Traceability

| Source item (round2.md R2-G20-09) | Requirement |
|---|---|
| Compile actual target | FR-R02G2009-004 |
| XCUITest | FR-R02G2009-001, 002 |
| Logic test | FR-R02G2009-003 |
| All-level solvability | FR-R02G2009-005 |
| Release config | FR-R02G2009-004 |
| Schema migration | FR-R02G2009-003 |
| Accessibility | FR-R02G2009-001 |
| Excluded scope | device journeys (SC-R02G2009-006), price, per-game app |
