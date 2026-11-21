# Feature Specification: R02-G05-02 — Colorfall Canyons: level generator and solver witness

**Feature Branch**: `342-colorfall-canyons-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G05-02 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0502-###,
SC-R02G0502-###, T-R02G0502-###

**Input**: User description: the archived R02-G05-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Colorfall Canyons, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/342-colorfall-canyons-level-generator-and-solver-witness`; FR-R02G0502-###,
  SC-R02G0502-###, T-R02G0502-###.
- **Packaging (ADR-0009):** experience R02-G05 (`r02-g05.colorfall-canyons`, free) in
  `Packages/ExperiencesRound02/ColorfallCanyons`; this feature extends `ColorfallCanyonsCore` (R02-G05-01, feature 341)
  with the generator, the solver and the witness files. The source's `Apps/ColorfallCanyons` and
  `Packages/GameModules/ColorfallCanyonsCore` paths are superseded.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design
  (`python3 scripts/planning_index.py levels --experience R02-G05`: 20 levels in each of bands 1 … 5, each with its planned
  seed and move budget 8 … 19).
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as in R02-G05-01). **Device-only
  items:** none (generation and certification run on the host). **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: `ColorfallCanyonsRules` from R02-G05-01) and R02-F24 (catalog
  digest, difficulty and progression rule); R02-F03 numbers.
- **Model:** feature 332 (Hue Compass's generator and solver witness).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always route the colours into their basins: some short set of carves and
valve changes, within the move budget, followed by letting time run, wins. The game has proof of it for every level.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget and the tick
limit, with exact conservation on every tick.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget and the
   tick limit.
2. **Given** any catalog level, **When** the level is played with no edits at all, **Then** it is not won (the puzzle
   needs the player).
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same smallest number of edits.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the smallest number of edits that wins, the number
of distinct routings the solver examined, the colours and basins involved and the ticks to the win. Harder bands need
more edits, never faster reactions.

**Independent Test**: band by band, the mean smallest edit count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, the tick of the win, per-tick state digests, the
conservation totals, and counterexamples: the level played without edits fails, and every set of fewer edits than the
smallest fails. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsolvable, too easy or too hard for its band:** the generator moves to the next candidate
  deterministically (within a stated bound) and records how many it skipped; no candidate within the bound is a named
  refusal.
- **More than one smallest edit set:** allowed; the witness picks one by a stated tie rule.
- **A level solvable with no edit:** never emitted.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0502-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves solvable within the budget and the tick limit MAY be emitted, and none
  is won without edits.
- **FR-R02G0502-002**: A solver MUST find the smallest set of edits (carves and valve toggles) that, followed by running
  time, wins the level, searching every set up to a stated size, with its work bounded by arithmetic; every simulated run
  MUST assert exact conservation.
- **FR-R02G0502-003**: Each level MUST carry difficulty metrics (smallest edit count, distinct routings examined, ticks to
  the win, colours and basins involved) derived from the level and the solver.
- **FR-R02G0502-004**: Each level MUST have a versioned witness record (level, actions, win tick, per-tick digests,
  conservation totals, counterexamples); damaged, newer and edited files MUST be refused.
- **FR-R02G0502-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the smallest edit count never fall.
- **FR-R02G0502-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: smallest edit count, a smallest edit set, the win tick, work.
- **Difficulty**: smallest edits, routings examined, ticks to the win, colours and basins.
- **Witness**: schema, the level's stored form, actions, win tick, per-tick digests, totals, counterexamples, skipped
  candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0502-001**: All 100 catalog levels are won by replaying their witness within the budget and tick limit, with
  zero drift of fluid and of each colour on every tick.
- **SC-R02G0502-002**: The solver's smallest edit count equals an independent brute-force search on sampled catalog levels
  (at least two per band).
- **SC-R02G0502-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file matches
  the regenerated witness byte for byte.
- **SC-R02G0502-004**: The mean smallest edit count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G0502-005**: Every level fails without edits and with every smaller edit set; edited, newer and damaged witness
  files are refused.
- **SC-R02G0502-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/colorfall-canyons/levels/NNN.witness.json`; they are regenerated only by a
  test run with an explicit opt-in and checked byte for byte on every other run.
- The player sees the whole terrain, every spring and every basin's target; nothing is hidden.
- Levels are presented, hinted and played through later features (R02-G05-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0502-001, 002 |
| Certificates (witness, counterexamples, per-tick digests, conservation) | FR-R02G0502-004 |
| Difficulty metrics | FR-R02G0502-003, 005 |
| Schema migration, error handling | FR-R02G0502-004, 006 |
| Deterministic tests | SC-R02G0502-002, 003 |
| No Stage One breakage | FR-R02G0502-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
