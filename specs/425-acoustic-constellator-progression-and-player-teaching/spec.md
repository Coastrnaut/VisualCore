# Feature Specification: R02-G13-05 — Acoustic Constellator: progression and player teaching

**Feature Branch**: `425-acoustic-constellator-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G13-05 (migration ledger, game feature of experience R02-G13) · ID namespace FR-R02G1305-###,
SC-R02G1305-###, T-R02G1305-###

**Input**: User description: the archived R02-G13-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Acoustic Constellator, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/425-acoustic-constellator-progression-and-player-teaching`; FR-R02G1305-###,
  SC-R02G1305-###, T-R02G1305-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g13.acoustic-constellator` (a
  registered candidate since R02-G13-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Acoustic Constellator is
  free, so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock;
  "content count 85" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G13-01 … 04.
- **Model:** feature 415 (Harmonic Bridges' progression and teaching) for hints, tutorial, failure text, progress,
  daily and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
415's answers where the games agree. Facts checked in code (read-only, 2026-11-23): `AcousticConstellatorSolver.plan`
certifies a level by the smallest action set that wins — the missing symbol pairs, then extra multisets of helper links
and ±1 nudges for 0 … `maxActions` (6) − the missing count extras — bounded at 400,000 listens; its witness actions are
the plan's links in pair order, then its nudges, then one listen; every link, unlink, nudge and listen spends 1 action;
a listen fails `missing(pair)`, `disconnected(tick, link)` or `incoherent(longestRun)`, and the last action spent
without a win fails `budget(action)` (its 0-based index); undo works in playing and failed plays, a won play is final;
levels 1 … 3 carry the tutorial flag; budgets are 1 … 40; the adapter prepares level (seed mod 100) + 1 and snapshots
`{level, records}` as schema 1; the core may not read a clock; the other round-two games' daily multipliers are 37,
41, 43, 47, 53, 59, 61, 67, 71, 73, 79 and 83.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play has no hint; a
  failed play's hint is "Undo the last action or retry the level." While playing: the solver's plan is computed for the
  level as it stands — the current links in place (the player's links as placed ones), every star at its current
  starting phase. Its first action is the hint (a missing pair's link first, then helper links, then nudges, then the
  listen); the whole plan (its links and nudges plus the listen) must fit the actions left, or else, as when the work
  bound is exceeded or no plan exists (for example a placed link that blocks a star's degree): "No way to win was found
  in the moves left: undo the last action or retry the level." Level 1 names the kind ("Link two stars of the symbol",
  "Link a helper pair so the phases pull together", "Nudge a star's phase" or "The symbol is ready: listen"), level 2
  names the stars ("Work on star 2 and star 5" / "Work on star 3" / "Listen: tap the coherence gauge"), level 3 the
  exact action ("Link star 2 to star 5" / "Nudge star 3 by +1" / the same listen text). Hints never change the state,
  are unlimited, do not affect stars and reset to level 1 after any change of the play. Impact: FR-R02G1305-002;
  SC-R02G1305-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), three
  instructions in order: (1) "Drag from one star to another (or use the panel's star, partner and Link) to link a pair
  the dashed plum guides show" — it advances once a link has been accepted; (2) "Link every guided pair; linked stars
  pull each other's phases, and a link stretched too far snaps — tap a star to nudge its phase, and a hint shows which"
  — until no symbol pair is missing or the level ends (a link that completes the symbol moves straight on to the third
  step; an undo does not move it back); (3) "Tap the coherence gauge (or Listen) to hear whether the stars hold
  together for the hold; if they fall apart, undo" — until the level ends. `tutorial.dismiss` ends it for that level;
  undo never moves it back. Impact: FR-R02G1305-001; SC-R02G1305-001.
- Q: What are the progress and star rules? → A: stars measure the actions spent by every accepted link, unlink, nudge and
  listen record, undone ones included: 3 when at most the certified witness's action count (its links and nudges plus
  the listen), 2 when at most that + 2, else 1; per level the best (least) actions spent of a won campaign play and its
  stars, a better result replacing a worse one; level 1 open; a campaign win opens the next; `level.select [n]` opens any
  open level and refuses others (`r02-g13.locked`); `level.next` moves to the next open level (refused when none,
  `r02-g13.locked`); the five bands of 20 are the certified difficulty bands. Impact: FR-R02G1305-004;
  SC-R02G1305-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 89) mod 100 + 1, negative day counts wrapped into 0 … 99 (89 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g13.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (40); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1305-005;
  SC-R02G1305-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 415: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the snapshot payload becomes schema 2
  (`{level, mode, progress, records, tutorial}`) with a migration from schema 1 (level 1 open plus the restored level,
  campaign mode, tutorial at its first step on tutorial levels). A failure is explained from the failing action, actions
  numbered from 1 and ticks and stars from 0: a missing pair — "Action m (the listen) found the symbol's pair star a –
  star b unlinked."; a disconnection — "Action m (the listen): on tick t the link from star a to star b snapped and the
  symbol came apart."; incoherence — "Action m (the listen): the stars held together for at most r of the h ticks
  needed within w."; the budget — "Action m (a link of star a and star b | an unlink of star a and star b | a nudge of
  star s by ±1 | the listen) spent the last move without a win." — each followed by "Undo the last action or retry the
  level." Impact: FR-R02G1305-003, 007; SC-R02G1305-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — link the stars the dashed guides show, nudge a
star whose phase pulls the others apart, listen once the symbol is linked — each advancing when done, and can dismiss
them.

**Why this priority**: coupled phases, drift and snapping are unfamiliar; without teaching the first levels are
guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — what to do next (link, unlink, nudge or
listen), then which stars, then exactly which link or which nudge — so that the level can still be won within the moves
left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win was found in the moves left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a failed listen or running out of moves the player is told exactly what went wrong — which action failed, which
symbol pair was missing, on which tick which link snapped and the symbol came apart, the longest coherent run against
the hold, or that the moves ran out — and offered undo or a retry.

**Independent Test**: every failure explanation names the true action and numbers.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win was found in the moves left:** it says so and never suggests a useless action.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason (`r02-g13.locked`, `r02-g13.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1305-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1305-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level wins within its budget; from a state where no win is
  found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not affect stars and
  returns to its first level after any change of the play.
- **FR-R02G1305-003**: A failure MUST be explained in accessible text naming the action that failed and its cause (the
  missing pair, the tick and link where the symbol came apart, the longest coherent run against the hold, or the last
  move spent without a win), with undo and retry offered.
- **FR-R02G1305-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1305-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1305-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1305-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested link, unlink, nudge or listen, why.
- **Failure explanation**: the action that failed, its cause (missing pair, snapped link and tick, longest run, budget),
  as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1305-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1305-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is an action the rules accept.
- **SC-R02G1305-003**: Every failure explanation in 500 seeded failures names the true action and numbers.
- **SC-R02G1305-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1305-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G13-07; announcements, haptics and sound are R02-G13-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the constellation.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1305-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1305-004 |
| Goals and results | FR-R02G1305-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1305-004, 006 |
| Failure explanation | FR-R02G1305-003 |
| Daily and practice modes | FR-R02G1305-005 |
| Schema migration | FR-R02G1305-007 |
| Deterministic tests | SC-R02G1305-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn constellation is unchanged); no
  device run before ImplementationLock-100; no availability before X-R02-G13.
