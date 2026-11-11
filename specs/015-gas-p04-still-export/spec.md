# Feature Specification: Generative Art Studio — Phase 04 Offscreen still export

**Feature Branch**: `015-gas-p04-still-export` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: A01-P04 · ID namespace FR-A01-4##, SC-A01-4##, T-A01-4##

**Input**: User description: archived manual `apps/01-generative-art-studio.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation). Canonical override: the reusable offscreen render, readback and image encoding (gap
G-EXPORT) are built in VisualCoreRendering (constitution Principle II). Evidence is host and simulator only. The
manual's Phase 04 MVP line (the versioned document store with favorites and duplication) was delivered in Phase 03
and is regression-checked here.

## User Scenarios & Testing *(mandatory)*

Users: creators who want repeatable exports (manual §2, journey 3), plus app developers reusing the VisualCore
exporter.

### User Story 1 - Export one full-resolution still (Priority: P1) 🎯

From a scene, the user opens Export and chooses a size and an aspect ratio. A preview shows the crop. The app renders
the composition at that exact size, at the current scene time, and offers the image to share or save.

**Why this priority**: It is journey 3 and version 0.1 feature 05.

**Independent Test**: Export at each size and aspect. The file has exactly the chosen pixel dimensions, is opaque,
and is tagged as sRGB. Its content matches an on-screen render of the same composition and time, scaled.

**Acceptance Scenarios**:

1. **Given** a scene, **When** the user exports at a chosen size and aspect, **Then** the image has exactly the chosen
   width and height in pixels.
2. **Given** an export, **When** it is inspected, **Then** it has no transparency and carries an sRGB color profile,
   matching the only options offered.
3. **Given** a paused scene at time t, **When** exported, **Then** the export shows time t of the same composition.
   Exporting twice gives identical images.
4. **Given** a finished export, **When** the user shares it, **Then** the system share sheet offers the image.
   Saving to Photos asks only for add-only access, with a disclosed reason.

---

### User Story 2 - Exports stay within device limits (Priority: P1)

The app never offers or attempts a size the device's renderer cannot produce. An export that fails, for example
because of memory, shows a readable error, and the scene keeps working.

**Why this priority**: It is the manual's risk 3 (large exports can exceed GPU limits).

**Independent Test**: Request a size above the device limit: it is capped or refused with a reason. Force a render
failure: an error appears and the live scene continues.

**Acceptance Scenarios**:

1. **Given** the device's maximum render size, **When** the export options are shown, **Then** no option exceeds it,
   and the largest option is capped to it.
2. **Given** an export that fails, **When** the error appears, **Then** the live scene keeps rendering, and 0 GPU
   resources leak from the attempt.

---

### User Story 3 - Reusable exporter in VisualCore (Priority: P2)

Other apps reuse three operations: render a scene offscreen at any size, read the pixels back in display
orientation, and encode them as an opaque sRGB PNG.

**Independent Test**: Package tests for exact size, orientation, color and opacity of the encoded image; docs and an
API-baseline entry. The ProjectM regression still passes.

**Acceptance Scenarios**:

1. **Given** the new API, **When** the API review runs, **Then** it is documented and the baseline updated.
2. **Given** the VisualCore change, **When** the reference regression runs, **Then** it passes (7/7).

### Edge Cases

- Aspect ratios produce whole, even pixel dimensions, and the long edge equals the chosen size.
- An export is rendered at a higher resolution than the screen. Point-sized content (particles) keeps its on-screen
  proportions.
- An export while playing uses the time at the moment Export was pressed. Playback is paused during the export and
  restored after.
- The app is backgrounded during an export: the export is abandoned without leaks, and a retry works.
- An export larger than the device limit is never attempted.
- A failed share or save is reported by the system, and the export file stays available until the sheet closes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A01-401**: The scene screen MUST offer Export:
  - sizes by long edge: 1080, 2048 and 4096 px, capped to the device's maximum render size;
  - aspect ratios: Square 1:1, Portrait 4:5, Landscape 16:9, Story 9:16;
  - a crop preview for the chosen aspect.
- **FR-A01-402**: An export MUST render the current composition at the exact chosen pixel dimensions, at the scene's
  current time, offscreen through the VisualCore render host, without a second render host or EGL context.
- **FR-A01-403**: Exported images MUST be opaque PNGs tagged with the sRGB color profile. These are the only alpha and
  profile options, shown in the export panel as "Opaque · sRGB".
- **FR-A01-404**: Exporting the same composition and time twice MUST produce identical pixels. An export MUST match an
  on-screen render of the same composition and time when both are scaled to a common size (within tolerance).
- **FR-A01-405**: Exports MUST NOT exceed the device's maximum render size or the memory budget. A failed export MUST
  show a readable error, leave the live scene running and leak 0 GPU resources.
- **FR-A01-406**: Point-sized content MUST keep its on-screen proportions in exports of any size.
- **FR-A01-407**: The finished image MUST be offered through the system share sheet. Saving to Photos uses add-only
  access with a usage description, and no other permission is requested.
- **FR-A01-408**: The reusable pieces MUST live in VisualCoreRendering:
  - offscreen render of a host's scene at a given size and time;
  - readback with display orientation;
  - opaque sRGB PNG encoding;
  - a query of the device maximum render size.

  They need package tests, docs and an API-baseline update, and the ProjectM regression MUST pass afterwards.
- **FR-A01-409**: Export controls MUST be accessible (labels, values, Dynamic Type). The app MUST stay offline and link
  no ProjectM module.
- **FR-A01-410**: The VisualCore contract MUST be updated: G-EXPORT closed and M09 available. The contract check MUST
  pass.

### Key Entities

- **Export job** (app): long-edge size, aspect, the derived pixel width and height, time, format (PNG), alpha (opaque)
  and profile (sRGB).
- **Still image** (VisualCore): width, height, RGBA pixels in display orientation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A01-401**: For all 12 size × aspect combinations (capped by the device limit), exported images have exactly the
  derived dimensions, no alpha channel and an sRGB profile, on both runtimes.
- **SC-A01-402**: Exporting the same composition and time twice gives identical pixels (max difference 0) for all 4
  families.
- **SC-A01-403**: An export downscaled to the on-screen size matches the on-screen render, with mean difference
  ≤ 6/255 (resampling tolerance), for all 4 families.
- **SC-A01-404**: A forced export failure leaves the live scene rendering, with 0 leaked resources.
- **SC-A01-405**: The API review, documented-API check, contract check, ProjectM regression (7/7) and app tests on
  both runtimes all pass, and the Phase 03 library tests still pass.

## Assumptions

- Video export and transparent backgrounds are later-stage ideas (manual §2) and out of scope.
- Library thumbnails can reuse the exporter later. They are not required in this phase.
- Device maximum render sizes are measured on simulators here; real device limits are confirmed in campaign II.
