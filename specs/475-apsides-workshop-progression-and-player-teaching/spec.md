# Feature Specification: R02-G18-05 — Apsides Workshop: progression and player teaching

**Feature Branch**: `475-apsides-workshop-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Draft

**Ledger gate**: R02-G18-05 (migration ledger, game feature of experience R02-G18) · ID namespace FR-R02G1805-###,
SC-R02G1805-###, T-R02G1805-###

**Input**: User description: the archived R02-G18-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Apsides Workshop, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/475-apsides-workshop-progression-and-player-teaching`; FR-R02G1805-###,
  SC-R02G1805-###, T-R02G1805-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g18.apsides-workshop` (a registered
  candidate since R02-G18-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Apsides Workshop is
  free, so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock;
  "content count 78" (the 100 certified levels stand); the paths `Apps/ApsidesWorkshop` and
  `Packages/GameModules/ApsidesWorkshopCore` (the experience lives in `Packages/ExperiencesRound02/ApsidesWorkshop`).
  **Device-only items:** none beyond the round's device campaign. **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G18-01 … 04.
- **Model:** feature 465 (Celestial Eclipse Lab's progression and teaching) for hints from a solver entry at the current
  state, tutorial, failure text, progress, daily and practice modes and the snapshot migration.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — turn the periapsis knob to shape and aim the
orbit, change its size, watch the gauges, then play the revolution when every target reads in its band — each advancing
when done, and can dismiss them.

**Why this priority**: tuning an ellipse by its eccentricity, periapsis direction and size to sweep sky sectors is
unfamiliar; without teaching the first levels are guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which lever to change next (the periapsis
knob or the size), then which way and how far, then exactly which setting — so that the level can still be won within
the actions left.

**Why this priority**: predicting how a change of eccentricity, direction or size moves the swept shares and the
apsides is hard to do in the head; a hint keeps the player moving.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only and then plays the
   revolution, **Then** the level is won.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a revolution that struck a planet, reached a target out of order, swept a share outside its band, or put an apsis
in the wrong sector or at the wrong distance, the player is told exactly what went wrong — which planet or target, at
which tick, with which reading — and offered undo or a retry.

**Why this priority**: the failure happens during the revolution; without words the player cannot see what to change.

**Independent Test**: every failure explanation names the true planet or target, tick and reading.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Why this priority**: pacing across 100 levels and a reason to return.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when the current orbit already wins:** it says to play the revolution.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless tuning.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason (`r02-g18.locked`, `r02-g18.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1805-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1805-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level, then playing the revolution, wins within its
  budget; from a state where no win is found it says so and suggests undo or retry. A hint never changes the state, is
  unlimited, does not affect stars and returns to its first level after any change of the play.
- **FR-R02G1805-003**: A failure MUST be explained in accessible text naming its cause (the planet struck and the tick;
  the target reached out of order and the tick; the target whose share fell outside its band, with the share; or the
  apsis target with the sector or distance it read), with undo and retry offered.
- **FR-R02G1805-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1805-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1805-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1805-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); refusals carry named reason codes; existing tests pass; new public names documented;
  the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested tuning (the periapsis knob's eccentricity and direction, or the size), why.
- **Failure explanation**: the cause (a planet contact, a target out of order, a share outside its band, an apsis in the
  wrong sector or at the wrong distance) with the planet or target, tick and reading, as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice,
  daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1805-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1805-002**: For all 100 certified levels, following exact hints from the start and then playing the
  revolution wins; for 200 seeded reachable states every exact hint is a tuning the rules accept.
- **SC-R02G1805-003**: Every failure explanation in 500 seeded failures names the true planet or target, tick and
  reading.
- **SC-R02G1805-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1805-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G18-07; announcements, haptics and sound are R02-G18-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the sky.
- Observability: refused progression actions are logged by reason code, as the presenter already logs refusals.
- Accessibility: every new text is plain, ordered and available to VoiceOver as panel text; nothing relies on colour.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1805-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1805-004 |
| Goals and results | FR-R02G1805-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1805-004, 006 |
| Failure explanation | FR-R02G1805-003 |
| Daily and practice modes | FR-R02G1805-005 |
| Schema migration | FR-R02G1805-007 |
| Deterministic tests | SC-R02G1805-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn compass is unchanged); no device
  run before ImplementationLock-100; no availability before X-R02-G18.
