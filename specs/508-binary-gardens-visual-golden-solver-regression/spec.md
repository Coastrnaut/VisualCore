# Feature Specification: R02-G21-08 — Binary Gardens: visual golden and solver regression

**Feature Branch**: `508-binary-gardens-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-08 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2108-###,
SC-R02G2108-###, T-R02G2108-###

**Input**: User description: the archived R02-G21-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Binary Gardens, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/508-binary-gardens-visual-golden-solver-regression`; FR-R02G2108-###,
  SC-R02G2108-###, T-R02G2108-###.
- **Packaging (ADR-0009):** experience R02-G21 (`r02-g21.binary-gardens`, free; a registered candidate since
  R02-G21-03) in `Packages/ExperiencesRound02/BinaryGardens`; no app target, bundle identifier, XcodeGen scheme or store
  listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and its
  prior-round device prerequisites, the "content count 81" milestone figure (the catalog has 100 certified levels) and
  the paths `Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore`; entitlement comes from the shared
  purchase controller (tier free). **Device-only items:** frame time and memory on D1/D2/D3 after
  ImplementationLock-100. **Owner-only items:** none.
- **Prerequisites not yet recorded (planned, specified and tasked, 2026-11-27):** R02-G21-04 (feature 504, in progress:
  its core parts — the view orbit, the picker, the gesture controller, the drawn-eye geometry, the materials 38 … 41
  and the snapshot additions — are committed, its panel and presenter work is not; the gate is not recorded),
  R02-G21-05 (feature 505: progress, modes, the state-derived tutorial, snapshot schema 2 and digest domain v2),
  R02-G21-06 (feature 506: announcements, haptics, eased lights, the Reduce Flashing glow cap) and R02-G21-07 (feature
  507: saves, replay and migration). None of 505, 506 or 507 is in code. This feature pins its baselines on the code
  those features leave, so it is implemented only after all four gates are recorded; where a requirement below names
  their parts, it names them as prerequisites.
- **Model:** feature 498 (the Mushroom Weather visual golden and solver regression, itself modelled on feature 488),
  adapted to two stars on quantized rings, phases, luminosities and tilt, the run of the light over 48 ticks, the
  garden worlds, their light gauges and the shown tick.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
498's answers where the games agree. Facts checked in committed code and specs (read-only, 2026-11-27):
`BinaryGardensSolver.plan(_:maxDepth:workBound:)` certifies a level by a breadth-first sweep over legal arrangement moves
(both stars' ring, phase and luminosity, then the tilt), judging every arrangement at depth 0, 1, 2 … in full below the
winning depth, and returns `actions`, `arrangement`, `arrangementsByDepth`, `nearestMiss`, `nearestMissArrangement` and
`work` (arrangements judged, the start and the winning one included), bounded by `workBound` = 5,000 and searched to
`maxDepth`, the band's plan length (1, 2, 3, 3, 4 for bands 1 … 5); the largest catalog work is 1,589 (level 81: 893);
`BinaryGardensSolver.replayWins` replays actions and the run through the kernel's play; the 100 witness files in
`docs/games/binary-gardens/levels/NNN.witness.json` (schema 1) hold the number, the level (budget, clamp radius,
difficulty, fingerprint, id, lethal tolerance, luminosity levels, maximum tilt, minimum separation, phase step, ring
radii, seed, star speed, the two stars with their ring, phase and luminosity and each one's freedom, start tilt,
tutorial, and the worlds with orbit radius, speed and phase, comfortable band, lethal bounds, bloom band and required
window), the actions (the plan, then `run`), the per-action state digests (`BinaryGardensWitness.digest(arrangement:
spent:)`), the fingerprints after `begin`, after `dismissTutorial` on a tutorial level (levels 1 … 3) and after each
action, the report, the counterexample (`depth` = size − 1, `arrangements`, `nearestMiss`, its `arrangement` and its
`failure`), the difficulty (including `work`) and the skipped candidate count; the catalog tests pin the catalog digest
(`adf594d6…401f`); the simulator frame checks of feature 503 draw at 1,152 × 768 with tick 24 shown, levels 1, 21, 41,
61 and 81 with the certified plan made, at tiers level-0 … level-2, and require, at every reference point at least 6 px
from what is drawn after it, each world's centre 0.15 brighter in luminance than the backdrop there and each star's
0.4, the first lit actions bar red above blue by 0.08, the first gauge plate's left margin 0.05 from the backdrop and
each 9 × 9 lower-corner patch median within 0.06 of the gradient; none of those five levels has a tilt dial (maximum
tilt 0); the first level with the full tilt range 0 … 3 is level 25; the palette `BinaryGardensPalette.all` has 27
named colours (`hex` holds the five registered values); `BinaryGardensMaterial` has 42 cases, codes 0 … 41
(`BinaryGardensShaders.maxMaterial` is `inspectBracket` = 41 since feature 504); the tiers differ only in cube-sphere
tessellation, corona rays, trails, motes and glow shells; the system scene's `release()` frees the system, glow and
fallback renderers, `liveObjectCount` counts them, and the presenter's `teardown` and `shedCaches` both call
`release()`; `ProcessMemory.footprint()` reads the footprint; the hero scenario plays level 1's certified plan without
the run and shows `BinaryGardensScenarios.heroTick`; the CI job `round02-host-tests` runs in halves a and b, half b's
filter already includes `BinaryGardens`, and half b carries one named regression step per game of its half (Mushroom
Weather's the latest).

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level (the manifest entry's certified candidate, built as the experience core builds
  it) equals its witness's level part by part and by fingerprint; the witness's actions replay on a fresh play (begun,
  the tutorial dismissed on a tutorial level) to a win on exactly the final `run` and not before (no proper prefix of
  the arrangement actions followed by `run` wins), within the budget, with exactly its per-action fingerprints, state
  digests and terminal report; and `plan` at the band's plan length returns exactly the witness's arrangement actions,
  with `arrangementsByDepth[size − 1]` equal to the counterexample's `arrangements`, `nearestMiss` and
  `nearestMissArrangement` equal to its `nearestMiss` and `arrangement`, and `work` at most `workBound` and equal to the
  witness difficulty's `work` (counted, never timed). The run is split into 10 tests of 10 levels, each well under
  10 s. Impact: FR-R02G2108-001; SC-R02G2108-001.
- Q: Which alterations must the regression detect and how is each named? → A: thirteen kinds, each applied to a copy of
  level 1 (band 1, tutorial), 41 (band 3) or 81 (band 5) and each producing a failure message naming the level and the
  part: a world's comfortable band, a world's lethal bound, a world's bloom band, a world's required window, a world's
  orbit (radius, speed or phase), a ring radius, a luminosity level, a star's starting ring, phase or luminosity, the
  lethal tolerance, the budget (each rebuilt through the level initialiser, the first copy the level rules accept and
  whose fingerprint changes; a refused construction is itself a failure naming the part); a plan action; a witness
  action, a per-action fingerprint or a per-action digest; the counterexample's arrangements count. The altered world
  and star are chosen from the fixed seed 2_508 (no random source). The unaltered input gives no failure. Mushroom
  Weather's twelve kinds are adapted to this level's parts; the star start is added because Binary Gardens has a
  movable start that Mushroom Weather does not. Impact: FR-R02G2108-002; SC-R02G2108-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: the golden set is
  17 frames: levels 1, 21, 41, 61 and 81 at tiers 0, 1 and 2 (the feature-503 frame-check levels), plus level 25 at
  tier 0 (the first level with a tilt dial over the full range, so the dial is pinned too), each after all of the
  witness's actions but before the `run` (actions spent from the actions bars, the predicted run the winning one, the
  level not yet won), with tick 24 shown (as the feature-503 frame checks send `clock.show [24]`), at presentation time
  0, the authored camera (view orbit at rest), no preview and no inspected world; plus the hero frame: the level the
  scenario manifest's hero scenario opens after its entries (the certified plan and the hero tick shown), tier 0. For
  each frame the Core computes, at 1,152 × 768: the projected pixel positions, rounded to 1/8 pixel (a point behind the
  eye is null), of the barycentre, every world's centre (world order), both stars' centres, the first gauge plate's
  left margin, the first actions bar and, when the level has a tilt dial, the first tilt pip; the counts of rings,
  rings a star stands on, worlds, worlds in each of the five bands at the shown tick (lethal low, dim, comfortable,
  bright, lethal high), gauge cells in each band over all worlds, short window brackets, lit and total tilt pips, lit
  and total luminosity pips, lit and total actions bars and broken elements; the shown tick, the tilt, each star's ring,
  phase and luminosity index, and each world's integral and longest comfortable window with its start; every palette
  colour of `BinaryGardensPalette.all` as 8-bit sRGB (27 today); and every material code with its palette constant
  name (42 today, codes 0 … 41). The palette and the material table are taken whole, so a colour or material added by a
  prerequisite is pinned with the rest. The whole is serialized as JSON with sorted keys and hashed with SHA-256. The 17
  descriptions and their digests live in `Packages/ExperiencesRound02/BinaryGardens/golden-frames.json`; the host test
  recomputes each: an equal digest passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned
  one and every count, value, colour and material entry must be equal, or the test fails naming the frame and the first
  differing value; each pinned digest must also equal the digest of its pinned description. The file is rewritten only
  when `BINARY_GARDENS_WRITE_GOLDEN=1` is set. The simulator test renders the 17 frames and checks each against the same
  description with the feature-503 tolerances. Impact: FR-R02G2108-003, 004; SC-R02G2108-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level:
  seed 0, level 1), draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is
  read with `ProcessMemory.footprint()` after each cycle; every reading of cycles 2 … 12 stays within 16 MB of cycle
  1's reading, applied only when the memory test class runs alone (`TEST_RUNNER_BINARY_GARDENS_MEMORY_ISOLATED=1`; in
  the full parallel suite the readings are only printed). After each close and each memory warning the system scene
  holds no GPU objects of its own (`liveObjectCount` is 0) and the next frame rebuilds them. An unavailable footprint
  fails with a named reason. Impact: FR-R02G2108-005; SC-R02G2108-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's `round02-host-tests` job keeps running all
  round-two host tests in its two halves and adds to half b a named step "Binary Gardens regression (host)" that runs
  the Binary Gardens regression filter alone; no new matrix half and no change to the halves' filters (half b already
  includes `BinaryGardens`). The local command `python3 scripts/binary_gardens_regression.py` runs the host regression
  filter and then the simulator regression test classes through `xcodebuild_package.py --only-testing` on `sim-27.2`,
  and prints one summary line per part with pass or fail and the first failing name; its exit code is non-zero on any
  failure; `--dry-run` prints the commands and `--skip-simulator` runs the host part only. Nothing is timed against the
  wall clock. Impact: FR-R02G2108-006, 007; SC-R02G2108-005.
- Q: When may the golden baseline be pinned, given that features 504 … 507 are not recorded? → A: only after the gates
  R02-G21-04, 05, 06 and 07 are recorded in the migration ledger; the solver regression may be written earlier because
  the solver, the levels and the witnesses are fixed since R02-G21-02 and none of the prerequisites changes them, but
  the gate is recorded only after the whole feature runs on the code of all four. Impact: FR-R02G2108-009;
  SC-R02G2108-006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can still be won — every garden world kept in its light across a
full cycle by the stars' rings, phases, luminosities and tilt within the budget, then the run — and that the certified
actions are still the fewest that do it, after any change to the code.

**Why this priority**: an unwinnable level, or a level whose certified solution is no longer the shortest, is the
worst failure a puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the certifying search on each
level; any difference from the certified solution fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win on exactly its final run and the search finds exactly the certified actions, with the same count of
   arrangements judged at the depth below and the same nearest miss, within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The starfield backdrop, the tilt dial, the dashed and lit rings, the world orbits, the cube-sphere garden worlds with
their bands, the two stars with their luminosity pips, the light gauges with their cells, guides, window brackets and
bloom meters, and the actions bars the player sees stay where the rules say they are and in the palette, at every
quality tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a star, world, band or gauge cell drawn in the wrong place or colour misleads the player about
the light.

**Independent Test**: for a fixed set of golden frames (levels, tiers and shown ticks), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-503 tolerances.
2. **Given** a change to the scene geometry, palette, material table or camera, **When** the regression runs, **Then**
   the pinned digest no longer matches and the regression fails until the baseline is regenerated on purpose.

### User Story 3 - Memory stays bounded (Priority: P2)

A player who opens and closes the game many times, or plays a long session, does not see the app grow until the system
ends it.

**Independent Test**: on the simulator, opening, drawing and closing the experience repeatedly and receiving memory
warnings keeps the app's memory footprint within 16 MB of the first cycle and releases the game's GPU objects.

**Acceptance Scenarios**:

1. **Given** 12 open-draw-warn-close cycles, **When** the footprint is read after each, **Then** every reading after the
   first stays within the bound of the first, and no GPU object of the game remains after a close or a warning.

### User Story 4 - The checks run on every change (Priority: P2)

The project's continuous integration runs the host part of the regression on every push, and one documented local
command runs the whole regression, so a regression is caught before a gate is recorded.

**Independent Test**: the workflow runs the solver and golden-description checks; the local command runs host and
simulator parts and reports one summary.

**Acceptance Scenarios**:

1. **Given** a push, **When** the workflow runs, **Then** a named Binary Gardens regression step runs and passes.
2. **Given** the local command, **When** it runs, **Then** it prints one line per part with pass or fail and exits
   non-zero on any failure.

### Edge Cases

- **A baseline that must change on purpose** (a deliberate visual change): regenerating it is an explicit step with an
  environment switch, never automatic, and the new digest is committed with the change.
- **A search that would exceed its bound:** the check fails with the level number instead of hanging; the bound is
  5,000 arrangements judged, more than three times the largest catalog search.
- **The deepest levels:** the band-5 searches are the most expensive, so the solver part runs in groups of 10 levels
  and every test stays under 10 seconds.
- **Tutorial levels (1 … 3):** the replay dismisses the tutorial after `begin`, and the fingerprint after
  `dismissTutorial` is checked as stored.
- **Frames at a tier whose detail differs:** each tier has its own description; positions and counts shared by all
  tiers are checked against the same reference, and the tier-only parts (tessellation, coronas, trails, motes, glow)
  are not described.
- **A level without a tilt dial:** the first tilt pip's position is null and its counts are 0; level 25 keeps the dial
  in the golden set.
- **A prerequisite that adds a colour or material:** the palette and material table enter the description whole, so
  the addition is pinned when the baseline is regenerated after that prerequisite is recorded.
- **Memory measurement noise:** the bound applies after a warm-up cycle, not to a single sample.
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (arrangements
  judged), not seconds.
- **A missing, unreadable or incomplete golden manifest:** the regression fails naming the file and the frame; it is
  never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size; other aspects and the iPhone
  and iPad panel layouts stay covered by the R02-G21-03, R02-G21-04 and R02-G21-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2108-001**: The regression MUST replay every certified level's witness to a win on exactly its final run,
  with its stored per-action fingerprints, digests and report, and MUST re-run the certifying search on every level,
  requiring the certified actions, the recorded count of arrangements judged at the depth below the plan, the recorded
  nearest miss and its arrangement, and the recorded work, within the search's work bound.
- **FR-R02G2108-002**: An altered level, plan or witness MUST make the regression fail, naming the level and the
  differing part, for each of the thirteen kinds of alteration listed in the clarifications.
- **FR-R02G2108-003**: A golden set of 17 frames (levels, tiers, shown ticks, including the tilt-dial frame and the hero
  frame) MUST have a code-computed description (projected positions of the barycentre, every world's centre, both
  stars' centres, the first gauge plate's left margin, the first actions bar and the first tilt pip; the counts of
  rings, rings with a star, worlds, worlds and gauge cells per band, short window brackets, lit and total tilt pips,
  luminosity pips and actions bars and broken elements; the shown tick, the tilt, the stars' controls and each world's
  integral and window; every palette colour; every material code with its constant name) pinned in the repository with
  its digest; a recomputed description matches when its digest is equal or every position lies within one 1/8-pixel
  quantum and every other value is equal.
- **FR-R02G2108-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  feature-503 tolerances; regenerating a baseline MUST need the explicit switch `BINARY_GARDENS_WRITE_GOLDEN=1`.
- **FR-R02G2108-005**: Repeatedly opening, drawing and closing the experience with memory warnings MUST keep the
  footprint growth within 16 MB of the first cycle and MUST release the game's GPU objects after each close and each
  warning.
- **FR-R02G2108-006**: The continuous-integration workflow MUST run the host part of the regression on every push in a
  named step; one documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G2108-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each
  test under 10 seconds), and MUST NOT change the game's rules, levels, witnesses or state.
- **FR-R02G2108-008**: Existing tests MUST pass unchanged; new public names are documented with `///`; the reference
  regression passes.
- **FR-R02G2108-009**: The golden baseline MUST be generated, and the gate recorded, only after the gates R02-G21-04,
  05, 06 and 07 are recorded in the migration ledger.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified plan and its witness file.
- **Golden frame**: a level, a tier, a shown tick, a frame time and a size, with its code-computed description and
  digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on
  purpose.
- **Memory cycle**: one open, draw, warn and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2108-001**: All 100 levels replay their witnesses and re-plan to their certified actions within the search's
  work bound; 100 of 100.
- **SC-R02G2108-002**: Each of the 13 kinds of alteration listed in the clarifications is detected and named; 13 of 13
  on each of levels 1, 41 and 81.
- **SC-R02G2108-003**: The golden set covers 5 levels × 3 tiers plus the tilt-dial frame and the hero frame (17
  frames); every rendered frame matches its description within tolerance and every recomputed description matches its
  pinned entry; 17 of 17.
- **SC-R02G2108-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G2108-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary line per part and an overall line.
- **SC-R02G2108-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the ledger shows R02-G21-04 … 07 recorded before R02-G21-08.
- **SC-R02G2108-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on
  D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 502 and the renderer and CPU reference of feature 503 (with the
  drawn-eye geometry and materials of feature 504) are the sources of truth; this feature adds checks, not rules.
- Features 505, 506 and 507 do not change the levels, witnesses, solver or scene positions; if one changes the palette,
  the material table or the snapshot the description reads, the baseline taken after its gate is recorded includes the
  change.
- The memory bound is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G21-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G2108-001, 002 |
| Screenshot baselines (code-only) | FR-R02G2108-003, 004 |
| Memory checks | FR-R02G2108-005 |
| CI | FR-R02G2108-006 |
| Deterministic tests, error handling, observability | FR-R02G2108-002, 007 |
| Prerequisites (R02-G21-04 … 07) | FR-R02G2108-009 |
| Accessibility, copyright/originality | unchanged from R02-G21-06 and R02-G21-03 (code-only visuals) |
| Schema migration | none: the golden manifest has schema 1; saves stay with R02-G21-07 |
| Excluded scope | device measurements (SC-R02G2108-007), price, per-game app |
