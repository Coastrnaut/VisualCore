# Feature Specification: Neon Arcade — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `074-na-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A10-P00 (legacy ledger) · ID namespace FR-A10-0##, SC-A10-0##, T-A10-0##

**Input**: User description: archived manual `apps/10-neon-arcade.md` §9 Phase 00 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Neon Arcade (`a10.neon-arcade`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/NeonArcade` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with Adapter/,
  ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target. The manual's gate "the app can
  compile an empty SwiftUI shell" is met by the one app itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A09;
  the contract lives in `docs/apps/neon-arcade/`.
- **Constitution:** 2.6.0 adds the A10 experience rules (committed at the start of this gate).
- **Evidence:** host and simulator only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Neon Arcade gets a map of what VisualCore already provides for each capability the
experience needs — 2D rendering, particles, animation, input handling, collision visualization and scene transitions
— with real files, declared names and package products, each marked available, requires adaptation or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Neon Arcade work, and the starting commit is
recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Neon Arcade absent, so Phase 01
starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Neon Arcade is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Neon Arcade can proceed, what is missing upstream, and which VisualCore
module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable drawing path were missing, **Then** the decision is
   "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example shapes without hit shapes, or bloom without per-object glow
  limits): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example A04's particle editor or A07's tunnel
  collision) but not in a framework product: not counted as available; reuse needs it moved into VisualCore first.
- **Many hazards and particles at once** (the manual's draw and readability risks): the audit records whether shapes
  batch into one draw and what bounds exist; it does not measure performance.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Neon Arcade work starts.
- **Skill or health claims and monetization:** recorded as rules (no benefit claims, no loot boxes, no online
  leaderboards), not solved here.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A10-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A10-002**: The contract MUST hold a capability matrix covering the six brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A10-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least the deterministic fixed-step game loop, authoritative collision between the
  player, hazards and orbs, start/pause/restart/game-over flows with local scores, touch steering with configurable
  sensitivity, glow and particle feedback constrained by readability, and sound and haptic toggles with reduced-flash
  controls MUST be assessed.
- **FR-A10-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A10-005**: The one app MUST build for testing with Neon Arcade absent; the experience package check MUST pass;
  Neon Arcade MUST stay unregistered and unavailable (its targets come with A10-P01's first rules).
- **FR-A10-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no online leaderboards or user-generated levels, no loot boxes or purchasable currency, no purchased,
  generated or hand-made artwork or recorded sound, no claims of skill, reflex, cognitive or health benefits), the
  license rule (every palette, pattern and shader bundled later records its author and license; only original
  content) and a stop/go decision with reasons.
- **FR-A10-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A10-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A10-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (6) and version 0.1
  features (6) trace to matrix rows.
- **SC-A10-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A10-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A10-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (9 registered experiences, none of them A10).
- **SC-A10-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A10-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides the seeded fixed-step clock and runner, a particle system and renderer, 2D primitives drawn in
  one batch with hit testing, gestures, effects passes (including bloom), haptic and announcement planners,
  experience storage and quality tiers; the audit confirms each from the code.
- Game-specific rules (lanes, hazards, orbs, waves, scoring) are app-local; generic collision and game-loop pieces are
  assessed for VisualCore ownership.
- Later phases (A10-P01 to A10-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A10-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A10-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A10-005, US3 |
| Review gate: written stop/go decision | FR-A10-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A10-008 |
| Brainstorm capabilities (2D rendering, particles, animation, input handling, collision visualization, scene transitions) | FR-A10-002 |
| Manual non-goals (whole arcade collection, online leaderboards, user-generated levels, loot boxes) | FR-A10-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network.
