# Feature Specification: R02-G11-02 — Echo Cartographer: level generator and solver witness

**Feature Branch**: `402-echo-cartographer-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

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

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
392's answers where the games agree. Facts checked (read-only, 2026-11-23): R02-G11-01's `EchoCartographerChamber`
(W, H 5 … 16, rays, breadth-first path lengths), `EchoCartographerLevel` (1 … 4 beacons, tolerance 0 … 2, energy
1 … 60, miss cost 1 … 3, the claim rule), `EchoCartographerPlay` and `EchoCartographerRules`; R02-F24's
`PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at most 1, jump at most 3);
`SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries (`planning_index.py levels
--experience R02-G11`: bands 1 … 5 × 20, energy budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19). The acceptance
ranges below were measured before they were written down: a prototype of the solver over 60 candidates per band gave
witness pulse counts mostly 2 (band 1), 2 … 3 (band 2), 3 (bands 3 and 4) and 3 … 6 (band 5), every band reaching its
range in at least 8 % of candidates, with at most about 50 000 nodes of work.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, energy) are a table
  in `EchoCartographerManifest` with their provenance. Candidate c of entry n draws from `SeededRandom(seed:
  SeedDerivation.derive(plannedSeed, index: c))`, in this order: the width and the height by band (6 … 7, 7 … 9, 8 … 10,
  9 … 12, 10 … 14, each drawn); every cell in index order a wall with chance 1 in 5 (bands 1 … 2) or 1 in 4 (bands
  3 … 5); the entry among the open cells; the entry's region (the open cells reachable from it), which must hold at
  least 12 cells or the candidate is skipped; the beacon count by band (1, 1 … 2, 2, 2 … 3, 3 … 4); the beacons drawn one
  by one from the region without the entry. Tolerance by band 1, 1, 1, 0, 0; miss cost 1, 1, 2, 2, 3; energy = the
  manifest's; ids `echo-cartographer-NNN`; tutorial on levels 1 … 3; difficulty = band. A candidate the solver does not
  certify with a witness pulse count in its band's range (1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6) and at most energy − 1
  pulses within its work bound is skipped; at most 256 candidates, then `generation(n)`. Impact: FR-R02G1102-001, 006;
  SC-R02G1102-001, 003, 004.
- Q: How does the solver plan the pulses, and what proves the beacons are singled out? → A: a placement is a set of
  beacon-count distinct cells of the region other than the entry; it fits the echoes heard when, for every pulse heard,
  the sorted path lengths from that pulse's emitter to its cells equal the reported echoes. The fitting placements are
  counted by a depth-first enumeration over the cells that fit every pulse singly, in cell-index order, pruning a
  partial placement whose distance counts already exceed any pulse's echoes; counts stop at 1 000 ("at least 1 000").
  The solver is greedy: starting from the opening knowledge, at each turn it tries every cell known open and not yet
  pulsed, in cell-index order, counts the placements that would fit after that pulse's echo, and pulses the cell with
  the fewest (ties: lowest index), revealing its rays; it stops when exactly one placement fits (the true beacons, which
  always fit) and gives up after 6 pulses. Work = enumeration nodes visited, counted and bounded at 400 000 per
  candidate; over the bound the candidate is skipped. The witness is the plan's pulses followed by one claim on each
  beacon's cell in beacon order, replayed through the kernel's play. Impact: FR-R02G1102-002; SC-R02G1102-001, 002,
  005.
- Q: What difficulty metrics are stored and what progression is required? → A: `EchoCartographerDifficulty` holds the
  witness pulse count, the width and height, the region's cells, the beacons, the tolerance, the placements fitting
  before the last pulse (at most 1 000) and the solver work. The catalog in manifest order keeps R02-F24's standard
  `ProgressionRule` (drop at most 1, jump at most 3) on the witness pulse count; the band ranges, each one pulse wide and
  meeting the next band's at one value, make band means non-decreasing. Impact: FR-R02G1102-003, 005; SC-R02G1102-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/echo-cartographer/levels/NNN.witness.json`,
  JSON schema 1 with sorted keys: number, the level's stored form, the actions, the echo digest after every pulse (16 hex
  characters of the SHA-256 of the emitter, the rays and the echoes), the placements fitting after every pulse, the play
  fingerprints after `begin` (and `dismissTutorial` when the level has one) and after each action, the counterexample
  (the first two placements, in enumeration order, that fit every pulse but the last), the difficulty and the candidates
  skipped. A test rebuilds every witness and compares bytes; it writes the files only with
  `ECHO_CARTOGRAPHER_WRITE_WITNESSES=1`. Decoding refuses newer schemas, damaged files and witnesses that no longer
  replay. Impact: FR-R02G1102-004; SC-R02G1102-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<EchoCartographerRules>.digest(id: "echo-cartographer", identities:)` over the 100 level fingerprints
  in manifest order, pinned in a test. Certification tests are split into groups of 5 levels so each runs under 10
  seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per process. New
  refusals: `generation(Int)` (`r02-g11.generation`) and `witness(String)` (`r02-g11.witness`). The independent check
  of SC-R02G1102-002 recomputes path lengths by fixed-point relaxation and counts fitting placements by brute force over
  every beacon-count subset of the region on two levels per band (the two smallest regions of the band), and confirms
  exactly one fits after the witness and at least two before its last pulse. Impact: FR-R02G1102-004, 006;
  SC-R02G1102-002, 003, 006.

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
