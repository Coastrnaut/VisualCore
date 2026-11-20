# Feature Specification: R02-F23 — Puzzle contract, seed generation and solver certification

**Feature Branch**: `223-puzzle-contract-seed-generation-and-solver-certification` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

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

- **A level already solved at the start:** refused unless the fairness floor allows a zero-move solution.
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
