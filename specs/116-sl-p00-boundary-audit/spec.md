# Feature Specification: Simulation Lab — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `116-sl-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A16-P00 (legacy ledger) · ID namespace FR-A16-0##, SC-A16-0##, T-A16-0##

**Input**: User description: archived manual `apps/16-simulation-lab.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Simulation Lab (`a16.simulation-lab`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/SimulationLab` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with Adapter/,
  ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target, bundle identifier, in-app
  product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met by the one app
  itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A15;
  the contract lives in `docs/apps/simulation-lab/`.
- **Visuals are code:** fields, colour ramps, overlays and backgrounds are shaders and procedural drawing; bundled
  presets and educational copy need an author or source and license.
- **Constitution:** 2.12.0 adds the A16 experience rules (committed at the start of this gate, `f2d45f77`).

## Clarifications

### Session 2026-11-16

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
the A16 constitution commit is `f2d45f77` and the A16-P00 specify commit `1006181f` (the phase start: the no-change
diff of `Packages` and `External` is taken from it); the reference submodule is pinned at `d93edd1`; fifteen
experiences are registered (`Catalog/registrations.json`, A01–A15). VisualCore offers in `VisualCoreRendering`
`PingPongTarget` (a read and a write `RenderTarget` with `swap()`), `FloatRenderSupport` (`detect(in:)` probes
`GL_EXT_color_buffer_half_float` or `GL_EXT_color_buffer_float` and a 4×4 RGBA16F target; `storageFormat` gives
RGBA16F or the documented RGBA8 fallback), `FieldPass` with `FieldUniform` and `FieldPassError`, `RenderTarget`,
`ResourceRegistry` and `StillCapture` (`capture(host:size:prefix:)` into a temporary folder); in `VisualCoreSimulation`
`FieldGrid` with `StoragePrecision` (float32, float16, float16TowardZero, unorm8) built for CPU references of GPU field
passes (feature 019). Fluid Art Playground uses `PingPongTarget` and `FieldPass` app-locally. A still is shared through
SwiftUI `ShareLink` in Generative Art Studio, Fluid Art Playground, Fractal Explorer (which captures through
`StillCapture`) and Infinite Geometry. No cellular-automaton, Gray-Scott or wave rules and no shippable field histogram
exist in any framework product (`ImageComparison`'s histogram is test support; `FrameChecks.histogram` in
VisualCoreExperience is a luma histogram of RGBA8 frames compiled only under DEBUG or VISUALCORE_AUTOMATION).
`ResourceRegistry` creates every texture with LINEAR filtering and CLAMP_TO_EDGE, so the wrap and fixed-zero
boundaries of clarification 5 are done with `texelFetch` and index arithmetic in the step shaders (facts corrected by
the contract audit, T-A16-012).

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A15: the one app is the shell;
  this phase proves it builds for testing with Simulation Lab absent; the targets come with A16-P01's first rules.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least one
  test that exercises it; an implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: Which package holds Simulation Lab? → A: `Packages/ExperiencesCreative/SimulationLab` (Auto-Creator.md §16), as
  A05–A15 did; no new package is created.
- Q: Does Simulation Lab need a permission or a new privacy answer? → A: No new one. Presets are kept in the
  experience's own storage; a still is captured into a temporary folder and handed to the system share sheet, as in
  Generative Art Studio, so the experience adds no usage string; no network, camera, location or microphone.
- Q: What precision and boundary rules does the audit assume for later phases? → A: Cellular automata on RGBA8
  (`unorm8`, exact states); reaction-diffusion and the wave field on RGBA16F when `FloatRenderSupport` reports
  support, otherwise those two families are disabled with a message (no silent 8-bit run); the CPU reference uses
  `FieldGrid` with the matching `StoragePrecision`; boundaries are wrap for automata and reaction-diffusion and fixed
  zero for the wave field. The exact tolerances and stability limits are decided in A16-P01, not here.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Simulation Lab gets a map of what VisualCore already provides for each capability the
experience needs — shader simulation with framebuffer feedback, numerical visualization, parameter controls, data
visualization, animation and capture — and for each version 0.1 feature, with real files, declared names and package
products, each marked available, requires adaptation or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the five brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Simulation Lab work, and the starting commit
is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Simulation Lab absent, so Phase
01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Simulation Lab is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Simulation Lab can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable offscreen feedback path were missing, **Then** the
   decision is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example an offscreen render target but no ping-pong pair, or 8-bit targets
  but no floating-point colour attachment): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example a feedback field in Fluid Art Playground or a
  still export in Generative Art Studio) but not in a framework product: not counted as available; reuse needs it in
  VisualCore first.
- **Floating-point render targets on OpenGL ES through ANGLE** (the manual's risk 1): the audit records whether a
  capability probe and a fallback exist; the choice and its owner are named, nothing is built here.
- **Read-write feedback on the same texture** (the manual's risk 2): the audit records how existing passes keep
  resources separate and assigns the assertion to a phase.
- **Authoritative-looking visuals** (the manual's risk 3): recorded as a rule (educational approximation labels), not
  solved here.
- **Numerical stability** (time steps, wave CFL limit, invalid states): recorded as a rule with an owner; no solver is
  built here.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Simulation Lab work starts.
- **Persisted data, permissions, accessibility interface:** none is added in this phase (no interface); the still
  capture's permission posture for later phases is decided in clarification 4 (share sheet, no new usage string).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A16-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (offscreen targets, framebuffer feedback, fullscreen passes, textures), the experience
  host, the build and release steps, source ownership and the reference regression steps, each with real paths.
- **FR-A16-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A16-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least these MUST be assessed: the cellular-automaton rules with a CPU reference; the
  Gray-Scott reaction-diffusion rules with a CPU reference; the 2D wave field with a stability limit; seeded starting
  conditions and the parameter schema per experiment; boundary rules (wrap, clamp, fixed); a ping-pong pair of render
  targets with explicit read/write separation; floating-point or packed-precision targets with a capability probe and
  fallback; the GPU-versus-CPU comparison within a stated tolerance; pause, reset, single step and speed; the histogram
  or legend overlay; seeding and painting by touch with a control alternative; saved presets; still capture; resize
  and context-loss rebuild from CPU state.
- **FR-A16-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record the
  phase-start commit, the reference pin and the results.
- **FR-A16-005**: The one app MUST build for testing with Simulation Lab absent; the experience package check MUST pass;
  Simulation Lab MUST stay unregistered and unavailable (its targets come with A16-P01's first rules).
- **FR-A16-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no claim of scientific accuracy, prediction or certification, no high-precision cluster computation, no
  multi-user experiments, no pass that reads the texture it writes, no purchased, generated or hand-made images,
  textures or artwork, no unlicensed presets or copy), the manual's three risks (precision and filtering, read-write
  feedback, authoritative-looking visuals) each with an owner, a verification method and a release-blocker condition,
  and a stop/go decision with reasons.
- **FR-A16-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A16-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A16-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A16-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A16-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A16-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (15 registered experiences, none of them A16).
- **SC-A16-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A16-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides 2D and offscreen pieces used by earlier experiences — offscreen render targets, fullscreen shader
  passes, feedback fields (Fluid Art Playground's advection), shader compilation with typed errors, still export
  (Generative Art Studio), quality tiers, gesture recognizers, accessibility planners, experience storage and document
  stores with migration; the audit confirms each from the code and records what is missing (for example a ping-pong
  pair, float targets, a histogram reducer or simulation rules).
- Simulation rules, presets, copy and the interface are app-local; generic pieces (for example a ping-pong target pair
  or a float-target capability probe) are assessed for VisualCore ownership.
- Later phases (A16-P01 to A16-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A16-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A16-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A16-005, US3 |
| Review gate: written stop/go decision | FR-A16-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A16-008 |
| Brainstorm capabilities (GPU simulation with framebuffer feedback, numerical visualization, parameter controls, data visualization, animation and capture) | FR-A16-002 |
| Manual non-goals and risks 1–3 | FR-A16-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network.
