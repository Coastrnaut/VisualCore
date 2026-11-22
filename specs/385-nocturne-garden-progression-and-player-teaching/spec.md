# Feature Specification: R02-G09-05 — Nocturne Garden: progression and player teaching

**Feature Branch**: `385-nocturne-garden-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G09-05 (migration ledger, game feature of experience R02-G09) · ID namespace FR-R02G0905-###,
SC-R02G0905-###, T-R02G0905-###

**Input**: User description: the archived R02-G09-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Nocturne Garden, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/385-nocturne-garden-progression-and-player-teaching`; FR-R02G0905-###,
  SC-R02G0905-###, T-R02G0905-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g09.nocturne-garden` (a registered
  candidate since R02-G09-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Nocturne Garden is free,
  so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock; "content
  count 76" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G09-01 … 04.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
375's answers where the games agree. Facts checked in code (read-only, 2026-11-22): `NocturneGardenSolver` certifies a
level by a bounded depth-first search (20,000 plant evaluations) for a winning sequence of exactly its lower bound L of
moves (a sun move when needed plus plants) from the empty bed; a play fails on a leak beyond the allowance
(`leak(move)`, with the kernel's own reason text naming the move, the action and the cells) or when the moves spent
reach the budget (`budget`); undo works in playing, paused and failed, a won play is final; levels 1 … 3 carry the
tutorial flag; manifest budgets are 8 … 19 and the level's range 1 … 40; the adapter prepares level (seed mod 100) + 1
and snapshots `{level, records}` as schema 1; the core may not read a clock; the other round-two games' daily
multipliers are 37, 41, 43, 47, 53, 59, 61 and 67.

- Q: How is a hint computed and what does each level reveal? → A: the plan comes from the current state. A won play has
  no hint; a failed play's hint is "Undo the last move or retry the level." While playing: the solver's bounded search
  (a new entry point) from the current blooms and sun, looking for the fewest further moves that win within the moves
  left and the supply left: for each total length from 1 up to the moves left: the allowed elevations ascending as the
  certification orders them (the current sun with plants only, another with a sun move first), then the removal of one
  planted bloom (canonical order) followed by those (corrected during implementation, 2026-11-22: the literal order —
  all plants-only lengths before any sun move — spent over the work bound on levels 36, 38 and 40; the fewest moves
  are still found). Its first move is the plan: level 1 names the move ("Plant a rose", "Set the sun to 3 of 4", "Remove bloom 2"),
  level 2 adds the size and sun ("Plant a rose of size 2 under sun 3 of 4"), level 3 adds the exact cell ("… at column
  5, row 1"). When no plan is found within the bound: "No way to match the target was found in the moves left: undo the
  last move or retry the level." Hints never change the state, are unlimited, do not affect stars and reset to level 1
  after any change of the play. "A state that can still win" means one whose plan exists. Impact: FR-R02G0905-002;
  SC-R02G0905-002.
- Q: What does the tutorial show, and when does it advance? → A: on levels 1 … 3, three instructions in order: (1) "Tap
  a cell of the mist to plant a bloom there (or use the panel); its black shadow falls on the mist — a hint shows where"
  — it advances once a move has been accepted; (2) "Drag a bloom to move it, pinch it to resize it, drag the lantern to
  lengthen every shadow; match the gold outline without letting the shadow touch the coral cells" — until a second move
  is accepted or the level ends; (3) "Reach the required match before the moves run out" — until the level ends.
  `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G0905-001; SC-R02G0905-001.
- Q: What are the progress and star rules? → A: stars measure the moves made, undone ones included (the play's action
  records): 3 when at most the certified smallest move count, 2 when at most that + 2, else 1; per level the best
  (fewest) moves made of a won campaign play and its stars, a better result replacing a worse one; level 1 open; a
  campaign win opens the next; `level.select [n]` opens any open level and refuses others (`r02-g09.locked`);
  `level.next` moves to the next open level (refused when none, `r02-g09.locked`); the five bands of 20 are the
  certified difficulty bands. Impact: FR-R02G0905-004; SC-R02G0905-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 71) mod 100 + 1, negative day counts wrapped into 0 … 99 (71 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g09.date`). Daily play follows campaign rules (a daily win records that level's best result and stars) but does not open levels. `mode.practice` replays the
  current level with the budget raised to the kernel's maximum (40); practice results never award stars or open levels;
  `mode.campaign` returns. Impact: FR-R02G0905-005; SC-R02G0905-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 375: progress and
  the mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the snapshot payload becomes schema 2
  (`{level, records, progress, mode, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level,
  campaign mode, tutorial at its first step on tutorial levels). Failures are explained from the failing move: leak
  "Move m (…the action…) leaked the shadow into k forbidden cells; a allowed." (the kernel's reason, sentence-cased);
  budget "The moves ran out: b of b spent with a match of x/y; it needs p/q.", each followed by "Undo the last move or
  retry the level." Impact: FR-R02G0905-003, 007; SC-R02G0905-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — plant a bloom, shape the shadow by moving,
resizing and the sun, match the gold outline without touching the coral cells — each advancing when done, and can
dismiss them.

**Why this priority**: shaping a shadow from flowers is unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help: what to do next (which kind to plant, which
bloom to move or remove, or the sun to set), then with which size and sun, then exactly where, so that the target can
still be matched within the moves left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which the target cannot be matched in the moves left, **When** a hint is asked, **Then** it
   says so and suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After the shadow leaks into the forbidden cells or the move budget runs out the player is told exactly what went wrong
— which move leaked how many cells against the allowance, or how many moves were spent and how the match compares with
the requirement — and offered undo or a retry.

**Independent Test**: every failure explanation names the true reason, move and counts.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
move budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when the target cannot be matched in the moves left:** it says so and never suggests a useless move.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0905-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G0905-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from any state that can still win within the moves left wins within the budget; from a
  state that cannot win it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not
  affect stars and returns to its first level after any change of the play.
- **FR-R02G0905-003**: A failure MUST be explained in accessible text naming the reason (leak or budget), the move
  that leaked with the leaking cells against the allowance, or the moves spent and the match against the requirement,
  with undo and
  retry offered.
- **FR-R02G0905-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G0905-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the move budget without affecting progress.
- **FR-R02G0905-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0905-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested move, why.
- **Failure explanation**: the reason, the move and the cell counts or the moves and the match, as text.
- **Progress**: solved levels with best moves made and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0905-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G0905-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is a legal move, and from every state that can still win following hints wins.
- **SC-R02G0905-003**: Every failure explanation in 500 seeded failures names the true reason, move and counts.
- **SC-R02G0905-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0905-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G09-07; announcements and haptics are R02-G09-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the garden.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0905-001, 002 |
| Pacing (bands, unlocks) | FR-R02G0905-004 |
| Goals and results | FR-R02G0905-004 |
| Meaningful content (all 100 levels, free) | FR-R02G0905-004, 006 |
| Failure explanation | FR-R02G0905-003 |
| Daily and practice modes | FR-R02G0905-005 |
| Schema migration | FR-R02G0905-007 |
| Deterministic tests | SC-R02G0905-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn garden is unchanged); no
  device run before ImplementationLock-100; no availability before X-R02-G09.
