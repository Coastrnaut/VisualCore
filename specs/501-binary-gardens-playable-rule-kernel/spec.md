# Feature Specification: R02-G21-01 — Binary Gardens: playable rule kernel

**Feature Branch**: `501-binary-gardens-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-01 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2101-###,
SC-R02G2101-###, T-R02G2101-###

**Input**: User description: the archived R02-G21-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Binary Gardens, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/501-binary-gardens-playable-rule-kernel`; FR-R02G2101-###,
  SC-R02G2101-###, T-R02G2101-###.
- **Packaging (ADR-0009):** Binary Gardens is experience R02-G21 (`r02-g21.binary-gardens`, free) inside the single
  VisualCore app. The source's `Apps/BinaryGardens` and `Packages/GameModules/BinaryGardensCore` become the experience
  module `Packages/ExperiencesRound02/BinaryGardens`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G21 and its gate X-R02-G21.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 81 (the catalog's "81
  solver-certified stages") is a milestone inside the levels of R02-G21-02: the canonical catalog is the archived
  100-level manifest (`python3 scripts/planning_index.py levels --experience R02-G21`: 20 levels in each of bands
  1 … 5, moves budgets 8 … 19), which every round-two game ships, so 81 is a figure reached on the way and not a
  different catalog. **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Exactness:** the source's law (received flux = Σ luminosityᵢ / max(rᵢ², r_min²), analytic orbit curves, plants
  responding to integrated flux bands) is evaluated in deterministic integer arithmetic: orbits are quantized to 48
  phase steps per cycle, positions come from a fixed integer cosine table, and flux is a whole number of milliflux
  computed by one truncating integer division per star, so every device computes the same light bit for bit. Every rule
  (a world inside its comfortable band, a lethal run longer than the tolerance, the stable illumination window, the
  bloom band of the integrated flux, the stars' minimum separation) is then decided exactly on those integers. The
  catalog's 0.008333 s timestep is the presentation clock of later features; the kernel counts ticks and never reads a
  clock.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G21-02 can certify levels).
- **Model:** feature 491 (Mushroom Weather's rule kernel) and feature 481 (Microscopic Aurora's) for structure, stored
  form, records and refusals.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following
features 481 and 491 where the games agree (stages, stored form, records, refusal codes, puzzle contract). Facts
checked in code (read-only, 2026-11-27): Mushroom Weather's kernel (`MushroomWeatherLevel`, `MushroomWeatherPlay`,
`MushroomWeatherError` with codes `r02-g20.level`, `.action`, `.budget`, `.stage`, `.stale`, `.newer-schema`,
`.malformed`, and `.generation` and `.witness` added by its feature 492) keeps every limit as an integer range,
fingerprints levels with SHA-256 of a canonical text and implements R02-F23's `PuzzleRules` (`MushroomWeatherPuzzle`,
`VisualCoreSimulation`); its feature 492 had to widen the action budget from 1 … 12 to 1 … 24 for the manifest, so
this kernel starts at 1 … 24. No `BinaryGardens` module exists yet in `Packages/ExperiencesRound02`. The archived
manifest of R02-G21 has moves budgets 8 … 19 and the control emphases `adjust orbit`, `phase twin stars`, `set
luminosity`, `watch world` and `commit light window`, 20 levels each.

- Q: How are the analytic orbits made exact? → A: one cycle is 48 phase steps (7.5° each), and the whole system is
  sampled once per tick. Every body moves a whole number of phase steps per tick, so after 48 ticks every body is back
  at its start: one cycle of 48 ticks is the exact period of the system, and "a full cycle" means exactly ticks
  1 … 48. Angles use a fixed integer cosine table at scale 1024, the quarter wave C[0 … 12] = 1024, 1015, 989, 946,
  887, 812, 724, 623, 512, 392, 265, 134, 0 (each the nearest integer to 1024·cos(7.5°·k)); the rest of the wave
  follows by symmetry (C[k] = −C[24 − k] for 13 … 24, −C[k − 24] for 25 … 36, C[48 − k] for 37 … 47) and
  S[k] = C[(k + 36) mod 48]. The table is data, never computed at run time; a test checks it against its definition.
  Distances are whole distance units; positions are integers at scale 2²⁰ (1024²): a world at orbit radius a and phase
  ψ is at (a·C[ψ]·1024, a·S[ψ]·1024, 0); a star at radius ρ and phase θ under orbit-plane tilt τ is at
  (ρ·C[θ]·1024, ρ·S[θ]·C[τ], ρ·S[θ]·S[τ]). All values fit in 64-bit integers (largest squared distance below 2⁵⁶).
  Impact: FR-R02G2101-001, 003; SC-R02G2101-003.
- Q: What exactly is the flux, its scale and its clamp? → A: flux is in milliflux (scale 1000: one flux unit is one
  luminosity unit at one distance unit). With D the squared star-to-world distance at scale 2⁴⁰ and r_min the level's
  clamp radius (1 … 8 distance units), star i gives world j the flux ⌊1000·Lᵢ·2⁴⁰ / max(D, r_min²·2⁴⁰)⌋, and the
  world's flux at a tick is the sum over the two stars. The clamp removes every division by zero or near zero (a world
  passing through a star receives the clamped maximum, 64 000 milliflux per star at most). Luminosities are 1 … 64
  units; the numerator stays below 2⁵⁷. Impact: FR-R02G2101-003, 014; SC-R02G2101-003, 004.
- Q: What are the bodies and what does the player control? → A: exactly two stars and 1 … 5 garden worlds. The stars
  share the binary's angular speed ω (1 … 3 phase steps per tick, fixed by the level: the orbits are coupled); each
  star has a ring (an index into the level's 2 … 8 strictly increasing ring radii, each 1 … 40 units), a phase offset
  (0 … 47) and a luminosity (an index into the level's 1 … 4 strictly increasing luminosity levels); the shared orbit
  plane has a tilt 0 … T_max steps (T_max 0 … 6, so at most 45°). Each world has a fixed orbit radius (1 … 60 units),
  starting phase (0 … 47) and speed (−4 … 4 steps per tick; negative is retrograde, 0 a world held still) in the base
  plane. A star's position at tick t has phase (θ + ω·t) mod 48, a world's (ψ + ν·t) mod 48 (non-negative modulo).
  The level marks, for each star, whether its ring, its phase and its luminosity can be adjusted; tilt is adjustable
  when T_max > 0. The stars must keep the level's minimum separation σ (0 … 16 units; 0 means none): the squared
  separation at every tick 0 … 47 is at least σ²·2⁴⁰. Impact: FR-R02G2101-001, 002.
- Q: How do the plants respond, and how is the run judged? → A: each world has four flux bounds, lethal low λ_lo,
  comfortable low c_lo, comfortable high c_hi and lethal high λ_hi, with 0 ≤ λ_lo < c_lo ≤ c_hi < λ_hi ≤ 200 000
  milliflux, splitting every tick into lethal low (F < λ_lo), dim, comfortable (c_lo ≤ F ≤ c_hi), bright and lethal
  high (F > λ_hi); a lethal tolerance E (0 … 12, one per level); a required window W (1 … 48 ticks); and a bloom band
  B_lo … B_hi (0 ≤ B_lo ≤ B_hi ≤ 9 600 000) for its integrated flux I, the sum of its flux over ticks 1 … 48. The run
  walks ticks 1 … 48 + E (ticks beyond 48 repeat the start of the next cycle, so a lethal run that straddles the cycle
  boundary is counted whole). At each tick, worlds in ascending order: a lethal tick extends the world's lethal run, any
  other tick ends it; the first world whose run exceeds E fails `frozen` (if that tick is lethal low) or `scorched`
  (lethal high), naming the world and the tick. Without a lethal failure, worlds in ascending order: a world whose
  longest cyclic run of comfortable ticks over the cycle is shorter than W fails `unstable` (world, window, required);
  a world with I < B_lo fails `wilted`, with I > B_hi `bleached` (world, integral, band). Otherwise the level is won:
  every world keeps a stable illumination window across the full cycle and its plants bloom. A level is refused when
  its starting arrangement violates the separation or already wins, or no control is adjustable. Impact:
  FR-R02G2101-004, 005, 014; SC-R02G2101-004.
- Q: Which actions exist, how does a level live and how is it stored? → A: `ring(star, index)`, `phase(star, step)`,
  `luminosity(star, index)` and `tilt(step)`. Each must change the value, act on an adjustable control and keep the
  separation; each spends one action and is refused `r02-g21.action` when out of range, unchanged, locked or breaking
  the separation, `r02-g21.budget` when no action is left. `run` ("commit light window") spends nothing and ends the
  level (won or failed); inspecting a world ("watch world") is the report and changes nothing. Undo and redo restore
  arrangements and, from failed, undo returns to playing with the arrangement before the run. The budget is 1 … 24.
  As features 481 and 491: stages loading → tutorial → playing ⇄ paused → won or failed → result; begin,
  dismissTutorial, pause and resume are their own record kinds; each record carries the schema, the level seed, an
  index, the kind, the action and the fingerprints before and after; replay refuses a record of another level or a
  broken chain (`r02-g21.malformed`); `.stage` (an action in the wrong stage) and `.stale` (a previous fingerprint that
  does not match) as there. The stored form is JSON schema 1 with sorted keys (id, seed, difficulty 1 … 5, ring radii,
  star speed, luminosity levels, the two stars with starting ring, phase, luminosity and adjustable flags, tilt range
  and starting tilt, minimum separation, clamp radius, worlds with radius, phase, speed, four flux bounds, window and
  bloom band, lethal tolerance, budget, tutorial, fingerprint = SHA-256 of a canonical text); a damaged or edited form
  is refused `r02-g21.malformed`, a newer one `r02-g21.newer-schema`, an invalid level `r02-g21.level`. Schema 1 is
  the first; a later schema adds a forward migration and keeps reading schema 1. The report after every action holds
  every body's position by tick, every world's flux by tick with each star's share, the band of every tick, the lethal
  runs, the comfortable windows, the integrals and mean flux, the minimum star separation, the first failure and the
  predicted outcome, with words for each ("star 1 on ring 3, 12 units, phase 9, luminosity 24", "world 2 at tick 17:
  41 250 milliflux, comfortable, band 30 000 … 52 000", "world 2: window of 31 ticks from tick 5, 24 required").
  The puzzle contract (R02-F23): the position is the arrangement (rings, phases, luminosities, tilt), the moves are
  the actions legal from it, the goal test is that the predicted run wins; certifying levels (R02-G21-02) sweeps
  arrangements. Impact: FR-R02G2101-006, 007, 008, 009, 010, 011, 013, 014.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Balance the twin stars so every garden world stays in its light (Priority: P1) 🎯

A player sees two suns circling each other and tiny flowering worlds circling both. Each world's plants need light in
a comfortable band: too little for too long and they freeze, too much for too long and they scorch, and over the whole
cycle they need a steady stretch of comfortable light and the right total light to bloom. The player moves each sun to
a nearer or farther distance ring, shifts where along its orbit it stands, turns its brightness up or down, and tilts
the plane the suns orbit in, then commits the light window: the cycle runs and every world's received light is judged.
When every world keeps a stable illumination window across the full cycle, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known arrangement wins when the cycle is run; after every action the
predicted positions, fluxes, bands, windows, integrals and outcome equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known arrangement, **When** it is set up and the cycle is run, **Then** the level is won.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.
3. **Given** a world and the arrangement, **When** the player inspects it, **Then** its flux at every tick, the band of
   every tick, its window and its integral are reported in words and nothing changes.

### User Story 2 - A world freezes, scorches or never settles (Priority: P1)

Running the cycle fails the level when a world receives lethal low or lethal high flux for more consecutive ticks than
the tolerance, when a world's longest comfortable stretch is shorter than its required window, or when a world's total
light falls outside its bloom band. Each failure names its reason, the world and the tick or the measured value; the
player can undo the run and rearrange.

**Independent Test**: scripted sequences end failed with the named reason on the run.

**Acceptance Scenarios**:

1. **Given** an arrangement that leaves a world lethally dim for E + 1 consecutive ticks, **When** the cycle runs,
   **Then** the level fails `frozen` naming that world and the tick.
2. **Given** a failed run, **When** the player undoes, **Then** play resumes with the arrangement before the run.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A control that is locked, an index out of range, a phase outside 0 … 47 or a tilt above T_max:** refused without
  cost.
- **An action that changes nothing** (a star moved to its own ring, phase or luminosity, the tilt set to itself):
  refused without cost.
- **An action that brings the stars closer than the minimum separation at any tick:** refused without cost; exactly at
  the separation is allowed.
- **A star and a world at the same point, or closer than the clamp radius:** the flux uses the clamp; there is no
  division by zero and no unbounded value.
- **Flux exactly at a lethal bound:** not lethal; lethal needs a strictly lower or higher flux.
- **Flux exactly at a comfortable bound:** comfortable.
- **A lethal run exactly as long as the tolerance:** the world survives; failure needs one tick more.
- **A mixed lethal run** (lethal low then lethal high with no other tick between): one run; it fails with the band
  of the tick at which it exceeds the tolerance (`frozen` if lethal low, `scorched` if lethal high).
- **A lethal run straddling the end of the cycle:** counted whole, through the start of the next cycle; the failure
  names the walk tick (tick 50 is tick 2 of the next cycle).
- **A comfortable window exactly as long as required, or the whole cycle comfortable:** the window holds (48 ticks at
  most).
- **An integral exactly at a bloom bound:** inside the band.
- **Tolerance 0:** a single lethal tick fails the world.
- **The action budget spent:** further arrangement actions are refused; running is still allowed.
- **A level already won at load, or with nothing adjustable:** never accepted; every level needs at least one action
  to win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo from failed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2101-001**: A level MUST define the ring radii, the stars' shared angular speed, the luminosity levels, the
  two stars (starting ring, phase and luminosity and which of them can be adjusted), the tilt range and starting tilt,
  the stars' minimum separation, the flux clamp radius, the garden worlds (orbit radius, starting phase, speed, the
  four flux bounds, the required window and the bloom band), the lethal tolerance, the action budget and whether it
  shows a tutorial. A level is refused when a value is out of range or out of order (ring radii or luminosity levels not
  strictly increasing, flux bounds or bloom bounds out of order), there is no world or more than the bound, nothing is
  adjustable, a star's luminosity is marked adjustable while there is only one luminosity level, the starting stars break the minimum separation at any tick of the cycle, or the starting arrangement
  already wins.
- **FR-R02G2101-002**: Each star MUST stand on one of the level's rings at a phase of the 48-step cycle with one of the
  level's luminosities; the orbit plane MUST have one tilt within the level's range; the two stars MUST keep the minimum
  separation at every tick of the cycle.
- **FR-R02G2101-003**: Every tick MUST place every star and world on its analytic circular orbit from the fixed integer
  cosine table (stars in the tilted orbit plane, worlds in the base plane) and give every world the sum over both stars
  of the integer flux luminosity / max(squared distance, squared clamp radius) in milliflux, truncated per star, so
  every device gets the same flux; the system MUST return exactly to its start after one cycle of 48 ticks.
- **FR-R02G2101-004**: Every world's plants MUST respond to its flux bands: each tick MUST be classed lethal low, dim,
  comfortable, bright or lethal high against the world's four bounds, and the world's integrated flux over the cycle
  MUST be compared with its bloom band.
- **FR-R02G2101-005**: Running the cycle MUST end the level: failed at the first tick a world's consecutive lethal
  ticks exceed the tolerance (reason: frozen for lethal low, scorched for lethal high), counting a run across the cycle
  boundary whole, with the world and the walk tick t (1 … 48 + E; a tick t > 48 has the positions and flux of tick
  t − 48 and is named in words as tick t − 48 of the next cycle); otherwise failed when a world's longest cyclic comfortable window is
  shorter than its required window (reason: unstable) or its integrated flux is below or above its bloom band (reasons:
  wilted, bleached), naming the lowest-numbered such world and its measure (worlds are judged one at a time in ascending order; within
  one world the window is checked before the bloom band, so a world failing both fails unstable); otherwise won.
- **FR-R02G2101-006**: An action MUST set a star's ring, a star's phase, a star's luminosity or the orbit tilt, and
  spend one action; every action MUST be validated (ranges, adjustable flags, change, separation, stage, budget,
  previous fingerprint) and refused without change when invalid. Running and inspecting spend nothing.
- **FR-R02G2101-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G2101-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result); actions while paused are refused, never partly applied.
- **FR-R02G2101-009**: Levels MUST have a versioned stored form (schema 1) with a fingerprint; damaged, edited and newer
  forms MUST be refused; a later schema MUST migrate schema 1 forward.
- **FR-R02G2101-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G2101-011**: Invalid requests MUST be refused with stable reason codes `r02-g21.*`; existing modules
  unchanged.
- **FR-R02G2101-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G2101-013**: Every star, ring, world, band and measure MUST be identifiable without colour vision: the kernel
  names them in words (stars and worlds by number, rings by number and distance, phases and tilt in steps, flux in
  milliflux against each band, ticks, actions left).
- **FR-R02G2101-014**: The truth metric MUST be computed exactly and reported after every action, as the kernel's
  observability: per world its integrated flux over the cycle and its normalized integrated flux (the mean flux per
  tick, kept exact as the integral over 48 ticks), its survival (longest lethal run, read cyclically and at most 48,
  against the tolerance; longest comfortable window against the requirement: the longest run of consecutive comfortable
  ticks over ticks 1 … 48 read cyclically, tick 48 followed by tick 1, at most 48, reported with its start tick, the
  smallest start among equal longest runs and tick 1 when all 48 ticks are comfortable; its bloom result), every tick's flux with each star's share and its band,
  the minimum squared star separation over ticks 0 … 47 and the earliest tick at which it occurs, the first failure and
  the predicted outcome.

### Key Entities

- **Level**: rings, star speed, luminosity levels, two stars with adjustable flags, tilt range, separation, clamp
  radius, worlds, tolerance, budget, tutorial flag, fingerprint.
- **Star**: ring, phase, luminosity, adjustable flags.
- **Garden world**: orbit radius, starting phase, speed, four flux bounds, required window, bloom band.
- **Arrangement**: both stars' rings, phases and luminosities and the tilt.
- **Light report**: positions by tick, flux by tick and star, bands, lethal runs, windows, integrals, minimum
  separation, first failure, outcome.
- **Action**: ring, phase, luminosity, tilt, run, undo, redo.
- **Play**: stage, arrangement, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2101-001**: For 500 seeded constructed levels the known arrangement wins and every refused action is
  refused with its named reason.
- **SC-R02G2101-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G2101-003**: Over 500 seeded runs, every position, flux, band, lethal run, window, integral and outcome
  equals an independent computation, and every body is back at its starting position after 48 ticks.
- **SC-R02G2101-004**: Failure happens on the run with the reason named, including a flux one milliflux either side
  of each of the four bounds, a distance one unit either side of the clamp radius, a lethal run one tick either side of
  the tolerance (also across the cycle boundary), a window one tick short of the requirement, an integral one
  milliflux either side of each bloom bound and a separation one unit either side of the minimum.
- **SC-R02G2101-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G2101-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Drag star distance rings" is the ring action; "tilt orbit plane" is the tilt action; "inspect each miniature
  world" is the report, which changes nothing; the manifest's `phase twin stars` and `set luminosity` are the phase and
  luminosity actions, `adjust orbit` the ring action, `watch world` inspection and `commit light window` the run.
- "Each garden world has stable illumination window across a full cycle" is the won rule of FR-R02G2101-005; "world
  receives lethal low/high flux for too many ticks" is its frozen and scorched failures; "plants respond to integrated
  flux bands" is the per-tick bands and the bloom band of FR-R02G2101-004.
- "Per-world integrated normalized flux and survival" is the exact truth metric of FR-R02G2101-014.
- "Numerical gravitation in fixed steps" in the signature shader is presentation; the judged orbits are the analytic
  quantized circles of this kernel, with no gravitational integration.
- Levels and their certification (the bounded coupled-orbit parameter sweep sampling received flux) come in
  R02-G21-02; drawing in R02-G21-03; gestures in R02-G21-04.
- Binary Gardens judges the light received by orbiting worlds over a cycle, not eclipse sequences (Celestial Eclipse
  Lab, R02-G17) or swept sky regions (Apsides Workshop, R02-G18); its moves (rings, phases, luminosities, tilt) and
  its solution representation are its own.
- The game design is the project's own archived design; the code is original; no star catalogue or third-party data
  is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (rings, phases, luminosity, tilt, run, budget) | FR-R02G2101-002, 006, 007, 008 |
| flux = Σ luminosityᵢ / max(rᵢ², r_min²); orbit curves analytic | FR-R02G2101-003 |
| Plants respond to integrated flux bands | FR-R02G2101-004 |
| Exact win/failure evaluation (stable window across a full cycle; lethal flux for too many ticks) | FR-R02G2101-005 |
| Truth metric: per-world integrated normalized flux and survival | FR-R02G2101-014; SC-R02G2101-003 |
| Puzzle contract for certification | FR-R02G2101-010 |
| Schema migration, error handling | FR-R02G2101-009, 011 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G21-02; INV-11 is superseded by the free tier) | FR-R02G2101-012 |
| Accessibility (colour independence) | FR-R02G2101-013 |
| Observability | FR-R02G2101-014 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no platform floating point and no run-time trigonometry in the rules; no gravitational integration in the
  judged state; no device run before ImplementationLock-100.
