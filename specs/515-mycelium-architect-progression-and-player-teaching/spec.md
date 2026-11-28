# Feature Specification: R02-G22-05 — Mycelium Architect: progression and player teaching

**Feature Branch**: `515-mycelium-architect-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Draft

**Ledger gate**: R02-G22-05 (migration ledger, game feature of experience R02-G22) · ID namespace FR-R02G2205-###,
SC-R02G2205-###, T-R02G2205-###

**Input**: User description: the archived R02-G22-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Mycelium Architect, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/515-mycelium-architect-progression-and-player-teaching`; FR-R02G2205-###,
  SC-R02G2205-###, T-R02G2205-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g22.mycelium-architect` (a registered
  candidate since R02-G22-03) inside the one app. No app target, bundle identifier, XcodeGen scheme or store listing.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Mycelium Architect is
  free (catalog tier `free`), so every level is playable without payment (the shared purchase controller grants it);
  the Round 2 lock and the per-round device campaign; "content count 84" (the 100 certified levels of R02-G22-02
  stand); the paths `Apps/MyceliumArchitect` and `Packages/GameModules/MyceliumArchitectCore` (the experience lives in
  `Packages/ExperiencesRound02/MyceliumArchitect`). **Device-only items:** none beyond the device campaign after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression, difficulty
  bands), R02-F26 (accessible text), and the kernel, content, adapter, renderer and gestures of R02-G22-01 … 04.
- **Model:** feature 505 (Binary Gardens' progression and teaching): hints from the current state with the certified
  witness first and a bounded search second, a state-derived tutorial, failure text, progress and stars against the
  certified action count, daily and practice modes and the snapshot migration 1 → 2.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — place a nutrient on a site or seed a filament
from the root, watch the ghost veins, keep the growth away from toxin and inside the weight limit, then run the growth
— each advancing when done, and can dismiss them.

**Why this priority**: steering growth that follows a nutrient gradient, bends with curvature and branches at consumed
nutrients is unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown in that opening and play continues unchanged.
3. **Given** the tutorial is at its second instruction, **When** the player undoes the last action, **Then** the
   instruction stays where it is.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which kind of change (a nutrient, a
blocker, a clear, a seed or an unseed), then roughly where, then the exact cell or direction — so that the level can
still be won within the actions left.

**Why this priority**: predicting where a tip will turn after a placement, over many pulses, is hard to do in the head;
a hint keeps the player moving.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only and then runs the growth,
   **Then** the level is won in the certified number of actions.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.
3. **Given** the current arrangement already wins, **When** a hint is asked, **Then** it says to run the growth.
4. **Given** a hint at level 2, **When** the player makes any change, **Then** the next hint request starts at level 1.

### User Story 3 - Understand a failure (Priority: P1)

After a run in which a tip grew into toxin, a tip ran out of nutrient, a terminal was not reached or the network grew
too heavy, the player is told exactly what went wrong — which tip, terminal, cell and pulse, or which weight against
which bound — and offered undo or a retry.

**Why this priority**: the failure happens over many pulses; without words the player cannot see what to change.

**Independent Test**: every failure explanation names the true tip, terminal, cell, pulse, weight and bound.

**Acceptance Scenarios**:

1. **Given** a run that fails `toxic`, **When** the result is shown, **Then** the text names the tip, the toxic cell and
   the pulse and offers undo or retry.
2. **Given** a run that fails `overweight`, **When** the result is shown, **Then** the text names the network's weight
   and the limit, grouped as the level groups numbers.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars against the certified action count; a daily level comes
from the date; practice relaxes the budget to 24 without affecting progress.

**Why this priority**: pacing across 100 levels in five bands and a reason to return.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

**Acceptance Scenarios**:

1. **Given** only level 1 open, **When** level 3 is selected, **Then** it is refused `r02-g22.locked` and nothing
   changes.
2. **Given** a campaign win of level k in the certified count, **Then** level k records 3 stars and level k + 1 opens.
3. **Given** an impossible date for the daily level, **Then** it is refused `r02-g22.date`.
4. **Given** a practice win, **Then** no stars are recorded and no level opens.
5. **Given** a schema-1 snapshot of level 7, **When** it is restored, **Then** levels 1 … 7 are open, nothing is won,
   the mode is campaign and the play replays exactly.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when the current arrangement already wins:** it says to run the growth.
- **A hint off the witness's way:** a placement or seed that is neither in the start nor in the certified arrangement
  falls to the bounded search.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless action.
- **A hint with no action left:** the search depth is 0, so only "run the growth" or the stuck text can result.
- **A hint search that would run long:** bounded by counted work (arrangements judged); it never stalls a frame.
- **A refused change (a full count, a starting seed, a non-site cell):** never suggested (only legal moves are tried).
- **A locked level, no next open level or an impossible date:** refused with a named reason (`r02-g22.locked`,
  `r02-g22.date`) and nothing changes.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with levels 1 … its level open and campaign mode.
- **Level 100 won in the campaign:** no further level opens and `level.next` from level 100 is refused
  `r02-g22.locked` (no wrap); every level stays selectable with `level.select`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2205-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it, never moves back on undo or redo and can be dismissed; instructions never block
  or perform actions.
- **FR-R02G2205-002**: A hint MUST be available in three progressive levels, computed from the current state — the
  certified witness's next action while the play is on its way, otherwise a bounded search — so that following the
  exact hints from the start of every certified level, then running the growth, wins within its budget; from a state
  where no win is found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not
  affect stars and returns to its first level after any change of the play.
- **FR-R02G2205-003**: A failure MUST be explained in accessible text naming its cause (toxic: the tip, the cell and the
  pulse; starved: the tip, the cell, the pulse, the weight and the nutrient budget; unreached: the terminal and its
  cell; overweight: the weight and the limit), with undo and retry offered.
- **FR-R02G2205-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal (the certified action count) and a result (1 … 3 stars by actions spent) per
  level, the best result kept.
- **FR-R02G2205-005**: A daily level MUST be a deterministic function of the local calendar date with a fixed multiplier
  coprime with 100 and unused by every other round-two game; a practice mode MUST raise the budget to 24 without
  affecting progress.
- **FR-R02G2205-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G2205-007**: Progress, the mode and the tutorial step MUST be part of the experience snapshot, schema 2, with
  a migration from schema 1; progress and the mode are digested (domain v2), the tutorial step and every presentation
  value are not; refusals carry named reason codes (`r02-g22.locked`, `r02-g22.date`, `r02-g22.not-whole`, the kernel's
  codes); new public names are documented; the reference regression passes.
- **FR-R02G2205-008**: The tutorial instruction, the hint and the failure explanation MUST appear as wrapping text in
  the control panel on iPhone and iPad, never over the scene, with a labelled hint button, mode buttons and a picker of
  open levels with their bands and stars, each with an accessibility label, value and identifier; nothing relies on
  colour alone.
- **FR-R02G2205-009**: Hints, tutorial steps, stars, the daily level and the migration MUST be deterministic, integer
  only and free of any clock or random source; the hint search's work MUST be counted and bounded, never timed.
- **FR-R02G2205-010**: Refused progression actions MUST be logged by reason code as the presenter already logs
  refusals, and the panel MUST say why in words.

### Key Entities

- **Tutorial step**: the instructions for the tutorial levels and `done`; the instruction for the current state and its
  order.
- **Hint**: level 1 … 3, the suggested action (a nutrient, blocker or clear on a cell, or a seed or unseed in a
  direction), or the run, the stuck text or the undo-or-retry advice.
- **Failure explanation**: the cause (toxic, starved, unreached, overweight) with the tip or terminal, the cell, the
  pulse or the weight and its bound, as text.
- **Progress**: won levels with best actions spent and stars, the open frontier; the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2205-001**: On the three tutorial levels, scripted players following each instruction win, and every
  instruction matches the state it was shown in.
- **SC-R02G2205-002**: For all 100 certified levels, following exact hints from the start and then running the growth
  wins in the certified action count; for 200 seeded reachable states every exact hint is an action the rules accept,
  and every hint computation stays within its counted work bound.
- **SC-R02G2205-003**: Every failure explanation in 500 seeded failures, covering all four causes, names the true tip or
  terminal, cell, pulse, weight and bound.
- **SC-R02G2205-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable, and every 100 consecutive days visit each
  level exactly once.
- **SC-R02G2205-005**: A schema-1 snapshot of every level 1 … 100 restores under schema 2 by the migration rules; a
  schema-2 round trip reproduces the digest; every malformed payload is refused.
- **SC-R02G2205-006**: Existing tests pass, apart from the named assertions this feature changes; the reference
  regression passes 7 of 7; each new test finishes under 10 s on the host (asserted locally only, never on CI).

## Assumptions

- Saving progress to disk is R02-G22-07; announcements, haptics and sound are R02-G22-06.
- The kernel's tutorial stage stays dismissed by the adapter; the tutorial steps become the experience's own state.
- The certified plan of each level (the witness's actions without the run) is available to the adapter and the
  presenter from the R02-G22-02 witnesses.
- Observability: refused progression actions are logged by reason code.
- Accessibility: every new text is plain, ordered and available to VoiceOver as panel text; system accessibility audits
  wait for device testing.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G2205-001, 002 |
| Pacing (bands, unlocks) | FR-R02G2205-004 |
| Goals and results | FR-R02G2205-004 |
| Meaningful content (all 100 levels, free) | FR-R02G2205-004, 006 |
| Failure explanation | FR-R02G2205-003 |
| Daily and practice modes | FR-R02G2205-005 |
| Schema migration, error handling | FR-R02G2205-007 |
| Deterministic tests | FR-R02G2205-009; SC-R02G2205-001 … 005 |
| Observability | FR-R02G2205-010 |
| Accessibility | FR-R02G2205-008 |
| Nonfunctional (bounded work, timing, regression) | FR-R02G2205-009; SC-R02G2205-002, 006 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn cave floor, veins and gauges
  are unchanged); no advertising, account, network or payment path; no device run before ImplementationLock-100; no
  availability before X-R02-G22; persistence to disk, sound and announcements are later features of R02-G22.
