# Feature Specification: Infinite Geometry — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `039-ig-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A05-P00 (legacy ledger) · ID namespace FR-A05-0##, SC-A05-0##, T-A05-0##

**Input**: User description: archived manual `apps/05-infinite-geometry.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Infinite Geometry (`a05.infinite-geometry`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/InfiniteGeometry`; it never gets a standalone target. The manual's gate "the app can
  compile an empty SwiftUI shell" becomes: the experience's GPU-free domain target and its experience target compile
  with one module test each, and nothing is registered in the app yet (no placeholder is visible to a person).
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker of A01-P00 (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A04; the contract lives in `docs/apps/infinite-geometry/`.
- **Constitution:** 2.1.0 adds the A05 experience rules (commit of this gate).
- **Evidence:** host and simulator only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Infinite Geometry gets a map of what VisualCore already provides for each capability the
experience needs — geometry rendering, shader effects, transformations, camera controls, procedural meshes — with real
files, declared names and package products, each marked available, needs adaptation or missing upstream.

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

The owner sees that the ProjectM reference regression passes before any Infinite Geometry work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The experience's targets exist and compile (Priority: P2)

The engineer has a GPU-free domain target and an experience target that compile and test, so Phase 01 starts by
adding rules, not plumbing — and a person using the app sees nothing new yet.

**Independent Test**: build and test the experience package; check the app's registry and catalog are unchanged.

**Acceptance Scenarios**:

1. **Given** the experiences package, **When** it is tested, **Then** the two new module tests pass with the rest.
2. **Given** the app, **When** its experience registry and catalog are read, **Then** Infinite Geometry is not
   registered and stays unavailable.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Infinite Geometry can proceed, what is missing upstream, and which
VisualCore module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or mesh path were missing, **Then** the decision is "stop" and names
   the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a camera without bounds): marked "requires adaptation" with the
  missing part named.
- **A capability exists in a harness but not in a framework product**: not counted as available.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Infinite Geometry work starts.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A05-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A05-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A05-003**: Every non-available row MUST have a gap entry naming the owning VisualCore module and the phase that
  will build it.
- **FR-A05-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A05-005**: The experience package MUST gain a GPU-free domain target and an experience target with one module
  test each; nothing is registered in the app and the catalog entry stays unavailable.
- **FR-A05-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no imported meshes or textures, no CAD or exactness claims) and a stop/go decision with reasons.
- **FR-A05-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A05-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.
- **Experience targets**: domain target and experience target, each with a module test.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A05-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A05-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A05-004**: The experiences package tests pass on both simulator runtimes, including the 2 new module tests.
- **SC-A05-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A05-006**: Every new test finishes in under 10 seconds.

## Assumptions

- R02-F04 (pipelines, depth targets) and R02-F05 (mesh compiler) are recorded and count as available capabilities.
- Later phases (A05-P01 to A05-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A05-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A05-002, 007, US1 |
| Review gate: compile an empty shell (one-app form) | FR-A05-005, US3 |
| Review gate: written stop/go decision | FR-A05-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A05-008 |
| Brainstorm capabilities (geometry, shaders, transformations, camera, procedural meshes) | FR-A05-002 |
