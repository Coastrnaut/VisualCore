# Feature Specification: R02-G07-02 — Amethyst Escape: level generator and solver witness

**Feature Branch**: `362-amethyst-escape-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Clarified

**Ledger gate**: R02-G07-02 (migration ledger, game feature of experience R02-G07) · ID namespace FR-R02G0702-###,
SC-R02G0702-###, T-R02G0702-###

**Input**: User description: the archived R02-G07-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Amethyst Escape, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/362-amethyst-escape-level-generator-and-solver-witness`; FR-R02G0702-###,
  SC-R02G0702-###, T-R02G0702-###.
- **Packaging (ADR-0009):** experience R02-G07 (`r02-g07.amethyst-escape`, free) in the one app; this feature extends the
  pure `AmethystEscapeCore` of feature 361.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (Auto-Creator.md, R02-G07
  chapter: "100 solver-certified levels … the chapter header's earlier figure ("80 solver-certified stages") and its
  shorter manifests are milestones only"; `python3 scripts/planning_index.py levels --experience R02-G07`: 20 levels in
  each of bands 1 … 5, each with its planned seed and move budget 8 … 19). The prompt's "content count 80" is that
  milestone figure.
- **Model:** feature 352 (Chrono Constellator's content pipeline) for manifest, generator, witness files, digest and
  progression.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
352's answers where the games agree. Facts checked in code (read-only, 2026-11-22): R02-G07-01's `AmethystEscapeLevel`
(6 … 12 sectors, 2 … 5 shells, apertures, walls, blocked wedges, one exit gap, budget 1 … 60), `AmethystEscapeCrystal`,
`AmethystEscapePlay` and `AmethystEscapeRules`; R02-F24's `PuzzleCatalog.digest(id:identities:)` and
`ProgressionRule.standard` (drop at most 1, jump at most 3); `SeedDerivation.derive(_:index:)` and `SeededRandom`; the
canonical manifest's 100 entries (`planning_index.py levels --experience R02-G07`: bands 1 … 5 × 20, move budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19). Feature 352 is
the pattern. A Python prototype (2026-11-22, the 100 manifest seeds, the rules below with Python's own generator)
certified 100 of 100 levels in 7 s, at most 51 candidates for one level and at most 38,000 states explored for one proof.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, move budget) are a
  table in `AmethystEscapeManifest` with their provenance. Candidate k of entry n draws from
  `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`, in this order: the profile by band (6 sectors × 2
  shells; 6 × 3; 8 × 3; 8 × 4; 10 × 4); for each shell from the innermost: its apertures (the outermost shell one drawn
  sector, the exit gap; every other shell draw(1 … 2) distinct drawn sectors), its walls (each sector in order with draw(0 …
  99) < 35; when every sector is walled, the lowest wall is removed) and its blocked wedges (each sector that is not an
  aperture with draw(0 … 99) < 25); then the start, drawn among shell 0's sectors that are not blocked. A candidate is kept
  when the pearl does not escape by advances alone and the solver proves a smallest move count in the band's range (3 … 4;
  5 … 6; 7 … 8; 9 … 10; 11 … 12) that fits the manifest budget; otherwise k grows, at most 512 candidates, then
  `generation(n)`. Ids `amethyst-escape-NNN`; tutorial flag on levels 1 … 3; difficulty = band; budget = manifest budget.
  Impact: FR-R02G0702-001; SC-R02G0702-001, 003, 004.
- Q: How does the solver decide the smallest move count, and what proves it? → A: a breadth-first search over crystal
  states (every shell offset and the pearl's pocket) from the opening state, expanding moves in the rules' fixed order
  (rotate(r, +1), rotate(r, −1) for each shell r in order, then advance unless it is stuck); a move into a blocked wedge
  is a dead end (never expanded); the first escape found is at the smallest depth m and its path is the witness. The proof
  is the search itself: every state reachable in fewer than m moves was expanded and none escapes; the counts of states
  first reached at each depth 0 … m − 1 are recorded. Work = states expanded, bounded by N^K × K × N (at most 400,000 for
  the band-5 profile). The witness is replayed through the kernel's play. Impact: FR-R02G0702-002; SC-R02G0702-001, 002,
  005.
- Q: What difficulty metrics are stored and what progression is required? → A: `AmethystEscapeDifficulty` holds the
  smallest move count, the turns and advances of the witness, the shell and sector counts and the states explored. The
  catalog in manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at most 3) on the smallest
  move count; the band ranges make band means non-decreasing. Impact: FR-R02G0702-003, 005; SC-R02G0702-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/amethyst-escape/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the actions, the state digest after every move (16 hex
  characters of the SHA-256 of the offsets and the pearl's pocket), the play fingerprints after `begin` and after each
  action, the smallest move count with the states first reached at each depth below it, the unedited counterexample (the
  pearl advanced with no shell turned: its outcome — stuck, wedge or budget — and move), the near miss (the witness minus
  its last action, which has not escaped), the difficulty and the candidates skipped. A test rebuilds every witness and
  compares bytes; it writes the files only with `AMETHYST_ESCAPE_WRITE_WITNESSES=1`. Decoding refuses newer schemas,
  damaged files and witnesses that no longer replay. Impact: FR-R02G0702-004; SC-R02G0702-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<AmethystEscapeRules>.digest(id: "amethyst-escape", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split by band so each runs under 10 seconds on a debug host
  build (measured locally, not asserted on CI). New refusals: `generation(Int)` (`r02-g07.generation`) and
  `witness(String)` (`r02-g07.witness`). Impact: FR-R02G0702-005, 006; SC-R02G0702-006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always get the pearl out: some sequence of shell turns and advances within the
move budget carries it through the exit gap without falling into a blocked wedge. The game has proof of it for every
level.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget, and every
move's state equals the stored digests.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** the pearl is advanced from the start with no shell turned, **Then** it does not
   escape (the puzzle needs the player).
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same smallest number of moves.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the smallest number of moves that escapes, how
many of them are turns and how many advances, the shells and sectors, and how many states the proof explored. Harder
bands need longer routes through more shells, never faster reactions.

**Independent Test**: band by band, the mean smallest move count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every move and
counterexamples: advancing without turning any shell does not escape, and no shorter sequence escapes. Any edited or
fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsolvable, too easy or too hard for its band:** the generator moves to the next candidate
  deterministically (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **More than one shortest sequence:** allowed; the witness is the first one the search finds in its fixed move order.
- **A level escaped by advances alone:** never emitted.
- **A route through a blocked wedge:** never part of a solution; the search never continues from a failed state.
- **A level whose shortest route needs more moves than its budget:** not emitted.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0702-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves escapable within the budget MAY be emitted, and none escapes by advances
  alone.
- **FR-R02G0702-002**: A solver MUST find the smallest number of moves (turns and advances) that escapes, with a proof
  that no shorter sequence escapes, its work bounded by the number of crystal states; every escape it reports MUST be
  replayed through the kernel.
- **FR-R02G0702-003**: Each level MUST carry difficulty metrics (smallest move count, turns and advances in the witness,
  shells, sectors, states explored) derived from the level and the solver.
- **FR-R02G0702-004**: Each level MUST have a versioned witness record (level, actions, per-move state digests,
  counterexamples); damaged, newer and edited files MUST be refused.
- **FR-R02G0702-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the smallest move count never fall.
- **FR-R02G0702-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: smallest move count, a shortest action sequence, the states explored by depth (the proof).
- **Difficulty**: smallest moves, turns, advances, shells, sectors, states explored.
- **Witness**: schema, the level's stored form, actions, per-move digests, counterexamples, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0702-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G0702-002**: The solver's smallest move count equals an independent brute-force search on sampled catalog
  levels (at least two per band).
- **SC-R02G0702-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file matches
  the regenerated witness byte for byte.
- **SC-R02G0702-004**: The mean smallest move count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G0702-005**: Every level fails to escape by advances alone and with every shorter sequence the proof covers;
  edited, newer and damaged witness files are refused.
- **SC-R02G0702-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/amethyst-escape/levels/NNN.witness.json` (the manifest's "Certification
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- The player sees every shell, aperture, wall and wedge; nothing is hidden.
- Levels are presented, hinted and played through later features (R02-G07-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0702-001, 002 |
| Solver: breadth-first search over discretized shell angles and pearl pocket indices | FR-R02G0702-002 |
| Truth metric: graph route length and reachable exit proof | FR-R02G0702-002, 003 |
| Certificates (witness, counterexamples, per-move digests) | FR-R02G0702-004 |
| Difficulty metrics | FR-R02G0702-003, 005 |
| Schema migration, error handling | FR-R02G0702-004, 006 |
| Deterministic tests | SC-R02G0702-002, 003 |
| No Stage One breakage | FR-R02G0702-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
