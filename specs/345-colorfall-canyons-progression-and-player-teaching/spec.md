# Feature Specification: R02-G05-05 — Colorfall Canyons: progression and player teaching

**Feature Branch**: `345-colorfall-canyons-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G05-05 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0505-###,
SC-R02G0505-###, T-R02G0505-###

**Input**: User description: the archived R02-G05-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Colorfall Canyons, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/345-colorfall-canyons-progression-and-player-teaching`; FR-R02G0505-###,
  SC-R02G0505-###, T-R02G0505-###.
- **Packaging (ADR-0009):** experience R02-G05 (`r02-g05.colorfall-canyons`, free, a registered candidate) in
  `Packages/ExperiencesRound02/ColorfallCanyons`; this feature extends its Core, adapter and experience target.
- **Superseded parts of the source prompt:** price, "no IAP", "meaningful premium content" as paid content (every level
  of this free experience is free; "meaningful content" means all 100 certified levels in five difficulty bands with
  goals and results) and the Round 2 lock. **Device-only items:** none. **Owner-only items:** none.
- **Model:** feature 335 (Hue Compass's progression and player teaching) and feature 325 (Wave Knot Keeper's).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
335's answers where the games agree. Facts checked in code (read-only, 2026-11-21): `ColorfallCanyonsSolver` finds a
smallest winning edit set (carves of carvable cells, each valve toggled at most once) of at most 3 edits applied before
the first tick and runs to the verdict with exact conservation; every accepted action (carve, valve, step) spends from
the level's budget (1 … 30) except steps, and every action can be undone and redone, including the one that failed the
play; levels 1 … 3 carry the tutorial flag; the adapter prepares level (seed mod 100) + 1, accepts `canyon.carve`,
`canyon.valve`, `time.step`, `play.undo`, `play.redo` and `level.next` (100 wraps to 1) and snapshots `{level, records}`
as schema 1; the core may not read a clock.

- Q: How is a hint computed and what does each level reveal? → A: from the current state (heights, fluid, valves, tick
  and actions left), the hint searches edit sets applied now, of size 0, 1, 2 … up to min(actions left, 3), in the
  solver's order, each run from the current fluid to the verdict; the first winning set is the plan. An empty plan
  means "let it run": level 1 "Let the fluid run", level 2 "Run to the end", level 3 "Run: N ticks" (the ticks left). A
  plan whose first edit is a carve: level 1 "Carve a channel", level 2 "Carve near row r", level 3 "Carve row r, column c";
  a valve: level 1 "Switch a valve", level 2 "Switch the <colour> spring", level 3 "Open (or close) the <colour> valve".
  When no set wins: "No win is reachable from here: undo the last change or retry the level." Hints never change the
  state, are unlimited, do not affect stars and reset to level 1 after any change of the play; they are given while
  playing or paused; a failed play's hint is the undo-or-retry text; a won level has none.
  "A state that can still win" means one whose plan exists. Impact: FR-R02G0505-002; SC-R02G0505-002.
- Q: What does the tutorial show, and when does it advance? → A: on levels 1 … 3, three instructions in order: (1)
  "Drag across a sandstone cell (or use Carve) to cut a channel, and tap a spring (or its valve button) to open or close
  it, until the fluid will reach the right basins; a hint shows how" — it advances once an edit has been accepted and the
  current plan is empty; (2) "Let the fluid run with Step or Run and watch the basins fill" — until a step is accepted;
  (3) "Fill every basin with its colours without overflow; undo any change that sends a wrong colour in" — until the
  level ends. `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G0505-001;
  SC-R02G0505-001.
- Q: What are the progress and star rules? → A: as feature 335 with actions spent (carves and valve toggles): per level
  the best (fewest) actions spent in a won campaign play and the stars (3 when at most the certified smallest edit
  count, 2 when at most that + 2, else 1; a better result replaces a worse one); level 1 open; a campaign win opens the
  next; `level.select [n]` opens any open level and refuses others (`r02-g05.locked`); `level.next` moves to the next
  open level (refused when none, `r02-g05.locked`); the five bands of 20 are the certified difficulty bands.
  Impact: FR-R02G0505-004; SC-R02G0505-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 53) mod 100 + 1, negative day counts wrapped into 0 … 99 (53 is coprime with 100 and differs from the other
  round-two games' 37, 41, 43 and 47); the date reaches the core as `mode.daily [year, month, day]` (an impossible date
  is refused with `r02-g05.date`). Daily play follows campaign rules but does not open levels. `mode.practice` replays
  the current level with the budget raised to the kernel's maximum (30); practice results never award stars or open
  levels; `mode.campaign` returns. Impact: FR-R02G0505-005; SC-R02G0505-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 335: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter); the snapshot payload becomes schema 2 (`{level, records, progress,
  mode, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level, campaign mode, tutorial at its
  first step on tutorial levels). Failures are explained from the failing tick: contamination "Basin k (row r, column c)
  took n units of <colour>; it allows at most m."; overflow "Basin k overflowed: v units, its capacity is c."; time "Time
  ran out at tick T: basin k holds <amounts>; it needs <target>." (the first unfilled basin; amounts as "cyan a,
  coral b, yellow c", the target as the basin's description), each followed by "Undo the
  last change or retry the level." Impact: FR-R02G0505-003, 007; SC-R02G0505-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — carve a channel, open a valve, let the fluid
run, read the basins — each advancing when done, and can dismiss them.

**Why this priority**: the fluid rules are unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on levels 1 … 3 win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help: what to do next, where, and exactly which
carve, valve or run makes the basins fill correctly.

**Why this priority**: a player who cannot see why fluid goes astray needs a way forward without quitting.

**Independent Test**: on every certified level, following exact hints from the start wins within the action budget and
tick limit.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win is reachable, **When** a hint is asked, **Then** it says so and suggests undo or
   retry.

### User Story 3 - Understand a failure (Priority: P1)

After contamination, an overflow or running out of time the player is told exactly what went wrong — which basin, which
colour and how much — and offered undo or a retry.

**Independent Test**: every failure explanation names the true basin, colour and amounts of the failing tick.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win is reachable from the current state:** it says so and suggests undo, never a useless action.
- **A locked level or an impossible date:** refused with a named reason.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on levels 1 … 3 in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0505-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G0505-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from any state that can still win (a winning set of at most 3 edits applied now exists) wins
  within the budget and tick limit; from a state that cannot win it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not affect stars
  and returns to its first level after any change of the play.
- **FR-R02G0505-003**: A failure MUST be explained in accessible text naming the reason (contamination, overflow or time),
  the basin, the colour and the amounts against the target, with undo and retry offered.
- **FR-R02G0505-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G0505-005**: A daily level MUST be a deterministic function of the local calendar date ((days since
  2026-01-01 × 53) mod 100 + 1); a practice mode MUST raise the action budget to 30 without affecting progress.
- **FR-R02G0505-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0505-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema; existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested action, why.
- **Failure explanation**: the reason, basin, colour and amounts, as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0505-001**: On levels 1 … 3, scripted players following each instruction win, and every instruction matches
  the state it was shown in.
- **SC-R02G0505-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is a legal action, and from every state that can still win following hints wins.
- **SC-R02G0505-003**: Every failure explanation in 500 seeded failures names the true reason, basin, colour and
  amounts.
- **SC-R02G0505-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0505-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G05-07; announcements and haptics are R02-G05-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- Undo covers every action, including the one that failed the play, so a failure can be undone as well as retried.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the canyon; Dynamic Type and announcements are R02-G05-06.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0505-001, 002 |
| Pacing (bands, unlocks) | FR-R02G0505-004 |
| Goals and results | FR-R02G0505-004 |
| Meaningful content (all 100 levels, free) | FR-R02G0505-004, 006 |
| Failure explanation | FR-R02G0505-003 |
| Daily and practice modes | FR-R02G0505-005 |
| Schema migration | FR-R02G0505-007 |
| Deterministic tests | SC-R02G0505-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn scene is unchanged).
- No paid unlocks, no advertising, no accounts, no network, no saving to disk in this feature, no device run, no
  availability before X-R02-G05.
