# Feature Specification: R02-G20-01 — Mushroom Weather: playable rule kernel

**Feature Branch**: `491-mushroom-weather-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G20-01 (migration ledger, game feature of experience R02-G20) · ID namespace FR-R02G2001-###,
SC-R02G2001-###, T-R02G2001-###

**Input**: User description: the archived R02-G20-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Mushroom Weather, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/491-mushroom-weather-playable-rule-kernel`; FR-R02G2001-###,
  SC-R02G2001-###, T-R02G2001-###.
- **Packaging (ADR-0009):** Mushroom Weather is experience R02-G20 (`r02-g20.mushroom-weather`, free) inside the
  single VisualCore app. The source's `Apps/MushroomWeather` and `Packages/GameModules/MushroomWeatherCore` become the
  experience module `Packages/ExperiencesRound02/MushroomWeather`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G20 and its gate X-R02-G20.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 76 (the catalog's "76
  solver-certified stages") is a milestone inside the levels of R02-G20-02. **Device-only items:** none (pure logic).
  **Owner-only items:** none.
- **Exactness:** the source's law (humidity diffuses over the forest floor, evaporates and is released by fungi;
  growth is triggered by time-integrated thresholds) is evaluated in deterministic integer arithmetic on integer
  humidity units per cell, so every device computes the same weather bit for bit, and every unit of water is accounted
  for in a source and sink ledger. Every rule (a colony inside its preferred band, a colony drying out, mold
  saturation, the growth trigger) is then decided exactly on those integers. The catalog's 0.016667 s timestep is the
  presentation clock of later features; the kernel counts cycles and never reads a clock.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G20-02 can certify levels).
- **Model:** feature 481 (Microscopic Aurora's rule kernel) for structure, stored form, records and refusals.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
481's answers where the games agree (stages, stored form, records, refusal codes, puzzle contract). Facts checked in
code (read-only, 2026-11-26): Microscopic Aurora's kernel (`MicroscopicAuroraLevel`, `MicroscopicAuroraPlay`,
`MicroscopicAuroraError` with codes `r02-g19.level`, `.action`, `.budget`, `.stage`, `.stale`, `.newer-schema`,
`.malformed`) keeps every limit as an integer range, fingerprints levels with SHA-256 of a canonical text and
implements R02-F23's `PuzzleRules` (`MicroscopicAuroraPuzzle`, `VisualCoreSimulation`); no `MushroomWeather` module
exists yet in `Packages/ExperiencesRound02`.

- Q: What is the forest floor, in which units? → A: a grid of 6 … 12 rows by 6 … 14 columns (rows and columns from 0);
  each cell is floor or blocked (a log or stone that holds no water and exchanges none). Humidity is a whole number of
  units per floor cell, 0 … 10000; the boundary is closed (no water crosses the edge of the grid). The mold bound M is
  1000 … 10000 and every starting humidity is 0 … M. Impact: FR-R02G2001-001, 003; SC-R02G2001-004.
- Q: What exactly happens in one cycle, so every device agrees and the ledger balances? → A: three steps, each computed
  from the state at the start of that step (synchronous, so cell order cannot change the result). (1) Diffusion: for
  every pair of orthogonally adjacent floor cells a and b, the flow from a to b is (hₐ − h_b)·D/64 with D 1 … 12,
  truncated toward zero; each cell adds the flows into it and subtracts the flows out of it. Flows are antisymmetric,
  so the total is unchanged exactly, and since a cell has at most four neighbours and 4·12/64 < 1, no cell goes
  negative. (2) Evaporation: each floor cell has an evaporation rate 0 … 200 (vent cells have an open and a closed rate);
  with moonlight level L 0 … 3, a cell loses ⌊h·rate·(4 + L)/4096⌋, never more than it holds. (3) Release: each pod
  adds its release r (1 … 40) to its cell, or its grown release g (r … 80) once grown. The ledger of the cycle is the
  total before, the released, the evaporated and the total after, and total after = total before + released −
  evaporated holds exactly. All values fit in 64-bit integers. Impact: FR-R02G2001-003, 014; SC-R02G2001-003.
- Q: How do pods grow and what are the colonies? → A: after each cycle's three steps, each pod adds its cell's humidity
  to its integral; when the integral reaches the growth threshold G (100 … 200000) the pod is grown from the next cycle
  on. A colony stands on a floor cell (never a pod's), with a band low … high (0 ≤ low ≤ high ≤ M) and, if sensitive,
  a survival floor f (0 ≤ f ≤ low); a level has 1 … 6 colonies, every one a target. A colony is in band in a cycle when
  low ≤ h ≤ high after that cycle. Impact: FR-R02G2001-001, 004, 005.
- Q: In which order is the run judged, and what does "sustain for T cycles" mean exactly? → A: the run walks cycles
  1 … T (T 20 … 200). After each cycle: the lowest-numbered sensitive colony with h < f fails `dried` (colony, cycle);
  otherwise the first floor cell in row-major order with h > M fails `mold` (cell, cycle). After the last cycle, the
  level is won exactly when every colony has been in band for each of the last K cycles (K 5 … T), so the network ends
  stable; otherwise it fails `unstable`, naming the colony with the shortest final in-band run (lowest number on a
  tie) and that run's length. The report also gives each colony's longest in-band run and its first cycle out of band.
  A level is refused when a sensitive colony starts below its floor, a cell starts above M, or the starting arrangement
  wins. Impact: FR-R02G2001-005, 014; SC-R02G2001-004.
- Q: Which actions exist, how does a level live and how is it stored? → A: pod slots 0 … P − 1 (P 1 … 6).
  `place(slot, row, column)` puts a pod into a slot or moves it (the cell must differ from the slot's current one, be
  floor, and hold no colony and no other pod); `remove(slot)` empties an occupied slot; `vent(index, open)` sets one of
  the level's 0 … 6 vent cells (it must change the vent's state); `moonlight(level)` sets L (it must change it). Each
  spends one action and is refused `r02-g20.action` when out of range, unchanged or on a forbidden cell, or removing an
  empty slot, `r02-g20.budget` when no action is left. A pod moved or placed starts ungrown with a zero integral; growth
  happens only during the run. `run` spends nothing and ends the level (won or failed); undo and redo restore
  arrangements and, from failed, undo returns to playing with the arrangement before the run. The budget is 1 … 12. As
  feature 481: stages loading → tutorial → playing ⇄ paused → won or failed → result; begin, dismissTutorial, pause and
  resume are their own record kinds; each record carries the schema, the level seed, an index, the kind, the action
  and the fingerprints before and after; replay refuses a record of another level or a broken chain
  (`r02-g20.malformed`); `.stage` and `.stale` as there. The stored form is JSON schema 1 with sorted keys (id, seed,
  difficulty 1 … 5, rows, columns, blocked cells, starting humidity, diffusion, evaporation rates, vents, moonlight,
  pod rules, colonies, mold bound, run length, required cycles, starting pods, budget, tutorial, fingerprint = SHA-256
  of a canonical text); a damaged or edited form is refused `r02-g20.malformed`, a newer one `r02-g20.newer-schema`,
  an invalid level `r02-g20.level`. The report after every action holds the humidity by cycle, the ledger by cycle, the
  growth cycles, each colony's runs, the first failure and the predicted outcome, with words for each ("pod 2 at row 3,
  column 7, grown at cycle 18", "colony 1 at row 5, column 2: 412 units, band 380 … 520, in band for the last 12 of 12
  cycles"). The puzzle contract (R02-F23): the position is the arrangement (pods, vents, moonlight), the moves are the
  actions legal from it, the goal test is that the predicted run wins; certifying levels (R02-G20-02) searches
  arrangements. Impact: FR-R02G2001-006, 007, 008, 009, 010, 011, 013, 014.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Arrange the fungi so every colony stays in its humidity band (Priority: P1) 🎯

A player sees a midnight miniature forest floor laid out as cells, with mushroom colonies that each prefer a band of
humidity, some cells under canopy vents, and a moonlight level. The player places, moves or removes spore pods (fungi
that breathe out moisture), opens or closes canopy vents (which change how fast a cell dries), and shifts the moonlight
(which changes evaporation everywhere), then lets the weather run: humidity spreads between neighbouring cells,
evaporates and is released by the fungi, and fungi that have been moist long enough grow and release more. When every
target colony stays inside its preferred band for the required number of consecutive cycles, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known arrangement wins when the weather is run; after every action
the predicted humidity field, ledger, colony intervals and outcome equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known arrangement, **When** it is set up and the weather is run, **Then** the level is
   won.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - A colony dries out or the mold takes over (Priority: P1)

Running the weather fails the level when a sensitive colony's humidity falls below its survival floor, when any cell's
humidity rises above the mold saturation bound, or when the run ends without every target colony having held its band
for the required cycles. Each failure names its reason, the colony or cell and the cycle; the player can undo the run
and rearrange.

**Independent Test**: scripted sequences end failed with the named reason on the run.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A spore pod placed off the floor, on a blocked cell, on another pod or on a colony:** refused without cost.
- **An action that changes nothing** (a vent set to its current state, moonlight set to its current level, a pod moved
  to its own cell): refused without cost.
- **A colony exactly on a band edge:** inside the band; leaving needs a strictly lower or higher humidity.
- **Humidity exactly at the mold bound:** not mold; saturation needs a strictly greater value.
- **Humidity exactly at a sensitive colony's survival floor:** alive; drying out needs a strictly lower value.
- **A growth integral exactly at its threshold:** the fungus grows.
- **Diffusion between two equal cells:** no flow; flows are antisymmetric, so water is never created or lost by
  rounding.
- **Evaporation larger than a cell holds:** the cell empties to zero, never below; the ledger records what left.
- **The action budget spent:** further arrangement actions are refused; running is still allowed.
- **A level already won at load:** never accepted; every level needs at least one action to win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2001-001**: A level MUST define the forest floor (its cells, blocked cells and the boundary), the starting
  humidity of every cell, the diffusion rate, the evaporation of every cell with its vent open and closed, the
  moonlight levels and their evaporation factor, the colonies (cell, preferred band, sensitivity and survival floor),
  the pod release and growth rules (release per cycle, growth threshold and grown release), the mold saturation bound,
  the run length in cycles, the required consecutive cycles in band, the starting pods, vents and moonlight, the
  action budget and whether it shows a tutorial. A level is refused when a value is out of range (including required
  cycles above the run length), a colony, vent or starting pod lies off the floor, two colonies or two pods share a cell
  or a pod stands on a colony, there is no target colony, a sensitive colony starts below its survival floor, a cell
  starts above the mold bound, or the starting arrangement already wins.
- **FR-R02G2001-002**: A spore pod MUST stand on one free floor cell (not blocked, not a colony, not another pod); the
  number of pods is bounded by the level; a vent belongs to a fixed vent cell and is open or closed; the moonlight is
  one of the level's fixed levels.
- **FR-R02G2001-003**: Every cycle of the weather MUST update every cell's humidity by exact integer diffusion between
  orthogonal neighbours (antisymmetric flows, so the total is conserved), minus evaporation (by vent state and
  moonlight, never below zero), plus release from pods (grown pods release more), in a fixed order so every device
  gets the same field.
- **FR-R02G2001-004**: A pod MUST grow when the humidity it has accumulated over cycles (its time integral) reaches
  the growth threshold, and from then on release the grown amount.
- **FR-R02G2001-005**: Running the weather MUST end the level: failed at the first cycle a sensitive colony falls
  below its survival floor (reason: dried out) or any cell exceeds the mold bound (reason: mold), with the colony or
  cell and the cycle; otherwise won exactly when every target colony has been inside its band for each of the last
  required cycles of the run, and failed (reason: unstable) naming the colony with the shortest final interval when
  not.
- **FR-R02G2001-006**: An action MUST place, move or remove a pod, open or close a vent, or set the moonlight, and
  spend one action; every action MUST be validated (ranges, cells, stage, budget, previous fingerprint) and refused
  without change when invalid.
- **FR-R02G2001-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G2001-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G2001-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G2001-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G2001-011**: Invalid requests MUST be refused with stable reason codes `r02-g20.*`; existing modules
  unchanged.
- **FR-R02G2001-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G2001-013**: Every cell, colony, pod, vent and measure MUST be identifiable without colour vision: the kernel
  names them in words (cells by row and column, colonies by number, humidity in units against each band, cycles,
  actions left).
- **FR-R02G2001-014**: The truth metric MUST be computed exactly and reported after every action: the humidity
  conservation ledger (total at the start, released by pods, evaporated, total at the end, equal by construction for
  every cycle) and the colony survival intervals (for every colony, its longest run of consecutive cycles in band and
  its first cycle out of band), with the first failure and the predicted outcome.

### Key Entities

- **Level**: floor, starting humidity, diffusion, evaporation by vent and moonlight, colonies, pod rules, mold bound,
  run length, required cycles, starting arrangement, budget, tutorial flag, fingerprint.
- **Colony**: cell, band (low, high), sensitivity and survival floor.
- **Spore pod**: cell, accumulated humidity, grown or not.
- **Weather report**: humidity by cycle, the ledger by cycle, pod growth cycles, colony intervals, first failure,
  outcome.
- **Action**: place pod, move pod, remove pod, set vent, set moonlight, run, undo, redo.
- **Play**: stage, pods, vents, moonlight, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2001-001**: For 500 seeded constructed levels the known arrangement wins and every refused action is
  refused with its named reason.
- **SC-R02G2001-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G2001-003**: Over 500 seeded runs, every humidity value, ledger entry, growth cycle, colony interval and
  outcome equals an independent computation, and the ledger balances exactly for every cycle.
- **SC-R02G2001-004**: Failure happens on the run with the reason named, including a colony one unit either side of a
  band edge, a cell one unit either side of the mold bound, a sensitive colony one unit either side of its survival
  floor, a growth integral one unit either side of its threshold and an interval one cycle short of the requirement.
- **SC-R02G2001-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G2001-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Drag spore pods" is the pod actions; "open or close canopy vents" is the vent action; "shift moonlight intensity"
  is the moonlight action; letting the weather run is the run action.
- "All target colonies sustain preferred humidity band for T cycles" is the won rule of FR-R02G2001-005; "sensitive
  colony dries out" and "mold saturation exceeds upper bound" are its two failures.
- "Humidity conservation with source/sink ledger and colony survival intervals" is the exact truth metric of
  FR-R02G2001-014.
- Levels and their certification (grid diffusion with bounded evapotranspiration and reachability checks) come in
  R02-G20-02; drawing in R02-G20-03; gestures in R02-G20-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (pods, vents, moonlight, run, budget) | FR-R02G2001-002, 006, 007, 008 |
| humidity_{t+1} = humidity_t + D·laplacian·dt − evaporation + release | FR-R02G2001-003 |
| Growth triggered by time-integrated thresholds | FR-R02G2001-004 |
| Exact win/failure evaluation (bands for T cycles, drying out, mold saturation) | FR-R02G2001-005 |
| Truth metric: humidity conservation ledger and colony survival intervals | FR-R02G2001-014; SC-R02G2001-003 |
| Puzzle contract for certification | FR-R02G2001-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G20-02; INV-11 is superseded by the free tier) | FR-R02G2001-012 |
| Accessibility (colour independence) | FR-R02G2001-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no platform floating point in the rules; no device run before ImplementationLock-100.
