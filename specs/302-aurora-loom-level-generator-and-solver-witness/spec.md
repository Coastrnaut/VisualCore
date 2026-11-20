# Feature Specification: R02-G01-02 — Aurora Loom: level generator and solver witness

**Feature Branch**: `302-aurora-loom-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

**Ledger gate**: R02-G01-02 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0102-###,
SC-R02G0102-###, T-R02G0102-###

**Input**: User description: the archived R02-G01-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Aurora Loom, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/302-aurora-loom-level-generator-and-solver-witness`; FR-R02G0102-###,
  SC-R02G0102-###, T-R02G0102-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free) in `Packages/ExperiencesRound02/AuroraLoom`;
  this feature extends `AuroraLoomCore` (R02-G01-01) with the generator, the solver and the witness files.
- **Content count:** the canonical catalog is the 100-level manifest of Auto-Creator.md section 7 (`python3
  scripts/planning_index.py levels --experience R02-G01`, 20 levels in each of bands 1 … 5, each with its planned seed and
  move budget); the source's "80 stages" is a milestone only.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as in R02-G01-01). **Device-only
  items:** none (generation and certification run on the host). **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: the rules from R02-G01-01) and R02-F24 (catalog digest and
  progression rule); R02-F03 numbers.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always reach the harmony within the move allowance; the game has proof of it
for every level.

**Why this priority**: an unsolvable level breaks the game's promise.

**Independent Test**: each level's stored witness, replayed from its start, wins within the allowance.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness moves are replayed, **Then** the level is won with moves to spare or
   exactly at the allowance.
2. **Given** any catalog level, **When** the solver is run again, **Then** it finds the same shortest solution length.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget, the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics taken from the solver's actual work and the shortest solution; harder bands ask
for more moves and finer accuracy, never for tinier gestures.

**Independent Test**: band by band, the shortest solution and the solver work rise or stay; within the catalog the
progression rule holds.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the action witness, the per-move state fingerprints, the final
residual and a counterexample showing a near-miss that fails; any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose first candidate is unsolvable within the allowance or already won:** the generator moves to the next
  candidate deterministically and records how many it skipped.
- **A solver that would exceed its work budget:** the exact grid search decides; a level is never shipped unproven.
- **A level the counterexample cannot be built for:** refused (every level must show a failing near-miss).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0102-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget, and only levels the solver proves solvable within the allowance MAY be emitted.
- **FR-R02G0102-002**: A solver MUST find a shortest winning setting from any level's start, using bounded coordinate
  descent first and an exact grid search when descent does not prove optimality, within a stated work budget.
- **FR-R02G0102-003**: Each level MUST carry difficulty metrics (shortest solution, solver work, winning settings
  available) derived from the solver.
- **FR-R02G0102-004**: Each level MUST have a witness record (level, action witness, per-move fingerprints, terminal
  residual, failing counterexample) stored as a versioned file; damaged, newer and edited files MUST be refused.
- **FR-R02G0102-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy a progression rule.
- **FR-R02G0102-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST be unchanged except
  additive; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: shortest move count, a shortest action list, work spent, winning settings per ribbon, method used.
- **Difficulty**: shortest moves, solver work, tolerance and speed of the level.
- **Witness**: schema, level stored form, actions, per-move fingerprints, terminal worst residual, counterexample.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0102-001**: All 100 catalog levels are won by replaying their witness within the allowance; none starts won.
- **SC-R02G0102-002**: The solver's shortest length equals an exhaustive check on every catalog level and on 500 seeded
  levels; descent and the grid search agree whenever descent claims a result.
- **SC-R02G0102-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G0102-004**: Mean shortest solution and mean solver work do not fall from one band to the next; the catalog
  keeps its progression rule.
- **SC-R02G0102-005**: Every counterexample fails with a named gate, ribbon and tick; edited, newer and damaged witness
  files are refused.
- **SC-R02G0102-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- The 100 witness files live in `docs/games/aurora-loom/levels/` as the manifest names them; they are regenerated by a
  test run with an explicit opt-in and checked byte for byte on every other run.
- Levels are presented, hinted and played through later features (R02-G01-03 … 07).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0102-001, 002 |
| Certificates (witness, counterexample) | FR-R02G0102-004 |
| Difficulty metrics | FR-R02G0102-003, 005 |
| INV-06 content witnesses | FR-R02G0102-002, 004 |
| No Stage One breakage | FR-R02G0102-006 |

## Negative Requirements / Excluded scope

- No rendering, gestures, hints UI, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels.
