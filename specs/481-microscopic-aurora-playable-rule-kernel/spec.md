# Feature Specification: R02-G19-01 — Microscopic Aurora: playable rule kernel

**Feature Branch**: `481-microscopic-aurora-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Draft

**Ledger gate**: R02-G19-01 (migration ledger, game feature of experience R02-G19) · ID namespace FR-R02G1901-###,
SC-R02G1901-###, T-R02G1901-###

**Input**: User description: the archived R02-G19-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Microscopic Aurora, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/481-microscopic-aurora-playable-rule-kernel`; FR-R02G1901-###,
  SC-R02G1901-###, T-R02G1901-###.
- **Packaging (ADR-0009):** Microscopic Aurora is experience R02-G19 (`r02-g19.microscopic-aurora`, free) inside the
  single VisualCore app. The source's `Apps/MicroscopicAurora` and `Packages/GameModules/MicroscopicAuroraCore` become
  the experience module `Packages/ExperiencesRound02/MicroscopicAurora`; this feature adds its pure Core with tests.
  Catalog registration, adapter and renderer come in later features of R02-G19 and its gate X-R02-G19.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 82 (the catalog's "82
  solver-certified stages") is a milestone inside the levels of R02-G19-02. **Device-only items:** none (pure logic).
  **Owner-only items:** none.
- **Exactness:** the source's law (swimmers steered by bounded separation, alignment and cohesion accelerations plus
  the curl field of magnetic wells, integrated with a fixed step) is evaluated in deterministic integer arithmetic on
  integer positions and velocities, so every device computes the same swim bit for bit; every rule (the trail density
  in each dish cell, the target stencil's coverage and connectedness, leaving the enclosure, the swarm's coherence) is
  then decided exactly on those integers. The catalog's 0.008333 s timestep is the presentation clock of later
  features; the kernel counts ticks and never reads a clock.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G19-02 can certify levels).
- **Model:** feature 471 (Apsides Workshop's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Steer the swimmers so their glowing trails draw the pattern (Priority: P1) 🎯

A player sees a round dish under a microscope with a small swarm of luminous swimmers and a faint target pattern (a
stencil of dish cells). The player places up to three magnetic wells, each with a strength and a turning sense, then
releases the swarm for one swim: the swimmers keep together by separation, alignment and cohesion and curl around the
wells, leaving glowing trails. When the trails cover enough of the stencil, as one connected pattern, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known placement of wells wins when the swim is played; after every
action the predicted swim, trail density, coverage and outcome equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known wells, **When** they are placed and the swim is played, **Then** the level is won.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - The swarm escapes, breaks apart, or misses the pattern (Priority: P1)

Playing the swim fails the level when a swimmer leaves the enclosure, when the swarm loses its required coherence (it
splits into groups too small), when the trails cover too little of the stencil, or when the covered stencil cells do
not form one connected pattern. Each failure names its reason, the swimmer or cell and the tick; the player can undo
the play and move the wells again.

**Independent Test**: scripted sequences end failed with the named reason on the play.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A well placed outside the dish, on another well or with a strength out of range:** refused without cost.
- **A placement equal to the current one:** refused without cost.
- **A swimmer exactly on the enclosure's rim:** still inside; leaving needs a strictly greater distance.
- **Two swimmers at the same point:** separation has a fixed, defined direction, so the swim stays deterministic.
- **A cell's trail density exactly at the threshold:** the cell counts as lit.
- **Coverage exactly at the required share:** met.
- **No well placed:** the swarm swims by its own rules; a valid play.
- **The action budget spent:** further placements are refused, playing is still allowed.
- **A level already solved at load:** never accepted; every level needs at least one action to win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1901-001**: A level MUST define the dish (its cells and the round enclosure), the swarm (each swimmer's
  starting position and velocity), the swim's length in ticks, the swarm rules' strengths and radii, the target
  stencil (a set of dish cells), the trail threshold, the required coverage and connectedness, the required coherence,
  the starting wells, the action budget and whether it shows a tutorial. A level is refused when a value is out of
  range, a swimmer starts outside the enclosure, a stencil cell lies outside it, the stencil is empty, or the starting
  wells already win.
- **FR-R02G1901-002**: A magnetic well MUST be given by its dish position, its strength and its turning sense, each
  chosen from fixed steps; at most three wells exist, never two on the same position, never outside the enclosure.
- **FR-R02G1901-003**: Every tick of the swim MUST move every swimmer by a fixed-step integration of bounded
  separation, alignment and cohesion accelerations from its neighbours plus the curl acceleration of every well,
  with speed bounded, computed deterministically in a fixed swimmer order so every device gets the same positions.
- **FR-R02G1901-004**: The trail density of every dish cell MUST be counted over the swim (the ticks swimmers spend in
  it), and a cell is lit when its density reaches the level's threshold.
- **FR-R02G1901-005**: Playing the swim MUST end the level: won exactly when no swimmer leaves the enclosure, the swarm
  keeps its required coherence at every tick, the lit stencil cells reach the required coverage and form one connected
  pattern; otherwise failed with the reason (exit, coherence, coverage, connectedness), the swimmer or cell and the
  tick.
- **FR-R02G1901-006**: An action MUST place, move or remove a well (or change its strength or sense) and spend one
  action; every action MUST be validated (ranges, positions, stage, budget, previous fingerprint) and refused without
  change when invalid.
- **FR-R02G1901-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1901-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1901-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1901-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1901-011**: Invalid requests MUST be refused with stable reason codes `r02-g19.*`; existing modules
  unchanged.
- **FR-R02G1901-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1901-013**: Every well, cell, swimmer and measure MUST be identifiable without colour vision: the kernel
  names them in words (well numbers and positions, coverage in percent, cells by row and column, ticks, actions left).
- **FR-R02G1901-014**: The truth metric MUST be computed exactly and reported after every action: the swarm density
  distribution (trail density per cell, lit cells) and the pattern connectivity (coverage of the stencil, the largest
  connected group of lit stencil cells, the swarm's smallest coherence over the swim), with the first failure and the
  predicted outcome.

### Key Entities

- **Level**: dish, swarm, swim length, swarm rules, stencil, thresholds, starting wells, budget, tutorial flag,
  fingerprint.
- **Swimmer**: position, velocity (integers).
- **Magnetic well**: position, strength, turning sense.
- **Swim report**: positions by tick, trail density per cell, lit cells, coverage, connected groups, coherence by
  tick, first exit, first failure, outcome.
- **Action**: place well, move well, remove well, play, undo, redo.
- **Play**: stage, wells, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1901-001**: For 500 seeded constructed levels the known wells win and every refused action is refused with
  its named reason.
- **SC-R02G1901-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1901-003**: Over 500 seeded swims, every position, trail density, lit cell, coverage, connected group,
  coherence and outcome equals an independent computation.
- **SC-R02G1901-004**: Failure happens on the play with the reason named, including a coverage one cell either side of
  the requirement, a density one tick either side of the threshold, a swimmer one unit inside and outside the rim and
  a coherence one swimmer either side of the requirement.
- **SC-R02G1901-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1901-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Drag up to three magnetic wells" is the placement actions; "scrub speed" is the presentation speed of the swim and
  "tap freeze field" pauses its preview (both presentation only, later features); playing the swim is the play action.
- "Trailing density occupies target stencil with sufficient connectedness" is the coverage and connectedness rule of
  FR-R02G1901-005; "destroys required coherence" is the coherence rule.
- "Swarm density distribution and pattern connectivity" is the exact truth metric of FR-R02G1901-014.
- Levels and their certification (field strength search with the seeded simulator and shape loss) come in R02-G19-02;
  drawing in R02-G19-03; gestures in R02-G19-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (wells, play, budget) | FR-R02G1901-002, 006, 007, 008 |
| Bounded separation, alignment, cohesion plus magnetic curl field; fixed-step integration | FR-R02G1901-003 |
| Trail density | FR-R02G1901-004 |
| Exact win/failure evaluation (stencil coverage, connectedness, enclosure, coherence) | FR-R02G1901-005 |
| Truth metric: swarm density distribution and pattern connectivity | FR-R02G1901-014; SC-R02G1901-003 |
| Puzzle contract for certification | FR-R02G1901-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G19-02; INV-11 is superseded by the free tier) | FR-R02G1901-012 |
| Accessibility (colour independence) | FR-R02G1901-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no platform floating point in the rules; no device run before ImplementationLock-100.
