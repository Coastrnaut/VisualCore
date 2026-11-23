# Feature Specification: R02-G10-02 — Backwards Aurora: level generator and solver witness

**Feature Branch**: `392-backwards-aurora-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G10-02 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1002-###,
SC-R02G1002-###, T-R02G1002-###

**Input**: User description: the archived R02-G10-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Backwards Aurora, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/392-backwards-aurora-level-generator-and-solver-witness`; FR-R02G1002-###,
  SC-R02G1002-###, T-R02G1002-###.
- **Packaging (ADR-0009):** experience R02-G10 (`r02-g10.backwards-aurora`, free) in the one app; this feature extends
  the pure `BackwardsAuroraCore` of feature 391.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G10`: 20 levels in each of bands 1 … 5, each with its planned seed
  and reversal budget 8 … 19). The prompt's "content count 76" (the catalog's "76 solver-certified stages") is a
  milestone figure, as for the earlier round-two games.
- **Model:** feature 382 (Nocturne Garden's content pipeline) for manifest, generator, witness files, digest and
  progression.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always fold the aurora back: some sequence of reversals within the budget
brings every checkpoint to its true height with every bend within the limit, without tearing the aurora. The game has
proof of it for every level.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness reversals, replayed from the start, win within the budget, and every
reversal's state equals the stored digests.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** its witness stops one reversal short, **Then** the level is not yet won.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds a winning sequence with the same
   smallest number of reversals.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and reversal budget the same way on every build; a changed rule or
seed changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the smallest number of reversals, the wave's
length, the number of checkpoints, how much of the wave the witness reverses, the bend and breaking limits and how much
work the solver did. Harder bands need more reversals over longer waves with tighter limits, never faster reactions.

**Independent Test**: band by band, the mean smallest reversal count does not fall; the catalog keeps the progression
rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning reversals, a digest of the state after every reversal and
counterexamples: the witness one reversal short is not yet won, and no shorter sequence can win. Any edited or fake
witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **More than one winning sequence:** allowed; the witness is the first one the solver finds in its fixed order.
- **A sequence that would win but tears the aurora on the way:** never a solution; the search never continues from a
  failed state.
- **A level whose smallest reversal count exceeds its budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1002-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and reversal budget; only levels the solver proves winnable within the budget MAY be emitted.
- **FR-R02G1002-002**: A solver MUST find a winning sequence with the smallest number of reversals, with a proof that no
  shorter sequence wins, its work bounded and counted; every sequence it reports MUST be replayed through the kernel.
- **FR-R02G1002-003**: Each level MUST carry difficulty metrics (smallest reversal count, wave length, checkpoints,
  samples reversed by the witness, bend limit, breaking margin, solver work) derived from the level and the solver.
- **FR-R02G1002-004**: Each level MUST have a versioned witness record (level, reversals, per-reversal state digests,
  counterexamples); damaged, newer and edited files MUST be refused.
- **FR-R02G1002-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the smallest reversal count never fall.
- **FR-R02G1002-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, reversal budget.
- **Solver result**: smallest reversal count, a winning reversal sequence, the work counted, the proof.
- **Difficulty**: smallest reversals, wave length, checkpoints, samples reversed, bend limit, breaking margin, solver
  work.
- **Witness**: schema, the level's stored form, reversals, per-reversal digests, counterexamples, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1002-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G1002-002**: The solver's smallest reversal count equals an independent check on sampled catalog levels (at
  least two per band).
- **SC-R02G1002-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1002-004**: The mean smallest reversal count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1002-005**: Every level is not won one reversal short of its witness, and the proof covers every shorter
  sequence; edited, newer and damaged witness files are refused.
- **SC-R02G1002-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/backwards-aurora/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- The player sees the wave, the checkpoints, the limits and the reversals left; nothing is hidden.
- Levels are presented, hinted and played through later features (R02-G10-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and reversal budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1002-001, 002 |
| Solver: interval dynamic programming over reversible wave segments and endpoint continuity constraints | FR-R02G1002-002 |
| Truth metric: normalized signal edit distance and continuity | FR-R02G1002-002, 003 |
| Certificates (witness, counterexamples, per-reversal digests) | FR-R02G1002-004 |
| Difficulty metrics | FR-R02G1002-003, 005 |
| Schema migration, error handling | FR-R02G1002-004, 006 |
| Deterministic tests | SC-R02G1002-002, 003 |
| No Stage One breakage | FR-R02G1002-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
