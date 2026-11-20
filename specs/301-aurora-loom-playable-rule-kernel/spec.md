# Feature Specification: R02-G01-01 — Aurora Loom: playable rule kernel

**Feature Branch**: `301-aurora-loom-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-01 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0101-###,
SC-R02G0101-###, T-R02G0101-###

**Input**: User description: the archived R02-G01-01 `/speckit-specify` prompt (round2.md line 2296), verbatim in the
invocation: "Implement deterministic state transition and exact win/failure evaluation" for Aurora Loom, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/301-aurora-loom-playable-rule-kernel`; FR-R02G0101-###, SC-R02G0101-###,
  T-R02G0101-###.
- **Packaging (ADR-0009):** Aurora Loom is experience R02-G01 (`r02-g01.aurora-loom`, free) inside the single VisualCore
  app. No app target, bundle identifier, scheme or store listing. The source's `Apps/AuroraLoom` and
  `Packages/GameModules/AuroraLoomCore` become the experience module `Packages/ExperiencesRound02/AuroraLoom` (section 16);
  this feature creates the package and its pure Core with tests. Registration in the catalog, the experience adapter and
  the renderer come in later features of R02-G01 (02–09) and its integration gate X-R02-G01.
- **Superseded parts of the source prompt:** the USD 2.99 upfront price and "no IAP" (the experience is free under the
  shared purchase controller); the Round 2 lock and per-round device campaign (ImplementationLock-100). **Device-only
  items:** none in this feature (the kernel is pure logic). **Owner-only items:** none.
- **Shared features used:** R02-F03 (numbers), R02-F23 (puzzle contract: the kernel's rules are a `PuzzleRules`, so the
  generator and solver of R02-G01-02 can certify levels); the other prerequisites listed by the source are delivered by
  unified-app features or concern later features of this game.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): no `Packages/ExperiencesRound02` exists yet; experience modules follow the
`<Name>/Core`, `CoreTests`, `Experience`, `ExperienceTests` layout of `Packages/ExperiencesCreative`; the existing A18
experience is named "Aurora" (`AuroraExperience`), so every Aurora Loom type carries the `AuroraLoom` prefix; R02-F23's
`PuzzleRules` and `StableHash` are available; no `AuroraLoom*` name exists.

- Q: How are phases represented so evaluation is exact on every device? → A: integers. A phase is a count of 1/4,096 of a
  turn, taken modulo 4,096. Gate positions are sixteenths of the ribbon (1 … 15, four distinct). Wave step i (0 … 15)
  adds i · s · 16 units at a gate at s sixteenths; phase step j (0 … 15) adds j · 256 units; a ribbon turns ω units per
  tick (0 … 256) and the target harmony at gate g is Θ_g + Ω · n at tick n (Θ_g 0 … 4,095; Ω a power of two 1 … 256, so
  one period is P = 4,096 / Ω ticks of 1/120 s). The residual is the signed wrap of (ribbon phase − target) into
  −2,048 … 2,047; tolerance is 1 … 512 units. Rationale: the source asks for canonical quantized state; integers make
  every device agree bit for bit. Impact: FR-R02G0101-001, 002; SC-R02G0101-001.
- Q: When exactly is a level won or failed? → A: after every accepted move, undo or redo the kernel evaluates ticks
  n = 0 … 2P − 1 for all three ribbons and four gates; the level is won when every |residual| ≤ tolerance (inclusive).
  It fails when a move spends the last of the allowance (1 … 64 moves) and the level is not won; the failure names the
  ribbon, gate and tick with the largest |residual| (ties: lowest ribbon, then gate, then tick). A level whose start
  already wins is refused. Impact: FR-R02G0101-002, 003; SC-R02G0101-001, 004.
- Q: What is a move, and how do undo and redo count against the allowance? → A: a move sets one control of one ribbon
  to a new step (`wave` or `phase`, 0 … 15); setting the current value is refused (`no-change`). Every accepted move,
  undo and redo appends a record (schema, level seed, tick = record index, kind, ribbon, control, step, previous and
  next fingerprint). Undo restores the previous controls and refunds the move; redo re-applies it; a new move clears the
  redo stack. A move must name the current fingerprint as its previous one, else it is refused as `stale`. Impact:
  FR-R02G0101-004, 005; SC-R02G0101-002, 003.
- Q: What are the life stages and which actions does each allow? → A: `loading` → (`tutorial` when the level asks for
  one) → `playing` ↔ `paused` → `won` or `failed` → `result`; events `begin`, `dismissTutorial`, `pause`, `resume` and
  `showResult` move between them, any other event in a stage is refused (`stage`). Moves, undo and redo are accepted only
  while `playing`; the kernel never changes the outcome by itself. The fingerprint of a state is the SHA-256 hex
  (`StableHash`) of a fixed byte layout: schema, the level fingerprint, the six control steps, the moves spent and the
  stage. Impact: FR-R02G0101-004, 006; SC-R02G0101-003.
- Q: How are levels stored and refusals named, and how do the rules meet the puzzle contract? → A: `AuroraLoomLevel` is
  `Codable` JSON schema 1 with sorted keys and a fingerprint (SHA-256 hex of its canonical JSON); decoding re-checks every
  rule and the fingerprint; newer schemas are refused. `AuroraLoomRules` conforms to `PuzzleRules` (state: the six control
  steps; moves: every single-control change, in ribbon, control, step order; solved: the win test). Reason codes
  (`AuroraLoomError`): `r02-g01.level`, `r02-g01.move`, `r02-g01.stage`, `r02-g01.stale`, `r02-g01.allowance`,
  `r02-g01.newer-schema`, `r02-g01.malformed`. Impact: FR-R02G0101-007, 008, 009; SC-R02G0101-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Make three ribbons agree (Priority: P1) 🎯

A player turns ribbons' wave and phase controls, each in sixteen steady steps; the game tells, exactly and the same way
every time, whether all three ribbons now meet the target harmony at all four gates for two full periods, and declares
the level won the moment they do.

**Why this priority**: it is the game.

**Independent Test**: from a level's start, a known winning sequence of control changes wins, and a sequence that leaves
one gate off target does not.

**Acceptance Scenarios**:

1. **Given** a level, **When** the controls are set so every gate sample stays within tolerance for two periods, **Then**
   the level is won.
2. **Given** a level, **When** one ribbon is one step off at one gate beyond tolerance, **Then** the level is not won.

### User Story 2 - Run out of moves (Priority: P1)

A player who uses the whole move allowance without reaching the harmony sees the level fail, with an explanation of which
gate and ribbon were furthest off — never a hidden automatic solution.

**Independent Test**: spending the allowance without a win fails the level and reports the largest mismatch.

### User Story 3 - Undo, redo and replay (Priority: P1)

A player undoes and redoes moves freely before the level ends; a recorded sequence of moves replays to exactly the same
states, outcome and fingerprints on every device.

**Independent Test**: undo restores the exact previous state and fingerprint; replaying a recorded trace reproduces every
fingerprint.

### User Story 4 - Pause and the life of a level (Priority: P2)

The level moves through loading, tutorial, playing, paused, won or failed and result; moves made while paused or after the
end are refused, and the game never changes the outcome by itself.

**Independent Test**: every move in a state that forbids it is refused with a reason, and the state is unchanged.

### User Story 5 - Levels that can be stored (Priority: P2)

A level is stored with a schema version and a fingerprint; damaged or newer records are refused, never half-loaded.

**Independent Test**: levels round-trip exactly; damaged and newer records are refused.

### Edge Cases

- **A move out of range** (no such ribbon, a step outside 0 … 15): refused, state unchanged.
- **A move after the allowance is spent or after the end:** refused.
- **A stale move** (its claimed previous fingerprint does not match): refused.
- **A level already in harmony at the start:** refused as a level, so no level can be won without a move.
- **Gate samples exactly on the tolerance boundary:** inside (won); one unit beyond: outside.
- **Damaged, newer or inconsistent stored levels:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0101-001**: A level MUST define three ribbons with sixteen-step wave and phase controls, four gates, a target
  harmony, a tolerance, a move allowance and a start, and MUST be refused when invalid.
- **FR-R02G0101-002**: Ribbon phases at the gates MUST be evaluated exactly (the same on every device) over two complete
  periods sampled at the fixed step of 1/120 second.
- **FR-R02G0101-003**: The level MUST be won exactly when every gate sample of every ribbon stays within tolerance for the
  two periods, and failed exactly when the allowance is spent without that; the failure MUST name the furthest-off gate
  and ribbon.
- **FR-R02G0101-004**: Every move MUST be validated (range, allowance, state, previous fingerprint) and recorded as an
  append-only record with the previous and next state fingerprints; invalid moves MUST be refused without change.
- **FR-R02G0101-005**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every fingerprint and the outcome.
- **FR-R02G0101-006**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result), refusing moves where the machine forbids them.
- **FR-R02G0101-007**: Levels MUST have a versioned stored form with a fingerprint; damaged and newer forms MUST be refused.
- **FR-R02G0101-008**: The rules MUST be expressible as a puzzle contract (R02-F23) so later features can certify levels.
- **FR-R02G0101-009**: Invalid requests MUST be refused with stable reason codes naming the experience; existing modules
  and experiences MUST be unchanged; every new public name carries documentation; the reference regression passes.

### Key Entities

- **Level**: id, seed, band, three ribbons' start controls and angular speed, four gate positions, target harmony per
  gate, tolerance, move allowance.
- **Ribbon controls**: wave step and phase step, each 0 … 15.
- **Move**: ribbon, control (wave or phase), new step.
- **Move record**: schema, level seed, tick, ribbon, control, step, previous and next fingerprints.
- **Play state**: life stage, controls, moves spent, records, undo and redo stacks, outcome and its explanation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0101-001**: For 1,000 seeded levels, a constructed winning control setting wins and every setting one step away
  at any single control that breaks a gate does not; boundary samples at exactly the tolerance are inside, one unit
  beyond outside.
- **SC-R02G0101-002**: For 500 seeded move traces, replay reproduces every fingerprint and the outcome; undo of every move
  restores the exact earlier state and fingerprint.
- **SC-R02G0101-003**: Every refused move (out of range, over allowance, wrong state, stale fingerprint) leaves the state
  and fingerprint unchanged, for 1,000 seeded attempts.
- **SC-R02G0101-004**: Spending the allowance without winning fails with the furthest-off gate and ribbon named, in every
  seeded case.
- **SC-R02G0101-005**: Levels round-trip exactly; damaged and newer forms are refused.
- **SC-R02G0101-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- The kernel is pure logic; drawing, gestures, camera, sound and VoiceOver presentation come in later features of this
  game, which consume the kernel's immutable snapshots.
- The 100 catalog levels and their solver witnesses are generated in R02-G01-02; this feature proves the rules on seeded
  levels built in tests.
- Visuals are code only and the game makes no network request; nothing here draws. Layout on iPhone and iPad, VoiceOver and
  the accessible stepper controls belong to R02-G01-04 and -06, which drive the kernel through the same moves.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition | FR-R02G0101-004, 005, 006 |
| Exact win evaluation (two periods, four gates) | FR-R02G0101-002, 003 |
| Exact failure evaluation (move allowance) | FR-R02G0101-003 |
| Sixteen-step controls | FR-R02G0101-001 |
| Schema migration | FR-R02G0101-007 |
| Solver-ready rules | FR-R02G0101-008 |
| Invariants INV-01 … INV-05, INV-07 … INV-09 | FR-R02G0101-001 … 007 |
| INV-06 content witnesses, INV-10 renderer purity, INV-12 novelty | later features R02-G01-02, -03 and the gate X-R02-G01 |
| INV-11 monetization | superseded: the experience is free (ADR-0009) |
| No Stage One breakage | FR-R02G0101-009 |

## Negative Requirements / Excluded scope

- No app target or scheme, no catalog registration yet, no rendering, gestures, audio, persistence of progress, level
  generator or solver (later features), no device run before ImplementationLock-100, no analytics, no network.
