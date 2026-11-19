# Implementation Plan: Effects Composer — Phase 05 Colour, still export and robustness

**Branch**: `184-ec-p05-color-export-robustness` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

Linear-light boundaries for grade, blur and vignette with high-precision intermediates where the device allows them;
a full-size still export to PNG, JPEG or HEIC validated before drawing and handed to the share sheet; recovery from a
context loss during editing and export, a size change and a memory warning; a device measurement plan. Gaps G-COLOR,
G-EXPORT and G-ROBUST close. No VisualCore change.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/color.md](contracts/color.md), [contracts/export.md](contracts/export.md),
[contracts/robustness.md](contracts/robustness.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, Swift Testing; GLSL ES 3.00 through `FieldPass`; ImageIO for decoding exports in tests;
  CoreTransferable and SwiftUI `ShareLink`.
- **VisualCore APIs used (audited, clarification facts):** `FieldPass` with `#include "vc/color.glsl"`
  (`vc_srgbDecode`, `vc_srgbEncode`); `FloatRenderSupport.detect(in:)`, `storageFormat(forceFallback:)`;
  `ResourceRegistry.acquireTarget(width:height:format:)`, `recycle`, `release`, `trimPools()`, `maxTextureSize`;
  `RenderTarget.readPixels()`; `StillImage(width:height:bottomUpRGBA:)`; `StillImageEncoder.isAvailable(_:)`,
  `data(_:format:quality:)`; `StillImageFormat`; `ExportGeometry(maxEdge:maxPixels:)`, `effectiveMaxEdge`,
  `maxPixels`; `RenderHost.recreateContext()` (tests).
- **Dependencies:** no new product; the experience target already depends on VisualCoreScenes and VisualCoreRendering.
- **Testing:** `EffectsComposerCoreTests`, `EffectsComposerExperienceTests` on sim-27.2; the app build and unit
  tests; the runner on iOS 27.2. No VisualCore change, so no reference regression is required for this phase.
- **Performance:** a 2,048 × 2,048 picture holds source and result (16 MiB each, `.rgba8`), two intermediates
  (32 MiB each in `.rgba16f`) and an export result (16 MiB) at most: 112 MiB, bounded by `PreviewPool.maxTargets`
  raised from 4 to 5 for the export target. Device timing is the device plan's.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I (one app) | PASS: inside experience A25 only |
| II (VisualCore reuse) | PASS: only audited VisualCore APIs; no change to VisualCore |
| III (context ownership) | PASS: every GPU object comes from the host's registry inside its callbacks; encoding runs on CPU bytes off the main actor |
| IV (visuals are code) | PASS: no assets; fixtures generated in code |
| VIII (privacy) | PASS: the file goes only to the share sheet the person opens; no library permission; temporary files removed |
| XIII (docs/tests) | PASS: `///` on every new public name; tests per contract |
| A25 colour | PASS: source and export sRGB-encoded; linear-light effects decode and encode |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/EffectsComposer/Core/ColorDomain.swift                 new     ColorDomain, EffectID.colorDomain, SRGB transfer (CPU)
Packages/ExperiencesCreative/EffectsComposer/Core/EffectReference.swift             modify  linear-light effects; storage precision (byte or half)
Packages/ExperiencesCreative/EffectsComposer/Core/EffectPrograms.swift              modify  #include "vc/color.glsl"; decode/encode in grade, blur, vignette
Packages/ExperiencesCreative/EffectsComposer/CoreTests/ColorDomainTests.swift       new
Packages/ExperiencesCreative/EffectsComposer/Experience/StillExport.swift           new     ExportRefusal, StillExport.validate/encode/write, EffectsExportFile
Packages/ExperiencesCreative/EffectsComposer/Experience/PreviewRenderer.swift       modify  intermediate format, draw(into:), exportPicture, trimIdle, seam
Packages/ExperiencesCreative/EffectsComposer/Experience/ComposerPresenter.swift     modify  export(format:), status words, memory warning, file cleanup
Packages/ExperiencesCreative/EffectsComposer/Experience/ECControls.swift            modify  export-png/-jpeg/-heic buttons, share link
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ColorPathTests.swift   new
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/StillExportTests.swift new
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/RobustnessTests.swift  new
docs/apps/effects-composer/device-plan.md                                           new     D1–D3 {device}
docs/apps/effects-composer/visualcore-contract.json; README.md                      modify  G-COLOR, G-EXPORT, G-ROBUST closed
```

Dependency direction stays Core → VisualCore pure products; Experience → Core, VisualCoreRendering, VisualCoreScenes,
VisualCoreExperienceHost, VisualCoreUI. The core stays free of UI, GPU and clocks.

- **Lifecycle:** the intermediate format is chosen in `setup` (after every rebuild) from `FloatRenderSupport`; an
  export draws inside the host's frame callback on the main actor, reads back, releases its target, then encodes off
  the main actor; a context loss between draw and read-back makes the read-back empty and the export fails as
  interrupted. Teardown of the experience removes the temporary export folder.
- **Data schemas:** none persisted; the chain document (schema 1) is unchanged because colour domains are fixed per
  effect, not stored.
- **Migration:** none. **Rollback:** revert the commits; no stored format changes.

## Parallel work

- **Agent C:** ColorDomain, EffectReference and EffectPrograms with ColorDomainTests (core files only).
- **Agent X:** StillExport.swift and the encoding/refusal parts of StillExportTests (no renderer change).
- **Agent R:** renderer, presenter and controls integration with ColorPathTests, the renderer parts of
  StillExportTests and RobustnessTests, after C and X.
- **Lead:** the device plan, contract, READMEs, runs, ticks and commits.
