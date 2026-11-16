# Feature Specification: Interactive Anatomy — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `123-ia-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A17-P00 (legacy ledger) · ID namespace FR-A17-0##, SC-A17-0##, T-A17-0##

**Input**: User description: archived manual `apps/17-interactive-anatomy.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Interactive Anatomy (`a17.interactive-anatomy`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/InteractiveAnatomy` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with Adapter/,
  ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target, bundle identifier, in-app
  product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met by the one app
  itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A16;
  the contract lives in `docs/apps/interactive-anatomy/`.
- **Visuals are code:** fields, colour ramps, overlays and backgrounds are shaders and procedural drawing; bundled
  presets and educational copy need an author or source and license.
- **Constitution:** 2.13.0 adds the A17 experience rules (committed at the start of this gate, `a834dda9`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Interactive Anatomy gets a map of what VisualCore already provides for each capability the
experience needs — 3D model rendering, materials, camera controls, lighting, and labels and overlays
— and for each version 0.1 feature, with real files, declared names and package products, each marked available,
requires adaptation or upstream gap.
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

The owner sees that the ProjectM reference regression passes before any Interactive Anatomy work, and the starting commit
is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Interactive Anatomy absent, so Phase
01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Interactive Anatomy is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Interactive Anatomy can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable lit, depth-tested mesh path were missing, **Then** the
   decision is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example sphere and cube generators but no lathe or sweep, or alpha blending
  but no depth-sorted translucency): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example Molecular Explorer's atom picking or its overlay
  labels) but not in a framework product: not counted as available; reuse needs it in
  VisualCore first.
- **Medical mistakes** (the manual's risk 1): the audit records the content sources, their licenses and the review
  that is a person's action; nothing is written here.
- **Purchased or high-poly assets** (the manual's risk 2): avoided by the rule that visuals are code; the geometry is
  procedural, so no redistribution right is needed.
- **Overlapping labels** (the manual's risk 3): the audit records the label and overlay pieces that exist and assigns
  the overlap rule and the searchable list to a phase.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A17-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (meshes, mesh rendering, lighting, depth, blending, textures), the experience
  host, the build and release steps, source ownership and the reference regression steps, each with real paths.
- **FR-A17-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A17-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least these MUST be assessed:
  - the procedural geometry of the region's structures (lathes, sweeps, tubes and capsules beyond the existing plane,
    cube and sphere generators);
  - the structure graph (ids, names, systems, layers, parents, neighbours) with a GPU-free model and tests;
  - layered visibility, with isolate and ghost (translucent, depth-sorted) drawing;
  - picking a structure by touch, and selection highlighting;
  - labels anchored to structures, with overlap handling and the accessible structure list as their alternative;
  - search over names and synonyms;
  - the orbit and zoom camera with framing on a selection;
  - lighting and materials per system;
  - factual text with citations, provenance and a not-reviewed label;
  - the bundled offline content pack with its schema and versioning;
  - the saved view or state;
  - triangle, draw-call and label budgets per quality level;
  - resize and context-loss rebuild.
- **FR-A17-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record the
  phase-start commit, the reference pin and the results.
- **FR-A17-005**: The one app MUST build for testing with Interactive Anatomy absent; the experience package check MUST pass;
  Interactive Anatomy MUST stay unregistered and unavailable (its targets come with A17-P01's first rules).
- **FR-A17-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, no diagnostic,
    treatment, accuracy or certification claim, no patient or personal health data, no purchased, generated, scanned
    or hand-modelled meshes, textures or images, and no unsourced or unlicensed content text;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: medical
    mistakes misinform, purchased assets carry redistribution rights, and 3D labels overlap;
  - a stop/go decision with reasons.
- **FR-A17-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A17-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A17-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A17-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A17-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A17-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (16 registered experiences, none of them A17).
- **SC-A17-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A17-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides 3D pieces used by earlier experiences (Molecular Explorer, Solar System Explorer, Infinite
  Geometry):
  - meshes and their generators, the mesh renderer with lighting and premultiplied alpha, and the orbit camera with its
    bounds;
  - ray intersection with triangles, spheres and boxes;
  - quality tiers, the canvas overlay, accessibility planners, experience storage and document stores with migration.

  The audit confirms each from the code and records what is missing, for example lathe or sweep generators, depth-sorted
  translucency, or anchored labels with overlap handling.
- Anatomy content, the structure graph, copy and the interface are app-local. Generic pieces (for example a lathe
  generator or a label-overlap solver) are assessed for VisualCore ownership.
- Later phases (A17-P01 to A17-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A17-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A17-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A17-005, US3 |
| Review gate: written stop/go decision | FR-A17-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A17-008 |
| Brainstorm capabilities (3D model rendering, textures and materials, camera controls, lighting, labels and overlays) | FR-A17-002 |
| Manual non-goals and risks 1–3 | FR-A17-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork or
  models; no network; no medical claim.
