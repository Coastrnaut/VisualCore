# Feature Specification: R02-G06-05 — Chrono Constellator: progression and player teaching

**Feature Branch**: `355-chrono-constellator-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G06-05 (migration ledger, game feature of experience R02-G06) · ID namespace FR-R02G0605-###,
SC-R02G0605-###, T-R02G0605-###

**Input**: User description: the archived R02-G06-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Chrono Constellator, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/355-chrono-constellator-progression-and-player-teaching`; FR-R02G0605-###,
  SC-R02G0605-###, T-R02G0605-###.
- **Packaging (ADR-0009):** experience R02-G06 (`r02-g06.chrono-constellator`, free, a registered candidate) in
  `Packages/ExperiencesRound02/ChronoConstellator`; this feature extends its Core, adapter and experience target.
- **Superseded parts of the source prompt:** price, "no IAP", "meaningful premium content" as paid content (every level
  of this free experience is free; "meaningful content" means all 100 certified levels in five difficulty bands with
  goals and results), the "content count 78" milestone figure and the Round 2 lock. **Device-only items:** none.
  **Owner-only items:** none.
- **Model:** feature 345 (Colorfall Canyons's progression and player teaching) and feature 335 (Hue Compass's).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
345's answers where the games agree. Facts checked in code (read-only, 2026-11-21): `ChronoConstellatorSolver.solve`
certifies a phase-only timeline of the smallest edit count from a level's default phases (the m* lower bound, nil when
every window is blocked or the default already aligns); `ChronoConstellatorGenerator.winTick(_:timeline:)` replays a
timeline to its win tick or nil; edits in use are the stars whose phase differs from the level's default plus the holds,
within the budget (1 … 20, the kernel's maximum is 20); edits are accepted only at tick 0, `time.rewind` returns to tick
0 keeping the timeline (also from failed), every action can be undone and redone and a won play is final; levels 1 … 3
carry the tutorial flag; the adapter prepares level (seed mod 100) + 1 and snapshots `{level, records}` as schema 1; the
core may not read a clock.

- Q: How is a hint computed and what does each level reveal? → A: the plan comes from the current state. A won play has
  no hint; a failed play's hint is "Undo the last change, rewind or retry the level." While playing or paused: if the
  current timeline wins (a replay from tick 0 reaches a win tick), the plan is to run — at tick 0 or later: level 1
  "Replay the timeline", level 2 "Run to the end", level 3 "Run: N ticks" (the ticks to the win tick from the current
  tick). Otherwise, after tick 0 the plan is to rewind (every level: "Rewind to tick 0 to change the timeline"). At tick
  0, if the timeline has holds, the plan removes the first hold (star order, then start): level 1 "Remove a hold", level
  2 "Remove star k's hold", level 3 "Remove star k's hold from tick s"; without holds, the solver runs on the level with
  the current phases as its defaults and its phase changes are the plan, accepted only if the edits in use afterwards
  stay within the budget and the resulting timeline wins: level 1 "Change a star's start", level 2 "Change the start of
  star k (shape)", level 3 "Start star k (shape) at row r, column c (phase p)" — the first change in star order. When
  no plan exists: "No win is reachable from here: undo the last change, rewind or retry the level." Hints never change
  the state, are unlimited, do not affect stars and reset to level 1 after any change of the play. "A state that can
  still win" means one whose plan exists. Impact: FR-R02G0605-002; SC-R02G0605-002.
- Q: What does the tutorial show, and when does it advance? → A: on levels 1 … 3, three instructions in order: (1)
  "Drag a star along its silver loop (or use Phase − and +) to change where it starts, until every star can meet its
  target on the same tick; a hint shows which" — it advances once a phase change has been accepted and the current
  timeline wins; (2) "Replay with Step or Run and watch the ribbons" — until a step is accepted; (3) "Every star must
  stand on its own target on the same tick without two stars meeting; undo or rewind a change that makes them collide"
  — until the level ends. `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G0605-001;
  SC-R02G0605-001.
- Q: What are the progress and star rules? → A: as feature 345 with edits in use at the win: per level the best (fewest)
  edits of a won campaign play and the stars (3 when at most the certified smallest edit count, 2 when at most that + 2,
  else 1; a better result replaces a worse one); level 1 open; a campaign win opens the next; `level.select [n]` opens
  any open level and refuses others (`r02-g06.locked`); `level.next` moves to the next open level (refused when none,
  `r02-g06.locked`); the five bands of 20 are the certified difficulty bands. Impact: FR-R02G0605-004; SC-R02G0605-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 59) mod 100 + 1, negative day counts wrapped into 0 … 99 (59 is coprime with 100 and differs from the other
  round-two games' 37, 41, 43, 47 and 53); the date reaches the core as `mode.daily [year, month, day]` (an impossible
  date is refused with `r02-g06.date`). Daily play follows campaign rules but does not open levels. `mode.practice`
  replays the current level with the budget raised to the kernel's maximum (20); practice results never award stars or
  open levels; `mode.campaign` returns. Impact: FR-R02G0605-005; SC-R02G0605-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 345: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter); the snapshot payload becomes schema 2 (`{level, records, progress,
  mode, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level, campaign mode, tutorial at its
  first step on tutorial levels). Failures are explained from the failing tick: collision "Star a (shape) and star b
  (shape) met at row r, column c on tick T."; time "Time ran out at tick T: <stars off target, as "star k (shape) is at
  row r, column c, its target is row r′, column c′", joined by "; ">.", each followed by "Undo the last change, rewind
  or retry the level." Impact: FR-R02G0605-003, 007; SC-R02G0605-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — move a star's start, replay the timeline, line
every star up on its target on the same tick — each advancing when done, and can dismiss them.

**Why this priority**: replaying a timeline to align moving stars is unfamiliar; without teaching the first levels are
guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help: what to change, which star, and exactly which
start phase (or rewind and run) makes every star meet its target on the same tick.

**Independent Test**: on every certified level, following exact hints from the start wins within the edit budget and
tick limit.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win is reachable, **When** a hint is asked, **Then** it says so and suggests undo,
   rewind or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a collision or running out of time the player is told exactly what went wrong — which stars met on which cell at
which tick, or which stars were off their targets — and offered undo, rewind or a retry.

**Independent Test**: every failure explanation names the true stars, cell and tick of the failure.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
edit budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo, rewind or retry.
- **A hint during a replay (tick above 0):** it suggests rewinding first when the timeline needs a change, or running on
  when the current timeline already wins.
- **A hint when no win is reachable from the current state:** it says so, never suggests a useless action.
- **A locked level or an impossible date:** refused with a named reason.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0605-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G0605-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from any state that can still win (a run, a rewind, a hold removal or a certified set of
  phase changes within the budget wins) wins within the budget and tick limit; from a state that
  cannot win it says so and suggests undo, rewind or retry. A hint never changes the state, is unlimited, does not affect
  stars and returns to its first level after any change of the play.
- **FR-R02G0605-003**: A failure MUST be explained in accessible text naming the reason (collision or time), the stars,
  the cell or the stars off target, and the tick, with undo, rewind and retry offered.
- **FR-R02G0605-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G0605-005**: A daily level MUST be a deterministic function of the local calendar date ((days since
  2026-01-01 × 59) mod 100 + 1); a practice mode MUST raise the edit budget to 20 (the kernel's maximum) without
  affecting progress.
- **FR-R02G0605-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0605-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested action, why.
- **Failure explanation**: the reason, the stars, the cell or targets, the tick, as text.
- **Progress**: solved levels with best edits used and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0605-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G0605-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is a legal action, and from every state that can still win following hints wins.
- **SC-R02G0605-003**: Every failure explanation in 500 seeded failures names the true reason, stars, cell and tick.
- **SC-R02G0605-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0605-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G06-07; announcements and haptics are R02-G06-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the sky.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0605-001, 002 |
| Pacing (bands, unlocks) | FR-R02G0605-004 |
| Goals and results | FR-R02G0605-004 |
| Meaningful content (all 100 levels, free) | FR-R02G0605-004, 006 |
| Failure explanation | FR-R02G0605-003 |
| Daily and practice modes | FR-R02G0605-005 |
| Schema migration | FR-R02G0605-007 |
| Deterministic tests | SC-R02G0605-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn sky is unchanged); no device
  run before ImplementationLock-100; no availability before X-R02-G06.
