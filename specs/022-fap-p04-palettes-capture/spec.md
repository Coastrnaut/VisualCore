# Feature Specification: Fluid Art Playground — Phase 04 Interaction and capture UX

**Feature Branch**: `022-fap-p04-palettes-capture` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A02-P04 · ID namespace FR-A02-4##, SC-A02-4##, T-A02-4##

**Input**: User description: archived manual `apps/02-fluid-art-playground.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- Reuse VisualCore first: palettes and the shader palette include, the pinch recognizer, the effect graph's glow, and
  A01's still export path (offscreen render, export geometry, PNG encoding).
- Only generic gaps are added to VisualCore, with tests, docs, the baseline and the ProjectM regression.
- Every gesture has a control alternative.
- Pause, step, reset and the seeded test mode stay in Phase 05.
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing delegation (CLAUDE.md §2), recommended option in each case.

- Q: How does each palette turn dye into color? → A: Dye stays a per-channel amount. The display mode decides how it
  shows:
  - **Ink**: `paper × exp(−2·dye)`, with paper sRGB (0.96, 0.94, 0.88). Splat colors are ink absorptions, so the ink
    looks indigo, sepia, crimson and so on.
  - **Smoke**: background (0.04, 0.04, 0.05), mixed toward near-white by `1 − exp(−1.5·luma(dye))`, with no hue.
    Splat colors are grays from 0.55 to 0.9.
  - **Glowing dye**: black plus clamped dye, followed by VisualCore's bloom (threshold 0.6, intensity 1.2,
    radius 8).

  New splats use the active palette's colors. Dye already on the canvas is shown in the new mode immediately.
- Q: How does pinching interact with painting? → A: VisualCore's `PinchRecognizer` is fed through a `PointerTracker`.
  When a second finger goes down, both fingers' strokes are cancelled (the touch tracker forgets them) and pinch mode
  starts. While pinching, `brushRadius = radius at the start × scale`, clamped to 0.005…0.25. Painting resumes with
  the next touch after all fingers lift. The Adjust panel has a Brush size slider over the same range, shown as a
  percentage of the canvas.
- Q: What size and timing does a capture use? → A: The long edge is 2048 pixels, in the aspect of the canvas, capped
  by the device's maximum render size (A01's `ExportGeometry`). The scene is paused for the offscreen render, so no
  extra step runs. The render uses the same display path, including the glow effect for Glowing dye. The PNG is
  written to a temporary file (the previous capture is deleted) and offered through the share sheet. Errors appear as
  a message.
- Q: How is "every pass writes somewhere else" observed? → A: VisualCore adds a main-actor run observer to
  `FieldPass`. Each run reports the pass label, the output texture or framebuffer and the input textures. It is
  nil in production. The fixture counts runs per frame against the expected list (splats × 2, two advections,
  viscosity copy + 8 when on, divergence, fill, N pressure, gradient, display) and asserts that no input equals the
  output. Effect-graph passes (the glow) use VisualCore's `EffectRenderer` target management, verified in VisualCore's
  own tests (feature 005), and are not field passes.
- Q: Which permission text does capture need? → A: Only `NSPhotoLibraryAddUsageDescription`: "Fluid Art Playground
  saves your captured picture to Photos only when you choose Save Image." The system asks only if the user picks
  Save Image in the share sheet. The isolation check allows exactly this one key.

## User Scenarios & Testing *(mandatory)*

Users: people painting (manual journeys 1–3), VoiceOver and Switch Control users, and people who want to keep or share
a picture.

### User Story 1 - Choose a look: ink, smoke or glowing dye (Priority: P1) 🎯

The user picks one of three palettes. **Ink** shows dark inks spreading on paper. **Smoke** shows soft gray smoke on a
dark background. **Glowing dye** shows saturated colors on black with a gentle glow. Switching palettes changes how the
fluid looks immediately, without restarting the motion.

**Why this priority**: It is version 0.1 feature 04 and the Phase 04 MVP requirement.

**Independent Test**: Render the same field in each palette:
- the three images differ clearly from each other;
- each matches its palette's definition (background tone, ink darkening, smoke brightness, glow spread) at known
  probe points.

Switching palettes keeps the fields (no rebuild).

**Acceptance Scenarios**:

1. **Given** the playground, **When** the user selects Ink, **Then** areas without dye show the paper color, and dye
   darkens it.
2. **Given** Smoke, **When** dye is present, **Then** it appears as lighter gray on a dark background, with no hue.
3. **Given** Glowing dye, **When** a bright splat is present, **Then** the color appears on black and light spreads
   slightly beyond the dye (glow); with Reduce Flashing, the glow never flashes.
4. **Given** any palette, **When** the user switches, **Then** the fluid keeps moving from where it was.

---

### User Story 2 - Pinch to change the brush, or use a control (Priority: P1)

Pinching on the canvas makes the brush larger or smaller. While pinching, the two fingers do not paint. A Brush size
control in the Adjust panel does the same without a gesture, and the size is shown and announced.

**Why this priority**: It is manual journey 1 ("pinch to change brush radius") and the constitution's control
alternative rule.

**Independent Test**: Scripted two-finger events through the playground model change the brush radius in proportion
to the pinch, within the radius bounds, and produce no splats from the pinching fingers. The Brush size control
changes the same value (UI test).

**Acceptance Scenarios**:

1. **Given** a brush, **When** two fingers spread to twice their distance, **Then** the brush radius doubles (clamped
   to the maximum).
2. **Given** a pinch in progress, **When** the fingers move, **Then** no splats are created from them.
3. **Given** VoiceOver, **When** the user adjusts Brush size, **Then** the value and unit are announced and the
   painting uses the new size.

---

### User Story 3 - Capture a still (Priority: P2)

A Capture button saves the current picture as a high-resolution image. The user can share it or save it to Photos.
Capturing does not advance or disturb the simulation.

**Why this priority**: Manual journey 3 ("capture a still") is part of Phase 04's interaction and capture UX, and A01
already provides the shared export path.

**Independent Test**: Capture renders the current dye at the export size through VisualCore's offscreen path:
- the image matches the on-screen look (same palette);
- the simulation step count is unchanged;
- the PNG is valid and opaque.

A UI test reaches the share sheet.

**Acceptance Scenarios**:

1. **Given** a picture, **When** the user taps Capture, **Then** an image of at most the documented size is produced
   in the active palette, and the share sheet offers it.
2. **Given** a capture, **When** it finishes, **Then** the simulation has not taken an extra step, and the picture on
   screen continues unchanged.
3. **Given** a capture failure (for example the size is too large for the device), **When** it happens, **Then** a
   clear message is shown, and the app keeps running.

---

### User Story 4 - Every pass writes somewhere else (Priority: P1)

Over complete frames, with every feature on (splats, viscosity, projection, every palette and the glow), no rendering
pass ever samples the target it writes.

**Why this priority**: It is the manual's Phase 04 regression fixture.

**Independent Test**: A per-run record of field passes (inputs and output) is collected over several frames in every
palette and both storages. Zero runs have an input equal to the output. The run count matches the expected pass list
of the frame.

### Edge Cases

- A pinch that would take the radius beyond its bounds: clamped to 0.005…0.25 of the shorter edge.
- A pinch that starts while one finger is already painting: that finger's stroke ends, and pinching takes over;
  painting resumes on the next touch.
- A capture during an active swipe: the capture uses the picture of the current frame; touches are not dropped.
- Switching to Glowing dye with Reduce Flashing on: the glow stays steady (the flash limiter applies).
- A capture larger than the device allows: refused before any GPU work, with a message.
- Photos permission: only requested by the system share sheet when the user chooses to save, with a disclosed reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A02-401**: The app MUST provide three palettes, Ink, Smoke and Glowing dye. Each is defined by a background
  color, splat colors and a display mode (subtractive ink, monochrome smoke, additive glow). They are stored as
  versioned data and covered by tests.
- **FR-A02-402**: Switching palettes MUST take effect on the next frame without rebuilding the fields. The palette
  choice is available as a picker in the Adjust panel.
- **FR-A02-403**: Glowing dye MUST add a glow through VisualCore's effect graph, honoring Reduce Flashing through
  VisualCore's flash limiter. Other palettes bypass the effect.
- **FR-A02-404**: A two-finger pinch on the canvas MUST scale the brush radius by the pinch scale, within bounds,
  using VisualCore's pinch recognizer. Pinching fingers MUST NOT create splats. A Brush size slider MUST provide the
  same control without a gesture.
- **FR-A02-405**: A Capture control MUST render the current picture offscreen at the documented export size through
  VisualCore's existing export path (no second context), without advancing the simulation, and offer the PNG through
  the system share sheet. Failures are reported clearly.
- **FR-A02-406**: The app MUST declare the Photos add-only usage reason (used only when the user saves from the share
  sheet), and no other permission.
- **FR-A02-407**: VisualCore MUST let callers observe field-pass runs (the inputs and output of each run), with tests,
  docs and the baseline, followed by a passing ProjectM regression. The app's fixture MUST show zero runs that sample
  their output, over complete frames in every palette and both storages.
- **FR-A02-408**: The contract MUST record the reused VisualCore pieces and any new gap. The checks MUST pass, and the
  app MUST stay offline with EGL ownership in the VisualCore host.

### Key Entities

- **Fluid palette** (app): id, name, background color, six splat colors, display mode, glow strength.
- **Brush** (app): the radius in the configuration (existing), changed by pinch or slider.
- **Capture** (app): export size, PNG data, status message.
- **Field pass run** (VisualCore): the pass label, the output target and the input targets of one run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A02-401**: For a fixed test field, the three palette renders differ pairwise by a mean per-pixel difference of
  at least 10% of full scale. Probe points match each palette's definition within 3/255.
- **SC-A02-402**: Scripted pinches change the radius by the pinch scale within 1% (clamped at the bounds), and 0
  splats come from the pinching fingers.
- **SC-A02-403**: A capture at the default size produces an opaque PNG whose palette probes match the on-screen frame.
  The step count is unchanged by the capture.
- **SC-A02-404**: Over 10 frames per palette and storage, with all passes active, 0 field-pass runs sample their own
  output, and the run counts equal the expected pass lists.
- **SC-A02-405**: The UI tests (palette picker, Brush size, Capture to the share sheet) pass on both runtimes, and the
  accessibility audit (default size and XXXL) finds no new issues.
- **SC-A02-406**: API review, documented-API, isolation (with the one allowed usage reason), contract, ProjectM
  regression (7/7) and app tests on both runtimes all pass.

## Assumptions

- Palettes are artistic presets, not color-science claims.
- The palette and brush choices are not persisted in this phase (Phase 05 or 06 adds persistence, if any). They reset
  when the playground opens.
- Pause, single-step, reset and the deterministic seeded test mode are Phase 05 (its MVP).
- The export size reuses A01's geometry rules: a 2048-point long edge by default, capped by the device's maximum
  render size.
- Simulator rendering is not color-calibrated; probe tolerances are relative to the same renderer.

## Traceability

| Source | Covered by |
|---|---|
| v0.1 feature 04 (ink, smoke, glowing-dye palettes) | FR-A02-401–FR-A02-403, SC-A02-401 |
| Manual journey 1 (pinch to change the brush radius) | FR-A02-404, SC-A02-402 |
| Manual journey 2 (switch the dye palette) | FR-A02-402 |
| Manual journey 3 (capture a still) | FR-A02-405, FR-A02-406, SC-A02-403 |
| Manual Phase 04 regression fixture (every ping-pong pass writes to a different target) | FR-A02-407, SC-A02-404 |
| Manual §6 render stage 4 (composite dye with palette and bloom) | FR-A02-401, FR-A02-403 |

## Negative Requirements

- No second renderer, EGL context or ProjectM linkage; no networking; no permission other than Photos add-only via
  the share sheet.
- No flashing glow when Reduce Flashing is on.
- Capture never advances or resets the simulation.
- A gesture never acts without a control alternative.
