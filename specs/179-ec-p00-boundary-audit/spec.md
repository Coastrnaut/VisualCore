# Feature Specification: Effects Composer — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `179-ec-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P00 (legacy ledger) · ID namespace FR-A25-0##, SC-A25-0##, T-A25-0##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Effects Composer (`a25.effects-composer`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/EffectsComposer` (Auto-Creator.md §16 layout). It never gets a standalone target,
  bundle identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell"
  is met by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A24. The contract lives in `docs/apps/effects-composer/`.
- **Visuals are code:** the five effects and the built-in test image are generated in code; a person's imported image
  is their input, never bundled.
- **Constitution:** 2.21.0 adds the A25 experience rules (committed at the start of this gate, `eec911ea`).
- Follow `specs/172-gbl-p00-boundary-audit`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Effects Composer gets a map of what VisualCore already provides for each capability the
experience needs (render graph, framebuffer pipelines, shader library, effect parameters, preset serialization, and
offscreen rendering and export) and for each version 0.1 feature. Every entry has real files, declared names and
package products, and is marked available, requires adaptation, or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the six brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Effects Composer work, and the starting commit
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

The engineer knows the one app builds for testing and its experience checks pass with Effects Composer absent. Phase
01 then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Effects Composer is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Effects Composer can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** drawing a full-screen pass that samples a texture into an offscreen target in the
   host's context were missing and could not be built over the existing renderer, **Then** the decision is "stop"
   and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example passes exist but no chain compiler): marked "requires adaptation"
  with the missing part named.
- **A capability exists only inside another experience** (for example another experience's graph compiler or image
  export): not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **Colour-space mistakes** (the manual's risk 1): the audit records which textures and targets are linear or sRGB,
  and where pass colour boundaries are owned.
- **An image larger than the texture limit** (risk 2): the audit records where the limit is read and where the cap or
  scaling rule is owned.
- **Intermediate targets growing without bound** (risk 3): the audit records the target pool, budget and lifetime
  owner.
- **A preset file that is damaged, newer or holds non-finite numbers:** the audit records the versioned envelope and
  refusal support and where the preset format's policy is owned.
- **A denied or cancelled image pick:** the audit records that the built-in test image remains usable.
- **A context loss or resize during editing or export:** the audit records that targets are rebuilt from CPU state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (programs, full-screen passes with sampler inputs, render targets and their budget,
  read-back, texture upload, the GLSL library), the frame clock, diagnostics, the experience host, the build and
  release steps, source ownership and the reference regression steps, each with real paths.
- **FR-A25-002**: The contract MUST hold a capability matrix covering the six brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A25-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the effect definition, node, chain, parameter and output-settings models, versioned and validated, with caps;
  - five built-in effects with bounded parameters;
  - compiling a linear chain into an ordered pass plan with intermediate-target lifetimes and a pass never sampling the
    target it writes;
  - a bounded pool of intermediate targets;
  - shader compile and link diagnostics visible to the experience;
  - reorder, enable and disable with an immediate preview;
  - a before and after compare that keeps the untouched source;
  - preset storage with versioned files, and refusal of damaged or newer files;
  - image import through the system picker with scoped access, and decoding to a texture within the texture limit;
  - colour-space boundaries (linear and sRGB);
  - still export at a validated size and format, rendered offscreen and encoded;
  - resize, orientation and context-loss handling.
- **FR-A25-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A25-005**: The one app MUST build for testing with Effects Composer absent. The experience package check MUST
  pass. Effects Composer MUST stay unregistered and unavailable; its targets come with A25-P01's first rules.
- **FR-A25-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking or upload, no private
    API, no user-written code, no video editing, no import without the person's pick, no claim of professional colour
    accuracy or preset compatibility with another editor, and no purchased, generated or photographic bundled images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: colour-space
    mistakes, images above the texture limit, and unbounded intermediate targets;
  - a stop/go decision with reasons.
- **FR-A25-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A25-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (6) and version 0.1
  features (6) trace to matrix rows.
- **SC-A25-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A25-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A25-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (24 registered experiences, none of them A25).
- **SC-A25-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A25-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the pieces earlier experiences used (the render host, field passes with sampler inputs, render
  targets, read-back, texture upload, the GLSL library, experience storage, versioned envelopes): the audit confirms
  each from the code and records what is missing.
- The effect definitions, the chain compiler's rules, copy and interface are app-local; generic pieces (for example an
  image decoder into a texture within the limit, or an image encoder for read-back) are assessed for VisualCore
  ownership.
- Later phases (A25-P01 to A25-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A25-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A25-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A25-005, US3 |
| Review gate: written stop/go decision | FR-A25-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A25-008 |
| Brainstorm capabilities (render graph, framebuffer pipelines, shader library, effect parameters, preset serialization, offscreen rendering and export) | FR-A25-002 |
| Manual non-goals and risks 1–3 | FR-A25-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API; no permission and no usage string yet; no effect implemented.
