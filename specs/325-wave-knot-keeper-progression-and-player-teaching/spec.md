# Feature Specification: R02-G03-05 — Wave Knot Keeper: progression and player teaching

**Feature Branch**: `325-wave-knot-keeper-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

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

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
315's answers where the games agree. Facts checked in code (read-only, 2026-11-21): `WaveKnotKeeperSolver.solve(_:depth:)`
finds the shortest move list from a level's start to a winning rope by breadth-first search over legal ropes to depth 3
(at most 3,661 ropes expanded for 10 points); the kernel's summary is crossings, writhe and degeneracy against the
target; the play has a tutorial stage that the adapter dismisses at once today on levels 1 … 3; the adapter prepares level
(seed mod 100) + 1, accepts `point.move`, `point.select`, `play.undo`, `play.redo` and `level.next` and snapshots
`{level, records}` as schema 1; the core may not read a clock; the allowance is 1 … 64.

- Q: How is a hint computed and what does each level reveal? → A: the solver's breadth-first search runs from the
  current rope (as a level whose start is the current rope) to the nearest winning rope, depth at most 3, giving the
  shortest remaining move list. Level 1 names the point of its first move ("Move point 4"); level 2 adds the axis ("Move
  point 4 along y"); level 3 adds the exact direction ("Move point 4 down (−y)", with "over"/"under" for ±z). Following
  the level-3 hint shortens the shortest remaining solution by one. When no winning rope is within 3 moves, or the
  shortest remaining solution is longer than the moves left, the hint says "No short solution from here; undo or retry"
  and offers undo. Hints never change the state, are unlimited, do not affect stars, and reset to level 1 after any
  change of the play. Impact: FR-R02G0305-002; SC-R02G0305-002.
- Q: What does the tutorial show, and when does it advance? → A: on the tutorial levels 1 … 3, three instructions in
  order: (1) "Drag point <n> one step (or use the panel)" (the level-1 hint's point) until any move is accepted;
  (2) "Match the target's crossings and twist (writhe); strands pass through each other only inside the blue gates" until
  the next accepted move or a hint is asked; (3) "Ask for a hint whenever you are stuck" until the level is won. A dismiss
  action ends the tutorial for that level; undo never moves it back. Impact: FR-R02G0305-001; SC-R02G0305-001.
- Q: What are the progress and star rules? → A: as feature 315: per level the best number of moves that won and the
  stars (3 when equal to the certified shortest, 2 within shortest + 2, else 1; a better result replaces a worse one);
  level 1 open; a campaign win opens the next; `level.select [n]` opens any open level and refuses others
  (`r02-g03.locked`); `level.next` moves to the next open level (refused when none); five bands of 20. Impact:
  FR-R02G0305-004; SC-R02G0305-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 43) mod 100 + 1, negative day counts wrapped into 0 … 99 (43 is coprime with 100, so 100 consecutive days visit
  every level once, and the sequence differs from Aurora Loom's × 37 and Lissajous Labyrinth's × 41); the date reaches the
  core as `mode.daily [year, month, day]` from the presenter (an impossible date is refused with `r02-g03.date`). Daily
  play follows campaign rules but does not open levels. `mode.practice` replays the current level with the allowance
  raised to the kernel's maximum (64); practice results never award stars or open levels; `mode.campaign` returns.
  Impact: FR-R02G0305-005; SC-R02G0305-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 315: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint level
  revealed so far is presentation (held by the presenter, reset after any change of the play); the snapshot payload
  becomes schema 2 (`{level, records, progress, mode, tutorial}`) with a migration from schema 1 (no progress, campaign
  mode, tutorial at its first step on tutorial levels). A failure is explained from the kernel's summary: "The rope has c
  crossings and writhe w; the target is C and W." or, for a degenerate projection, "Two strands overlap in the view, so
  the crossings cannot be counted.", each followed by "Undo the last move or retry the level." Impact: FR-R02G0305-003,
  007; SC-R02G0305-003.

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
