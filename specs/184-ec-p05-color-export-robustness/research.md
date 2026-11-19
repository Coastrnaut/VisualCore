# Research: Effects Composer — Phase 05

- **R1 Linear light per effect.** Decision: grade, blur and vignette decode with `vc_srgbDecode` and encode with
  `vc_srgbEncode`; distort and posterize work on stored values. Rationale: exposure, averaging and darkening are
  physical light operations; distort only moves samples and posterize's levels are meant to be even to the eye.
  Alternative: everything linear (rejected: posterize bands crowd into the shadows).
- **R2 Grade pivot in linear light.** Decision: the contrast pivot becomes 0.18 (linear mid-grey, encoded 0.46);
  exposure multiplies linear light; saturation keeps Rec. 709 luma, now on linear values. Rationale: the 0.5 pivot was
  an encoded-value choice. Defaults (exposure 0, contrast 1, saturation 1) stay the identity.
- **R3 What intermediates hold.** Decision: every target holds sRGB-encoded values; `.rgba16f` intermediates only add
  precision. Rationale: one meaning for every target, so stored-value effects need no conversion and the copy and
  present passes stay unchanged. Alternative: linear intermediates (rejected: each stored-value effect would need two
  conversions and `.rgba8` fallbacks would band in the shadows).
- **R4 CPU reference precision.** Decision: `EffectReference.applyChain(_:to:storage:)` quantises between nodes to
  8 bits (`.byte`) or to half-float (`.half`, Swift `Float16`), matching the GPU path. Rationale: posterize after a blur
  could flip a level between precisions; matching the storage keeps the 2/255 tolerance honest.
- **R5 CPU sRGB functions.** Decision: the core writes the exact piecewise sRGB formula (the one of `vc/color.glsl`);
  VisualCore has none for the CPU (clarification facts).
- **R6 Export target.** Decision: a fresh `.rgba8` target of the source's size, drawn with the same plan and programs
  as the preview, read back with `readPixels()`, then released. Rationale: the regression fixture compares a separate
  draw with the preview, which proves the export does not just copy the preview.
- **R7 Encoding off the main actor.** Decision: `StillImageEncoder.data` runs in `Task.detached`; the file is written
  atomically. Rationale: encoding a 2,048-pixel picture is CPU work that must not stall frames.
- **R8 Interruption seam.** Decision: an internal `beforeReadBack` closure on the renderer, set only by tests, runs
  between the draw and the read-back. Rationale: a real context loss cannot be timed from a test otherwise.
- **R9 Memory warning.** Decision: the presenter observes `UIApplication.didReceiveMemoryWarningNotification` on an
  injected `NotificationCenter` and calls `trimPools()` through the renderer. Rationale: held targets stay alive, so
  only idle ones go and the preview is unchanged.
- **R10 As built: export file lifetime (T-A25-512, T-A25-513, 2026-11-19).** The host has one `teardown` for a
  context rebuild and for closing, so teardown keeps a written export and its share item (only a request not yet
  drawn fails as interrupted). The export folder is removed before the next export and when the presenter is
  released (`isolated deinit`), which happens when the experience closes. `ShareLink` reports no completion, so a
  shared file is not removed right after sharing; it stays until the next export or the close.
