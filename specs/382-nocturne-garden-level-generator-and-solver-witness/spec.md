# Feature Specification: R02-G09-02 — Nocturne Garden: level generator and solver witness

**Feature Branch**: `382-nocturne-garden-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

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

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
372's answers where the games agree. Facts checked in code (read-only, 2026-11-22): R02-G09-01's `NocturneGardenLevel`
(bed 16 … 32 × 12 … 24, supply total 1 … 12, sizes ⊆ 1 … 3, elevations ⊆ 1 … 4, budget 1 … 40, required match p/q,
leak allowance), `NocturneGardenBloom` (exact cells), `NocturneGardenMask`, `NocturneGardenPlay` and
`NocturneGardenRules`; R02-F24's `PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at most
1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries
(`planning_index.py levels --experience R02-G09`: bands 1 … 5 × 20, move budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17,
16 … 19).

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, move budget) are a
  table in `NocturneGardenManifest` with their provenance. Candidate k of entry n draws from `SeededRandom(seed:
  SeedDerivation.derive(plannedSeed, index: k))`, in this order: the bed by band (16 × 12, 20 × 14, 24 × 16, 28 × 20, 32
  × 24); the allowed sizes (band 1: {2}; band 2: {1, 2}; bands 3 … 5: {1, 2, 3}) and elevations (bands 1 … 2: {2, 3};
  bands 3 … 5: {1, 2, 3, 4}); a construction sun; the bloom count b by band (1 … 2; 2 … 3; 3 … 4; 4 … 5; 5 … 6) and b
  blooms, each a drawn kind, size and anchor whose cast lies wholly in the bed and adds at least 3 new cells; the target
  is their exact mask; the forbidden cells are the cells outside the target within Chebyshev distance 1 (bands 1 … 2) or
  2 (bands 3 … 5) of it, each kept with probability 1/2 (bands 1 … 2) or 3/4 (bands 3 … 5); the required match is 4/5,
  17/20, 9/10, 19/20, 1/1 by band; the leak allowance 2, 2, 1, 1, 0 by band; the supply is the kinds of the b blooms
  plus, from band 3 on, one decoy of another kind; the opening sun is drawn from the allowed elevations (so a sun move
  may be needed). A candidate is kept when the solver certifies it within its work bound with a smallest move count at
  most the manifest budget; otherwise k grows, at most 256 candidates, then `generation(n)`. Ids `nocturne-garden-NNN`;
  tutorial flag on levels 1 … 3; difficulty = band; budget = manifest budget. Impact: FR-R02G0902-001, 006;
  SC-R02G0902-001, 003, 004.
- Q: How does the solver decide the smallest move count, and what proves it? → A: for each allowed elevation e (in
  ascending order) the needed shared cells are s(e) = the least s with s·q ≥ p·|T| (the union is at least the target),
  and the cover c(e) = the largest |cells ∩ T| of any single plant (every kind in the supply, size and anchor) at e with
  no leak beyond the allowance on its own; the lower bound is L = min over e of [e ≠ opening sun] + ⌈s(e) / c(e)⌉. The
  solver searches depth-first, elevation by elevation, for a winning sequence of exactly L moves: a sun move first when
  e differs from the opening, then plants among the grid-snapped candidates at e, ordered by shape score (cells in T
  minus cells outside T, then the rules' plant order), pruning when shared + remaining plants · c(e) < s(e) or the leak
  exceeds the allowance; it never continues from a failed state. A sequence of L moves found proves L is the smallest; a
  candidate whose search finds none within the bound is skipped. Work = plants evaluated, counted and bounded at 20,000
  per level. The witness is the first sequence found, replayed through the kernel's play. Impact: FR-R02G0902-002;
  SC-R02G0902-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `NocturneGardenDifficulty` holds the
  smallest move count, the distinct kinds and sizes of the witness, whether it changes the sun, the target's and the
  forbidden regions' cell counts, the required match and the solver work. The catalog in manifest order keeps R02-F24's
  standard `ProgressionRule` (drop at most 1, jump at most 3) on the smallest move count; the band ranges make band
  means non-decreasing. Impact: FR-R02G0902-003, 005; SC-R02G0902-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/nocturne-garden/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the actions, the state digest after every action (16 hex
  characters of the SHA-256 of the mask's sorted cells), the play fingerprints after `begin` and after each action, the
  smallest move count with the lower-bound argument (elevation, needed cells, cover), the near miss (the witness minus
  its last action: not won, its shared cells short of the need), the difficulty and the candidates skipped. A test
  rebuilds every witness and compares bytes; it writes the files only with `NOCTURNE_GARDEN_WRITE_WITNESSES=1`. Decoding
  refuses newer schemas, damaged files and witnesses that no longer replay. Impact: FR-R02G0902-004; SC-R02G0902-003,
  005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<NocturneGardenRules>.digest(id: "nocturne-garden", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into groups of 5 levels so each runs under 10 seconds
  on a debug host build (measured locally, not asserted on CI); generated levels are cached per process. New refusals:
  `generation(Int)` (`r02-g09.generation`) and `witness(String)` (`r02-g09.witness`). The independent check of
  SC-R02G0902-002 recomputes the lower bound by brute force over all single plants on sampled levels (two per band) and
  replays each witness on a fresh play. Impact: FR-R02G0902-002, 005, 006; SC-R02G0902-002, 006.

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
