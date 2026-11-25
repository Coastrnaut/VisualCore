# Feature Specification: R02-G17-08 — Celestial Eclipse Lab: visual golden and solver regression

**Feature Branch**: `468-celestial-eclipse-lab-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G17-08 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1708-###,
SC-R02G1708-###, T-R02G1708-###

**Input**: User description: the archived R02-G17-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Celestial Eclipse Lab, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/468-celestial-eclipse-lab-visual-golden-solver-regression`; FR-R02G1708-###,
  SC-R02G1708-###, T-R02G1708-###.
- **Packaging (ADR-0009):** experience R02-G17 (`r02-g17.celestial-eclipse-lab`, free; a registered candidate) in
  `Packages/ExperiencesRound02/CelestialEclipseLab`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 74" milestone figure (the catalog has 100 certified levels). **Device-only items:** frame time and
  memory on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 458 (Starlit Cartouche's visual golden and solver regression), adapted to phase changes, the
  clock run, the eclipse lenses and the corona halos.

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
458's answers where the games agree. Facts checked in code (read-only, 2026-11-25): `CelestialEclipseLabSolver.plan`
certifies a level by a search by number of phase changes from its starting phases, returning `actions` (the phase
changes), `settingsByDepth` (phase settings judged per number of changes) and `work`, within at most 5 changes
(`maxChanges`) and 60,000 settings judged (`workBound`); the 100 witness files in
`docs/games/celestial-eclipse-lab/levels/` hold the number, the level (bodies with their orbit points, radii and fixed
flags, horizon, target eclipses with windows, starting phases, budget, tutorial, fingerprint), the actions (the plan's
phase changes, then the run that wins), the per-action digests, the fingerprints after `begin`, after `dismissTutorial`
on a tutorial level and after each action, the predicted timeline (intervals and matched count), the counterexample
(`depth` = size − 1 and `settings`), the difficulty and the skipped candidate count, byte-checked by
`CelestialEclipseLabCatalogTests` with the catalog digest pinned; the simulator frame checks of feature 463 compare
rendered frames with the CPU reference (a body's centre not covered at the shown tick brighter than the backdrop by 0.25
in luminance, the first lit actions bar with red above blue by 0.08, the timeline strip's centre 0.1 from the backdrop,
each point at least 6 px from what is drawn after it) at 1,152 × 768; the palette has 21 named colours (corrected at
implement from 22: the 22nd constant is a hex list); `CelestialEclipseLabSkyScene.release()` frees every renderer, the
next draw rebuilds them and `liveObjectCount` counts them; `ProcessMemory.footprint()` reads the footprint; the CI job
`round02-host-tests` has a named regression step per earlier round-two game (Starlit Cartouche's the latest).

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint); the witness's actions replay on a fresh
  play to a win on exactly the final run and not before, within the budget, with exactly its per-action fingerprints
  and digests; and `plan` returns exactly the witness's phase changes with `settingsByDepth[size − 1]` equal to the
  counterexample's `settings` at depth size − 1; `work` is at most `workBound` (counted, never timed). The run is split
  into tests of 10 levels (10 tests), each well under 10 s. Impact: FR-R02G1708-001; SC-R02G1708-001.
- Q: Which alterations must the regression detect and how is each named? → A: twelve kinds, each applied to a copy and
  each producing a failure message naming the level and the part: a body's orbit point, a body's radius, a body's
  fixed flag, a starting phase, a target's bodies, a target's window, the horizon, the budget; a plan phase change; a
  witness action, a per-action fingerprint or digest; the counterexample's settings count. Impact: FR-R02G1708-002;
  SC-R02G1708-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, each after all of the witness's phase changes but before the run,
  so actions are spent from the actions bars and the level is not yet won, shown at the first tick of the predicted
  timeline at which an eclipse is under way (tick 0 when there is none), at presentation time 0, the default chosen
  body, the authored camera, plus the hero frame of the scenario manifest's hero scenario at tier 0: 16 frames) the
  Core computes, at 1,152 × 768, the projected pixel positions of every body at the shown tick, the centre of every
  shadow lens, every halo, the playhead and the first actions bar, rounded to 1/8 pixel, the counts of bodies, rings,
  shadow lenses, halos, targets, matched targets, lit and total actions bars, and the 21 palette colours as 8-bit sRGB;
  serialized as JSON with sorted keys and hashed with SHA-256. The 16 descriptions and their digests live in
  `Packages/ExperiencesRound02/CelestialEclipseLab/golden-frames.json`; the host test recomputes each: an equal digest
  passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned one and every count and colour
  must be equal, or the test fails naming the frame and the first differing value; each pinned digest must also equal
  the digest of its pinned description. The file is rewritten only when `CELESTIAL_ECLIPSE_LAB_WRITE_GOLDEN=1` is set.
  The simulator test renders the 16 frames and checks them against the same descriptions with the feature-463
  tolerances. Impact: FR-R02G1708-003, 004; SC-R02G1708-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; every reading of cycles 2 … 12 stays within 16 MB of cycle 1's reading,
  applied only when the memory test class runs alone (`TEST_RUNNER_CELESTIAL_ECLIPSE_LAB_MEMORY_ISOLATED=1`; in the
  full parallel suite the readings are only printed). After each close and each memory warning the scene holds no GPU
  objects of its own (`liveObjectCount` is 0) and the next frame rebuilds them. An unavailable footprint fails with a
  named reason. Impact: FR-R02G1708-005; SC-R02G1708-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's `round02-host-tests` job keeps running all
  round-two host tests and adds a named step "Celestial Eclipse Lab regression (host)" that runs the Celestial Eclipse
  Lab regression filter alone. The local command `python3 scripts/celestial_eclipse_lab_regression.py` runs the host
  regression filter and then the simulator regression test classes through `xcodebuild_package.py --only-testing`, and
  prints one summary line per part with pass or fail and the first failing name; its exit code is non-zero on any
  failure. Nothing is timed against the wall clock. Impact: FR-R02G1708-006, 007; SC-R02G1708-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can still be won — its target eclipses brought into order within
their windows by phase changes within the budget, then the run — and that the certified phase changes are still the
fewest that do it, after any change to the code.

**Why this priority**: an unwinnable level, or a level whose certified solution is no longer the shortest, is the
worst failure a timing puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the certifying search on each
level; any difference from the certified solution fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win on exactly its final run and the search finds exactly the certified phase changes, with the same
   count of phase sets tried one change short, within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The ivory planets on their notched orbital rings, the shadow lenses of the eclipses, the corona halos, the target
brackets, the timeline with its playhead and the actions bars the player sees stay where the rules say they are and in
the palette, at every quality tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a planet, shadow or gauge drawn in the wrong place or colour misleads the player about the
eclipses.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-463 tolerances.
2. **Given** a change to the scene geometry, palette or camera, **When** the regression runs, **Then** the pinned digest
   no longer matches and the regression fails until the baseline is regenerated on purpose.

### User Story 3 - Memory stays bounded (Priority: P2)

A player who opens and closes the game many times, or plays a long session, does not see the app grow until the system
ends it.

**Independent Test**: on the simulator, opening, drawing and closing the experience repeatedly and receiving memory
warnings keeps the app's memory footprint within 16 MB of the first cycle and releases the game's GPU objects.

**Acceptance Scenarios**:

1. **Given** 12 open-draw-warn-close cycles, **When** the footprint is read after each, **Then** every reading
   after the first stays within the bound of the first, and no GPU object of the game remains after a close or a
   warning.

### User Story 4 - The checks run on every change (Priority: P2)

The project's continuous integration runs the host part of the regression on every push, and one documented local
command runs the whole regression, so a regression is caught before a gate is recorded.

**Independent Test**: the workflow runs the solver and golden-description checks; the local command runs host and
simulator parts and reports one summary.

**Acceptance Scenarios**:

1. **Given** a push, **When** the workflow runs, **Then** a named Celestial Eclipse Lab regression step runs and passes.
2. **Given** the local command, **When** it runs, **Then** it prints one line per part with pass or fail and exits
   non-zero on any failure.

### Edge Cases

- **A baseline that must change on purpose** (a deliberate visual change): regenerating it is an explicit step with an
  environment switch, never automatic, and the new digest is committed with the change.
- **A search that would exceed its bound:** the check fails with the level number instead of hanging.
- **The deepest levels:** the longest band-5 searches are the most expensive, so the solver part runs in groups of 10
  levels and every test stays under 10 seconds.
- **Frames at a tier whose detail differs:** each tier has its own description; positions shared by all tiers are
  checked against the same reference.
- **Memory measurement noise:** the bound applies after a warm-up cycle, not to a single sample.
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (phase sets tried),
  not seconds.
- **A missing, unreadable or incomplete golden manifest:** the regression fails naming the file and the frame; it is
  never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size; other aspects and the iPhone
  and iPad panel layouts stay covered by the R02-G17-03 and R02-G17-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1708-001**: The regression MUST replay every certified level's witness to a win on exactly its final run
  and MUST re-run the certifying search on every level, requiring the certified phase changes and the recorded count of
  phase sets tried one change short within the search's work bound.
- **FR-R02G1708-002**: An altered level, plan or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G1708-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected positions of the bodies, the shadow lenses' centres, the halos, the playhead and
  the first actions bar, the counts of bodies, rings, eclipse lenses, halos, targets, matched targets and lit and total
  actions bars, palette colours) pinned in the repository with its digest; a recomputed description
  matches when its digest is equal or every position lies within one 1/8-pixel quantum and every count and colour is
  equal.
- **FR-R02G1708-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G1708-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within 16 MB of the first cycle and MUST release the game's GPU objects.
- **FR-R02G1708-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G1708-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each
  test under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G1708-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified plan and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on
  purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1708-001**: All 100 levels replay their witnesses and re-plan to their certified phase changes within the
  search's work bound; 100 of 100.
- **SC-R02G1708-002**: Each of the twelve kinds of alteration listed in the clarifications is detected and named.
- **SC-R02G1708-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry.
- **SC-R02G1708-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G1708-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G1708-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds.
- **SC-R02G1708-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on
  D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 462 and the renderer and CPU reference of feature 463 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G17-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G1708-001, 002 |
| Screenshot baselines (code-only) | FR-R02G1708-003, 004 |
| Memory checks | FR-R02G1708-005 |
| CI | FR-R02G1708-006 |
| Deterministic tests, error handling, observability | FR-R02G1708-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G17-06 and R02-G17-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G1708-007), price, per-game app |
