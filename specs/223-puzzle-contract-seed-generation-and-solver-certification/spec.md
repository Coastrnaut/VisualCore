# Feature Specification: R02-F23 — Puzzle contract, seed generation and solver certification

**Feature Branch**: `223-puzzle-contract-seed-generation-and-solver-certification` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-F23 (migration ledger, shared round feature) · ID namespace FR-R02F23-###, SC-R02F23-###, T-R02F23-###

**Input**: User description: the archived R02-F23 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"immutable level schemas; explicit solutions; uniqueness mode; fairness budget; deterministic validation", with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/223-puzzle-contract-seed-generation-and-solver-certification`; FR-R02F23-###,
  SC-R02F23-###, T-R02F23-###.
- **Section 13 disposition: new, in an existing module.** Section 13.2 proposes a VisualCorePuzzle module; R02-F16 put
  the grid and graph solvers and their certificates (`RouteGraph`, `GridGraph`, `RouteSearch`, `SolverCertificate`,
  `CertificateChecker`) in VisualCoreSimulation instead, and this feature follows that precedent: no new module. The
  lifecycle and digest parts named in the map are delivered by UA-F02 (the experience contract and `StableHash` in
  VisualCoreMath) and are reused. There is no general puzzle contract yet: no immutable level form with an explicit
  solution, no check that the solution is legal and solves the level, no uniqueness check, no fairness budget and no
  seeded generator that only hands out certified levels. This feature adds them; existing types stay unchanged.
- **Who the users are:** every player of a puzzle experience, who gets only levels that can be solved, whose solution is
  the one the level promises when it says so, that are neither trivially short nor unreasonably long, and that are the
  same on every device for the same seed; the engineer, who needs a level's identity to change whenever its content
  changes, and every check to be bounded and reproducible.
- **Prerequisites:** R02-F03 (numerical foundations) and R02-F16 (route solvers) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** generation time of a batch of levels on D1–D3, recorded in the device
  campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `StableHash.sha256Hex` (VisualCoreMath), `SeededRandom` and
`SeedDerivation.derive(_:index:)` (VisualCoreSimulation), and the R02-F16 solvers and `SolverCertificate` are present; no
puzzle contract exists; the names `PuzzleRules`, `PuzzleLevel`, `PuzzleUniqueness`, `FairnessBudget`, `PuzzleValidator`,
`PuzzleCertificate`, `PuzzleVerdict`, `PuzzleGenerator`, `PuzzleGeneration` and `PuzzleError` are free.

- Q: What do a puzzle's rules provide, and where does the contract live? → A: in VisualCoreSimulation, a protocol
  `PuzzleRules` with a `rulesID` (lowercase slug of at most 64 characters), a `State` and a `Move` (both `Hashable`,
  `Codable`, `Sendable`), `moves(in:)` returning the legal moves in a fixed order, `apply(_:to:)` returning the next
  state or nil for an illegal move, and `isSolved(_:)`. Rules must be pure: the same state always gives the same moves
  and results. Impact: FR-R02F23-002, 003; SC-R02F23-002.
- Q: What is a level and how is its identity formed? → A: `PuzzleLevel<Rules>` is immutable: rules id, schema 1, start,
  solution (at most 4,096 moves), uniqueness promise (`PuzzleUniqueness`: `.none`, `.goal` — exactly one solved state is
  reachable within the length bound — or `.solution` — the given solution is the only shortest one), a `FairnessBudget`
  and an optional generator seed; its `identity` is the SHA-256 hex (`StableHash`) of its canonical JSON (sorted keys,
  identity excluded). Decoding recomputes the identity and refuses a mismatch (`.edited`); a newer schema is refused.
  Impact: FR-R02F23-001, 007; SC-R02F23-001.
- Q: What does validation check, in what order, and what does it report? → A: `PuzzleValidator.certify(_:rules:)` checks
  in this order and stops at the first failure: the rules id matches; every solution move is legal (`illegalMove(index)`);
  the solution ends solved (`notSolved`); its length lies in the budget's bounds (`tooShort`, `tooLong`); then a
  breadth-first search from the start to the maximum length explores at most the node budget (`unproven` when exceeded),
  refuses any reached state with more moves than the branching bound (`tooBranching(count)`), refuses a shortest solution
  below the minimum length (`tooShort`), and checks the uniqueness promise (`notUnique`) by counting solved states (goal)
  or shortest paths capped at 2 (solution; the given solution must also
  be as short as the shortest, otherwise it is not the only shortest solution and the verdict is `notUnique`). States are
  counted as discovered, the start included. The `PuzzleCertificate` holds the verdict, the states explored, the shortest
  solution length, the solved states found (capped at 2) and the largest branching seen; it is `Equatable` and the same on
  every run. Impact: FR-R02F23-002…004, 006; SC-R02F23-002, 003.
- Q: What are the fairness budget's bounds, and how does the generator search? → A: `FairnessBudget` holds the minimum and
  maximum solution length (0 ≤ min ≤ max ≤ 4,096), the branching bound (1 … 1,024) and the node budget (1 … 1,000,000).
  `PuzzleGenerator.generate` takes a seed, an attempt budget (1 … 10,000), the rules, the budget, the promise and a
  candidate maker that turns a `SeededRandom` into a start and a solution (or nil); attempt i uses
  `SeededRandom(seed: SeedDerivation.derive(seed, index: i))`, and the first candidate that certifies becomes the level,
  whose `seed` is that attempt's derived seed, so the maker given `SeededRandom(seed: level.seed)` makes the same
  candidate again. The `PuzzleGeneration` reports the attempts used and the count of each rejection verdict;
  when every attempt fails it throws `.generationFailed(attempts)`. Impact: FR-R02F23-004, 005; SC-R02F23-004.
- Q: How are refusals named? → A: `PuzzleError` with codes `r2-f23.rules-id`, `r2-f23.solution-length`,
  `r2-f23.budget`, `r2-f23.attempts`, `r2-f23.generation-failed`, `r2-f23.newer-schema`, `r2-f23.malformed` and
  `r2-f23.edited`; verdicts are not errors but the certificate's answer. Impact: FR-R02F23-008.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A level that is what it says (Priority: P1) 🎯

An engineer writes a level as an immutable record — its start, its explicit solution and what it promises — with an
identity derived from its content; any change to the content changes the identity, and a damaged or edited record is
recognised.

**Why this priority**: every puzzle experience stores and ships levels.

**Independent Test**: a level's identity is stable across saves and devices and changes with any change of content; a
record whose identity does not match its content is refused.

**Acceptance Scenarios**:

1. **Given** a level, **When** it is saved and reopened, **Then** it is identical, identity included.
2. **Given** a saved level with one value changed, **When** it is opened, **Then** it is refused as damaged.

### User Story 2 - Certify a level (Priority: P1)

The engineer asks whether a level is valid: its solution must be legal move by move, end in a solved state and fit the
fairness budget; if the level promises uniqueness, no other solution may exist within the search bound. The answer is a
certificate that says which check failed and where.

**Independent Test**: seeded levels with planted faults (an illegal move, a solution that stops short, a second solution,
a solution beyond the budget) each fail with the right reason; sound levels pass, every time.

### User Story 3 - Generate from a seed (Priority: P2)

The engineer asks for a level from a seed; the generator tries candidates in a fixed order and returns only a certified
one, or reports that none was found within its attempt budget. The same seed always gives the same level.

**Independent Test**: two runs with the same seed give the identical level; every returned level certifies; an
impossible request reports failure after its budget.

### User Story 4 - Fairness (Priority: P2)

A level is fair when its intended solution is neither shorter nor longer than the bounds set for it, every state the
player can reach offers a bounded number of moves, and the search that proves it stays within its node budget.

**Independent Test**: levels outside each bound are refused with the bound named; levels inside pass.

### Edge Cases

- **A level already solved at the start:** its solution is empty, refused as too short unless the minimum length is 0.
- **A solution with a move the rules do not allow:** refused at that move's index.
- **A uniqueness search that runs out of budget:** refused as unproven, never as unique.
- **A generator that never finds a level:** reports failure with the attempts made.
- **Damaged, newer or edited records:** refused with a named reason.
- **Oversize levels or budgets:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F23-001**: Levels MUST be immutable records with a start, an explicit solution, a uniqueness promise and a
  content-derived identity that changes with any change of content.
- **FR-R02F23-002**: Validation MUST replay the solution move by move against the puzzle's rules and refuse illegal moves
  and solutions that do not end solved, naming the move.
- **FR-R02F23-003**: When a level promises uniqueness, validation MUST prove within a bounded search that no other
  solution exists, and refuse when one exists or the bound is reached.
- **FR-R02F23-004**: A fairness budget (solution length bounds, a branching bound, a search node budget) MUST be checked,
  naming the bound that fails.
- **FR-R02F23-005**: A generator MUST turn a seed into a certified level deterministically, or report failure after a
  bounded number of attempts.
- **FR-R02F23-006**: Validation MUST produce a certificate whose verdict and statistics are identical on every run.
- **FR-R02F23-007**: Levels MUST have a versioned stored form; newer, damaged and edited forms MUST be refused.
- **FR-R02F23-008**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F23-009**: Existing types (route solvers and certificates, the experience contract, `StableHash`) and their
  tests MUST be unchanged; every new public name carries documentation; the API baseline and the reference regression
  are updated.

### Key Entities

- **Puzzle rules**: the moves available in a state, the result of a move, whether a state is solved.
- **Level**: identity, schema, start, solution, uniqueness promise, fairness budget, generator seed if any.
- **Fairness budget**: solution length bounds, branching bound, node budget.
- **Certificate**: verdict, failing check and position, statistics (states explored, solutions found, shortest length).
- **Generator**: seed, attempt budget, candidate maker, the rules and budget it certifies against.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F23-001**: For 200 seeded levels, save and reopen gives identical levels and identities; changing any one
  value changes the identity; edited records are refused.
- **SC-R02F23-002**: For 200 seeded levels with one planted fault each (illegal move, short solution, second solution,
  too long, too short, too branching, budget exceeded), validation fails with exactly the planted reason; sound levels pass.
- **SC-R02F23-003**: Validation of the same level gives identical certificates on every run.
- **SC-R02F23-004**: For 100 seeds, two generator runs give identical levels and every generated level certifies; an
  impossible request fails after exactly its attempt budget.
- **SC-R02F23-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- Each puzzle experience supplies its own rules; this slice ships the contract, validation, uniqueness search, fairness
  checks, generator and stored form, proved on small puzzles written in the tests.
- No user interface: level select, hints, colours and layout belong to the consuming experiences.
- A candidate maker draws only from the generator it is given and keeps no state of its own, so a seed fully
  determines the candidates; levels are drawn in code by the consuming experiences on iPhone and iPad alike.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Immutable level schemas | FR-R02F23-001, 007 |
| Explicit solutions | FR-R02F23-002 |
| Uniqueness mode | FR-R02F23-003 |
| Fairness budget | FR-R02F23-004 |
| Deterministic validation | FR-R02F23-005, 006 |
| Observability | FR-R02F23-006, 008 |
| No Stage One breakage | FR-R02F23-009 |

## Negative Requirements / Excluded scope

- No new module, no change to the route solvers, the experience contract or `StableHash`, no level editor, no hint
  system, no network level sharing, no device run before ImplementationLock-100, no analytics.
