# Feature Specification: R02-G12-05 — Harmonic Bridges: progression and player teaching

**Feature Branch**: `415-harmonic-bridges-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G12-05 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1205-###,
SC-R02G1205-###, T-R02G1205-###

**Input**: User description: the archived R02-G12-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Harmonic Bridges, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/415-harmonic-bridges-progression-and-player-teaching`; FR-R02G1205-###,
  SC-R02G1205-###, T-R02G1205-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g12.harmonic-bridges` (a registered
  candidate since R02-G12-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Harmonic Bridges is free,
  so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock; "content
  count 82" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G12-01 … 04.
- **Model:** feature 405 (Echo Cartographer's progression and teaching) for hints, tutorial, failure text, progress,
  daily and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
405's answers where the games agree. Facts checked in code (read-only, 2026-11-23): `HarmonicBridgesSolver.plan`
certifies a level by the minimal set of retuned strings — for k = 1 … 6 it tries the subsets of useful strings in
lexicographic order and each product of their maximal bridge patterns (lowest peg each), bounded at 400,000 choices —
and its witness is the plan's tunings in string order followed by one test; a tuning spends 1 action, a test spends 1;
a play fails `broken(step, string)` when a test finds a step without a crossing (string nil when no string reaches
across) or `budget(action)` when the last action is spent without a win (the 0-based index of that action); undo works
in playing and failed plays, a won play is final; levels 1 … 3 carry the tutorial flag; budgets are 1 … 60; the adapter
prepares level (seed mod 100) + 1 and snapshots `{level, records}` as schema 1; the core may not read a clock; the other
round-two games' daily multipliers are 37, 41, 43, 47, 53, 59, 61, 67, 71, 73 and 79.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play has no hint; a
  failed play's hint is "Undo the last action or retry the level." While playing: the solver's minimal plan is computed
  for the level with every string at its current peg (locks kept). When the current pegs already join the start to the
  goal in every step the plan is the test; otherwise the plan is its first tuning (lowest string index) — and the whole
  plan (its tunings plus the test) must fit the actions left, or else, as when the work bound is exceeded: "No way to
  win was found in the moves left: undo the last action or retry the level." Level 1 names the kind ("Tune a string so
  that more steps are bridged" or "Every step is bridged: test the crossing"), level 2 names the string ("Tune string 2"
  / "Test the crossing: tap the goal or a step pip"), level 3 names the peg ("Tune string 2 to peg 7" / the same test
  text). Hints never change the state, are unlimited, do not affect stars and reset to level 1 after any change of the
  play. Impact: FR-R02G1205-002; SC-R02G1205-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), three
  instructions in order: (1) "Drag a string's peg up or down (or use the panel's peg steppers and Tune) — when one of its
  harmonics matches a tone of the step it swings and its samples fill" — it advances once a tuning has been accepted;
  (2) "A string whose five samples all fill becomes a cyan bridge: bridge a path from the start to the violet goal in
  every step — a hint shows which string" — until the current pegs join the start to the goal in every step or the
  level ends (a tuning that already does both moves straight on to the third step; an undo that unbridges a step does
  not move it back); (3) "Tap the goal or a step pip to test the crossing; if a step breaks, undo it" — until the level ends.
  `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G1205-001; SC-R02G1205-001.
- Q: What are the progress and star rules? → A: stars measure the actions spent by every accepted tuning and test
  record, undone ones included: 3 when at most the certified witness's action count (its tunings plus the test), 2 when
  at most that + 2, else 1; per level the best (least) actions spent of a won campaign play and its stars, a better
  result replacing a worse one; level 1 open; a campaign win opens the next; `level.select [n]` opens any open level and
  refuses others (`r02-g12.locked`); `level.next` moves to the next open level (refused when none, `r02-g12.locked`);
  the five bands of 20 are the certified difficulty bands. Impact: FR-R02G1205-004; SC-R02G1205-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 83) mod 100 + 1, negative day counts wrapped into 0 … 99 (83 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g12.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (60); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1205-005;
  SC-R02G1205-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 405: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the snapshot payload becomes schema 2
  (`{level, mode, progress, records, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level,
  campaign mode, tutorial at its first step on tutorial levels). A failure is explained from the failing action, actions
  numbered from 1 and steps and strings from 0: a broken test — "Action m (the test) broke the crossing in step s at
  string i: the start reached the goal in k of n steps." (or "… in step s: no string reaches across: …" without a
  string); the budget — "Action m (a tuning of string i to peg p | a test) spent the last move without a win: the start
  reached the goal in k of n steps." — k counted at the pegs after the failing action (the kernel's report then) — each
  followed by "Undo the last action or retry the level." Impact:
  FR-R02G1205-003, 007; SC-R02G1205-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — pluck a string to hear what it sings, drag its
peg until it resonates with the step's tones and its samples fill, test the crossing once every step is bridged — each
advancing when done, and can dismiss them.

**Why this priority**: resonance between string lengths, pegs and tones is unfamiliar; without teaching the first levels
are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — what to do next (tune or test), then which
string, then exactly which peg — so that the crossing can still be won within the moves left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win was found in the moves left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a broken crossing or running out of moves the player is told exactly what went wrong — which action failed, in
which step the crossing broke and at which string, or that the moves ran out and in how many steps the crossing held —
and offered undo or a retry.

**Independent Test**: every failure explanation names the true action and numbers.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win was found in the moves left:** it says so and never suggests a useless action.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason (`r02-g12.locked`, `r02-g12.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1205-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1205-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level wins within its budget; from a state where no win is
  found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not affect stars and
  returns to its first level after any change of the play.
- **FR-R02G1205-003**: A failure MUST be explained in accessible text naming the action that failed and its cause (the
  step and string of a broken crossing, or the last move spent without a win) with the steps in which the crossing held,
  with undo and retry offered.
- **FR-R02G1205-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1205-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1205-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1205-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested tuning or test, why.
- **Failure explanation**: the action that failed, the broken step and string or the exhausted budget, the steps that
  held, as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1205-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1205-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is an action the rules accept.
- **SC-R02G1205-003**: Every failure explanation in 500 seeded failures names the true action and numbers.
- **SC-R02G1205-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1205-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G12-07; announcements, haptics and the audible audition are R02-G12-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the bridges.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1205-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1205-004 |
| Goals and results | FR-R02G1205-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1205-004, 006 |
| Failure explanation | FR-R02G1205-003 |
| Daily and practice modes | FR-R02G1205-005 |
| Schema migration | FR-R02G1205-007 |
| Deterministic tests | SC-R02G1205-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn bridges are unchanged); no
  device run before ImplementationLock-100; no availability before X-R02-G12.
