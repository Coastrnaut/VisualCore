# Feature Specification: UA-F07 — Adoption of the existing apps A01 to A04 as experiences

**Feature Branch**: `193-ua-f07-legacy-adoption` (spec directory only; work stays on `main`)

**Created**: 2026-11-12

**Status**: Draft

**Ledger gate**: UA-F07 (migration ledger) · ID namespace FR-U07-###, SC-U07-###, T-U07-###

**Input**: User description: the UA-F07 `/speckit-specify` prompt of Auto-Creator.md section 20
(`docs/catalog/unified-app-features.json`), verbatim in the invocation.

Canonical overrides:
- **Feature directory and ids:** `specs/193-ua-f07-legacy-adoption`; requirement ids FR-U07-###, success
  criteria SC-U07-###, task ids T-U07-###.
- **Names from the brief:** the four apps Generative Art Studio (A01), Fluid Art Playground (A02), Fractal
  Explorer (A03) and Particle Universe (A04); their Core packages; the `ExperienceConformance` helper; the
  enumeration guard; `Catalog/path-map.json`; `project.yml`; the legacy ledger and the migration ledger with the
  gates X-A01 to X-A04; `docs/migration/migration-plan.md`; `docs/apps`. Other modules are not named here.
- **Who the users are:** a person who opens one of the four existing creative experiences from the launcher of
  the one app and finds it working as it did in its standalone app; and the owner, who needs the four standalone
  apps folded into the one app without losing a test, a fixture or a recorded result.
- **Out of scope:** new features of the four apps; the legacy phases A04-P04 to A04-P06 (they run later from the
  archived prompts).
- **Device-only items:** the replay time of long Particle Universe states is measured on devices in the device
  campaign (clarification 3). **Owner-only items:** none.
- **What exists today (read-only audit of 2026-11-12):**
  - A01 has 14 interface tests in 8 classes, 40 app unit tests and 31 Core tests. A02 has 9 interface tests in 7
    classes, 76 app unit tests and 56 Core tests. A03 has 10 interface tests in 6 classes, 64 app unit tests and
    38 Core tests. A04 has 23 interface tests in 7 classes, no app unit tests and 41 Core tests. In total: 56
    interface tests in 28 classes.
  - The committed fixtures whose bytes are recorded in the pre-consolidation baseline are the four A01
    `library-v1` documents, the A03 `bookmark-v1.json` and the A04 `replay-v1.json`. A01 has no committed
    replay file: its replay is checked in code. A02's fixtures are numerical tests in code, with no fixture files.
  - None of the four is registered in the unified app; all four are `available: false` in the catalog;
    `Catalog/path-map.json` records no move; `docs/migration/path-map.json` plans 33 moves, all pending.
  - The legacy ledger has A01-P00 to A03-P06 and A04-P00 to A04-P03 as pass; A04-P04 to A04-P06 are pending.
  - The gates X-A01 to X-A04 depend on UA-F07, UA-F05, UA-F06 and UA-F09. UA-F09 (the verification runner)
    is not yet pass.
  - The session host shows the experience's native controls below the canvas but gives no touch on the canvas to
    the experience. A02 and A03 are driven by touches on the canvas, and A04 places its force by a tap.
  - Experience rule E-13 says a quality tier never changes the state digest, and E-04 says CPU state decides
    outcomes. A02's tiers change the solver's iterations, and its fluid lives in GPU textures. A04's tiers
    lower the live particle limit.
  - Top-level type names and interface test class names repeat across the four apps and the unified app (for
    example `HomeView`, `SettingsUITests`, `LaunchSmokeUITests`).

## Clarifications

### Session 2026-11-12

Answered by the lead under the owner's standing delegation; the recommended option was taken each time.

- Q: Fluid Art Playground keeps its fluid in GPU textures. What do its digest and saved state cover, so that rule E-04
  (CPU decides) and E-05 (restore gives the same digest) hold? → A: The digest and the snapshot cover the CPU state:
  the configuration, the control choices, the pending splats as actions, and the step. The fluid picture is how
  that state is shown. After a restore the picture starts again from the seeded dye pattern with the restored
  configuration. The decision is recorded in an ADR: the picture is not an outcome, and nothing is decided from
  the GPU.
- Q: Fluid Art Playground and Particle Universe lower simulated work under a lower quality level, which would
  change the digest (against E-13). Where does the quality level act? → A: Only on how the state is shown. Particle
  Universe keeps simulating its full requested particle count and draws at most the level's limit. Fluid Art
  Playground's solver passes and splat cap belong to the picture (see the first answer). Each difference from the
  standalone apps is listed as an adapter difference (FR-U07-003).
- Q: How does Particle Universe keep its state within the 1 MiB snapshot limit, since 20,000 particles do not fit and
  the particle system has no stored form? → A: As a replay: the scene, the commands with the step each was given at,
  and the step count. A restore prepares the seed and replays them. Each replay is bounded by the session's
  preparation time limit. A short test measures the replay's cost per step on the simulator, and longer durations
  are bounded from it by arithmetic. Long replays are measured on devices later (corrected 2026-11-13 by the owner's
  rule that tests are short); no framework change is made.
- Q: How can an adopted experience be opened and verified before its X gate makes it available to everyone? →
  A: It is registered as a candidate (`ExperienceRegistry.candidates`) with its scenario manifest. The scenario
  runner and a debug launch argument reach candidates, the launcher does not, and the registry agreement test keeps
  comparing only `ExperienceRegistry.all` with the catalog. A candidate moves to `all` in the step that records its
  X gate.
- Q: How do touches on the canvas reach an adopted experience? → A: The session gives canvas pointer events to the
  open experience's presenter, which turns them into domain actions (normalized positions and phases) and sends
  them through its action port. Every touch is then an action that scenarios can script and records can replay.
  The framework change gets documentation, an API baseline update and the two-chunk reference regression.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generative Art Studio runs inside the one app (Priority: P1)

A person opens Generative Art Studio from the launcher of the one app. They choose a family, change presets,
palettes, the seed and the parameters, play and pause time, save a composition and open it again, and leave.
Everything behaves as it did in the standalone app, and the person's state is there when they come back.

**Why this priority**: A01 is the first experience the migration plan adopts, and the lowest-risk one. It proves
the adapter pattern that the other three follow.

**Independent Test**: With A01 made available in a test build, open it from the launcher, use each control,
leave and open again, and compare the picture and the state with what the standalone app gives for the same
inputs.

**Acceptance Scenarios**:

1. **Given** the one app with A01 registered, **When** the person opens it, **Then** a running experience shows
   the same scene the standalone app shows for the same family, document and time.
2. **Given** a running A01, **When** the person changes a parameter, a preset, a palette or the seed, **Then** the
   picture and the spoken description change as in the standalone app, and the state digest changes.
3. **Given** a running A01 with changes, **When** the person leaves and opens it again, or the app ends and
   starts again, **Then** the same composition and time are shown.
4. **Given** a saved composition, **When** the person opens their library, **Then** they can open, rename and
   remove it as in the standalone app, and the library lives only in A01's own storage.
5. **Given** A01, **When** the conformance helper and the session host tests run, **Then** every check passes.

---

### User Story 2 - Domain behaviour is unchanged (Priority: P1)

The owner needs proof that adopting the apps changed nothing in their domain logic: the same tests pass and the
same fixtures are byte for byte what they were.

**Why this priority**: The brief requires "without changing domain behavior"; it is the condition for every
later step (move, retire).

**Independent Test**: Run each Core package's existing tests unchanged and compare the hashes of the committed
fixtures with the pre-consolidation baseline.

**Acceptance Scenarios**:

1. **Given** the four Core packages, **When** their host tests run, **Then** the same tests pass as before the
   feature, with no test changed, removed or skipped.
2. **Given** the committed fixtures named above, **When** their hashes are compared with the baseline, **Then**
   all six are identical, before and after any move.

---

### User Story 3 - Fractal Explorer runs inside the one app (Priority: P2)

A person explores the Mandelbrot and Julia sets: pans and zooms on the canvas or with the buttons, changes the
iteration cap and the palette, goes to a coordinate, plays a tour, and saves and opens bookmarks.

**Why this priority**: A03 is self-contained, has deterministic math, and needs the canvas touch path that A02
and A04 also need.

**Independent Test**: Open A03 in a test build, pan and zoom by touch and by buttons, save a bookmark, leave and
open again, and compare the framing with the standalone app for the same inputs.

**Acceptance Scenarios**:

1. **Given** a running A03, **When** the person drags or pinches on the canvas, **Then** the framing changes as in
   the standalone app.
2. **Given** a tour, **When** it plays, **Then** its captions and steps advance with the experience's own time,
   not the device clock, and it stops when the person leaves.
3. **Given** a saved bookmark, **When** the person opens it after the app ended, **Then** the same framing is
   shown, from A03's own storage.

---

### User Story 4 - Particle Universe runs inside the one app (Priority: P2)

A person plays with the particle sandbox: emitters, a force placed by a tap and moved by a drag, trails, blend,
families, play, pause, step and a new seed.

**Why this priority**: A04's simulation already runs in fixed steps. Its later phases (P04 to P06) extend the
same adapter, so the adapter must exist first.

**Independent Test**: Open A04 in a test build, place and move the force, add and remove emitters, step, and
compare the particle checksum with the standalone app for the same inputs.

**Acceptance Scenarios**:

1. **Given** a running A04, **When** the person taps the canvas, **Then** the force is placed where they tapped.
2. **Given** the same seed and the same actions, **When** the experience runs the same number of steps, **Then**
   the checksum equals the standalone app's checksum.
3. **Given** the gate X-A04, **When** this feature ends, **Then** X-A04 is still pending, because A04-P04 to P06
   are not sealed.

---

### User Story 5 - Fluid Art Playground runs inside the one app (Priority: P3)

A person paints with fluid: strokes on the canvas, a pinch to change the brush, splashes, pause, step, reset,
palettes, edges and detail, and captures a still.

**Why this priority**: A02 is the hardest fit, because its fluid lives on the GPU. It comes last so that the
pattern and the touch path are proven first.

**Independent Test**: Open A02 in a test build, stroke and splash, pause and step, and compare the CPU state
digest and the picture with the standalone app.

**Acceptance Scenarios**:

1. **Given** a running A02, **When** the person strokes on the canvas, **Then** dye follows the stroke as in the
   standalone app.
2. **Given** A02 after the app ended, **When** it opens again, **Then** the configuration and the controls are
   restored. The fluid picture starts again from its seeded dye pattern (clarification 1).

---

### User Story 6 - No interface test is lost (Priority: P2)

The owner needs every interface test of the four standalone apps to exist again in the one app, under a name
that a table connects to the old one, and a guard that fails when one is missing.

**Why this priority**: The standalone targets can be removed only when their tests live on.

**Independent Test**: Run the guard on the mapping table and on the ported test classes, and run the ported
tests on the phone and the tablet of both simulator runtimes.

**Acceptance Scenarios**:

1. **Given** the 56 interface tests of the four apps, **When** the guard runs, **Then** each old test name maps to
   at least one new test that exists and ran, and the guard fails if one is removed.
2. **Given** a ported test, **When** it runs in the one app, **Then** it checks what the old test checked, through
   the identifiers of the one app.

---

### User Story 7 - Sources move and standalone targets retire, in order (Priority: P3)

After parity is proven, each app's sources move to the paths of the migration plan, keeping their history, and
the standalone target is removed. Every move is recorded, and the steps run in the order the plan gives.

**Why this priority**: It finishes the consolidation, but only after stories 1 to 6 have proven parity.

**Independent Test**: Check that each recorded move exists at its new path with history, that the old path is
gone, that the tests pass again after the move, and that the target is gone from the project only after the
experience was verified on both runtimes.

**Acceptance Scenarios**:

1. **Given** an experience that passed stories 2 and its own adoption story, **When** its sources move, **Then**
   each move keeps the file history and is listed in `Catalog/path-map.json`.
2. **Given** a moved experience, **When** it is verified on both simulator runtimes, **Then** its standalone target
   is removed from `project.yml` and the project builds.
3. **Given** the end of the feature, **Then** the legacy ledger is unchanged, X-A01, X-A02 and X-A03 are recorded
   as pass in the migration ledger, and X-A04 is pending.

### Edge Cases

- **Failure:** an adopted experience whose shaders fail to compile shows the session's failure view with Retry
  and Back, and no other experience is affected.
- **Cancellation:** leaving while an adopted experience prepares cancels the preparation; nothing is saved.
- **Lifecycle interruption:** the app going to the background saves the experience's state. On return the
  experience resumes without running steps for the time it was away. A04's
  "background round trip keeps the person's choice" holds.
- **Memory pressure:** a memory warning closes the open adopted experience through the session with its message;
  its state is saved first.
- **Corrupted or newer-version data:** a damaged or newer saved state of an adopted experience gives the unified
  notice with Reset and Back (UA-F05). A damaged or newer A01 library document or A03 bookmark gives the
  recovery each app already has, without a crash.
- **Two apps' names:** a type or test class name that two apps share never makes the one app fail to build or
  hide a test.
- **A context lost:** an adopted experience whose graphics context is lost is recreated by the session as for any
  experience. A02's fields are rebuilt.
- **A move that breaks a path:** a test or a check that reads a repository path by its old location is updated
  in the same step as the move, and the step fails if any such path is missing.

## Requirements *(mandatory)*

### Functional Requirements

**Domain parity (story 2)**
- **FR-U07-001**: The host tests of the four Core packages MUST pass with no test source changed, removed or
  skipped, before the adapters, after the adapters and after the moves.
- **FR-U07-002**: The six committed fixtures named in "What exists today" MUST keep the bytes recorded in the
  pre-consolidation baseline at every step; a move changes their path, never their content.
- **FR-U07-003**: An adapter MUST NOT change what a Core type computes. Behaviour that the adapter needs differently
  (for example time from steps instead of the device clock) is done in the adapter, and each such difference is
  listed with its reason.

**Adoption (stories 1, 3, 4, 5)**
- **FR-U07-010**: Each of A01, A02, A03 and A04 MUST be an experience of the one app with the id the catalog
  gives it (`a01.generative-art-studio`, `a02.fluid-art-playground`, `a03.fractal-explorer`,
  `a04.particle-universe`), opened through the one session and drawn through the one renderer.
- **FR-U07-011**: Each adopted experience MUST pass the conformance helper (deterministic preparation, digest,
  actions, snapshot round trip, reset, migrations, quality profile) and the session host tests (open, close,
  suspension, retry, memory pressure, context loss).
- **FR-U07-012**: Each adopted experience MUST offer, through its native controls and its canvas, the actions
  its standalone app offers in phases that passed. A04 offers those of P00 to P03.
- **FR-U07-013**: The experiences MUST NOT depend on each other. Code they share (for example a canvas input path
  or a still capture) lives in the framework or the app shell, not in one experience.
- **FR-U07-014**: Each adopted experience MUST keep its state in a saved snapshot of at most 1 MiB, restored to the
  same digest, with the schema version of its core. Particle Universe keeps a replay (scene, commands with their
  steps, step count) that a restore replays within the preparation time limit (clarification 3). Fluid Art
  Playground keeps its CPU state; its picture starts again from the seed (clarification 1).
- **FR-U07-015**: Each adopted experience MUST read and write its own files and values only through its storage
  handle (UA-F05). The A01 library and the A03 bookmarks live there; the experience sources pass the source
  storage rule.
- **FR-U07-016**: Each adopted experience MUST take the person's Reduce Motion and Reduce Flashing choices from
  the shell and combine them with the system setting, replacing each app's own setting.
- **FR-U07-022**: The controls of each adopted experience MUST meet rule E-12. Every control has a VoiceOver label,
  the controls fit at the largest accessibility text size without clipping, touch targets are at least 44 by 44
  points, and information is never shown by colour alone. The ported accessibility audits run at the default and
  the largest text size.
- **FR-U07-017**: Each adopted experience MUST declare its quality levels with names the catalog shows. A quality
  change MUST NOT change the digest (E-13): a level acts only on how the state is shown (clarification 2).
- **FR-U07-018**: Time in an adopted experience MUST advance with the experience's fixed steps, not the device
  clock; this covers palette animation, tours and particle stepping.
- **FR-U07-019**: Touches on the canvas MUST reach the open experience's presenter, which turns them into domain
  actions with normalized positions and sends them through its action port (clarification 5). Drags, pinches and
  taps then work as in the standalone apps and stay deterministic and recordable.
- **FR-U07-020**: A still capture or export that an app offers MUST work in the one app and write only where the
  person chooses through the system's share or save interface, or to the experience's own storage.
- **FR-U07-021**: Before its X gate, an adopted experience MUST be a candidate (`ExperienceRegistry.candidates`)
  that the scenario runner and a debug launch argument can open, while the launcher and the catalog's availability
  stay unchanged (clarification 4).
- **FR-U07-030**: Every interface test of the four apps MUST have at least one counterpart in the one app's
  interface tests, checking the same behaviour.
- **FR-U07-031**: A mapping table MUST list every old test (class and method) with its new test(s). A guard MUST
  fail when a mapped new test does not exist or did not run, or when an old test is missing from the table.
- **FR-U07-032**: Ported test classes MUST have names that are unique in the one app's test bundle.
- **FR-U07-033**: A behaviour of an old test that cannot exist in the one app (for example an app's own
  settings screen, its launch title, its acknowledgements screen) MUST map to the one app's equivalent. If
  none exists, the mapping table states why and which test proves the replacement.
- **FR-U07-034**: The app unit tests of A01 to A03 MUST keep running after their move, as experience tests.

**Moves and retirement (story 7)**
- **FR-U07-040**: The sources of an experience MUST move only after FR-U07-001, FR-U07-002 and FR-U07-011
  pass for it, and only to the paths of `docs/migration/migration-plan.md`.
- **FR-U07-041**: Each move MUST keep the file history and be recorded in `Catalog/path-map.json` with its old
  path, new path and the commit that made it; `docs/migration/path-map.json` marks it done.
- **FR-U07-042**: After a move, the tests of stories 1 to 6 for that experience MUST pass again before the next
  step.
- **FR-U07-043**: A standalone target MUST be removed from `project.yml` only after its experience is verified
  in the one app on both simulator runtimes. The project MUST build after the removal. Particle Universe's target
  stays until X-A04 can pass, after its legacy phases P04 to P06.
- **FR-U07-044**: A repository check or test that names an old path MUST be updated in the step that moves the
  path. Records under `docs/apps` and the archived specifications stay as they are.
- **FR-U07-045**: Each experience MUST be adopted, moved and retired as a separate step that can be reverted
  alone, in the order A01, A02, A03, A04, with the standalone target kept until its own retirement.

**Records (story 7)**
- **FR-U07-050**: The legacy ledger MUST be byte for byte unchanged by this feature.
- **FR-U07-051**: X-A01, X-A02 and X-A03 MUST be recorded as pass in the migration ledger. X-A04 MUST stay
  pending until A04-P04 to A04-P06 are sealed. The X gates depend on UA-F07 in the ledger. This feature therefore
  runs their four checks with the same commands before its seal, to prove each experience is ready, and records
  each X gate right after UA-F07 is recorded. The registration then moves from `candidates` to `all`
  (corrected 2026-11-13).
- **FR-U07-052**: Each `docs/apps` release dossier MUST stay as history and gain one note that its store listing
  is superseded by the one app. Nothing else in the dossier changes.
- **FR-U07-053**: After any change to the framework, the ProjectM reference regression MUST pass 7 of 7 in two
  chunks and the reference worktree MUST be clean.

**Boundaries**
- **FR-U07-060**: The one app MUST keep one app target and one bundle identifier. No new standalone app target is
  added, and none of the four bundle identifiers ships in the one app.
- **FR-U07-061**: The OpenGL ES to ANGLE to Metal path MUST be the only renderer. No adopted experience
  calls GL or EGL directly from the app.
- **FR-U07-062**: `External/projectm-ios` MUST stay read-only and ProjectM types MUST stay out of the
  framework's public API and out of the app.
- **FR-U07-063**: No advertising, analytics, tracking or network code MUST enter the one app. The adopted
  experiences ask for no permission at launch.
- **FR-U07-064**: Every new public framework symbol MUST have `///` documentation and the API baseline MUST be
  updated.

### Key Entities

- **Adopted experience**: one of the four apps as an experience: its id, its core state (what the digest and
  the snapshot cover), its actions, its quality levels and its presenter.
- **Adapter**: the code that connects an app's existing domain and scene types to the experience contract,
  without changing them.
- **Test mapping**: one row per old interface test: old class and method, new class and method(s), and a note
  when the behaviour moved to the one app's equivalent.
- **Executed move**: old path, new path, the commit and the experience it belongs to.
- **Parity record**: per experience, the Core test result, the fixture hashes, the conformance and session
  results, and the interface test results on both runtimes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-U07-001**: 4 of 4 Core packages pass their existing host tests, with 0 test changed or skipped; checked
  before the adapters, after the adapters and after the moves.
- **SC-U07-002**: 6 of 6 committed fixtures have the baseline hash at every step.
- **SC-U07-003**: 4 of 4 adopted experiences pass every conformance check and every session host test.
- **SC-U07-004**: 56 of 56 old interface tests appear in the mapping table with at least one existing new
  test that ran and passed on the phone and the tablet of both simulator runtimes; removing one makes the guard
  fail.
- **SC-U07-005**: For the same seed and the same actions, each adopted experience gives the same state as the
  standalone app in 3 of 3 compared runs per experience: the same A04 checksum, the same A03 framing, the same
  A01 document and time, and the same A02 configuration.
- **SC-U07-006**: Every executed move appears in `Catalog/path-map.json` and keeps its history; 0 planned A01 to
  A03 move is left pending at the end.
- **SC-U07-007**: 3 standalone targets (A01, A02, A03) are removed after their experience was verified on 2 of 2
  runtimes, and the project builds after each removal.
- **SC-U07-008**: The legacy ledger has 0 changed bytes. Before the seal, the X checks of A01, A02 and A03 pass
  as UA-F07 checks. Right after the record, X-A01, X-A02 and X-A03 are pass and X-A04 is pending.
- **SC-U07-009**: The reference regression passes 7 of 7 after the last framework change; the boundary checks
  (one target, no ProjectM, no direct GL, no advertising, tracking or network) pass.
- **SC-U07-010**: Each adopted experience's saved state restores to the same digest after the app ends, in 3 of
  3 cases per experience.
- **SC-U07-011**: A short replay (10 simulated seconds) of Particle Universe runs on both simulator runtimes and on
  the host. The longest state that restores within the preparation time limit of 10 seconds follows from its cost
  per step and is recorded. Longer states are measured on devices (device-only item). The owner's rule of 2026-11-13
  forbids long tests.

## Assumptions

- The verification runner of UA-F09 is needed for the X-A gates and for "verified on both runtimes"
  (Auto-Creator.md section 17.2, step 4). UA-F07's ledger dependencies do not include UA-F09, so the
  adapter work can start now. Verification, moves, retirement and the X-A records come after UA-F09 passes.
- The comparison with the standalone app (SC-U07-005) uses the standalone target while it still exists, so it
  runs before retirement.
- "A01 replay and baselines" means the four `library-v1` fixtures and the replay determinism checked in A01's
  Core tests, since no other A01 replay or baseline file is committed. "A02 fixtures" means its numerical fixture
  tests, which are code.
- Each app's own settings, launch screen and acknowledgements screen are replaced by the one app's settings,
  launcher and acknowledgements. Their interface tests map there (FR-U07-033).
- The interface tests run with the app's test runner in chunks of whole classes, each under ten minutes.
