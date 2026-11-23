# Feature Specification: R02-G12-09 — Harmonic Bridges: simulator integration and full app lock

**Feature Branch**: `419-harmonic-bridges-simulator-integration-and-full-app-lock` (spec directory only; work on
`main`)

**Created**: 2026-11-23

**Status**: Draft

**Ledger gate**: R02-G12-09 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1209-###,
SC-R02G1209-###, T-R02G1209-###

**Input**: User description: the archived R02-G12-09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Compile actual target, XCUITest, logic test, all-level solvability and release config" for Harmonic Bridges, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/419-harmonic-bridges-simulator-integration-and-full-app-lock`;
  FR-R02G1209-###, SC-R02G1209-###, T-R02G1209-###.
- **Packaging (ADR-0009):** "compile actual target" means the one app (`Apps/VisualCore`) with the experience
  `r02-g12.harmonic-bridges` (free, a registered candidate) linked; no per-game target, bundle identifier, scheme or
  store listing (the source's `Apps/HarmonicBridges` and `Packages/GameModules/HarmonicBridgesCore` are superseded by
  the experience module in `Packages/ExperiencesRound02`). The experience stays a candidate until X-R02-G12.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** the same journeys on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 409 (Echo Cartographer's simulator integration and full app lock).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game works inside the real app (Priority: P1) 🎯

A tester opens Harmonic Bridges from the one app on the simulator, plays level 1 with the panel's string and peg
steppers and its Tune and Test buttons to a win, sees the stars, opens the next level, replays the best solution and
returns after closing the app to find the progress kept.

**Why this priority**: the game only matters as part of the shipped app; this is the first end-to-end proof there.

**Independent Test**: interface tests launch the app with the candidate made available for testing, drive only the
visible, labelled controls and read the experience's spoken description.

**Acceptance Scenarios**:

1. **Given** a fresh app on the simulator, **When** the tester opens Harmonic Bridges and plays level 1's certified
   solution (its tunings, then the test) with the panel's string and peg steppers and the Tune and Test buttons,
   **Then** the level is won, the stars are shown and the next level opens.
2. **Given** a won level, **When** the app is relaunched, **Then** the same progress, stars and open levels are shown.
3. **Given** a solved level, **When** the tester taps Replay and steps through it, **Then** the replay ends won and Stop
   returns to the campaign.

### User Story 2 - The app's logic accepts the game (Priority: P1)

The app's own unit tests open the candidate through the app's registry, play it through the app's engine, restore saved
states of every earlier schema and confirm the candidate is not listed as available.

**Independent Test**: app unit tests with the registry, the engine and the stored migration examples.

### User Story 3 - Both build configurations compile and every level is solvable (Priority: P2)

The app compiles in its debug and release configurations for the simulator with Harmonic Bridges linked, and the
solver regression proves all 100 levels solvable as certified.

**Independent Test**: a debug and a release simulator build of the app succeed; the regression of feature 418 passes.

### Edge Cases

- **Candidate visibility:** without the testing argument the game is not listed as available and cannot be opened from
  the catalog; with it, tests can open it.
- **Earlier saves:** stored saved states of every earlier schema restore through the app and migrate to the current
  schema (3).
- **Release builds:** test-only code (scenarios, golden descriptions) is excluded from the release configuration, which
  must still compile.
- **Interface lookup:** every control the tests use has a stable identifier, so tests do not depend on wording; the two
  Undo buttons (the play row's and the failure section's) have different identifiers.
- **Relaunch:** the interface test sends the app to the background before terminating it, so the save point runs (the
  lesson of feature 309).
- **Tutorial:** level 1 opens with its tutorial; the test dismisses it before playing.
- **A lost tap:** a stepper press that does not move its value is not counted, so a lost tap cannot skew the chosen
  string or peg.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1209-001**: The panel's controls MUST carry stable accessibility identifiers (experience prefix plus control
  name) in addition to their labels and values.
- **FR-R02G1209-002**: Interface tests in the one app MUST open Harmonic Bridges with the candidate testing argument,
  win level 1 through the panel alone, see the stars and the next level, relaunch with progress kept, and replay a
  solved level to its end.
- **FR-R02G1209-003**: The app registration MUST store a migration example of every earlier snapshot schema (1 and 2),
  and the app's unit tests MUST restore each and open the candidate through the registry and engine.
- **FR-R02G1209-004**: The app MUST compile in the debug and release configurations for the simulator with Harmonic
  Bridges linked; test-only code MUST be excluded from release.
- **FR-R02G1209-005**: The all-level solvability regression (feature 418) MUST pass in this gate's evidence.
- **FR-R02G1209-006**: Harmonic Bridges MUST stay a candidate: not listed as available, not openable from the catalog
  without the testing argument.
- **FR-R02G1209-007**: Existing tests MUST pass; the release checks that cover the app (interface test groups, app unit
  tests, app build) MUST include the new tests; the reference regression passes.

### Key Entities

- **Interface test group**: the Harmonic Bridges interface tests, named in the release checks' groups.
- **Migration example**: a stored saved state of an earlier schema with its expected restore.
- **Build configuration**: debug and release builds of the one app for the simulator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1209-001**: The interface tests win level 1, keep progress over a relaunch and replay a solved level; each
  test finishes in under 90 seconds on the simulator, not counting the simulator's automation-session setup of each app
  launch (about 30 s per launch; a relaunch test launches twice), and within the app's 180-second per-test allowance.
- **SC-R02G1209-002**: The app unit tests restore both earlier-schema examples and open the candidate; the candidate is
  not listed as available.
- **SC-R02G1209-003**: Debug and release simulator builds of the app succeed.
- **SC-R02G1209-004**: The solver regression passes for 100 of 100 levels.
- **SC-R02G1209-005**: Existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G1209-006** {device}: after ImplementationLock-100, the same journeys on D1/D2/D3 (feature 420 prepares them).

## Assumptions

- Interface tests follow the app's existing patterns (one namespace of helpers per experience, launch arguments,
  identifiers, short waits), as Echo Cartographer's interface tests.
- The interface tests' 90-second bound sits inside the app's 180-second per-test allowance.
- This feature adds no visuals: identifiers, tests and stored examples only, so the code-only graphics and their
  licensing stay those of features 413 and 416; nothing here uses third-party material.
- Layout is unchanged: the panel of feature 416 on the iPhone and iPad simulators; the interface tests run on the iOS 27
  iPhone simulator, as the app's interface chunks do.
- Observability: interface test failures name the control and the expected text; the release checks print one line per
  group.

## Traceability

| Source item (round2.md R2-G12-09) | Requirement |
|---|---|
| Compile actual target | FR-R02G1209-004 |
| XCUITest | FR-R02G1209-001, 002 |
| Logic test | FR-R02G1209-003 |
| All-level solvability | FR-R02G1209-005 |
| Release config | FR-R02G1209-004 |
| Schema migration | FR-R02G1209-003 |
| Accessibility | FR-R02G1209-001 |
| Excluded scope | device journeys (SC-R02G1209-006), price, per-game app |
