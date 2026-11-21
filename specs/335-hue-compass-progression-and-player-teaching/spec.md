# Feature Specification: R02-G04-05 — Hue Compass: progression and player teaching

**Feature Branch**: `335-hue-compass-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G04-05 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0405-###,
SC-R02G0405-###, T-R02G0405-###

**Input**: User description: the archived R02-G04-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Progression and player teaching" for Hue Compass (tutorials, hints, failure explanation, unlocks, daily and practice
modes), with the canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/335-hue-compass-progression-and-player-teaching`; FR-R02G0405-###,
  SC-R02G0405-###, T-R02G0405-###.
- **Packaging (ADR-0009):** experience R02-G04 (`r02-g04.hue-compass`, free, a registered candidate) in
  `Packages/ExperiencesRound02/HueCompass`; this feature extends its Core, adapter and experience target.
- **Superseded parts of the source prompt:** price, "no IAP", paid unlocks and the Round 2 lock; every level is free.
  **Device-only items:** none. **Owner-only items:** none.
- **Model:** feature 325 (Wave Knot Keeper's progression and player teaching).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — aim, probe, read the clue, select — each
advancing when done, and can dismiss them.

**Independent Test**: scripted players following each instruction on levels 1 … 3 win.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help: what to do next, where to do it, and exactly
which action — a probe that narrows the possible targets, or the selection once one fits every clue.

**Independent Test**: on every certified level, following exact hints from the start wins within the allowance.

### User Story 3 - Understand a failure (Priority: P1)

After a miss or running out of probes the player is told exactly why — how far the selection was from the target, or
that the probes ran out — and offered undo or retry.

**Independent Test**: every failure explanation names the true distances or the exhausted allowance.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice raises the
allowance without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint asked after every candidate is settled:** it names the selection.
- **A hint when probes are nearly spent:** it never suggests a probe that would spend the last unit; it suggests the
  best selection instead.
- **A locked level or an impossible date:** refused with a named reason.
- **Practice and daily results:** never open levels; practice never awards stars.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0405-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G0405-002**: A hint MUST be available in three progressive levels, computed from the clues seen so that
  following the exact hints from any reachable state keeps the level winnable within the allowance when it still is; a
  hint never changes the state, is unlimited, does not affect stars and returns to its first level after any change of
  the play.
- **FR-R02G0405-003**: A failure MUST be explained in accessible text (the selection's distance from the target in
  bearings and bands, or the exhausted allowance) with undo and retry offered.
- **FR-R02G0405-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, bands
  shown, a goal and a result (stars) per level.
- **FR-R02G0405-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the allowance without affecting progress.
- **FR-R02G0405-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0405-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema; existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state, its order.
- **Hint**: level, the suggested action, why.
- **Failure explanation**: the reason and the distances, text.
- **Progress**: solved levels with best units spent and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0405-001**: On levels 1 … 3, scripted players following each instruction win, and every instruction matches
  the state it was shown in.
- **SC-R02G0405-002**: For all 100 certified levels, following exact hints from the start wins within the allowance; for
  2,000 seeded reachable states every exact hint is a legal action that never spends the last unit on a probe.
- **SC-R02G0405-003**: Every failure explanation in 500 seeded failures names the true distances or the exhausted
  allowance.
- **SC-R02G0405-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0405-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G04-07; announcements and haptics are R02-G04-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps are the experience's own state.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorials | FR-R02G0405-001 |
| Hints | FR-R02G0405-002 |
| Failure explanation | FR-R02G0405-003 |
| Unlocks, stars, bands | FR-R02G0405-004 |
| Daily and practice modes | FR-R02G0405-005 |
| No paywall or ads | FR-R02G0405-006 |
| Schema migration | FR-R02G0405-007 |

## Negative Requirements / Excluded scope

- No paid unlocks, no advertising, no accounts, no network, no saving to disk in this feature, no device run.
