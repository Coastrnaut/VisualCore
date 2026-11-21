# Feature Specification: R02-G04-01 — Hue Compass: playable rule kernel

**Feature Branch**: `331-hue-compass-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G04-01 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0401-###,
SC-R02G0401-###, T-R02G0401-###

**Input**: User description: the archived R02-G04-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Hue Compass, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/331-hue-compass-playable-rule-kernel`; FR-R02G0401-###, SC-R02G0401-###,
  T-R02G0401-###.
- **Packaging (ADR-0009):** Hue Compass is experience R02-G04 (`r02-g04.hue-compass`, free) inside the single VisualCore
  app. The source's `Apps/HueCompass` and `Packages/GameModules/HueCompassCore` become the experience module
  `Packages/ExperiencesRound02/HueCompass`; this feature adds its pure Core with tests. Catalog registration, adapter and
  renderer come in later features of R02-G04 and its gate X-R02-G04.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the Round
  2 lock and per-round device campaign (ImplementationLock-100); the source's "content count 76" (the canonical catalog is
  the 100-level manifest, generated in R02-G04-02). **Device-only items:** none (pure logic). **Owner-only items:** none.
- **Exactness:** every kernel rule is decided in integers on a discrete compass wheel, so every device decides the same.
  The source's continuous rule hue = (atan2(y, x) + offset) / 2π is realised as an exact sector test on that wheel.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract, so
  R02-G04-02 can certify levels).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only, 2026-11-21): `Packages/ExperiencesRound02` holds Aurora Loom, Lissajous Labyrinth and Wave Knot Keeper
as the pattern (Core with level, play, records with previous and next fingerprints, rules as R02-F23 `PuzzleRules`,
`StableHash` fingerprints, `r02-gNN.*` reason codes); no `HueCompass*` name exists.

- Q: What exactly is the compass wheel and how is a direction's bearing decided? → A: the wheel has 96 bearings
  (0 … 95, counter-clockwise from +x) and 24 hue bands of 4 bearings each. Bearing k's sector is bounded by two fixed
  integer boundary vectors from a constant table (vector k at angle 2πk/96, components rounded once to multiples of
  1/65536 and stored as integer constants); a non-zero integer direction p is in sector k exactly when
  cross(boundary k, p) ≥ 0 and cross(boundary k+1, p) < 0, so each direction is in exactly one sector, decided in
  integers. The hue band of bearing b is (⌊b/4⌋ + offset) mod 24, the exact form of (atan2(y, x) + offset)/2π.
  Impact: FR-R02G0401-001, 002; SC-R02G0401-003.
- Q: What does a probe at bearing β return? → A: the hue gap, the circular distance between band(β) and band(τ) of the
  target τ, unsigned, 0 … 12 bands; and the fog depth, the sum of the fog densities (0 … 9 each) of the bearings strictly
  between β and τ along the shorter arc; when both arcs are equally long (48 apart), the counter-clockwise arc from β is
  used. The hue gap never reads fog and the depth never reads hue. Impact: FR-R02G0401-003, 011; SC-R02G0401-003.
- Q: What are the ranges of tolerances, allowance and actions, and when does a play end? → A: bearing tolerance 0 … 4
  bearings, band tolerance 0 … 2 bands (circular distances), allowance 2 … 24. A turn moves the bearing by −48 … 48
  non-zero steps (mod 96) and spends nothing. A probe spends one unit; a probe that spends the last unit records its
  clue and fails the level (`probes`). A selection (bearing 0 … 95, band 0 … 23) spends one unit and wins or fails
  (`selection`) at once. Impact: FR-R02G0401-003, 004; SC-R02G0401-001, 004.
- Q: What can be undone? → A: only turns. Undo and redo stacks hold turns; a probe or a selection clears both stacks
  (a clue once seen cannot be unseen). Impact: FR-R02G0401-006; SC-R02G0401-002.
- Q: How are records, fingerprints and stored forms defined? → A: as in R02-G03-01: every accepted turn, probe,
  selection, undo and redo appends a record (schema, level seed, tick, kind, operands, previous and next fingerprints);
  the play fingerprint is the SHA-256 of the schema, level fingerprint, bearing, units spent, clues and stage; levels
  are JSON schema 1 with sorted keys and a fingerprint (the target and offset included; 96 fog densities), re-checked on
  decode; reason codes `r02-g04.level`, `.action`, `.stage`, `.stale`, `.allowance`, `.newer-schema`, `.malformed`.
  Impact: FR-R02G0401-005 … 010; SC-R02G0401-002, 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find the hidden bearing (Priority: P1) 🎯

A player turns a spectral compass to a bearing and samples a clue there. Each clue tells how far, in hue bands, the
probed bearing is from the hidden target and how much fog lies between them. From the clues the player infers the
target and selects a bearing and a hue band; a selection inside both tolerances wins.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of probes and a correct selection wins; the clues
equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known solution, **When** the probes and the selection are applied, **Then** the level is
   won exactly at the selection.
2. **Given** any bearing, **When** it is probed, **Then** the clue (hue gap and fog depth) equals the independent
   brute-force value.

### User Story 2 - Miss or run out of probes (Priority: P1)

A selection outside either tolerance fails the level; spending the last of the allowance on a probe fails it too. The
reason is shown.

**Independent Test**: scripted plays end failed with the named reason.

### User Story 3 - Undo, redo and replay (Priority: P1)

Turning the compass can be undone and redone exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **Probing the target bearing itself:** the hue gap is 0 and the fog depth is 0.
- **Target diametrically opposite the probe:** both arcs are equally short; a fixed rule picks one, the same everywhere.
- **Wrap-around:** bearings and hue bands wrap around the wheel; distances are always the shorter way round.
- **Selection with the last unit of the allowance:** allowed; only a probe that spends the last unit fails.
- **A direction exactly on a sector boundary:** belongs to exactly one sector by a fixed rule.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0401-001**: A level MUST define the compass wheel (its bearings and hue bands), the hue offset, the fog
  density of every bearing, the hidden target bearing, the bearing tolerance, the hue-band tolerance and the allowance; its
  start bearing MUST NOT already lie within the bearing tolerance of the target.
- **FR-R02G0401-002**: The bearing of any integer direction MUST be decided exactly by a fixed sector rule on the wheel
  (the exact form of hue = (atan2(y, x) + offset) / 2π), each direction in exactly one sector.
- **FR-R02G0401-003**: Turning the compass MUST change the current bearing by whole steps around the wheel and spend
  nothing; a probe MUST return the clue at the current bearing (hue gap in bands, fog depth to the target) and spend one
  unit of the allowance.
- **FR-R02G0401-004**: A selection (bearing and hue band) MUST spend one unit; it MUST win exactly when the bearing is
  within the bearing tolerance and the band within the band tolerance of the target, and fail otherwise. A probe that
  spends the last unit MUST fail the level.
- **FR-R02G0401-005**: Every action MUST be validated (range, stage, previous fingerprint, allowance) and refused without
  change when invalid.
- **FR-R02G0401-006**: Undo and redo of compass turns MUST restore exact states and fingerprints; probes and selections
  are permanent; replaying a record trace MUST reproduce every state.
- **FR-R02G0401-007**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G0401-008**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G0401-009**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G0401-010**: Invalid requests MUST be refused with stable reason codes `r02-g04.*`; existing modules
  unchanged.
- **FR-R02G0401-011**: The clue's two parts MUST be independent: the hue gap never depends on fog, and the fog depth
  never depends on hue, so a player who cannot tell hues apart still has a full non-colour clue (luminance perceivable
  on its own).
- **FR-R02G0401-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save) MUST each have a named direct test and a seeded neighbouring-input check.

### Key Entities

- **Level**: wheel, offset, fog densities, target bearing, start bearing, tolerances, allowance, tutorial flag,
  fingerprint.
- **Action**: turn (steps), probe, selection (bearing, band), undo, redo.
- **Play**: stage, current bearing, allowance spent, clues, records, undo and redo stacks.
- **Clue**: probed bearing, hue gap, fog depth.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0401-001**: For 500 seeded constructed levels the known solution wins and every refused action is refused
  with its named reason.
- **SC-R02G0401-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  turn restores the exact earlier state.
- **SC-R02G0401-003**: The sector rule agrees with an independent angle computation on every direction of a 33 × 33
  lattice whose reference angle is more than 10⁻⁶ rad from every sector boundary, and clues equal a brute-force computation for every bearing of 500 seeded levels.
- **SC-R02G0401-004**: A wrong selection and a probe that spends the last unit fail with the reason named.
- **SC-R02G0401-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G0401-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- The wheel's colours, fog and glass are drawn later from the kernel's integers; the rules never use floating point.
- Levels and their certification come in R02-G04-02; drawing in R02-G04-03; gestures R02-G04-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition | FR-R02G0401-003, 005, 006, 007 |
| Exact win/failure evaluation | FR-R02G0401-004 |
| Hue rule (atan2 + offset) | FR-R02G0401-002 |
| Clues by hue difference and optical depth; luminance independent | FR-R02G0401-003, 011 |
| Puzzle contract for certification | FR-R02G0401-009 |
| Invariants INV-01 … INV-08 | FR-R02G0401-012 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no device run before ImplementationLock-100.
