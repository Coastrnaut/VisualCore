# Tasks: Living Wallpapers — Phase 02 Offscreen still renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/still.md](contracts/still.md), [contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md).
Gate A19-P02 (legacy). Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A19-P02 --timeout 600
--name <check> -- <command>`. Commit after every task (no trailers); read every check's exit before ticking, never in
the same command. iOS 27 only; iOS 26 and the reference regression at X-A19. Precedent:
`specs/132-ac-p02-overlay-theme/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A19-201 Baseline: cite the A19-P01 evidence (`.autonomy/checks/A19-P01.{lw-core-ios27,app-build,experience-packages}.json`) on the tree recorded at A19-P01 (`caac74c3`), whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A19-P01 evidence cited: .autonomy/checks/A19-P01.lw-core-ios27.json, A19-P01.app-build.json and A19-P01.experience-packages.json, all exit 0; no Packages, Apps or project.yml change since the A19-P01 record commit caac74c3
- [ ] T-A19-202 Add the targets `LivingWallpapersExperience` (path `LivingWallpapers/Experience`) and `LivingWallpapersExperienceTests` (path `LivingWallpapers/ExperienceTests`) and the product `LivingWallpapersExperience` to `Packages/ExperiencesCreative/Package.swift` (lead; dependencies as the Ambient Clock experience plus `VisualCoreScenes` and `VisualCorePersistence`)

## Phase 2: Foundational — VisualCore additions (G-ENCODE, G-STILLTIME)

- [X] T-A19-203 [P] Extend `Packages/VisualCoreRendering/Sources/VisualCoreRendering/StillImage.swift` per contracts/still.md: `StillImageFormat` (png, jpeg, heic with `typeIdentifier`), `StillImageEncoder.data(_:format:quality:)` ("quality 0…1, default 0.9, ignored for PNG"; opaque, sRGB; `pngData` calls it unchanged), `isAvailable(_:)`; `///` on every symbol; write `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/StillFormatTests.swift` (png byte-identical to `pngData`; each available format reads back at the size, `kCGColorSpaceSRGB` and its type identifier; JPEG and HEIC flat colour within 8 per channel; HEIC availability recorded and true on iOS 27.2; an unavailable format throws `.encoding`) (FR-A19-201) — Verified 2026-11-17: 2026-11-17: StillImageFormat (png, jpeg, heic with typeIdentifier), StillImageEncoder.data(_:format:quality:) and isAvailable(_:) in VisualCoreRendering/StillImage.swift; StillFormatTests (6: png byte-identical to pngData, every available format reads back at size, kCGColorSpaceSRGB and type, flat colour exact for PNG and within 8 for JPEG and HEIC, lower JPEG quality smaller, HEIC available on the iOS 27.2 simulator) pass in .autonomy/checks/A19-P02.rendering-ios27.json exit 0; written by an agent, retested
- [ ] T-A19-204 [P] Extend `Packages/VisualCoreRendering/Sources/VisualCoreExperienceHost/ExperienceStill.swift` (`ExperienceSession.renderStill(width:height:time:)`; `ExperienceStillRenderer.init(timed:)` and `callAsFunction(width:height:time:)`; the existing forms use time 0) and `ExperienceHostView.swift` (installs the timed renderer); write `Packages/VisualCoreRendering/Tests/VisualCoreExperienceHostTests/StillTimeTests.swift` (two times differ for a time-dependent scene, the same time is identical, the two-argument form equals time 0, live counts unchanged after a timed still) (FR-A19-202)
- [ ] T-A19-205 Update `Packages/VisualCoreRendering/README.md` (rows for `StillImageFormat`, `StillImageEncoder.data`, `isAvailable`, the timed still) and the API baseline (`python3 scripts/check_public_api.py --update`, then `--name public-api -- python3 scripts/check_public_api.py`); run the rendering and host tests (`--name rendering-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreRenderingTests VisualCoreExperienceHostTests`)

## Phase 3: Story 1 — the framed background (P1) 🎯

- [ ] T-A19-206 [P] [US1] Create `Packages/ExperiencesCreative/LivingWallpapers/Core/CropFrame.swift` ("margin 0.06 × the short canvas edge; template aspect within one point; inside the canvas"; top, bottom, side bands from `SafeAreaGuide`) and extend `Core/ExportPlanner.swift` with `ExportFormat` jpeg and heic; write `CoreTests/CropFrameTests.swift` (all nine templates, both orientations, three canvas sizes) (FR-A19-204; SC-A19-203)
- [ ] T-A19-207 [US1] Create `Packages/ExperiencesCreative/LivingWallpapers/Experience/{Adapter/WallpaperCore.swift,SceneShaders.swift,WallpaperPresenter.swift,CropOverlay.swift,WallpaperControls.swift,LivingWallpapersExperience.swift}` per data-model.md and contracts/experience.md: `WallpaperCore` (snapshot schema 1; the eight controls of clarification Q5 with ranges "scene 0…3, preset 0…2, parameters three values, template 0…8, orientation 0/1, animation time 0…3600, format 0…2, motion 0/1"; digest of every field; outcome `scene-<id>`; `qualityTiers` level-0 and level-1); four inline fragment sources over `vc/` with preset colours, parameters and seed uniforms at two levels; the presenter (one `FullScreenShaderScene`; `fixedTime` = animation time when motion is off or Reduce Motion is on); the native crop overlay with an accessibility label naming template, orientation and pixel size; controls through the action port; no GL call, no refused word
- [ ] T-A19-208 [US1] Write `Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/{WallpaperTestSupport,WallpaperCoreTests,SceneRenderTests,CropOverlayTests}.swift`: every action accepted in range and refused outside; equal actions equal digests; snapshot round trip; each scene at both levels not blank and identical for equal state and time; a motion-off picture is the same at two frame times; a repeated setup after a context recreation draws the same frame (spec edge case); the overlay frame for each template matches `CropFrame` (FR-A19-203, 204, 206; SC-A19-204)

## Phase 4: Story 2 and 3 — export, cancel and retry (P1)

- [ ] T-A19-209 [US2] Create `Packages/ExperiencesCreative/LivingWallpapers/Experience/StillExport.swift` per data-model.md (states idle → planned → rendered → encoded → verified → written, or cancelled or failed with no-limit, does-not-fit, format-unavailable, render, encoding, verification; owns `TemporaryFolder("LivingWallpapers-Export")`; removes its file on cancel or failure; a cancel flag checked after each step) (FR-A19-205)
- [ ] T-A19-210 [US3] Write `Packages/ExperiencesCreative/LivingWallpapers/ExperienceTests/StillExportTests.swift` on the real host: every available format exports at a fitting template and verifies; two animation times give different files and the same time identical pixels; before and after a cancel after render, a cancel after encode, an oversize failure and a retry at the offered size, `host.resources.stats.liveCount` and the folder's `fileCount` are equal; the live picture renders afterwards (SC-A19-201, 202)

## Phase 5: Registration and manifest

- [ ] T-A19-211 Register the candidate: `Catalog/registrations.json` entry for a19 (capabilities ≤ 40 characters each, quality_tiers ["level-0", "level-1"], palette, manifest `Packages/ExperiencesCreative/LivingWallpapers/scenario-manifest.json`, permissions []); `python3 scripts/build_catalog.py`; `Apps/VisualCore/App/ExperienceRegistry.swift` candidate `livingWallpapers` (no examples: schema 1); `project.yml` product; lists in app and script tests that name candidates
- [ ] T-A19-212 Write `Packages/ExperiencesCreative/LivingWallpapers/Experience/Adapter/WallpaperManifest.swift` (nine standard scenarios and the five fixtures of clarification Q5) and `ExperienceTests/WallpaperManifestTests.swift` (valid with `ContentRequirement(fixtures: 5)`, derived digests equal the engine's, every fixture ends in its state, the committed file matches); generate `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`

## Phase 6: Records and evidence

- [ ] T-A19-213 Living Wallpapers tests on sim-27.2 (`--name lw-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests LivingWallpapersExperienceTests`), the documented API (`--name documented-api`), the platform scan (`--name platform-claims -- sh specs/138-lw-p01-export-contract/scan-platform-claims.sh`) and the GL isolation (`--name isolation -- python3 scripts/check_app_isolation.py --experiences Packages/ExperiencesCreative/LivingWallpapers`) (FR-A19-207)
- [ ] T-A19-214 Contract: G-ENCODE, G-STILLTIME and G-SCENES closed by "A19-P02"; rows whose gaps are all closed become available with evidence (`--name contract`)
- [ ] T-A19-215 Catalog (`--name catalog -- python3 scripts/build_catalog.py --check`); app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`); runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a19.living-wallpapers --runtime 27`); packages and script tests
- [ ] T-A19-216 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A19-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

201 → 202 → {203, 204, 206} → 205 → 207 → 208 → 209 → 210 → 211 → 212 → 213 → 214 → 215 → 216. 203, 204 and 206 are
separate files; 207–210 are one experience (one writer).

## Parallel examples

Agent V: T-A19-203, 204 (VisualCore). Agent K: T-A19-206 (core). Agent E: T-A19-207–210 (experience). Lead:
Package.swift, README and baseline (205), registration (211), manifest generation (212), runs, contract, commits.

## Implementation strategy

MVP: the framed background (206–208). The export and the no-orphan fixture (209, 210) close the regression gate.
Review checkpoints after 205 (VisualCore green) and after 210.
