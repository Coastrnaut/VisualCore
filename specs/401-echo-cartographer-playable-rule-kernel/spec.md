# Feature Specification: R02-G11-01 — Echo Cartographer: playable rule kernel

**Feature Branch**: `401-echo-cartographer-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

**Ledger gate**: R02-G11-01 (migration ledger, game feature of experience R02-G11) · ID namespace FR-R02G1101-###,
SC-R02G1101-###, T-R02G1101-###

**Input**: User description: the archived R02-G11-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Echo Cartographer, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/401-echo-cartographer-playable-rule-kernel`; FR-R02G1101-###, SC-R02G1101-###,
  T-R02G1101-###.
- **Packaging (ADR-0009):** Echo Cartographer is experience R02-G11 (`r02-g11.echo-cartographer`, free) inside the single
  VisualCore app. The source's `Apps/EchoCartographer` and `Packages/GameModules/EchoCartographerCore` become the
  experience module `Packages/ExperiencesRound02/EchoCartographer`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G11 and its gate X-R02-G11.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 90 (the catalog's "90
  solver-certified stages") is produced in R02-G11-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic on a grid chamber, so every device decides the
  same; the catalog's 0.008333 s timestep is the presentation clock of later features and never decides a rule (echo
  delays are reported as whole ticks of it).
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G11-02 can certify levels).
- **Model:** feature 391 (Backwards Aurora's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Map a dark chamber by its echoes and find the beacons (Priority: P1) 🎯

A player stands in a dark chamber of which only the entry spot is known. Touching a known open spot emits a pulse: the
pulse runs out in straight lines, revealing the walls it strikes and the open floor it crosses, and the hidden beacons
answer with echoes whose delays tell how far each beacon is along the open floor. Pulsing from several spots, the player
narrows down where each beacon must be, marks candidate spots, and taps a spot to claim a beacon. When every beacon has
been claimed within the allowed tolerance, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of pulses and claims wins on its last action; after
every pulse the revealed cells, the echo distances and delays equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known actions, **When** they are applied, **Then** the level is won exactly on the claim
   that locates the last beacon.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - Run out of energy (Priority: P1)

Every pulse and every missed claim spends energy; when the energy is gone with beacons still hidden, the level fails and
the reason and the action are named.

**Independent Test**: scripted sequences end failed with the named reason on the exact action.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A pulse from a spot not known to be open:** refused without cost.
- **A claim on a known wall, outside the chamber, or where a beacon was already claimed:** refused without cost.
- **A claim exactly at the tolerance:** counts; one cell further is a miss.
- **Win on the last energy:** a claim that locates the last beacon wins even with no energy left.
- **A level already solved at load:** never generated; every level hides at least one beacon.
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1101-001**: A level MUST define the chamber (a grid of open and wall cells), the entry cell, the hidden
  beacons, the claim tolerance, the energy budget and the cost of a missed claim.
- **FR-R02G1101-002**: A pulse MUST be emitted from a cell known to be open and MUST reveal, along each of its straight
  rays, the open cells it crosses and the wall it strikes, and report each ray's travel distance and delay.
- **FR-R02G1101-003**: A pulse MUST report each beacon's echo: the shortest path length along open cells from the
  emitter to the beacon, and its delay, without saying which beacon answered.
- **FR-R02G1101-004**: A claim on a cell MUST locate a not-yet-located beacon within the tolerance, or else count as a
  miss and spend the miss cost.
- **FR-R02G1101-005**: The level MUST be won exactly on the action after which every beacon is located; it MUST fail with
  a named reason when the energy reaches zero with a beacon still hidden.
- **FR-R02G1101-006**: Every action MUST be validated (range, known cell, stage, previous fingerprint) and refused without
  change when invalid.
- **FR-R02G1101-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1101-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1101-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1101-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1101-011**: Invalid requests MUST be refused with stable reason codes `r02-g11.*`; existing modules unchanged.
- **FR-R02G1101-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1101-013**: Every cell, echo, marker and measure MUST be identifiable without colour vision: the kernel names
  them in words (cell position and what is known of it, each echo's distance, beacons located, energy left).
- **FR-R02G1101-014**: The truth metric MUST be computed exactly: ray travel distance agreement (every reported distance
  equals an independent computation) and beacon localization error (the distance between each claim and the beacon it
  located), reported after every action.

### Key Entities

- **Level**: chamber, entry, beacons, tolerance, energy budget, miss cost, tutorial flag, fingerprint.
- **Knowledge**: what the player has learned of each cell (unknown, open, wall).
- **Echo report**: the rays and beacon echoes of one pulse.
- **Action**: pulse, claim, mark, undo, redo.
- **Play**: stage, knowledge, markers, located beacons, energy, records, undo and redo stacks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1101-001**: For 500 seeded constructed levels the known actions win and every refused action is refused with
  its named reason.
- **SC-R02G1101-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1101-003**: Over 500 seeded levels and pulses, every revealed cell, ray distance, echo distance and delay
  equals an independent computation.
- **SC-R02G1101-004**: Energy failure happens on the exact action with the reason named, including one action either
  side of the budget and the claim tolerance boundary.
- **SC-R02G1101-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1101-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Raycast wave returns with path-length delay" is read as rays along the grid whose delay is proportional to their
  travel distance; "echoes based on static convex segments" as walls made of whole grid cells (unit squares).
- "Every beacon triangulated and tapped inside a spatial tolerance" is read as every beacon located by a claim within
  the level's tolerance; the triangulation is the player's reasoning from echoes taken at several spots.
- "Ray travel distance agreement and beacon localization error" is read as the exact truth metric of FR-R02G1101-014.
- Levels and their certification (grid chamber generator with connected-component and unique beacon inference proof)
  come in R02-G11-02; drawing in R02-G11-03; gestures (tap to emit, drag markers, orbit) in R02-G11-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (pulses, claims, energy) | FR-R02G1101-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (all beacons located; energy exhausted) | FR-R02G1101-005 |
| Truth metric: ray travel distance agreement and beacon localization error | FR-R02G1101-014; SC-R02G1101-003 |
| Puzzle contract for certification | FR-R02G1101-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G11-02; INV-11 is superseded by the free tier) | FR-R02G1101-012 |
| Accessibility (colour independence) | FR-R02G1101-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
