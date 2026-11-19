# Feature Specification: Effects Composer — Phase 05 Colour, still export and robustness

**Feature Branch**: `184-ec-p05-color-export-robustness` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P05 (legacy ledger) · ID namespace FR-A25-5##, SC-A25-5##, T-A25-5##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation): "Implement color, memory and device robustness for Effects Composer; scope only the
smallest vertical slice that proves the feature, with domain tests, validated render behavior, and documented
VisualCore contracts."

Canonical overrides:
- **Phase gates (manual §9 Phase 05), binding:**
  - MVP: still export with dimension and format validation;
  - regression fixture: a full-size export matches the preview's parameters within colour and resampling tolerances;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-EXPORT, G-COLOR and G-ROBUST of `docs/apps/effects-composer/visualcore-contract.json`. The
  release work (G-RELEASE) is A25-P06.
- **No VisualCore change is planned:** the export, encoding, float-target and pool machinery already exist (A25-P00
  audit); a missing piece found later becomes a recorded upstream task.
- **Device work:** measurements of memory, frame pacing and export time on real devices are written as a plan tagged
  {device} and run only after ImplementationLock-100.
- **Privacy:** the exported file goes only where the person sends it with the system share sheet; nothing is saved to
  the photo library without that choice; nothing leaves the device otherwise.

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Preview today:** every pass target is a pooled `.rgba8` target of the source's size (`PreviewPool.acquire`); the
  effects work on stored values (A25-P01/P02 specs); render targets sample with `GL_LINEAR`.
- **VisualCore:** `FieldPass` resolves `#include` against the VisualCore includes, which hold `vc/color.glsl` with
  `vc_srgbEncode` and `vc_srgbDecode`; `FloatRenderSupport.detect(in:)` and `storageFormat(forceFallback:)` choose
  `.rgba16f` or `.rgba8`; `RenderTarget.readPixels()` returns `[]` for a stale or released target;
  `ResourceRegistry.trimPools()` frees every pooled, unused target; `StillImageEncoder.isAvailable(_:)` and
  `data(_:format:quality:)` write PNG, JPEG and HEIC tagged sRGB with alpha forced opaque; `ExportGeometry(maxEdge:
  maxPixels:)` caps the edge at 8,192 and the pixels at 64,000,000. No CPU sRGB transfer function exists in VisualCore.
- **Platform:** Living Wallpapers hands a written file to `ShareLink` through a `Transferable` with a
  `FileRepresentation` (`WallpaperExportFile`); no photo-library permission is involved.

- Q: Which effects work on linear light, and what do intermediate pictures hold? → A: grade, blur and vignette decode
  their input with `vc_srgbDecode` and encode their output with `vc_srgbEncode`; distort (a resampling) and posterize
  (perceptual levels) work on stored values. Every target holds sRGB-encoded values, so the two precision paths differ
  only in precision: the ping-pong intermediates are `.rgba16f` where `FloatRenderSupport` reports it renderable and
  `.rgba8` otherwise (a `forceFallback` switch for tests); the source and the result stay `.rgba8`. `EffectReference`
  (the CPU reference in the core) applies the same transfer functions, written in the core with the exact piecewise
  sRGB formula.
- Q: How does export work, and what is validated? → A: `export` offers inline PNG, JPEG and HEIC buttons
  (`export-png`, `export-jpeg`, `export-heic`; inline, never a system menu over the live canvas, lesson of A23-P05).
  The size is the source's. Before drawing, the request is refused as `a25.export-format-unavailable` ("This format
  cannot be written here.") when `StillImageEncoder.isAvailable` is false and as `a25.export-too-large` ("This
  picture is too large to export.") when the size exceeds `ExportGeometry(maxEdge: min(maxTextureSize, 2048))`. The
  renderer draws the chain into a fresh export result target, reads it back and checks the read is complete; the
  bytes are encoded at quality 0.9 off the main thread and written to `tmp/EffectsComposer/Look <W>x<H>.<ext>`; the
  status reads "Exporting…" and then "Exported"; a `share` link (`ShareLink` with an `EffectsExportFile`
  `Transferable`) appears while the file exists. A second export while one runs is ignored; the earlier file is
  removed before a new export and when the experience closes.
- Q: How is the regression fixture built? → A: A generated 96 × 64 gradient imported through the normal path with the
  chain grade, blur, vignette; the PNG export decoded with ImageIO equals the preview's result read-back at every
  pixel within 1/255, and JPEG and HEIC are within a mean absolute difference of 3/255 over all channels.
- Q: How are interruptions handled and tested? → A: A context loss during export is detected by an empty read-back
  or a refused draw and reported as `a25.export-interrupted` ("The export was interrupted. Try again."), writing
  nothing; tests trigger it through a renderer seam called between drawing and reading back, where they call
  `recreateContext`. Not enough graphics memory for the export target is `a25.export-memory` ("There is not enough
  memory to export this picture."). A memory warning (`UIApplication.didReceiveMemoryWarningNotification`, observed
  through an injectable `NotificationCenter`) calls `ResourceRegistry.trimPools()`; held targets stay, so the preview
  is unchanged. A size change letterboxes the unchanged result into the new view.
- Q: What is written for the devices? → A: `docs/apps/effects-composer/device-plan.md`: for D1, D2 and D3 ({device},
  after ImplementationLock-100; D3 stays on iPadOS 26.5) the peak memory of a 2,048-pixel picture with eight effects,
  the preview frame time while editing, the export time per format and recovery after backgrounding, each with the
  limit it must meet.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Export the finished picture (Priority: P1)

A person who has built a look exports the processed picture as a still file at the picture's full size and shares it
with the system share sheet.

**Why this priority**: export is the manual's MVP requirement for this phase and the end of journey 3.

**Independent Test**: build a chain, export as each format, decode the file and compare it with the preview.

**Acceptance Scenarios**:

1. **Given** a chain on a picture, **When** the person exports as PNG, **Then** a file of the picture's size is
   written whose pixels equal the preview's within 1/255.
2. **Given** the same chain, **When** the person exports as JPEG or HEIC, **Then** the file decodes to the picture's
   size and its mean difference from the preview is within the lossy tolerance.
3. **Given** a format this system cannot write or a size above the limits, **When** export is asked, **Then** it is
   refused with a named message before any drawing, and no file is written.
4. **Given** a written export, **When** the person shares it or starts another export, **Then** the earlier temporary
   file is removed.

---

### User Story 2 - Colours behave like light (Priority: P1)

Effects that brighten, blur or darken a picture work on light values, so a blur of a black and white edge does not
darken and an exposure change looks like more light; an empty chain leaves the picture exactly as it was.

**Why this priority**: the manual names colour robustness as this phase's deliverable and the audit's colour
boundaries (G-COLOR) are due here.

**Independent Test**: draw a generated colour ramp and a mid-grey through identity and single-effect chains and
compare with reference values computed on the CPU.

**Acceptance Scenarios**:

1. **Given** an empty or all-disabled chain, **When** drawn, **Then** a generated ramp of all 256 code values comes
   back within one code value, both with high-precision and with standard-precision intermediate pictures.
2. **Given** an exposure change on mid-grey, **When** drawn, **Then** the result matches a reference computed in
   linear light within 2/255.
3. **Given** a blur across a hard black and white edge, **When** drawn, **Then** the edge's middle value matches the
   linear-light average (about 188 of 255), not the encoded average (128).

---

### User Story 3 - Nothing breaks when the system interrupts (Priority: P2)

The preview and the export survive a lost graphics context, a change of size and a low-memory warning.

**Why this priority**: robustness is the phase's title; these are the manual's §13 risks 2 and 3.

**Independent Test**: rebuild the context, resize and send a memory warning in the middle of editing and of export.

**Acceptance Scenarios**:

1. **Given** a chain on an imported picture, **When** the context is rebuilt, **Then** the next preview is
   byte-identical to the one before.
2. **Given** an export in progress, **When** the context is lost before it finishes, **Then** the export reports a
   named failure, no file is left, and the next export succeeds.
3. **Given** a preview, **When** the view changes size, **Then** the next frame is drawn at the new size and the
   processed picture itself is unchanged.
4. **Given** a low-memory warning, **When** it arrives, **Then** idle pooled pictures are released and the next
   preview is unchanged.

### Edge Cases

- **Export with every effect disabled:** the file equals the source picture.
- **Export of the built-in test picture:** allowed, at its 256 × 256 size.
- **Export while a picture is being read:** the export uses the picture currently shown.
- **High precision unavailable:** standard-precision intermediates are used and the ramp still round-trips.
- **A repeated tap on export while one is running:** ignored; one file is written.
- **Not enough graphics memory for the export:** refused with a named message; the preview keeps working.
- **The app goes to the background during an export:** a draw already read back is encoded and written; a draw not
  yet read back fails as interrupted when the context is lost.
- **A restored session:** no export file survives; the share link appears only after a new export.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-501**: The experience MUST export the processed picture at the source picture's full size as PNG, JPEG or
  HEIC, tagged sRGB, and hand it to the system share sheet only when the person asks.
- **FR-A25-502**: Before drawing, an export MUST be refused with a named message when the format cannot be written on
  this system or the size exceeds the export limits; a refused export writes nothing.
- **FR-A25-503**: A full-size export MUST match the preview's pixels within 1/255 for PNG and within a stated mean
  tolerance for the lossy formats (regression fixture).
- **FR-A25-504**: Each effect MUST state whether it works on linear light or on stored values; linear-light effects
  decode on read and encode on write, the source and the export stay sRGB-encoded bytes, and intermediate pictures use
  high precision where the device can draw into it and standard precision otherwise.
- **FR-A25-505**: An empty chain MUST reproduce the source within one code value on both precision paths.
- **FR-A25-506**: A context rebuild MUST restore the preview byte for byte from kept state; an export interrupted by a
  context loss MUST report a named failure and leave no file.
- **FR-A25-507**: A size change MUST redraw at the new size; a low-memory warning MUST release idle pooled pictures
  without changing the preview.
- **FR-A25-508**: The temporary export file MUST be removed after sharing or before the next export; at most one export
  runs at a time.
- **FR-A25-509**: Every new public name MUST carry documentation; G-EXPORT, G-COLOR and G-ROBUST MUST be closed with
  evidence; a device measurement plan for D1–D3 MUST be written and tagged {device}.

### Key Entities

- **Export request**: format (PNG, JPEG, HEIC) and quality 0.9; the size is the source's.
- **Export result**: a temporary file with its format and size, or a refusal (`a25.export-format-unavailable`,
  `a25.export-too-large`, `a25.export-memory`) or failure (`a25.export-interrupted`) with a code and message.
- **Colour domain**: per effect, linear light (grade, blur, vignette) or stored values (distort, posterize).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-501**: 3 of 3 formats export a file of the source size; PNG equals the preview within 1/255 at every pixel;
  JPEG and HEIC are within a mean of 3/255.
- **SC-A25-502**: 100% of unavailable formats and over-limit sizes are refused before any drawing, with no file left.
- **SC-A25-503**: An identity chain returns all 256 ramp values within one code value on both precision paths; a
  linear-light blur of a black and white edge gives 188 ± 3 of 255 at the edge.
- **SC-A25-504**: After 10 context rebuilds the preview is byte-identical each time; an interrupted export leaves 0
  files; a memory warning leaves the preview byte-identical.
- **SC-A25-505**: Each unit test finishes in under 10 seconds; each interface journey in under 60 seconds.

## Assumptions

- The preview is computed at the source picture's size (at most 2,048 pixels on its longer edge), so the full-size
  export renders the same chain again at that size; a smaller preview for speed is left to the device measurements.
- The lossy quality is 0.9.
- Test pictures are generated in code.
- The share sheet itself cannot be driven by unit tests; the file it would receive is checked instead.

## Traceability

| Source | Requirement |
|---|---|
| MVP: still export with dimension/format validation (manual §2 feature 05) | FR-A25-501, 502, 508 |
| Regression fixture: full-size export matches preview within colour/resampling tolerances | FR-A25-503 |
| Colour robustness (phase title; audit G-COLOR) | FR-A25-504, 505 |
| Memory and device robustness (manual §13 risks 2, 3; audit G-ROBUST) | FR-A25-506, 507, 509 |
| EGL/context ownership solely in the VisualCore host | FR-A25-506 |
| Contract G-EXPORT, G-COLOR, G-ROBUST | FR-A25-501–509 |

## Negative Requirements

- No saving to the photo library without the person's share-sheet choice; no network; no video or animated export; no
  second renderer; no GPU object outside the VisualCore host; no bundled photograph; no device run before
  ImplementationLock-100.
