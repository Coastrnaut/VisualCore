# Feature Specification: R02-G01-08 — Aurora Loom: visual golden and solver regression

**Feature Branch**: `308-aurora-loom-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-08 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0108-###,
SC-R02G0108-###, T-R02G0108-###

**Input**: User description: the archived R02-G01-08 `/speckit-specify` prompt (round2.md line 2492), verbatim in the
invocation: "Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Aurora Loom, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/308-aurora-loom-visual-golden-solver-regression`; FR-R02G0108-###,
  SC-R02G0108-###, T-R02G0108-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate) in
  `Packages/ExperiencesRound02/AuroraLoom`; no app target, bundle identifier, scheme or store listing. The source's file
  paths (`Apps/AuroraLoom`, `Packages/GameModules/AuroraLoomCore`) are superseded by that package.
- **Content count:** the existing 100 solver-certified levels with their witness files (feature 302), not the source's 80.
- **Screenshot baselines:** code-only. A baseline is a description of the frame the code computes on the CPU (projected
  positions, palette colours and a pinned digest of that description), never a stored picture made outside the code;
  rendered frames are compared with it on the simulator.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** frame time and memory on D1/D2/D3 after ImplementationLock-100.
  **Owner-only items:** none.
- **Shared features used:** the experience host's off-screen rendering and quality tiers, the shared scenario manifest
  and verification runner, the repository's GitHub workflow, and R02-G01-01 … 07.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `AuroraLoomSolver.solve(_:)` is exact (per-ribbon bounded descent of at most
`maxSweeps` = 32 sweeps, then the full 256-setting grid) and counts every score evaluation in `work`; the 100 witness
files are byte-checked by `AuroraLoomCatalogTests` and their refusals by `AuroraLoomWitnessTests`; the simulator render
tests of feature 303 already compare frames with the CPU reference at 768 × 512; `ProcessMemory.footprint()`
(VisualCoreRendering) reads the process footprint through the public `task_info`; `AuroraLoomRibbonScene.release()` frees
the GPU objects; the GitHub workflow's host job runs `swift test --package-path Packages/ExperiencesRound02`;
`scripts/xcodebuild_package.py` runs simulator tests with `--only-testing` and a time limit.

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint), the witness replays to a win in exactly
  its recorded moves, and `solve` from the start returns a solution of exactly the certified shortest length whose moves
  win, with `work` at most 3 × (32 × 32 + 256) = 3,840 evaluations (three ribbons, each at most 32 sweeps of 32 settings
  and the 256-setting grid). Work is counted, never timed. The run is split by band (20 levels per test). Impact:
  FR-R02G0108-001; SC-R02G0108-001.
- Q: Which alterations must the regression detect and how is each named? → A: twelve kinds, each applied to a copy and
  each producing a failure message naming the level and the part: a level's tolerance, allowance, a gate, a ribbon start
  step, ω; a solution move's ribbon, control or step; a witness's terminal steps, counterexample, recorded shortest; the
  level fingerprint. Impact: FR-R02G0108-002; SC-R02G0108-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2 at frame time 0, plus the hero frame of the scenario manifest's hero
  scenario at tier 0: 16 frames) the Core computes, at 768 × 512, the projected pixel positions of every ribbon sample
  checked by the feature-303 frame check, of every gate marker and gate centre, rounded to 1/8 pixel, and the expected
  colours as 8-bit sRGB; serialized as JSON with sorted keys, hashed with SHA-256. The 16 descriptions and their digests
  live in a committed file `Packages/ExperiencesRound02/AuroraLoom/golden-frames.json` (amended in analyze: positions
  come from the system's sine and cosine, whose last bit may differ between macOS releases, so a digest alone could fail
  CI without any visual change). The host test recomputes each description: an equal digest passes; otherwise every
  position must lie within one 1/8-pixel quantum of the pinned one and every colour must be equal, or the test fails
  naming the frame and the first differing value. The file is rewritten only when `AURORA_LOOM_WRITE_GOLDEN=1` is set. The simulator test renders the
  16 frames and checks them against the same descriptions with the feature-303 tolerances. Impact: FR-R02G0108-003,
  004; SC-R02G0108-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; the bound is that every reading of cycles 2 … 12 stays within 16 MB of
  cycle 1's reading. After each close and after each memory warning the scene holds no GPU objects (a test-visible count
  of live programs and buffers is 0) and the next frame rebuilds them. An unavailable footprint fails the check with a
  named reason rather than passing. Impact: FR-R02G0108-005; SC-R02G0108-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's host job keeps running all round-two host
  tests (solver regression and golden digests included) and adds a named step that runs the Aurora Loom regression
  filter alone, so a failure is visible by name. The local command `python3 scripts/aurora_loom_regression.py` runs the
  host regression filter and then the simulator regression test classes through `xcodebuild_package.py --only-testing`
  with a time limit, and prints one summary line per part with pass or fail and the first failing name; its exit code is
  non-zero on any failure. Nothing in either is timed against the wall clock. Impact: FR-R02G0108-006, 007;
  SC-R02G0108-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can be won within its allowance and that the best-possible move
count shown is true, after any change to the code.

**Why this priority**: an unwinnable level or a wrong "best possible" is the worst failure a puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the solver on each level; any
difference from the certified shortest solution fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win in exactly its recorded moves and the solver finds a solution of exactly the certified shortest
   length within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The ribbons, gates and markers the player sees stay where the rules say they are and in the palette, at every quality
tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a drawn marker in the wrong place misleads the player about whether a gate is met.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description (positions within 2 pixels, colours within 0.12 per channel, background within 0.05 of night).
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
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work, not seconds.
- **A missing, unreadable or incomplete golden manifest** (a frame without a digest, an unknown frame, a schema other
  than 1): the regression fails naming the file and the frame; it is never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size (768 × 512, aspect 1.5); the
  other aspects 0.4 … 2.5 and the iPhone and iPad panel layouts stay covered by the R02-G01-03 and R02-G01-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0108-001**: The regression MUST replay every certified level's witness to a win in exactly its recorded
  moves and MUST re-solve every level, requiring the certified shortest length within the solver's work bound.
- **FR-R02G0108-002**: An altered level, solution or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G0108-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected positions of ribbons, gates and markers, palette colours) whose digest is pinned
  in the repository.
- **FR-R02G0108-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G0108-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within a stated bound and MUST release the game's GPU objects.
- **FR-R02G0108-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G0108-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each test
  under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G0108-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified shortest solution and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned digests, regenerated only on purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0108-001**: All 100 levels replay their witnesses and re-solve to their certified shortest length within
  3,840 evaluations of work; 100 of 100.
- **SC-R02G0108-002**: Each of the 12 kinds of alteration of clarification Q2 is detected and named.
- **SC-R02G0108-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every description matches its pinned digest.
- **SC-R02G0108-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G0108-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G0108-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10 seconds.
- **SC-R02G0108-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 302 and the renderer and CPU reference of feature 303 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound of 16 MB is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G01-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G0108-001, 002 |
| Screenshot baselines (code-only) | FR-R02G0108-003, 004 |
| Memory checks | FR-R02G0108-005 |
| CI | FR-R02G0108-006 |
| Deterministic tests, error handling, observability | FR-R02G0108-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G01-06 and R02-G01-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G0108-007), price, per-game app |
