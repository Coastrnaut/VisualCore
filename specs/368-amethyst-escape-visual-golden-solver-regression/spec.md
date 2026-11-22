# Feature Specification: R02-G07-08 — Amethyst Escape: visual golden and solver regression

**Feature Branch**: `368-amethyst-escape-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G07-08 (migration ledger, game feature of experience R02-G07) · ID namespace FR-R02G0708-###,
SC-R02G0708-###, T-R02G0708-###

**Input**: User description: the archived R02-G07-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Amethyst Escape, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/368-amethyst-escape-visual-golden-solver-regression`; FR-R02G0708-###,
  SC-R02G0708-###, T-R02G0708-###.
- **Packaging (ADR-0009):** experience R02-G07 (`r02-g07.amethyst-escape`, free; a registered candidate) in
  `Packages/ExperiencesRound02/AmethystEscape`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 80" milestone figure. **Device-only items:** frame time and memory on D1/D2/D3 after
  ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 358 (Chrono Constellator's visual golden and solver regression).

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
358's answers where the games agree. Facts checked in code (read-only audit, 2026-11-22): `AmethystEscapeSolver.solve`
is a packed breadth-first search from the opening crystal over every shell rotation (both directions) and the advance,
returning the certified shortest escape with its actions, `smallest`, `depths` (the states first reached at each depth)
and `work` (the states expanded); `AmethystEscapeSolver.stateCount(level)` is the size of the packed state space; the
100 witness files in `docs/games/amethyst-escape/levels/` hold the number, the level, the actions, per-move digests and
fingerprints, the smallest move count, the depths, the unedited run, the near miss, the difficulty and the skipped count,
and are byte-checked by `AmethystEscapeCatalogTests` one band of 20 levels per test; the catalog digest is pinned there;
the simulator frame checks of feature 363 compare rendered frames with the CPU reference (the pearl centre within 3 px
of a pixel 0.15 brighter than the backdrop, the exit arrow at least 0.1 away from the backdrop, every open wedge top at
least 0.05 away from the backdrop, the probe corners within 0.05 of the backdrop); `AmethystEscapeCrystalScene.release()`
frees every renderer and the next draw rebuilds them (memory warning, teardown); the CI host job runs all round-two host
tests and has a named regression step per earlier round-two game; `scripts/xcodebuild_package.py` runs simulator tests
with `--only-testing`.

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint); the witness's actions replay on a fresh
  play to a win in exactly its smallest move count, within the budget, with exactly its per-move digests and
  fingerprints; and `solve` returns exactly the witness's actions (the certified shortest escape), with `smallest` and
  `depths` equal to the witness's; `work` is at most `stateCount(level)` (counted, never timed). The run is split into
  tests of 10 levels so each stays short. Impact: FR-R02G0708-001; SC-R02G0708-001.
- Q: Which alterations must the regression detect and how is each named? → A: twelve kinds, each applied to a copy and
  each producing a failure message naming the level and the part: a shell's aperture, a shell's wall, a blocked wedge,
  the sector count, the start sector, the budget; a solution action; a witness action, a per-move digest, a per-move
  fingerprint; the smallest move count; the depths. Impact: FR-R02G0708-002; SC-R02G0708-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, each after the witness's first min(smallest − 1, 3) actions so the
  move bar and turned shells show, at presentation time 0 and the authored camera, plus the hero frame of the scenario
  manifest's hero scenario at tier 0: 16 frames) the Core computes, at 1,152 × 768, the projected pixel positions of the
  pearl centre, the exit arrow centre and every wedge top centre, rounded to 1/8 pixel, the move bar's length rounded to
  1/1,024, the move count, and the expected colours as 8-bit sRGB (backdrop, amethyst, highlight, platinum, blocked,
  pearl, exit, amber); serialized as JSON with sorted keys and hashed with SHA-256. The 16 descriptions and their digests
  live in `Packages/ExperiencesRound02/AmethystEscape/golden-frames.json`; the host test recomputes each: an equal digest
  passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned one and every colour must be
  equal, or the test fails naming the frame and the first differing value; each pinned digest must also equal the digest
  of its pinned description. The file is rewritten only when `AMETHYST_ESCAPE_WRITE_GOLDEN=1` is set. The simulator
  test renders the 16 frames and checks them against the same descriptions with the feature-363 tolerances. Impact:
  FR-R02G0708-003, 004; SC-R02G0708-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; every reading of cycles 2 … 12 stays within 16 MB of cycle 1's reading,
  applied only when the memory test class runs alone (`TEST_RUNNER_AMETHYST_ESCAPE_MEMORY_ISOLATED=1`; in the full
  parallel suite the readings are only printed). After each close and each memory warning the scene holds no GPU
  objects of its own (a test-visible count is 0) and the next frame rebuilds them. An unavailable footprint fails with a
  named reason. Impact: FR-R02G0708-005; SC-R02G0708-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's host job keeps running all round-two host
  tests and adds a named step "Amethyst Escape regression (host)" that runs the Amethyst Escape regression filter alone.
  The local command `python3 scripts/amethyst_escape_regression.py` runs the host regression filter and then the
  simulator regression test classes through `xcodebuild_package.py --only-testing`, and prints one summary line per part
  with pass or fail and the first failing name; its exit code is non-zero on any failure. Nothing is timed against the
  wall clock. Impact: FR-R02G0708-006, 007; SC-R02G0708-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can be won within its move budget and that the fewest moves
shown is true, after any change to the code.

**Why this priority**: an unwinnable level or a wrong "best possible" is the worst failure a puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the solver on each level; any
difference from the certified shortest escape fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win in exactly its recorded actions and the solver finds an escape of exactly the certified smallest
   length within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The shells, wedges, wall fins, pearl and exit the player sees stay where the rules say they are and in the palette, at
every quality tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a wedge or opening drawn in the wrong place misleads the player about which route is open.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-363 tolerances (clarification Q3).
2. **Given** a change to the scene geometry, palette or camera, **When** the regression runs, **Then** the pinned digest
   no longer matches and the regression fails until the baseline is regenerated on purpose.

### User Story 3 - Memory stays bounded (Priority: P2)

A player who opens and closes the game many times, or plays a long session, does not see the app grow until the system
ends it.

**Independent Test**: on the simulator, opening, drawing and closing the experience repeatedly and receiving memory
warnings keeps the app's memory footprint within a stated bound after warm-up and releases the game's GPU objects.

### User Story 4 - The checks run on every change (Priority: P2)

The project's continuous integration runs the host part of the regression on every push, and one documented local
command runs the whole regression, so a regression is caught before a gate is recorded.

**Independent Test**: the workflow runs the solver and golden-description checks; the local command runs host and
simulator parts and reports one summary.

### Edge Cases

- **A baseline that must change on purpose** (a deliberate visual change): regenerating it is an explicit step with an
  environment switch, never automatic, and the new digest is committed with the change.
- **A solver that takes longer than its bound:** the check fails with the level number instead of hanging.
- **Frames at a tier whose detail differs:** each tier has its own description; positions shared by all tiers are
  checked against the same reference.
- **Memory measurement noise:** the bound applies after a warm-up cycle and to the growth between the first and last
  measured cycle, not to a single sample.
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (states
  visited), not seconds.
- **A missing, unreadable or incomplete golden manifest** (a frame without a digest, an unknown frame, a schema other
  than 1): the regression fails naming the file and the frame; it is never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size (1,152 × 768, aspect 1.5); the
  other aspects and the iPhone and iPad panel layouts stay covered by the R02-G07-03 and R02-G07-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0708-001**: The regression MUST replay every certified level's witness to a win in exactly its recorded
  actions and MUST re-solve every level, requiring the certified shortest escape length and the same work count.
- **FR-R02G0708-002**: An altered level, solution or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G0708-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected positions of the pearl, the exit arrow and every wedge top centre, the move
  bar's length, palette colours) pinned in the repository with its digest; a recomputed description matches when its
  digest is equal or every position lies within one 1/8-pixel quantum and every colour is equal.
- **FR-R02G0708-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G0708-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within a stated bound and MUST release the game's GPU objects.
- **FR-R02G0708-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G0708-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each test
  under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G0708-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified shortest escape and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0708-001**: All 100 levels replay their witnesses and re-solve to their certified smallest move count with
  the witness's actions and depths, within the state-count work bound; 100 of 100.
- **SC-R02G0708-002**: Each kind of alteration listed in the clarifications is detected and named.
- **SC-R02G0708-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry (equal digest, or
  within one 1/8-pixel quantum with equal colours).
- **SC-R02G0708-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G0708-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G0708-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds.
- **SC-R02G0708-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 362 and the renderer and CPU reference of feature 363 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound of 16 MB is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G07-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G0708-001, 002 |
| Screenshot baselines (code-only) | FR-R02G0708-003, 004 |
| Memory checks | FR-R02G0708-005 |
| CI | FR-R02G0708-006 |
| Deterministic tests, error handling, observability | FR-R02G0708-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G07-06 and R02-G07-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G0708-007), price, per-game app |
