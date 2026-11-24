# Feature Specification: R02-G16-01 — Starlit Cartouche: playable rule kernel

**Feature Branch**: `451-starlit-cartouche-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Draft

**Ledger gate**: R02-G16-01 (migration ledger, game feature of experience R02-G16) · ID namespace FR-R02G1601-###,
SC-R02G1601-###, T-R02G1601-###

**Input**: User description: the archived R02-G16-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Starlit Cartouche, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/451-starlit-cartouche-playable-rule-kernel`; FR-R02G1601-###, SC-R02G1601-###,
  T-R02G1601-###.
- **Packaging (ADR-0009):** Starlit Cartouche is experience R02-G16 (`r02-g16.starlit-cartouche`, free) inside the
  single VisualCore app. The source's `Apps/StarlitCartouche` and `Packages/GameModules/StarlitCartoucheCore` become
  the experience module `Packages/ExperiencesRound02/StarlitCartouche`; this feature adds its pure Core with tests.
  Catalog registration, adapter and renderer come in later features of R02-G16 and its gate X-R02-G16.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 80 (the catalog's "80
  solver-certified stages") is a milestone inside the levels of R02-G16-02. **Device-only items:** none (pure logic).
  **Owner-only items:** none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic on beats (one launch tick), star lattice
  positions and glyph points, so every device decides the same; the catalog's 0.008333 s timestep is the presentation
  clock of later features (30 presentation ticks per beat) and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G16-02 can certify levels).
- **Model:** feature 441 (Voxel Origami's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fly a route that draws the cartouche (Priority: P1) 🎯

A player sees a chart of stars drifting on their orbits, the corridors between them, and beside it an ancient symbol
(the cartouche) drawn as strokes between the stars' glyph points. The ship waits at a star and launches along a
corridor to another star; each leg draws its stroke in light. When the trail has drawn exactly the strokes of the
symbol and the ship rests at the final beacon in time, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of legs wins on its last leg; after every action the
ship's star and beat, the drawn strokes and the closeness to the symbol equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known legs, **When** they are applied, **Then** the level is won exactly on the last one.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - A leg crosses a hazard, misses a window, strays or runs out of time (Priority: P1)

A leg fails the level when it travels a corridor while a hazard tube lies across it, leaves its star after that star's
time window closes or arrives outside the destination's window, draws a stroke that is not part of the symbol, or
arrives after the level's deadline; using up the action budget without a win fails the level too. Each failure names
its reason, the leg and the stars, corridor or beat where it applies; the player can undo the failing leg and try again.

**Independent Test**: scripted sequences end failed with the named reason on the exact action.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **An unknown star, a star with no corridor from the ship's star, a wait outside the allowed range, a corridor whose
  stars are out of range at the departure beat:** refused without cost.
- **A leg arriving exactly on a window's opening or closing beat, or exactly on the deadline:** allowed.
- **A hazard interval that ends one beat before the leg departs, or starts one beat after it arrives:** clear.
- **Retracing a stroke of the symbol:** allowed; the stroke is drawn once.
- **The last action of the budget:** a leg on it can still win; any other last action without a win fails the level.
- **A level already solved at load:** never accepted; every level needs at least one leg to win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1601-001**: A level MUST define its stars (each with a periodic orbit of lattice positions and a glyph
  point), the corridors between stars with their travel times, the range within which a corridor can be flown, each
  star's time window, the hazard tubes (a corridor and the beats it is blocked), the start star, the beacon star, the
  deadline, the symbol's strokes, the action budget and whether it shows a tutorial.
- **FR-R02G1601-002**: A leg MUST move the ship from its star along a corridor to another star, departing after a chosen
  wait and arriving after the corridor's travel time, computed exactly in beats; it MUST be flyable only when the two
  stars are within range at the departure beat.
- **FR-R02G1601-003**: A leg MUST fail the level when it departs after its star's window closes, travels a corridor
  while a hazard tube lies across it, arrives outside the destination's window, draws a stroke outside the symbol or
  arrives after the deadline, naming the reason, the leg, the stars and the beat or corridor.
- **FR-R02G1601-004**: Every leg MUST spend one action; the level MUST be won exactly when, after an accepted leg, the
  drawn strokes equal the symbol's strokes and the ship is at the beacon.
- **FR-R02G1601-005**: Using up the budget without a win MUST fail the level with a named reason.
- **FR-R02G1601-006**: Every action MUST be validated (star, wait, range, stage, previous fingerprint) and refused
  without change when invalid.
- **FR-R02G1601-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1601-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1601-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1601-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1601-011**: Invalid requests MUST be refused with stable reason codes `r02-g16.*`; existing modules
  unchanged.
- **FR-R02G1601-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1601-013**: Every star, corridor and measure MUST be identifiable without colour vision: the kernel names
  them in words (star numbers, the ship's star and beat, strokes drawn and missing, actions left, beats to the deadline).
- **FR-R02G1601-014**: The truth metric MUST be computed exactly and reported after every action: the projected
  glyph mismatch (strokes of the symbol not yet drawn and strokes drawn outside it) and the hazard clearance (the
  fewest beats between any leg flown and a hazard on its corridor, or clear).

### Key Entities

- **Level**: stars, corridors, range, windows, hazards, start, beacon, deadline, symbol strokes, budget, tutorial
  flag, fingerprint.
- **Star**: its orbit (lattice positions by beat), its glyph point, its time window.
- **Corridor**: two stars and a travel time.
- **Hazard tube**: a corridor and the beats it is blocked.
- **Route report**: the ship's star and beat, strokes drawn, missing and stray, hazard clearance, the outcome.
- **Action**: leg (destination star, wait), undo, redo.
- **Play**: stage, ship star, beat, drawn strokes, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1601-001**: For 500 seeded constructed levels the known legs win and every refused action is refused with
  its named reason.
- **SC-R02G1601-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1601-003**: Over 500 seeded levels and action sequences, every star position, range decision, arrival beat,
  hazard decision, window decision, stroke set, mismatch count and outcome equals an independent computation.
- **SC-R02G1601-004**: Failure happens on the exact action with the reason named, including one action either side of
  the budget, one beat either side of a window, the deadline and a hazard interval, and a range one unit inside and
  outside.
- **SC-R02G1601-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1601-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Tap route nodes to queue legs" is choosing the destination star of the next leg; "drag time slider" is choosing the
  wait before departure; "preview gliding 3D route" is presentation only.
- "Ship transitions between node orbits on quantized launch ticks" is a leg departing on a whole beat after a whole
  number of beats of waiting, the stars moving along their periodic orbits beat by beat.
- "Route crosses hazard tube or violates node time window" are the hazard and window failures of FR-R02G1601-003; a
  stroke outside the symbol and a late arrival also fail, because they can never lead to a win.
- "Projected glyph skeleton mismatch and hazard clearance" is the exact truth metric of FR-R02G1601-014.
- Levels and their certification (time-expanded graph search over navigable corridors) come in R02-G16-02; drawing in
  R02-G16-03; gestures in R02-G16-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (legs, waits, beats, budget) | FR-R02G1601-002, 004, 006, 007, 008 |
| Exact win/failure evaluation (symbol drawn, beacon, hazards, windows) | FR-R02G1601-003, 004, 005 |
| Truth metric: projected glyph skeleton mismatch and hazard clearance | FR-R02G1601-014; SC-R02G1601-003 |
| Puzzle contract for certification | FR-R02G1601-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G16-02; INV-11 is superseded by the free tier) | FR-R02G1601-012 |
| Accessibility (colour independence) | FR-R02G1601-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
