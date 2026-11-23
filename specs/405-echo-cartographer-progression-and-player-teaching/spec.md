# Feature Specification: R02-G11-05 — Echo Cartographer: progression and player teaching

**Feature Branch**: `405-echo-cartographer-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G11-05 (migration ledger, game feature of experience R02-G11) · ID namespace FR-R02G1105-###,
SC-R02G1105-###, T-R02G1105-###

**Input**: User description: the archived R02-G11-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Echo Cartographer, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/405-echo-cartographer-progression-and-player-teaching`; FR-R02G1105-###,
  SC-R02G1105-###, T-R02G1105-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g11.echo-cartographer` (a registered
  candidate since R02-G11-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Echo Cartographer is free,
  so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock; "content
  count 90" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G11-01 … 04.
- **Model:** feature 395 (Backwards Aurora's progression and teaching) for hints, tutorial, failure text, progress, daily
  and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
395's answers where the games agree. Facts checked in code (read-only, 2026-11-23): `EchoCartographerSolver` certifies a
level by a greedy pulse plan from the opening knowledge — at each turn every cell known open and not yet pulsed is tried
in cell-index order and the one whose echo leaves the fewest fitting beacon placements is pulsed (ties: lowest index)
— until exactly one placement fits (at most 6 pulses, 400,000 enumeration nodes); its witness is those pulses then one
claim on each beacon's own cell; a pulse spends 1 energy, a claim that locates a beacon is free, a missed claim spends
the level's miss cost (1 … 3, never more than the energy left); a play fails only when the energy runs out with a beacon
hidden (`energy(index)`, the 0-based index of the action); undo works in playing, paused and failed, a won play is
final; levels carry a tutorial flag; energies are 1 … 60; the adapter prepares level (seed mod 100) + 1 and snapshots
`{level, records}` as schema 1; the core may not read a clock; the other round-two games' daily multipliers include 37,
41, 43, 47, 53, 59, 61, 67, 71 and 73.

- Q: How is a hint computed and what does each level reveal? → A: the plan comes from the current state and the level's
  truth. A won play has no hint; a failed play's hint is "Undo the last action or retry the level." While playing: the
  echoes heard by the play's pulses are the observations; when exactly one beacon placement fits them the plan is a
  claim on the lowest-index beacon not yet located (its own cell, which always locates it); otherwise the plan is the
  solver's greedy next pulse (a new entry point continuing the certification's greedy rule from the current knowledge
  and pulses) — and the whole continuation (further pulses until one placement fits) must fit in the energy left, or
  else: "No way to locate every beacon was found in the energy left: undo the last action or retry the level." Level 1
  names the kind ("Send a pulse to narrow down where the beacons can be" or "The echoes leave one place for the
  beacons: claim a beacon"), level 2 adds the row ("… from a known open cell in row 3" / "… in row 3"), level 3 names
  the cell ("Send a pulse from column 2, row 3" / "Claim column 2, row 3"). Hints never change the state, are unlimited,
  do not affect stars and reset to level 1 after any change of the play. Impact: FR-R02G1105-002; SC-R02G1105-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag, three instructions
  in order: (1) "Tap a lit floor cell to send a pulse (or use the panel) — the echoes tell how far each beacon is along
  the open floor" — it advances once a pulse has been accepted; (2) "Drag markers onto cells where a beacon could be and
  pulse again to narrow them down — a hint shows where" — until a beacon is located or the level ends; (3) "Hold a cell
  to claim a beacon there; a miss costs energy — locate every beacon before the energy runs out" — until the level ends.
  `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G1105-001; SC-R02G1105-001.
- Q: What are the progress and star rules? → A: stars measure the energy spent by every accepted pulse and claim record,
  undone ones included: 3 when at most the certified plan's pulse count (its witness energy, claims being free), 2 when
  at most that + 2, else 1; per level the best (least) energy spent of a won campaign play and its stars, a better
  result replacing a worse one; level 1 open; a campaign win opens the next; `level.select [n]` opens any open level and
  refuses others (`r02-g11.locked`); `level.next` moves to the next open level (refused when none, `r02-g11.locked`);
  the five bands of 20 are the certified difficulty bands. Impact: FR-R02G1105-004; SC-R02G1105-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 79) mod 100 + 1, negative day counts wrapped into 0 … 99 (79 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g11.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the energy raised to the kernel's
  maximum (60); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1105-005;
  SC-R02G1105-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 395: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the snapshot payload becomes schema 2
  (`{level, records, progress, mode, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level,
  campaign mode, tutorial at its first step on tutorial levels). A failure is explained from the action that spent the
  last energy: "Action m (a pulse from column x, row y | a missed claim at column x, row y) spent the last energy: k of
  n beacons located after p pulses and q missed claims." followed by "Undo the last action or retry the level."
  Impact: FR-R02G1105-003, 007; SC-R02G1105-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — send a pulse from a cell known to be open, read
the echoes to narrow down where the beacons can be, claim each beacon before the energy runs out — each advancing when
done, and can dismiss them.

**Why this priority**: locating hidden beacons from echo delays is unfamiliar; without teaching the first levels are
guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — what to do next (pulse or claim), then
roughly where, then exactly which cell — so that every beacon can still be located within the energy left.

**Independent Test**: on every certified level, following exact hints from the start wins within the energy.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win was found in the energy left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After the energy runs out the player is told exactly what went wrong — which action spent the last energy, how many
beacons were located out of how many, how many pulses were sent and how many claims missed — and offered undo or a
retry.

**Independent Test**: every failure explanation names the true action and numbers.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
energy without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win was found in the energy left:** it says so and never suggests a useless action.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1105-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1105-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level wins within its energy; from a state where no win is
  found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not affect stars and
  returns to its first level after any change of the play.
- **FR-R02G1105-003**: A failure MUST be explained in accessible text naming the action that spent the last energy, the
  beacons located out of the total, the pulses sent and the claims missed, with undo and retry offered.
- **FR-R02G1105-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1105-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the energy without affecting progress.
- **FR-R02G1105-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1105-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested pulse or claim, why.
- **Failure explanation**: the action that spent the last energy, beacons located, pulses and missed claims, as text.
- **Progress**: solved levels with best energy spent and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1105-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1105-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is an action the rules accept.
- **SC-R02G1105-003**: Every failure explanation in 500 seeded failures names the true action and numbers.
- **SC-R02G1105-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1105-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G11-07; announcements and haptics are R02-G11-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the chamber.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1105-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1105-004 |
| Goals and results | FR-R02G1105-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1105-004, 006 |
| Failure explanation | FR-R02G1105-003 |
| Daily and practice modes | FR-R02G1105-005 |
| Schema migration | FR-R02G1105-007 |
| Deterministic tests | SC-R02G1105-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn chamber is unchanged); no
  device run before ImplementationLock-100; no availability before X-R02-G11.
