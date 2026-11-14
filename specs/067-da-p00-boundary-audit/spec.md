# Feature Specification: Digital Aquarium — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `067-da-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A09-P00 (legacy ledger) · ID namespace FR-A09-0##, SC-A09-0##, T-A09-0##

**Input**: User description: archived manual `apps/09-digital-aquarium.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Digital Aquarium (`a09.digital-aquarium`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/DigitalAquarium` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with
  Adapter/, ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target. The manual's gate
  "the app can compile an empty SwiftUI shell" is met by the one app itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A08;
  the contract lives in `docs/apps/digital-aquarium/`.
- **Constitution:** 2.5.0 adds the A09 experience rules (committed at the start of this gate).
- **Evidence:** host and simulator only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Digital Aquarium gets a map of what VisualCore already provides for each capability the
experience needs — sprite and object systems, animation, procedural environments, particles, scene management and
touch interaction — with real files, declared names and package products, each marked available, requires adaptation
or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Digital Aquarium work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Digital Aquarium absent, so
Phase 01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Digital Aquarium is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Digital Aquarium can proceed, what is missing upstream, and which
VisualCore module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable drawing path were missing, **Then** the decision is
   "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example particles without depth layers, or polygons without per-species
  shape animation): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example A04's particle editor or A07's tunnel pieces)
  but not in a framework product: not counted as available; reuse needs it moved into VisualCore first.
- **Many independent fish** (the manual's draw-overhead risk): the audit records whether shapes batch into one draw
  and what bounds exist; it does not measure performance.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Digital Aquarium work starts.
- **Realism and wellbeing claims:** recorded as a rule (illustrative display, no animal-care, health or sleep
  claims), not solved here.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A09-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A09-002**: The contract MUST hold a capability matrix covering the six brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A09-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least bounded steering with a neighbour search (schools), swim animation of
  procedural fish shapes, depth layers, bubbles and caustics, tap-to-feed and decoration placement, habitat
  persistence and the ambient low-motion mode with dimming MUST be assessed.
- **FR-A09-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A09-005**: The one app MUST build for testing with Digital Aquarium absent; the experience package check MUST
  pass; Digital Aquarium MUST stay unregistered and unavailable (its targets come with A09-P01's first rules).
- **FR-A09-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no purchased, generated or hand-made artwork, no creature economy, no claims of realistic animal
  behaviour, animal-care guidance, health, relaxation or sleep benefits) and a stop/go decision with reasons.
- **FR-A09-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A09-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A09-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (6) and version 0.1
  features (6) trace to matrix rows.
- **SC-A09-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A09-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A09-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (8 registered experiences, none of them A09).
- **SC-A09-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A09-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides the seeded simulation clock, a particle system and renderer, 2D primitives (rect, circle, line,
  polygon, polyline) drawn in one batch, gestures, effects passes, experience storage and quality tiers; the audit
  confirms each from the code.
- Bounded steering with a neighbour search and water effects (caustics) are expected gaps; the audit names owners.
- Later phases (A09-P01 to A09-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A09-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A09-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A09-005, US3 |
| Review gate: written stop/go decision | FR-A09-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A09-008 |
| Brainstorm capabilities (sprite and object systems, animation, procedural environments, particles, scene management, touch interaction) | FR-A09-002 |
| Manual non-goals (ecosystem simulator, creature economy, online aquarium) and risks (asset licensing, draw overhead, erratic motion) | FR-A09-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network.
