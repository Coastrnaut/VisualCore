# Feature Specification: R02-G16-05 — Starlit Cartouche: progression and player teaching

**Feature Branch**: `455-starlit-cartouche-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G16-05 (migration ledger, game feature of experience R02-G16) · ID namespace FR-R02G1605-###,
SC-R02G1605-###, T-R02G1605-###

**Input**: User description: the archived R02-G16-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Starlit Cartouche, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/455-starlit-cartouche-progression-and-player-teaching`; FR-R02G1605-###,
  SC-R02G1605-###, T-R02G1605-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g16.starlit-cartouche` (a registered
  candidate since R02-G16-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Starlit Cartouche is
  free, so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock;
  "content count 80" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G16-01 … 04.
- **Model:** feature 445 (Voxel Origami's progression and teaching) for hints, tutorial, failure text, progress, daily
  and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
445's answers where the games agree. Facts checked in code (read-only, 2026-11-24): `StarlitCartoucheSolver.plan`
certifies a level by a breadth-first search over (star, beat, strokes drawn) states from the start star at beat 0,
corridors by index from the ship's star then waits 0 … 8, filtering each leg through the chart, for at most 7 legs and
300,000 legs tried; a plan is its list of `.leg(star, wait)` actions; every leg spends 1 action and the play is won the
moment every stroke of the symbol is drawn with the ship at the beacon; a leg fails `departure(star, beat, close)`,
`hazard(corridor, hazard, from, to)`, `arrival(star, beat, open, close)`, `deadline(beat, deadline)` or
`stroke(corridor)`, and the last action spent without a win fails `budget(spent)`; undo works in playing and failed
plays, a won play is final; levels 1 … 3 carry the tutorial flag; budgets are 8 … 19 in the catalog (1 … 24 allowed);
the adapter prepares level (seed mod 100) + 1, keeps the chosen destination and wait outside the play and snapshots
`{level, records}` as schema 1; the core may not read a clock; the other round-two games' daily multipliers are 31, 41,
43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and 97.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play has no hint; a
  failed play's hint is "Undo the last action or retry the level." While playing: the solver's plan is computed from the
  current star, beat and drawn strokes through a solver entry that starts from them (`plan(_:from:)`, the certifying
  `plan(_:)` being that entry at the start star, beat 0 and no strokes); its first leg (j, w) is the hint; the whole
  plan must fit the actions left, or else, as when the work bound is exceeded or no plan exists: "No way to win was
  found in the actions left: undo the last action or retry the level." Level 1 names the stroke ("The next leg flies
  corridor c, between star a and star b"), level 2 the destination ("Fly to star j"), level 3 the exact leg ("Fly to
  star j after waiting w beats"). Hints never change the state, are unlimited, do not affect stars and reset to level 1
  after any change of the play. Impact: FR-R02G1605-002; SC-R02G1605-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), three
  instructions in order: (1) "Tap a star to choose where to fly, set the wait on the slider (or Wait − and +) so the
  star is in range at launch, then double-tap it (or press Fly): the trail draws a stroke of the symbol" — it advances
  once a leg has been accepted; (2) "Draw every stroke of the symbol and end at the beacon ring before the deadline — a
  hint shows which leg is next" — it advances once a second leg has been accepted or the level ends (a leg that wins
  ends the level); (3) "A leg that misses a star's window, crosses an active hazard tube, arrives after the deadline or
  flies a corridor outside the symbol fails the level: undo and choose another star or wait" — until the level ends.
  `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G1605-001; SC-R02G1605-001.
- Q: What are the progress and star rules? → A: stars measure the actions spent by every accepted leg record, undone
  ones included: 3 when at most the certified witness's leg count, 2 when at most that + 2, else 1; per level the best
  (least) actions spent of a won campaign play and its stars, a better result replacing a worse one; level 1 open; a
  campaign win opens the next; `level.select [n]` opens any open level and refuses others (`r02-g16.locked`);
  `level.next` moves to the next open level (refused when none, `r02-g16.locked`); the five bands of 20 are the
  certified difficulty bands. Impact: FR-R02G1605-004; SC-R02G1605-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 37) mod 100 + 1, negative day counts wrapped into 0 … 99 (37 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g16.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (24); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1605-005;
  SC-R02G1605-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 445: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the chosen destination and wait stay
  presentation; the snapshot payload becomes schema 2 (`{level, mode, progress, records, tutorial}`) with a migration
  from schema 1 (level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels). A
  failure is explained from the failing action, actions numbered from 1, stars, corridors and hazards by index: a
  departure — "Action m (a leg to star j after w beats) leaves star i at beat t, after its window closed at beat c."; a
  hazard — "Action m (a leg to star j after w beats) flies corridor k through hazard h, active from beat a to beat b.";
  an arrival — "Action m (a leg to star j after w beats) reaches star j at beat t, outside its window from beat o to
  beat c."; the deadline — "Action m (a leg to star j after w beats) arrives at beat t, after the deadline at beat d.";
  a stray stroke — "Action m (a leg to star j after w beats) flies corridor k, which is not part of the symbol."; the
  budget — "Action m (a leg to star j after w beats) spent the last action without completing the symbol at the beacon."
  — each followed by "Undo the last action or retry the level." Impact: FR-R02G1605-003, 007; SC-R02G1605-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — choose a star to fly to, time the launch with
the slider until the star is in range, fly the leg so its trail draws a stroke of the symbol, and keep clear of hazard
tubes and star windows — each advancing when done, and can dismiss them.

**Why this priority**: flying between moving stars on beats is unfamiliar; without teaching the first levels are
guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which stroke of the symbol to draw next, then
which star to fly to, then exactly which star and how many beats to wait — so that the level can still be won within
the actions left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a leg that leaves a star outside its window, crosses an active hazard tube, arrives after the deadline or flies a
corridor that is not part of the symbol, or after running out of actions, the player is told exactly what went wrong —
which leg, which star, hazard or corridor, and at which beat — and offered undo or a retry.

**Independent Test**: every failure explanation names the true leg, the star, hazard or corridor, and the beats.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless leg.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason (`r02-g16.locked`, `r02-g16.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1605-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1605-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level wins within its budget; from a state where no win
  is found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not affect stars
  and returns to its first level after any change of the play.
- **FR-R02G1605-003**: A failure MUST be explained in accessible text naming the leg that failed and its cause (the star
  and its window for a departure or arrival, the hazard and its beats, the deadline, the stray corridor, or the last
  action spent without a win), with undo and retry offered.
- **FR-R02G1605-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1605-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1605-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1605-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested leg (destination and wait), why.
- **Failure explanation**: the leg that failed, its cause (a window, a hazard, the deadline, a stray stroke, or the
  budget) with the stars, hazard, corridor and beats, as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice,
  daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1605-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1605-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is a leg the rules accept.
- **SC-R02G1605-003**: Every failure explanation in 500 seeded failures names the true leg, star, hazard or corridor
  and beats.
- **SC-R02G1605-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1605-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G16-07; announcements, haptics and sound are R02-G16-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the chart.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1605-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1605-004 |
| Goals and results | FR-R02G1605-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1605-004, 006 |
| Failure explanation | FR-R02G1605-003 |
| Daily and practice modes | FR-R02G1605-005 |
| Schema migration | FR-R02G1605-007 |
| Deterministic tests | SC-R02G1605-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn chart is unchanged); no device
  run before ImplementationLock-100; no availability before X-R02-G16.
