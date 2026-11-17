# Feature Specification: Ambient Clock — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `130-ac-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A18-P00 (legacy ledger) · ID namespace FR-A18-0##, SC-A18-0##, T-A18-0##

**Input**: User description: archived manual `apps/18-ambient-clock.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Ambient Clock (`a18.ambient-clock`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/AmbientClock` (Auto-Creator.md §16 layout). It never gets a standalone target, bundle
  identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met
  by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A17. The contract lives in `docs/apps/ambient-clock/`.
- **Visuals are code:** every theme is a shader, field, particle or SDF drawing. Typography uses system fonts.
- **Constitution:** 2.14.0 adds the A18 experience rules (committed at the start of this gate, `84b3b311`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Ambient Clock gets a map of what VisualCore already provides. It covers each capability
the experience needs (shader backgrounds, animation, typography integration, scene transitions, configuration and
presets) and each version 0.1 feature. Every entry has real files, declared names and package products, and is
marked available, requires adaptation, or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Ambient Clock work, and the starting commit is
recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Ambient Clock absent. Phase 01
then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Ambient Clock is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Ambient Clock can proceed, what is missing upstream, and which module will
own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable text-over-shader path were missing, **Then** the
   decision is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a full-screen shader scene but no text drawn in the GPU path):
  marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's palette or overlay):
  not counted as available; reuse needs it in VisualCore first.
- **Thermal load and OLED burn-in** (the manual's risk 1): the audit records the frame-rate, dimming and drift pieces
  that exist and assigns the screen-care rules to a phase.
- **Time correctness** (the manual's risk 2): the audit records how the date enters an experience deterministically
  and where locale, calendar, time-zone and day changes come from; no simulated clock reaches production.
- **Weather** (the manual's risk 3): kept out of version 0.1; no location or network.
- **Keeping the screen awake:** the audit records whether VisualCore or the app offers a keep-awake request, and the
  scan rules that refuse `isIdleTimerDisabled` in other experiences.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A18-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (full-screen shaders, fields, palettes, particles, text overlays), the experience
  host, the build and release steps, source ownership and the reference regression steps, each with real paths.
- **FR-A18-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A18-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - locale-aware time and date formatting (12/24 hours, seconds) with an injectable date for determinism;
  - updates on foreground return, time-zone, daylight-saving, locale and significant time changes;
  - four procedural themes with quality and motion controls;
  - readable typography over the theme (contrast, Dynamic Type, VoiceOver);
  - the theme editor with saveable favourites and their schema;
  - night mode (brightness, red shift, lower frame rate) and the motion-reduction option;
  - screen care (pixel drift, dimming) and the keep-awake policy;
  - scene transitions between themes;
  - frame and particle budgets per quality level;
  - resize and context-loss rebuild.
- **FR-A18-004**: The ProjectM reference regression MUST run in two chunks and pass. A baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A18-005**: The one app MUST build for testing with Ambient Clock absent. The experience package check MUST pass.
  Ambient Clock MUST stay unregistered and unavailable; its targets come with A18-P01's first rules.
- **FR-A18-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, location or weather,
    no simulated clock in production, no screen-on guarantee, no background rendering, and no purchased, generated
    or photographic images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: thermal load
    and burn-in, time correctness, and weather permissions;
  - a stop/go decision with reasons.
- **FR-A18-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A18-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A18-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A18-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A18-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A18-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (17 registered experiences, none of them A18).
- **SC-A18-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A18-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides the 2D pieces earlier experiences used (Generative Art Studio, Fluid Art Playground, Fractal
  Explorer, Simulation Lab): full-screen shader scenes, fields, palettes, parameters, quality tiers, the canvas overlay,
  accessibility planners and experience storage. The audit confirms each from the code and records what is missing.
- The clock's layouts, themes, copy and interface are app-local; generic pieces (for example a deterministic
  clock source or a screen-care drift) are assessed for VisualCore ownership.
- Later phases (A18-P01 to A18-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A18-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A18-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A18-005, US3 |
| Review gate: written stop/go decision | FR-A18-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A18-008 |
| Brainstorm capabilities (shader backgrounds, animation, typography integration, scene transitions, configuration and presets) | FR-A18-002 |
| Manual non-goals and risks 1–3 | FR-A18-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no claim beyond the system clock's accuracy.
