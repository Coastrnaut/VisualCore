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
  compile an empty SwiftUI shell" is met by the one app itself (see Clarifications); nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker of A01-P00 (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A04; the contract lives in `docs/apps/infinite-geometry/`.
- **Constitution:** 2.1.0 adds the A05 experience rules (commit of this gate).
- **Evidence:** host and simulator only.

## Clarifications

### Session 2026-11-13

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`scripts/check_experience_packages.py` reports `EXTRA_TARGET` for any experience target of an `Experiences*` package
that belongs to no registered experience and requires registered experiences to have all four targets and to be linked
by the app; `LauncherModel.shown` lists only available experiences; the A05 constitution commit is `427eea32`; the
reference submodule is pinned at `d93edd1`.

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: The one app is the shell: this phase
  proves the VisualCore app still builds for testing with Infinite Geometry absent (not registered, not linked, catalog
  unavailable). The experience's targets are created in A05-P01 together with its first real domain rules, because an
  empty target would be an `EXTRA_TARGET` finding and registering an empty experience would be a placeholder (both
  forbidden).
- Q: Which commit is the phase start? → A: The A05 constitution commit `427eea32`; the no-change diff of
  `Packages` and `External` is taken from it.
- Q: Where are the contract and its readable view? → A: `docs/apps/infinite-geometry/visualcore-contract.json` and the
  generated `visualcore-contract.md`, checked by `scripts/check_app_contract.py --app infinite-geometry`; the baseline
  in `docs/apps/infinite-geometry/regression-baseline.md`.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least one
  test that exercises it; a harness-only or Showcase-only implementation is "requires adaptation" at best.
- Q: Which build steps does the inventory count? → A: The named steps of `python3 scripts/release_check.py --list` at the
  time of the check, recorded with the count.

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

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Infinite Geometry absent, so
Phase 01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Infinite Geometry is neither registered nor available.

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
- **FR-A05-005**: The one app MUST build for testing with Infinite Geometry absent; the experience package check MUST
  pass; Infinite Geometry MUST stay unregistered and unavailable (its targets come with A05-P01's first rules).
- **FR-A05-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no imported meshes or textures, no CAD or exactness claims) and a stop/go decision with reasons.
- **FR-A05-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A05-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A05-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A05-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A05-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (4 registered experiences, none of them A05).
- **SC-A05-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A05-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- R02-F04 (pipelines, depth targets) and R02-F05 (mesh compiler) are recorded and count as available capabilities.
- Later phases (A05-P01 to A05-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A05-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A05-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A05-005, US3 |
| Review gate: written stop/go decision | FR-A05-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A05-008 |
| Brainstorm capabilities (geometry, shaders, transformations, camera, procedural meshes) | FR-A05-002 |
