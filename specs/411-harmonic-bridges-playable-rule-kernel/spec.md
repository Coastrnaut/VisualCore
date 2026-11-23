# Feature Specification: R02-G12-01 — Harmonic Bridges: playable rule kernel

**Feature Branch**: `411-harmonic-bridges-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

**Ledger gate**: R02-G12-01 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1201-###,
SC-R02G1201-###, T-R02G1201-###

**Input**: User description: the archived R02-G12-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Harmonic Bridges, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/411-harmonic-bridges-playable-rule-kernel`; FR-R02G1201-###, SC-R02G1201-###,
  T-R02G1201-###.
- **Packaging (ADR-0009):** Harmonic Bridges is experience R02-G12 (`r02-g12.harmonic-bridges`, free) inside the single
  VisualCore app. The source's `Apps/HarmonicBridges` and `Packages/GameModules/HarmonicBridgesCore` become the
  experience module `Packages/ExperiencesRound02/HarmonicBridges`; this feature adds its pure Core with tests. Catalog
  registration, adapter and renderer come in later features of R02-G12 and its gate X-R02-G12.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 82 (the catalog's "82
  solver-certified stages") is produced in R02-G12-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic, so every device decides the same; the
  catalog's 0.008333 s timestep is the presentation clock of later features and never decides a rule. The law
  y(x,t) = Σ A_n sin(nπx/L) cos(ω_n t + φ_n) is evaluated only where it is exactly rational: at sample points where every
  squared sine is a whole number of quarters.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G12-02 can certify levels).
- **Model:** feature 401 (Echo Cartographer's rule kernel) for structure, stored form, records and refusals.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Tune strings until resonance forms a path of bridges (Priority: P1) 🎯

A player sees islands joined by suspended strings and a level's sounding tones. Turning a string's tuning peg changes
its pitch; when one of the string's harmonics matches a sounding tone, the string swells into a standing wave, and
where the wave's averaged swing is strong enough along the whole string the string becomes a walkable bridge. The
player plucks strings to hear what they would do, tunes them, and tests a crossing: if a path of bridges joins the
start island to the goal island through every step of the crossing window, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of tunings and a test wins on the test; after every
tuning the resonant harmonics, the averaged swing at every sample and the bridges equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known actions, **When** they are applied, **Then** the level is won exactly on the test.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - A bridge breaks during the crossing, or the moves run out (Priority: P1)

A test whose path breaks in some step of the crossing window fails the level, naming the step and the string that
broke; using up the action budget without a win fails it too.

**Independent Test**: scripted sequences end failed with the named reason on the exact action.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **A peg value outside its range, an unknown string or a locked string:** refused without cost.
- **A tuning that changes nothing (the peg already at that value):** refused as a no-op without cost.
- **An averaged swing exactly at the solidity threshold:** solid; one quarter below is not.
- **A harmonic that would lie above the highest allowed mode:** not resonant.
- **The last action of the budget:** a test on it can still win; any other last action without a win fails the level.
- **A level already solvable at load:** never generated; every level needs at least one tuning before a test can win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1201-001**: A level MUST define its islands, its strings (which islands each joins, its length, its peg value
  and whether it is locked), the start and goal islands, the tones of each step of the crossing window, the solidity
  threshold and the action budget.
- **FR-R02G1201-002**: A string's resonances MUST be computed exactly: the harmonics of the string that match a
  sounding tone of a step, up to the highest allowed mode.
- **FR-R02G1201-003**: The time-averaged swing of every string MUST be computed exactly at its sample points from its
  resonances, and a string MUST be a bridge in a step exactly when every sample's swing reaches the threshold.
- **FR-R02G1201-004**: A tuning MUST set one unlocked string's peg to a value in range and spend one action; a pluck MUST
  report a string's resonances and swing without changing anything.
- **FR-R02G1201-005**: A test MUST win exactly when the start and goal islands are joined by bridges in every step of
  the crossing window, and MUST fail naming the first step and a string where the joining path breaks otherwise; using
  up the budget without a win MUST fail with a named reason.
- **FR-R02G1201-006**: Every action MUST be validated (range, string, lock, stage, previous fingerprint) and refused
  without change when invalid.
- **FR-R02G1201-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1201-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1201-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1201-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1201-011**: Invalid requests MUST be refused with stable reason codes `r02-g12.*`; existing modules unchanged.
- **FR-R02G1201-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1201-013**: Every string, island, bridge and measure MUST be identifiable without colour vision: the kernel
  names them in words (string ends and peg, resonant harmonics, swing and bridge state per step, actions left).
- **FR-R02G1201-014**: The truth metric MUST be computed exactly: the mode amplitude envelope of every string at every
  sample and step, and the bridge graph's connectivity (which islands the start reaches in each step), reported after
  every action.

### Key Entities

- **Level**: islands, strings, start and goal, the crossing window's tones, threshold, budget, tutorial flag,
  fingerprint.
- **String**: two islands, length, peg value, locked flag.
- **Resonance report**: a string's matching harmonics and its swing per sample, per step.
- **Action**: tune, test, undo, redo (pluck is a query).
- **Play**: stage, peg values, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1201-001**: For 500 seeded constructed levels the known actions win and every refused action is refused with
  its named reason.
- **SC-R02G1201-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1201-003**: Over 500 seeded levels and tunings, every resonance, sample swing, bridge and reachable set equals
  an independent computation.
- **SC-R02G1201-004**: Failure happens on the exact action with the reason named, including one action either side of
  the budget and one quarter either side of the solidity threshold.
- **SC-R02G1201-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1201-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Solidity threshold from time-averaged envelope" is read as the mean square of the displacement over time, which for
  harmonics at distinct frequencies is the sum of each harmonic's mean square; it is exact at sample points where every
  squared sine is a whole number of quarters.
- "Start to goal reachability sustained for required window" is read as reachability in every step of the level's
  crossing window, each step having its own sounding tones; "bridge breaks during a crossing-window step" as a test
  whose path is missing in some step.
- "Mode amplitude envelope and bridge graph connectivity" is read as the exact truth metric of FR-R02G1201-014.
- Levels and their certification (discrete rational string-mode search with graph edge existence and reachability) come
  in R02-G12-02; drawing in R02-G12-03; gestures (pluck, drag peg, tap freeze) in R02-G12-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (tunings, tests, budget) | FR-R02G1201-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (reachability over the window; a break in a step) | FR-R02G1201-005 |
| Truth metric: mode amplitude envelope and bridge graph connectivity | FR-R02G1201-014; SC-R02G1201-003 |
| Puzzle contract for certification | FR-R02G1201-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G12-02; INV-11 is superseded by the free tier) | FR-R02G1201-012 |
| Accessibility (colour independence) | FR-R02G1201-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
