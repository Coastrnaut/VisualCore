# Feature Specification: Generative Art Studio — Phase 02 Shader scenes and parameter controls

**Feature Branch**: `013-gas-p02-scene-controls` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: A01-P02 · ID namespace FR-A01-2##, SC-A01-2##, T-A01-2##

**Input**: User description: archived manual `apps/01-generative-art-studio.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation). Canonical override: these reusable pieces are built in VisualCore (constitution
Principle II):
- the scene clock (gap G-CLOCK): VisualCoreSimulation;
- parameter editing state: VisualCoreParameters;
- a generic parameter panel: VisualCoreUI.

Evidence is host and simulator only.

## User Scenarios & Testing *(mandatory)*

Users: casual makers and visual artists (manual §2), plus app developers reusing the VisualCore controls.

### User Story 1 - Adjust a scene with constrained controls and see it immediately (Priority: P1) 🎯

While viewing a scene, the user opens a parameter panel. It lists every parameter of the family, each with its title,
current value and unit, adjustable only within its allowed range. Moving a control updates the live scene on the
next frame. Each parameter can be reset, and so can all of them.

**Why this priority**: It is version 0.1 feature 02 and the manual's Phase 02 MVP gate.

**Independent Test**: Open a family, change a parameter, and see the rendered image change. Resetting returns the
image to the preset's image. The controls cannot leave the range.

**Acceptance Scenarios**:

1. **Given** a family is open, **When** the panel is shown, **Then** it lists every parameter of the family schema in
   order, with title, formatted value and unit, and an accessible adjustable control.
2. **Given** a control, **When** it is moved to its extremes or past them, **Then** the value stays within the
   parameter's range, and logarithmic parameters move by ratio.
3. **Given** a changed parameter, **When** the next frame renders, **Then** the scene reflects the new value (the image
   differs from before the change).
4. **Given** changed parameters, **When** "Reset" (one) or "Reset all" is used, **Then** the values return to the
   preset's resolved values, and the rendered image matches the preset image within tolerance.

---

### User Story 2 - Choose presets, palettes and seeds; control time (Priority: P1)

The user picks another preset of the family, picks a palette, shuffles to a new seed, and pauses, plays or scrubs
time to inspect a moment. Scrubbing to a time while paused always shows the same image for the same composition.

**Why this priority**: Version 0.1 features 03 and 06 (presets, seeds, pause and scrub) and journey 1 (adjust
palette and motion).

**Independent Test**: Select a preset, palette and seed and see each change applied. Pause, scrub to t = 2 s and
render, then repeat; the images are identical.

**Acceptance Scenarios**:

1. **Given** a family with several presets, **When** another preset is chosen, **Then** its seed, palette and values
   are applied and the panel shows them.
2. **Given** any composition, **When** the palette is changed, **Then** only the palette changes. **When** the seed
   is shuffled, **Then** a new seed is applied and the image changes.
3. **Given** a playing scene, **When** paused, **Then** time stops advancing. **When** scrubbed to t, **Then** the
   scene shows time t. **When** played again, **Then** time continues from t.
4. **Given** Reduce Motion is on, **When** a scene plays, **Then** time advances at half speed. Scrubbing and paused
   images are unaffected.

---

### User Story 3 - Corrupt or future compositions are recoverable (Priority: P1)

When a composition handed to the scene screen is corrupt or has a newer schema version, the user sees a clear,
recoverable message and can continue with the family's default preset. Nothing crashes and nothing renders garbage.

**Why this priority**: It is the manual's Phase 02 regression-fixture gate, and it protects Phase 03 (saving).

**Independent Test**: Launch with a corrupt and with a future-version composition. A readable error appears with a
"Use default" action, and choosing it shows the default preset rendering.

**Acceptance Scenarios**:

1. **Given** corrupt composition data, **When** it is opened, **Then** an error says the composition could not be
   read, offers "Use default", and the scene shows the family default after the action.
2. **Given** a composition with a newer schema version, **When** it is opened, **Then** the error names the
   unsupported version and offers the same recovery. The data is not modified.
3. **Given** a valid composition with out-of-range values or an unknown palette, **When** it is opened, **Then** it
   opens with the documented corrections, which are listed as notes, not as an error.

---

### User Story 4 - Reusable controls in VisualCore (Priority: P2)

Other apps reuse three pieces:
- a scene clock (play, pause, scrub, speed, reduced-motion rate);
- parameter-editing state (set, set by slider position, reset one or all, tell whether a value is modified, format
  with its unit);
- a generic SwiftUI parameter panel bound to that state.

**Independent Test**: Package tests for each piece, docs and an API-baseline entry. The ProjectM regression still
passes.

**Acceptance Scenarios**:

1. **Given** the new public API, **When** the public-API review runs, **Then** every declaration is documented and
   the baseline is updated.
2. **Given** the VisualCore changes, **When** the reference regression runs, **Then** it passes (7/7).

### Edge Cases

- A parameter's slider position is non-finite or outside 0–1: it is clamped, never stored as NaN.
- Scrubbing past 120 s or below 0 clamps to 0…120 s. Speed is limited to 0…4×.
- Resetting a parameter that is unchanged is a no-op.
- Changing the palette or seed of the particles family restarts the particle replay from the same time
  (deterministic).
- A shader fails to compile after a parameter change: impossible by construction, since parameters change uniforms
  only and never shader text.
- Opening the panel never creates another render host.
- Rapid control changes (many per frame): only the latest value is applied at the next frame.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A01-201**: The scene screen MUST offer a parameter panel that lists every parameter of the family schema in
  order, with title, formatted value with unit, a control constrained to the range (linear or logarithmic), a
  per-parameter reset and "Reset all".
- **FR-A01-202**: Control changes MUST reach the live scene by the next rendered frame, with no new render host and no
  shader rebuild.
- **FR-A01-203**: The user MUST be able to choose a preset, choose a palette and shuffle the seed. Each choice
  produces a validated composition that the scene applies.
- **FR-A01-204**: The user MUST be able to pause, play and scrub time (0…120 s). A paused scene at time t renders
  deterministically for its composition. Reduce Motion halves the playback rate.
- **FR-A01-205**: Opening composition data MUST classify the outcome:
  - corrupt or unreadable data, or a newer schema version → a recoverable error with a readable reason and a
    "Use default" action;
  - correctable values → open with notes.

  Data is never modified on failure.
- **FR-A01-206**: These reusable pieces MUST live in VisualCore with package tests, public docs and an API-baseline
  update:
  - `SceneClock` in VisualCoreSimulation: play, pause, scrub, speed, reduced-motion rate, deterministic time from
    frame deltas;
  - `ParameterEditor` in VisualCoreParameters: values, normalized set, reset one or all, modified flags, unit
    formatting;
  - `ParameterPanel` in VisualCoreUI: a SwiftUI form bound to the editor, with accessible adjustable controls.

  The ProjectM regression MUST pass afterwards.
- **FR-A01-207**: Controls MUST be accessible: each slider exposes its title as the label and the formatted value
  with unit as the value, supports VoiceOver increment and decrement, has reset buttons with labels, and uses Dynamic
  Type. Play, pause and scrub are labelled.
- **FR-A01-208**: The app MUST stay offline, request no permissions, link no ProjectM module and create no EGL
  objects. Domain logic MUST stay host-testable.
- **FR-A01-209**: The VisualCore contract MUST be updated: G-CLOCK closed, M02 and M10 updated. The contract check
  MUST pass.

### Key Entities

- **SceneClock** (VisualCore): state (playing or paused), time (s), speed (×), reduced-motion factor, bounds.
- **ParameterEditor** (VisualCore): schema, current values, baseline (reset target) values, modified set.
- **Composition editor** (app): current validated composition, notes, recoverable error, the selected family's
  presets and palettes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A01-201**: For every parameter of all 4 families, setting the minimum, maximum, out-of-range and non-finite
  positions keeps values in range (100% of 21 parameters).
- **SC-A01-202**: Changing one parameter by ≥ 25% of its range changes the rendered image (mean ≥ 1/255) for each
  family. Reset all returns the image to the preset image (≥ 99% of channels within 2/255).
- **SC-A01-203**: A paused scene scrubbed to the same time renders identical images twice (max difference 0), for all
  4 families on both runtimes.
- **SC-A01-204**: 3 of 3 failure classes (corrupt, future version, correctable values) produce the specified outcome,
  in domain tests and in a UI test.
- **SC-A01-205**: The public-API review, documented-API check, contract check, ProjectM regression (7/7) and app tests
  on iOS 27.2 and 26.5 all pass.

## Assumptions

- Saving compositions, favorites and duplication are Phase 03, and export is Phase 04. In this phase compositions
  arrive from presets or from launch data (for tests and the recovery path).
- Gestures on the canvas (pan and zoom) are not required by the manual for this phase and are deferred.
- Device performance of live control changes is measured in campaign II only.
