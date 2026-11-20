# Feature Specification: R02-G02-01 — Lissajous Labyrinth: playable rule kernel

**Feature Branch**: `311-lissajous-labyrinth-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

**Ledger gate**: R02-G02-01 (migration ledger, game feature of experience R02-G02) · ID namespace FR-R02G0201-###,
SC-R02G0201-###, T-R02G0201-###

**Input**: User description: the archived R02-G02-01 `/speckit-specify` prompt (round2.md line 3389), verbatim in the
invocation: "Implement deterministic state transition and exact win/failure evaluation" for Lissajous Labyrinth, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/311-lissajous-labyrinth-playable-rule-kernel`; FR-R02G0201-###, SC-R02G0201-###,
  T-R02G0201-###.
- **Packaging (ADR-0009):** Lissajous Labyrinth is experience R02-G02 (`r02-g02.lissajous-labyrinth`, free) inside the
  single VisualCore app. No app target, bundle identifier, scheme or store listing. The source's `Apps/LissajousLabyrinth`
  and `Packages/GameModules/LissajousLabyrinthCore` become the experience module
  `Packages/ExperiencesRound02/LissajousLabyrinth` (section 16) in the package R02-G01-01 created; this feature adds its
  pure Core with tests. Catalog registration, adapter and renderer come in later features of R02-G02 and its gate
  X-R02-G02.
- **Superseded parts of the source prompt:** the USD 2.99 upfront price and "no IAP" (free under the shared purchase
  controller); the Round 2 lock and per-round device campaign (ImplementationLock-100); the source's "content count 90"
  (the canonical catalog is the 100-level manifest, generated in R02-G02-02). **Device-only items:** none (pure logic).
  **Owner-only items:** none.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a `PuzzleRules`, so
  R02-G02-02 can certify levels); the other listed prerequisites are delivered by unified-app features or concern later
  features of this game.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tune the tracer through every checkpoint (Priority: P1) 🎯

A player turns the frequency and phase dials of a moving point; its closed three-dimensional path must pass every
illuminated checkpoint in order during one complete lap without touching an obstacle. When it does, the level is won.

**Why this priority**: this is the game; without an exact, trustworthy win test nothing else matters.

**Independent Test**: seeded levels built with a known safe setting are won by that setting and judged identically by an
independent reference evaluation for nearby settings.

**Acceptance Scenarios**:

1. **Given** a level and its safe setting, **When** the dials are set to it, **Then** the level is won.
2. **Given** a setting whose lap touches an obstacle, **When** it is evaluated, **Then** it does not win and the first
   contact (obstacle and tick) is named.
3. **Given** a setting that visits the checkpoints out of order or misses one, **When** it is evaluated, **Then** it does
   not win and the first missing checkpoint is named.

### User Story 2 - Run out of actions (Priority: P1)

Each dial change spends one action from the level's allowance; when the last action is spent without a win, the level is
failed with an honest explanation of what went wrong.

**Independent Test**: spending the allowance on losing settings fails the level with the cause named.

### User Story 3 - Undo, redo and replay (Priority: P1)

A player can undo and redo dial changes; a recorded trace of actions replays to the same states and outcome everywhere.

**Independent Test**: seeded traces replay to identical fingerprints; undo restores every earlier state exactly.

### User Story 4 - Pause and the life of a level (Priority: P2)

A level loads, may show a tutorial, is played, can be paused and resumed, ends won or failed and shows its result;
actions are refused where the life stage forbids them.

**Independent Test**: every event in every stage is accepted or refused as the stage table says.

### User Story 5 - Levels that can be stored (Priority: P2)

Levels have a versioned stored form with a fingerprint, so later features can ship and load them safely.

**Independent Test**: levels round-trip byte for byte; damaged, edited and newer forms are refused.

### Edge Cases

- **A dial set out of range, to its current value, or to a frequency pair that is not coprime:** refused, state unchanged.
- **An action after the allowance is spent or after the end:** refused.
- **A stale action** (its claimed previous fingerprint is not the current one): refused.
- **A level already won at the start:** refused as a level.
- **A tracer exactly on a checkpoint's or obstacle's boundary:** defined inclusively for checkpoints (visited) and
  exclusively for obstacles (contact only strictly inside), and tested at the boundary and one unit either side.
- **The lap's closing segment** (last sample back to the first): checked for contact like every other segment.
- **Damaged, newer or inconsistent stored levels:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0201-001**: A level MUST define the tracer's three amplitudes and third-axis frequency, the two player
  frequencies and two phases at the start, ordered checkpoints, obstacles, an action allowance and a band, and MUST be
  refused when invalid.
- **FR-R02G0201-002**: The tracer's closed path MUST be evaluated exactly (the same on every device) over one complete
  fundamental period sampled at a fixed tick, with contact tested on every segment between consecutive samples.
- **FR-R02G0201-003**: The level MUST be won exactly when the lap visits every checkpoint in order and never touches an
  obstacle, and failed exactly when the allowance is spent without that; the failure MUST name the first contact or the
  first missing checkpoint.
- **FR-R02G0201-004**: Every action MUST be validated (range, coprime frequencies, allowance, life stage, previous
  fingerprint) and recorded as an append-only record with the previous and next state fingerprints; invalid actions MUST
  be refused without change.
- **FR-R02G0201-005**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every fingerprint and the outcome.
- **FR-R02G0201-006**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result), refusing actions where the machine forbids them.
- **FR-R02G0201-007**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST be
  refused.
- **FR-R02G0201-008**: The rules MUST be expressible as a puzzle contract (R02-F23) so later features can certify levels.
- **FR-R02G0201-009**: Invalid requests MUST be refused with stable reason codes naming the experience; existing modules
  and experiences MUST be unchanged; every new public name carries documentation; the reference regression passes.
- **FR-R02G0201-010**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save) MUST each have a named boundary test with a seeded neighbouring-input check.

### Key Entities

- **Level**: id, seed, band, amplitudes, third-axis frequency and phase, start dials, checkpoints (centre, radius) in
  order, obstacles (centre, radius), action allowance, tutorial flag, fingerprint.
- **Dials**: two frequencies and two phases.
- **Action**: which dial and its new value.
- **Action record**: schema, level seed, tick, kind, dial, value, previous and next fingerprints.
- **Lap verdict**: won, or the first contact (obstacle, tick) or first missing checkpoint.
- **Play state**: life stage, dials, actions spent, records, undo and redo stacks, outcome and its explanation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0201-001**: For 500 seeded levels a constructed safe setting wins; for every single-dial change from it on the
  first 50 of them the verdict agrees with an independent reference evaluation written in the test; boundary samples are
  judged as the edge cases state.
- **SC-R02G0201-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state and fingerprint.
- **SC-R02G0201-003**: Every refused action (out of range, not coprime, over allowance, wrong stage, stale) leaves the
  state and fingerprint unchanged, for 1,000 seeded attempts.
- **SC-R02G0201-004**: Spending the allowance without winning fails with the first contact or missing checkpoint named,
  in every seeded case.
- **SC-R02G0201-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0201-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds; the eight named invariant tests pass.

## Assumptions

- The kernel is pure logic; drawing, dials, gestures, camera, sound and VoiceOver come in later features of this game
  (R02-G02-03 … 07), which consume the kernel's immutable snapshots; the viewpoint never changes the verdict.
- The 100 catalog levels and their witnesses are generated in R02-G02-02; this feature proves the rules on seeded levels
  built in tests.
- Visuals are code only, no network; the design is the project's own archived round-two design.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition | FR-R02G0201-004, 005, 006 |
| Exact win evaluation (checkpoints in order over a lap) | FR-R02G0201-002, 003 |
| Exact failure evaluation (obstacle contact, allowance) | FR-R02G0201-003 |
| Frequency ratios and phases | FR-R02G0201-001, 004 |
| Schema migration | FR-R02G0201-007 |
| Solver-ready rules | FR-R02G0201-008 |
| Invariants INV-01 … INV-05, INV-07 … INV-09 | FR-R02G0201-010 |
| INV-06 content, INV-10 renderer purity, INV-12 novelty | later features R02-G02-02, -03 and the gate X-R02-G02 |
| INV-11 monetization | superseded: the experience is free (ADR-0009) |
| No Stage One breakage | FR-R02G0201-009 |

## Negative Requirements / Excluded scope

- No app target or scheme, no catalog registration yet, no rendering, gestures, audio, persistence of progress, level
  generator or solver (later features), no device run before ImplementationLock-100, no analytics, no network.
