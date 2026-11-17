# Tasks: Living Wallpapers — Phase 01 Platform API and export contract verification

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/core.md](contracts/core.md), [quickstart.md](quickstart.md). Gate A19-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A19-P01 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore or ProjectM change. Precedent: `specs/131-ac-p01-clock-a11y/tasks.md`. Rollback: revert the commits (no
stored data exists yet).

## Phase 1: Setup

- [X] T-A19-101 Baseline: cite the A19-P00 evidence (`.autonomy/checks/A19-P00.{app-build,no-change,experience-packages}.json`) on an unchanged `Packages` tree instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A19-P00 evidence cited: .autonomy/checks/A19-P00.app-build.json, A19-P00.no-change.json and A19-P00.experience-packages.json, all exit 0; no Packages, Apps or project.yml change since the A19-P00 record commit 6efbd66f
- [X] T-A19-102 Add the targets `LivingWallpapersCore` (path `LivingWallpapers/Core`, dependencies `VisualCoreScenes` and `VisualCoreExperience`) and `LivingWallpapersCoreTests` (path `LivingWallpapers/CoreTests`, dependencies the core, `VisualCoreScenes` and `VisualCoreRendering`) to `Packages/ExperiencesCreative/Package.swift` (lead), with a comment naming feature 138 and "a pending core until A19-P02 adds the experience" — Verified 2026-11-17: 2026-11-17: LivingWallpapersCore (VisualCoreScenes, VisualCoreExperience) and LivingWallpapersCoreTests (the core, VisualCoreScenes, VisualCoreRendering) added to Packages/ExperiencesCreative/Package.swift; the package builds and tests in .autonomy/checks/A19-P01.lw-core-ios27.json exit 0

## Phase 2: Story 1 — curated backgrounds and the project (P1) 🎯

- [ ] T-A19-103 [P] [US1] Create `Packages/ExperiencesCreative/LivingWallpapers/Core/SceneCatalog.swift` per data-model.md: four scenes `aurora-bands`, `ink-flow`, `soft-cells`, `ripple-dunes`; "two or three per scene, with minimum < maximum and minimum ≤ default ≤ maximum" parameters; three presets of "four `RGBColor` with r, g, b in 0…1, opaque by construction"; lookup by id; `///` on every public symbol; no source or comment uses the words the T-A19-110 scan refuses ("video", "live wallpaper", "set as wallpaper")
- [ ] T-A19-104 [P] [US1] Create `Packages/ExperiencesCreative/LivingWallpapers/Core/WallpaperProject.swift` per data-model.md: schema 1, envelope kind `a19.wallpaper-project`, the 16,384-byte limit, `animationTime` "0…3600, finite", `format` png only, `WallpaperProject.default` (aurora-bands, preset 0, seed 1, iphone-16-pro, portrait, time 0, png) and `ProjectRefusal` with the seven codes and sentences; `encoded()` with sorted keys; `decode(_:)` checks size, envelope, version, body, then scene, preset, template and parameters in that order; no word the T-A19-110 scan refuses
- [ ] T-A19-105 [P] [US1] Write `Packages/ExperiencesCreative/LivingWallpapers/CoreTests/{SceneCatalogTests,ProjectTests}.swift`: counts, unique ids, ranges and opacity; project round trip exact; one sample per refusal (damaged, newer-version, unknown-scene, unknown-preset, unknown-template, invalid-parameter, too-large) leaving the default (FR-A19-101, 102; SC-A19-101, 104)

## Phase 3: Story 2 — exact sizes and the read-back fixture (P1)

- [ ] T-A19-106 [P] [US2] Create `Packages/ExperiencesCreative/LivingWallpapers/Core/CanvasTemplates.swift`: the nine templates of clarification Q3 with portrait sizes, `size(for:)` swapping edges for landscape, `SafeAreaGuide` (top 0.22, bottom 0.10, side 0.04, labelled approximate) and provenance "Apple technical specifications, retrieved 2026-11-17"
- [ ] T-A19-107 [P] [US2] Create `Packages/ExperiencesCreative/LivingWallpapers/Core/{ExportPlanner,ImageColorPipeline}.swift`: `ExportFormat` (png), `ExportPlan` (format, width, height, profile sRGB, fallback flag); `ExportPlanner.plan(project:maxEdge:maxPixels:)` (exact template size when it fits; `doesNotFit(template:offered:)` with `ExportGeometry(maxEdge:maxPixels:).size(longEdge:aspect:)` at the template's `ExportAspect`; `noLimit` when maxEdge ≤ 0); `ImageColorPipeline.inspect(_:)` (ImageIO: pixel width, height, colour space name, bytes) and `verify(_:against:)` (ok, or dimensions, profile, unreadable); no word the T-A19-110 scan refuses
- [ ] T-A19-108 [P] [US2] Write `Packages/ExperiencesCreative/LivingWallpapers/CoreTests/{TemplateTests,PlannerTests,ExportFixtureTests}.swift`: nine templates with provenance and swapped landscape; fits plan exactly; limits 2048, 4096 and 8192 refuse every larger template with an offered size that fits and equals `ExportGeometry`'s; limit 0 is `noLimit`; the fixture encodes a solid `StillImage` at every planned size that fits 4096 through `StillImageEncoder.pngData`, inspects it, and finds 0 mismatches with profile `kCGColorSpaceSRGB`; a damaged file is `unreadable` (FR-A19-103–105; SC-A19-102, 103)

## Phase 4: Story 3 — no impossible promise (P2)

- [ ] T-A19-109 [P] [US3] Write `docs/apps/living-wallpapers/video-decision.md` (clarification Q5: interface assessed, cost bounds, no-go, owner if reopened) and `docs/apps/living-wallpapers/licenses.md` (the four scenes and their presets written in this repository; template sizes from Apple's published specifications with the retrieval date; no third-party asset)
- [ ] T-A19-110 [US3] Write `specs/138-lw-p01-export-contract/scan-platform-claims.sh` (refuses `AVAssetWriter`, `VideoToolbox`, `CVPixelBuffer`, `UIScreen.main.brightness` and, case-insensitively, "live wallpaper", "video", "set as wallpaper" in `Packages/ExperiencesCreative/LivingWallpapers`) and run it (`--name platform-claims -- sh specs/138-lw-p01-export-contract/scan-platform-claims.sh`) (FR-A19-106; SC-A19-105)

## Phase 5: Records and evidence

- [ ] T-A19-111 Core tests on sim-27.2 (`--name lw-core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests`; each test under 10 s) and the documented API (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/LivingWallpapers`) (SC-A19-106)
- [ ] T-A19-112 Contract `docs/apps/living-wallpapers/visualcore-contract.json`: G-MODEL, G-TEMPLATES and G-VIDEO closed by "A19-P01"; rows whose gaps are all closed become available with evidence (`--name contract -- python3 scripts/check_app_contract.py --app living-wallpapers --render`)
- [ ] T-A19-113 Packages, catalog, script tests, no-change and the app build (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name catalog -- python3 scripts/build_catalog.py --check`; `--name script-tests -- python3 scripts/test_scripts.py`; `--name no-change -- git diff --exit-code --stat 9d453506..HEAD -- Packages/VisualCore Packages/VisualCoreRendering External`; `--name app-build -- python3 scripts/release_check.py --only app-build-for-testing-ios27`) (FR-A19-107)
- [ ] T-A19-114 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A19-P01; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

T-A19-101 → 102 → {103, 104, 106, 107} → {105, 108} → {109, 110} → 111 → 112 → 113 → 114. 103/104/106/107 and
105/108 are separate files and may run in parallel; 109 is independent.

## Parallel examples

Agent C: T-A19-103, 106 (catalog, templates) with the matching tests of 105 and 108. Agent P: T-A19-104, 107 (project,
planner, pipeline) with their tests. Agent D: T-A19-109. Lead: Package.swift (102), the scan (110), runs, contract,
commits.

## Implementation strategy

MVP: the catalog and project (103–105). The planner, templates and fixture (106–108) prove the regression rule; the
decision and scan (109, 110) close the platform risk. Review checkpoints after 108 (fixture passes) and at 112.
