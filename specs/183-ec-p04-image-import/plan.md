# Implementation Plan: Effects Composer — Phase 04 Image import

**Branch**: `183-ec-p04-image-import` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

One additive VisualCore API (`RenderTarget.upload(rgba:)`), an ImageIO decoder in the experience that applies the
orientation, converts to sRGB and scales to the limit, the picker control and the presenter's import path with
re-upload after a context loss. Gaps G-IMPORT and U-RGBAUPLOAD close.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/visualcore.md](contracts/visualcore.md), [contracts/import.md](contracts/import.md). Quickstart:
[quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, Swift Testing; ImageIO and CoreGraphics (system frameworks); SwiftUI `PhotosPicker`.
- **Dependencies:** no new product; VisualCoreRendering gains one method.
- **Testing:** the VisualCoreRendering package on sim-27.2; the API baseline; the reference regression in two chunks;
  `EffectsComposerCoreTests` and `EffectsComposerExperienceTests`; the app build; the runner.
- **Constraints:** additive VisualCore change only; no permission; nothing stored.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| II | PASS: a generic upload goes into VisualCore with docs, tests, baseline and the reference regression |
| II-a | PASS: the reference regression runs after the change |
| III | PASS: decoding on the CPU off the main actor; uploads only in the host's context |
| VIII | PASS: the system picker only; no read permission; the picture is not stored |
| A25 colour | PASS: profiles converted to sRGB at decode |

Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUObjects.swift                   modify  RenderTarget.upload(rgba:)
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ByteUploadTests.swift           new
Packages/VisualCoreRendering/visualcore-public-api.txt; Packages/VisualCoreRendering/README.md; Packages/VisualCore/README.md   modify
Packages/ExperiencesCreative/EffectsComposer/Experience/ImageImport.swift                                   new     decode, ImportedPicture, ImportRefusal
Packages/ExperiencesCreative/EffectsComposer/Experience/{PreviewRenderer,ComposerPresenter,ECControls}.swift modify  picture source, import path, controls
Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/{ImageImportTests,PictureSourceTests,ImportFixtures}.swift new
docs/apps/effects-composer/visualcore-contract.json (G-IMPORT, U-RGBAUPLOAD closed) modify
```

- **Lifecycle:** the decoded bytes live in the presenter; `setup` (also after a rebuild) uploads them; teardown releases
  the target, never the bytes.
- **Migration:** none. **Rollback:** revert the commits (the VisualCore addition is additive).

## Parallel work

- **Agent V:** the VisualCore upload, its tests, the baseline and READMEs.
- **Agent I:** ImageImport, its fixtures and tests (pure CPU).
- **Agent P:** the presenter, renderer and controls integration, after V and I.
- **Lead:** the reference regression, the contract, runs and commits.
