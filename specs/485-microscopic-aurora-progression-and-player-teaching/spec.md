# Feature Specification: R02-G19-05 — Microscopic Aurora: progression and player teaching

**Feature Branch**: `485-microscopic-aurora-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G19-05 (migration ledger, game feature of experience R02-G19) · ID namespace FR-R02G1905-###,
SC-R02G1905-###, T-R02G1905-###

**Input**: User description: the archived R02-G19-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Microscopic Aurora, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/485-microscopic-aurora-progression-and-player-teaching`; FR-R02G1905-###,
  SC-R02G1905-###, T-R02G1905-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g19.microscopic-aurora` (a registered
  candidate since R02-G19-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Microscopic Aurora is
  free, so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock;
  "content count 82" (the 100 certified levels stand); the paths `Apps/MicroscopicAurora` and
  `Packages/GameModules/MicroscopicAuroraCore` (the experience lives in `Packages/ExperiencesRound02/MicroscopicAurora`).
  **Device-only items:** none beyond the round's device campaign. **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G19-01 … 04.
- **Model:** feature 475 (Apsides Workshop's progression and teaching): hints from the current state, tutorial,
  failure text, progress and stars, daily and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
475's answers where the games agree. Facts checked in code (read-only, 2026-11-26): a report depends only on the set of
wells (`MicroscopicAuroraDish.report(level, wells:)`); `MicroscopicAuroraSolver.plan` certifies a level with sites and no
starting well by judging every set of 0, 1, 2 … wells on distinct sites (strengths 1 … 4, two senses), at most 1,200
sets judged; the certified witnesses are 1 or 2 placements followed by the play; `place(slot:well:)` and `remove(slot:)`
each spend 1 action, the play none, and placements off the level's sites are refused ("not a site"); the play ends the
level won, or failed with `exit(swimmer, tick)`, `coherence(tick, group)`, `coverage(lit, needed)` or
`connectedness(cell)`, all deterministic; undo works in playing, paused and failed plays, a won play is final; levels
1 … 3 carry the tutorial flag; catalog budgets are 8 … 19 (1 … 24 allowed); levels have 3 … 6 sites; the adapter
prepares level (seed mod 100) + 1, keeps the shown tick, the freeze, the preview and the orbit outside the play and
snapshots `{level, records}` as schema 1; the core may not read a clock; the other round-two games' daily multipliers
are 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and 97.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play has no hint; a
  failed play's hint is "Undo the last action or retry the level." While playing: when the current wells already win,
  the hint is "The trails already cover the stencil as one pattern: play the swim"; otherwise a bounded search from the
  current wells looks for a winning set of wells reachable within min(actions left, 2) actions, where an action places a
  well on a site no other well holds (into the first free slot, or replacing a slot's well) or takes a slot's well away;
  one action is tried before two; the certified witness's next placement is tried first whenever the current wells are
  a subset of the witness's wells (so exact hints from a level's start replay its witness), then removals by slot, then
  placements by slot, site, strength 1 … 4 and sense (clockwise first); at most 1,200 sets judged. The first action of
  the found sequence is the hint; when none is found: "No way to win was found in the actions left: undo the last
  action or retry the level." Level 1 names the site or the well ("Use the site at row r, column c next" or "Take well
  n away"); level 2 adds the sense ("Place a clockwise (or counterclockwise) well at the site at row r, column c");
  level 3 the exact well ("Place well n at row r, column c with strength s, turning clockwise" or "counterclockwise";
  "Take well n away"). Hints never change the state, are unlimited, do not affect stars and reset to level 1 after any
  change of the play. Impact: FR-R02G1905-002; SC-R02G1905-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), three
  instructions in order: (1) "Tap a marked site (or choose a site and press Place) to put a magnetic well there; the
  trails and gauges show the new swim" — it advances once a placement has been accepted; (2) "Light every stencil cell
  with the trails as one joined pattern, then press Play — a hint shows which site to use" — it advances once a second
  action has been accepted or the level ends; (3) "A swimmer leaving the dish, the swarm splitting, too few lit cells or
  a lit cell cut off from the pattern fails the swim: undo and try another well" — until the level ends.
  `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G1905-001; SC-R02G1905-001.
- Q: What are the progress and star rules? → A: stars measure the actions spent by every accepted placement and removal
  record, undone ones included: 3 when at most the certified witness's placement count, 2 when at most that + 2, else 1;
  per level the best (least) actions spent of a won campaign play and its stars, a better result replacing a worse one;
  level 1 open; a campaign win opens the next; `level.select [n]` opens any open level and refuses others
  (`r02-g19.locked`); `level.next` moves to the next open level (refused when none, `r02-g19.locked`); the five bands of
  20 are the certified difficulty bands. Impact: FR-R02G1905-004; SC-R02G1905-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 19) mod 100 + 1, negative day counts wrapped into 0 … 99 (19 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g19.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (24); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1905-005;
  SC-R02G1905-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 475: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the shown tick, the freeze, a drag's
  preview and the orbit stay presentation; the snapshot payload becomes schema 2 (`{level, mode, progress, records,
  tutorial}`) with a migration from schema 1 (level 1 open plus the restored level, campaign mode, tutorial at its first
  step on tutorial levels). A failure is explained from the play's failure, swimmers numbered from 1 and cells in the
  level's words ("the cell at row r, column c"): an exit — "Swimmer s left the dish at tick t."; a split — "The swarm
  split at tick t: its largest group had g swimmers, fewer than the n needed."; coverage — "Only l stencil cells were
  lit; n were needed."; a cut-off cell — "The cell at row r, column c is lit but not joined to the pattern." — each
  followed by "Undo the last action or retry the level." Impact: FR-R02G1905-003, 007; SC-R02G1905-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — place a magnetic well on a marked site, watch
the trails and gauges change, then play the swim when the trails cover the stencil as one pattern — each advancing when
done, and can dismiss them.

**Why this priority**: steering a swarm by curl wells is unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which site to use next (or which well to
take away), then the turning sense, then the exact well (site, strength and sense) — so that the level can still be won
within the actions left.

**Why this priority**: predicting how a well bends a swarm's trails is hard to do in the head; a hint keeps the player
moving.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only and then plays the swim,
   **Then** the level is won.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a swim in which a swimmer left the dish, the swarm split apart, too few stencil cells were lit or a lit cell was
cut off from the pattern, the player is told exactly what went wrong — which swimmer, at which tick, how large the
largest group was, how many cells were lit of how many needed, or which cell — and offered undo or a retry.

**Why this priority**: the failure happens during the swim; without words the player cannot see what to change.

**Independent Test**: every failure explanation names the true swimmer, tick, group size, counts or cell.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Why this priority**: pacing across 100 levels and a reason to return.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when the current wells already win:** it says to play the swim.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless well.
- **A hint search that would run long:** bounded by a fixed work limit; it never stalls the frame.
- **A hint when every slot is used:** it may suggest taking a well away or moving one.
- **A locked level or an impossible date:** refused with a named reason (`r02-g19.locked`, `r02-g19.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1905-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1905-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level, then playing the swim, wins within its budget;
  from a state where no win is found it says so and suggests undo or retry. A hint never changes the state, is
  unlimited, does not affect stars and returns to its first level after any change of the play.
- **FR-R02G1905-003**: A failure MUST be explained in accessible text naming its cause (the swimmer that left the dish
  and the tick; the tick the swarm split and its largest group; the stencil cells lit and needed; or the lit cell cut
  off from the pattern), with undo and retry offered.
- **FR-R02G1905-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1905-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1905-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1905-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); refusals carry named reason codes; existing tests pass; new public names documented;
  the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested action (a well placed on a site with a strength and sense, or a well taken away), why.
- **Failure explanation**: the cause (an exit, a split, too little coverage, a cut-off cell) with the swimmer, tick,
  group size, counts or cell, as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice,
  daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1905-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1905-002**: For all 100 certified levels, following exact hints from the start and then playing the swim
  wins; for 200 seeded reachable states every exact hint is an action the rules accept.
- **SC-R02G1905-003**: Every failure explanation in 500 seeded failures names the true swimmer, tick, group size, counts
  or cell.
- **SC-R02G1905-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1905-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G19-07; announcements, haptics and sound are R02-G19-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the dish.
- Observability: refused progression actions are logged by reason code, as the presenter already logs refusals.
- Accessibility: every new text is plain, ordered and available to VoiceOver as panel text; nothing relies on colour.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1905-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1905-004 |
| Goals and results | FR-R02G1905-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1905-004, 006 |
| Failure explanation | FR-R02G1905-003 |
| Daily and practice modes | FR-R02G1905-005 |
| Schema migration | FR-R02G1905-007 |
| Deterministic tests | SC-R02G1905-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn dish is unchanged); no device
  run before ImplementationLock-100; no availability before X-R02-G19.
