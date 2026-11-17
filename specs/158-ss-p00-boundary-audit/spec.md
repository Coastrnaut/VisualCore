# Feature Specification: Shader Studio — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `158-ss-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A22-P00 (legacy ledger) · ID namespace FR-A22-0##, SC-A22-0##, T-A22-0##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Shader Studio (`a22.shader-studio`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/ShaderStudio` (Auto-Creator.md §16 layout). It never gets a standalone target, bundle
  identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met
  by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A21. The contract lives in `docs/apps/shader-studio/`.
- **Visuals are code:** templates, their textures and every preview are code; no purchased, generated or
  photographic image.
- **Constitution:** 2.18.0 adds the A22 experience rules (committed at the start of this gate, `27d7d83e`).
- Follow `specs/151-au-p00-boundary-audit`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Shader Studio gets a map of what VisualCore already provides for each capability the
experience needs (shader compilation, diagnostics and error reporting, render previews, the shader asset pipeline
and parameter controls) and for each version 0.1 feature. Every entry has real files, declared names and package
products, and is marked available, requires adaptation, or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Shader Studio work, and the starting commit
is recorded, so later phases can prove what they changed upstream.

**Independent Test**: the regression's results are recorded for an unchanged tree; the baseline document names the
commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** its two chunks are read for the phase-start tree, **Then** 7 of 7
   steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Shader Studio absent. Phase 01
then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Shader Studio is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Shader Studio can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** compiling a runtime fragment shader in the host's context, reading its compile
   log, or drawing it full screen were missing and could not be built over the existing renderer, **Then** the
   decision is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a compile that fails without a structured log): marked "requires
  adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's runtime shader rebuild):
  not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **Expensive or hanging shaders** (the manual's risk 1): the audit records the caps on source and preview, the stop
  and reset, and that no execution sandbox is claimed.
- **Editing on a small screen** (the manual's risk 2): the audit records the editor's ownership, hardware-keyboard
  support and the iPad-first layout.
- **Shader language support varies** (the manual's risk 3): the audit records which capability queries exist and
  where the compatibility profile is owned.
- **Line numbers shifted by inserted code:** the audit records where a prefix (version, precision, includes) is added
  and how the person's line numbers are recovered.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (shader compilation and linking, full-screen shaders, the GLSL library, textures and
  render targets, capability queries), the experience host, the build and release steps, source ownership and the
  reference regression steps, each with real paths.
- **FR-A22-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A22-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the project, template and uniform models, versioned and validated, with documented caps;
  - a source validator run before any compile (size, lines, uniforms, inputs);
  - compiling and linking a person's fragment shader in the host's context, with the complete log captured;
  - mapping log lines to the person's lines after inserted template code;
  - an explicit Compile and Run action that swaps programs only on success and keeps the last good preview;
  - a bounded preview surface (size and frame rate) with a stop, reset and watchdog for slow frames;
  - a parameter inspector for bounded uniforms and defined texture inputs made in code;
  - local project save and open with versioned files, and refusal of damaged or newer files;
  - a code editor with line numbers, syntax assistance and a hardware keyboard;
  - a compatibility profile from the host's capability queries;
  - resize, orientation and context-loss rebuild from the project's source.
- **FR-A22-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A22-005**: The one app MUST build for testing with Shader Studio absent. The experience package check MUST
  pass. Shader Studio MUST stay unregistered and unavailable; its targets come with A22-P01's first rules.
- **FR-A22-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, no shader gallery or
    marketplace, no private API, no compile off the host's thread, no sandbox claim, no unmeasured performance claim,
    and no purchased, generated or photographic images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: expensive
    driver behaviour from user shaders, editor ergonomics on iPhone, and varying shader language support;
  - a stop/go decision with reasons.
- **FR-A22-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A22-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A22-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A22-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A22-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (21 registered experiences, none of them A22).
- **SC-A22-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A22-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the pieces earlier experiences used (full-screen shader scenes, the GLSL library, shader
  compilation inside its scenes, capability probes, parameters, experience storage and named files as Digital Zen
  Garden used them): the audit confirms each from the code and records what is missing.
- The templates, editor, copy and interface are app-local; generic pieces are assessed for VisualCore ownership.
- Later phases (A22-P01 to A22-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A22-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A22-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A22-005, US3 |
| Review gate: written stop/go decision | FR-A22-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A22-008 |
| Brainstorm capabilities (shader compilation, diagnostics and error reporting, render previews, shader asset pipeline, parameter controls) | FR-A22-002 |
| Manual non-goals and risks 1–3 | FR-A22-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API; no permission and no usage string.
