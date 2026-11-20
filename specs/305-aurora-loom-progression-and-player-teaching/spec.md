# Feature Specification: R02-G01-05 — Aurora Loom: progression and player teaching

**Feature Branch**: `305-aurora-loom-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-05 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0105-###,
SC-R02G0105-###, T-R02G0105-###

**Input**: User description: the archived R02-G01-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Aurora Loom, with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/305-aurora-loom-progression-and-player-teaching`; FR-R02G0105-###,
  SC-R02G0105-###, T-R02G0105-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate) in
  `Packages/ExperiencesRound02/AuroraLoom`.
- **Superseded parts of the source prompt:** "meaningful premium content", price and "no IAP": Aurora Loom is free under
  the shared purchase controller; every one of its 100 levels is included and nothing is sold, advertised or locked behind
  payment. The source's "content count 80" is a milestone. The Round 2 lock and per-round device campaign
  (ImplementationLock-100). **Device-only items:** none. **Owner-only items:** none.
- **Shared features used:** R02-F24 (catalog and progression rule), the solver and certified catalog of R02-G01-02, the
  kernel, renderer and controls of R02-G01-01 … 04.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `AuroraLoomSolver.solve(_:)` solves each ribbon among its 256 settings from a level's
start; `AuroraLoomExperienceCore` prepares level (seed mod 100) + 1, accepts `ribbon.move`, `play.undo`, `play.redo` and
`level.next`, and snapshots `{level, records}` as schema 1; the kernel reports a failure as the worst mismatch (ribbon,
gate, tick, residual); the core may not read a clock.

- Q: How is a hint computed and what does each level reveal? → A: the solver runs on a level whose start is the current
  steps (same gates, Ω, tolerance), giving each ribbon's fewest changes and its chosen winning setting. Level 1 names the
  ribbon with the most changes left (ties: the larger worst residual, then the lower ribbon); level 2 adds the control
  (wave before phase when both change); level 3 adds the exact step. Following the level-3 hint shortens the remaining
  shortest solution by one. When the shortest remaining solution exceeds the moves left, the hint says so and offers undo.
  Hints never change the state, are unlimited and do not affect stars. Impact: FR-R02G0105-002; SC-R02G0105-002.
- Q: What does the tutorial show, and when does it advance? → A: on tutorial levels (1 … 3) one instruction at a time:
  (1) "Drag ribbon r's anchor up or down to change its wave" until a wave move is made; (2) "Turn ribbon r's dial to change
  its phase" until a phase move is made; (3) "Bring every ribbon through the gold markers at all four gates" until the
  level is won; r is the level-1 hint's ribbon. A dismiss action ends the tutorial for that level; undo never moves the
  tutorial back. Impact: FR-R02G0105-001; SC-R02G0105-001.
- Q: What are the progress and star rules? → A: progress holds, per level, the best number of moves that won and the
  stars: 3 when the moves equal the level's certified shortest solution, 2 within shortest + 2, otherwise 1. Level 1 is
  open; winning a level in campaign mode opens the next; `level.select [n]` opens any open level and refuses others
  (`r02-g01.locked`); `level.next` moves to the next open level. Bands are shown as the catalog's bands (20 levels each).
  Impact: FR-R02G0105-004; SC-R02G0105-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 37) mod 100 + 1; the date reaches the core as the action `mode.daily [year, month, day]` from the presenter (the
  core never reads a clock), so every date in the player's calendar maps to a stable level. Daily play follows campaign
  rules but does not open levels. `mode.practice` replays the current level with the allowance raised to the kernel's
  maximum (64); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G0105-005;
  SC-R02G0105-004.
- Q: Where does progress live and how is it versioned? → A: progress and the mode are part of the experience
  state and its digest; the tutorial step is snapshotted but not digested (it never moves back, so undo must still
  restore the earlier digest, R2-G01-INV-05); and the snapshot payload becomes schema 2 (`{level, records, progress, mode,
  tutorial}`) with a migration from schema 1 (no progress, campaign mode, tutorial at its first step). New refusal codes:
  `r02-g01.locked`, `r02-g01.date`. Failure explanations read the kernel's worst mismatch: "Ribbon r is furthest off at gate
  g: x of a turn outside the tolerance after the last move" with undo and retry offered. Impact: FR-R02G0105-003, 007;
  SC-R02G0105-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn the loom from the first level (Priority: P1) 🎯

A new player opens level 1, sees one short instruction for the current step (drag an anchor, turn a dial, meet the
markers), and the instruction advances as they act; nothing blocks play and the tutorial can be dismissed.

**Why this priority**: players who do not understand the goal leave in the first minute.

**Independent Test**: on levels 1 … 3 the instruction shown follows the player's actions in the defined order and never
prevents a move.

**Acceptance Scenarios**:

1. **Given** level 1 just opened, **When** the player has made no move, **Then** the first instruction names the anchor of
   the furthest-off ribbon.
2. **Given** a tutorial step is shown, **When** the player performs it, **Then** the next step is shown; dismissing ends the
   tutorial for that level.

### User Story 2 - Ask for a hint, step by step (Priority: P1)

A stuck player asks for a hint: the first hint names which ribbon to change, the second which control, the third the
exact step; hints come from the solver, are never wrong and never move anything by themselves.

**Independent Test**: for every certified level and many reachable states, each hint level names a change that lies on a
shortest remaining solution.

### User Story 3 - Understand a failure (Priority: P1)

When the moves run out, the player sees which ribbon and gate were furthest off and by how much, in words, and is offered
undo or retry — never a generic "Wrong".

**Independent Test**: every failure explanation names the same ribbon, gate and residual as the kernel's failure.

### User Story 4 - Pace and goals across 100 levels (Priority: P2)

Levels are grouped in five bands; finishing a level opens the next; each level shows its goal (moves allowed, the best
possible) and a result (stars for meeting the shortest solution); a daily level is chosen from the local date; a practice
mode allows unlimited undo and hints without spending moves.

**Independent Test**: the unlock order, star rules, daily choice and practice rules hold for scripted progress.

### Edge Cases

- **A hint asked in a state with no solution within the remaining moves:** the hint says so and offers undo.
- **A hint asked when already won or failed:** no hint; the result is shown instead.
- **A level picked that is not yet open:** refused with the reason; the open level stays.
- **The local date at midnight, time zone changes, a date before 2026:** the daily level is a fixed function of the
  calendar date in the player's calendar; any date maps to a level 1 … 100.
- **Practice mode:** moves are not limited; results in practice never award stars or open levels.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0105-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform moves.
- **FR-R02G0105-002**: A hint MUST be available in three progressive levels (ribbon, control, exact step), computed from
  the solver for the current state so that following it keeps a shortest remaining solution; a hint never changes the
  state.
- **FR-R02G0105-003**: A failure MUST be explained in accessible text naming the furthest-off ribbon, gate, tick and
  residual (the kernel's failure) with undo and retry offered.
- **FR-R02G0105-004**: Progress MUST follow defined rules: the first level open, solving a level opens the next, the
  catalog's bands shown, a goal (allowance, best possible) and a result (stars) per level.
- **FR-R02G0105-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  allow unlimited moves and hints without affecting progress.
- **FR-R02G0105-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0105-007**: Progress MUST be a versioned value the experience snapshot carries (saving to disk is R02-G01-07);
  existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state (which handle to use, what to aim for), its order.
- **Hint**: level (ribbon, control, step), the suggested move, the remaining shortest length.
- **Failure explanation**: ribbon, gate, tick, residual, text.
- **Progress**: solved levels with best move counts and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0105-001**: On levels 1 … 3, scripted players following each instruction win, and every instruction matches
  the state it was shown in.
- **SC-R02G0105-002**: For all 100 certified levels and 2,000 seeded reachable states, every hint names a move after which
  the shortest remaining solution is one shorter (or the hint correctly reports no solution within the moves left).
- **SC-R02G0105-003**: Every failure explanation in 500 seeded failures names the kernel's failure exactly.
- **SC-R02G0105-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0105-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test finishes in under
  10 seconds.

## Assumptions

- Saving progress to disk, the gallery and replay are R02-G01-07; full accessibility polish R02-G01-06, including the
  panel's layout at large text sizes on iPhone and iPad; in this feature every instruction, hint and failure text is plain
  text in the panel, read by VoiceOver.
- The teaching text is original; the design is the project's own.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0105-001, 002 |
| Pacing and goals | FR-R02G0105-004 |
| Failure-specific coaching | FR-R02G0105-003 |
| Modes (Play, Practice, Daily-Seed Equivalent) | FR-R02G0105-004, 005 |
| "Meaningful premium content" | superseded: free, all levels included (FR-R02G0105-006) |
| No Stage One breakage | FR-R02G0105-007 |

## Negative Requirements / Excluded scope

- No purchase prompt, advertising, account, streak pressure, network, timed challenge or automatic solving.
