# Feature Specification: Generative Art Studio — Phase 05 Polish, accessibility and regression

**Feature Branch**: `016-gas-p05-polish-a11y` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A01-P05 · ID namespace FR-A01-5##, SC-A01-5##, T-A01-5##

**Input**: User description: archived manual `apps/01-generative-art-studio.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation). Canonical override: the reusable accessibility settings model (gap G-UI, matrix row M10)
is built in VisualCore (constitution Principle II). The manual's Phase 05 regression fixture is required: background
and foreground recreation restores the scene without stale GL handles. Evidence is host and simulator only. The
manual's Phase 05 MVP line (still export) was delivered in Phase 04 and is regression-checked here.

## User Scenarios & Testing *(mandatory)*

Users: people who rely on Reduce Motion, flashing-light sensitivity settings, VoiceOver or large text (manual §2
feature 06, §3 accessibility), plus app developers who reuse the VisualCore accessibility settings.

### User Story 1 - Motion and flashing follow my settings (Priority: P1) 🎯

Animation slows when the system's Reduce Motion is on, and sudden brightness changes are limited when the system's
flashing-light setting is on. In the app's Settings, each one can be set to follow the system, or be forced on or
off. A change takes effect in an open scene without reopening it.

**Why this priority**: It is version 0.1 feature 06 and the manual's accessibility promise for animated art.

**Independent Test**: With each combination of system setting and app choice, the effective setting is as defined.
An open scene changes its rate and flash limiting within one frame of the change. The choice persists across
relaunch.

**Acceptance Scenarios**:

1. **Given** the app choice "System" and system Reduce Motion on, **When** a scene plays, **Then** it plays at the
   reduced rate. Turning the system setting off restores the normal rate without reopening the scene.
2. **Given** the app choice "On" for Reduce Flashing, **When** a scene has a sudden brightness change, **Then** the
   change shown per frame is limited.
3. **Given** a choice was made, **When** the app relaunches, **Then** the choice is kept.

---

### User Story 2 - The canvas and controls work with VoiceOver and large text (Priority: P1)

VoiceOver describes the live canvas: family, preset or palette, seed, and whether it is playing. Every screen
(gallery, scene, controls, export, library, settings) passes the system accessibility audit, at default text size
and at the largest accessibility text size.

**Why this priority**: It is the manual's App UI and accessibility verification row (Dynamic Type and VoiceOver
fallback).

**Independent Test**: An automated accessibility audit reports no issues on each screen at both text sizes. The
canvas description changes when the composition or the play state changes.

**Acceptance Scenarios**:

1. **Given** a scene, **When** VoiceOver focuses the canvas, **Then** it hears the family, palette, seed and play
   state. After a palette change it hears the new palette.
2. **Given** the largest accessibility text size, **When** each screen is shown, **Then** text is not clipped and
   controls remain reachable.

---

### User Story 3 - Scenes survive backgrounding and context loss (Priority: P1)

Leaving the app and coming back, or a graphics context loss, restores the same image. No stale graphics objects are
used, nothing leaks, and export still works afterwards.

**Why this priority**: It is the manual's Phase 05 regression fixture and the risk "stale GL handles after
recreation".

**Independent Test**: For every family: a background/foreground cycle and a context recreation both give the same
image at the same time as before (within tolerance). The host reports 0 stale-object uses after recovery and 0
leaks. An export after recovery matches an export before.

**Acceptance Scenarios**:

1. **Given** a scene at time t, **When** the app is backgrounded and foregrounded, **Then** it shows time t of the
   same composition and continues.
2. **Given** a context loss, **When** the scene recovers, **Then** the image at time t matches the image before the
   loss, and resources are recreated without leaks.

---

### User Story 4 - Reusable accessibility settings in VisualCore (Priority: P2)

Other apps reuse the settings model. It combines system Reduce Motion and the flashing-light setting with an app
choice (System, On or Off) into effective values, and it observes system changes.

**Independent Test**: Host tests cover all 9 combinations per setting. Simulator tests show the observer reflects
the system values. Docs and the API baseline are updated, and the ProjectM regression passes.

**Acceptance Scenarios**:

1. **Given** the new API, **When** the API review runs, **Then** it is documented and the baseline is updated.
2. **Given** the VisualCore change, **When** the reference regression runs, **Then** it passes (7/7).

### Edge Cases

- The system setting changes while a scene is open, or while the app is in the background: the new value applies
  on return, without reopening the scene.
- Reduce Flashing is turned on during playback: limiting begins without a visible jump, and exports are not limited.
  An export is a still image, so no flashing can occur.
- The app choice "Off" overrides a system setting that is on. This is the user's explicit choice, and the Settings
  screen says so.
- A context loss while the export sheet is open: the next export works.
- Largest text with long palette or preset names: the text wraps instead of truncating meaningfully.
- Background → foreground repeated 20 times: no growth in live resources.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A01-501**: The app MUST provide Settings with Reduce Motion and Reduce Flashing, each set to System (default),
  On or Off. Choices persist on the device only.
- **FR-A01-502**: The effective Reduce Motion MUST slow scene playback to the reduced rate. The effective Reduce
  Flashing MUST limit per-frame brightness change in the live scene through the VisualCore flash limiter. Both apply
  to an open scene within one frame of a change.
- **FR-A01-503**: The live canvas MUST expose an accessibility description with the family, preset (or "custom"),
  palette, seed and play state, updated when any of them changes.
- **FR-A01-504**: Every app screen MUST pass the automated accessibility audit at the default text size and at the
  largest accessibility text size. Each issue found is fixed or documented with its reason.
- **FR-A01-505**: Background/foreground cycles and context recreation MUST restore every family at the same scene
  time, with 0 stale-object uses after recovery and 0 leaks. Export MUST work after recovery.
- **FR-A01-506**: The reusable accessibility settings MUST live in VisualCore:
  - a pure settings model that resolves system values and the app choice into effective values;
  - an observer of system Reduce Motion and the flashing-light setting.

  They need tests, docs and an API-baseline update, and the ProjectM regression MUST pass afterwards.
- **FR-A01-507**: The regression suite MUST pass on both runtimes. It covers the Phase 01–04 render, controls,
  library and export tests.
- **FR-A01-508**: The VisualCore contract MUST be updated: G-UI closed and M10 available. The contract check MUST
  pass. The app MUST stay offline, request no new permission and link no ProjectM module.

### Key Entities

- **Accessibility choice** (VisualCore): System, On or Off, per setting.
- **Accessibility settings** (VisualCore): system values plus app choices, giving effective Reduce Motion and Reduce
  Flashing.
- **Canvas description** (app): family, preset, palette, seed and play state, rendered as one sentence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A01-501**: All 9 system × choice combinations per setting resolve as defined (18 cases). An open scene's rate
  and flash limiting follow a change within one frame. Choices survive relaunch.
- **SC-A01-502**: With Reduce Flashing effective, a full-screen black↔white alternation is shown with a per-frame
  brightness change of at most the limiter's bound. Without it, the change is unlimited.
- **SC-A01-503**: The accessibility audit reports 0 unresolved issues on 6 screens at 2 text sizes on both runtimes.
- **SC-A01-504**: For 4 families, after background/foreground and after context recreation, the image at the same
  time matches the earlier one (mean difference ≤ 1/255). Stale uses after recovery = 0, and leaks = 0. 20 cycles
  give no growth in live resources.
- **SC-A01-505**: The API review, documented-API check, contract check, ProjectM regression (7/7) and the full app
  test suites on both runtimes all pass.

## Assumptions

- Quality presets (manual Settings row "quality") need device measurements and are out of scope until campaign II.
  Settings shows only accessibility choices and an About line.
- The system flashing-light setting is read through the public accessibility API. Simulators report it off unless
  the test overrides the system value through the model's injectable source.
- Human review of VoiceOver on real devices is campaign II work. Here the automated audit and labels are the
  evidence.
