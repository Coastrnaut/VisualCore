# Feature Specification: R02-G12-08 — Harmonic Bridges: visual golden and solver regression

**Feature Branch**: `418-harmonic-bridges-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G12-08 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1208-###,
SC-R02G1208-###, T-R02G1208-###

**Input**: User description: the archived R02-G12-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Harmonic Bridges, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/418-harmonic-bridges-visual-golden-solver-regression`; FR-R02G1208-###,
  SC-R02G1208-###, T-R02G1208-###.
- **Packaging (ADR-0009):** experience R02-G12 (`r02-g12.harmonic-bridges`, free; a registered candidate) in
  `Packages/ExperiencesRound02/HarmonicBridges`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 82" milestone figure. **Device-only items:** frame time and memory on D1/D2/D3 after
  ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 408 (Harmonic Bridges's visual golden and solver regression).

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
408's answers where the games agree. Facts checked in code (read-only audit, 2026-11-23): `HarmonicBridgesSolver.plan`
certifies a level by the minimal set of retuned strings (k = 1 … 6, at most 400,000 choices, `workBound`), returning the
tunings, `smallerChoices` (every choice of fewer tunings, none winning) and `work`; the 100 witness files in
`docs/games/harmonic-bridges/levels/` hold the number, the level, the actions (the plan's tunings then the test), the
per-action fingerprints, the per-step bridge digests, the counterexample (`choices` = `smallerChoices`, `size`), the
difficulty and the skipped candidate count, and are byte-checked by `HarmonicBridgesCatalogTests` with the catalog
digest pinned there; the simulator frame checks of feature 413 compare rendered frames with the CPU reference (island
tops 0.1 from the ground in luminance with red above blue, membrane check points 0.08 from the ground with blue above
red, the gauge's first bar 0.1 from the ground, the ground within 0.05, each point at least 6 px from other elements) at
1,152 × 768; `HarmonicBridgesBridgeScene.release()` frees every renderer, the next draw rebuilds them and
`liveObjectCount` counts them; the CI job `round02-host-tests` runs all round-two host tests and has a named regression
step per earlier round-two game (Echo Cartographer's the latest); `scripts/xcodebuild_package.py` runs simulator tests
with `--only-testing`.

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint); the witness's actions replay on a fresh
  play to a win in exactly its action count, within the budget, with exactly its per-action fingerprints and per-step
  bridge digests; and `plan` returns exactly the witness's tunings with exactly its `smallerChoices` (the
  counterexample's `choices`) and size; `work` is at most `workBound` (counted, never timed). The run is split into
  tests of 10 levels so each stays short. Impact: FR-R02G1208-001; SC-R02G1208-001.
- Q: Which alterations must the regression detect and how is each named? → A: eleven kinds, each applied to a copy and
  each producing a failure message naming the level and the part: an island's position, a string's length, a string's
  starting peg, a string's lock, a step's tone, the threshold, the budget; a plan tuning; a witness action, a
  per-action fingerprint; the smaller-choices count. Impact: FR-R02G1208-002; SC-R02G1208-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, each after the witness's tunings and before its test, so bridges,
  filled marks, pips and a partly spent gauge show, at presentation time 0 (the step shown is step 0) and the authored
  camera, plus the hero frame of the scenario manifest's hero scenario at tier 0: 16 frames) the Core computes, at
  1,152 × 768, the projected pixel positions of every island top, every string midpoint, every membrane check point of
  the shown step's bridges, every step pip and the gauge's first bar, rounded to 1/8 pixel, the counts of islands,
  strings, bridges in the shown step, filled and hollow marks, pips and lit and total gauge bars, and the expected
  colours as 8-bit sRGB (ground, island face, island edge, string, membrane, filled mark, hollow mark, start, goal, pip,
  unlit pip, lit gauge, unlit gauge); serialized as JSON with sorted keys and hashed with SHA-256. The 16 descriptions
  and their digests live in `Packages/ExperiencesRound02/HarmonicBridges/golden-frames.json`; the host test recomputes
  each: an equal digest passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned one and
  every count and colour must be equal, or the test fails naming the frame and the first differing value; each pinned
  digest must also equal the digest of its pinned description. The file is rewritten only when
  `HARMONIC_BRIDGES_WRITE_GOLDEN=1` is set. The simulator test renders the 16 frames and checks them against the same
  descriptions with the feature-413 tolerances. Impact: FR-R02G1208-003, 004; SC-R02G1208-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; every reading of cycles 2 … 12 stays within 16 MB of cycle 1's reading,
  applied only when the memory test class runs alone (`TEST_RUNNER_HARMONIC_BRIDGES_MEMORY_ISOLATED=1`; in the full
  parallel suite the readings are only printed). After each close and each memory warning the scene holds no GPU
  objects of its own (`liveObjectCount` is 0) and the next frame rebuilds them. An unavailable footprint fails with a
  named reason. Impact: FR-R02G1208-005; SC-R02G1208-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's `round02-host-tests` job keeps running all
  round-two host tests and adds a named step "Harmonic Bridges regression (host)" that runs the Harmonic Bridges
  regression filter alone. The local command `python3 scripts/harmonic_bridges_regression.py` runs the host regression
  filter and then the simulator regression test classes through `xcodebuild_package.py --only-testing`, and prints one
  summary line per part with pass or fail and the first failing name; its exit code is non-zero on any failure. Nothing
  is timed against the wall clock. Impact: FR-R02G1208-006, 007; SC-R02G1208-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can be won within its budget and that the certified plan is still
the smallest set of tunings that bridges every step, after any change to the code.

**Why this priority**: an unwinnable level or a level whose certified plan is no longer minimal is the worst failure a
tuning puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the certifying solver on each
level; any difference from the certified plan fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win in exactly its recorded actions and the solver finds exactly the certified plan, with the same
   count of smaller choices tried, within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The copper island prisms, the strings with their filled and hollow sample marks, the cyan membranes of the shown step's
bridges, the start ring, the goal star, the step pips and the moves gauge the player sees stay where the rules say they
are and in the palette, at every quality tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a bridge or mark drawn in the wrong place misleads the player about the crossing.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-413 tolerances.
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
- **Memory measurement noise:** the bound applies after a warm-up cycle, not to a single sample.
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (choices
  tried), not seconds.
- **A missing, unreadable or incomplete golden manifest:** the regression fails naming the file and the frame; it is
  never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size; the other aspects and the iPhone
  and iPad panel layouts stay covered by the R02-G12-03 and R02-G12-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1208-001**: The regression MUST replay every certified level's witness to a win in exactly its recorded
  actions and MUST re-plan every level, requiring the certified plan and its count of smaller choices within the
  solver's work bound.
- **FR-R02G1208-002**: An altered level, plan or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G1208-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected island tops, string midpoints, the membrane check points of the shown step's
  bridges, the filled and hollow mark counts, the step pips, the gauge's lit and total bars, palette colours) pinned in the repository with its digest;
  a recomputed description matches when its digest is equal or every position lies within one 1/8-pixel quantum and
  every count and colour is equal.
- **FR-R02G1208-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G1208-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within a stated bound and MUST release the game's GPU objects.
- **FR-R02G1208-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G1208-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each
  test under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G1208-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified plan and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on
  purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1208-001**: All 100 levels replay their witnesses and re-plan to their certified plans within the solver's
  work bound; 100 of 100.
- **SC-R02G1208-002**: Each kind of alteration listed in the clarifications is detected and named.
- **SC-R02G1208-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry.
- **SC-R02G1208-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G1208-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G1208-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds.
- **SC-R02G1208-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on
  D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 412 and the renderer and CPU reference of feature 413 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G12-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G1208-001, 002 |
| Screenshot baselines (code-only) | FR-R02G1208-003, 004 |
| Memory checks | FR-R02G1208-005 |
| CI | FR-R02G1208-006 |
| Deterministic tests, error handling, observability | FR-R02G1208-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G12-06 and R02-G12-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G1208-007), price, per-game app |
