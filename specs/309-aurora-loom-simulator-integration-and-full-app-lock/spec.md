# Feature Specification: R02-G01-09 — Aurora Loom: simulator integration and full app lock

**Feature Branch**: `309-aurora-loom-simulator-integration-and-full-app-lock` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-09 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0109-###,
SC-R02G0109-###, T-R02G0109-###

**Input**: User description: the archived R02-G01-09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Compile actual target, XCUITest, logic test, all-level solvability and release config" for Aurora Loom, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/309-aurora-loom-simulator-integration-and-full-app-lock`; FR-R02G0109-###,
  SC-R02G0109-###, T-R02G0109-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate) in the one
  VisualCore app. "The actual target" is the one app target with Aurora Loom linked; no per-game target, bundle
  identifier, scheme or store listing. Aurora Loom stays a candidate (not available to players) until X-R02-G01.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** playing on D1/D2/D3 after ImplementationLock-100 (feature 310
  prepares it). **Owner-only items:** none (no signing is needed for simulator builds).
- **Shared features used:** the app's debug launch arguments (`-vcCandidates`, `-openExperience`, `-vcReset`,
  `-vcSkipWelcome`), the app's UI test support, the registry's stored migration examples and the release checks.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): the app's debug launch arguments are `-vcCandidates` (candidates become available and
are registered; debug builds only), `-openExperience <id>`, `-vcResetData` and `-vcSkipWelcome`
(`AppUITestSupport.VC`); A21's interface tests (`Apps/VisualCore/Tests/UI/Aurora`, namespace `AU`) are the model;
`release_check.py` runs interface tests in named chunks (`UI_CHUNKS`, serial chunks in `SERIAL_CHUNKS`), builds the
Release app for the simulator (`app-release-build`) and checks its symbols against `RELEASE_FORBIDDEN`
(`app-release-symbols`); the registry stores earlier-schema examples through `ExperienceRegistration(..., examples:)`
(A18's `schemaOneExample()`/`schemaTwoExample()` return `MigrationExample`); Aurora Loom's registration still says
"Snapshot schema 1" although its snapshot is schema 3 since feature 307; its panel has labels and values but no
accessibility identifiers.

- Q: How do the interface tests find controls and what do they read? → A: every panel control gets the identifier
  `experience.r02-g01.aurora-loom.<name>` through the experience's port (`port.identifier(name)`, as A21): `wave-<r>`,
  `phase-<r>` (steppers, r = 1 … 3), `apply`, `clear`, `undo`, `redo`, `next-level`, `hint`, `retry`, `daily`, `practice`, `campaign`,
  `level-picker`, `replay`, `replay-step`, `replay-stop`, `sound`, `skip-tutorial`. The tests read the canvas's
  description (`session.canvas`, the presenter's `describe`) for the level, stars and replay position. Impact:
  FR-R02G0109-001, 002.
- Q: Which interface tests exist and how are they grouped? → A: namespace `AL` in
  `Apps/VisualCore/Tests/UI/AuroraLoom/ALSupport.swift`; `ALPlayUITests` (fresh launch with `-vcResetData
  -vcSkipWelcome -vcCandidates -openExperience r02-g01.aurora-loom`: skip the tutorial, set level 1's certified target steps
  as pending steps with the steppers, then Apply (one move per changed control, see the amendment below), and win, read "3 of 3 stars" and level 2 open; relaunch without reset: the stars and level 2
  are still there) and `ALReplayUITests` (after the win, Replay, Step until "Replay complete", Stop back to campaign).
  They run as a new serial chunk `i3` of `release_check.py`. Each test stays under 60 s. Impact: FR-R02G0109-002, 007;
  SC-R02G0109-001.
- Q: Which earlier-schema examples are stored and where do they come from? → A: `AuroraLoomExperienceCore.schemaOneExample()`
  (`{level, records}` of a seeded play of level 2 with two moves) and `schemaTwoExample()` (`{level, mode, progress,
  records, tutorial}` with level 1 solved without a trace), both `MigrationExample`s built in the Core, registered with
  `examples:`; the app's `SnapshotMigrationCheck` restores both into schema 3 with progress kept. The registration's
  comment is corrected. Impact: FR-R02G0109-003; SC-R02G0109-002.
- Q: What proves the release configuration excludes test-only code? → A: the existing `app-release-build` and
  `app-release-symbols` steps, with `AuroraLoomGolden` and `acceptanceScenarios` added to
  `RELEASE_FORBIDDEN` (the symbols that exist only under `DEBUG || VISUALCORE_AUTOMATION`). Impact: FR-R02G0109-004;
  SC-R02G0109-003.
- Q: How is "not available" checked? → A: an app unit test: without `-vcCandidates` the catalog lists
  `r02-g01.aurora-loom` as not available and the launcher cannot open it; the registry's candidates list contains it and
  `all` does not. Impact: FR-R02G0109-006; SC-R02G0109-002.

Amendment found while planning (2026-11-20): the panel's steppers spend one move per tap, so a player who uses only the
panel (for example with VoiceOver) cannot win level 1 at all: ribbon 3 needs 4 + 7 single-step taps against an
allowance of 9 and a certified shortest of 2 (feature 306 proved the win through `adjust` with whole deltas, which the
steppers never send). Decision: the steppers set a **pending** step per ribbon control (shown as the stepper's value,
"wave 15, now 3"); an **Apply** button commits every pending change as one move each, in ribbon order, wave before
phase, exactly like a canvas drag commits one move per gesture; **Clear** drops the pending steps; pending steps are
dropped when the level, mode or play changes from elsewhere. Moves, stars and the allowance are unchanged. Impact:
FR-R02G0109-008; SC-R02G0109-007.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game works inside the real app (Priority: P1) 🎯

A tester opens Aurora Loom from the one app on the simulator, plays level 1 with the panel's controls to a win, sees the
stars, opens the next level, replays the best solution and returns after closing the app to find the progress kept.

**Why this priority**: the game only matters as part of the shipped app; this is the first end-to-end proof there.

**Independent Test**: interface tests launch the app with the candidate made available for testing, drive only the
visible, labelled controls and read the experience's spoken description.

**Acceptance Scenarios**:

1. **Given** a fresh app on the simulator, **When** the tester opens Aurora Loom, sets level 1's solution steps as
   pending steps with the panel's steppers and taps Apply, **Then** the level is won, the stars are shown and the next level opens.
2. **Given** a won level, **When** the app is relaunched, **Then** the same progress, stars and open levels are shown.
3. **Given** a solved level, **When** the tester taps Replay and steps through it, **Then** the replay ends won and
   Stop returns to the campaign.

### User Story 2 - The app's logic accepts the game (Priority: P1)

The app's own unit tests open the candidate through the app's registry, play it through the app's engine, restore
saved states of every earlier schema and confirm the candidate is not listed as available.

**Independent Test**: app unit tests with the registry, the engine and the stored migration examples.

### User Story 3 - Both build configurations compile and every level is solvable (Priority: P2)

The app compiles in its debug and release configurations for the simulator with Aurora Loom linked, and the solver
regression proves all 100 levels solvable as certified.

**Independent Test**: a debug and a release simulator build of the app succeed; the regression of feature 308 passes.

### Edge Cases

- **Candidate visibility:** without the testing argument the game is not listed as available and cannot be opened from
  the catalog; with it, tests can open it.
- **Earlier saves:** a stored schema-1 and schema-2 example restore through the app and migrate to schema 3.
- **Release builds:** test-only code (scenarios, golden descriptions) is excluded from the release configuration, which
  must still compile.
- **Interface lookup:** every control the tests use has a stable identifier, so tests do not depend on wording.
- **Apply with nothing pending:** Apply and Clear are hidden while nothing is pending.
- **Apply past the allowance or the end of play:** the pending moves are sent in order; the first refused one (for
  example the allowance spent, or the level already won by an earlier pending move) stops the rest, is announced with
  its reason, and every remaining pending step is dropped; the moves already applied stay.
- **Announcements of pending steps:** each stepper change announces "Ribbon r wave s pending. Apply to move." (phase
  likewise); Apply's moves are announced as ordinary moves.
- **Layout:** Apply and Clear sit in the panel's wrapping button rows, keep the 320-point iPhone and largest-text
  layout of feature 306 and the 520-point readable width on iPad.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0109-001**: The panel's controls MUST carry stable accessibility identifiers (experience prefix plus control
  name) in addition to their labels and values.
- **FR-R02G0109-002**: Interface tests in the one app MUST open Aurora Loom with the candidate testing argument, win
  level 1 through the panel alone, see the stars and the next level, relaunch with progress kept, and replay a solved
  level to its end.
- **FR-R02G0109-003**: The app registration MUST store the schema-1 and schema-2 migration examples, and the app's unit
  tests MUST restore both and open the candidate through the registry and engine.
- **FR-R02G0109-004**: The app MUST compile in the debug and release configurations for the simulator with Aurora Loom
  linked; test-only code MUST be excluded from release.
- **FR-R02G0109-005**: The all-level solvability regression (feature 308) MUST pass in this gate's evidence.
- **FR-R02G0109-006**: Aurora Loom MUST stay a candidate: not listed as available, not openable from the catalog without
  the testing argument.
- **FR-R02G0109-008**: The panel's steppers MUST set pending steps without spending moves; Apply MUST commit each
  pending change as one move (ribbon order, wave before phase); Clear MUST drop them; pending steps MUST be dropped when
  the level, mode or play changes from elsewhere, and MUST be announced and shown as the stepper's value.
- **FR-R02G0109-007**: Existing tests MUST pass; the release checks that cover the app (interface test groups, app unit
  tests, app build) MUST include the new tests; the reference regression passes.

### Key Entities

- **Interface test group**: the Aurora Loom interface tests, named in the release checks' groups.
- **Migration example**: a stored saved state of an earlier schema with its expected restore.
- **Build configuration**: debug and release builds of the one app for the simulator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0109-001**: The interface tests win level 1, keep progress over a relaunch and replay a solved level; each
  test finishes in under 60 seconds on the simulator.
- **SC-R02G0109-002**: The app unit tests restore both earlier-schema examples and open the candidate; the candidate is
  not listed as available.
- **SC-R02G0109-003**: Debug and release simulator builds of the app succeed.
- **SC-R02G0109-004**: The solver regression passes for 100 of 100 levels.
- **SC-R02G0109-005**: Existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G0109-007**: Every certified level can be won with the panel alone within its allowance, in exactly its
  certified shortest number of moves (one Apply per solution); proven for all 100 levels through the presenter.
- **SC-R02G0109-006** {device}: after ImplementationLock-100, the same journeys on D1/D2/D3 (feature 310 prepares them).

## Assumptions

- Interface tests follow the app's existing patterns (one namespace of helpers per experience, launch arguments,
  identifiers, short waits).
- The interface tests' 60-second bound is the app's existing per-test bound for interface tests.

## Traceability

| Source item (round2.md R2-G01-09) | Requirement |
|---|---|
| Compile actual target | FR-R02G0109-004 |
| XCUITest | FR-R02G0109-001, 002 |
| Logic test | FR-R02G0109-003 |
| All-level solvability | FR-R02G0109-005 |
| Release config | FR-R02G0109-004 |
| Schema migration | FR-R02G0109-003 |
| Excluded scope | device journeys (SC-R02G0109-006), price, per-game app |
