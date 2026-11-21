# Feature Specification: R02-G03-05 — Wave Knot Keeper: progression and player teaching

**Feature Branch**: `325-wave-knot-keeper-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G03-05 (migration ledger, game feature of experience R02-G03) · ID namespace FR-R02G0305-###,
SC-R02G0305-###, T-R02G0305-###

**Input**: User description: the archived R02-G03-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Add tutorial hints, pacing, failure-specific coaching and meaningful premium content" for Wave Knot Keeper, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/325-wave-knot-keeper-progression-and-player-teaching`; FR-R02G0305-###,
  SC-R02G0305-###, T-R02G0305-###.
- **Packaging (ADR-0009):** experience R02-G03 (`r02-g03.wave-knot-keeper`, free; a registered candidate) in the one
  app; "meaningful premium content" is superseded: the game is free and all 100 levels are included.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign.
  **Device-only items:** none. **Owner-only items:** none.
- **Model:** feature 315 (Wave Knot Keeper's progression and player teaching).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn the knot from the first level (Priority: P1) 🎯

A new player opens level 1, sees one short instruction for the current step (move a point, match the target crossings
and writhe, pass strands only inside gates), and the instruction advances as they act; nothing blocks
play and the tutorial can be dismissed.

**Why this priority**: players who do not understand the goal leave in the first minute.

**Independent Test**: on the tutorial levels 1 … 3 the instruction shown follows the player's actions in the defined
order and never prevents an action.

**Acceptance Scenarios**:

1. **Given** level 1 just opened, **When** the player has taken no action, **Then** the first instruction names the point
   of the level-1 hint to move.
2. **Given** a tutorial step is shown, **When** the player performs it, **Then** the next step is shown; dismissing ends the
   tutorial for that level.

### User Story 2 - Ask for a hint, step by step (Priority: P1)

A stuck player asks for a hint: the first hint names which point to move, the second along which axis, the third the
exact direction; hints come from the solver, are never wrong and never change anything by themselves.

**Independent Test**: for every certified level and many reachable states, following the exact hint shortens the shortest
remaining solution by one.

**Acceptance Scenarios**:

1. **Given** a playing level, **When** the player asks for hints three times, **Then** the point, the axis and the
   exact direction are revealed in that order, each consistent with the previous ones.
2. **Given** a state from which no solution fits in the actions left, **When** a hint is asked, **Then** the hint says so
   and offers undo.

### User Story 3 - Understand a failure (Priority: P1)

When the moves run out, the player sees why the knot does not match — its crossings and writhe against the target,
or that two strands overlap in the view — in words, and is offered undo or retry, never a generic "Wrong".

**Independent Test**: every failure explanation names the same crossings, writhe and degeneracy as the kernel's
summary.

### User Story 4 - Pace and goals across 100 levels (Priority: P2)

Levels are grouped in five bands; finishing a level opens the next; each level shows its goal (moves allowed, the best
possible) and a result (stars for meeting the shortest solution); a daily level is chosen from the local date; a practice
mode allows more moves without affecting progress.

**Independent Test**: the unlock order, star rules, daily choice and practice rules hold for scripted progress.

### Edge Cases

- **A hint asked when no solution fits in the actions left:** the hint says so and offers undo.
- **A hint asked when already won or failed:** no hint; the result is shown instead.
- **A level picked that is not yet open:** refused with the reason; the open level stays.
- **The local date at midnight, time zone changes, a date before 2026:** the daily level is a fixed function of the
  calendar date in the player's calendar; any date maps to a level 1 … 100.
- **Practice mode:** results in practice never award stars or open levels; `mode.campaign` returns to a fresh campaign
  play of the same level, and choosing daily or practice drops the current play's records (undo history) of the level
  left.
- **Daily results:** a daily win records the level's result (best actions and stars) but never opens a level; the daily
  level may lie beyond the frontier.
- **A changed mode or level and the tutorial:** the tutorial appears only on levels 1 … 3 in campaign mode, once per
  opening of the level; dismissing it ends it for that opening.
- **A schema-1 or damaged payload:** a schema-1 payload migrates; a damaged or newer payload is refused with the existing
  restore refusals and the experience opens fresh.
- **A hint search limit:** when no solution is found within the hint search depth, the hint says so and offers undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0305-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G0305-002**: A hint MUST be available in three progressive levels (point, axis, exact direction), computed from
  the solver for the current rope so that following it keeps a shortest remaining solution; a hint never changes the
  state, is unlimited, does not affect stars and returns to level 1 after any change of the play.
- **FR-R02G0305-003**: A failure MUST be explained in accessible text naming the kernel's summary (the rope's crossings and
  writhe against the target, or a degenerate projection) with undo and retry offered.
- **FR-R02G0305-004**: Progress MUST follow defined rules: the first level open, solving a level in campaign mode opens the
  next, the catalog's bands shown, a goal (allowance, best possible) and a result (stars) per level.
- **FR-R02G0305-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the allowance without affecting progress.
- **FR-R02G0305-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0305-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (saving to disk is R02-G03-07); existing tests pass; new public names documented; the reference
  regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state, its order.
- **Hint**: level (point, axis, direction), the suggested move, the remaining shortest length.
- **Failure explanation**: the summary (crossings, writhe, degenerate) against the target, text.
- **Progress**: solved levels with best action counts and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0305-001**: On levels 1 … 3, scripted players following each instruction win, and every instruction matches
  the state it was shown in.
- **SC-R02G0305-002**: For all 100 certified levels and 2,000 seeded reachable states, every exact hint names an action
  after which the shortest remaining solution is one shorter (or the hint correctly reports no solution within the
  moves left or the search depth).
- **SC-R02G0305-003**: Every failure explanation in 500 seeded failures names the kernel's summary exactly.
- **SC-R02G0305-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0305-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test finishes in under
  10 seconds.

## Assumptions

- Saving progress to disk and replay are R02-G03-07; full accessibility polish R02-G03-06; in this feature every
  instruction, hint and failure text is plain text in the panel, read by VoiceOver.
- The teaching text is original; the design is the project's own.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0305-001, 002 |
| Pacing and goals | FR-R02G0305-004 |
| Failure-specific coaching | FR-R02G0305-003 |
| Modes (Play, Practice, Daily-Seed Equivalent) | FR-R02G0305-004, 005 |
| "Meaningful premium content" | superseded: free, all levels included (FR-R02G0305-006) |
| No Stage One breakage | FR-R02G0305-007 |

## Negative Requirements / Excluded scope

- No purchase prompt, advertising, account, streak pressure, network, timed challenge or automatic solving.
