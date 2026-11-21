# Feature Specification: R02-G03-02 — Wave Knot Keeper: level generator and solver witness

**Feature Branch**: `322-wave-knot-keeper-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G03-02 (migration ledger, game feature of experience R02-G03) · ID namespace FR-R02G0302-###,
SC-R02G0302-###, T-R02G0302-###

**Input**: User description: the archived R02-G03-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Wave Knot Keeper, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/322-wave-knot-keeper-level-generator-and-solver-witness`; FR-R02G0302-###,
  SC-R02G0302-###, T-R02G0302-###.
- **Packaging (ADR-0009):** experience R02-G03 (`r02-g03.wave-knot-keeper`, free) in
  `Packages/ExperiencesRound02/WaveKnotKeeper`; this feature extends `WaveKnotKeeperCore` (R02-G03-01, feature 321) with
  the generator, the solver and the witness files. The source's `Apps/WaveKnotKeeper` and
  `Packages/GameModules/WaveKnotKeeperCore` paths are superseded.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design
  (`python3 scripts/planning_index.py levels --experience R02-G03`: 20 levels in each of bands 1 … 5, each with its planned
  seed and move budget 8 … 19); the source's "content count 72" is a milestone only.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as in R02-G03-01). **Device-only
  items:** none (generation and certification run on the host). **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: `WaveKnotKeeperRules` from R02-G03-01) and R02-F24 (catalog
  digest, difficulty and progression rule); R02-F03 numbers.
- **Model:** feature 312 (Lissajous Labyrinth's generator and solver witness).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only, 2026-11-21): R02-G03-01's `WaveKnotKeeperLevel` (6 … 16 points in −16 … 16, at most 4 gates, tension
bound 1 … 49,152, allowance 1 … 64; refused when the start passes through itself, already wins or exceeds the bound),
`WaveKnotKeeperTarget` (crossings 0 … 32, |writhe| ≤ crossings, same parity), `WaveKnotKeeperRules.moves` (every legal
single-point unit step in point then direction order, at most 6 per point), `WaveKnotKeeperGeometry.summary`, `isSimple`,
`tension`, `WaveKnotKeeperPlay.refusal(of:points:level:)` with `r02-g03.move("crossing" | "tension" | …)`; R02-F24's
`PuzzleCatalog.digest(id:identities:)`, `ProgressionRule`; `SeedDerivation.derive(_:index:)`, `SeededRandom`; the
archived manifest's 100 entries (bands 1 … 5 × 20, budgets 8 … 19). Feature 312 is the pattern.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, move budget) are a
  table in `WaveKnotKeeperManifest` copied from the archived design with its provenance. Candidate k of entry n draws from
  `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`: a solved rope of 5 + band points (6 … 10), each point
  at a seeded angle around the origin (angles sorted, then `band` seeded neighbour swaps so the projection crosses
  itself) at a seeded radius 5 … 12 and height −4 … 4, rounded to the lattice; it is kept only if simple, in bounds and
  with a non-degenerate projection, and its summary is the target. Gates: bands 1 … 5 get 0, 0, 1, 1, 2 cubes of side 3
  centred on seeded rope points. The start is `scramble` seeded legal moves from the solved rope (bands 1 … 5: 1, 2, 2,
  3, 3), never stepping back onto an earlier rope; each step takes the first move, in the seeded order of the
  legal moves, whose rope's summary differs from the solved rope's, else the first legal move; the tension bound is the largest tension along that walk plus 64 ×
  (6 − band); the allowance is the manifest budget. A candidate is kept when the level is valid (its start does not win),
  its shortest solution lies in its band's range (bands 1 … 5: 1, 1–2, 2, 2–3, 3 moves) and does not exceed the budget;
  otherwise k grows, at most 64 candidates, then `generation(n)`. Ids `wave-knot-keeper-NNN`; tutorial flag on levels
  1 … 3. Impact: FR-R02G0302-001; SC-R02G0302-001, 003.
- Q: How does the solver find the shortest solution and how much work may it do? → A: `WaveKnotKeeperSolver` runs a
  breadth-first search from the start over legal ropes (the kernel's `WaveKnotKeeperRules.moves` and `apply`), ropes
  compared by their points, to the first winning rope, depth at most 3 (the largest band range); ties by the rules' move
  order at each depth, so the witness is the first shortest sequence in that order. The work is the number of ropes
  expanded; with at most 10 points and 6 directions it is at most 1 + 60 + 3,600 = 3,661 expansions (at most 219,660 move
  checks) per level. A start not solved within the depth is unsolvable for the generator. Impact: FR-R02G0302-002;
  SC-R02G0302-002.
- Q: What difficulty metrics are stored and what progression is required? → A: `WaveKnotKeeperDifficulty` holds the
  shortest solution, the point count, the gate count, the target crossings and the work. The catalog in manifest order
  keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at most 3) on shortest solutions; band means of
  shortest and of point count never fall. Impact: FR-R02G0302-003, 005; SC-R02G0302-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/wave-knot-keeper/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the moves, the play fingerprints after `begin` and after
  each move, the terminal summary (crossings, writhe, tension), the near miss (from the winning rope, the first legal move
  in rules order whose rope does not win, with its summary), the crossing counterexample (the first rope explored by the
  solver, in search order, with a move the rules refuse with `r02-g03.move("crossing")`: the rope's points and that move),
  the difficulty and the candidates skipped. A test rebuilds every witness and compares bytes; it writes the files only
  with `WAVE_KNOT_KEEPER_WRITE_WITNESSES=1`. Decoding refuses newer schemas, damaged files and witnesses that no longer
  replay. A candidate without both counterexamples is skipped. Impact: FR-R02G0302-004; SC-R02G0302-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<WaveKnotKeeperRules>.digest(id: "wave-knot-keeper", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split by band so each runs under 10 seconds on a debug host
  build (measured locally, not asserted on CI). New refusals: `generation(Int)` (`r02-g03.generation`) and
  `witness(String)` (`r02-g03.witness`). Impact: FR-R02G0302-005, 006; SC-R02G0302-006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always move the rope's control points, one lattice step at a time and never
through itself outside a gate, until its projected crossings and writhe match the target, within the move allowance; the
game has proof of it for every level.

**Why this priority**: an unsolvable level breaks the game's promise.

**Independent Test**: each level's stored witness, replayed from its start, wins within the allowance.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness moves are replayed, **Then** the level is won within the allowance.
2. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same shortest solution length.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

**Acceptance Scenarios**:

1. **Given** the manifest, **When** the catalog is built twice, **Then** both builds are identical level by level.
2. **Given** a changed planned seed, **When** the catalog is built, **Then** the pinned digest check fails.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the shortest number of moves, the number of
control points, the number of crossing gates, the target crossing count and the solver's work. Harder bands ask for more
moves on longer ropes, never for tinier gestures.

**Independent Test**: band by band, the mean shortest solution and the mean point count do not fall; the catalog keeps the
progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the move witness, the per-move state fingerprints, the terminal summary
(crossings, writhe, tension) and two counterexamples: a legal single move from the winning rope that loses (with its
summary) and a move that would pass a strand through another outside a gate (refused by the rules). Any edited or fake
witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsolvable, already won, too easy or too hard for its band:** the generator moves to the next
  candidate deterministically (at most 64) and records how many it skipped; no candidate in 64 is a named refusal.
- **More than one shortest solution:** allowed; the witness picks one by a stated tie rule.
- **A degenerate projection on the way:** intermediate ropes may be degenerate (they never win); the winning rope is not.
- **A level the counterexamples cannot be built for:** refused (every level must show a losing near miss and a refused
  crossing).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0302-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves solvable within the allowance MAY be emitted, and none starts won.
- **FR-R02G0302-002**: A solver MUST find the shortest move sequence from the start to a winning rope through legal ropes
  only (the kernel's move legality: bounds, no coinciding points, no strand passing through another outside a gate, the
  tension bound), searching every legal rope up to the band's depth bound, with its work (ropes expanded) bounded by
  arithmetic.
- **FR-R02G0302-003**: Each level MUST carry difficulty metrics (shortest solution, point count, gate count, target
  crossings, solver work) derived from the level and the solver.
- **FR-R02G0302-004**: Each level MUST have a versioned witness record (level, move witness, per-move fingerprints,
  terminal summary, losing near miss with its summary, a refused crossing move); damaged, newer and edited files MUST be
  refused.
- **FR-R02G0302-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of shortest solution never fall.
- **FR-R02G0302-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: shortest move count, a shortest move list, work.
- **Difficulty**: shortest moves, points, gates, target crossings, work.
- **Witness**: schema, the level's stored form, moves, fingerprints, terminal summary, two counterexamples, skipped
  candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0302-001**: All 100 catalog levels are won by replaying their witness within the allowance; none starts won.
- **SC-R02G0302-002**: The solver's shortest length equals an independent plain breadth-first search over the kernel's
  `PuzzleRules` on sampled catalog levels (at least two per band), and every witness's final rope wins by the kernel.
- **SC-R02G0302-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file matches
  the regenerated witness byte for byte.
- **SC-R02G0302-004**: Mean shortest solution and mean point count do not fall from one band to the next; the catalog
  keeps its progression rule.
- **SC-R02G0302-005**: Every near-miss counterexample loses with its summary named; every crossing counterexample is
  refused by the rules with `r02-g03.move`; edited, newer and damaged witness files are refused.
- **SC-R02G0302-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/wave-knot-keeper/levels/NNN.witness.json`; they are regenerated only by a test
  run with an explicit opt-in and checked byte for byte on every other run.
- Levels are presented, hinted and played through later features (R02-G03-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0302-001, 002 |
| Certificates (witness, counterexamples) | FR-R02G0302-004 |
| Difficulty metrics | FR-R02G0302-003, 005 |
| Schema migration, error handling | FR-R02G0302-004, 006 |
| Deterministic tests | SC-R02G0302-002, 003 |
| No Stage One breakage | FR-R02G0302-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
