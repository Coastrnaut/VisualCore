# Feature Specification: Physics Playground — Phase 05 Numerical stability and performance audit

**Feature Branch**: `086-pp-p05-stability` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A11-P05 (legacy ledger) · ID namespace FR-A11-5##, SC-A11-5##, T-A11-5##

**Input**: User description: archived manual `apps/11-physics-playground.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — presets for pendulum, spring chain and stacked objects (built in A11-P04,
  audited here under stress); regression fixture — an identical initial state and event stream reproduce deterministic
  CPU results; graphics-context ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/physics-playground/visualcore-contract.json`): G-STABILITY (app-local) —
  stability caps checked under stress, a stated per-tick work budget for the active bodies, and sleeping bodies that
  stop costing work at rest.
- **Quality levels** are declared here: the experience's declared level count matches the levels the drawing uses and
  its catalog registration; levels change only drawing detail, never the physics.
- **Device QA:** frame pacing, thermals and touch latency on real devices are planned in a device-campaign document;
  device tasks are tagged {device} and run only after ImplementationLock-100.
- **Storefront:** no per-app listing (ADR-0009); the catalog entry (name, short description, capabilities) is written
  truthfully here, every capability backed by a named test, with no claims of accuracy, safety or learning outcomes.
- **Owner rulings:** short tests; measure briefly and bound longer runs by arithmetic; no wall-clock assertions on CI;
  iOS 27 at phase gates; reference regression and iOS 26 at X-A11; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
the world (schema 3) already caps speeds (40 m/s, 40 rad/s), clamps spring stiffness and damping to their stable
bounds, limits the positional correction to 0.1 m per tick and holds at most 48 bodies and 16 springs; the broad phase
returns only overlapping pairs; `PlaygroundCore.qualityTiers` is 1 (registration `["level-0"]`); Neon Arcade declares
three tiers through `ArcadeBudget.levels`, forwards the host's `qualityProfile` through its experience wrapper and maps
host tier 0 (the best) to its fullest drawing budget, with Low Power Mode injected (`lowPowerMode`) and selecting the
lowest.

- Q: When does a body sleep and wake? → A: A dynamic, unpinned, ungrabbed body whose speed is below 0.05 m/s and
  angular speed below 0.05 rad/s for 60 consecutive ticks (0.5 s) falls asleep: its velocities become 0 and it is
  skipped by gravity, drag and integration; a pair of two sleeping bodies, or a sleeping body and a wall or a static or
  pinned body, is not tested. It wakes (counter reset) in the tick in which an awake dynamic body's bounds overlap it, a
  spring joins it to an awake body, an edit names it (grab, nudge, pin, delete of a body touching it), or any level
  changes (all wake); presets, reset and opened slots start awake. Per-body `asleep` and `restTicks` are saved (world
  schema 4, migration 3 → 4 sets awake with 0; the experience state becomes schema 5) and covered by the digest.
- Q: What is the stated work budget? → A: Counted per tick (derived, never saved): narrow-phase tests ≤ 48·47/2 + 48·4
  = 1,320, contact points ≤ 2 per contact, solver point updates ≤ iterations × points. The audit records the counts at
  48 awake bodies and 16 springs and the host's median tick time over 600 ticks in research.md (measured, not asserted);
  longer runs are bounded by arithmetic.
- Q: What are the stress scenes? → A: Five seeds: free play filled to 48 bodies by drops, 16 springs between seeded
  pairs of bodies, stiffness level 3; every 30 ticks a seeded nudge (±1) on a seeded body; every 240 ticks seeded
  gravity, drag and stiffness levels; 1,200 ticks each, every value checked each tick. The energy check uses the same
  scene without nudges or level changes after tick 0 (drag low): total energy sampled each second never rises > 1 %.
- Q: What do the quality levels change? → A: Three levels; host tier 0 is the best: tier 0 → spring zigzags of 8 coils,
  circles of 33 segments, hatch lines every 0.12 m, arrowheads drawn; tier 1 → 6 coils, 24 segments, hatch every
  0.2 m; tier 2 → 4 coils, 16 segments, no hatch (static bodies keep their darker fill). Low Power Mode (injected in
  tests) selects tier 2. `qualityTiers` 3; registration `["level-0", "level-1", "level-2"]`; the core stores no tier.
- Q: What is the storefront text and which words are refused? → A: Summary "A sandbox of circles, boxes and springs
  under gravity and drag, with presets, saved experiments and tutorials." Capabilities each map to a named test in a
  table in `docs/apps/physics-playground/README.md`, checked by `specs/086-pp-p05-stability/scan-claims.sh`, which also
  refuses (case-insensitive, whole words) accurate, accuracy, precise, precision, engineering-grade, safety, predict,
  prediction, teaches, learning outcome and improves understanding in the catalog entry and the README.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing explodes (Priority: P1) 🎯

A person can push the playground hard — fill it with bodies, stiffen every spring, fling things at full speed, switch
gravity and drag at random — and the world never produces impossible values, never loses a body through a wall and
never gains energy from nowhere.

**Why this priority**: the manual's risk 1 (instability from large steps or stiff springs) and this phase's audit.

**Independent Test**: seeded stress scenes run for a short span with every number checked each tick.

**Acceptance Scenarios**:

1. **Given** stress scenes (48 bodies, 16 springs at the highest stiffness, random flings and level changes), **When**
   they run for 1,200 ticks each, **Then** no value is non-finite, no body leaves the stage and the speed caps hold.
2. **Given** a stress scene with no edits after its start and drag on, **When** it runs, **Then** its total energy never
   rises by more than 1 % in any second.
3. **Given** each preset, **When** it is stressed with flings and stiffness changes, **Then** it stays valid.

---

### User Story 2 - The same inputs give the same world (Priority: P1)

A recorded session — the starting experiment and every action with its tick — replays to exactly the same world, bit
for bit, whatever the frame pacing and whether or not it is drawn, at every quality level.

**Why this priority**: the phase's regression fixture (manual §11 fixture 5).

**Acceptance Scenarios**:

1. **Given** a recorded session over every action kind, **When** it is replayed twice and at frame times of 1/30, 1/60
   and 1/120 s, **Then** the world digests are identical.
2. **Given** each quality level, **When** the session is replayed and drawn, **Then** the world digest is the same.

---

### User Story 3 - Resting bodies cost nothing (Priority: P2)

Bodies that have come to rest fall asleep and stop being simulated until something touches, pulls or edits them, so a
settled scene costs little; the stated work budget per tick holds at the body limit.

**Why this priority**: the manual's profiling plan (maximum active-body budget, optional sleep detection) and risk 3.

**Acceptance Scenarios**:

1. **Given** the stacked-objects preset, **When** it settles, **Then** its boxes fall asleep and the number of pair
   tests per tick drops to the stated settled level.
2. **Given** a sleeping body, **When** another body hits it, a spring pulls it, gravity or a level changes, or it is
   grabbed, nudged or pinned, **Then** it wakes in that tick.
3. **Given** 48 awake bodies and 16 springs, **When** a tick runs, **Then** the counted work (pair tests, contacts,
   solver iterations) stays within the stated budget.

---

### User Story 4 - Truthful storefront and a device plan (Priority: P2)

Whoever reads the catalog entry sees a short, true description and capabilities each backed by a named test, with no
accuracy, safety or learning claims; whoever runs the device campaign finds the measurements to take, with thresholds.

**Acceptance Scenarios**:

1. **Given** the catalog entry, **When** it is checked, **Then** every capability names an existing test and no
   forbidden claim appears.
2. **Given** the device-campaign document, **When** it is read, **Then** each row has a device, procedure, threshold and
   status "pending device campaign".

### Edge Cases

- **A sleeping body under a pinned or static body:** stays asleep; static and pinned bodies never wake others.
- **A sleeping body on a spring that is stretched by an edit:** wakes.
- **Level changes (gravity, drag, stiffness):** wake every body.
- **How sleep looks:** sleeping bodies are drawn exactly like awake ones (sleep is an optimisation, not a feature the
  person sees); the state panel and the spoken description are unchanged.
- **Quality level changed mid-run:** drawing detail changes; the digest does not.
- **Low Power Mode:** the lowest quality level is drawn; the physics is unchanged.
- **Thermal or performance claims:** none without device measurements; the device plan holds them.

## Requirements *(mandatory)*

### Functional Requirements

**Stability (G-STABILITY, app-local)**

- **FR-A11-501**: Seeded stress scenes MUST run with every value finite, every body inside the stage and every cap
  respected, and total energy of an unedited damped scene MUST never rise by more than 1 % per second.
- **FR-A11-502**: Bodies MUST fall asleep after resting below stated speed thresholds for a stated time, skip simulation
  while asleep, and wake when touched by an awake body, pulled by a spring, changed by an edit or a level change; sleep
  state MUST be saved and covered by the digest.
- **FR-A11-503**: The per-tick work (pair tests, contacts, solver iterations) MUST be counted and stay within a stated
  budget at 48 bodies and 16 springs; wall-clock time is measured briefly on the host and bounded by arithmetic, not
  asserted.

**Determinism**

- **FR-A11-510**: A recorded session of every action kind MUST replay to identical digests across repeats, frame pacings
  and quality levels, with drawing on or off.

**Quality levels**

- **FR-A11-520**: The experience MUST declare three quality levels, used by the presenter (arrow and outline detail,
  spring coil count, hatch density) and listed in its registration; Low Power Mode MUST select the lowest; the digest
  MUST be independent of the level.

**Storefront and device plan**

- **FR-A11-530**: The catalog entry MUST have a truthful summary and capabilities each backed by a named test, checked
  by a claims scan that refuses accuracy, safety, prediction and learning-outcome words.
- **FR-A11-531**: A device-campaign document MUST list frame pacing per level, thermal behaviour over 10 minutes, touch
  latency and VoiceOver, each pending the device campaign.

### Key Entities

- **Sleep state**: per body: asleep flag and resting-tick counter.
- **Work counter**: pair tests, contacts, solver iterations of the last tick (derived, never saved).
- **Quality level**: 0…2 with drawing budgets.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A11-501**: 0 non-finite values, 0 bodies outside the stage over 5 stress scenes × 1,200 ticks; energy rise ≤ 1 %
  per second in the unedited damped scene.
- **SC-A11-502**: Replays are identical in 100 % of repeats, pacings (1/30, 1/60, 1/120 s) and levels (0, 1, 2).
- **SC-A11-503**: A settled five-box stack is fully asleep within 3 s and its pair tests per tick drop to 0; every wake
  trigger wakes in the same tick.
- **SC-A11-504**: Per-tick work at 48 bodies and 16 springs stays within the stated budget; host timings recorded.
- **SC-A11-505**: Declared levels = presenter levels = registration levels = 3; the claims scan passes; the device plan
  lists its rows.
- **SC-A11-506**: Package tests, the app build, unit tests and the runner pass on iOS 27; each test under 10 s.

## Assumptions

- Thresholds for sleep and the work budget are set in clarification and tuned only if a fixture fails (recorded).
- Phase 04's presets, experiments and tutorials are reused unchanged.

## Out of Scope

- Device measurements (campaign), release documents (A11-P06), new physics features.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 MVP gate (presets) | FR-A11-501 (presets under stress); story 1 |
| Phase 05 regression fixture (deterministic replay) | FR-A11-510; story 2 |
| Manual §12 profiling plan (CPU solver time, active-body budget, sleep, reduced quality) | FR-A11-502, 503, 520; story 3 |
| Manual §13 risks 1–3 | FR-A11-501–503, 530 |
| Contract gap G-STABILITY; constitution A11 (stable and bounded, truthful claims) | FR-A11-501–503, 530 |

## Negative Requirements

- No performance or thermal numbers without device measurements; no accuracy, safety or learning claims; no wall-clock
  assertions on CI; quality levels never change the physics.
