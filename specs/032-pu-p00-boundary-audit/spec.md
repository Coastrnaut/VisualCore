# Feature Specification: Particle Universe — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `032-pu-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A04-P00 · ID namespace FR-A04-0##, SC-A04-0##, T-A04-0##

**Input**: User description: archived manual `apps/04-particle-universe.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- The app lives in this monorepo at `Apps/ParticleUniverse/`, not in a separate repository (constitution 1.5.0, A04
  rules).
- Phase 00 is audit-only and modifies neither VisualCore nor ProjectM.
- Its gap register classifies each needed capability as available, requires adaptation or upstream gap, and names the
  VisualCore module that will own each reusable gap later (Principle II, "Maximize reuse"). For this app that covers
  emitters, forces and fields, the seeded simulation, buffers and instanced drawing, trails, quality tiers, presets and
  scene persistence.
- It reuses the app-neutral contract checker built in A01-P00, as A02 and A03 did.
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2); the recommended option was chosen in each
case. Facts were checked in code:
- `ParticleSystem` (VisualCoreSimulation) is a deterministic, seeded, fixed-capacity CPU simulation (default 10,000,
  hard cap 100,000) with one emitter kind (point source with a direction cone) and forces `gravity`, `drag` and a
  radius-bounded `attractor`;
- `ParticleRenderer` (VisualCoreRendering) draws `ParticleInstance`s as instanced soft-edged quads with premultiplied
  "over" blending only; A01's `ParticlesArtScene` is its consumer;
- `PingPongTarget` and `FieldPass` exist (A02) and can carry a decaying trail texture;
- `QualityPolicy` (VisualCoreDiagnostics) gives tiers from thermal state and Low Power Mode;
- `NamedLibrary`, `DocumentStore`, `StillCapture`, `TemporaryFolder` exist for saved scenes and capture.

- Q: Where do the inventory, matrix and gap register live? → A: In `docs/apps/particle-universe/visualcore-contract.json`
  (the shared schema), rendered to `visualcore-contract.md` and checked by `scripts/check_app_contract.py --app
  particle-universe`.
- Q: Does the simulation run on the GPU? → A: No. OpenGL ES 3.0 through ANGLE offers no compute shaders here, so the
  simulation stays on the CPU in VisualCore's `ParticleSystem` (deterministic, testable, bounded) and only drawing is
  on the GPU (instanced quads). The matrix records "GPU-oriented particle simulation" as `requires adaptation`:
  render-to-texture particle state is a later idea, not MVP.
- Q: Which gaps does the register expect, and who owns them? → A: Reusable gaps go to VisualCore:
  - emitter families (point, line, ring, burst) with bounded counts → VisualCoreSimulation, Phase 01;
  - repulsors, wind and falloff fields with singularity-safe forces → VisualCoreSimulation, Phase 02;
  - additive blending and a trail-decay pass on `PingPongTarget` → VisualCoreRendering, Phase 03;
  - a particle-count quality tier mapping → VisualCoreDiagnostics, Phase 02;
  - scene schema and presets stay app content on `NamedLibrary` (Phase 04).
- Q: What exactly is the app shell? → A: A thin SwiftUI target `ParticleUniverse` in the root `project.yml` (sources in
  `Apps/ParticleUniverse/App/`) plus a UI smoke-test target; a titled home screen only; no render host, no package yet.
- Q: Which ProjectM regression steps form the baseline? → A: The same 7 steps as A01–A03, in two `run-check` chunks.

## User Scenarios & Testing *(mandatory)*

Users:
- the engineer (agent) who implements Particle Universe phases 01–06;
- the owner reviewing the stop/go decision;
- the developers of other apps who reuse what this audit puts into VisualCore (for example A09 Digital Aquarium, A11
  Physics Playground and A19 Living Wallpapers, which also draw many moving sprites).

### User Story 1 - Evidence-backed integration matrix (Priority: P1) 🎯

Before writing any particle code, the implementer can read one matrix that maps every capability the app needs to real
VisualCore files, symbols and package products, each with a status and an example consumer.

**Why this priority**: The manual's first acceptance gate and its required capability audit (§6).

**Independent Test**: Open the matrix. Every row cites existing files, public symbols and package products, and the
shared contract check confirms that each citation resolves in the current tree.

**Acceptance Scenarios**:

1. **Given** the five brainstorm capabilities (GPU-oriented particle simulation, buffer management, instanced
   rendering, blending and trails, interaction and simulation parameters), **When** the matrix is read, **Then** each
   has a row with a status, evidence and an example consumer.
2. **Given** the matrix, **When** the citation check runs, **Then** every cited file and symbol resolves. A renamed or
   removed symbol fails the check and is named.

---

### User Story 2 - Inventory of the host, thread, build and regression baseline (Priority: P1)

The implementer knows how VisualCore renders, how it is built and tested, which sources own what, and which ProjectM
regression tests protect the shared seam. This covers what matters to a particle sandbox:
- the CPU particle system (emitters, forces, capacity, determinism) and the particle renderer (batching, blending);
- ping-pong targets and field passes usable for trail decay;
- pointer input and gesture recognizers;
- quality policy, frame pacing and thermal state;
- document persistence and temporary files; offscreen export.

**Why this priority**: Without it, later phases risk a second GL lifecycle, an unsupported compute assumption, or
breaking the reference.

**Independent Test**: Read the inventory. Each build or test command it lists runs once in this phase, and its
recorded result matches.

**Acceptance Scenarios**:

1. **Given** the inventory, **When** read, **Then** it names, each with file references: the render host entry point,
   its main-thread rule and context-loss behavior; shader loading and diagnostics; the particle system and renderer;
   render targets usable for trails; pointer input; quality and pacing policy; persistence; offscreen export.
2. **Given** the listed ProjectM regression steps, **When** they run, **Then** they pass, and their results are
   recorded as this phase's baseline.

---

### User Story 3 - Compilable empty app shell (Priority: P1)

An empty Particle Universe app builds and launches on the simulator before any particle code exists.

**Why this priority**: The manual's second acceptance gate.

**Independent Test**: Build for both simulator runtimes and run a smoke UI test that finds the app's title.

**Acceptance Scenarios**:

1. **Given** the shell, **When** built for the iOS 27.2 and 26.5 simulators, **Then** it compiles without signing and
   launches to a titled home screen with a spoken label.
2. **Given** the shell, **When** its dependencies are audited, **Then** it links no ProjectM engine, preset or bridge
   module.

---

### User Story 4 - Gap register and stop/go decision (Priority: P2)

The owner reads a written stop/go decision listing everything missing upstream, where each piece will be built and the
phase that builds it.

**Why this priority**: The manual's third acceptance gate; it applies the reuse rule and the risk register (§13: GPU
buffer/instance support, additive-blend comfort, thermal pressure) before code is written.

**Independent Test**: Every `upstream gap` or `requires adaptation` row has a register entry with an owner module, a
phase and a test intent. The decision states go or stop with reasons.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** read, **Then** every gap names an owning VisualCore module (existing or new) or
   justifies keeping it in the app, and names the phase (01–06) that closes it.
2. **Given** a missing capability that would need a second renderer, compute shaders the OpenGL ES path does not
   offer, a VisualCore fork or private APIs, **When** the decision is made, **Then** it is recorded as a blocker or as a
   bounded CPU/GPU design, never worked around silently.

### Edge Cases

- A capability exists only inside the ProjectM reference: it counts as unavailable and goes into the register.
- GPU-side particle state: OpenGL ES 3.0 through ANGLE has no compute shaders here; the matrix MUST say whether
  simulation stays on the CPU (VisualCore `ParticleSystem`) or uses render-to-texture, and why.
- A citation that points only to test code: evidence must include a public, non-test symbol.
- The reference build or its regression fails: the phase is blocked and recorded, never waived.
- A performance figure from a simulator or host run: context only, never a device or budget claim.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A04-001**: The phase MUST produce a read-only repository inventory with file paths: VisualCore package products
  and modules; the render host and thread rule; shader APIs; the particle system and renderer; render targets for
  trails; pointer input; quality, pacing and thermal policy; persistence and temporary files; offscreen export; build
  steps and source ownership.
- **FR-A04-002**: The phase MUST produce an integration matrix covering the five brainstorm capabilities plus five
  version 0.1 needs: multiple emitter families with bounded counts; attractors, repulsors and gravity/wind fields;
  adjustable size, lifetime, color gradient and trail strength; pause/reseed/save; device-adaptive quality and a
  reduced-flash mode. Each row has a status, evidence (file, public symbol, package product) and an example consumer.
- **FR-A04-003**: Matrix citations MUST pass `scripts/check_app_contract.py --app particle-universe`.
- **FR-A04-004**: The phase MUST record the baseline ProjectM regression (7 steps in two chunks) with results.
- **FR-A04-005**: The phase MUST create a compilable, empty app shell under `Apps/ParticleUniverse/` with bundle
  identity `dev.visualcore.ParticleUniverse`: unsigned builds on both runtimes, a titled home screen with an
  accessibility label, a launch smoke test, no permission, usage description or networking, no render host.
- **FR-A04-006**: The shell MUST NOT link ProjectM engine, preset or bridge modules; the dependency audit build phase
  MUST cover the new target.
- **FR-A04-007**: The phase MUST NOT modify any VisualCore package source, the ProjectM reference or its pins
  (diff check).
- **FR-A04-008**: The phase MUST produce a gap register: owning module (or app justification), closing phase (01–06),
  test intent. Reusable work goes to VisualCore by default.
- **FR-A04-009**: The phase MUST record a stop/go decision with reasons. Stop conditions: a second renderer, a fork,
  private APIs or networking, compute shaders the path cannot provide.
- **FR-A04-010**: The phase MUST record traceability from the brainstorm, version 0.1 features 01–06 and journeys 1–3
  to matrix rows and planned phases.
- **FR-A04-011**: The phase MUST record negative requirements with their sources: no exact unlimited N-body physics;
  no online preset marketplace; no networked multi-user simulation; no networking; no device-performance claims
  before campaign II.

### Key Entities

- **Inventory entry**, **matrix row**, **gap entry**, **decision record** (as in the A01–A03 contract schema).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A04-001**: 100% of matrix citations resolve in the automated check.
- **SC-A04-002**: 10 of 10 capability rows carry a status, evidence and an example consumer or a justified gap.
- **SC-A04-003**: The empty shell builds and passes its smoke test on both simulator runtimes.
- **SC-A04-004**: The baseline ProjectM regression passes all 7 steps.
- **SC-A04-005**: 100% of gaps name an owner and a closing phase; reusable gaps go to a VisualCore module.
- **SC-A04-006**: 0 changes to VisualCore package sources or the ProjectM reference in this phase's commits.
- **SC-A04-007**: 6 of 6 version 0.1 features and 3 of 3 journeys trace to at least one phase.

## Assumptions

- The audited baseline is VisualCore as of gate A03-P06 (Fractal Explorer complete); the reference stays pinned at
  `d93edd1`.
- The shell uses existing VisualCore products only. No VisualCore code is written in Phase 00.
- The iOS 27.2 and 26.5 simulators are available. Device evidence is out of scope until campaign II.
- The manual's separate-repository layout is replaced by `Apps/ParticleUniverse/` (CLAUDE.md §4).

## Traceability

| Source | Covered by |
|---|---|
| Brainstorm: GPU-oriented simulation, buffer management, instanced rendering, blending and trails, interaction parameters | FR-A04-002 |
| v0.1 features 01–06 | FR-A04-002 rows, FR-A04-010 |
| Journeys 1–3 (starfield + attractor; emitter type, lifetime, trails; pause/reseed/replay) | FR-A04-010 |
| Manual Phase 00 gates | US1, US3, US4 |
| Manual §6 capability audit and §13 risks 1–3 | FR-A04-002, FR-A04-008 |

## Negative Requirements

- No modification of VisualCore or the ProjectM reference in this phase.
- No second renderer, no EGL in the app.
- No networking, permissions or usage descriptions in the shell.
- No performance claims from simulator runs.
