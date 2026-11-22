# Feature Specification: R02-G07-01 — Amethyst Escape: playable rule kernel

**Feature Branch**: `361-amethyst-escape-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G07-01 (migration ledger, game feature of experience R02-G07) · ID namespace FR-R02G0701-###,
SC-R02G0701-###, T-R02G0701-###

**Input**: User description: the archived R02-G07-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Amethyst Escape, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/361-amethyst-escape-playable-rule-kernel`; FR-R02G0701-###, SC-R02G0701-###,
  T-R02G0701-###.
- **Packaging (ADR-0009):** Amethyst Escape is experience R02-G07 (`r02-g07.amethyst-escape`, free) inside the single
  VisualCore app. The source's `Apps/AmethystEscape` and `Packages/GameModules/AmethystEscapeCore` become the experience
  module `Packages/ExperiencesRound02/AmethystEscape`; this feature adds its pure Core with tests. Catalog registration,
  adapter and renderer come in later features of R02-G07 and its gate X-R02-G07.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the Round
  2 lock and per-round device campaign (ImplementationLock-100). The content count 80 (the catalog's "80
  solver-certified stages") is produced in R02-G07-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in integers (shells, sectors and rotation steps), so every device decides
  the same; the catalog's 0.008333 s timestep is the presentation clock of later features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G07-02 can certify levels).
- **Model:** feature 351 (Chrono Constellator's rule kernel) for structure, stored form, records and refusals.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
351's answers where the games agree. Facts checked in code (read-only, 2026-11-22): `Packages/ExperiencesRound02` holds
Aurora Loom, Lissajous Labyrinth, Wave Knot Keeper, Hue Compass, Colorfall Canyons and Chrono Constellator as the pattern
(Core with level, play, records with previous and next fingerprints, rules as R02-F23 `PuzzleRules`, `StableHash`
fingerprints, `r02-gNN.*` reason codes); no `AmethystEscape*` name exists; the catalog sets the timestep at 0.008333 s
and the content at 80 stages.

- Q: What exactly are the shells, sectors, apertures, walls and wedges? → A: N = 6 … 12 sectors (the same for every
  shell) and 2 … 5 shells numbered 0 (innermost) … K − 1 (outermost). Each shell lists, in its own sectors 0 … N − 1:
  its outer apertures (a non-empty set; the outermost shell has exactly one, the exit gap), its radial walls (wall j
  stands between its sectors j and j + 1 mod N; at most N − 1 walls) and its blocked wedges (a set; never every sector).
  The pearl starts in shell 0 at a sector that is not blocked, with every shell at offset 0. The move budget is 1 … 60.
  Shells are named "shell 1 (inner)" … "shell K (outer)" and sectors by their clock-face position ("sector 3 of 12"), so
  everything is told apart without colour. Impact: FR-R02G0701-001, 013; SC-R02G0701-001.
- Q: How do rotations and advances move things, exactly? → A: shell r has an offset o_r in 0 … N − 1; a pocket (r, a)
  at absolute sector a lies in shell r's own sector (a − o_r) mod N. `rotate(r, +1)` (clockwise) sets o_r to
  (o_r + 1) mod N and `rotate(r, −1)` to (o_r − 1) mod N; if the pearl is in shell r its absolute sector changes by the
  same step. `advance` from (r, a) with own sector j: if j is an outer aperture of shell r — when r is the outermost
  shell the pearl leaves through the exit gap (won); otherwise it moves to (r + 1, a). Else, if wall j is absent, it moves
  to (r, a + 1 mod N). Else it is refused (`r02-g07.stuck`). A move that lands on a blocked wedge (the destination's own
  sector in its shell's blocked set) puts the pearl there and fails the level. Impact: FR-R02G0701-002, 003, 005;
  SC-R02G0701-003.
- Q: What do the actions cost, and how is the budget spent? → A: every accepted rotate and advance spends one move; a
  refused action spends nothing; undo and redo spend nothing (undo gives the move back, redo spends it again). There is
  no budget refusal: the move that reaches the budget is still applied and then judged. Impact: FR-R02G0701-004;
  SC-R02G0701-001, 004.
- Q: In which order are exit, wedge and budget decided, and from which stages can the player go back? → A: after an
  advance: exit first (won), then wedge (failed, naming the shell and the sector); then, after any accepted move that did
  not end the level, budget (moves spent equal to the budget: failed). Undo and redo restore the exact earlier state for
  every accepted rotate and advance; a new action clears the redo stack. Undo works in playing and paused; from failed,
  undo returns to playing (an honest retry, recorded); a won level is final and refuses undo. Impact: FR-R02G0701-005, 007,
  008; SC-R02G0701-002, 004.
- Q: How are records, fingerprints and stored forms defined? → A: as in R02-G06-01: every accepted action appends a
  record (schema, level seed, move index, kind, operands, previous and next fingerprints); the play fingerprint is the
  SHA-256 of the schema, the level fingerprint, the offsets, the pearl's pocket, the moves spent, the stage and the
  failure; levels are JSON schema 1 with sorted keys and a fingerprint, re-checked on decode; reason codes
  `r02-g07.level`, `.action`, `.stage`, `.stale`, `.stuck`, `.newer-schema`, `.malformed`. Impact: FR-R02G0701-006 …
  011; SC-R02G0701-002, 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Rotate the shells and roll the pearl out (Priority: P1) 🎯

A player looks at a crystal of nested shells around a pearl. Each shell is a ring of equal wedge pockets with openings
(apertures) in its outer wall and some radial walls between pockets; some pockets are blocked wedges. The player turns
shells one step at a time and taps to advance the pearl: the pearl rolls outward through an aperture lined up under it,
or else one pocket clockwise along its ring. When the pearl leaves the outermost shell through its exit gap, the level
is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known action sequence wins on its last action; after every action the
shell offsets and the pearl's pocket equal an independent computation from the level and the actions.

**Acceptance Scenarios**:

1. **Given** a level and its known solution, **When** its actions are applied, **Then** the level is won exactly on the
   advance that carries the pearl through the exit gap.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - Fall into a blocked wedge or run out of moves (Priority: P1)

An advance that carries the pearl into a blocked wedge fails the level; so does spending the last move without a win.
The reason, the shell and the pocket are named.

**Independent Test**: scripted sequences end failed with the named reason on the exact move.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **Rotating the pearl's shell:** the pearl turns with its shell (it keeps its pocket in that shell); rotating any other
  shell never moves the pearl.
- **Nowhere to roll:** an advance with no aperture lined up and a radial wall ahead is refused (`stuck`) and spends
  nothing; the player must rotate first.
- **Exit on the last move:** an advance that carries the pearl out of the exit gap on the last move of the budget wins.
- **Outward into a blocked wedge:** an aperture lined up over a blocked wedge of the next shell fails the advance there.
- **A full turn:** rotating a shell by its sector count returns it to the same offset and the same fingerprint.
- **Zero moves:** a level is never won before the first move, and a pearl never starts in a blocked wedge.
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0701-001**: A level MUST define two or more nested shells with the same number of sectors, for each shell its
  outer apertures, its radial walls and its blocked wedges (in the shell's own sectors), the pearl's starting pocket in the
  innermost shell, the move budget, and exactly one aperture in the outermost shell, the exit gap.
- **FR-R02G0701-002**: Rotating a shell MUST turn it by one sector clockwise or anticlockwise (its offset changes by ±1
  modulo the sector count); the pearl MUST turn with its own shell and never with another.
- **FR-R02G0701-003**: Advancing the pearl MUST make exactly one deterministic pocket transition: outward to the same
  angle of the next shell when its current pocket's outer aperture is there, otherwise one sector clockwise along its
  ring when no radial wall is in the way, otherwise it is refused without change.
- **FR-R02G0701-004**: Every rotation and every accepted advance MUST spend one move from the budget; undo and redo MUST
  spend nothing.
- **FR-R02G0701-005**: The level MUST be won exactly on the advance that carries the pearl outward from the outermost
  shell through its exit gap; it MUST fail with a named reason when an advance carries the pearl into a blocked wedge
  (wedge) or when the last move of the budget is spent without a win (budget).
- **FR-R02G0701-006**: Every action MUST be validated (range, stage, previous fingerprint, budget) and refused without
  change when invalid.
- **FR-R02G0701-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G0701-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G0701-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G0701-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G0701-011**: Invalid requests MUST be refused with stable reason codes `r02-g07.*`; existing modules unchanged.
- **FR-R02G0701-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G0701-013**: Every shell, pocket, aperture, wall and blocked wedge MUST be identifiable without colour vision:
  the kernel names them in words and positions (shell number, clock-face sector), so later features can show them as
  text and shapes.

### Key Entities

- **Level**: sector count, shells (outer apertures, radial walls, blocked wedges), start pocket, move budget, exit gap,
  tutorial flag, fingerprint.
- **Pocket**: a shell and an absolute sector; a shell's own sector is the absolute sector minus its offset.
- **Action**: rotate (shell, direction), advance, undo, redo.
- **Play**: stage, shell offsets, pearl pocket, moves spent, records, undo and redo stacks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0701-001**: For 500 seeded constructed levels the known solution wins and every refused action is refused
  with its named reason.
- **SC-R02G0701-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G0701-003**: Over 500 seeded levels and action sequences, every state equals an independent brute-force
  computation from the level and the actions.
- **SC-R02G0701-004**: Wedge and budget each fail on the exact move with the reason named, including the boundary cases
  one move either side of the budget.
- **SC-R02G0701-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0701-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Connectivity graph is recomputed at angle changes" is read as: which pockets connect depends only on the shell
  offsets, so each advance is decided from the current offsets; nothing is cached across rotations.
- The pearl only rolls outward or clockwise (a fixed, deterministic direction), so a level's route is decided by the
  shell offsets the player chooses; inward moves do not exist.
- Facets, highlights and dispersion are drawn later from the kernel's integers; the rules never use floating point.
- Levels and their certification come in R02-G07-02; drawing in R02-G07-03; gestures R02-G07-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (fixed rotation increments, recomputed connectivity, deterministic pocket transitions) | FR-R02G0701-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (exit gap; blocked wedge or move budget) | FR-R02G0701-005 |
| Truth metric: graph route length and reachable exit proof | FR-R02G0701-003, 010; SC-R02G0701-003 |
| Puzzle contract for certification | FR-R02G0701-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content belongs to R02-G07-02; INV-11 is superseded by the free tier; INV-12 novelty to R02-G07-02) | FR-R02G0701-012 |
| Accessibility (colour independence) | FR-R02G0701-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no continuous physics of the pearl; no device run before ImplementationLock-100.
