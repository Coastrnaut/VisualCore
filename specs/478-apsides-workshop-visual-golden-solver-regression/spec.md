# Feature Specification: R02-G18-08 — Apsides Workshop: visual golden and solver regression

**Feature Branch**: `478-apsides-workshop-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G18-08 (migration ledger, game feature of experience R02-G18) · ID namespace FR-R02G1808-###,
SC-R02G1808-###, T-R02G1808-###

**Input**: User description: the archived R02-G18-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Apsides Workshop, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/478-apsides-workshop-visual-golden-solver-regression`; FR-R02G1808-###,
  SC-R02G1808-###, T-R02G1808-###.
- **Packaging (ADR-0009):** experience R02-G18 (`r02-g18.apsides-workshop`, free; a registered candidate) in
  `Packages/ExperiencesRound02/ApsidesWorkshop`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 78" milestone figure (the catalog has 100 certified levels). **Device-only items:** frame time and
  memory on D1/D2/D3 after ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 468 (Celestial Eclipse Lab's visual golden and solver regression), adapted to orbit tunings, the
  play of the revolution, the cosmic compass and the luminous orbit loops.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
468's answers where the games agree. Facts checked in code (read-only, 2026-11-26): `ApsidesWorkshopSolver.plan`
certifies a level by a search by number of tunings from its starting orbit, returning `actions` (the tunings), `orbit`
(the winning orbit), `orbitsByDepth` (orbits judged per number of tunings) and `work`, within at most 2 tunings
(`maxTunings`) and 16,000 orbits judged (`workBound`); the 100 witness files in `docs/games/apsides-workshop/levels/`
hold the number, the level (period, planets with centre and radius, targets with kind, sector and band, starting
orbit, budget, tutorial, fingerprint), the actions (the plan's tunings, then the play that wins), the per-action
digests, the fingerprints after `begin`, after `dismissTutorial` on a tutorial level and after each action, the report
(shares, apsides, deviations, met count), the counterexample (`depth` = size − 1 and `orbits`), the difficulty and the
skipped candidate count, byte-checked by the catalog tests with the catalog digest pinned; the simulator frame checks
of feature 473 compare rendered frames with the CPU reference (the star's and the orbiter's centres brighter than the
backdrop by 0.25 in luminance, the first lit actions bar with red above blue by 0.08, the first gauge track's centre 0.1
from the backdrop, each point at least 6 px from what is drawn after it, the backdrop patches within 0.06 of the
gradient) at 1,152 × 768; the palette has 18 named colours (the 19th constant is a hex list);
`ApsidesWorkshopCompassScene.release()` frees every renderer, the next draw rebuilds them and `liveObjectCount` counts
them; `ProcessMemory.footprint()` reads the footprint; the CI job `round02-host-tests` has a named regression step per
earlier round-two game (Celestial Eclipse Lab's the latest).

- Q: What exactly does the solver regression check, and how is "within its work bound" measured? → A: for every one of
  the 100 levels: the generated level equals its witness's level (fingerprint); the witness's actions replay on a fresh
  play to a win on exactly the final play and not before, within the budget, with exactly its per-action fingerprints
  and digests; and `plan` returns exactly the witness's tunings with `orbitsByDepth[size − 1]` equal to the
  counterexample's `orbits` at depth size − 1; `work` is at most `workBound` (counted, never timed). The run is split
  into tests of 10 levels (10 tests), each well under 10 s. Impact: FR-R02G1808-001; SC-R02G1808-001.
- Q: Which alterations must the regression detect and how is each named? → A: twelve kinds, each applied to a copy and
  each producing a failure message naming the level and the part: a planet's centre, a planet's radius, a target's kind,
  a target's sector, a target's band, the starting orbit, the period, the budget; a plan tuning; a witness action, a
  per-action fingerprint or digest; the counterexample's orbits count. Impact: FR-R02G1808-002; SC-R02G1808-002.
- Q: What is a golden frame description, where is its digest pinned, and how is it regenerated? → A: for each golden
  frame (levels 1, 21, 41, 61, 81 at tiers 0, 1, 2, each after all of the witness's tunings but before the play, so
  actions are spent from the actions bars and the level is not yet won, shown at tick T / 2 (the period halved, as the
  feature-473 frame checks), at presentation time 0, the authored camera and no preview, plus the hero frame of the
  scenario manifest's hero scenario at tier 0: 16 frames) the Core computes, at 1,152 × 768, the projected pixel
  positions of the star, the orbiter at the shown tick, the periapsis and apoapsis markers, every planet and the first
  actions bar, rounded to 1/8 pixel, the counts of sectors, swept-area wedges, orbit-loop points, planets, gauges, met
  gauges, lit and total actions bars, and the 18 palette colours as 8-bit sRGB; serialized as JSON with sorted keys and
  hashed with SHA-256. The 16 descriptions and their digests live in
  `Packages/ExperiencesRound02/ApsidesWorkshop/golden-frames.json`; the host test recomputes each: an equal digest
  passes; otherwise every position must lie within one 1/8-pixel quantum of the pinned one and every count and colour
  must be equal, or the test fails naming the frame and the first differing value; each pinned digest must also equal
  the digest of its pinned description. The file is rewritten only when `APSIDES_WORKSHOP_WRITE_GOLDEN=1` is set. The
  simulator test renders the 16 frames and checks them against the same descriptions with the feature-473 tolerances.
  Impact: FR-R02G1808-003, 004; SC-R02G1808-003.
- Q: How is memory measured and what releases are checked? → A: on the simulator, 12 cycles of open (prepare a level),
  draw 3 frames at tier 0, send a memory warning, draw 1 frame, close (teardown); the footprint is read with
  `ProcessMemory.footprint()` after each cycle; every reading of cycles 2 … 12 stays within 16 MB of cycle 1's reading,
  applied only when the memory test class runs alone (`TEST_RUNNER_APSIDES_WORKSHOP_MEMORY_ISOLATED=1`; in the full
  parallel suite the readings are only printed). After each close and each memory warning the scene holds no GPU objects
  of its own (`liveObjectCount` is 0) and the next frame rebuilds them. An unavailable footprint fails with a named
  reason. Impact: FR-R02G1808-005; SC-R02G1808-004.
- Q: How do CI and the local command report, and what do they run? → A: CI's `round02-host-tests` job keeps running all
  round-two host tests and adds a named step "Apsides Workshop regression (host)" that runs the Apsides Workshop
  regression filter alone. The local command `python3 scripts/apsides_workshop_regression.py` runs the host regression
  filter and then the simulator regression test classes through `xcodebuild_package.py --only-testing`, and prints one
  summary line per part with pass or fail and the first failing name; its exit code is non-zero on any failure. Nothing
  is timed against the wall clock. Impact: FR-R02G1808-006, 007; SC-R02G1808-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can still be won — its targets met in order by tunings of the
periapsis knob and the size within the budget, then the play — and that the certified tunings are still the fewest
that do it, after any change to the code.

**Why this priority**: an unwinnable level, or a level whose certified solution is no longer the shortest, is the
worst failure an orbit puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the certifying search on each
level; any difference from the certified solution fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win on exactly its final play and the search finds exactly the certified tunings, with the same
   count of orbits judged one tuning short, within its work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The cosmic compass of eight sky sectors around the star, the glacial orbit loop with its ghost loop and swept-area
wedges, the apsis markers, the hatched planets, the orbiter, the target gauges and the actions bars the player sees stay
where the rules say they are and in the palette, at every quality tier, so a later visual change cannot silently move or
recolour them.

**Why this priority**: an orbit, apsis or gauge drawn in the wrong place or colour misleads the player about the
targets.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-473 tolerances.
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

1. **Given** a push, **When** the workflow runs, **Then** a named Apsides Workshop regression step runs and passes.
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
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (orbits judged),
  not seconds.
- **A missing, unreadable or incomplete golden manifest:** the regression fails naming the file and the frame; it is
  never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size; other aspects and the iPhone
  and iPad panel layouts stay covered by the R02-G18-03 and R02-G18-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1808-001**: The regression MUST replay every certified level's witness to a win on exactly its final play
  and MUST re-run the certifying search on every level, requiring the certified tunings and the recorded count of orbits
  judged one tuning short within the search's work bound.
- **FR-R02G1808-002**: An altered level, plan or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G1808-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected positions of the star, the orbiter, the apsis markers, the planets and the first
  actions bar, the counts of sectors, wedges, orbit points, planets, gauges, met gauges and lit and total actions bars,
  the 18 palette colours) pinned in the repository with its digest; a recomputed description
  matches when its digest is equal or every position lies within one 1/8-pixel quantum and every count and colour is
  equal.
- **FR-R02G1808-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G1808-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within 16 MB of the first cycle and MUST release the game's GPU objects.
- **FR-R02G1808-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G1808-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each
  test under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G1808-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified plan and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on
  purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1808-001**: All 100 levels replay their witnesses and re-plan to their certified tunings within the
  search's work bound; 100 of 100.
- **SC-R02G1808-002**: Each kind of alteration listed in the clarifications is detected and named.
- **SC-R02G1808-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry.
- **SC-R02G1808-004**: Over 12 open-draw-warn-close cycles, every footprint reading of cycles 2 … 12 stays within 16 MB
  of cycle 1's, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G1808-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G1808-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds.
- **SC-R02G1808-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on
  D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 472 and the renderer and CPU reference of feature 473 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G18-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G1808-001, 002 |
| Screenshot baselines (code-only) | FR-R02G1808-003, 004 |
| Memory checks | FR-R02G1808-005 |
| CI | FR-R02G1808-006 |
| Deterministic tests, error handling, observability | FR-R02G1808-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G18-06 and R02-G18-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G1808-007), price, per-game app |
