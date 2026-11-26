# Feature Specification: R02-G19-02 — Microscopic Aurora: level generator and solver witness

**Feature Branch**: `482-microscopic-aurora-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Draft

**Ledger gate**: R02-G19-02 (migration ledger, game feature of experience R02-G19) · ID namespace FR-R02G1902-###,
SC-R02G1902-###, T-R02G1902-###

**Input**: User description: the archived R02-G19-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Microscopic Aurora, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/482-microscopic-aurora-level-generator-and-solver-witness`; FR-R02G1902-###,
  SC-R02G1902-###, T-R02G1902-###.
- **Packaging (ADR-0009):** experience R02-G19 (`r02-g19.microscopic-aurora`, free) in the one app; this feature
  extends the pure `MicroscopicAuroraCore` of feature 481. No app target, bundle identifier, scheme or store listing.
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign.
  **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (`python3
  scripts/planning_index.py levels --experience R02-G19`: 20 levels in each of bands 1 … 5, each with its planned seed
  and moves budget 8 … 19, control emphases `record trail`, `commit organism shape`, `place magnetic pole`, `tune field`
  and `release swimmers`, 20 each). The prompt's "content count 82" is a milestone figure, as for the earlier round-two
  games.
- **Kernel extension (additive):** the manifest's budgets reach 19, above feature 481's budget range 1 … 12, so the
  range widens to 1 … 24; and a level may declare its well sites, the cells where wells may be placed (placements
  elsewhere are refused), so the solver searches, and proves minimality over, the whole move space of a level. A level
  without sites keeps feature 481's behaviour, stored form and fingerprint.
- **Model:** feature 472 (Apsides Workshop's content pipeline) for manifest, generator, solver, witness files, digest and
  progression, adapted to the swarm rules of feature 481: a move places, changes or removes a well, and the play ends
  the level.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always win: some well placements within the moves budget give a swim whose
trails cover the stencil as one pattern without a swimmer escaping or the swarm breaking apart. The game has proof of it
for every level, and proof that no fewer placements would do.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win on the play within the budget;
every action's resulting state equals the stored digest; the proof that fewer placements cannot win is re-checked.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed and the swim is played, **Then** the level is won
   within the budget.
2. **Given** any catalog level, **When** any well setting reachable with fewer actions than the witness is played, **Then**
   none wins.
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same witness.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and budget the same way on every build; a changed rule or seed changes
the pinned fingerprints and fails the checks.

**Why this priority**: reproducible content is what the witnesses, the digest and every later feature rely on.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

**Acceptance Scenarios**:

1. **Given** the manifest, **When** the catalog is built twice, **Then** every level and the digest are identical.
2. **Given** a manifest entry whose candidates are unsuitable, **When** the generator runs, **Then** it moves to the
   next candidate deterministically and records how many it skipped.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the placements the witness needs, the stencil's size, the
required coverage, the swarm's size, the number of sites, the settings searched and the solver's work. Harder bands
mean larger patterns, stricter coverage and more wells working together, never faster reactions.

**Why this priority**: the five bands must feel like a progression.

**Independent Test**: band by band, the mean witness length does not fall; the catalog keeps the progression rule.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** the witness lengths are averaged per band, **Then** no band's mean is below the
   previous band's.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, a digest of the state after every action, the
terminal swim report (the swarm density distribution: lit stencil cells and coverage; the pattern connectivity: groups
and the smallest coherence) and the counterexample proof that fewer placements cannot win. Any edited or fake witness is caught.

**Why this priority**: the certificates are the release evidence for the content.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

**Acceptance Scenarios**:

1. **Given** the 100 witness files, **When** the witnesses are regenerated, **Then** every file matches byte for byte.
2. **Given** a witness file with one changed character, a newer schema or a damaged body, **When** it is decoded,
   **Then** it is refused with a named reason.

### Edge Cases

- **A seed whose candidate is unsuitable for its band:** the generator moves to the next candidate deterministically
  (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **A candidate whose starting wells already win, or whose swarm escapes or breaks apart with every setting:** never
  emitted (the kernel refuses the first; the solver finds no plan for the second).
- **More than one minimal setting:** allowed; the witness is the one the solver finds in its fixed order.
- **Adjacent levels with the same stencil:** the later candidate is skipped (FR-R02G1902-007).
- **A plan needing more placements than the budget:** not emitted.
- **A search over its work bound:** the candidate is skipped (counted work, never timed).
- **A coverage exactly at the requirement, a density at the threshold, a swimmer on the rim:** decided exactly by the
  kernel's integer rules; the generator and solver add no tolerance.
- **A two-placement plan whose second well would land on the first's site:** impossible by construction; the witness
  places wells on distinct sites in slot order.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1902-001**: A generator MUST build each catalog level deterministically from its manifest number, seed,
  band and budget; only levels the kernel accepts and the solver certifies within the budget MAY be emitted.
- **FR-R02G1902-002**: A solver MUST find a minimal sequence of placements after which playing the swim wins, by a
  low-dimensional search over the wells' sites, strengths and senses with the seeded swarm simulator of feature 481 and a
  shape loss guiding the order, with its work bounded and counted, and MUST prove that no shorter sequence wins; every
  plan it reports MUST be replayed through the kernel's play.
- **FR-R02G1902-003**: Each level MUST carry difficulty metrics (witness length, stencil size, required coverage, swarm
  size, sites, settings searched, solver work) derived from the level and the solver.
- **FR-R02G1902-004**: Each level MUST have a versioned witness record (level, actions, per-action state digests,
  terminal swim report with its density distribution and pattern connectivity, counterexample proof); damaged, newer and
  edited files MUST be refused.
- **FR-R02G1902-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the witness length never fall.
- **FR-R02G1902-006**: Invalid requests MUST be refused with stable reason codes `r02-g19.*`; existing code MUST change
  only additively; every new public name is documented; the reference regression passes.
- **FR-R02G1902-007**: Each emitted level MUST differ from its neighbours in the manifest (its fingerprint and its
  stencil are not those of the previous level), so adjacent seeds give genuinely different puzzles.

### Key Entities

- **Manifest entry**: number, planned seed, band, moves budget, control emphasis.
- **Minimality proof**: every well setting reachable with fewer actions, none of which wins.
- **Solver result**: the placements, the work counted, the proof.
- **Difficulty**: witness length, stencil size, coverage, swarm size, sites, settings searched, work.
- **Witness**: schema, the level's stored form, actions, per-action state digests, terminal swim report,
  counterexample, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1902-001**: All 100 catalog levels are won by replaying their witness and playing the swim, within the
  budget.
- **SC-R02G1902-002**: The minimality proof equals an independent brute-force check on sampled catalog levels (at least
  two per band).
- **SC-R02G1902-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file
  matches the regenerated witness byte for byte.
- **SC-R02G1902-004**: The mean witness length does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G1902-005**: For every level, no well setting reachable with fewer actions than its witness wins; edited, newer and
  damaged witness files are refused.
- **SC-R02G1902-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes
  in under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/microscopic-aurora/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- "Low-dimensional field strength search with seeded boid simulator and shape-loss evaluation" is read as: the solver
  enumerates the well settings reachable by placements (sites, strengths 1 … 4, senses) by the number of actions from
  the start, judging each with the kernel's exact swim, and orders the settings at each depth by a shape loss (how far
  the swim's lit cells are from the stencil), so the first win found is minimal and the loss only speeds the search.
- "Keep false pattern due to blur outside the admissible zone" is read as: a cell counts only when its exact trail
  density reaches the threshold, never by a blurred or rendered estimate.
- Levels are presented, hinted and played through later features (R02-G19-03 … 07); this feature draws nothing.
- Accessibility and observability: every generated level is named in words by feature 481's kernel (wells, sites, cells,
  coverage, coherence), so no level depends on colour; the witness files and the difficulty metrics are the
  content pipeline's observable record, and skipped candidates are counted, not hidden.
- The manifest's numbers, seeds, bands and budgets are copied from the project's own archived design; no third-party
  content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G1902-001, 002 |
| Solver: low-dimensional field strength search with seeded boid simulator and shape loss | FR-R02G1902-002 |
| Truth metric: swarm density distribution and pattern connectivity | FR-R02G1902-004 |
| Certificates (witness, counterexample, per-action digests) | FR-R02G1902-004 |
| Difficulty metrics | FR-R02G1902-003, 005 |
| Different puzzle from adjacent seeds | FR-R02G1902-007 |
| Schema migration, error handling | FR-R02G1902-004, 006 |
| Deterministic tests | SC-R02G1902-002, 003 |
| No Stage One breakage | FR-R02G1902-006 |
