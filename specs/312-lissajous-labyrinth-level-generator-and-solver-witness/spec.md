# Feature Specification: R02-G02-02 — Lissajous Labyrinth: level generator and solver witness

**Feature Branch**: `312-lissajous-labyrinth-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G02-02 (migration ledger, game feature of experience R02-G02) · ID namespace FR-R02G0202-###,
SC-R02G0202-###, T-R02G0202-###

**Input**: User description: the archived R02-G02-02 `/speckit-specify` prompt (round2.md line 3417), verbatim in the
invocation: "Generate solvable seeded levels with certificates and difficulty metrics" for Lissajous Labyrinth, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/312-lissajous-labyrinth-level-generator-and-solver-witness`; FR-R02G0202-###,
  SC-R02G0202-###, T-R02G0202-###.
- **Packaging (ADR-0009):** experience R02-G02 (`r02-g02.lissajous-labyrinth`, free) in
  `Packages/ExperiencesRound02/LissajousLabyrinth`; this feature extends `LissajousLabyrinthCore` (R02-G02-01, feature 311)
  with the generator, the solver and the witness files. The source's `Apps/LissajousLabyrinth` and
  `Packages/GameModules/LissajousLabyrinthCore` paths are superseded.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design
  (`python3 scripts/planning_index.py levels --experience R02-G02`: 20 levels in each of bands 1 … 5, each with its planned
  seed and move budget 8 … 19); the source's "content count 90" is a milestone only.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as in R02-G02-01). **Device-only
  items:** none (generation and certification run on the host). **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: `LissajousLabyrinthRules` from R02-G02-01) and R02-F24 (catalog
  digest, difficulty and progression rule); R02-F03 numbers.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): R02-G02-01's `LissajousLabyrinthLevel` (amplitudes 1 … 4, frequency c 1 … 9, 1 … 6
checkpoints, 0 … 8 obstacles, allowance 1 … 64, refused when the start already wins), `LissajousLabyrinthLap.verdict`
(4,096 ticks, exact integer segment test), `LissajousLabyrinthRules.moves` (every single-dial change whose frequencies stay
coprime: an action sets one dial to any value of its range), `LissajousLabyrinthError` (`r02-g02.*`); R02-F24's
`PuzzleCatalog.digest(id:identities:)`, `PuzzleDifficulty`, `ProgressionRule`; `SeedDerivation.derive(_:index:)`. The
legal setting space is 55 coprime frequency pairs × 256 phase pairs = 14,080 settings.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, move budget) are a
  table in `LissajousLabyrinthManifest` copied from the archived design with its provenance. Candidate k of entry n draws
  from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`: amplitudes and frequency c; a target winning
  setting (coprime a, b; phases); checkpoints placed on the target's path at increasing, well-spread ticks (bands 1 … 5:
  2, 3, 4, 5, 6 checkpoints of radius 512, 448, 384, 320, 256); obstacles (bands: 2, 3, 4, 6, 8 of radius 256 … 512) placed
  on the paths of other legal settings and kept only when the target path clears them; a start that changes `scramble`
  dials of the target. A candidate is kept when the level is valid, its start does not win, its shortest solution lies in
  its band's range (bands 1 … 5: 1–2, 2, 2–3, 3, 3–4 actions) and does not exceed the move budget (the allowance is the
  budget); otherwise k grows, at most 64 candidates, then `generation(n)`. Ids `lissajous-labyrinth-NNN`; tutorial flag on
  levels 1 … 3. Impact: FR-R02G0202-001; SC-R02G0202-001, 003.
- Q: How does the solver decide every setting and the shortest path? → A: `LissajousLabyrinthSolver` decides all 14,080
  legal settings: a sound prefilter (a sample inside a checkpoint ball is inside its axis box; the per-axis box hits of
  x(a, φ), y(b) and z(ψ) are separable tables combined as bit sets of 4,096 ticks, so a setting with an empty box set for
  any checkpoint cannot win) and the kernel's exact `verdict` for every survivor. The shortest solution is a
  breadth-first search from the start over legal states (single-dial changes keeping the frequencies coprime) to the
  nearest winning setting; ties by the winning setting's (a, b, φ, ψ) ascending, actions in dial order, values ascending.
  The work is the number of exact verdicts. Impact: FR-R02G0202-002; SC-R02G0202-002.
- Q: What difficulty metrics are stored and what progression is required? → A: `LissajousLabyrinthDifficulty` holds the
  shortest solution, the number of winning settings, the minimum clearance of the witness path (the smallest
  squared distance minus squared radius between any sample and any obstacle, an integer) and the work. The catalog in
  manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at most 3) on shortest solutions; band
  means of shortest never fall and band means of winning settings never rise. Impact: FR-R02G0202-003, 005;
  SC-R02G0202-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/lissajous-labyrinth/levels/NNN.witness.json`,
  JSON schema 1 with sorted keys: number, the level's stored form, the actions, the play fingerprints after `begin` (and
  the tutorial) and after each action, the terminal measure (checkpoint visit ticks in order, minimum clearance), the
  near miss (from the winning setting, the single legal dial change with the smallest value distance that loses, ties in
  dial order then lower value, with its verdict), the non-coprime counterexample (frequency b set to the smallest other
  value sharing a factor with a; when a is 1, frequency a set to the smallest other value sharing a factor with b; when both
  are 1, both set to 2) refused by the rules with `r02-g02.move`, the difficulty and the candidates skipped. A test
  rebuilds every witness and compares bytes; it writes the files only with `LISSAJOUS_LABYRINTH_WRITE_WITNESSES=1`.
  Decoding refuses newer schemas, damaged files and witnesses that no longer replay. Impact: FR-R02G0202-004;
  SC-R02G0202-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<LissajousLabyrinthRules>.digest(id: "lissajous-labyrinth", identities:)` over the 100 level
  fingerprints in manifest order, pinned in a test. Certification tests are split so each runs under 10 seconds on a debug
  host build (CI measured, not asserted). New refusals: `generation(Int)` (`r02-g02.generation`) and `witness(String)`
  (`r02-g02.witness`). Impact: FR-R02G0202-005, 006; SC-R02G0202-006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always tune the dials so the tracer passes every checkpoint in order without
touching an obstacle, within the move allowance; the game has proof of it for every level.

**Why this priority**: an unsolvable level breaks the game's promise.

**Independent Test**: each level's stored witness, replayed from its start, wins within the allowance.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness actions are replayed, **Then** the level is won within the allowance.
2. **Given** any catalog level, **When** the solver runs again, **Then** it finds the same shortest solution length and the
   same number of winning settings.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Why this priority**: reproducible content is what makes the witnesses and the catalog digest meaningful.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

**Acceptance Scenarios**:

1. **Given** the manifest, **When** the catalog is built twice, **Then** both builds are identical level by level.
2. **Given** a changed planned seed, **When** the catalog is built, **Then** the pinned digest check fails.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the shortest number of actions, the number of
winning settings among all legal ones, the tightest clearance of the winning path and the solver's work. Harder bands ask
for more dial changes among fewer winning settings, never for tinier gestures.

**Why this priority**: pacing across 100 levels depends on honest difficulty.

**Independent Test**: band by band, the mean shortest solution does not fall and the mean number of winning settings does
not rise; the catalog keeps the progression rule.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** bands are compared in order, **Then** mean shortest solutions never fall.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the action witness, the per-action state fingerprints, the terminal
measure (checkpoint visit ticks in order and the minimum clearance to any obstacle) and two counterexamples: the nearest
legal setting that loses (with its verdict) and the nearest frequency pair that is not coprime (refused by the rules).
Any edited or fake witness is caught.

**Why this priority**: the source requires certificates and refuses fake expected hashes.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

**Acceptance Scenarios**:

1. **Given** a witness file with one byte changed, **When** it is checked, **Then** it is refused with a named reason.

### Edge Cases

- **A seed whose candidate is unsolvable, already won, too easy or too hard for its band:** the generator moves to the next
  candidate deterministically (at most 64) and records how many it skipped; no candidate in 64 is a named refusal.
- **More than one winning setting:** allowed; the witness picks the one with the fewest actions by a stated tie rule, and
  the count is a difficulty metric.
- **A winning setting reachable only through a non-coprime intermediate:** the shortest path respects that every
  intermediate state must be legal (coprime), so the action order or a detour is part of the proof.
- **A level the counterexamples cannot be built for:** refused (every level must show a losing near-miss).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0202-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves solvable within the allowance MAY be emitted, and none starts won.
- **FR-R02G0202-002**: A solver MUST decide every legal setting of a level (all coprime frequency pairs 1 … 9 and all 16 ×
  16 phase offsets) with the exact segment-swept collision test of R02-G02-01, and find the shortest action sequence from
  the start to a winning setting through legal states only; its work is bounded by the 14,080 legal settings (at most one
  exact verdict each) and a search over at most 14,080 states.
- **FR-R02G0202-003**: Each level MUST carry difficulty metrics (shortest solution, winning settings, minimum clearance of
  the witness path, solver work) derived from the solver.
- **FR-R02G0202-004**: Each level MUST have a versioned witness record (level, action witness, per-action fingerprints,
  terminal measure, losing near-miss with its verdict, non-coprime counterexample refused by the rules); damaged, newer and
  edited files MUST be refused.
- **FR-R02G0202-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of shortest solution never fall.
- **FR-R02G0202-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: shortest action count, a shortest action list, winning settings, work, the winning setting chosen.
- **Difficulty**: shortest actions, winning settings, minimum clearance, work.
- **Witness**: schema, the level's stored form, actions, fingerprints, terminal measure, two counterexamples, skipped
  candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0202-001**: All 100 catalog levels are won by replaying their witness within the allowance; none starts won.
- **SC-R02G0202-002**: The solver's exact fast decision equals the kernel's lap verdict on every legal setting of a seeded
  level with three obstacles and over 1,000 winners, and on every winning setting plus 440 seeded-random settings of 20 more seeded levels and of 10 catalog levels
  (two per band); its shortest lengths equal a plain breadth-first search over the decided winning set on those levels,
  and every witness's final setting wins by the kernel's verdict. (Kernel laps cost about 1–2 ms each in a debug build,
  so an exhaustive check of every level would break the owner's short-test rule; the sampled checks bound the rest.)
- **SC-R02G0202-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file matches
  the regenerated witness byte for byte.
- **SC-R02G0202-004**: Mean shortest solution does not fall and mean winning settings do not rise from one band to the
  next; the catalog keeps its progression rule.
- **SC-R02G0202-005**: Every near-miss counterexample loses with a named verdict (contact with obstacle and tick, or the
  first missed checkpoint); every non-coprime counterexample is refused by the rules; edited, newer and damaged witness
  files are refused.
- **SC-R02G0202-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds, the whole catalog certification included.

## Assumptions

- The 100 witness files live in `docs/games/lissajous-labyrinth/levels/NNN.witness.json` as the manifest names them; they
  are regenerated by a test run with an explicit opt-in and checked byte for byte on every other run.
- Levels are presented, hinted and played through later features (R02-G02-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design
  (`docs/archive/planning/rounds/round2.md`); no third-party content is used.
- Layout on iPad and iPhone, the dials and gestures are owned by R02-G02-04, hints by R02-G02-05 and accessibility
  (VoiceOver, controls) by R02-G02-06; the witness and difficulty data are plain text and numbers usable by them. Observability: generation reports skipped candidates and solver work per level.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0202-001, 002 |
| Certificates (witness, counterexamples) | FR-R02G0202-004 |
| Difficulty metrics | FR-R02G0202-003, 005 |
| Schema migration, error handling | FR-R02G0202-004, 006 |
| Deterministic tests | SC-R02G0202-002, 003 |
| No Stage One breakage | FR-R02G0202-006 |

## Negative Requirements / Excluded scope

- No rendering, dials UI, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
