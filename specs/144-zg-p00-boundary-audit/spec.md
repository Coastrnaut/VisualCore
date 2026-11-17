# Feature Specification: Digital Zen Garden — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `144-zg-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P00 (legacy ledger) · ID namespace FR-A20-0##, SC-A20-0##, T-A20-0##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Digital Zen Garden (`a20.digital-zen-garden`) is an experience of the VisualCore app, built
  in `Packages/ExperiencesCreative/DigitalZenGarden` (Auto-Creator.md §16 layout). It never gets a standalone target,
  bundle identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell"
  is met by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A19. The contract lives in `docs/apps/digital-zen-garden/`.
- **Visuals are code:** sand relief, rake grooves, stones and shadows are procedural; no purchased, generated or
  photographic texture.
- **Constitution:** 2.16.0 adds the A20 experience rules (committed at the start of this gate, `eb1f1233`).
- Follow `specs/137-lw-p00-boundary-audit`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Digital Zen Garden gets a map of what VisualCore already provides. It covers each
capability the experience needs (touch interaction, procedural textures, feedback shaders, animation, save and restore
state) and each version 0.1 feature. Every entry has real files, declared names and package products, and is marked
available, requires adaptation, or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Digital Zen Garden work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's results are recorded for an unchanged tree; the baseline document names the
commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** its two chunks are read for the phase-start tree, **Then** 7 of 7
   steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Digital Zen Garden absent.
Phase 01 then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Digital Zen Garden is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Digital Zen Garden can proceed, what is missing upstream, and which
module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host, touch input or a persistent render target that can be drawn into
   were missing and could not be built over the existing renderer, **Then** the decision is "stop" and names the
   blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example touch input that delivers one position per frame but no coalesced
  samples): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's brush splats, undo or
  named saves): not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **Undo by GPU snapshot** (the manual's risk 1): the audit records that undo replays a command log with checkpoints
  rather than storing texture snapshots.
- **Small screens** (the manual's risk 2): the audit records where touch precision and a brush zoom are owned.
- **Bright effects** (the manual's risk 3): the audit records the quiet defaults (sound and animation off, nothing
  flashes) and where Reduce Motion and Reduce Flashing reach the experience.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (full-screen shaders, fields, persistent and ping-pong render targets, meshes), the
  input path, the experience host, the build and release steps, source ownership and the reference regression steps,
  each with real paths.
- **FR-A20-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A20-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the garden document, strokes, stones and the command log, versioned and validated;
  - touch strokes resampled to uniform spacing with a sample cap, and a brush preview;
  - rake footprints drawn into a persistent sand height target, rebuilt deterministically from the command log;
  - sand relief lighting, stones as procedural shapes, soft shadows;
  - stone placement, rotation, deletion and layer-aware selection with hit testing;
  - undo and redo by command, with checkpoints;
  - named gardens saved and loaded in the experience's storage with caps;
  - the low-stimulation mode (sound and animation off by default), Reduce Motion and Reduce Flashing;
  - native alternatives for every gesture and VoiceOver descriptions;
  - resize, orientation and context-loss rebuild.
- **FR-A20-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A20-005**: The one app MUST build for testing with Digital Zen Garden absent. The experience package check MUST
  pass. Digital Zen Garden MUST stay unregistered and unavailable; its targets come with A20-P01's first rules.
- **FR-A20-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, no private API, no
    granular physics claim, no therapeutic or wellbeing claim, no generative AI content, no engagement loops, and no
    purchased, generated or photographic images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: expensive
    GPU feedback undo, touch precision at small sizes, and bright effects disrupting calm;
  - a stop/go decision with reasons.
- **FR-A20-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A20-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A20-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A20-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A20-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (19 registered experiences, none of them A20).
- **SC-A20-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A20-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the 2D pieces earlier experiences used (Fluid Art Playground's resampled pointer strokes and
  ping-pong fields, Simulation Lab's GPU stepping, Tiny Worlds' meshes, Ambient Clock's cached still frame): the audit
  confirms each from the code and records what is missing.
- The tray, rakes, stones, copy and interface are app-local; generic pieces are assessed for VisualCore ownership.
- Later phases (A20-P01 to A20-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A20-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A20-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A20-005, US3 |
| Review gate: written stop/go decision | FR-A20-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A20-008 |
| Brainstorm capabilities (touch interaction, procedural textures, feedback shaders, animation, save and restore state) | FR-A20-002 |
| Manual non-goals and risks 1–3 | FR-A20-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API.
