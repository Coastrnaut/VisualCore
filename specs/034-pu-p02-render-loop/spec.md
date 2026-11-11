# Feature Specification: Particle Universe — Phase 02 One emitter and one force in the render loop

**Feature Branch**: `034-pu-p02-render-loop` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A04-P02 · ID namespace FR-A04-2##, SC-A04-2##, T-A04-2##

**Input**: User description: archived manual `apps/04-particle-universe.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: point attractors, repulsors and gravity/wind fields (v0.1 feature 02);
  - regression fixture 2: a high particle count respects the configured cap and yields to the quality controller;
  - EGL and context ownership stays solely in the audited VisualCore host.
- **Gaps closed (contract), in VisualCore (constitution Principle II, A04 reuse rule):**
  - G-FIELDS (VisualCoreSimulation): repulsors, softened point gravity, wind and vortex fields that stay finite at
    every position, including exactly at their center (manual fixture 4);
  - G-PQUALITY (VisualCoreDiagnostics plus a live limit in VisualCoreSimulation): a particle budget per quality tier
    that lowers the live limit under heat or Low Power Mode.
- **This phase also adds the GPU render loop:** the sandbox draws the seeded simulation with VisualCore's
  `ParticleRenderer` inside VisualCore's render host. The Phase 01 CPU preview remains as a fallback when the GPU path
  reports an error.
- **Out of scope here:** trails and blending options (Phase 03), multiple emitters in the UI and the scene editor
  (Phases 03–04), saving scenes (Phase 04), and profiling numbers (Phase 05).

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2), choosing the recommended option each time.
Facts checked in code:
- `ParticleForce` has `gravity`, `drag` and `attractor` (constant pull within a radius, skipped within 1e-9 of the
  center); the Phase 01 replay fixture uses `attractor`.
- `QualityPolicy` (VisualCoreDiagnostics) steps tiers by `FramePacing.Thermal` and Low Power Mode with hysteresis. A02
  reads `ProcessInfo` thermal state and Low Power Mode itself, through an app-local seam.
- `ParticleRenderer` draws instanced quads with premultiplied alpha through a `ResourceRegistry`.
- `RenderHost.renderOffscreen(width:height:time:)` returns a `StillImage`.
- A01's `ParticlesArtScene` is an app-local `RenderScene` around `ParticleRenderer`.

- Q: How are the new forces added to VisualCore, and what are their bounds? → A: `ParticleForce` gains four cases:
  - `.repulsor(point:strength:radius:)`: a push away from the point with linear falloff to 0 at the radius,
    |a| ≤ strength;
  - `.gravityWell(point:strength:softening:)`: a = s·d/(|d|²+ε²)^{3/2}, so
    |a| ≤ 2s/(3√3·ε²);
  - `.wind(velocity:rate:)`: a = rate·(w − v);
  - `.vortex(point:strength:radius:)`: a tangential push (counter-clockwise for a positive strength) with linear
    falloff, |a| ≤ |strength|.

  At the exact center the direction is undefined, so repulsor, gravity well and vortex give 0 there.
  `ParticleForce.clamped()` maps non-finite values to 0 and clamps:
  - strength: ±10,000, or 0…1e9 for the gravity well;
  - radius: 1…2,000;
  - softening: 1…500;
  - rate: 0…10;
  - wind speed: ≤ 2,000.

  The system steps with clamped forces. The existing cases are unchanged for valid values, so A01 and the Phase 01
  fixture keep their checksums. Each case has a public `bound` (largest acceleration magnitude) for the tests; wind's
  bound depends on the velocity: rate·(|w| + |v|).
- Q: How is the particle budget defined and applied? → A:
  - `ParticleBudget` in VisualCoreDiagnostics has shares `[1, 0.6, 0.35, 0.2]` for tiers 0–3 and a minimum of 100.
  - `limit(requested:tier:)` = min(requested, max(minimum, ⌊requested × share⌋)).
  - `ParticleSystem.liveLimit` is a settable value clamped to 1…capacity, defaulting to capacity. Emission stops
    while `aliveCount ≥ liveLimit`, and every refused particle counts as dropped.
  - `DeviceConditions.current()` (VisualCoreDiagnostics, public `ProcessInfo` only) reads the thermal state and Low
    Power Mode, so apps share one reader.
  - The sandbox uses `QualityPolicy(tierCount: 4, lowPowerCeiling: 1)` and decides once per frame. The requested
    limit is the scene's limit (default 4,000).
- Q: How does a person place and change the one force? → A: The app core gains `PlacedForce` (kind, world position,
  strength multiplier 0.1…2, default 1). Its defaults are:
  - attractor: 300, radius 300;
  - repulsor: 400, radius 250;
  - gravity well: 2,000,000, softening 40;
  - wind: 120 units/s from the center toward the tapped point, rate 0.8;
  - vortex: 250, radius 300.

  The force occupies scene force slot 0 through `SceneSimulation.setPlacedForce(_:)`, applied live. The controls are:
  - a kind menu: None, Attractor, Repulsor, Gravity well, Wind, Vortex;
  - tap to place and drag to move;
  - a "Center" button;
  - four nudge buttons of 50 units each;
  - a strength slider.

  `SceneForce` gains the same four cases. Adding cases keeps every version-1 file valid, so the schema stays 1.
- Q: Where does the GPU drawing live, and how is it tested? → A: `ParticleLayerScene` in VisualCoreRendering is a
  generic `RenderScene` that:
  - clears to a background color;
  - fits a world rectangle into the drawable (aspect fit, y up) with `Camera2D` and `ViewMetrics`;
  - draws `[ParticleInstance]` from a source closure with `ParticleRenderer`.

  It is reusable by A09 and A19. Package tests on both simulators render it offscreen and check the pixels (SC-A04-205).
  The sandbox hosts it in `RenderHost`/`RenderSurface`. The model advances the simulation from the scene's frame time
  on the main actor; the drawing reads a copy. A host error shows the CPU preview, with a note in the UI.
- Q: How do UI tests drive heat and Low Power Mode? → A: Launch arguments `-uitestThermal
  nominal|fair|serious|critical` and `-uitestLowPower YES` replace `DeviceConditions` in DEBUG builds only. Release
  builds read `ProcessInfo` alone. A short decision interval for tests is not needed: with serious heat the first
  decision steps down at once.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Place and move one force (Priority: P1) 🎯

A person picks an emitter family and a force (attractor, repulsor, gravity well, wind or vortex). They tap the scene
to place the force and drag to move it, and the particles respond.

**Why this priority**: v0.1 feature 02 and journey 1 ("tap to create attractor, drag to move it").

**Independent Test**: UI tests tap and drag on the scene and read the force position; host tests on force math.

**Acceptance Scenarios**:

1. **Given** the sandbox, **When** the person chooses a force kind and taps the scene, **Then** one force of that kind
   is placed at the tapped world point, and the force's kind and position are shown in text.
2. **Given** a placed force, **When** the person drags, **Then** the force follows the finger.
3. **Given** a placed force, **When** the person changes its strength with a control (no gesture needed), **Then** the
   new strength applies on the next step. Every gesture has a control alternative: buttons place the force at the center
   and nudge it.
4. **Given** an attractor or gravity well, **Then** particles near it accelerate toward it. A repulsor pushes them away,
   wind pushes everything in one direction, and a vortex turns them around its center.

---

### User Story 2 - Forces never break the simulation (Priority: P1)

No force placement produces NaN or infinite particles, even with a particle exactly at a force's center.

**Why this priority**: Manual §11 fixture 4 and §6 algorithm decision 2 ("bounded acceleration").

**Independent Test**: Host tests sample every force at and around its center.

**Acceptance Scenarios**:

1. **Given** any force kind with any finite parameters, **When** it is evaluated at its exact center, at 1e-12 from
   it and across a grid of positions, **Then** every acceleration is finite and no larger than the force's bound.
2. **Given** particles spawned exactly on a force's center and stepped 10,000 times, **Then** no particle is removed
   for being non-finite.

---

### User Story 3 - The particle count yields to the quality controller (Priority: P1)

On a hot device or in Low Power Mode, the live particle limit drops, and it returns when conditions recover. The
person's requested limit is never exceeded.

**Why this priority**: Manual §11 fixture 2 and v0.1 feature 06 (device-adaptive quality; the reduced-flash mode comes
with trails in Phase 03).

**Independent Test**: Host tests drive the policy with synthetic thermal and Low Power inputs.

**Acceptance Scenarios**:

1. **Given** a requested limit and a quality tier, **Then** the effective live limit is the tier's share of the
   requested limit, rounded down and never below the minimum, and it is shown in the sandbox.
2. **Given** a scene at the full limit, **When** the tier drops, **Then** no new particles are created until the live
   count is below the new limit. Existing particles are not deleted, so nothing visibly vanishes. Particles that could
   not be created are counted as dropped.
3. **Given** a serious thermal state, **When** the quality controller steps down, **Then** the effective limit
   decreases. After the calm period it steps back up.

---

### User Story 4 - The GPU render loop draws what the simulation computes (Priority: P1)

The scene is drawn by the GPU through VisualCore's render host, frame by frame. What is drawn matches the CPU
simulation, and the CPU preview remains as a fallback.

**Why this priority**: Brainstorm "instanced rendering", "buffer management" and v0.1 feature 04 (instanced rendering
with a performance fallback).

**Independent Test**: An offscreen render of a fixed simulation state, checked pixel by pixel against the CPU
positions, plus UI tests of the live scene.

**Acceptance Scenarios**:

1. **Given** a fixed state of the simulation, **When** it is rendered offscreen, **Then** each particle's projected
   center pixel is lit (the particle's color dominates), and a pixel more than 3 particle radii from every particle is
   background.
2. **Given** the live sandbox, **Then** the GPU scene advances while playing and holds while paused. A context
   recreation keeps the simulation state, because GPU objects are rebuilt from CPU state.
3. **Given** a GPU setup or draw error, **Then** the sandbox shows the CPU preview and a short note, and keeps working.

### Edge Cases

- A tap outside the world square places the force at the nearest point inside it.
- A strength outside its range is clamped. A non-finite strength is ignored.
- The tier changes at most once per decision interval (VisualCore `QualityPolicy` hysteresis).
- The effective limit never drops below the minimum budget (100) unless the requested limit itself is lower; it never
  exceeds the requested limit (checklist CHK012, research R3).
- Choosing a different force kind replaces the force and keeps its position. Removing the force leaves the family's
  own forces only. Kind and strength changes take effect on the next simulation step (CHK010).
- Wind blows from the world center toward the force position; a wind placed exactly at the center blows toward +x
  (CHK005).
- In the background the render host is paused together with the simulation, and it resumes with it (CHK019).
- Under Reduce Motion the scene starts paused on both the GPU path and the CPU preview (CHK020).
- At accessibility text sizes the force controls wrap into a column, like the Phase 01 controls (CHK027).
- Offscreen pixel test (SC-A04-205): the three fixed states are (a) one emitter's burst at the center, (b) particles
  pulled by an attractor, (c) particles under a vortex, each drawn over a black background. "Lit" means the pixel's
  brightest channel is the particle color's dominant channel and is at least 128; "background" means all color
  channels are 0 (CHK007, CHK008).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A04-201**: VisualCore MUST add force fields with documented, bounded, finite accelerations:
  - repulsor (push away within a radius, linear falloff);
  - softened point gravity (inverse square with a softening length);
  - wind (pulls velocity toward a wind velocity at a rate);
  - vortex (tangential, with linear falloff within a radius).

  The existing attractor, gravity and drag behavior MUST stay bit-identical, so the Phase 01 replay fixture and A01
  are unchanged (G-FIELDS).
- **FR-A04-202**: Every force MUST give a finite acceleration with magnitude ≤ its documented bound for all finite
  positions and parameters, including at its center; parameters MUST be clamped or rejected before use.
- **FR-A04-203**: VisualCore MUST provide:
  - a particle budget that maps quality tiers to shares of a requested limit, with a minimum;
  - a live limit on `ParticleSystem` (≤ capacity) that stops new emission above it and counts the drops (G-PQUALITY).
- **FR-A04-204**: The sandbox MUST:
  - offer one force of a chosen kind, placed by tap, moved by drag, and placed or nudged by controls;
  - offer a strength control;
  - show the force's kind, position and strength in text.
- **FR-A04-205**: The sandbox MUST:
  - run VisualCore's `QualityPolicy` on the thermal state and Low Power Mode;
  - apply the tier's budget as the live limit;
  - show the effective limit.
- **FR-A04-206**: The sandbox MUST draw the simulation with VisualCore's `ParticleRenderer` in a `RenderHost` scene.
  The app owns no EGL or GL lifecycle, and the CPU preview remains as a fallback on errors.
- **FR-A04-207**: The contract MUST record G-FIELDS and G-PQUALITY as closed with tests. The API baseline, the
  documented-API check, the host suites, the reference regression and the A01/A02 builds MUST pass.

### Negative requirements

- No new renderer and no app-owned EGL/GL context or GL calls outside VisualCore's renderer.
- No claim of physical accuracy for the gravity well (an artistic, softened field).
- No measured performance numbers. Tiers come from thermal state and Low Power Mode, not invented FPS targets.
- No persistence, networking or permissions.

### Key Entities

- **Force kind**: attractor, repulsor, gravity well, wind, vortex, each with its parameters and bounds.
- **Placed force**: the kind, world position (or wind direction for wind) and strength.
- **Particle budget**: shares per tier and a minimum; the effective limit for a requested limit and tier.
- **Live limit**: the simulation's current emission ceiling, which is at most the pool capacity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A04-201**: Each force is sampled at its center, within 1e-12 of it and on a 101 × 101 grid. 100% of the
  accelerations are finite and within their bound.
- **SC-A04-202**: 10,000 steps with particles spawned on a force center remove 0 non-finite particles, for every force
  kind.
- **SC-A04-203**: With a demand of 10× the requested limit, live ≤ effective limit ≤ requested limit at every step,
  and dropped = demand − created. After the limit is lowered, live never grows while above it and falls to it as
  older particles expire (US3 AC2: nothing is deleted; clarified in T-A04-203).
- **SC-A04-204**: A synthetic serious thermal state lowers the effective limit within one decision interval. After the
  calm period it rises again.
- **SC-A04-205**: In offscreen renders of 3 fixed states, 100% of particle centers are lit and 100% of sampled
  far-away pixels are background.
- **SC-A04-206**: UI tests (tap to place, drag, controls, strength, the effective limit text) and the accessibility
  audits pass on iOS 27.2 and 26.5.

## Assumptions

- VisualCore's `RenderHost`, `RenderSurface`, `ParticleRenderer`, `Camera2D`, `ViewMetrics` and `QualityPolicy` are
  the audited integration points (A04-P00 contract M02, M03, M05, M10).
- The thermal state and Low Power Mode come from public `ProcessInfo` APIs.
- Exact defaults (bounds, shares, strengths) are fixed in clarification.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 02 (attractors, repulsors, gravity/wind fields) | FR-A04-201, FR-A04-204, US1 |
| Manual §11 fixture 4 (singularities) | FR-A04-202, US2 |
| Manual §11 fixture 2 (count cap and quality controller) | FR-A04-203, FR-A04-205, US3 |
| v0.1 feature 04 (instanced rendering with fallback); brainstorm "instanced rendering", "buffer management" | FR-A04-206, US4 |
| v0.1 feature 06 (device-adaptive quality), part | FR-A04-205 |
| Journey 1 (tap to create attractor, drag to move it) | US1 |
| Manual §6 algorithm decision 2 (bounded acceleration) | FR-A04-202 |
| Gap register G-FIELDS, G-PQUALITY | FR-A04-201, FR-A04-203, FR-A04-207 |
