# Feature Specification: R02-G10-05 — Backwards Aurora: progression and player teaching

**Feature Branch**: `395-backwards-aurora-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G10-05 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1005-###,
SC-R02G1005-###, T-R02G1005-###

**Input**: User description: the archived R02-G10-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Backwards Aurora, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/395-backwards-aurora-progression-and-player-teaching`; FR-R02G1005-###,
  SC-R02G1005-###, T-R02G1005-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g10.backwards-aurora` (a registered
  candidate since R02-G10-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Backwards Aurora is free,
  so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock; "content
  count 76" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G10-01 … 04.
- **Model:** feature 385 (Nocturne Garden's progression and teaching) for hints, tutorial, failure text, progress, daily
  and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
385's answers where the games agree. Facts checked in code (read-only, 2026-11-23): `BackwardsAuroraSolver` certifies a
level by an iterative-deepening search over reversible sections (20,000 reversals evaluated at most) from the opening
wave, pruned by the seam-count bound ⌈β / 4⌉; a play fails on a tear (`tear(reversal, seam)`) or when the reversals
spent reach the budget (`budget`); undo works in playing, paused and failed, a won play is final; levels 1 … 3 carry the
tutorial flag; manifest budgets are 8 … 19 and the level's range 1 … 40; the adapter prepares level (seed mod 100) + 1
and snapshots `{level, records}` as schema 1; the core may not read a clock; the other round-two games' daily
multipliers are 37, 41, 43, 47, 53, 59, 61, 67 and 71.

- Q: How is a hint computed and what does each level reveal? → A: the plan comes from the current state. A won play has
  no hint; a failed play's hint is "Undo the last reversal or retry the level." While playing: the solver's bounded
  search (a new entry point) from the current wave, looking for the fewest further reversals that win within the
  reversals left, by the same iterative deepening and seam-count pruning as the certification. Its first reversal is the
  plan: level 1 names its length ("Reverse a section of 4 samples"), level 2 adds where it starts ("… starting at sample
  3"), level 3 names both ends ("Reverse samples 3 to 6"). When no plan is found within the bound: "No way to fold the
  aurora back was found in the reversals left: undo the last reversal or retry the level." Hints never change the state,
  are unlimited, do not affect stars and reset to level 1 after any change of the play. "A state that can still win"
  means one whose plan exists. Impact: FR-R02G1005-002; SC-R02G1005-002.
- Q: What does the tutorial show, and when does it advance? → A: on levels 1 … 3, three instructions in order: (1) "Tap
  two samples to mark the ends of a section (or use the panel) — a hint shows which" — it advances once a reversal has
  been accepted; (2) "Swipe along the section to reverse it, or hold it first to preview; keep every bend within the
  limit and never tear the aurora" — until a second reversal is accepted or the level ends; (3) "Bring every checkpoint
  to its true height before the reversals run out" — until the level ends. `tutorial.dismiss` ends it for that level;
  undo never moves it back. Impact: FR-R02G1005-001; SC-R02G1005-001.
- Q: What are the progress and star rules? → A: stars measure the reversals made, undone ones included (the play's
  reversal records): 3 when at most the certified smallest reversal count, 2 when at most that + 2, else 1; per level
  the best (fewest) reversals made of a won campaign play and its stars, a better result replacing a worse one; level 1
  open; a campaign win opens the next; `level.select [n]` opens any open level and refuses others (`r02-g10.locked`);
  `level.next` moves to the next open level (refused when none, `r02-g10.locked`); the five bands of 20 are the
  certified difficulty bands. Impact: FR-R02G1005-004; SC-R02G1005-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 73) mod 100 + 1, negative day counts wrapped into 0 … 99 (73 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g10.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (40); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1005-005;
  SC-R02G1005-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 385: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the snapshot payload becomes schema 2
  (`{level, records, progress, mode, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level,
  campaign mode, tutorial at its first step on tutorial levels). Failures are explained from the failing reversal: tear
  "Reversal m (samples i to j) tore the aurora at seam s: a bend of b against the breaking limit B."; budget "The
  reversals ran out: b of b spent with k of n checkpoints matched and a worst bend of w against the limit L.", each
  followed by "Undo the last reversal or retry the level." Impact: FR-R02G1005-003, 007; SC-R02G1005-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — mark a section by its ends, swipe to reverse
it (holding first to preview), keep every bend within the limit and never tear the aurora, bring every checkpoint to its
true height — each advancing when done, and can dismiss them.

**Why this priority**: reversing time sections of a wave is unfamiliar; without teaching the first levels are
guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help: how long a section to reverse next, then
where it starts, then exactly which samples, so that the aurora can still be folded back within the reversals left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win is possible in the reversals left, **When** a hint is asked, **Then** it says so
   and suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After the aurora tears or the reversals run out the player is told exactly what went wrong — which reversal tore which
seam with what bend against the breaking limit, or how many reversals were spent with how many checkpoints matched and
the worst bend against the limit — and offered undo or a retry.

**Independent Test**: every failure explanation names the true reason, reversal and numbers.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
reversal budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win is possible in the reversals left:** it says so and never suggests a useless reversal.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1005-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1005-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from any state that can still win within the reversals left wins within the budget; from a
  state that cannot win it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not
  affect stars and returns to its first level after any change of the play.
- **FR-R02G1005-003**: A failure MUST be explained in accessible text naming the reason (tear or budget), the reversal
  and the seam that tore with its bend against the breaking limit, or the reversals spent with the checkpoints matched
  and the worst bend against the limit, with undo and retry offered.
- **FR-R02G1005-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1005-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the reversal budget without affecting progress.
- **FR-R02G1005-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1005-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested reversal, why.
- **Failure explanation**: the reason, the reversal, seam and bend, or the reversals, checkpoints and worst bend, as text.
- **Progress**: solved levels with best reversals made and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1005-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1005-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is a legal reversal, and from every state that can still win following hints wins.
- **SC-R02G1005-003**: Every failure explanation in 500 seeded failures names the true reason, reversal and numbers.
- **SC-R02G1005-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1005-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G10-07; announcements and haptics are R02-G10-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the aurora.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1005-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1005-004 |
| Goals and results | FR-R02G1005-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1005-004, 006 |
| Failure explanation | FR-R02G1005-003 |
| Daily and practice modes | FR-R02G1005-005 |
| Schema migration | FR-R02G1005-007 |
| Deterministic tests | SC-R02G1005-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn aurora is unchanged); no
  device run before ImplementationLock-100; no availability before X-R02-G10.
