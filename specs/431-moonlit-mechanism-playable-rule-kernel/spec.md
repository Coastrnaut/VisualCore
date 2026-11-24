# Feature Specification: R02-G14-01 — Moonlit Mechanism: playable rule kernel

**Feature Branch**: `431-moonlit-mechanism-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Draft

**Ledger gate**: R02-G14-01 (migration ledger, game feature of experience R02-G14) · ID namespace FR-R02G1401-###,
SC-R02G1401-###, T-R02G1401-###

**Input**: User description: the archived R02-G14-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Moonlit Mechanism, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/431-moonlit-mechanism-playable-rule-kernel`; FR-R02G1401-###, SC-R02G1401-###,
  T-R02G1401-###.
- **Packaging (ADR-0009):** Moonlit Mechanism is experience R02-G14 (`r02-g14.moonlit-mechanism`, free) inside the single
  VisualCore app. The source's `Apps/MoonlitMechanism` and `Packages/GameModules/MoonlitMechanismCore` become the
  experience module `Packages/ExperiencesRound02/MoonlitMechanism`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G14 and its gate X-R02-G14.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 77 (the catalog's "77
  solver-certified stages") is produced in R02-G14-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic, so every device decides the same; the
  catalog's 0.008333 s timestep is the presentation clock of later features and never decides a rule. "Angular phases
  constrained by integer tooth count" are whole-tooth phases; "projected polygons transformed by light matrix" are
  shadows cast on a whole-cell wall grid through an integer projection that depends on the lamp's height step; "tested
  across key frames" compares the cast cells with each key frame's target cells exactly.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G14-02 can certify levels).
- **Model:** feature 421 (Acoustic Constellator's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn the clockwork until its shadows spell the symbols (Priority: P1) 🎯

A player sees a train of interlocking gears in front of a lamp; each gear carries open and solid blades whose shadows
fall on a paper wall. Turning the handle turns the whole train, each meshing gear the opposite way by the same number
of teeth; re-seating a gear shifts it by one tooth against its neighbours; raising or lowering the lamp moves every
shadow by its gear's depth. The wall shows a sequence of key frames, each with a target symbol. When the player runs
the machine, it steps through the key frames; if at every required key frame the shadows cover the symbol exactly
(within the level's allowance of stray cells) and never touch a forbidden cell, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of turns, re-seats, lamp steps and a run wins on the
run; after every action the gear phases, the cast cells of every key frame and the overlap counts equal an independent
computation.

**Acceptance Scenarios**:

1. **Given** a level and its known actions, **When** they are applied, **Then** the level is won exactly on the run.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - The machine jams, a shadow strays onto a forbidden mark, or the moves run out (Priority: P1)

A run fails when a meshing pair of gears is out of alignment (the machine jams), when a key frame's shadows miss part
of the symbol or stray beyond the allowance, or when a shadow covers a forbidden cell; using up the action budget
without a win fails the level too. Each failure names its reason, the key frame, and the gear pair or the cell where it
applies.

**Independent Test**: scripted sequences end failed with the named reason on the exact action and key frame.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **An unknown gear, re-seating the driver gear, a turn, re-seat or lamp step other than one step, a lamp step beyond
  the lowest or highest height:** refused without cost.
- **Stray cells exactly at the allowance:** still a match; one more is a miss.
- **A shadow on a forbidden cell at a key frame that is not required:** still a failure (forbidden cells hold at every
  key frame of a run).
- **A misaligned mesh:** the run fails as a jam before any key frame is compared.
- **The last action of the budget:** a run on it can still win; any other last action without a win fails the level.
- **A level already solved at load:** never generated; every level needs at least one action before a run can win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1401-001**: A level MUST define its gears (tooth count, starting phase, blade pattern, depth, placement), the
  meshing pairs and their alignment, the driver gear, the lamp heights and starting height, the wall grid, the key
  frames (the handle turn of each, its target cells, whether it is required), the forbidden cells, the stray allowance
  and the action budget.
- **FR-R02G1401-002**: Turning the handle by one tooth MUST advance the driver gear by one tooth and every other gear by
  one tooth in the direction its distance from the driver in the train gives, all exactly modulo their tooth counts.
- **FR-R02G1401-003**: The shadow cast at a key frame MUST be the union of the wall cells of every solid blade of every
  gear at its phase for that key frame, projected for the lamp height; it MUST be computed exactly.
- **FR-R02G1401-004**: Turning the handle, re-seating a gear and stepping the lamp MUST each spend one action; a run MUST
  spend one action and decide the level.
- **FR-R02G1401-005**: A run MUST win exactly when every meshing pair is aligned and at every required key frame the
  shadow covers every target cell with at most the allowance of cells outside the target, and no key frame's shadow
  covers a forbidden cell; it MUST fail naming a jammed pair, the key frame and its missing or stray count, or the key
  frame and the forbidden cell; using up the budget without a win MUST fail with a named reason.
- **FR-R02G1401-006**: Every action MUST be validated (gear, step, lamp range, stage, previous fingerprint) and refused
  without change when invalid.
- **FR-R02G1401-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1401-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1401-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1401-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1401-011**: Invalid requests MUST be refused with stable reason codes `r02-g14.*`; existing modules
  unchanged.
- **FR-R02G1401-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1401-013**: Every gear, blade and measure MUST be identifiable without colour vision: the kernel names them in
  words (gear, teeth and phase, the lamp height, each key frame's covered, missing and stray cells, actions left).
- **FR-R02G1401-014**: The truth metric MUST be computed exactly and reported after every action: the angular relation
  error of every meshing pair (its distance from alignment in teeth) and, for every key frame, the target-mask overlap
  (covered, missing, stray and forbidden cell counts).

### Key Entities

- **Level**: gears, meshing pairs, driver, lamp heights, wall grid, key frames, forbidden cells, allowance, budget,
  tutorial flag, fingerprint.
- **Gear**: tooth count, starting phase, blade pattern, depth, placement.
- **Key frame**: handle turn, target cells, required flag.
- **Run report**: per meshing pair its alignment error; per key frame the phases, cast cells and overlap counts; the
  outcome.
- **Action**: turn, re-seat, lamp, run, undo, redo.
- **Play**: stage, phases, lamp height, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1401-001**: For 500 seeded constructed levels the known actions win and every refused action is refused with
  its named reason.
- **SC-R02G1401-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1401-003**: Over 500 seeded levels and action sequences, every phase, cast cell, overlap count, alignment
  error and outcome of a run equals an independent computation.
- **SC-R02G1401-004**: Failure happens on the exact action and key frame with the reason named, including one action
  either side of the budget, one cell either side of the stray allowance, one tooth either side of alignment and the
  first and last key frame.
- **SC-R02G1401-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1401-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Turn a gear handle" is the handle turning the driver gear one tooth at a time; "adjust lamp height" is a stepped lamp
  height; "scrub shadow sequence" is looking at any key frame's shadow without changing the state (a query of the run
  report, not an action).
- "Interlocking gears violate mesh phase constraints" is read as a meshing pair out of alignment: turning the handle
  keeps every pair's alignment, re-seating a gear can break it, and a run with a broken pair jams.
- "Occlude prohibited target area" is read as a shadow covering a forbidden wall cell at any key frame of the run.
- "Silhouettes match target frames at required tick samples" is read as every target cell covered and at most the
  level's allowance of stray cells at every required key frame.
- "Angular relation error and target-mask overlap per frame" is the exact truth metric of FR-R02G1401-014.
- Levels and their certification (discretized phase search with gear-ratio constraints and the silhouette union
  metric) come in R02-G14-02; drawing in R02-G14-03; gestures (turn the handle, drag a gear, slide the lamp, scrub the
  key frames, orbit) in R02-G14-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (turns, re-seats, lamp steps, runs, budget) | FR-R02G1401-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (silhouette match, mesh jam, forbidden area) | FR-R02G1401-005 |
| Truth metric: angular relation error and target-mask overlap per frame | FR-R02G1401-014; SC-R02G1401-003 |
| Puzzle contract for certification | FR-R02G1401-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G14-02; INV-11 is superseded by the free tier) | FR-R02G1401-012 |
| Accessibility (colour independence) | FR-R02G1401-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
