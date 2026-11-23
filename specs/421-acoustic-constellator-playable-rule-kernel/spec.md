# Feature Specification: R02-G13-01 — Acoustic Constellator: playable rule kernel

**Feature Branch**: `421-acoustic-constellator-playable-rule-kernel` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G13-01 (migration ledger, game feature of experience R02-G13) · ID namespace FR-R02G1301-###,
SC-R02G1301-###, T-R02G1301-###

**Input**: User description: the archived R02-G13-01 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement deterministic state transition and exact win/failure evaluation" for Acoustic Constellator, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/421-acoustic-constellator-playable-rule-kernel`; FR-R02G1301-###,
  SC-R02G1301-###, T-R02G1301-###.
- **Packaging (ADR-0009):** Acoustic Constellator is experience R02-G13 (`r02-g13.acoustic-constellator`, free) inside
  the single VisualCore app. The source's `Apps/AcousticConstellator` and `Packages/GameModules/AcousticConstellatorCore`
  become the experience module `Packages/ExperiencesRound02/AcousticConstellator`; this feature adds its pure Core with
  tests. Catalog registration, adapter and renderer come in later features of R02-G13 and its gate X-R02-G13.
- **Superseded parts of the source prompt:** the price and "no IAP" (free under the shared purchase controller); the
  Round 2 lock and per-round device campaign (ImplementationLock-100). The content count 85 (the catalog's "85
  solver-certified stages") is produced in R02-G13-02. **Device-only items:** none (pure logic). **Owner-only items:**
  none.
- **Exactness:** every kernel rule is decided in exact integer arithmetic, so every device decides the same; the
  catalog's 0.008333 s timestep is the presentation clock of later features and never decides a rule. The law
  phase_i += ω_i·dt + K Σ sin(phase_j − phase_i)·dt is applied on a whole-number phase clock with a whole-number
  coupling table, and spectral phase coherence (the Kuramoto order parameter) is compared with its threshold exactly.
- **Shared features used:** R02-F03 (numbers) and R02-F23 (puzzle contract: the kernel's rules are a puzzle contract,
  so R02-G13-02 can certify levels).
- **Model:** feature 411 (Harmonic Bridges's rule kernel) for structure, stored form, records and refusals.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
411's answers where the games agree. Facts checked in code (read-only, 2026-11-23): `Packages/ExperiencesRound02` holds
Aurora Loom … Harmonic Bridges as the pattern (Core with level, play, records with previous and next fingerprints, rules
as R02-F23 `PuzzleRules`, `StableHash` fingerprints, `r02-gNN.*` reason codes); no `AcousticConstellator*` name exists;
the catalog sets the timestep at 0.008333 s, the content at 85 stages, the controls "drag links between 3D stars, tap a
node to phase nudge, orbit to inspect", the law phase_i += ω_i·dt + K Σ sin(phase_j − phase_i)·dt and the truth metric
"Kuramoto order parameter and graph-isomorphism labeling". Checked by computation (2026-11-23): on a 12-step clock,
|Σ e^{iπφ/6}|² equals A + B√3 with A = n + Σ_{i<j} a(gap) and B = Σ_{i<j} b(gap), where (a, b) for gaps 0 … 6 is (2, 0),
(0, 1), (1, 0), (0, 0), (−1, 0), (0, −1), (−2, 0) (20,000 random phase sets, largest difference 2·10⁻¹⁴); the coupling
table s(0 … 6) = 0, 1, 2, 2, 2, 1, 0 is 2·sin(πd/6) rounded to whole numbers; over 400 random spanning-tree constellations
of 3 … 7 stars with rates 0 … 1 a coupling step clamped to ±1 per tick reaches a hold of 8 ticks at R² ≥ 3/4 in 58 % of
cases, against 20 % or less for an unclamped step, which overshoots and oscillates.

- Q: What are the stars, the links and the target symbol, exactly? → A: a level has 3 … 8 stars (index 0 … n − 1),
  each with a natural rate ω in 0 … 11 phase steps per tick, a starting phase φ₀ in 0 … 11 and a drawing position on a
  12 × 12 × 12 grid that never decides a rule; 0 … 6 fixed links (pairs of distinct stars that the player cannot
  remove); a target symbol of 2 … 10 distinct star pairs whose graph is connected (its stars are the symbol's stars); a
  coupling strength K in 1 … 8; a degree limit D in 2 … 4 (links per star, fixed links included); a link limit E (the
  number of links at once, fixed included) at least the symbol's size and at most 16; a snap limit σ in 2 … 5 phase
  steps; a coherence threshold θ in 1 … n² (compared with n²R²); a hold H in 2 … 12 ticks; a window W in H … 48 ticks;
  an action budget of 1 … 40. A level whose fixed links break a limit is refused. Impact: FR-R02G1301-001; SC-R02G1301-001.
- Q: How does a phase advance in one tick, exactly? → A: phases live on a 12-step clock (0 … 11, arithmetic modulo 12);
  the signed gap from star i to star j is d = φⱼ − φᵢ reduced to −5 … 6; the coupling table is s(d) = sign(d) ·
  t(|d|) with t(0 … 6) = 0, 1, 2, 2, 2, 1, 0; star i's pull is P = Σ s(d) over its current links; its coupling step is
  c = ⌊K · P / 4⌋ (rounded toward minus infinity) clamped to −1 … 1; all stars then move at once to
  (φᵢ + ωᵢ + c) mod 12, every pull being computed from the phases before the tick. Impact: FR-R02G1301-002;
  SC-R02G1301-003.
- Q: Which actions exist, what does each cost, and when is one refused? → A: `link(a, b)` adds a link between two
  distinct stars and spends 1 action; `unlink(a, b)` removes a link the player made and spends 1; `nudge(i, δ)` with δ
  = +1 or −1 shifts star i's starting phase by one step (mod 12) and spends 1; `listen` spends 1 and decides the level.
  Refused without change: an unknown star, a link from a star to itself, a link that exists, a link that would take a
  star above D or the links above E, removing a missing or fixed link, a nudge step other than ±1 (`r02-g13.action`); a
  wrong stage (`r02-g13.stage`) or a stale fingerprint (`r02-g13.stale`). Undo and redo spend nothing; a new action
  clears the redo stack. The life of a level is loading → tutorial (when the level has one) → playing ⇄ paused → won or
  failed → result, entered by `begin`, `dismissTutorial`, `pause`, `resume` and `showResult`. Impact: FR-R02G1301-004,
  006, 008, 011.
- Q: In which order does a listen decide, and what is reported? → A: a listen first checks that every symbol pair is
  linked (else it fails `missing`, naming the lowest-index missing pair); it then runs ticks 1 … W from the starting
  phases with the current links: each tick moves all phases (as above), then snaps every link whose gap |d| exceeds σ
  (all such links at once, for the rest of this listen only), then fails `disconnected` (naming the tick and the
  lowest-index link snapped in it) if the remaining links no longer join all of the symbol's stars, then counts the tick
  as coherent when every symbol pair is still linked and A + B√3 ≥ θ (decided exactly: with D′ = θ − A, true when
  B ≥ 0 and (D′ ≤ 0 or 3B² ≥ D′²), or B < 0 and D′ ≤ 0 and D′² ≥ 3B²). H consecutive coherent ticks win the level on
  that tick; if the window ends first the listen fails `incoherent`, reporting the longest coherent run. After any other
  accepted action, a budget fully spent without a win fails the level (`budget`). Undo and redo restore the exact
  earlier state; undo works in playing and paused; from failed, undo returns to playing (an honest retry, recorded); a
  won level is final and refuses undo. The truth metric is reported after every action: a listen of the current state
  (the phases at every tick, the links snapped per tick, A and B per tick, the coherent runs and the outcome it would
  give) and the graph-isomorphism label of the player's link graph (the lexicographically smallest adjacency string
  over all orderings of the stars) with whether it equals the label of the target symbol's graph; the metric never
  decides the outcome by itself. Impact: FR-R02G1301-003, 005, 007, 008, 014; SC-R02G1301-002, 003, 004.
- Q: How are records, fingerprints and stored forms defined? → A: as in R02-G12-01: every accepted action appends a
  record (schema, level seed, action index, kind, stars, step, previous and next fingerprints); the play fingerprint is
  the SHA-256 of the schema, the level fingerprint, the links, the starting phases, the actions spent, the stage and the
  failure; levels are JSON schema 1 with sorted keys (stars as [x, y, z, ω, φ₀], fixed links and symbol as pairs, K, D,
  E, σ, θ, H, W, budget, tutorial flag, seed, id) and a fingerprint, re-checked on decode; a level with a repeated or
  self pair, a disconnected symbol, fixed links over a limit, or values out of range is refused; reason codes
  `r02-g13.level`, `.action`, `.stage`, `.stale`, `.newer-schema`, `.malformed`. Impact: FR-R02G1301-006 … 011;
  SC-R02G1301-002, 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Link drifting stars until they sing in one phase as the target symbol (Priority: P1) 🎯

A player sees drifting musical stars, each pulsing at its own natural rate, and a target celestial symbol drawn as a
set of star pairs. Linking two stars couples them, pulling their phases together; nudging a star shifts its phase. The
player links the symbol's pairs (and any helping links the star degree limits allow) and listens: if every link of the
symbol exists and the stars' phases cohere above the level's threshold for the hold interval within the listening
window, the level is won.

**Why this priority**: this is the whole game.

**Independent Test**: from a constructed level, a known sequence of links, nudges and a listen wins on the listen;
after every action the phases at every tick, the snapped links and the coherence equal an independent computation.

**Acceptance Scenarios**:

1. **Given** a level and its known actions, **When** they are applied, **Then** the level is won exactly on the listen.
2. **Given** any action sequence, **When** it is applied twice, **Then** every state and the outcome are the same.

### User Story 2 - The constellation comes apart, never coheres, or the moves run out (Priority: P1)

A listen fails when a link of the symbol is missing, when links snap under phase drift and the symbol's stars come
apart, or when the window ends without the hold; using up the action budget without a win fails the level too. Each
failure names its reason, the tick and the link where it applies.

**Independent Test**: scripted sequences end failed with the named reason on the exact action and tick.

### User Story 3 - Undo, redo and replay (Priority: P1)

The player undoes and redoes every action exactly; a recorded trace replays to the same states everywhere.

**Independent Test**: 500 seeded traces replay identically; undo restores exact fingerprints.

### User Story 4 - The life of a level and its stored form (Priority: P2)

A level loads, may show a tutorial, plays, pauses and ends; levels have a versioned stored form that refuses damage.

**Independent Test**: the state machine refuses actions in the wrong stage; levels round-trip and damaged forms are
refused.

### Edge Cases

- **An unknown star, a link from a star to itself, a link that already exists, a link over a star's degree limit or the
  level's link limit, removing a missing or fixed link, a nudge other than one step:** refused without cost.
- **Coherence exactly at the threshold:** counts as coherent; one unit below does not.
- **A link whose phase gap equals the snap limit:** holds; one step more snaps it.
- **The hold reached on the last tick of the window:** a win; one tick short is a failure.
- **The last action of the budget:** a listen on it can still win; any other last action without a win fails the level.
- **A level already solved at load:** never generated; every level needs at least one action before a listen can win.
- **Actions after the end:** every action is refused once the level is won or failed, except undo.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1301-001**: A level MUST define its stars (natural rate, starting phase, drawing position), its fixed links,
  the target symbol (star pairs), the coupling strength, the degree and link limits, the snap limit, the coherence
  threshold, the hold interval, the listening window and the action budget.
- **FR-R02G1301-002**: The phase of every star MUST advance exactly, tick by tick, by its natural rate plus the coupling
  pull of its linked neighbours, all stars at once.
- **FR-R02G1301-003**: A link MUST snap during a listen exactly when its stars' phase gap exceeds the snap limit, and the
  coherence of the stars MUST be computed and compared with the threshold exactly.
- **FR-R02G1301-004**: Linking two stars, removing a link the player made and nudging a star's phase by one step MUST
  each spend one action; a listen MUST spend one action and decide the level.
- **FR-R02G1301-005**: A listen MUST win exactly when every link of the target symbol exists and the stars stay coherent
  with the symbol intact for the hold interval within the window; it MUST fail naming a missing symbol link, the tick
  and link where the symbol's stars come apart, or the longest coherent run when the window ends; using up the budget
  without a win MUST fail with a named reason.
- **FR-R02G1301-006**: Every action MUST be validated (stars, link existence, limits, step, stage, previous fingerprint)
  and refused without change when invalid.
- **FR-R02G1301-007**: Undo and redo MUST restore exact states and fingerprints; replaying a record trace MUST reproduce
  every state.
- **FR-R02G1301-008**: The level's life MUST follow a defined state machine (loading, tutorial, playing, paused, won,
  failed, result).
- **FR-R02G1301-009**: Levels MUST have a versioned stored form with a fingerprint; damaged, edited and newer forms MUST
  be refused.
- **FR-R02G1301-010**: The rules MUST be expressible as a puzzle contract (R02-F23).
- **FR-R02G1301-011**: Invalid requests MUST be refused with stable reason codes `r02-g13.*`; existing modules
  unchanged.
- **FR-R02G1301-012**: The source's invariants this kernel owns (time, input budget, goal, repeatability, undo, failure
  honesty, stability, save, renderer purity) MUST each have a named direct test and a seeded neighbouring-input check.
- **FR-R02G1301-013**: Every star, link and measure MUST be identifiable without colour vision: the kernel names them in
  words (star, rate and phase, links and their gaps, coherence, actions left).
- **FR-R02G1301-014**: The truth metric MUST be computed exactly and reported after every action: the order parameter
  of the stars at every tick of a listen of the current state, the links snapped per tick, and a graph-isomorphism label
  of the player's link graph with whether it matches the target symbol.

### Key Entities

- **Level**: stars, fixed links, target symbol, coupling, limits, snap limit, threshold, hold, window, budget, tutorial
  flag, fingerprint.
- **Star**: natural rate, starting phase, drawing position.
- **Link**: two stars; fixed or placed by the player.
- **Listen report**: phases per tick, snapped links per tick, coherence per tick, the coherent runs and the outcome.
- **Action**: link, unlink, nudge, listen, undo, redo.
- **Play**: stage, links, starting phases, actions spent, records, undo and redo stacks, failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1301-001**: For 500 seeded constructed levels the known actions win and every refused action is refused with
  its named reason.
- **SC-R02G1301-002**: For 500 seeded action traces, replay reproduces every fingerprint and the outcome; undo of every
  action restores the exact earlier state.
- **SC-R02G1301-003**: Over 500 seeded levels and action sequences, every phase, snapped link, coherence value and
  outcome of a listen equals an independent computation.
- **SC-R02G1301-004**: Failure happens on the exact action and tick with the reason named, including one action either
  side of the budget, one unit either side of the coherence threshold, one step either side of the snap limit and one
  tick either side of the hold.
- **SC-R02G1301-005**: Levels round-trip exactly; damaged, edited and newer forms are refused.
- **SC-R02G1301-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.

## Assumptions

- "Cap max degree" is read as each star's link count limit; "edge budget exceeded" as the action budget spent without a
  win (links cost actions), with the level's link limit refused rather than exceeded.
- "Graph disconnects under drift" is read as links snapping when their stars' phases drift apart beyond the snap limit
  during a listen, so that the symbol's stars are no longer joined by links.
- "Phase-coherence exceeds threshold for hold interval" is read as the order parameter of all stars at or above the
  level's threshold, with every symbol link intact, for that many consecutive ticks inside the listening window.
- "Kuramoto order parameter and graph-isomorphism labeling" is the exact truth metric of FR-R02G1301-014.
- Levels and their certification (spanning tree and cycle search plus bounded synchronization simulation) come in
  R02-G13-02; drawing in R02-G13-03; gestures (drag links, tap to nudge, orbit) in R02-G13-04.
- The game design is the project's own archived design; the code is original.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Deterministic state transition (links, nudges, listens, budget) | FR-R02G1301-002, 003, 004, 006, 007, 008 |
| Exact win/failure evaluation (symbol links, coherence hold, drift snap) | FR-R02G1301-005 |
| Truth metric: order parameter and graph-isomorphism label | FR-R02G1301-014; SC-R02G1301-003 |
| Puzzle contract for certification | FR-R02G1301-010 |
| Invariants INV-01 … 05 and INV-07 … 10 (INV-06 content and INV-12 novelty belong to R02-G13-02; INV-11 is superseded by the free tier) | FR-R02G1301-012 |
| Accessibility (colour independence) | FR-R02G1301-013 |

## Negative Requirements / Excluded scope

- No rendering, gestures, generator, solver certification, adapter, catalog registration or persistence in this
  feature; no floating point in the rules; no device run before ImplementationLock-100.
