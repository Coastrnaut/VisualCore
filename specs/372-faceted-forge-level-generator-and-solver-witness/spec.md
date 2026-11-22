# Feature Specification: R02-G08-02 — Faceted Forge: level generator and solver witness

**Feature Branch**: `372-faceted-forge-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G08-02 (migration ledger, game feature of experience R02-G08) · ID namespace FR-R02G0802-###,
SC-R02G0802-###, T-R02G0802-###

**Input**: User description: the archived R02-G08-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Faceted Forge, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/372-faceted-forge-level-generator-and-solver-witness`; FR-R02G0802-###,
  SC-R02G0802-###, T-R02G0802-###.
- **Packaging (ADR-0009):** experience R02-G08 (`r02-g08.faceted-forge`, free) in the one app; this feature extends the
  pure `FacetedForgeCore` of feature 371.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design
  (`python3 scripts/planning_index.py levels --experience R02-G08`: 20 levels in each of bands 1 … 5, each with its
  planned seed and move budget 8 … 19). The prompt's "content count 84" (the catalog's "84 solver-certified stages") is
  a milestone figure, as for the earlier round-two games.
- **Model:** feature 362 (Amethyst Escape's content pipeline) for manifest, generator, witness files, digest and
  progression.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
362's answers where the games agree. Facts checked in code (read-only, 2026-11-22): R02-G08-01's `FacetedForgeLevel`
(crystal 4 … 14 half-spaces in the box −6 … 6, budget 1 … 12, sliver 0 < s < 1/2, target 2 … budget + 1 entries of a
share and 4 … 26 faces), `FacetedForgePiece` (exact cut, canonical order), `FacetedForgePlay` and `FacetedForgeRules`;
R02-F24's `PuzzleCatalog.digest(id:identities:)` and `ProgressionRule.standard` (drop at most 1, jump at most 3);
`SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries (`planning_index.py levels
--experience R02-G08`: bands 1 … 5 × 20, move budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19). A cut with both
halves costs about 0.13 ms in a debug host build (6,962 cuts of 50 fixture crystals in 0.89 s, 2026-11-22). A
prototype of these rules (2026-11-22, debug host build) certified all 100 manifest levels in 52 s, at most 41
candidates skipped for one level, at most 16,431 cut evaluations for one search and at most 4.5 s for one level.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, move budget) are a
  table in `FacetedForgeManifest` with their provenance. Candidate k of entry n draws from `SeededRandom(seed:
  SeedDerivation.derive(plannedSeed, index: k))`, in this order: the crystal by band (band 1 a cube −a … a, a = 3 … 6;
  band 2 a box with each face at ±2 … 6; band 3 a cube a = 4 … 6 with one corner cut by x+y+z ≤ b, b = a + 1 … 3a − 2;
  band 4 an octahedron |x|+|y|+|z| ≤ a, a = 5 … 6, written with the four body diagonals; band 5 a cube a = 5 … 6 with
  two opposite corners cut, x+y+z ≤ b and x+y+z ≥ −b); the number of cuts c by band (2 … 3; 3 … 4; 4 … 5; 5 … 6; 6 … 7);
  then c cuts, each of a drawn piece (canonical order), a drawn direction (bands 1 … 2 the axes and face diagonals,
  bands 3 … 5 all 13) and a drawn depth among the middle half of those that cross it (the outer quarter on each side is
  left out, so pieces stay large enough). The target is the resulting multiset of (share, face count); the sliver limit
  is 1/64 for every level. A candidate is kept when every piece's share is at least 1/32, bands 3 … 5 use at least one
  body diagonal, and the solver certifies it within its work bound; otherwise k grows, at most 256 candidates, then
  `generation(n)`. Ids `faceted-forge-NNN`; tutorial flag on levels 1 … 3; difficulty = band; budget = manifest budget.
  To hold the manifest budgets, the kernel's ranges widen additively: budget 1 … 20 and target face counts 4 … 34 (14
  crystal planes + 20 cuts); every earlier level stays valid. Impact: FR-R02G0802-001, 006; SC-R02G0802-001, 003, 004.
- Q: How does the solver decide the smallest cut count, and what proves it? → A: each accepted cut turns one piece into
  two, so a target of P pieces needs at least P − 1 cuts: that is the lower bound, and any winning sequence of P − 1 cuts
  proves it is the smallest. The solver searches depth-first for such a sequence from the crystal alone (not from the
  generator's cuts), in the rules' fixed order (pieces in canonical order, directions 0 … 12, depths ascending), keeping
  a cut only when both halves are at least the sliver limit and the pieces can still be partitioned into the remaining
  target (each piece's share is the sum of a sub-multiset of the target, and a piece given one entry already has that
  entry's face count); it never continues from a failed state. Work = cuts evaluated, counted and bounded at 20,000 per
  level; a candidate whose search exceeds the bound is skipped. The witness is the first sequence found, replayed
  through the kernel's play. Impact: FR-R02G0802-002; SC-R02G0802-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `FacetedForgeDifficulty` holds the
  smallest cut count, the distinct directions and the body or face diagonals of the witness, the crystal's face count,
  the target's piece count and the solver work. The catalog in manifest order keeps R02-F24's standard
  `ProgressionRule` (drop at most 1, jump at most 3) on the smallest cut count; the band ranges make band means
  non-decreasing. Impact: FR-R02G0802-003, 005; SC-R02G0802-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/faceted-forge/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the cuts, the state digest after every cut (16 hex
  characters of the SHA-256 of the pieces' canonical corners), the play fingerprints after `begin` and after each cut,
  the smallest cut count with the lower-bound argument (pieces needed), the near miss (the witness minus its last cut:
  not won, its piece count one short), the difficulty and the candidates skipped. A test rebuilds every witness and
  compares bytes; it writes the files only with `FACETED_FORGE_WRITE_WITNESSES=1`. Decoding refuses newer schemas,
  damaged files and witnesses that no longer replay. Impact: FR-R02G0802-004; SC-R02G0802-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<FacetedForgeRules>.digest(id: "faceted-forge", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into groups of 5 levels so each runs under 10
  seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per process. New
  refusals: `generation(Int)` (`r02-g08.generation`) and `witness(String)` (`r02-g08.witness`). The independent check
  of SC-R02G0802-002 recounts the pieces of each sampled witness and replays it on a fresh play, and a bounded
  breadth-first search over the first P − 2 cuts of band-1 levels confirms none wins. Impact: FR-R02G0802-002, 005,
  006; SC-R02G0802-002, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always reach the target: some sequence of cuts within the cut budget splits
the crystal into exactly the target pieces without making a sliver. The game has proof of it for every level.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness cuts, replayed from the start, win within the budget, and every cut's
state equals the stored digests.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** its witness stops one cut short, **Then** the level is not yet won (the target
   needs every cut).
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds a winning sequence with the same smallest
   number of cuts.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the smallest number of cuts, how many distinct
directions and how many diagonal directions the witness uses, the crystal's face count, the target's pieces and how much
work the solver did. Harder bands need more cuts and more varied directions, never faster reactions.

**Independent Test**: band by band, the mean smallest cut count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning cuts, a digest of the state after every cut and
counterexamples: the witness one cut short is not yet won, and no shorter sequence can win. Any edited or fake witness
is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **More than one winning sequence:** allowed; the witness is the first one the solver finds in its fixed cut order.
- **A target that some sliver-making sequence also reaches:** never a solution; the search never continues from a failed
  state.
- **A level whose smallest cut count exceeds its budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0802-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves winnable within the budget MAY be emitted.
- **FR-R02G0802-002**: A solver MUST find a winning sequence with the smallest number of cuts, with a proof that no
  shorter sequence wins, its work bounded and counted; every sequence it reports MUST be replayed through the kernel.
- **FR-R02G0802-003**: Each level MUST carry difficulty metrics (smallest cut count, distinct and diagonal directions of
  the witness, crystal faces, target pieces, solver work) derived from the level and the solver.
- **FR-R02G0802-004**: Each level MUST have a versioned witness record (level, cuts, per-cut state digests,
  counterexamples); damaged, newer and edited files MUST be refused.
- **FR-R02G0802-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the smallest cut count never fall.
- **FR-R02G0802-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: smallest cut count, a winning cut sequence, the work counted (the proof).
- **Difficulty**: smallest cuts, distinct directions, diagonal directions, crystal faces, target pieces, solver work.
- **Witness**: schema, the level's stored form, cuts, per-cut digests, counterexamples, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0802-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G0802-002**: The solver's smallest cut count equals an independent check on sampled catalog levels (at least
  two per band).
- **SC-R02G0802-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G0802-004**: The mean smallest cut count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G0802-005**: Every level is not won one cut short of its witness and with every shorter sequence the proof
  covers; edited, newer and damaged witness files are refused.
- **SC-R02G0802-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/faceted-forge/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- The player sees every piece's share and face count and the target; nothing is hidden.
- Levels are presented, hinted and played through later features (R02-G08-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0802-001, 002 |
| Solver: convex half-space polytope clipping and exact-oriented face classification | FR-R02G0802-002 |
| Truth metric: volume conservation and manifold/edge incidence | FR-R02G0802-002, 003 |
| Certificates (witness, counterexamples, per-cut digests) | FR-R02G0802-004 |
| Difficulty metrics | FR-R02G0802-003, 005 |
| Schema migration, error handling | FR-R02G0802-004, 006 |
| Deterministic tests | SC-R02G0802-002, 003 |
| No Stage One breakage | FR-R02G0802-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
