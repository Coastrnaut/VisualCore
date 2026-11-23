# Feature Specification: R02-G12-02 — Harmonic Bridges: level generator and solver witness

**Feature Branch**: `412-harmonic-bridges-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G12-02 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1202-###,
SC-R02G1202-###, T-R02G1202-###

**Input**: User description: the archived R02-G12-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Harmonic Bridges, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/412-harmonic-bridges-level-generator-and-solver-witness`; FR-R02G1202-###,
  SC-R02G1202-###, T-R02G1202-###.
- **Packaging (ADR-0009):** experience R02-G12 (`r02-g12.harmonic-bridges`, free) in the one app; this feature extends
  the pure `HarmonicBridgesCore` of feature 411.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G12`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19). The prompt's "content count 82" (the catalog's "82 solver-certified stages") is a milestone
  figure, as for the earlier round-two games.
- **Model:** feature 402 (Echo Cartographer's content pipeline) for manifest, generator, witness files, digest and
  progression.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
402's answers where the games agree. Facts checked (read-only, 2026-11-23): R02-G12-01's `HarmonicBridgesLevel`
(islands 2 … 8, strings 1 … 12, length 1 … 6, peg 1 … 12, steps 1 … 4 of 1 … 3 tones, frequency 1 … 72, strength
1 … 3, threshold 1 … 12, budget 1 … 60), `HarmonicBridgesReport`, `HarmonicBridgesPlay` and `HarmonicBridgesRules`;
R02-F24's `PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at most 1, jump at most 3);
`SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries (`planning_index.py levels
--experience R02-G12`: bands 1 … 5 × 20, moves budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19). The acceptance
ranges below were measured before they were written down: a prototype of this generator and solver over 60 generated
candidates per band gave minimal tuning counts in the band's range for 60, 49, 43, 39 and 37 of 60 (bands 1 … 5), with
at most 237 nodes of work; skipped draws (no string length and peg that is a bridge in every step) were bounded.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, budget) are a table
  in `HarmonicBridgesManifest` with their provenance. Candidate c of entry n draws from `SeededRandom(seed:
  SeedDerivation.derive(plannedSeed, index: c))`, in this order: the scrambled count k in the band's range (1 … 2,
  2 … 3, 3 … 4, 4 … 5, 5 … 6); the path length P = k + (0 or 1), at most 7; the island count min(8, P + 1 + (0 or 1));
  the steps by band (1, 1 … 2, 2, 2 … 3, 3 … 4), each with its tones (2, 2 … 3, 2 … 3, 2 … 3, 3) drawn without repeat
  from the frequencies {6, 12, 18, 24, 30, 36, 48, 60, 72}, each with a strength 1 … 3; the threshold by band (1 … 3,
  2 … 4, 2 … 5, 3 … 6, 3 … 6); the path from island 0 through P − 1 distinct interior islands (a shuffled draw) to the last
  island; for each path string a (length, peg) drawn from the pairs that are a bridge in every step (none: the candidate
  is skipped); the k scrambled path strings (a drawn subset) get instead a peg that is not a bridge in every step (none:
  skipped); then decoy strings by band (1 … 2, 2 … 3, 2 … 4, 3 … 4, 3 … 5) on unused island pairs (shuffled), each with a
  length 1 … 6, a peg 1 … 12 and locked with chance 3 in 10; the strings are shuffled. Start is island 0, goal the last;
  budget = the manifest's; ids `harmonic-bridges-NNN`; tutorial on levels 1 … 3; difficulty = band; island drawing
  positions are laid out from the path order and never decide a rule. A candidate the solver does not certify with a
  minimal tuning count in its band's range and at most budget − 1 tunings within its work bound is skipped; at most 256
  candidates, then `generation(n)`. Impact: FR-R02G1202-001; SC-R02G1202-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing smaller wins? → A: for every string and peg, the
  bridge pattern is the set of window steps in which the string is a bridge. A string kept at its peg keeps its current
  pattern; a retuned unlocked string's useful options are the maximal patterns, among its other pegs, that are not
  contained in its current pattern, each realised by its lowest peg (more bridges never hurt reachability, so a minimal
  plan never needs a non-maximal or a contained pattern). The solver tries k = 1, 2, … 6 retuned strings: subsets of the
  useful strings in lexicographic index order and, for each, the product of their options in order; the first choice
  after which the start reaches the goal in every step is the plan. Work = choices tried, counted and bounded at
  400 000; over the bound the candidate is skipped. The minimality proof is that every choice of every smaller size was
  tried and failed (their count is stored). The witness is the plan's tunings in string order followed by one test,
  replayed through the kernel's play. Impact: FR-R02G1202-002; SC-R02G1202-001, 002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `HarmonicBridgesDifficulty` holds the
  witness tuning count, the islands, strings, locked strings, steps, tones, the threshold, the choices tried at smaller
  sizes and the solver work. The catalog in manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1,
  jump at most 3) on the witness tuning count; the band ranges, each two values wide and meeting the next band's at
  one value, make band means non-decreasing. Impact: FR-R02G1202-003, 005; SC-R02G1202-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/harmonic-bridges/levels/NNN.witness.json`, JSON
  schema 1 with sorted keys: number, the level's stored form, the actions, the bridge digest after every tuning (16 hex
  characters of the SHA-256 of the bridges per step), the play fingerprints after `begin` (and `dismissTutorial` when the
  level has one) and after each action, the counterexample (the size one below the plan and the number of choices of
  that size tried, none winning; for a one-tuning plan, the starting pegs' break), the difficulty and the candidates
  skipped. A test rebuilds every witness and compares bytes; it writes the files only with
  `HARMONIC_BRIDGES_WRITE_WITNESSES=1`. Decoding refuses newer schemas, damaged files and witnesses that no longer
  replay. Impact: FR-R02G1202-004; SC-R02G1202-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<HarmonicBridgesRules>.digest(id: "harmonic-bridges", identities:)` over the 100 level fingerprints in
  manifest order, pinned in a test. Certification tests are split into groups of 5 levels so each runs under 10 seconds
  on a debug host build (measured locally, not asserted on CI); generated levels are cached per process. New refusals:
  `generation(Int)` (`r02-g12.generation`) and `witness(String)` (`r02-g12.witness`). The independent check of
  SC-R02G1202-002 brute-forces every set of one tuning fewer than the plan over every peg (12 per string, no pattern
  pruning) on the two levels with the fewest strings in each of bands 1 … 3, and over every bridge pattern (every
  pattern a peg gives, not only maximal ones) on two levels in each of bands 4 and 5, and confirms none wins and that
  the plan wins. Impact: FR-R02G1202-004, 006; SC-R02G1202-002, 003, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some tunings within the moves budget make bridges join the
start island to the goal island in every step of the crossing window, and a test then wins. The game has proof of it
for every level, and proof that no fewer tunings would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget; every
tuning's resulting bridges equal the stored digest; the proof that fewer tunings cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** any choice of one tuning fewer than the witness is tried, **Then** no test wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the tunings the witness needs, the islands,
strings, locked strings, steps and tones, the threshold and the solver's work. Harder bands mean more strings to tune
over longer windows, never faster reactions.

**Independent Test**: band by band, the mean witness tuning count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the bridges after every tuning and
the counterexample proof that one tuning fewer cannot win. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate already won at its starting pegs, or needing no tuning:** never emitted.
- **More than one minimal plan:** allowed; the witness is the one the solver finds in its fixed order.
- **A plan needing more actions than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1202-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget; only levels the solver certifies within the budget MAY be emitted.
- **FR-R02G1202-002**: A solver MUST find a minimal set of tunings after which a test wins, with its work bounded and
  counted, and MUST prove that no smaller set wins; every plan it reports MUST be replayed through the kernel.
- **FR-R02G1202-003**: Each level MUST carry difficulty metrics (witness tunings, islands, strings, locked strings,
  steps, tones, threshold, solver work) derived from the level and the solver.
- **FR-R02G1202-004**: Each level MUST have a versioned witness record (level, actions, per-tuning bridge digests,
  counterexample proof); damaged, newer and edited files MUST be refused.
- **FR-R02G1202-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness tuning count never fall.
- **FR-R02G1202-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget.
- **Minimality proof**: the tunings of every smaller size that were tried and none of which wins.
- **Solver result**: the tunings, the test, the work counted, the proof.
- **Difficulty**: witness tunings, islands, strings, locked strings, steps, tones, threshold, work.
- **Witness**: schema, the level's stored form, actions, per-tuning bridge digests, counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1202-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G1202-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1202-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1202-004**: The mean witness tuning count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1202-005**: For every level, no set of one tuning fewer than its witness wins; edited, newer and damaged
  witness files are refused.
- **SC-R02G1202-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/harmonic-bridges/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Discrete rational string-mode search with graph edge existence and reachability" is read as: for every string, the
  bridge pattern over the window's steps at each of its 12 pegs; the search tries ever larger sets of retuned strings
  until the start reaches the goal in every step.
- Levels are presented, hinted and played through later features (R02-G12-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1202-001, 002 |
| Solver: discrete rational string-mode search with graph edge existence and reachability | FR-R02G1202-002 |
| Truth metric: mode amplitude envelope and bridge graph connectivity | FR-R02G1202-002, 003 |
| Certificates (witness, counterexample, per-tuning digests) | FR-R02G1202-004 |
| Difficulty metrics | FR-R02G1202-003, 005 |
| Invariants INV-06 content and INV-12 novelty | FR-R02G1202-002, 003 |
| Schema migration, error handling | FR-R02G1202-004, 006 |
| Deterministic tests | SC-R02G1202-002, 003 |
| No Stage One breakage | FR-R02G1202-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
