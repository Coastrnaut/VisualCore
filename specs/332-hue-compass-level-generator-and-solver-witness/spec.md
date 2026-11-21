# Feature Specification: R02-G04-02 — Hue Compass: level generator and solver witness

**Feature Branch**: `332-hue-compass-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G04-02 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0402-###,
SC-R02G0402-###, T-R02G0402-###

**Input**: User description: the archived R02-G04-02 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Generate solvable seeded levels with certificates and difficulty metrics" for Hue Compass, with the canonical overrides
of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/332-hue-compass-level-generator-and-solver-witness`; FR-R02G0402-###,
  SC-R02G0402-###, T-R02G0402-###.
- **Packaging (ADR-0009):** experience R02-G04 (`r02-g04.hue-compass`, free) in `Packages/ExperiencesRound02/HueCompass`;
  this feature extends `HueCompassCore` (R02-G04-01, feature 331) with the generator, the solver and the witness files.
  The source's `Apps/HueCompass` and `Packages/GameModules/HueCompassCore` paths are superseded.
- **Content count:** the canonical catalog is the 100-level manifest of the archived design
  (`python3 scripts/planning_index.py levels --experience R02-G04`: 20 levels in each of bands 1 … 5, each with its planned
  seed and move budget 8 … 19); the source's "content count 76" is a milestone only.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as in R02-G04-01). **Device-only
  items:** none (generation and certification run on the host). **Owner-only items:** none.
- **Shared features used:** R02-F23 (puzzle contract: `HueCompassRules` from R02-G04-01) and R02-F24 (catalog digest,
  difficulty and progression rule); R02-F03 numbers.
- **Model:** feature 322 (Wave Knot Keeper's generator and solver witness).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every shipped level can be deduced (Priority: P1) 🎯

A player opening any of the 100 levels can always find the hidden target by reasoning: some set of probes, within the
allowance, leaves only targets that one selection accepts. The game has proof of it for every level.

**Why this priority**: a level whose target cannot be deduced turns the game into guessing.

**Independent Test**: each level's stored witness probes, replayed from the start, leave a candidate set that the witness
selection accepts in full, within the allowance, and the selection wins.

**Acceptance Scenarios**:

1. **Given** any catalog level, **When** its witness is replayed, **Then** the level is won within the allowance.
2. **Given** any catalog level and any target consistent with the witness clues, **When** the witness selection is
   judged against that target, **Then** it is accepted (the deduction is sound, not lucky).
3. **Given** a catalog level, **When** the solver runs again, **Then** it finds the same smallest probe count.

### User Story 2 - Levels come from their planned seeds (Priority: P1)

Each level is built from its manifest seed, band and move budget the same way on every build; a changed rule or seed
changes the pinned fingerprints and fails the checks.

**Independent Test**: building the catalog twice gives identical levels; the catalog digest equals the pinned value.

### User Story 3 - Difficulty that means something (Priority: P2)

Each level carries difficulty metrics from the solver's actual result: the smallest number of probes that settles the
target, the number of targets still possible after a single best probe, the tolerances and the solver's work. Harder
bands need more probes and tighter tolerances, never faster reactions.

**Independent Test**: band by band, the mean smallest probe count does not fall; the catalog keeps the progression rule.

### User Story 4 - Honest witness files (Priority: P2)

For each level a witness file records the level, the probe bearings, the clues, the candidate count after each probe, the
selection, the play fingerprints, and two counterexamples: a selection just outside a tolerance that fails, and a smaller
probe set that leaves two targets no single selection accepts together. Any edited or fake witness is caught.

**Independent Test**: all 100 witness files match what the generator and solver produce now, byte for byte; an edited
file is refused.

### Edge Cases

- **A seed whose candidate is not deducible, too easy or too hard for its band:** the generator moves to the next
  candidate deterministically (a bounded number) and records how many it skipped; no candidate within the bound is a
  named refusal.
- **More than one smallest probe set:** allowed; the witness picks one by a stated tie rule.
- **A level deducible with a single probe (smallest count 1):** the "smaller probe set" counterexample is the empty set
  (no probe), which must leave two targets no selection accepts together.
- **Damaged, newer or edited witness files:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0402-001**: A generator MUST build each catalog level deterministically from its manifest number, seed, band
  and move budget; only levels the solver proves deducible within the allowance MAY be emitted, and none starts solved.
- **FR-R02G0402-002**: A solver MUST find the smallest set of probe bearings after which every target consistent with
  the clues is accepted by one selection, searching every set up to a stated size, with its work bounded by arithmetic.
- **FR-R02G0402-003**: Each level MUST carry difficulty metrics (smallest probe count, candidates after the best single
  probe, tolerances, solver work) derived from the level and the solver.
- **FR-R02G0402-004**: Each level MUST have a versioned witness record (level, probes, clues, candidate counts,
  selection, fingerprints, the failing near-miss selection, the insufficient smaller probe set); damaged, newer and edited
  files MUST be refused.
- **FR-R02G0402-005**: The catalog of 100 levels MUST have a digest pinned in tests and MUST satisfy the shared
  progression rule; band means of the smallest probe count never fall.
- **FR-R02G0402-006**: Invalid requests MUST be refused with stable reason codes; existing code MUST change only
  additively; every new public name is documented; the reference regression passes.

### Key Entities

- **Manifest entry**: number, planned seed, band, move budget.
- **Solver result**: smallest probe count, a smallest probe set, the selection, work.
- **Difficulty**: smallest probes, candidates after the best single probe, tolerances, work.
- **Witness**: schema, the level's stored form, probes, clues, candidate counts, selection, fingerprints, two
  counterexamples, skipped candidates.
- **Catalog**: the 100 levels in manifest order with a digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0402-001**: All 100 catalog levels are won by replaying their witness within the allowance; for each, every
  target consistent with the witness clues is accepted by the witness selection.
- **SC-R02G0402-002**: The solver's smallest probe count equals an independent brute-force search on sampled catalog
  levels (at least two per band).
- **SC-R02G0402-003**: Building the catalog twice gives identical levels and the pinned digest; each witness file matches
  the regenerated witness byte for byte.
- **SC-R02G0402-004**: The mean smallest probe count does not fall from one band to the next; the catalog keeps its
  progression rule.
- **SC-R02G0402-005**: Every near-miss selection fails; every smaller probe set leaves two consistent targets no single
  selection accepts; edited, newer and damaged witness files are refused.
- **SC-R02G0402-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds on a debug host build, the catalog certification split as needed.

## Assumptions

- The 100 witness files live in `docs/games/hue-compass/levels/NNN.witness.json`; they are regenerated only by a test run
  with an explicit opt-in and checked byte for byte on every other run.
- The player knows the level's public facts (offset, fog, tolerances, allowance, start) but not the target; a target
  within the bearing tolerance of the start is impossible by the kernel's rule and is not a candidate.
- Levels are presented, hinted and played through later features (R02-G04-03 … 07); this feature draws nothing.
- The manifest's numbers, seeds, bands and move budgets are copied from the project's own archived design; no
  third-party content is used.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Solvable seeded levels ("uniqueness tests") | FR-R02G0402-001, 002 |
| Certificates (witness, counterexamples) | FR-R02G0402-004 |
| Difficulty metrics | FR-R02G0402-003, 005 |
| Schema migration, error handling | FR-R02G0402-004, 006 |
| Deterministic tests | SC-R02G0402-002, 003 |
| No Stage One breakage | FR-R02G0402-006 |

## Negative Requirements / Excluded scope

- No rendering, controls, gestures, hints, progression UI or persistence of player progress; no daily-seed mode (later
  features); no device run before ImplementationLock-100; no network; no hand-authored levels; no purchases or ads.
