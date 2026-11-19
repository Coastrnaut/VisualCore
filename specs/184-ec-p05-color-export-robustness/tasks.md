# Tasks: Effects Composer — Phase 05 Colour, still export and robustness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/color.md](contracts/color.md), [contracts/export.md](contracts/export.md),
[contracts/robustness.md](contracts/robustness.md), [quickstart.md](quickstart.md). Gate A25-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A25-P05 --timeout 595 --name <check> -- <command>`.
- **Commits:** one per task, no trailers. **Checks:** read every exit before ticking.
- **Scope:** iOS 27 for the experience; no VisualCore change, so no reference regression.
- **Rollback:** revert the commits; nothing stored changes.

## Phase 1: Setup

- [X] T-A25-501 Baseline: `--name baseline` runs both Effects Composer test targets on sim-27.2 at the start commit — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.baseline.json (exit 0)
  (`specs/184-ec-p05-color-export-robustness/quickstart.md` step 1) and must exit 0

## Phase 2: Story 2 — colours behave like light (P1, foundational for export)

- [X] T-A25-502 [P] [US2] Create `Packages/ExperiencesCreative/EffectsComposer/Core/ColorDomain.swift`: `ColorDomain` — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.ec-color-export.json (exit 0; ColorDomainTests 5 passed; ReferenceTests spot values updated for linear light; ProgramRenderTests max 0/255, distort 1/255)
  (`.linear`, `.stored`), `EffectID.colorDomain` (grade, blur, vignette → `.linear`; distort, posterize → `.stored`),
  `SRGB.decode`/`encode` (the exact piecewise formula of `vc/color.glsl`), `ReferenceStorage` (`.byte`, `.half`);
  update `Packages/ExperiencesCreative/EffectsComposer/Core/EffectReference.swift` (linear effects decode, compute,
  encode; grade pivot 0.18; `applyChain(_:to:storage:)` quantising between nodes) and
  `Packages/ExperiencesCreative/EffectsComposer/Core/EffectPrograms.swift` (`#include "vc/color.glsl"`; decode/encode
  in grade, blur, vignette); tests in `Packages/ExperiencesCreative/EffectsComposer/CoreTests/ColorDomainTests.swift`
  (transfer round trip over 256 values within 1/255; domains; grade defaults are the identity; mid-grey exposure +1
  equals the linear computation); update every existing core or experience test whose expected values assumed
  encoded-value grade, blur or vignette, recording each change in the test's header (analyze U1)
- [ ] T-A25-503 [US2] Renderer intermediates in
  `Packages/ExperiencesCreative/EffectsComposer/Experience/PreviewRenderer.swift`: slots use
  `FloatRenderSupport.detect(in:).storageFormat(forceFallback: forceStandardPrecision)` chosen in `setup`; source and
  result stay `.rgba8`; `PreviewPool.acquire` takes a format; tests in
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ColorPathTests.swift` (identity ramp within 1/255 on
  both paths; mid-grey exposure within 2/255 of the CPU linear reference; blur radius 2 across a black/white edge gives
  188 ± 3; every effect on the test picture within 2/255 (distort 4/255) of `EffectReference` with the path's storage)

## Phase 3: Story 1 — export the finished picture (P1) 🎯

- [ ] T-A25-504 [P] [US1] Create `Packages/ExperiencesCreative/EffectsComposer/Experience/StillExport.swift`:
  `ExportRefusal` (codes and messages of data-model.md verbatim), `StillExport.validate(width:height:format:
  maxTextureSize:available:)` (`ExportGeometry(maxEdge: min(maxTextureSize, 2048))`), `StillExport.write(_:format:in:)`
  (quality 0.9, off the main actor, atomic, file `Look <W>x<H>.<ext>`), `EffectsExportFile` (`Transferable`); tests in
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/StillExportTests.swift` for validation and writing
  (each format decodes at its size tagged sRGB; refusals; file name)
- [ ] T-A25-505 [US1] Integrate per contracts/export.md: `PreviewRenderer.exportPicture(_:)` (fresh `.rgba8` target,
  `beforeReadBack` seam, `.interrupted`, `.memory`, target released; `PreviewPool.maxTargets` 5),
  `ComposerPresenter.export(format:)` (status "Exporting…"/"Exported", one at a time, earlier file removed, folder
  removed on close), `ECControls` (`export-png`, `export-jpeg`, `export-heic`, `share`); add to
  `StillExportTests.swift`: the regression fixture (96 × 64 gradient, grade+blur+vignette; PNG within 1/255 of the
  preview read-back everywhere; JPEG and HEIC within a mean of 3/255), refusals before drawing (render count unchanged,
  no file), a second export removes the first file, a call while exporting is ignored, an all-disabled chain exports
  the source exactly, an export started while a picture is being read uses the shown picture, a full pool refuses
  as `a25.export-memory` and the preview keeps working, and closing the experience removes the export folder
  (analyze C1–C3)

## Phase 4: Story 3 — nothing breaks (P2)

- [ ] T-A25-506 [US3] `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/RobustnessTests.swift` and the
  presenter's memory-warning observer (injected `NotificationCenter`, `trimPools()`): 10 rebuilds byte-identical; an
  export interrupted by `recreateContext` in `beforeReadBack` fails as `a25.export-interrupted` with no file and the
  next export succeeds; two framebuffer sizes letterbox the same result; a memory warning leaves the preview
  byte-identical; the interruption test stands for a background move during export (analyze C4)
- [X] T-A25-507 [US3] Write `docs/apps/effects-composer/device-campaign.md`: D1, D2, D3 rows tagged {device} (after — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.device-campaign.json (exit 0; 7 rows pending device campaign)
  ImplementationLock-100; D3 stays on iPadOS 26.5): peak memory with a 2,048-pixel picture and eight effects ≤ 200 MiB,
  preview frame time while editing ≤ 33 ms, export time per format ≤ 3 s, recovery after backgrounding

## Phase 5: Evidence and close

- [ ] T-A25-508 Review checkpoint: `--name ec-ios27`, `documented-api`, `isolation`, `core-purity` (commands of
  quickstart.md steps 1–2)
- [ ] T-A25-509 Contract: G-COLOR, G-EXPORT, G-ROBUST closed by "A25-P05" with notes on rows M11, M23, M24, M25, M36
  (`--name contract`); `docs/apps/effects-composer/README.md`
- [ ] T-A25-510 `--name catalog`, `experience-packages`, `script-tests`; `xcodegen generate --spec project.yml`, then
  `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`;
  `--name verify-27`
- [ ] T-A25-511 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A25-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

501 → {502, 504}; 502 → 503; {503, 504} → 505 → 506 → 508; 507 any time; 508 → 509 → 510 → 511.

## Parallel examples

- **Agent C:** 502. **Agent X:** 504. **Agent R:** 503, 505, 506 after C and X. **Lead:** 501, 507–511.

## Implementation strategy

MVP is story 1 on top of story 2's colour path: export depends on the final colour behaviour, so colour lands first.
