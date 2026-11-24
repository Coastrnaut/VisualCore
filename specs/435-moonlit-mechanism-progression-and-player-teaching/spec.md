# Feature Specification: R02-G14-05 — Moonlit Mechanism: progression and player teaching

**Feature Branch**: `435-moonlit-mechanism-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G14-05 (migration ledger, game feature of experience R02-G14) · ID namespace FR-R02G1405-###,
SC-R02G1405-###, T-R02G1405-###

**Input**: User description: the archived R02-G14-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Moonlit Mechanism, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/435-moonlit-mechanism-progression-and-player-teaching`; FR-R02G1405-###,
  SC-R02G1405-###, T-R02G1405-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g14.moonlit-mechanism` (a registered
  candidate since R02-G14-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Moonlit Mechanism is
  free, so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock;
  "content count 77" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G14-01 … 04.
- **Model:** feature 425 (Acoustic Constellator's progression and teaching) for hints, tutorial, failure text,
  progress, daily and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
425's answers where the games agree. Facts checked in code (read-only, 2026-11-24): `MoonlitMechanismSolver.plan`
certifies a level by the plan vector (net turns, net lamp steps, each gear's net re-seat) of least L1 norm that wins
from the level's starting phases and lamp height, for norms 0 … `maxActions` (6), bounded at 400,000 runs; its witness
actions are the turns, then the re-seats in gear order, then the lamp steps, then one run; every turn, re-seat, lamp
step and run spends 1 action; a run fails `jammed(child)`, `forbidden(frame, cell)`, `missing(frame, count)` or
`stray(frame, count)`, and the last action spent without a win fails `budget(index)` (0-based); undo works in playing
and failed plays, a won play is final; levels 1 … 3 carry the tutorial flag; budgets are 1 … 40; the run report of the
current set-up (`play.report`) says whether a run would win; the adapter prepares level (seed mod 100) + 1, keeps the
shown key frame outside the play and snapshots `{level, records}` as schema 1; the core may not read a clock; the other
round-two games' daily multipliers are 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83 and 89.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play has no hint; a
  failed play's hint is "Undo the last action or retry the level." While playing: the solver's plan is computed from the
  current phases and lamp height through a solver entry that starts from them (`plan(_:phases:height:)`, the certifying
  `plan(_:)` being that entry at the level's starting phases and height). Its first witness action is the hint (turns
  first, then re-seats in gear order, then lamp steps, then the run); the whole plan plus the run must fit the actions
  left, or else, as when the work bound is exceeded or no plan exists: "No way to win was found in the actions left:
  undo the last action or retry the level." Level 1 names the kind ("Turn the handle", "Re-seat a gear", "Move the
  lamp" or "The shadows are ready: run the machine"), level 2 the gear or the way ("Turn the handle forward" / "Work on
  gear 2" / "Raise the lamp" / "Run: tap the lamp"), level 3 the exact action ("Turn the handle forward one tooth" /
  "Re-seat gear 2 by +1" / "Raise the lamp one step" / the same run text). Hints never change the state, are unlimited,
  do not affect stars and reset to level 1 after any change of the play. Impact: FR-R02G1405-002; SC-R02G1405-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), three
  instructions in order: (1) "Drag a gear around (or use Turn − and +) to turn the handle, or double-tap a gear (or
  use Re-seat) to shift it by a tooth: watch its shadow move on the paper" — it advances once a turn, a re-seat or a lamp
  step has been accepted (levels 2 and 3 are solved without a turn, so a re-seat or lamp step must count); (2) "Drag the
  lamp up or down (or use Lamp − and +) to slide the shadows onto their targets — a hint shows which change is next" —
  until the run report of the current set-up wins or the level ends (a change that already makes the set-up win moves
  straight on to the third step; an undo does not move it back); (3) "Tap the lamp (or Run) to run the machine
  through every key frame; if it fails, undo" — until the level ends. `tutorial.dismiss` ends it for that level; undo
  never moves it back. Impact: FR-R02G1405-001; SC-R02G1405-001.
- Q: What are the progress and star rules? → A: stars measure the actions spent by every accepted turn, re-seat, lamp
  step and run record, undone ones included: 3 when at most the certified witness's action count (its turns, re-seats
  and lamp steps plus the run), 2 when at most that + 2, else 1; per level the best (least) actions spent of a won
  campaign play and its stars, a better result replacing a worse one; level 1 open; a campaign win opens the next;
  `level.select [n]` opens any open level and refuses others (`r02-g14.locked`); `level.next` moves to the next open
  level (refused when none, `r02-g14.locked`); the five bands of 20 are the certified difficulty bands. Impact:
  FR-R02G1405-004; SC-R02G1405-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 97) mod 100 + 1, negative day counts wrapped into 0 … 99 (97 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g14.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (40); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1405-005;
  SC-R02G1405-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 425: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the shown key frame stays presentation;
  the snapshot payload becomes schema 2 (`{level, mode, progress, records, tutorial}`) with a migration from schema 1
  (level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels). A failure is
  explained from the failing action, actions numbered from 1 and gears, key frames and cells from 0: a jam — "Action m
  (the run): gear c jammed against its parent, gear p."; a forbidden shadow — "Action m (the run): key frame k cast a
  shadow on forbidden cell x."; missing — "Action m (the run): key frame k missed n target cells."; stray — "Action m
  (the run): key frame k cast n stray cells, more than the a allowed."; the budget — "Action m (a turn of the handle by
  ±1 | a re-seat of gear g by ±1 | a lamp step by ±1 | the run) spent the last action without a win." — each followed
  by "Undo the last action or retry the level." Impact: FR-R02G1405-003, 007; SC-R02G1405-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — turn the handle or re-seat a gear and watch
its shadow move, raise or lower the lamp to slide the shadows onto their targets, run the machine once every key frame
looks right — each advancing when done, and can dismiss them.

**Why this priority**: gear trains, alternating directions and lamp-shifted shadows are unfamiliar; without teaching
the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — what to do next (turn, re-seat, move the
lamp or run), then which gear or which way, then exactly which action — so that the level can still be won within the
actions left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a failed run or running out of actions the player is told exactly what went wrong — which gear jammed against its
parent, which key frame's shadow fell on which forbidden cell, how many target cells a key frame missed or how many
stray cells it cast, or that the actions ran out — and offered undo or a retry.

**Independent Test**: every failure explanation names the true action and numbers.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless action.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason (`r02-g14.locked`, `r02-g14.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1405-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1405-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level wins within its budget; from a state where no win is
  found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not affect stars and
  returns to its first level after any change of the play.
- **FR-R02G1405-003**: A failure MUST be explained in accessible text naming the action that failed and its cause (the
  jammed gear and its parent, the key frame and forbidden cell, the key frame and its missing or stray count, or the last
  action spent without a win), with undo and retry offered.
- **FR-R02G1405-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1405-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1405-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1405-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested turn, re-seat, lamp step or run, why.
- **Failure explanation**: the action that failed, its cause (jammed pair, forbidden cell, missing or stray count,
  budget), as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1405-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1405-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is an action the rules accept.
- **SC-R02G1405-003**: Every failure explanation in 500 seeded failures names the true action and numbers.
- **SC-R02G1405-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1405-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G14-07; announcements, haptics and sound are R02-G14-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the clockwork.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1405-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1405-004 |
| Goals and results | FR-R02G1405-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1405-004, 006 |
| Failure explanation | FR-R02G1405-003 |
| Daily and practice modes | FR-R02G1405-005 |
| Schema migration | FR-R02G1405-007 |
| Deterministic tests | SC-R02G1405-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn clockwork is unchanged); no
  device run before ImplementationLock-100; no availability before X-R02-G14.
