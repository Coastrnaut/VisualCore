# Feature Specification: R02-G15-05 — Voxel Origami: progression and player teaching

**Feature Branch**: `445-voxel-origami-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G15-05 (migration ledger, game feature of experience R02-G15) · ID namespace FR-R02G1505-###,
SC-R02G1505-###, T-R02G1505-###

**Input**: User description: the archived R02-G15-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Voxel Origami, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/445-voxel-origami-progression-and-player-teaching`; FR-R02G1505-###,
  SC-R02G1505-###, T-R02G1505-###.
- **Packaging (ADR-0009):** teaching and progression live in the experience `r02-g15.voxel-origami` (a registered
  candidate since R02-G15-03) inside the one app.
- **Superseded parts of the source prompt:** price, "no IAP" and "meaningful premium content": Voxel Origami is free,
  so every level is playable without payment (the shared purchase controller grants it); the Round 2 lock; "content
  count 88" (the 100 certified levels stand). **Device-only items:** none beyond the round's device campaign.
  **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: hints, failure explanation), R02-F24 (progression), R02-F26
  (accessible text), the kernel, content, adapter, renderer and gestures of R02-G15-01 … 04.
- **Model:** feature 435 (Moonlit Mechanism's progression and teaching) for hints, tutorial, failure text, progress,
  daily and practice modes and the snapshot migration.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
435's answers where the games agree. Facts checked in code (read-only, 2026-11-24): `VoxelOrigamiSolver.plan` certifies a
level by a breadth-first search over quarter-turn states from the level's start turns, hinges in index order and steps
−1 before +1, skipping idle hinges and turns that collide or sweep, for at most `maxTurns` (6) turns and `workBound`
(300,000) turns tried; a plan is its list of `.turn(hinge, step)` actions; every turn spends 1 action and the play is
won the moment the shape matches the target (there is no separate run); a turn fails `collision(hinge, moving, still,
cell)` or `sweep(hinge, moving, still, cell)` and the last action spent without a match fails `budget(index)` (0-based);
undo works in playing and failed plays, a won play is final; levels 1 … 3 carry the tutorial flag; budgets are 8 … 19
in the catalog (1 … 40 allowed); the adapter prepares level (seed mod 100) + 1, keeps the chosen hinge outside the play
and snapshots `{level, records}` as schema 1; the core may not read a clock; the other round-two games' daily
multipliers are 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and 97.

- Q: How is a hint computed and what does each level reveal? → A: from the current state. A won play has no hint; a
  failed play's hint is "Undo the last action or retry the level." While playing: the solver's plan is computed from the
  current turns through a solver entry that starts from them (`plan(_:turns:)`, the certifying `plan(_:)` being that
  entry at the level's start turns); its first turn (h, s) is the hint; the whole plan must fit the actions left, or
  else, as when the work bound is exceeded or no plan exists: "No way to win was found in the actions left: undo the last
  action or retry the level." Level 1 names what moves ("The next turn swings cube k", k the hinge's tracked cube — the
  swinging cube farthest from the hinge line), level 2 the hinge ("Turn hinge h"), level 3 the exact turn ("Turn hinge h
  forward (+1)" or "Turn hinge h back (−1)"). Hints never change the state, are unlimited, do not affect stars and reset
  to level 1 after any change of the play. Impact: FR-R02G1505-002; SC-R02G1505-002.
- Q: What does the tutorial show, and when does it advance? → A: on the levels with a tutorial flag (1 … 3), three
  instructions in order: (1) "Tap a cube to choose its hinge, then drag the cube (or use Turn − and +) to turn the hinge a
  quarter turn: every cube beyond it swings" — it advances once a turn has been accepted; (2) "Orbit with two fingers to
  see every side and compare the chain with the turquoise target — a hint shows which turn is next" — it advances once
  a second turn has been accepted or the level ends (a turn that wins ends the level); (3) "If a turn would hit another
  cube the level fails: undo and choose another hinge or way" — until the level ends. `tutorial.dismiss` ends it for that
  level; undo never moves it back. Impact: FR-R02G1505-001; SC-R02G1505-001.
- Q: What are the progress and star rules? → A: stars measure the actions spent by every accepted turn record, undone
  ones included: 3 when at most the certified witness's turn count, 2 when at most that + 2, else 1; per level the best
  (least) actions spent of a won campaign play and its stars, a better result replacing a worse one; level 1 open; a
  campaign win opens the next; `level.select [n]` opens any open level and refuses others (`r02-g15.locked`);
  `level.next` moves to the next open level (refused when none, `r02-g15.locked`); the five bands of 20 are the certified
  difficulty bands. Impact: FR-R02G1505-004; SC-R02G1505-004.
- Q: How do the daily level and practice mode work? → A: the daily level is (days from 2026-01-01 to the given calendar
  date × 31) mod 100 + 1, negative day counts wrapped into 0 … 99 (31 is coprime with 100 and differs from the other
  round-two games' multipliers); the date reaches the core as `mode.daily [year, month, day]` (an impossible date is
  refused with `r02-g15.date`). Daily play follows campaign rules (a daily win records that level's best result and
  stars) but does not open levels. `mode.practice` replays the current level with the budget raised to the kernel's
  maximum (40); practice results never award stars or open levels; `mode.campaign` returns. Impact: FR-R02G1505-005;
  SC-R02G1505-004.
- Q: Where does progress live, how is it versioned and how is a failure explained? → A: as feature 435: progress and the
  mode are part of the experience state and its digest; the tutorial step is snapshotted but not digested; the hint
  level is presentation (held by the presenter, its search off the main actor); the chosen hinge stays presentation; the
  snapshot payload becomes schema 2 (`{level, mode, progress, records, tutorial}`) with a migration from schema 1 (level
  1 open plus the restored level, campaign mode, tutorial at its first step on tutorial levels). A failure is explained
  from the failing action, actions numbered from 1, cubes and hinges by index and cells as (x, y, z): a collision —
  "Action m (a turn of hinge h by ±1) would put cube a on cube b at (x, y, z)."; a sweep — "Action m (a turn of hinge h
  by ±1) would swing cube a through cube b at (x, y, z)."; the budget — "Action m (a turn of hinge h by ±1) spent the
  last action without a match." — each followed by "Undo the last action or retry the level." Impact: FR-R02G1505-003,
  007; SC-R02G1505-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn by playing (Priority: P1) 🎯

On the first levels a new player sees one short instruction at a time — choose a hinge and turn it to swing the cubes
beyond it, look around the solid to compare it with the turquoise target, and recover from a turn that hits another
cube — each advancing when done, and can dismiss them.

**Why this priority**: hinged chains folding in three dimensions are unfamiliar; without teaching the first levels are
guesswork.

**Independent Test**: scripted players following each instruction on the tutorial levels win.

**Acceptance Scenarios**:

1. **Given** level 1 has just opened, **When** the player follows each instruction in turn, **Then** each instruction
   advances only after its action is accepted and the level ends won.
2. **Given** an instruction is shown, **When** the player dismisses the tutorial, **Then** no further instruction is
   shown on that level and play continues unchanged.

### User Story 2 - A hint when stuck (Priority: P1)

A stuck player asks for a hint and gets progressively more specific help — which cube the next turn should move, then
which hinge, then exactly which hinge and which way — so that the level can still be won within the actions left.

**Independent Test**: on every certified level, following exact hints from the start wins within the budget.

**Acceptance Scenarios**:

1. **Given** any certified level at its start, **When** the player follows exact hints only, **Then** the level is won.
2. **Given** a state from which no win was found in the actions left, **When** a hint is asked, **Then** it says so and
   suggests undo or retry.

### User Story 3 - Understand a failure (Priority: P1)

After a turn that would land a cube on another or swing it through another, or after running out of actions, the player
is told exactly what went wrong — which turn, which cube moved, which cube was in its way and where — and offered undo
or a retry.

**Independent Test**: every failure explanation names the true action, cubes and cell.

### User Story 4 - Progress, daily and practice (Priority: P2)

Levels open in order; each records its best result and stars; a daily level comes from the date; practice relaxes the
budget without affecting progress.

**Independent Test**: scripted progress through 100 levels obeys the unlock, star, daily and practice rules.

### Edge Cases

- **A hint after the level is won or failed:** a won level has no hint; a failed one suggests undo or retry.
- **A hint when no win was found in the actions left:** it says so and never suggests a useless turn.
- **A hint search that would run long:** bounded by the solver's work limit; it never stalls the frame.
- **A locked level or an impossible date:** refused with a named reason (`r02-g15.locked`, `r02-g15.date`).
- **Practice and daily results:** never open levels; practice never awards stars.
- **A daily level still locked in the campaign:** playable as the daily level without opening it.
- **Tutorial in practice or daily mode:** shown on the tutorial levels in every mode, with the same steps.
- **An older saved state without progress:** restored with the first level open and campaign mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1505-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform actions.
- **FR-R02G1505-002**: A hint MUST be available in three progressive levels, computed from the current state so that
  following the exact hints from the start of every certified level wins within its budget; from a state where no win is
  found it says so and suggests undo or retry. A hint never changes the state, is unlimited, does not affect stars and
  returns to its first level after any change of the play.
- **FR-R02G1505-003**: A failure MUST be explained in accessible text naming the turn that failed and its cause (the
  moving cube, the cube in its way and the cell for a collision or a sweep, or the last action spent without a match),
  with undo and retry offered.
- **FR-R02G1505-004**: Progress MUST follow defined rules: the first level open, a campaign win opens the next, the five
  difficulty bands of 20 shown, a goal and a result (stars) per level.
- **FR-R02G1505-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  raise the budget without affecting progress.
- **FR-R02G1505-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G1505-007**: Progress MUST be a versioned value the experience snapshot carries, with a migration from the
  current snapshot schema (1); existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state and its order.
- **Hint**: level, the suggested turn (hinge and way), why.
- **Failure explanation**: the turn that failed, its cause (collision or sweep with the cubes and cell, or the budget),
  as text.
- **Progress**: solved levels with best actions spent and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1505-001**: On the tutorial levels, scripted players following each instruction win, and every instruction
  matches the state it was shown in.
- **SC-R02G1505-002**: For all 100 certified levels, following exact hints from the start wins; for 200 seeded
  reachable states every exact hint is a turn the rules accept.
- **SC-R02G1505-003**: Every failure explanation in 500 seeded failures names the true action, cubes and cell.
- **SC-R02G1505-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G1505-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test under 10 s.

## Assumptions

- Saving progress to disk is R02-G15-07; announcements, haptics and sound are R02-G15-06.
- The kernel's tutorial stage is dismissed by the adapter today; the tutorial steps become the experience's own state.
- The tutorial instruction, the hint and the failure text appear as wrapping text in the control panel on iPhone and
  iPad, never over the solid.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G1505-001, 002 |
| Pacing (bands, unlocks) | FR-R02G1505-004 |
| Goals and results | FR-R02G1505-004 |
| Meaningful content (all 100 levels, free) | FR-R02G1505-004, 006 |
| Failure explanation | FR-R02G1505-003 |
| Daily and practice modes | FR-R02G1505-005 |
| Schema migration | FR-R02G1505-007 |
| Deterministic tests | SC-R02G1505-001 … 004 |

## Negative Requirements / Excluded scope

- All text and rules are original; no new art, model or shader (the existing code-drawn solid is unchanged); no device
  run before ImplementationLock-100; no availability before X-R02-G15.
