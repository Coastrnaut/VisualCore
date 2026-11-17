# Tasks: Living Wallpapers — Phase 03 Project and preset editing and crop interface

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/editor.md](contracts/editor.md), [quickstart.md](quickstart.md). Gate A19-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A19-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only. No
VisualCore change. Precedent: `specs/133-ac-p03-themes-favourites/tasks.md`. Rollback: revert the commits.

## Phase 1: Setup

- [X] T-A19-301 Baseline: cite the A19-P02 evidence (`.autonomy/checks/A19-P02.{lw-ios27,app-unit,verify-27}.json`) on the tree recorded at A19-P02 (`4ea0d03b`), whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A19-P02 evidence cited: .autonomy/checks/A19-P02.lw-ios27.json, A19-P02.app-unit.json and A19-P02.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A19-P02 record commit 4ea0d03b

## Phase 2: Story 1 — editable colours (P1) 🎯

- [X] T-A19-302 [P] [US1] Core: `Packages/ExperiencesCreative/LivingWallpapers/Core/WallpaperProject.swift` schema 2 per data-model.md ("`customColors: [RGBColor]?`, nil or exactly four"; schema 1 decodes with nil; a count other than four is `invalid-parameter` id `customColors`); update `CoreTests/ProjectTests.swift` (schema-1 sample decodes with nil, round trip with custom colours, wrong count refused, newer still refused) — Verified 2026-11-17: 2026-11-17: Core/WallpaperProject.swift schema 2 (customColors nil or exactly four, finite in 0...1; schema 1 decodes with nil; wrong count or range invalid-parameter customColors; schema 3 newer); ProjectTests updated and new (schema-1 file without colours, exact round trip with colours, wrong counts 0/3/5, out-of-range colour) pass in .autonomy/checks/A19-P03.lw-ios27.json exit 0 (47 core and 47 experience tests on sim-27.2); written by an agent, retested
- [X] T-A19-303 [US1] Experience: `Experience/Adapter/WallpaperCore.swift` snapshot schema 2 (`custom` 0/1, `colors` twelve numbers each 0…1; migration 1 → 2 sets `custom` 0 and the preset's colours; controls `preset.color [slot 0…3, r 0…1, g 0…1, b 0…1]` and `preset.reset []`; a scene or preset change clears `custom`; the digest writes `colors` only when `custom` is 1); `Experience/Adapter/AdapterSchemaExamples.swift` (`schemaExample(version:seed:)`, `schemaOneExample()`, `schemaTwoExample()`); the presenter uses the custom colours for the palette uniforms; register the schema-1 example in `Apps/VisualCore/App/ExperienceRegistry.swift` (lead) — Verified 2026-11-17: 2026-11-17: WallpaperCore snapshot schema 2 (custom 0/1, colors 12 in 0...1, migration 1 to 2 with custom 0 and the preset's colours, preset.color and preset.reset, a real scene or preset change clears custom, digest domain a19.wallpaper.v2 writing colours only while custom); AdapterSchemaExamples (schemaOneExample registered in Apps/VisualCore/App/ExperienceRegistry.swift, schemaTwoExample); the presenter and SceneShaders.palette(colors:) use the custom colours; exercised in .autonomy/checks/A19-P03.lw-ios27.json exit 0 (47 core and 47 experience tests on sim-27.2); written by an agent, retested
- [ ] T-A19-304 [US1] Tests: `ExperienceTests/{ColourEditTests,SnapshotMigrationTests}.swift` and updates to `WallpaperCoreTests.swift`: each slot edit changes the picture; reset returns the preset's pixels exactly; out-of-range and wrong-count refused and change nothing; scene or preset change clears; the schema-1 example restores as schema 2 with `custom` 0 and its digest; newer refused (FR-A19-301; SC-A19-301)

## Phase 3: Story 2 and 3 — notice, result and help (P1)

- [ ] T-A19-305 [P] [US2] Core: `Core/ExportNotice.swift` (`notice(for:limit:)` with the wording of clarification Q2; nil when the plan fits) and `Core/ExportResultLine.swift` (`line(plan:result:)`, for example "PNG, 1206 × 2622 pixels, sRGB"); `CoreTests/ExportNoticeTests.swift` (limits 2048, 4096, 8192: a notice with the three numbers for every template above, none for fitting ones; limit 0 reads "Open a picture to export it."; result line for each format) (FR-A19-302, 303; SC-A19-302)
- [ ] T-A19-306 [P] [US3] Core: `Core/WallpaperHelp.swift` (the three sections of clarification Q4; no phase named; "the steps can differ between iOS versions"); `CoreTests/HelpTests.swift` (three non-empty sections; the person sets the wallpaper; none of the refused phrases)
- [ ] T-A19-307 [US2] Experience: `Experience/WallpaperControls.swift` shows the notice beside the template picker with an export button that uses `offeredPlan(format:)`, the result line after a written export with a "How to use it" button, and `Experience/HelpView.swift` reachable from the editor and the result; `ExperienceTests/NoticeAndResultTests.swift` (the controls' model gives the notice and the result line for a refused and a written export; the help opens from both places) (FR-A19-302–304)
- [ ] T-A19-308 [US3] Write `specs/140-lw-p03-editor/scan-help-claims.sh` (refuses, case-insensitively, "automatically", "sets your wallpaper", "installs", "animated wallpaper" in `Packages/ExperiencesCreative/LivingWallpapers`) and run it with the platform scan (`--name help-claims`, `--name platform-claims`) (SC-A19-304)

## Phase 4: Story 4 — accessibility (P2)

- [ ] T-A19-309 [US4] Experience: labels with values on every control in `WallpaperControls.swift`; the export outcome announced once through `ExperienceFeedback.announce` (`.outcome` for done or failed, `.rejection` for the notice); a one-column layout at accessibility-five; `ExperienceTests/EditorAccessibilityTests.swift` (every control's label non-empty and naming its value; one announcement per outcome through a recording sink; at accessibility-five an `ImageRenderer` layout has no control wider than the canvas) (FR-A19-305; SC-A19-303)

## Phase 5: Manifest, records and evidence

- [ ] T-A19-310 Update `Experience/Adapter/WallpaperManifest.swift` (rejection entries for `preset.color` out of range and wrong count; the five fixtures unchanged) and regenerate `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`
- [ ] T-A19-311 Tests on sim-27.2 (`--name lw-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing LivingWallpapersCoreTests LivingWallpapersExperienceTests`), documented API, isolation (SC-A19-305)
- [ ] T-A19-312 Contract: G-EDITOR, G-HELP and G-A11Y closed by "A19-P03"; rows whose gaps are all closed become available with evidence (`--name contract`)
- [ ] T-A19-313 Catalog, app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`, which runs the registry's migration check with the schema-1 example), runner (`--name verify-27`), packages and script tests
- [ ] T-A19-314 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A19-P03; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

301 → {302, 305, 306} → 303 → 304 → 307 → 308 → 309 → 310 → 311 → 312 → 313 → 314. 302, 305, 306 are separate core
files; 303, 304, 307, 309 are the experience (one writer).

## Parallel examples

Agent K: T-A19-302, 305, 306 (core and its tests). Agent E: T-A19-303, 304, 307, 309, 310 (experience). Lead:
registry example, scan (308), manifest regeneration, runs, contract, commits.

## Implementation strategy

MVP: editable colours with schema 2 (302–304). Notice, result and help (305–308) close the regression gate; the
accessibility work (309) closes G-A11Y. Review checkpoints after 304 and at 311.
