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
