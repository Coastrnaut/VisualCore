# Feature Specification: R02-G08-05 — Faceted Forge: progression and player teaching

**Feature Branch**: `375-faceted-forge-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G08-05 (migration ledger, game feature of experience R02-G08) · ID namespace FR-R02G0805-###,
SC-R02G0805-###, T-R02G0805-###

**Input**: User description: the archived R02-G08-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Faceted Forge, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/375-faceted-forge-progression-and-player-teaching`; FR-R02G0805-###,
  SC-R02G0805-###, T-R02G0805-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g08.faceted-forge` (a registered
  candidate since R02-G08-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Faceted Forge is free,
  so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock; "content
  count 84" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G08-01 … 04.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
365's answers where the games agree. Facts checked in code (read-only, 2026-11-22): `FacetedForgeSolver` certifies a
level by a bounded depth-first search (20,000 cut evaluations) for a winning sequence of exactly target pieces − 1 cuts
from the crystal alone, pruned by `canPartition`; every accepted cut adds exactly one piece, so a won play always spent
exactly the lower bound of cuts; a play fails on a sliver (`sliver(piece, cut)`, the new canonical index and the cuts
spent before it) or when the cuts spent reach the budget (`budget`); undo works in playing, paused and failed, a won
play is final; levels 1 … 3 carry the tutorial flag; manifest budgets are 8 … 19 and the level's range 1 … 20; the
adapter prepares level (seed mod 100) + 1 and snapshots `{level, records}` as schema 1; the core may not read a clock;
the other round-two games' daily multipliers are 37, 41, 43, 47, 53, 59 and 61.

- Q: How is a hint computed and what does each level reveal? → A: the plan comes from the current state. A won play has
  no hint; a failed play's hint is "Undo the last cut or retry the level." While playing: the same bounded depth-first
  search as the solver (a new entry point from the current pieces), looking for exactly target pieces − current pieces
  more cuts, which must fit in the cuts left and start from pieces that `canPartition` accepts; its first cut is the
  plan: level 1 "Cut piece k" (piece k named in words: its share and face count), level 2 "Cut piece k in direction x",
  level 3 "Cut piece k in direction x at depth d". When no plan is found: "No way to match the target was found in the
  cuts left: undo the last cut or retry the level." Hints never change the state, are unlimited, do not affect stars and
  reset to level 1 after any change of the play. "A state that can still win" means one whose plan exists. Impact:
  FR-R02G0805-002; SC-R02G0805-002.
- Q: What does the tutorial show, and when does it advance? → A: on levels 1 … 3, three instructions in order: (1)
  "Choose a piece and aim the ruby plane — drag its rim to tilt it, drag inside it to slide it, or use the panel — then
  tap the plane (or Cut) to split the piece; a hint shows where" — it advances once a cut has been accepted; (2) "Each
  cut adds one piece: match the target's shares and face counts exactly; a piece thinner than 1/64 of the crystal ends
  the play" — until a second cut is accepted or the level ends; (3) "Match every target piece before the cuts run out" —
  until the level ends. `tutorial.dismiss` ends it for that level; undo never moves it back. Impact: FR-R02G0805-001;
  SC-R02G0805-001.
- Q: What are the progress and star rules, given that every win spends exactly the lower bound of cuts? → A: stars
  measure the cuts made, undone ones included (the play's cut records): 3 when at most the certified smallest cut count
  (no cut undone), 2 when at most that + 2, else 1; per level the best (fewest) cuts made of a won campaign play and its
  stars, a better result replacing a worse one; level 1 open; a campaign win opens the next; `level.select [n]` opens
  any open level and refuses others (`r02-g08.locked`); `level.next` moves to the next open level (refused when none,
  `r02-g08.locked`); the five bands of 20 are the certified difficulty bands. Impact: FR-R02G0805-004; SC-R02G0805-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 67) mod 100 + 1, negative day counts wrapped into 0 … 99 (67 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g08.date`). Daily play follows campaign rules but does not open levels. `mode.practice` replays the
  current level with the budget raised to the kernel's maximum (20); practice results never award stars or open
  levels; `mode.campaign` returns. Impact: FR-R02G0805-005; SC-R02G0805-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 365: progress and
  the mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter); the snapshot payload becomes schema 2 (`{level, records, progress,
  mode, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level, campaign mode, tutorial at its
  first step on tutorial levels). Failures are explained from the failing cut: sliver "Cut c left piece p at s of the
  crystal, thinner than the sliver limit of 1/64."; budget "The cuts ran out: b of b spent with n pieces; the target
  has m.", each followed by "Undo the last cut or retry the level." Impact: FR-R02G0805-003, 007; SC-R02G0805-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — choose a piece and aim the plane, cut, match the
target pieces without leaving a sliver — each advancing when done, and can dismiss them.

**Why this priority**: cutting a crystal into target shares is unfamiliar; without teaching the first levels are
guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help: which piece to cut, in which direction, and
exactly at which depth, so that the target can still be matched within the cuts left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which the target cannot be matched in the cuts left, **When** a hint is asked, **Then** it
   says so and suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a cut leaves a sliver or the cut budget runs out the player is told exactly what went wrong — which piece of
which cut was too thin and how its share compares with the limit, or how many cuts were spent and how the pieces
differ from the target — and offered undo or a retry.

**Independent Test**: every failure explanation names the true reason, piece and cut or cuts and pieces.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
cut budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when the target cannot be matched in the cuts left:** it says so and never suggests a useless cut.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason.
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0805-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G0805-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from any state that can still win within the cuts left wins within the budget; from a
  state that cannot win it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not
  affect stars and returns to its first level after any change of the play.
- **FR-R02G0805-003**: A failure MUST be explained in accessible text naming the reason (sliver or budget), the piece
  and cut of a sliver with its share and the limit, or the cuts spent and the pieces against the target, with undo and
  retry offered.
- **FR-R02G0805-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G0805-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the cut budget without affecting progress.
- **FR-R02G0805-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0805-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested cut, why.
- **Failure explanation**: the reason, the piece and cut or the cuts and pieces, as text.
- **Progress**: solved levels with best cuts used and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0805-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G0805-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is a legal cut, and from every state that can still win following hints wins.
- **SC-R02G0805-003**: Every failure explanation in 500 seeded failures names the true reason, piece and cut or cuts.
- **SC-R02G0805-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0805-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G08-07; announcements and haptics are R02-G08-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the crystal.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0805-001, 002 |
| Pacing (bands, unlocks) | FR-R02G0805-004 |
| Goals and results | FR-R02G0805-004 |
| Meaningful content (all 100 levels, free) | FR-R02G0805-004, 006 |
| Failure explanation | FR-R02G0805-003 |
| Daily and practice modes | FR-R02G0805-005 |
| Schema migration | FR-R02G0805-007 |
| Deterministic tests | SC-R02G0805-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn crystal is unchanged); no
  device run before ImplementationLock-100; no availability before X-R02-G08.
