# Feature Specification: R02-G16-08 — Starlit Cartouche: visual golden and solver regression

**Feature Branch**: `458-starlit-cartouche-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G16-08 (migration ledger, game feature of experience R02-G16) · ID namespace FR-R02G1608-###,
SC-R02G1608-###, T-R02G1608-###

**Input**: User description: the archived R02-G16-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Starlit Cartouche, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/458-starlit-cartouche-visual-golden-solver-regression`; FR-R02G1608-###,
  SC-R02G1608-###, T-R02G1608-###.
- **Packaging (ADR-0009):** experience R02-G16 (`r02-g16.starlit-cartouche`, free; a registered candidate) in
  `Packages/ExperiencesRound02/StarlitCartouche`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 80" milestone figure (the catalog has 100 certified levels). **Device-only items:** frame time and
  memory on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 448 (Voxel Origami's visual golden and solver regression).

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
448's answers where the games agree. Facts checked in code (read-only, 2026-11-25): `StarlitCartoucheSolver.plan`
certifies a level by a breadth-first search over route states (the ship's star, the beat, the strokes drawn) from its
start (star `start`, beat 0, nothing drawn), each state's legs tried corridors by index then waits 0 … 8, a leg kept
only when the chart accepts it and finds no failure, states merged by star, beat and strokes, at most 7 legs
(`maxLegs`) and 300,000 legs tried (`workBound`), returning `legs`, `statesByDepth` and `work`; certifying one level
takes a few milliseconds in a debug build; the 100 witness files in `docs/games/starlit-cartouche/levels/` hold the
number, the level (stars on orbits, range, corridors, hazards, start, beacon, deadline, symbol, budget, tutorial,
fingerprint), the actions (the plan's legs; the last one wins), the per-action digests, the fingerprints after `begin`,
after `dismissTutorial` on a tutorial level and after each action, the counterexample (`depth` = size − 1 and `states`),
the difficulty and the skipped candidate count, byte-checked by `StarlitCartoucheCatalogTests` with the catalog digest
pinned; the simulator frame checks of feature 453 compare rendered frames with the CPU reference (a star's centre
brighter than the backdrop by 0.25 in luminance, the ship's centre with blue above red by 0.08, the first actions bar
0.1 from the backdrop, each point at least 6 px from what is drawn after it) at 1,152 × 768; the palette has 22 named
colours (`night` … `glow`); `StarlitCartoucheChartScene.release()` frees every renderer, the next draw rebuilds them and
`liveObjectCount` counts them; `ProcessMemory.footprint()` reads the footprint; the CI job `round02-host-tests` has a
named regression step per earlier round-two game (Voxel Origami's the latest).

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint); the witness's legs replay on a fresh
  play to a win on exactly the last leg and not before, within the budget, with exactly its per-action fingerprints and
  digests; and `plan` returns exactly the witness's legs with `statesByDepth[size − 1]` equal to the counterexample's
  `states` at depth size − 1; `work` is at most `workBound` (counted, never timed). The run is split into tests of 10
  levels (10 tests), each well under 10 s. Impact: FR-R02G1608-001; SC-R02G1608-001.
- Q: Which alterations must the regression detect and how is each named? → A: thirteen kinds, each applied to a copy and
  each producing a failure message naming the level and the part: a star's orbit, a star's window, a corridor's ends, a
  hazard, the range, the beacon, the deadline, a symbol stroke, the budget; a plan leg; a witness action, a per-action
  fingerprint or digest; the counterexample's state count. Impact: FR-R02G1608-002; SC-R02G1608-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, each after all of the witness's legs but the last, so the symbol is
  part drawn, at least one action is spent from the actions bars and the level is not yet won, at presentation time 0,
  the default choice, the authored camera, plus the hero frame of the scenario manifest's hero scenario at tier 0: 16
  frames) the Core computes, at 1,152 × 768, the projected pixel positions of every star at the current beat, the ship,
  the beacon, the midpoint of every drawn stroke and the first actions bar, rounded to 1/8 pixel, the counts of stars,
  corridors, hazards, active hazards, symbol strokes, drawn strokes, lit and total actions bars, and the 22 palette
  colours as 8-bit sRGB; serialized as JSON with sorted keys and hashed with SHA-256. The 16 descriptions and their
  digests live in `Packages/ExperiencesRound02/StarlitCartouche/golden-frames.json`; the host test recomputes each: an
  equal digest passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned one and every count
  and colour must be equal, or the test fails naming the frame and the first differing value; each pinned digest must
  also equal the digest of its pinned description. The file is rewritten only when `STARLIT_CARTOUCHE_WRITE_GOLDEN=1` is
  set. The simulator test renders the 16 frames and checks them against the same descriptions with the feature-453
  tolerances. Impact: FR-R02G1608-003, 004; SC-R02G1608-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; every reading of cycles 2 … 12 stays within 16 MB of cycle 1's reading,
  applied only when the memory test class runs alone (`TEST_RUNNER_STARLIT_CARTOUCHE_MEMORY_ISOLATED=1`; in the full
  parallel suite the readings are only printed). After each close and each memory warning the scene holds no GPU
  objects of its own (`liveObjectCount` is 0) and the next frame rebuilds them. An unavailable footprint fails with a
  named reason. Impact: FR-R02G1608-005; SC-R02G1608-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's `round02-host-tests` job keeps running all
  round-two host tests and adds a named step "Starlit Cartouche regression (host)" that runs the Starlit Cartouche
  regression filter alone. The local command `python3 scripts/starlit_cartouche_regression.py` runs the host regression
  filter and then the simulator regression test classes through `xcodebuild_package.py --only-testing`, and prints one
  summary line per part with pass or fail and the first failing name; its exit code is non-zero on any failure. Nothing
  is timed against the wall clock. Impact: FR-R02G1608-006, 007; SC-R02G1608-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can still be flown into its symbol and reach the beacon within its
budget and deadline, and that the certified legs are still the fewest that do it, after any change to the code.

**Why this priority**: an unwinnable level, or a level whose certified solution is no longer the shortest, is the
worst failure a route puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the certifying search on each
level; any difference from the certified solution fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win on exactly its last recorded leg and the search finds exactly the certified legs, with the same
   count of states reached one leg short, within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The pearl stars on their orbits, the corridors, the hazard tubes, the drawn strokes, the sapphire ship, the beacon and
the actions bars the player sees stay where the rules say they are and in the palette, at every quality tier, so a
later visual change cannot silently move or recolour them.

**Why this priority**: a star, corridor or gauge drawn in the wrong place or colour misleads the player about the
route.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-453 tolerances.
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

1. **Given** a push, **When** the workflow runs, **Then** a named Starlit Cartouche regression step runs and passes.
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
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (legs tried), not
  seconds.
- **A missing, unreadable or incomplete golden manifest:** the regression fails naming the file and the frame; it is
  never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size; other aspects and the iPhone
  and iPad panel layouts stay covered by the R02-G16-03 and R02-G16-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1608-001**: The regression MUST replay every certified level's witness to a win on exactly its last recorded
  leg and MUST re-run the certifying search on every level, requiring the certified legs and the recorded count of
  states one leg short within the search's work bound.
- **FR-R02G1608-002**: An altered level, plan or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G1608-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected positions of the stars, the ship, the beacon, the drawn strokes' midpoints and
  the first actions bar, the counts of stars, corridors, hazards, active hazards, symbol and drawn strokes and lit and
  total actions bars, palette colours) pinned in the repository with its digest; a recomputed description
  matches when its digest is equal or every position lies within one 1/8-pixel quantum and every count and colour is
  equal.
- **FR-R02G1608-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G1608-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within 16 MB of the first cycle and MUST release the game's GPU objects.
- **FR-R02G1608-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G1608-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each
  test under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G1608-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified plan and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on
  purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1608-001**: All 100 levels replay their witnesses and re-plan to their certified legs within the search's
  work bound; 100 of 100.
- **SC-R02G1608-002**: Each of the thirteen kinds of alteration listed in the clarifications is detected and named.
- **SC-R02G1608-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry.
- **SC-R02G1608-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G1608-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G1608-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds.
- **SC-R02G1608-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on
  D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 452 and the renderer and CPU reference of feature 453 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G16-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G1608-001, 002 |
| Screenshot baselines (code-only) | FR-R02G1608-003, 004 |
| Memory checks | FR-R02G1608-005 |
| CI | FR-R02G1608-006 |
| Deterministic tests, error handling, observability | FR-R02G1608-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G16-06 and R02-G16-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G1608-007), price, per-game app |
