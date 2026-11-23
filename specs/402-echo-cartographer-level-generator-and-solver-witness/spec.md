# Feature Specification: R02-G11-02 — Echo Cartographer: level generator and solver witness

**Feature Branch**: `402-echo-cartographer-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

**Ledger gate**: R02-G11-02 (migration ledger, game feature of experience R02-G11) · ID namespace FR-R02G1102-###,
SC-R02G1102-###, T-R02G1102-###

**Input**: User description: the archived R02-G11-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Echo Cartographer, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/402-echo-cartographer-level-generator-and-solver-witness`; FR-R02G1102-###,
  SC-R02G1102-###, T-R02G1102-###.
- **Packaging (ADR-0009):** experience R02-G11 (`r02-g11.echo-cartographer`, free) in the one app; this feature extends
  the pure `EchoCartographerCore` of feature 401.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G11`: 20 levels in each of bands 1 … 5, each with its planned seed
  and energy budget 8 … 19). The prompt's "content count 90" (the catalog's "90 solver-certified stages") is a
  milestone figure, as for the earlier round-two games.
- **Model:** feature 392 (Backwards Aurora's content pipeline) for manifest, generator, witness files, digest and
  progression.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved by reasoning (Priority: P1) 🎯

A player opening any of the 100 levels can always find every beacon: some pulses within the energy, each from a cell
already known to be open, give echoes that leave exactly one possible place for every beacon, and claiming those places
wins. The game has proof of it for every level.

**Why this priority**: an unsolvable level, or one that can only be won by guessing, breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the energy; every
pulse's echo equals the stored digest; the proof that the echoes allow only one beacon placement is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the energy.
2. **Given** any catalog level, **When** its witness stops one pulse short, **Then** more than one beacon placement
   still fits the echoes heard so far.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and energy the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the pulses the witness needs, the chamber's size
and open cells, the beacons, the tolerance, the candidate placements before the last pulse and the solver's work.
Harder bands mean larger chambers, more beacons and tighter tolerance, never faster reactions.

**Independent Test**: band by band, the mean witness pulse count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of every echo and the counterexample:
one pulse short, two beacon placements that both fit. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **Echoes that never single out the beacons:** such a candidate is never emitted.
- **More than one pulse plan:** allowed; the witness is the one the solver finds in its fixed order.
- **A plan needing more energy than the level has:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1102-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and energy; only levels the solver certifies within the energy MAY be emitted.
- **FR-R02G1102-002**: A solver MUST find a pulse plan, each pulse from a cell known open at its turn, after which
  exactly one beacon placement fits every echo heard, with its work bounded and counted; every plan it reports MUST be
  replayed through the kernel.
- **FR-R02G1102-003**: Each level MUST carry difficulty metrics (witness pulses, chamber size and open cells, beacons,
  tolerance, placements fitting before the last pulse, solver work) derived from the level and the solver.
- **FR-R02G1102-004**: Each level MUST have a versioned witness record (level, actions, per-pulse echo digests,
  counterexample); damaged, newer and edited files MUST be refused.
- **FR-R02G1102-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness pulse count never fall.
- **FR-R02G1102-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, energy budget.
- **Inference proof**: the echoes heard and the beacon placements that fit them (exactly one at the end).
- **Solver result**: the pulse plan, the claims, the work counted, the proof.
- **Difficulty**: witness pulses, chamber size, open cells, beacons, tolerance, placements before the last pulse, work.
- **Witness**: schema, the level's stored form, actions, per-pulse echo digests, counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1102-001**: All 100 catalog levels are won by replaying their witness within the energy.
- **SC-R02G1102-002**: The uniqueness proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1102-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1102-004**: The mean witness pulse count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1102-005**: For every level, one pulse short of its witness at least two beacon placements fit; edited, newer
  and damaged witness files are refused.
- **SC-R02G1102-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/echo-cartographer/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Unique beacon inference proof" is read as: after the witness pulses, exactly one placement of the level's beacon
  count on the chamber's reachable open cells reproduces every echo heard. The proof uses the chamber as built; the
  pulses' revealed walls and the echoes are what the player reasons from.
- Levels are presented, hinted and played through later features (R02-G11-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and energy budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels (seeded room generator) | FR-R02G1102-001, 002 |
| Solver: grid chamber generator with connected-component and unique beacon inference proof | FR-R02G1102-002 |
| Truth metric: ray travel distance agreement and beacon localization error | FR-R02G1102-002, 003 |
| Certificates (witness, counterexample, per-pulse echo digests) | FR-R02G1102-004 |
| Difficulty metrics | FR-R02G1102-003, 005 |
| Invariants INV-06 content and INV-12 novelty | FR-R02G1102-002, 003 |
| Schema migration, error handling | FR-R02G1102-004, 006 |
| Deterministic tests | SC-R02G1102-002, 003 |
| No Stage One breakage | FR-R02G1102-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
