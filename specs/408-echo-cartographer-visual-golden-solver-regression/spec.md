# Feature Specification: R02-G11-08 — Echo Cartographer: visual golden and solver regression

**Feature Branch**: `408-echo-cartographer-visual-golden-solver-regression` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

**Ledger gate**: R02-G11-08 (migration ledger, game feature of experience R02-G11) · ID namespace FR-R02G1108-###,
SC-R02G1108-###, T-R02G1108-###

**Input**: User description: the archived R02-G11-08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Execute CPU solver fixtures, screenshot baselines, memory checks and CI" for Echo Cartographer, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/408-echo-cartographer-visual-golden-solver-regression`; FR-R02G1108-###,
  SC-R02G1108-###, T-R02G1108-###.
- **Packaging (ADR-0009):** experience R02-G11 (`r02-g11.echo-cartographer`, free; a registered candidate) in
  `Packages/ExperiencesRound02/EchoCartographer`; no app target, bundle identifier or store listing.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock, the per-round device campaign and the
  "content count 90" milestone figure. **Device-only items:** frame time and memory on D1/D2/D3 after
  ImplementationLock-100. **Owner-only items:** none.
- **Model:** feature 398 (Backwards Aurora's visual golden and solver regression).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every level stays solvable as certified (Priority: P1) 🎯

A player can trust that every one of the 100 levels can be won within its energy and that the certified pulse plan
still singles out the beacons, after any change to the code.

**Why this priority**: an unwinnable level or a level whose echoes no longer pin the beacons down is the worst failure a
deduction puzzle can ship.

**Independent Test**: the regression replays each level's stored witness and re-runs the certifying solver on each
level; any difference from the certified plan fails with the level number.

**Acceptance Scenarios**:

1. **Given** the 100 certified levels and their witness files, **When** the regression runs, **Then** each witness
   replays to a win in exactly its recorded actions and the solver finds exactly the certified pulse plan within its
   work bound.
2. **Given** a level or witness that was altered, **When** the regression runs, **Then** it fails and names the level
   and the part that differs.

### User Story 2 - The picture does not drift (Priority: P1)

The opal floor tiles of known open cells, the dark wall blocks with their mint edges, the entry diamond, the marker
rings, the located beacon pillars, the last pulse's rays and the energy gauge the player sees stay where the rules say
they are and in the palette, at every quality tier, so a later visual change cannot silently move or recolour them.

**Why this priority**: a wall or tile drawn in the wrong place misleads the player about the chamber.

**Independent Test**: for a fixed set of golden frames (levels, tiers and frame times), the code computes the expected
frame description; its digest equals the pinned digest, and the simulator's rendered frame matches the description
within stated tolerances.

**Acceptance Scenarios**:

1. **Given** the golden set, **When** frames are rendered on the simulator, **Then** every frame matches its CPU
   description within the feature-403 tolerances.
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
- **A slower CI runner:** no wall-clock assertion runs on CI; time bounds are counted in solver work (enumeration
  nodes), not seconds.
- **A missing, unreadable or incomplete golden manifest:** the regression fails naming the file and the frame; it is
  never regenerated without the explicit switch.
- **Layout and aspect:** this feature changes no interface. Golden frames use one size; the other aspects and the iPhone
  and iPad panel layouts stay covered by the R02-G11-03 and R02-G11-06 tests.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1108-001**: The regression MUST replay every certified level's witness to a win in exactly its recorded
  actions and MUST re-plan every level, requiring the certified pulse plan within the solver's work bound.
- **FR-R02G1108-002**: An altered level, plan or witness MUST make the regression fail, naming the level and the
  differing part.
- **FR-R02G1108-003**: A golden set of frames (levels, tiers, frame times, including the hero frame) MUST have a
  code-computed description (projected cell centres of the known open tiles, the known walls, the markers and the
  located beacons, the entry, the gauge's lit and total bars, palette colours) pinned in the repository with its digest;
  a recomputed description matches when its digest is equal or every position lies within one 1/8-pixel quantum and
  every count and colour is equal.
- **FR-R02G1108-004**: Rendered frames of the golden set on the simulator MUST match their descriptions within the
  tolerances of User Story 2; regenerating a baseline MUST need an explicit switch.
- **FR-R02G1108-005**: Repeatedly opening, drawing, closing the experience and memory warnings MUST keep the footprint
  growth within a stated bound and MUST release the game's GPU objects.
- **FR-R02G1108-006**: The continuous-integration workflow MUST run the host part of the regression on every push; one
  documented local command MUST run the host and simulator parts with one summary.
- **FR-R02G1108-007**: The regression MUST be deterministic (fixed seeds, no clock, no random source) and short (each
  test under 10 seconds), and MUST NOT change the game's rules, levels or state.
- **FR-R02G1108-008**: Existing tests MUST pass unchanged; new public names are documented; the reference regression
  passes.

### Key Entities

- **Solver fixture**: a certified level, its manifest entry, its certified pulse plan and its witness file.
- **Golden frame**: a level, a tier, a frame time and a size, with its code-computed description and digest.
- **Golden manifest**: the list of golden frames with their pinned descriptions and digests, regenerated only on
  purpose.
- **Memory cycle**: one open, draw and close of the experience with the footprint measured after it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1108-001**: All 100 levels replay their witnesses and re-plan to their certified pulses within the solver's
  work bound; 100 of 100.
- **SC-R02G1108-002**: Each kind of alteration named by the clarification is detected and named.
- **SC-R02G1108-003**: The golden set covers 5 levels × 3 tiers plus the hero frame (16 frames); every rendered frame
  matches its description within tolerance and every recomputed description matches its pinned entry.
- **SC-R02G1108-004**: Over 12 open-draw-warn-close cycles, the footprint stays within the stated bound of the first
  cycle's reading, and the game's GPU objects are released after each close and each memory warning.
- **SC-R02G1108-005**: The workflow runs the host part on every push and passes; the local command runs all parts and
  prints one summary.
- **SC-R02G1108-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds.
- **SC-R02G1108-007** {device}: after ImplementationLock-100, frame time and memory at each tier are recorded on
  D1/D2/D3.

## Assumptions

- The 100 levels, witnesses and solver of feature 402 and the renderer and CPU reference of feature 403 are the sources
  of truth; this feature adds checks, not rules.
- The memory bound is a conservative simulator bound; device bounds come from the device campaign.
- Golden descriptions are compared with tolerances because GPU rasterization differs slightly between simulators.

## Traceability

| Source item (round2.md R2-G11-08) | Requirement |
|---|---|
| CPU solver fixtures | FR-R02G1108-001, 002 |
| Screenshot baselines (code-only) | FR-R02G1108-003, 004 |
| Memory checks | FR-R02G1108-005 |
| CI | FR-R02G1108-006 |
| Deterministic tests, error handling, observability | FR-R02G1108-002, 007 |
| Accessibility, copyright/originality | unchanged from R02-G11-06 and R02-G11-03 (code-only visuals) |
| Excluded scope | device measurements (SC-R02G1108-007), price, per-game app |
