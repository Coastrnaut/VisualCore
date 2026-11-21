# Feature Specification: R02-G05-01 — Colorfall Canyons: playable rule kernel

**Feature Branch**: `341-colorfall-canyons-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G05-01 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0501-###,
SC-R02G0501-###, T-R02G0501-###

**Input**: User description: the archived R02-G05-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Colorfall Canyons, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/341-colorfall-canyons-playable-rule-kernel`; FR-R02G0501-###, SC-R02G0501-###,
  T-R02G0501-###.
- **Packaging (ADR-0009):** Colorfall Canyons is experience R02-G05 (`r02-g05.colorfall-canyons`, free) inside the single
  VisualCore app. The source's `Apps/ColorfallCanyons` and `Packages/GameModules/ColorfallCanyonsCore` become the
  experience module `Packages/ExperiencesRound02/ColorfallCanyons`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G05 and its gate X-R02-G05.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the Round
  2 lock and per-round device campaign (ImplementationLock-100). The content count 100 is produced in R02-G05-02.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Exactness:** every kernel rule is decided in integers (volumes and dye masses in whole units, a fixed tick of
  1/60 s), so every device decides the same and conservation holds exactly, not within a tolerance.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G05-02 can certify levels).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Route the colours into their basins (Priority: P1) 🎯

A player looks at a small canyon terrain with three springs of coloured light-fluid (cyan, coral, yellow) and several
basins. Fluid runs downhill cell by cell. The player carves short sluices (lowering terrain) and opens or closes the
springs' valves, then lets time run; when every target basin holds its required mix of colours, filled but not
overflowing, within the time limit, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of carves, valve changes and time steps wins; every
tick's volumes equal an independent computation and nothing is created or lost.

**Acceptance Scenarios**:

1. **Given** a level and its known solution, **When** its actions are applied, **Then** the level is won exactly at the
   tick the last target is satisfied.
2. **Given** any state, **When** time advances one tick, **Then** the total fluid and each colour's mass (in cells,
   basins and spilled off the map) equal what the springs have released, exactly.

### User Story 2 - Contaminate, overflow or run out of time (Priority: P1)

Too much of a wrong colour in a protected basin fails the level; so does a basin overflowing or the time limit passing
without a win. The reason is shown.

**Independent Test**: scripted plays end failed with the named reason at the exact tick.

### User Story 3 - Pause, step, undo, redo and replay (Priority: P1)

The player can pause, step time one tick at a time, undo and redo every action exactly, and a recorded trace replays to
the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **Flat ground:** a cell with no strictly lower open neighbour holds its fluid (a pool); fluid never flows uphill or
  sideways on the level.
- **Equal lowest neighbours:** a fixed direction order picks one, the same everywhere.
- **Splitting an outflow between colours:** whole units are shared out by a fixed rule, so no unit is created or lost.
- **A spring runs dry:** it stops releasing; a closed valve releases nothing.
- **Carving at the limit:** terrain cannot be carved below the lowest height, nor can rock, springs, basins or drains.
- **Win and failure on the same tick:** failure is decided first, so a contaminated or overflowing basin never wins.
- **Zero-time:** a level is never won before its first tick.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0501-001**: A level MUST define a small rectangular terrain of cells, each with a height and a kind (open
  ground, rock, spring, basin or drain), the springs' colours, release rates, supplies and starting valve states, the
  basins' capacities, required fills and colour mixes and which basins are protected (with their tolerated amount of
  wrong colour), the flow rate, the action budget and the tick limit.
- **FR-R02G0501-002**: Each tick MUST move fluid by a fixed rule: every open cell passes up to the flow rate of its fluid
  to its single downhill neighbour, chosen exactly from heights by a fixed order; springs release their colour; basins
  and drains only receive. All of a tick's moves MUST be computed from the state at the start of the tick.
- **FR-R02G0501-003**: Fluid volume and each colour's mass MUST be conserved exactly on every tick (released = held +
  spilled), and an outflow's units MUST be shared between colours by a fixed whole-unit rule.
- **FR-R02G0501-004**: Carving MUST lower one carvable cell by one height step and spend one action; toggling a spring's
  valve MUST spend one action; stepping time MUST advance whole ticks and spend nothing.
- **FR-R02G0501-005**: The level MUST be won exactly when, at the end of a tick within the tick limit, every target basin
  holds at least its required fill and its colour mix lies within tolerance; it MUST fail with a named reason when a
  protected basin's wrong colour exceeds its tolerated amount (contamination), when any basin exceeds its capacity
  (overflow), or when the tick limit passes without a win (time). Failure is decided before win on the same tick.
- **FR-R02G0501-006**: Every action MUST be validated (range, stage, previous fingerprint, budget) and refused without
  change when invalid.
- **FR-R02G0501-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G0501-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G0501-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G0501-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G0501-011**: Invalid requests MUST be refused with stable reason codes `r02-g05.*`; existing modules
  unchanged.
- **FR-R02G0501-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G0501-013**: Each colour MUST be identifiable without colour vision: the kernel names every colour and every
  basin's required mix in words and amounts, so later features can show them as text and patterns.

### Key Entities

- **Level**: terrain (heights and kinds), springs, basins, flow rate, action budget, tick limit, tutorial flag,
  fingerprint.
- **Action**: carve (cell), valve (spring), step (ticks), undo, redo.
- **Play**: stage, tick, current heights, valve states, supplies left, fluid per cell by colour, spilled amounts, actions
  spent, records, undo and redo stacks.
- **Tick result**: the moves of one tick and the conservation totals.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0501-001**: For 500 seeded constructed levels the known solution wins and every refused action is refused
  with its named reason.
- **SC-R02G0501-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G0501-003**: Over 500 seeded levels run to their tick limit, total fluid and each colour's mass drift by
  exactly zero on every tick, and every tick's moves equal an independent brute-force computation.
- **SC-R02G0501-004**: Contamination, overflow and time each fail at the exact tick with the reason named, including the
  boundary cases one unit either side of each limit.
- **SC-R02G0501-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0501-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- Terrain, fluid and glow are drawn later from the kernel's integers; the rules never use floating point.
- Levels and their certification come in R02-G05-02; drawing in R02-G05-03; gestures R02-G05-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (q_{t+1} = q_t + inflow − outflow, fixed dt) | FR-R02G0501-002, 004, 006, 007, 008 |
| Colour mass conserved separately | FR-R02G0501-003 |
| Exact win/failure evaluation | FR-R02G0501-005 |
| Truth metric: fluid and dye-mass drift per tick | FR-R02G0501-003; SC-R02G0501-003 |
| Puzzle contract for certification | FR-R02G0501-010 |
| Invariants INV-01 … INV-10 | FR-R02G0501-012 |
| Accessibility (colour independence) | FR-R02G0501-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no free-surface fluid simulation; no device run before ImplementationLock-100.
