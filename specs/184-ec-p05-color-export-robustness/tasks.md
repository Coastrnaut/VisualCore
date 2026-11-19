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
- [X] T-A25-503 [US2] Renderer intermediates in — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.ec-ios27.json (exit 0, 83+49 tests; ColorPathTests identity 0/255 both paths, blur edge 187, every effect within 1/255)
  `Packages/ExperiencesCreative/EffectsComposer/Experience/PreviewRenderer.swift`: slots use
  `FloatRenderSupport.detect(in:).storageFormat(forceFallback: forceStandardPrecision)` chosen in `setup`; source and
  result stay `.rgba8`; `PreviewPool.acquire` takes a format; tests in
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/ColorPathTests.swift` (identity ramp within 1/255 on
  both paths; mid-grey exposure within 2/255 of the CPU linear reference; blur radius 2 across a black/white edge gives
  188 ± 3; every effect on the test picture within 2/255 (distort 4/255) of `EffectReference` with the path's storage)

## Phase 3: Story 1 — export the finished picture (P1) 🎯

- [X] T-A25-504 [P] [US1] Create `Packages/ExperiencesCreative/EffectsComposer/Experience/StillExport.swift`: — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.ec-color-export.json (exit 0; suite StillExport passed, PNG/JPEG/HEIC decode at size tagged sRGB, refusals, file name)
  `ExportRefusal` (codes and messages of data-model.md verbatim), `StillExport.validate(width:height:format:
  maxTextureSize:available:)` (`ExportGeometry(maxEdge: min(maxTextureSize, 2048))`), `StillExport.write(_:format:in:)`
  (quality 0.9, off the main actor, atomic, file `Look <W>x<H>.<ext>`), `EffectsExportFile` (`Transferable`); tests in
  `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/StillExportTests.swift` for validation and writing
  (each format decodes at its size tagged sRGB; refusals; file name)
- [X] T-A25-505 [US1] Integrate per contracts/export.md: `PreviewRenderer.exportPicture(_:)` (fresh `.rgba8` target, — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.ec-ios27.json (exit 0; PresenterExport: PNG max 0/255, JPEG mean 1.96, HEIC mean 2.19; refusals, one file, disabled chain, held import, full pool, close)
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

- [X] T-A25-506 [US3] `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/RobustnessTests.swift` and the — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.ec-ios27.json (exit 0; RobustnessTests: 10 rebuilds byte-identical, interrupted export no file, two sizes, memory warning 11→9 live)
  presenter's memory-warning observer (injected `NotificationCenter`, `trimPools()`): 10 rebuilds byte-identical; an
  export interrupted by `recreateContext` in `beforeReadBack` fails as `a25.export-interrupted` with no file and the
  next export succeeds; two framebuffer sizes letterbox the same result; a memory warning leaves the preview
  byte-identical; the interruption test stands for a background move during export (analyze C4)
- [X] T-A25-507 [US3] Write `docs/apps/effects-composer/device-campaign.md`: D1, D2, D3 rows tagged {device} (after — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.device-campaign.json (exit 0; 7 rows pending device campaign)
  ImplementationLock-100; D3 stays on iPadOS 26.5): peak memory with a 2,048-pixel picture and eight effects ≤ 200 MiB,
  preview frame time while editing ≤ 33 ms, export time per format ≤ 3 s, recovery after backgrounding

## Phase 5: Evidence and close

- [X] T-A25-508 Review checkpoint: `--name ec-ios27`, `documented-api`, `isolation`, `core-purity` (commands of — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.{ec-ios27,documented-api,isolation,core-purity}.json (all exit 0)
  quickstart.md steps 1–2)
- [X] T-A25-509 Contract: G-COLOR, G-EXPORT, G-ROBUST closed by "A25-P05" with notes on rows M11, M23, M24, M25, M36 — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.contract.json (exit 0; G-COLOR, G-EXPORT, G-ROBUST closed; M11, M23, M24, M25, M36 available)
  (`--name contract`); `docs/apps/effects-composer/README.md`
- [X] T-A25-510 `--name catalog`, `experience-packages`, `script-tests`; `xcodegen generate --spec project.yml`, then — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.{catalog,experience-packages,script-tests,app-unit,verify-27}.json (all exit 0)
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

## Phase 6: Convergence

- [X] T-A25-512 Keep a written export across a context rebuild in — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P05.ec-ios27-3.json (exit 0, 84+49; aWrittenExportSurvivesAContextRebuild and closingRemovesTheFolder pass; attempt ec-ios27-2 failed: a released-presenter close was not observable, replaced by the shell's deactivating state)
  `Packages/ExperiencesCreative/EffectsComposer/Experience/ComposerPresenter.swift`: `teardown` fails only a request
  not yet drawn (as interrupted) and keeps `exportFile` and its file; a write finishing after a rebuild is kept; the
  export folder is removed before the next export and when the presenter is released (`deinit`, the experience
  closing); add to `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/RobustnessTests.swift`: an export
  finished before `recreateContext` still exists afterwards with its share item, and releasing the presenter removes
  the folder, per spec Edge Cases (background during an export), FR-A25-506 (contradicts)
- [X] T-A25-513 Record in `specs/184-ec-p05-color-export-robustness/research.md` and — Verified 2026-11-19: 2026-11-19 research.md R10 and docs/apps/effects-composer/README.md record the file lifetime; validate_docs PASS
  `docs/apps/effects-composer/README.md` that the share sheet reports no completion, so the file stays until the next
  export or the experience closes, per FR-A25-508 (partial)
