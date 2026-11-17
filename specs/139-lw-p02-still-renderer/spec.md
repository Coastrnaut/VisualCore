# Feature Specification: Living Wallpapers — Phase 02 Offscreen still renderer

**Feature Branch**: `139-lw-p02-still-renderer` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A19-P02 (legacy ledger) · ID namespace FR-A19-2##, SC-A19-2##, T-A19-2##

**Input**: User description: archived manual `apps/19-living-wallpapers.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: iPhone and iPad canvas templates and cropping guides;
  - regression fixture: a cancelled export and a retry leave no orphan temporary GPU resource;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here** (`docs/apps/living-wallpapers/visualcore-contract.json`):
  - G-ENCODE: JPEG and HEIC stills beside PNG, all tagged sRGB, verified by reading the file back
    (`VisualCoreRendering`);
  - G-STILLTIME: the open experience's still rendered at a chosen animation time (`VisualCoreExperienceHost`);
  - G-SCENES: the four curated scenes drawn in code (app-local).
- **Experience A19 inside the one app:** registered as a candidate experience, not a standalone app. Visuals are code:
  every scene is a fragment shader over VisualCore's GLSL library.
- **VisualCore change:** both additions are additive public API with `///` documentation, tests and an API baseline
  update; the reference regression in two chunks runs at X-A19 (owner ruling of 2026-11-14, faster gates).
- Follow `specs/132-ac-p02-overlay-theme`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `StillImageEncoder.pngData` (`VisualCoreRendering/StillImage.swift`) builds an opaque sRGB `CGImage` and writes it
  through `CGImageDestinationCreateWithData`. `OffscreenRenderError` is a public enum with the case `encoding`, and
  adding a case would break exhaustive switches in consumers.
- `ExperienceSession.renderStill(width:height:)` always passes `time: 0` to `RenderHost.renderOffscreen`, and
  `ExperienceHostView` puts it in the environment as `experienceStillRenderer` (`ExperienceHostView.swift:277`).
- `FullScreenShaderScene` sets `u_time` from `fixedTime`, or else from the frame time × `timeScale`.
  `renderOffscreen` passes its `time` as the frame time.
- `ResourceRegistry.stats` (`ResourceLedger.Snapshot`) gives the live count per kind and the live bytes; Audio
  Odyssey's long-session test already compares them. `TemporaryFolder` has `fileCount` and `removeAll()`.
- The planning catalog's design has five regression fixtures, so the content audit requires five manifest fixtures.
  A18's themes are inline fragment sources (`ThemeShaders.swift`).
- The phase starts at `43a6f0ca` (the specify commit).

- Q: What does the encoder addition look like? → A: Additive and source-compatible in `VisualCoreRendering`:
  - `public enum StillImageFormat: String, CaseIterable, Sendable { png, jpeg, heic }` with its uniform type
    identifier;
  - `StillImageEncoder.data(_:format:quality:)`, where quality is 0…1 with a default of 0.9 and is ignored for PNG.
    It writes an opaque `CGImage` tagged sRGB through the same destination path. `pngData` stays and calls it;
  - `StillImageEncoder.isAvailable(_:)`, which is true when the format's identifier is in
    `CGImageDestinationCopyTypeIdentifiers()`. An unavailable format throws `.encoding`. The experience refuses it
    before any rendering, with its own named reason `format-unavailable`.

  Tests read every written file back: the width, the height, the colour space name `kCGColorSpaceSRGB`, and the type
  identifier. JPEG pixels are compared within a tolerance, PNG exactly. HEIC is tested where `isAvailable(.heic)` is
  true, and the test records the result; on the iOS 27.2 simulator it is expected true.
- Q: How does a still get its time? → A: Additive in `VisualCoreExperienceHost`:
  - `ExperienceSession.renderStill(width:height:time:)`; the two-argument form keeps passing 0;
  - `ExperienceStillRenderer` gains `init(timed:)` and `callAsFunction(width:height:time:)`. The existing `init`
    maps to time 0, so existing callers are unchanged;
  - `ExperienceHostView` installs the timed renderer.

  Living Wallpapers' scenes take `u_time` from the frame, scaled by the motion speed. Under Reduce Motion or with
  motion off, `fixedTime` is the chosen animation time, so an export at that time matches the still preview.
- Q: How are the four scenes drawn? → A: One `FullScreenShaderScene` per scene. The inline fragment sources use the
  GLSL library (`vc/noise`, `vc/palette`, `vc/hash`, `vc/sdf`), with uniforms for the four preset colours, the
  scene's parameters and the seed:
  - **level-0:** full detail;
  - **level-1:** fewer octaves and cells, with the pixel block of A18's pattern.

  Equal state and time give identical pixels. The scene and the preset change by recompiling or updating uniforms;
  there is no crossfade in this phase.
- Q: How is the crop frame computed and shown? → A: Pure geometry in the core, so it is testable without the GPU:
  - `CropFrame.fit(template:orientation:canvasWidth:canvasHeight:margin:)` gives the template's rectangle
    aspect-fitted and centred inside the canvas, with a margin of 0.06 of the short canvas edge, plus the three guide
    bands in canvas points;
  - the experience's canvas overlay (SwiftUI, native) draws the frame outline, shades outside it, and marks the
    guide bands. Its accessibility label names the template, the orientation and the pixel size.
- Q: What is an export attempt, and how are cancelling and retrying proven? → A: `StillExport` in the experience,
  on the main actor:
  - **Steps:** plan (the A19-P01 planner, maxEdge = `RenderHost.maxRenderSize`), then render
    (`renderStill(width:height:time:)`), then encode, then verify by reading back, then write one file into
    `TemporaryFolder("LivingWallpapers-Export")`;
  - **Cancelling:** a cancel flag checked after each step, or a failure at any step, removes that attempt's file.
    The render target is released by `renderOffscreen` itself on every path;
  - **The fixture:** in `ExperienceTests`, on the simulator with the real host, the live counts of
    `host.resources.stats` and the folder's `fileCount` are compared before and after:
    - a cancel after render;
    - a cancel after encode;
    - a failure from an oversize plan;
    - a retry at the offered size.

    The live picture still renders afterwards.

  The manifest's five fixtures are `fixture-scene-ink-flow`, `fixture-preset-third`, `fixture-template-ipad-landscape`,
  `fixture-time-set` and `fixture-parameter-changed`. The controls are `scene.select [i]`, `scene.preset [i]`,
  `scene.parameter [index, value]`, `canvas.template [i]`, `canvas.orientation [0|1]`, `scene.time [seconds]`,
  `export.format [i]` and `motion.enabled [0|1]`. Snapshot schema 1.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the background framed for the chosen device (Priority: P1) 🎯

A person picks a scene and a device template and sees the background with the device's frame and its approximate
safe areas drawn over it, in portrait or landscape, so they know what the exported file will contain.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: open the experience with each template and orientation; read the crop frame and the guides the
overlay reports.

**Acceptance Scenarios**:

1. **Given** a template and an orientation, **When** the experience shows the scene, **Then** a frame with the
   template's aspect is fitted inside the canvas and the top, bottom and side guides are marked inside it.
2. **Given** a change of scene, preset, parameter, template or orientation, **Then** the picture and the frame follow
   at once, and the change is a recorded action.

---

### User Story 2 - A still of exactly the chosen size, time and format (Priority: P1)

A person exports the framed background as a PNG, JPEG or HEIC file at the template's exact size, at the animation
moment they chose.

**Why this priority**: the deliverable "offscreen still renderer".

**Independent Test**: export each format at a template size and two animation times; read the files back.

**Acceptance Scenarios**:

1. **Given** a planned export, **When** it runs, **Then** the file reads back at the planned size and colour profile.
2. **Given** two different animation times of a moving scene, **Then** the two stills differ; **Given** the same time
   twice, **Then** they are identical.
3. **Given** a format the device cannot encode, **Then** it is refused with a named reason before any rendering.

---

### User Story 3 - Cancelling or retrying leaves nothing behind (Priority: P1)

A person who cancels an export, or whose export fails and who tries again, ends with no leftover GPU resource and no
leftover temporary file, and the live picture keeps running.

**Why this priority**: the manual's regression fixture.

**Independent Test**: count the live GPU resources and the temporary files before, after a cancelled export, after a
failed export and after a retry.

**Acceptance Scenarios**:

1. **Given** an export cancelled after rendering and before writing, **Then** live GPU resources and temporary files
   equal the counts before the export.
2. **Given** an export that fails (a size the device cannot render), **When** it is retried at a size that fits,
   **Then** the retry succeeds and the counts again equal those before.

### Edge Cases

- **No experience open:** an export is refused with a named reason.
- **A size above the device's limit:** refused before allocation (A19-P01 planner); the offered size is used on retry.
- **Reduce Motion:** the live preview stays still; the export still uses the chosen animation time.
- **Context loss during preview:** the scene rebuilds from its state; the next export works.
- **A template whose aspect is far from the canvas:** the frame letterboxes inside the canvas, never crops the guides.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A19-201**: VisualCore MUST encode a still as PNG, JPEG or HEIC, each opaque and tagged sRGB, refuse a format
  the device cannot encode with a named reason, and report which formats are available.
- **FR-A19-202**: VisualCore MUST render the open experience's still at a chosen animation time on the session's own
  render host; the existing time-0 path keeps its behaviour.
- **FR-A19-203**: The four curated scenes MUST be drawn in code with their presets and parameters, at two quality
  levels, with the same picture for the same state and time.
- **FR-A19-204**: The experience MUST show the chosen template's frame and approximate safe-area guides over the scene
  in both orientations.
- **FR-A19-205**: An export MUST plan, render, encode, verify by reading back, and hand back a file; cancelling or
  failing at any step MUST leave no GPU resource and no temporary file of its own.
- **FR-A19-206**: Every state change MUST be a validated action with a digest, a snapshot and a scenario manifest
  holding the nine standard scenarios and five fixtures; the experience is registered as a candidate.
- **FR-A19-207**: The GPU context stays in the host: the experience makes no GL call and no platform-wallpaper call.

### Key Entities

- **Wallpaper state**: scene, preset, parameters, template, orientation, animation time, format (the A19-P01 project).
- **Crop frame**: the template's rectangle fitted in the canvas and its guide bands.
- **Export attempt**: plan, rendered still, encoded data, verification, temporary file; cancelled, failed or done.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A19-201**: 100% of exported files of each available format read back at the planned size and the sRGB profile.
- **SC-A19-202**: After a cancelled export, a failed export and a retry, the live GPU resource count and the temporary
  file count equal their values before (0 difference each time).
- **SC-A19-203**: For every template and orientation, the drawn frame has the template's aspect within one pixel and
  lies inside the canvas.
- **SC-A19-204**: Every scene at both levels draws a picture that is not blank; equal state and time give identical
  pixels.
- **SC-A19-205**: The VisualCore and rendering package tests and the public API baseline pass; the reference regression
  (7 of 7 steps) runs at X-A19 (owner ruling of 2026-11-14); unit tests run under 10 seconds each.

## Assumptions

- The A19-P01 core (scenes, templates, project, planner, inspection) is used as it is.
- Saving to Photos or Files, progress for long exports, and the history come in A19-P04; the editor in A19-P03.

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 deliverable: offscreen still renderer | FR-A19-202, 205 |
| MVP: iPhone/iPad templates and cropping guides | FR-A19-204, US1 |
| Regression fixture: cancel and retry leave no orphan GPU resource | FR-A19-205, SC-A19-202 |
| Gate: context ownership in the host | FR-A19-207 |
| Contract G-ENCODE, G-STILLTIME, G-SCENES | FR-A19-201–203 |
| Brainstorm: offscreen rendering, high-resolution rendering, frame capture | FR-A19-201, 202, 205 |

## Negative Requirements

- No second renderer or EGL path; no GL call in the experience; no system-wallpaper call; no movie encoding; no
  network; no purchased, generated or photographic image; no saving outside a temporary file in this phase.
