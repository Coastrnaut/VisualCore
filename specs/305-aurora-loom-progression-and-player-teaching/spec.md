# Feature Specification: R02-G01-05 — Aurora Loom: progression and player teaching

**Feature Branch**: `305-aurora-loom-progression-and-player-teaching` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

**Ledger gate**: R02-G01-05 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0105-###,
SC-R02G0105-###, T-R02G0105-###

**Input**: User description: the archived R02-G01-05 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Provide tutorial hints, pacing, goals and meaningful premium content" for Aurora Loom, with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/305-aurora-loom-progression-and-player-teaching`; FR-R02G0105-###,
  SC-R02G0105-###, T-R02G0105-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate) in
  `Packages/ExperiencesRound02/AuroraLoom`.
- **Superseded parts of the source prompt:** "meaningful premium content", price and "no IAP": Aurora Loom is free under
  the shared purchase controller; every one of its 100 levels is included and nothing is sold, advertised or locked behind
  payment. The source's "content count 80" is a milestone. The Round 2 lock and per-round device campaign
  (ImplementationLock-100). **Device-only items:** none. **Owner-only items:** none.
- **Shared features used:** R02-F24 (catalog and progression rule), the solver and certified catalog of R02-G01-02, the
  kernel, renderer and controls of R02-G01-01 … 04.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Learn the loom from the first level (Priority: P1) 🎯

A new player opens level 1, sees one short instruction for the current step (drag an anchor, turn a dial, meet the
markers), and the instruction advances as they act; nothing blocks play and the tutorial can be dismissed.

**Why this priority**: players who do not understand the goal leave in the first minute.

**Independent Test**: on levels 1 … 3 the instruction shown follows the player's actions in the defined order and never
prevents a move.

**Acceptance Scenarios**:

1. **Given** level 1 just opened, **When** the player has made no move, **Then** the first instruction names the anchor of
   the furthest-off ribbon.
2. **Given** a tutorial step is shown, **When** the player performs it, **Then** the next step is shown; dismissing ends the
   tutorial for that level.

### User Story 2 - Ask for a hint, step by step (Priority: P1)

A stuck player asks for a hint: the first hint names which ribbon to change, the second which control, the third the
exact step; hints come from the solver, are never wrong and never move anything by themselves.

**Independent Test**: for every certified level and many reachable states, each hint level names a change that lies on a
shortest remaining solution.

### User Story 3 - Understand a failure (Priority: P1)

When the moves run out, the player sees which ribbon and gate were furthest off and by how much, in words, and is offered
undo or retry — never a generic "Wrong".

**Independent Test**: every failure explanation names the same ribbon, gate and residual as the kernel's failure.

### User Story 4 - Pace and goals across 100 levels (Priority: P2)

Levels are grouped in five bands; finishing a level opens the next; each level shows its goal (moves allowed, the best
possible) and a result (stars for meeting the shortest solution); a daily level is chosen from the local date; a practice
mode allows unlimited undo and hints without spending moves.

**Independent Test**: the unlock order, star rules, daily choice and practice rules hold for scripted progress.

### Edge Cases

- **A hint asked in a state with no solution within the remaining moves:** the hint says so and offers undo.
- **A hint asked when already won or failed:** no hint; the result is shown instead.
- **A level picked that is not yet open:** refused with the reason; the open level stays.
- **The local date at midnight, time zone changes, a date before 2026:** the daily level is a fixed function of the
  calendar date in the player's calendar; any date maps to a level 1 … 100.
- **Practice mode:** moves are not limited; results in practice never award stars or open levels.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0105-001**: Levels with a tutorial MUST show one instruction at a time, derived from the current state, that
  advances when the player performs it and can be dismissed; instructions never block or perform moves.
- **FR-R02G0105-002**: A hint MUST be available in three progressive levels (ribbon, control, exact step), computed from
  the solver for the current state so that following it keeps a shortest remaining solution; a hint never changes the
  state.
- **FR-R02G0105-003**: A failure MUST be explained in accessible text naming the furthest-off ribbon, gate, tick and
  residual (the kernel's failure) with undo and retry offered.
- **FR-R02G0105-004**: Progress MUST follow defined rules: the first level open, solving a level opens the next, the
  catalog's bands shown, a goal (allowance, best possible) and a result (stars) per level.
- **FR-R02G0105-005**: A daily level MUST be a deterministic function of the local calendar date; a practice mode MUST
  allow unlimited moves and hints without affecting progress.
- **FR-R02G0105-006**: All 100 levels MUST be playable without payment, advertising, accounts or network.
- **FR-R02G0105-007**: Progress MUST be a versioned value the experience snapshot carries (saving to disk is R02-G01-07);
  existing tests pass; new public names documented; the reference regression passes.

### Key Entities

- **Tutorial step**: the instruction for the current state (which handle to use, what to aim for), its order.
- **Hint**: level (ribbon, control, step), the suggested move, the remaining shortest length.
- **Failure explanation**: ribbon, gate, tick, residual, text.
- **Progress**: solved levels with best move counts and stars, the open frontier, the mode (campaign, practice, daily).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0105-001**: On levels 1 … 3, scripted players following each instruction win, and every instruction matches
  the state it was shown in.
- **SC-R02G0105-002**: For all 100 certified levels and 2,000 seeded reachable states, every hint names a move after which
  the shortest remaining solution is one shorter (or the hint correctly reports no solution within the moves left).
- **SC-R02G0105-003**: Every failure explanation in 500 seeded failures names the kernel's failure exactly.
- **SC-R02G0105-004**: Scripted progress through 100 levels obeys the unlock, star, daily and practice rules; the daily
  level for every date 2026-01-01 … 2036-12-31 lies in 1 … 100 and is stable.
- **SC-R02G0105-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test finishes in under
  10 seconds.

## Assumptions

- Saving progress to disk, the gallery and replay are R02-G01-07; full accessibility polish R02-G01-06.
- The teaching text is original; the design is the project's own.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tutorial hints | FR-R02G0105-001, 002 |
| Pacing and goals | FR-R02G0105-004 |
| Failure-specific coaching | FR-R02G0105-003 |
| Modes (Play, Practice, Daily-Seed Equivalent) | FR-R02G0105-004, 005 |
| "Meaningful premium content" | superseded: free, all levels included (FR-R02G0105-006) |
| No Stage One breakage | FR-R02G0105-007 |

## Negative Requirements / Excluded scope

- No purchase prompt, advertising, account, streak pressure, network, timed challenge or automatic solving.
