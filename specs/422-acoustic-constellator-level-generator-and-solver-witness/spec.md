# Feature Specification: R02-G13-02 — Acoustic Constellator: level generator and solver witness

**Feature Branch**: `422-acoustic-constellator-level-generator-and-solver-witness` (spec directory only; work on
`main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G13-02 (migration ledger, game feature of experience R02-G13) · ID namespace FR-R02G1302-###,
SC-R02G1302-###, T-R02G1302-###

**Input**: User description: the archived R02-G13-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Acoustic Constellator, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/422-acoustic-constellator-level-generator-and-solver-witness`;
  FR-R02G1302-###, SC-R02G1302-###, T-R02G1302-###.
- **Packaging (ADR-0009):** experience R02-G13 (`r02-g13.acoustic-constellator`, free) in the one app; this feature
  extends the pure `AcousticConstellatorCore` of feature 421.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G13`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19). The prompt's "content count 85" (the catalog's "85 solver-certified stages") is a milestone
  figure, as for the earlier round-two games.
- **Model:** feature 412 (Harmonic Bridges's content pipeline) for manifest, generator, witness files, digest and
  progression.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
412's answers where the games agree. Facts checked (read-only, 2026-11-23): R02-G13-01's `AcousticConstellatorLevel`
(stars 3 … 8, rates and phases 0 … 11, fixed links 0 … 6, symbol 2 … 10 connected pairs, K 1 … 8, degree limit 2 … 4,
link limit up to 16, snap limit 2 … 5, threshold 1 … n², hold 2 … 12, window up to 48, budget 1 … 40),
`AcousticConstellatorListen`, `AcousticConstellatorPlay` and `AcousticConstellatorRules`; R02-F24's
`PuzzleCatalog.digest(id:identities:)` and the standard `ProgressionRule` (drop at most 1, jump at most 3);
`SeedDerivation.derive(_:index:)` and `SeededRandom`; the canonical manifest's 100 entries (`planning_index.py levels
--experience R02-G13`: bands 1 … 5 × 20, moves budgets 8 … 11, 10 … 13, 12 … 15, 14 … 17, 16 … 19). The acceptance
ranges below were measured before they were written down: a prototype of this generator and solver over 60 candidates
per band gave minimal plans in the band's range for 48, 33, 38, 17 and 21 of 60 (bands 1 … 5), with at most 6,657
listens of work, and no candidate won at its start.

- Q: How is a level built from its manifest entry? → A: the 100 entries (number, planned seed, band, budget) are a table
  in `AcousticConstellatorManifest` with their provenance. Candidate c of entry n draws from `SeededRandom(seed:
  SeedDerivation.derive(plannedSeed, index: c))`, in this order: the star count n by band (3 … 4, 4 … 5, 5 … 6, 6 … 7,
  7 … 8); the symbol as a spanning tree (a shuffled order of the stars, each star after the first joined to a drawn
  earlier one) plus, from band 3, one extra pair not already in it (a cycle); a base rate 0 … 11 and each star's rate
  base + 0 or 1 (1 with chance 1 in 3), modulo 12; each star's starting phase 0 … 11; the missing count by band (1 … 2,
  1 … 2, 2 … 3, 2 … 3, 3 … 4, at most the symbol's size) and the missing pairs as a drawn subset of the symbol, the rest
  being the fixed links; the coupling K 2 … 8, the snap limit 3 … 5 and the hold 4 … 8; the window by band (24, 24, 32,
  40, 48). Then the degree limit is min(4, max(2, the symbol's largest degree + 1)), the link limit min(16, the
  symbol's size + 2) and the threshold ⌊3n²/5⌋. Budget = the manifest's; ids `acoustic-constellator-NNN`; tutorial on
  levels 1 … 3; difficulty = band; star drawing positions are laid out from the symbol and never decide a rule. A
  candidate the solver does not certify with a minimal plan in its band's range (1 … 2, 2 … 3, 3 … 4, 4 … 5, 5 … 6
  actions before the listen) and at most budget − 1 actions within its work bound is skipped; at most 256 candidates,
  then `generation(n)`. Impact: FR-R02G1302-001; SC-R02G1302-001, 003, 004.
- Q: How does the solver find a minimal plan, and what proves nothing smaller wins? → A: every winning plan contains a
  link for every missing symbol pair, so those are always in the plan. The other useful actions are helper links (pairs
  not yet linked, in pair order) and nudges (star order, −1 then +1); unlinking is never useful (the player starts with
  no links of their own) and opposite nudges on one star cancel, so a minimal plan contains neither. The solver tries
  e = 0, 1, 2, … extra actions: every multiset of e options in option order, skipping a repeated helper link, opposite
  nudges on one star and sets that break the degree or link limit; for each it runs the kernel's listen on the fixed,
  missing and helper links with the nudged phases. The first set whose listen wins is the plan. Work = listens, counted
  and bounded at 400,000; over the bound the candidate is skipped. The minimality proof is that every set of every
  smaller size was tried and lost (their count is stored). The witness is the plan's links in pair order, then its
  nudges in star order, then one listen, replayed through the kernel's play. Impact: FR-R02G1302-002; SC-R02G1302-001,
  002, 005.
- Q: What difficulty metrics are stored and what progression is required? → A: `AcousticConstellatorDifficulty` holds
  the witness action count (before the listen), the stars, the symbol's pairs and cycles (pairs − stars + 1), the fixed
  links, the rate spread (0 or 1), the window, the hold, the threshold, the sets tried at smaller sizes and the solver
  work. The catalog in manifest order keeps R02-F24's standard `ProgressionRule` (drop at most 1, jump at most 3) on the
  witness action count; the band ranges, each two values wide and meeting the next band's at one value, make band means
  non-decreasing. Impact: FR-R02G1302-003, 005; SC-R02G1302-004.
- Q: What is in a witness file and how is it checked? → A: `docs/games/acoustic-constellator/levels/NNN.witness.json`,
  JSON schema 1 with sorted keys: number, the level's stored form, the actions, the state digest after every action (16
  hex characters of the SHA-256 of the links and phases), the play fingerprints after `begin` (and `dismissTutorial` when
  the level has one) and after each action, the counterexample (the size one below the plan and the number of sets of
  that size tried, none winning), the difficulty and the candidates skipped. A test rebuilds every witness and compares
  bytes; it writes the files only with `ACOUSTIC_CONSTELLATOR_WRITE_WITNESSES=1`. Decoding refuses newer schemas,
  damaged files and witnesses that no longer replay. Impact: FR-R02G1302-004; SC-R02G1302-003, 005.
- Q: How is the catalog identified, how long may certification take and how are refusals named? → A: the digest is
  `PuzzleCatalog<AcousticConstellatorRules>.digest(id: "acoustic-constellator", identities:)` over the 100 level
  fingerprints in manifest order, pinned in a test. Certification tests are split into groups of 5 levels so each runs
  under 10 seconds on a debug host build (measured locally, not asserted on CI); generated levels are cached per process.
  New refusals: `generation(Int)` (`r02-g13.generation`) and `witness(String)` (`r02-g13.witness`). The independent check
  of SC-R02G1302-002 brute-forces every multiset of one action fewer than the plan over all actions the play accepts
  (every link, every unlink of a placed link, every nudge, no pruning of opposite nudges) on the two levels with the
  fewest stars in each of bands 1 … 3, and over the pruned options (helper links and nudges, enumerated independently of
  the solver's order) on the two levels with the fewest stars in bands 4 and 5, where the full set (about 650,000
  listens at size 5) would not fit the 10-second test limit. Impact: FR-R02G1302-005, 006; SC-R02G1302-002, 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some links and phase nudges within the moves budget make every
link of the target symbol exist and the stars cohere for the hold, and a listen then wins. The game has proof of it for
every level, and proof that no fewer actions would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget; every
action's resulting state equals the stored digest; the proof that fewer actions cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget.
2. **Given** any catalog level, **When** any set of one action fewer than the witness is tried, **Then** no listen wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the actions the witness needs, the stars, the
symbol's pairs and cycles, the fixed links, the rate spread, the window and hold, and the solver's work. Harder bands
mean larger constellations that need more links and finer phase work, never faster reactions.

**Independent Test**: band by band, the mean witness action count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action and the
counterexample proof that one action fewer cannot win. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate already won at its start, or needing no action:** never emitted.
- **More than one minimal plan:** allowed; the witness is the one the solver finds in its fixed order.
- **A plan needing more actions than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1302-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and budget; only levels the solver certifies within the budget MAY be emitted.
- **FR-R02G1302-002**: A solver MUST find a minimal set of actions (links and nudges) after which a listen wins, with
  its work bounded and counted, and MUST prove that no smaller set wins; every plan it reports MUST be replayed through
  the kernel.
- **FR-R02G1302-003**: Each level MUST carry difficulty metrics (witness actions, stars, symbol pairs and cycles, fixed
  links, rate spread, window, hold, solver work) derived from the level and the solver.
- **FR-R02G1302-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  counterexample proof); damaged, newer and edited files MUST be refused.
- **FR-R02G1302-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness action count never fall.
- **FR-R02G1302-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget.
- **Minimality proof**: the action sets of every smaller size that were tried and none of which wins.
- **Solver result**: the actions, the listen, the work counted, the proof.
- **Difficulty**: witness actions, stars, symbol pairs and cycles, fixed links, rate spread, window, hold, work.
- **Witness**: schema, the level's stored form, actions, per-action state digests, counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1302-001**: All 100 catalog levels are won by replaying their witness within the budget.
- **SC-R02G1302-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1302-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1302-004**: The mean witness action count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1302-005**: For every level, no set of one action fewer than its witness wins; edited, newer and damaged
  witness files are refused.
- **SC-R02G1302-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/acoustic-constellator/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Graph spanning tree/cycle search plus bounded oscillator synchronization simulation" is read as: the generator draws
  the symbol as a spanning tree of the stars plus cycles by band; the solver tries ever larger sets of actions (the
  missing symbol links, then helper links and phase nudges) and runs the kernel's bounded listen on each.
- Levels are presented, hinted and played through later features (R02-G13-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1302-001, 002 |
| Solver: spanning tree/cycle search plus bounded synchronization simulation | FR-R02G1302-002 |
| Truth metric: order parameter and graph-isomorphism label | FR-R02G1302-002, 003 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G1302-004 |
| Difficulty metrics | FR-R02G1302-003, 005 |
| Invariants INV-06 content and INV-12 novelty | FR-R02G1302-002, 003 |
| Schema migration, error handling | FR-R02G1302-004, 006 |
| Deterministic tests | SC-R02G1302-002, 003 |
| No Stage One breakage | FR-R02G1302-006 |
