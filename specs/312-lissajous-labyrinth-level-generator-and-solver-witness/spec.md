# Feature Specification: R02-G02-02 — Lissajous Labyrinth: level generator and solver witness

**Feature Branch**: `312-lissajous-labyrinth-level-generator-and-solver-witness` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

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
  the start to a winning setting through legal states only; its work is bounded by the size of that setting space.
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
- **SC-R02G0202-002**: The solver's verdicts equal the kernel's lap verdict on every setting checked by an independent
  brute-force pass (all legal settings of 10 catalog levels and of 50 seeded levels); its shortest lengths equal a plain
  breadth-first search over legal states on every catalog level.
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
- Accessibility (VoiceOver, controls) is owned by later features; the witness and difficulty data are plain text and
  numbers usable by them. Observability: generation reports skipped candidates and solver work per level.

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
