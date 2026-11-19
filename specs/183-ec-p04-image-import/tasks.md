# Tasks: Effects Composer — Phase 04 Image import

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/visualcore.md](contracts/visualcore.md), [contracts/import.md](contracts/import.md),
[quickstart.md](quickstart.md). Gate A25-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A25-P04 --timeout 595 --name <check> -- <command>`.
- **Commits:** one per task, no trailers. **Checks:** read every exit before ticking.
- **Scope:** iOS 27 for the experience; the VisualCore change also runs the reference regression on iOS 27 and 26.
- **Precedent:** `specs/175-gbl-p03-runner-probe/tasks.md`. **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A25-401 Baseline: cite the A25-P03 evidence (`.autonomy/checks/A25-P03.{ec-ios27-2,app-unit-2,verify-27}.json`) — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P03.{ec-ios27-2,app-unit-2,verify-27}.json exit 0

## Phase 2: VisualCore — U-RGBAUPLOAD (P1)

- [X] T-A25-402 [P] In `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUObjects.swift`: `RenderTarget.upload(rgba:)` per — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P04.byte-upload.json exit 0 (ByteUploadTests 3: rgba8 equal, rgba16f n/255, refusals)
  contracts/visualcore.md; `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/ByteUploadTests.swift`: bytes into `.rgba8` read back
  equal, into `.rgba16f` within half-float precision of n/255 (read with `readFloatPixels`), `.r8`, a wrong count and a
  stale target after `recreateContext` refused (FR-A25-401)
- [X] T-A25-403 The public API baseline (`python3 scripts/check_public_api.py --update`, then the check), `///` on the — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P04.{public-api,documented-api-rendering}.json exit 0 (the baseline line upload(rgba pixels: [UInt8]) -> Bool already listed for Texture, so it is unchanged); both READMEs
  addition, and the two README paragraphs (`Packages/VisualCoreRendering/README.md`, `Packages/VisualCore/README.md`)

## Phase 3: Stories 1 and 2 — use my own picture, upright and in the right colours (P1) 🎯

- [X] T-A25-404 [P] [US1] [US2] Create `Packages/ExperiencesCreative/EffectsComposer/Experience/ImageImport.swift` per clarification Q2 and data-model.md — Verified 2026-11-19: 2026-11-19 .autonomy/checks/A25-P04.image-import.json exit 0; ImageImport per clarification Q2 (never upscales; damaged when ImageIO reads no complete image)
  (data above 50 MiB refused before decoding; under 8 pixels refused; longer edge at most `limit`; orientation applied;
  sRGB; straight alpha; rows top-down)
- [ ] T-A25-405 [US2] Write `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/{ImportFixtures,ImageImportTests}.swift` per clarification Q3: the 8
  orientations put the marked corner top left with the right size; Display P3 red within 3/255 of its sRGB value;
  4,000 × 1,000 decodes to 2,048 × 512; damaged, tiny and oversized data refused with their codes; alpha kept
  (SC-A25-401–403)
- [ ] T-A25-406 [US1] [US4] Integrate per clarification Q4 in `Packages/ExperiencesCreative/EffectsComposer/Experience/{PreviewRenderer,ComposerPresenter,ECControls}.swift`:
  `importPicture(data:)` (background decode, latest pick wins, "Reading the picture…"), `useTestPicture()`, the source at
  the picture's size uploaded with `upload(rgba:)`, re-upload after a rebuild, the `import` (PhotosPicker) and
  `test-picture` controls; `Packages/ExperiencesCreative/EffectsComposer/ExperienceTests/PictureSourceTests.swift`: an imported picture becomes the source and the
  chain applies to it (CPU reference within 2/255); a refusal leaves the source; the test picture returns; the source is
  byte-identical after `recreateContext`; a restored session shows the test picture; a stale result is dropped

## Phase 4: Evidence

- [ ] T-A25-407 VisualCore evidence: `--name rendering-tests` (the VisualCoreRendering package on sim-27.2),
  `--name public-api` (`python3 scripts/check_public_api.py`), `--name reference-1` and `--name reference-2` (quickstart)
- [ ] T-A25-408 Review checkpoint: `--name ec-ios27` (both experience test targets), the documented API (also for
  `Packages/VisualCoreRendering/Sources`), isolation and core purity
- [ ] T-A25-409 Contract: G-IMPORT and U-RGBAUPLOAD closed by "A25-P04" (`--name contract`); README of the experience
- [ ] T-A25-410 `--name catalog`, `experience-packages`, `script-tests`; `xcodegen generate --spec project.yml`, then
  `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`; `--name verify-27`
- [ ] T-A25-411 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A25-P04; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

401 → {402, 404}; 402 → 403; 404 → 405; {402, 404} → 406 → 407 → 408 → 409 → 410 → 411.

## Parallel examples

- **Agent V:** 402, 403. **Agent I:** 404, 405. **Agent P:** 406 after V and I. **Lead:** 407–411.
