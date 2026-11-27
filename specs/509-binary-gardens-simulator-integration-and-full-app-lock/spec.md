# Feature Specification: R02-G21-09 — Binary Gardens: simulator integration and full app lock

**Feature Branch**: `509-binary-gardens-simulator-integration-and-full-app-lock` (spec directory only; work on
`main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-09 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2109-###,
SC-R02G2109-###, T-R02G2109-###

**Input**: User description: the archived R02-G21-09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Compile actual target, XCUITest, logic test, all-level solvability and release config" for Binary Gardens, with
the canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/509-binary-gardens-simulator-integration-and-full-app-lock`;
  FR-R02G2109-###, SC-R02G2109-###, T-R02G2109-###.
- **Packaging (ADR-0009):** "compile actual target" means the one app (`Apps/VisualCore`) with the experience
  `r02-g21.binary-gardens` (free, a registered candidate) linked; no per-game target, bundle identifier, scheme
  or store listing (the source's `Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore` are superseded by
  the experience module in `Packages/ExperiencesRound02/BinaryGardens`). The experience stays a candidate until
  X-R02-G21.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** the same journeys on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Prerequisites recorded first:** R02-G21-04 (feature 504, recorded pass on 2026-11-27), R02-G21-05 … R02-G21-08 (features
  505 … 508, specified and planned, not yet in code). This feature's interface tests, schema examples and regression
  evidence depend on what those features build, so its implementation starts only after their gates are recorded.
- **Model:** feature 499 (Mushroom Weather's simulator integration and full app lock), adapted to choosing a star,
  changing its ring, phase, luminosity or the orbit tilt and running the light.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
499's answers where the games agree. Facts checked in committed code and specs (read-only, 2026-11-27):

- **Model as built (feature 499):** `Apps/VisualCore/Tests/UI/MushroomWeather` holds `MWSupport.swift`,
  `MWPlayUITests.swift` (a win with three stars, progress kept over a relaunch) and `MWReplayUITests.swift`; they run in
  the serial chunk `c4` of `release_check.py`; `MushroomWeatherExperienceCore.schemaOneExample()` and
  `schemaTwoExample()` are registered with `examples:` in `ExperienceRegistry.swift`; `AppModelTests` restores both
  examples and plays level 1's certified plan through the registry and engine; each launch carries `-vcResetData
  -vcSkipWelcome -vcCandidates -openExperience <id>`; interface tests run with a 180-second per-test allowance
  (`-default-test-execution-time-allowance 180`). Feature 499's identifiers were aligned with what was built during
  its analyze step.
- **Binary Gardens today:** registered as the only entry of `ExperienceRegistry.candidates` (a `binaryGardens`
  registration with opening seed 0 and its scenario manifest under `DEBUG || VISUALCORE_AUTOMATION`, no `examples:`,
  its comment saying "Snapshot schema 1, so no earlier example is stored yet") and in `Catalog/registrations.json`
  (`r02-g21.binary-gardens`, 100 levels, three quality tiers). `BinaryGardensExperienceCore.schemaVersion` is 1. The
  panel (`BinaryGardensControls`, features 503 and 504) gives its controls identifiers through `port.identifier(name)`:
  `actions` ("Level n · a of b actions left"), `status`, `tutorial`, `failure`, `progress`, `message`,
  `preview-refusal`, `star` (segmented "Star 1" / "Star 2", value "star k"), `star-detail`, `ring-minus`, `ring`,
  `ring-plus`, `phase-minus`, `phase`, `phase-plus`, `luminosity-minus`, `luminosity` (value "level i of L"),
  `luminosity-plus`, `tilt-minus`, `tilt`, `tilt-plus`, `tick-minus`, `tick`, `tick-plus`, `run`, `tick-detail`,
  `undo`, `redo`, `next-level`, `ring-choice`, `luminosity-choice`, `phase-target`, `set-phase`, `tilt-choice`,
  `inspect`, `inspect-detail` and `reset-view`; there is no pinned name list yet. The canvas description of a won level
  says "Every world kept its window and bloomed." (`BinaryGardensPresenter.describe`); feature 506 plans the spoken
  announcement "Every world kept its light and bloomed. …", which interface tests cannot read.
- **Level 1** (`docs/games/binary-gardens/levels/001.witness.json`): budget 9, two luminosity levels, both stars at
  luminosity index 1, only star 2's ring and luminosity adjustable, tutorial flag set; the certified plan is one action,
  star 2 (0-based star 1) set to luminosity index 0, then the run. Levels 1 … 3 carry the tutorial.
- **From the prerequisite specifications (not yet in code):** feature 505 adds progress, stars ("Best: s of 3 stars",
  3 stars at most the certified count, 2 at most that + 2, else 1), the level picker of open levels, the modes, the
  hint, the tutorial dismissal and snapshot schema 2 (`{level, mode, progress, records, tutorial}`) with a 1 → 2 step;
  feature 506 adds the announcements, haptics and the Sound toggle; feature 507 adds the winning trace and `verified`
  to each result, the replay mode (`replay.start`, `replay.step`, `replay.stop`) with its panel controls, the stored
  sound choice and snapshot schema 3 with a 2 → 3 step; feature 508 adds `BinaryGardensGolden` (test builds only) and
  the solver regression of all 100 levels (`scripts/binary_gardens_regression.py`).
- **Free names:** the UI chunk keys in `release_check.py` in use are a, b, d, e, f, g2, g3, h2, i2, j2, j3, j4, k2,
  m2, o2 … z2, a3 … f3, h3, i3, k3 … z3, a4, b4 and c4 (`d4` is free); no UI test class or folder uses the prefix
  `BG`.
- **Content count:** the source prompt's "content count 81" was resolved by feature 502 (81 is a milestone count; the
  certified catalog has 100 levels), so every count here is 100.

- Q: How do the interface tests find controls and what do they read? → A: through the identifiers the panel carries
  (`experience.r02-g21.binary-gardens.<name>`). This feature pins the full list as
  `BinaryGardensControls.identifierNames` — the names above plus those features 505 … 507 add (the tutorial dismissal,
  hint, stars, goal, band, explanation, modes, level picker, play-level, replay section and sound, named as Mushroom
  Weather names them where a control has the same role) — with a test that every name is unique and used once in the
  panel; where a prerequisite builds a different name, the list follows what is built and this specification is
  aligned at analyze. The panel's level line (a heading text, not a control) carries no identifier and no test reads
  it. The tests read the canvas description for the level and the win, the `stars` text for the stars,
  the `actions` text to confirm each action took effect, the `star` control's value before an adjustment, the
  `luminosity` control's value before and after the change, and the replay step's value for the replay position.
  Impact: FR-R02G2109-001, 002.
- Q: Which interface tests exist and how are they grouped? → A: namespace `BG` in
  `Apps/VisualCore/Tests/UI/BinaryGardens/BGSupport.swift`; `BGPlayUITests` (fresh launch with `-vcResetData
  -vcSkipWelcome -vcCandidates -openExperience r02-g21.binary-gardens`: dismiss the tutorial, play level 1's certified
  plan — choose Star 2 (reading the `star` value "star 2" so a lost tap is retried), check the `luminosity` value reads
  "level 2 of 2", press Luminosity − (counting it only when the actions-left count moves from 9 to 8 and the value
  reads "level 1 of 2") — then Run; read "Every world kept its window and bloomed." and "Best: 3 of 3 stars", the level
  picker shows level 2 open; relaunch without reset after sending the app to the background: the stars and level 2 are
  kept) and `BGReplayUITests` (after the win, Replay best solution, Step until the replay ends won, Stop back to the
  campaign). They run as a new serial chunk `d4` of `release_check.py` (its key checked unique); each test stays under
  90 s apart from the simulator's automation-session setup of each app launch (about 30 s per launch, and a relaunch
  test launches twice). Level 1's certified plan is pinned in `BG` and checked against the Core by an app unit test.
  Impact: FR-R02G2109-002, 007; SC-R02G2109-001.
- Q: Which earlier-schema examples are stored and where do they come from? → A:
  `BinaryGardensExperienceCore.schemaOneExample()` (the schema-1 saved state `{level: 1, records}` of a play of level 1
  with one accepted arrangement action other than the certified one, which leaves the play unwon and still playing:
  on level 1, where only star 2 is adjustable and the certified plan is one luminosity change, star 2's ring change
  `star.ring [1, 1]`, accepted by the kernel as the host test proves)
  and `schemaTwoExample()` (schema 2 with progress, the campaign mode, the tutorial done and level 1 solved with 2
  actions spent and 2 stars, one action above the certified count of 1 (the certified count is the plan's arrangement actions, the run not
  counted, as the budget counts it), no trace), both `MigrationExample`s built in the
  Core (`BinaryGardensSchemaExamples.swift`, modelled on `MushroomWeatherSchemaExamples`), registered with `examples:`;
  the app's migration check restores both into schema 3 with progress kept (a schema-2 result without a trace keeps
  its stars unverified, as feature 507 reconciles). The registration's comment is corrected. Impact: FR-R02G2109-003;
  SC-R02G2109-002.
- Q: What proves the release configuration excludes test-only code? → A: the existing `app-release-build` and
  `app-release-symbols` steps; `BinaryGardensGolden` is forbidden by feature 508, and the scenarios exist only under
  `DEBUG || VISUALCORE_AUTOMATION` (covered by the existing `acceptanceScenarios` entry). Impact: FR-R02G2109-004;
  SC-R02G2109-003.
- Q: How is "not available" checked? → A: an app unit test: without `-vcCandidates` the catalog lists
  `r02-g21.binary-gardens` as not available and the launcher cannot open it; the registry's candidates list contains
  it and `all` does not. Impact: FR-R02G2109-006; SC-R02G2109-002.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The game works inside the real app (Priority: P1) 🎯

A tester opens Binary Gardens from the one app on the simulator, plays level 1 with the panel's star picker, its
Luminosity − button and its Run button to a win, sees the stars, opens the next level, replays the best solution and
returns after closing the app to find the progress kept.

**Why this priority**: the game only matters as part of the shipped app; this is the first end-to-end proof there.

**Independent Test**: interface tests launch the app with the candidate made available for testing, drive only the
visible, labelled controls and read the experience's texts.

**Acceptance Scenarios**:

1. **Given** a fresh app on the simulator, **When** the tester opens Binary Gardens and plays level 1's certified
   solution (star 2's luminosity lowered one level, then the run of the light) with the panel's controls, **Then** the
   experience says "Every world kept its window and bloomed.", the stars read "Best: 3 of 3 stars", and level 2 is
   open in the level picker.
2. **Given** a won level, **When** the app is relaunched, **Then** the same progress, stars and open levels are shown.
3. **Given** a solved level, **When** the tester starts the replay and steps through it, **Then** the replay ends won
   and stopping it returns to the campaign.

### User Story 2 - The app's logic accepts the game (Priority: P1)

The app's own unit tests open the candidate through the app's registry, play it through the app's engine, restore saved
states of every earlier schema and confirm the candidate is not listed as available.

**Independent Test**: app unit tests with the registry, the engine and the stored migration examples.

### User Story 3 - Both build configurations compile and every level is solvable (Priority: P2)

The app compiles in its debug and release configurations for the simulator with Binary Gardens linked, and the solver
regression proves all 100 levels solvable as certified.

**Independent Test**: a debug and a release simulator build of the app succeed; the regression of feature 508 passes.

### Edge Cases

- **Candidate visibility:** without the testing argument the game is not listed as available and cannot be opened from
  the catalog; with it, tests can open it.
- **Earlier saves:** stored saved states of every earlier schema (1 and 2) restore through the app and migrate to the
  current schema (3).
- **Release builds:** test-only code (scenarios, golden descriptions) is excluded from the release configuration, which
  must still compile.
- **Interface lookup:** every control the tests use has a stable identifier, so tests do not depend on wording; the
  selected star and the luminosity are read from their controls' values before Luminosity − is pressed, and Run is
  pressed only after the action shows in the actions count.
- **Relaunch:** the interface test sends the app to the background before terminating it, so the save point runs (the
  lesson of feature 309).
- **Tutorial:** level 1 opens with its tutorial; the test dismisses it before playing.
- **A lost tap:** a press whose effect does not show (the actions count or the chosen value does not move) is not
  counted, so a lost tap cannot skew the play; a second Luminosity − on level 1 would be refused at the lowest level
  and is never sent once the value reads "level 1 of 2".
- **Prerequisites not yet recorded:** if any of R02-G21-04 … 08 is not recorded, this feature's implementation does not
  start; nothing here builds the progress, replay or schema work of those features.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2109-001**: The panel's controls MUST carry stable accessibility identifiers (experience prefix plus control
  name) in addition to their labels and values, and the list of names MUST be pinned and checked unique.
- **FR-R02G2109-002**: Interface tests in the one app MUST open Binary Gardens with the candidate testing argument, win
  level 1 through the panel alone, see the stars and the next level, relaunch with progress kept, and replay a solved
  level to its end.
- **FR-R02G2109-003**: The app registration MUST store a migration example of every earlier snapshot schema (1 and 2),
  and the app's unit tests MUST restore each and open the candidate through the registry and engine.
- **FR-R02G2109-004**: The app MUST compile in the debug and release configurations for the simulator with Binary
  Gardens linked; test-only code MUST be excluded from release.
- **FR-R02G2109-005**: The all-level solvability regression (feature 508) MUST pass in this gate's evidence.
- **FR-R02G2109-006**: Binary Gardens MUST stay a candidate: not listed as available, not openable from the catalog
  without the testing argument.
- **FR-R02G2109-007**: Existing tests MUST pass; the release checks that cover the app (interface test groups, app unit
  tests, app build) MUST include the new tests; the reference regression passes.

### Key Entities

- **Interface test group**: the Binary Gardens interface tests, named in the release checks' groups.
- **Migration example**: a stored saved state of an earlier schema with its expected restore.
- **Build configuration**: debug and release builds of the one app for the simulator.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2109-001**: The interface tests win level 1, keep progress over a relaunch and replay a solved level; each
  test finishes in under 90 seconds on the simulator, not counting the simulator's automation-session setup of each app
  launch (about 30 s per launch; a relaunch test launches twice), and within the app's 180-second per-test allowance.
- **SC-R02G2109-002**: The app unit tests restore both earlier-schema examples and open the candidate; the candidate is
  not listed as available.
- **SC-R02G2109-003**: Debug and release simulator builds of the app succeed.
- **SC-R02G2109-004**: The solver regression passes for 100 of 100 levels.
- **SC-R02G2109-005**: Existing tests pass; the reference regression passes 7 of 7.
- **SC-R02G2109-006** {device}: after ImplementationLock-100, the same journeys on D1/D2/D3 (feature 510, R02-G21-10,
  prepares them).

## Assumptions

- Interface tests follow the app's existing patterns (one namespace of helpers per experience, launch arguments,
  identifiers, short waits), as Mushroom Weather's interface tests.
- The interface tests' 90-second bound sits inside the app's 180-second per-test allowance.
- Features 505 … 507 build the stars text, level picker, tutorial dismissal and replay controls with identifiers, as
  their requirements FR-R02G2105-008 and FR-R02G2107-008 demand; the names this feature pins follow what is built.
- This feature adds no visuals: identifiers, tests and stored examples only, so the code-only graphics and their
  licensing stay those of features 503 and 506; nothing here uses third-party material.
- Layout is unchanged: the panel of features 503 … 507 on the iPhone and iPad simulators; the interface tests run on the
  iOS 27 iPhone simulator, as the app's interface chunks do.
- Observability: interface test failures name the control and the expected text; the release checks print one line per
  group.

## Traceability

| Source item (round2.md R2-G21-09) | Requirement |
|---|---|
| Compile actual target | FR-R02G2109-004 |
| XCUITest | FR-R02G2109-001, 002 |
| Logic test | FR-R02G2109-003 |
| All-level solvability | FR-R02G2109-005 |
| Release config | FR-R02G2109-004 |
| Schema migration | FR-R02G2109-003 |
| Accessibility | FR-R02G2109-001 |
| Deterministic tests | FR-R02G2109-002, 003, 005 |
| Excluded scope | device journeys (SC-R02G2109-006), price, per-game app |
