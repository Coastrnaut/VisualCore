# Feature Specification: Oscilloscope Studio — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `060-os-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A08-P00 (legacy ledger) · ID namespace FR-A08-0##, SC-A08-0##, T-A08-0##

**Input**: User description: archived manual `apps/08-oscilloscope-studio.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Oscilloscope Studio (`a08.oscilloscope-studio`) is an experience of the VisualCore app,
  built in `Packages/ExperiencesCreative/OscilloscopeStudio` (Auto-Creator.md §16 layout: Core, CoreTests, Experience
  with Adapter/, ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target. The manual's
  gate "the app can compile an empty SwiftUI shell" is met by the one app itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A07;
  the contract lives in `docs/apps/oscilloscope-studio/`.
- **Constitution:** 2.4.0 adds the A08 experience rules (committed at the start of this gate).
- **Evidence:** host and simulator only.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`scripts/check_experience_packages.py` reports `EXTRA_TARGET` for any experience target of an `Experiences*` package
that belongs to no registered experience; `LauncherModel.shown` lists only available experiences; the A08 constitution
commit is `0cdd2ca0` and the A08-P00 specify commit `6fdb5ca9` (the phase start: the no-change diff of `Packages` and
`External` is taken from it); the reference submodule is pinned at `d93edd1`. Every shared source writes mono samples
(`AudioSource.swift:35` "A producer of mono `Float` audio samples"; the microphone and file sources mix down);
`DemoSignal.Mode` offers `sequence`, `tone440`, `tone1k` and `silence` only; `SpectrumAnalyzer` gives magnitudes in dB
with a −200 dB floor and `expectedBin(frequency:sampleRate:size:)`; the scene graph's only line is a two-point
`.line(Vec2, Vec2, width:)` drawn by `PrimitiveRenderer`. The contract is
`docs/apps/oscilloscope-studio/visualcore-contract.json` with the generated `visualcore-contract.md`, checked by
`scripts/check_app_contract.py --app oscilloscope-studio`; the baseline is
`docs/apps/oscilloscope-studio/regression-baseline.md`; the build steps are the named steps of
`python3 scripts/release_check.py --list` at the time of the check, with the count.

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: The one app is the shell: this phase
  proves the VisualCore app still builds for testing with Oscilloscope Studio absent (not registered, not linked,
  catalog unavailable). The experience's targets are created in A08-P01 with its first real domain rules, because an
  empty target would be an `EXTRA_TARGET` finding and registering an empty experience would be a placeholder.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least one
  test that exercises it; an implementation that exists only inside another experience (A06, A07) or a harness is
  "requires adaptation" at best.
- Q: Which package holds Oscilloscope Studio? → A: `Packages/ExperiencesCreative/OscilloscopeStudio` (Auto-Creator.md
  §16), as A06 and A07 did in `ExperiencesCreative`; no new package is created.
- Q: Does Oscilloscope Studio need a new permission or privacy answer? → A: No. `VisualCoreAudio` and
  `VisualCoreAudioDSP` are real products since A06 and the app's `NSMicrophoneUsageDescription` exists (`project.yml`,
  checked by `BundleTests`); Oscilloscope Studio reuses the shared permission and string, so audio rows cite those
  products and the app's privacy answers do not change.
- Q: Which scope pieces exist, and who owns the missing ones? → A: Mono sources, the ring buffer, the spectrum in dB
  and the demo tones exist. Gaps and owners, following the manual's phases (P01 audio fixture and acquisition, P02
  timebase/trigger waveform renderer, P03 spectrum and XY): a demo generator with square and sweep signals →
  `VisualCoreAudioDSP` and two-channel (stereo) capture → `VisualCoreAudio` (A08-P01); trigger detection with a
  timebase window and min/max display decimation → `VisualCoreAudioDSP`, and bounded multi-point trace strips built in
  `VisualCoreScenes` and drawn through `VisualCoreRendering` (A08-P02); spectrum frequency and dBFS annotation and the
  XY mode stay app-local (A08-P03); the spoken measurement description is app-local (A08-P05). The audit confirms or
  corrects each from the code (owner phases corrected to the manual's phase titles during implementation, 2026-11-14).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Oscilloscope Studio gets a map of what VisualCore already provides for each capability
the experience needs — line rendering, waveform buffers, real-time data visualization, shader effects and multiple
visualization modes — with real files, declared names and package products, each marked available, requires
adaptation or upstream gap. The audio machinery that A06 and A07 use (sources, permission, ring buffer, spectrum
analysis, demo signals) is shown as reused, not rebuilt.

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

The owner sees that the ProjectM reference regression passes before any Oscilloscope Studio work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Oscilloscope Studio absent, so
Phase 01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Oscilloscope Studio is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Oscilloscope Studio can proceed, what is missing upstream, and which
VisualCore module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable audio path were missing, **Then** the decision is
   "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a spectrum in dB without bin-frequency labelling, or line
  primitives without thick, bounded trace strips): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example A06's analysis display or A07's announcements)
  but not in a framework product: not counted as available; reuse needs it moved into VisualCore first.
- **Stereo input:** the shared sources may deliver mono only (mixed down); the XY view's needs are recorded as a gap or
  as "disabled and marked for mono sources", never assumed.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Oscilloscope Studio work starts.
- **Units and calibration:** recorded as a rule (relative dBFS, no calibrated volts or SPL), not solved here.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A08-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A08-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence; the shared audio products MUST appear as the evidence for audio input and analysis.
- **FR-A08-003**: Every non-available row MUST have a gap entry naming the owning VisualCore module and the phase that
  will build it; at least trigger detection with a timebase window, display decimation (no more points than pixels),
  bounded trace strips, square and sweep demo signals, stereo (two-channel) input for the XY view and the spectrum's
  frequency and level annotation MUST be assessed.
- **FR-A08-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A08-005**: The one app MUST build for testing with Oscilloscope Studio absent; the experience package check
  MUST pass; Oscilloscope Studio MUST stay unregistered and unavailable (its targets come with A08-P01's first rules).
- **FR-A08-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no audio leaving the device, no system-wide capture of other apps' audio, no microphone monitoring to
  the speaker, no claims of calibrated, certified, laboratory or medical accuracy) and a stop/go decision with
  reasons.
- **FR-A08-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A08-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A08-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A08-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A08-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A08-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (7 registered experiences, none of them A08).
- **SC-A08-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A08-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- `VisualCoreAudio` and `VisualCoreAudioDSP` are real products since A06 (sources, permission, session recovery,
  ring buffer, spectrum analysis, demo signals, level meter); Oscilloscope Studio reuses them.
- Trigger and timebase, display decimation, square and sweep demo signals, multi-point trace strips and two-channel
  input are expected upstream gaps (see Clarifications for the owners); the audit confirms or corrects this from the
  code.
- Later phases (A08-P01 to A08-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A08-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A08-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A08-005, US3 |
| Review gate: written stop/go decision | FR-A08-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A08-008 |
| Brainstorm capabilities (line rendering, waveform buffers, real-time data visualization, shader effects, multiple visualization modes) | FR-A08-002 |
| Manual non-goals (certified measurement, system audio interception, lab/medical accuracy) and validity risks (units, clipping, latency, routing, calibration) | FR-A08-003, 006 |
