# Feature Specification: R02-G05-08 — Colorfall Canyons: visual golden and solver regression

**Feature Branch**: `348-colorfall-canyons-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G05-08 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0508-###,
SC-R02G0508-###, T-R02G0508-###

**Input**: User description: the archived R02-G05-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Add deterministic CI checks for solver, golden frames and memory" for Colorfall Canyons, with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/348-colorfall-canyons-visual-golden-solver-regression`; FR-R02G0508-###,
  SC-R02G0508-###, T-R02G0508-###.
- **Packaging (ADR-0009):** experience R02-G05 (`r02-g05.colorfall-canyons`, free; a registered candidate) in
  `Packages/ExperiencesRound02/ColorfallCanyons`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** frame time and memory on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 338 (Hue Compass's visual golden and solver regression).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
338's answers where the games agree. Facts checked in code (read-only audit, 2026-11-21): `ColorfallCanyonsSolver.solve`
tries edit sets of size 0 … 3 in a fixed order, counting distinct routings simulated (`work`) and those of fewer edits
than the smallest (`smaller`); the 100 witness files hold the level, the actions, per-tick digests, fingerprints, the
win tick, `smaller`, the near miss, the unedited run, totals and the difficulty, and are byte-checked by
`ColorfallCanyonsCatalogTests` (a band of 20 levels' solver runs took 3 … 15 s on the debug host, so those tests run in
halves); the simulator frame checks of feature 343 compare rendered frames with the CPU reference at 1,152 × 768 (each
flowing emitter top lit within 3 px by at least 0.15 over night, every dry front-row open cell's top centre and at least
80 % of all open cells at least 0.1 in luminance from night, the corners within 0.05 of night); a memory warning
releases the scene's GPU objects; the CI host job runs all round-two host tests and has a named regression step per
earlier round-two game; `scripts/xcodebuild_package.py` runs simulator tests with `--only-testing`.

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint); the witness's actions replay on a fresh
  play to a win at exactly its win tick with exactly its per-tick digests and fingerprints; and `solve` returns exactly
  the witness's edit set (the certified smallest), with `smaller` equal to the witness's count and the win tick equal.
  Work is counted, never timed. The run is split into tests of 10 levels so each stays short. Impact: FR-R02G0508-001;
  SC-R02G0508-001.
- Q: Which alterations must the regression detect and how is each named? → A: twelve kinds, each applied to a copy and
  each producing a failure message naming the level and the part: a cell height, a cell ground, a spring's colour, the
  flow rate, the budget, the tick limit, a basin's target share, a basin's wrong-mass tolerance; a solution edit; a
  witness action, a per-tick digest; the level fingerprint. Impact: FR-R02G0508-002; SC-R02G0508-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, each after its witness's edits and 12 ticks so fluid shows, at
  presentation time 0 and the authored camera, plus the hero frame of the scenario manifest's hero scenario at tier 0:
  16 frames) the Core computes, at 1,152 × 768, the projected pixel positions of every cell's top centre, every spring
  emitter top, every basin centre and every wet cell's sheet top centre, rounded to 1/8 pixel, and the expected colours
  as 8-bit sRGB (night, sandstone, rock, pearl, cyan, coral, yellow and each wet cell's fluid mix); serialized as JSON
  with sorted keys and hashed with SHA-256. The 16 descriptions and their digests live in
  `Packages/ExperiencesRound02/ColorfallCanyons/golden-frames.json`; the host test recomputes each: an equal digest
  passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned one and every colour must be
  equal, or the test fails naming the frame and the first differing value; each pinned digest must also equal the digest
  of its pinned description. The file is rewritten only when `COLORFALL_CANYONS_WRITE_GOLDEN=1` is set. The simulator
  test renders the 16 frames and checks them against the same descriptions with the feature-343 tolerances. Impact:
  FR-R02G0508-003, 004; SC-R02G0508-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; every reading of cycles 2 … 12 stays within 16 MB of cycle 1's reading,
  applied only when the memory test class runs alone (`TEST_RUNNER_COLORFALL_CANYONS_MEMORY_ISOLATED=1`; in the full
  parallel suite the readings are only printed). After each close and each memory warning the scene holds no renderers
  of its own (a test-visible count is 0) and the next frame rebuilds them. An unavailable footprint fails with a named
  reason. Impact: FR-R02G0508-005; SC-R02G0508-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's host job keeps running all round-two host
  tests and adds a named step "Colorfall Canyons regression (host)" that runs the Colorfall Canyons regression filter
  alone. The local command `python3 scripts/colorfall_canyons_regression.py` runs the host regression filter and then the
  simulator regression test classes through `xcodebuild_package.py --only-testing`, and prints one summary line per part
  with pass or fail and the first failing name; its exit code is non-zero on any failure. Nothing is timed against the
  wall clock. Impact: FR-R02G0508-006, 007; SC-R02G0508-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can be won within its budget and tick limit and that the fewest actions shown is true, after any change to the code.

**Why this priority**: an unwinnable level or a wrong "best possible" is the worst failure a puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the solver on each level; any
difference from the certified smallest edit set fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win in exactly its recorded actions and the solver finds an edit set of exactly the certified smallest
   size within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The canyon blocks, springs, basins and fluid the player sees stay where the rules say they are and in the palette, at every quality
tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a channel or basin drawn in the wrong place misleads the player about where the fluid will go.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-343 tolerances (clarification Q3).
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
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (distinct routings simulated), not seconds.
- **A missing, unreadable or incomplete golden manifest** (a frame without a digest, an unknown frame, a schema other
  than 1): the regression fails naming the file and the frame; it is never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size (1,152 × 768, aspect 1.5); the
  other aspects and the iPhone and iPad panel layouts stay covered by the R02-G05-03 and R02-G05-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0508-001**: The regression MUST replay every certified level's witness to a win in exactly its recorded
  actions and MUST re-solve every level, requiring the certified smallest edit set within the solver's work bound.
- **FR-R02G0508-002**: An altered level, solution or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G0508-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected positions of block tops, spring emitters, basin centres and fluid sheets, palette colours) pinned in the
  repository with its digest; a recomputed description matches when its digest is equal or every position lies within
  one 1/8-pixel quantum and every colour is equal.
- **FR-R02G0508-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G0508-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within a stated bound and MUST release the game's GPU objects.
- **FR-R02G0508-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G0508-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each test
  under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G0508-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified smallest edit set and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0508-001**: All 100 levels replay their witnesses and re-solve to their certified smallest edit set with
  the witness's `smaller` count (distinct routings simulated) and win tick; 100 of 100.
- **SC-R02G0508-002**: Each of the 12 kinds of alteration of clarification Q2 is detected and named.
- **SC-R02G0508-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry (equal digest, or
  within one 1/8-pixel quantum with equal colours).
- **SC-R02G0508-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G0508-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G0508-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10 seconds.
- **SC-R02G0508-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 342 and the renderer and CPU reference of feature 343 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound of 16 MB is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G04-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G0508-001, 002 |
| Screenshot baselines (code-only) | FR-R02G0508-003, 004 |
| Memory checks | FR-R02G0508-005 |
| CI | FR-R02G0508-006 |
| Deterministic tests, error handling, observability | FR-R02G0508-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G05-06 and R02-G05-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G0508-007), price, per-game app |
