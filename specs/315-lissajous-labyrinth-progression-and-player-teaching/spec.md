# Feature Specification: R02-G02-05 — Lissajous Labyrinth: progression and player teaching

**Feature Branch**: `315-lissajous-labyrinth-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G02-05 (migration ledger, game feature of experience R02-G02) · ID namespace FR-R02G0205-###,
SC-R02G0205-###, T-R02G0205-###

**Input**: User description: the archived R02-G02-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Lissajous Labyrinth, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/315-lissajous-labyrinth-progression-and-player-teaching`; FR-R02G0205-###,
  SC-R02G0205-###, T-R02G0205-###.
- **Packaging (ADR-0009):** experience R02-G02 (`r02-g02.lissajous-labyrinth`, free; a registered candidate) in
  `Packages/ExperiencesRound02/LissajousLabyrinth`.
- **Superseded parts of the source prompt:** "meaningful premium content", price and "no IAP": Lissajous Labyrinth is free
  under the shared purchase controller; every one of its 100 levels is included and nothing is sold, advertised or locked
  behind payment. The source's "content count 90" is a milestone. The Round 2 lock and per-round device campaign
  (ImplementationLock-100). **Device-only items:** none. **Owner-only items:** none.
- **Shared features used:** R02-F24 (catalog and progression rule), the solver and certified catalog of R02-G02-02, the
  kernel, renderer and controls of R02-G02-01 … 04 (the stage flow, the dial rings and the pending panel stay).
- **Model:** feature 305 (Aurora Loom), adapted to four dials (frequencies 1 … 9, coprime; phases 0 … 15), checkpoints
  visited in order and obstacles.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
305's answers where the games agree. Facts checked in code (read-only audit, 2026-11-21): `LissajousLabyrinthSolver`
finds a level's winning settings (independent of the start) and its proven shortest solution by breadth-first search over
legal settings (every intermediate frequency pair coprime); the kernel's verdict is `contact(obstacle, tick)` (the first
contact, tick of 4,096 per lap) or `missed(checkpoint)`; the play has a `tutorial` stage that the adapter dismisses at
once today; the adapter prepares level (seed mod 100) + 1, accepts `dial.set`, `play.undo`, `play.redo` and `level.next`
and snapshots `{level, records}` as schema 1; the core may not read a clock; the allowance is 1 … 64.

- Q: How is a hint computed and what does each level reveal? → A: the solver's breadth-first search runs from the
  current dials to the level's winning settings (the same moves, coprime rule and order as the certified solution), giving
  the shortest remaining action list. Level 1 names the dial of its first action ("Turn Phase C"); level 2 adds the
  direction ("Raise Phase C" when the target value is larger, "Lower" when smaller); level 3 adds the exact value ("Set
  Phase C to 3"). Following the level-3 hint shortens the shortest remaining solution by one. When the shortest remaining
  solution is longer than the actions left, the hint says "No solution fits in the actions left; undo or retry" and offers
  undo. Hints never change the state, are unlimited, do not affect stars, and reset to level 1 after any change of the
  play. Impact: FR-R02G0205-002; SC-R02G0205-002.
- Q: What does the tutorial show, and when does it advance? → A: on the tutorial levels 1 … 3, three instructions in
  order: (1) "Turn the <Dial> ring to change the path" (the level-1 hint's dial) until any dial action is accepted;
  (2) "Copper checkpoints light up when the lap reaches them in order; keep the path off the violet spheres" until the
  next accepted action or a hint is asked; (3) "Ask for a hint whenever you are stuck" until the level is won. A dismiss
  action ends the tutorial for that level; undo never moves it back. Impact: FR-R02G0205-001; SC-R02G0205-001.
- Q: What are the progress and star rules? → A: progress holds, per level, the best number of actions that won and the
  stars: 3 when the actions equal the certified shortest solution, 2 within shortest + 2, otherwise 1; a better result
  replaces a worse one. Level 1 is open; winning a level in campaign mode opens the next; `level.select [n]` opens any
  open level and refuses others (`r02-g02.locked`); `level.next` moves to the next open level (refused when none). Bands
  are the catalog's five bands of 20 levels. Impact: FR-R02G0205-004; SC-R02G0205-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 41) mod 100 + 1, negative day counts wrapped into 0 … 99 (41 is coprime with 100, so 100 consecutive days visit
  every level once, and the sequence differs from Aurora Loom's × 37); the date reaches the core as the action
  `mode.daily [year, month, day]` from the presenter (the core never reads a clock; an impossible date is refused with
  `r02-g02.date`). Daily play follows campaign rules but does not open levels. `mode.practice` replays the current level
  with the allowance raised to the kernel's maximum (64); practice results never award stars or open levels;
  `mode.campaign` returns. Impact: FR-R02G0205-005; SC-R02G0205-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: progress and the mode are part of
  the experience state and its digest; the tutorial step is snapshotted but not digested (it never moves back with undo,
  so undo still restores the earlier digest); the hint level revealed so far is presentation (amended at plan,
  2026-11-21, as feature 305 did: the presenter holds it and resets it after any change of the play); the snapshot payload becomes schema 2 (`{level,
  records, progress, mode, tutorial}`) with a migration from schema 1 (no progress, campaign mode, tutorial at its first
  step on tutorial levels). A failure is explained from the kernel's verdict: "The path touches obstacle n at p % of the
  lap" (n = index + 1, p = ⌊100 · tick / 4,096⌋) or "Checkpoint n is not reached in order" (n = index + 1), each followed
  by "Undo the last change or retry the level." Impact: FR-R02G0205-003, 007; SC-R02G0205-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn the labyrinth from the first level (Priority: P1) 🎯

A new player opens level 1, sees one short instruction for the current step (turn a frequency dial, turn a phase dial,
thread every checkpoint in order without touching an obstacle), and the instruction advances as they act; nothing blocks
play and the tutorial can be dismissed.

**Why this priority**: players who do not understand the goal leave in the first minute.

**Independent Test**: on the tutorial levels 1 … 3 the instruction shown follows the player's actions in the defined
order and never prevents an action.

**Acceptance Scenarios**:

1. **Given** level 1 just opened, **When** the player has taken no action, **Then** the first instruction names the dial
   of the level-1 hint to turn.
2. **Given** a tutorial step is shown, **When** the player performs it, **Then** the next step is shown; dismissing ends the
   tutorial for that level.

### User Story 2 - Ask for a hint, step by step (Priority: P1)

A stuck player asks for a hint: the first hint names which dial to change, the second whether to raise or lower it, the
third the exact value; hints come from the solver, are never wrong and never change anything by themselves.

**Independent Test**: for every certified level and many reachable states, following the exact-value hint shortens the
shortest remaining solution by one.

**Acceptance Scenarios**:

1. **Given** a playing level, **When** the player asks for hints three times, **Then** the dial, the direction and the
   exact value are revealed in that order, each consistent with the previous ones.
2. **Given** a state from which no solution fits in the actions left, **When** a hint is asked, **Then** the hint says so
   and offers undo.

### User Story 3 - Understand a failure (Priority: P1)

When the actions run out, the player sees why the lap is not safe — which obstacle the path touches and where in the lap,
or which checkpoint is not reached in order — in words, and is offered undo or retry, never a generic "Wrong".

**Independent Test**: every failure explanation names the same obstacle and tick, or the same checkpoint, as the
kernel's verdict.

### User Story 4 - Pace and goals across 100 levels (Priority: P2)

Levels are grouped in five bands; finishing a level opens the next; each level shows its goal (actions allowed, the best
possible) and a result (stars for meeting the shortest solution); a daily level is chosen from the local date; a practice
mode allows more actions without affecting progress.

**Independent Test**: the unlock order, star rules, daily choice and practice rules hold for scripted progress.

### Edge Cases

- **A hint asked when no solution fits in the actions left:** the hint says so and offers undo.
- **A hint asked when already won or failed:** no hint; the result is shown instead.
- **A level picked that is not yet open:** refused with the reason; the open level stays.
- **The local date at midnight, time zone changes, a date before 2026:** the daily level is a fixed function of the
  calendar date in the player's calendar; any date maps to a level 1 … 100.
- **Practice mode:** results in practice never award stars or open levels.
- **Pending panel values and hints:** a hint describes the play's dials, not the pending values; pending values are
  dropped by the same outside changes as in feature 314.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0205-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G0205-002**: A hint MUST be available in three progressive levels (dial, direction, exact value), computed from
  the solver for the current dials so that following it keeps a shortest remaining solution; a hint never changes the
  state, is unlimited, does not affect stars and returns to level 1 after any change of the play.
- **FR-R02G0205-003**: A failure MUST be explained in accessible text naming the kernel's verdict (the touched obstacle and
  the lap position of the contact, or the checkpoint not reached in order) with undo and retry offered.
- **FR-R02G0205-004**: Progress MUST follow defined rules: the first level open, solving a level in campaign mode opens the
  next, the catalog's bands shown, a goal (allowance, best possible) and a result (stars) per level.
- **FR-R02G0205-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the allowance without affecting progress.
- **FR-R02G0205-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0205-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (saving to disk is R02-G02-07); existing tests pass; new public names documented; the reference
  regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state, its order.
- **Hint**: level (dial, direction, value), the suggested action, the remaining shortest length.
- **Failure explanation**: the verdict (obstacle and tick, or checkpoint), text.
- **Progress**: solved levels with best action counts and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0205-001**: On levels 1 … 3, scripted players following each instruction win, and every instruction matches
  the state it was shown in.
- **SC-R02G0205-002**: For all 100 certified levels and 2,000 seeded reachable states, every exact hint names an action
  after which the shortest remaining solution is one shorter (or the hint correctly reports no solution within the
  actions left).
- **SC-R02G0205-003**: Every failure explanation in 500 seeded failures names the kernel's verdict exactly.
- **SC-R02G0205-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0205-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test finishes in under
  10 seconds.

## Assumptions

- Saving progress to disk and replay are R02-G02-07; full accessibility polish R02-G02-06; in this feature every
  instruction, hint and failure text is plain text in the panel, read by VoiceOver.
- The teaching text is original; the design is the project's own.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0205-001, 002 |
| Pacing and goals | FR-R02G0205-004 |
| Failure-specific coaching | FR-R02G0205-003 |
| Modes (Play, Practice, Daily-Seed Equivalent) | FR-R02G0205-004, 005 |
| "Meaningful premium content" | superseded: free, all levels included (FR-R02G0205-006) |
| No Stage One breakage | FR-R02G0205-007 |

## Negative Requirements / Excluded scope

- No purchase prompt, advertising, account, streak pressure, network, timed challenge or automatic solving.
