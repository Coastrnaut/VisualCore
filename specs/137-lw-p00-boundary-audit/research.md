# Research: A19-P00 (feature 137)

## Facts (verified in code, 2026-11-17)

The facts of the clarification session hold. VisualCore provides an offscreen render at any size on the host's own
context with read-back and a size limit (`RenderHost.renderOffscreen`, `maxRenderSize`, `maxOffscreenPixels`), an
sRGB PNG encoder, export geometry with aspect presets, render targets, GPU budgets, temporary folders, experience
storage and the experience's still renderer. It has no JPEG or HEIC encoder, no colour space but sRGB, no video
encoding, no tiling, no device-size catalog, no export job with progress, and no still at a chosen time.

## Decisions

- **D1 Scope:** audit only. The one app is the shell.
- **D2 Matrix scope:** the five brainstorm capabilities (offscreen rendering, high-resolution rendering, effects and
  compositing, frame capture, export pipelines) and the six version 0.1 features:
  - curated procedural backgrounds and colour presets;
  - iPhone and iPad canvas templates and crop guides;
  - still-image export with a verified colour profile;
  - optional short video export after feasibility;
  - export progress, cancellation, error recovery and local history;
  - instructions for applying an exported image by hand.

  Cross-cutting rows cover context loss and resize, quality tiers, accessibility, persistence with migration, bounded
  resources, permissions and truthful claims.
- **D3 Availability rule:** clarification 2.
- **D4 Gap owners** (the manual's phases):

  | Gaps | Phase |
  |---|---|
  | The project model, canvas templates and their provenance, export requests and results; the video feasibility decision (G-VIDEO) | A19-P01 |
  | The offscreen still renderer at output size and time (G-STILLTIME, `VisualCoreExperienceHost`); JPEG and HEIC with a verified sRGB profile (G-ENCODE, `VisualCoreRendering`); the procedural scenes | A19-P02 |
  | Project and preset editing, crop and safe-area guides, the help text (G-HELP) | A19-P03 |
  | Save and share through the share sheet with the permission word (G-SAVE); the export job with progress, cancellation and cleanup (G-EXPORTJOB); the history (G-HISTORY) | A19-P04 |
  | Resolution, colour and heat device tests | A19-P05 |
  | Release | A19-P06 |
- **D5 Permissions:** clarification 4. Saving to Photos uses the share sheet and the existing add-only string; no
  PhotoKit call, no read access.
- **D6 Sizes:** clarification 5. No tiling in version 0.1; a size that does not fit is refused before allocation and
  offered at the largest size that fits.
- **Alternatives considered:**
  - PhotoKit with add-only authorization (rejected: the share sheet covers saving without a PhotoKit call and keeps
    one permission path for the app);
  - tiled rendering for sizes over `maxRenderSize` (rejected for 0.1: the device limits cover phone and tablet screen
    sizes, and tiling needs sub-rectangle projection in every scene);
  - Display P3 output (rejected: the renderer draws 8-bit sRGB, so a P3 tag would claim more than the pixels hold).
