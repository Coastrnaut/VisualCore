# Feature Specification: R02-G06-02 — Chrono Constellator: level generator and solver witness

**Feature Branch**: `352-chrono-constellator-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G06-02 (migration ledger, game feature of experience R02-G06) · ID namespace FR-R02G0602-###,
SC-R02G0602-###, T-R02G0602-###

**Input**: User description: the archived R02-G06-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Chrono Constellator, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/352-chrono-constellator-level-generator-and-solver-witness`; FR-R02G0602-###,
  SC-R02G0602-###, T-R02G0602-###.
- **Packaging (ADR-0009):** experience R02-G06 (`r02-g06.chrono-constellator`, free) in
  `Packages/ExperiencesRound02/ChronoConstellator`; this feature extends `ChronoConstellatorCore` (R02-G06-01, feature
  351) with the generator, the solver and the witness files. The source's `Apps/ChronoConstellator` and
  `Packages/GameModules/ChronoConstellatorCore` paths are superseded.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design (Auto-Creator.md, R02-G06
  chapter: "100 solver-certified levels … the chapter header's earlier figure ('78 solver-certified stages') and its
  shorter manifests are milestones only"; `python3 scripts/planning_index.py levels --experience R02-G06`: 20 levels in
  each of bands 1 … 5, each with its planned seed and move budget 8 … 19). The prompt's "content count 78" is that
  milestone figure.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as in R02-G06-01). **Device-only
  items:** none (generation and certification run on the host). **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: `ChronoConstellatorRules` from R02-G06-01) and R02-F24 (catalog
  digest, difficulty and progression rule); R02-F03 numbers.
- **Model:** feature 342 (Colorfall Canyons's generator and solver witness).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be solved (Priority: P1) 🎯

A player opening any of the 100 levels can always bring the constellation together: some small timeline of start-phase
changes and holds, within the edit budget, replayed from the start, puts every star on its own target on the same tick
without a collision. The game has proof of it for every level.

**Why this priority**: an unsolvable level breaks the game.

**Independent Test**: each level's stored witness actions, replayed from the start, win within the budget and the tick
limit, and every tick's positions equal the stored digests.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the budget and the
   tick limit.
2. **Given** any catalog level, **When** its default timeline is replayed with no edits, **Then** it is not won (the
   puzzle needs the player).
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same smallest number of edits.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the smallest number of edits that wins, the tick
of the win, the number of stars, the loops' lengths and how many tempting alignment windows are blocked by collisions.
Harder bands need more edits and dodge more collisions, never faster reactions.

**Independent Test**: band by band, the mean smallest edit count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the winning actions, the tick of the win, per-tick position digests and
counterexamples: the level replayed without edits fails, and no timeline with fewer edits wins. Any edited or fake witness
is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is unsolvable, too easy or too hard for its band:** the generator moves to the next candidate
  deterministically (bounded) and records how many it skipped; no candidate within the bound is a named refusal.
- **More than one smallest timeline:** allowed; the witness picks one by a stated tie rule.
- **A level won with no edit:** never emitted.
- **An alignment window blocked by a collision:** it does not count as a solution of that size; the witness's window is
  collision-free.
- **A smallest edit count of 1:** the near miss (the witness minus its last edit) is the unedited level, so both
  counterexamples name the same failure.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0602-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves solvable within the budget and the tick limit MAY be emitted, and none
  is won without edits.
- **FR-R02G0602-002**: A solver MUST find the smallest number of edits (start-phase changes and holds) whose timeline
  wins the level, with a proof that no smaller timeline wins, its work bounded by arithmetic; every win it reports MUST be
  replayed through the kernel.
- **FR-R02G0602-003**: Each level MUST carry difficulty metrics (smallest edit count, win tick, star count, loop lengths,
  alignment windows considered and windows blocked by collisions) derived from the level and the solver.
- **FR-R02G0602-004**: Each level MUST have a versioned witness record (level, actions, win tick, per-tick position
  digests, counterexamples); damaged, newer and edited files MUST be refused.
- **FR-R02G0602-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the smallest edit count never fall.
- **FR-R02G0602-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: smallest edit count, a smallest timeline, the win tick, the lower-bound proof, work.
- **Difficulty**: smallest edits, win tick, stars, loop lengths, windows considered and blocked.
- **Witness**: schema, the level's stored form, actions, win tick, per-tick digests, counterexamples, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0602-001**: All 100 catalog levels are won by replaying their witness within the budget and tick limit.
- **SC-R02G0602-002**: The solver's smallest edit count equals an independent brute-force search on sampled catalog
  levels (at least two per band).
- **SC-R02G0602-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file matches
  the regenerated witness byte for byte.
- **SC-R02G0602-004**: The mean smallest edit count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G0602-005**: Every level fails without edits and with every smaller timeline the proof covers; edited, newer
  and damaged witness files are refused.
- **SC-R02G0602-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/chrono-constellator/levels/NNN.witness.json` (the manifest's "Required
  artifact"); they are regenerated only by a test run with an explicit opt-in and checked byte for byte on every other
  run.
- The player sees every star, its loop and its target; nothing is hidden.
- Levels are presented, hinted and played through later features (R02-G06-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels | FR-R02G0602-001, 002 |
| Solver: integer-tick phase search for replay windows and time offsets | FR-R02G0602-002 |
| Certificates (witness, counterexamples, per-tick digests) | FR-R02G0602-004 |
| Difficulty metrics | FR-R02G0602-003, 005 |
| Schema migration, error handling | FR-R02G0602-004, 006 |
| Deterministic tests | SC-R02G0602-002, 003 |
| No Stage One breakage | FR-R02G0602-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
