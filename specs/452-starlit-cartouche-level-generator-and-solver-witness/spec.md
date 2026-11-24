# Feature Specification: R02-G16-02 — Starlit Cartouche: level generator and solver witness

**Feature Branch**: `452-starlit-cartouche-level-generator-and-solver-witness` (spec directory only; work on
`main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G16-02 (migration ledger, game feature of experience R02-G16) · ID namespace FR-R02G1602-###,
SC-R02G1602-###, T-R02G1602-###

**Input**: User description: the archived R02-G16-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Starlit Cartouche, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/452-starlit-cartouche-level-generator-and-solver-witness`;
  FR-R02G1602-###, SC-R02G1602-###, T-R02G1602-###.
- **Packaging (ADR-0009):** experience R02-G16 (`r02-g16.starlit-cartouche`, free) in the one app; this feature
  extends the pure `StarlitCartoucheCore` of feature 451.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G16`: 20 levels in each of bands 1 … 5, each with its planned
  seed and moves budget 8 … 19). The prompt's "content count 80" (the catalog's "80 solver-certified stages") is a milestone
  figure, as for the earlier round-two games.
- **Model:** feature 442 (Voxel Origami's content pipeline) for manifest, generator, witness files, digest and
  progression.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
442's answers where the games agree. Facts checked (read-only, 2026-11-24): R02-G16-01's `StarlitCartoucheLevel` (4 …
12 stars on orbits of 1 … 4 positions, range 1 … 12, corridors, hazards, windows closing by beat 64, deadline 1 … 64,
budget 1 … 16), `StarlitCartoucheChart` (leg refusals, failures in order, route report), `StarlitCartouchePlay` and
`StarlitCartoucheRules`; R02-F24's `PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at
most 1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries
(bands 1 … 5 × 20, moves budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19 by band, control emphases `avoid hazard`,
`time launch`, `commit glyph`, `place route waypoint`, `adjust arc`, 20 each); the kernel's budget bound 1 … 16 is
below the manifest's 19. The ranges below were measured before they were written down: a prototype of this generator
and the time-expanded breadth-first solver on the real kernel (release build, 120 candidates per band) generated 117,
119, 114, 116 and 116 valid candidates (bands 1 … 5), of which 110, 105, 98, 102 and 105 had a minimal plan inside the
band's range, with at most 33 832 legs tried per candidate and under 0.07 s per band of 120 candidates.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, budget, control
  emphasis) are a table in `StarlitCartoucheManifest` with their provenance. Candidate c of entry n draws from
  `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the star count (band + 4 …
  band + 5); for each star a glyph point (redrawn until distinct) and an orbit of 1 … 3 positions with coordinates
  −5 … 5; the range (6 … 8); the start star; a route of band + 1 … band + 2 legs, each choosing up to 8 times a next star
  other than the current one and the first flyable wait counted from a drawn offset 0 … 3 (waits 0 … 8, modulo 9),
  adding the corridor (travel 1 … 3) when new (no flyable next star in 8 draws skips the candidate); band + 1 drawn
  decoy corridors (new pairs only, at most 24 corridors); hazards (band + 2 for `avoid hazard`, else 0 … band; each on a
  drawn corridor with a drawn interval of from 0 … last arrival + 2 and length 0 … 3, dropped when it would meet a leg of
  the route on that corridor; at most 8); the deadline (the last arrival plus 0 … max(0, 5 − band), at most 64); and
  the windows (every visited star for `time launch`, else each with a 1 in 3 draw: open = earliest arrival − 0 … 2 (0 for
  the start), close = latest arrival or departure + 0 … 2; the others [0, 64]). Symbol = the corridors the route flew;
  beacon = its last star; budget = the manifest's; ids `starlit-cartouche-NNN`; tutorial on levels 1 … 3; difficulty =
  band. A candidate the level rules refuse, or that the solver does not certify with a minimal plan in its band's range
  (2 … 3, 3 … 4, 4 … 5, 5 … 6, 6 … 7 legs) within its work bound, is skipped; at most 256 candidates, then
  `generation(n)`. The kernel's budget bound widens to 1 … 24 (FR-R02G1602-007). Impact: FR-R02G1602-001, 007;
  SC-R02G1602-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing shorter wins? → A: a breadth-first search over
  route states (the ship's star, the beat and the set of symbol strokes drawn) from the start — the catalog's
  time-expanded graph search, time being part of every state: at each depth the states are expanded in the order they
  were reached, each state's legs in the order corridors by index (those touching the ship's star), then waits 0 … 8; a
  leg reaches a state only when it is flyable and the chart finds no failure (a stray stroke always fails); states are
  merged by star, beat and strokes. The first leg that wins ends the search; the plan is its path. Work = legs tried
  (every corridor and wait considered), counted and bounded at 300 000; over the bound, or past the band's upper plan
  length, the candidate is skipped. The minimality proof is that every state reachable in fewer legs was reached and none
  won (the counts of states at each smaller depth are stored). The witness is the plan's legs, replayed through the
  kernel's play. Impact: FR-R02G1602-002; SC-R02G1602-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `StarlitCartoucheDifficulty` holds the
  witness leg count, the stars, the corridors, the hazards, the symbol strokes, the states searched at smaller depths and
  the solver work. The catalog in manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at
  most 3) on the witness leg count; the band ranges, each two values wide and meeting the next band's at one value, make
  band means non-decreasing. Impact: FR-R02G1602-003, 005; SC-R02G1602-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/starlit-cartouche/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the actions, the state digest after every action (16 hex
  characters of the SHA-256 of the ship's star, the beat and the drawn strokes), the play fingerprints after `begin`
  (and `dismissTutorial` when the level has one) and after each action, the counterexample (the depth one below the plan
  and the number of states reached at that depth, none winning), the difficulty and the candidates skipped. A test
  rebuilds every witness and compares bytes; it writes the files only with `STARLIT_CARTOUCHE_WRITE_WITNESSES=1`.
  Decoding refuses newer schemas, damaged files and witnesses that no longer replay. Impact: FR-R02G1602-004;
  SC-R02G1602-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<StarlitCartoucheRules>.digest(id: "starlit-cartouche", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into groups of 10 levels so each runs under 10
  seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per process. New
  refusals: `generation(Int)` (`r02-g16.generation`) and `witness(String)` (`r02-g16.witness`). The independent check of
  SC-R02G1602-002 is a depth-first enumeration of every leg sequence the play accepts (no state merging), shorter than
  the plan, on the two levels with the fewest stars in each band: none wins. Impact: FR-R02G1602-005, 006;
  SC-R02G1602-002, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some legs within the moves budget draw the cartouche and reach the
beacon in time without crossing a hazard or missing a window. The game has proof of it for
every level, and proof that no fewer actions would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget; every
action's resulting state equals the stored digest; the proof that fewer actions cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** any sequence of fewer legs than the witness is tried, **Then** none wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the legs the witness needs, the stars, corridors
and hazards, the states searched and the solver's work. Harder bands mean longer symbols and more timing to plan,
never faster reactions.

**Independent Test**: band by band, the mean witness leg count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action and the
counterexample proof that fewer actions cannot win. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate needing no leg:** never emitted (every symbol has at least one stroke).
- **More than one minimal plan:** allowed; the witness is the one the solver finds in its fixed order.
- **A plan needing more actions than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1602-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget; only levels the solver certifies within the budget MAY be emitted.
- **FR-R02G1602-002**: A solver MUST find a minimal sequence of legs that wins (the symbol drawn, the ship at the
  beacon, no failure), with its work bounded and counted, and MUST prove that no shorter sequence wins; every plan it
  reports MUST be replayed through the kernel.
- **FR-R02G1602-003**: Each level MUST carry difficulty metrics (witness legs, stars, corridors, hazards, symbol
  strokes, states searched, solver work) derived from the level and the solver.
- **FR-R02G1602-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  counterexample proof); damaged, newer and edited files MUST be refused.
- **FR-R02G1602-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness leg count never fall.
- **FR-R02G1602-007**: The kernel's budget bound MUST admit every manifest budget (8 … 19); levels of feature 451's
  bounds stay valid.
- **FR-R02G1602-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget.
- **Minimality proof**: every route state reachable in fewer legs, none of which wins.
- **Solver result**: the legs, the work counted, the proof.
- **Difficulty**: witness legs, stars, corridors, hazards, symbol strokes, states searched, work.
- **Witness**: schema, the level's stored form, actions, per-action state digests, counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1602-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G1602-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1602-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1602-004**: The mean witness leg count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1602-005**: For every level, no sequence of fewer legs than its witness wins; edited, newer and damaged
  witness files are refused.
- **SC-R02G1602-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/starlit-cartouche/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Time-expanded graph search over navigable star corridors" is read as: the solver searches the route states (the
  ship's star, the beat and the strokes drawn) reachable by ever more accepted legs (each leg flyable and clear of every
  failure), level by level, so the first win found is minimal; time is part of every state.
- Levels are presented, hinted and played through later features (R02-G16-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1602-001, 002 |
| Solver: time-expanded graph search over navigable star corridors | FR-R02G1602-002 |
| Truth metric: projected glyph skeleton mismatch and hazard clearance | FR-R02G1602-002, 003 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G1602-004 |
| Difficulty metrics | FR-R02G1602-003, 005 |
| Invariants INV-06 content and INV-12 novelty | FR-R02G1602-002, 003 |
| Schema migration, error handling | FR-R02G1602-004, 006 |
| Deterministic tests | SC-R02G1602-002, 003 |
| No Stage One breakage | FR-R02G1602-006 |
| Manifest budgets 8 … 19 | FR-R02G1602-007 |
