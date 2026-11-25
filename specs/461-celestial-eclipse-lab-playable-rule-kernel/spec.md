# Feature Specification: R02-G17-01 — Celestial Eclipse Lab: playable rule kernel

**Feature Branch**: `461-celestial-eclipse-lab-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Draft

**Ledger gate**: R02-G17-01 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1701-###,
SC-R02G1701-###, T-R02G1701-###

**Input**: User description: the archived R02-G17-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Celestial Eclipse Lab, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/461-celestial-eclipse-lab-playable-rule-kernel`; FR-R02G1701-###,
  SC-R02G1701-###, T-R02G1701-###.
- **Packaging (ADR-0009):** Celestial Eclipse Lab is experience R02-G17 (`r02-g17.celestial-eclipse-lab`, free) inside
  the single VisualCore app. The source's `Apps/CelestialEclipseLab` and `Packages/GameModules/CelestialEclipseLabCore`
  become the experience module `Packages/ExperiencesRound02/CelestialEclipseLab`; this feature adds its pure Core with
  tests. Catalog registration, adapter and renderer come in later features of R02-G17 and its gate X-R02-G17.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 74 (the catalog's "74
  solver-certified stages") is a milestone inside the levels of R02-G17-02. **Device-only items:** none (pure logic).
  **Owner-only items:** none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic on ticks (one step of the miniature clock),
  lattice positions and disc radii, so every device decides the same; the catalog's 0.008333 s timestep is the
  presentation clock of later features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G17-02 can certify levels).
- **Model:** feature 451 (Starlit Cartouche's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Phase the orbits so the eclipses come in order (Priority: P1) 🎯

A player sees miniature bodies on their orbits seen from one side, and a target sequence of eclipses (which body passes
in front of which), each with a time window. The player turns the movable bodies' orbits to new phases, then runs the
clock: as the bodies move, their discs overlap in the projection; when the eclipses happen in exactly the target order,
each inside its window, and no other eclipse comes first, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known set of phases wins when the clock is run; after every action
the predicted eclipse timeline and the closeness to the target equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known phases, **When** they are set and the clock is run, **Then** the level is won.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - An unwanted eclipse comes first, or a window is missed (Priority: P1)

A run fails the level when an eclipse that is not the next required one happens before the target sequence is complete,
when the next required eclipse happens outside its window, or when the clock reaches its horizon before the sequence is
complete. Each failure names its reason, the eclipse (front and back body) and the tick; the player can undo the run and
change the phases again.

**Independent Test**: scripted sequences end failed with the named reason on the run.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **An unknown body, a fixed body, a phase outside the body's period, a phase equal to the current one:** refused
  without cost.
- **Discs that just touch (the distance between centres equal to the sum of the radii):** no eclipse; overlap needs a
  strictly smaller distance.
- **An eclipse exactly on a window's opening or closing tick:** inside the window.
- **Two eclipses beginning on the same tick:** ordered by a fixed rule, so the timeline is the same everywhere.
- **An eclipse already under way at tick 0:** it begins at tick 0.
- **The action budget spent:** further phase changes are refused, the run is still allowed.
- **A level already solved at load:** never accepted; every level needs at least one phase change to win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1701-001**: A level MUST define its bodies (each with a periodic orbit of lattice positions, a disc radius
  and whether its phase is fixed), the horizon of the clock, the target sequence of eclipses (each a front body, a back
  body and a window of ticks), the action budget and whether it shows a tutorial.
- **FR-R02G1701-002**: Each body's depth MUST keep one front-to-back order for every pair of bodies at every tick, so
  every eclipse names its front and back body without ambiguity; a level breaking this is refused.
- **FR-R02G1701-003**: A phase change MUST set a movable body's starting offset along its orbit and spend one action;
  the predicted eclipse timeline MUST be recomputed exactly after it.
- **FR-R02G1701-004**: Two bodies MUST eclipse at a tick exactly when the squared distance between their projected
  centres is smaller than the square of the sum of their radii; an eclipse event is the first tick of each run of such
  ticks.
- **FR-R02G1701-005**: Running the clock MUST end the level: won exactly when the eclipse events, in timeline order,
  match the target sequence label by label, each inside its window, with no other event before the sequence is
  complete; otherwise failed with the reason (an unwanted eclipse, a missed window, the horizon reached), the eclipse
  and the tick.
- **FR-R02G1701-006**: Every action MUST be validated (body, phase, stage, budget, previous fingerprint) and refused
  without change when invalid.
- **FR-R02G1701-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1701-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1701-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1701-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1701-011**: Invalid requests MUST be refused with stable reason codes `r02-g17.*`; existing modules
  unchanged.
- **FR-R02G1701-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1701-013**: Every body, eclipse and measure MUST be identifiable without colour vision: the kernel names them
  in words (body numbers, front and back, ticks, windows, actions left, the next required eclipse).
- **FR-R02G1701-014**: The truth metric MUST be computed exactly and reported after every action: the ordered eclipse
  intervals (front, back, first and last tick) and each eclipse's visibility class (partial, total or annular), and how
  much of the target sequence the predicted timeline matches.

### Key Entities

- **Level**: bodies, horizon, target sequence, budget, tutorial flag, fingerprint.
- **Body**: its orbit (lattice positions by tick), disc radius, fixed or movable.
- **Target eclipse**: front body, back body, window.
- **Eclipse interval**: front, back, first and last tick, visibility class.
- **Timeline report**: the eclipse intervals in order, the matched prefix of the target, the first offending event, the
  outcome.
- **Action**: phase (body, offset), run, undo, redo.
- **Play**: stage, phases, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1701-001**: For 500 seeded constructed levels the known phases win and every refused action is refused with
  its named reason.
- **SC-R02G1701-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1701-003**: Over 500 seeded levels and phase settings, every position, overlap decision, event tick,
  interval, visibility class, matched prefix and outcome equals an independent computation.
- **SC-R02G1701-004**: Failure happens on the run with the reason named, including one tick either side of a window, the
  horizon and the overlap limit (a distance one unit inside and outside the sum of the radii).
- **SC-R02G1701-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1701-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Drag orbital handles" is choosing a movable body's phase; "rotate time dial" and "step through predicted eclipse
  timeline" are previews of the predicted timeline, which the kernel reports after every action (presentation only).
- "Discs projected from orbital positions" is each body's lattice position seen along one fixed axis; the depth along
  that axis orders front and back.
- "Unwanted eclipse occurs before required eclipse" is the unwanted-eclipse failure of FR-R02G1701-005; a missed window
  and the horizon also fail, because they can never lead to a win.
- "Ordered interval overlap timestamps and visibility classification" is the exact truth metric of FR-R02G1701-014.
- Levels and their certification (analytical overlap interval enumeration and phase search) come in R02-G17-02; drawing
  in R02-G17-03; gestures in R02-G17-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (phases, run, budget) | FR-R02G1701-003, 006, 007, 008 |
| Exact win/failure evaluation (target order, windows, unwanted eclipses) | FR-R02G1701-004, 005 |
| Depth ordering to disambiguate occultations | FR-R02G1701-002 |
| Truth metric: ordered overlap intervals and visibility classification | FR-R02G1701-014; SC-R02G1701-003 |
| Puzzle contract for certification | FR-R02G1701-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G17-02; INV-11 is superseded by the free tier) | FR-R02G1701-012 |
| Accessibility (colour independence) | FR-R02G1701-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
