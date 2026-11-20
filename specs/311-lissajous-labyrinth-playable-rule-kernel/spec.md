# Feature Specification: R02-G02-01 — Lissajous Labyrinth: playable rule kernel

**Feature Branch**: `311-lissajous-labyrinth-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

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

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): `Packages/ExperiencesRound02` exists with Aurora Loom's Core (R02-G01-01) as the
pattern; no `LissajousLabyrinth*` name exists (the word "Lissajous" appears only in comments of OscilloscopeStudio and
curve tests); R02-F23's `PuzzleRules` and `StableHash` are available.

- Q: How is the tracer's path computed so the verdict is exact on every device? → A: integers. An angle is a count of
  1/4,096 of a turn; sine comes from a fixed table of 4,096 integers scaled to 1,024 (rounded 1,024 · sin(2πk/4,096),
  stored as source and pinned by a hash test), cosine is the sine a quarter turn later. One lap is 4,096 ticks of 1/240 s
  (the source's 0.004167 s). At tick n the tracer is x = A · S(a·n + 256·φ), y = B · S(b·n), z = C · S(c·n + 256·ψ +
  1,024), all angles modulo 4,096, with amplitudes A, B, C of 1 … 4, player frequencies a, b of 1 … 9 that must be
  coprime (ratios 1:1 … 9:8 and beyond), a level-fixed third frequency c of 1 … 9 and phases φ, ψ of 0 … 15 (sixteenths
  of a turn). With gcd(a, b) = 1 the path closes after exactly 4,096 ticks, the fundamental period. Rationale: the source
  asks for canonical quantized state; integers make every device agree bit for bit. Impact: FR-R02G0201-001, 002;
  SC-R02G0201-001.
- Q: When exactly is a lap won, and what counts as contact? → A: checkpoints (1 … 6, in order) and obstacles (0 … 8) are
  balls with integer centres (each coordinate −5,000 … 5,000) and radii 64 … 1,024. Scanning ticks 0 … 4,095, the next
  checkpoint is visited at the first tick whose sample lies inside or on it (squared distance ≤ r²); at most one checkpoint
  advances per tick. Contact is tested on every segment from sample n to sample n + 1 (the last segment closes the lap back
  to sample 0): the segment touches an obstacle when its closest point is strictly inside (squared distance < r²),
  computed exactly in integers. The lap is won when every checkpoint was visited in order and no segment touches an
  obstacle. Otherwise the verdict names the first contact (lowest tick, then lowest obstacle) or, without contact, the
  first checkpoint not reached. A level whose start already wins is refused. Impact: FR-R02G0201-002, 003; SC-R02G0201-001,
  004.
- Q: What is an action, and how do undo, redo and the allowance work? → A: an action sets one of four dials (`frequencyA`
  1 … 9, `frequencyB` 1 … 9, `phaseA` = φ 0 … 15, `phaseC` = ψ 0 … 15) to a new value; setting the current value is
  refused (`no-change`), a value out of range (`range`) and a frequency pair that is not coprime (`not-coprime`). The lap
  is evaluated after every accepted action, undo or redo. Each accepted action spends one of the level's allowance
  (1 … 64); spending the last one without a win fails the level with the verdict as its explanation. Undo restores the
  previous dials and refunds the action; redo re-applies it; a new action clears the redo stack. Every accepted action,
  undo and redo appends a record (schema, level seed, tick = record index, kind, dial, value, previous and next
  fingerprint); an action must name the current fingerprint as its previous one, else it is refused as `stale`.
  Impact: FR-R02G0201-004, 005; SC-R02G0201-002, 003.
- Q: What are the life stages, and what is a state's fingerprint? → A: `loading` → (`tutorial` when the level asks for
  one) → `playing` ↔ `paused` → `won` or `failed` → `result`, moved by `begin`, `dismissTutorial`, `pause`, `resume` and
  `showResult`; any other event in a stage is refused (`stage`). Actions, undo and redo are accepted only while
  `playing`. The fingerprint of a state is the SHA-256 hex (`StableHash`) of a fixed byte layout: schema, the level
  fingerprint, the four dials, the actions spent and the stage. Impact: FR-R02G0201-004, 006; SC-R02G0201-003.
- Q: How are levels stored and refusals named, and how do the rules meet the puzzle contract? → A:
  `LissajousLabyrinthLevel` is `Codable` JSON schema 1 with sorted keys and a fingerprint (SHA-256 hex of its canonical
  JSON); decoding re-checks every rule and the fingerprint; newer schemas are refused. `LissajousLabyrinthRules` conforms
  to `PuzzleRules` (state: the four dials; moves: every single-dial change in dial order, values ascending, skipping the
  current value and non-coprime pairs; solved: the lap verdict is won). Reason codes (`LissajousLabyrinthError`):
  `r02-g02.level`, `r02-g02.move`, `r02-g02.stage`, `r02-g02.stale`, `r02-g02.allowance`, `r02-g02.newer-schema`,
  `r02-g02.malformed`. Every type carries the `LissajousLabyrinth` prefix. Impact: FR-R02G0201-007, 008, 009;
  SC-R02G0201-005.

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
- **An action after the allowance is spent or after the end:** refused. Spending the last action always ends the level
  (won or failed), so a further action is refused as `stage`; the `allowance` code remains as a guard (implementation,
  2026-11-20).
- **A stale action** (its claimed previous fingerprint is not the current one): refused.
- **A level already won at the start:** refused as a level.
- **A tracer exactly on a checkpoint's or obstacle's boundary:** a sample on a checkpoint's surface visits it; a segment
  whose closest point lies exactly on an obstacle's surface does not touch it; both are tested at the boundary and one
  unit either side.
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

- **Level**: id, seed, band, amplitudes, third-axis frequency, start dials, checkpoints (centre, radius) in
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
- Layout on iPhone and iPad, VoiceOver and the accessible stepper controls for the four dials belong to R02-G02-04 and
  -06, which drive the kernel through the same actions; the sine table is computed by the project, not copied.

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
