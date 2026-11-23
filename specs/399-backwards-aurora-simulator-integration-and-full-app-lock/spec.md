# Feature Specification: R02-G10-09 — Backwards Aurora: simulator integration and full app lock

**Feature Branch**: `399-backwards-aurora-simulator-integration-and-full-app-lock` (spec directory only; work on
`main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G10-09 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1009-###,
SC-R02G1009-###, T-R02G1009-###

**Input**: User description: the archived R02-G10-09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Compile actual target, XCUITest, logic test, all-level solvability and release config" for Backwards Aurora, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/399-backwards-aurora-simulator-integration-and-full-app-lock`; FR-R02G1009-###,
  SC-R02G1009-###, T-R02G1009-###.
- **Packaging (ADR-0009):** "compile actual target" means the one app (`Apps/VisualCore`) with the experience
  `r02-g10.backwards-aurora` (free, a registered candidate) linked; no per-game target, bundle identifier, scheme or
  store listing. The experience stays a candidate until X-R02-G10.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** the same journeys on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 389 (Nocturne Garden's simulator integration and full app lock).

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
389's answers. Facts checked in code (read-only, 2026-11-23): feature 389 (Nocturne Garden) is the model
(`Apps/VisualCore/Tests/UI/NocturneGarden`, namespace `NG`, serial chunk `r3`; identifiers through
`port.identifier(name)`; `NocturneGardenSchemaExamples.swift`); Backwards Aurora's panel (`BackwardsAuroraControls`)
has labels and values on every control (feature 396) but no identifiers, with two Undo buttons (the play row's and the
failure section's), adjustable steppers for the section's start and end and the level, Reverse, the replay controls
and the Sound toggle; its registration in `Apps/VisualCore/App/ExperienceRegistry.swift` still says "Snapshot schema 1,
so no earlier example is stored yet" although the snapshot is schema 3 since feature 397; the panel's "Aurora" element
carries the summary and, when won, the canvas description says "Every checkpoint matches and every bend is within the
limit." followed by "Stars: k of 3."; the UI chunk keys in `release_check.py` end at `r3` (no `s3`); no `BA`
namespace exists among the UI test folders.

- Q: How do the interface tests find controls and what do they read? → A: every panel control gets the identifier
  `experience.r02-g10.backwards-aurora.<name>` through `port.identifier(name)`: the buttons `reverse`, `undo`, `redo`,
  `next-level`, `reset-view`, `hint`, `dismiss-tutorial`, `failure-undo`, `retry`, `campaign`, `daily`, `practice`,
  `play-level`, `replay`, `replay-step`, `replay-stop`, the steppers `start-picker`, `end-picker` and `level-picker`,
  the toggle `sound` and the summary element `summary` (the "Aurora" element). The tests read the canvas description for
  the level, the win and the stars, and the replay step's value for the replay position. Impact: FR-R02G1009-001, 002.
- Q: Which interface tests exist and how are they grouped? → A: namespace `BA` in
  `Apps/VisualCore/Tests/UI/BackwardsAurora/BASupport.swift`; `BAPlayUITests` (fresh launch with `-vcResetData
  -vcSkipWelcome -vcCandidates -openExperience r02-g10.backwards-aurora`: dismiss the tutorial, play level 1's certified
  solution by setting the start and end steppers and tapping Reverse for each reversal; read "Every checkpoint matches
  and every bend is within the limit" and "Stars: 3 of 3", the level picker shows level 2 open; relaunch without reset
  after sending the app to the background: the stars and level 2 are kept) and `BAReplayUITests` (after the win, Replay
  best solution, Step until the replay ends won, Stop back to the campaign). They run as a new serial chunk `s3` of
  `release_check.py` (its key checked unique); each test stays under 90 s apart from the simulator's automation-session
  setup of each app launch (feature 389's lesson: about 30 s per launch, and a relaunch test launches twice). Level 1's
  certified reversals are pinned in `BA` and checked against the Core by an app unit test. Impact: FR-R02G1009-002,
  007; SC-R02G1009-001.
- Q: Which earlier-schema examples are stored and where do they come from? → A:
  `BackwardsAuroraExperienceCore.schemaOneExample()` (the schema-1 saved state of a seeded play of level 1 with one
  reversal that does not win) and `schemaTwoExample()` (schema 2 with progress and level 1 solved, no trace), both
  `MigrationExample`s built in the Core (`BackwardsAuroraSchemaExamples.swift`, modelled on
  `NocturneGardenSchemaExamples`), registered with `examples:`; the app's migration check restores both into schema 3
  with progress kept (a schema-2 result without a trace keeps its stars, as feature 397 reconciles). The registration's
  comment is corrected. Impact: FR-R02G1009-003; SC-R02G1009-002.
- Q: What proves the release configuration excludes test-only code? → A: the existing `app-release-build` and
  `app-release-symbols` steps; `BackwardsAuroraGolden` is forbidden by feature 398, and the scenarios exist only under
  `DEBUG || VISUALCORE_AUTOMATION` (covered by the existing `acceptanceScenarios` entry). Impact: FR-R02G1009-004;
  SC-R02G1009-003.
- Q: How is "not available" checked? → A: an app unit test: without `-vcCandidates` the catalog lists
  `r02-g10.backwards-aurora` as not available and the launcher cannot open it; the registry's candidates list contains
  it and `all` does not. Impact: FR-R02G1009-006; SC-R02G1009-002.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game works inside the real app (Priority: P1) 🎯

A tester opens Backwards Aurora from the one app on the simulator, plays level 1 with the panel's section start and end
steppers and the Reverse button to a win, sees the stars, opens the next level, replays the best solution and returns
after closing the app to find the progress kept.

**Why this priority**: the game only matters as part of the shipped app; this is the first end-to-end proof there.

**Independent Test**: interface tests launch the app with the candidate made available for testing, drive only the
visible, labelled controls and read the experience's spoken description.

**Acceptance Scenarios**:

1. **Given** a fresh app on the simulator, **When** the tester opens Backwards Aurora, plays level 1's certified solution
   with the panel's start and end steppers and Reverse, **Then** the level is won, the stars are shown and the next
   level opens.
2. **Given** a won level, **When** the app is relaunched, **Then** the same progress, stars and open levels are shown.
3. **Given** a solved level, **When** the tester taps Replay and steps through it, **Then** the replay ends won and Stop
   returns to the campaign.

### User Story 2 - The app's logic accepts the game (Priority: P1)

The app's own unit tests open the candidate through the app's registry, play it through the app's engine, restore saved
states of every earlier schema and confirm the candidate is not listed as available.

**Independent Test**: app unit tests with the registry, the engine and the stored migration examples.

### User Story 3 - Both build configurations compile and every level is solvable (Priority: P2)

The app compiles in its debug and release configurations for the simulator with Backwards Aurora linked, and the
solver regression proves all 100 levels solvable as certified.

**Independent Test**: a debug and a release simulator build of the app succeed; the regression of feature 398 passes.

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

- **FR-R02G1009-001**: The panel's controls MUST carry stable accessibility identifiers (experience prefix plus control
  name) in addition to their labels and values.
- **FR-R02G1009-002**: Interface tests in the one app MUST open Backwards Aurora with the candidate testing argument,
  win level 1 through the panel alone, see the stars and the next level, relaunch with progress kept, and replay a
  solved level to its end.
- **FR-R02G1009-003**: The app registration MUST store the schema-1 and schema-2 migration examples, and the app's unit
  tests MUST restore both and open the candidate through the registry and engine.
- **FR-R02G1009-004**: The app MUST compile in the debug and release configurations for the simulator with Backwards
  Aurora linked; test-only code MUST be excluded from release.
- **FR-R02G1009-005**: The all-level solvability regression (feature 398) MUST pass in this gate's evidence.
- **FR-R02G1009-006**: Backwards Aurora MUST stay a candidate: not listed as available, not openable from the catalog
  without the testing argument.
- **FR-R02G1009-007**: Existing tests MUST pass; the release checks that cover the app (interface test groups, app unit
  tests, app build) MUST include the new tests; the reference regression passes.

### Key Entities

- **Interface test group**: the Backwards Aurora interface tests, named in the release checks' groups.
- **Migration example**: a stored saved state of an earlier schema with its expected restore.
- **Build configuration**: debug and release builds of the one app for the simulator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1009-001**: The interface tests win level 1, keep progress over a relaunch and replay a solved level; each
  test finishes in under 90 seconds on the simulator, not counting the simulator's automation-session setup of each app
  launch (about 30 s per launch, measured for feature 389's chunk `r3`; a relaunch test launches twice), and within the
  app's 180-second per-test allowance.
- **SC-R02G1009-002**: The app unit tests restore both earlier-schema examples and open the candidate; the candidate is
  not listed as available.
- **SC-R02G1009-003**: Debug and release simulator builds of the app succeed.
- **SC-R02G1009-004**: The solver regression passes for 100 of 100 levels.
- **SC-R02G1009-005**: Existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G1009-006** {device}: after ImplementationLock-100, the same journeys on D1/D2/D3 (feature 400 prepares them).

## Assumptions

- Interface tests follow the app's existing patterns (one namespace of helpers per experience, launch arguments,
  identifiers, short waits), as Nocturne Garden's interface tests.
- The interface tests' 90-second bound sits inside the app's 180-second per-test allowance.
- This feature adds no visuals: identifiers, tests and stored examples only, so the code-only graphics and their
  licensing stay those of features 393 and 396.
- Layout is unchanged: the panel of feature 396 (520 pt wide) on the iPhone and iPad simulators; the interface tests run
  on the iOS 27 iPhone simulator, as the app's interface chunks do.

## Traceability

| Source item (round2.md R2-G10-09) | Requirement |
|---|---|
| Compile actual target | FR-R02G1009-004 |
| XCUITest | FR-R02G1009-001, 002 |
| Logic test | FR-R02G1009-003 |
| All-level solvability | FR-R02G1009-005 |
| Release config | FR-R02G1009-004 |
| Schema migration | FR-R02G1009-003 |
| Excluded scope | device journeys (SC-R02G1009-006), price, per-game app |
