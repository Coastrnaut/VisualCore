# Feature Specification: R02-G19-01 — Microscopic Aurora: playable rule kernel

**Feature Branch**: `481-microscopic-aurora-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

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

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
471's answers where the games agree (stages, stored form, records, refusal codes, puzzle contract). Facts checked in
code (read-only, 2026-11-26): Apsides Workshop's kernel (`ApsidesWorkshopLevel`, `ApsidesWorkshopPlay`,
`ApsidesWorkshopError` with codes `r02-g18.level`, `.action`, `.budget`, `.stage`, `.stale`, `.newer-schema`,
`.malformed`) keeps every limit as an integer range, fingerprints levels with SHA-256 of a canonical text and
implements R02-F23's `PuzzleRules` (`ApsidesWorkshopRules`, `VisualCoreSimulation`).

- Q: What are the dish, the enclosure and the swimmers, in which units? → A: the dish is a square of 24 × 24 cells
  (rows and columns 0 … 23); one cell is 256 dish units, so positions run 0 … 6143 on each axis and a position's cell is
  (⌊y/256⌋, ⌊x/256⌋). The enclosure is the circle about the dish centre (3072, 3072) of radius R cells, R 6 … 11; a
  swimmer is inside when (x − 3072)² + (y − 3072)² ≤ (256R)², so the rim itself is inside. The swarm has 4 … 16
  swimmers, each an integer position and an integer velocity in dish units per tick; the swim lasts T ticks, 120 … 480.
  Impact: FR-R02G1901-001, 002; SC-R02G1901-004.
- Q: What exactly happens in one tick, so every device agrees? → A: all accelerations are computed from the state at
  tick t, then every swimmer is updated (a synchronous step, so swimmer order cannot change the result). For swimmer i,
  its neighbours are the other swimmers within the neighbour radius ρ (2 … 6 cells, compared as squared distances in
  dish units). Separation sums pᵢ − pⱼ over neighbours within the separation radius σ (1 cell … ρ); two swimmers at the
  same point push along +x for the lower index and −x for the higher, by one dish unit. Alignment is the neighbours'
  mean velocity minus vᵢ, cohesion their mean position minus pᵢ (means by integer division truncating toward zero;
  with no neighbour, alignment and cohesion are zero, and with none within σ, separation is zero).
  The swarm acceleration is (wₛ·separation)/64 + (wₐ·alignment)/16 + (w_c·cohesion)/256 with weights 0 … 8 each.
  Each well at the centre q of its cell, with strength s 1 … 4 and sense ±1 (+1 counterclockwise), adds the curl
  acceleration sense·s·4096·(−dy, dx)/(dx² + dy² + 65536) with (dx, dy) = p − q. Every division truncates toward zero.
  The total acceleration is clamped to ±a_max per axis (2 … 16), then v ← v + a clamped to ±v_max per axis (8 … 48),
  then p ← p + v (semi-implicit Euler). All values fit in 64-bit integers. Impact: FR-R02G1901-003; SC-R02G1901-003.
- Q: How are trails, lit cells, coverage and connectedness decided? → A: a cell's trail density is the number of
  (swimmer, tick) pairs for ticks 1 … T whose position lies in the cell; the cell is lit when its density is at least
  the threshold (1 … 64). The stencil is 4 … 120 distinct cells whose centres lie inside the enclosure. Coverage is the
  number of lit stencil cells over the stencil's size in tenths of a percent, rounded down (0 … 1000), against a
  required coverage of 500 … 1000. Connectedness holds when the lit stencil cells form exactly one group under
  four-neighbour adjacency (up, down, left, right). Impact: FR-R02G1901-004, 005, 014.
- Q: What is coherence, and in which order are the failures judged? → A: two swimmers are linked when their squared
  distance is at most the square of the coherence radius κ (2 … 8 cells); the swarm's coherence at a tick is the size
  of its largest linked group; the required coherence is 2 … N. Playing walks ticks 1 … T, after each tick's move:
  the lowest-index swimmer outside the enclosure fails `exit` (swimmer, tick); otherwise a coherence below the
  requirement fails `coherence` (tick, largest group). After the swim, a coverage below the requirement fails
  `coverage` (lit and needed cells); otherwise more than one group fails `connectedness`, naming the first lit stencil
  cell in row-major order that is not in the group of the first one; otherwise the level is won. A level is refused
  when a swimmer starts outside the enclosure or the start's coherence is below the requirement. Impact:
  FR-R02G1901-005; SC-R02G1901-004.
- Q: Which actions exist, how does a level live and how is it stored? → A: three well slots 0 … 2. `place(slot, row,
  column, strength, sense)` puts a well into a slot or changes it (the result must differ from the slot's current
  well), on a cell whose centre is inside the enclosure and that no other well occupies; `remove(slot)` empties an
  occupied slot. Each spends one action and is refused `r02-g19.action` when out of range, unchanged or on an
  occupied or outside cell, or removing an empty slot, `r02-g19.budget` when no action is left. `play` spends nothing and ends the level (won or
  failed); undo and redo restore placements and, from failed, undo returns to playing with the wells before the play.
  The budget is 1 … 12. As feature 471: stages loading → tutorial → playing ⇄ paused → won or failed → result; begin,
  dismissTutorial, pause and resume are their own record kinds; each record carries the schema, the level seed, an
  index, the kind, the action and the fingerprints before and after; replay refuses a record of another level or a
  broken chain (`r02-g19.malformed`); `.stage` and `.stale` as there. The stored form is JSON schema 1 with sorted keys
  (id, seed, difficulty 1 … 5, enclosure radius, swim length, swarm rules, swimmers, stencil, threshold, coverage,
  coherence, starting wells, budget, tutorial, fingerprint = SHA-256 of a canonical text); a damaged or edited form is
  refused `r02-g19.malformed`, a newer one `r02-g19.newer-schema`, an invalid level `r02-g19.level`. The report after
  every action holds the positions by tick, every cell's density, the lit cells, the coverage, the groups, the
  smallest coherence and its tick, the first failure and the predicted outcome, with words for each ("well 2 at row 7,
  column 12, strength 3, counterclockwise", "stencil 34 of 40 cells lit, 85.0 %, needs 80.0 %"). The puzzle contract
  (R02-F23): the position is the wells, the moves are the placements legal from it, the goal test is that the
  predicted play wins; certifying levels (R02-G19-02) searches well strengths and positions. Impact:
  FR-R02G1901-006, 007, 008, 009, 010, 011, 013, 014.

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

- **A well placed outside the enclosure, on another well's cell or with a strength out of range:** refused without
  cost.
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
  range, the separation radius exceeds the neighbour radius, a swimmer starts outside the enclosure, the start's
  coherence is below the requirement, a stencil cell lies outside it or appears twice, the stencil is empty, a starting
  well lies outside the enclosure or shares a cell with another, or the starting wells already win.
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
