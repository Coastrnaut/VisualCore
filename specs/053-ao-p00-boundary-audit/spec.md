# Feature Specification: Audio Odyssey — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `053-ao-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A07-P00 (legacy ledger) · ID namespace FR-A07-0##, SC-A07-0##, T-A07-0##

**Input**: User description: archived manual `apps/07-audio-odyssey.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Audio Odyssey (`a07.audio-odyssey`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/AudioOdyssey` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with Adapter/,
  ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target. The manual's gate "the app can
  compile an empty SwiftUI shell" is met by the one app itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A06;
  the contract lives in `docs/apps/audio-odyssey/`.
- **Constitution:** 2.3.0 adds the A07 experience rules (committed at the start of this gate).
- **Evidence:** host and simulator only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Audio Odyssey gets a map of what VisualCore already provides for each capability the
experience needs — 3D scene rendering, camera systems, audio feature integration, procedural environments, animation
and transitions — with real files, declared names and package products, each marked available, requires adaptation
or upstream gap. The audio machinery that A06 built (sources, analysis, mapping, quality tiers) is shown as reused,
not rebuilt.

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

The owner sees that the ProjectM reference regression passes before any Audio Odyssey work, and the starting commit
is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Audio Odyssey absent, so
Phase 01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Audio Odyssey is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Audio Odyssey can proceed, what is missing upstream, and which
VisualCore module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable audio path were missing, **Then** the decision is
   "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a perspective camera without a rail, or depth meshes without
  streaming segments): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example A06's scenes or A05's meshes) but not in a
  framework product: not counted as available; reuse needs it moved into VisualCore first.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Audio Odyssey work starts.
- **Long journeys and coordinate precision**: recorded as a gap or rule for the camera-rail owner (origin rebasing),
  not solved here.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A07-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A07-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence; the audio products built for A06 MUST appear as the evidence for audio input and analysis.
- **FR-A07-003**: Every non-available row MUST have a gap entry naming the owning VisualCore module and the phase that
  will build it; at least the camera rail with comfort limits, the streaming tunnel/terrain segments and the bounded
  segment pool with world-origin rebasing MUST be assessed.
- **FR-A07-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A07-005**: The one app MUST build for testing with Audio Odyssey absent; the experience package check MUST
  pass; Audio Odyssey MUST stay unregistered and unavailable (its targets come with A07-P01's first rules).
- **FR-A07-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no audio leaving the device, no system-wide capture of other apps' audio, no VR/headset mode, no
  open-world navigation, no claims about relaxation, health or motion-sickness prevention) and a stop/go decision
  with reasons.
- **FR-A07-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A07-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A07-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A07-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A07-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A07-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (6 registered experiences, none of them A07).
- **SC-A07-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A07-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- `VisualCoreAudio` and `VisualCoreAudioDSP` are real products since A06 (sources, permission, session recovery,
  ring buffer, FFT, bands, onsets, smoothing, mapping, quality tiers); Audio Odyssey reuses them.
- Camera rails, streaming procedural segments and origin rebasing are expected upstream gaps; the audit confirms or
  refutes this from the code.
- Later phases (A07-P01 to A07-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A07-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A07-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A07-005, US3 |
| Review gate: written stop/go decision | FR-A07-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A07-008 |
| Brainstorm capabilities (3D scene rendering, camera systems, audio feature integration, procedural environments, animation and transitions) | FR-A07-002 |
| Manual non-goals (system audio capture, VR, open world) and risks (comfort, streaming stalls, precision) | FR-A07-003, 006 |
