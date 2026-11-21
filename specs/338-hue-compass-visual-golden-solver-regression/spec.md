# Feature Specification: R02-G04-08 — Hue Compass: visual golden and solver regression

**Feature Branch**: `338-hue-compass-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G04-08 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0408-###,
SC-R02G0408-###, T-R02G0408-###

**Input**: User description: the archived R02-G04-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Hue Compass, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/338-hue-compass-visual-golden-solver-regression`; FR-R02G0408-###,
  SC-R02G0408-###, T-R02G0408-###.
- **Packaging (ADR-0009):** experience R02-G04 (`r02-g04.hue-compass`, free; a registered candidate) in
  `Packages/ExperiencesRound02/HueCompass`; no app target, bundle identifier, scheme or store listing.
- **Content count:** the existing 100 solver-certified levels with their witness files (feature 332), not the source's
  76.
- **Screenshot baselines:** code-only. A baseline is a description of the frame the code computes on the CPU (projected
  positions, palette colours and a pinned digest of that description), never a stored picture made outside the code;
  rendered frames are compared with it on the simulator.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** frame time and memory on D1/D2/D3 after ImplementationLock-100.
  **Owner-only items:** none.
- **Shared features used:** the experience host's off-screen rendering and quality tiers, the shared scenario manifest
  and verification runner, the repository's GitHub workflow, and R02-G04-01 … 07.
- **Model:** feature 328 (Wave Knot Keeper), itself after features 318 and 308, including their lessons: the
  golden digest falls back to a one-quantum position comparison (system sine and cosine may differ in the last bit
  between macOS releases), the pinned descriptions are checked against their own digests, and a process-wide memory
  bound is applied only when its test class runs alone.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
328's answers where the games agree. Facts checked in code (read-only audit, 2026-11-21): `HueCompassSolver.solve(_:depth:)`
tries the empty probe set, then every single bearing, then every pair in lexicographic order, counting the sets tried in
`work` (at most 1 + 96 + 4,560 = 4,657 at depth 2, which `HueCompassSolverTests` already bounds); the 100 witness files
(level, actions, clues, counts, fingerprints, near miss, ambiguity, difficulty, skipped) are byte-checked by
`HueCompassCatalogTests`; the simulator frame checks of feature 333 compare rendered frames with the CPU reference at
1,152 × 768 (the needle tip and each probe mark lit within 3 px by at least 0.15 over night, each checkable band
segment's colour sample within 0.15 per channel, background within 0.05 of night); a memory warning releases the scene's
GPU objects (`HueCompassFallbackTests`); the GitHub workflow's host job runs all round-two host tests and has named
regression steps for the earlier round-two games; `scripts/xcodebuild_package.py` runs simulator tests with
`--only-testing`.

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint), the witness's actions replay on a fresh
  play to a win with exactly its recorded clues and fingerprints, and `solve` returns a probe set of exactly the
  certified smallest size with `work` at most 4,657 and equal to the certified solution's work; the probe set settles
  the level (every consistent candidate accepted by one selection). Work is counted, never timed. The run is split by
  band (20 levels per test). Impact: FR-R02G0408-001; SC-R02G0408-001.
- Q: Which alterations must the regression detect and how is each named? → A: fourteen kinds, each applied to a copy
  and each producing a failure message naming the level and the part: a level's hue offset, a fog density, the target
  bearing, the start bearing, the bearing tolerance, the band tolerance, the allowance; a solution probe bearing; a
  witness's action, clue, near miss, ambiguity, recorded fingerprint; the level fingerprint. Impact: FR-R02G0408-002;
  SC-R02G0408-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, each after its witness's probes but before the selection so the
  probe marks show, at presentation time 0 and the authored camera, plus the hero frame of the scenario manifest's hero
  scenario at tier 0: 16 frames) the Core computes, at 1,152 × 768, the projected pixel positions of the needle tip,
  every band segment's colour sample point, every probe mark centre, the selection mark and the target ring when
  present, rounded to 1/8 pixel, and the expected colours as 8-bit sRGB (night, pearl, ember, sapphire and each
  segment's band colour); serialized as JSON with sorted keys and hashed with SHA-256. The 16 descriptions and their
  digests live in `Packages/ExperiencesRound02/HueCompass/golden-frames.json`; the host test recomputes each: an equal
  digest passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned one and every colour must
  be equal, or the test fails naming the frame and the first differing value; each pinned digest must also equal the
  digest of its pinned description. The file is rewritten only when `HUE_COMPASS_WRITE_GOLDEN=1` is set. The simulator
  test renders the 16 frames and checks them against the same descriptions with the feature-333 tolerances. Impact:
  FR-R02G0408-003, 004; SC-R02G0408-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; the bound is that every reading of cycles 2 … 12 stays within 16 MB of
  cycle 1's reading, applied only when the memory test class runs alone (`TEST_RUNNER_HUE_COMPASS_MEMORY_ISOLATED=1`; in
  the full parallel suite the readings are only printed). After each close and each memory warning the scene holds no
  renderers of its own (a test-visible count is 0) and the next frame rebuilds them. An unavailable footprint fails the
  check with a named reason rather than passing. Impact: FR-R02G0408-005; SC-R02G0408-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's host job keeps running all round-two host
  tests and adds a named step that runs the Hue Compass regression filter alone. The local command
  `python3 scripts/hue_compass_regression.py` runs the host regression filter and then the simulator regression test
  classes through `xcodebuild_package.py --only-testing` (bounded by that runner's per-test time allowance), and prints
  one summary line per part with pass or fail and the first failing name; its exit code is non-zero on any failure.
  Nothing in either is timed against the wall clock. Impact: FR-R02G0408-006, 007; SC-R02G0408-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can be won within its allowance and that the fewest probes shown is true, after any change to the code.

**Why this priority**: an unwinnable level or a wrong "best possible" is the worst failure a puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the solver on each level; any
difference from the certified smallest probe set fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win in exactly its recorded actions and the solver finds a probe set of exactly the certified smallest
   size within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The needle, hue wheel, fog and marks the player sees stay where the rules say they are and in the palette, at every quality
tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a band or mark drawn in the wrong place misleads the player about the clue they are reading.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-333 tolerances (clarification Q3).
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
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (probe sets tried), not seconds.
- **A missing, unreadable or incomplete golden manifest** (a frame without a digest, an unknown frame, a schema other
  than 1): the regression fails naming the file and the frame; it is never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size (1,152 × 768, aspect 1.5, the size of the R02-G04-03 frame checks); the
  other aspects and the iPhone and iPad panel layouts stay covered by the R02-G04-03 and R02-G04-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0408-001**: The regression MUST replay every certified level's witness to a win in exactly its recorded
  actions and MUST re-solve every level, requiring the certified smallest probe set within the solver's work bound.
- **FR-R02G0408-002**: An altered level, solution or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G0408-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected positions of the needle, band segments, fog and marks, palette colours) pinned in the
  repository with its digest; a recomputed description matches when its digest is equal or every position lies within
  one 1/8-pixel quantum and every colour is equal.
- **FR-R02G0408-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G0408-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within a stated bound and MUST release the game's GPU objects.
- **FR-R02G0408-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G0408-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each test
  under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G0408-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified smallest probe set and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0408-001**: All 100 levels replay their witnesses and re-solve to their certified smallest probe set within
  4,657 probe sets tried (1 + 96 + 4,560, the most at depth 2); 100 of 100.
- **SC-R02G0408-002**: Each of the 14 kinds of alteration of clarification Q2 is detected and named.
- **SC-R02G0408-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry (equal digest, or
  within one 1/8-pixel quantum with equal colours).
- **SC-R02G0408-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G0408-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G0408-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10 seconds.
- **SC-R02G0408-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 332 and the renderer and CPU reference of feature 333 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound of 16 MB is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G04-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G0408-001, 002 |
| Screenshot baselines (code-only) | FR-R02G0408-003, 004 |
| Memory checks | FR-R02G0408-005 |
| CI | FR-R02G0408-006 |
| Deterministic tests, error handling, observability | FR-R02G0408-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G04-06 and R02-G04-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G0408-007), price, per-game app |
