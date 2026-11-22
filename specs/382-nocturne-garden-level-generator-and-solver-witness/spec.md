# Feature Specification: R02-G09-02 — Nocturne Garden: level generator and solver witness

**Feature Branch**: `382-nocturne-garden-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G09-02 (migration ledger, game feature of experience R02-G09) · ID namespace FR-R02G0902-###,
SC-R02G0902-###, T-R02G0902-###

**Input**: User description: the archived R02-G09-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Nocturne Garden, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/382-nocturne-garden-level-generator-and-solver-witness`; FR-R02G0902-###,
  SC-R02G0902-###, T-R02G0902-###.
- **Packaging (ADR-0009):** experience R02-G09 (`r02-g09.nocturne-garden`, free) in the one app; this feature extends
  the pure `NocturneGardenCore` of feature 381.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G09`: 20 levels in each of bands 1 … 5, each with its planned seed
  and move budget 8 … 19). The prompt's "content count 76" (the catalog's "76 solver-certified stages") is a milestone
  figure, as for the earlier round-two games.
- **Model:** feature 372 (Faceted Forge's content pipeline) for manifest, generator, witness files, digest and
  progression.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always reach the target: some arrangement of blooms and sun within the move
budget casts a shadow that matches the target closely enough without leaking beyond the allowance. The game has proof of
it for every level.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget, and every
action's state equals the stored digests.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** its witness stops one action short, **Then** the level is not yet won (the
   target needs every action).
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds a winning sequence with the same
   smallest number of moves.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the smallest number of moves, how many distinct
bloom kinds and sizes the witness uses, whether the sun must change, the target's and the forbidden regions' cell
counts, the required match and how much work the solver did. Harder bands need more blooms and finer fits, never faster
reactions.

**Independent Test**: band by band, the mean smallest move count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action and
counterexamples: the witness one action short is not yet won, and no shorter sequence can win. Any edited or fake
witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **More than one winning sequence:** allowed; the witness is the first one the solver finds in its fixed cut order.
- **An arrangement that reaches the match only by leaking beyond the allowance:** never a solution; the search never
  continues from a failed state.
- **A level whose smallest move count exceeds its budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0902-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves winnable within the budget MAY be emitted.
- **FR-R02G0902-002**: A solver MUST find a winning sequence with the smallest number of moves, with a proof that no
  shorter sequence wins, its work bounded and counted; every sequence it reports MUST be replayed through the kernel.
- **FR-R02G0902-003**: Each level MUST carry difficulty metrics (smallest move count, distinct kinds and sizes of the
  witness, sun change, target and forbidden cells, required match, solver work) derived from the level and the solver.
- **FR-R02G0902-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  counterexamples); damaged, newer and edited files MUST be refused.
- **FR-R02G0902-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the smallest move count never fall.
- **FR-R02G0902-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: smallest move count, a winning action sequence, the work counted (the proof).
- **Difficulty**: smallest moves, distinct kinds, distinct sizes, sun change, target cells, forbidden cells, required
  match, solver work.
- **Witness**: schema, the level's stored form, actions, per-action digests, counterexamples, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0902-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G0902-002**: The solver's smallest move count equals an independent check on sampled catalog levels (at least
  two per band).
- **SC-R02G0902-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G0902-004**: The mean smallest move count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G0902-005**: Every level is not won one action short of its witness and with every shorter sequence the proof
  covers; edited, newer and damaged witness files are refused.
- **SC-R02G0902-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/nocturne-garden/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- The player sees the target, the forbidden regions, the supply, the match and the leak; nothing is hidden.
- Levels are presented, hinted and played through later features (R02-G09-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0902-001, 002 |
| Solver: grid-snapped candidate placements with stencil overlap and shape-distance scoring | FR-R02G0902-002 |
| Truth metric: mask intersection-over-union and contour Hausdorff proxy | FR-R02G0902-002, 003 |
| Certificates (witness, counterexamples, per-action digests) | FR-R02G0902-004 |
| Difficulty metrics | FR-R02G0902-003, 005 |
| Schema migration, error handling | FR-R02G0902-004, 006 |
| Deterministic tests | SC-R02G0902-002, 003 |
| No Stage One breakage | FR-R02G0902-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
