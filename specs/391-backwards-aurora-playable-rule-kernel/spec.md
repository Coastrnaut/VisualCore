# Feature Specification: R02-G10-01 — Backwards Aurora: playable rule kernel

**Feature Branch**: `391-backwards-aurora-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G10-01 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1001-###,
SC-R02G1001-###, T-R02G1001-###

**Input**: User description: the archived R02-G10-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Backwards Aurora, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/391-backwards-aurora-playable-rule-kernel`; FR-R02G1001-###, SC-R02G1001-###,
  T-R02G1001-###.
- **Packaging (ADR-0009):** Backwards Aurora is experience R02-G10 (`r02-g10.backwards-aurora`, free) inside the single
  VisualCore app. The source's `Apps/BackwardsAurora` and `Packages/GameModules/BackwardsAuroraCore` become the
  experience module `Packages/ExperiencesRound02/BackwardsAurora`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G10 and its gate X-R02-G10.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 76 (the catalog's "76
  solver-certified stages") is produced in R02-G10-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic (the signal's samples are signed integers in a
  fixed unit), so every device decides the same; the catalog's 0.008333 s timestep is the presentation clock of later
  features and never decides a rule.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G10-02 can certify levels).
- **Model:** feature 381 (Nocturne Garden's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fold the aurora back into its true shape (Priority: P1) 🎯

A player sees an aurora drawn as a wave of samples along a timeline, a few checkpoints where the true signal's height is
known, and the limits on how sharply the wave may bend. Some sections of the wave run backwards. The player chooses a
section by its two ends and reverses it in time; the wave's samples in that section swap order. When every checkpoint
shows its true height and every seam of the wave bends within the limit, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of reversals wins on its last action; after every
action the wave, the checkpoint matches, the seam bends and the distance to the target equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known reversals, **When** they are applied, **Then** the level is won exactly on the action
   that makes every checkpoint match with every seam within the bend limit.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - Tear the aurora or run out of reversals (Priority: P1)

A reversal whose new seams bend past the breaking limit tears the aurora and fails the level; so does spending the last
reversal without a win. The reason, the seam and the action are named.

**Independent Test**: scripted sequences end failed with the named reason on the exact action.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A section outside the wave or too short:** a reversal whose ends lie outside the wave, or that covers fewer than two
  samples, is refused (`r02-g10.action`).
- **A reversal that changes nothing:** reversing a section that reads the same both ways is refused (`r02-g10.noop`) and
  spends nothing.
- **A bend exactly at a limit:** a bend equal to the bend limit counts as within it; a bend equal to the breaking limit
  does not tear; one unit more tears.
- **Win on the last reversal:** an action that wins on the last reversal of the budget wins.
- **A level already solved at load:** never generated; a level's opening wave never already wins.
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1001-001**: A level MUST define the opening wave (an ordered list of signed integer samples), the target
  wave of the same length, the checkpoints (sample positions whose target height must be reached), the bend limit, the
  breaking limit, the shortest and longest reversible section and the reversal budget.
- **FR-R02G1001-002**: A reversal MUST reverse the order of the samples between two chosen ends (inclusive) and change
  nothing else.
- **FR-R02G1001-003**: The bend at a seam MUST be the exact second difference of three neighbouring samples; the wave is
  smooth when every interior bend is within the bend limit.
- **FR-R02G1001-004**: Every accepted reversal MUST spend one reversal; undo and redo MUST spend nothing.
- **FR-R02G1001-005**: The level MUST be won exactly on the action after which every checkpoint equals its target height
  and the wave is smooth; it MUST fail with a named reason when a reversal leaves a bend beyond the breaking limit at
  one of its two new seams (tear) or when the last reversal is spent without a win (budget).
- **FR-R02G1001-006**: Every action MUST be validated (range, section length, stage, previous fingerprint, budget) and
  refused without change when invalid.
- **FR-R02G1001-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1001-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1001-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1001-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1001-011**: Invalid requests MUST be refused with stable reason codes `r02-g10.*`; existing modules
  unchanged.
- **FR-R02G1001-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1001-013**: Every sample, checkpoint, seam and measure MUST be identifiable without colour vision: the kernel
  names them in words (sample position and height, checkpoint matched or not, the worst bend against the limit, the
  reversals left), so later features can show them as text and shapes.
- **FR-R02G1001-014**: The truth metric MUST be computed exactly: the normalized edit distance between the wave and the
  target (the sum of absolute sample differences over the sum of absolute target heights, as an exact fraction) and the
  continuity (the worst bend), reported after every action.

### Key Entities

- **Level**: opening wave, target wave, checkpoints, bend limit, breaking limit, section lengths, reversal budget,
  tutorial flag, fingerprint.
- **Wave**: the ordered samples; its bends and distance to the target.
- **Action**: reverse, undo, redo.
- **Play**: stage, wave, reversals spent, records, undo and redo stacks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1001-001**: For 500 seeded constructed levels the known reversals win and every refused action is refused
  with its named reason.
- **SC-R02G1001-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1001-003**: Over 500 seeded levels and action sequences, every wave, bend, checkpoint match and distance
  equals an independent computation.
- **SC-R02G1001-004**: Tear and budget each fail on the exact action with the reason named, including the boundary cases
  at the breaking limit and one reversal either side of the budget.
- **SC-R02G1001-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1001-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Signal samples in signed fixed precision" is read as signed integers in one fixed unit of the aurora's height.
- "Interval reversal must preserve seam continuity and bounded curvature" is read as the bend (second difference) at
  every seam being bounded: within the bend limit to win, within the breaking limit to survive a reversal.
- "Reconstructed waveform matches target checkpoints and seam limits" is read as every checkpoint equal to the target
  and the whole wave within the bend limit.
- "Normalized signal edit distance and continuity" is read as the exact distance and worst bend of FR-R02G1001-014.
- Levels and their certification (interval dynamic programming over reversible segments) come in R02-G10-02; drawing
  in R02-G10-03; gestures (tap segment ends, swipe to reverse, timeline freeze preview) in R02-G10-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (interval reversal of signed samples) | FR-R02G1001-002, 004, 006, 007, 008 |
| Exact win/failure evaluation (checkpoints and seam limits; tear fails) | FR-R02G1001-003, 005 |
| Truth metric: normalized edit distance and continuity | FR-R02G1001-014; SC-R02G1001-003 |
| Puzzle contract for certification | FR-R02G1001-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content belongs to R02-G10-02; INV-11 is superseded by the free tier; INV-12 novelty to R02-G10-02) | FR-R02G1001-012 |
| Accessibility (colour independence) | FR-R02G1001-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
