# Feature Specification: R02-G17-05 — Celestial Eclipse Lab: progression and player teaching

**Feature Branch**: `465-celestial-eclipse-lab-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G17-05 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1705-###,
SC-R02G1705-###, T-R02G1705-###

**Input**: User description: the archived R02-G17-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Celestial Eclipse Lab, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/465-celestial-eclipse-lab-progression-and-player-teaching`; FR-R02G1705-###,
  SC-R02G1705-###, T-R02G1705-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g17.celestial-eclipse-lab` (a
  registered candidate since R02-G17-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Celestial Eclipse Lab is
  free, so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock;
  "content count 74" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G17-01 … 04.
- **Model:** feature 455 (Starlit Cartouche's progression and teaching) for hints, tutorial, failure text, progress,
  daily and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
455's answers where the games agree. Facts checked in code (read-only, 2026-11-25): `CelestialEclipseLabSolver.plan`
certifies a level by searching phase settings by the number of changed movable bodies from the level's starting phases
(subsets, then phases, in lexicographic order; at most 5 changes and 60,000 settings judged); a plan is its list of
`.phase(body, offset)` actions in body order, followed by the run; every phase change spends 1 action and the run spends
none; the run ends the level won, or failed with `unwanted(front, back, tick)`, `window(front, back, tick, open,
close)` or `horizon(front, back, open, close)`, all deterministic; undo works in playing and failed plays, a won play is
final; levels 1 … 3 carry the tutorial flag; budgets are 8 … 19 in the catalog (1 … 24 allowed); the adapter prepares
level (seed mod 100) + 1, keeps the chosen body and shown tick outside the play and snapshots `{level, records}` as
schema 1; the core may not read a clock; the other round-two games' daily multipliers are 31, 37, 41, 43, 47, 53, 59,
61, 67, 71, 73, 79, 83, 89 and 97.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play has no hint; a
  failed play's hint is "Undo the last action or retry the level." While playing: when the current phases already win,
  the hint is "The eclipses are in order: run the clock"; otherwise the solver searches from the current phases through
  a solver entry that starts from them (`plan(_:from:)`, the certifying `plan(_:)` being that entry at the level's
  starting phases) within min(actions left, 5) changes; its first change (b, p) is the hint; when no plan is found
  (none, or the work bound exceeded): "No way to win was found in the actions left: undo the last action or retry the
  level." Level 1 names the planet ("Move planet b next"), level 2 the way and distance ("Move planet b k steps forward"
  or "back", the shorter way around its orbit, forward on a tie), level 3 the exact change ("Set planet b to phase p").
  Hints never change the state, are unlimited, do not affect stars and reset to level 1 after any change of the play.
  Impact: FR-R02G1705-002; SC-R02G1705-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), three
  instructions in order: (1) "Drag a planet along its orbit (or use Phase − and + and Set phase) to change when it
  passes the others; the timeline below the sky shows the eclipses that would follow" — it advances once a phase change
  has been accepted; (2) "Make the target eclipses happen in order, each inside its bracket, then press Run — a hint
  shows which planet to move" — it advances once a second phase change has been accepted or the level ends; (3) "Any
  other eclipse first, or a target outside its window, fails the run: undo and change a phase" — until the level ends.
  `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G1705-001; SC-R02G1705-001.
- Q: What are the progress and star rules? → A: stars measure the actions spent by every accepted phase-change record,
  undone ones included: 3 when at most the certified witness's change count, 2 when at most that + 2, else 1; per level
  the best (least) actions spent of a won campaign play and its stars, a better result replacing a worse one; level 1
  open; a campaign win opens the next; `level.select [n]` opens any open level and refuses others (`r02-g17.locked`);
  `level.next` moves to the next open level (refused when none, `r02-g17.locked`); the five bands of 20 are the
  certified difficulty bands. Impact: FR-R02G1705-004; SC-R02G1705-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 29) mod 100 + 1, negative day counts wrapped into 0 … 99 (29 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g17.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (24); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1705-005;
  SC-R02G1705-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 455: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the chosen body, shown tick and pending
  phase stay presentation; the snapshot payload becomes schema 2 (`{level, mode, progress, records, tutorial}`) with a
  migration from schema 1 (level 1 open plus the restored level, campaign mode, tutorial at its first step on tutorial
  levels). A failure is explained from the run's failure, targets numbered from 1 and planets by index: an unwanted
  eclipse — "The run met an unwanted eclipse first: planet f in front of planet b at tick t, before target k (planet f′
  in front of planet b′)."; a window — "Target k (planet f in front of planet b) began at tick t, outside its window
  from tick o to tick c."; the horizon — "The clock reached tick h before target k (planet f in front of planet b,
  window o … c) happened." (h the last tick, horizon − 1) — each followed by "Undo the last action or retry the
  level." Impact: FR-R02G1705-003, 007; SC-R02G1705-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — move a planet along its orbit to change when it
passes the others, watch the timeline of predicted eclipses, run the clock when the target eclipses come in order — each
advancing when done, and can dismiss them.

**Why this priority**: phasing orbits to order eclipses is unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which planet to move next, then which way and
how far, then exactly which phase — so that the level can still be won within the actions left.

**Why this priority**: the search over phases is hard to do in the head; a hint keeps the player moving.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only and then runs the clock,
   **Then** the level is won.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a run that met an unwanted eclipse first, a target eclipse outside its window, or the horizon before the sequence
was complete, the player is told exactly what went wrong — which planets, which target and at which tick — and offered
undo or a retry.

**Why this priority**: the failure happens on the clock; without words the player cannot see what to change.

**Independent Test**: every failure explanation names the true planets, target and ticks.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Why this priority**: pacing across 100 levels and a reason to return.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless phase change.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason (`r02-g17.locked`, `r02-g17.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1705-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1705-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level, then running the clock, wins within its budget;
  from a state where no win is found it says so and suggests undo or retry. A hint never changes the state, is
  unlimited, does not affect stars and returns to its first level after any change of the play.
- **FR-R02G1705-003**: A failure MUST be explained in accessible text naming its cause (the unwanted eclipse's planets
  and tick and the target it came before; the target, its tick and window; or the horizon and the target left), with
  undo and retry offered.
- **FR-R02G1705-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1705-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1705-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1705-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested phase change (planet and offset), why.
- **Failure explanation**: the cause (an unwanted eclipse, a target outside its window, or the horizon) with the
  planets, target and ticks, as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice,
  daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1705-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1705-002**: For all 100 certified levels, following exact hints from the start and then running the clock
  wins; for 200 seeded reachable states every exact hint is a phase change the rules accept.
- **SC-R02G1705-003**: Every failure explanation in 500 seeded failures names the true planets, target and ticks.
- **SC-R02G1705-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1705-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G17-07; announcements, haptics and sound are R02-G17-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the sky.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1705-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1705-004 |
| Goals and results | FR-R02G1705-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1705-004, 006 |
| Failure explanation | FR-R02G1705-003 |
| Daily and practice modes | FR-R02G1705-005 |
| Schema migration | FR-R02G1705-007 |
| Deterministic tests | SC-R02G1705-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn sky is unchanged); no device
  run before ImplementationLock-100; no availability before X-R02-G17.
